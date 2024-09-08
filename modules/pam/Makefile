CC		= gcc
CFLAGS	= -Wall -Wextra -Wpedantic -Werror -Wno-unused-parameter -fPIC -fno-stack-protector
CDEF	=	'-DVNOI_ROOT="root"' \
			'-DVNOI_USER_PROMPT="Username: "' \
			'-DVNOI_PASSWD_PROMPT="Password: "' \
			'-DVNOI_DEFAULT_USERNAME="icpc"' \
			'-DVNOI_DEFAULT_PASSWORD="icpc"' \
			'-DVNOI_LOGIN_ENDPOINT="https://vpn.vnoi.info/auth/auth/login"' \
			'-DVNOI_CONFIG_ENDPOINT="https://vpn.vnoi.info/user/vpn/config"' \
			'-DVNOI_WIREGUARD_DIR="/etc/wireguard"' \
			'-DVNOI_PAM_LOGFILE="/var/log/vnoi_pam.log"'

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
	rm *.o vnoi_pam.so
