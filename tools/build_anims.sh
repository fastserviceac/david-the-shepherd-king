#!/bin/zsh
# Re-cuts every animation set from the source clips. usage: build_anims.sh <folder holding the extracted clip frames>
V=$1; A="tools/anim.py"; D=art/david/anim
run() { python3 $A "$@" 2>&1 | grep frames }
# the older clips film David about 5% larger than the newer ones (idle, walk, run), so they are cut at a larger reference height to match
david() { run "$@" href=630 soft=1 }
run $V/run2 $D run mode=loop double=1 href=608 soft=1 steady=40
# his idle is the calm side-on stance at the end of the look-about clip, so it matches his walk and roll
run $V/idle2 $D idle mode=range a=214 b=241 step=2 href=628 soft=1
run $V/n_jumpb $D jump mode=range a=20 b=100 step=2 hframe=0 feet=each soft=1 steady=999
run $V/n_attack1 $D attack mode=range a=90 b=108 step=1 hframe=60 soft=1 wide=2.6 steady=999
run $V/n_attack3 $D attack2 mode=range a=14 b=30 step=1 hframe=0 soft=1 wide=2.6 steady=999   # low sweep
run $V/n_attack3 $D attack3 mode=range a=22 b=40 step=1 hframe=0 soft=1 wide=2.6 tall=2.1 steady=999   # rising blow
run $V/n_attack2 $D attack4 mode=range a=18 b=36 step=1 hframe=0 soft=1 wide=2.6 tall=2.1 steady=999   # overhead smash, the end of a chain
run $V/spin $D spin mode=range a=76 b=107 step=1 hframe=2 soft=1 wide=3.0 steady=999   # the round blow: one full turn, staff level (Runway kling-4 clip, tools/src/clips/spin.mp4); then anchor.py spin 0
run $V/n_sling $D sling mode=range a=48 b=95 step=2 hframe=0 soft=1 steady=999     # the whirl, looped while he winds up
run $V/n_sling $D throw mode=range a=100 b=132 step=2 hframe=0 soft=1 steady=999    # the release and follow-through, from the same clip
david $V/hurt $D hurt mode=range a=20 b=56 step=2 hframe=160
run $V/n_carry $D carry mode=loop double=1 href=604 soft=1 steady=40 tall=2.1     # the lamb across his shoulders
run $V/walk $D walk mode=loop double=1 href=605 step=2 soft=1 steady=40 rim=6
run $V/roll $D roll mode=range a=18 b=68 step=2 hframe=0 soft=1
run $V/duck $D duck mode=range a=40 b=136 step=6 hframe=0 soft=1 steady=999
# looking about when left standing; this clip shows him larger (about 628 px)
run $V/idle2 $D idle2 mode=range a=0 b=239 step=3 href=628 soft=1
run $V/sheep art/sheep/anim walk key=blue mode=loop double=1 wide=1.5 tall=1.4 size=110 erode=9
run $V/graze art/sheep/anim graze key=blue mode=range a=0 b=188 step=4 hframe=0 wide=1.5 tall=1.4 size=110 erode=9
python3 tools/rim_clean.py art/sheep/anim      # the sheep clips carry an orange glow round the animal: eat it off the outline
run $V/jackal art/jackal/anim walk mode=loop double=1 wide=1.8 tall=1.4 size=110 erode=3
run $V/lunge art/jackal/anim lunge mode=range a=64 b=134 step=2 hframe=0 wide=1.8 tall=1.8 size=110 feet=each erode=3
# the bear's walk, from a clip started on the game's own bear: two full gait cycles (bear.gd stride is set to match)
run $V/h_bear_walk2 art/bear/anim walk key=blue mode=loop double=1 wide=1.5 tall=1.4 size=150
run $V/lion art/lion/anim walk mode=loop double=1 wide=1.8 tall=1.4 size=150 halo=0 erode=3
run $V/pounce art/lion/anim crouch mode=range a=16 b=64 step=4 hframe=0 halo=0 wide=1.8 tall=1.4 size=150 erode=3
run $V/pounce art/lion/anim pounce mode=range a=96 b=156 step=2 hframe=0 halo=0 wide=1.8 tall=1.8 size=150 feet=each erode=3
run $V/roar art/lion/anim roar mode=range a=40 b=132 step=4 hframe=0 halo=0 wide=1.8 tall=1.8 size=150 erode=3
run $V/roar art/lion/anim pant mode=range a=140 b=188 step=4 hframe=0 halo=0 wide=1.8 tall=1.4 size=150 erode=3

