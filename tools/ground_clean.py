#!/usr/bin/env python3
"""Clears what a clip left on the ground at an animal's feet: grass tufts (olive) and dust or a shadow (grey, pale).
usage: ground_clean.py <frames dir> <set name> [band=40]
Only the lowest `band` rows of each frame's figure are touched; hooves and feet are dark and keep their colour."""
import sys, glob
import numpy as np
from PIL import Image

d, name = sys.argv[1], sys.argv[2]
band = int(sys.argv[3].split('=')[1]) if len(sys.argv) > 3 else 40
total = 0
for f in sorted(glob.glob(f'{d}/{name}_*.png')):
    im = np.asarray(Image.open(f).convert('RGBA')).astype(np.float32)
    rgb = im[..., :3] / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    c = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / c) % 6, h)
    h = np.where(mx == g, (b - r) / c + 2, h)
    h = np.where(mx == b, (r - g) / c + 4, h)
    h = h * 60.0
    seen = im[..., 3] > 15
    ys = np.where(seen.any(1))[0]
    if len(ys) == 0:
        continue
    low = np.zeros_like(seen)
    low[max(0, ys.max() - band):] = True
    junk = low & seen & (((s < 0.13) & (v > 0.45)) | ((h > 40) & (h < 100) & (s > 0.12)) | (h > 180))
    # and whatever is left in that band that is not joined to the animal above it (the rest of a tuft, a speck)
    keep = seen & ~junk
    body = keep & ~low
    for _ in range(band * 3):
        grow = body.copy()
        grow[1:] |= body[:-1]; grow[:-1] |= body[1:]; grow[:, 1:] |= body[:, :-1]; grow[:, :-1] |= body[:, 1:]
        grow &= keep
        if (grow == body).all():
            break
        body = grow
    junk |= keep & low & ~body
    n = int(junk.sum())
    if n:
        im[junk, 3] = 0
        Image.fromarray(im.astype(np.uint8)).save(f)
        total += n
print(f'{name}: {total} ground pixels cleared')
