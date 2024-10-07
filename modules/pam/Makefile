include config.mk

CC		= gcc
CFLAGS	= -Wall -Wextra -Wpedantic -Werror -Wno-unused-parameter -fPIC -fno-stack-protector
CDEF	=	'-DVNOI_ROOT=$(VNOI_ROOT)' \
			'-DVNOI_USER_PROMPT=$(VNOI_USER_PROMPT)' \
			'-DVNOI_PASSWD_PROMPT=$(VNOI_PASSWD_PROMPT)' \
			'-DVNOI_DEFAULT_USERNAME=$(VNOI_DEFAULT_USERNAME)' \
			'-DVNOI_DEFAULT_PASSWORD=$(VNOI_DEFAULT_PASSWORD)' \
			'-DVNOI_LOGIN_ENDPOINT=$(VNOI_LOGIN_ENDPOINT)' \
			'-DVNOI_CONFIG_ENDPOINT=$(VNOI_CONFIG_ENDPOINT)' \
			'-DVNOI_WIREGUARD_DIR=$(VNOI_WIREGUARD_DIR)' \
			'-DVNOI_PAM_LOGFILE=$(VNOI_PAM_LOGFILE)'

LD		= ld
LDFLAGS = -x --shared
LDLIBS	= -lpam -lcurl -ljson-c -lsystemd

.PHONY: all clean
all: vnoi_pam.so

OBJS := $(patsubst %.c,%.o,$(wildcard *.c))

vnoi_pam.so: $(OBJS)
	$(LD) $(LDFLAGS) $(LDLIBS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) $(CDEF) -c -o $@ $<

clean:
	rm -f *.o vnoi_pam.so
