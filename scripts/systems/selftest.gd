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
			"section2": await _s2(lv)
			"wadi": await _wadi(lv)
			"den": await _den(lv)
			"section3": await _s3(lv)
			"watch": await _watch(lv)
			"section4": await _s4(lv)
		await _frames(10)
		_check(m.level.done, "section completes")
	await _beasts(m)
	var missing := 0
	for i in Game.sections().size():
		if not m.map.data.get("places", {}).has(m.map._key(i)):
			missing += 1
	_check(not m.map.data.is_empty() and missing == 0, "every section has its place on the map")
	m.map.open(true, 2)
	var q: Vector2 = m.map._at(31.7054, 35.2024)
	var q2: Vector2 = m.map._spot(2)
	_check(q.x > 0.0 and q.x < q2.x and q.y > 0.0 and q.y < q2.y, "Bethlehem falls north-west of the ravine on the map")
	m.map.close()
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
	Game.save["lang"] = "pt"
	_check(Game.t("The Well") == "O Poço" and str(Game.line("ps23_1")["text"]).begins_with("O SENHOR"), "Portuguese is shown when it is chosen")
	Game.save["lang"] = "en"
	_old_save()
	print("SMOKE %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	tree.quit(0 if failures == 0 else 1)


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
	var again: Dictionary = Game.save.duplicate(true)
	again["psalm"] = ["p23_waters"]
	again["flock"][2]["at"] = "section1"
	Game.take_save(again.duplicate(true))
	_check(Game.psalm() == ["p23_waters"] and str(Game.flock()[2]["at"]) == "section1" and Game.save["gifts"].count("lyre") == 1, "a save that already has them is left as it is")
	Game.take_save({"section": 3, "flock": "nine", "psalm": 4})
	_check(Game.flock().size() == 9 and Game.psalm() is Array, "a spoiled flock or psalm in the file is made good")
	Game.save = kept


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
	_check(landed == 2, "letting go at the top of the breath lands a phrase (%d of the first two)" % landed)
	_check(ewe.calm > 0.0 or was_gathered, "three phrases settle the sheep that hear them")
	_check(Game.has_line("p23_pastures"), "and the line of the psalm comes to him there")
	await _frames(150)
	_check(p.act == "" and p.lyre_t == 0.0, "he gets up when he stops playing")
	Input.action_press("lyre")
	await _frames(20)
	Input.action_release("lyre")
	await _frames(3)
	_check(p.phrases == 0 and p.lyre_flash < 0.0, "let go too soon, the phrase does not land")
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
	_check(told == 8, "each place off the path has its story in both languages (%d)" % told)
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
	lv.do_task(lv.lever_task)
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
	_check(lv.own[0]["state"] == "mixed", "his sheep have run in among the other flocks")
	lv.shepherd_call(lv.on_ground(2560.0), 600.0, false)
	_check(lv.own[0]["state"] == "led" and lv.others[0]["state"] == "idle", "his own come to his voice; the others do not")
	await _goto(2100.0)
	var stolen := false
	for k in 900:
		if lv.watered:
			break
		if lv.draw_task["on"] and lv.drinks[0] <= 0:
			lv.do_task(lv.draw_task)
			lv.do_task(lv.pour_tasks[0])
		for o in lv.others:
			if o["state"] == "drinking":
				stolen = true
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
		await _frames(2)
	_check(lv.watered, "every one of his flock has drunk")
	print("  other men's sheep reached the water unchecked: %s" % stolen)
	_check(lv.own[lv.LAMB]["state"] == "gone", "the lamb slips away while he deals with the jackal")
	lv.do_task(lv.back_task)
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
	lv.do_task(lv.tasks[0])
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
			lv.do_task(lv.fire_task)
		if lv.rest_task["on"]:
			lv.do_task(lv.rest_task)
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
	lv.do_task(lv.tend_task)
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
	lv.do_task(lv.lay_task)
	await _frames(5)
	_check(not lv.carrying and lv.lamb.visible and lv.player.act == "", "he lays it in the cleft and his hands are free")
	for k in 12:
		await _frames(8)
		for n in tree.get_nodes_in_group("enemies"):
			n.hit(9, 1, "staff")
	_check(lv._pack_left() == 0 and lv._goal_now() == "Lift the lamb", "the jackals are driven off the path")
	await _goto(lv.CLEFT_X)
	lv.do_task(lv.lift_task)
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
	lv.do_task(lv.lift_task)
	await _frames(5)
	_check(lv.player.act == "carry" and lv.carrying, "he lifts it and carries it")
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(240)
	Input.action_release("jump")
	_check(lv.player.position.x < lv.WASH_X0 and lv.player.position.y < 600.0, "with the lamb he cannot leap the washout, and does not walk into it")
	lv.do_task(lv.bridge_task)
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
		for lg in ["en", "pt"]:
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
	lv.do_task(lv.lever_task)
	lv.shepherd_call(lv.on_ground(2560.0), 600.0, false)
	lv.do_task(lv.draw_task)
	lv.fulcrum["body"].position.x = 2233.0
	await _goto(2200.0)
	await _frames(40)
	await _snap(dir, "well_2b_bucket")
	await _goto(1960.0)
	lv.do_task(lv.pour_tasks[0])
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


func _snap(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


# ---- real-flow check: narration, pause, section change, chapter end ----

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

	m.start_section(Game.sections().size() - 1)
	await _wait(7.0)
	await _skip_story(15.0)
	await _goto(m.level.SAMUEL_X - 50.0)
	await _wait(1.0)
	if snap:
		await _wait(2.0)
		await _snap(dir, "anointing")
	var t := 0.0
	while t < 60.0 and m.state != "menu":
		await _press("accept")
		await _wait(0.3)
		t += 0.35
	_check(m.state == "menu", "chapter ends and returns to the menu")
	_check(Game.save["finished"] == true, "chapter marked finished")
	print("FLOW %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	tree.quit(0 if failures == 0 else 1)
