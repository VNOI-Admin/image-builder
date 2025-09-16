#!/bin/bash
exec &>>/opt/vnoi/store/log/update-login-banner.log
set -euo pipefail

echo 'Updating login banner...'

# Get WireGuard client IP
CLIENT_IP=$(ip -4 addr show dev client 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

# Get gnome-session PID for gdm (if running)
GNOME_SESSION_PID=$(pgrep gnome-session -U gdm -n || true)

# Get gdm UID
GDM_UID=$(id -u gdm)

if [[ -n "$GNOME_SESSION_PID" ]]; then
    echo "Found gnome-session PID=$GNOME_SESSION_PID"

    # Extract DBus session address from the environment of gnome-session
    DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/$GNOME_SESSION_PID/environ \
        | grep --color=never '^DBUS_SESSION_BUS_ADDRESS=' \
        | cut -d= -f2-)

    echo "Using existing DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"

    sudo -u gdm env \
        XDG_RUNTIME_DIR=/run/user/$GDM_UID \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
        gsettings set org.gnome.login-screen banner-message-text "$CLIENT_IP"
else
    echo "No gnome-session found for gdm, falling back to dbus-run-session"

    sudo -u gdm env \
        dbus-run-session \
        gsettings set org.gnome.login-screen banner-message-text "$CLIENT_IP"
fi
