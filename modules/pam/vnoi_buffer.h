#include <malloc.h>

struct buffer;
struct buffer *buffer_create();
int buffer_extend(struct buffer *buf, size_t new_size);
void buffer_destroy(struct buffer *buf);
size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata);
const char *buffer_extract(struct buffer *buf);
