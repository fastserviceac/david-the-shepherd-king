# Art and film sheet for Chapter One (run in Claude chat with Higgsfield)

Everything here is free on the Higgsfield allowance until 13 November. Work down the parts in order: Part A matters most, because without the paintings the new sections cannot be built.

Where files go:

| Part | Save into | 
|---|---|
| A paintings, B props | `tools/src/art_in/` |
| C David clips | `tools/src/clips/` |
| D story film shots | `tools/src/films/` |

If the chat cannot save files, that is fine: the results stay in the Higgsfield account and can be collected from there. Keep the file names in the prompts so each result can be told apart.

---

## Part A: paintings (images)

### Paste this first

> Use the Higgsfield connector. For each prompt I give you, generate one image with model nano_banana_pro at 2K, 16:9, on my unlimited allowance. Use the attached pictures only as a guide to painting style, level of detail and horizon height, not for their content. Run them one at a time and name each result as given.

Attach `tools/src/style_s1.jpg`, `style_s2.jpg`, `style_s3.jpg` and `style_midground.jpg`.

### Backdrops (the far view behind the play area)

End every backdrop prompt with:

> Highly detailed digital matte painting, painterly realism, cinematic light, deep atmospheric perspective. The hill country of Judah around Bethlehem, about 1000 BC. Wide landscape seen from a low side-on viewpoint, horizon a little above the middle, the bottom fifth of the picture plain dark ground with nothing important in it. No people, no animals, no buildings later than the Iron Age, no text, no border.

| Name | Prompt |
|---|---|
| `well_backdrop` | Evening at the well outside the gate of Bethlehem. A low walled hill town of pale limestone houses with flat roofs on a ridge to the right, terraced olive groves and threshing floors below it, a worn track leading down to a stone-ringed well in a hollow. Long red-gold light from a sun almost on the horizon, dust hanging in the air, the first blue of evening in the eastern sky. |
| `wadi_backdrop` | Twilight in a dry riverbed climbing into the Judean wilderness. Pale water-worn limestone walls rising in steps on both sides, a bed of smooth boulders and gravel winding upward and away, a few broom bushes and a lone acacia, the last band of orange light on the highest cliffs and deep violet shadow below, the first stars. |
| `den_backdrop` | The inside of a large limestone cave at night. A high rough vault lost in darkness, stalactites, pale flowstone, side passages leading off, a shaft in the roof letting down one thin column of blue moonlight through drifting dust. Very dark overall, cold blue-black, with warm firelight glimmering faintly from somewhere deep in the cave. |
| `watch_backdrop` | The hour before dawn over the hills of Bethlehem. An immense clear night sky thick with stars and the band of the Milky Way, a thin old moon low in the east, rolling dark hills, the sleeping walled town small on a far ridge, and the faintest grey-rose line of first light along the horizon. Still, vast and quiet. |

### Midgrounds (the strip just behind the path)

End every midground prompt with:

