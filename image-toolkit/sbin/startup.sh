#!/bin/bash

exec > /opt/vnoi/store/log/startup.log 2>&1

echo "Starting client"
/opt/vnoi/bin/client &
