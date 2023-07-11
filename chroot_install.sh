pwd

if [ -f /root/local_config.sh ]; then
    source /root/local_config.sh
else
    echo "local_config.sh not found, running config.sh"
    source /root/config.sh
fi

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export LC_ALL=C

echo "live-build" > /etc/hostname

echo "Set mirror to $MIRROR"

cat <<EOF > /etc/apt/sources.list
deb $MIRROR focal main restricted universe multiverse
deb-src $MIRROR focal main restricted universe multiverse

deb $MIRROR focal-security main restricted universe multiverse
deb-src $MIRROR focal-security main restricted universe multiverse

deb $MIRROR focal-updates main restricted universe multiverse
deb-src $MIRROR focal-updates main restricted universe multiverse
EOF

apt-get update
apt-get install -y libterm-readline-gnu-perl systemd-sysv

dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id

dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

apt-get -y upgrade

apt-get install -y \
    sudo \
    ubuntu-standard \
    casper \
    lupin-casper \
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
    gpg

apt-get install -y --no-install-recommends linux-generic

apt-get install -y \
    ubiquity \
    ubiquity-casper \
    ubiquity-frontend-gtk \
    ubiquity-slideshow-ubuntu \
    ubiquity-ubuntu-artwork

apt-get install -y \
    plymouth-theme-ubuntu-logo \
    ubuntu-desktop-minimal \
    ubuntu-gnome-wallpapers

apt-get install -y \
    clamav-daemon \
    terminator \
    apt-transport-https \
    curl \
    vim \
    nano \
    less

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list
rm microsoft.gpg


apt-get update
apt-get install -y code

# Remove unnecessary packages
apt-get purge -y \
    transmission-gtk \
    transmission-common \
    gnome-mahjongg \
    gnome-mines \
    gnome-sudoku \
    aisleriot \
    hitori

# Install tools needed for management and monitoring
echo "Install tools needed for management and monitoring"
apt-get -y install net-tools openssh-server xvfb tinc oathtool imagemagick \
    aria2 iputils-ping vlc vlc-plugin-access-extra

# Install local build tools
echo "Install local build tools"
apt-get -y install build-essential autoconf autotools-dev

# Install important packages for network drivers
apt-get -y install linux-headers-generic dkms rtl8812au-dkms rtl8821ce-dkms r8168-dkms

# Install packages needed by contestants
echo "Install packages needed by contestants"
apt-get -y install openjdk-11-jdk-headless codeblocks-contrib emacs \
	geany gedit joe kate kdevelop nano vim vim-gtk3 \
	ddd valgrind visualvm ruby python3-pip konsole

# Install Sublime Text
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
apt-get update
apt-get install sublime-text

# Documentation
apt-get -y install stl-manual python3-doc

# CPP Reference
wget -O /tmp/html_book_20190607.zip http://upload.cppreference.com/mwiki/images/b/b2/html_book_20190607.zip
mkdir -p /opt/cppref
unzip -o /tmp/html_book_20190607.zip -d /opt/cppref
rm -f /tmp/html_book_20190607.zip

# Mark some packages as needed so they wont' get auto-removed

apt-get -y install `dpkg-query -Wf '${Package}\n' | grep linux-image-`
apt-get -y install `dpkg-query -Wf '${Package}\n' | grep linux-modules-`

# Remove unneeded packages

apt-get -y remove gnome-power-manager brltty extra-cmake-modules
apt-get -y remove zlib1g-dev libobjc-9-dev libx11-dev dpkg-dev manpages-dev
# apt-get -y remove linux-firmware
apt-get -y remove network-manager-openvpn network-manager-openvpn-gnome openvpn
# apt -y remove gnome-getting-started-docs-it gnome-getting-started-docs-ru \
# 	gnome-getting-started-docs-es gnome-getting-started-docs-fr gnome-getting-started-docs-de
# apt-get -y remove build-essential autoconf autotools-dev
# apt-get -y remove `dpkg-query -Wf '${Package}\n' | grep linux-header`

# Remove most extra modules but preserve those for sound
# kernelver=$(uname -a | cut -d\  -f 3)
# tar jcf /tmp/sound-modules.tar.bz2 -C / \
# 	lib/modules/$kernelver/kernel/sound/{ac97_bus.ko,pci} \
# 	lib/modules/$kernelver/kernel/drivers/gpu/drm/vmwgfx
# apt-get -y remove `dpkg-query -Wf '${Package}\n' | grep linux-modules-extra-`
# tar jxf /tmp/sound-modules.tar.bz2 -C /
# depmod -a

# Create local HTML
cp -a html /opt/vnoi/html
mkdir -p /opt/vnoi/html/fonts
wget -O /tmp/fira-sans.zip "https://gwfh.mranftl.com/api/fonts/fira-sans?download=zip&subsets=latin&variants=regular"
wget -O /tmp/share.zip "https://gwfh.mranftl.com/api/fonts/share?download=zip&subsets=latin&variants=regular"
unzip -o /tmp/fira-sans.zip -d /opt/vnoi/html/fonts
unzip -o /tmp/share.zip -d /opt/vnoi/html/fonts
rm /tmp/fira-sans.zip
rm /tmp/share.zip

# apt-get autoremove -y

# Reconfigure locales
dpkg-reconfigure locales

# Reconfigure resolvconf
dpkg-reconfigure resolvconf

# Reconfigure network-manager
cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq

[ifupdown]
managed=false
EOF

mkdir -p /root/.ssh/
mv /root/authorized_keys /root/.ssh/
chmod 400 /root/.ssh/authorized_keys

dpkg-reconfigure network-manager

# Clean up the chroot environment
truncate -s 0 /etc/machine-id

rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

apt-get clean
rm -rf /tmp/* ~/.bash_history
umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0

exit
