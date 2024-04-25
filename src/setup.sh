#!/bin/bash

set -e

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

# Create ICPC account
echo "Create icpc account"
/opt/vnoi/sbin/mkuser.sh

# Set ICPC user's initial password
echo "icpc:icpc" | chpasswd

# Fix permission and ownership
chown icpc.icpc /opt/vnoi/store/submissions
chmod 770 /opt/vnoi/store/log

# Add our own syslog facility

echo "local0.* /opt/vnoi/store/log/local.log" >> /etc/rsyslog.d/10-vnoi.conf

# Add custom NTP to timesyncd config

cat - <<EOM > /etc/systemd/timesyncd.conf
[Time]
NTP=ntp.ubuntu.com time.windows.com
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

# Configure startup script, hidden from vnoi user access
mkdir -p /home/icpc/.config/autostart

cat - <<'EOM' > /home/icpc/.config/autostart/icpc.desktop
[Desktop Entry]
Type=Application
Exec=sudo /opt/vnoi/sbin/startup.sh
NoDisplay=true
X-GNOME-Autostart-enabled=true
Name[en_US]=icpc
Name=icpc
Comment[en_US]=
Comment=
EOM

chown root:root /home/icpc/.config/autostart/icpc.desktop
# only allow execution
chmod 744 /home/icpc/.config/autostart/icpc.desktop

# Create cronjob to run `python3 /opt/vnoi/sbin/report.py` every 15 seconds
cat - <<'EOM' > /etc/cron.d/icpc
* * * * * /opt/vnoi/sbin/report.py
* * * * * sleep 10; /opt/vnoi/sbin/report.py
* * * * * sleep 20; /opt/vnoi/sbin/report.py
* * * * * sleep 30; /opt/vnoi/sbin/report.py
* * * * * sleep 40; /opt/vnoi/sbin/report.py
* * * * * sleep 50; /opt/vnoi/sbin/report.py
EOM

crontab /etc/cron.d/icpc
rm /etc/cron.d/icpc

# Allow vlc to run as root
sed -i 's/geteuid/getppid/' /usr/bin/vlc

# Allow cvlc, ffmpeg and client to run as root without password
cat - <<'EOM' > /etc/sudoers.d/02-icpc
icpc ALL=(root) NOPASSWD: /opt/vnoi/bin/client, /opt/vnoi/sbin/startup.sh
EOM
chmod 440 /etc/sudoers.d/02-icpc

# Add aliases to .bashrc
cat - <<'EOM' >> /home/icpc/.bashrc
alias client='sudo /opt/vnoi/bin/client & disown'
EOM

# Setup nginx and hls config
cp -f /opt/vnoi/misc/nginx.conf /etc/nginx/nginx.conf
cp -f /opt/vnoi/misc/hls.conf /etc/nginx/sites-available/hls.conf
ln -s /etc/nginx/sites-available/hls.conf /etc/nginx/sites-enabled/hls.conf
rm -f /etc/nginx/sites-enabled/default
mkdir -p /var/www/html/stream
systemctl enable --now nginx

# Disable cloud-init
touch /etc/cloud/cloud-init.disabled

# Update /etc/hosts
echo "${VPN_CORE_ADDRESS} ${VPN_CORE_DOMAIN_NAME}" >> /etc/hosts
echo "${CONTEST_SITE_ADDRESS} ${CONTEST_SITE_DOMAIN_NAME}" >> /etc/hosts
echo "${WEBSERVER_PUBLIC_ADDRESS} ${WEBSERVER_PUBLIC_DOMAIN_NAME}" >> /etc/hosts
# Time servers
echo 185.125.190.56 ntp.ubuntu.com >> /etc/hosts
echo 168.61.215.74 time.windows.com >> /etc/hosts

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

# Deny icpc user from SSH login
echo "DenyUsers icpc" >> /etc/ssh/sshd_config

echo "### DONE ###"
echo "- Remember to run cleanup script."

# vim: ts=4
