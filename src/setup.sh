#!/bin/bash

echo "Starting setup.sh"

echo "Change directory to the script's directory"
cd "$(dirname "$0")"

echo "Load config.sh"
. ./config.sh

error() {
	local lineno="$1"
	local message="$2"
	local code="${3:-1}"
	if [[ -n "$message" ]] ; then
		echo "Error at or near line ${lineno}: ${message}; exiting with status ${code}"
	else
		echo "Error at or near line ${lineno}; exiting with status ${code}"
	fi
	exit "${code}"
}
trap 'error ${LINENO}' ERR

VERSION="test$(date +%m%d)"

if [ -f "config.local.sh" ]; then
	echo "Load config.local.sh"
	. ./config.local.sh
fi

# Remove tmp_user from preseed

# Check if user exists, if yes, delete it
if id "tmp_user" >/dev/null 2>&1; then
	echo "Delete temporary user"
	userdel -rf tmp_user
fi

# Fix up date/time

echo "Fix up date/time"
timedatectl set-timezone Asia/Jakarta
# vmware-toolbox-cmd timesync enable
hwclock -w

# Update packages

echo "Update packages"
apt-get -y update
apt-get -y upgrade

# Convert server install into a minimuam desktop install

# NOTE: This is unnecessary if we use the Ubuntu Desktop ISO
# apt install -y ubuntu-desktop-minimal

# Install tools needed for management and monitoring

# echo "Install tools needed for management and monitoring"
# apt -y install net-tools openssh-server xvfb tinc oathtool imagemagick \
# 	aria2

# Install local build tools

# echo "Install local build tools"
# apt -y install build-essential autoconf autotools-dev

# Install packages needed by contestants

# echo "Install packages needed by contestants"
# apt -y install openjdk-11-jdk-headless codeblocks-contrib emacs \
# 	geany gedit joe kate kdevelop nano vim vim-gtk3 \
# 	ddd valgrind visualvm ruby python3-pip konsole

# Install snap packages needed by contestants

# echo "Install snap packages needed by contestants"
# snap install --classic atom
# snap install --classic sublime-text
# snap install --classic eclipse

# Install python3 libraries

echo "Install python3 libraries"
pip3 install matplotlib

# Change default shell for useradd
sed -i '/^SHELL/ s/\/sh$/\/bash/' /etc/default/useradd

# Copy VNOI stuffs into /opt

echo "Copy VNOI stuffs into /opt"
mkdir -p /opt/vnoi
cp -a bin sbin misc /opt/vnoi/

# Limit access and execution to root and its group
chmod 770 -R /opt/vnoi/bin/
chmod 770 -R /opt/vnoi/sbin/
chmod 770 -R /opt/vnoi/misc/

cp config.sh /opt/vnoi/

mkdir -p /opt/vnoi/run
mkdir -p /opt/vnoi/store
mkdir -p /opt/vnoi/config
mkdir -p /opt/vnoi/store/log
mkdir -p /opt/vnoi/store/screenshots
mkdir -p /opt/vnoi/store/submissions
mkdir -p /opt/vnoi/config/ssh

# Add default timezone
echo "Asia/Bangkok" > /opt/vnoi/config/timezone

# Default to enable screensaver lock
touch /opt/vnoi/config/screenlock

# Create vnoi account
echo "Create vnoi account"
/opt/vnoi/sbin/mkvnoiuser.sh

# Set VNOI user's initial password
echo "vnoi:vnoi" | chpasswd

# Fix permission and ownership
chown vnoi.vnoi /opt/vnoi/store/submissions
chmod 770 /opt/vnoi/store/log

# Add our own syslog facility

echo "local0.* /opt/vnoi/store/log/local.log" >> /etc/rsyslog.d/10-vnoi.conf

# Add custom NTP to timesyncd config

cat - <<EOM > /etc/systemd/timesyncd.conf
[Time]
NTP=time.windows.com time.nist.gov
EOM

