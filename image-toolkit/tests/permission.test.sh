#!/bin/bash
source "$(dirname "$0")/common.sh"

USR="icpc"

assert_no_perm() {
    if
        sudo -u "$USR" test -r "$1" ||
        sudo -u "$USR" test -w "$1" ||
        sudo -u "$USR" test -x "$1"
    then
        fail
    else
        pass
    fi
}

assert_full_perm() {
    if
        sudo -u "$USR" test -r "$1" &&
        sudo -u "$USR" test -w "$1" &&
        sudo -u "$USR" test -x "$1"
    then
        pass
    else
        fail
    fi
}

test_case "check permission for /opt/vnoi/bin/"
assert_no_perm "/opt/vnoi/bin/"

test_case "check permission for /opt/vnoi/sbin/"
assert_no_perm "/opt/vnoi/sbin/"

test_case "check permission for /opt/vnoi/misc/"
assert_no_perm "/opt/vnoi/misc/"

test_case "check permission for /opt/vnoi/store/log/"
assert_no_perm "/opt/vnoi/store/log/"

test_case "check permission for /opt/vnoi/store/submissions/"
assert_full_perm "/opt/vnoi/store/submissions/"

test_case "check permission for /etc/sudoers.d/02-icpc"
assert_no_perm "/etc/sudoers.d/02-icpc"

test_case "check permission for /etc/wireguard/client.conf"
assert_no_perm "/etc/wireguard/client.conf"
