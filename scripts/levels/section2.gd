extends "res://scripts/levels/level_base.gd"
## 1.2 The Lost Lamb. Dusk in the ravine. David finds his sling and uses it
## to drop log bridges across the wide gaps.

const BASE := 572.0

var ewe


func _setup() -> void:
	flutters = 3
	flutter_tint = Color(0.8, 0.78, 0.9)
	leaves = Color(0.75, 0.6, 0.5, 0.45)
	ambience = "dusk"
	backdrop_art = "res://art/s2_backdrop.png"
	midground_art = "res://art/s2_mid.png"
	mid_tint = Color(0.78, 0.72, 0.86)
	mood = "dusk"
	width = 5600.0
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
		make_ground(4040.0, width, BASE, 14.0, 1.5),
	]
	checkpoints = [150.0, 1100.0, 1920.0, 3210.0, 4120.0]
	ledge(2300.0, 68.0, 110.0)
	ledge(2470.0, 136.0, 110.0)


func _populate() -> void:
	# a side cave: a cistern cut in the rock. The back of it stands a man's height above the floor:
	# a fallen block, shoved to the foot of the step, is the way up. A jackal has made the place its own
	var c2 := add_cave(3420.0, [[820.0, 0.0], [640.0, 118.0]], Color(1.5, 1.0, 0.82))
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

	# wool and tracks at the foot of the ridge
	var end := on_ground(5380.0)
	add_glow(end + Vector2(0, -14), Color(1.0, 0.85, 0.7, 0.5), 180.0)
	add_painter(end, 4, func(ci: CanvasItem) -> void:
		for o in [Vector2(-30, -5), Vector2(-4, -7), Vector2(22, -4), Vector2(52, -6)]:
			ci.draw_circle(o, 5.0, pal["wool"])
			ci.draw_circle(o + Vector2(5, -3), 4.0, pal["wool"]))
	add_trigger(5330.0, 5480.0, _at_tracks)


## Three jars hung in one dead tree, each at a different height: a test of the sling.
## Break all three and a smooth stone falls from the branches.
func _trial() -> void:
	if "s2_trial" in Game.stones() or Game.backdrop:
		return
	var tree := Sprite2D.new()
	tree.texture = load("res://art/props/deadtree.png")
	tree.centered = false
	var sc := 0.78 / ART
	tree.scale = Vector2(sc, sc)
	var tip := 5120.0
	tree.position = Vector2(tip - tree.texture.get_width() * sc, BASE + 10.0 - tree.texture.get_height() * sc)
	tree.z_index = 1
	tree.modulate = pal.get("char", Color(1, 1, 1))
	add_child(tree)
	var branch := tree.position.y + tree.texture.get_height() * sc * 0.16
	var left := {"n": 3}
	for spot in [Vector2(tip - 8.0, BASE - 250.0), Vector2(tip - 84.0, BASE - 170.0), Vector2(tip - 160.0, BASE - 110.0)]:
		var t = Target.new()
		t.position = spot
		t.rope = spot.y - branch
		add_child(t)
		t.struck.connect(func() -> void:
			left["n"] -= 1
			if left["n"] == 0:
				Game.sfx("gather", -4.0, 0.0)
				add_stone("s2_trial", on_ground(tip - 84.0)))
	add_hint(4900.0, 250.0, "Three jars in the dead tree")


func _bridge(x0: float, x1: float, jar: Vector2) -> void:
	var drop := add_bridge(x0, x1, BASE)
	var t = Target.new()
	t.position = jar
	t.rope = jar.y - (BASE - 330.0)
	add_child(t)
	t.struck.connect(drop)
	# the dead tree the jar hangs from: its long branch ends right above the jar
	var tree := Sprite2D.new()
	tree.texture = load("res://art/props/deadtree.png")
	tree.centered = false
	var sc := 0.69 / ART
	tree.scale = Vector2(sc, sc)
	tree.position = Vector2(jar.x - tree.texture.get_width() * sc, BASE + 10.0 - tree.texture.get_height() * sc)
	tree.z_index = 1
	tree.modulate = pal.get("char", Color(1, 1, 1))
	add_child(tree)
	t.rope = jar.y - (tree.position.y + tree.texture.get_height() * sc * 0.16)


func begin() -> void:
	if not Game.main.intro.has_story("count"):      # the film before this section speaks the line itself
		await say(["n_s2_intro"])


func _at_tracks() -> void:
	await say(["n_s2_tracks"])
	complete()
