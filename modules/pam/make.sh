#!/bin/bash

set -e

mkdir -p build
gcc -c vnoi_pam.c -o build/vnoi_pam.o -fPIC -fno-stack-protector -Wall -Wextra -Wpedantic -Wno-unused-parameter \
    '-DVNOI_ROOT="root"' \
    '-DVNOI_USER_PROMPT="Username: "' \
    '-DVNOI_PASSWD_PROMPT="Password: "' \
    '-DVNOI_DEFAULT_USERNAME="icpc"' \
    '-DVNOI_DEFAULT_PASSWORD="icpc"' \
    '-DVNOI_LOGIN_ENDPOINT="http://localhost:8080/login"' \
    '-DVNOI_CONFIG_ENDPOINT="http://localhost:8080/config"' \
    '-DVNOI_WIREGUARD_DIR="/etc/wireguard"'

ld -x --shared -o build/vnoi_pam.so build/vnoi_pam.o -lpam -lcurl -ljson-c -lsystemd
