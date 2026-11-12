"""Makes audio/sfx/step_wet.mp3: a foot set down in shallow standing water. Built from nothing but numbers, like
tools/sfx_logs.sh builds the bridge: a short slap of filtered noise, a small rising 'plip' as the water closes
over, and a soft low body under it. Energy is kept between about 200 Hz and 4 kHz so laptop speakers carry it.
usage: python3 tools/sfx_wet.py   (needs numpy and ffmpeg)"""
import numpy as np, subprocess, wave, os, tempfile
SR = 44100
rng = np.random.default_rng(3)
n = int(SR * 0.42)
t = np.arange(n) / SR

def band(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1 / (1 + (lo / np.maximum(fr, 1)) ** 4) * 1 / (1 + (fr / hi) ** 4)
    return np.fft.irfft(f, len(x))

slap = band(rng.standard_normal(n), 700, 3800) * np.exp(-t / 0.035) * np.minimum(t / 0.004, 1)
wash = band(rng.standard_normal(n), 400, 2200) * np.exp(-np.maximum(t - 0.03, 0) / 0.11) * np.minimum(t / 0.03, 1) * 0.45
t2 = np.maximum(t - 0.06, 0)
plip = np.sin(2 * np.pi * (520 * t2 + 2600 * t2 ** 2)) * np.exp(-t2 / 0.045) * (t > 0.06) * 0.5
body = np.sin(2 * np.pi * 210 * t) * np.exp(-t / 0.03) * 0.5
x = slap / np.abs(slap).max() * 0.9 + wash / np.abs(wash).max() * 0.4 + plip + body
x *= np.minimum((n - np.arange(n)) / (SR * 0.05), 1)
x = x / np.abs(x).max() * 0.8
tmp = os.path.join(tempfile.gettempdir(), 'step_wet.wav')
with wave.open(tmp, 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype(np.int16).tobytes())
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-ar', '44100', '-ac', '1', '-b:a', '128k', 'audio/sfx/step_wet.mp3'], check=True)
os.remove(tmp)
f = np.abs(np.fft.rfft(x)) ** 2
fr = np.fft.rfftfreq(n, 1 / SR)
print('step_wet.mp3: %.2f s, energy 200-4000 Hz: %d%%, below 100 Hz: %d%%' % (n / SR, 100 * f[(fr > 200) & (fr < 4000)].sum() / f.sum(), 100 * f[fr < 100].sum() / f.sum()))
