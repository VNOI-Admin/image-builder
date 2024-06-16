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
    webcam_pick_devices() {
        # Find device by unique identifiers
        # https://docs.kernel.org/userspace-api/media/v4l/open.html#v4l2-device-node-naming
        while :
        do
            echo "Looking for video devices"

            local VIDEO_DEVICES
            mapfile -t VIDEO_DEVICES < <(find /dev/v4l/by-id -regex ".*/usb-.*-video-index0")

            local VIDEO_DEVICES_COUNT
            VIDEO_DEVICES_COUNT=${#VIDEO_DEVICES[@]}

            # Zero video devices
            if [[ $VIDEO_DEVICES_COUNT -eq 0 ]]; then
                echo "No video devices found"
                sleep 3
                continue
            else
                echo "Found $VIDEO_DEVICES_COUNT device(s): ${VIDEO_DEVICES[@]}"
            fi

            VIDEO_DEVICE_PATH=${VIDEO_DEVICES[0]}
            echo "Using $VIDEO_DEVICE_PATH"

            # We might need to use a different device
            # Find out the correct device using aplay -L
            AUDIO_DEVICE=alsa://plughw:0,0
            return
        done
    }

    webcam_stream() {
        # Monitor the video device using udevadm monitor
        # If device is unplugged, kill existing clvc instance to release /dev/video0
        echo "Starting udevadm to monitor video device connection"
        while read -r line; do
            if [[ "$line" =~ "remove" ]] ; then
                echo "Received video device removal: $line"
                break
            fi
        done < <(udevadm monitor --udev -s video4linux) &
        UDEVADM_PID=$!

        echo "Starting cvlc instance for streaming webcam $VIDEO_DEVICE_PATH"
        cvlc -vv -q v4l2://$VIDEO_DEVICE_PATH --v4l2-width=1280 --v4l2-height=720 \
        --input-slave $AUDIO_DEVICE \
        --sout \
            "#transcode{ \
                venc=x264{keyint=15},vcodec=h264,acodec=aac,channels=1,vb=3000,ab=128,fps=15 \
            }:duplicate{ \
                dst=std{access=rtmp,mux=ffmpeg{mux=flv},dst=rtmp://localhost/live/webcam}, \
            }" &
        CVLC_PID=$!

        echo "Waiting for cvlc or udevadm to exit"
        wait -fn -p TERMINATED_PID $UDEVADM_PID $CVLC_PID
        if [[ $TERMINATED_PID -eq $CVLC_PID ]]; then
            echo "cvlc exited"
        else
            echo "udevadm exited"
        fi

        echo "Sending SIGTERM to cvlc and udevadm"
        kill $UDEVADM_PID $CVLC_PID

        echo "Waiting for cvlc and udevadm to exit"
        # timeout returns 124 if the command times out
        timeout 3s wait -f $UDEVADM_PID $CVLC_PID; if [ $? -eq 124 ]; then
            echo "Timeout waiting for cvlc and udevadm to exit, sending SIGKILL"
            kill -9 $UDEVADM_PID $CVLC_PID
        fi
    }

    webcam_pick_devices
    while :
    do
        echo "Checking video device at $VIDEO_DEVICE_PATH"
        if [[ -e $VIDEO_DEVICE_PATH ]]; then
            echo "Video device found"
        else
            echo "Waiting 5s for device"
            sleep 5

            if [[ -e $VIDEO_DEVICE_PATH ]]; then
                echo "Video device found"
            else
                echo "Video device not found. Picking new device"
                webcam_pick_devices
            fi
        fi

        webcam_stream

        echo "Stream stopped. Restarting in 3s"

        # Sleep to prevent CPU hogging and let the processes be killed in any order
        sleep 3
    done
}

vlc_restart_loop &
webcam_stream_loop &

sleep infinity
