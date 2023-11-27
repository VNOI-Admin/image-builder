#!/bin/bash

export ARCH="amd64" # Architecture
export DISTRO="focal" # (DEPRECATED) Distribution, focal recommended
export VARIANT="minbase" # Variant

export MIRROR="http://vn.archive.ubuntu.com/ubuntu/" # see https://launchpad.net/ubuntu/+archivemirrors

export INS_DIR="./live-build" # Installation directory
export CHROOT=$INS_DIR/chroot
export IMAGE=$INS_DIR/image
export ICPC=$INS_DIR/icpc

export ICPC_URL="https://image.icpc.global/icpc2023/ubuntu-22.04.1-icpc2023-20230722-amd64.iso" # ICPC image URL

export SUPER_PASSWD="" # password for superuser and grub
