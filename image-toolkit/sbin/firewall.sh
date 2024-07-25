#!/bin/bash

set -e

source /opt/vnoi/config.sh

case "$1" in
	start)
		cat /opt/vnoi/misc/iptables.save | \
			sed -e 's#{ADMIN_SUBNET}#'${ADMIN_SUBNET}'#g' | \
			sed -e 's#{COACH_SUBNET}#'${COACH_SUBNET}'#g' | \
			sed -e 's#{WEBSERVER_PUBLIC_DOMAIN_NAME}#'${WEBSERVER_PUBLIC_DOMAIN_NAME}'#g' | \
			/usr/sbin/iptables-restore
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
	restart)
		/usr/sbin/iptables -P INPUT ACCEPT
		/usr/sbin/iptables -P OUTPUT ACCEPT
		/usr/sbin/ip6tables -P INPUT ACCEPT
		/usr/sbin/ip6tables -P OUTPUT ACCEPT
		/usr/sbin/iptables -F
		/usr/sbin/ip6tables -F
		logger -p local0.info "FIREWALL: stopped"

		cat /opt/vnoi/misc/iptables.save | \
			sed -e 's#{ADMIN_SUBNET}#'${ADMIN_SUBNET}'#g' | \
			sed -e 's#{COACH_SUBNET}#'${COACH_SUBNET}'#g' | \
			/usr/sbin/iptables-restore
		/usr/sbin/ip6tables -P INPUT DROP
		/usr/sbin/ip6tables -P OUTPUT DROP
		logger -p local0.info "FIREWALL: started"
		;;
	*)
		echo Must specify start or stop
		;;
esac

# vim: ft=sh ts=4 noet
