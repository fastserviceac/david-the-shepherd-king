"""Samuel's anointing frames: the oil is poured onto David's head, so the stream is ended at head height
(the clip let it run to the ground, where the screen colour also stained it)."""
import glob
from PIL import Image, ImageFilter
import numpy as np
TALL, FIG = 1.45, 552.0        # canvas factor and figure height in pixels, as cut by anim.py
for f in sorted(glob.glob('art/samuel/anim/anoint_*.png')):
    im = np.asarray(Image.open(f)).astype(np.float32) / 255
    h, w = im.shape[:2]
    ground = h * TALL / (TALL + 0.1)
    y0 = int(ground - 0.50 * FIG); x0 = int(w / 2 + 0.2 * FIG)
    gone = np.zeros((h, w), np.float32); gone[y0:, x0:] = 1
    soft = np.asarray(Image.fromarray((gone * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))).astype(np.float32) / 255
    im[..., 3] *= 1.0 - np.clip(soft * 1.6, 0, 1)
    # what is left of the stream is golden oil, never pink
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    front = np.zeros((h, w), bool); front[:, x0:] = True
    pink = front & (b > g * 1.05)
    im[..., 2] = np.where(pink, g * 0.45, b)
    Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8), 'RGBA').save(f)
print('anoint frames fixed')