# the bear's rear-up comes from a clip upscaled to 1440p, so its pixel settings are doubled
run $V/rear2x art/bear/anim rear mode=range a=24 b=64 step=4 hframe=0 wide=1.5 tall=2.3 size=150 white=1 erode=9 inner=16
run $V/rear2x art/bear/anim swipe mode=range a=80 b=118 step=2 hframe=0 wide=1.5 tall=2.3 size=150 white=1 erode=9 inner=16
python3 tools/bear_fix.py 2>&1 | grep tidied
echo ALL DONE
# Samuel anointing. The 1440p upscale of the clip has the detail but a pink cast, so colour comes from the original clip:
#   python3 tools/anim.py $V/pour3 /tmp/an1 anoint key=magenta mode=range a=0 b=239 step=3 href=314 size=138 res=2 wide=0.9 tall=1.45 erode=3 inner=6
#   python3 tools/anim.py $V/pour3x art/samuel/anim anoint key=magenta mode=range a=0 b=239 step=3 href=628 size=276 res=2 wide=0.9 tall=1.45 erode=5 inner=12
#   python3 tools/anoint_colour.py /tmp/an1 && python3 tools/anoint_fix.py
run $V/sway $D sway mode=range a=10 b=56 step=2 hframe=0 soft=1 wide=1.6 steady=999
run $V/n_throw $D pickup mode=range a=8 b=34 step=2 hframe=0 soft=1 steady=999     # bending to the ground: shown while he works with his hands
run $V/n_throw $D toss mode=range a=46 b=98 step=2 hframe=0 soft=1 steady=999       # an overhand throw; not used yet
run $V/n_hurt $D flinch mode=range a=48 b=66 step=1 hframe=0 soft=1 steady=999 wide=2.0     # knocked back by a blow
run $V/n_clinch $D push mode=range a=40 b=92 step=4 hframe=0 soft=1 steady=999 wide=1.6     # braced against something heavy (the clip asked for a clinch; it came with a boulder)
python3 tools/push_fix.py
run $V/n_hop $D hop mode=range a=13 b=40 step=1 hframe=0 soft=1 steady=3     # the skip backwards: he travels in the clip, so each frame is centred on him
python3 tools/anchor.py hop 27
run $V/n_call $D call mode=range a=14 b=118 step=4 hframe=0 soft=1 steady=999 wide=1.6     # hand to his mouth, then beckoning
python3 tools/anchor.py call 0
run $V/n2_clinch $D clinch mode=range a=20 b=132 step=4 hframe=0 soft=1 steady=3 wide=1.8     # seizing a spent beast: arms locked, braced
python3 tools/anchor.py clinch 0
run $V/n_draw $D draw mode=range a=22 b=100 step=3 hframe=0 soft=1 steady=999 wide=1.8     # hauling the bucket up out of the well
run $V/n_draw $D pour mode=range a=104 b=144 step=2 hframe=0 soft=1 steady=999 wide=1.8    # tipping it into the trough
python3 tools/anchor.py draw 0 pour 0
run $V/n_lyre $D lyre mode=range a=0 b=192 step=4 href=603 soft=1 steady=999 wide=1.6     # sitting down with the kinnor, playing, lifting his face
# kneeling: one cut of the whole clip, dealt into going down, staying down and rising (tools/kneel_split.py)
mkdir -p $V/kn_cut; run $V/n_kneel $V/kn_cut kn mode=range a=16 b=188 step=2 hframe=0 soft=1 steady=999 wide=2.0
python3 tools/kneel_split.py $V/kn_cut
# his feet stay on one spot when the game changes from one move to another
python3 tools/anchor.py jump 0 attack 0 attack2 0 attack3 18 attack4 0 sway 0 idle2 0 sling 4 throw 0 pickup 0 toss 26 flinch 0
# animal moves made later, each started from a frame of the animal's own first clip so it is the same beast
run $V/r_sheep_leap art/sheep/anim leap key=blue mode=range a=42 b=104 step=2 hframe=0 wide=1.5 tall=2.7 size=110 erode=9
python3 tools/rim_clean.py art/sheep/anim
run $V/r_bear_run art/bear/anim run mode=range a=48 b=118 step=2 hframe=0 wide=1.8 tall=1.4 size=150
run $V/r_bear_daze art/bear/anim daze mode=range a=16 b=76 step=3 hframe=0 wide=1.8 tall=1.4 size=150 steady=999
run $V/r_bear_daze art/bear/anim brace mode=range a=78 b=120 step=3 hframe=0 wide=1.8 tall=1.4 size=150 steady=999
run $V/r_lion_run art/lion/anim run mode=range a=30 b=118 step=2 hframe=0 halo=0 erode=3 wide=2.2 tall=1.4 size=150
run $V/r_lion_rake art/lion/anim rake mode=range a=20 b=52 step=2 hframe=0 halo=0 erode=3 wide=2.2 tall=1.4 size=150 steady=999
# the bear's rear-up and slam, from a clip started on the game's own bear (tools/src/bear_start.png)
run $V/h_bear_slam art/bear/anim slamup key=blue mode=range a=2 b=26 step=2 hframe=0 wide=1.8 tall=2.3 size=150
run $V/h_bear_slam art/bear/anim slam key=blue mode=range a=64 b=94 step=2 hframe=0 wide=1.8 tall=2.3 size=150
run $V/h_lion_vault art/lion/anim vault key=blue mode=range a=64 b=116 step=2 hframe=0 halo=0 erode=3 wide=2.2 tall=1.8 size=150
# the jackal worrying at a sheep, and running flat out, from clips started on the game's own jackal (tools/src/jackal_start.png)
run $V/h_jackal_worry art/jackal/anim worry key=blue mode=range a=24 b=108 step=3 hframe=0 wide=1.8 tall=1.4 size=110 erode=3
run $V/h_jackal_flee art/jackal/anim run key=blue mode=range a=52 b=116 step=2 hframe=60 wide=1.8 tall=1.4 size=110 erode=3
# the sheep's run, from a green-screen clip started on the game's own sheep (tools/src/sheep_start_green.png)
run $V/g_sheep_run_green art/sheep/anim run key=green halo=2 mode=loop double=0 wide=1.5 tall=1.4 size=110 erode=3

