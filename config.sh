#!/bin/bash

export ARCH="amd64" # Architecture
export DISTRO="focal" # Distribution, focal recommended
export VARIANT="minbase" # Variant

export MIRROR="http://fr.archive.ubuntu.com/ubuntu/" # see https://launchpad.net/ubuntu/+archivemirrors

export INS_DIR="./live-build" # Installation directory
export CHROOT=$INS_DIR/chroot
export IMAGE=$INS_DIR/image