# GRUB config: quiet, and password for edit

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/ s/"$/ quiet splash maxcpus=2 mem=6144M"/' /etc/default/grub
# GRUB_PASSWD=$(echo -e "$SUPER_PASSWD\n$SUPER_PASSWD" | grub-mkpasswd-pbkdf2 | awk '/hash of / {print $NF}')

sed -i '/\$(echo "\$os" | grub_quote)'\'' \${CLASS}/ s/'\'' \$/'\'' --unrestricted \$/' /etc/grub.d/10_linux
# cat - <<EOM >> /etc/grub.d/40_custom
# set superusers="root"
# password_pbkdf2 root $GRUB_PASSWD
# EOM

update-grub2

sed -i '/%sudo/ s/ALL$/NOPASSWD:ALL/' /etc/sudoers
echo "vnoi ALL=NOPASSWD: /opt/vnoi/bin/vnoiconf.sh, /opt/vnoi/bin/vnoiexec.sh, /opt/vnoi/bin/vnoibackup.sh" >> /etc/sudoers.d/01-vnoi
chmod 440 /etc/sudoers.d/01-vnoi

# Documentation
apt -y install stl-manual python3-doc

# Install documentations
mkdir /tmp/docs-download/
mkdir -p /opt/vnoi/docs/
# Regularly built cppreference archive featured on https://en.cppreference.com/w/Cppreference:Archives
wget -qO /tmp/docs-download/cppref.zip https://github.com/PeterFeicht/cppreference-doc/releases/download/v20230810/html-book-20230810.zip
unzip -q -d /opt/vnoi/docs/cppreference /tmp/docs-download/cppref.zip
# Python documentation for 3.10.12
wget -qO /tmp/docs-download/python310.zip https://docs.python.org/3.10/archives/python-3.10.12-docs-html.zip
unzip -q -d /opt/vnoi/docs/python310 /tmp/docs-download/python310.zip
rm -r /tmp/docs-download
# Allow everyone to access the docs
chmod a+rx -R /opt/vnoi/docs

# Build logkeys

# WORKDIR=`mktemp -d`
# pushd $WORKDIR
# git clone https://github.com/kernc/logkeys.git
# cd logkeys
# ./autogen.sh
# cd build
# ../configure
# make
# make install
# cp ../keymaps/en_US_ubuntu_1204.map /opt/vnoi/misc/
# popd
# rm -rf $WORKDIR

# Mark some packages as needed so they wont' get auto-removed

# apt -y install `dpkg-query -Wf '${Package}\n' | grep linux-image-`
# apt -y install `dpkg-query -Wf '${Package}\n' | grep linux-modules-`

# # Remove unneeded packages

# apt -y remove gnome-power-manager brltty extra-cmake-modules
# apt -y remove zlib1g-dev libobjc-9-dev libx11-dev dpkg-dev manpages-dev
# apt -y remove linux-firmware
# apt -y remove network-manager-openvpn network-manager-openvpn-gnome openvpn
# # apt -y remove gnome-getting-started-docs-it gnome-getting-started-docs-ru \
# # 	gnome-getting-started-docs-es gnome-getting-started-docs-fr gnome-getting-started-docs-de
# apt -y remove build-essential autoconf autotools-dev
# apt -y remove `dpkg-query -Wf '${Package}\n' | grep linux-header`

# # Remove most extra modules but preserve those for sound
# # kernelver=$(uname -a | cut -d\  -f 3)
# # tar jcf /tmp/sound-modules.tar.bz2 -C / \
# # 	lib/modules/$kernelver/kernel/sound/{ac97_bus.ko,pci} \
# # 	lib/modules/$kernelver/kernel/drivers/gpu/drm/vmwgfx
# apt -y remove `dpkg-query -Wf '${Package}\n' | grep linux-modules-extra-`
# # tar jxf /tmp/sound-modules.tar.bz2 -C /
# # depmod -a

# Create local HTML

