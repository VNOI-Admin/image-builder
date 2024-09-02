#include <systemd/sd-bus.h>

/* Based on https://0pointer.net/blog/the-new-sd-bus-api-of-systemd.html */
int restart_systemd_unit(const char *unit_name){
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

  /* Restart Unit. API at https://www.freedesktop.org/wiki/Software/systemd/dbus/ */
  r = sd_bus_call_method(bus,
                         "org.freedesktop.systemd1",          /* service to contact */
                         "/org/freedesktop/systemd1",         /* object path */
                         "org.freedesktop.systemd1.Manager",  /* interface name */
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

  printf("Queued service job as %s.\n", path);

  cleanup:
  sd_bus_error_free(&error);
  sd_bus_message_unref(m);
  sd_bus_unref(bus);

  return r < 0 ? -1 : 0;
}
