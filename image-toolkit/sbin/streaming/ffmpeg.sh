#!/bin/bash

echo "Starting ffmpeg"
ffmpeg -re -i rtmp://localhost/live/stream -c copy -f segment -reset_timestamps 1 -strftime 1 -segment_time 120 -segment_format mp4 "/opt/vnoi/misc/records/out-%Y-%m-%d-%H-%M-%S.mp4"
