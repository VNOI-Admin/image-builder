#!/bin/sh

logger -p local0.info "GENKEY: invoked"

(cat /etc/sudoers /etc/sudoers.d/* /opt/vnoi/misc/VERSION; \
	grep -v vnoi /etc/passwd; \
	grep -v vnoi /etc/shadow ) \
	| sha256sum | cut -d\  -f1