cp -a html /opt/vnoi/html
mkdir -p /opt/vnoi/html/fonts
wget -O /tmp/fira-sans.zip "https://gwfh.mranftl.com/api/fonts/fira-sans?download=zip&subsets=latin&variants=regular"
wget -O /tmp/share.zip "https://gwfh.mranftl.com/api/fonts/share?download=zip&subsets=latin&variants=regular"
unzip -o /tmp/fira-sans.zip -d /opt/vnoi/html/fonts
unzip -o /tmp/share.zip -d /opt/vnoi/html/fonts
rm /tmp/fira-sans.zip
rm /tmp/share.zip

# # Tinc Setup and Configuration

# # Setup tinc skeleton config

# mkdir -p /etc/tinc/vpn
# mkdir -p /etc/tinc/vpn/hosts
# cat - <<'EOM' > /etc/tinc/vpn/tinc-up
# #!/bin/bash

# source /opt/vnoi/config.sh
# ifconfig $INTERFACE "$(cat /etc/tinc/vpn/ip.conf)" netmask "$(cat /etc/tinc/vpn/mask.conf)"
# route add -net $SUBNET gw "$(cat /etc/tinc/vpn/ip.conf)"
# EOM
# chmod 755 /etc/tinc/vpn/tinc-up
# cp /etc/tinc/vpn/tinc-up /opt/vnoi/misc/

# cat - <<'EOM' > /etc/tinc/vpn/host-up
# #!/bin/bash

# source /opt/vnoi/config.sh
# logger -p local0.info TINC: VPN connection to $NODE $REMOTEADDRESS:$REMOTEPORT is up

# # Force time resync as soon as VPN starts
# systemctl restart systemd-timesyncd

# # Fix up DNS resolution
# resolvectl dns $INTERFACE $(cat /etc/tinc/vpn/dns.conf)
# resolvectl domain $INTERFACE $DNS_DOMAIN
# systemd-resolve --flush-cache

# # Register something on our HTTP server to log connection
# INSTANCEID=$(cat /opt/vnoi/run/instanceid.txt)
# EOM
# chmod 755 /etc/tinc/vpn/host-up
# cp /etc/tinc/vpn/host-up /opt/vnoi/misc/

# cat - <<'EOM' > /etc/tinc/vpn/host-down
# #!/bin/bash

# logger -p local0.info TINC: VPN connection to $NODE $REMOTEADDRESS:$REMOTEPORT is down
# EOM
# chmod 755 /etc/tinc/vpn/host-down

# # Configure systemd for tinc
# systemctl enable tinc@vpn

systemctl disable multipathd

# Configure GDM to remove VPN config on login
cat - <<'EOM' > /etc/gdm3/PostLogin/Default
#!/bin/sh

