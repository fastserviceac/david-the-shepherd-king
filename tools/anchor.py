"""usage: anchor.py <set> <frame> [<set> <frame> ...]
Slides every frame of a David set sideways by one amount, so that his feet in the named frame (one where he stands
upright) sit where they do in the idle set. Without this each set is centred on its own average pose, and he hops
sideways by a few pixels whenever the game changes from one move to another."""
import sys, glob
import numpy as np
from PIL import Image
D = 'art/david/anim'

def feet(path):
    a = np.asarray(Image.open(path))[:, :, 3] > 120
    ys = np.where(a.sum(axis=1) > 3)[0]; b = ys[-1]
    cols = np.where(a[b - 14:b + 1].sum(axis=0) > 0)[0]
    return (cols[0] + cols[-1]) / 2 - a.shape[1] / 2

want = feet('%s/idle_00.png' % D)
args = sys.argv[1:]
for name, k in zip(args[::2], args[1::2]):
    files = sorted(glob.glob('%s/%s_[0-9][0-9].png' % (D, name)))
    d = int(round(want - feet(files[int(k)])))
    for f in files:
        a = np.asarray(Image.open(f)); out = np.zeros_like(a)
        if d > 0: out[:, d:] = a[:, :-d]
        elif d < 0: out[:, :d] = a[:, -d:]
        else: out = a
        Image.fromarray(out).save(f)
    print('anchored', name, 'by', d)
