#include <malloc.h>
#include <string.h>

#include <curl/curl.h>

#include "vnoi_log.h"
#include "vnoi_buffer.h"
#include "vnoi_json.h"
#include "vnoi_auth.h"

#define curl_setopt_and_handle_error(opt, value) \
  curl_rcode = curl_easy_setopt(curlh, opt, value); \
  if (curl_rcode != CURLE_OK){ \
    handle_curl_error(#opt " setopt failed", curl_rcode); \
    return -1; \
  }

const int FIELD_MAXLEN = 4096; // 4KB

void handle_curl_error(const char *p_msg, CURLcode curl_rcode){
  const char *error_msg = curl_easy_strerror(curl_rcode);
  write_log("%s: %s\n", p_msg, error_msg);
}

int curl_init_wrapper(CURL **curlh_return, const char *endpoint,
    struct buffer **header_buf, struct buffer **body_buf){
  CURL *curlh = NULL;
  CURLcode curl_rcode;

  curl_rcode = curl_global_init(CURL_GLOBAL_ALL);
  if (curl_rcode != CURLE_OK){
    handle_curl_error("curl_global_init failed", curl_rcode);
    return -1;
  }

  *curlh_return = curlh = curl_easy_init();
  if (curlh == NULL){
    write_log("curl_easy_init failed\n");
    return -1;
  }

  curl_setopt_and_handle_error(CURLOPT_VERBOSE, 1L);
  curl_setopt_and_handle_error(CURLOPT_URL, endpoint);

  /* Set write callback */
  *header_buf = buffer_create();
  if (*header_buf == NULL){
    write_log("Header buffer creation failed\n");
    return -1;
  }

  *body_buf = buffer_create();
  if (*body_buf == NULL){
    write_log("Body buffer creation failed\n");
    return -1;
  }

  curl_setopt_and_handle_error(CURLOPT_WRITEFUNCTION, write_callback);
  curl_setopt_and_handle_error(CURLOPT_HEADERDATA, *header_buf);
  curl_setopt_and_handle_error(CURLOPT_WRITEDATA, *body_buf);

  return 1;
}

int curl_perform_wrapper(CURL *curlh){
  CURLcode curl_rcode;

  curl_rcode = curl_easy_perform(curlh);
  if (curl_rcode != CURLE_OK){
    handle_curl_error("curl_easy_perform failed", curl_rcode);
    return -1;
  }

  long http_code = 0;
  curl_rcode = curl_easy_getinfo(curlh, CURLINFO_RESPONSE_CODE, &http_code);
  if (curl_rcode != CURLE_OK){
    handle_curl_error("curl_easy_getinfo failed", curl_rcode);
    return -1;
  }
  if (http_code != 200 && http_code != 201 && http_code != 202){
    write_log("HTTP status code: %ld\n", http_code);
    return 0;
  }

  return 1;
}

// Returns 1 if successful, -1 if internal error, 0 if server-side error/unauthorized.
// Free header_buf and body_buf after use.
int perform_POST(const char *endpoint, char *post_fields,
    struct buffer **header_buf, struct buffer **body_buf){
  CURL *curlh = NULL;
  CURLcode curl_rcode;
  int child_rcode = 0, return_code = 0;

  child_rcode = curl_init_wrapper(&curlh, endpoint, header_buf, body_buf);
  if (child_rcode < 0){
    return_code = -1;
    goto cleanup;
  }

  curl_setopt_and_handle_error(CURLOPT_COPYPOSTFIELDS, post_fields);

  /* Perform POST */
  child_rcode = curl_perform_wrapper(curlh);
  if (child_rcode < 0){
    return_code = -1;
    goto cleanup;
  } else if (child_rcode == 0){
    return_code = 0;
    goto cleanup;
  } else {
    return_code = 1;
  }

  cleanup:
  curl_easy_cleanup(curlh);
  curl_global_cleanup();
  return return_code;
}

int perform_GET(const char *endpoint, const struct curl_slist *header_list,
    struct buffer **header_buf, struct buffer **body_buf){
  CURL *curlh = NULL;
  CURLcode curl_rcode;
  int child_rcode = 0, return_code = 0;

  child_rcode = curl_init_wrapper(&curlh, endpoint, header_buf, body_buf);
  if (child_rcode < 0){
    return_code = -1;
    goto cleanup;
  }

  curl_setopt_and_handle_error(CURLOPT_HTTPHEADER, header_list);

  /* Perform GET */
  child_rcode = curl_perform_wrapper(curlh);
  if (child_rcode < 0){
    return_code = -1;
    goto cleanup;
  } else if (child_rcode == 0){
    return_code = 0;
    goto cleanup;
  } else {
    return_code = 1;
  }

  cleanup:
  curl_easy_cleanup(curlh);
  curl_global_cleanup();
  return return_code;
}

// Returns 1 if authorized, 0 if not authorized, -1 if error.
// Free access_token after use.
int authenticate_contestant(const char *username, const char *password,
    const char **access_token){
  const char *escaped_username = NULL, *escaped_password = NULL;
  char post_fields[FIELD_MAXLEN];
  int child_rcode = 0, return_code = 1;
  struct buffer *header_buf = NULL, *body_buf = NULL;

  /* Escape fields */
  #define curl_escape_and_handle_error(str) \
    escaped_ ## str = curl_escape(str, 0); \
    if (str == NULL){ \
      write_log(#str " escape failed\n"); \
      return_code = -1; \
      goto cleanup; \
    }

  curl_escape_and_handle_error(username);
  curl_escape_and_handle_error(password);
  #undef curl_escape_and_handle_error

  /* Make POST fields */
  child_rcode = snprintf(post_fields, FIELD_MAXLEN,
    "username=%s&password=%s", escaped_username, escaped_password);
  if (child_rcode < 0 || child_rcode >= FIELD_MAXLEN){
    write_log("Post fields snprintf failed\n");
    return_code = -1;
    goto cleanup;
  }

  /* Perform POST */
  child_rcode = perform_POST(VNOI_LOGIN_ENDPOINT, post_fields,
    &header_buf, &body_buf);

  /* Check response */
  if (child_rcode < 0){
    write_log("POST failed\n");
    return_code = -1;
    goto cleanup;
  } else if (child_rcode == 0){
    return_code = 0;
    goto cleanup;
  }

  /* Extract access token */
  const char *body_buf_data = buffer_extract(body_buf);
  *access_token = get_json_value(body_buf_data, "accessToken");
  if (*access_token == NULL){
    write_log("Access token extraction failed\nJSON Content: %s\n", body_buf_data);
    return_code = -1;
    goto cleanup;
  }

  cleanup:
  buffer_destroy(header_buf);
  free(header_buf);

  buffer_destroy(body_buf);
  free(body_buf);

  curl_free((void*) escaped_username);
  curl_free((void*) escaped_password);
  return return_code;
}

// Returns 1 if successful, 0 if server-side error, -1 if internal error.
// Free config_file after use.
int get_contestant_config(const char *access_token, const char **config_file){
  int child_rcode = 0, return_code = 1;
  char bearer_header[FIELD_MAXLEN];
  struct buffer *header_buf = NULL, *body_buf = NULL;

  /* Make GET header */
  child_rcode = snprintf(bearer_header, FIELD_MAXLEN,
    "Authorization: Bearer %s", access_token);
  if (child_rcode < 0 || child_rcode >= FIELD_MAXLEN){
    write_log("Bearer header snprintf failed\n");
    return_code = -1;
    goto cleanup;
  }

  struct curl_slist *header_list = NULL;
  header_list = curl_slist_append(header_list, bearer_header);
  if (header_list == NULL){
    write_log("Header list creation failed\n");
    return_code = -1;
    goto cleanup;
  }

  /* Perform GET */
  child_rcode = perform_GET(VNOI_CONFIG_ENDPOINT, header_list, &header_buf, &body_buf);
  if (child_rcode < 0){
    write_log("GET failed\n");
    return_code = -1;
    goto cleanup;
  } else if (child_rcode == 0){
    return_code = 0;
    goto cleanup;
  }

  /* Extract config file */
  const char *body_buf_data = buffer_extract(body_buf);
  *config_file = get_json_value(body_buf_data, "config");
  if (*config_file == NULL){
    write_log("Config file extraction failed\nJSON Content: %s\n", body_buf_data);
    return_code = -1;
    goto cleanup;
  }

  cleanup:
  curl_slist_free_all(header_list);
  return return_code;
}

#undef curl_setopt_and_handle_error
