# New beasts: wolf, leopard, viper, hyena

Four animals for Chapter One, each checked against scripture and the wildlife of the Judean hills.
The game already has their behaviour; it spawns none of them until these clips exist as frame sets.

## How to run this

1. Make the four key images first (one per animal). Check each looks right before any video.
2. Make each clip with its animal's key image as the start image, so the animal matches across clips.
3. Save clips as `tools/src/beasts/<name>.mp4` (for example `wolf_walk.mp4`) and key images as
   `tools/src/<animal>_start.png`, the same as the bear and lion.

Video settings: 720p, 16:9, 5 seconds, no audio, one at a time.

## Key images (make these first)

Every image prompt ends with:

> Strict side-on profile view facing right, whole body visible with clear space on every side, standing on nothing. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow, nothing else in the picture. Realistic painted look, soft natural light.

| Name | Prompt |
|---|---|
| wolf_start | A lean Arabian wolf of the Judean desert: small and rangy, short pale sandy-grey coat, long legs, narrow chest, large ears, thin tail held low. Standing alert, head level. |
| leopard_start | An Arabian leopard: small, lean and pale, cream-gold coat with tight dark rosettes, long tail with a dark tip. Standing low and watchful, head forward. |
| viper_start | A Palestine viper: thick-bodied snake about as long as a man's arm, sandy-brown with a dark zigzag band down its back, broad flat head. Coiled in a loose pile on the ground, head resting on the coils. |
| hyena_start | A striped hyena: sloping back, high shoulders, long shaggy grey-buff coat with black stripes on the body and legs, a mane along the spine, pointed ears, black muzzle. Standing with its head held low. |

## Clips

Every video prompt ends with:

> Strict side-on profile view facing right, locked-off static camera, no zoom. The animal stays the same size, whole body visible with clear space on every side. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow on the floor, no dust, nothing else in the picture. Realistic painted look.

### Wolf (comes at dusk, takes one sheep and scatters the rest)

| Name | Prompt |
|---|---|
| wolf_walk | The wolf paces on the spot as if on a treadmill, wary, head low and turned slightly toward the viewer's right, a full walking cycle repeated. |
| wolf_run | The wolf runs flat out on the spot as if on a treadmill, body stretched, tail streaming, a full galloping cycle repeated. |
| wolf_lunge | The wolf drops its chest, springs forward one length with jaws open and closes them, then pulls its head back and up. |
| wolf_drag | The wolf walks backward on the spot with its head low and neck braced, tugging hard at something heavy it holds in its jaws just out of sight at the right edge, a full backward-stepping cycle repeated. |
| wolf_hurt | The wolf flinches sideways with a yelp, ears flat, tail tucked, and shrinks low before straightening. |

### Leopard (lies in wait above the path)

| Name | Prompt |
|---|---|
| leopard_lurk | The leopard lies flat along the ground, chin on its front paws, perfectly still except for the tip of its tail flicking and one slow blink. |
| leopard_spring | From a flat crouch the leopard gathers its hind legs and launches forward and downward in one long leap, front paws reaching out, body fully stretched in the air. |
| leopard_land | The leopard lands from a leap onto its front paws, hindquarters following, skids a half step and holds a low crouch, breathing hard. |
| leopard_walk | The leopard walks on the spot as if on a treadmill, low and loose-shouldered, tail curved, a full walking cycle repeated. |
| leopard_run | The leopard bounds on the spot as if on a treadmill, back flexing, a full bounding cycle repeated. |
| leopard_hurt | The leopard recoils with a snarl, head turned away, one front paw lifted, then drops back to a low stance. |

### Viper (coiled in the path or at the foot of a wall)

| Name | Prompt |
|---|---|
| viper_coil | The viper lies coiled and almost still, its sides rising and falling slightly with breath, tongue flickering out once. |
| viper_rear | The viper lifts its head and the front third of its body off the coils, neck drawn back in an S, mouth slightly open, swaying a little. |
| viper_strike | From a raised S the viper darts its head forward and low in one very fast straight movement to full stretch, then lies stretched out for a moment. |
| viper_spent | The viper, stretched out long on the ground, slowly draws its body back toward a coil, head low. |

### Hyena (a timid scavenger that comes in the night)

| Name | Prompt |
|---|---|
| hyena_slink | The hyena creeps on the spot as if on a treadmill, back sloping, head held low and stretched forward, steps slow and careful, a full creeping cycle repeated. |
| hyena_run | The hyena runs on the spot as if on a treadmill with its loping, rocking gait, mane flat, tail down, a full cycle repeated. |
| hyena_cringe | The hyena stops, shrinks back onto its haunches with its mane bristling up and head turned aside, takes two small steps backward, and holds. |
| hyena_hurt | The hyena jerks away with a yelp, tail tucked tight, body curled, then stumbles a step. |

## After the clips arrive

Each clip is cut into a frame set named `art/<animal>/anim/<move>_NN.png` with `tools/anim.py`, blue key, the same
way as the bear and lion. Check every set for scale against that animal's walk set before it goes in.
Do not run `tools/rim_clean.py` on them: it damaged the bear and lion sets.
