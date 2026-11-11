"""The upscaler tinted Samuel's robe with the pink of the screen. This keeps the upscaled frames' fine detail
and edge, but takes colour from the same frames cut from the original clip.
usage: anoint_colour.py <dir of frames cut from the original clip>"""
import sys, glob, os
from PIL import Image, ImageFilter
import numpy as np
low_dir = sys.argv[1]
def blur(x, r): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255
for f in sorted(glob.glob('art/samuel/anim/anoint_*.png')):
    hi = np.asarray(Image.open(f)).astype(np.float32) / 255
    lo = Image.open(os.path.join(low_dir, os.path.basename(f))).resize((hi.shape[1], hi.shape[0]), Image.BICUBIC)
    lo = np.asarray(lo).astype(np.float32) / 255
    y = hi[..., :3].mean(axis=2)
    detail = (y - blur(y, 2.5)) * 1.0                       # fine detail only
    rgb = np.clip(lo[..., :3] + detail[..., None], 0, 1)
    a = np.minimum(hi[..., 3], blur(lo[..., 3], 1.5) * 1.6).clip(0, 1)
    Image.fromarray((np.dstack([rgb, a]) * 255).astype(np.uint8), 'RGBA').save(f)
print('anoint colours restored')
