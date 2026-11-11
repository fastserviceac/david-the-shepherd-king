"""Green/blue-screen video frames -> aligned sprite frames.
usage: anim.py <frames_dir> <out_dir> <name> key=green|blue|magenta mode=loop|range [a= b= step=] hframe=N | href=PIXELS
       size=150 res=2 feet=global|each wide=1.4 tall=1.65 double=0|1 halo=0|1 erode=5 inner=8
size is the figure's height in game units; res is how many image pixels go to one unit."""
import sys, os, glob
from PIL import Image, ImageFilter
import numpy as np
src, out, name = sys.argv[1:4]
opt = dict(key='green', mode='loop', a='0', b='0', step='1', hframe='-1', size='150', feet='global', wide='1.4', tall='1.65',
           double='0', halo='1', erode='5', inner='8', res='2', white='0', href='0', soft='0', steady='7', rim='0')
opt.update(dict(x.split('=') for x in sys.argv[4:]))
files = sorted(glob.glob(src + '/f*.png'))

def filt(x, f):
    return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(f)).astype(np.float32) / 255

def load(path):
    return np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255

def mask(im):
    """Rough cut: how much of each pixel is screen."""
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    if opt['key'] == 'magenta':
        q = np.minimum(r, b) / (g + 0.04)
        bg = np.clip((q - 1.5) / 0.7, 0, 1) * np.clip((np.minimum(r, b) - 0.3) / 0.12, 0, 1)
    elif opt['key'] == 'blue':
        q = b / (np.maximum(r, g) + 0.04)
        bg = np.clip((q - 1.25) / 0.45, 0, 1) * np.clip((b - 0.1) / 0.08, 0, 1)
        grown = bg > 0.5; bluish = b > r * 1.04       # the pale glow the video puts round the animal
        for _ in range(14):
            grown = grown | ((filt(grown.astype(np.float32), ImageFilter.MaxFilter(3)) > 0.5) & bluish)
        bg = np.maximum(bg, grown.astype(np.float32))
    elif opt['halo'] == '1':
        q = g / (b + 0.04)
        bg = np.clip((q - 2.2) / 1.2, 0, 1) * np.clip((g - 0.28) / 0.1, 0, 1) * np.clip((g - r * 0.8) / 0.08, 0, 1)
    elif opt['halo'] == '2':     # a dark or unevenly lit green screen: judge by how green, not how bright
        q = g / (np.maximum(r, b) + 0.02)
        bg = np.clip((q - 1.35) / 0.35, 0, 1) * np.clip((g - 0.08) / 0.06, 0, 1)
    else:
        q = g / (np.maximum(r, b) + 0.03)
        bg = np.clip((q - 1.15) / 0.3, 0, 1) * np.clip((g - 0.2) / 0.1, 0, 1)
    if opt['white'] == '1':        # painted motion streaks and dust in the clip are not part of the animal
        lo = im.min(axis=2); sat = im.max(axis=2) - lo
        pale = np.clip((lo - 0.45) / 0.15, 0, 1) * np.clip((0.3 - sat) / 0.12, 0, 1)
        bg = np.maximum(bg, filt(pale, ImageFilter.MaxFilter(5)))
    a = filt(filt(1.0 - bg, ImageFilter.MinFilter(int(opt['erode']))), ImageFilter.GaussianBlur(1.0))
    return bg, a

