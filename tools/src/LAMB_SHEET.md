# Clips for Chapter One's smaller lengthening: the flock at rest and the lamb

For tranches 2 and 3 of `CHAPTER_ONE_PLAN.md`. Nothing here has been generated or paid for.

Not needed, already in the game: David seated playing the lyre (`art/david/anim/lyre_*`) and the lyre prop.
Standing and walking with the lyre are on `tools/src/C2_SHEET.md` (`c2_lyre_stand`, `c2_lyre_walk`).

## How to run this

1. Sheep clips use `tools/src/sheep_start.png` as the start image, so the animal matches the flock in the game.
2. The newborn needs its own start picture first (below). Check it before any video.
3. David's clips use `tools/src/david_start.png`.
4. Save clips as `tools/src/clips/<name>.mp4`.

Video settings: 720p, 16:9, no audio, one at a time. Seconds are given per clip.

Estimated cost for all 11 clips: about 660 credits on Runway (kling-4, about 60 a clip) or about 26,700 on ElevenLabs (veo-3.1-lite, about 2,424 a clip). The start picture is about 1,200 ElevenLabs credits if made there.

## Start picture for the newborn (image)

> A newborn lamb only minutes old: very small, thin long legs folded under it, damp flattened wool, pale cream with a dark face, large ears lying back, lying on its chest with its head just raised. Strict side-on profile view facing right, whole body visible with clear space on every side, lying on nothing. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow, nothing else in the picture. Realistic painted look, soft natural light.

Save as `tools/src/lamb_start.png`.

## Sheep and lamb clips

Every prompt ends with:

> Strict side-on profile view facing right, locked-off static camera, no zoom. The animal stays the same size, whole body visible with clear space on every side. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow on the floor, no dust, nothing else in the picture. Realistic painted look.

### The flock settles when he plays (tranche 2)

| Name | Start | Seconds | Prompt |
|---|---|---|---|
| sheep_lie | sheep_start | 6 | One woolly white sheep with a dark face stands, bends its front knees, lowers its chest to the ground, folds its hind legs under and settles lying upright on its chest, head up, calm. |
| sheep_rest | sheep_start | 6 | One woolly white sheep with a dark face lies upright on its chest with its legs folded under it, head up, slowly chewing, one ear flicking once, breathing slowly. It does not get up. |
| sheep_rise | sheep_start | 5 | One woolly white sheep with a dark face lies upright on its chest, then pushes up hind legs first, then front legs, stands and shakes its wool once. |
| sheep_uneasy | sheep_start | 5 | One woolly white sheep with a dark face stands tense with its head high and ears forward, shifts its weight, stamps one front foot, turns its head sharply to look behind and back again. |

### Lambing night (tranche 3)

| Name | Start | Seconds | Prompt |
|---|---|---|---|
| ewe_labour | sheep_start | 6 | One woolly white ewe with a dark face lies on her side, flanks rising and falling heavily, lifts her head and neck off the ground, strains, lowers her head again, and repeats. |
| ewe_tend | sheep_start | 6 | One woolly white ewe with a dark face stands with her head lowered to the ground in front of her, nuzzling and licking something small just out of sight at the right edge, lifts her head to look round, and lowers it again. |
| lamb_wake | lamb_start | 5 | The newborn lamb lies on its chest, lifts its wobbling head, shakes its ears, and tries to gather its front legs under it. |
| lamb_stand | lamb_start | 8 | The newborn lamb pushes up onto shaking legs, falls back onto its chest, tries again, and stands swaying with its legs spread wide. |
| lamb_totter | lamb_start | 5 | The newborn lamb takes small unsteady steps on the spot as if on a treadmill, legs stiff and wide, head bobbing, a full wobbling walk cycle repeated. |

## David's clips (tranche 3)

Every prompt ends with:

> Strict side-on profile view facing right, locked-off static camera, no zoom, no camera movement. He stays the same size, whole body visible from head to feet with clear space above his head and on both sides. Flat even green screen background, even lighting, no shadows on the wall, no dust, no extra objects or people.

| Name | Seconds | Prompt |
|---|---|---|
| david_rub | 6 | The young shepherd kneels on both knees and, with a handful of dry grass in each hand, rubs briskly and gently at something small lying on the ground in front of him, pauses to look at it, and rubs again. |
| david_gather | 6 | The young shepherd kneels on one knee, slides both hands under a very small newborn lamb lying on the ground in front of him, lifts it against his chest, wraps the edge of his cloak round it, and stands. |

## After the clips arrive

- Cut each into `art/sheep/anim/<name>_NN.png` or `art/david/anim/<name>_NN.png` with `tools/anim.py`: blue key for the animals with the same settings as the sheep walk in `tools/build_anims.sh` (`wide=1.5 tall=1.4 size=110 erode=9`), David's with `href=598`.
- Check each sheep set for height against the sheep walk set, and each David set against his run frames, before it goes in.
- Delete any leftover `.import` files when a set is re-cut with fewer frames.

## Notes on fact

- Rubbing a newborn dry with grass and bringing it to its mother is ordinary shepherd practice, not scripture.
- Lambing in the Judean hills falls from winter into early spring. The plan's "spring" should read "late winter to spring".
