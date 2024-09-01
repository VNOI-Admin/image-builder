#include <malloc.h>
#include <string.h>
#include <stdio.h>
#include <curl/curl.h>
#include "vnoi_memory.c"

const int POST_FIELDS_MAXLEN = 1000;

size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata){
  int child_rcode = 0;

  struct memory *buf = (struct memory *) userdata;

  child_rcode = memory_extend(buf, buf->size + nmemb);
  if (child_rcode < 0) return CURL_WRITEFUNC_ERROR;

  memcpy(buf->data + buf->size, ptr, nmemb); // Return value can be discarded
  buf->size += nmemb;

  return nmemb;
}

void handle_curl_error(const char *p_msg, CURLcode curl_rcode){
  const char *error_msg = curl_easy_strerror(curl_rcode);
  fprintf(stderr, "%s: %s", p_msg, error_msg);
}

// Returns 0 if successful, -1 if error
int perform_POST(const char *endpoint, const char *post_fields, struct memory *buf){
  CURL *curlh = NULL;
  CURLcode curl_rcode;
  int return_code = 0;

  curl_global_init(CURL_GLOBAL_ALL);

  curlh = curl_easy_init();
  if (curlh == NULL){
    fprintf(stderr, "curl_easy_init failed");
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
  memory_create(&buf);
  setopt_and_handle_error(CURLOPT_WRITEFUNCTION, write_callback);
  setopt_and_handle_error(CURLOPT_WRITEDATA, &buf);

  #undef setopt_and_handle_error

  /* Perform POST */
  curl_rcode = curl_easy_perform(curlh);
  if (curl_rcode != CURLE_OK){
    handle_curl_error("POST failed", curl_rcode);
    return_code = -1;
    goto cleanup;
  }

  cleanup:
  curl_easy_cleanup(curlh);
  curl_global_cleanup();
  return return_code;
}

// Returns 1 if authorized, 0 if not authorized, -1 if error
int authenticate_contestant(const char *username, const char *password){
  char *escaped_username = NULL, *escaped_password = NULL;
  char post_fields[POST_FIELDS_MAXLEN];
  int child_rcode = 0, return_code = 0;

  /* Escape fields */
  escaped_username = curl_escape(username, 0);
  if (escaped_username == NULL){
    fprintf(stderr, "Username escape failed");
    return_code = -1;
    goto cleanup;
  }

  escaped_password = curl_escape(password, 0);
  if (escaped_password == NULL){
    fprintf(stderr, "Password escape failed");
    return_code = -1;
    goto cleanup;
  }

  /* Make POST fields */
  child_rcode = snprintf(post_fields, POST_FIELDS_MAXLEN,
    "username=%s&password=%s", escaped_username, escaped_password);
  if (child_rcode < 0){
    fprintf(stderr, "Post fields snprintf failed");
    return_code = -1;
    goto cleanup;
  }

  /* Perform POST */
  perform_POST(VNOI_LOGIN_ENDPOINT, post_fields);

  cleanup:
  curl_free(escaped_username);
  curl_free(escaped_password);
  return return_code;
}
