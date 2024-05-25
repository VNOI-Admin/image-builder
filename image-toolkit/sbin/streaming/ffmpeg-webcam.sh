#!/bin/bash

echo "Polling for cvlc start"

while ! timeout 60s ffprobe -v quiet -probesize 32 rtmp://localhost/live/webcam; do
    sleep 0.5;
done

echo "Starting ffmpeg"
ffmpeg -re -i rtmp://localhost/live/webcam \
    -c copy -f segment -reset_timestamps 1 -strftime 1 -segment_time 120 -segment_format mp4 \
    "/opt/vnoi/misc/records/webcam-out-%Y-%m-%d-%H-%M-%S.mp4" & FFMPEG_PID=$!

systemd-notify --ready
wait $FFMPEG_PID
