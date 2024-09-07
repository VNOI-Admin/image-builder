/* 
  This PAM module intercepts username and password, sends it to a
  remote server for authentication, and signs in the user using a
  default username and password.
  It is basically a toned down Kerberos.
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <security/pam_modules.h>
#include <security/pam_ext.h>

#include "vnoi_auth.h"
#include "vnoi_wg.h"

void handle_pam_error(const char *p_msg, pam_handle_t *pamh, int pam_rcode){
  const char *error_msg = pam_strerror(pamh, pam_rcode);
  fprintf(stderr, "%s: %s\n", p_msg, error_msg);
}

void access_token_cleanup(pam_handle_t *pamh, void *data, int error_status){
  if (data == NULL) return;
  free(data);
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
    int argc, const char **argv){
  int pam_rcode, auth_rcode;

  const char *username = NULL;
  const char *password = NULL;
  const char *access_token = NULL;

  // Uncomment if this module is not required/requisite
  /*
    const char *access_token = calloc(1, 1);
    // Store placeholder access token
    pam_rcode = pam_set_data(pamh, "vnoi_access_token", (void*) access_token, access_token_cleanup);
    if (pam_rcode != PAM_SUCCESS){
      handle_pam_error("Access token placeholder store failed", pamh, pam_rcode);
      return PAM_AUTH_ERR;
    }
  */

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
  const char *username = NULL;

  pam_rcode = pam_get_user(pamh, &username, VNOI_USER_PROMPT);
  if (pam_rcode != PAM_SUCCESS){
    handle_pam_error("Username prompt failed", pamh, pam_rcode);
    return PAM_CRED_INSUFFICIENT;
  }

  /* Skip if this is root, since no action is needed */
  if (strcmp(username, VNOI_ROOT) == 0)
    return PAM_SUCCESS;

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
  child_rcode = wireguard_restart_overwrite_config(config_content);
  if (child_rcode < 0){
    fprintf(stderr, "Wireguard restart/overwrite failed\n");
    return_code = PAM_SESSION_ERR;
    goto cleanup;
  }

  cleanup:
  return return_code;
}
