# Chapter One, deeper and longer: a plan to mark up

Nothing here is built and nothing has been spent. Scripture was checked against the World English Bible (WEB) on 16 November 2026. Minutes and credits are estimates.

## The idea

Chapter One becomes the making of Psalm 23. David keeps the same nine sheep through one shepherd's year, goes home to Bethlehem between seasons, and plays the lyre. Each place gives him one line of the psalm. The lamb the lion takes is one he delivered and raised. At the end the whole psalm is heard once.

## The new shape

Today: eight sections, 25 to 40 minutes on a first play. Rows in bold are new visits; only Bethlehem is a new place. Psalm lines use "the LORD", as the game's lines already do (WEB prints "Yahweh").

| # | Section or visit | Season | What is new | Psalm line earned | Min added |
|---|---|---|---|---|---|
| 1 | **Bethlehem: the house** | Spring | Jesse sends him out; water from the gate well; the lyre | "The LORD is my shepherd; I shall lack nothing." | 8 |
| 2 | The Pastures | Spring | His nine, four known by name; they lie down when he plays | "He makes me lie down in green pastures." | 6 |
| 3 | **Lambing night** (Pastures) | Late winter | He delivers the lamb and keeps a wolf off | none: the lamb is the reward | 12 |
| 4 | **Shearing** (Bethlehem) | Early summer | Calm each sheep, shear, carry fleeces; brothers at work | none | 10 |
| 5 | **The drought road** (Pastures, Wadi) | Summer | Lead the flock to far pasture; viper, hyena | "He guides me in the paths of righteousness" | 14 |
| 6 | The Well | Summer | The well is low; the lyre holds the flock | "He leads me beside still waters." | 5 |
| 7 | The Lost Lamb | Summer | The missing one is his lamb, by name | none | 3 |
| 8 | The Wadi | Summer | Its tracks beside the cat's | none | 3 |
| 9 | The Bear's Den | Summer | He plays in the dark before the bear | "Even though I walk through the valley of the shadow of death, I will fear no evil" | 3 |
| 10 | The Lion's Ridge | Summer | Carrying the lamb down | "Your rod and your staff, they comfort me." then "He restores my soul." | 4 |
| 11 | **Home with the lamb** (Bethlehem) | Autumn | Answers to Jesse; an errand; Eliab's doubt | none | 8 |
| 12 | **The cold pasture** (Pastures) | Winter | Rain and frost; shelter and fodder; leopard | none | 10 |
| 13 | The Night Watch | Winter | He eats by the fire with eyes in the dark; the lyre settles the fold | "You prepare a table before me in the presence of my enemies." | 10 |
| 14 | The Anointing | Winter's end | Fetched from the sheep, he walks in past seven brothers | "You anoint my head with oil. My cup runs over." | 6 |
| 15 | **The psalm** (ending) | | He plays it whole; the last line is new | "Surely goodness and loving kindness shall follow me…" | 5 |

**Arithmetic.** Added: 8+6+12+10+14+5+3+3+3+4+8+10+10+6+5 = **107 minutes**. With today's 25 to 40: **132 to 147**. Optional going back (stones, places, a strayed sheep): 15 to 25 more. Honest range: **2 hours 10 to 2 hours 50**. These are guesses until each tranche is timed.

## The five parts

### 1. The psalm spine

- **Player does:** after each trial he sits and plays; the line appears, is spoken, and fills a gap in the journal's psalm page.
- **Why:** every section gets a reason beyond "next place", and the ending is paid for.
- **Learned by:** the first line comes at home with nothing at stake; the gaps show more are coming.
- **Code:** a `find_line` in `game.gd`, modelled on `find_stone`; the moment reuses `add_gift` and `give_here` in `level_base.gd`; a page in `_journal` in `hud.gd`; lines in `data/narration/chapter1.json` and `.pt.json`.
- **Save:** `psalm`, the lines found.
- **Needs:** 9 new lines and one whole reading in both languages (about 2,400 characters); 1 piece of music.

### 2. The lyre

- **Player does:** hold a key and a line rises and falls like a breath; release at the top and the phrase lands. Three phrases settle what is near: a restless fold, a frightened sheep, a ewe in labour. Noise and beasts make the line jump. It is the playing proposed for Chapter Two.
- **Why:** "skillful in playing" is the first thing said of him to Saul. It is what takes him to court.
- **Learned by:** at home, a restless ewe by the door and the lyre on the wall beside her; one key-cap prompt.
- **Code:** a new `add_song` beside `add_task` in `level_base.gd`, with `shepherd_call` as the model; it acts on `worried`, `bolt`, `threat` and `stay` in `sheep.gd`; a playing state in `player.gd`; the breath line in `hud.gd`; a key in `_setup_input`, and sound through `sfx_hold` and `duck`, in `game.gd`.
- **Save:** `lyre` added to `gifts`.
- **Needs:** his seated playing and the lyre itself are already in the game (the Night Watch uses them). New: 4 sheep clips so the flock can lie down and rise, 1 piece of solo lyre cut into phrases, 4 sounds.

