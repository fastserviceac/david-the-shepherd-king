"""Cuts the four figure groups (Samuel, Jesse, brothers, servant) out of one
magenta-screen clip in which they all stand in a row. usage: people.py <frames_dir> <art_dir>"""
import sys, os, glob
from PIL import Image, ImageFilter
import numpy as np
src, out = sys.argv[1], sys.argv[2]
names = ['samuel', 'jesse', 'brothers', 'servant']
files = sorted(glob.glob(src + '/f*.png'))[40:190:4]
def key(path):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255
    # the backdrop only changes from top to bottom, so each row's own left edge says what "background" is there
    rowbg = np.median(im[:, 2:16], axis=1)[:, None, :]
    dist = np.abs(im - rowbg).max(axis=2)
    a = np.clip((dist - 0.07) / 0.07, 0, 1)
    body = a > 0.5
    ys = np.where(body.sum(axis=1) > 6)[0]
    feet = ys[-1]
    a[feet + 2:] = 0
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
    solid = (a > 0.97).astype(np.float32)
    def blur(x): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32) / 255
    den = blur(solid); ext = np.dstack([blur(im[..., c] * solid) for c in range(3)]) / np.maximum(den[..., None], 0.02)
    rgb = np.where((solid[..., None] > 0.5) | (den[..., None] < 0.03), im, ext)
    return np.dstack([rgb, a]), feet
sets = {n: [] for n in names}
for f in files:
    rgba, feet = key(f)
    m = rgba[..., 3] > 0.5
    cols = m.sum(axis=0) > 2
    runs = []; start = None; gap = 0; last = 0
    for x in range(len(cols) + 1):
        on = x < len(cols) and cols[x]
        if on:
            if start is None: start = x
            last = x; gap = 0
        elif start is not None:
            gap += 1
            if gap > 8 or x == len(cols):
                if last - start > 20: runs.append((start, last + 1))
                start = None
    if len(runs) != 4: continue
    for n, (x0, x1) in zip(names, runs):
        ys = np.where(m[:, x0:x1].sum(axis=1) > 1)[0]
        sets[n].append((rgba[max(0, ys[0] - 4):feet + 3, max(0, x0 - 4):x1 + 4], (x0 + x1) / 2))
print('frames kept', {n: len(v) for n, v in sets.items()})
for n in names:
    fr = [c for c, _ in sets[n]]
    W = max(c.shape[1] for c in fr) + 8; H = max(c.shape[0] for c in fr) + 8
    os.makedirs('%s/%s/anim' % (out, n), exist_ok=True)
    for old in glob.glob('%s/%s/anim/idle_*.png' % (out, n)): os.remove(old)
    for k, c in enumerate(fr):
        canvas = np.zeros((H, W, 4), np.float32)
        x = (W - c.shape[1]) // 2; y = H - c.shape[0]            # centred, feet on the bottom edge
        canvas[y:y + c.shape[0], x:x + c.shape[1]] = c
        Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), 'RGBA').save('%s/%s/anim/idle_%02d.png' % (out, n, k))
    print(n, len(fr), (W, H))
