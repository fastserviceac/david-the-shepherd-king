"""The stone the map's model of the fortress at Gibeah is built of: a square of the Gate's own wall painting
(tools/src/art_in/c2_gibeah_mid.png), lifted towards sunlit limestone -> art/map_gibeah_stone.png, 512x512.
usage: python3 tools/fort_map.py"""
import numpy as np
from PIL import Image
im = Image.open('tools/src/art_in/c2_gibeah_mid.png').convert('RGB')
sq = im.crop((900, 520, 900 + 560, 520 + 560)).resize((512, 512), Image.LANCZOS)
a = np.asarray(sq).astype(np.float32) / 255
grey = a.mean(axis=2, keepdims=True)
a = grey + (a - grey) * 0.6                       # less red
a = np.clip((a - a.mean()) * 0.85 + 0.6, 0, 1)    # lifted, a little flatter
a *= np.array([1.0, 0.93, 0.8], np.float32)       # warm limestone
# the square repeats over the walls: its edges are cross-faded so it has no seam
k = 48
ramp = np.linspace(0, 1, k, dtype=np.float32)
a[:, :k] = a[:, :k] * ramp[None, :, None] + a[:, -k:][:, ::-1] * (1 - ramp)[None, :, None]
a[:k] = a[:k] * ramp[:, None, None] + a[-k:][::-1] * (1 - ramp)[:, None, None]
Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save('art/map_gibeah_stone.png')
print('stone', a.mean(axis=(0, 1)).round(2))
