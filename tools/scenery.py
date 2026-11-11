"""Turns the paintings in tools/src/art_in into game scenery.
  <name>_backdrop.png -> art/<name>_backdrop.png, 5120x2880 (cropped to 16:9, enlarged)
  <name>_mid.png      -> art/<name>_mid.png, 2560x1440 with the flat magenta sky cut away
usage: scenery.py [name ...]   (no names: every painting found)"""
import sys, glob, os
import numpy as np
from PIL import Image, ImageFilter
SRC = 'tools/src/art_in'

def fit(im, w, h):
    r = w / h
    if im.width / im.height > r:
        nw = int(im.height * r); x = (im.width - nw) // 2; im = im.crop((x, 0, x + nw, im.height))
    else:
        nh = int(im.width / r); y = (im.height - nh) // 2; im = im.crop((0, y, im.width, y + nh))
    return im.resize((w, h), Image.LANCZOS)

def key_magenta(im):
    a = np.asarray(im.convert('RGB')).astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(r, b) - g                       # how magenta a pixel is
    bg = np.clip((m - 0.10) / 0.22, 0, 1) * np.clip((np.minimum(r, b) - 0.35) / 0.15, 0, 1)
    alpha = Image.fromarray(((1 - bg) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    al = np.asarray(alpha).astype(np.float32) / 255
    # take the pink cast off edge pixels: red and blue may not exceed green by much where the cut is soft
    edge = (al < 0.98) | (m > 0.04)
    cap = g + 0.06
    r2 = np.where(edge, np.minimum(r, np.maximum(cap, r - m)), r)
    b2 = np.where(edge, np.minimum(b, np.maximum(cap, b - m)), b)
    pink = m > 0.05          # screen colour that soaked into thin things like grass tips: pull it back to a dry-grass tone
    r2 = np.where(pink, np.minimum(r2, g * 1.25), r2)
    b2 = np.where(pink, np.minimum(b2, g * 0.8), b2)
    out = np.dstack([r2, g, b2, al])
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGBA')

names = sys.argv[1:] or sorted({os.path.basename(f).rsplit('_', 1)[0] for f in glob.glob(SRC + '/*_backdrop.png') + glob.glob(SRC + '/*_mid.png')})
for n in names:
    p = '%s/%s_backdrop.png' % (SRC, n)
    if os.path.exists(p):
        fit(Image.open(p).convert('RGB'), 5120, 2880).save('art/%s_backdrop.png' % n); print('backdrop', n)
    p = '%s/%s_mid.png' % (SRC, n)
    if os.path.exists(p):
        key_magenta(fit(Image.open(p).convert('RGB'), 2560, 1440)).save('art/%s_mid.png' % n); print('mid', n)

# props: tools/src/art_in/props/<name>.png on magenta -> art/props/<name>.png, cut out and trimmed to the object
for p in sorted(glob.glob(SRC + '/props/*.png')):
    n = os.path.basename(p)[:-4]
    if sys.argv[1:] and n not in sys.argv[1:]:
        continue
    im = key_magenta(Image.open(p).convert('RGB'))
    a = np.asarray(im)[..., 3] > 40
    ys = np.where(a.sum(axis=1) > 2)[0]; xs = np.where(a.sum(axis=0) > 2)[0]
    im.crop((max(xs[0] - 4, 0), max(ys[0] - 4, 0), xs[-1] + 5, ys[-1] + 5)).save('art/props/%s.png' % n); print('prop', n)