### 3. His own flock

- **Player does:** the same nine sheep in every section, each with its own look; four answer to names. He delivers a lamb in spring. A strayed sheep stays missing until fetched.
- **Why:** "those few sheep". The lion taking "a lamb" only hurts if the player knows which lamb.
- **Learned by:** the count at the Well, now of known faces; names are heard when he calls.
- **Code:** `add_sheep` in `level_base.gd` (today nine anonymous sheep per section) reads a flock list; `wool`, `size` and `mark` in `sheep.gd` already vary; `sheep_taken` and `lose_follow` write back; a flock page in `hud.gd`.
- **Save:** `flock` (nine entries: name, look, where it is) and `lamb_born`.
- **Needs:** 1 picture of the newborn, 5 ewe and lamb clips, 2 David clips (rubs it dry; gathers it up); about 12 short lines in each language. Prompts are in `tools/src/LAMB_SHEET.md`.

### 4. The shepherd's year

- **Player does:** returns to the Pastures and Wadi in other seasons with other work: lambing, shearing, the drought road, the cold pasture. Each of the four new animals belongs to one season.
- **Why:** a shepherd's skill is a year, not a day; the lion comes at the end of it.
- **Learned by:** each visit adds one tool and asks for it with an earlier one, as the rebuilt Well does.
- **Code:** new entries in `data/chapters.json`, each a script built on an existing section; `_build_sky`, `_build_painted`, `set_dark`, `add_pool`, `add_task`, `add_pushable`, `add_beast`, `send_wave` in `level_base.gd`; `ambience` and `music` in `game.gd`.
- **Save:** nothing new, but progress is kept as a section number, so existing saves must be converted.
- **Needs:** 3 paintings (parched pasture, parched wadi, winter pasture), 3 David clips (shears; carries fleeces; cold, cloak drawn), 10 sounds, about 25 lines in each language. The four animals' clips are already on `tools/src/NEW_BEASTS_SHEET.md`.

### 5. Bethlehem and his family

- **Player does:** three visits home. He answers to Jesse for the count, does one errand, and leaves with something: the lyre, shears, a winter cloak.
- **Why:** "they are his father's sheep" is the chapter's first reason; the father should be seen, and Samuel's visit means more once the player has stood last in that house.
- **Learned by:** no fighting at home: the calm place to meet each tool.
- **Code:** a new `bethlehem.gd` on `level_base.gd`, using `add_actor`, `actor_play`, `add_task`, `add_place`, `add_gift`, `say`.
- **Save:** `errands`, the ones done.
- **Needs:** 2 paintings (house and yard; gate and well), 5 people clips (Jesse 2, Eliab 1, brothers together 2; Jesse and the brothers already have standing figures in the game), about 30 lines in each language, 1 piece of home music, 6 short film shots between seasons.

## Cost (estimates; nothing is spent without your yes to a quoted price)

| Item | Count | Each | Total |
|---|---|---|---|
| Voice, English and Portuguese | about 13,900 characters | 1 | 13,900 ElevenLabs |
| Music | 3 | 900 | 2,700 ElevenLabs |
| Sounds | 20 | 55 | 1,100 ElevenLabs |
| Paintings, made and upscaled | 5 | 1,200 + 1,940 | 15,700 ElevenLabs |
| Picture of the newborn lamb | 1 | 1,200 | 1,200 ElevenLabs |
| **Without video** | | | **34,600 ElevenLabs** |
| Video by Runway kling-4 | 25 clips (19 animation, 6 film) | 60 | 1,500 Runway |
| or by ElevenLabs veo-3.1-lite | 25 clips | 2,424 | 60,600 ElevenLabs |

Every new line needs Brazilian Portuguese text and voice. Portuguese psalm lines come from the Bíblia Portuguesa Mundial, as the other verses do.

## Scripture, and what is not scripture

Checked in the WEB:

- Psalm 23: the lines above.
- 1 Samuel 17:34–35: "took a lamb out of the flock… rescued it out of his mouth".
- 1 Samuel 16:18: "skillful in playing".
- 1 Samuel 16:11: "There remains yet the youngest. Behold, he is keeping the sheep."
- 1 Samuel 17:12: "he had eight sons". 17:28: "those few sheep in the wilderness".
- 2 Samuel 23:15: "the well of Bethlehem, which is by the gate".
- Seasons: Psalm 78:71, "from following the ewes that have their young"; Genesis 31:40, "the drought consumed me, and the frost by night"; Genesis 37:12, a father's flock fed far from home; 1 Samuel 25:2, "shearing his sheep in Carmel".