# Chapter Two, the Summons (clips in tools/src/clips/c2; frames extracted with tools/frames.swift at 24 fps, then the
# black bar rows (top/bottom 6 px, sides 2 px) of every frame overwritten with their neighbouring row/column before keying)
# the keeper's green screen is a muddy grey-green (84,124,75): halo=3 keys it
run $V/keeper_idle art/keeper/anim idle key=green halo=3 wide=1.2 tall=1.3 size=152 erode=3 mode=range a=0 b=143 step=5
# all four donkey sets share href=575 so the donkey is the same size and stands on the same spot
run $V/donkey_walk art/donkey/anim walk key=blue wide=1.5 tall=1.4 size=125 erode=3 href=575 mode=loop step=2
run $V/donkey_idle art/donkey/anim idle key=blue wide=1.5 tall=1.4 size=125 erode=3 href=575 mode=range a=0 b=143 step=6
run $V/donkey_balk art/donkey/anim balk key=blue wide=1.5 tall=1.4 size=125 erode=3 href=575 mode=range a=31 b=78 step=2 steady=999
run $V/donkey_calm art/donkey/anim calm key=blue wide=1.5 tall=1.4 size=125 erode=3 href=575 mode=range a=60 b=108 step=3 steady=999
run $V/mule_idle art/mule/anim idle key=blue wide=1.5 tall=1.4 size=165 erode=3 mode=range a=0 b=143 step=5
run $V/kid_idle art/kid/anim idle key=blue wide=1.2 tall=1.4 size=62 erode=3 grow=2 mode=range a=0 b=143 step=6
# paintings: cp tools/src/art_in/c2/c2_home_{backdrop,mid}.png tools/src/art_in/ ; python3 tools/scenery.py c2_home   (scenery.py defringes c2_home's mid)
# the messenger's idle (skips the first 1.1 s, where the staff is still slanted) and the keeper counting, first 3.5 s only
run $V/messenger_idle art/messenger/anim idle key=green halo=3 wide=1.2 tall=1.3 size=156 erode=3 mode=range a=28 b=143 step=4
run $V/keeper_count_2 art/keeper/anim count key=green halo=3 wide=1.2 tall=1.3 size=152 erode=3 mode=range a=0 b=84 step=4
# David plays the lyre standing and walking (ElevenLabs Veo clips from tools/src/art_in/c2/david_lyre_start_2.png; frames extracted at 24 fps into <dir>/c2_lyre_{stand,walk}_3)
# href differs from the usual 605 because the lyre/hair make the silhouette taller: stand 612, walk 617 match his walk (288 px) and idle (295 px) heights
run $V/c2_lyre_stand_3 $D lyre_stand mode=range a=0 b=95 step=4 href=612 soft=1 steady=999 wide=1.6     # plays to and fro
run $V/c2_lyre_walk_3 $D lyre_walk mode=loop double=1 href=617 soft=1 steady=40 wide=1.6 step=2     # one 2-step cycle, loops

# Chapter Two, the Gate of Gibeah (Higgsfield seedance_2_0 clips in tools/src/clips/c2, 122 frames each at 24 fps, black bar rows fixed as above)
# their green is muddier still than the keeper's (81,116,76): halo=3 leaves a veil of it round them, halo=4 keys it
run $V/steward_idle art/steward/anim idle key=green halo=4 wide=1.2 tall=1.3 size=156 erode=3 mode=range a=0 b=120 step=5     # he rubs his brow in the middle of it: kept, he is tired
run $V/youth_idle art/youth/anim idle key=green halo=4 wide=1.2 tall=1.3 size=148 erode=3 mode=range a=0 b=120 step=5
run $V/gatekeeper_idle art/gatekeeper/anim idle key=green halo=4 wide=1.2 tall=1.3 size=158 erode=3 mode=range a=0 b=120 step=5
run $V/jonathan_idle art/jonathan/anim idle key=green halo=4 wide=1.2 tall=1.3 size=160 erode=3 mode=range a=0 b=120 step=5     # seen up on the wall, drawn at 0.62
# paintings: cp tools/src/art_in/c2/c2_{gibeah_backdrop,gibeah_mid,court_backdrop}.png tools/src/art_in/ ; python3 tools/scenery.py c2_gibeah c2_court c2_gate c2_gate_open
# (scenery.py fades c2_court's foot and feathers the two ends of the gate props so they melt into the wall band)
