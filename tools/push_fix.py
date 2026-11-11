"""The pushing clip was filmed with a boulder in David's arms. This takes the boulder out of the cut frames, so the
same braced pose can be used against whatever he is pushing in the game. Run after cutting the `push` set."""
import glob
import numpy as np
from PIL import Image, ImageFilter
for f in sorted(glob.glob('art/david/anim/push_*.png')):
    a = np.asarray(Image.open(f).convert('RGBA')).astype(np.float32) / 255
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx = np.maximum(np.maximum(r, g), b); mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / (mx + 1e-3); lum = (r + g + b) / 3
    H, W = al.shape; yy, xx = np.mgrid[0:H, 0:W]
    ys = np.where(al.sum(axis=1) > 3)[0]; top, bot = ys[0], ys[-1]
    hair = (al > 0.5) & (lum < 0.14) & (yy < top + 60)
    hx = np.where(hair.sum(axis=0) > 2)[0]; edge = hx[-1] if len(hx) else W // 2
    region = ((xx > edge - 4) | ((xx > edge - 34) & (yy > top + 38))) & (yy < top + (bot - top) * 0.5)       # in front of his face and chest
    keep = (sat > 0.36) & (lum > 0.2)                                # skin and cloak; the stone is grey and dull
    keep = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))) > 127
    a[..., 3] = np.where(region & ~keep, 0, al)
    solid = Image.fromarray((a[..., 3] * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(7))
    a[..., 3] = np.where(region, np.minimum(a[..., 3], np.asarray(solid).astype(np.float32) / 255), a[..., 3])      # stray specks go too
    Image.fromarray((a * 255).astype(np.uint8)).save(f)
print('boulder removed from the push frames')
