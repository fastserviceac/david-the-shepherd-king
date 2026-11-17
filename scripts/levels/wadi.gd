extends "res://scripts/levels/level_base.gd"
## 1.4 The Wadi. Twilight. The tracks climb a dry riverbed in steps. Boulders left perched by the winter floods
## come down to a sling stone: as a step, as a plug in a gap, or onto whatever waits underneath.

var shelf: Rect2
var b1                    # the boulders, in the order they stand
var b2
var b3
var b4
var b5
var jars := {"n": 0}      # jars still hanging in the dead acacia
var _far := 0.0           # the farthest he has come, for the goal
var end_x := 7660.0       # the bear's cave, at the head of the wadi


func _setup() -> void:
	birds = false
	leaves = Color(0.7, 0.6, 0.7, 0.3)
	ambience = "dusk"
	mood = "theme_uneasy"
	backdrop_art = "res://art/wadi_backdrop.png"
	midground_art = "res://art/wadi_mid.png"
	mid_tint = Color(0.72, 0.7, 0.9)
	width = 7900.0
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
		make_ground(4000.0, 5700.0, 390.0, 6.0, 0.9),
		make_ground(5930.0, width, 390.0, 6.0, 1.9),       # the upper wadi, beyond the last break in the bed
	]
	checkpoints = [150.0, 1420.0, 2880.0, 4120.0, 6000.0, 6700.0]
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
	platforms.append(Rect2(5600.0, 232.0, 100.0, 24.0))      # perches in the upper wadi
	platforms.append(Rect2(6390.0, 232.0, 100.0, 24.0))
	Game.save["has_sling"] = true


func _populate() -> void:
	# a side cave: a refuge. Its inner floor is too high to climb; a boulder on its lip, brought down
	# with the sling, makes the step
	var c3 := add_cave(3120.0, [[760.0, 0.0], [700.0, 150.0]], Color(0.6, 0.55, 0.72), "res://art/props/mouth_wadi_hf.png")
	add_embers(c3["x0"] + 280.0)
	var step_at: float = c3["floors"][1] - 80.0
	add_boulder(Vector2(c3["floors"][1] + 34.0, c3["base"] - 150.0), Rect2(step_at, c3["base"] - 72.0, 76.0, 72.0))      # it sits on the lip of the inner floor
	add_light(Vector2(c3["floors"][1] + 34.0, c3["base"] - 190.0), 120.0)
	var jar := "res://art/props/jar.png"
	add_sprite(jar, on_ground(c3["floors"][1] + 420.0) + Vector2(0, 4), 0.3, 1, Color(0.7, 0.7, 0.8))
	add_sprite(jar, on_ground(c3["floors"][1] + 452.0) + Vector2(0, 4), 0.24, 1, Color(0.7, 0.7, 0.8))
	add_sprite(jar, on_ground(c3["floors"][1] + 560.0) + Vector2(0, 4), 0.27, 1, Color(0.7, 0.7, 0.8)).flip_h = true
	add_embers(c3["floors"][1] + 500.0)
	add_stone("wadi_refuge", on_ground(c3["floors"][1] + 640.0))
	add_place("refuge", on_ground(c3["floors"][1] + 380.0), "The Refuge", "heart")
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
	b1 = add_boulder(Vector2(1185.0, 400.0), Rect2(1232.0, 555.0, 72.0, 55.0))
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
	b2 = add_boulder(Vector2(2478.0, 312.0), Rect2(2466.0, 445.0, 72.0, 55.0))

	# the gap: a slab perched over it comes down as a bridge
	b3 = add_boulder(Vector2(2548.0, 340.0), Rect2(2596.0, 498.0, 188.0, 60.0))
	add_hint(2470.0, 250.0, "Look up")

	add_jackal(3300.0, 3000.0, 3720.0)
	# last step: the boulder sits high. Throw high
	b4 = add_boulder(Vector2(3882.0, 262.0), Rect2(3934.0, 445.0, 72.0, 55.0))
	b4.gate = "eye"          # the way on asks for the gift given just below it
	# the gift of this place: the sure eye. Every boulder below brought down, the one over the jackals too
	jars = {"n": 3}
	if not Game.has("eye") and not Game.backdrop:
		var tip := 3740.0      # a dead acacia, and three jars hung in it at three heights: a marksman's test
		var gy := on_ground(3600.0).y
		var tree := add_bough_tree(tip, gy)
		for spot in [Vector2(tip - 34.0, gy - 250.0), Vector2(tip - 100.0, gy - 170.0), Vector2(tip - 166.0, gy - 110.0)]:
			var tg = hang_jar(tree, spot)
			tg.struck.connect(func() -> void: jars["n"] -= 1)
	else:
		jars["n"] = 0
	add_gift("eye", 3810.0, func() -> bool: return jars["n"] <= 0 and b1.fallen and b2.fallen and b3.fallen, "Three jars hang in the dead tree, and every boulder below must be down")

	add_trigger(4660.0, 4780.0, func() -> void: say(["n_wadi_wool"]))
	_upper_wadi()
	# the bear's cave: a great broken outcrop painted for this dusk, its mouth black and tall enough for what lives in it
	var mouth := on_ground(end_x + 20.0)
	var den_mouth := add_sprite("res://art/props/mouth_s2.png", mouth + Vector2(0, 16), 1.0, 1, Color(0.74, 0.76, 1.0))
	den_mouth.scale = Vector2.ONE * (600.0 / den_mouth.texture.get_width())
	add_bones_at(mouth + Vector2(-150.0, 6.0))
	add_trigger(end_x - 70.0, end_x + 80.0, _at_cave)