Not in the text:

- The psalm's heading reads "A Psalm by David." (World English Bible; "Um Salmo de Davi" in the Bíblia Portuguesa Mundial), checked 16 November. That he made it as a boy with the sheep is tradition.
- WEB says "harp" (1 Samuel 16:23). "Lyre" is the usual reading of the Hebrew word.
- Named sheep, the lamb raised from birth, and David at lambing, shearing and far pasture are invention. The verses show the customs only. 2 Samuel 12:3 ("one little ewe lamb… grew up together with him") is a deliberate echo.
- 1 Chronicles 2:13–15 lists seven sons and calls David "the seventh". The plan follows 1 Samuel's eight.
- 1 Samuel 17:12–31, which holds "eight sons" and "those few sheep", is missing from the oldest Greek text of 1 Samuel. The plan follows the Hebrew, as the World English Bible does. Details are in `CHAPTER_TWO_PROPOSAL.md`.

## Build order

| Tranche | What | Done looks like | Tested by |
|---|---|---|---|
| 1. No new art, no spend | Psalm lines as text in both languages; the lyre with his existing seated playing and a stand-in sound; the named flock across all eight sections; saves converted | You play Pastures and the Well: same nine sheep, the lyre settles them, two lines in the journal | `--smoke` (fails on a missing Portuguese line); `--flow` through all eight; a new check that an old save loads; your save copied aside and restored |
| 2. Lyre and psalm made real | 2 clips, lyre music, psalm voiced | Playing looks and sounds finished | `--smoke`; `--shots` at 2560x1440; your ear |
| 3. The lamb | Lambing night; the lamb through to the Ridge | You know the lamb before the lion comes | `--flow`; timed play |
| 4. The year | Shearing, drought road, cold pasture, longer Night Watch, four animals | Each visit teaches one tool and combines two | `--smoke`, `--flow`; timed play |
| 5. Bethlehem | Three visits, longer Anointing, the ending | The whole chapter runs over two hours | Full `--flow`; timed play in both languages |

## A smaller version (chosen by the owner, 16 November 2026)

Build tranches 1 to 3 only, then start Chapter Two.

- **Kept:** the psalm spine, the lyre, the named flock, lambing night and the lamb, the ending psalm. Rows 2, 3, 6 to 10, part of 13, and 15.
- **Left for later:** the seasons (rows 4, 5, 12) and Bethlehem (rows 1, 11, the longer 14).
- **Length:** about 46 minutes added, so Chapter One runs about 70 to 85 minutes.
- **Cost estimate:** 11 clips and 1 picture (see `tools/src/LAMB_SHEET.md`), no paintings: about 6,800 ElevenLabs credits without video, plus about 660 Runway credits or about 26,700 ElevenLabs credits for the clips.
- **Why:** Chapter Two opens in Jesse's house and is built on the lyre, so Bethlehem and the playing get made there anyway and can be brought back into Chapter One afterwards. The seasons and Bethlehem are most of the cost here, and the lyre is untested: better to learn whether it plays well before building two hours on it.

## Risks

- Your real save must survive the new section order.
- The lyre moves into Chapter One, so Chapter Two's first gift must change.
- I cannot hear the lyre or see motion at speed; those are yours to judge.

## Choices for you

1. **How the lyre plays.** Breath-and-release, or a rhythm game? *Recommend breath-and-release, the same in both chapters.*
2. **Where the lyre comes from.** It hangs in Jesse's house and he may take it, or he makes it himself? *Recommend Jesse's house: it ties the lyre to home.*
3. **Can a named sheep be lost for good?** *Recommend no: it stays missing until fetched, and only the lamb is ever taken.*
4. **Names.** Four fixed Hebrew names with meanings, or the player's own? *Recommend fixed, so his voice can call them.*
5. **Seasons.** New paintings for parched and winter land, or existing ones re-coloured? *Recommend new (about 9,400 credits for three).*
6. **Video.** Runway at about 60 a clip, or ElevenLabs at about 2,424? *Recommend one Runway test clip of David first; use Runway only if he matches.*
7. **Tranche 1 with stand-ins.** Only the lyre's sound is a stand-in, and the sheep cannot lie down yet. See it early for feel, or wait for tranche 2? *Recommend seeing it early.*
8. **Length.** Accept about 2 hours 10 to 2 hours 50, or add more to be sure of three? *Recommend accepting, and timing each tranche.*
