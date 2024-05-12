#!/bin/bash

echo "Starting cvlc"
cvlc -q screen:// --screen-fps=15 --sout \
    "#transcode{ \
        vcodec=h264,acodec=none,vb=3000,ab=0 \
    }:duplicate{ \
        dst=std{access=rtmp,mux=ffmpeg{mux=flv},dst=rtmp://localhost/live/stream}, \
        dst=std{access=http,mux=ts,dst=:101} \
    }" & $PID=$!

echo "Polling for cvlc start"
while ! timeout 0.1 nc -z localhost 101; do
    sleep 0.5;
done

systemd-notify --ready
wait $PID