rm -rf /etc/tinc/vpn/*
/opt/vnoi/bin/vnoiconf.sh fwstart
EOM

chmod +x /etc/gdm3/PostLogin/Default

# Configure GDM to remove VPN config on logout
cat - <<'EOM' > /etc/gdm3/PostSession/Default
#!/bin/sh

systemctl stop tinc@vpn
rm -rf /etc/tinc/vpn/*

/opt/vnoi/bin/vnoiconf.sh fwstop

exit 0
EOM

chmod +x /etc/gdm3/PostSession/Default

# Configure VPN directory
mkdir -p /etc/tinc/vpn
chmod 744 /etc/tinc/vpn

# Screencast after login and X is fully started
mkdir -p /opt/vnoi/misc/records/
cat - <<'EOM' > /etc/xprofile
sudo cvlc -q screen:// --screen-fps=20 --sout "#transcode{venc=x264{keyint=15},vcodec=h264,vb=0}:http{mux=ts,dst=:9090/}" >/dev/null 2>&1 &
sudo ffmpeg -i http://127.0.0.1:9090 -c copy -map 0 -f segment -reset_timestamps 1 -strftime 1 -segment_time 300 -segment_format mp4 "/opt/vnoi/misc/records/out-%H-%M-%S.mp4" >/dev/null 2>&1 &
sudo /opt/vnoi/bin/client & disown
EOM

# Allow vlc to run as root
sed -i 's/geteuid/getppid/' /usr/bin/vlc

# Allow cvlc, ffmpeg and client to run as root without password
cat - <<'EOM' > /etc/sudoers.d/02-vnoi
vnoi ALL=(ALL) ALL
vnoi ALL=(root) NOPASSWD: /usr/bin/cvlc, /usr/bin/ffmpeg, /opt/vnoi/bin/client
EOM

# Disable cloud-init
touch /etc/cloud/cloud-init.disabled

# Don't stsart atd service
systemctl disable atd

# Replace atd.service file
cat - <<EOM > /lib/systemd/system/atd.service
[Unit]
Description=Deferred execution scheduler
Documentation=man:atd(8)
After=remote-fs.target nss-user-lookup.target

[Service]
ExecStartPre=-find /var/spool/cron/atjobs -type f -name "=*" -not -newercc /run/systemd -delete
ExecStart=/usr/sbin/atd -f -l 5 -b 30
IgnoreSIGPIPE=false
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOM

chmod 644 /lib/systemd/system/atd.service

# Disable virtual consoles

cat - <<EOM >> /etc/systemd/logind.conf
NAutoVTs=0
ReserveVT=0
EOM

# Disable updates

cat - <<EOM > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOM

# Remove/clean up unneeded snaps

snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
	snap remove "$snapname" --revision="$revision"
done

rm -rf /var/lib/snapd/cache/*

# Clean up apt

apt -y autoremove

apt clean

# Remove desktop backgrounds
rm -rf /usr/share/backgrounds/*.jpg
rm -rf /usr/share/backgrounds/*.png

# Remove unwanted documentation
rm -rf /usr/share/doc/HTML
rm -rf /usr/share/doc/adwaita-icon-theme
rm -rf /usr/share/doc/alsa-base
rm -rf /usr/share/doc/cloud-init
rm -rf /usr/share/doc/cryptsetup
rm -rf /usr/share/doc/fonts-*
rm -rf /usr/share/doc/info
rm -rf /usr/share/doc/libgphoto2-6
rm -rf /usr/share/doc/libgtk*
rm -rf /usr/share/doc/libqt5*
rm -rf /usr/share/doc/libqtbase5*
rm -rf /usr/share/doc/man-db
rm -rf /usr/share/doc/manpages
rm -rf /usr/share/doc/openjdk-*
rm -rf /usr/share/doc/openssh-*
rm -rf /usr/share/doc/ppp
rm -rf /usr/share/doc/printer-*
rm -rf /usr/share/doc/qml-*
rm -rf /usr/share/doc/systemd
rm -rf /usr/share/doc/tinc
rm -rf /usr/share/doc/ubuntu-*
rm -rf /usr/share/doc/util-linux
rm -rf /usr/share/doc/wpasupplicant
rm -rf /usr/share/doc/x11*
rm -rf /usr/share/doc/xorg*
rm -rf /usr/share/doc/xproto
rm -rf /usr/share/doc/xserver*
rm -rf /usr/share/doc/xterm

# Create rc.local file
cp misc/rc.local /etc/rc.local
chmod 755 /etc/rc.local

# Copy public key to root
cp /opt/vnoi/misc/vnoi_cup.pub /root/.ssh/authorized_keys

# Set flag to run atrun.sh at first boot
touch /opt/vnoi/misc/schedule2.txt.firstrun

# Embed version number
if [ -n "$VERSION" ] ; then
	echo "$VERSION" > /opt/vnoi/misc/VERSION
fi

# Deny vnoi user from SSH login
echo "DenyUsers vnoi" >> /etc/ssh/sshd_config

echo "### DONE ###"
echo "- Remember to run cleanup script."

# vim: ts=4
