#!/bin/bash

echo "Starting ffmpeg"
ffmpeg -i http://localhost:101 -re -c copy -f segment -reset_timestamps 1 -strftime 1 -segment_time 120 -segment_format mp4 "/opt/vnoi/misc/records/out-%Y-%m-%d-%H-%M-%S.mp4"
