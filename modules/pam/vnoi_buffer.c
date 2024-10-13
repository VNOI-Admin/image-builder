#include <malloc.h>
#include <string.h>

#include "vnoi_log.h"
#include "vnoi_buffer.h"

struct buffer {
  char *data;
  size_t real_size, size;
};

// Returns 0 if successful, -1 if error. Not handling overwrite.
struct buffer *buffer_create(){
  struct buffer *buf = malloc(sizeof(struct buffer));
  if (buf == NULL)
    return NULL;

  buf->data = malloc(1);
  if (buf->data == NULL){
    free(buf);
    return NULL;
  }

  buf->real_size = 1;
  buf->size = 0;

  return buf;
}

// Returns 0 if successful, -1 if error
int buffer_extend(struct buffer *buf, size_t new_size){
  if (new_size <= buf->real_size) return 0;

  size_t new_real_size = buf->real_size;
  while (new_real_size < new_size) new_real_size *= 2;

  char *new_data = realloc(buf->data, new_real_size);
  if (new_data == NULL){
    write_log("buffer extend failed\n");
    return -1;
  }

  buf->data = new_data;
  buf->real_size = new_real_size;
  return 0;
}

void buffer_destroy(struct buffer *buf){
  if (buf->data != NULL)
    free(buf->data);
}

size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata){
  int child_rcode = 0;

  struct buffer *buf = (struct buffer *) userdata;

  child_rcode = buffer_extend(buf, buf->size + size * nmemb);
  if (child_rcode < 0) return -1;

  memcpy(buf->data + buf->size, ptr, size * nmemb); // Return value can be discarded
  buf->size += size * nmemb;

  return size * nmemb;
}

const char *buffer_extract(struct buffer *buf){
  if (buf->data[buf->size-1])
    write_callback("", 1, 1, buf); // Add null terminator
  return buf->data;
}
