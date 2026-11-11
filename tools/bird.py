"""Cuts the six wing positions of the bird sheet (magenta screen, lower row) into aligned frames.
usage: bird.py <sheet.png>   ->  art/bird/anim/fly_00.png ..."""
import sys, os
from PIL import Image, ImageFilter
import numpy as np
im = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(np.float32) / 255
H, W = im.shape[:2]
row = im[int(H * 0.33):int(H * 0.70)]                      # the lower of the two rows of birds
r, g, b = row[..., 0], row[..., 1], row[..., 2]
q = np.minimum(r, b) / (g + 0.04)
bg = np.clip((q - 1.5) / 0.7, 0, 1) * np.clip((np.minimum(r, b) - 0.3) / 0.12, 0, 1)
a = 1.0 - bg
a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
rgb = np.dstack([np.minimum(r, np.maximum(g, b) * 1.05), g, b])      # the screen's pink never stays on a feather edge
m = a > 0.5
cols = m.sum(axis=0) > 3
runs = []; start = None; gap = 0; last = 0
for x in range(W + 1):
    on = x < W and cols[x]
    if on:
        if start is None: start = x
        last = x; gap = 0
    elif start is not None:
        gap += 1
        if gap > 40 or x == W:
            if last - start > 150: runs.append((start, last + 1))
            start = None
print('birds found', len(runs))
os.makedirs('art/bird/anim', exist_ok=True)
CW, CH, AX, AY = 760, 760, 680, 380           # canvas, and where the beak tip sits on it
for k, (x0, x1) in enumerate(runs[:6]):
    # wing tips of the upper row poke into the top of this strip: drop anything joined to the top edge
    occ = m[:, x0:x1].sum(axis=1) > 0
    if occ[:4].any():
        end = int(np.argmax(~occ))          # first empty row
        m[:end, x0:x1] = False; a[:end, x0:x1] = 0
    sub = m[:, x0:x1]
    xr = np.where(sub.sum(axis=0) > 0)[0][-1] + x0
    ys = np.where(m[:, xr - 8:xr + 1].sum(axis=1) > 0)[0]; yr = int(ys.mean())
    canvas = np.zeros((CH, CW, 4), np.float32)
    ys_all = np.where(sub.sum(axis=1) > 0)[0]; y0, y1 = ys_all[0], ys_all[-1] + 1
    piece = np.dstack([rgb[y0:y1, x0:x1], a[y0:y1, x0:x1]])
    px, py = AX - (xr - x0), AY - (yr - y0)
    px0, py0 = max(0, px), max(0, py)
    hh = min(piece.shape[0] - (py0 - py), CH - py0); ww = min(piece.shape[1] - (px0 - px), CW - px0)
    canvas[py0:py0 + hh, px0:px0 + ww] = piece[py0 - py:py0 - py + hh, px0 - px:px0 - px + ww]
    out = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), 'RGBA').resize((CW // 4, CH // 4), Image.LANCZOS)
    out.save('art/bird/anim/fly_%02d.png' % k)
print('frames written', min(6, len(runs)), out.size)
