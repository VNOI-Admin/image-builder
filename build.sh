#!/bin/bash

set -e

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
    umount -l $CHROOT/dev
    umount -l $CHROOT/run
    log "Done"

	exit "${code}"
}

trap 'error ${LINENO}' ERR

# Install requested packages if system has apt
install_if_has_apt() {
    PACKAGES="$@"
    if [ -x "$(command -v apt-get)" ]; then
        log "Installing $PACKAGES"
        apt-get update
        apt-get install $@ -y
        log "Done"
    else
        log "apt-get not found, skipping installation of $PACKAGES"
    fi
}

assert_root() {
    # Check if user is root
    if [ "$EUID" -ne 0 ]
        then echo "Please run as root"
        exit 1
    fi
}

assert_nonroot() {
    if [ "$EUID" -eq 0 ]
        then echo "Please run as VirtualBox User"
        exit 1
    fi
}

SUDO_USER="root"
TOOLKIT="image-toolkit"

if [ -f config.local.sh ]; then
    source config.local.sh
else
    log "config.local.sh not found, running config.sh"
    source config.sh
fi

if $(findmnt -rno SOURCE,TARGET "$CHROOT/dev" > /dev/null); then
    log "Unmounting /dev and /run from chroot"
    sudo umount -l $CHROOT/dev
    sudo umount -l $CHROOT/run
    log "Done"
fi

