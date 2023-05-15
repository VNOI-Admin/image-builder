#!/bin/bash

source /opt/vnoi/misc/config

if [ "$DOSETUP" = "1" ]; then
	if ! /opt/vnoi/bin/vnoicheckuser -q; then
		/opt/vnoi/bin/vnoisetup
	fi
fi
