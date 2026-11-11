"""Draws the game's maps from real elevation data, so every ridge and wadi is where it truly is.
Elevation: Mapzen/AWS "Terrain Tiles" (open data; mostly SRTM, public domain), cached in tools/src/dem.
  art/map_hills.png  the hills round Bethlehem, where Chapter One happens
  art/map_land.png   Judah from the coastal plain to the Dead Sea, for the wider story
The same boxes are written to data/map.json so the game can place markers by latitude and longitude."""
import os, math, json, subprocess
import numpy as np
from PIL import Image, ImageFilter
CACHE = 'tools/src/dem'
VIEWS = {'hills': dict(z=13, lon0=35.125, lon1=35.355, lat0=31.612, lat1=31.722),
         'land': dict(z=10, lon0=34.66, lon1=35.72, lat0=31.41, lat1=31.93)}
W, H = 2560, 1440

def tile_xy(lon, lat, z):
    n = 2 ** z
    x = (lon + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y

def fetch(z, x, y):
    p = '%s/%d_%d_%d.png' % (CACHE, z, x, y)
    if not os.path.exists(p):
        subprocess.run(['curl', '-sfL', '-o', p, 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png' % (z, x, y)], check=True)
    a = np.asarray(Image.open(p).convert('RGB')).astype(np.float32)
    return a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768

def elevation(v):
    z = v['z']
    xa, ya = tile_xy(v['lon0'], v['lat1'], z); xb, yb = tile_xy(v['lon1'], v['lat0'], z)
    tx0, ty0, tx1, ty1 = int(xa), int(ya), int(xb), int(yb)
    big = np.vstack([np.hstack([fetch(z, x, y) for x in range(tx0, tx1 + 1)]) for y in range(ty0, ty1 + 1)])
    crop = big[int((ya - ty0) * 256):int((yb - ty0) * 256), int((xa - tx0) * 256):int((xb - tx0) * 256)]
    im = Image.fromarray(crop).resize((W, H), Image.BICUBIC)      # Mercator rows are close enough to even at this size
    a = np.asarray(im).astype(np.float32)
    k = np.exp(-0.5 * (np.arange(-4, 5) / 1.4) ** 2); k /= k.sum()       # a light blur, so tile steps do not show as terraces
    a = np.apply_along_axis(lambda r: np.convolve(np.pad(r, 4, mode='edge'), k, mode='valid'), 1, a)
    return np.apply_along_axis(lambda c: np.convolve(np.pad(c, 4, mode='edge'), k, mode='valid'), 0, a)

def ramp(h, stops):
    out = np.zeros(h.shape + (3,), np.float32)
    for (h0, c0), (h1, c1) in zip(stops, stops[1:]):
        u = np.clip((h - h0) / (h1 - h0), 0, 1)[..., None]
        m = ((h >= h0) & (h <= h1))[..., None]
        out = np.where(m, np.array(c0) * (1 - u) + np.array(c1) * u, out)
    out = np.where((h < stops[0][0])[..., None], np.array(stops[0][1]), out)
    return np.where((h > stops[-1][0])[..., None], np.array(stops[-1][1]), out)

def draw(name, v):
    h = elevation(v)
    km_w = (v['lon1'] - v['lon0']) * 111.32 * math.cos(math.radians((v['lat0'] + v['lat1']) / 2))
    px = km_w * 1000 / W
    gy, gx = np.gradient(h, px)
    exag = 2.2 if name == 'hills' else 3.2
    nx, ny, nz = -gx * exag, -gy * exag, np.ones_like(h)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = np.array([-0.55, -0.6, 0.58])       # light from the north-west, as on a drawn map
    shade = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / norm, 0, 1)
    # parchment tones: pale on the heights, warm ochre down the wilderness, the Dead Sea a deep slate blue
    col = ramp(h, [(-430, (0.60, 0.50, 0.36)), (-200, (0.70, 0.58, 0.40)), (200, (0.80, 0.69, 0.50)),
                   (600, (0.86, 0.78, 0.60)), (900, (0.92, 0.87, 0.72)), (1050, (0.96, 0.93, 0.82))])
    col = col * (0.5 + 0.72 * shade[..., None])
    slope = np.sqrt(gx * gx + gy * gy)
    col = col * (1 - np.clip(slope * 0.9, 0, 0.35))[..., None]      # steep wadi walls read as ink
    sea = h < -398
    if name == 'land':
        col = np.where(sea[..., None], np.array((0.33, 0.43, 0.50)), col)
        med = (h <= 0.5) & (np.indices(h.shape)[1] < W * 0.25)
        col = np.where(med[..., None], np.array((0.36, 0.47, 0.54)), col)
    # worn edges and a little grain
    yy, xx = np.mgrid[0:H, 0:W]
    edge = np.minimum.reduce([xx, W - xx, yy, H - yy]) / 160.0
    col = col * (0.62 + 0.38 * np.clip(edge, 0, 1))[..., None]
    rng = np.random.default_rng(3)
    col = col + (rng.random((H, W, 1)) - 0.5) * 0.035
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save('art/map_%s.png' % name)
    print(name, 'heights', int(h.min()), 'to', int(h.max()), 'm;', round(km_w, 1), 'km wide')

os.makedirs(CACHE, exist_ok=True)
for n, v in VIEWS.items():
    draw(n, v)
