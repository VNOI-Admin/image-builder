#!/bin/bash

exec > "/opt/vnoi/store/log/startup-$$.log" 2>&1

# Check pgid and pid match
if [ ! $$ = $(ps -o pgid -hp $$) ]; then
    echo "Enabling job control"
    set -m
fi

# https://stackoverflow.com/questions/360201/how-do-i-kill-background-processes-jobs-when-my-shell-script-exits/53714583#53714583
trap "exit \$exit_code" INT TERM
trap "exit_code=\$?; kill 0" EXIT

if [ -f /run/icpc-startup.pid ]; then
    echo "Found existing startup pid file"

    STARTUP_PID=$(cat /run/icpc-startup.pid)
    # Check if the pid is still running and whether it's me
    if kill -0 $STARTUP_PID && diff /proc/$STARTUP_PID/cmdline /proc/$$/cmdline; then
        echo "Killing existing startup"
        kill -- -$(cat /run/icpc-startup.pid)
    else
        echo "Removing stale startup pid file"
    fi

    rm /run/icpc-startup.pid
fi

echo "Writing my own pid"
echo $$ > /run/icpc-startup.pid

echo "Starting client"
/opt/vnoi/bin/client &

vlc_restart_loop() {
    while :
    do
        echo "Starting cvlc"
        cvlc -vv -q screen:// --screen-fps=15 --sout \
            "#transcode{ \
                vcodec=h264,acodec=none,vb=3000,ab=0 \
            }:duplicate{ \
                dst=std{access=rtmp,mux=ffmpeg{mux=flv},dst=rtmp://localhost/live/stream}, \
                dst=std{access=http,mux=ts,dst=:101} \
            }"
        echo "VLC exited, restarting in 3 seconds"
        sleep 3
    done
}

vlc_restart_loop &
