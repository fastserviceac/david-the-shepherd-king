"""The yard of Gibeah by day, from what was painted for dusk: the wall band and the door of the hall are re-lit
with one and the same change of colour, taken from the wall, so they still belong together. Each channel is moved
to the pale grey-gold of the morning backdrop's stone and its contrast kept a little lower.
The wall band's pier (which carries its join at dusk) shows as a seam in daylight, so here the band is made to
repeat without one: the pier is cut off and the band's two ends are cross-faded over each other.
The ground is a painted earth texture (tools/src/art_in/c2/c2_yard_ground.png), made to repeat the same way.
usage: python3 tools/yard_day.py"""
from PIL import Image
import numpy as np
TARGET = np.array([158.0, 146.0, 130.0]); SPREAD = np.array([40.0, 38.0, 36.0])
wall = np.asarray(Image.open('art/c2_gibeah_mid.png').convert('RGBA')).astype(np.float32)
solid = wall[..., 3] > 200
mean = wall[solid][:, :3].mean(0); std = wall[solid][:, :3].std(0)

def lit(a):
    a = a.copy(); a[..., :3] = np.clip((a[..., :3] - mean) * (SPREAD / std) + TARGET, 0, 255); return a

def wrap_x(a, over):
    """Make `a` repeat left to right: its last `over` columns are faded into its first."""
    w = a.shape[1]; t = np.linspace(0, 1, over, dtype=np.float32)[None, :, None]; t = t * t * (3 - 2 * t)
    out = a[:, :w - over].copy(); out[:, :over] = a[:, w - over:] * (1 - t) + a[:, :over] * t
    return out

def save(a, path, size=None):
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    if size: im = im.resize(size, Image.LANCZOS)
    im.save(path); print(path)

save(wrap_x(lit(wall[:, 124:]), 260), 'art/c2_yard_mid.png', (2560, 1440))
save(lit(np.asarray(Image.open('art/props/c2_hall_door.png').convert('RGBA')).astype(np.float32)), 'art/props/c2_hall_door_day.png')
g = np.asarray(Image.open('tools/src/art_in/c2/c2_yard_ground.png').convert('RGB').resize((1376, 768), Image.LANCZOS)).astype(np.float32)
low = np.asarray(Image.fromarray(g.astype(np.uint8)).resize((16, 9), Image.BILINEAR).resize((1376, 768), Image.BICUBIC)).astype(np.float32)
g = g - low + low.reshape(-1, 3).mean(0)                      # no light or dark patches to repeat
g = (g - g.reshape(-1, 3).mean(0)) * 0.8 + np.array([170.0, 153.0, 128.0])
g = wrap_x(g, 200); g = np.swapaxes(wrap_x(np.swapaxes(g, 0, 1), 160), 0, 1)
save(g, 'art/ground_yard.png')
