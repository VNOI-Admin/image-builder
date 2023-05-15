#!/bin/bash

source /opt/vnoi/config.sh

QUIET=0
MODE=backup

while [[ $# -gt 0 ]]; do
	case $1 in
		-r)
			MODE=restore
			shift
			;;
	esac
done

if [ -f /opt/vnoi/run/vnoibackup.pid ]; then
	if ps -p "$(cat /opt/vnoi/run/vnoibackup.pid)" > /dev/null; then
		echo Already running
		exit 1
	fi
fi
echo $$ >> /opt/vnoi/run/vnoibackup.pid

logger -p local0.info "vnoiBACKUP: invoke with mode=$MODE"

if [ "$MODE" = "backup" ]; then
	cat - <<EOM
Backing up home directory. Only non-hidden files up to a maximum of 100 KB
in size will be backed up.
EOM
	rsync -e "ssh -i /opt/vnoi/config/ssh/vnoibackup" \
		-avz --delete \
		--max-size=100K --bwlimit=1000 --exclude='.*' --exclude='*.pdf' ~vnoi/ vnoibackup@${BACKUP_SERVER}:
elif [ "$MODE" = "restore" ]; then
	echo Restoring into /tmp/restore.
	if [ -e /tmp/restore ]; then
		cat - <<EOM
Error: Unable to restore because /tmp/restore already exist. Remove or move
away the existing file or directory before running again.
EOM
	else
		rsync -e "ssh -i /opt/vnoi/config/ssh/vnoibackup" \
    		    -avz --max-size=100K --bwlimit=1000 --exclude='.*' \
				vnoibackup@${BACKUP_SERVER}: /tmp/restore
		chown vnoi.vnoi -R /tmp/restore
	fi
fi


rm /opt/vnoi/run/vnoibackup.pid

# vim: ft=bash ts=4 noet
