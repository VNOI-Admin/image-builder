#!/bin/bash
source "$(dirname "$0")/common.sh"

test_case "check if stream.m3u8 exists for hls"
file_path='/var/www/html/stream/hls/stream.m3u8'
if [[ -f "$file_path" ]] ; then
    pass
else
    echo "stream.m3u8 not found, retrying in 2 minutes..."
    sleep 120
    if [[ -f "$file" ]] ; then
      pass
    else
      fail "stream.m3u8 not found"
    fi
fi

test_case "check if ffmpeg-record.service is active"
if systemctl is-active --quiet ffmpeg-record.service; then
    pass
else
    fail
fi

# check for ffmpeg process
# if pgrep ffmpeg --exact; then
#     pass
# else
#     fail
# fi
