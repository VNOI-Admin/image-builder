cvlc -q screen:// --screen-fps=30 --sout "#transcode{vcodec=theo,vb=2000,channels=1,ab=128,samplerate=44100,width=1920}:http{dst=:9090/stream.ogg}" >/dev/null 2>&1 &
ffmpeg -i http://:9090/stream.ogg -c copy -map 0 -f segment -reset_timestamps 1 -strftime 1 -segment_time 120 -segment_format ogg "/opt/vnoi/misc/records/out-%Y-%m-%d-%H-%M-%S.mp4" >/dev/null 2>&1 &
/opt/vnoi/bin/client &
