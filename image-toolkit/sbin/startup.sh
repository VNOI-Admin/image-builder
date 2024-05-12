#!/bin/bash

/opt/vnoi/bin/client &

killall vlc
killall ffmpeg

cvlc -q screen:// --screen-fps=15 --sout "#transcode{vcodec=h264,acodec=none,vb=3000,ab=0}:duplicate{dst=std{access=rtmp,mux=ffmpeg{mux=flv},dst=rtmp://localhost/live/stream},dst=std{access=http,mux=ts,dst=:101}}" >/dev/null 2>&1 &

while ! timeout 0.1 nc -z localhost 101; do sleep 0.5; done
ffmpeg -i http://localhost:101 -c copy -f segment -reset_timestamps 1 -strftime 1 -segment_time 120 -segment_format mp4 "/opt/vnoi/misc/records/out-%Y-%m-%d-%H-%M-%S.mp4" >/dev/null 2>&1 &
