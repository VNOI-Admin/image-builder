set -e
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

    echo "Unmounting /proc and /sys from chroot"
    umount -l /proc
    umount -l /sys
    umount -l /dev/pts
    echo "Done"

	exit "${code}"
}

trap 'error ${LINENO}' ERR

pwd

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export LC_ALL=C

# https://askubuntu.com/a/469213
# rm /etc/resolv.conf
# echo 'nameserver 8.8.4.4' >> /etc/resolv.conf

# Update apt sources
apt-get update
# apt-get -y upgrade

# Install packages
apt-get install -y \
    sudo \
    ubuntu-standard \
    casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    resolvconf \
    net-tools \
    wireless-tools \
    wpagui \
    locales \
    grub-common \
    grub-gfxpayload-lists \
    grub-pc \
    grub-pc-bin \
    grub2-common \
    gpg \
    vlc \
    vlc-plugin-access-extra \
    ffmpeg \
    python3-tk \
    p7zip-full \
    wireguard-tools \
    wireguard \
    python3-psutil \
    nginx \
    libnginx-mod-rtmp

# Install Chrome to avoid using Firefox snap. Firefox snap can't read stuffs not in ~/
mkdir /tmp/chrome-download/
wget -qO /tmp/chrome-download/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i /tmp/chrome-download/chrome.deb
rm -r /tmp/chrome-download

# Install virtualbox ose if creating development environment
if [ "$PROD_DEV" = "dev" ]; then
    apt-get -y install virtualbox-guest-x11
fi

# Reconfigure network-manager
cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq

[ifupdown]
managed=false
EOF

# Ubiquity installer patch
# https://answers.launchpad.net/ubuntu/+source/ubiquity/+question/353445

sed -i -e '/apt-get -o APT::Get::List-Cleanup=false \\/d' \
       -e '/-o Dir::Etc::sourcelist="$file" update --print-uris | \\/d' \
       -e '/grep "^'\''.*'\''")/d' \
       -e 's|lines="\$($chroot \$ROOT \\|lines="\$($chroot \$ROOT apt-get clean)"|' \
       -e '$a\' \
       /usr/lib/ubiquity/apt-setup/apt-setup-signed-release

sed -i -e 's|-o APT::Get::List-Cleanup=false|clean=false|' /usr/lib/ubiquity/apt-setup/apt-setup-verify

# Disable setup

# Create file /etc/modprobe.d/network.conf for enabling drivers for network cards from realtek
cat <<EOF > /etc/modprobe.d/network.conf
install r8169 /sbin/modprobe --ignore-install r8169
install rtw88 /sbin/modprobe --ignore-install rtw88
EOF

dpkg-reconfigure network-manager

# Set up root password for pre-setup login
. /root/src/encrypted_passwd.sh
echo "root:$ENCRYPTED_SUPER_PASSWD" | chpasswd -e

# Clean up the chroot environment
truncate -s 0 /etc/machine-id

apt-get autoremove --purge -y

rm -f /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

rm -rf /tmp/* ~/.bash_history
umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0

exit
