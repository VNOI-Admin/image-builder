#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>

#define __USE_XOPEN_EXTENDED 1 /* https://stackoverflow.com/questions/782338/warning-with-nftw */
#include <ftw.h>
#include "vnoi_wg.h"
#include "vnoi_systemd.h"

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

// Returns 0 if successful, -1 if error encountered.
int wireguard_config_write(const char *config_content){
  int child_rcode, return_code = 0;
  
  int config_fd = -1;
  FILE *config_fp = NULL;

  /* Clear wireguard past configs */
  child_rcode = remove_tree(VNOI_WIREGUARD_DIR);
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard config removal failed\n");
    return_code = -1;
    goto cleanup;
  }

  /* Write new wireguard config */
  child_rcode = mkdir(VNOI_WIREGUARD_DIR, 0700);
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard config directory creation failed: %s\n",
      strerror(errno));
    return_code = -1;
    goto cleanup;
  }

  config_fd = creat(VNOI_WIREGUARD_DIR "/client.conf", 0600);
  if (config_fd < 0){
    fprintf(stderr, "Wireguard config file creation failed: %s\n",
      strerror(errno));
    return_code = -1;
    goto cleanup;
  }

  config_fp = fdopen(config_fd, "w");
  if (config_fp == NULL){
    fprintf(stderr, "Wireguard config file fdopen failed: %s\n",
      strerror(errno));
    return_code = -1;
    goto cleanup;
  }

  child_rcode = fprintf(config_fp, "%s", config_content);
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard config file write failed\n");
    return_code = -1;
    goto cleanup;
  }

  cleanup:
  if (config_fp){
    fclose(config_fp);
  } else if (config_fd >= 0){
    close(config_fd);
  }
  return return_code;
}

int wireguard_restart_overwrite_config(const char *config_content){
  int child_rcode;
  child_rcode = wireguard_config_write(config_content);
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard config write failed\n");
    return -1;
  }

  child_rcode = restart_systemd_unit("wg-quick@client");
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard restart failed\n");
    return -1;
  }

  return 0;
}