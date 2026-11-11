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
	var missing := 0
	for i in Game.sections().size():
		if not m.map.data.get("places", {}).has(m.map._key(i)):
			missing += 1
	_check(not m.map.data.is_empty() and missing == 0, "every section has its place on the map")
	m.map.open(true, 2)
	var q: Vector2 = m.map._at(31.7054, 35.2024)
	_check(q.x > 300.0 and q.x < 600.0 and q.y > 60.0 and q.y < 200.0, "Bethlehem falls where it should on the map")
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
	print("SMOKE %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	tree.quit(0 if failures == 0 else 1)


func _s1(lv) -> void:
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
	_check(told == 3, "each place off the path has its story in both languages (%d)" % told)
	var kept: float = Game.craft_xp("hand")       # the player's own progress is put back afterwards
	Game.save["growth"] = Game.save.get("growth", {})
	Game.save["growth"]["hand"] = 0.0
	var before: int = Game.rank("hand")
	Game.grow("hand", 100000.0)
	_check(Game.rank("hand") == 3 and before == 0, "a craft grows with use")
	Game.save["growth"]["hand"] = kept
	await _goto(4800.0)
	_check(not lv.done, "fold stays shut while sheep are missing")
	await _goto(4500.0)
	for s in lv.get_children():
		if s.get("gatherable") != null and not s.gathered:
			lv.player.position = s.position
			lv.player.velocity = Vector2.ZERO
			await _frames(10)
	_check(lv.sheep_count == lv.sheep_total and lv.sheep_total == 5, "all five sheep gathered")
	for b in tree.get_nodes_in_group("hittable"):
		b.hit(1, 1, "staff")
		b.hit(1, 1, "staff")
	await _goto(4800.0)


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
	await _goto(5400.0)


func _index(script_name: String) -> int:
	for i in Game.sections().size():
		if str(Game.sections()[i]["script"]).get_file().get_basename() == script_name:
			return i
	return 0


## The Well: lever the stone, call his own out of the crowd, water them while other sheep steal, count them in.
func _well(lv) -> void:
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
	_check(lv.own[4]["state"] == "gone", "the lamb slips away while he deals with the jackal")
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
	_check(turned == 2 and lv.in_fold == 4, "two strangers turned back at the gate, four of his own counted in")


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
	_check(n_b == 4, "four perched boulders")
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
	await _goto(5400.0)


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
	await _goto(4900.0)
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
	await _goto(4940.0)


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
	for n in tree.get_nodes_in_group("enemies"):
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
	for stg in [1, 2, 3]:
		lv.lion.stage = stg
		lv.lion.hp = maxi(1, int(lv.lion.max_hp * (1.0 - 0.33 * (stg - 1))) - 1)
		lv.lion.state = "recover"
		lv.lion.st = 0.1
		for f in 4000:
			lv.player.invuln = 5.0
			lv.player.hp = lv.player.max_hp
			seen_lion[lv.lion.state] = true
			if f > 500 and (stg < 3 or seen_lion.has_all(["pounce", "lurk", "rush", "recover"])):
				break
			await _frames(1)
	print("  lion on its own went through: ", seen_lion.keys())
	for need in ["pounce", "lurk", "rush", "recover"]:
		_check(seen_lion.has(need), "the lion uses its " + need)
	lv.player.invuln = 0.0
	for k in lv.lion.max_hp:      # his health depends on the difficulty
		lv.lion.state = "recover"
		lv.lion.hit(1, 1, "test")
	await _frames(5)
	_check(lv.lamb.gatherable, "lamb can be rescued")
	await _goto(3950.0)


func _s4(lv) -> void:
	await _goto(940.0)
	await _frames(30)
	_check(not is_nan(lv.followers[0].stay), "the flock is left with the servant")
	await _goto(2000.0)
	await _frames(90)
	_check(absf(lv.followers[0].global_position.x - 1060.0) < 200.0, "the flock stays with the servant when David goes on")
	await _goto(3050.0)
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
	for name in ["section1", "well", "section2", "wadi", "den", "section3", "watch", "section4"]:
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
	await _goto(5250.0)
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
	await _goto(4800.0)
	await _wait(1.0)
	await _skip_story(20.0)
	await _wait(7.0)
	await _skip_story(15.0)
	_check(m.section_idx == 1 and m.state == "play", "finishing section 1 opens section 2")
	_check(int(Game.save["unlocked"]) >= 1, "progress is saved")

	m.start_section(Game.sections().size() - 1)
	await _wait(7.0)
	await _skip_story(15.0)
	await _goto(3050.0)
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
