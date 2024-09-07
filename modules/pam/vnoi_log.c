#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

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
