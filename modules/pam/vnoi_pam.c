/* 
  This PAM module intercepts username and password, sends it to a
  remote server for authentication, and signs in the user using a
  default username and password.
  It is basically a toned down Kerberos.
*/

#include <stdio.h>
#include <string.h>
#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include "vnoi_auth.c"

void handle_pam_error(const char *p_msg, pam_handle_t *pamh, int pam_rcode){
  const char *error_msg = pam_strerror(pamh, pam_rcode);
  fprintf(stderr, "%s: %s\n", p_msg, error_msg);
}

void access_token_cleanup(pam_handle_t *pamh, void *data, int error_status){
  if (data != NULL){
    free(data);
  }
}

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
    int argc, const char **argv){
  int pam_rcode, auth_rcode;
  const char *error_msg = NULL;

  const char *username = NULL;
  const char *password = NULL;

  const char *access_token = NULL;

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
  if (strcmp(username, VNOI_ROOT)){
    printf("Welcome Root\n");
    return PAM_SUCCESS;
  }

  /* Authenticate contestant */
  auth_rcode = authenticate_contestant(username, password, &access_token);
  if (auth_rcode < 0){
    fprintf(stderr, "Authentication failed due to internal error\n");
    return PAM_AUTH_ERR;
  } else if (auth_rcode == 0){
    fprintf(stderr, "Authentication failed, wrong username or password\n");
    return PAM_USER_UNKNOWN;
  }

  printf("Authentication successful\n. Welcome %s\n", username);

  /* Store access token */
  pam_rcode = pam_set_data(pamh, "vnoi_access_token", access_token, access_token_cleanup);
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
    int argc, const char **argv);
