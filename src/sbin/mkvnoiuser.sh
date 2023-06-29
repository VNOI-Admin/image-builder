#!/bin/sh

logger -p local0.info "MKVNOIUSER: Create a new vnoi user"

# Create vnoi account
useradd -m vnoi

# Setup desktop background
sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.background picture-options 'centered'
sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.background picture-uri \
	'file:///opt/vnoi/misc/vnoi-wallpaper.png'
sudo -Hu vnoi xvfb-run gsettings set org.gnome.shell enabled-extensions "['add-username-ext']"
sudo -Hu vnoi xvfb-run gsettings set org.gnome.shell disable-user-extensions false
sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.session idle-delay 900
sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-delay 30
if [ -f /opt/vnoi/config/screenlock ]; then
	sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled true
else
	sudo -Hu vnoi xvfb-run gsettings set org.gnome.desktop.screensaver lock-enabled false
fi

# set default fullname
chfn -f "vnoi Contestant" vnoi

# Update path
echo 'PATH=/opt/vnoi/bin:$PATH' >> ~vnoi/.bashrc
echo "alias vnoiconf='sudo /opt/vnoi/bin/vnoiconf.sh'" >> ~vnoi/.bashrc
echo "alias vnoiexec='sudo /opt/vnoi/bin/vnoiexec.sh'" >> ~vnoi/.bashrc
echo "alias vnoibackup='sudo /opt/vnoi/bin/vnoibackup.sh'" >> ~vnoi/.bashrc
echo 'TZ=$(cat /opt/vnoi/config/timezone)' >> ~vnoi/.profile
echo 'export TZ' >> ~vnoi/.profile

# Mark Gnome's initial setup as complete
sudo -Hu vnoi bash -c 'echo yes > ~/.config/gnome-initial-setup-done'

sudo -Hu vnoi bash -c 'mkdir -p ~vnoi/.local/share/gnome-shell/extensions'
cp -a /opt/vnoi/misc/add-username-ext ~vnoi/.local/share/gnome-shell/extensions/
chown -R vnoi.vnoi ~vnoi/.local/share/gnome-shell/extensions/add-username-ext

# Copy VSCode extensions
mkdir -p ~vnoi/.vscode/extensions
tar jxf /opt/vnoi/misc/vscode-extensions.tar.bz2 -C ~vnoi/.vscode/extensions
chown -R vnoi.vnoi ~vnoi/.vscode

# vnoi startup
cp /opt/vnoi/misc/vnoistart.desktop /usr/share/gnome/autostart/

# Setup default Mozilla Firefox configuration
cp -a /opt/vnoi/misc/mozilla ~vnoi/.mozilla
chown -R vnoi.vnoi ~vnoi/.mozilla

logger -p local0.info "MKVNOIUSER: VNOI user created"
