extends "res://scripts/levels/level_base.gd"
## 1.2 The Lost Lamb. Dusk in the ravine. David finds his sling and uses it
## to drop log bridges across the wide gaps.

const BASE := 572.0

var ewe
var end_x := 7780.0       # the foot of the ridge, where the tracks are


func _setup() -> void:
	flutters = 3
	flutter_tint = Color(0.8, 0.78, 0.9)
	leaves = Color(0.75, 0.6, 0.5, 0.45)
	ambience = "dusk"
	backdrop_art = "res://art/s2_backdrop.png"
	midground_art = "res://art/s2_mid.png"
	mid_tint = Color(0.78, 0.72, 0.86)
	mood = "dusk"
	width = 8000.0
	pal.merge({
		"mist": Color(0.8, 0.6, 0.95, 0.09),
		"grass": Color(0.72, 0.52, 0.72), "ground": Color(0.5, 0.42, 0.6), "char": Color(0.86, 0.72, 0.84),
		"sky_top": Color(0.12, 0.1, 0.3), "sky_mid": Color(0.55, 0.25, 0.45), "sky_bot": Color(0.98, 0.55, 0.4),
		"sun_pos": Vector2(0.3, 0.74), "sun_col": Color(1.0, 0.6, 0.4), "sun_size": 0.09, "stars": 0.5,
		"far": Color(0.72, 0.36, 0.45), "near": Color(0.2, 0.13, 0.27), "rim": Color(1.0, 0.62, 0.5),
		"wool": Color(0.9, 0.8, 0.82), "mote": Color(0.85, 1.0, 0.5, 0.75),
	}, true)
	segments = [
		make_ground(0.0, 640.0, BASE, 10.0, 0.2),
		make_ground(770.0, 1500.0, BASE, 12.0, 1.1),
		make_ground(1840.0, 3000.0, BASE, 14.0, 2.0),
		make_ground(3130.0, 3700.0, BASE, 10.0, 0.7),
		make_ground(4040.0, 5560.0, BASE, 14.0, 1.5),
		make_ground(5820.0, 6900.0, BASE, 12.0, 0.4),      # the upper ravine: a fork, and a false trail
		make_ground(7050.0, width, BASE, 10.0, 2.6),
	]
	checkpoints = [150.0, 1100.0, 1920.0, 3210.0, 4120.0, 5900.0, 7130.0]
	ledge(2300.0, 68.0, 110.0)
	ledge(2470.0, 136.0, 110.0)
	# the false trail: three steps up the side of the ravine
	ledge(6160.0, 68.0, 120.0)
	ledge(6330.0, 136.0, 120.0)
	ledge(6500.0, 204.0, 150.0)


func _populate() -> void:
	# a side cave: a cistern cut in the rock. The back of it stands a man's height above the floor:
	# a fallen block, shoved to the foot of the step, is the way up. A jackal has made the place its own
	var c2 := add_cave(3420.0, [[820.0, 0.0], [640.0, 118.0]], Color(1.5, 1.0, 0.82), "res://art/props/mouth_s2.png")
	add_embers(c2["x0"] + 290.0)
	add_pushable(c2["x0"] + 470.0, 58.0, 50.0, "res://art/props/rock_low.png", c2["x0"] + 400.0, c2["floors"][1] - 32.0)
	add_jackal(c2["x0"] + 640.0, c2["x0"] + 380.0, c2["floors"][1] - 80.0)
	add_sprite("res://art/props/well.png", on_ground(c2["floors"][1] + 380.0) + Vector2(0, 8), 0.3, 1, Color(0.6, 0.6, 0.72))
	add_light(on_ground(c2["floors"][1] + 380.0) + Vector2(0, -50), 130.0)
	add_stone("s2_cistern", on_ground(c2["floors"][1] + 560.0))
	add_place("cistern", on_ground(c2["floors"][1] + 300.0), "The Hewn Cistern", "heart")
	for tx in [300.0, 900.0, 2250.0, 2700.0, 3400.0, 4500.0, 5150.0]:
		add_tree(tx, rng.randf_range(0.8, 1.4), rng.randf() < 0.6)


	# the gift of this place: the sling, by the brook. A jackal has the bank; it must be driven off first
	if not Game.has("sling"):
		var keepers: Array = [add_jackal(980.0, 800.0, 1460.0), add_jackal(1180.0, 800.0, 1460.0), add_jackal(1360.0, 800.0, 1460.0)]
		add_gift("sling", 1250.0, func() -> bool:
			for k in keepers:
				if is_instance_valid(k) and not k.fleeing:
					return false
			return true, "A pack holds the brook.  Drive off all three")
		Game.gifted.connect(func(id: String) -> void:
			if id == "sling" and is_inside_tree():
				say(["n_s2_sling"]))
	add_hint(1400.0, 200.0, "Break the hanging jar")

	_bridge(1500.0, 1840.0, Vector2(1680.0, BASE - 92.0))
	_bridge(3700.0, 4040.0, Vector2(3880.0, BASE - 215.0))
	add_hint(3590.0, 230.0, "↑  aim high")

	# the thorn brake: a strayed ewe, and a pack that has found her first
	ewe = add_sheep(2640.0)
	ewe.gatherable = false
	add_stone("s2_brake", Vector2(2525.0, platforms[1].position.y))
	add_leap("s2_leap", 2080.0)      # for when he comes back with swift feet
	add_ambush(2080.0, 2960.0, [2, 3, 3], func() -> void:
		Game.music("battle", 0.8)
		await say(["n_s2_ewe"]), func() -> void:
		Game.music(mood, 2.5)
		ewe.gatherable = true
		add_glow(ewe.position + Vector2(0, -16), Color(1.0, 0.9, 0.7, 0.5), 180.0)
		say(["n_s2_ewe_safe"]))
	_trial()
	add_jackal(3450.0, 3300.0, 3660.0)
	add_jackal(4600.0, 4300.0, 4950.0)

	add_trigger(2000.0, 2120.0, func() -> void: say(["ps23_4"]))

	_upper_ravine()

	# wool and tracks at the foot of the ridge
	var end := on_ground(end_x)
	add_glow(end + Vector2(0, -14), Color(1.0, 0.85, 0.7, 0.5), 180.0)
	add_painter(end, 4, func(ci: CanvasItem) -> void:
		for o in [Vector2(-30, -5), Vector2(-4, -7), Vector2(22, -4), Vector2(52, -6)]:
			ci.draw_circle(o, 5.0, pal["wool"])
			ci.draw_circle(o + Vector2(5, -3), 4.0, pal["wool"]))
	add_trigger(end_x - 50.0, end_x + 100.0, _at_tracks)


