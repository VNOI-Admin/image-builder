#!/bin/bash

# Check if user is root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
fi

if [ -f local_config.sh ]; then
    source local_config.sh
else
    echo "local_config.sh not found, running config.sh"
    source config.sh
fi

build() {
    # Install dependencies for building the ISO
    apt-get install \
        binutils \
        debootstrap \
        squashfs-tools \
        xorriso \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools

    mkdir -p live-build/{chroot,image/{casper,isolinux,install}}

    echo $VARIANT, $DISTRO, $ARCH, $MIRROR, $INS_DIR, $CHROOT, $IMAGE

    # Checkout bootstrap
    debootstrap \
        --arch=$ARCH \
        --variant=$VARIANT \
        $DISTRO \
        $CHROOT \
        $DEBOOTSTRAP_MIRROR

    echo "Mount /dev and /run to chroot"
    mount --bind /dev $CHROOT/dev
    mount --bind /run $CHROOT/run

    # Copy this folder to chroot except the $INS_DIR
    cp -R build.sh chroot_install.sh local_config.sh config.sh src $CHROOT/root

    # Copy local_config.sh if exists
    if [ -f local_config.sh ]; then
        cp local_config.sh $CHROOT/root
    fi

    clear

    sudo su -c "chroot $CHROOT /bin/bash /root/chroot_install.sh '$MIRROR'"

    # Remove build.sh, chroot_install.sh, config.sh and local_config.sh from chroot
    rm -f $CHROOT/root/build.sh $CHROOT/root/chroot_install.sh $CHROOT/root/config.sh $CHROOT/root/local_config.sh

    if [ -f local_config.sh ]; then
        rm -f $CHROOT/root/local_config.sh
    fi

    # Unmount /dev and /run from chroot
    echo "Unmounting /dev and /run from chroot"
    umount $CHROOT/dev
    umount $CHROOT/run

    image_build
}

image_build() {
    # Check if filesystem.squashfs exists
    if [ -f $IMAGE/casper/filesystem.squashfs ]; then
        rm -f $IMAGE/casper/filesystem.squashfs
    fi

    # Setup and populate the CD image directory
    cp $CHROOT/boot/vmlinuz-**-**-generic $IMAGE/casper/vmlinuz
    cp $CHROOT/boot/initrd.img-**-**-generic $IMAGE/casper/initrd

    cp $CHROOT/boot/memtest86+.bin $IMAGE/install/memtest86+

    wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O $IMAGE/install/memtest86-usb.zip

    unzip -p $IMAGE/install/memtest86-usb.zip memtest86-usb.img > $IMAGE/install/memtest86

    rm -f $IMAGE/install/memtest86-usb.zip

    # GRUB menu configuration
    touch $IMAGE/ubuntu

    cat <<EOF > $IMAGE/isolinux/grub.cfg
search --set=root --file /ubuntu

insmod all_video

set default="0"
set timeout=30

menuentry "Install Ubuntu FS (Custom Preseed)" {
   linux /casper/vmlinuz file=/cdrom/preseed/custom.seed auto=true priority=critical boot=casper automatic-ubiquity quiet splash noprompt noshell ---
   initrd /casper/initrd
}

menuentry "Try Ubuntu FS without installing" {
   linux /casper/vmlinuz boot=casper nopersistent toram quiet splash ---
   initrd /casper/initrd
}

menuentry "Check disc for defects" {
   linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
   initrd /casper/initrd
}

menuentry "Test memory Memtest86+ (BIOS)" {
   linux16 /install/memtest86+
}

menuentry "Test memory Memtest86 (UEFI, long load time)" {
   insmod part_gpt
   insmod search_fs_uuid
   insmod chain
   loopback loop /install/memtest86
   chainloader (loop,gpt1)/efi/boot/BOOTX64.efi
}
EOF

    # Create manifest
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

    cat <<EOF > $IMAGE/README.diskdefines
#define DISKNAME  Ubuntu from scratch
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

    # Add preseeed
    mkdir $IMAGE/preseed
    cp custom.seed $IMAGE/preseed/custom.seed

    clear

    echo "Building ISO"
    cd $IMAGE

    grub-mkstandalone \
        --format=x86_64-efi \
        --output=isolinux/bootx64.efi \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=isolinux/grub.cfg"

    (
        cd isolinux && \
        dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
        sudo mkfs.vfat efiboot.img && \
        LC_CTYPE=C mmd -i efiboot.img efi efi/boot && \
        LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
    )

    grub-mkstandalone \
        --format=i386-pc \
        --output=isolinux/core.img \
        --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" \
        --modules="linux16 linux normal iso9660 biosdisk search" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=isolinux/grub.cfg"

    cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img

    /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v -e 'md5sum.txt' -e 'bios.img' -e 'efiboot.img' > md5sum.txt)"

    sudo xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "Contestant ISO" \
        -output "../contestant.iso" \
        -eltorito-boot boot/grub/bios.img \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            --eltorito-catalog boot/grub/boot.cat \
            --grub2-boot-info \
            --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -eltorito-alt-boot \
            -e EFI/efiboot.img \
            -no-emul-boot \
        -append_partition 2 0xef isolinux/efiboot.img \
        -m "isolinux/efiboot.img" \
        -m "isolinux/bios.img" \
        -graft-points \
            "/EFI/efiboot.img=isolinux/efiboot.img" \
            "/boot/grub/bios.img=isolinux/bios.img" \
            "/boot/grub/grub.cfg=isolinux/grub.cfg" \
            "/boot/grub/loopback.cfg=isolinux/grub.cfg" \
            "."
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

case $1 in
    build)
        build
        ;;
    clean)
        rm -rf $INS_DIR
        ;;
    image_build)
        image_build
        ;;
    help)
        echo "Usage: $0 {build}"
        ;;
    '')
        echo "Usage: $0 {build}"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: $0 {build}"
        exit 1
        ;;
esac
