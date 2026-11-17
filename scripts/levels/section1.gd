extends "res://scripts/levels/level_base.gd"
## 1.1 The Pastures. Late afternoon. Learn to move, jump and use the staff
## while gathering the flock into the fold.


var fold_x := 7300.0      # where the fold stands, at the far end
var wild_ewe              # the one that only his call will bring
var thorn_ewe             # the one caught in the brake
var _far := 0.0           # the farthest he has come, for the goal
var restless_ewe          # Devorah: she will not stand until the lyre quiets her
var song_spot := {}


func _setup() -> void:
	flutters = 4
	leaves = Color(1.0, 0.86, 0.5, 0.55)
	ambience = "pastures"
	backdrop_art = "res://art/s1_backdrop.png"
	midground_art = "res://art/s1_mid.png"
	width = 7700.0
	pal.merge({
		"shafts": Color(1.0, 0.85, 0.5, 0.07), "mist": Color(1.0, 0.9, 0.7, 0.06),
		"sky_top": Color(0.2, 0.36, 0.6), "sky_mid": Color(0.96, 0.66, 0.4), "sky_bot": Color(1.0, 0.87, 0.58),
		"sun_pos": Vector2(0.74, 0.5), "sun_col": Color(1.0, 0.9, 0.65), "sun_size": 0.075,
		"far": Color(0.95, 0.68, 0.45), "near": Color(0.36, 0.26, 0.32), "rim": Color(1.0, 0.82, 0.5),
		"mote": Color(1.0, 0.9, 0.6, 0.5),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 13.0, 0.4)]
	checkpoints = [220.0, 2350.0, 4050.0, 5330.0, 6120.0]
	ledge(1040.0, 68.0, 130.0)
	ledge(1230.0, 136.0, 160.0)
	ledge(3150.0, 68.0, 120.0)
	ledge(3330.0, 136.0, 120.0)
	ledge(3510.0, 204.0, 170.0)
	ledge(1440.0, 204.0, 90.0)       # a step beyond the second ledge, for those who look up
	ledge(2020.0, 114.0, 120.0)      # too high for a boy: it needs the running leap he grows into
	# the old terraces beyond the meadow: three steps up
	ledge(5480.0, 68.0, 130.0)
	ledge(5660.0, 136.0, 130.0)
	ledge(5840.0, 204.0, 160.0)


func _populate() -> void:
	# a side cave: where shepherds pen a flock in bad weather. Embers at the mouth, a climb in the dark, and the back of it
	var c1 := add_cave(2900.0, [[1500.0, 0.0]], Color(1.75, 1.2, 0.72), "res://art/props/mouth_s1.png")
	add_embers(c1["x0"] + 300.0)
	add_perch(c1["x0"] + 620.0, 64.0, 150.0)
	var c1b := add_perch(c1["x0"] + 820.0, 128.0, 170.0)
	add_stone("s1_cave", c1b + Vector2(20, 0))
	add_sprite("res://art/props/bones.png", on_ground(c1["x0"] + 1290.0) + Vector2(0, 5), 0.07, 2, Color(0.6, 0.6, 0.7))
	add_light(on_ground(c1["x0"] + 1330.0) + Vector2(0, -60), 110.0)
	add_place("foldcave", on_ground(c1["x0"] + 1340.0), "The Fold Cave", "voice")
	for tx in [120.0, 860.0, 1560.0, 2600.0, 2760.0, 3020.0, 4420.0]:
		add_tree(tx, rng.randf_range(0.8, 1.3), rng.randf() < 0.4)

	add_sheep(700.0, null, true)      # the flock is nine: eight ewes and this year's lamb, in every section
	# one that will not stand: she paces under the olive and trots off from his hand. The lyre is what quiets her,
	# and the first place he has reason to take it up
	restless_ewe = add_sheep(905.0, null, false, "devorah")
	restless_ewe.restless = true
	song_spot = add_song(905.0, func() -> void: pass, 170.0)
	add_sheep(0.0, Vector2(1320.0, platforms[1].position.y))
	# two nervous ones in the meadow: they bolt from a running boy, and must be walked up to
	for nx in [1640.0, 1935.0]:
		var shy = add_sheep(nx)
		shy.skittish = true
	var ewe = add_sheep(2420.0)
	ewe.wild = true          # and one that no hand will reach: she is what the gift is for
	wild_ewe = ewe
	add_stone("s1_start", on_ground(46.0))                                    # behind where he begins
	add_stone("s1_step", Vector2(1485.0, platforms[5].position.y))
	add_stone("s1_leap", Vector2(2080.0, platforms[6].position.y))
	add_store("s1_store", 1760.0)     # hung in the olive by the steps: for when he has a sling
	add_sheep(0.0, Vector2(3600.0, platforms[4].position.y))

	add_jackal(4420.0, 4060.0, 4560.0)      # dusk brings the first of them down to the flock: the reason there is a shepherd
	add_bush(1800.0)
	add_bush(3950.0)

	if not Game.backdrop:
		add_hint(330.0, 150.0, "A D  move")
		add_hint(700.0, 120.0, "Walk to a sheep to gather it")
		add_hint(1000.0, 250.0, "Space  jump")
		add_hint(1690.0, 190.0, "J  staff")
		add_hint(fold_x, 210.0, "Bring the flock to the fold")
		add_hint(2080.0, 60.0, "Too high, for now")
		add_hint(2760.0, 150.0, "Tab  his growth")

	# the gift of this place: his voice. Two brought in by hand first; then the ewe that will not be caught
	add_gift("voice", 2180.0, func() -> bool: return sheep_count >= 4, "Bring in all four behind you.  The nervous ones will not stand for running")
	add_hint(1560.0, 150.0, "Shift  walk softly")
	_build_fold(fold_x)
	add_trigger(2500.0, 2700.0, func() -> void:
		Game.find_line("p23_shepherd")
		say(["ps23_1"]))
	add_trigger(fold_x - 80.0, fold_x + 100.0, _at_fold, false)
	_beyond_the_meadow()


