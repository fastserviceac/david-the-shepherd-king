# The lyre's sound (Chapter One, tranche 2)

Made 17 November 2026 (owner approved): one ElevenLabs music piece (900 credits) and four sounds (17 each). Sources are in
`tools/src/audio/`. `lyre_music.mp3` was cut at its rests into `lyre_phrase_00` to `_11` (each held to 3.2 s with a fade,
levelled to -24 LUFS) and its ringing close (37.55 to 43.0 s) became `lyre_song`; the separately made strum
(`tools/src/audio/lyre_song.mp3`) is kept but not used. `lyre_lost` and `lyre_sit` are levelled to -30 LUFS,
`sheep_settle` to -28. Played by `Game.lyre()` in `scripts/systems/game.gd`.

## Files the game looks for

| File | When it plays | Length |
|---|---|---|
| `audio/sfx/lyre_phrase_00.mp3` … `_11.mp3` | a phrase lands (played in turn, so a song is never the same three) | 1.5 to 3 s each |
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