def soft_cut(im):
    """Light-touch cut for David: the footage is sharp, so every pixel of him is kept as filmed.
    Screen green and the yellow-green glow some clips put round him become transparent; the thin
    edge that mixes figure and screen is un-mixed against the screen colour; nothing is blurred."""
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    green = np.clip((g / (np.maximum(r, b) + 0.02) - 1.18) / 0.22, 0, 1) * np.clip((g - 0.07) / 0.05, 0, 1)
    # glow: yellow-green, which nothing he wears or his skin ever is (those are all redder than green)
    # (skin and cloth always carry more blue, or are far redder, than this yellow)
    lo2 = np.minimum(r, g)
    glow = np.clip((lo2 * 0.52 - b) / 0.05, 0, 1) * np.clip((g - r * 0.70) / 0.05, 0, 1) * np.clip((g - 0.22) / 0.06, 0, 1)
    bg = np.maximum(green, glow)
    if int(opt['rim']) > 0:      # some clips put a pale grey-green rim round him: eat inward from the screen while pixels stay greener than red
        grown = bg > 0.5; greenish = (g >= r * 0.97) & (g > b)
        for _ in range(int(opt['rim'])):
            grown = grown | ((filt(grown.astype(np.float32), ImageFilter.MaxFilter(3)) > 0.5) & greenish)
        bg = np.maximum(bg, grown.astype(np.float32))
    a = 1.0 - bg
    a = filt(a, ImageFilter.MinFilter(3))                       # one pixel in, off the mixed edge
    a = filt(a, ImageFilter.GaussianBlur(0.6))
    a[:, :6] = 0; a[:, -6:] = 0; a[:6, :] = 0; a[-6:, :] = 0   # the outermost pixels of a clip are off-colour and would cut as a faint line
    sel = green > 0.97
    S = np.median(im[sel], axis=0) if sel.sum() > 500 else np.array([0.05, 0.4, 0.03], np.float32)
    # un-mix the edge pixels: remove the screen's share of the colour
    aa = np.clip(a, 0.3, 1.0)[..., None]
    rgb = np.where(a[..., None] < 0.985, (im - (1.0 - aa) * S) / aa, im)
    rgb = np.clip(rgb, 0, 1)
    # any green cast left on an edge pixel is pulled down to its red/blue level
    edge = a < 0.985
    gg = np.where(edge, np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2])), rgb[..., 1])
    gg = np.where(edge, np.maximum(gg, (rgb[..., 0] + rgb[..., 2]) * 0.36), gg)      # and never pushed so low it turns pink
    rgb = np.dstack([rgb[..., 0], gg, rgb[..., 2]])
    return bg, rgb, a


def clean(im, bg, a):
    """Final cut. Colour is only trusted well inside the figure. Everywhere nearer the edge the
    pixel is treated as a mix of the figure's own colour (taken from inside) and the screen,
    and is un-mixed: the screen's share becomes transparency, never a coloured rim."""
    D = int(opt['inner'])
    solid = filt((a > 0.97).astype(np.float32), ImageFilter.MinFilter(2 * D + 1))
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    if opt['key'] == 'green': spill = g > np.maximum(r, b) * 1.06 + 0.02        # screen colour showing through fur or blur
    elif opt['key'] == 'blue': spill = b > np.maximum(r, g) * 1.06 + 0.02
    else: spill = np.zeros_like(solid) > 1
    solid = solid * (1.0 - filt(spill.astype(np.float32), ImageFilter.MaxFilter(5)))
    sel = bg > 0.95
    S = np.median(im[sel], axis=0) if sel.sum() > 500 else np.array([0.1, 0.8, 0.1], np.float32)
    rgb = im.copy(); alpha = a.copy(); have = solid.copy()
    for rad in (D * 0.8 + 1, D * 2.0 + 2, D * 5.0 + 4):       # widening passes reach thin parts: legs, tail, staff
        den = filt(solid, ImageFilter.GaussianBlur(rad))
        F = np.dstack([filt(im[..., c] * solid, ImageFilter.GaussianBlur(rad)) for c in range(3)]) / np.maximum(den[..., None], 0.02)
        d = F - S
        am = np.clip(((im - S) * d).sum(axis=2) / np.maximum((d * d).sum(axis=2), 0.01), 0, 1)
        un = (im - (1.0 - am[..., None]) * S) / np.maximum(am[..., None], 0.25)          # the figure's share of the pixel
        lum = np.clip(un.mean(axis=2, keepdims=True) / np.maximum(F.mean(axis=2, keepdims=True), 0.02), 0.6, 1.25)
        take = (have < 0.5) & (den > 0.04)
        rgb = np.where(take[..., None], F * lum, rgb)
        alpha = np.where(take, np.minimum(alpha, np.clip((am - 0.08) / 0.4, 0, 1)), alpha)
        have = np.maximum(have, take.astype(np.float32))
    # thin parts far from the body (a tail, the tip of the staff) keep the rough cut, with the screen colour taken out
    far = have < 0.5
    k = {'green': 1, 'blue': 2}.get(opt['key'], -1)
    if k >= 0:
        others = np.maximum(im[..., (k + 1) % 3], im[..., (k + 2) % 3])
        fixed = im.copy(); fixed[..., k] = np.minimum(im[..., k], others * 1.02)
        rgb = np.where(far[..., None], fixed, rgb)
    return np.clip(rgb, 0, 1), filt(alpha, ImageFilter.GaussianBlur(0.7))

