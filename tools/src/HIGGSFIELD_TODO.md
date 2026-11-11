# What is still needed from Higgsfield (free until 13 November)

Run this in Claude chat with the Higgsfield connector. Results stay in the Higgsfield account; they are collected and built into the game from there. Only one video and one image run at a time, so paste a part, let it finish, then the next.

## Part 1: David move clips (most useful first)

Paste first:

> Use the Higgsfield connector. For each prompt I give you, generate one video with model seedance_2_0, 720p, 16:9, no audio, on my unlimited allowance, with Higgsfield media id 4874e842-f1ad-4cb5-93ca-ef21b6d90f08 as the start image. Run them one at a time.

Every prompt ends with:

> Strict side-on profile view facing right, locked-off static camera, no zoom, no camera movement. He stays the same size, whole body visible from head to feet with clear space above his head and on both sides. Flat even green screen background, even lighting, no shadows on the wall, no dust, no extra objects or people.

| Name | Seconds | Prompt |
|---|---|---|
| hop | 5 | The young shepherd stands in a ready stance, then springs one quick short hop backwards (to the left), landing balanced on both feet with knees bent, and settles into the ready stance. He does it twice. |
| call | 6 | The young shepherd stands calmly, raises one hand beside his mouth and calls out to his flock, then beckons with an open hand, and lowers his arm to stand calmly again. |
| clinch | 6 | The young shepherd, with nothing in his hands, steps forward and grapples the empty air in front of him as if holding a large animal by the neck: arms locked round it at chest height, feet braced wide, leaning his weight in and straining. Then he lets go and steps back into a ready stance. There is no object, rock or animal in the picture, only him. |
| torch | 6 | The young shepherd walks on the spot as if on a treadmill, holding a burning hand torch up and forward in his right hand at head height, looking ahead warily, his other hand held out a little for balance. |
| draw | 6 | The young shepherd stands and hauls a rope up hand over hand from something low in front of him, as if drawing a full bucket from a well, then lifts the bucket and tips it forward to pour. |
| lyre | 8 | The young shepherd sits on a low stone in the lower half of the frame, holding a small wooden lyre against his chest, and plays it calmly, plucking the strings with his right hand, head slightly bowed, then lifts his face to look up at the sky and keeps playing. |
| slam_dodge | 5 | The young shepherd stands in a ready stance, then jumps straight up with both knees tucked high as if something sweeps along the ground under him, lands, and settles into the ready stance. He does it twice. He stays in the lower two thirds of the frame so his head is never cut off. |

## Part 2: props (images)

Paste first:

> Use the Higgsfield connector. For each prompt I give you, generate one image with model nano_banana_pro at 2K, 16:9, on my unlimited allowance. Run them one at a time.

Every prompt ends with:

> One object only, centred, filling most of the picture, seen exactly side-on at eye level, evenly lit, detailed painterly realism. The background is a completely flat pure magenta (#FF00FF) that fills the whole picture edge to edge: no ground, no landscape, no horizon, no shadow, no gradient. No people, no text.

| Name | Prompt |
|---|---|
| prop_embers | A small ring of fist-sized stones holding a bed of glowing red embers and a few charred sticks. |
| prop_lyre | A kinnor, the small wooden lyre of ancient Israel: a shallow sound box, two curved arms, a crossbar and ten gut strings, plain and well used. |
| prop_bones | A scatter of old animal bones and a ram's skull. |
| prop_cistern | The mouth of an ancient rock-cut cistern seen from the side: a low rim of rough hewn limestone set into a bank of bare rock, with a dark opening and a worn groove where ropes have run. |
| prop_pillar | A waist-high pillar of rough unworked field stones piled one on another, weathered and lichened, the kind set up as a grave marker beside an ancient road. No fire on it. |
| prop_threshing | A round threshing floor of beaten earth and flat stones seen from a low side angle, with a wooden winnowing fork and two clay storage jars beside it. |

## Part 3: story film shots (video)

These are in `ART_SHEET.md`, Part D, with their opening message and closing line. Order: count_1, count_2, count_3, ridge_1, ridge_2, dawn_1, dawn_2, dawn_3, end_1, end_2, end_3, then wadi_1, wadi_2, den_1, den_2, watch_1, watch_2. (well_1 and well_2 are being made on Runway.)

## Part 4: animals that still move like cut-outs (video)

Paste first:

> Use the Higgsfield connector. For each prompt I give you, generate one video with model seedance_2_0, 720p, 16:9, 5 seconds, no audio, on my unlimited allowance. Run them one at a time.

Every prompt ends with:

> Strict side-on profile view facing right, locked-off static camera, no zoom. The animal stays the same size, whole body visible with clear space on every side. Completely flat, even, pure blue screen background (#0047FF) with no gradient, no glow or rim light round the animal, no shadow on the floor, no dust, nothing else in the picture. Realistic painted look.

| Name | Prompt |
|---|---|
| sheep_leap | One woolly white sheep with a dark face trots two steps, gathers itself and jumps forward over a small gap, landing on its front feet and trotting on. It stays in the middle of the frame as if the camera travels with it. |
| bear_walk | A large Syrian brown bear walks on all fours on the spot as if on a treadmill, heavy shoulders rolling, head low and swinging. A full walking cycle, repeated. |
| bear_slam | A large Syrian brown bear rears up on its hind legs, then drops and slams both front paws hard onto the ground in front of it, and settles back on all fours. |
| lion_run | A lean lion runs flat out on the spot as if on a treadmill, body stretched low, a full galloping cycle repeated. |
| lion_rake | A lean lion crouched low takes one fast swipe forward along the ground with a front paw, then draws back into its crouch. |

## Part 5: cave mouths painted for each scene (images)

The cave mouth now in the game is one grey rock arch reused everywhere, and it does not belong to the scenes it stands in. These replace it. Same opening message as Part 2. Attach `tools/src/style_s1.jpg` for the first, `style_s2.jpg` for the second.

Every prompt ends with:

> One object only, centred, seen exactly side-on at eye level, with its base flat along the bottom so it can stand on level ground. Detailed painterly realism. The background is a completely flat pure magenta (#FF00FF) that fills the whole picture edge to edge: no ground plane, no landscape, no horizon, no sky, no shadow, no gradient. No people, no animals, no text.

| Name | Prompt |
|---|---|
| mouth_pastures | The mouth of a small natural cave in a low outcrop of pale cream limestone, about twice a man's height and four times as wide, its top rounded and grown with dry grass, thyme and a little olive scrub, boulders tumbled at both ends so it tapers into the ground. The opening is a low dark arch in the middle, deep black inside. Warm golden late-afternoon light from the left. |
| mouth_ravine | The mouth of a cave in a broken outcrop of rose and violet-grey limestone, about twice a man's height and four times as wide, thorn bushes and a dead branch at its foot, boulders tumbled at both ends so it tapers into the ground. The opening is a low dark arch in the middle, deep black inside. Dusk light: violet shadow with a last warm rim from the left. |
| mouth_wadi | The mouth of a cave in water-worn pale limestone, layered and smooth, about twice a man's height and four times as wide, a broom bush at one side, rounded boulders at both ends so it tapers into the ground. The opening is a low dark arch in the middle, deep black inside. Cool blue-violet twilight. |
