# story films: build_story.py <id> <work dir> --shots ... --lines ...
python3 tools/build_story.py well /tmp/story_well --shots tools/src/films/well_1.mp4 tools/src/films/well_2.mp4 --lines n_well_intro
python3 tools/build_story.py count /tmp/story_count --shots tools/src/films/count_1.mp4@top tools/src/films/count_3.mp4@bottom --lines n_s2_intro --music audio/music/theme_tender.mp3
python3 tools/build_story.py wadi /tmp/story_wadi --shots tools/src/films/wadi_1.mp4 tools/src/films/wadi_2.mp4 --lines n_wadi_intro --music audio/music/theme_uneasy.mp3
python3 tools/build_story.py den /tmp/story_den --shots tools/src/films/den_1.mp4 tools/src/films/den_2.mp4@top --lines n_den_intro --music audio/music/theme_uneasy.mp3
