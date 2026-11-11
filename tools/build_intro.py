"""Cuts the prologue film together from its shots, narration, music and sounds.
usage: build_intro.py <work_dir>      (work_dir holds kNN.png stills, vNN.mp4 shots, audio/nNN.mp3, audio/music.mp3)
A shot uses its video when vNN.mp4 exists, otherwise a slow camera move over its still.
Writes <work_dir>/intro_master.mp4 and data/intro.json (subtitle cues, title time, length)."""
import sys, os, json, subprocess
W = sys.argv[1]
FPS = 24
X = 0.9            # crossfade between shots, seconds
OUT_W, OUT_H = 1920, 1080
PIC_H = 804        # picture height inside the frame: 2.39:1 cinema bars
MUSIC_AT = 7.5     # the film opens on wind and the first words; the score enters here, which puts its silence on the tearing of the robe

# shot id, seconds on screen, camera move over a still (zoom from, zoom to, drift x, drift y), speed factor for video
SHOTS = [
    ('00', 13.4, (1.00, 1.12, 0.0, -0.3), 1.0),
    ('01', 9.8, (1.00, 1.10, 0.2, 0.0), 1.0),
    ('02', 11.4, (1.12, 1.00, 0.0, 0.2), 1.0),
    ('03', 10.0, (1.00, 1.12, 0.0, -0.2), 1.0),
    ('04', 6.8, (1.00, 1.10, 0.3, 0.0), 1.0),
    ('05', 8.0, (1.10, 1.00, -0.3, 0.0), 1.0),
    ('06', 16.0, (1.00, 1.12, 0.0, 0.0), 1.35),
    ('07', 7.6, (1.00, 1.08, 0.0, 0.0), 1.5),
    ('08', 9.4, (1.00, 1.14, 0.15, 0.0), 1.0),
    ('9a', 8.6, (1.10, 1.00, 0.0, 0.0), 1.0),
    ('09', 10.6, (1.00, 1.12, 0.0, 0.1), 1.0),
    ('10', 16.0, (1.00, 1.10, 0.0, -0.2), 1.0),
]
# narration line, the shot it starts on, delay after that shot begins, subtitle text, reference
LINES = [
    ('01', '00', 1.2, 'About a thousand years before Christ, Israel had no king. Twelve tribes, bound by a covenant, and judged by an old prophet named Samuel.', ''),
    ('02', '01', 0.5, 'Then the elders of Israel came to him at Ramah, and said: “Now make us a king to judge us like all the nations.”', '1 Samuel 8:5'),
    ('03', '02', 0.6, 'It grieved Samuel. But the LORD said to him: “They have not rejected you, but they have rejected me as the king over them.”', '1 Samuel 8:7'),
    ('04', '03', 0.6, 'So Israel was given Saul, the son of Kish. From his shoulders and upward he was taller than any of the people.', '1 Samuel 9:2'),
    ('05', '04', 0.5, 'The LORD sent Saul against Amalek with one command: spare nothing. Saul won the battle. But he spared the king, and the best of the sheep and the cattle.', '1 Samuel 15:3, 9'),
    ('06', '06', 0.8, 'At Gilgal, Samuel came to him. “Then what does this bleating of the sheep in my ears and the lowing of the cattle which I hear mean? Behold, to obey is better than sacrifice.”', '1 Samuel 15:14, 22'),
    ('07', '07', 0.2, 'As Samuel turned around to go away, Saul grabbed the skirt of his robe, and it tore.', '1 Samuel 15:27'),
    ('08', '08', 0.7, '“The LORD has torn the kingdom of Israel from you today, and has given it to a neighbour of yours who is better than you.”', '1 Samuel 15:28'),
    ('09', '9a', 0.5, 'Samuel came no more to see Saul until the day of his death. And the LORD said: “Fill your horn with oil, and go. I will send you to Jesse the Bethlehemite, for I have provided a king for myself amongst his sons.”', '1 Samuel 15:35; 16:1'),
    ('10', '10', 1.2, 'And in Bethlehem, the youngest son was keeping the sheep.', '1 Samuel 16:11'),
]

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-1500:]); sys.exit(1)
def dur(path):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path], capture_output=True, text=True).stdout.strip())

