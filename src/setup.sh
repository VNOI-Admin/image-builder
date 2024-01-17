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
. ./encrypted_passwd.sh
echo "root:$ENCRYPTED_SUPER_PASSWD" | chpasswd -e

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/ s/"$/ quiet splash"/' /etc/default/grub
sed -i '/\$(echo "\$os" | grub_quote)'\'' \${CLASS}/ s/'\'' \$/'\'' --unrestricted \$/' /etc/grub.d/10_linux
cat - <<EOM >> /etc/grub.d/40_custom
set superusers="root"
password_pbkdf2 root $GRUB_PASSWD
EOM

update-grub2

sed -i '/%sudo/ s/ALL$/NOPASSWD:ALL/' /etc/sudoers

# # Install documentations
# mkdir /tmp/docs-download/
# mkdir -p /opt/vnoi/docs/
# # Regularly built cppreference archive featured on https://en.cppreference.com/w/Cppreference:Archives
# wget -qO /tmp/docs-download/cppref.zip https://github.com/PeterFeicht/cppreference-doc/releases/download/v20230810/html-book-20230810.zip
# unzip -q -d /opt/vnoi/docs/cppreference /tmp/docs-download/cppref.zip
# # Python documentation for 3.10.12
# wget -qO /tmp/docs-download/python310.zip https://docs.python.org/3.10/archives/python-3.10.12-docs-html.zip
# unzip -q -d /opt/vnoi/docs/python310 /tmp/docs-download/python310.zip
# rm -r /tmp/docs-download
# # Allow everyone to access the docs
# chmod a+rx -R /opt/vnoi/docs

# # Create local HTML

# cp -a html /opt/vnoi/html
# mkdir -p /opt/vnoi/html/fonts
# wget -O /tmp/fira-sans.zip "https://gwfh.mranftl.com/api/fonts/fira-sans?download=zip&subsets=latin&variants=regular"
# wget -O /tmp/share.zip "https://gwfh.mranftl.com/api/fonts/share?download=zip&subsets=latin&variants=regular"
# unzip -o /tmp/fira-sans.zip -d /opt/vnoi/html/fonts
# unzip -o /tmp/share.zip -d /opt/vnoi/html/fonts
# rm /tmp/fira-sans.zip
# rm /tmp/share.zip

# Fix CCS shortcut to open VNOJ
sed -i 's#evince /usr/share/doc/icpc/CCS.pdf#gnome-www-browser contest.vnoi.info#' /usr/share/applications/ccs.desktop

# # Tinc Setup and Configuration

systemctl disable multipathd

# Configure GDM to copy VPN config on login
cat - <<'EOM' > /etc/gdm3/PostLogin/Default
#!/bin/sh
rm -rf /etc/wireguard/*
/opt/vnoi/bin/vnoiconf.sh fwstart
EOM

chmod +x /etc/gdm3/PostLogin/Default

# Configure GDM to remove VPN config on logout
cat - <<'EOM' > /etc/gdm3/PostSession/Default
#!/bin/sh
rm -rf /etc/wireguard/*
/opt/vnoi/bin/vnoiconf.sh fwstop
exit 0
EOM

chmod +x /etc/gdm3/PostSession/Default

# Screencast
mkdir -p /opt/vnoi/misc/records/

# After login and X is fully started
# cat - <<'EOM' > /etc/xprofile
# sudo /opt/vnoi/sbin/startup.sh
# EOM

# After login and GUI is fully started
cat - << 'EOM' > /etc/systemd/system/vnoi-startup.service
[Unit]
Description=VNOI startup script
Wants=graphical.target

[Service]
ExecStart=/opt/vnoi/sbin/startup.sh
WantedBy=graphical.target
Type=notify
RemainAfterExit=yes
Restart=on-failure

[Install]
WantedBy=graphical.target
EOM
systemctl start vnoi-startup

# Allow vlc to run as root
sed -i 's/geteuid/getppid/' /usr/bin/vlc

# Allow cvlc, ffmpeg and client to run as root without password
cat - <<'EOM' > /etc/sudoers.d/02-vnoi
vnoi ALL=(root) NOPASSWD: /opt/vnoi/bin/client, /opt/vnoi/sbin/startup.sh
EOM
chmod 440 /etc/sudoers.d/02-vnoi

# Add aliases to .bashrc
cat - <<'EOM' >> /home/vnoi/.bashrc
alias client='sudo /opt/vnoi/bin/client & disown'
EOM

# Disable cloud-init
touch /etc/cloud/cloud-init.disabled

# Update /etc/hosts
echo "${AUTH_ADDRESS} vpn.vnoi.info" >> /etc/hosts
echo "10.1.0.2 contest.vnoi.info" >> /etc/hosts
echo "${WEBSERVER_PUBLIC_ADDRESS} contest2.vnoi.info" >> /etc/hosts
# Time servers
echo 185.125.190.56 ntp.ubuntu.com >> /etc/hosts
echo 168.61.215.74 time.windows.com >> /etc/hosts
echo 132.163.96.3 ntp1.glb.nist.gov >> /etc/hosts

# Disable nouveau by forcing it to fail to load
cat - <<'EOM' > /etc/modprobe.d/blacklist.conf
install nouveau /bin/true
EOM

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
cp /opt/vnoi/misc/authorized_keys /root/.ssh/authorized_keys

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
