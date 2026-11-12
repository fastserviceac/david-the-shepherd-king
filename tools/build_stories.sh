# story films: build_story.py <id> <work dir> --shots ... --lines ...
python3 tools/build_story.py well /tmp/story_well --shots tools/src/films/well_1.mp4 tools/src/films/well_2.mp4 --lines n_well_intro
python3 tools/build_story.py count /tmp/story_count --shots tools/src/films/count_1.mp4@top tools/src/films/count_3.mp4@bottom --lines n_s2_intro --music audio/music/theme_tender.mp3
python3 tools/build_story.py wadi /tmp/story_wadi --shots tools/src/films/wadi_1.mp4 tools/src/films/wadi_2.mp4 --lines n_wadi_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py den /tmp/story_den --shots tools/src/films/den_1.mp4 tools/src/films/den_2.mp4@top --lines n_den_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py ridge /tmp/story_ridge --shots tools/src/films/ridge_1.mp4 tools/src/films/ridge_2.mp4@top --lines n_s3_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py watch /tmp/story_watch --shots tools/src/films/watch_1.mp4 tools/src/films/watch_2.mp4 --lines n_watch_intro --music audio/music/theme_tender.mp3
# the prophet comes up the road as the prologue showed him (striped robe), named by the line, before David comes down
python3 tools/build_story.py dawn /tmp/story_dawn --shots tools/src/films/dawn_road.mp4@0.2 tools/src/films/dawn_1.mp4 --lines n_dawn_samuel n_s4_intro@2 --music audio/music/theme_still.mp3
# the film that closes the chapter: needs tools/src/films/end_1.mp4, end_2.mp4, end_3.mp4 (not yet made)
# python3 tools/build_story.py end /tmp/story_end --shots tools/src/films/end_1.mp4 tools/src/films/end_2.mp4 tools/src/films/end_3.mp4 --lines n_end_samuel n_end_david n_end_saul n_end_lyre --music audio/music/theme_uneasy.mp3
