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

def defringe(im, band=7):
    """Paintings whose leaves blend into the magenta keep a pink rim 2-3 px wide. Within a few pixels of the cut,
    blue may not rise towards green and red may not run far above it (the leaf's own cast), and the cut is drawn in a pixel."""
    a = np.asarray(im).astype(np.float32) / 255
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    hole = Image.fromarray(((al < 0.5) * 255).astype(np.uint8))
    near = np.asarray(hole.filter(ImageFilter.MaxFilter(2 * band + 1))) > 0
    pink = (np.minimum(r, b) > g - 0.02)          # magenta that soaked into thin leaves further in: the same fix anywhere
    fix = near | pink
    b2 = np.where(fix, np.minimum(b, g - 0.05), b)
    r2 = np.where(fix, np.minimum(r, g + 0.09), r)
    al2 = np.asarray(Image.fromarray((al * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))).astype(np.float32) / 255
    return Image.fromarray((np.clip(np.dstack([r2, g, b2, al2]), 0, 1) * 255).astype(np.uint8), 'RGBA')
DEFRINGE = {'c2_home'}


def fade_foot(im, start=0.6, floor=(26, 19, 17)):
    """Darken the foot of a backdrop: a painting whose lower third is a busy foreground would fight the figures
    walking in front of it, so from `start` of its height down it sinks to near-black, as the other backdrops do."""
    a = np.asarray(im).astype(np.float32)
    h = a.shape[0]
    t = np.clip((np.arange(h) / h - start) / (0.86 - start), 0, 1)
    t = (t * t * (3 - 2 * t))[:, None, None]
    return Image.fromarray((a * (1 - t) + np.array(floor, np.float32) * t).astype(np.uint8))


FADE = {'c2_road': (26, 19, 17), 'c2_elah': (26, 19, 17), 'c2_court': (26, 19, 17), 'c2_yard': (118, 104, 88)}      # the yard by day sinks to trodden earth, not to dark
def pier(im, wide=96):
    """A wall band that repeats unmirrored: its left end becomes a pier standing a little proud of the wall
    (the wall's own stone from further along, lighter, with a shadow down its right side), so the join is an edge of masonry."""
    a = np.asarray(im).astype(np.float32)
    w = a.shape[1]
    src = a[:, w // 2:w // 2 + wide].copy()
    src[..., :3] = np.clip(src[..., :3] * 1.16 + 4, 0, 255)
    src[..., 3] = a[:, :wide, 3].max(axis=1, keepdims=True)          # as tall as the wall is here
    a[:, :wide] = src
    for k in range(14):                                                 # its shadow on the wall beside it
        a[:, wide + k, :3] *= 0.55 + 0.45 * k / 14
    a[:, :3, :3] *= 1.12; a[:, wide - 4:wide, :3] *= 0.8
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')
PIER = {'c2_gibeah'}
FEATHER = {'c2_gate', 'c2_gate_open', 'c2_hall_door'}

def fade_top(im, part=0.22):
    """A midground whose painting runs off its top edge (the olive crowns at the watch) would end in a straight line
    across the trees wherever the sky above it shows: the top fades out instead, into the backdrop's sky."""
    a = np.asarray(im).astype(np.float32)
    f = int(a.shape[0] * part)
    t = np.arange(f, dtype=np.float32) / f
    a[:f, :, 3] *= (t * t * (3 - 2 * t))[:, None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')
FADE_TOP = {'watch'}

names = sys.argv[1:] or sorted({os.path.basename(f).rsplit('_', 1)[0] for f in glob.glob(SRC + '/*_backdrop.png') + glob.glob(SRC + '/*_mid.png')})
for n in names:
    p = '%s/%s_backdrop.png' % (SRC, n)
    if os.path.exists(p):
        (lambda m: fade_foot(m, floor=FADE[n]) if n in FADE else m)(fit(Image.open(p).convert('RGB'), 5120, 2880)).save('art/%s_backdrop.png' % n); print('backdrop', n)
    p = '%s/%s_mid.png' % (SRC, n)
    if os.path.exists(p):
        (lambda m: fade_top(m) if n in FADE_TOP else m)((lambda m: pier(m) if n in PIER else m)((lambda m: defringe(m) if n in DEFRINGE else m)(key_magenta(fit(Image.open(p).convert('RGB'), 2560, 1440))))).save('art/%s_mid.png' % n); print('mid', n)

# props: tools/src/art_in/props/<name>.png on magenta -> art/props/<name>.png, cut out and trimmed to the object
for p in sorted(glob.glob(SRC + '/props/*.png')):
    n = os.path.basename(p)[:-4]
    if sys.argv[1:] and n not in sys.argv[1:]:
        continue
    im = key_magenta(Image.open(p).convert('RGB'))
    a = np.asarray(im)[..., 3] > 40
    ys = np.where(a.sum(axis=1) > 2)[0]; xs = np.where(a.sum(axis=0) > 2)[0]
    im = im.crop((max(xs[0] - 4, 0), max(ys[0] - 4, 0), xs[-1] + 5, ys[-1] + 5))
    if n in FEATHER:         # a piece of wall that stands in front of the wall band: its two ends melt into it
        px = np.asarray(im).astype(np.float32)
        w = px.shape[1]; k = int(w * 0.1)
        ramp = np.ones(w, np.float32); ramp[:k] = np.linspace(0, 1, k) ** 1.5; ramp[-k:] = ramp[:k][::-1]
        px[..., 3] *= ramp[None, :]
        im = Image.fromarray(px.astype(np.uint8))
    im.save('art/props/%s.png' % n); print('prop', n)
