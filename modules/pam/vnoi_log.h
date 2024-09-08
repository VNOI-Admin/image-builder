#include <curl/curl.h>
void write_log(const char *format, ...);
int debug_callback(CURL *handle, curl_infotype type, char *data,
    size_t size, void *clientp);
