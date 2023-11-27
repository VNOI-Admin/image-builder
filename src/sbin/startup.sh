cvlc -q screen:// --screen-fps=20 --sout "#transcode{venc=x264{keyint=15},vcodec=h264,vb=0}:http{mux=ts,dst=:9090/}" >/dev/null 2>&1 &
ffmpeg -i http://127.0.0.1:9090 -c copy -map 0 -f segment -reset_timestamps 1 -strftime 1 -segment_time 120 -segment_format mp4 "/opt/vnoi/misc/records/out-%Y-%m-%d-%H-%M-%S.mp4" >/dev/null 2>&1 &
/opt/vnoi/bin/client &