func begin() -> void:
	if not Game.main.intro.has_story("wadi"):      # the film before this section speaks the line itself
		await say(["n_wadi_intro"])


func _at_cave() -> void:
	await say(["n_wadi_cave"])
	complete()


## The upper wadi. The bed breaks once more; beyond it the tracks part company, jackals wait under a perched
## boulder, and where the walls close in a pack that has been following the same trail turns on him.
func _upper_wadi() -> void:
	if Game.backdrop:
		return
	# where the trail runs under the ledges a leopard lies above it: a flock being brought up the wadi is the prey it waits for
	add_beast("leopard", 5240.0, {"perches": [[5240.0, 130.0, 150.0], [5460.0, 150.0, 150.0]]})
	# the last break: a slab the floods left on a perch comes down across it
	b5 = add_boulder(Vector2(5650.0, 232.0), Rect2(5716.0, 388.0, 200.0, 60.0))
	add_hint(5560.0, 230.0, "The bed is broken ahead.  Look up")
	# where the trails part: he must read the ground to know which is the lamb's
	add_tracks(5980.0, 6200.0, true)
	add_tracks(6000.0, 6160.0, false)
	add_wool(6110.0)
	add_task(6090.0, "Kneel and read the ground", 1.3, func() -> void:
		show_tip("The small prints stop.  From here the lamb was carried: only the broad pads go on", 6.5))
	# two jackals on the trail, and a boulder on the perch over them
	add_jackal(6390.0, 6280.0, 6620.0)
	add_jackal(6520.0, 6280.0, 6620.0)
	add_boulder(Vector2(6408.0, 232.0), Rect2(6306.0, 335.0, 72.0, 55.0))
	# the walls close in. The pack has been following the same scent
	add_ambush(6760.0, 7440.0, [2, 3], func() -> void:
		Game.music("battle", 0.8)
		show_tip("The walls close in.  They were after the same lamb", 5.5), func() -> void:
		Game.music(mood, 2.5)
		show_tip("Ahead, the rock opens.  The broad tracks go straight in"))
	add_tracks(7460.0, end_x - 60.0, true)


## What he is to do now, from where things stand. Polled, so it is right at any checkpoint too.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_far = maxf(_far, player.global_position.x)
	set_goal(_goal_now())


func _goal_now() -> String:
	var f := _far
	if not ambush.is_empty():
		if ambush["cleared"]:
			return "Go into the bear's cave, east"
		if not ambush["walls"].is_empty():
			return "Drive off the pack in the narrow wadi"
	if f < 1232.0:
		if f > 900.0 and is_instance_valid(b1) and not b1.fallen:
			return "Bring the boulder down for a step"
		return "Follow the tracks up the wadi, east"
	if f < 2200.0:
		return "Follow the broad tracks, not the small ones"
	if f < 2790.0:
		if is_instance_valid(b2) and not b2.fallen:
			return "Drop the boulder on the jackals below"
		if is_instance_valid(b3) and not b3.fallen:
			return "Sling the slab down to bridge the gap"
		return "Follow the broad tracks, east"
	if f < 4000.0:
		if not Game.has("eye"):
			if jars["n"] > 0:
				return "Break the three jars in the dead tree"
			if not (b1.fallen and b2.fallen and b3.fallen):
				return "Bring down every boulder you passed, back west"
			return "Step into the light under the dead tree"
		if is_instance_valid(b4) and not b4.fallen:
			return "Sling the high boulder down for a step"
		return "Follow the broad tracks, east"
	if f < 5500.0:
		return "Follow the broad tracks up the wadi, east"
	if f < 5930.0:
		if is_instance_valid(b5) and not b5.fallen:
			return "Sling the slab down to bridge the break"
		return "Follow the broad tracks, east"
	return "Follow the broad tracks to the cave, east"
