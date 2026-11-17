# The lyre's sound (Chapter One, tranche 2)

Nothing here has been generated or paid for. The game already asks for these files and plays the old stand-in
(three rising tones) until they exist: `Game.lyre()` in `scripts/systems/game.gd`.

## Files the game looks for

| File | When it plays | Length |
|---|---|---|
| `audio/sfx/lyre_phrase_00.mp3` … `_05.mp3` | a phrase lands (played in turn, so a song is never the same three) | 1.5 to 3 s each |
| `audio/sfx/lyre_song.mp3` | the third phrase: the song goes out to the flock | 3 to 5 s |
| `audio/sfx/lyre_lost.mp3` | a phrase let go too soon | under 1 s |
| `audio/sfx/lyre_sit.mp3` | he takes the lyre up | under 1 s |
| `audio/sfx/sheep_settle.mp3` | sheep reached by the song settle | 1 to 3 s |

## How to make them

1. **One piece of solo lyre music** (ElevenLabs music, about 900 credits, any length up to about 60 s), cut at its
   rests into six phrases and one longer closing strum. Prompt:

   > Solo kinnor, a small ancient wooden lyre with ten gut strings, played alone and unhurried by a young shepherd
   > out on a hillside. Gentle plucked phrases in a simple mode, each phrase rising and settling, with a short
   > pause between phrases, ending on a soft full strum that rings out. No other instruments, no voice, no
   > percussion, no reverb hall, intimate and close, warm.

2. **Four sounds** (ElevenLabs sound effects, about 55 credits each):
   - `lyre_lost`: "A single gut string on a small wooden lyre plucked and immediately damped by the hand, a short dull buzz, close."
   - `lyre_sit`: "A small wooden lyre lifted onto the knee: a soft knock of wood and one string brushed lightly, close."
   - `lyre_song`: only if the music piece has no usable closing strum. "A slow full strum across ten gut strings of a small wooden lyre, ringing out gently."
   - `sheep_settle`: "A sheep lying down in grass: a soft contented low murmur, a rustle, a slow breath out, close and quiet."

Check by measurement (length, loudness, where the energy sits; keep most of it above 80 Hz for laptop speakers),
then by the owner's ear.
