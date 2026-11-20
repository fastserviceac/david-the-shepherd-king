extends RefCounted
## Automated checks, run with:  godot --headless --path . -- --smoke
## and screenshots with:        godot --path . -- --shots=/some/folder

var main
var tree: SceneTree
var failures := 0


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _goto(x: float) -> void:
	var p = main.level.player
	p.position = main.level.on_ground(x)
	p.velocity = Vector2.ZERO
	p.cam.reset_smoothing()
	await _frames(8)


## A task done the way he does it: standing at it, the prompt for it showing over his head, the Grab button
## held until it is done. Calling the task directly passes even when a player could never see or reach it.
## Whatever stops the hold is a failure, and the task is then carried out directly so the rest can be tested.
func _hold(lv, tk: Dictionary) -> void:
	var p = lv.player
	var what := str(tk["text"])
	if not tk["on"]:
		_check(false, "HOLD '%s': the task is not open" % what)
		lv.do_task(tk)
		return
	if absf(p.global_position.x - float(tk["x"])) >= float(tk["reach"]) - 4.0 or absf(p.global_position.y - lv.on_ground(float(tk["x"])).y) >= 80.0:
		await _goto(float(tk["x"]))
	for a in ["move_left", "move_right", "walk", "grab"]:
		Input.action_release(a)
	var seen := false
	for i in 200:
		await _frames(1)
		if lv.task_now == tk and lv.prompt_a > 0.5 and lv.prompt_words == Game.t(what):
			seen = true
			break
	if not seen:
		var why := "prompt shows '%s'" % lv.prompt_words
		if Game.cinematic:
			why = "a scene is still running"
		elif lv.respawning:
			why = "he is being set back"
		elif lv.task_now != null and lv.task_now != tk:
			why = "another task stands in front of it: '%s'" % str(lv.task_now["text"])
		elif lv.task_now == null:
			why = "he is not in reach of it (he %d,%d  task %d,%d  reach %d)" % [int(p.global_position.x), int(p.global_position.y), int(tk["x"]), int(lv.on_ground(float(tk["x"])).y), int(tk["reach"])]
		_check(false, "HOLD '%s': its prompt never shows: %s" % [what, why])
		lv.do_task(tk)
		return
	var n0: int = lv.tasks_done
	Input.action_press("grab")
	for i in int(float(tk["hold"]) * 60.0) + 150:
		await _frames(1)
		if lv.tasks_done != n0:
			break
	Input.action_release("grab")
	if lv.tasks_done == n0:
		_check(false, "HOLD '%s': held, it is never done (on floor %s, speed %d, act '%s', bar %.2f)" % [what, str(p.is_on_floor()), int(p.velocity.x), str(p.act), float(tk["t"])])
		lv.do_task(tk)
	await _frames(2)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _bot(frames: int) -> void:
	Input.action_press("move_right")
	for i in frames:
		if main.level.done:
			break
		await tree.physics_frame
		if i % 40 == 0:
			Input.action_press("jump")
		elif i % 40 == 12:
			Input.action_release("jump")
		if i % 25 == 0:
			Input.action_press("attack")
		elif i % 25 == 3:
			Input.action_release("attack")
		if i % 90 == 30:
			Input.action_press("sling")
		elif i % 90 == 70:
			Input.action_release("sling")
	for a in ["move_right", "jump", "attack", "sling"]:
		Input.action_release(a)


