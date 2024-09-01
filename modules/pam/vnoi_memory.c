#include <malloc.h>

struct memory {
  char *data;
  size_t real_size, size;
};

int memory_create(struct memory *buf);
int memory_extend(struct memory *buf, size_t new_size);

int memory_create(struct memory *buf){
  buf->data = malloc(1);
  if (buf->data == NULL){
    fprintf(stderr, "Memory creation failed");
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
    fprintf(stderr, "Memory extend failed");
    return -1;
  }

  buf->real_size = new_real_size;
  return 0;
}
