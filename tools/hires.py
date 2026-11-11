"""Rebuilds painted art at higher resolution from upscaled source paintings.
Each existing game image says where its object sits in the original sheet and what belongs to it;
the upscaled sheet supplies the detail. usage: hires.py <originals_dir> <upscaled_dir>"""
import sys, os
from PIL import Image, ImageFilter
import numpy as np
SRC, UP = sys.argv[1], sys.argv[2]
OUT = 2          # finished images are this many times the old ones

def arr(p, mode='RGB'): return np.asarray(Image.open(p).convert(mode)).astype(np.float32) / 255
def filt(x, f): return np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).filter(f)).astype(np.float32) / 255
def white_key(im):
    lo = im.min(axis=2); sat = im.max(axis=2) - lo
    return 1.0 - np.clip((lo - 0.84) / 0.1, 0, 1) * np.clip((0.14 - sat) / 0.07, 0, 1)
def resize(a, size, how=Image.LANCZOS):
    if a.ndim == 2: return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize(size, how)).astype(np.float32) / 255
    return np.dstack([resize(a[..., c], size, how) for c in range(a.shape[2])])

def locate(old, src):
    """Where in the original sheet (x, y, shrink) the old image was cut from."""
    oh, ow = old.shape[:2]; m = old[..., 3] > 0.98; best = None
    for s in (1, 2):
        small = resize(src, (src.shape[1] // s, src.shape[0] // s)) if s > 1 else src
        key = white_key(small) > 0.5
        H, W = small.shape[:2]
        if oh > H or ow > W: continue
        # coarse: slide over a thumbnail of both
        q = 8
        ko = resize(old[..., 3], (max(1, ow // q), max(1, oh // q))); ks = resize(key.astype(np.float32), (W // q, H // q))
        cand = []
        for y in range(0, ks.shape[0] - ko.shape[0] + 1):
            for x in range(0, ks.shape[1] - ko.shape[1] + 1):
                cand.append((float(np.abs(ks[y:y + ko.shape[0], x:x + ko.shape[1]] - ko).mean()), x * q, y * q))
        cand.sort()
        for _, cx, cy in cand[:3]:
            for y in range(max(0, cy - q), min(H - oh, cy + q) + 1):
                for x in range(max(0, cx - q), min(W - ow, cx + q) + 1):
                    d = float(np.abs(small[y:y + oh, x:x + ow] - old[..., :3])[m].mean()) if m.sum() else 1.0
                    if best is None or d < best[0]: best = (d, x * s, y * s, s)
    return best

def rebuild(old_path, src_name, up_name, mode, where=None, out_path=None):
    old = arr(old_path, 'RGBA'); src = arr('%s/%s' % (SRC, src_name)); up = arr('%s/%s' % (UP, up_name))
    k = up.shape[1] // src.shape[1]
    oh, ow = old.shape[:2]
    if where is None:
        d, x, y, s = locate(old, src)
    else:
        x, y, s = where; d = 0.0
    hi = up[y * k:(y + oh * s) * k, x * k:(x + ow * s) * k]
    size = (hi.shape[1], hi.shape[0])
    guide = resize(old[..., 3], size, Image.BICUBIC)
    near = filt(guide, ImageFilter.MaxFilter(2 * k + 1)) > 0.04            # nothing appears where the old image had nothing
    if mode == 'dark':                                                      # foliage painted dark on white: darkness is coverage
        al = np.clip((1 - hi.min(axis=2)) / 0.3, 0, 1); al = al * al * (3 - 2 * al)
        rgb = np.clip(np.where(al[..., None] > 0.01, (hi - (1 - al[..., None])) / np.maximum(al[..., None], 0.01), hi), 0, 1) * (al[..., None] ** 0.8)
        al = al * near
    else:
        al = filt(filt(white_key(hi), ImageFilter.MinFilter(5)), ImageFilter.GaussianBlur(1.2))
        inside = filt((guide > 0.97).astype(np.float32), ImageFilter.MinFilter(4 * k + 1))     # pale stone inside an object stays solid
        al = np.maximum(al * near, inside)
        solid = filt((al > 0.97).astype(np.float32), ImageFilter.MinFilter(5))
        den = filt(solid, ImageFilter.GaussianBlur(5))
        ext = np.dstack([filt(hi[..., c] * solid, ImageFilter.GaussianBlur(5)) for c in range(3)]) / np.maximum(den[..., None], 0.02)
        rgb = np.where((solid[..., None] > 0.5) | (den[..., None] < 0.03), hi, ext)       # edge pixels take colour from inside, never the white
    pm = np.dstack([rgb * al[..., None], al])
    pm = resize(pm, (ow * OUT, oh * OUT))
    a2 = pm[..., 3]; rgb2 = np.where(a2[..., None] > 0.004, pm[..., :3] / np.maximum(a2[..., None], 0.004), 0)
    Image.fromarray((np.clip(np.dstack([rgb2, a2]), 0, 1) * 255).astype(np.uint8), 'RGBA').save(out_path or old_path)
    print(os.path.basename(old_path), 'from', src_name, 'at', (x, y), 'shrink', s, 'match', round(d, 3), '->', (ow * OUT, oh * OUT))

if __name__ == '__main__':
    P = 'art/props/'
    rebuild('art/s1_mid.png', None, 'mid_a.png', 'dark', (0, 0, 1)) if False else None
    rebuild('art/s2_mid.png', 's2_mid.png', 'mid_d.png', 'dark', (0, 0, 1))
    rebuild('art/s3_mid.png', 's3_mid.png', 'mid_c.png', 'dark', (0, 0, 1))
    rebuild('art/s4_town.png', 's4_town.png', 'mid_b.png', 'white', (0, 266, 1))
    rebuild(P + 'bush.png', 'props.png', 'sh_d.png', 'dark')
    for n in ['jar', 'cairn', 'fold']: rebuild(P + n + '.png', 'props.png', 'sh_d.png', 'white')
    for n in ['rock_low', 'rock_mid', 'rock_tall']: rebuild(P + n + '.png', 'outcrops.png', 'sh_c.png', 'white')
    for n in ['d_boulder', 'd_flowers', 'd_grass', 'd_shrub', 'd_log', 'd_stones']: rebuild(P + n + '.png', 'dressing.png', 'sh_b.png', 'white')
    for n in ['bridge', 'deadtree']: rebuild(P + n + '.png', 'bridge.png', 'sh_a.png', 'white')