## Three jars hung in one dead tree, each at a different height: a test of the sling.
## Break all three and a smooth stone falls from the branches.
func _trial() -> void:
	if "s2_trial" in Game.stones() or Game.backdrop:
		return
	var tip := 5120.0
	var tree := add_bough_tree(tip, BASE)
	var left := {"n": 3}
	for spot in [Vector2(tip - 34.0, BASE - 250.0), Vector2(tip - 100.0, BASE - 170.0), Vector2(tip - 166.0, BASE - 110.0)]:
		var t = hang_jar(tree, spot)
		t.struck.connect(func() -> void:
			left["n"] -= 1
			if left["n"] == 0:
				Game.sfx("gather", -4.0, 0.0)
				add_stone("s2_trial", on_ground(tip - 84.0)))
	add_hint(4900.0, 250.0, "Three jars in the dead tree")


func _bridge(x0: float, x1: float, jar: Vector2) -> void:
	var drop := add_bridge(x0, x1, BASE)
	# the dead tree the jar hangs from: its long bough reaches out over the gap, and the rope is tied to it
	var tree := add_bough_tree(jar.x + 34.0, BASE, 0.69)
	var t = hang_jar(tree, jar)
	t.struck.connect(drop)


func begin() -> void:
	if not Game.main.intro.has_story("count"):      # the film before this section speaks the line itself
		await say(["n_s2_intro"])


func _at_tracks() -> void:
	await say(["n_s2_tracks"])
	complete()


## The upper ravine. The trial tree is not the end of it: beyond is a third gap, a fork where the wool leads the
## wrong way, a place to stand still and listen, and jackals that would rather have the ewe than him.
func _upper_ravine() -> void:
	if Game.backdrop:
		return
	_bridge(5560.0, 5820.0, Vector2(5690.0, BASE - 150.0))
	add_wool(5960.0)
	# he cannot see the lamb; he can hear it, if he stands still
	add_task(6040.0, "Stand still and listen", 1.4, func() -> void:
		Game.sfx("lamb", -13.0, 0.0)
		show_tip("A cry, thin and far off.  Not from the rocks above: from on up the ravine", 6.5))
	add_hint(6040.0, 150.0, "The wool goes two ways here")
	# the false trail: wool on every step, and nothing at the top but a stone and the wind
	add_wool(6215.0, 68.0 + 26.0)
	add_wool(6385.0, 136.0 + 26.0)
	add_stone("s2_false", Vector2(6600.0, platforms[4].position.y))
	add_trigger(6540.0, 6660.0, func() -> void:
		if player.global_position.y < platforms[4].position.y + 12.0:
			show_tip("Only wool.  The thorn combs every sheep that passes: this is an old trail", 6.0))
	# on the ravine floor two jackals keep pace with whatever comes through. They want the ewe
	add_jackal(6420.0, 6120.0, 6860.0)
	add_jackal(6700.0, 6120.0, 6860.0)
	add_tree(6950.0 - 140.0, 1.2, true)
	# beyond the last gap the ground is soft, and it has kept what crossed it
	add_tracks(7140.0, 7520.0)
	add_tracks(7400.0, 7740.0, true)
	add_wool(7300.0)
