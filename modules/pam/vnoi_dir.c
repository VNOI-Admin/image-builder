#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <ftw.h>

// Callback function for nftw.
// Removes the file or directory at path.
int remove_callback(const char *path, const struct stat *sb, int typeflag, struct FTW *ftwbuf){
  int child_rcode = 0;

  child_rcode = remove(path);
  if (child_rcode < 0){
    fprintf(stderr, "Error removing %s: %s\n", path, strerror(errno));
    return -1;
  }
  return 0;
}

// Returns 0 if successful, -1 if error encountered.
int remove_tree(const char *path){
  int child_rcode = 0;
  child_rcode = nftw(path, remove_callback, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
  if (child_rcode < 0)
    return -1;
  return 0;
}
