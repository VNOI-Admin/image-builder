#!/bin/sh

logger -p local0.info "MKVNOIUSER: Create a new vnoi user"

# Create vnoi account
useradd -m vnoi

# Setup desktop background
sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.session idle-delay 900
sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-delay 30
if [ -f /opt/vnoi/config/screenlock ]; then
	sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled true
else
	sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled false
fi

# set default fullname
chfn -f "vnoi" vnoi

# Update path
echo 'TZ=$(cat /opt/vnoi/config/timezone)' >> ~vnoi/.profile
echo 'export TZ' >> ~vnoi/.profile

# Mark Gnome's initial setup as complete
sudo -Hu vnoi bash -c 'echo yes > ~/.config/gnome-initial-setup-done'

# Copy VSCode extensions
mkdir -p ~vnoi/.vscode/extensions
tar jxf /opt/vnoi/misc/vscode-extensions.tar.bz2 -C ~vnoi/.vscode/extensions
chown -R vnoi.vnoi ~vnoi/.vscode

logger -p local0.info "MKVNOIUSER: VNOI user created"
