#!/bin/bash

source /opt/vnoi/config.sh

case "$1" in
	start)
		cat /opt/vnoi/misc/iptables.save | \
			sed -e 's/{AUTH_ADDRESS}/'${AUTH_ADDRESS}'/g' | \
			sed -e 's/{WEBSERVER_PUBLIC_DOMAIN}/'${WEBSERVER_PUBLIC_DOMAIN}'/g' | \
			sed -e 's#{SUBNET}#'${SUBNET}'#g' | tee | /usr/sbin/iptables-restore
		/usr/sbin/ip6tables -P INPUT DROP
		/usr/sbin/ip6tables -P OUTPUT DROP
		logger -p local0.info "FIREWALL: started"
		;;
	stop)
		/usr/sbin/iptables -P INPUT ACCEPT
		/usr/sbin/iptables -P OUTPUT ACCEPT
		/usr/sbin/ip6tables -P INPUT ACCEPT
		/usr/sbin/ip6tables -P OUTPUT ACCEPT
		/usr/sbin/iptables -F
		/usr/sbin/ip6tables -F
		logger -p local0.info "FIREWALL: stopped"
		;;
	*)
		echo Must specify start or stop
		;;
esac

# vim: ft=sh ts=4 noet
