#!/bin/sh

set -e

echo "MKVNOIUSER: Create a new icpc user"

# Create vnoi account
useradd -m icpc

# Setup desktop background
# sudo -Hu icpc xvfb-run gsettings set org.gnome.desktop.session idle-delay 900
# sudo -Hu icpc xvfb-run gsettings set org.gnome.desktop.screensaver lock-delay 30
# if [ -f /opt/vnoi/config/screenlock ]; then
# 	sudo -Hu icpc xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled true
# else
# 	sudo -Hu icpc xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled false
# fi

# set default fullname
chfn -f "icpc" icpc

# Update path
echo 'TZ=$(cat /opt/vnoi/config/timezone)' >> ~icpc/.profile
echo 'export TZ' >> ~icpc/.profile

# Mark Gnome's initial setup as complete
sudo -Hu icpc bash -c 'echo yes > ~/.config/gnome-initial-setup-done'

# Copy VSCode extensions
# TODO: Check this out
# mkdir -p ~icpc/.vscode/extensions
# tar jxf /opt/vnoi/misc/vscode-extensions.tar.bz2 -C ~icpc/.vscode/extensions
# chown -R icpc.icpc ~icpc/.vscode

echo "MKICPCUSER: ICPC user created"
