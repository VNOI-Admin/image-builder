#include <malloc.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <curl/curl.h>
#include <json-c/json.h>
#include "vnoi_memory.c"

int authenticate_contestant(const char *username, const char *password, const char **access_token);

const int POST_FIELDS_MAXLEN = 1000;

void handle_curl_error(const char *p_msg, CURLcode curl_rcode){
  const char *error_msg = curl_easy_strerror(curl_rcode);
  fprintf(stderr, "%s: %s\n", p_msg, error_msg);
}

// Returns 1 if successful, -1 if internal error, 0 if wrong username or password.
// Free header_buf and body_buf after use.
int perform_POST(const char *endpoint, const char *post_fields,
    struct memory **header_buf, struct memory **body_buf){
  CURL *curlh = NULL;
  CURLcode curl_rcode;
  int return_code = 1, child_rcode, http_status = 0;

  curl_global_init(CURL_GLOBAL_ALL);

  curlh = curl_easy_init();
  if (curlh == NULL){
    fprintf(stderr, "curl_easy_init failed\n");
    return_code = -1;
    goto cleanup;
  }

  #define setopt_and_handle_error(opt, value) \
    curl_rcode = curl_easy_setopt(curlh, opt, value); \
    if (curl_rcode != CURLE_OK){ \
      handle_curl_error(#opt " setopt failed", curl_rcode); \
      return_code = -1; \
      goto cleanup; \
    }
  
  setopt_and_handle_error(CURLOPT_VERBOSE, 1L);
  setopt_and_handle_error(CURLOPT_URL, endpoint);
  setopt_and_handle_error(CURLOPT_POSTFIELDS, post_fields);

  /* Set write callback */
  header_buf = malloc(sizeof(struct memory));
  if (header_buf == NULL){
    fprintf(stderr, "Header buffer creation failed\n");
    return_code = -1;
    goto cleanup;
  }

  child_rcode = memory_create(*header_buf);
  if (child_rcode < 0){
    return_code = -1;
    goto cleanup;
  }

  body_buf = malloc(sizeof(struct memory));
  if (body_buf == NULL){
    fprintf(stderr, "Body buffer creation failed\n");
    return_code = -1;
    goto cleanup;
  }
  child_rcode = memory_create(*body_buf);
  if (child_rcode < 0){
    return_code = -1;
    goto cleanup;
  }

  setopt_and_handle_error(CURLOPT_WRITEFUNCTION, write_callback);
  setopt_and_handle_error(CURLOPT_HEADERDATA, &header_buf);
  setopt_and_handle_error(CURLOPT_WRITEDATA, &body_buf);

  #undef setopt_and_handle_error

  /* Perform POST */
  curl_rcode = curl_easy_perform(curlh);
  if (curl_rcode != CURLE_OK){
    handle_curl_error("POST failed", curl_rcode);
    return_code = -1;
    goto cleanup;
  }

  long http_code = 0;
  curl_easy_getinfo(curlh, CURLINFO_RESPONSE_CODE, &http_code);
  if (http_code != 200 && http_code != 201 && http_code != 202){
    fprintf(stderr, "HTTP status code: %ld\n", http_code);
    return_code = 0;
  }

  cleanup:
  curl_easy_cleanup(curlh);
  curl_global_cleanup();
  return return_code;
}

// Returned string must be freed after use.
char *get_json_value(const char *json_str, const char *key){
  struct json_object *json_obj = json_tokener_parse(json_str);
  struct json_object *value_obj = NULL;
  char *return_str = NULL;
  const char *value_str = NULL;
  json_bool child_rcode;

  if (json_obj == NULL){
    fprintf(stderr, "JSON parse failed\n");
    goto cleanup;
  }

  child_rcode = json_object_object_get_ex(json_obj, key, &value_obj);
  if (!child_rcode || value_obj == NULL){
    fprintf(stderr, "Key not found\n");
    goto cleanup;
  }

  value_str = json_object_get_string(value_obj);
  return_str = strdup(value_str);
  if (return_str == NULL){
    fprintf(stderr, "String duplication failed: %s\n", strerror(errno));
    goto cleanup;
  }

  cleanup:
  json_object_put(json_obj);
  return return_str;
}

// Returns 1 if authorized, 0 if not authorized, -1 if error.
// Free access_token after use.
int authenticate_contestant(const char *username, const char *password, const char **access_token){
  const char *escaped_username = NULL, *escaped_password = NULL;
  char post_fields[POST_FIELDS_MAXLEN];
  int child_rcode = 0, return_code = 0;
  struct memory *header_buf = NULL, *body_buf = NULL;

  /* Escape fields */
  escaped_username = curl_escape(username, 0);
  if (escaped_username == NULL){
    fprintf(stderr, "Username escape failed\n");
    return_code = -1;
    goto cleanup;
  }

  escaped_password = curl_escape(password, 0);
  if (escaped_password == NULL){
    fprintf(stderr, "Password escape failed\n");
    return_code = -1;
    goto cleanup;
  }

  /* Make POST fields */
  child_rcode = snprintf(post_fields, POST_FIELDS_MAXLEN,
    "username=%s&password=%s", escaped_username, escaped_password);
  if (child_rcode < 0){
    fprintf(stderr, "Post fields snprintf failed\n");
    return_code = -1;
    goto cleanup;
  }

  /* Perform POST */
  child_rcode = perform_POST(VNOI_LOGIN_ENDPOINT, post_fields,
    &header_buf, &body_buf);

  /* Check response */
  if (child_rcode < 0){
    fprintf(stderr, "POST failed\n");
    return_code = -1;
    goto cleanup;
  }
  if (child_rcode == 0){
    return_code = 0;
    goto cleanup;
  }

  /* Extract access token */
  *access_token = get_json_value(body_buf->data, "access_token");
  if (*access_token == NULL){
    fprintf(stderr, "Access token extraction failed\nJSON Content: %s\n", body_buf->data);
    return_code = -1;
    goto cleanup;
  }

  cleanup:
  memory_destroy(header_buf);
  free(header_buf);

  memory_destroy(body_buf);
  free(body_buf);

  curl_free((void*) escaped_username);
  curl_free((void*) escaped_password);
  return return_code;
}
