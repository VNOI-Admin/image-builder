#!/bin/bash

# https://stackoverflow.com/a/45112755
# This checks pgid and pid match, and make match if not.
# Future startup.sh runs will terminate all processes with the same pgid.
# Since all subprocesses will be in the same process group as the main script,
# this means terminating all subprocesses of this script.
if [ ! $$ = $(ps -o pgid -hp $$) ]; then
    set -m
    "$0" "$@"
    exit $?
else
    echo "Job control enabled"
fi

exec > "/opt/vnoi/store/log/startup-$$.log" 2>&1

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
        # Sleep to prevent CPU hogging and let the processes be killed in any order
        sleep 3
    done
}

webcam_stream_loop() {
    while :
    do
        DEVICE_NO=0
        while ! [[ -e "/dev/video$DEVICE_NO" ]]; do
            sleep 3;
        done

        echo "Starting cvlc instance for webcam streaming"
        cvlc -vv -q v4l2:///dev/video$DEVICE_NO --v4l2-width=1280 --v4l2-height=720 --sout \
            "#transcode{ \
                vcodec=h264,acodec=none,vb=3000,ab=0,fps=15 \
            }:duplicate{ \
                dst=std{access=rtmp,mux=ffmpeg{mux=flv},dst=rtmp://localhost/live/webcam}, \
            }" &
        CLVC_PID=$!
        # Monitor the process and device
        while [[ -e "/dev/video$DEVICE_NO" ]] && ps -p $CLVC_PID > /dev/null; do
            sleep 3
        done

        # If device is unplugged, kill existing clvc instance to release /dev/video0
        if ! [[ -e "/dev/video$DEVICE_NO" ]]; then
            echo "Device unplugged, proceed to kill cvlc"
            kill $CLVC_PID 2>/dev/null || :
        fi

        echo "VLC instance for webcam streaming exited, restarting in 3 seconds"
        # Sleep to prevent CPU hogging and let the processes be killed in any order
        sleep 3
    done
}

vlc_restart_loop &
webcam_stream_loop &

sleep infinity
