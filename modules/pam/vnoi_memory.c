#include <malloc.h>

struct memory;
int memory_create(struct memory *buf);
int memory_extend(struct memory *buf, size_t new_size);
void memory_destroy(struct memory *buf);
size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata);

struct memory {
  char *data;
  size_t real_size, size;
};

// Returns 0 if successful, -1 if error. Not handling overwrite.
int memory_create(struct memory *buf){
  buf->data = malloc(1);
  if (buf->data == NULL){
    fprintf(stderr, "Memory creation failed\n");
    return -1;
  }

  buf->real_size = 1;
  buf->size = 0;
  return 0;
}

// Returns 0 if successful, -1 if error
int memory_extend(struct memory *buf, size_t new_size){
  if (new_size <= buf->real_size) return 0;

  int new_real_size = buf->real_size;
  while (new_real_size < new_size) new_real_size *= 2;

  char *new_data = realloc(buf->data, new_real_size);
  if (new_data == NULL){
    fprintf(stderr, "Memory extend failed\n");
    return -1;
  }

  buf->data = new_data;
  buf->real_size = new_real_size;
  return 0;
}

void memory_destroy(struct memory *buf){
  if (buf->data != NULL)
    free(buf->data);
}

size_t write_callback(char *ptr, size_t size, size_t nmemb, void *userdata){
  int child_rcode = 0;

  struct memory *buf = (struct memory *) userdata;

  child_rcode = memory_extend(buf, buf->size + size * nmemb);
  if (child_rcode < 0) return CURL_WRITEFUNC_ERROR;

  memcpy(buf->data + buf->size, ptr, size * nmemb); // Return value can be discarded
  buf->size += size * nmemb;

  return size * nmemb;
}

const char *memory_extract(struct memory *buf){
  if (buf->data[buf->size-1])
    write_callback("", 1, 1, buf); // Add null terminator
  return buf->data;
}
