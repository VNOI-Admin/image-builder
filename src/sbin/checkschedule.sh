#!/bin/bash

source /opt/vnoi/config.sh


if [ -f /opt/vnoi/misc/schedule2.txt.firstrun ]; then
	logger -p local0.info "SCHEDULE: first run"
	/opt/vnoi/sbin/atrun.sh schedule
	rm /opt/vnoi/misc/schedule2.txt.firstrun
fi

# Check for new contest schedule
SCHEDFILE=$(mktemp)
wget --timeout=3 --tries=3 -O $SCHEDFILE "https://${POP_SERVER}/config/schedule2.txt" > /dev/null 2>&1
if [ $? -eq 0 -a -f $SCHEDFILE ]; then
	diff -q /opt/vnoi/misc/schedule2.txt $SCHEDFILE > /dev/null
	if [ $? -ne 0 ]; then
		logger -p local0.info "SCHEDULE: Setting up new contest schedule"
		cp $SCHEDFILE /opt/vnoi/misc/schedule2.txt
		/opt/vnoi/sbin/atrun.sh schedule
	fi
fi
rm $SCHEDFILE