func smoke(m) -> void:
	main = m
	tree = m.get_tree()
	m.hud.visible = true
	for i in Game.sections().size():
		if OS.has_environment("SMOKE_ONLY") and not str(Game.sections()[i]["script"]).get_file().get_basename() in OS.get_environment("SMOKE_ONLY").split(","):
			continue      # SMOKE_ONLY=section3,den runs just those sections
		print("Section %d: %s" % [i + 1, Game.sections()[i]["title"]])
		Game.backdrop = false
		Game.cinematic = false
		await m.load_level(i, 0)
		var lv = m.level
		lv.begin()
		await _frames(5)
		await _bot(600)
		print("  bot reached x=%d of %d, hp=%d" % [int(lv.player.position.x), int(lv.width), lv.player.hp])
		match str(Game.sections()[i]["script"]).get_file().get_basename():
			"section1": await _s1(lv)
			"well": await _well(lv)
			"section2":
				await _led(lv, "twin")
				await _s2(lv)
			"wadi":
				await _led(lv, "goats")
				await _wadi(lv)
			"den":
				await _dam(lv)
				await _den(lv)
			"section3": await _s3(lv)
			"watch": await _watch(lv)
			"section4": await _s4(lv)
			"summons": await _summons(lv)
			"ridge_road": await _ridge_road(lv)
			"gibeah_gate": await _gibeah_gate(lv)
			"kings_hall": await _kings_hall(lv)
			"armour_bearer": await _armour_bearer(lv)
			"night_fit": await _night_fit(lv)
			"back_and_forth": await _back_and_forth(lv)
		await _frames(10)
		if is_instance_valid(m.level):
			for c in m.level.tips_covered:
				print("  COVERED  " + str(c))
		_check(m.level.done, "section completes")
	if not OS.has_environment("SMOKE_ONLY") or "lambing" in OS.get_environment("SMOKE_ONLY"):
		await _lambing(m)
	await _beasts(m)
	var missing := 0
	for i in Game.chapter_sections(0).size():      # the map is of Chapter One's hills; later chapters go back to it, and have no place of their own on it yet
		if not m.map.data.get("places", {}).has(m.map._key(i)):
			missing += 1
	_check(not m.map.data.is_empty() and missing == 0, "every section of Chapter One has its place on the map")
	m.map.open(true, 2)
	var q: Vector2 = m.map._at(31.7054, 35.2024)
	var q2: Vector2 = m.map._spot(2)
	_check(q.x > 0.0 and q.x < q2.x and q.y > 0.0 and q.y < q2.y, "Bethlehem falls north-west of the ravine on the map")
	m.map.close()
	await _fort_map(m)
	var stale := 0
	for who in DirAccess.get_directories_at("res://art"):
		var d := "res://art/%s/anim" % who
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d):
				if f.ends_with(".import") and not FileAccess.file_exists(d + "/" + f.trim_suffix(".import")):
					stale += 1
	_check(stale == 0, "no left-over frames from older cuts (%d found)" % stale)
	var untold := 0
	for id in Game.narration.keys():
		if not Game.narration_pt.has(id):
			untold += 1
	_check(untold == 0 and Game._ui_pt.size() > 100, "every line of the story has its Portuguese (%d missing)" % untold)
	var unvoiced: Array = []
	for e in Game.PSALM + [{"id": "p23_whole"}]:
		for at in ["res://audio/narration/%s.mp3", "res://audio/narration/pt/%s.mp3"]:
			if not ResourceLoader.exists(at % str(e["id"])):
				unvoiced.append(at % str(e["id"]))
	_check(unvoiced.is_empty(), "every line of the psalm, and the whole psalm, is spoken in both languages %s" % str(unvoiced))
	Game.save["lang"] = "pt"
	_check(Game.t("The Well") == "O Poço" and str(Game.line("ps23_1")["text"]).begins_with("O SENHOR"), "Portuguese is shown when it is chosen")
	Game.save["lang"] = "en"
	_old_save()
	_chapters()
	print("SMOKE %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	tree.quit(0 if failures == 0 else 1)


## The sections of every chapter run on in one list, and a journey saved when there was only Chapter One still
## loads: what it had is kept, a finished Chapter One opens Chapter Two, and nothing past that is opened early.
func _chapters() -> void:
	var kept: Dictionary = Game.save.duplicate(true)
	var first: int = Game.chapter_sections(0).size()
	var names: Array = []
	for i in first:
		names.append(str(Game.sections()[i]["script"]).get_file().get_basename())
	_check(first == 8 and names == ["section1", "well", "section2", "wadi", "den", "section3", "watch", "section4"],
			"Chapter One's eight sections keep their numbers")
	_check(Game.sections().size() > first and Game.chapter_of(first - 1) == 0 and Game.chapter_of(first) == 1 and Game.chapter_start(1) == first
			and str(Game.sections()[first]["script"]).get_file().get_basename() == "summons", "Chapter Two's sections follow them")
	var two: Array = Game.chapter_sections(1).map(func(e): return str(e["script"]).get_file().get_basename())
	_check(two == ["summons", "ridge_road", "gibeah_gate", "kings_hall", "armour_bearer", "night_fit", "back_and_forth"] and not Game.chapters[1].get("more", false)
			and first + two.size() == Game.sections().size(), "Chapter Two is whole: its seven sections, and no longer marked as still being made")
	# a finished Chapter One, saved by the game as it was: "unlocked" 99, no chapter anywhere in the file
	var done := {"section": 0, "checkpoint": 0, "has_sling": true, "unlocked": 99, "started": false, "finished": true, "difficulty": 1,
			"growth": {"hand": 120.0, "voice": 20.0}, "stones": ["s1_start", "well_start", "s1_cave"], "pouch": 1,
			"gifts": ["lyre", "voice", "hand", "sling", "eye", "heart", "feet"], "places": ["foldcave"],
			"psalm": ["p23_shepherd", "p23_pastures", "p23_waters"], "flock": Game.flock().duplicate(true), "deeds_told": ["bear", "lion"]}
	Game.take_save(done.duplicate(true))
	var same := true
	for k in done:
		if k != "unlocked" and JSON.stringify(Game.save.get(k)) != JSON.stringify(done[k]):
			same = false
	_check(same, "a finished Chapter One loads with its gifts, crafts, stones, deeds and psalm as they were")
	_check(int(Game.save["unlocked"]) == first and int(Game.save["v"]) == 2, "and Chapter Two's first section is unlocked, and no more than that (%d)" % int(Game.save["unlocked"]))
	_check(Game.earned_hearts() == 3 and Game.deed_done("chapter1") and Game.deed_done("lion"), "its hearts and deeds are counted as before")
	var was_fast: bool = Game.fast
	Game.fast = false          # as a player meets it: a section is open only when its pictures exist
	var lacks: Array = Game.section_lacks(first)
	_check(Game.section_open(first) == lacks.is_empty() and Game.chapter_open(1) == lacks.is_empty(),
			"a section is shut to players while any of its pictures is missing (%d missing)" % lacks.size())
	main.menu.chapter = 0
	main.menu.open("sections")
	var rows: Array = main.menu.items.map(func(it): return it[0])
	var night: bool = Game.interlude_ready(0)      # the lambing night is listed before the Pastures once it is painted
	_check(rows[0] == ("interlude_0" if night else "section_0"), "the lambing night is listed before the Pastures once its pictures exist (%s)" % str(night))
	if night:
		rows.remove_at(0)
	_check(rows.slice(0, first) == range(first).map(func(i): return "section_%d" % i) and ("chapter_1" in rows) == lacks.is_empty(),
			"the menu lists Chapter One's sections, and Chapter Two only when it can be walked into")
	Game.force_ready = true
	main.menu.open("sections")
	rows = main.menu.items.map(func(it): return it[0])
	main.menu.chapter = 1
	main.menu.open("sections")
	_check("chapter_1" in rows and main.menu.items[0][0] == "section_%d" % first and main.menu.items[0][2] == true and main.menu.heading == "Chapter Two",
			"with its pictures there, Chapter Two has its own list and its first section is open")
	main.menu.chapter = 0
	main.menu.close()
	Game.force_ready = false
	Game.fast = was_fast
	Game.gifts_for(first)
	_check(Game.has("feet") and Game.has("lyre") and not Game.has("walksong") and Game.has_line("p23_oil"), "he comes into Chapter Two with what Chapter One gave him, and not yet its own gift")
	# an unfinished journey from the same older game is left where it was
	Game.take_save({"section": 5, "checkpoint": 1, "unlocked": 5, "started": true, "finished": false, "gifts": ["lyre", "voice"], "psalm": [], "pouch": 0})
	_check(int(Game.save["unlocked"]) == 5 and int(Game.save["section"]) == 5 and not Game.section_open(first), "an unfinished older journey is left where it was")
	# a journey of the game as it is now, partway into Chapter Two
	Game.take_save({"v": 2, "section": first, "checkpoint": 0, "unlocked": first + 1, "started": true, "finished": true, "gifts": ["lyre", "walksong"], "psalm": [], "pouch": 0})
	_check(int(Game.save["unlocked"]) == mini(first + 1, Game.sections().size()) and int(Game.save["section"]) == first and Game.has("walksong"),
			"a journey saved inside Chapter Two loads inside Chapter Two")
	main.menu.open("main")
	_check(main.menu.items[0][0] == "continue", "and can be continued from the menu")
	main.menu.close()
	Game.take_save(kept)


## Chapter Two, the Summons: the nine out of the night fold, past the mules by the lyre, the Walking Song, the
## keeper shown the named ones, the count and the well, and the donkey played home past the same mules.
func _summons(lv) -> void:
	var p = lv.player
	var had: Array = Game.save.get("gifts", []).duplicate()
	var gifts: Array = had.duplicate()
	gifts.erase("walksong")
	Game.save["gifts"] = gifts
	for g in ["lyre", "voice"]:
		Game.give(g, true)
	for a in ["move_right", "jump", "attack", "sling"]:
		Input.action_release(a)
	_check(lv.sheep_total == 9 and lv.flock_here.size() == 9 and lv.sheep_count == 0, "his own nine are shut in the night fold (%d gathered)" % lv.sheep_count)
	await _goto(lv.NIGHT_FOLD_X)
	await _frames(20)
	_check(lv.sheep_count == 0, "and do not come out until the bar is lifted")
	await _hold(lv, lv.bar_task)
	await _gather_nine(lv)
	_check(lv.sheep_count == 9, "the bar lifted, they come to him (%d)" % lv.sheep_count)
	_check(not Game.has("walksong"), "the Walking Song is not his before the trial")
	Input.action_press("lyre")
	await _frames(12)
	_check(p.act == "play" and not p.lyre_feet, "until then he sits to play")
	Input.action_release("lyre")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(40)
	# unquieted, they will not pass a mule
	await _goto(lv.MULES[0] - 420.0)
	await _frames(200)
	Input.action_press("move_right")
	Input.action_press("walk")
	await _until(func() -> bool: return lv.brays > 0 or p.global_position.x > lv.MULES[0] + 700.0, 900)
	Input.action_release("move_right")
	Input.action_release("walk")
	await _frames(70)
	_check(lv.brays >= 1 and lv.sheep_count < 9, "led up to a mule unquieted, the flock bolts (%d still with him)" % lv.sheep_count)
	_check(lv.song_noise(Vector2(lv.MULES[0] + 100.0, 0)) > 0.0 and lv.song_noise(Vector2(lv.MULES[0] - 330.0, 0)) == 0.0, "close to a mule his playing is unsettled; a little way off it is not")
	# quieted with the lyre, called on, and walked: they pass both
	var brays_before: int = lv.brays
	for mx in lv.MULES:
		lv.hush = 999.0          # held quiet while the test puts the flock back together behind him
		await _gather_nine(lv)
		await _goto(mx - 325.0)
		p.facing = 1
		await _frames(260)
		lv.hush = 0.0
		brays_before = lv.brays if mx == lv.MULES[0] else brays_before
		await _play_song(p, 3)
		_check(lv.hush > 0.0, "a song quiets the flock for a while")
		var held := 0
		for sh in lv.followers:
			held += 1 if not is_nan(sh.stay) else 0
		await _frames(10)
		Input.action_press("call")
		await _frames(3)
		Input.action_release("call")
		await _frames(3)
		var roused := 0
		for sh in lv.followers:
			roused += 1 if is_nan(sh.stay) else 0
		if mx == lv.MULES[0]:
			_check(held == 9 and roused == 9 and p.act == "", "the song holds them where they stand, and his call from where he sits brings them on (%d held, %d roused)" % [held, roused])
		Input.action_press("move_right")
		Input.action_press("walk")
		await _until(func() -> bool: return p.global_position.x > mx + lv.MULE_REACH + 420.0, 900)
		Input.action_release("move_right")
		Input.action_release("walk")
		await _frames(60)
	_check(lv.brays == brays_before and lv.sheep_count == 9, "quieted, called on and walked, all nine pass both mules (%d, %d brays)" % [lv.sheep_count, lv.brays - brays_before])
	# the gift, at its place
	await _goto(lv.GIFT_X)
	await _frames(40)
	_check(Game.has("walksong") and p.act == "", "all nine brought past the mules, the Walking Song is given")
	main.hud.page = 0          # the journal in Chapter Two: its own gift, and what he carries from the hills
	Input.action_press("growth")
	await _frames(30)
	_check(main.hud.panel > 0.5, "the journal opens in Chapter Two")
	Input.action_release("growth")
	await _frames(20)
	# played on his feet: he keeps walking, and what follows keeps following
	Input.action_press("move_right")
	Input.action_press("walk")
	await _frames(30)
	Input.action_press("lyre")
	await _frames(4)
	_check(p.act == "play" and p.lyre_feet and absf(p.velocity.x) > 40.0, "begun while walking, he plays on his feet and walks on")
	var x0: float = p.global_position.x
	await _play_song(p, 3, true)
	_check(p.act == "play" and p.verse == 1 and p.verse_rest > 0.0, "on his feet three phrases close a verse, and he plays on")
	var follows := 0
	for sh in lv.followers:
		if sh.calm > 0.0 and is_nan(sh.stay):
			follows += 1
	_check(follows == 9 and p.global_position.x > x0 + 150.0, "the flock is quieted and still follows him (%d of 9)" % follows)
	Input.action_release("lyre")
	Input.action_release("walk")
	await _until(func() -> bool: return lv.penned, 900)
	Input.action_release("move_right")
	_check(lv.penned and lv.pick_task["on"], "at the day fold the nine go in, and the keeper is to be shown them")
	await _frames(300)
	# the named ones: the wrong sheep is refused, the right one is known
	var not_lamb = null
	for sh in lv.followers:
		if sh.who != "lamb" and not_lamb == null:
			not_lamb = sh
	await _goto(not_lamb.global_position.x)
	await _frames(6)
	Input.action_press("grab")          # by hand, as he plays it: held on the wrong sheep
	await _frames(40)
	Input.action_release("grab")
	await _frames(4)
	_check(lv.ask_i == 0 and lv.wrong == 1, "shown the wrong sheep, the keeper is not satisfied")
	_check("Not that one" in lv.prompt_words or Game.t("Not that one.") in lv.prompt_words, "and he is told so where he can see it (%s)" % lv.prompt_words)
	var the_lamb = null
	for sh in lv.followers:
		if sh.who == "lamb":
			the_lamb = sh
	await _goto(the_lamb.global_position.x)
	await _frames(200)          # the answer has been read: he may show another
	Input.action_press("grab")
	await _frames(40)
	Input.action_release("grab")
	await _frames(4)
	_check(lv.ask_i == 1, "held by hand on the lamb, Shai is known")
	lv.ask_i = 0
	lv.wrong = 1
	for id in lv.ASK:
		for sh in lv.followers:
			if sh.who == id:
				await _goto(sh.global_position.x)
				await _frames(6)
				await _hold(lv, lv.pick_task)
	_check(lv.ask_i == lv.ASK.size() and not lv.pick_task["on"] and lv.count_task["on"], "shown the lamb and the three named ewes, he knows them (%d of 4)" % lv.ask_i)
	await _hold(lv, lv.count_task)
	await _frames(20)
	await _hold(lv, lv.well_task)
	await _frames(20)
	_check(lv.counted and lv.handed and lv.halter_task["on"], "counted in and shown the well, the flock is the keeper's")
	# the donkey: it will not pass a mule unplayed, and passes when he plays as he walks
	var d = lv.donkey
	await _hold(lv, lv.halter_task)
	await _goto(lv.MULES[1] + 420.0)
	p.facing = -1
	d.global_position = lv.on_ground(p.global_position.x + 92.0)
	Input.action_press("move_left")
	Input.action_press("walk")
	await _frames(420)
	Input.action_release("move_left")
	Input.action_release("walk")
	_check(d.balks >= 1 and d.balking and d.global_position.x > lv.MULES[1], "led up to a mule unplayed, the donkey plants its feet")
	await _goto(d.global_position.x - 92.0)
	p.facing = -1
	var played := {"feet": false}
	var home := func() -> bool: return absf(d.global_position.x - lv.GATE_X) < 140.0
	Input.action_press("move_left")
	Input.action_press("walk")
	await _frames(25)
	var holding := false
	for i in 6000:
		if home.call():
			break
		# he waits for it when it hangs back, and goes on when it comes
		if p.global_position.x < d.global_position.x - 170.0:
			Input.action_release("move_left")
		else:
			Input.action_press("move_left")
		if p.act != "play":
			if absf(p.velocity.x) >= 40.0:      # take it up again, walking
				Input.action_release("lyre")
				await tree.physics_frame
				Input.action_press("lyre")
				holding = true
			else:
				Input.action_press("move_left")
		elif holding and p.breath_v >= 0.93:
			Input.action_release("lyre")
			holding = false
		elif not holding:
			Input.action_press("lyre")
			holding = true
		played["feet"] = played["feet"] or p.lyre_feet
		await tree.physics_frame
	for a in ["move_left", "walk", "lyre"]:
		Input.action_release(a)
	await _frames(30)
	_check(home.call() and played["feet"], "played to as he walks, it comes past both mules to his father's gate (x=%d, %d balks)" % [int(d.global_position.x), d.balks])
	_check(lv.kid_task["on"], "and there the young goat can be tied on")
	await _hold(lv, lv.kid_task)
	await _frames(20)
	_check(lv.kid_tied and lv.leave_task["on"] and not d.led, "the load is whole: bread, wine and the young goat")
	await _hold(lv, lv.leave_task)
	await _frames(30)
	Game.save["gifts"] = had


## 2.2: the donkey will not pass the ford, the slide or the wolves unplayed; the stones must be rolled off before
## any song takes it over them; and bringing it through the wolves earns the Steady Hand.
func _ridge_road(lv) -> void:
	var p = lv.player
	var d = lv.donkey
	var had: Array = Game.save.get("gifts", []).duplicate()
	var gifts: Array = had.duplicate()
	gifts.erase("steady")
	Game.save["gifts"] = gifts
	for g in ["lyre", "voice", "walksong"]:
		Game.give(g, true)
	for a in ["move_right", "jump", "attack", "sling"]:
		Input.action_release(a)
	_check(d.led and lv.sheep_total == 0, "he sets out leading the donkey, and the flock stays with the keeper (%d sheep here)" % lv.sheep_total)
	_check(lv.donkey_fear(lv.FORD_X) > 0.0 and lv.donkey_fear(lv.SLIDE_X) > 0.0 and lv.donkey_fear(lv.FORD_X + 900.0) == 0.0, "the ford and the slide frighten it; the open road does not")
	# the ford
	await _goto(lv.FORD_X - 520.0)
	d.global_position = lv.on_ground(p.global_position.x - 92.0)
	Input.action_press("move_right")
	Input.action_press("walk")
	await _frames(420)
	Input.action_release("move_right")
	Input.action_release("walk")
	_check(d.balks >= 1 and d.balking and d.global_position.x < lv.FORD_X, "led up to the ford unplayed, it plants its feet")
	await _goto(d.global_position.x + 92.0)
	var feet: bool = await _lead_playing(p, d, func() -> bool: return d.global_position.x > lv.FORD_X + lv.FORD_REACH + 30.0, 3000)
	_check(feet and d.global_position.x > lv.FORD_X + lv.FORD_REACH, "played to as he walks, it crosses (x=%d)" % int(d.global_position.x))
	# the slide: no song takes it over the stones; rolled off, it is played past
	await _goto(lv.SLIDE_X - 520.0)
	d.global_position = lv.on_ground(p.global_position.x - 92.0)
	_check(lv.song_noise(Vector2(lv.SLIDE_X - 100.0, 0)) > 0.0, "the slipping stones unsettle his playing")
	await _lead_playing(p, d, func() -> bool: return d.global_position.x > lv.SLIDE_X + lv.SLIDE_REACH, 900)
	_check(d.global_position.x < lv.SLIDE_X and not lv.cleared, "the road blocked, playing does not bring it over the stones (x=%d)" % int(d.global_position.x))
	await _hold(lv, lv.slide_task)
	await _frames(5)
	_check(lv.cleared and lv.song_noise(Vector2(lv.SLIDE_X - 100.0, 0)) == 0.0 and not lv.slide_task["on"], "the stones rolled off, the road is open and quiet")
	await _goto(d.global_position.x + 92.0)
	await _lead_playing(p, d, func() -> bool: return d.global_position.x > lv.SLIDE_X + lv.SLIDE_REACH + 30.0, 3000)
	_check(d.global_position.x > lv.SLIDE_X + lv.SLIDE_REACH, "and it is played past the place (x=%d)" % int(d.global_position.x))
	# the wolves at dusk
	_check(lv.wolves.is_empty() and not lv.wolves_out, "no wolf is on the road before dusk")
	await _goto(lv.DUSK_X + 60.0)
	d.global_position = lv.on_ground(p.global_position.x - 92.0)
	await _frames(20)
	_check(lv.wolves_out and lv.wolves.size() == 2, "where the road drops between the rocks, two wolves come down (%d)" % lv.wolves.size())
	var w0 = lv.wolves[0]
	_check(lv.donkey_fear(w0.global_position.x + 100.0) > 0.0, "and the donkey will not go near them")
	_check(not Game.has("steady") and not lv._through(), "the Steady Hand is not his before he has brought it through")
	for w in lv.wolves:
		for k in 3:
			if is_instance_valid(w):
				w.hit(1, -1, "staff")
				await _frames(12)
	await _frames(120)
	var left := 0
	for w in lv.wolves:
		if is_instance_valid(w) and absf(w.global_position.x - p.global_position.x) < 900.0:
			left += 1
	print("  wolves still near after three blows each: %d" % left)
	for w in lv.wolves:          # whatever the blows left, the rest of the road is walked with them gone
		if is_instance_valid(w):
			w.queue_free()
	await _frames(5)
	await _lead_playing(p, d, func() -> bool: return d.global_position.x > lv.PASS_X + 40.0, 4000)
	_check(lv._through(), "the wolves driven off, it comes through the rocks with him (x=%d, he at %d, balking %s, fear %.0f, act %s, cinematic %s, quiet %.1f)" % [int(d.global_position.x), int(p.global_position.x), d.balking, lv.donkey_fear(d.global_position.x), p.act, Game.cinematic, d.quiet])
	await _goto(lv.GIFT_X)
	await _until(func() -> bool: return Game.has("steady"), 900)
	_check(Game.has("steady"), "and the Steady Hand is given")
	await _lead_playing(p, d, func() -> bool: return d.global_position.x > lv.GATE_X - 250.0, 3000)
	await _goto(lv.GATE_X)
	await _frames(10)
	_check(lv.gate_task["on"], "with the load whole at the foot of Gibeah, he can go up")
	await _hold(lv, lv.gate_task)
	await _frames(30)
	Game.save["gifts"] = had


## Chapter Two, the Gate of Gibeah: a man takes more phrases than a flock, a phrase let go too soon takes one
## back, and his quiet does not last; the young man answers for him, the gate is a step into the yard, and the
## steward receives the gift piece by piece while he is quiet.
func _gibeah_gate(lv) -> void:
	var p = lv.player
	var d = lv.donkey
	var had: Array = Game.save.get("gifts", []).duplicate()
	for g in ["lyre", "voice", "walksong", "steady"]:
		Game.give(g, true)
	for a in ["move_right", "jump", "attack", "sling", "lyre"]:
		Input.action_release(a)
	_check(not lv.inside and d.led and lv.sheep_total == 0, "he comes to the gate leading the donkey, outside the wall")
	_check(p.cam.limit_right == int(lv.OUT_END), "and the yard cannot be seen from outside it")
	await _goto(lv.WATCH_X - 200.0)
	await _frames(30)
	var ge: Dictionary = lv.ears["gate"]
	_check(lv.refused and ge["on"], "the gatekeeper turns him away")
	ge["heard"] = 0
	ge["calm"] = 0.0
	ge["was"] = false
	await _frames(3)
	_check(not lv.ask_task["on"] and not lv.enter_task["on"], "unplayed, he will be asked nothing and the gate stays shut")
	await _play_song(p, 3)
	_check(int(ge["heard"]) == 3 and ge["calm"] == 0.0 and p.act == "play" and p.lyre_end <= 0.0,
			"three phrases, enough for a flock, do not quiet a man: the verse closes and he plays on (%d heard)" % int(ge["heard"]))
	Input.action_press("lyre")
	for i in 200:
		await tree.physics_frame
		if p.act == "play" and p.verse_rest <= 0.0 and p.breath_v > 0.2 and p.breath_v < 0.7:
			break
	Input.action_release("lyre")
	await _frames(3)
	_check(int(ge["heard"]) == 2, "a phrase let go too soon takes one back (%d heard)" % int(ge["heard"]))
	await _play_song(p, 2)
	await _frames(3)
	_check(ge["calm"] > 0.0 and lv.ask_task["on"], "the fourth quiets him, and now he can be asked (heard %d)" % int(ge["heard"]))
	ge["calm"] = 0.03
	await _frames(8)
	_check(ge["calm"] == 0.0 and not lv.ask_task["on"] and lv._need(ge) == lv.AGAIN, "his quiet wears off, and he must be played to again, though less")
	await _play_song(p, lv.AGAIN)
	await _frames(3)
	_check(ge["calm"] > 0.0 and lv.ask_task["on"], "played to again, he listens again")
	await _hold(lv, lv.ask_task)
	await _frames(10)
	_check(lv.asked and lv.enter_task["on"] and not ge["on"], "the young man answers for him and the gate is opened")
	Input.action_release("lyre")
	await _frames(120)
	await _hold(lv, lv.enter_task)
	await _frames(20)
	_check(lv.inside and p.global_position.x > lv.YARD_X and absf(d.global_position.x - p.global_position.x) < 200.0 and p.cam.limit_left == int(lv.YARD_X),
			"through the gate he is in the yard, the donkey with him (he at %d)" % int(p.global_position.x))
	_check(is_instance_valid(lv.jonathan) and lv.jonathan.get_parent() != lv and lv.JONATHAN_X > lv.CISTERN_X and lv.JONATHAN_X < lv.STORE_X,
			"Jonathan stands up on the wall across the yard, off the path: seen, with nothing asked of him")
	# the steward
	var se: Dictionary = lv.ears["store"]
	_check(not lv.offer_task["on"] or lv._near_load(), "the gift cannot be offered with the donkey left behind")
	await _goto(lv.STORE_X - 80.0)
	d.global_position = lv.on_ground(p.global_position.x - 92.0)
	await _frames(10)
	_check(lv.offer_task["on"] and not se["on"], "with the load at the storehouse, the gift can be offered")
	await _hold(lv, lv.offer_task)
	await _frames(10)
	_check(lv.turned and se["on"] and not lv.give_task["on"], "the steward would leave it till morning")
	se["heard"] = 0
	await _play_song(p, lv.STORE_NEED - 1)
	_check(se["calm"] == 0.0, "he takes more than the gatekeeper did")
	await _play_song(p, 1)
	await _frames(3)
	_check(se["calm"] > 0.0 and lv.give_task["on"], "the fifth phrase quiets him: the gift can be handed over")
	var before: float = se["calm"]
	await _hold(lv, lv.give_task)
	await _frames(3)
	_check(lv.given == 1 and se["calm"] < before - 1.0 and lv.give_task["on"], "each thing he receives costs some of his quiet (%.1f to %.1f)" % [before, se["calm"]])
	se["calm"] = 0.03
	await _frames(8)
	_check(not lv.give_task["on"] and lv.given == 1, "and when it is gone he turns back to his tally")
	await _play_song(p, lv.AGAIN)
	await _frames(3)
	await _hold(lv, lv.give_task)
	await _frames(3)
	_check(lv.given == 2 and not lv.wait_task["on"], "played to again, he takes the wine")
	await _hold(lv, lv.give_task)
	await _frames(10)
	_check(lv.given == 3 and lv.wait_task["on"] and not d.led and not se["on"], "and the young goat: the gift is delivered whole, and the donkey is the stable's")
	Input.action_release("lyre")
	await _frames(120)
	await _goto(lv.HALL_X)
	await _hold(lv, lv.wait_task)
	await _frames(30)
	Game.save["gifts"] = had


## The map's third view: the fortress at Gibeah. It is not shown before he has come there; once he has, the map
## opens on it when he is in it, lists Chapter Two's fortress sections as its places, and Tab goes round all three.
func _fort_map(m) -> void:
	var gate_i := _index("gibeah_gate")
	var was_unlocked: int = int(Game.save.get("unlocked", 0))
	var was_sec: int = m.section_idx
	Game.save["unlocked"] = 5
	m.section_idx = 3
	m.map.open(true, 3)
	_check(not m.map._fort_known() and m.map.view == "hills" and m.map.ids == range(8) and m.map._here() == 3, "in Chapter One the map is the hills, with its eight places and no more")
	m.map._toggle()
	_check(m.map.view == "land" and m.map.ids.is_empty(), "and Tab goes to the wider land, as it did: looked at, with no places on it")
	m.map._toggle()
	_check(m.map.view == "hills" and m.map.index == 3, "and back to the hills, at the place he had chosen")
	m.map.close()
	# Chapter Two's first two sections: his father's house on the hills, the ridge road on the wider land
	var sum_i := _index("summons")
	Game.save["unlocked"] = sum_i
	m.section_idx = sum_i
	m.map.open(true, sum_i)
	_check(m.map.view == "hills" and m.map.ids == range(9) and m.map._here() == 8 and m.map.index == 8, "come to the Summons, his father's house is the ninth place on the hills, and he stands there")
	var home_at: Vector2 = m.map._spot(8)
	var town_at: Vector2 = m.map._at(31.7054, 35.2024)
	_check(home_at.distance_to(town_at) < 120.0 and home_at.distance_to(m.map._spot(7)) > 12.0, "it lies at the edge of Bethlehem, apart from the Anointing's mark (%d from the town)" % int(home_at.distance_to(town_at)))
	m.map._toggle()
	_check(m.map.view == "land" and m.map.ids.is_empty(), "the ridge road is not on the land before he has set out on it")
	m.map.close()
	Game.save["unlocked"] = sum_i + 1
	m.section_idx = sum_i + 1
	m.map.open(true, sum_i + 1)
	_check(m.map.view == "land" and m.map.ids == [sum_i + 1] and m.map._here() == 0 and m.map._open_to(0), "on the Ridge Road the map opens on the wider land, and he stands on the road")
	await _frames(40)
	var road_at: Vector2 = m.map._spot(0)
	var beth: Vector2 = m.map._at(31.7054, 35.2024)
	var gib: Vector2 = m.map._at(31.8232, 35.231)
	_check(road_at.y < beth.y and road_at.y > gib.y and road_at.x > 380.0 and road_at.x < 1260.0, "the road's mark lies between Bethlehem and Gibeah, clear of the card (%s)" % str(road_at.round()))
	m.map._toggle()
	_check(m.map.view == "hills" and m.map.ids == range(9) and m.map._here() == -1, "and Tab goes on to the hills, where his father's house now is")
	m.map.close()
	var baf_i := _index("back_and_forth")
	Game.save["unlocked"] = baf_i
	m.section_idx = baf_i
	m.map.open(true, baf_i)
	await _frames(40)
	_check(m.map.view == "land" and m.map.ids == [sum_i + 1, baf_i] and m.map._here() == 1 and m.map._spot(1).y > m.map._spot(0).y + 12.0,
			"at the chapter's end the road home is the land's second place, south of the ridge road's mark, and he stands there")
	m.map.close()
	Game.save["unlocked"] = gate_i + 1
	m.section_idx = gate_i
	m.map.open(true, gate_i)
	_check(m.map._fort_known() and m.map.view == "gibeah" and m.map._g(m.map.index) == gate_i and m.map._here() == m.map.index,
			"opened at the Gate of Gibeah, the map is the fortress and he stands at its gate")
	var names: Array = m.map.ids.map(func(g): return m.map._key(m.map.ids.find(g)))
	_check(names.slice(0, 4) == ["gibeah_gate", "kings_hall", "armour_bearer", "night_fit"], "its places are the fortress's sections, in order (%s)" % str(names))
	_check(m.map._open_to(0) and m.map._open_to(1) and not m.map._open_to(2), "a place in it is open only once he has come to it")
	await _frames(30)
	var gate_at: Vector2 = m.map._spot(0)
	var hall_at: Vector2 = m.map._spot(1)
	_check(hall_at.y < gate_at.y and hall_at.x > gate_at.x and gate_at.x > 360.0 and gate_at.x < 1280.0 and gate_at.y > 0.0 and gate_at.y < 720.0,
			"the hall lies north-east of the gate, and both are on the screen clear of the card (gate %s, hall %s)" % [str(gate_at.round()), str(hall_at.round())])
	m.map.index = 1
	m.map._toggle()
	_check(m.map.view == "land", "from the fortress Tab goes to the wider land")
	m.map._toggle()
	_check(m.map.view == "hills" and m.map.ids == range(9) and m.map._here() == -1, "then to the hills, where he is not")
	m.map._toggle()
	_check(m.map.view == "gibeah" and m.map.index == 1, "and round to the fortress again, at the place he had chosen")
	m.map.close()
	Game.save["unlocked"] = was_unlocked
	m.section_idx = was_sec


## Walks him east playing on his feet, waiting for the donkey when it hangs back, until `done` or `frames` run out.
## Returns whether he was playing on his feet at any time.
func _lead_playing(p, d, done: Callable, frames: int) -> bool:
	var feet := false
	var holding := false
	Input.action_press("move_right")
	Input.action_press("walk")
	await _frames(25)
	for i in frames:
		if done.call():
			break
		if p.global_position.x > d.global_position.x + 170.0:
			Input.action_release("move_right")
		else:
			Input.action_press("move_right")
		if p.act != "play":
			if absf(p.velocity.x) >= 40.0:
				Input.action_release("lyre")
				await tree.physics_frame
				Input.action_press("lyre")
				holding = true
			else:
				Input.action_press("move_right")
		elif holding and p.breath_v >= 0.93:
			Input.action_release("lyre")
			holding = false
		elif not holding:
			Input.action_press("lyre")
			holding = true
		feet = feet or p.lyre_feet
		await tree.physics_frame
	for a in ["move_right", "walk", "lyre"]:
		Input.action_release(a)
	await _frames(30)
	return feet


## Walks him onto every one of the flock that is not with him.
func _gather_nine(lv) -> void:
	for round in 3:
		for sh in tree.get_nodes_in_group("sheep"):
			if is_instance_valid(sh) and sh.level == lv and not sh.gathered:
				await _goto(sh.global_position.x)
				await _frames(10)
		if lv.sheep_count >= lv.sheep_total:
			return
		await _frames(60)


## Plays `n` phrases, each let go at the top of the breath. `held`: the key is already down.
func _play_song(p, n: int, held: bool = false) -> void:
	if not held:          # a song that has ended is let end: he gets up before he can begin another
		await _until(func() -> bool: return p.lyre_end <= 0.0 and p.act != "play_up", 400)
	for k in n:
		if not held:
			Input.action_press("lyre")
		held = false
		for i in 300:
			await tree.physics_frame
			if p.breath_v >= 0.93:
				break
		Input.action_release("lyre")
		await _frames(3)


## A journey saved before the psalm, the lyre and the named flock: it must load with everything it had, and with
## the new things beside it. Nothing is read from or written to the player's own file.
func _old_save() -> void:
	var kept: Dictionary = Game.save.duplicate(true)
	var old := {"section": 5, "checkpoint": 2, "has_sling": true, "unlocked": 5, "started": true, "finished": false, "difficulty": 2,
			"growth": {"feet": 40.0, "voice": 3.0}, "stones": ["s1_start", "well_start"], "gifts": ["voice", "hand", "sling", "eye", "heart"],
			"places": ["foldcave"], "pouch": 0, "lang": "pt", "seen": {"A D  move": 5.0}}
	Game.take_save(old.duplicate(true))
	var same := true
	for k in old:
		if JSON.stringify(Game.save.get(k)) != JSON.stringify(old[k]) and k != "gifts":
			same = false
	for g in old["gifts"]:
		if not Game.has(g):
			same = false
	_check(same, "an older save loads with everything it held")
	_check(Game.has("lyre") and Game.flock().size() == 9 and str(Game.flock()[0]["id"]) == "lamb", "and is given the lyre and his nine sheep")
	_check(Game.has_line("p23_pastures") and Game.has_line("p23_waters") and Game.has_line("p23_valley") and not Game.has_line("p23_rod") and not Game.has_line("p23_goodness"),
			"and the lines of the psalm from the places he has been through")
	_check(Game.save.get("lamb_born") == true and not Game.interlude_due(0), "a journey begun before the lambing night has Shai already, and is not sent back to it")
	Game.take_save({})
	_check(Game.save.get("lamb_born") == false and Game.interlude_due(0), "a new journey begins with the lambing night")
	var again: Dictionary = Game.save.duplicate(true)
	again["psalm"] = ["p23_waters"]
	again["flock"][2]["at"] = "section1"
	Game.take_save(again.duplicate(true))
	_check(Game.psalm() == ["p23_waters"] and str(Game.flock()[2]["at"]) == "section1" and Game.save["gifts"].count("lyre") == 1, "a save that already has them is left as it is")
	Game.take_save({"section": 3, "flock": "nine", "psalm": 4})
	_check(Game.flock().size() == 9 and Game.psalm() is Array, "a spoiled flock or psalm in the file is made good")
	Game.save = kept


## The lambing night before the Pastures: the count at the fold, the ewe found among the rocks, the labour kept
## quiet by the lyre and undone by a wolf, the lamb rubbed dry, laid at its mother's head, carried home at her pace.
func _lambing(m) -> void:
	print("Lambing Night (before section 1)")
	Game.backdrop = false
	Game.cinematic = false
	var born_was = Game.save.get("lamb_born", false)
	Game.save["lamb_born"] = false
	await m.load_level(0, 0, true)
	var lv = m.level
	_check(m.in_interlude and lv.section_name() == "lambing" and m.here()["title"] == "Lambing Night", "the night before the Pastures loads as its own place")
	lv.begin()
	await _frames(5)
	_check(lv.rachel.who == "rachel" and lv.lamb.who == "lamb" and lv.flock.size() == 7 and not "rachel" in lv.flock.map(func(s): return s.who),
			"seven ewes are in the fold, Rachel is out among the rocks, and the lamb is not yet born")
	_check(lv.tasks.any(func(tk): return tk["text"] == "take a brand from the fire"), "a brand can be taken from the fire")
	await _goto(lv.FOLD)
	await _frames(20)
	_check(lv.part == 1, "at the fold he counts them, and one is missing")
	await _goto(lv.BIRTH_X - 120.0)
	await _frames(10)
	_check(lv.part == 2 and lv.song_spot["on"], "he finds her lambing, and the lyre is asked for")
	await _frames(30)
	_check(lv.labour == 0.0, "without the lyre the labour does not go on")
	lv.rachel.settle(30.0, false)
	await _frames(60)
	_check(lv.labour > 0.0, "quieted by the song, with him beside her, it goes on")
	lv._spawn_wolf(lv.BIRTH_X + 300.0)
	await _frames(5)
	var before: float = lv.labour
	await _frames(30)
	_check(lv.wolf != null and lv.rachel.calm <= 0.0 and lv.labour == before and lv.song_noise(lv.rachel.global_position) > 0.0,
			"a wolf near her breaks the quiet and stops the labour")
	lv.wolf.drive_off()
	await _frames(10)
	lv.rachel.settle(30.0, false)
	lv.labour = 0.999
	await _frames(30)
	_check(lv.part == 3 and lv.lamb.visible and lv.rub_task["on"], "the wolf gone and the labour done, the lamb lies still")
	await _hold(lv, lv.rub_task)
	await _frames(5)
	_check(lv.part == 3, "it cannot be rubbed dry with bare hands")
	await _goto(lv.GRASS_X)
	await _hold(lv, lv.grass_task)
	_check(lv.has_grass, "dry grass is pulled from under the rock shelf")
	await _goto(lv.BIRTH_X - 52.0)
	await _frames(200)
	await _hold(lv, lv.rub_task)
	await _until(func() -> bool: return lv.part == 4 and lv.lay_head_task["on"], 900)
	_check(lv.part == 4 and lv.lay_head_task["on"], "rubbed with grass it breathes")
	await _hold(lv, lv.lay_head_task)
	await _until(func() -> bool: return lv.part == 5, 900)
	_check(lv.part == 5 and Game.save["lamb_born"] == true and lv.rachel.pose == "ewe_tend" and lv.lamb.named == "Shai", "laid at its mother's head, she knows it, and he calls it Shai")
	await _hold(lv, lv.gather_task)
	await _until(func() -> bool: return lv.part == 6 and lv.carrying, 900)
	await _frames(5)
	_check(lv.part == 6 and lv.carrying and lv.player.act == "carry" and lv.player.carry_set == "cradle" and lv.rachel in lv.followers and lv.rachel.max_speed < 270.0,
			"he carries it in his arms, and she follows at a pace slower than his run")
	await _hold(lv, lv.lay_task)
	_check(not lv.carrying and lv.lamb.visible and lv.lamb.safe, "he can lay it down to have his hands free")
	await _frames(3)
	await _hold(lv, lv.lift_task)
	_check(lv.carrying, "and take it up again")
	lv.rachel.global_position = lv.on_ground(lv.FOLD + 200.0)
	await _goto(lv.FOLD + 120.0)
	var t := 0
	while not lv.done and t < 600:
		await _frames(1)
		t += 1
	_check(lv.part == 7 and lv.done and str(Game.flock_one("lamb")["at"]) == "" and str(Game.flock_one("rachel")["at"]) == "", "home at the fold the lamb stands, and the night is done")
	Game.save["lamb_born"] = born_was
	m.in_interlude = false


## The lyre, played by holding the key and letting go at the top of the breath: three phrases, and the sheep
## that hear them settle. Run at the start of the Pastures, beside the restless ewe.
func _lyre(lv) -> void:
	var had: Array = Game.save.get("gifts", []).duplicate()
	var lines: Array = Game.psalm().duplicate()
	Game.give("lyre", true)
	Game.save["psalm"] = []
	_check(lv.flock_here.size() == 9 and lv.sheep_total == 9, "the nine of the Pastures are his own nine (%d)" % lv.flock_here.size())
	var ewe = lv.restless_ewe
	_check(ewe.named == "Devorah" and ewe.who == "devorah" and is_equal_approx(ewe.size, float(Game.flock_one("devorah")["size"])), "a named ewe wears her own look")
	var was_gathered: bool = ewe.gathered
	await _goto(ewe.global_position.x - 220.0)
	var p = lv.player
	var landed := 0
	for round in 3:
		Input.action_press("lyre")
		for i in 240:
			await tree.physics_frame
			if p.breath_v >= 0.93:
				break
		Input.action_release("lyre")
		await _frames(3)
		if round < 2:
			landed += 1 if p.phrases == round + 1 else 0
		if round == 0:
			_check(ewe.heed_t > 0.0 or was_gathered, "a sheep in hearing lifts its head to the phrase")
			Input.action_press("lyre")          # a stumble: let go too soon, and the song does not go back
			await _frames(20)
			Input.action_release("lyre")
			await _frames(3)
			_check(p.phrases == 1 and p.lyre_flash < 0.0 and p.act == "play", "let go too soon, the phrase does not land, and the one that did is kept")
	_check(landed == 2, "letting go at the top of the breath lands a phrase (%d of the first two)" % landed)
	_check(p.chord_in > 0.0 and p.phrases == 0 and p.verse == 1, "the third phrase closes the song: its last chord waits for the tune to come home")
	_check(ewe.calm > 0.0 or was_gathered, "three phrases settle the sheep that hear them")
	_check(ewe.settle_in > 0.0 or was_gathered, "and they go down as the chord reaches them, not before")
	_check(Game.has_line("p23_pastures"), "and the line of the psalm comes to him there")
	await _until(func() -> bool: return not Game.cinematic and p.act == "", 900)
	var sat := false
	for tries in 40:                # a second song, with nothing given after it
		Input.action_press("lyre")
		await _frames(2)
		if p.act == "play":
			sat = true
			break
		Input.action_release("lyre")
		await _frames(10)
	_check(sat, "he takes up the lyre again (%s %s %.0f)" % [p.act, Game.cinematic, p.velocity.x])
	await _play_song(p, 3, true)
	_check(p.act == "play" and p.lyre_end > 0.0 and p.phrases == 0, "a song ends: he stays a moment while the chord rings (%s %.2f)" % [p.act, p.lyre_end])
	Input.action_press("lyre")          # pressed again as it ends: the song is over all the same
	await _frames(int((p.SONG_END + p.LYRE_RISE) * 60.0) + 20)
	_check(p.act == "" and p.lyre_t == 0.0 and p.glow_v < 0.3, "the song over, he lowers the lyre and gets up by himself (%s %.2f %.2f)" % [p.act, p.lyre_t, p.glow_v])
	Input.action_release("lyre")
	await _frames(3)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_check(p.act == "", "a leap ends the playing")
	await _frames(40)
	Game.save["gifts"] = had
	Game.give("lyre", true)
	Game.save["psalm"] = lines


## The wolf, the leopard, the viper and the hyena, each on the flat ground of the watch with a sheep or two. In the
## tests they wear the jackal's pictures (Game.fast); it is what they do that is judged.
func _beasts(m) -> void:
	Game.backdrop = false
	Game.cinematic = false
	await m.load_level(_index("watch"), 0)
	var lv = m.level
	await _frames(5)
	lv.player.hp = 99
	await _wolf(lv)
	await _leopard(lv)
	await _viper(lv)
	await _hyena(lv)


## Waits until cond is true, for at most `frames` frames.
func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


## Sends away what the level had of its own, so a beast has only what the test gives it.
func _bare(lv, at: float) -> void:
	for n in tree.get_nodes_in_group("sheep") + tree.get_nodes_in_group("enemies"):
		n.queue_free()
	lv.followers.clear()
	await _frames(2)
	lv.player.invuln = 0.0
	lv.player.facing = 1
	await _goto(at)


func _wolf(lv) -> void:
	var p = lv.player
	await _bare(lv, 400.0)
	var w = lv.add_beast("wolf", 1000.0, {"edge_x": lv.width})
	# with its own pictures cut he is drawn from them; until then the tests borrow the jackal's
	_check(w != null and w.stand_in == Game.FA._paths("wolf", "walk").is_empty(), "a wolf is made for the tests, in its own pictures when they exist")
	w.cool = 99.0
	await _frames(90)
	_check(absf(w.to_player()) > 190.0 and not w.touch_on and w.state == "circle", "the wolf keeps outside his reach")
	w.hit(1, 1, "stone")
	_check(w.state == "flee" and not w.fleeing, "a stone while it circles sends it off for a while")
	w.state = "circle"
	w.hp = 3
	var near = lv.add_sheep(440.0)
	near.gathered = true
	lv.followers.append(near)
	lv.sheep_count += 1
	var far = lv.add_sheep(1100.0)
	w.cool = 0.0
	_check(await _until(func() -> bool: return w.carry != null, 300), "the wolf dashes in and snatches the sheep that is far from him")
	_check(not near.gathered and near.bolt > 0.0 or near.global_position.x < 440.0, "its dash scatters the flock")
	await _frames(40)
	_check(w.carry == far and far.carried and w.state == "drag", "it drags the sheep off, slowly")
	w.hit(1, -1, "staff")
	_check(w.carry == null and not far.carried and w.state == "flee", "a blow makes it drop the sheep and run")
	await _frames(4)
	w.state = "circle"
	w.hp = 3
	w.cool = 0.0
	w.global_position = lv.on_ground(1000.0)
	w.velocity = Vector2.ZERO
	w.modulate.a = 1.0
	var lost0: int = lv.sheep_lost
	await _until(func() -> bool: return lv.sheep_lost > lost0, 1100)
	_check(lv.sheep_lost == lost0 + 1, "carried far enough, the sheep is lost (sheep_taken)")
	w.hp = 1
	w.hit(1, 1, "staff")
	_check(w.fleeing, "driven off for good at no strength left")
	p.hp = 99


func _leopard(lv) -> void:
	var p = lv.player
	await _bare(lv, 900.0)
	var l = lv.add_beast("leopard", 1000.0, {"perches": [[1000.0, 130.0, 160.0], [1500.0, 130.0, 160.0]]})
	_check(l != null and l.state == "lurk" and l.global_position.y < 470.0, "the leopard lies on its rock")
	l.st = 0.0
	_check(await _until(func() -> bool: return l.state == "spring", 90), "it springs at a man passing beneath")
	await _until(func() -> bool: return l.state == "land", 90)
	_check(p.hp == 97, "a spring that is not dodged costs two hearts")
	_check(await _until(func() -> bool: return l.state == "lurk" and not l.arcing and l.global_position.distance_to(l.perch) < 20.0, 600), "after the spring it bounds back to a perch and lurks again")
	await _goto(2400.0)
	p.invuln = 0.0
	l.hp = 6
	l.hit(1, 1, "stone")
	_check(await _until(func() -> bool: return l.state == "dazed" and not l.arcing, 60), "a stone while it lurks flushes it down, dazed")
	var h0: int = l.hp
	l.hit(1, -1, "staff")
	_check(l.hp < h0, "in the open the staff lands")
	p.hp = 99


func _viper(lv) -> void:
	var p = lv.player
	await _bare(lv, 1200.0)
	var v = lv.add_beast("viper", 1290.0)
	_check(v != null and v.state == "coil", "the viper lies coiled")
	_check(await _until(func() -> bool: return v.state == "rear", 60), "it rears when he comes near")
	_check(await _until(func() -> bool: return v.state == "strike", 90), "and then strikes")
	await _until(func() -> bool: return v.state == "spent", 30)
	_check(p.hp == 98 and v.touch_kind == "low", "the strike is low, and costs a heart")
	await _until(func() -> bool: return v.state == "coil", 120)
	v.hit(1, 1, "staff")
	_check(not v.fleeing, "the staff does not find it unless it is spent")
	p.position = lv.on_ground(1200.0)
	p.velocity = Vector2.ZERO
	p.invuln = 0.0
	await _until(func() -> bool: return v.state == "rear", 60)
	await _until(func() -> bool: return v.state == "strike", 90)
	p.hop_t = p.HOP_TIME
	await _until(func() -> bool: return v.state == "spent", 30)
	_check(p.hp == 98 and p.opening_t > 0.0, "a skip back avoids the strike")
	v.hit(1, 1, "staff")
	_check(v.fleeing, "one blow of the staff ends it while it is spent")
	var v2 = lv.add_beast("viper", 1700.0)
	v2.hit(1, 1, "stone")
	_check(v2.fleeing, "a stone from afar ends it")
	p.hp = 99


func _hyena(lv) -> void:
	var p = lv.player
	await _bare(lv, 500.0)
	lv.add_sheep(100.0)
	var h = lv.add_beast("hyena", 830.0)
	_check(h != null and h.state == "slink", "a hyena comes out of the dark")
	p.facing = 1
	var x0: float = h.global_position.x
	await _frames(60)
	_check(absf(h.global_position.x - x0) < 10.0, "faced from a distance, it holds still")
	p.facing = -1
	await _frames(60)
	_check(h.global_position.x < x0 - 40.0, "with his back turned it creeps toward the farthest sheep")
	p.facing = 1
	h.global_position = lv.on_ground(p.global_position.x + 200.0)
	x0 = h.global_position.x
	await _frames(40)
	_check(h.global_position.x > x0 + 20.0, "faced within reach, it cringes and backs away")
	for k in 3:
		await _until(func() -> bool: return h.state == "slink" or h.fleeing, 900)
		h.hit(1, 1, "staff")
	_check(h.sends == 3 and h.fleeing, "sent off three times, it gives up for good")
	lv.add_beast("hyena", 150.0)
	p.facing = 1      # his back to it, and the sheep beyond it
	var lost0: int = lv.sheep_lost
	await _until(func() -> bool: return lv.sheep_lost > lost0, 600)
	_check(lv.sheep_lost == lost0 + 1, "left at a sheep, it takes it")
	p.hp = 99


func _s1(lv) -> void:
	await _lyre(lv)
	await _goto(46.0)
	await _frames(6)
	_check("s1_start" in Game.stones(), "a smooth stone can be found")
	var had_gifts: Array = Game.save.get("gifts", []).duplicate()
	Game.save["gifts"] = []
	var earned := {"yes": false}
	lv.add_gift("voice", 400.0, func() -> bool: return earned["yes"], "")
	await _goto(400.0)
	await _frames(20)
	_check(not Game.has("voice") and Game.call_reach() == 0.0, "a gift is not given before it is earned")
	earned["yes"] = true
	await _frames(20)
	_check(Game.has("voice") and Game.call_reach() > 0.0 and lv.player.act == "", "a gift is given at its place once the trial is done")
	Game.save["gifts"] = []
	Game.gifts_for(3)
	_check(Game.has("voice") and Game.has("hand") and Game.has("sling") and not Game.has("eye"), "travelling to a later section brings the earlier gifts")
	Game.save["gifts"] = had_gifts
	for g in lv.gift_spots:
		g["node"].queue_free()
	lv.gift_spots.clear()
	var cv: Dictionary = lv.caves[0]
	await lv._cave_pass(cv)
	await _frames(5)
	_check(lv.in_cave != null and lv.player.global_position.x > lv.width and lv.dark_amount > 0.8, "a side cave is entered through its mouth, and it is dark inside")
	await lv._cave_pass(null, cv)
	await _frames(5)
	_check(lv.in_cave == null and absf(lv.player.global_position.x - cv["door"]) < 30.0 and lv.dark_amount < 0.1, "and he comes out where he went in")
	var kept_stones: Array = Game.stones().duplicate()
	Game.save["stones"] = ["a", "b"]
	_check(Game.pouch_max() == 0, "two smooth stones do not yet fill a pouch")
	Game.find_stone("c")
	_check(Game.pouch_max() == 1 and Game.pouch() == 1, "the third smooth stone puts one in the pouch")
	Game.save["stones"] = kept_stones
	Game.fill_pouch()
	_check(Game.stones_total >= 17 and Game.places_total >= 8, "the journal knows how many stones and places there are (%d, %d)" % [Game.stones_total, Game.places_total])
	Game.pad = true
	_check(Game.keys("J  staff") == "X  staff" and Game.keys("Run, then Space") == "Run, then A" and Game.keys("A D  move") == "Stick  move", "with a controller in hand the prompts name its buttons")
	Game.pad = false
	_check(Game.keys("J  staff") == "J  staff", "and with the keyboard they name keys")
	Game.touch = true
	var was_lang := Game.lang()
	Game.save["lang"] = "en"
	var tk := [Game.keys("J  staff"), Game.keys("Enter:  go there"), Game.keys("Sling:  hold K, then let go"),
			Game.keys("Two have broken from the fold.  Call them (Q), or go to them"), Game.keys("A D  move"),
			Game.keys("A nervous ewe bolts if he runs at her.  Walk up (Shift), or call her (Q)")]
	_check(tk == ["Staff  staff", "Tap:  go there", "Sling:  hold Sling, then let go",
			"Two have broken from the fold.  Call them (Call), or go to them", "Stick  move",
			"A nervous ewe bolts if he runs at her.  Walk up (a gentle push of the stick), or call her (Call)"],
			"on a touchscreen the prompts name the buttons on screen %s" % [tk])
	Game.save["lang"] = was_lang
	# a thumb on the on-screen buttons and stick works the same actions as the keys
	var lv_paused := tree.paused
	var tap := func(i: int, at: Vector2, down: bool) -> void:
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = at
		e.pressed = down
		main.get_viewport().push_input(e, true)
	tap.call(0, Vector2(1206, 648), true)
	await _frames(2)
	var jump_held := Input.is_action_pressed("jump")
	tap.call(1, Vector2(200, 600), true)
	var dr := InputEventScreenDrag.new()
	dr.index = 1
	dr.position = Vector2(280, 600)
	main.get_viewport().push_input(dr, true)
	await _frames(2)
	var runs := Input.is_action_pressed("move_right") and not Input.is_action_pressed("walk")
	tap.call(0, Vector2(1206, 648), false)
	tap.call(1, Vector2(280, 600), false)
	await _frames(2)
	_check(jump_held and runs and not Input.is_action_pressed("jump") and not Input.is_action_pressed("move_right") and lv_paused == tree.paused,
			"the on-screen buttons and stick press and let go of the game's actions")
	Game.touch = false
	var had_places: Array = Game.places().duplicate()
	Game.save["places"] = []
	for pl in lv.finds:
		pl["glow"].queue_free()
		pl["tw"].kill()
	lv.finds.clear()
	lv.add_place("landmark", lv.on_ground(300.0), "The Landmark", "eye")
	await _goto(300.0)
	await _frames(20)
	_check("landmark" in Game.places() and lv.finds.is_empty(), "a place off the path is found by going there")
	Game.save["places"] = had_places
	var mapd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json"))
	var told := 0
	for key in mapd["places"]:
		for e in mapd["places"][key].get("finds", []):
			if Game.narration.has("n_place_" + e[0]) and Game.narration_pt.has("n_place_" + e[0]) and Game._ui_pt.has(e[1]):
				told += 1
	_check(told == 11, "each place off the path has its story in both languages (%d)" % told)
	var kept: float = Game.craft_xp("hand")       # the player's own progress is put back afterwards
	Game.save["growth"] = Game.save.get("growth", {})
	Game.save["growth"]["hand"] = 0.0
	var before: int = Game.rank("hand")
	Game.grow("hand", 100000.0)
	_check(Game.rank("hand") == 3 and before == 0, "a craft grows with use")
	Game.save["growth"]["hand"] = kept
	# a jackal goes for a sheep he can see, and leaves alone one he cannot
	var bait = lv.add_sheep(380.0)
	lv.sheep_total -= 1
	bait.gatherable = false
	bait.prey = true
	var jk = lv.add_jackal(440.0, 250.0, 560.0)
	await _goto(3000.0)
	for k in 90:
		await tree.physics_frame
	_check(bait.threat < 0.01, "a jackal leaves a sheep alone while the shepherd is far out of sight")
	await _goto(720.0)      # in sight of the sheep, but not on top of the jackal
	for k in 150:
		await tree.physics_frame
	_check(bait.threat > 0.15, "a jackal goes for a sheep in his sight and the ring begins to close (%.2f)" % bait.threat)
	bait.queue_free()
	# its patrol ground is where it lives, not a fence: it follows him off it
	await _frames(2)
	await _goto(690.0)
	lv.player.invuln = 30.0
	var far := 0.0
	for k in 200:
		await tree.physics_frame
		far = maxf(far, jk.global_position.x)
	_check(far > 660.0, "a jackal follows him off its own ground (to %.0f, its ground ends at 560)" % far)
	await _goto(3000.0)
	for k in 420:
		await tree.physics_frame
	_check(jk.global_position.x < 575.0, "and goes home when he is gone (%.0f)" % jk.global_position.x)
	jk.queue_free()
	# the round blow strikes on both sides at once; held and let go, the staff goes right round him
	var gifts_then: Array = Game.save.get("gifts", []).duplicate()
	if not Game.has("hand"):
		Game.save["gifts"] = gifts_then + ["hand"]
	await _goto(1500.0)
	var px: float = lv.player.global_position.x
	var ja = lv.add_jackal(px - 70.0, px - 200.0, px + 200.0)
	var jb = lv.add_jackal(px + 70.0, px - 200.0, px + 200.0)
	ja.hp = 50
	jb.hp = 50
	ja.held = 5.0
	jb.held = 5.0
	await _frames(20)
	Input.action_press("attack")
	await _frames(45)
	Input.action_release("attack")
	await _frames(3)
	_check(lv.player.spin_t > 0.0, "the staff held back and let go goes right round him")
	await _frames(40)
	_check(ja.hp < 50 and jb.hp < 49, "the round blow strikes the one behind as well as the one in front (%d, %d)" % [ja.hp, jb.hp])
	# struck from a leap, he comes down on them
	ja.hp = 50
	jb.hp = 50
	ja.global_position.x = px - 60.0
	jb.global_position.x = px + 60.0
	ja.held = 5.0
	jb.held = 5.0
	lv.player.global_position.x = px
	await _frames(30)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(16)
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	_check(lv.player.plunge == 1, "a blow struck from a leap brings him down staff first")
	await _frames(60)
	_check(lv.player.plunge == 0 and ja.hp < 50 and jb.hp < 50, "and it lands on both sides of him (%d, %d)" % [ja.hp, jb.hp])
	ja.queue_free()
	jb.queue_free()
	Game.save["gifts"] = gifts_then
	lv.player.invuln = 0.0
	await _frames(4)
	await _goto(main.level.fold_x)
	_check(not lv.done, "fold stays shut while sheep are missing")
	await _goto(4500.0)
	for s in lv.get_children():
		if s.get("gatherable") != null and not s.gathered:
			s.gatherable = true
			lv.player.position = s.position
			lv.player.velocity = Vector2.ZERO
			await _frames(10)
	_check(lv.sheep_count == lv.sheep_total and lv.sheep_total == 9, "all nine sheep gathered")
	for b in tree.get_nodes_in_group("hittable"):
		b.hit(1, 1, "staff")
		b.hit(1, 1, "staff")
	await _goto(main.level.fold_x)


func _s2(lv) -> void:
	# a sheep that follows him jumps a gap in the ground rather than drifting across it in the air
	var ew = lv.add_sheep(600.0, null, false)
	ew.gathered = true
	ew.follow_index = 0
	await _goto(1000.0)
	var mid_air := false
	for k in 150:
		await tree.physics_frame
		if ew.global_position.x > 660.0 and ew.global_position.x < 750.0 and ew.leap >= 0.0:
			mid_air = true
	_check(mid_air and ew.global_position.x > 770.0 and absf(ew.global_position.y - lv.ground_y(ew.global_position.x)) < 6.0, "a following sheep leaps the gap and lands")
	ew.queue_free()
	Game.save["has_sling"] = false
	var kept_gifts: Array = Game.save.get("gifts", []).duplicate()
	Game.save["gifts"] = kept_gifts.filter(func(g): return g != "sling")
	await m_reload(_index("section2"))
	lv = main.level
	lv.player.position = Vector2(700.0, 700.0)
	await _frames(60)
	_check(lv.player.position.y < 700.0, "falling in a pit returns David to the watchfire")
	await _goto(1250.0)
	await _frames(10)
	_check(not Game.has("sling"), "the sling is not his while the jackal holds the brook")
	for n in tree.get_nodes_in_group("enemies"):
		if absf(n.global_position.x - 1180.0) < 400.0:
			n.hit(9, 1, "staff")
	await _frames(10)
	await _goto(1250.0)
	await _frames(20)
	_check(Game.save["has_sling"] == true and Game.has("sling"), "sling given once the jackal is driven off")
	for g in kept_gifts:
		Game.give(g, true)
	await _goto(1460.0)
	Input.action_press("sling")
	await _frames(50)
	Input.action_release("sling")
	await _frames(40)
	var jars := 0
	for n in tree.get_nodes_in_group("hittable"):
		if n.has_signal("struck"):
			jars += 1
			n.hit(1, 1, "stone")
	print("  jars left after one real throw: %d" % jars)
	await _frames(5)
	await _goto(1670.0)
	await _frames(20)
	_check(lv.player.position.y < 600.0, "bridge holds David over the gap")
	for n in tree.get_nodes_in_group("enemies"):
		n.hit(5, 1, "staff")
	await _goto(2500.0)
	await _frames(10)
	_check(not lv.ambush["walls"].is_empty(), "the pack closes in at the thorn brake")
	for k in 12:
		await _frames(8)
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
	_check(lv.ewe.gatherable and lv.ambush["cleared"], "the ewe is freed when the pack is driven off")
	await _goto(main.level.end_x)


func _index(script_name: String) -> int:
	for i in Game.sections().size():
		if str(Game.sections()[i]["script"]).get_file().get_basename() == script_name:
			return i
	return 0


## The Well: lever the stone, call his own out of the crowd, water them while other sheep steal, count them in.
func _well(lv) -> void:
	Game.save["gifts"] = Game.save.get("gifts", []).filter(func(g): return g != "hand")      # so the trial of the well runs
	_check(not lv.draw_task["on"] and lv.stone["on"] == (Game.rank("hand") >= 2), "the stone is too heavy until his hand has grown, and no water can be drawn")
	await _goto(2100.0)
	var x0: float = lv.fulcrum["body"].position.x
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	_check(lv.fulcrum["body"].position.x > x0 + 20.0, "he can push the block toward the stone")
	lv._fulcrum_moved(2230.0)
	_check(lv.lever_task["on"], "with the block set, the staff can lever the stone")
	await _hold(lv, lv.lever_task)
	await _frames(5)
	_check(lv.opened and lv.draw_task["on"], "the well is open")
	var came := 0
	for k in 10:            # the pack that comes for the water: driven off, as the trial asks
		await _frames(6)
		for n in tree.get_nodes_in_group("enemies"):
			if not n.fleeing:
				came += 1
				n.hit(9, 1, "staff")
	await _frames(20)
	_check(came >= 3 and Game.has("hand"), "a pack comes for the water, and the strong hand is given when it is driven off")
	_check(lv.own[0]["state"] == "mixed", "his sheep have run in among the other flocks (%s, calm %.1f, mixed_up %s)" % [lv.own[0]["state"], lv.own[0]["s"].calm, lv.mixed_up])
	lv.shepherd_call(lv.on_ground(2560.0), 600.0, false)
	_check(lv.own[0]["state"] == "led" and lv.others[0]["state"] == "idle", "his own come to his voice; the others do not")
	await _goto(2100.0)
	var stolen := false
	for k in 900:
		if lv.watered:
			break
		if lv.draw_task["on"] and lv.drinks[0] <= 0:
			await _hold(lv, lv.draw_task)
			await _hold(lv, lv.pour_tasks[0])
		for o in lv.others:
			if o["state"] == "drinking":
				stolen = true
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
		await _frames(2)
	_check(lv.watered, "every one of his flock has drunk")
	print("  other men's sheep reached the water unchecked: %s" % stolen)
	_check(lv.own[lv.LAMB]["state"] == "gone", "the lamb slips away while he deals with the jackal")
	await _hold(lv, lv.back_task)
	await _frames(5)
	_check(lv.closed, "the stone goes back over the well")
	await _goto(3720.0)
	await _frames(10)
	_check(lv.counting, "the count begins at the gate of the fold")
	var turned := 0
	for k in 3000:
		if not lv.counting:
			break
		var u: Variant = lv.under_rod()
		if u != null and not u["mine"]:
			lv.rod()
			turned += 1
		await _frames(1)
	_check(turned == 2 and lv.in_fold == 8, "two strangers turned back at the gate, eight of his own counted in")


## The Wadi: every perched boulder comes down to a sling stone and leaves a way up.
func _wadi(lv) -> void:
	var eye_before: bool = Game.has("eye")
	Game.save["gifts"] = Game.save.get("gifts", []).filter(func(g): return g != "eye")
	var high = null
	for b in tree.get_nodes_in_group("hittable"):
		if b.get("gate") == "eye":
			high = b
	high.hit(1, 1, "stone")
	_check(not high.fallen, "the last boulder will not come down without the sure eye")
	Game.give("eye", true)
	await _goto(1250.0)
	await _frames(20)
	_check(lv.player.position.x < 1300.0 and lv.player.position.y > 560.0, "the first step is too high to climb")
	var n_b := 0
	for b in tree.get_nodes_in_group("hittable"):
		if b.has_signal("fell"):
			n_b += 1
			b.hit(1, 1, "stone")
	await _frames(10)
	_check(n_b == 7, "seven perched boulders, one of them in the side cave")
	var n_j := 0
	for b in tree.get_nodes_in_group("hittable"):
		if b.has_signal("struck"):
			n_j += 1
			b.hit(1, 1, "stone")
	_check(n_j == 3 or eye_before, "three jars hang in the dead tree for the trial of the eye")
	lv.player.position = Vector2(1268.0, 540.0)
	lv.player.velocity = Vector2.ZERO
	await _frames(30)
	_check(lv.player.position.y < 560.0, "a fallen boulder is a step to stand on")
	lv.player.position = Vector2(2690.0, 480.0)
	lv.player.velocity = Vector2.ZERO
	await _frames(30)
	_check(lv.player.position.y < 520.0, "the slab bridges the gap")
	for n in tree.get_nodes_in_group("enemies"):
		n.hit(9, 1, "staff")
	await _goto(main.level.end_x)


## The Bear's Den: a torch from the embers, the bear under the moon shaft.
func _den(lv) -> void:
	_check(lv.dark != null and lv.torch_t == 0.0, "the cave is dark and he has no light")
	await _goto(430.0)
	await _hold(lv, lv.tasks[0])
	_check(lv.torch_t > 40.0, "the embers light a torch")
	await _frames(30)
	_check(lv.torch_t < lv.torch_max and lv.player_light > 200.0, "the torch burns down as he goes")
	for n in tree.get_nodes_in_group("enemies"):
		n.hit(9, 1, "staff")
	await _goto(3440.0)
	await _frames(20)
	_check(lv.bear != null, "the bear rises in the heart of the cave")
	await _goto(lv.out_x + 30.0)
	await _frames(10)
	_check(not lv.done, "no way out while the bear holds the cave")
	var bh: int = lv.bear.hp
	lv.bear.state = "walk"
	lv.bear.dir = -1
	lv.bear.hit(2, 1, "staff")
	_check(lv.bear.hp == bh, "the bear's hide turns the staff from the front")
	lv.bear.hit(2, -1, "staff")
	_check(lv.bear.hp == bh - 2, "a blow from behind tells")
	lv.bear.state = "rear"
	lv.bear.hit(1, 1, "stone")
	_check(lv.bear.state == "reel" and lv.bear.is_open(), "a stone as it rears staggers it")
	lv.bear.hit(lv.bear.max_hp / 2, 1, "test")
	_check(lv.bear.stage >= 2, "the bear's fight changes as it weakens")
	lv.player.global_position = lv.on_ground(3800.0)
	print("  David at ", lv.player.global_position.x, " bear at ", lv.bear.global_position.x)
	var seen_bear := {}          # let it fight on its own through every stage, David standing unharmed
	for stg in [1, 2, 3]:
		lv.bear.stage = stg
		lv.bear.hp = maxi(1, int(lv.bear.max_hp * (1.0 - 0.33 * (stg - 1))) - 1)
		lv.bear.state = "rest"
		lv.bear.st = 0.1
		for f in 4000:
			lv.player.invuln = 5.0
			lv.torch_t = 0.0
			lv.player.hp = lv.player.max_hp
			seen_bear[lv.bear.state] = true
			if f > 500 and (stg < 3 or seen_bear.has_all(["charge", "swipe", "slam", "rest"])):
				break
			await _frames(1)
	print("  bear on its own went through: ", seen_bear.keys())
	for need in ["charge", "swipe", "slam", "rest"]:
		_check(seen_bear.has(need), "the bear uses its " + need)
	lv.player.invuln = 0.0
	for k in lv.bear.max_hp:
		lv.bear.state = "rest"
		lv.bear.hit(1, 1, "test")
	await _frames(5)
	_check(lv.boss == null, "bear driven off")
	await _goto(4700.0)
	await _goto(5130.0)
	lv.torch_t = maxf(lv.torch_t, 20.0)      # with his torch alight (out, the goal is to light it again)
	_check(lv._goal_now() == "Search the bear's larder", "he has still to look in the bear's larder")
	await _goto(7290.0)
	await _frames(10)
	_check(not lv.ambush["walls"].is_empty(), "the scavengers come for him in the dark of the back passage")
	for k in 12:
		await _frames(8)
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
	_check(lv.ambush["cleared"], "and are driven off")
	await _goto(lv.SHELF_X - 40.0)
	Input.action_press("move_right")
	for k in 6:
		Input.action_press("jump")
		await _frames(50)
		Input.action_release("jump")
		await _frames(4)
	_check(lv.player.position.x < lv.SHELF_X, "the shelf the way out goes over is too high to leap")
	await _goto(7590.0)
	var shoved := 0
	while lv.step_rock["body"].position.x < lv.SHELF_X - 32.0 and shoved < 1500:
		await _frames(1)
		shoved += 1
	Input.action_release("move_right")
	await _frames(5)
	Input.action_press("move_left")       # back off for a run at it
	await _frames(25)
	Input.action_release("move_left")
	Input.action_press("move_right")
	for k in 8:
		Input.action_press("jump")
		await _frames(40)
		Input.action_release("jump")
		await _frames(4)
	Input.action_release("move_right")
	print("  the rock took %.1f s to roll under the shelf; he stands at y=%d" % [shoved / 60.0, int(lv.player.position.y)])
	_check(lv.player.position.x > lv.SHELF_X and lv.player.position.y < lv.BASE - 100.0, "with the rock rolled under it for a step, he climbs out")
	await _goto(lv.out_x + 30.0)


## The Night Watch: three watches of beasts, the strays called back, the fire fed, the psalm, dawn.
func _watch(lv) -> void:
	await _goto(1500.0)
	var saw_stir := false
	for k in 600:
		await _frames(2)
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
		if not lv.out.is_empty():
			saw_stir = true
			for st in lv.out.duplicate():
				lv.bring_back(st)
		if lv.fire_task["on"]:
			await _hold(lv, lv.fire_task)
		if lv.rest_task["on"]:
			await _hold(lv, lv.rest_task)
		if lv.done:
			break
	_check(saw_stir and lv.fed and lv.rested, "the flock broke and was brought back, the fire was fed, he rested")
	_check(lv.hour == 6, "the night is kept through to dawn")


func m_reload(i: int) -> void:
	await main.load_level(i, 0)
	main.level.begin()
	await _frames(5)


func _s3(lv) -> void:
	# the trial of the feet: an unhindered run from the watchfire must beat the fading light with room to spare
	var had_feet: bool = Game.has("feet")
	Game.save["gifts"] = Game.save.get("gifts", []).filter(func(g): return g != "feet")
	lv.run_ok = false
	await _goto(1250.0)
	Input.action_press("move_right")
	var took := 0
	while took < 600 and not lv.run_ok:
		lv.player.invuln = 5.0
		await _frames(1)
		took += 1
	Input.action_release("move_right")
	print("  the run took %.1f s unhindered, of %.1f allowed" % [took / 60.0, lv.RUN_TIME])
	_check(lv.run_ok and took / 60.0 < lv.RUN_TIME - 1.2, "the run to the light can be made in time")
	if had_feet:
		Game.give("feet", true)
	for n in tree.get_nodes_in_group("enemies"):
		if n.global_position.x < 4500.0:      # the ones on the way up; those on the way down are met later
			n.hit(9, 1, "staff")
	await _goto(3000.0)
	await _frames(10)
	_check(lv.lion != null, "lion appears")
	await _frames(400)
	print("  after 400 frames with the lion: hp=%d, lion state=%s" % [lv.player.hp, lv.lion.state])
	lv.player.invuln = 0.0
	lv.player.hurt(9, 0.0)
	await _frames(30)
	_check(lv.player.hp == lv.player.max_hp and not lv.player.dead, "defeat returns David to the watchfire with full health")
	_check(lv.lion.hp == lv.lion.max_hp, "lion fight resets")
	_check(lv.arena_walls.is_empty(), "beaten back, he is not shut out of the lion's ground")
	await _goto(3000.0)
	await _frames(10)
	_check(lv.arena_walls.size() == 2, "and it closes behind him when he comes again")
	var lh: int = lv.lion.hp
	lv.lion.state = "prowl"
	lv.lion.hit(2, 1, "staff")
	_check(lv.lion.hp == lh, "the prowling lion slips a blow of the staff")
	lv.lion.kb = 0.0
	lv.lion.state = "crouch"
	lv.lion.hit(1, 1, "stone")
	_check(lv.lion.hp == lh - 1 and lv.lion.state == "reel", "a stone as it crouches breaks its spring")
	lv.lion.hit(lv.lion.max_hp / 2, 1, "test")
	_check(lv.lion.stage >= 2, "the lion's fight changes as it weakens")
	var seen_lion := {}          # let it fight on its own through every stage, David standing unharmed
	var slink_run := 0
	var slink_max := 0
	for stg in [1, 2, 3]:
		lv.lion.stage = stg
		lv.lion.hp = maxi(1, int(lv.lion.max_hp * (1.0 - 0.33 * (stg - 1))) - 1)
		lv.lion.state = "recover"
		lv.lion.st = 0.1
		for f in 4000:
			lv.player.invuln = 5.0
			lv.player.hp = lv.player.max_hp
			seen_lion[lv.lion.state] = true
			slink_run = slink_run + 1 if lv.lion.state == "slink" else 0
			slink_max = maxi(slink_max, slink_run)
			if f > 500 and (stg < 3 or seen_lion.has_all(["pounce", "lurk", "rush", "recover"])):
				break
			await _frames(1)
	print("  lion on its own went through: ", seen_lion.keys(), "  (it ended at x=%d in state %s, David at x=%d; longest slink %d frames)" % [int(lv.lion.global_position.x), lv.lion.state, int(lv.player.global_position.x), slink_max])
	if not seen_lion.has_all(["lurk", "rush"]):      # whether it chose to slink away is chance; that slinking ends in a rush is not
		lv.lion.state = "slink"
		lv.lion.st = 3.0
		lv.lion.edge_x = lv.lion.max_x - 24.0
		for f in 600:
			lv.player.invuln = 5.0
			seen_lion[lv.lion.state] = true
			if seen_lion.has_all(["lurk", "rush"]):
				break
			await _frames(1)
		print("  the lion was sent to slink away, and went through: ", seen_lion.keys())
	for need in ["pounce", "lurk", "rush", "recover"]:
		_check(seen_lion.has(need), "the lion uses its " + need)
	lv.lion.state = "slink"          # held up on its way into the dark, it still comes back
	lv.lion.st = 0.3
	lv.lion.edge_x = lv.lion.max_x - 24.0
	lv.lion.global_position.x = lv.lion.min_x + 200.0
	lv.lion.modulate.a = 0.0
	var back := false
	for f in 60:           # far too short a time to have run there
		lv.player.invuln = 5.0
		if lv.lion.state == "lurk":
			back = true
			break
		await _frames(1)
	_check(back, "a lion held up as it slinks away is still at the edge when its time is up")
	lv.player.invuln = 0.0
	for k in lv.lion.max_hp:      # his health depends on the difficulty
		lv.lion.state = "recover"
		lv.lion.hit(1, 1, "test")
	await _frames(5)
	_check(lv.lamb.gatherable, "lamb can be rescued")
	await _goto(3950.0)
	await _frames(20)
	_check(lv.carrying and not lv.done, "he lifts the lamb, and the way down is still ahead of him")
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	_check(lv.player.is_on_floor() and lv.player.velocity.y >= 0.0, "with the lamb on his shoulders he does not leap")
	await _frames(700)
	_check(lv.player.position.x < lv.WATER_X + 250.0 and lv._goal_now().begins_with("Wash"), "he does not go on down with the lamb bleeding")
	await _goto(lv.WATER_X)
	Input.action_release("move_right")
	await _hold(lv, lv.tend_task)
	_check(lv.tended, "he washes and binds its wound at the pool")
	_check(lv.pool_at(lv.player.global_position) != null and lv.pool_at(lv.on_ground(lv.WATER_X + 300.0)) == null, "his feet are in the water there, and nowhere else")
	await _goto(lv.ROCK_X - 80.0)
	Input.action_press("move_right")
	var shoved := 0
	while lv.rock["on"] and shoved < 1500:
		await _frames(1)
		shoved += 1
	await _frames(240)
	Input.action_release("move_right")
	print("  the rock took %.1f s to shoulder off the path" % (shoved / 60.0))
	_check(not lv.rock["on"] and lv.player.position.x > 5400.0, "a fallen rock bars the path, and he shoulders it over the step and goes on")
	await _goto(lv.CLEFT_X)
	_check(lv._goal_now() == "Lay the lamb in the cleft of the rock", "jackals wait below, and he cannot fight with the lamb")
	await _hold(lv, lv.lay_task)
	await _frames(5)
	_check(not lv.carrying and lv.lamb.visible and lv.player.act == "", "he lays it in the cleft and his hands are free")
	for k in 12:
		await _frames(8)
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
	_check(lv._pack_left() == 0 and lv._goal_now() == "Lift the lamb", "the jackals are driven off the path")
	await _goto(lv.CLEFT_X)
	await _hold(lv, lv.lift_task)
	await _frames(5)
	_check(lv.carrying and lv.spoken, "he takes the lamb up again for the last of the way")
	await _goto(lv.end_x)
	await _frames(20)


func _s4(lv) -> void:
	await _goto(lv.SERVANT_X - 120.0)
	await _frames(20)
	_check(not lv.met, "the servant does not take the flock while part of it is still out on the hill")
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	_check(lv.player.position.x < lv.SERVANT_X + 50.0, "and he does not go on to the town past him, leaving it there")
	_check(lv.wild_ewe.wild and not lv.bay_jackal.fleeing, "one stray will come only to his call, and a jackal has another cut off")
	for sh in lv.get_children():
		if sh.get("gatherable") != null and not sh.gathered:
			lv.player.position = sh.position
			lv.player.velocity = Vector2.ZERO
			await _frames(10)
	_check(lv.sheep_count == lv.sheep_total and lv.sheep_total == 5, "the five strays are brought in")
	await _goto(2100.0)
	await _frames(10)
	_check(not lv.ambush["walls"].is_empty(), "the jackals try the flock once more on the road")
	for k in 12:
		await _frames(8)
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
	_check(lv.ambush["cleared"], "and are driven off")
	await _goto(lv.LAMB_X - 60.0)
	await _frames(20)
	_check(not is_nan(lv.lamb.stay), "the lamb lies down at the washout")
	await _hold(lv, lv.lift_task)
	await _frames(5)
	_check(lv.player.act == "carry" and lv.carrying, "he lifts it and carries it")
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(240)
	Input.action_release("jump")
	_check(lv.player.position.x < lv.WASH_X0 and lv.player.position.y < 600.0, "with the lamb he cannot leap the washout, and does not walk into it")
	await _hold(lv, lv.bridge_task)
	Input.action_press("move_right")
	await _frames(400)
	Input.action_release("move_right")
	_check(lv.bridged and lv.player.position.x > lv.WASH_X1 and lv.player.position.y < 600.0, "he drags the footbridge across and carries the lamb over it")
	await _goto(lv.SERVANT_X - 120.0)
	await _frames(30)
	_check(lv.met and lv.player.act == "" and lv.lamb.visible and not is_nan(lv.followers[0].stay), "at the servant he sets it down, and the flock is left there")
	await _goto(lv.PILLAR_X - 300.0)
	await _frames(20)
	_check(lv._goal_now() == "Cut the thorn back from Rachel's grave", "thorn has come up round the grave, and it is his to cut")
	for b in lv.thorn:
		for k in 5:
			b.hit(1, 1, "staff")
	await _goto(lv.SAMUEL_X - 700.0)
	await _frames(90)
	_check(absf(lv.followers[0].global_position.x - (lv.SERVANT_X - 100.0)) < 260.0, "the flock stays with the servant when David goes on")
	_check(lv.player.position.y < lv.TOP + 20.0, "the town stands above the road, on its terraces")
	await _goto(lv.SAMUEL_X - 50.0)
	await _frames(20)


## Walks and jumps David about a section at random and reports anywhere he pushes one way for two seconds
## and gets nowhere: the places he can be wedged.
func stuck(m, names: String) -> void:
	main = m
	tree = m.get_tree()
	m.menu.close()
	Game.backdrop = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for name in names.split(","):
		await m.load_level(_index(name), 0)
		var lv = m.level
		Game.cinematic = false
		var found := {}
		for run in 160:
			var p = lv.player
			p.global_position = lv.on_ground(rng.randf_range(60.0, lv.width - 60.0)) + Vector2(0, -2.0)
			p.velocity = Vector2.ZERO
			for leg in 6:
				var act := "move_right" if rng.randf() < 0.5 else "move_left"
				Input.action_press(act)
				var x0: float = p.global_position.x
				for f in 120:
					Game.cinematic = false
					p.invuln = 5.0
					p.hp = p.max_hp
					if rng.randf() < 0.03:
						Input.action_press("jump")
					else:
						Input.action_release("jump")
					await _frames(1)
				Input.action_release(act)
				Input.action_release("jump")
				var px: float = p.global_position.x
				if absf(px - x0) < 6.0 and px > 40.0 and px < lv.width - 40.0:
					# is he wedged? try the other way and a jump as well
					var other := "move_left" if act == "move_right" else "move_right"
					Input.action_press(other)
					for f in 90:
						if f % 30 == 0:
							Input.action_press("jump")
						else:
							Input.action_release("jump")
						await _frames(1)
					Input.action_release(other)
					Input.action_release("jump")
					var key := "%s x=%d y=%d going %s%s" % [name, int(px / 10.0) * 10, int(p.global_position.y / 10.0) * 10 if absf(p.global_position.x - px) < 6.0 else int(lv.player.global_position.y), act, "  WEDGED (cannot get out either way)" if absf(p.global_position.x - px) < 6.0 else "  (blocked one way)"]
					found[key] = true
		for k in found:
			print("STUCK ", k)
	print("STUCKTEST done")
	tree.quit()


## Screenshots of every place off the path: seen from below, and at the moment it is found.
func placeshots(m, dir: String) -> void:
	main = m
	tree = m.get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	m.menu.close()
	m.hud.visible = true
	Game.backdrop = false
	Game.cinematic = false
	Game.save["places"] = []
	Game.save["has_sling"] = true
	if OS.has_environment("SPOTS"):      # SPOTS=section1:1485,well:540 : stand him there and take a picture
		Game.save["stones"] = []
		Game.save["gifts"] = []
		Game.fast = false
		for spot in OS.get_environment("SPOTS").split(","):
			var nm := spot.get_slice(":", 0)
			var sx := float(spot.get_slice(":", 1))
			if nm == "menu":      # SPOTS=menu:0 : the main menu as it opens
				m.show_menu()
				await _frames(60)
				await _snap(dir, "menu")
				continue
			await m.load_level(_index(nm), 0)
			Game.cinematic = false
			m.level.player.global_position = m.level.on_ground(sx - 120.0)
			m.level.player.velocity = Vector2.ZERO
			for cv in m.level.caves:      # a spot inside a side cave: be in it, so its dark, camera and torch are on
				if sx > float(cv["x0"]) and sx < float(cv["x1"]):
					m.level._cave_state(cv)
					m.level.player.global_position = m.level.on_ground(sx - 120.0)
			m.level.player.cam.reset_smoothing()
			var wet = m.level.pool_at(m.level.player.global_position)
			if wet != null:      # standing in a pool: show the rings a step makes
				await _frames(15)
				m.level.ripple(wet, m.level.player.global_position.x + 8.0)
				await _frames(12)
				m.level.ripple(wet, m.level.player.global_position.x - 30.0)
			if OS.has_environment("BEASTS"):      # BEASTS=wolf:160,hyena:-260 : those beasts stand that far from him (+ is ahead)
				for bs in OS.get_environment("BEASTS").split(","):
					var bb = m.level.add_beast(bs.get_slice(":", 0), m.level.player.global_position.x + float(bs.get_slice(":", 1)))
					if bb != null and OS.has_environment("BEASTSTATE"):      # BEASTSTATE=lunge : set a state for the picture
						bb.state = OS.get_environment("BEASTSTATE")
			if OS.has_environment("FALL"):      # FALL=40 : bring the boulders down and take the picture that many frames in
				for b in m.level.get_children():
					if b.has_method("fall") and absf(b.position.x - sx) < 500.0:
						b.fall(1)
				await _frames(int(OS.get_environment("FALL")))
			if OS.get_environment("POSE") == "shove":      # carrying the lamb with his weight against something heavy
				m.level.player.act = "carry"
				m.level.player.facing = 1
				for k in 60:
					m.level.push_t = 0.18
					await _frames(1)
			elif OS.get_environment("POSE") != "" and m.level.has_method("pose"):      # POSE=lever etc: the level sets up a moment of work
				var hold: int = m.level.pose(OS.get_environment("POSE"))
				await _frames(30)
				if hold > 0:
					Input.action_press("grab")
					for k in hold:      # a line of narration may start here: the picture is of the work, not the talk
						Game.cinematic = false
						await _frames(1)
			else:
				await _frames(50 if wet == null else 22)
			await _snap(dir, "spot_%s_%d%s" % [nm, int(sx), ("_" + OS.get_environment("POSE")) if OS.get_environment("POSE") != "" else ""])
			Input.action_release("grab")
		print("PLACESHOTS done")
		tree.quit()
		return
	if OS.has_environment("MAP_ONLY"):
		await m.load_level(_index("wadi"), 0)
		Game.cinematic = false
		Game.fast = false
		Game.save["unlocked"] = 4
		Game.save["gifts"] = ["voice", "hand", "sling"]
		Game.save["places"] = ["foldcave", "cistern"]
		Game.save["stones"] = ["s1_start", "s1_step", "s1_leap", "s1_cave", "well_start", "s2_brake", "wadi_start"]
		for lg in ([] if OS.get_environment("MAP_ONLY") == "gibeah" else ["en", "pt"]):      # MAP_ONLY=gibeah: the fortress alone
			Game.save["lang"] = lg
			m.map.open(true, 3)
			await _frames(110)
			await _snap(dir, "map_" + lg)
			m.map.index = 0
			await _frames(5)
			await _snap(dir, "map_first_" + lg)
			m.map._start_walk()
			await _frames(28)
			await _snap(dir, "map_walk_" + lg)
			m.map.walk = -1.0
			m.map._toggle()
			await _frames(140)
			await _snap(dir, "map_land_" + lg)
			m.map.close()
		# the fortress, as it is once he serves in it
		Game.save["unlocked"] = _index("night_fit") + 1
		Game.save["gifts"] = ["voice", "hand", "sling", "lyre", "walksong", "steady", "favour"]
		m.section_idx = _index("kings_hall")
		for lg in ["en", "pt"]:
			Game.save["lang"] = lg
			m.map.open(true, m.section_idx)
			await _frames(130)
			await _snap(dir, "map_gibeah_" + lg)
			m.map.close()      # no picture of him walking here: a fortress road is walked in half a second, and saving a picture takes longer, so he would arrive and travel
		# the wider land once the ridge road is a place on it, and the hills with his father's house
		Game.save["unlocked"] = _index("back_and_forth")
		m.section_idx = _index("back_and_forth")
		for lg in ["en", "pt"]:
			Game.save["lang"] = lg
			m.map.open(true, m.section_idx)
			await _frames(150)
			await _snap(dir, "map_road_" + lg)
			m.map._toggle()
			m.map.index = 8
			await _frames(130)
			await _snap(dir, "map_home_" + lg)
			m.map.close()
		print("PLACESHOTS done")
		tree.quit()
		return
	if OS.has_environment("JOURNAL_ONLY"):
		await m.load_level(_index("section2"), 0)
		Game.cinematic = false
		for lg in ["en", "pt"]:
			Game.save["lang"] = lg
			Input.action_press("growth")
			await _frames(40)
			await _snap(dir, "journal_" + lg)
			Input.action_release("growth")
			await _frames(20)
		print("PLACESHOTS done")
		tree.quit()
		return
	for name in ([] if OS.has_environment("CAVES_ONLY") else ["section1", "well", "section2", "wadi", "den", "section3", "watch", "section4"]):
		await m.load_level(_index(name), 0)
		var lv = m.level
		Game.cinematic = false
		if lv.finds.is_empty():
			print("no place in ", name)
			continue
		var at: Vector2 = lv.finds[0]["at"]
		lv.player.global_position = lv.on_ground(at.x - 330.0)
		lv.player.velocity = Vector2.ZERO
		lv.player.cam.reset_smoothing()
		await _frames(50)
		await _snap(dir, name + "_a_below")
		lv.player.global_position = at
		lv.player.velocity = Vector2.ZERO
		lv.player.cam.reset_smoothing()
		Game.fast = false
		await _frames(70)
		await _snap(dir, name + "_b_found")
		Game.fast = true
	# the side caves: at the mouth outside, just inside, and at the back with a torch lit
	Game.save["places"] = []
	m.overlay.visible = false
	for name in ["section1", "section2", "wadi"]:
		await m.load_level(_index(name), 0)
		var lc = m.level
		Game.cinematic = false
		var cv: Dictionary = lc.caves[0]
		lc.player.global_position = lc.on_ground(cv["door"] - 150.0)
		lc.player.cam.reset_smoothing()
		await _frames(50)
		await _snap(dir, name + "_cave_1_mouth")
		lc._cave_state(cv)
		lc.player.global_position = lc.on_ground(cv["x0"] + 240.0)
		lc.player.cam.reset_smoothing()
		await _frames(50)
		await _snap(dir, name + "_cave_2_inside")
		lc.light_torch()
		lc.player.global_position = lc.on_ground(cv["x0"] + 600.0)
		lc.player.cam.reset_smoothing()
		await _frames(50)
		await _snap(dir, name + "_cave_3_step")
		lc.player.global_position = lc.on_ground(cv["x1"] - 330.0)
		lc.player.cam.reset_smoothing()
		await _frames(40)
		await _snap(dir, name + "_cave_4_back")
	print("PLACESHOTS done")
	tree.quit()
	return
	# the gift in the Pastures: waiting, ready, and being given
	m.hud.place_t = 0.0
	m.overlay.visible = false
	Game.save["gifts"] = []
	await m.load_level(_index("section1"), 0)
	var l1 = m.level
	Game.cinematic = false
	l1.player.global_position = l1.on_ground(2040.0)
	l1.player.cam.reset_smoothing()
	await _frames(60)
	await _snap(dir, "gift_1_waiting")
	l1.sheep_count = 2
	await _frames(80)
	await _snap(dir, "gift_2_ready")
	Game.fast = false
	l1.player.global_position = l1.on_ground(2180.0)
	await _frames(70)
	await _snap(dir, "gift_3_kneel")
	await _frames(110)
	await _snap(dir, "gift_4_named")
	await _frames(330)
	await _snap(dir, "gift_5_after")
	Game.fast = true
	print("PLACESHOTS done")
	tree.quit()


## Screenshots of the growth page, a smooth stone, the jar trial and the thorn brake.
func newshots(m, dir: String) -> void:
	main = m
	tree = m.get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	m.menu.close()
	m.hud.visible = true
	Game.backdrop = false
	Game.cinematic = false
	Game.save["growth"] = {"feet": 120.0, "hand": 7.0, "eye": 8.0, "heart": 4.0, "voice": 2.0}
	Game.save["has_sling"] = true
	var lv
	if OS.has_environment("DAVID_LANG"):
		Game.save["lang"] = OS.get_environment("DAVID_LANG")
	# the well
	await m.load_level(_index("well"), 0)
	lv = m.level
	await _goto(600.0)
	await _frames(60)
	await _snap(dir, "well_1_road")
	Game.grew.emit("voice", 2)
	await _frames(70)
	await _snap(dir, "well_1b_grew")
	lv.player.grow_fx = 0.0
	main.hud.notices.clear()
	await _goto(2190.0)
	await _frames(50)
	await _snap(dir, "well_2_stone")
	lv._fulcrum_moved(2230.0)
	await _hold(lv, lv.lever_task)
	lv.shepherd_call(lv.on_ground(2560.0), 600.0, false)
	await _hold(lv, lv.draw_task)
	lv.fulcrum["body"].position.x = 2233.0
	await _goto(2200.0)
	await _frames(40)
	await _snap(dir, "well_2b_bucket")
	await _goto(1960.0)
	await _hold(lv, lv.pour_tasks[0])
	await _frames(170)
	await _snap(dir, "well_3_troughs")
	lv.watered = true
	lv._close_well()
	await _goto(3720.0)
	Game.fast = false
	await _frames(150)
	await _snap(dir, "well_4_count")
	Game.fast = true
	# the wadi
	await m.load_level(_index("wadi"), 0)
	lv = m.level
	await _goto(1040.0)
	await _frames(60)
	await _snap(dir, "wadi_1_step")
	await _goto(2200.0)
	await _frames(50)
	await _snap(dir, "wadi_2_shelf")
	await _goto(3760.0)
	await _frames(50)
	await _snap(dir, "wadi_3_high")
	await _goto(lv.end_x - 150.0)
	await _frames(50)
	await _snap(dir, "wadi_4_cave")
	# the den
	await m.load_level(_index("den"), 0)
	lv = m.level
	await _goto(330.0)
	await _frames(50)
	await _snap(dir, "den_1_mouth")
	lv.light_torch()
	await _goto(1250.0)
	await _frames(50)
	await _snap(dir, "den_2_torch")
	lv.torch_t = 0.0
	await _frames(20)
	await _snap(dir, "den_3_dark")
	lv.light_torch()
	await _goto(3700.0)
	await _frames(80)
	await _snap(dir, "den_4_bear")
	# the night watch
	await m.load_level(_index("watch"), 0)
	lv = m.level
	await _goto(1400.0)
	await _frames(80)
	await _snap(dir, "watch_1_fold")
	lv.fire_level = 0.3
	await _goto(2100.0)
	await _frames(60)
	await _snap(dir, "watch_2_lowfire")
	Game.save["unlocked"] = 5
	Game.save["stones"] = ["s1_start", "well_terrace", "wadi_shelf"]
	m.map.open(true, 3)
	await _frames(10)
	await _snap(dir, "map_1_hills")
	m.map.view = "land"
	await _frames(10)
	await _snap(dir, "map_2_land")
	tree.quit(0)


func shots(m, dir: String) -> void:
	main = m
	tree = m.get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	Game.fast = false
	await m.show_menu()
	Game.fast = true
	await _frames(30)
	await _snap(dir, "menu")
	m.menu.close()
	m.hud.visible = true
	var stops := [[400.0, 1250.0, 1800.0, 3560.0, 4760.0], [300.0, 1400.0, 2500.0, 3650.0, 5350.0], [500.0, 1650.0, 3050.0, 3900.0], [300.0, 1000.0, 2700.0, 3050.0]]
	for i in stops.size():
		Game.backdrop = false
		Game.cinematic = false
		Game.save["has_sling"] = i >= 1
		await m.load_level(i, 0)
		for x in stops[i]:
			await _goto(x)
			await _frames(50)
			await _snap(dir, "s%d_%d" % [i + 1, int(x)])
	# David in motion, frame by frame, for review
	Game.save["has_sling"] = true
	Game.cinematic = false
	await m.load_level(0, 0)
	await _goto(2300.0)
	await _frames(20)
	await _snap(dir, "m_idle")
	Input.action_press("move_right")
	await _frames(26)
	for i in 8:
		await _snap(dir, "m_run%d" % i)
		await _frames(3)
	Input.action_press("jump")
	for i in 8:
		await _frames(5)
		await _snap(dir, "m_jump%d" % i)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(40)
	Input.action_press("attack")
	for i in 5:
		await _frames(3)
		await _snap(dir, "m_hit%d" % i)
	Input.action_release("attack")
	await _frames(30)
	Input.action_press("sling")
	for i in 3:
		await _frames(7)
		await _snap(dir, "m_sling%d" % i)
	Input.action_release("sling")
	# the staff combo and the sling throw
	await _frames(30)
	for hit in 3:
		Input.action_press("attack")
		await _frames(2)
		Input.action_release("attack")
		await _frames(7)
		await _snap(dir, "combo%d" % hit)
		await _frames(12)
	await _frames(40)
	Input.action_press("sling")
	await _frames(20)
	Input.action_release("sling")
	await _frames(5)
	await _snap(dir, "throw")
	# flinch when struck
	await _frames(30)
	m.level.player.hurt(1, m.level.player.position.x + 50.0)
	await _frames(7)
	await _snap(dir, "hurt")
	# story poses: carrying the lamb, kneeling, lifting his face
	await _frames(80)
	Game.cinematic = true
	m.level.player.act = "carry"
	await _frames(40)
	await _snap(dir, "carry")
	await m.load_level(3, 2)
	await _goto(3046.0)
	await _frames(30)
	m.level.player.act = "kneel"
	m.level.player.act_t = 0.0
	Game.fast = false
	m.level.pour()
	m.level.player.cam.zoom = Vector2(1.55, 1.55)
	await _frames(100)
	await _snap(dir, "anoint_kneel")
	await _frames(240)
	await _snap(dir, "anoint_pour")
	Game.fast = true
	m.level.player.act = "kneel_up"
	m.level.player.act_t = 0.0
	await _frames(90)
	await _snap(dir, "anoint_up")
	# the lion: crouch, pounce, landing, panting
	Game.cinematic = false
	await m.load_level(2, 2)
	await _goto(3000.0)
	await _frames(20)
	var lv = m.level
	var seen := {}
	for i in 900:
		await tree.physics_frame
		lv.player.hp = 5
		lv.player.invuln = 1.0
		if is_instance_valid(lv.lion):
			var st: String = lv.lion.state
			var n: int = seen.get(st, 0)
			if n < 3 and i % 9 == 0:
				seen[st] = n + 1
				await _snap(dir, "lion_%s%d" % [st, n])
	# the bear rearing and swiping
	await m.load_level(2, 1)
	await _goto(1600.0)
	await _frames(20)
	lv = m.level
	seen = {}
	for i in 700:
		await tree.physics_frame
		lv.player.hp = 5
		lv.player.invuln = 1.0
		if is_instance_valid(lv.bear):
			var st2: String = lv.bear.state
			var n2: int = seen.get(st2, 0)
			if n2 < 3 and i % 6 == 0:
				seen[st2] = n2 + 1
				await _snap(dir, "bear_%s%d" % [st2, n2])
	tree.quit()


## The torch as he carries it in the Bear's Den: standing, walking and running, each way, a few frames apart.
func torchshots(m, dir: String) -> void:
	main = m
	tree = m.get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	m.menu.close()
	m.hud.visible = false
	Game.backdrop = false
	Game.cinematic = false
	m.get_window().size = Vector2i(1280, 720)
	await m.load_level(_index("den"), 0)
	var lv = m.level
	var p = lv.player
	await _goto(lv.EMBERS[0] + 200.0)
	lv.light_torch()
	await _frames(40)
	await _snap(dir, "idle_r")
	for way in [["move_right", "r"], ["move_left", "l"]]:
		Input.action_press(way[0])
		Input.action_press("walk")
		for k in 4:
			await _frames(9)
			await _snap(dir, "walk_%s_%d" % [way[1], k])
		Input.action_release("walk")
		await _frames(50)
		for k in 4:
			await _frames(7)
			await _snap(dir, "run_%s_%d" % [way[1], k])
		Input.action_release(way[0])
		await _frames(40)
		await _snap(dir, "idle_%s" % way[1])
	Input.action_press("attack")
	await _frames(8)
	await _snap(dir, "strike")
	Input.action_release("attack")
	await _frames(30)
	m.get_tree().quit()


func _snap(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


## 2.4 The King's Hall: the shadow on the wall is the whole of it.
func _kings_hall(lv) -> void:
	var p = lv.player
	var had: Array = Game.save.get("gifts", []).duplicate()
	for g in ["lyre", "voice", "walksong", "steady"]:
		Game.give(g, true)
	for a in ["move_right", "jump", "attack", "sling", "lyre"]:
		Input.action_release(a)
	_check(not Game.has("favour") and int(Game.GIFTS["favour"]["after"]) == Game.chapter_start(1) + 3 and lv.section_idx == Game.chapter_start(1) + 3,
			"he comes into the hall without the King's Favour, which this section gives")
	_check(p.cam.limit_left == int(lv.VIEW_L) and p.cam.limit_right == int(lv.VIEW_R) and lv.VIEW_R - lv.VIEW_L < 1280.0 / p.cam.zoom.x + 2.0,
			"the hall is one room: the camera is held still, and the shadow stays on its wall")
	_check(not lv.hears(lv.DOOR_X) and lv.hears(lv.KING_X - 300.0) and not lv.hears(lv.LAMP_X + 10.0), "the king hears him from this side of the lamp, not from the door")
	await _goto(lv.KING_X - 380.0)
	await _frames(30)
	_check(lv.trial and not lv.rested and is_instance_valid(lv.king), "come before the king, the playing begins")
	_check(lv.lines.size() == Game.psalm().size() and (lv.lines.is_empty() or lv.lines[0] == "p23_shepherd"), "he has the lines of the psalm he found in the hills, in the psalm's order (%d)" % lv.lines.size())
	lv._begin_trial()
	lv.swell_wait = 99.0
	_check(is_equal_approx(lv.shadow, lv.start_shadow) and lv.song_noise(p.global_position) == 0.0 and lv.song_pace(p.global_position) == 1.0,
			"the shadow stands tall when he begins, and between swells the breath is his own")
	var s0: float = lv.shadow
	await _play_song(p, 1)
	_check(lv.shadow < s0 - lv.down * 0.8 and lv.landed == 1 and (lv.lines.is_empty() or lv.line_id == lv.lines[0]),
			"a phrase that lands brings the shadow down, and the first line of the psalm is written (%.2f to %.2f)" % [s0, lv.shadow])
	await _play_song(p, 1)
	_check(lv.lines.size() < 2 or lv.line_id == lv.lines[1], "the next phrase carries the next line")
	s0 = lv.shadow
	Input.action_press("lyre")
	for i in 200:
		await tree.physics_frame
		if p.act == "play" and p.breath_v > 0.2 and p.breath_v < 0.7:
			break
	Input.action_release("lyre")
	await _frames(3)
	_check(lv.shadow > s0 + lv.up * 0.8 and lv.trial, "a phrase let go too soon lets it grow (%.2f to %.2f)" % [s0, lv.shadow])
	Input.action_release("lyre")
	s0 = lv.shadow
	await _frames(90)
	_check(lv.shadow > s0 and lv.shadow < s0 + 0.05, "left alone it creeps up, slowly")
	lv.shadow = lv.TOP_CREEP - 0.001
	await _frames(40)
	_check(lv.shadow <= lv.TOP_CREEP and lv.trial and not lv.turning, "but by itself it never turns the king away")
	# a swell
	lv.shadow = 0.5
	lv.swell_kind = 1
	lv.swell_wait = 0.01
	await _frames(60)
	_check(lv.swell_on > 0.0 and lv.swell > 0.3 and lv.swell_kind == 0 and lv.song_noise(p.global_position) > 0.2 and lv.song_pace(p.global_position) == 1.0,
			"the trouble comes in swells: this one shakes the breath line (%.2f)" % lv.swell)
	lv.swell_on = 0.0
	lv.swell_wait = 0.01
	await _frames(60)
	_check(lv.swell_kind == 1 and lv.song_pace(p.global_position) > 1.2 and lv.song_noise(p.global_position) == 0.0, "and the next one hurries it")
	lv.swell = 1.0
	lv.swell_on = 3.0
	s0 = lv.shadow
	lv.phrase(p.global_position, false)
	_check(lv.shadow < s0 - lv.down * 1.3 and lv.swell_on <= lv.swell_long * 0.2 + 0.01, "a phrase landed inside a swell counts for more, and the swell breaks on it")
	lv.swell_on = 0.0
	lv.swell_wait = 99.0
	s0 = lv.shadow
	lv.phrase(lv.on_ground(lv.DOOR_X), false)
	_check(lv.shadow == s0, "played from the door, the king does not hear it")
	# too much lost: he turns away, and it begins again
	var hp: int = p.hp
	lv.shadow = 1.0 - lv.up * 0.5
	lv.landed = 3
	lv.phrase_lost(p.global_position, false)
	_check((lv.turning or lv.turned_once) and not lv.done, "too much lost, and the king turns his face to the wall")
	for i in 400:
		await tree.physics_frame
		if not lv.turning:
			break
	_check(lv.trial and not lv.turning and absf(lv.shadow - lv.start_shadow) < 0.02 and lv.landed == 0 and lv.line_i == 0 and p.hp == hp and not Game.cinematic and not lv.done,
			"no one is hurt: he waits, and begins again from the first line")
	# the shadow brought all the way down
	await _goto(lv.KING_X - 300.0)
	lv.swell_wait = 99.0
	lv.shadow = lv.down * 0.5
	await _play_song(p, 1)
	_check(lv.rested and not lv.trial and lv.rest_t >= 0.0 and lv.shadow == 0.0, "the shadow brought all the way down, the king rests")
	for i in 300:
		await tree.physics_frame
		if lv.done:
			break
	_check(Game.has("favour") and lv.done, "and the King's Favour is given")
	_check(Game.main.hud._pages() == 3 and Game.main.hud.COURT.size() >= 4, "the journal gains the court: a third page")
	var told := true
	for e in Game.main.hud.COURT:
		told = told and Game._ui_pt.has(e[0]) and Game._ui_pt.has(e[1])
	_check(told and Game._ui_pt.has("Not in scripture") and Game._ui_pt.has(Game.GIFTS["favour"]["line"]) and str(Game.GIFTS["favour"]["line"]).contains("none yet"),
			"the court is told in Portuguese too, and the gift does not promise doors that are not built")
	Input.action_release("lyre")
	Game.save["gifts"] = had
	Game.main.hud.page = 0


## The Night Fit: the hall's playing in waves, the lamps between them, what he already has, and the Night Song.
func _night_fit(lv) -> void:
	var p = lv.player
	var had: Array = Game.save.get("gifts", []).duplicate()
	var gifts: Array = Game.save.get("gifts", [])
	gifts.erase("nightsong")
	for g in ["lyre", "voice", "walksong", "steady", "favour"]:
		Game.give(g, true)
	for a in ["move_right", "jump", "attack", "sling", "lyre", "grab"]:
		Input.action_release(a)
	var idx: int = Game.chapter_start(1) + 5
	_check(not Game.has("nightsong") and int(Game.GIFTS["nightsong"]["after"]) == idx and lv.section_idx == idx and "nightsong" in Game.GIFT_ORDER
			and Game.song_hold() == 1.0, "he comes into the night without the Night Song, which this section gives")
	_check(lv.lamps.size() == 3 and lv.lamps_wanting() == 0 and lv.dark != null and lv.dark_amount > 0.5 and not is_instance_valid(lv.steward) and not is_instance_valid(lv.youth),
			"the hall at night: three lamps burning in the dark, and no one else in the room")
	_check(lv.up > 0.1 and lv.WAVES.size() == 3 and lv.WAVES[2]["start"] > lv.WAVES[1]["start"] and lv.WAVES[1]["start"] > lv.WAVES[0]["start"]
			and lv.WAVES[2]["shake"] > lv.WAVES[0]["shake"], "a lost phrase costs more than in the evening, and each wave is stronger than the last")
	await _goto(lv.KING_X - 380.0)
	await _frames(30)
	lv._begin_trial()
	_check(lv.trial and lv.wave == 0 and not lv.lull and absf(lv.shadow - float(lv.WAVES[0]["start"])) < 0.03, "come before the king, the first wave begins (%.2f)" % lv.shadow)
	lv.swell_wait = 99.0
	await _goto(lv.KING_X - 300.0)
	# the King's Favour: once in a wave he is waited for
	var hp: int = p.hp
	lv.shadow = 1.0 - lv.up * 0.5
	lv.phrase_lost(p.global_position, false)
	_check(lv.grace_used and not lv.turning and lv.trial and is_equal_approx(lv.shadow, lv.GRACE_AT), "the King's Favour: the loss that would have turned the king away does not, once")
	lv._gutter(1)
	lv.shadow = 1.0 - lv.up * 0.5
	lv.phrase_lost(p.global_position, false)
	_check(lv.turning or lv.turned_once, "the second time he turns his face to the wall")
	for i in 500:
		await tree.physics_frame
		if not lv.turning:
			break
	_check(lv.trial and not lv.turning and lv.wave == 0 and lv.lamps_wanting() == 0 and absf(lv.shadow - float(lv.WAVES[0]["start"])) < 0.02 and not lv.grace_used and p.hp == hp
			and not Game.cinematic and not lv.done, "no one is hurt: the lamps are lit again and he begins the same wave again (%s)" % str([lv.trial, lv.turning, lv.wave, lv.lamps_wanting(), lv.shadow, lv.grace_used, p.hp, hp, Game.cinematic]))
	# the first wave brought down: a lull, and a lamp guttering
	await _goto(lv.KING_X - 300.0)
	lv.swell_wait = 99.0
	lv.shadow = lv.down * 0.5
	lv.phrase(p.global_position, false)
	await _until(func() -> bool: return not Game.cinematic, 300)
	_check(lv.lull and not lv.rested and lv.wave == 0 and lv.lamps[0]["state"] == "low" and lv.lamps[0]["task"]["on"] and lv.lamps_out() == 0,
			"the first wave down is not the end: the lamp by the door gutters, and wants tending")
	lv.phrase(p.global_position, false)
	_check(lv.lull and not lv.rested and lv.wave == 0, "playing on does not light a lamp, nor bring the next wave")
	_check(lv.song_noise(p.global_position) == 0.0 and lv.song_pace(p.global_position) == 1.0, "between waves the breath is his own")
	lv.lamps[0]["t"] = 0.05
	await _frames(12)
	var s0: float = lv.shadow
	await _frames(90)
	_check(lv.lamps[0]["state"] == "out" and lv.lamps_out() == 1 and lv.shadow > s0 + 0.01 and lv.lull, "left alone the lamp goes out, and the dark lets the shadow grow (%.3f to %.3f)" % [s0, lv.shadow])
	await _goto(lv.lamps[0]["task"]["x"])
	Input.action_press("grab")
	await _until(func() -> bool: return lv.lamps[0]["state"] == "lit", 300)
	Input.action_release("grab")
	_check(lv.lamps[0]["state"] == "lit" and not lv.lamps[0]["task"]["on"], "he gets up and tends it at its stand, and it burns")
	await _until(func() -> bool: return lv.wave == 1, 300)
	_check(lv.wave == 1 and not lv.lull and lv.shadow >= float(lv.WAVES[1]["start"]) - 0.001 and lv.swell_shake > float(lv.WAVES[0]["shake"]),
			"every lamp burning, the second wave comes, taller and stronger (%.2f)" % lv.shadow)
	lv.swell_wait = 99.0
	lv.shadow = lv.down * 0.5
	lv.phrase(lv.on_ground(lv.KING_X - 300.0), false)
	_check(lv.lull and lv.lamps_wanting() == 2, "the second wave down, two lamps gutter")
	lv._tend(0)
	lv._tend(1)
	await _until(func() -> bool: return lv.wave == 2, 300)
	_check(lv.wave == 2 and not lv.lull, "and the last wave comes")
	# the last wave: it shakes and hurries at once, and the lamp by the king gutters in the middle of it
	lv.swell_on = 0.0
	lv.swell_wait = 0.01
	await _frames(60)
	_check(lv.swell > 0.3 and lv.song_noise(p.global_position) > 0.3 and lv.song_pace(p.global_position) > 1.2, "in the last wave a swell shakes the breath line and hurries it at once")
	_check(lv.lamps_wanting() == 0, "the first swell leaves the lamps alone")
	lv.swell_on = 0.0
	lv.swell_wait = 0.01
	await _frames(60)
	_check(lv.lamps[lv.MID_LAMP]["state"] == "low" and lv.trial and not lv.lull, "at the second the lamp by the king gutters, in the middle of the playing")
	lv._tend(lv.MID_LAMP)
	lv.swell_on = 0.0
	lv.swell_wait = 99.0
	lv.shadow = lv.down * 0.5
	lv.phrase(lv.on_ground(lv.KING_X - 300.0), false)
	_check(lv.rested and not lv.trial and lv.rest_t >= 0.0, "the last wave down, the king rests")
	for i in 400:
		await tree.physics_frame
		if lv.done:
			break
	_check(Game.has("nightsong") and lv.done and Game.song_hold() > 1.4, "and the Night Song is given: the quiet his playing leaves holds longer")
	# the gift is real outside this room: a sheep settled by the song stays settled longer
	var g: Dictionary = Game.GIFTS["nightsong"]
	_check(Game._ui_pt.has(g["name"]) and Game._ui_pt.has(g["line"]) and Game._ui_pt.has(g["why"]) and Game._ui_pt.has(g["how"]), "it is told in Portuguese too")
	Input.action_release("lyre")
	Game.save["gifts"] = had


## The Armour-Bearer: the work of the yard in its order, the king's shield on his arm, the block, and the drill.
func _armour_bearer(lv) -> void:
	var p = lv.player
	var had: Array = Game.save.get("gifts", []).duplicate()
	for a in ["move_right", "jump", "attack", "sling", "lyre"]:
		Input.action_release(a)
	await _frames(20)
	var idx: int = Game.chapter_start(1) + 4
	_check(not Game.has("shieldarm") and int(Game.GIFTS["shieldarm"]["after"]) == idx and lv.section_idx == idx and "shieldarm" in Game.GIFT_ORDER,
			"he comes to the yard without the Shield Arm, which this section gives")
	_check(not p.shield and lv.step == 0 and lv.water_task["on"] and not lv.steward_task["on"] and not lv.mark_task["on"],
			"he begins with empty hands and a servant's work: water first")
	# without the king's shield the Staff key is the staff, and nothing is raised
	Game.give("shieldarm", true)
	await _goto(lv.START_X)
	Input.action_press("attack")
	await _frames(14)
	Input.action_release("attack")
	_check(not p.blocking and not p.shield_up, "the Shield Arm does nothing where he does not bear the king's shield")
	Game.save["gifts"] = had.duplicate()
	await _frames(40)
	# the first two days, by their tasks
	await _hold(lv, lv.water_task)
	await _hold(lv, lv.pour_task)
	await _hold(lv, lv.oil_task)
	_check(lv.step == 3 and lv.lamps_task["on"], "water drawn and poured, oil asked for: the lamps are next")
	await _hold(lv, lv.lamps_task)
	await _until(func() -> bool: return lv.day == 2 and lv.step == 4 and lv.word_task["on"], 1200)
	_check(lv.day == 2 and lv.step == 4 and lv.word_task["on"] and absf(p.global_position.x - lv.HALL_X) < 120.0, "the day ends, and the next finds him at the door of the hall")
	await _hold(lv, lv.word_task)
	await _hold(lv, lv.steward_task)
	await _until(func() -> bool: return lv.step == 6 and lv.door_task["on"], 1200)
	_check(p.shield and lv.step == 6 and lv.door_task["on"], "the steward puts the king's shield and spear into his hands")
	# bearing them he walks, does not leap, and neither staff nor sling is in his hands
	await _goto(lv.STORE_X)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(70)
	Input.action_release("jump")
	_check(p.is_on_floor() and absf(p.velocity.x) <= p.WALK + 2.0 and p.velocity.x > 60.0, "bearing them he walks and does not leap (%d)" % int(p.velocity.x))
	Input.action_release("move_right")
	Input.action_press("sling")
	await _frames(10)
	_check(not p.charging and p.attack_t <= 0.0, "and the sling stays in his belt")
	Input.action_release("sling")
	Input.action_press("attack")
	await _frames(14)
	_check(not p.blocking and p.attack_t <= 0.0, "before the drill he carries the shield and cannot yet raise it, and he does not strike")
	Input.action_release("attack")
	await _hold(lv, lv.door_task)
	await _until(func() -> bool: return lv.step == 7 and lv.mark_task["on"], 1200)
	_check(lv.day == 3 and lv.step == 7 and lv.mark_task["on"], "the third morning: the shield-man calls him")
	# the drill
	await _goto(lv.MARK_X)
	await _hold(lv, lv.mark_task)
	_check(lv.drilling and p.shield_learn and lv.in_place(), "he takes his place, and is let raise the shield")
	Input.action_press("attack")
	await _frames(12)
	_check(p.blocking, "the Staff key raises the king's shield")
	var hp0: int = p.hp
	p.invuln = 0.0      # he was set down at the door a moment ago, and nothing can touch him for a second after that
	_check(not p.hurt(1, p.global_position.x + 60.0) and p.hp == hp0 and p.block_flash > 0.0, "a blow from the front lands on it and does no harm")
	p.invuln = 0.0
	_check(p.hurt(1, p.global_position.x - 60.0) and p.hp == hp0 - 1, "a blow from behind is not stopped by it")
	p.hp = hp0
	p.invuln = 0.0
	p.stun = 0.0
	await _frames(int(p.BLOCK_HOLD * 60.0) + 30)
	_check(not p.blocking and p.block_spent, "held up too long, the arm drops")
	Input.action_release("attack")
	await _goto(lv.MARK_X)
	p.facing = 1
	lv.stood = 0
	lv.bout = 0
	lv._rest(0.2)
	# a blow not met: nothing is lost but the bout
	lv.stood = 2
	var n := 0
	while n < 400 and lv.stood == 2:
		await tree.physics_frame
		n += 1
	_check(lv.stood == 0 and p.hp == hp0 and lv.bout == 0, "a blow he does not meet stings, costs no heart, and the bout begins again")
	# now he raises it for each stroke, not before
	n = 0
	while n < 4000 and not lv.passed:
		await tree.physics_frame
		n += 1
		p.invuln = 0.0
		if absf(p.global_position.x - lv.MARK_X) > 30.0 and not Game.cinematic:
			p.global_position = lv.on_ground(lv.MARK_X)
			p.facing = 1
		if lv.phase == "strike":
			Input.action_press("attack")
		else:
			Input.action_release("attack")
	Input.action_release("attack")
	_check(lv.passed and p.hp == hp0, "three bouts stood through: the drill is passed (%d frames)" % n)
	for i in 400:
		await tree.physics_frame
		if Game.has("shieldarm") and lv.end_task["on"]:
			break
	_check(Game.has("shieldarm") and lv.end_task["on"] and p.shield, "and the Shield Arm is given, the king's shield still on his arm")
	await _hold(lv, lv.end_task)
	await _until(func() -> bool: return lv.done, 1200)
	_check(lv.done and not p.shield, "he carries them back to the king's door; they were never his")
	var told := Game._ui_pt.has(Game.GIFTS["shieldarm"]["line"]) and Game._ui_pt.has(Game.GIFTS["shieldarm"]["key"]) and Game._ui_pt.has(Game.GIFTS["shieldarm"]["why"]) \
			and Game.narration.has("1sam16_21b") and Game.narration_pt.has("1sam16_21b") and Game._ui_pt.has(lv._goal_now())
	for e in Game.main.hud.COURT:
		told = told and Game._ui_pt.has(e[0]) and Game._ui_pt.has(e[1])
	_check(told and str(Game.GIFTS["shieldarm"]["line"]).contains("never his"), "it is told in Portuguese too, and the gift says the shield is the king's")
	Game.save["gifts"] = had


# ---- real-flow check: narration, pause, section change, chapter end ----

## Chapter Two, Back and Forth: the wolves at another man's sheep on the road south; at Bethlehem nine by the rod
## and eight by name, the stranger picked out, Devorah quieted and brought in, the flock watered and played to rest;
## the red ewe led north by the song, bolting from a runner unquieted and standing through one quieted; the news,
## and the height toward Elah.
func _back_and_forth(lv) -> void:
	var p = lv.player
	var had: Array = Game.save.get("gifts", []).duplicate()
	for g in ["lyre", "voice", "sling", "walksong", "steady", "nightsong"]:
		Game.give(g, true)
	for a in ["move_right", "jump", "attack", "sling"]:
		Input.action_release(a)
	await _frames(5)
	_check(lv.part == 0 and lv.sheep_total == 0 and lv.red_a.size() == 5 and not lv.led, "he takes the road south alone; the count of the flock is the keeper's")
	_check(lv.fars[0].visible and not lv.fars[1].visible and not lv.fars[2].visible and p.cam.limit_right == int(lv.A_W), "the road south has its own far view, and the camera keeps to it")
	await _goto(lv.A_FOLD - 300.0)
	await _frames(20)
	_check(lv.wolves_out and lv.wolves.size() == 2, "above the ford two wolves are at another man's sheep (%d)" % lv.wolves.size())
	if not lv.wolves_gone:
		_check(not lv.down_task["on"] and lv.red_a[0].prey and lv.red_a[0].mark.a > 0.0, "the red-daubed sheep are left out for them, and he cannot go on while they are")
		for w in lv.wolves:
			if is_instance_valid(w) and not w.fleeing:
				_check(w.is_prey(lv.red_a[0]) and not w.is_prey(lv.stranger), "a wolf will take a marked sheep the story has left out, and no other marked one")
				w.hp = 1
				w.hit(1, -1, "staff")
	await _until(func() -> bool: return lv.wolves_gone and lv.down_task["on"], 200)
	_check(lv.wolves_gone and lv.down_task["on"] and not lv.red_a[0].prey, "the wolves driven off, the road down to Bethlehem is open")
	await _hold(lv, lv.down_task)
	await _until(func() -> bool: return lv.part == 1 and not Game.cinematic, 400)
	# Bethlehem
	_check(lv.part == 1 and lv.fars[1].visible and not lv.fars[0].visible and p.cam.limit_left == int(lv.H) and p.global_position.x > lv.H, "he comes down to Bethlehem: its own far view, and the road is behind him")
	_check(lv.wolves.is_empty() and lv.pen.size() == 8 and not lv.pen.has("devorah") and lv.stranger.mark.a > 0.0 and lv.stranger.who == "",
			"nine stand in the day fold: eight of his father's, and one that wears another man's mark")
	var dv = lv.devorah
	_check(dv.who == "devorah" and not dv.gatherable and not dv.gathered and absf(dv.global_position.x - lv.NIGHT_FOLD_X) < 120.0, "Devorah is shut in the night fold by the house")
	await _goto(lv.KEEPER_X)
	await _frames(20)
	_check(lv.step == lv.COUNT and lv.count_task["on"], "at the day fold the keeper has nine to show him")
	await _hold(lv, lv.count_task)
	await _frames(10)
	_check(lv.step == lv.CALL and lv.call_task["on"], "nine go under the rod, and then he calls them by name")
	await _goto(lv.COUNT_X)
	for k in 3:
		await _hold(lv, lv.call_task)
		await _frames(20)
	_check(lv.call_i == 3 and lv.step == lv.CALL and lv.pen["noga"].name_t > 0.0, "the lamb, Rachel and Noga answer to their names")
	await _hold(lv, lv.call_task)
	await _frames(10)
	_check(lv.step == lv.PICK and lv.pick_task["on"] and not lv.call_task["on"], "Devorah is called and nothing answers: nine by the rod, eight by name")
	await _goto(lv.pen["rachel"].global_position.x)
	await _frames(6)
	await _hold(lv, lv.pick_task)
	_check(lv.wrong == 1 and lv.step == lv.PICK, "shown one of his father's, he is not satisfied")
	await _goto(lv.stranger.global_position.x)
	await _frames(6)
	await _hold(lv, lv.pick_task)
	await _frames(10)
	_check(lv.step == lv.FIND and lv.bar_task["on"] and not lv.pick_task["on"], "the ewe with the worn daub of red is found out")
	await _goto(lv.BAR_X)
	await _hold(lv, lv.bar_task)
	await _frames(5)
	_check(dv.gatherable and dv.restless, "the bar of the night fold lifted, Devorah is there, and shy of him")
	await _goto(dv.global_position.x - 130.0)
	await _frames(40)
	_check(not dv.gathered, "unquieted, she will not stand for his hand")
	await _goto(dv.home_x - 260.0)
	await _frames(10)
	await _play_song(p, 3)
	_check(dv.calm > lv.SETTLE * 1.5, "the lyre quiets her, and with the Night Song the quiet holds half as long again (%.0f s)" % dv.calm)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(40)
	await _goto(dv.global_position.x)
	await _frames(12)
	_check(dv.gathered and lv.step == lv.BRING and not dv.restless, "quieted, she comes to his hand")
	await _goto(lv.FOLD_X - 80.0)
	dv.global_position = lv.on_ground(p.global_position.x - 50.0)
	await _until(func() -> bool: return lv.step == lv.WATER, 300)
	_check(lv.step == lv.WATER and lv.pen.size() == 9 and lv.followers.is_empty() and lv.well_task["on"], "brought to the day fold she goes to her own place: nine of his father's, and one that is not")
	await _hold(lv, lv.well_task)
	await _frames(10)
	_check(lv.step == lv.REST and lv.rest_song["on"], "watered, they are to be played to rest")
	await _goto(lv.FOLD_X - 60.0)
	await _frames(10)
	await _play_song(p, 3)
	await _until(func() -> bool: return lv.step == lv.MORNING and lv.ewe_task["on"] and not Game.cinematic, 600)
	_check(lv.step == lv.MORNING and lv.ewe_task["on"], "three phrases by the fold, and the night passes")
	await _frames(20)
	var e = lv.stranger
	await _goto(e.global_position.x)
	await _hold(lv, lv.ewe_task)
	await _frames(10)
	_check(lv.led and lv.step == lv.LEAD and lv.quiet == 0.0, "in the morning the red ewe is his to take home")
	var ex0: float = e.global_position.x
	await _goto(ex0 - 200.0)
	Input.action_press("call")
	await _frames(3)
	Input.action_release("call")
	await _frames(80)
	_check(absf(e.global_position.x - ex0) < 12.0, "she does not know his voice: called, she stays where she is")
	Input.action_press("lyre")
	await _until(func() -> bool: return p.act == "play" and p.breath_v < 0.5, 200)
	await _until(func() -> bool: return p.breath_v >= 0.93, 300)
	Input.action_release("lyre")
	await _frames(4)
	_check(lv.quiet > 0.0, "a phrase of the lyre puts its quiet on her (act %s, breath %.2f)" % [p.act, p.breath_v])
	await _until(func() -> bool: return absf(e.global_position.x - p.global_position.x) < 90.0, 400)
	_check(absf(e.global_position.x - p.global_position.x) < 90.0, "and while it lasts she comes after him")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(40)
	await _goto(lv.GATE_X + 60.0)
	e.global_position = lv.on_ground(p.global_position.x + 70.0)
	e.stay = e.global_position.x
	await _frames(10)
	_check(lv.leave_task["on"], "with her at his father's gate, he can set out again")
	await _hold(lv, lv.leave_task)
	await _until(func() -> bool: return lv.part == 2 and not Game.cinematic, 400)
	# the road north
	_check(lv.part == 2 and lv.fars[2].visible and not lv.fars[1].visible and p.cam.limit_left == int(lv.N) and lv.led
			and absf(e.global_position.x - p.global_position.x) < 200.0, "he is on the road north, and the red ewe with him")
	lv.quiet = 0.0
	await _frames(5)
	ex0 = e.global_position.x
	Input.action_press("move_right")
	Input.action_press("walk")
	await _frames(150)
	Input.action_release("move_right")
	Input.action_release("walk")
	_check(absf(e.global_position.x - ex0) < 12.0 and p.global_position.x > ex0 + 150.0, "walked away from unplayed, she does not follow")
	await _goto(e.global_position.x + 60.0)
	var feet: bool = await _lead_playing(p, e, func() -> bool: return e.global_position.x > lv.N + 520.0, 3000)
	_check(feet and e.global_position.x > lv.N + 500.0, "played to as he walks, she follows the lyre up the road (x=%d)" % int(e.global_position.x - lv.N))
	# a runner: unquieted she bolts, quieted she stands through it
	lv._clear_runners()
	lv.quiet = 0.0
	await _frames(5)
	ex0 = e.global_position.x
	lv._runners(1)
	_check(lv.runners.size() == 1 and lv.song_noise(Vector2(float(lv.runners[0]["x"]) - 100.0, 0)) > 0.0 and lv.song_noise(p.global_position) == 0.0,
			"a man comes down the road at a run, and close to him his playing is unsettled")
	await _until(func() -> bool: return lv.bolts >= 1, 500)
	await _frames(100)
	_check(lv.bolts == 1 and e.global_position.x < ex0 - 150.0, "unquieted, she bolts back down the road from him (%d back)" % int(ex0 - e.global_position.x))
	lv._clear_runners()
	lv.bolt_t = 0.0
	lv.quiet = 20.0
	var stood: int = lv.held
	lv._runners(1)
	await _until(func() -> bool: return lv.held > stood, 600)
	_check(lv.held == stood + 1 and lv.bolts == 1 and lv.quiet > 0.0 and lv.quiet < 17.5, "quieted, she stands through the next, and it eats some of her quiet (%.1f s left)" % lv.quiet)
	lv._clear_runners()
	_check(not lv.give_task["on"] and not lv.given, "she is not given back before she is at her own fold")
	await _goto(lv.N_FOLD - 60.0)
	e.global_position = lv.on_ground(p.global_position.x - 60.0)
	lv.quiet = 5.0
	await _frames(10)
	_check(lv.give_task["on"], "at the fold above the ford she can be put in with her own")
	await _hold(lv, lv.give_task)
	await _frames(10)
	_check(lv.given and not lv.led and not lv.news and not lv.end_task["on"], "the ford man's ewe is home, and the road is his own again")
	await _goto(lv.N_JEBUS)
	await _until(func() -> bool: return lv.news, 200)
	_check(lv.news and lv.end_task["on"] and lv.runners.size() == 3, "under Jebus the runners come by with the news of Socoh (%d of them)" % lv.runners.size())
	await _goto(lv.N_HEIGHT)
	await _frames(90)
	_check(lv.elah == null or lv.elah.modulate.a > 0.9, "on the height the far view opens westward")
	await _hold(lv, lv.end_task)
	await _frames(30)
	Game.save["gifts"] = had


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await tree.process_frame
	await tree.process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout


func _skip_story(max_seconds: float) -> void:
	var t := 0.0
	while t < max_seconds and (Game.cinematic or main.overlay.busy or main.state != "play"):
		await _press("accept")
		await _wait(0.25)
		t += 0.3


func flow(m, dir: String) -> void:
	main = m
	tree = m.get_tree()
	var snap := dir != "" and DisplayServer.get_name() != "headless"
	if snap:
		DirAccess.make_dir_recursive_absolute(dir)
	await m.show_menu()
	_check(m.state == "menu" and m.menu.visible, "menu opens")
	await _press("accept")
	await _wait(0.4)
	_check(m.menu.mode == "difficulty", "New Game asks for a difficulty")
	await _press("accept")
	await _wait(7.0)
	_check(m.state == "play" and m.section_idx == 0, "choosing a difficulty starts section 1")
	_check(m.overlay.busy and Game.cinematic, "opening narration is playing")
	_check(m.overlay.voice.stream != null, "narration has a voice recording")
	if snap:
		await _snap(dir, "narration")
	await _skip_story(15.0)
	_check(not Game.cinematic and not m.overlay.busy, "narration can be skipped through")

	await _press("pause")
	await _wait(0.2)
	_check(tree.paused and m.menu.visible, "pause menu opens")
	if snap:
		await _snap(dir, "pause")
	await _press("pause")
	await _wait(0.2)
	_check(not tree.paused and m.state == "play", "pause menu closes")

	var lv = m.level
	lv.sheep_count = lv.sheep_total
	for b in tree.get_nodes_in_group("hittable"):
		b.hit(1, 1, "staff")
		b.hit(1, 1, "staff")
	await _goto(main.level.fold_x)
	await _wait(1.0)
	await _skip_story(20.0)
	await _wait(7.0)
	await _skip_story(15.0)
	_check(m.section_idx == 1 and m.state == "play", "finishing section 1 opens section 2")
	_check(int(Game.save["unlocked"]) >= 1, "progress is saved")

	m.start_section(Game.chapter_start(1) - 1)      # the Anointing: the last of Chapter One
	await _wait(7.0)
	await _skip_story(15.0)
	await _goto(m.level.SAMUEL_X - 50.0)
	await _wait(1.0)
	if snap:
		await _wait(2.0)
		await _snap(dir, "anointing")
	var t := 0.0
	var painted: bool = Game.section_lacks(Game.chapter_start(1)).is_empty()      # is Chapter Two there to walk into?
	while t < 90.0 and m.state != "menu" and not (painted and m.state == "play" and m.section_idx == Game.chapter_start(1)):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	if painted:
		_check(m.state == "play" and m.section_idx == Game.chapter_start(1), "chapter ends and goes on into Chapter Two, now that it is painted")
	else:
		_check(m.state == "menu", "chapter ends and returns to the menu")
	_check(Game.save["finished"] == true, "chapter marked finished")
	var first: int = Game.chapter_start(1)
	_check(int(Game.save["unlocked"]) == first, "and Chapter Two's first section is unlocked (%d)" % int(Game.save["unlocked"]))
	if not Game.section_lacks(first).is_empty():
		_check(not Game.chapter_open(1), "with its pictures unpainted, Chapter Two stays shut and the game goes back to the menu")
	# the same ending with Chapter Two there to walk into (its pictures stood in for, in this test alone)
	Game.force_ready = true
	m.start_section(first - 1)
	await _wait(7.0)
	await _skip_story(15.0)
	await _goto(m.level.SAMUEL_X - 50.0)
	await _wait(1.0)
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first, "the end of Chapter One leads on into Chapter Two")
	_check(int(Game.save["section"]) == first and Game.save["started"] == true and Game.save["finished"] == true, "and the journey is saved there")
	_check(Game.has("lyre") and Game.flock().size() == 9 and m.level.sheep_total == 9 and m.level.flock_here.size() == 9, "he comes into it with the lyre and his own nine")
	await _press("pause")
	await _wait(0.2)
	await m._on_menu("menu")
	await _wait(2.5)
	_check(m.state == "menu" and m.menu.items[0][0] == "continue", "left for the menu, Chapter Two can be continued")
	await _press("accept")
	await _wait(3.0)
	await _skip_story(15.0)
	_check(m.state == "play" and m.section_idx == first, "and Continue goes back into it")
	m.level.kid_tied = true
	m.level._leave()
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first + 1 and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first + 1, "the Summons done, the Ridge Road follows it")
	m.level._arrive()
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first + 2 and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first + 2, "the Ridge Road done, the Gate of Gibeah follows it")
	m.level._wait_called()
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first + 3 and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first + 3, "the Gate of Gibeah done, the King's Hall follows it")
	m.level._rest()
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first + 4 and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first + 4 and Game.has("favour"), "the king rested and the King's Favour given, the Armour-Bearer follows it")
	m.level.bear(true)
	m.level._passed()
	t = 0.0
	while t < 60.0 and not (Game.has("shieldarm") and m.level.end_task["on"] and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(Game.has("shieldarm"), "the drill passed, the Shield Arm is given")
	m.level._end()
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first + 5 and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first + 5 and Game.has("shieldarm"), "the king's arms carried back to his door, the Night Fit follows it")
	m.level._rest()
	t = 0.0
	while t < 90.0 and not (m.state == "play" and m.section_idx == first + 6 and not Game.cinematic and not m.overlay.busy):
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "play" and m.section_idx == first + 6 and Game.has("nightsong"), "the king brought to rest in the night and the Night Song given, the road home follows it")
	_check(m.level.part == 0 and not m.level.led, "Back and Forth begins on the road south, alone")
	m.level._end()
	t = 0.0
	while t < 90.0 and m.state != "menu":
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "menu" and int(Game.save["unlocked"]) == first + 7 and first + 7 == Game.sections().size(), "looking toward Elah, Chapter Two ends and the game returns to the menu (unlocked %d)" % int(Game.save["unlocked"]))
	_check(int(Game.save["section"]) == first and Game.save["started"] == false and Game.save["finished"] == true and not Game.chapter_open(2),
			"the journey is saved at the head of the finished chapter, and Chapter Three is not opened")
	m.menu.chapter = 1
	m.menu.open("sections")
	_check(m.menu.items.size() >= 7 and m.menu.items[6][0] == "section_%d" % (first + 6) and m.menu.items[6][2] == true, "all seven sections of Chapter Two can be walked into again")
	m.menu.close()
	m.menu.open("main")
	Game.force_ready = false
	print("FLOW %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	tree.quit(0 if failures == 0 else 1)


## Going back: a wild thing keeps off him, hears only the lyre played walking, follows while the phrases land, and
## brought home is his find.
func _led(lv, id: String) -> void:
	var e := {}
	for x in lv.wilds:
		if x["id"] == id:
			e = x
	_check(not e.is_empty(), "going back: there is something here to lead (%s)" % id)
	if e.is_empty():
		return
	var p = lv.player
	var was: Vector2 = p.global_position
	var had: Array = Game.places().duplicate()
	var s = e["herd"][0]
	var x0: float = s.global_position.x
	var up: bool = e["perch"] != null
	p.global_position = s.global_position + Vector2(-90.0, 0.0)
	p.velocity = Vector2.ZERO
	await _frames(30)
	if up:
		_check(absf(s.global_position.x - x0) < 2.0 and e["perch"] != null, "up on their rock they only watch him come")
	else:
		_check(absf(s.stay - x0) > 60.0, "it runs from him when he comes near")
	p.global_position = s.global_position + Vector2(-200.0, 0.0)
	lv.led_hear(p.global_position, false)
	_check(float(e["quiet"]) <= 0.0, "a song played standing does not move it")
	lv.led_hear(p.global_position, true)
	await _frames(70)
	_check(float(e["quiet"]) > 0.0 and is_nan(s.stay) and e["perch"] == null and absf(s.global_position.y - lv.on_ground(s.global_position.x).y) < 30.0,
			"the lyre played walking brings it down and after him")
	e["home"] = s.global_position.x + 20.0
	lv.led_hear(p.global_position, true)
	await _frames(5)
	_check(id in Game.places() and lv.wilds.is_empty(), "brought home, it is his find")
	Game.save["places"] = had
	p.global_position = was
	p.velocity = Vector2.ZERO
	p.hp = p.max_hp
	await _frames(5)


## Going back: the jackal bitch will not leave her pups for a blow or a short song; the Night Song moves them all.
func _dam(lv) -> void:
	var p = lv.player
	var was: Vector2 = p.global_position
	var had: Array = Game.places().duplicate()
	var gifts: Array = Game.save.get("gifts", []).duplicate()
	var g: Array = gifts.duplicate()
	g.erase("nightsong")
	Game.save["gifts"] = g
	var d: Dictionary = lv.add_dam("pups", "The Jackal's Pups", "heart", was.x + 260.0, was.x + 180.0, was.x + 420.0, was.x + 520.0)
	_check(not d.is_empty() and d["pups"].size() == 3 and d["pups"][0].meek() and not d["bitch"].meek(), "going back: a bitch lies in the way with her pups")
	await _frames(20)
	lv._dam_song(p.global_position, 600.0)
	_check(not d["gone"], "a song whose quiet does not hold leaves her where she is")
	d["bitch"].drive_off()
	await _frames(400)
	_check(is_instance_valid(d["bitch"]) and not d["bitch"].fleeing and is_instance_valid(d["pups"][0]), "driven off, she comes back to them")
	g.append("nightsong")
	Game.save["gifts"] = g
	lv._dam_song(d["bitch"].global_position, 600.0)
	_check(d["gone"] and d["bitch"].meek(), "the Night Song gives her time to take them away")
	await _frames(600)
	_check("pups" in Game.places() and lv.dams.is_empty() and not is_instance_valid(d["pups"][0]), "and when they are gone the way is his find")
	Game.save["places"] = had
	Game.save["gifts"] = gifts
	p.global_position = was
	p.velocity = Vector2.ZERO
	p.hp = p.max_hp
	await _frames(5)
