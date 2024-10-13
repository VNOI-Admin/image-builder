#!/bin/bash

set -e

VERBOSE_LEVEL=1
STEPS=()

# Custom color echo function, use for debugging
log() {
    local level=$1
    local message=$2

    if [[ $VERBOSE_LEVEL -ge $level ]]; then
        echo -e "\e[32m$message\e[0m"
    fi
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

    log 2 "Unmounting /dev and /run from chroot"
    umount -l $CHROOT/dev
    umount -l $CHROOT/run
    log 2 "Done"

	exit "${code}"
}

trap 'error ${LINENO}' ERR

add_step() {
    local step_name=$1
    local step_command=$2
    STEPS+=("$step_name" "$step_command")
}

run_command() {
    local command=$1

    if [[ $VERBOSE_LEVEL -eq 0 ]]; then
        eval "$command" &> /dev/null  # Run silently
    elif [[ $VERBOSE_LEVEL -eq 1 ]]; then
        eval "$command" 1> /dev/null  # Supress stdout
    else
        eval "$command"  # Full output for log level 2
    fi
}

run_all_steps() {
    local total_steps=$(( ${#STEPS[@]} / 2 ))  # Each step is a tuple of 2 strings
    local current_step=0

    for (( i = 0; i < ${#STEPS[@]} ; i += 2 )); do
        current_step=$((current_step + 1))
        local step_name=${STEPS[i]}
        local step_command=${STEPS[i+1]}

        log 1 "Step $current_step/$total_steps: $step_name"

        local start_time=$(date +%s)

        run_command "$step_command"

        local end_time=$(date +%s)
        local elapsed_time=$(( end_time - start_time ))

        log 2 "Elapsed time: ${elapsed_time} seconds"
    done
}

# Install requested packages if system has apt
install_if_has_apt() {
    PACKAGES="$@"
    if [ -x "$(command -v apt-get)" ]; then
        log 2 "Installing $PACKAGES"
        apt-get update
        apt-get install $@ -y
    else
        log 2 "apt-get not found, skipping installation of $PACKAGES"
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
    log 1 "config.local.sh not found, running config.sh"
    source config.sh
fi

if $(findmnt -rno SOURCE,TARGET "$CHROOT/dev" > /dev/null); then
    sudo umount -l $CHROOT/dev
    sudo umount -l $CHROOT/run
fi

build_modules() {
    log "Building modules"

    make -C modules/pam clean
    make -C modules/pam

    cp modules/pam/vnoi_pam.so $TOOLKIT/misc

    log "Done"
}

icpc_build() {
    log 1 "Start icpc_build"
    STEPS=()

    FORCE_DOWNLOAD=false
    CLEAR_EARLY=false
    COMPACT=false
    PROD_DEV="prod"
    APT_SOURCE="vnoi"

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
        -q)
            VERBOSE_LEVEL=0
            ;;
        -v)
            VERBOSE_LEVEL=1
            ;;
        -vv)
            VERBOSE_LEVEL=2
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
        --icpc-source)
            APT_SOURCE="icpc"
            ;;
        --compact)
            COMPACT=true
            ;;
        -h | --help)
            echo "Usage: $0 icpc_build [-u|--url <url>] [-f|--force]"
            echo
            echo "  -u, --url <url>    URL to the original ICPC image"
            echo "  -f, --force        Force download the original ICPC image"
            echo "  -q                 Verbose level: quiet"
            echo "  -v                 Verbose level: normal (default)"
            echo "  -vv                Verbose level: debug"
            echo "  --image-only       Only build the image, skip downloading and modifying the original ICPC image"
            echo "  --github-actions   Clear early to free up space"
            echo "  --vnoi-source      Use VNOI and Ubuntu sources"
            echo "  --icpc-source      Use ICPC sources"
            echo "  -h, --help         Show this help"
            exit 0
            ;;
    esac
    shift
    done

    ICPC_ISO_FILENAME="icpc-image.iso"
    if [ ! -f $ICPC_ISO_FILENAME ] || [ $FORCE_DOWNLOAD = true ]; then
        add_step "Downloading ICPC image" "$(cat <<"EOM"
install_if_has_apt aria2 genisoimage
aria2c -x 16 $ICPC_URL -o $ICPC_ISO_FILENAME --continue="true"
# wget $ICPC_URL -O $ICPC_ISO_FILENAME -q --show-progress

# Check if $2 file type is iso
if [ ! isoinfo -d -i filename.iso > /dev/null 2>&1 ]; then
    echo "File is not an ISO" 1>&2
    rm -f $ICPC_ISO_FILENAME
    exit 1
fi
EOM
        )"
    fi

    add_step "Installing packages" "install_if_has_apt \
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
        curl \
        libjson-c-dev \
        libpam0g-dev \
        libsystemd-dev \
        libcurl4-openssl-dev
    "

    add_step "Creating directories and removing old chroot" 'mkdir -p $INS_DIR/{chroot,image/{casper,install},icpc} && rm -rf $CHROOT/*'

    # Extract ISO to chroot
    add_step "Extract MBR from ISO" "$(cat <<"EOM"
7z x $ICPC_ISO_FILENAME -o$INS_DIR/icpc -aoa -mnt4
dd if="$ICPC_ISO_FILENAME" bs=1 count=446 of="$INS_DIR/icpc/contestant.mbr"
EOM
    )"

    add_step "Extracting squashfs filesystem from ISO" 'unsquashfs -f -d $CHROOT $ICPC/casper/filesystem.squashfs'

    if [ $CLEAR_EARLY = true ]; then
        add_step "Clearing early to free up space" 'rm -rf $ICPC/casper/filesystem.squashfs'
    fi

    add_step "Mount /dev and /run to chroot" " \
        mount --make-rslave --bind /dev \$CHROOT/dev; \
        mount --make-rslave --bind /run \$CHROOT/run \
    "

    add_step "Copy scripts and config to chroot" 'cp -R build.sh chroot_install.sh $CHROOT/root'

    if [ $PROD_DEV = "prod" ]; then
        build_modules

        log "Copy toolkit to chroot"
        cp -R $TOOLKIT/ $CHROOT/root/src/
        log "Done"
        add_step "Copy toolkit to chroot" 'cp -R $TOOLKIT/ $CHROOT/root/src/'
    else
        add_step "Skipped copying toolkit to chroot" 'mkdir -p $CHROOT/root/src'
    fi

    add_step "Encrypt super password" "$(cat <<"EOM"
