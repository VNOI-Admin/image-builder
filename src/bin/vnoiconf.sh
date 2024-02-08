#!/bin/bash

source /opt/vnoi/config.sh


check_ip()
{
	local IP=$1

	if expr "$IP" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
		return 0
	else
		return 1
	fi
}


do_config()
{

	local CONF=$1  # vpn config filepath
	local CRED=$2  # contestant credential

	if ! test -f "$CONF"; then
		echo "Can't read $CONF"
		exit 1
	fi

	WORKDIR=`mktemp -d`

	tar jxf $CONF -C $WORKDIR
	if [ $? -ne 0 ]; then
		echo "Failed to unpack $CONF"
		rm -rf $WORKDIR
		exit 1
	fi

	IP=$(cat $WORKDIR/vpn/ip.conf)
	MASK=$(cat $WORKDIR/vpn/mask.conf)
	DNS=$(cat $WORKDIR/vpn/dns.conf)

	if ! check_ip "$IP" || ! check_ip "$MASK"; then
		echo Bad IP numbers
		rm -r $WORKDIR
		exit 1
	fi

	echo "$IP" > /etc/tinc/vpn/ip.conf
	echo "$MASK" > /etc/tinc/vpn/mask.conf
	echo "$DNS" > /etc/tinc/vpn/dns.conf
	rm /etc/tinc/vpn/hosts/* 2> /dev/null
	cp $WORKDIR/vpn/hosts/* /etc/tinc/vpn/hosts/
	cp $WORKDIR/vpn/rsa_key.* /etc/tinc/vpn/
	cp $WORKDIR/vpn/tinc.conf /etc/tinc/vpn
	cp $WORKDIR/vpn/vnoibackup* /opt/vnoi/config/ssh/

	rm -r $WORKDIR
	USERID=$(cat /etc/tinc/vpn/tinc.conf | grep Name | cut -d\  -f3)
	chfn -f "$USERID" vnoi

	# Stop Zabbix agent
	systemctl stop zabbix-agent 2> /dev/null
	systemctl disable zabbix-agent 2> /dev/null

	# Restart firewall and VPN
	systemctl enable tinc@vpn 2> /dev/null
	systemctl restart tinc@vpn
	/opt/vnoi/sbin/firewall.sh start

	# Start Zabbix configuration
	systemctl enable zabbix-agent 2> /dev/null
	systemctl start zabbix-agent 2> /dev/null

	# Generate an instance ID to uniquely id this VM
	if [ ! -f /opt/vnoi/run/instanceid.txt ]; then
		openssl rand 10 | base32 > /opt/vnoi/run/instanceid.txt
	fi

	# store credential
	echo "${CRED%|*}" > /opt/vnoi/run/username.txt
	echo "${CRED##*|}" > /opt/vnoi/run/password.txt

	exit 0
}


logger -p local0.info "VNOICONF: invoke $1"

case "$1" in
	set_vpn_server)
		# Get VPN IP at the first argument and replace the AUTH_ADDRESS in config.sh with it
		if [ -z "$2" ]; then
			echo "No VPN server IP specified"
			exit 1
		fi
		if ! check_ip "$2"; then
			echo "Invalid VPN server IP"
			exit 1
		fi
		sed -i "s/AUTH_ADDRESS=.*/AUTH_ADDRESS=\"$2\"/" /opt/vnoi/config.sh
		# Replace vpn.vnoi.info in /etc/hosts with the new IP
		sed -i "s/.*vpn.vnoi.info.*/$2 vpn.vnoi.info/" /etc/hosts
		# Restart firewall and VPN
		/opt/vnoi/sbin/firewall.sh restart
		systemctl restart wg-quick@client
		;;
	fwstart)
		if [ -e /opt/vnoi/run/lockdown ]; then
			echo Not allowed to control firewall during lockdown mode
		else
			/opt/vnoi/sbin/firewall.sh start
		fi
		;;
	fwstop)
		if [ -e /opt/vnoi/run/lockdown ]; then
			echo Not allowed to control firewall during lockdown mode
		else
			/opt/vnoi/sbin/firewall.sh stop
		fi
		;;
	vpnclear)
		if [ -e /opt/vnoi/run/lockdown ]; then
			echo Not allowed to control firewall during lockdown mode
		else
			systemctl stop tinc@vpn
			systemctl disable tinc@vpn 2> /dev/null
			systemctl stop zabbix-agent
			systemctl disable zabbix-agent 2> /dev/null
			/opt/vnoi/sbin/firewall.sh stop
			rm /etc/tinc/vpn/ip.conf 2> /dev/null
			rm /etc/tinc/vpn/mask.conf 2> /dev/null
			rm /etc/tinc/vpn/hosts/* 2> /dev/null
			rm /etc/tinc/vpn/rsa_key.* 2> /dev/null
			rm /etc/tinc/vpn/tinc.conf 2> /dev/null
			rm /opt/vnoi/config/ssh/vnoibackup* 2> /dev/null
			chfn -f "" vnoi
		fi
		;;
	vpnstart)
		systemctl start wg-quick@client
		/opt/vnoi/sbin/firewall.sh start
		;;
	vpnrestart)
		systemctl restart wg-quick@client
		/opt/vnoi/sbin/firewall.sh start
		;;
	vpnstatus)
		systemctl status wg-quick@client
		;;
	settz)
		tz=$2
		if [ -z "$2" ]; then
			cat - <<EOM
No timezone specified. Run tzselect to learn about the valid timezones
available on this system.
EOM
			exit 1
		fi
		if [ -f "/usr/share/zoneinfo/$2" ]; then
			cat - <<EOM
Your timezone will be set to $2 at your next login.
*** Please take note that all dates and times communicated by the VNOI 2023 ***
*** organisers will be in Asia/Jakarta timezone (GMT+07), unless it is     ***
*** otherwise specified.                                                   ***
EOM
			echo "$2" > /opt/vnoi/config/timezone
		else
			cat - <<EOM
Timezone $2 is not valid. Run tzselect to learn about the valid timezones
available on this system.
EOM
			exit 1
		fi
		;;
	setautobackup)
		if [ "$2" = "on" ]; then
			touch /opt/vnoi/config/autobackup
			echo Auto backup enabled
		elif [ "$2" = "off" ]; then
			if [ -f /opt/vnoi/config/autobackup ]; then
				rm /opt/vnoi/config/autobackup
			fi
			echo Auto backup disabled
		else
			cat - <<EOM
Invalid argument to setautobackup. Specify "on" to enable automatic backup
of home directory, or "off" to disable automatic backup. You can always run
"vnoibackup" manually to backup at any time. Backups will only include
non-hidden files less than 1MB in size.
EOM
		fi
		;;
	setscreenlock)
		if [ "$2" = "on" ]; then
			touch /opt/vnoi/config/screenlock
			sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled true
			echo Screensaver lock enabled
		elif [ "$2" = "off" ]; then
			if [ -f /opt/vnoi/config/screenlock ]; then
				rm /opt/vnoi/config/screenlock
			fi
			sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled false
			echo Screensaver lock disabled
		else
			cat - <<EOM
Invalid argument to setscreenlock. Specify "on" to enable screensaver lock,
or "off" to disable screensaver lock.
EOM
		fi
		;;
	*)
		echo Not allowed
		;;
esac

# vim: ft=sh ts=4 sw=4 noet
