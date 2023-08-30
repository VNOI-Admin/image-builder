#!/bin/bash

# Capture error and stop script
set -e

# Check if user is root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
fi

SUDO_USER=$(logname)

# Custom color echo function, use for debugging
log() {
    echo -e "\e[32m$1\e[0m"
}

if [ -f local_config.sh ]; then
    source local_config.sh
else
    log "local_config.sh not found, running config.sh"
    source config.sh
fi


icpc_build() {
    FORCE_DOWNLOAD=false

    while [ $# -gt 0 ]; do
    case $1 in
        -u | --url)
            shift
            ICPC_URL=$1
            FORCE_DOWNLOAD=true
            ;;
        -f | --force)
            FORCE_DOWNLOAD=true
            ;;
        --image-only)
            icpc_image_build
            exit $?
            ;;
        -h | --help)
            echo "Usage: $0 icpc_build [-u|--url <url>] [-f|--force]"
            echo
            echo "  -u, --url <url>    URL to the original ICPC image"
            echo "  -f, --force        Force download the original ICPC image"
            echo "  --image-only       Only build the image, skip downloading and modifying the original ICPC image"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
    esac
    shift
    done

    ICPC_ISO_FILENAME="icpc-image.iso"
    if [ ! -f $ICPC_ISO_FILENAME ] || [ $FORCE_DOWNLOAD = true ]; then
        log "Downloading ICPC image"
        apt install aria2
        aria2c -x 16 $ICPC_URL -o $ICPC_ISO_FILENAME --continue="true"
        # wget $ICPC_URL -O $ICPC_ISO_FILENAME -q --show-progress
    fi

    # Check if $2 file type is iso
    if [ ! $(file $ICPC_ISO_FILENAME --extension | cut -d' ' -f2) = "iso/iso9660" ]; then
        log "File is not an ISO"
        rm -f $ICPC_ISO_FILENAME
        exit 1
    fi

    apt-get update
    apt-get install \
        binutils \
        debootstrap \
        squashfs-tools \
        xorriso \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools

    mkdir -p $INS_DIR/{chroot,image/{casper,install},icpc}

    log "Removing old chroot"
    rm -rf $CHROOT/*  # Clean chroot if exists
    log "Done"

    # Extract ISO to chroot
    log "Extract MBR from ISO"
    7z x $ICPC_ISO_FILENAME -o$INS_DIR/icpc -aoa -mnt4
    dd if="$ICPC_ISO_FILENAME" bs=1 count=446 of="$INS_DIR/icpc/contestant.mbr"
    log "Done"

    log "Extracting squashfs filesystem from ISO"
    time sudo unsquashfs -f -d $CHROOT $ICPC/casper/filesystem.squashfs
    log "Done"

    log "Mount /dev and /run to chroot"
    mount --bind /dev $CHROOT/dev
    mount --bind /run $CHROOT/run
    log "Done"

    log "Copy scripts and config to chroot"
    cp -R build.sh chroot_install.sh config.sh authorized_keys src/ $CHROOT/root
    if [ -f local_config.sh ]; then
        cp local_config.sh $CHROOT/root
    fi
    log "Done"

    log "chrooting into $CHROOT"
    sudo su -c "chroot $CHROOT /bin/bash /root/chroot_install.sh"
    log "Done"

    log "Cleanup scripts and config from chroot"
    rm -f $CHROOT/root{build.sh,chroot_install.sh,config.sh,local_config.sh,authorized_keys,local_config.sh}
    log "Done"

    log "Unmounting /dev and /run from chroot"
    umount $CHROOT/dev
    umount $CHROOT/run
    log "Done"

    icpc_image_build
}

icpc_image_build() {
    echo "Start building ICPC image"

    # # Copy $ICPC folder into $IMAGE
    rm -rf $IMAGE
    cp -r $ICPC $IMAGE

    rm -f $IMAGE/casper/filesystem.squashfs

    # # Create manifest
    chroot $CHROOT dpkg-query -W --showformat='${Package} ${Version}\n' | tee $IMAGE/casper/filesystem.manifest

    cp -v $IMAGE/casper/filesystem.manifest $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/ubiquity/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/casper/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/discover/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/laptop-detect/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/os-prober/d' $IMAGE/casper/filesystem.manifest-desktop
    # Compress filesystem
    mksquashfs $CHROOT $IMAGE/casper/filesystem.squashfs

    printf $(du -sx --block-size=1 $CHROOT | cut -f1) > $IMAGE/casper/filesystem.size

    echo "Building ISO"
    cd $IMAGE

    (
        dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
        sudo mkfs.vfat efiboot.img && \
        LC_CTYPE=C mmd -i efiboot.img EFI EFI/boot && \
        LC_CTYPE=C mcopy -i efiboot.img EFI/boot/*.efi ::EFI/boot
    )

    rm md5sum.txt
    /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v -e 'md5sum.txt' -e 'efiboot.img' -e 'contestant.mbr' > md5sum.txt)"

    xorriso -as mkisofs \
        -r -V "Contestant ISO" -J -joliet-long -l \
        -iso-level 3 \
        -partition_offset 16 \
        --grub2-mbr "contestant.mbr" \
        --mbr-force-bootable \
        -append_partition 2 0xEF efiboot.img \
        -appended_part_as_gpt \
        -c /boot.catalog \
        -b /boot/grub/i386-pc/eltorito.img \
            -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
        -eltorito-alt-boot \
        -e '--interval:appended_partition_2:all::' \
            -no-emul-boot \
        -o "../contestant.iso" \
        .
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

help() {
    echo "Usage: $0 {icpc_build}"
    echo
    echo "  icpc_build <image_file>: Build the ISO image based on the ICPC image"
}

case $1 in
    clean)
        rm -rf $INS_DIR
        ;;
    icpc_build)
        icpc_build $@
        ;;
    help)
        help
        ;;
    '')
        help
        ;;
    *)
        help
        ;;
esac
