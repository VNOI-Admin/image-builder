/* 
  This PAM module intercepts username and password, sends it to a
  remote server for authentication, and signs in the user using a
  default username and password.
  It is basically a toned down Kerberos.
*/

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include "vnoi_auth.c"
#include "vnoi_dir.c"
#include "vnoi_systemd.c"

void handle_pam_error(const char *p_msg, pam_handle_t *pamh, int pam_rcode){
  const char *error_msg = pam_strerror(pamh, pam_rcode);
  fprintf(stderr, "%s: %s\n", p_msg, error_msg);
}

void access_token_cleanup(pam_handle_t *pamh, void *data, int error_status){
  if (data == NULL) return;
  free(data);
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

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
    int argc, const char **argv){
  int pam_rcode, auth_rcode;

  const char *username = NULL;
  const char *password = NULL;

  const char *access_token = calloc(1, 1);

  // Uncomment if this module is not required/requisite
  // /* Store placeholder access token */
  // pam_rcode = pam_set_data(pamh, "vnoi_access_token", (void*) access_token, access_token_cleanup);
  // if (pam_rcode != PAM_SUCCESS){
  //   handle_pam_error("Access token placeholder store failed", pamh, pam_rcode);
  //   return PAM_AUTH_ERR;
  // }

  /* Prompt user for username */
  pam_rcode = pam_get_user(pamh, &username, VNOI_USER_PROMPT);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Username prompt failed", pamh, pam_rcode);
    return PAM_CRED_INSUFFICIENT;
  }

  /* Prompt user for password */
  pam_rcode = pam_get_authtok(pamh, PAM_AUTHTOK, &password, VNOI_PASSWD_PROMPT);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Password prompt failed", pamh, pam_rcode);
    return PAM_CRED_INSUFFICIENT;
  }

  // We let root do their thing.
  if (strcmp(username, VNOI_ROOT) == 0){
    printf("Welcome Root\n");
    return PAM_SUCCESS;
  }
  printf("Welcome %s\n", username);

  /* Authenticate contestant */
  auth_rcode = authenticate_contestant(username, password, &access_token);
  if (auth_rcode < 0){
    fprintf(stderr, "Authentication failed due to internal error\n");
    return PAM_AUTH_ERR;
  } else if (auth_rcode == 0){
    fprintf(stderr, "Authentication failed, wrong username or password\n");
    return PAM_USER_UNKNOWN;
  }

  printf("Authentication successful.\nWelcome %s\n", username);

  /* Store access token */
  pam_rcode = pam_set_data(pamh, "vnoi_access_token", (void*) access_token, access_token_cleanup);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Access token store failed", pamh, pam_rcode);
    return PAM_AUTH_ERR;
  }

  /* Change authentication username to default */
  pam_rcode = pam_set_item(pamh, PAM_USER, VNOI_DEFAULT_USERNAME);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Username modify failed", pamh, pam_rcode);
    return PAM_AUTH_ERR;
  }

  /* Change authentication password to default */
  pam_rcode = pam_set_item(pamh, PAM_AUTHTOK, VNOI_DEFAULT_PASSWORD);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Password modify failed", pamh, pam_rcode);
    return PAM_AUTH_ERR;
  }

  return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_open_session(pam_handle_t *pamh, int flags,
    int argc, const char **argv){
  int pam_rcode, config_rcode, child_rcode, return_code = PAM_SUCCESS;

  const char *access_token = NULL;
  const char *config_content = NULL;

  pam_rcode = pam_get_data(pamh, "vnoi_access_token", (const void**) &access_token);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Access token retrieval failed", pamh, pam_rcode);
    return_code = PAM_SESSION_ERR;
    goto cleanup;
  }

  config_rcode = get_contestant_config(access_token, &config_content);
  if (config_rcode < 0){
    fprintf(stderr, "Config file retrieval failed due to internal error\n");
    return_code = PAM_SESSION_ERR;
    goto cleanup;
  } else if (config_rcode == 0){
    fprintf(stderr, "Config file retrieval failed due to server-side error\n");
    return_code = PAM_SESSION_ERR;
    goto cleanup;
  }

  printf("Config file retrieval successful\n");
  /* Write config file */
  child_rcode = wireguard_config_write(config_content);
  if (child_rcode < 0){
    fprintf(stderr, "Config file write failed\n");
    return_code = PAM_SESSION_ERR;
    goto cleanup;
  }

  child_rcode = restart_systemd_unit("wg-quick@client");
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard restart failed\n");
    return_code = PAM_SESSION_ERR;
    goto cleanup;
  }

  cleanup:
  return return_code;
}
