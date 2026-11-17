"""Cuts the one usable piece out of the hall's wall-foot painting (tools/src/art_in/c2/c2_hall_mid.png, Higgsfield,
17 November) and lays it on clean magenta in tools/src/art_in/props, for tools/scenery.py to key:
  c2_hall_lamp.png  the lamp stand with its burning lamp
(the door post, bench and jar in the same painting sat on different base lines and did not stand in the room: not used)
The painting came with a ghost of the room across its middle and a dark gradient along its foot, so it is not
used as a band: the ghost's box is filled, anything magenta in hue however dark is made pure magenta, specks
and crumbs are rubbed out, and the foot is cut at the pieces' base line.
usage: python3 tools/hall_props.py ; python3 tools/scenery.py c2_hall_lamp"""
import numpy as np
from PIL import Image, ImageFilter
a = np.asarray(Image.open('tools/src/art_in/c2/c2_hall_mid.png').convert('RGB')).astype(np.float32) / 255
MAG = np.array([1.0, 0.0, 1.0], np.float32)
a[380:840, 600:1790] = MAG                     # the ghost of the room
r, g, b = a[..., 0], a[..., 1], a[..., 2]
hi = np.maximum(r, b)
bg = (np.minimum(r, b) - g > 0.38 * hi) & (hi > 0.07) & (np.abs(r - b) < 0.3 * hi + 0.04)
def opened(m, k):          # what is left of a mask after specks and threads narrower than k are rubbed out
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))
    return np.asarray(im) > 127
bg = opened(bg, 9)                             # pinholes of screen colour inside a thing stay part of it
bg = ~opened(~bg, 15)                          # crumbs and ragged threads outside the things go
a[bg] = MAG
def cut(name, x0, x1, y0, y1):
    p = a[y0:y1, x0:x1].copy()
    Image.fromarray((p * 255).astype(np.uint8)).save('tools/src/art_in/props/%s.png' % name)
    print(name, p.shape, 'magenta %.0f%%' % (100 * (np.abs(p - MAG).sum(axis=2) < 0.1).mean()))
cut('c2_hall_lamp', 1790, 1925, 620, 1180)
