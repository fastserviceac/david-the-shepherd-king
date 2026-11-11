"""Paints the water for the stone trough: three pictures the size of art/props/trough.png, one for each level,
each a surface that fits the hollow of the painting (its back edge lower down the wall as the trough empties),
reflecting the evening sky and shaded by the walls. Laid over the trough in the game and made to shimmer there."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
src = Image.open('art/props/trough.png')
W, H = src.size
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
rng = np.random.default_rng(5)
for level, back in ((3, 78.0), (2, 102.0), (1, 126.0)):
    xl = 150 - (back - 48) * 45 / 127 + 2          # where that height meets the left and right inner walls
    xr = 1020 + (back - 45) * 40 / 125 - 2
    poly = [(xl, back), (xr, back - 3), (1062, 172), (900, 180), (600, 180), (400, 187), (180, 185), (104, 178)]
    m = Image.new('L', (W * 2, H * 2), 0)
    ImageDraw.Draw(m).polygon([(x * 2, y * 2) for x, y in poly], fill=255)
    mask = np.asarray(m.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    u = np.clip((yy - back) / (184 - back), 0, 1)          # 0 at the far edge of the water, 1 at the near
    far, mid, near = np.array((0.93, 0.60, 0.40)), np.array((0.50, 0.46, 0.58)), np.array((0.13, 0.20, 0.30))
    col = np.where((u < 0.45)[..., None], far + (mid - far) * (u / 0.45)[..., None], mid + (near - mid) * ((u - 0.45) / 0.55)[..., None])
    wall = np.clip(1 - (yy - back) / 16.0, 0, 1)[..., None]           # the back wall mirrored in the water
    col = col * (1 - 0.55 * wall) + np.array((0.36, 0.25, 0.17)) * 0.55 * wall
    left = np.clip(1 - (xx - xl) / 230.0, 0, 1) ** 1.5             # shadow of the left wall: the light comes from that side
    col = col * (1 - 0.62 * left[..., None])
    front = np.clip((yy - 168) / 14.0, 0, 1)[..., None]            # and of the near rim
    col = col * (1 - 0.45 * front)
    streak = np.zeros((H, W), np.float32)                          # a few long glints of sky
    for _ in range(26):
        cx, cy, ln = rng.uniform(260, 1000), rng.uniform(back + 14, 170), rng.uniform(30, 120)
        streak += np.exp(-((yy - cy) / 1.6) ** 2) * np.clip(1 - np.abs(xx - cx) / ln, 0, 1) * rng.uniform(0.25, 0.7)
    col = col + np.clip(streak, 0, 1)[..., None] * np.array((1.0, 0.86, 0.66)) * 0.42
    edge = np.clip(mask * 6, 0, 1) - np.clip((mask - 0.5) * 6, 0, 1)   # a bright wet line where water meets stone
    col = col + (edge * (1 - wall[..., 0]))[..., None] * 0.10
    out = np.dstack([np.clip(col, 0, 1), mask * 0.94])
    Image.fromarray((out * 255).astype(np.uint8)).save('art/props/trough_water%d.png' % level)
print('painted trough water, 3 levels')
