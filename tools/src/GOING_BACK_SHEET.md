# Going back: the wild goats and the jackal's pups

Two of Chapter One's "going back" animals are built and tested but can't be seen until their pictures exist:
- The wild goats on the Wadi's crag need the frame sets `art/goat/anim/walk_NN.png` and `graze_NN.png`.
- The jackal's pups in the Bear's Den need `art/pup/anim/walk_NN.png`.

Until those are cut, the game leaves both animals out. The lost twin uses the lamb's own pictures and needs nothing.

Cost on Higgsfield (prices from 17 Nov): 2 key images at 2 credits each, and 6 clips at 22.5 each (`seedance_2_0`, 5 s, 720p).
That is about **139 credits** for everything.

## How to run this

1. Make the two key images first. Check that each looks right before making any video.
   - For `pup_start`, upload `tools/src/jackal_start.png` as a reference image. The pups must have the game jackal's coat.
2. Make each clip with its animal's key image as the start image, so the animal matches across clips.
3. Save the files here:
   - key images: `tools/src/goat_start.png` and `tools/src/pup_start.png`
   - clips: `tools/src/beasts/goat_walk.mp4` and so on, named as in the tables below

Video settings: 720p, 16:9, 5 seconds, no audio, one at a time.

## Key images

Every image prompt ends with:

> Strict side-on profile view facing right, whole body visible with clear space on every side, standing on nothing. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow, nothing else in the picture. Realistic painted look, soft natural light.

| Name | Prompt |
|---|---|
| goat_start | A Nubian ibex, the wild goat of the Judean desert cliffs: a nanny, lean and sure-footed, short sandy-tan coat paler on the belly, dark stripe down the front of each leg, slim backward-curving horns about the length of her head, short tail, small beard. Standing square on all four feet, head up, alert. |
| pup_start | A jackal pup about ten weeks old, the same golden jackal as the reference image and with the same coat colour, but small and round: big ears, short muzzle, fluffy coat, stubby legs, a short tail. Standing on all four feet, head level, curious. |

## Clips

Every video prompt ends with:

> Strict side-on profile view facing right, locked-off static camera, no zoom. The animal stays the same size, whole body visible with clear space on every side. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow on the floor, no dust, nothing else in the picture. Realistic painted look.

### Wild goat (stands on the crag, then follows the lyre down the wadi)

| Name | Prompt |
|---|---|
| goat_walk | The ibex walks on the spot as if on a treadmill, light and deliberate, head nodding a little with each step, a full walking cycle repeated. |
| goat_run | The ibex bounds on the spot as if on a treadmill, quick and springy, legs gathered under it, a full bounding cycle repeated. |
| goat_graze | The ibex stands in place, lowers its head to browse low plants at its feet, chews, lifts its head to look around, and lowers it again. |
| goat_leap | From standing, the ibex gathers on its hind legs and springs forward and down in one long leap, front legs reaching, and lands neatly on all four feet and stands. |

### Jackal pups (keep at their mother's side in the Bear's Den)

| Name | Prompt |
|---|---|
| pup_walk | The jackal pup trots on the spot as if on a treadmill, a little clumsy, ears bobbing, a full trotting cycle repeated. |
| pup_idle | The jackal pup stands in place, sniffs the ground, sits back on its haunches for a moment, scratches behind an ear with a hind leg, and stands again. |

## After the clips arrive

Extract the frames with `ffmpeg -vf fps=24` into `<dir>/<clip>/f%03d.png`, as for the other beasts. Then cut them and
add these lines to `tools/build_anims.sh`, with the `a=`/`b=` ranges set from the actual clips:

```
# going back: the wild goat (drawn the sheep's way, as a sheep with its own pictures) and the jackal's pups
run $V/goat_walk art/goat/anim walk key=blue mode=loop double=1 wide=1.5 tall=1.4 size=110 erode=3
run $V/goat_run art/goat/anim run key=blue mode=loop double=1 wide=1.5 tall=1.4 size=110 erode=3
run $V/goat_graze art/goat/anim graze key=blue mode=range a=0 b=120 step=3 hframe=0 wide=1.5 tall=1.4 size=110 erode=3
run $V/goat_leap art/goat/anim leap key=blue mode=range a=0 b=96 step=2 hframe=0 wide=1.5 tall=2.7 size=110 erode=3
run $V/pup_walk art/pup/anim walk key=blue mode=loop double=1 wide=1.8 tall=1.4 size=110 erode=3
run $V/pup_idle art/pup/anim idle key=blue mode=range a=0 b=120 step=3 hframe=0 wide=1.8 tall=1.4 size=110 erode=3
```

Checks:
- Check each set for scale against its own walk set. In the game, the goats are drawn at sheep size (one at 1.0, one at 0.82) and the pups at about 0.45 of a jackal.
- Do not run `tools/rim_clean.py` on these sets.
- Once the sets are in, run the Wadi and Bear's Den in the game and look at the goats on the crag and the pups beside their mother.
