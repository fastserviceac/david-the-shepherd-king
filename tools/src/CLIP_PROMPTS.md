# David move clips to generate in Claude chat (Higgsfield)

## Paste this first

> Use the Higgsfield connector. For each prompt I give you, generate one video with model `seedance_2_0`, 720p, 16:9, no audio, using my unlimited allowance, with the attached image as the start image. Run them one at a time and give me the download link for each.

Attach `tools/src/david_start.png` (or tell it to use Higgsfield media id `bdaecf32-debb-4d96-b1b6-683bbef8a4bb`, which is the same picture already in the account).

Save each finished clip into `tools/src/clips/` with the file name shown. Any that come back flagged or wrong, skip; the game keeps its current animation for that move.

## Every prompt ends with this line

> Strict side-on profile view facing right, locked-off static camera, no zoom, no camera movement. He stays the same size, whole body visible from head to feet with clear space above his head and on both sides. Flat even green screen background, even lighting, no shadows on the wall, no dust, no extra objects or people.

## The clips

| File | Seconds | Prompt (add the line above to the end) |
|---|---|---|
| `run.mp4` | 6 | The young shepherd runs on the spot as if on a treadmill: a strong athletic running cycle, knees driving, arms pumping, cloak and hair moving with the stride. He stays in the centre of the frame. |
| `jump.mp4` | 5 | The young shepherd stands still, crouches, then jumps straight up as high as he can with his knees tucked, lands on both feet, absorbs the landing in a crouch and stands up again. He stays in the centre of the frame. |
| `hop.mp4` | 5 | The young shepherd stands in a ready stance, then springs one quick short hop backwards (to the left), landing balanced on both feet with knees bent, and settles into the ready stance. He does it twice. |
| `call.mp4` | 6 | The young shepherd stands calmly, raises one hand beside his mouth and calls out to his flock, then beckons with an open hand, and lowers his arm to stand calmly again. |
| `attack1.mp4` | 5 | The young shepherd holds a long wooden shepherd's staff in both hands. From a ready stance he swings the staff in one fast horizontal sweep from behind him to in front of him at chest height, then recovers to the ready stance. He does it twice. |
| `attack2.mp4` | 5 | The young shepherd holds a long wooden shepherd's staff in both hands. From a ready stance he lifts the staff above his head and brings it down in front of him in one fast overhead swing, then recovers to the ready stance. He does it twice. |
| `attack3.mp4` | 5 | The young shepherd holds a long wooden shepherd's staff in both hands. From a ready stance he drops low and sweeps the staff forward along the ground, then rises with an upward swing, and recovers to the ready stance. |
| `sling.mp4` | 6 | The young shepherd takes a leather shepherd's sling from his belt, whirls it in a circle above his head three times, and releases the stone forward with a full step, then lowers his arm. |
| `throw.mp4` | 5 | The young shepherd bends, picks up a small stone from the ground, draws his arm back and throws it forward overhand like a ball, then stands again. |
| `hurt.mp4` | 5 | The young shepherd is knocked off balance from the front: he flinches, staggers two steps backwards with one arm raised to guard himself, steadies, and stands again. |
| `clinch.mp4` | 6 | The young shepherd lunges forward and wrestles with something large and unseen in front of him: both arms wrapped around it at chest height, feet braced wide, straining and pushing forward, then he shoves it away with both hands and steps back into a ready stance. |
| `kneel.mp4` | 8 | The young shepherd stands calmly, slowly lowers himself onto one knee with his head bowed and hands resting on his raised knee, stays still for three seconds, then rises slowly to stand again. |
| `carry.mp4` | 6 | The young shepherd walks on the spot as if on a treadmill, carrying a small white lamb across his shoulders, holding its legs with both hands, with a steady careful walk. He stays in the centre of the frame. |

Order of importance if time runs short: run, jump, attack1, attack2, attack3, hurt, hop, clinch, sling, throw, call, kneel, carry.

## Redo: jump

The first jump clip cut David's head off at the top of the jump, so it can't be used. Ask for it again with this prompt (plus the usual last line):

> jump.mp4, 5 seconds: The young shepherd stands still in the lower half of the frame, small enough that there is as much empty space above his head as his own height. He crouches, then makes one modest jump straight up with his knees tucked, lands on both feet, absorbs the landing in a crouch and stands up again. His whole body, including his head, stays inside the frame at the top of the jump. He does not walk or run before or after.
