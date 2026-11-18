# story films: build_story.py <id> <work dir> --shots ... --lines ...
python3 tools/build_story.py well /tmp/story_well --shots tools/src/films/well_1.mp4 tools/src/films/well_2.mp4 --lines n_well_intro
python3 tools/build_story.py count /tmp/story_count --shots tools/src/films/count_1.mp4@top tools/src/films/count_2.mp4@top tools/src/films/count_3.mp4@bottom --lines n_s2_intro --music audio/music/theme_tender.mp3
python3 tools/build_story.py wadi /tmp/story_wadi --shots tools/src/films/wadi_1.mp4 tools/src/films/wadi_2.mp4 --lines n_wadi_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py den /tmp/story_den --shots tools/src/films/den_1.mp4 tools/src/films/den_2.mp4@top --lines n_den_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py ridge /tmp/story_ridge --shots tools/src/films/ridge_1.mp4 tools/src/films/ridge_2.mp4@top --lines n_s3_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py watch /tmp/story_watch --shots tools/src/films/watch_1.mp4 tools/src/films/watch_2.mp4 --lines n_watch_intro --music audio/music/theme_tender.mp3
# the prophet comes up the road as the prologue showed him (striped robe), named by the line, before David comes down
python3 tools/build_story.py dawn /tmp/story_dawn --shots tools/src/films/dawn_road.mp4@0.2 tools/src/films/dawn_3.mp4@top tools/src/films/dawn_1.mp4 --lines n_dawn_samuel n_s4_brothers@2 n_s4_intro@3 --music audio/music/theme_still.mp3
# the film that closes the chapter
python3 tools/build_story.py end /tmp/story_end --shots tools/src/films/end_1.mp4 tools/src/films/end_2.mp4@0.25 tools/src/films/end_3.mp4 --lines n_end_samuel n_end_david@2 n_end_saul@3 n_end_lyre --music audio/music/theme_uneasy.mp3
# Chapter Two. The opening: the king's torment, his servants, the young man who has seen a son of Jesse, the messengers
python3 tools/build_story.py c2_summons /tmp/story_c2_summons --chapter 2 --shots tools/src/films/c2/c2_torment.mp4@0.3 tools/src/films/c2/c2_servants.mp4 tools/src/films/c2/c2_witness.mp4@top tools/src/films/c2/c2_messenger.mp4@0.7 --lines 1sam16_14 1sam16_16@2 1sam16_18@3 n_c2s1_intro@4 1sam16_19@4 --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py c2_road /tmp/story_c2_road --chapter 2 --shots tools/src/films/c2/c2_donkey_2.mp4@top tools/src/films/c2/c2_leaving.mp4@top --lines n_c2s2_intro --music audio/music/theme_tender.mp3
python3 tools/build_story.py c2_gate /tmp/story_c2_gate --chapter 2 --shots tools/src/films/c2/c2_road.mp4 tools/src/films/c2/c2_gibeah.mp4@0.7 --lines n_c2s3_intro --music audio/music/theme_still.mp3
python3 tools/build_story.py c2_hall /tmp/story_c2_hall --chapter 2 --shots tools/src/films/c2/c2_enter_2.mp4 --lines n_c2s4_intro --music audio/music/theme_still.mp3
# before the Armour-Bearer: he plays and the king comes to rest (c2_play has a modern mandolin and c2_play_2 tilts off his face, so this shot was made for it)
python3 tools/build_story.py c2_bearer /tmp/story_c2_bearer --chapter 2 --shots tools/src/films/c2/c2_play_3.mp4 --lines n_c2s5_intro --music audio/music/theme_tender.mp3
# the film that closes Chapter Two: back up the road, and at Gibeah the king's hand closing on his spear
python3 tools/build_story.py end2 /tmp/story_end2 --chapter 2 --shots tools/src/films/c2/c2_road.mp4 tools/src/films/c2/c2_spear.mp4 --lines n_c2s7_end 1sam17_15@2 --music audio/music/theme_uneasy.mp3
