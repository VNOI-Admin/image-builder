#!/bin/bash

export INS_DIR="./live-build" # Installation directory
export CHROOT=$INS_DIR/chroot
export IMAGE=$INS_DIR/image
export ICPC=$INS_DIR/icpc

export ICPC_URL="https://image.icpc.global/icpc2023/ubuntu-22.04.1-icpc2023-20240207-amd64.iso" # ICPC image URL
export UBUNTU_APT_SOURCE="http://archive.ubuntu.com/ubuntu" # Ubuntu APT source
export CUSTOM_APT_SOURCE="https://repo.vnoi.info" # VNOI APT source

export SUPER_PASSWD="123456789" # password for superuser and grub, must be at leasst 8 characters long
