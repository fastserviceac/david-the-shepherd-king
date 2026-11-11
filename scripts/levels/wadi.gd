extends "res://scripts/levels/level_base.gd"
## 1.4 The Wadi. Twilight. The tracks climb a dry riverbed in steps. Boulders left perched by the winter floods
## come down to a sling stone: as a step, as a plug in a gap, or onto whatever waits underneath.

var shelf: Rect2


func _setup() -> void:
	birds = false
	leaves = Color(0.7, 0.6, 0.7, 0.3)
	ambience = "dusk"
	mood = "theme_uneasy"
	backdrop_art = "res://art/wadi_backdrop.png"
	midground_art = "res://art/wadi_mid.png"
	mid_tint = Color(0.72, 0.7, 0.9)
	width = 5600.0
	pal.merge({
		"mist": Color(0.7, 0.6, 0.95, 0.08),
		"grass": Color(0.6, 0.52, 0.74), "ground": Color(0.5, 0.45, 0.62), "char": Color(0.78, 0.7, 0.9),
		"sky_top": Color(0.1, 0.1, 0.3), "sky_mid": Color(0.4, 0.25, 0.5), "sky_bot": Color(0.95, 0.55, 0.4),
		"sun_pos": Vector2(0.4, 0.8), "sun_col": Color(1.0, 0.6, 0.4), "sun_size": 0.06, "stars": 0.7,
		"far": Color(0.55, 0.4, 0.55), "near": Color(0.16, 0.13, 0.26), "rim": Color(0.95, 0.7, 0.6),
		"wool": Color(0.88, 0.82, 0.9), "mote": Color(0.85, 0.8, 1.0, 0.4),
	}, true)
	segments = [
		make_ground(0.0, 1310.0, 610.0, 7.0, 0.3),
		make_ground(1300.0, 2600.0, 500.0, 7.0, 1.4),
		make_ground(2780.0, 4010.0, 500.0, 7.0, 2.2),
		make_ground(4000.0, width, 390.0, 6.0, 0.9),
	]
	checkpoints = [150.0, 1420.0, 2880.0, 4120.0]
	# perches the floods left, too high to climb to
	platforms.append(Rect2(1110.0, 400.0, 110.0, 24.0))
	platforms.append(Rect2(2500.0, 340.0, 90.0, 24.0))
	platforms.append(Rect2(3830.0, 262.0, 100.0, 24.0))
	# the false trail: steps up to a shelf above the riverbed
	ledge(1760.0, 62.0, 110.0)
	ledge(1900.0, 124.0, 110.0)
	shelf = Rect2(2040.0, 312.0, 420.0, 28.0)
	platforms.append(shelf)
	ledge(4480.0, 114.0, 120.0)        # needs the running leap
	Game.save["has_sling"] = true


func _populate() -> void:
	# off the path: beyond the leap, the bare crag where the wild goats go
	var crag := add_perch(4650.0, 182.0, 220.0)
	add_place("crag", crag, "The Goats' Crag", "feet")
	add_stone("wadi_start", on_ground(46.0))
	add_stone("wadi_shelf", Vector2(2420.0, shelf.position.y))
	add_stone("wadi_leap", Vector2(4540.0, platforms[6].position.y))

	# the true trail: broad pads and wool. The false one: many small feet, going up the rocks
	add_tracks(260.0, 1180.0, true)
	add_tracks(1380.0, 1660.0, true)
	add_tracks(1640.0, 1770.0, false)
	add_tracks(1700.0, 2560.0, true)
	add_tracks(2840.0, 3900.0, true)
	add_tracks(4100.0, 5300.0, true)
	add_wool(900.0)
	add_wool(2240.0)
	add_wool(3520.0)
	add_wool(4720.0, 34.0)

	# first step: a boulder for a stair
	var b1 = add_boulder(Vector2(1185.0, 400.0), Rect2(1232.0, 555.0, 72.0, 55.0))
	add_hint(1040.0, 190.0, "K  bring the boulder down")
	add_trigger(820.0, 960.0, func() -> void: say(["n_wadi_boulder"]))

	# the fork
	add_trigger(1540.0, 1660.0, func() -> void: say(["n_wadi_fork"]))
	add_trigger(2100.0, 2200.0, func() -> void:
		if player.global_position.y < shelf.position.y + 10.0:
			say(["n_wadi_false"]), false)
	# under the shelf a pair of jackals hold the riverbed; over them, on the shelf's lip, a boulder
	add_jackal(2380.0, 2250.0, 2580.0)
	add_jackal(2500.0, 2250.0, 2580.0)
	var b2 = add_boulder(Vector2(2478.0, 312.0), Rect2(2466.0, 445.0, 72.0, 55.0))

	# the gap: a slab perched over it comes down as a bridge
	var b3 = add_boulder(Vector2(2548.0, 340.0), Rect2(2596.0, 498.0, 188.0, 60.0))
	add_hint(2470.0, 250.0, "Look up")

	add_jackal(3300.0, 3000.0, 3720.0)
	# last step: the boulder sits high. Throw high
	var b4 = add_boulder(Vector2(3882.0, 262.0), Rect2(3934.0, 445.0, 72.0, 55.0))
	b4.gate = "eye"          # the way on asks for the gift given just below it
	# the gift of this place: the sure eye. Every boulder below brought down, the one over the jackals too
	add_gift("eye", 3560.0, func() -> bool: return b1.fallen and b2.fallen and b3.fallen, "One boulder is still perched, back down the wadi")

	add_trigger(4660.0, 4780.0, func() -> void: say(["n_wadi_wool"]))
	# the cave mouth
	# the cave mouth: an arch of rock with the dark behind it
	var mouth := on_ground(5400.0)
	add_painter(mouth, 0, func(ci: CanvasItem) -> void:
		for k in 6:          # darkness deepening toward the middle of the opening
			var f := 1.0 - k / 6.0
			var pts := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				pts.append(Vector2(-12.0 + cos(a) * 150.0 * f, -92.0 + sin(a) * 96.0 * f))
			ci.draw_colored_polygon(pts, Color(0.01, 0.01, 0.03, 0.55)))
	var arch := add_sprite("res://art/props/cave_arch.png", mouth + Vector2(0, 14), 1.0, 1, Color(0.6, 0.55, 0.72))      # pulled toward the wadi's dusk rock, so it belongs to this place
	arch.scale = Vector2(0.86, 0.86)
	add_trigger(5330.0, 5480.0, _at_cave)


func begin() -> void:
	if not Game.main.intro.has_story("wadi"):      # the film before this section speaks the line itself
		await say(["n_wadi_intro"])


func _at_cave() -> void:
	await say(["n_wadi_cave"])
	complete()
