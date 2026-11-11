"""usage: rim_clean.py <folder of cut frames> [more folders]
Some animal clips come with a glow painted round the animal: orange against the blue screen. The cutter keeps it
as a bright rim, clearest under the belly and between the legs. This eats inward from the transparent edge for as
long as the pixels are that glow (bright and strongly orange) or left-over screen (bluer than red), then softens
the new edge by one pixel. Wool and hide are never that colour, so the animal itself is not touched."""
import sys, glob
import numpy as np
from PIL import Image, ImageFilter

def clean(path):
    im = Image.open(path).convert('RGBA'); a = np.asarray(im).astype(np.int32).copy()
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    glow = (r > 150) & (r - b > 78) & (g > 95) & (g - b > 35)
    screen = (b > r + 12) & (b > g - 6)
    faint = al < 250          # half-transparent edge pixels carry the rim's colour too
    # between the legs two rims meet and wash out to a pale wedge, sometimes with screen still inside it:
    # screen is taken wherever it is, and low on the animal (where wool is in shadow, never pale) pale yellow goes with it
    ys = np.where((al > 40).sum(axis=1) > 3)[0]
    low = np.zeros_like(glow); low[int(ys[0] + (ys[-1] - ys[0]) * 0.58):] = True
    pale = low & (r > 185) & (g > 165) & (r - b > 28)
    bad = glow | screen | pale
    hot = low & (r > 183) & (g > 148) & (r - b > 66)        # the brightest of the glow, shut in between two legs
    clear = al < 16
    edge = np.asarray(Image.fromarray((clear * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(19))) > 0      # within nine pixels of the outline
    cold = (r > 140) & ((b > r - 8) & (b > 120) | (g >= r - 4))          # washed-out screen: greyer or greener than any hide
    legs = np.zeros_like(glow); legs[int(ys[0] + (ys[-1] - ys[0]) * 0.68):] = True      # below the belly: only legs and the gaps between them
    wide = np.asarray(Image.fromarray((clear * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(35))) > 0
    gone = clear | (edge & screen & (b > 150)) | (edge & low & hot) | (wide & legs & (hot | cold))
    start = int(gone.sum())
    for i in range(14):
        near = np.asarray(Image.fromarray((gone * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
        take = near & ~gone & (bad | (faint & (i < 3)))
        if not take.any(): break
        gone = gone | take
    al2 = np.where(gone, 0, al).astype(np.uint8)
    # stray specks left floating where a rim was: anything thinner than five pixels that is not joined to the body goes
    solid = Image.fromarray(((al2 > 60) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(9))
    al2 = np.where(np.asarray(solid) > 0, al2, 0).astype(np.uint8)
    soft = np.asarray(Image.fromarray(al2).filter(ImageFilter.GaussianBlur(0.8))).astype(np.int32)
    al2 = np.minimum(al2, soft + 0)         # only ever thins the edge, never grows it
    out = a.copy(); out[..., 3] = al2
    Image.fromarray(out.astype(np.uint8)).save(path)
    return int(gone.sum()) - start

for d in sys.argv[1:]:
    files = sorted(glob.glob(d + '/*.png')); n = 0
    for f in files: n += clean(f)
    print(d, len(files), 'frames,', n // max(len(files), 1), 'rim pixels taken per frame')