func _build_fold(x: float) -> void:
	var at := on_ground(x)
	add_sprite("res://art/props/fold.png", at + Vector2(0, 14), 1.5, 1)
	add_glow(at + Vector2(190, -40), Color(1.0, 0.6, 0.25, 0.7), 240.0)


func begin() -> void:
	if is_instance_valid(Game.main) and Game.main.from_night:
		await say(["ps78_70"])      # the lambing night has already said who he is and where
		return
	await say(["n_s1_intro", "ps78_70"])


func _at_fold() -> void:
	if sheep_count < sheep_total:
		await say(["n_s1_missing"])
		return
	await say(["n_s1_to_well"])
	await line_here("p23_pastures")      # if the lyre never brought it to him out on the hill, it comes at the fold
	complete()


## The first time his playing settles them, the line of the psalm that is about exactly this comes to him.
func _on_song(_from: Vector2, settled: int) -> void:
	if settled <= 0 or Game.has_line("p23_pastures") or Game.backdrop:
		return
	if not Game.fast:
		await get_tree().create_timer(1.4).timeout
	if not done and not Game.cinematic and not respawning and is_instance_valid(player) and player.is_on_floor():
		line_here("p23_pastures")


## The longer way home. Past the meadow the ground is rougher: a brake of thorn where a ewe has caught herself,
## the old terraces where one has climbed after the last green, and then the open slope before the fold, where
## the jackals come down at dusk because that is when a flock is strung out and tired.
func _beyond_the_meadow() -> void:
	if Game.backdrop:
		return
	# the thorn brake: she went in after the shade and cannot get out. Cut a way to her, then free her
	for bx in [4780.0, 4900.0, 5130.0, 5240.0]:
		add_bush(bx)
	var caught = add_sheep(5015.0)
	caught.gatherable = false
	thorn_ewe = caught
	add_task(5015.0, "Free the ewe from the thorns", 1.2, func() -> void:
		caught.gatherable = true
		caught.hop = 1.0
		Game.sfx("sheep", -5.0, 0.1)
		show_tip("She is out.  Count her in with the rest"))
	add_hint(4700.0, 170.0, "A ewe is caught in the thorns ahead")
	add_beast("viper", 5460.0)      # an adder in the path past the thorn: the warm stones of a wall are where it lies
	# the terraces: one has climbed for the last of the green, and a smooth stone lies on the top step
	add_sheep(0.0, Vector2(5725.0, platforms[8].position.y))
	add_stone("s1_terrace", Vector2(5950.0, platforms[9].position.y))
	add_tree(5400.0, 1.1)
	add_tree(6050.0, 0.9, true)
	# dusk on the open slope: they come for the flock, not for him
	add_ambush(6250.0, 7000.0, [1, 2], func() -> void:
		Game.music("battle", 0.8)
		show_tip("Dusk.  They come for the flock: keep them off the sheep", 6.0), func() -> void:
		Game.music(mood, 2.5)
		show_tip("The slope is quiet.  The fold is just ahead"))


## What he is to do now, from where things stand. Polled, so it is right at any checkpoint too.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_far = maxf(_far, player.global_position.x)
	if is_instance_valid(restless_ewe) and restless_ewe.gathered:
		song_spot["on"] = false
	set_goal(_goal_now())


func _goal_now() -> String:
	if not ambush.is_empty() and not ambush["walls"].is_empty():
		return "Drive the jackals off the flock"
	if sheep_count >= sheep_total:
		return "Bring the flock to the fold, east"
	if sheep_count >= 4 and not Game.has("voice"):
		return "Stand in the shaft of light, east"
	if _far >= 4600.0 and is_instance_valid(thorn_ewe) and not thorn_ewe.gatherable and not thorn_ewe.gathered:
		return "Free the ewe from the thorns"
	if _far >= 2150.0 and Game.has("voice") and is_instance_valid(wild_ewe) and not wild_ewe.gathered:
		if player.global_position.x > wild_ewe.global_position.x + 500.0:
			return "Go back west and call the wild ewe (Q)"
		return "Call the wild ewe (Q)"
	if _far >= 780.0 and _far < 2150.0 and Game.has("lyre") and is_instance_valid(restless_ewe) and not restless_ewe.gathered and restless_ewe.calm <= 0.0:
		return "Quiet the restless ewe with the lyre (R)"
	return "Gather the nine sheep"
