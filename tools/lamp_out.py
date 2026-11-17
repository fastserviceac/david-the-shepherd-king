"""The Night Fit's lamp stands (scripts/levels/night_fit.gd), made from the hall's burning one
(art/props/c2_hall_lamp.png). No new painting.
  c2_hall_lamp_night.png  the same lamp on a shorter stand (a length of the plain pole taken out), so that the
                          boy's raised taper reaches its wick
  c2_hall_lamp_out.png    that lamp gone out: the flame above the bowl's rim taken away, the glow it threw on
                          the bowl dulled, a short charred wick left standing
usage: python3 tools/lamp_out.py"""
import numpy as np
from PIL import Image
a = np.asarray(Image.open('art/props/c2_hall_lamp.png').convert('RGBA')).astype(np.float32)
CUT = (200, 362)                           # rows of plain pole taken out: 162 px, 52 game units at the hall's scale
a = np.concatenate([a[:CUT[0]], a[CUT[1]:]])
Image.fromarray(a.clip(0, 255).astype(np.uint8)).save('art/props/c2_hall_lamp_night.png')
RIM = 46                                   # the first row of the bowl: everything above it is flame
a[:RIM, :, 3] = 0
for y in range(RIM, 100):                  # the bowl and the plate under it lose the flame's light, most at the rim
    k = 0.5 + 0.35 * min(1.0, (y - RIM) / 50.0)
    a[y, :, :3] *= (k, k * 0.96, k * 1.02)
for y in range(RIM - 5, RIM + 2):          # the wick: a soft charred stub, leaning
    u = (RIM + 1 - y) / 6.0
    for x in range(44, 49):
        d = abs(x - (46.0 + 1.2 * u))
        al = max(0.0, 1.0 - d / (1.7 - 0.7 * u)) * (1.0 - 0.5 * u)
        a[y, x, :3] = a[y, x, :3] * (1 - al) * (a[y, x, 3] > 0) + np.array([52, 40, 34]) * (al if a[y, x, 3] > 0 else 1.0)
        a[y, x, 3] = max(a[y, x, 3], 255 * al)
Image.fromarray(a.clip(0, 255).astype(np.uint8)).save('art/props/c2_hall_lamp_out.png')
print('art/props/c2_hall_lamp_night.png, art/props/c2_hall_lamp_out.png', a.shape)
