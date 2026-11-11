extends "res://scripts/levels/level_base.gd"
## 1.1 The Pastures. Late afternoon. Learn to move, jump and use the staff
## while gathering the flock into the fold.


func _setup() -> void:
	flutters = 4
	leaves = Color(1.0, 0.86, 0.5, 0.55)
	ambience = "pastures"
	backdrop_art = "res://art/s1_backdrop.png"
	midground_art = "res://art/s1_mid.png"
	width = 5200.0
	pal.merge({
		"shafts": Color(1.0, 0.85, 0.5, 0.07), "mist": Color(1.0, 0.9, 0.7, 0.06),
		"sky_top": Color(0.2, 0.36, 0.6), "sky_mid": Color(0.96, 0.66, 0.4), "sky_bot": Color(1.0, 0.87, 0.58),
		"sun_pos": Vector2(0.74, 0.5), "sun_col": Color(1.0, 0.9, 0.65), "sun_size": 0.075,
		"far": Color(0.95, 0.68, 0.45), "near": Color(0.36, 0.26, 0.32), "rim": Color(1.0, 0.82, 0.5),
		"mote": Color(1.0, 0.9, 0.6, 0.5),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 13.0, 0.4)]
	checkpoints = [220.0, 2350.0, 4050.0]
	ledge(1040.0, 68.0, 130.0)
	ledge(1230.0, 136.0, 160.0)
	ledge(3150.0, 68.0, 120.0)
	ledge(3330.0, 136.0, 120.0)
	ledge(3510.0, 204.0, 170.0)
	ledge(1440.0, 204.0, 90.0)       # a step beyond the second ledge, for those who look up
	ledge(2020.0, 114.0, 120.0)      # too high for a boy: it needs the running leap he grows into


func _populate() -> void:
	# a side cave: where shepherds pen a flock in bad weather. Embers at the mouth, a climb in the dark, and the back of it
	var c1 := add_cave(2900.0, [[1500.0, 0.0]], Color(1.75, 1.2, 0.72))
	add_embers(c1["x0"] + 300.0)
	add_perch(c1["x0"] + 620.0, 64.0, 150.0)
	var c1b := add_perch(c1["x0"] + 820.0, 128.0, 170.0)
	add_stone("s1_cave", c1b + Vector2(20, 0))
	add_sprite("res://art/props/bones.png", on_ground(c1["x0"] + 1290.0) + Vector2(0, 5), 0.07, 2, Color(0.6, 0.6, 0.7))
	add_light(on_ground(c1["x0"] + 1330.0) + Vector2(0, -60), 110.0)
	add_place("foldcave", on_ground(c1["x0"] + 1340.0), "The Fold Cave", "voice")
	for tx in [120.0, 860.0, 1560.0, 2600.0, 2760.0, 3020.0, 4420.0]:
		add_tree(tx, rng.randf_range(0.8, 1.3), rng.randf() < 0.4)

	add_sheep(700.0)
	add_sheep(0.0, Vector2(1320.0, platforms[1].position.y))
	# two nervous ones in the meadow: they bolt from a running boy, and must be walked up to
	for nx in [1640.0, 1935.0]:
		var shy = add_sheep(nx)
		shy.skittish = true
	var ewe = add_sheep(2420.0)
	ewe.wild = true          # and one that no hand will reach: she is what the gift is for
	add_stone("s1_start", on_ground(46.0))                                    # behind where he begins
	add_stone("s1_step", Vector2(1485.0, platforms[5].position.y))
	add_stone("s1_leap", Vector2(2080.0, platforms[6].position.y))
	add_sheep(0.0, Vector2(3600.0, platforms[4].position.y))
	add_sheep(4280.0)

	add_bush(1800.0)
	add_bush(3950.0)

	if not Game.backdrop:
		add_hint(330.0, 150.0, "A D  move")
		add_hint(700.0, 120.0, "Walk to a sheep to gather it")
		add_hint(1000.0, 250.0, "Space  jump")
		add_hint(1690.0, 190.0, "J  staff")
		add_hint(4800.0, 210.0, "Bring the flock to the fold")
		add_hint(2080.0, 60.0, "Too high, for now")
		add_hint(2760.0, 150.0, "Tab  his growth")

	# the gift of this place: his voice. Two brought in by hand first; then the ewe that will not be caught
	add_gift("voice", 2180.0, func() -> bool: return sheep_count >= 4, "Bring in all four behind you.  The nervous ones will not stand for running")
	add_hint(1560.0, 150.0, "Shift  walk softly")
	_build_fold(4800.0)
	add_trigger(2500.0, 2700.0, func() -> void: say(["ps23_1"]))
	add_trigger(4720.0, 4900.0, _at_fold, false)


func _build_fold(x: float) -> void:
	var at := on_ground(x)
	add_sprite("res://art/props/fold.png", at + Vector2(0, 14), 1.5, 1)
	add_glow(at + Vector2(190, -40), Color(1.0, 0.6, 0.25, 0.7), 240.0)


func begin() -> void:
	await say(["n_s1_intro", "ps78_70"])


func _at_fold() -> void:
	if sheep_count < sheep_total:
		await say(["n_s1_missing"])
		return
	await say(["n_s1_to_well"])
	complete()
