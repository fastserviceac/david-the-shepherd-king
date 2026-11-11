"""usage: kneel_split.py <dir holding the whole kneel cut as kn_NN.png>
The kneel clip is cut once as a single set, so that going down, staying down and rising all share one centre;
this deals it out into the three sets the game plays, slid sideways so his standing feet match the idle set."""
import sys, glob, os
import numpy as np
from PIL import Image
src = sys.argv[1]; D = 'art/david/anim'
def feet(path):
    a = np.asarray(Image.open(path))[:, :, 3] > 120
    ys = np.where(a.sum(axis=1) > 3)[0]; b = ys[-1]
    cols = np.where(a[b - 14:b + 1].sum(axis=0) > 0)[0]
    return (cols[0] + cols[-1]) / 2 - a.shape[1] / 2
files = sorted(glob.glob(src + '/kn_[0-9][0-9].png'))
d = int(round(feet('%s/idle_00.png' % D) - feet(files[0])))
parts = {'kneel': range(0, 17), 'kneel_hold': range(20, 66, 2), 'kneel_up': range(66, len(files))}
for name, idx in parts.items():
    for f in glob.glob('%s/%s_[0-9][0-9].png*' % (D, name)): os.remove(f)
    for k, i in enumerate(idx):
        a = np.asarray(Image.open(files[i])); out = np.zeros_like(a)
        if d > 0: out[:, d:] = a[:, :-d]
        elif d < 0: out[:, :d] = a[:, -d:]
        else: out = a
        Image.fromarray(out).save('%s/%s_%02d.png' % (D, name, k))
    print(name, 'frames', len(idx), 'slid by', d)