> A single wide band of scenery sitting along the bottom two thirds of the picture, painted in the same detailed matte-painting style, cut out against a completely flat, pure magenta (#FF00FF) background that fills the whole sky area with no gradient, no clouds and no haze. The band fades to near black along its bottom edge. No people, no animals, no text.

| Name | Prompt |
|---|---|
| `well_mid` | Dry-stone walls, an old olive tree, two stone water troughs, a stack of clay water jars and a low terrace wall, in warm evening light from the left. |
| `wadi_mid` | Tumbled water-worn limestone boulders, a ledge of layered rock, thorny broom bushes and a twisted dead acacia, in cool violet twilight. |
| `den_mid` | Cave floor formations: thick stalagmites, fallen slabs, a pile of old bones and dry branches, a low rock arch, lit dimly in cold blue with a faint warm rim. |
| `watch_mid` | A dry-stone sheepfold wall with a gap for a gate, a thorn-branch fence on top, a flat sitting stone and an old olive tree, in deep blue starlight. |

---

## Part B: props (images)

Same first message as Part A. End every prop prompt with:

> One object only, centred, seen exactly side-on at eye level, evenly lit, painted in the same detailed matte-painting style, on a completely flat pure magenta (#FF00FF) background with no shadow on the ground and no gradient. No people, no text.

| Name | Prompt |
|---|---|
| `prop_well` | An Iron Age village well: a low ring of rough limestone blocks about knee high, a worn rope coiled on the rim and a leather bucket. |
| `prop_wellstone` | A large round flat limestone slab, about a metre across and a hand thick, weathered, the kind used to cover the mouth of a well, standing on its edge. |
| `prop_trough` | A long low stone water trough carved from one block of limestone, half full of water. |
| `prop_torch` | A hand torch: a short olive-wood branch wrapped at one end with oil-soaked cloth, unlit. |
| `prop_embers` | A small ring of stones holding a bed of glowing red embers and a few charred sticks. |
| `prop_lyre` | A kinnor, the small wooden lyre of ancient Israel: a shallow sound box, two curved arms, a crossbar and ten gut strings, plain and well used. |
| `prop_bones` | A scatter of old animal bones and a ram's skull on bare rock. |

---

## Part C: David move clips (video)

Same method as `CLIP_PROMPTS.md`: model seedance_2_0, 720p, 16:9, no audio, start image `tools/src/david_start.png` (Higgsfield media id `bdaecf32-debb-4d96-b1b6-683bbef8a4bb`), and the same closing line about the side-on locked camera and green screen. Finish the list in `CLIP_PROMPTS.md` first, including the corrected jump at the bottom of that file.

| File | Seconds | Prompt |
|---|---|---|
| `push.mp4` | 6 | The young shepherd leans his shoulder and both hands against something heavy and unseen in front of him and pushes it slowly forward step by step, legs driving, straining. He moves on the spot as if on a treadmill. |
| `torch.mp4` | 6 | The young shepherd walks on the spot as if on a treadmill, holding a burning hand torch up and forward in his right hand at head height, looking ahead warily, his other hand held out a little for balance. |
| `lyre.mp4` | 8 | The young shepherd sits on a low stone in the lower half of the frame, holding a small wooden lyre against his chest, and plays it calmly, plucking the strings with his right hand, head slightly bowed, then lifts his face to look up at the sky and keeps playing. |
| `draw.mp4` | 6 | The young shepherd stands and hauls a rope up hand over hand from something low in front of him, as if drawing a full bucket from a well, then lifts the bucket and tips it forward to pour. |

---

## Part D: story films between sections (video)

These play between the playable sections, like the prologue: moving pictures with the narrator over them. Each film is two or three shots.

### Paste this first

> Use the Higgsfield connector. For each prompt I give you, generate one video with model seedance_2_0, 720p, 16:9, 8 seconds, no audio, on my unlimited allowance. Run them one at a time and name each result as given.

End every film prompt with:

> Cinematic live-action look, ancient Israel about 1000 BC, natural light, shallow depth of field, slow deliberate camera movement, muted earthy colour, fine film grain, 2.39:1 framing kept inside the 16:9 picture. Historically plausible Iron Age clothing of undyed wool and linen. No text, no captions, no modern objects.

Where a prompt names "the shepherd boy", describe him the same way every time: a boy of about fifteen with dark curly hair, a cream wool tunic to the knee, a rust-red cloak over one shoulder, a leather belt and sandals.

| File | Plays before | Prompt |
|---|---|---|
| `well_1` | The Well | Evening. Several flocks of sheep converge down dusty hill tracks toward a stone well below a walled hill town, raising gold dust in the low sun. Slow aerial drift forward. |
| `well_2` | The Well | Close on a heavy round stone covering the mouth of a well, shepherds' sandalled feet and staffs gathering round it, sheep pressing in behind. Slow push in. |
| `count_1` | The Lost Lamb | Dusk at a dry-stone sheepfold. The shepherd boy stands in the gateway holding his staff low across it, and the sheep pass under it one at a time as his lips move, counting. Camera at sheep height, slowly tracking back. |
| `count_2` | The Lost Lamb | The last sheep passes. The shepherd boy's face in close-up as he looks over the flock, then turns and looks out toward dark hills, troubled. Slow push in on his eyes. |
| `count_3` | The Lost Lamb | The shepherd boy walks away from the lit sheepfold into the darkening hills alone, staff in hand, small against a huge dusk sky. Wide shot, camera rising. |
| `wadi_1` | The Wadi | A tuft of white wool caught on a thorn bush trembles in the wind, a dry riverbed climbing into cliffs out of focus beyond it. Rack focus from the wool to the cliffs. |
| `wadi_2` | The Wadi | Low over smooth gravel, a line of small hoof prints and, beside them, the broad prints of a large animal, leading up a dry riverbed in the last light. Camera glides forward along the tracks. |
| `den_1` | The Bear's Den | Night. The black mouth of a cave in a limestone cliff, cold moonlight on the rock, a breath of mist drifting out of it. Very slow push toward the darkness. |
| `den_2` | The Bear's Den | The shepherd boy kneels at a small bed of embers and lights a cloth-wrapped torch from it; the flame catches and lights his face from below. Close shot, shallow focus. |
| `ridge_1` | The Lion's Ridge | A bare rocky ridge under a bright moon. On the skyline the silhouette of a lion stands still, head low, then turns its head toward the camera. Long lens, slow drift. |
| `ridge_2` | The Lion's Ridge | The shepherd boy climbs the last rocks onto the ridge, wind pulling at his cloak, and stops, breathing hard, looking ahead at something off screen. Low angle, camera rising with him. |
| `watch_1` | The Night Watch | The shepherd boy walks down a hill path under a vast starry sky carrying a small white lamb across his shoulders, tired, steady. Wide shot from the side, slow track. |
| `watch_2` | The Night Watch | A small fire burns beside a dry-stone sheepfold full of sleeping sheep, sparks rising into a sky full of stars. Slow tilt up from the fire to the stars. |
| `dawn_1` | The Anointing | First light. An old prophet with a long white beard, in a rough dark mantle, leads a young heifer on a rope up the road to a walled hill town. Wide shot, camera tracking beside him. |
| `dawn_2` | The Anointing | At the town gate a group of grey-bearded elders hurry out to meet the old prophet, anxious, hands half raised in greeting, and stop a few paces from him. Medium shot, slow push in. |
| `dawn_3` | The Anointing | Inside a courtyard, a tall handsome young man steps forward from a line of brothers and stands before the old prophet, who studies him and then slowly shakes his head. Over the prophet's shoulder, shallow focus. |
| `end_1` | End of chapter | The old prophet walks away alone down a road at morning, small in a wide landscape, an empty ram's horn hanging at his belt. Wide shot, camera still. |
| `end_2` | End of chapter | The shepherd boy, his hair still wet with oil, stands again among his sheep on a hillside, staff in hand, looking out over the hills as the wind rises. Slow orbit around him. |
| `end_3` | End of chapter | Night in a stone hall lit by a single lamp. A tall king sits alone on a carved seat with his head in his hands, his shadow huge on the wall behind him. Very slow push in. |

Order of importance if time runs short: all of Part A, then `prop_well`, `prop_wellstone`, `prop_torch`, `prop_embers`, `prop_lyre`, then the films for the sections that already exist (`count`, `ridge`, `dawn`, `end`), then Part C, then the rest.
