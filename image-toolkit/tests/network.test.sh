#!/bin/bash
source "$(dirname "$0")/common.sh"
source /opt/vnoi/config.sh

test_case "ping 8.8.8.8"
if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
    pass
else
    fail
fi

test_case "check port 80 at $WEBSERVER_PUBLIC_DOMAIN_NAME"
if nc -z -w5 "$WEBSERVER_PUBLIC_DOMAIN_NAME" 80; then
    pass
else
    fail
fi

test_case "ping google.com [disallowed]"
if timeout 3s ping -c 1 google.com > /dev/null 2>&1; then
    fail
else
    pass
fi

test_case "check port 80 at vpn.vnoi.info"
if nc -z -w5 vpn.vnoi.info 80; then
    pass
else
    fail
fi

test_case "check port 443 at vpn.vnoi.info"
if nc -z -w5 vpn.vnoi.info 443; then
    pass
else
    fail
fi

test_case "check port 51820 at vpn.vnoi.info"
if nc -z -w5 -u vpn.vnoi.info 51820; then
    pass
else
    fail
fi

test_case "check port 80 at $CONTEST_SITE_DOMAIN_NAME"
if nc -z -w5 "$CONTEST_SITE_DOMAIN_NAME" 80; then
    pass
else
    fail
fi

test_case "check port 443 at $CONTEST_SITE_DOMAIN_NAME"
if nc -z -w5 "$CONTEST_SITE_DOMAIN_NAME" 443; then
    pass
else
    fail
fi
