#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <malloc.h>
#include <curl/curl.h>

// No initialization needed
void write_log(const char *format, ...){
  int rcode;
  FILE *log_file = fopen(VNOI_PAM_LOGFILE, "a");
  if (log_file == NULL){
    printf("Log file open failed: %s\n", strerror(errno));
    return;
  }

  va_list args;
  va_start(args, format);
  rcode = vfprintf(log_file, format, args);
  va_end(args);

  fclose(log_file);

  if (rcode < 0)
    printf("Log write failed\n");
}

int debug_callback(CURL *handle, curl_infotype type, char *data,
    size_t size, void *clientp){
  char *msg = malloc(size + 1);
  if (msg == NULL){
    write_log("Memory allocation failed\n");
    return -1;
  }

  memcpy(msg, data, size);
  msg[size] = '\0';
  write_log("CURL: ===============\n%s\n===============", msg);
  free(msg);

  return 0;
}
