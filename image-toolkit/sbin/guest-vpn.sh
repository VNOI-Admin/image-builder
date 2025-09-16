#!/bin/bash
exec &>>/opt/vnoi/store/log/guest-vpn.log
set -e

echo "Waiting for network to be up"
sleep 10

echo "Fetching guest config"
mkdir -p -m 700 /etc/wireguard/
wget -qO- https://vpn.vnoi.info/user/vpn/guest | jq .config -r > /etc/wireguard/client.conf
chmod 600 /etc/wireguard/client.conf

echo "Starting wireguard"
systemctl restart wg-quick@client.service

/opt/vnoi/bin/update-login-banner.sh
