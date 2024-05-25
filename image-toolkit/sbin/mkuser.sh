#!/bin/sh

set -e

# logger -p local0.info "MKVNOIUSER: Create a new icpc user"

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

# Set up automatic login
# Replace the line that contains "AutomaticLoginEnable =" with "AutomaticLoginEnable = true"
# Replace the line that contains "AutomaticLogin =" with "AutomaticLogin = icpc"
# sed -i '/AutomaticLoginEnable =/c\AutomaticLoginEnable = true' /etc/gdm3/custom.conf
# sed -i '/AutomaticLogin =/c\AutomaticLogin = icpc' /etc/gdm3/custom.conf

# Set up passwordless login
sed -i '/disable-user-list=/c\disable-user-list=false' /etc/gdm3/greeter.dconf-defaults
sed -i '2 i auth sufficient pam_succeed_if.so user = icpc' /etc/pam.d/gdm-password

# Copy VSCode extensions
# TODO: Check this out
# mkdir -p ~icpc/.vscode/extensions
# tar jxf /opt/vnoi/misc/vscode-extensions.tar.bz2 -C ~icpc/.vscode/extensions
# chown -R icpc.icpc ~icpc/.vscode

# logger -p local0.info "MKICPCUSER: ICPC user created"