def info(path):
    if opt['soft'] == '1':
        bg, _rgb, a = soft_cut(load(path))
    else:
        bg, a = mask(load(path))
    m = a > 0.5
    m[:6] = False; m[-6:] = False; m[:, :6] = False; m[:, -6:] = False
    ys = np.where(m.sum(axis=1) > 3)[0]
    if len(ys) < 10: return None
    # body centre: the densest columns, so a staff or tail does not pull it off
    col = m.sum(axis=0).astype(np.float32); thick = col > col.max() * 0.45
    cx = (thick * np.arange(m.shape[1])).sum() / max(thick.sum(), 1)
    return dict(path=path, a=a.astype(np.float16), top=ys[0], bot=ys[-1], cx=cx)

a_i, b_i, step = int(opt['a']), int(opt['b']), int(opt['step'])
use = files if opt['mode'] == 'loop' else files[a_i:b_i + 1]
frames = [f for f in (info(p) for p in use) if f]
# The body centre is measured frame by frame, and a flaring cloak or a swung arm throws it off for a frame or two,
# which showed as the figure twitching sideways. Take a running median so only real, lasting movement is followed.
if len(frames) > 4:
    cxs = np.array([f['cx'] for f in frames], np.float32); w = int(opt['steady'])
    for i, f in enumerate(frames):
        f['cx'] = float(np.median(cxs[max(0, i - w):i + w + 1]))
hf = int(opt['hframe'])
if hf >= 0:
    h0 = info(files[hf]); H = h0['bot'] - h0['top']
else:
    H = int(np.median([f['bot'] - f['top'] for f in frames]))
if int(opt['href']) > 0: H = int(opt['href'])       # one fixed figure height for every set cut from the same camera
ground = int(np.percentile([f['bot'] for f in frames], 90))
half = int(H * float(opt['wide'])); up = int(H * float(opt['tall'])); below = int(H * 0.1)

def crop(f, full):
    cx = int(f['cx']); base = f['bot'] if opt['feet'] == 'each' else ground
    if full:
        im = load(f['path'])
        if opt['soft'] == '1':
            bg, rgb, a = soft_cut(im)
        else:
            bg, a = mask(im); rgb, a = clean(im, bg, a)
        rgba = np.dstack([rgb, a])
    else:
        rgba = f['a'].astype(np.float32)[..., None]
    pad = np.zeros((rgba.shape[0] + 2 * (up + below), rgba.shape[1] + 2 * half, rgba.shape[2]), np.float32)
    pad[up + below:up + below + rgba.shape[0], half:half + rgba.shape[1]] = rgba
    y1 = base + below + up + below; y0 = y1 - up - below
    return pad[y0:y1, cx:cx + 2 * half]

if opt['mode'] == 'loop':
    small = [np.asarray(Image.fromarray((crop(f, False)[..., 0] * 255).astype(np.uint8)).resize((60, 60))).astype(np.float32) / 255 for f in frames]
    n = len(small); best = None
    for P in range(8, min(60, n // 2)):
        d = np.mean([np.abs(small[i] - small[i + P]).mean() for i in range(n - P)])
        if best is None or d < best[0] * 0.95: best = (d, P)
    P = best[1] * (2 if opt['double'] == '1' else 1)
    P = min(P, n - n // 4 - 1)
    s = int(np.argmin([np.abs(small[i] - small[i + P]).mean() for i in range(n // 4, n - P)])) + n // 4
    sel = frames[s:s + P:step]
    print(name, 'loop period', P, 'start', s, 'score', round(best[0], 4))
else:
    sel = frames[::step]
os.makedirs(out, exist_ok=True)
for old in glob.glob('%s/%s_[0-9]*.png' % (out, name)) + glob.glob('%s/%s_[0-9]*.png.import' % (out, name)):
    os.remove(old)      # the .import files too: Godot goes on loading a deleted frame from its cache while one is left behind
sc = float(opt['size']) * float(opt['res']) / H
imgs = []
for k, f in enumerate(sel):
    c = crop(f, True)
    im = Image.fromarray((np.clip(c, 0, 1) * 255).astype(np.uint8), 'RGBA')
    im = im.resize((int(c.shape[1] * sc), int(c.shape[0] * sc)), Image.LANCZOS)
    im.save('%s/%s_%02d.png' % (out, name, k)); imgs.append(im)
pick = imgs[::max(1, len(imgs) // 8)]
cs = Image.new('RGBA', (sum(p.width for p in pick), pick[0].height), (70, 70, 95, 255)); x = 0
for p in pick: cs.alpha_composite(p, (x, 0)); x += p.width
cs.save(src + '/../sheet_%s.png' % name)
print(name, 'frames', len(imgs), 'canvas', imgs[0].size, 'native height', H)
