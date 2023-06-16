#!/bin/bash

source /opt/vnoi/config.sh

case "$1" in
	start)
		cat /opt/vnoi/misc/iptables.save | \
			sed -e 's/{POP_SERVER}/'${POP_SERVER}'/g' | \
			sed -e 's/{BACKUP_SERVER}/'${BACKUP_SERVER}'/g' | \
			sed -e 's/{CMS_PUBLIC_DOMAIN}/'${CMS_PUBLIC_DOMAIN}'/g' | \
			sed -e 's#{SUBNET}#'${SUBNET}'#g' | tee|iptables-restore
		iptables -A INPUT -p tcp --dport 88 -j ACCEPT
		ufw allow out to code.visualstudio.com
		ufw allow out to marketplace.visualstudio.com
		logger -p local0.info "FIREWALL: started"
		;;
	stop)
		iptables -P INPUT ACCEPT
		iptables -P OUTPUT ACCEPT
		iptables -F
		logger -p local0.info "FIREWALL: stopped"
		;;
	*)
		echo Must specify start or stop
		;;
esac

# vim: ft=sh ts=4 noet
