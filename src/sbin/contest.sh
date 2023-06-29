#!/bin/sh

# This needs to run as root!

contestprep()
{
	CONTESTID=$1
	# Prepare system for contest. This is run BEFORE start of contest.

	# init 3
	pkill -9 -u vnoi

	UID=$(id -u vnoi)
	EPASSWD=$(grep vnoi /etc/shadow | cut -d: -f2)
	FULLNAME=$(grep ^vnoi: /etc/passwd | cut -d: -f5 | cut -d, -f1)

	# Forces removal of home directory and mail spool
	userdel -rf vnoi > /dev/null 2>&1

	# Remove all other user files in /tmp and /var/tmp
	find /tmp -user $UID -exec rm -rf {} \;
	find /var/tmp -user $UID -exec rm -rf {} \;

	# Recreate submissions directory
	rm -rf /opt/vnoi/store/submissions
	mkdir /opt/vnoi/store/submissions
	chown $UID.$UID /opt/vnoi/store/submissions

	# Remove screenshot data
	rm /opt/vnoi/store/screenshots/*

	/opt/vnoi/sbin/mkvnoiuser.sh

	# Detect cases where the crypt password is invalid, and if so set default passwd
	if [ ${#EPASSWD} -gt 5 ]; then
		echo "vnoi:$EPASSWD" | chpasswd -e
	else
		echo "vnoi:vnoi" | chpasswd
	fi

	chfn -f "$FULLNAME" vnoi

	/opt/vnoi/sbin/firewall.sh start
	USER=$(/opt/vnoi/bin/vnoicheckuser -q)
	echo "$USER" > /opt/vnoi/run/userid.txt
	echo "$CONTESTID" > /opt/vnoi/run/contestid.txt
	echo "$CONTESTID" > /opt/vnoi/run/lockdown

	# init 5
}

schedule()
{
	# Remove existing jobs that were created by this script
	for i in `atq | cut -f1`; do
		if at -c $i | grep -q '# AUTO-CONTEST-SCHEDULE'; then
			atrm $i
		fi
	done

	while IFS=" " read date time cmd
	do
		cat - <<EOM | at $time $date 2> /dev/null
# AUTO-CONTEST-SCHEDULE
$cmd
EOM
		#echo $date, $time, $cmd
	done < /opt/vnoi/misc/schedule
}

monitor()
{
	DATE=$(date +%Y%m%d%H%M%S)
	DISPLAY=:0.0 sudo -u vnoi xhost +local:root > /dev/null
	echo "$DATE monitor run" >> /opt/vnoi/store/contest.log

	# capture screen every minute but with 50% chance
	if [ $(seq 2 | shuf | head -1) -eq 2 ]; then
		USER=$(cat /opt/vnoi/run/userid.txt)
		DISPLAY=:0.0 xwd -root -silent | convert xwd:- png:- | bzip2 -c - \
			> /opt/vnoi/store/screenshots/$USER-$DATE.png.bz2
	fi

	RESOLUTION=$(DISPLAY=:0.0 xdpyinfo | grep dimensions | awk '{print $2}')
	if [ -f /opt/vnoi/run/resolution ]; then
		if [ "$RESOLUTION" != "$(cat /opt/vnoi/run/resolution)" ]; then
			logger -p local0.alert "MONITOR: Display resolution changed to $RESOLUTION"
			echo "$RESOLUTION" > /opt/vnoi/run/resolution
		fi
	else
		echo "$RESOLUTION" > /opt/vnoi/run/resolution
		logger -p local0.info "MONITOR: Display resolution is $RESOLUTION"
	fi

	# Check if auto backups are requested
	if [ -f /opt/vnoi/config/autobackup ]; then
		# This script runs every minute, but we want to only do backups every 5 mins
		if [ $(( $(date +%s) / 60 % 5)) -eq 0 ]; then
			# Insert a random delay up to 30 seconds so backups don't all start at the same time
			sleep $(seq 30 | shuf | head -1)
			/opt/vnoi/bin/vnoibackup.sh > /dev/null &
		fi
	fi
}

lock()
{
	passwd -l vnoi
	cat - <<EOM > /etc/gdm3/greeter.dconf-defaults
[org/gnome/login-screen]
banner-message-enable=true
banner-message-text='The contest is about to start.\nYour computer is temporarily locked.\nYou are not allowed to log in yet.\nPlease wait for further instructions.'
EOM
	systemctl restart gdm3
}

unlock()
{
	passwd -u vnoi
	cat - <<EOM > /etc/gdm3/greeter.dconf-defaults
[org/gnome/login-screen]
banner-message-enable=false
EOM
	systemctl restart gdm3
}


logger -p local0.info "CONTEST: execute '$@'"

case "$1" in
	lock)
		lock
		;;
	unlock)
		unlock
		;;
	prep)
		contestprep $2
		unlock
		;;
	start)
		logkeys --start --keymap /opt/vnoi/misc/en_US_ubuntu_1204.map
		echo "* * * * * root /opt/vnoi/sbin/contest.sh monitor" > /etc/cron.d/contest
		;;
	stop)
		logkeys --kill
		rm /etc/cron.d/contest
		;;
	done)
		/opt/vnoi/sbin/firewall.sh stop
		rm /opt/vnoi/run/lockdown
		rm /opt/vnoi/run/contestid.txt
		rm /opt/vnoi/run/userid.txt
		;;
	schedule)
		schedule
		;;
	monitor)
		monitor
		;;
	*)
		;;
esac

# vim: ft=sh ts=4 noet
