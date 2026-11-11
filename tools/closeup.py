"""Samuel pouring the oil, as a close-up shot: cut him and the horn off the plain backdrop of the clip.
usage: closeup.py <frames_dir> <out_dir>"""
import sys, os, glob
from PIL import Image, ImageFilter
import numpy as np
V, out = sys.argv[1], sys.argv[2]
TALL = 1100
def filt(x, f): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(f)).astype(np.float32) / 255
for old in glob.glob(out + '/pour_*.png'): os.remove(old)
files = sorted(glob.glob(V + '/f*.png'))[16:186:3]
cuts = []
for f in files:
    im = np.asarray(Image.open(f).convert('RGB')).astype(np.float32) / 255
    H, W = im.shape[:2]
    im = im[:, int(W * 0.15):int(W * 0.78)]
    rowbg = np.median(im[:, -28:-4], axis=1)[:, None, :]          # the backdrop only changes from top to bottom
    a = np.clip((np.abs(im - rowbg).max(axis=2) - 0.08) / 0.08, 0, 1)
    a = filt(filt(a, ImageFilter.MinFilter(7)), ImageFilter.GaussianBlur(1.6))
    h, w = a.shape
    gone = np.zeros_like(a); gone[int(h * 0.8):, :int(w * 0.52)] = 1      # another figure's hand reaches into this corner
    a = a * (1.0 - np.clip(filt(gone, ImageFilter.GaussianBlur(40)) * 2.0, 0, 1))      # taken out with a soft edge
    solid = filt((a > 0.97).astype(np.float32), ImageFilter.MinFilter(9))
    den = filt(solid, ImageFilter.GaussianBlur(7))
    ext = np.dstack([filt(im[..., c] * solid, ImageFilter.GaussianBlur(7)) for c in range(3)]) / np.maximum(den[..., None], 0.02)
    lum = np.clip(im.mean(axis=2, keepdims=True) / np.maximum(ext.mean(axis=2, keepdims=True), 0.02), 0.6, 1.25)
    rgb = np.where((solid[..., None] > 0.5) | (den[..., None] < 0.03), im, ext * lum)     # the rim takes its hue from inside
    cuts.append(np.dstack([rgb, a]))
m = np.max([c[..., 3] for c in cuts], axis=0) > 0.5
ys = np.where(m.sum(axis=1) > 4)[0]; xs = np.where(m.sum(axis=0) > 4)[0]
y0, y1, x0, x1 = max(0, ys[0] - 8), ys[-1] + 1, max(0, xs[0] - 8), min(m.shape[1], xs[-1] + 9)
os.makedirs(out, exist_ok=True)
for k, c in enumerate(cuts):
    c = c[y0:y1, x0:x1]
    im = Image.fromarray((np.clip(c, 0, 1) * 255).astype(np.uint8), 'RGBA')
    im = im.resize((int(im.width * TALL / im.height), TALL), Image.LANCZOS)
    im.save('%s/pour_%02d.png' % (out, k))
print('pour frames', len(cuts), im.size)
