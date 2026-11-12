"""Paints a rain pool lying in a hollow of the rock, seen low from the side: art/props/pool.png.
The lip is cut from the painted rock of art/props/rock_low.png, so it is the same stone as the outcrops; the
water is painted the way tools/trough_water.py paints the trough's: the sky far off, the rim mirrored at the
back, the near edge dark, a few long glints. Tinted in the game by each level's light, like every other prop.
usage: python3 tools/pool.py"""
import numpy as np
from PIL import Image, ImageFilter

W, H = 460, 96                       # twice game units, like all painted props
CX, RIM_CY, RIM_RX, RIM_RY = 230.0, 50.0, 218.0, 40.0
WAT_CY, WAT_RX, WAT_RY = 44.0, 168.0, 21.0
S = 3                                # painted larger and brought down, for clean edges
rng = np.random.default_rng(11)

rock = np.asarray(Image.open('art/props/rock_low.png').convert('RGBA')).astype(np.float32) / 255
rh, rw = rock.shape[:2]
# the widest band of solid painted stone in the rock
x0, x1 = int(rw * 0.2), int(rw * 0.8)
solid = rock[:, x0:x1, 3].min(axis=1) > 0.98
rows = np.where(solid)[0]
y0, y1 = int(rows.min()), int(rows.max())
print('stone taken from rock_low rows %d-%d, cols %d-%d' % (y0, y1, x0, x1))

h, w = H * S, W * S
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
x, y = xx / S, yy / S
ang = np.arctan2((y - RIM_CY) / RIM_RY, (x - CX) / RIM_RX)

# an uneven outline for the lip: a few slow waves round it, so it is a broken edge of rock and not an oval
wob = np.zeros_like(ang)
for k, amp in ((2, 0.07), (3, 0.1), (5, 0.085), (9, 0.06), (14, 0.045), (23, 0.03)):
    wob += amp * np.sin(k * ang + rng.uniform(0, 6.28))
P = 2.7                              # blunter than an ellipse: a hollow, not a lens with pointed ends
r_rim = (np.abs((x - CX) / RIM_RX) ** P + np.abs((y - RIM_CY) / RIM_RY) ** P) ** (1 / P) / (1.0 + wob)
wob2 = np.zeros_like(ang)
for k, amp in ((3, 0.07), (6, 0.06), (11, 0.045), (17, 0.03)):
    wob2 += amp * np.sin(k * ang + rng.uniform(0, 6.28))
r_wat = (np.abs((x - CX) / WAT_RX) ** P + np.abs((y - WAT_CY) / WAT_RY) ** P) ** (1 / P) / (1.0 + wob2)

# the stone of the lip, from the painting
tx = (x0 + (x / W) * (x1 - x0 - 1)).astype(int)
ty = (y0 + (y / H) * (y1 - y0 - 1)).astype(int)
stone = rock[ty, tx, :3]
grey = stone.mean(axis=2, keepdims=True)
stone = (stone * 0.45 + grey * 0.55) * np.array((0.82, 0.86, 0.96))      # cooler and darker: wet stone at night, not sunlit
up = np.clip((RIM_CY - y) / RIM_RY, -1, 1)                    # +1 at the back of the lip, -1 at the front
stone = stone * (0.8 + 0.45 * np.clip(up, 0, 1))[..., None]   # the far lip catches the light
stone = stone * (1.0 - 0.38 * np.clip(-up - 0.25, 0, 1))[..., None]      # the near face is turned from it
inner = np.clip((r_wat - 1.0) / 0.16, 0, 1)                   # dark where the stone goes down to the water
stone = stone * (0.35 + 0.65 * inner)[..., None]
stone = stone * (1.0 - 0.55 * np.clip((r_rim - 0.8) / 0.2, 0, 1) * np.clip(-up, 0, 1))[..., None]      # shadow under the near lip

# the water
u = np.clip((y - (WAT_CY - WAT_RY)) / (2 * WAT_RY), 0, 1)     # 0 far edge, 1 near edge
far, mid, near = np.array((0.42, 0.49, 0.62)), np.array((0.19, 0.25, 0.37)), np.array((0.06, 0.08, 0.14))
col = np.where((u < 0.4)[..., None], far + (mid - far) * (u / 0.4)[..., None], mid + (near - mid) * ((u - 0.4) / 0.6)[..., None])
back = np.clip(1 - u / 0.3, 0, 1)[..., None]                  # the far lip mirrored in it
col = col * (1 - 0.6 * back) + np.array((0.2, 0.2, 0.25)) * 0.6 * back
side = np.clip((np.abs(x - CX) / WAT_RX - 0.6) / 0.4, 0, 1)[..., None]
col = col * (1 - 0.45 * side)                                 # and its ends in the shadow of the rock
streak = np.zeros((h, w), np.float32)
for _ in range(16):
    cx, cy, ln = rng.uniform(CX - 120, CX + 120), rng.uniform(WAT_CY - 9, WAT_CY + 15), rng.uniform(14, 60)
    streak += np.exp(-((y - cy) / 0.8) ** 2) * np.clip(1 - np.abs(x - cx) / ln, 0, 1) * rng.uniform(0.2, 0.7)
col = col + np.clip(streak, 0, 1)[..., None] * np.array((0.95, 0.97, 1.0)) * 0.32

water = np.clip((1.0 - r_wat) / 0.05, 0, 1)[..., None]
rgb = stone * (1 - water) + np.clip(col, 0, 1) * water
alpha = np.clip((1.0 - r_rim) / 0.09, 0, 1)      # the lip breaks up into the ground, with no drawn edge
alpha = alpha * np.clip((H - 3 - y) / 14.0, 0, 1)             # its foot goes softly into the ground

out = np.dstack([np.clip(rgb, 0, 1), alpha])
im = Image.fromarray((out * 255).astype(np.uint8), 'RGBA').resize((W, H), Image.LANCZOS)
im.save('art/props/pool.png')
print('art/props/pool.png', im.size)
