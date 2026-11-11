#!/bin/zsh
# The log bridge coming down: several heavy logs landing one after another, built from the game's own deep blow
# pitched down, with a low roll under it. Also turns the jar's long bright shatter into a short dull crack of fired clay.
S=audio/sfx
[ -f $S/jar_long.mp3.src ] || cp $S/jar.mp3 $S/jar_long.mp3.src
ffmpeg -y -loglevel error -i $S/hit.mp3 -i $S/hit.mp3 -i $S/hit.mp3 -i $S/hit.mp3 -i $S/hit.mp3 -i $S/hit.mp3 -i $S/lion_land.mp3 -filter_complex "
[0:a]asetrate=44100*0.62,aresample=44100,volume=1.9[a0];
[1:a]asetrate=44100*0.74,aresample=44100,volume=1.5,adelay=130:all=1[a1];
[2:a]asetrate=44100*0.55,aresample=44100,volume=1.7,adelay=290:all=1[a2];
[3:a]asetrate=44100*0.82,aresample=44100,volume=1.1,adelay=470:all=1[a3];
[4:a]asetrate=44100*0.66,aresample=44100,volume=1.0,adelay=720:all=1[a4];
[5:a]asetrate=44100*0.9,aresample=44100,volume=0.6,adelay=1010:all=1[a5];
[6:a]asetrate=44100*1.6,aresample=44100,volume=0.9,adelay=60:all=1[r];
[a0][a1][a2][a3][a4][a5][r]amix=inputs=7:normalize=0,lowpass=f=1100,highpass=f=55,afade=t=out:st=1.5:d=0.5,alimiter=limit=0.9[o]" -map "[o]" -t 2.0 -ar 44100 -ac 1 -b:a 160k $S/logs.mp3
ffmpeg -y -loglevel error -i $S/jar_long.mp3.src -af "atrim=0.52:1.04,asetpts=PTS-STARTPTS,asetrate=44100*0.7,aresample=44100,lowpass=f=2600,afade=t=out:st=0.25:d=0.5,volume=1.6,alimiter=limit=0.8" -ar 44100 -ac 1 -b:a 128k $S/jar.mp3
