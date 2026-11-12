"""Cuts a story film (the short films between sections) together from its shots, narration and music.
usage: build_story.py <id> <work_dir> --shots a.mp4 b.mp4 ... --lines n_x n_y ... [--music audio/music/theme_still.mp3]
Narration comes from audio/narration/<line>.mp3 (English) and audio/narration/pt/<line>.mp3; the words from
data/narration/chapter1(.pt).json. The picture is the same for both languages and is stretched a little if the
narration needs longer than the shots run. Writes video/story_<id>.ogv, video/story_<id>.pt.ogv and their cue
files data/story_<id>.json and data/story_<id>.pt.json. The Ogg Theora files are written by Godot's movie writer
(tools/enc), because this Mac's ffmpeg has no Theora encoder."""
import sys, os, json, subprocess, shutil

FPS = 24
X = 0.9                 # crossfade between shots, seconds
W, H, PIC_H = 1920, 1080, 804       # 2.39:1 picture inside a 16:9 frame, like the prologue
LEAD, GAP, TAIL = 1.2, 0.9, 1.8     # seconds before the first line, between lines, after the last

args = sys.argv[1:]
fid, work = args[0], args[1]
def opt(name, default=None):
    if name not in args: return default
    i = args.index(name) + 1; out = []
    while i < len(args) and not args[i].startswith('--'): out.append(args[i]); i += 1
    return out
shots, lines = opt('--shots'), opt('--lines')
keep = []
for i, sh in enumerate(shots):
    f, _, k = sh.partition('@')
    shots[i] = f; keep.append({'': 0.5, 'top': 0.0, 'bottom': 1.0}.get(k, None) if k in ('', 'top', 'bottom') else float(k))
music = (opt('--music') or ['audio/music/theme_still.mp3'])[0]
os.makedirs(work, exist_ok=True)

def dur(path):
    return float(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path]).decode().strip())

LANGS = {'en': ('audio/narration/%s.mp3', 'data/narration/chapter1.json', ''),
         'pt': ('audio/narration/pt/%s.mp3', 'data/narration/chapter1.pt.json', '.pt')}
plan = {}
for lang, (pat, words, _) in LANGS.items():
    text = json.load(open(words))['lines']
    t = LEAD; cues = []
    for l in lines:
        # a line not yet recorded is shown as words only, held long enough to read
        have = os.path.exists(pat % l)
        if not have: print(lang, l, 'has no recording yet: shown as text only')
        d = dur(pat % l) if have else max(5.0, len(text[l]['text']) / 13.0)
        cues.append({'t': round(t, 2), 'd': round(d + 0.4, 2), 'text': text[l]['text'], 'ref': text[l].get('ref', ''), 'file': (pat % l) if have else None})
        t += d + GAP
    plan[lang] = (cues, t - GAP)
if not plan: sys.exit('no narration found')

natural = sum(dur(s) for s in shots) - X * (len(shots) - 1)
need = max(end for _, end in plan.values()) + TAIL
length = max(natural, need)
slow = length / natural
print('shots run %.1fs, narration needs %.1fs: film is %.1fs (picture slowed x%.2f)' % (natural, need, length, slow))

# ---- picture: every shot scaled to the frame, cropped to the cinema bar, crossfaded, written as frames
frames = work + '/frames'
shutil.rmtree(frames, ignore_errors=True); os.makedirs(frames)
cmd = ['ffmpeg', '-y', '-loglevel', 'error']
for s in shots: cmd += ['-i', s]
parts = []; at = 0.0; ds = []
for i, s in enumerate(shots):
    d = dur(s) * slow; ds.append(d)
    # a shot that fills the whole 16:9 frame is cut down to the cinema bar; "file.mp4@top" (or @bottom, or @0.3)
    # says which part of its height to keep, when the middle would lose a face
    y = '(ih-%d)*%.3f' % (PIC_H, keep[i])
    parts.append('[%d:v]setpts=%.4f*PTS,fps=%d,scale=%d:-2:flags=lanczos,crop=%d:%d:0:%s,format=yuv420p,setsar=1[s%d]' % (i, slow, FPS, W, W, PIC_H, y, i))
last = '[s0]'; offset = ds[0] - X
for i in range(1, len(shots)):
    parts.append('%s[s%d]xfade=transition=fade:duration=%.2f:offset=%.3f[x%d]' % (last, i, X, offset, i))
    last = '[x%d]' % i; offset += ds[i] - X
parts.append('%spad=%d:%d:0:%d:black,fade=t=in:st=0:d=1.0,fade=t=out:st=%.2f:d=1.2[v]' % (last, W, H, (H - PIC_H) // 2, length - 1.2))
cmd += ['-filter_complex', ';'.join(parts), '-map', '[v]', '-t', '%.2f' % length, '-q:v', '3', frames + '/f%05d.jpg']
subprocess.check_call(cmd)
print(len(os.listdir(frames)), 'frames')

# ---- sound and the finished film, once per language
for lang, (cues, _) in plan.items():
    suffix = LANGS[lang][2]
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-stream_loop', '-1', '-i', music]
    mix = ['[0:a]volume=0.30,afade=t=in:st=0:d=2.5,afade=t=out:st=%.2f:d=2.5,atrim=0:%.2f[m]' % (length - 2.5, length)]
    names = ['[m]']
    k = 0
    for c in cues:
        if not c['file']: continue
        k += 1
        cmd += ['-i', c['file']]
        mix.append('[%d:a]volume=0.85,adelay=%d:all=1[n%d]' % (k, int(c['t'] * 1000), k)); names.append('[n%d]' % k)
    mix.append('%samix=inputs=%d:normalize=0:duration=first[a]' % (''.join(names), len(names)))
    wav = '%s/story_%s%s.wav' % (work, fid, suffix)
    subprocess.check_call(cmd + ['-filter_complex', ';'.join(mix), '-map', '[a]', '-t', '%.2f' % length, '-ar', '44100', '-ac', '2', wav])
    out = os.path.abspath('video/story_%s%s.ogv' % (fid, suffix))
    subprocess.check_call(['godot', '--path', 'tools/enc', '--write-movie', out, '--fixed-fps', str(FPS), '--', os.path.abspath(frames), os.path.abspath(wav)],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for c in cues: c.pop('file')
    json.dump({'length': round(length, 2), 'cues': cues}, open('data/story_%s%s.json' % (fid, suffix), 'w'), indent=1, ensure_ascii=False)
    print('wrote', out, '%.1f MB' % (os.path.getsize(out) / 1e6))
