#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <json-c/json.h>
#include "vnoi_json.h"

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
