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

void authenticate_contestant(const char *username, const char *password){

}

int handle_pam_error(const char *p_msg, pam_handle_t *pamh, int pam_rcode){
  const char *error_msg = pam_strerror(pamh, pam_rcode);
  fprintf(stderr, "%s: %s", p_msg, error_msg);
  return PAM_PERM_DENIED;
}

extern int pam_sm_authenticate(pam_handle_t *pamh, int flags,
                               int argc, const char **argv){
  int pam_rcode;
  const char *error_msg = NULL;

  const char *username = NULL;
  const char *password = NULL;


  /* Prompt user for username */
  pam_rcode = pam_get_user(pamh, &username, VNOI_USER_PROMPT);
  if (pam_rcode != PAM_SUCCESS)
    return handle_pam_error("Username prompt failed", pamh, pam_rcode);

  /* Prompt user for password */
  pam_rcode = pam_get_authtok(pamh, PAM_AUTHTOK, password, VNOI_PASSWD_PROMPT);
  if (pam_rcode != PAM_SUCCESS)
    return handle_pam_error("Password prompt failed", pamh, pam_rcode);

  /* Authenticate user */

  // We let root do their thing.
  if (strcmp(username, VNOI_ROOT))
    return PAM_SUCCESS;

  // Authenticate contestant

  /* Change authentication username to default */
  pam_rcode = pam_set_item(pamh, PAM_USER, VNOI_DEFAULT_USERNAME);
  if (pam_rcode != PAM_SUCCESS)
    return handle_pam_error("Username modify failed", pamh, pam_rcode);

  /* Change authentication password to default */
  pam_rcode = pam_set_item(pamh, PAM_AUTHTOK, VNOI_DEFAULT_PASSWORD);
  if (pam_rcode != PAM_SUCCESS)
    return handle_pam_error("Password modify failed", pamh, pam_rcode);

  return PAM_SUCCESS;
}