#include <string.h>
#include <systemd/sd-bus.h>

struct job_info_list {
  char *job_path;
  struct job_info_list *next;
};

void free_job_info_list(struct job_info_list *head){
  struct job_info_list *current = head;
  struct job_info_list *next;

  while (current != NULL){
    next = current->next;
    free(current->job_path);
    free(current);
    current = next;
  }
}

void append_job_info_list(struct job_info_list **head, const char *job_path){
  struct job_info_list *current = *head;
  struct job_info_list *new_node = malloc(sizeof(struct job_info_list));

  new_node->job_path = strdup(job_path);
  new_node->next = NULL;

  if (current == NULL){
    *head = new_node;
    return;
  }

  while (current->next != NULL)
    current = current->next;

  current->next = new_node;
}

/* Based on https://0pointer.net/blog/the-new-sd-bus-api-of-systemd.html 
and https://jonathangold.ca/blog/waiting-for-systemd-job-to-complete/ */
int restart_systemd_unit(const char *unit_name){
  const char service_name[] = "org.freedesktop.systemd1";
  const char object_path[] = "/org/freedesktop/systemd1";
  const char interface_name[] = "org.freedesktop.systemd1.Manager";

  sd_bus_error error = SD_BUS_ERROR_NULL;
  sd_bus_message *m = NULL;
  sd_bus *bus = NULL;
  const char *path;
  int r;

  /* Connect to the system bus */
  r = sd_bus_open_system(&bus);
  if (r < 0){
    fprintf(stderr, "Failed to connect to system bus: %s\n", strerror(-r));
    goto cleanup;
  }

  // /* Add match rule */
  // // https://www.freedesktop.org/software/systemd/man/latest/sd_bus_add_match.html
  // // https://dbus.freedesktop.org/doc/dbus-specification.html#message-bus-routing-match-rules
  // r = sd_bus_match_signal(bus, NULL, service_name, object_path, interface_name, "JobRemoved", NULL, NULL);
  // if (r < 0){
  //   fprintf(stderr, "Failed to add match signal: %s\n", strerror(-r));
  //   goto cleanup;
  // }

  /* Restart Unit. API at https://www.freedesktop.org/wiki/Software/systemd/dbus/ */
  r = sd_bus_call_method(bus, service_name, object_path, interface_name,
                         "RestartUnit",                       /* method name */
                         &error,                              /* object to return error in */
                         &m,                                  /* return message on success */
                         "ss",                                /* input signature */
                         unit_name,                           /* first argument */
                         "replace");                          /* second argument */
  if (r < 0){
    fprintf(stderr, "Failed to issue method call: %s\n", error.message);
    goto cleanup;
  }

  /* Parse the response message */
  r = sd_bus_message_read(m, "o", &path);
  if (r < 0){
    fprintf(stderr, "Failed to parse response message: %s\n", strerror(-r));
    goto cleanup;
  }

  // *job_path = strdup(path);

  cleanup:
  sd_bus_error_free(&error);
  sd_bus_message_unref(m);
  sd_bus_unref(bus);

  return r < 0 ? -1 : 0;
}
