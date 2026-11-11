"""Cuts a row of painted objects on a white background into separate clean PNGs.
usage: cut.py <image> <out_dir> name1,name2,... [shrink]"""
import sys, os
from PIL import Image, ImageFilter
import numpy as np
src, out, names = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
shrink = int(sys.argv[4]) if len(sys.argv) > 4 else 2
GAP = int(sys.argv[5]) if len(sys.argv) > 5 else 14
im = np.asarray(Image.open(src).convert('RGB')).astype(np.float32) / 255
lo = im.min(axis=2); sat = im.max(axis=2) - lo
white = np.clip((lo - 0.84) / 0.1, 0, 1) * np.clip((0.14 - sat) / 0.07, 0, 1)      # background and enclosed white pockets
a = 1.0 - white
a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
solid = (a > 0.97).astype(np.float32)
def blur(x): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5))).astype(np.float32) / 255
den = blur(solid); ext = np.dstack([blur(im[..., c] * solid) for c in range(3)]) / np.maximum(den[..., None], 0.02)
rgb = np.where((solid[..., None] > 0.5) | (den[..., None] < 0.03), im, ext)     # edge pixels take colour from inside, never from the white
rgba = np.dstack([rgb, a]); m = a > 0.5
cols = m.sum(axis=0) > 2; runs = []; start = None; gap = 0; last = 0
for x in range(len(cols) + 1):
    on = x < len(cols) and cols[x]
    if on:
        if start is None: start = x
        last = x; gap = 0
    elif start is not None:
        gap += 1
        if gap > GAP or x == len(cols):
            if last - start > 12: runs.append((start, last + 1))
            start = None
os.makedirs(out, exist_ok=True)
for n, (x0, x1) in zip(names, runs):
    ys = np.where(m[:, x0:x1].sum(axis=1) > 1)[0]
    c = rgba[max(0, ys[0] - 3):ys[-1] + 3, max(0, x0 - 3):x1 + 3]
    p = Image.fromarray((np.clip(c, 0, 1) * 255).astype(np.uint8), 'RGBA')
    p = p.resize((max(1, p.width // shrink), max(1, p.height // shrink)), Image.LANCZOS)
    p.save('%s/%s.png' % (out, n)); print(n, p.size)
print('objects found', len(runs), 'named', len(names))
