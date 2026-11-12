"""Writes what the 3D map of the hills needs, from the same real elevation data as tools/realmap.py:
  art/map_hills_height.png  elevation on a 384x216 grid, 16 bits in the red (high byte) and green (low byte) channels
  art/map_hills_ground.png  the ground's own colours: olive and field-green on the ridge where Bethlehem's farmland
                            is, paling through dry grass to the bare ochre and chalk of the wilderness to the east
The lowest and highest elevations are written into data/map.json ("relief") so the game can turn the bytes back to metres."""
import sys, json, math
import numpy as np
from PIL import Image
sys.argv = sys.argv[:1]
src = open('tools/realmap.py').read().split("os.makedirs(CACHE")[0]
exec(src)
v = VIEWS['hills']
h = elevation(v)                       # 1440 x 2560, metres
GW, GH = 384, 216
small = np.asarray(Image.fromarray(h).resize((GW, GH), Image.BICUBIC)).astype(np.float32)
lo, hi = float(small.min()), float(small.max())
q = np.round((small - lo) / (hi - lo) * 65535).astype(np.uint32)
rgb = np.zeros((GH, GW, 3), np.uint8); rgb[..., 0] = q >> 8; rgb[..., 1] = q & 255
Image.fromarray(rgb).save('art/map_hills_height.png')

km_w = (v['lon1'] - v['lon0']) * 111.32 * math.cos(math.radians((v['lat0'] + v['lat1']) / 2))
gy, gx = np.gradient(h, km_w * 1000 / W)
slope = np.sqrt(gx * gx + gy * gy)
yy, xx = np.mgrid[0:H, 0:W]
east = xx / W
# how green the ground is: the watershed ridge catches the rain, and it fails quickly east of it
green = np.clip((h - 560) / 260, 0, 1) * np.clip(1 - (east - 0.30) / 0.30, 0, 1)
rng = np.random.default_rng(5)
noise = np.asarray(Image.fromarray(rng.random((H // 8, W // 8)).astype(np.float32)).resize((W, H), Image.BICUBIC))
fine = rng.random((H, W)).astype(np.float32)
green = np.clip(green + (noise - 0.5) * 0.35, 0, 1)[..., None]
dry = ramp(h, [(150, (0.62, 0.50, 0.36)), (400, (0.74, 0.62, 0.44)), (650, (0.80, 0.71, 0.52)), (900, (0.84, 0.77, 0.60))])
lush = ramp(h, [(500, (0.52, 0.52, 0.30)), (750, (0.40, 0.46, 0.24)), (900, (0.46, 0.50, 0.28))])
col = dry * (1 - green) + lush * green
col = col * (1 - np.clip(slope * 0.7, 0, 0.28))[..., None]           # steep wadi walls are bare, darker rock
bed = np.clip(1 - slope * 9, 0, 1) * np.clip((560 - h) / 200, 0, 1)   # flat low ground: pale wadi gravel
nx, ny = -gx * 2.0, -gy * 2.0
shade = np.clip((nx * -0.55 + ny * -0.6 + 0.58) / np.sqrt(nx * nx + ny * ny + 1), 0, 1)    # a soft painted shadow, north-west light
col = col * (0.50 + 0.66 * shade[..., None])
col = col + bed[..., None] * np.array((0.10, 0.09, 0.07))
col = col + ((noise - 0.5) * 0.06 + (fine - 0.5) * 0.04)[..., None]
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).resize((2048, 1152), Image.LANCZOS).save('art/map_hills_ground.png')
d = json.load(open('data/map.json')); d['relief'] = {'lo': round(lo, 1), 'hi': round(hi, 1), 'w': GW, 'h': GH, 'km': round(km_w, 2)}
json.dump(d, open('data/map.json', 'w'), indent=1, ensure_ascii=False)
print('relief', round(lo), 'to', round(hi), 'm on', GW, 'x', GH)