icpc_build() {
    FORCE_DOWNLOAD=false
    CLEAR_EARLY=false
    PROD_DEV="prod"
    APT_SOURCE="icpc"

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
        --dev)
            PROD_DEV="dev"
            ;;
        --image-only)
            icpc_image_build $PROD_DEV
            return
            ;;
        --github-actions)
            CLEAR_EARLY=true
            ;;
        --vnoi-source)
            APT_SOURCE="vnoi"
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
        install_if_has_apt aria2
        log "Downloading ICPC image"
        aria2c -x 16 $ICPC_URL -o $ICPC_ISO_FILENAME --continue="true"
        # wget $ICPC_URL -O $ICPC_ISO_FILENAME -q --show-progress
    fi

    # Check if $2 file type is iso
    if [ ! $(file $ICPC_ISO_FILENAME --extension | cut -d' ' -f2) = "iso/iso9660" ]; then
        log "File is not an ISO"
        rm -f $ICPC_ISO_FILENAME
        exit 1
    fi

    install_if_has_apt \
        binutils \
        squashfs-tools \
        xorriso \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools \
        p7zip-full \
        p7zip-rar \
        unzip \
        zip

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
    mount --make-rslave --bind /dev $CHROOT/dev
    mount --make-rslave --bind /run $CHROOT/run
    log "Done"

    log "Copy scripts and config to chroot"
    cp -R build.sh chroot_install.sh $CHROOT/root
    log "Done"

    if [ $PROD_DEV = "prod" ]; then
        log "Copy toolkit to chroot"
        cp -R $TOOLKIT/ $CHROOT/root/src/
        log "Done"
    else
        mkdir -p $CHROOT/root/src
        log "Skipped copying toolkit to chroot"
    fi

    log "Encrypt super password"
    ENCRYPTED_SUPER_PASSWD=$(echo -n $SUPER_PASSWD | python3 -c 'import crypt, sys; print(crypt.crypt(sys.stdin.read(), crypt.mksalt(crypt.METHOD_SHA512)))')
    GRUB_PASSWD=$(echo -e "$SUPER_PASSWD\n$SUPER_PASSWD" | grub-mkpasswd-pbkdf2 | awk '/hash of / {print $NF}')
    echo "ENCRYPTED_SUPER_PASSWD='$ENCRYPTED_SUPER_PASSWD'" > $CHROOT/root/src/encrypted_passwd.sh
    echo "GRUB_PASSWD='$GRUB_PASSWD'" >> $CHROOT/root/src/encrypted_passwd.sh
    log "Done"

    log $APT_SOURCE
    if [ $APT_SOURCE = "vnoi" ]; then
        log "Making apt use VNOI and Ubuntu sources"
        # Change https://sysopspackages.icpc.global/ubuntu to http://archive.ubuntu.com/ubuntu
        sed -i 's/https:\/\/sysopspackages.icpc.global\/ubuntu/http:\/\/archive.ubuntu.com\/ubuntu/g' $CHROOT/etc/apt/sources.list
        # Remove the extremely big vscode repo
        sed -i '/https:\/\/sysopspackages.icpc.global\/vscode/d' $CHROOT/etc/apt/sources.list
        # Change https://sysopspackages.icpc.global to https://repo.vnoi.info
        sed -i 's/https:\/\/sysopspackages.icpc.global/https:\/\/repo.vnoi.info/g' $CHROOT/etc/apt/sources.list
        for file in $CHROOT/etc/apt/sources.list.d/*; do
            sed -i 's/https:\/\/sysopspackages.icpc.global\/ubuntu/http:\/\/archive.ubuntu.com\/ubuntu/g' $file
            sed -i 's/https:\/\/sysopspackages.icpc.global/https:\/\/repo.vnoi.info/g' $file
        done
        log "Done"

        log "Make VNOI key trusted"
        curl https://repo.vnoi.info/pubkey.txt | gpg --dearmor > $CHROOT/etc/apt/trusted.gpg.d/vnoi.gpg
    fi

    log "chrooting into $CHROOT"
    # Chroot, resetting all environment variables to ensure replicable building
    # https://www.linuxfromscratch.org/lfs/view/12.0/chapter07/chroot.html#:~:text=The%20%2Di%20option%20given%20to,PATH%20variables%20are%20set%20again.
    install -v /etc/resolv.conf $CHROOT/etc/
    su -c "chroot $CHROOT /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        PS1=\"[\u@\h \W]\$ \" \
        PATH=/usr/bin:/usr/sbin \
        PROD_DEV="$PROD_DEV" \
        /bin/bash /root/chroot_install.sh"
    log "Done"

    log "Cleanup scripts and config from chroot"
    rm -f $CHROOT/root/{build.sh,chroot_install.sh,config.sh,config.local.sh,authorized_keys}
    log "Done"

    log "Unmounting /dev and /run from chroot"
    umount -l $CHROOT/dev
    umount -l $CHROOT/run
    log "Done"

    if [ $CLEAR_EARLY = true ]; then
        log "Clearing early to free up space"
        rm -rf $ICPC_ISO_FILENAME
        log "Done"
    fi

    icpc_image_build $PROD_DEV $APT_SOURCE
}

icpc_image_build() {
    log "Start building ICPC image"

    if [ $1 = "prod" ]; then
        PRESEED=seeds/prod.preseed
        IMAGE_FILENAME="contestant.iso"
    else
        PRESEED=seeds/dev.preseed
        IMAGE_FILENAME="contestant-dev.iso"
    fi

    if [ $1 = "prod" ]; then
        PRESEED=seeds/prod.preseed
        IMAGE_FILENAME="contestant.iso"
    else
        PRESEED=seeds/dev.preseed
        IMAGE_FILENAME="contestant-dev.iso"
    fi

    APT_SOURCE=$2

    # Copy $ICPC folder into $IMAGE
    rm -rf $IMAGE
    cp -r $ICPC $IMAGE

    if [ $CLEAR_EARLY = true ]; then
        log "Clearing early to free up space"
        rm -rf $ICPC
        log "Done"
    fi

    rm -f $IMAGE/casper/filesystem.squashfs

    log "Move preseed at $PRESEED"
    cp $PRESEED $IMAGE/preseed/icpc.seed

    if [ $APT_SOURCE = "vnoi" ]; then
        log "Changing seed to make apt use VNOI and Ubuntu sources"
        sed -i 's/https:\/\/sysopspackages.icpc.global\/ubuntu/http:\/\/archive.ubuntu.com\/ubuntu/g' $IMAGE/preseed/icpc.seed
        sed -i 's/https:\/\/sysopspackages.icpc.global/https:\/\/repo.vnoi.info/g' $IMAGE/preseed/icpc.seed
        log "Done"
    fi

    log "Move custom grub.cfg with custom options" # TODO: (Try & Install or Install)
    cp grub.cfg $IMAGE/boot/grub/grub.cfg

    # # Create manifest
    chroot $CHROOT dpkg-query -W --showformat='${Package} ${Version}\n' > $IMAGE/casper/filesystem.manifest

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
        -o "../$IMAGE_FILENAME" \
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

    # from $TOOLKIT/config.sh
    if [ -f $TOOLKIT/config.sh ]; then
        TOOLKIT_CONFIG_SH=$($BASE64_ENCODE < $TOOLKIT/config.sh)
        echo "$TOOLKIT/config.sh: $TOOLKIT_CONFIG_SH"
    fi

    # from $TOOLKIT/misc/authorized_keys
    if [ -f $TOOLKIT/misc/authorized_keys ]; then
        AUTHORIZED_KEYS=$($BASE64_ENCODE < $TOOLKIT/misc/authorized_keys)
        echo "$TOOLKIT/misc/authorized_keys: $AUTHORIZED_KEYS"
    fi

    # Ask user if they want to use gh cli to push secret to repo
    read -p "Do you want to use gh cli to push secret to repo? (y/n) " -n 1 -r REPLY
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "Set ACTIONS_SECRET to repo"
        gh secret set CONFIG_LOCAL_SH -b "$CONFIG_LOCAL_SH"
        gh secret set TOOLKIT_CONFIG_SH -b "$TOOLKIT_CONFIG_SH"
        gh secret set AUTHORIZED_KEYS -b "$AUTHORIZED_KEYS"
    else
        echo "Skipping"
    fi
}

VM_NAME="ICPC-Dev"
dev_reload() {
    log "Checking if Virtual Machine is running"
    if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
    | grep -c "VMState=\"running\"") -ne 0 ]; then
        log "Running. Turning off VM"
        vboxmanage controlvm "$VM_NAME" poweroff
        log "Done"

        log "Polling for shutdown"
        while true; do
            if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
            | grep -c "VMState=\"running\"") -eq 0 ]; then
                break
            fi
            sleep 1
        done
        log "Done"
    else
        log "Not running"
    fi

    log "Restoring VM to snapshot root-install"
    vboxmanage snapshot "$VM_NAME" restore "root-install"
    log "Done"

    sleep 2

    log "Starting Virtual Machine"
    vboxmanage startvm "$VM_NAME"
    log "Done"

    log "Polling for guest control"
    while true; do
        if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
        | grep -c "GuestAdditionsRunLevel=2") -ne 0 ]; then
            break
        fi
        sleep 1
    done

    log "Installing from /media/sf_src (mounted Shared Folder)"
    vboxmanage guestcontrol "$VM_NAME" run \
        --username $SUDO_USER --password $SUPER_PASSWD \
        --exe "/bin/bash" \
        --wait-stdout --wait-stderr \
        -- -c "cd /root/src && /media/sf_src/setup.sh"
    log "Done"

    # Wait for Virtual Machine to shutdown
    log "Restarting Virtual Machine."
    vboxmanage controlvm "$VM_NAME" acpipowerbutton

    log "Waiting for Virtual Machine to shutdown"
    while true; do
        if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
        | grep -c "VMState=\"running\"") -eq 0 ]; then
            break
        fi
        sleep 1
    done
    log "Done"

    vboxmanage startvm "$VM_NAME"
    log "Virtual Machine started. Have fun coding!"
}

dev_create() {
    # add two options, --build and --new
    BUILD=false
    NEW=false
    FIRMWARE=efi64
    CPUS=4
    MEM=8192
    while [ $# -gt 0 ]; do
    case $1 in
        --build | -b)
            BUILD=true
            ;;
        --new | -n)
            NEW=true
            ;;
        --firmware | -f)
            shift
            FIRMWARE=$1
            ;;
        --cpus)
            shift
            CPUS=$1
            ;;
        --mem)
            shift
            MEM=$1
            ;;
        -h | --help)
            echo "Usage: $0 dev_create [--build] [--new] [--firmware <firmware>] [--cpus <cpus>] [--mem <mem>]"
            echo
            echo "  --firmware, -f  Set firmware type (default: efi64)"
            echo "  -b, --build     Build the ICPC image for development"
            echo "  -n, --new       Create a new Virtual Machine"
            echo "  --cpus          Set number of CPUs (default: 4)"
            echo "  --mem           Set memory size in MB (default: 8192)"
            echo "  -h, --help      Show this help"
            exit 0
            ;;
    esac
    shift
    done

    if [ $BUILD = true ]; then
        log "Building ICPC image for development"
        sudo ./$0 icpc_build --dev
        log "Done"
    else
        log "Skipping building ICPC image for development."
        log "Do make sure your image is for development (built with icpc_build --dev or dev_create)."
    fi

    VM_NAME="ICPC-Dev"
    VM_GUEST_OS_TYPE="Ubuntu22_LTS_64"
    VM_DIRECTORY="$HOME/VirtualBox VMs"

    if [ $NEW = true ]; then
        log "Removing old Virtual Machine"
        vboxmanage unregistervm $VM_NAME --delete || true
        echo "$VM_DIRECTORY/$VM_NAME"
        rm -rf "$VM_DIRECTORY/$VM_NAME"
        log "Done"
    fi

    log "Creating Virtual Machine $VM_NAME at $VM_DIRECTORY"
    vboxmanage createvm \
        --register \
        --default \
        --name "$VM_NAME" \
        --groups "/$VM_NAME" \
        --basefolder "$VM_DIRECTORY" \
        --ostype $VM_GUEST_OS_TYPE
    log "Done"

    log "Running configuration"
    vboxmanage modifyvm "$VM_NAME" \
        --memory $MEM \
        --cpus $CPUS \
        --firmware $FIRMWARE
    log "Done"

    log "Creating disk"
    DISK_FILENAME=$VM_DIRECTORY/$VM_NAME/$VM_NAME.vdi
    vboxmanage createmedium disk \
        --filename "$DISK_FILENAME" \
        --size 40960 \
        --variant Fixed
    log "Done"

    log "Attaching disk"
    vboxmanage storageattach "$VM_NAME" \
        --storagectl SATA \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$DISK_FILENAME" \
        --nonrotational on
    log "Done"

    log "Attaching installation image"
    vboxmanage storageattach "$VM_NAME" \
        --storagectl IDE \
        --port 0 \
        --device 0 \
        --type dvddrive \
        --medium "$INS_DIR/contestant-dev.iso"
    log "Done"

    log "Starting Virtual Machine. Please install contest image using the GUI."
    vboxmanage startvm "$VM_NAME"
    log "Done"

    # Wait for Virtual Machine to shutdown
    log "Waiting for Virtual Machine to shutdown"
    while true; do
        if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
        | grep -c "VMState=\"running\"") -eq 0 ]; then
            break
        fi
        sleep 1
    done
    log "Done"

    sleep 2

    log "Mounting Shared Folder"
    # Mount shared folder to /media/sf_src
    vboxmanage sharedfolder add "$VM_NAME" \
        --name "src" \
        --hostpath "$TOOLKIT" \
        --readonly \
        --automount
    log "Done"

    sleep 2

    log "Creating snapshot"
    vboxmanage snapshot "$VM_NAME" take "root-install"
    log "Done"

    sleep 2

    log "Loading toolkit to Virtual Machine"
    dev_reload
    log "Done"
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

help() {
    echo "Usage: $0 {icpc_build}"
    echo
    echo "  icpc_build: Build the ISO image based on the ICPC image"
    echo "  dev_create: Build the ISO image for development and create Virtual Machine. Run \" $0 dev_create --help\" for more options"
    echo "  dev_reload: Reload the Virtual Machine with the latest changes"
    echo "  generate_actions_secret: Generate actions secret from config.local.sh"
    echo "  clean: Clean up all files generated by this script"
    echo "  help: Show this help"
}

START_TIME=$(date +%s)

case $1 in
    clean)
        assert_root
        rm -rf $INS_DIR
        ;;
    icpc_build)
        assert_root
        icpc_build $@
        ;;
    generate_actions_secret)
        assert_root
        generate_actions_secret
        ;;
    dev_reload)
        assert_nonroot
        dev_reload
        ;;
    dev_create)
        assert_nonroot
        dev_create $@
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

log "Total time elapsed: $(($(date +%s) - $START_TIME)) seconds"
