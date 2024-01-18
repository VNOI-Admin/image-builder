#!/bin/bash

# Custom color echo function, use for debugging
log() {
    echo -e "\e[32m$1\e[0m"
}

# Capture error and stop script
error() {
	local lineno="$1"
	local message="$2"
	local code="${3:-1}"
	if [[ -n "$message" ]] ; then
		echo "Error at or near line ${lineno}: ${message}; exiting with status ${code}"
	else
		echo "Error at or near line ${lineno}; exiting with status ${code}"
	fi

    log "Unmounting /dev and /run from chroot"
    umount $CHROOT/dev
    umount $CHROOT/run
    log "Done"

	exit "${code}"
}
trap 'error ${LINENO}' ERR

# Check if user is root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
fi

SUDO_USER="root"

if [ -f config.local.sh ]; then
    source config.local.sh
else
    log "config.local.sh not found, running config.sh"
    source config.sh
fi

if $(findmnt -rno SOURCE,TARGET "$CHROOT/dev" > /dev/null); then
    log "Unmounting /dev and /run from chroot"
    umount $CHROOT/dev
    umount $CHROOT/run
    log "Done"
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
        --github-actions)
            CLEAR_EARLY=true
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
        apt install aria2 -y
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
        squashfs-tools \
        xorriso \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools \
        p7zip-full \
        p7zip-rar \
        unzip \
        zip \
        -y

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
    unsquashfs -f -d $CHROOT $ICPC/casper/filesystem.squashfs
    log "Done"

    log "Mount /dev and /run to chroot"
    mount --bind /dev $CHROOT/dev
    mount --bind /run $CHROOT/run
    log "Done"

    log "Copy scripts and config to chroot"
    cp -R build.sh chroot_install.sh config.sh authorized_keys src/ $CHROOT/root
    if [ -f config.local.sh ]; then
        cp config.local.sh $CHROOT/root
    fi
    log "Done"

    log "Encrypt super password"
    ENCRYPTED_SUPER_PASSWD=$(echo -n $SUPER_PASSWD | python3 -c 'import crypt, sys; print(crypt.crypt(sys.stdin.read(), crypt.mksalt(crypt.METHOD_SHA512)))')
    GRUB_PASSWD=$(echo -e "$SUPER_PASSWD\n$SUPER_PASSWD" | grub-mkpasswd-pbkdf2 | awk '/hash of / {print $NF}')
    echo "ENCRYPTED_SUPER_PASSWD='$ENCRYPTED_SUPER_PASSWD'" > $CHROOT/root/src/encrypted_passwd.sh
    echo "GRUB_PASSWD='$GRUB_PASSWD'" >> $CHROOT/root/src/encrypted_passwd.sh
    log "Done"

    log "chrooting into $CHROOT"
    su -c "chroot $CHROOT /bin/bash /root/chroot_install.sh"
    log "Done"

    log "Cleanup scripts and config from chroot"
    rm -f $CHROOT/root{build.sh,chroot_install.sh,config.sh,config.local.sh,authorized_keys}
    log "Done"

    log "Unmounting /dev and /run from chroot"
    umount $CHROOT/dev
    umount $CHROOT/run
    log "Done"

    rm -rf $ICPC_ISO_FILENAME

    icpc_image_build
}

icpc_image_build() {
    log "Start building ICPC image"

    # # Copy $ICPC folder into $IMAGE
    rm -rf $IMAGE
    cp -r $ICPC $IMAGE

    if [ $CLEAR_EARLY = true ]; then
        log "Clearing early to free up space"
        rm -rf $ICPC
        log "Done"
    fi

    rm -f $IMAGE/casper/filesystem.squashfs

    log "Move custom preseed"
    cp custom.seed $IMAGE/preseed/custom.seed

    log "Move custom grub.cfg with custom options" # TODO: (Try & Install or Install)
    cp grub.cfg $IMAGE/boot/grub/grub.cfg

    # # Create manifest
    chroot $CHROOT dpkg-query -W --showformat='${Package} ${Version}\n' | tee $IMAGE/casper/filesystem.manifest

    cp -v $IMAGE/casper/filesystem.manifest $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/ubiquity/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/casper/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/discover/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/laptop-detect/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/os-prober/d' $IMAGE/casper/filesystem.manifest-desktop
    # Compress filesystem
    mksquashfs $CHROOT $IMAGE/casper/filesystem.squashfs -noappend -comp gzip

    printf $(du -sx --block-size=1 $CHROOT | cut -f1) > $IMAGE/casper/filesystem.size

    if [ $CLEAR_EARLY = true ]; then
        log "Clearing early to free up space"
        for i in $(ls $CHROOT); do
            if [ ! $i = "dev" ] && [ ! $i = "run" ]; then
                rm -rf $CHROOT/$i
            fi
        done
        log "Done"
    fi

    log "Building ISO"
    cd $IMAGE

    (
        dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
        mkfs.vfat efiboot.img && \
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
    log "Build finished. Cleaning up (run clean command for full clean up)."
}

generate_actions_secret() {
    if [ "$(uname)" == "Darwin" ]; then
        BASE64_ENCODE="base64 -b0"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        BASE64_ENCODE="base64 -w0"
    fi
    # Generate actions secret from config.local.sh
    if [ -f config.local.sh ]; then
        CONFIG_LOCAL_SH=$($BASE64_ENCODE < config.local.sh)
        echo "config.local.sh: $CONFIG_LOCAL_SH"
    fi

    # from src/config.sh
    if [ -f config.sh ]; then
        SRC_CONFIG_SH=$($BASE64_ENCODE < config.sh)
        echo "src/config.sh: $SRC_CONFIG_SH"
    fi

    # from src/config.local.sh
    if [ -f src/config.local.sh ]; then
        SRC_CONFIG_LOCAL_SH=$($BASE64_ENCODE < src/config.local.sh)
        echo "src/config.local.sh: $SRC_CONFIG_LOCAL_SH"
    fi

    # from src/misc/authorized_keys
    if [ -f src/misc/authorized_keys ]; then
        AUTHORIZED_KEYS=$($BASE64_ENCODE < src/misc/authorized_keys)
        echo "src/misc/authorized_keys: $AUTHORIZED_KEYS"
    fi

    # Ask user if they want to use gh cli to push secret to repo
    read -p "Do you want to use gh cli to push secret to repo? (y/n) " -n 1 -r REPLY
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "Set ACTIONS_SECRET to repo"
        gh secret set CONFIG_LOCAL_SH -b "$CONFIG_LOCAL_SH"
        gh secret set SRC_CONFIG_SH -b "$SRC_CONFIG_SH"
        gh secret set SRC_CONFIG_LOCAL_SH -b "$SRC_CONFIG_LOCAL_SH"
        gh secret set AUTHORIZED_KEYS -b "$AUTHORIZED_KEYS"
    else
        echo "Skipping"
    fi
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

help() {
    echo "Usage: $0 {icpc_build}"
    echo
    echo "  icpc_build <image_file>: Build the ISO image based on the ICPC image"
    echo "  generate_actions_secret: Generate actions secret from config.local.sh"
    echo "  clean: Clean up all files generated by this script"
    echo "  help: Show this help"
}

case $1 in
    clean)
        rm -rf $INS_DIR
        ;;
    icpc_build)
        icpc_build $@
        ;;
    generate_actions_secret)
        generate_actions_secret
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
