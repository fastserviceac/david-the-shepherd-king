"""Tidies the bear's rear-up and swipe frames: drops streaks and dust not joined to the bear,
and shifts the colour to match the walking bear."""
import glob
from PIL import Image, ImageFilter
import numpy as np
def filt(x, f): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(f)).astype(np.float32) / 255
def stats(files):
    px = np.concatenate([(lambda a: a[a[:, 3] > 0.9][:, :3])(np.asarray(Image.open(f)).reshape(-1, 4).astype(np.float32) / 255) for f in files])
    return px.mean(axis=0), px.std(axis=0)
walk_m, walk_s = stats(sorted(glob.glob('art/bear/anim/walk_*.png'))[::6])
files = sorted(glob.glob('art/bear/anim/rear_*.png')) + sorted(glob.glob('art/bear/anim/swipe_*.png'))
cleaned = []
for f in files:
    im = np.asarray(Image.open(f)).astype(np.float32) / 255
    rgb, a = im[..., :3], im[..., 3]
    # grey streaks and dust: pale, colourless pixels with no brown fur around them
    lo = rgb.min(axis=2); sat = rgb.max(axis=2) - lo
    fur = filt(((a > 0.5) & (sat > 0.2)).astype(np.float32), ImageFilter.GaussianBlur(7))
    grey = np.clip((0.16 - sat) / 0.06, 0, 1) * np.clip((lo - 0.2) / 0.08, 0, 1) * np.clip((0.75 - fur) / 0.25, 0, 1)
    a = a * (1.0 - filt(grey, ImageFilter.MaxFilter(7)))
    # keep only what is joined to the body
    h, w = a.shape; q = 4
    small = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((w // q, h // q), Image.BILINEAR)).astype(np.float32) / 255
    body = small > 0.5
    core = filt(body.astype(np.float32), ImageFilter.MinFilter(9)) > 0.5
    reach = core.copy()
    for _ in range(120):
        grown = (filt(reach.astype(np.float32), ImageFilter.MaxFilter(3)) > 0.5) & body
        if (grown == reach).all(): break
        reach = grown
    keep = np.asarray(Image.fromarray((filt(reach.astype(np.float32), ImageFilter.MaxFilter(3)) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)).astype(np.float32) / 255
    cleaned.append((f, rgb, a * np.clip(keep * 2.0, 0, 1)))
px = np.concatenate([r[al > 0.9] for _, r, al in cleaned[::3]])
def chroma(p): return float(np.abs(p - p.mean(axis=1, keepdims=True)).mean())
walk_px = np.concatenate([(lambda q: q[q[:, 3] > 0.9][:, :3])(np.asarray(Image.open(f)).reshape(-1, 4).astype(np.float32) / 255) for f in sorted(glob.glob('art/bear/anim/walk_*.png'))[::6]])
K = min(1.0, chroma(walk_px) / chroma(px))
pl = px.mean(axis=1, keepdims=True); M2 = (pl + (px - pl) * K).mean(axis=0)
for f, rgb, a in cleaned:
    luma = rgb.mean(axis=2, keepdims=True)
    rgb = luma + (rgb - luma) * K                           # same strength of colour as the walking bear
    rgb = np.clip(rgb + (walk_m - M2), 0, 1)
    Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), 'RGBA').save(f)
print('bear frames tidied', len(cleaned))
