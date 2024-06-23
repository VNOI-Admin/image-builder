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

check_audio_device() {
	if [[ "$1" = "any" ]] || [[ "$1" = "system" ]]; then
		return 0
	fi

	local AUDIO_DEVICE_INFO
	mapfile -t AUDIO_DEVICE_INFO < <(find /proc/asound/ -regex ".*card[0-9]+/pcm[0-9]+c/info")
	for info_file in "${AUDIO_DEVICE_INFO[@]}"; do
		local NAME=$(sed -n "s/^name: //p" "$info_file")

		if [[ "$NAME" = "$1" ]]; then
			return 0
		fi
	done

	return 1
}

logger -p local0.info "VNOICONF: invoke $1"

case "$1" in
	set_vpn_server)
		# Get VPN IP at the first argument and replace the VPN_CORE_ADDRESS in config.sh with it
		if [ -z "$2" ]; then
			echo "No VPN server IP specified"
			exit 1
		fi
		if ! check_ip "$2"; then
			echo "Invalid VPN server IP"
			exit 1
		fi
		sed -i "s/VPN_CORE_ADDRESS=.*/VPN_CORE_ADDRESS=\"$2\"/" /opt/vnoi/config.sh
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
			systemctl stop wg-quick@client
			/opt/vnoi/sbin/firewall.sh stop
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
# 	setscreenlock)
# 		if [ "$2" = "on" ]; then
# 			touch /opt/vnoi/config/screenlock
# 			sudo -Hu icpc xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled true
# 			echo Screensaver lock enabled
# 		elif [ "$2" = "off" ]; then
# 			if [ -f /opt/vnoi/config/screenlock ]; then
# 				rm /opt/vnoi/config/screenlock
# 			fi
# 			sudo -Hu icpc xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled false
# 			echo Screensaver lock disabled
# 		else
# 			cat - <<EOM
# Invalid argument to setscreenlock. Specify "on" to enable screensaver lock,
# or "off" to disable screensaver lock.
# EOM
# 		fi
# 		;;
	set_audio_device)
		# Get device name at the first argument and replace the AUDIO_DEVICE_NAME in config.sh with it
		if [ -z "$2" ]; then
			echo "No device name specified"
			exit 1
		fi
		if ! check_audio_device "$2"; then
			echo "Warning: No audio devices match the name $2"
		fi
		sed -i "s/AUDIO_DEVICE_NAME=.*/AUDIO_DEVICE_NAME=\"$2\"/" /opt/vnoi/config.sh
		# Restart stream
		if [[ -f "/run/icpc-webcam-stream.pid" ]]; then
			kill -9 $(cat /run/icpc-webcam-stream.pid) 2> /dev/null
		fi
		;;
	list_audio_devices)
		mapfile -t AUDIO_DEVICE_INFO < <(find /proc/asound/ -regex ".*card[0-9]+/pcm[0-9]+c/info")
		for info_file in "${AUDIO_DEVICE_INFO[@]}"; do
			CARD_NO=$(sed -n "s/^card: //p" "$info_file")
			DEVICE_NO=$(sed -n "s/^device: //p" "$info_file")
			NAME=$(sed -n "s/^name: //p" "$info_file")

			echo "$CARD_NO,$DEVICE_NO: $NAME"
		done
		;;
	*)
		echo Not allowed
		;;
esac

# vim: ft=sh ts=4 sw=4 noet