ENCRYPTED_SUPER_PASSWD=$(echo -n $SUPER_PASSWD | python3 -c 'import crypt, sys; print(crypt.crypt(sys.stdin.read(), crypt.mksalt(crypt.METHOD_SHA512)))')
GRUB_PASSWD=$(echo -e "$SUPER_PASSWD\n$SUPER_PASSWD" | grub-mkpasswd-pbkdf2 | awk '/hash of / {print $NF}')
echo "ENCRYPTED_SUPER_PASSWD='$ENCRYPTED_SUPER_PASSWD'" > $CHROOT/root/src/encrypted_passwd.sh
echo "GRUB_PASSWD='$GRUB_PASSWD'" >> $CHROOT/root/src/encrypted_passwd.sh
EOM
    )"

    if [ $APT_SOURCE = "vnoi" ]; then
        add_step "Making apt use VNOI and Ubuntu sources" "$(cat <<"EOM"
log 2 $APT_SOURCE
# Change https://sysopspackages.icpc.global/ubuntu to $UBUNTU_APT_SOURCE
sed -i "s|https://sysopspackages.icpc.global/ubuntu|$UBUNTU_APT_SOURCE|g" $CHROOT/etc/apt/sources.list
# Remove the extremely big vscode repo
sed -i '/https:\/\/sysopspackages.icpc.global\/vscode/d' $CHROOT/etc/apt/sources.list
# Change https://sysopspackages.icpc.global to $CUSTOM_APT_SOURCE
sed -i "s|https://sysopspackages.icpc.global|$CUSTOM_APT_SOURCE|g" $CHROOT/etc/apt/sources.list
for file in $CHROOT/etc/apt/sources.list.d/*; do
    sed -i "s|https://sysopspackages.icpc.global/ubuntu|$UBUNTU_APT_SOURCE|g" $file
    sed -i "s|https://sysopspackages.icpc.global|$CUSTOM_APT_SOURCE|g" $file
done
EOM
        )"

        add_step "Make VNOI key trusted" 'curl $CUSTOM_APT_SOURCE/pubkey.txt | gpg --dearmor > $CHROOT/etc/apt/trusted.gpg.d/vnoi.gpg'
    fi

    add_step "chrooting into $CHROOT" "$(cat <<"EOM"
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
EOM
    )"

    add_step "Cleanup scripts and config from chroot" 'rm -f $CHROOT/root/{build.sh,chroot_install.sh,config.sh,config.local.sh,authorized_keys}'

    add_step "Unmounting /dev and /run from chroot" " \
        umount -l \$CHROOT/dev; \
        umount -l \$CHROOT/run \
    "

    if [ $CLEAR_EARLY = true ]; then
        add_step "Clearing early to free up space" 'rm -rf $ICPC_ISO_FILENAME'
    fi

    run_all_steps

    icpc_image_build $PROD_DEV $APT_SOURCE
}

icpc_image_build() {
    log 1 "Start building ICPC image"
    STEPS=()

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
        log 2 "Clearing early to free up space"
        rm -rf $ICPC
    fi

    rm -f $IMAGE/casper/filesystem.squashfs

    add_step "Move preseed at $PRESEED" 'cp $PRESEED $IMAGE/preseed/icpc.seed'

    if [ $APT_SOURCE = "vnoi" ]; then
        add_step "Changing seed to make apt use VNOI and Ubuntu sources" "$(cat <<"EOM"
sed -i "s|https://sysopspackages.icpc.global/ubuntu|$UBUNTU_APT_SOURCE|g" $IMAGE/preseed/icpc.seed
sed -i "s|https://sysopspackages.icpc.global|$CUSTOM_APT_SOURCE|g" $IMAGE/preseed/icpc.seed
EOM
        )"
    fi

    # TODO: (Try & Install or Install)
    add_step "Move custom grub.cfg with custom options" 'cp grub.cfg $IMAGE/boot/grub/grub.cfg'

    add_step "Create manifest" "$(cat <<"EOM"
chroot $CHROOT dpkg-query -W --showformat='${Package} ${Version}\n' > $IMAGE/casper/filesystem.manifest
cp -v $IMAGE/casper/filesystem.manifest $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/ubiquity/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/casper/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/discover/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/laptop-detect/d' $IMAGE/casper/filesystem.manifest-desktop
    sed -i '/os-prober/d' $IMAGE/casper/filesystem.manifest-desktop
EOM
    )"

    add_step "Compress filesystem" "$(cat <<"EOM"
if [ $COMPACT = true ]; then
    log 2 "Compressing filesystem with xz (slow, smaller size)"
    mksquashfs $CHROOT $IMAGE/casper/filesystem.squashfs -noappend -b 1048576 -comp xz -Xdict-size 100%
else
    log 2 "Compressing filesystem with gzip (fast, larger size)"
    mksquashfs $CHROOT $IMAGE/casper/filesystem.squashfs -noappend -comp gzip
fi

printf $(du -sx --block-size=1 $CHROOT | cut -f1) > $IMAGE/casper/filesystem.size
EOM
    )"

    if [ $CLEAR_EARLY = true ]; then
        add_step "Clearing early to free up space" "$(cat <<"EOM"
for i in $(ls $CHROOT); do
    if [ ! $i = "dev" ] && [ ! $i = "run" ]; then
        rm -rf $CHROOT/$i
    fi
done
EOM
        )"
    fi

    add_step "Building ISO" "$(cat <<"EOM"
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
EOM
    )"

    if [ $CLEAR_EARLY = true ]; then
        add_step "Clearing early to free up space" 'rm -rf $IMAGE'
    fi

    run_all_steps

    log 1 "Build finished. Cleaning up (run clean command for full clean up)."
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
    log 0 "Checking if Virtual Machine is running"
    if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
    | grep -c "VMState=\"running\"") -ne 0 ]; then
        log 0 "Running. Turning off VM"
        vboxmanage controlvm "$VM_NAME" poweroff
        log 0 "Done"

        log 0 "Polling for shutdown"
        while true; do
            if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
            | grep -c "VMState=\"running\"") -eq 0 ]; then
                break
            fi
            sleep 1
        done
        log 0 "Done"
    else
        log 0 "Not running"
    fi

    log 0 "Restoring VM to snapshot root-install"
    vboxmanage snapshot "$VM_NAME" restore "root-install"
    log 0 "Done"

    sleep 2

    log 0 "Starting Virtual Machine"
    vboxmanage startvm "$VM_NAME"
    log 0 "Done"

    log 0 "Polling for guest control"
    while true; do
        if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
        | grep -c "GuestAdditionsRunLevel=2") -ne 0 ]; then
            break
        fi
        sleep 1
    done

    log 0 "Installing from /media/sf_src (mounted Shared Folder)"
    vboxmanage guestcontrol "$VM_NAME" run \
        --username $SUDO_USER --password $SUPER_PASSWD \
        --exe "/bin/bash" \
        --wait-stdout --wait-stderr \
        -- -c "cd /root/src && /media/sf_src/setup.sh"
    log 0 "Done"

    # Wait for Virtual Machine to shutdown
    log 0 "Restarting Virtual Machine."
    vboxmanage controlvm "$VM_NAME" acpipowerbutton

    log 0 "Waiting for Virtual Machine to shutdown"
    while true; do
        if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
        | grep -c "VMState=\"running\"") -eq 0 ]; then
            break
        fi
        sleep 1
    done
    log 0 "Done"

    sleep 3

    vboxmanage startvm "$VM_NAME"
    log 0 "Virtual Machine started. Have fun coding!"
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
        log 0 "Building ICPC image for development"
        sudo ./$0 icpc_build --dev
        log 0 "Done"
    else
        log 0 "Skipping building ICPC image for development."
        log 0 "Do make sure your image is for development (built with icpc_build --dev or dev_create)."
    fi

    VM_NAME="ICPC-Dev"
    VM_GUEST_OS_TYPE="Ubuntu22_LTS_64"
    VM_DIRECTORY="$HOME/VirtualBox VMs"

    if [ $NEW = true ]; then
        log 0 "Removing old Virtual Machine"
        vboxmanage unregistervm $VM_NAME --delete || true
        echo "$VM_DIRECTORY/$VM_NAME"
        rm -rf "$VM_DIRECTORY/$VM_NAME"
        log 0 "Done"
    fi

    log 0 "Creating Virtual Machine $VM_NAME at $VM_DIRECTORY"
    vboxmanage createvm \
        --register \
        --default \
        --name "$VM_NAME" \
        --groups "/$VM_NAME" \
        --basefolder "$VM_DIRECTORY" \
        --ostype $VM_GUEST_OS_TYPE
    log 0 "Done"

    log 0 "Running configuration"
    vboxmanage modifyvm "$VM_NAME" \
        --memory $MEM \
        --cpus $CPUS \
        --firmware $FIRMWARE \
        --usb-xhci=on
    log 0 "Done"

    log 0 "Creating disk"
    DISK_FILENAME=$VM_DIRECTORY/$VM_NAME/$VM_NAME.vdi
    vboxmanage createmedium disk \
        --filename "$DISK_FILENAME" \
        --size 40960 \
        --variant Fixed
    log 0 "Done"

    log 0 "Attaching disk"
    vboxmanage storageattach "$VM_NAME" \
        --storagectl SATA \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$DISK_FILENAME" \
        --nonrotational on
    log 0 "Done"

    log 0 "Attaching installation image"
    vboxmanage storageattach "$VM_NAME" \
        --storagectl IDE \
        --port 0 \
        --device 0 \
        --type dvddrive \
        --medium "$INS_DIR/contestant-dev.iso"
    log 0 "Done"

    log 0 "Starting Virtual Machine. Please install contest image using the GUI."
    vboxmanage startvm "$VM_NAME"
    log 0 "Done"

    # Wait for Virtual Machine to shutdown
    log 0 "Waiting for Virtual Machine to shutdown"
    while true; do
        if [ $(vboxmanage showvminfo --machinereadable $VM_NAME \
        | grep -c "VMState=\"running\"") -eq 0 ]; then
            break
        fi
        sleep 1
    done
    log 0 "Done"

    sleep 2

    log 0 "Mounting Shared Folder"
    # Mount shared folder to /media/sf_src
    vboxmanage sharedfolder add "$VM_NAME" \
        --name "src" \
        --hostpath "$TOOLKIT" \
        --readonly \
        --automount
    log 0 "Done"

    sleep 2

    log 0 "Creating snapshot"
    vboxmanage snapshot "$VM_NAME" take "root-install"
    log 0 "Done"

    sleep 2

    log 0 "Loading toolkit to Virtual Machine"
    dev_reload
    log 0 "Done"
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.

help() {
    echo "Usage: $0 {icpc_build|dev_create|dev_reload|generate_actions_secret|clean|help}"
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
        make -C modules/pam clean
        ;;
    icpc_build)
        assert_root
        icpc_build $@
        ;;
    generate_actions_secret)
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

log 0 "Total time elapsed: $(($(date +%s) - $START_TIME)) seconds"
