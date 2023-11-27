echo -n Clearing machine

rm /opt/vnoi/misc/records/*
rm -rf /home
mkdir /home
cd /home
cp -r /etc/skel /home/vnoi && chown -R vnoi:vnoi /home/vnoi

echo "Done."