os.makedirs(W + '/seg', exist_ok=True)
look = 'scale=%d:%d:force_original_aspect_ratio=increase:flags=lanczos,crop=%d:%d,unsharp=5:5:0.6:5:5:0.0,noise=alls=5:allf=t,pad=%d:%d:0:%d:black,format=yuv420p' % (OUT_W, PIC_H, OUT_W, PIC_H, OUT_W, OUT_H, (OUT_H - PIC_H) // 2)
segs = []
for sid, secs, move, speed in SHOTS:
    vid = '%s/v%s.mp4' % (W, sid); still = '%s/k%s.png' % (W, sid)
    n = int(round(secs * FPS))
    srcp = vid if os.path.exists(vid) else still
    kind = 'video' if os.path.exists(vid) else 'still'
    out = '%s/seg/s%s_%s_%d.mp4' % (W, sid, kind, n)
    if os.path.exists(out) and os.path.getmtime(out) > os.path.getmtime(srcp):       # already rendered from this source
        segs.append((sid, out, n / FPS, kind)); print('shot', sid, kind, 'kept'); continue
    if os.path.exists(vid):
        have = dur(vid) * speed
        sp = speed if have >= secs else secs / dur(vid) * 1.01          # never run out of footage
        vf = "setpts=%.4f*PTS,minterpolate=fps=%d:mi_mode=blend,%s" % (sp, FPS, look) if sp > 1.02 else "fps=%d,%s" % (FPS, look)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', vid, '-vf', vf, '-frames:v', str(n), '-an', '-c:v', 'libx264', '-crf', '15', '-preset', 'medium', out])
        kind = 'video'
    elif os.path.exists(still):
        z0, z1, dx, dy = move
        big = 6400
        zp = ("scale=%d:-2:flags=lanczos,zoompan=z='%f+(%f)*on/%d':x='(iw-iw/zoom)*(0.5+(%f)*(on/%d-0.5))':y='(ih-ih/zoom)*(0.5+(%f)*(on/%d-0.5))':d=%d:s=%dx%d:fps=%d"
              % (big, z0, z1 - z0, n, dx, n, dy, n, n, OUT_W, OUT_W * 9 // 16, FPS))
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', still, '-vf', zp + ',' + look, '-frames:v', str(n), '-an', '-c:v', 'libx264', '-crf', '15', '-preset', 'medium', out])
        kind = 'still'
    else:
        print('missing shot', sid); sys.exit(1)
    segs.append((sid, out, n / FPS, kind))
    print('shot', sid, kind, round(n / FPS, 2))

# picture: crossfade the shots in a chain; fade in from black and out at the end
inputs = []; fc = []; start = {}; t = 0.0
for i, (sid, path, d, kind) in enumerate(segs):
    inputs += ['-i', path]
    start[sid] = t
    if i == 0:
        last = '[0:v]'; t = d
    else:
        off = t - X
        fc.append("%s[%d:v]xfade=transition=fade:duration=%.3f:offset=%.3f[x%d]" % (last, i, X, off, i))
        last = '[x%d]' % i; start[sid] = off; t = off + d
total = t
fc.append("%sfade=t=in:st=0:d=1.6,fade=t=out:st=%.3f:d=2.4[v]" % (last, total - 2.4))

# Another language: NARR_LANG=pt takes the voice from <work_dir>/audio_pt and the words from data/intro.pt.json,
# and (with AUDIO_ONLY) writes <work_dir>/intro_mix_pt.wav and the new cue times back into data/intro.pt.json.
LANG = os.environ.get('NARR_LANG', '')
NARR = 'audio_' + LANG if LANG else 'audio'
LOCAL = json.load(open('data/intro.%s.json' % LANG))['cues'] if LANG else None
# sound: narration lines at their cues, music ducked under the voice, a few sounds
cues = []; a_in = []; a_fc = []; voices = []
k = len(segs)
for num, sid, delay, text, ref in LINES:
    p = '%s/%s/n%s.mp3' % (W, NARR, num); d = dur(p)
    if LOCAL: text, ref = LOCAL[len(cues)]['text'], LOCAL[len(cues)]['ref']
    at = start[sid] + delay
    if cues: at = max(at, cues[-1]['t'] + cues[-1]['d'] - 0.6 + 0.45)        # never talk over the previous line
    a_in += ['-i', p]
    a_fc.append("[%d:a]aresample=48000,loudnorm=I=-17:TP=-2:LRA=9,adelay=%d:all=1[n%s]" % (k, int(at * 1000), num)); voices.append('[n%s]' % num); k += 1
    cues.append({'t': round(at, 2), 'd': round(d + 0.6, 2), 'text': text, 'ref': ref})
    if at - (start[sid] + delay) > 1.5: print('line', num, 'starts', round(at - start[sid] - delay, 1), 's late for its shot')
a_fc.append("%samix=inputs=%d:normalize=0,apad=whole_dur=%.3f,asplit=2[voice][key]" % (''.join(voices), len(voices), total))
extra = []
def sound(path, at, gain, fade_out=0.0):
    global k
    if not os.path.exists(path): return
    a_in.extend(['-i', path])
    f = "[%d:a]aresample=48000,volume=%.2f" % (k, gain)
    if fade_out > 0: f += ",afade=t=out:st=%.2f:d=%.2f" % (max(0.0, dur(path) - fade_out), fade_out)
    a_fc.append(f + ",adelay=%d:all=1[e%d]" % (int(at * 1000), k)); extra.append('[e%d]' % k); k += 1
sound(W + '/audio/tear.mp3', start['07'] + 4.3, 1.5)
sound('audio/sfx/gust.mp3', 0.3, 0.6, 0.6)
for j, off in enumerate([0.3, 3.9, 8.2, 12.5]):
    sound('audio/sfx/sheep.mp3', start['06'] + off, 0.22)
sound('audio/sfx/gust.mp3', start['08'] + 1.0, 0.5, 0.5)
sound('audio/sfx/sheep.mp3', start['10'] + 6.5, 0.16)
music = W + '/audio/music.mp3'
a_in += ['-stream_loop', '-1', '-i', music]
a_fc.append("[%d:a]aresample=48000,volume=1.25,afade=t=in:st=0:d=2.5,adelay=%d:all=1,atrim=0:%.3f,afade=t=out:st=%.3f:d=4.0[mus]" % (k, int(MUSIC_AT * 1000), total, total - 4.0))
# the film must not open on a bare voice: a quiet cut of the same theme lies under the first words and
# gives way as the score comes in at MUSIC_AT (the score keeps its place, so its silence still falls on the tearing of the robe)
k += 1
a_in += ['-i', 'audio/music/theme_still.mp3']
a_fc.append("[%d:a]aresample=48000,volume=0.55,afade=t=in:st=0:d=0.6,afade=t=out:st=%.2f:d=4.5,atrim=0:%.2f[bed]" % (k, MUSIC_AT - 0.8, MUSIC_AT + 3.8))
a_fc.append("[mus][bed]amix=inputs=2:normalize=0[mus2]")
a_fc.append("[mus2][key]sidechaincompress=threshold=0.05:ratio=2.2:attack=40:release=600[duck]")
a_fc.append("[voice][duck]%samix=inputs=%d:normalize=0,alimiter=limit=0.89[a]" % (''.join(extra), 2 + len(extra)))
master = W + '/intro_master.mp4'
if os.environ.get('AUDIO_ONLY'):        # remix the sound alone: <work_dir>/intro_mix.wav, to be muxed onto the finished film
    run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y'] + inputs + a_in + ['-filter_complex', ';'.join(a_fc), '-map', '[a]',
         '-t', '%.3f' % total, W + ('/intro_mix_%s.wav' % LANG if LANG else '/intro_mix.wav')])
    if LANG:
        json.dump({'length': round(total, 2), 'title_at': round(start['10'] + 7.0, 2), 'cues': cues}, open('data/intro.%s.json' % LANG, 'w'), ensure_ascii=False, indent=1)
    print('sound', round(total, 2), 's'); sys.exit(0)
run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y'] + inputs + a_in + ['-filter_complex', ';'.join(fc + a_fc), '-map', '[v]', '-map', '[a]',
     '-c:v', 'libx264', '-crf', '15', '-preset', 'medium', '-c:a', 'aac', '-b:a', '256k', '-t', '%.3f' % total, master])
title_at = start['10'] + 7.0
json.dump({'length': round(total, 2), 'title_at': round(title_at, 2), 'cues': cues}, open('data/intro.json', 'w'), ensure_ascii=False, indent=1)
print('film', round(total, 2), 's  title at', round(title_at, 2), ' ->', master)
