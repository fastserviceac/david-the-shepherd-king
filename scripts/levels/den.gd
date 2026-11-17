extends "res://scripts/levels/level_base.gd"
## 1.5 The Bear's Den. A limestone cave, black inside. A torch gives a pool of light and keeps the lesser
## beasts at its edge, but it burns down, and a draught through the rock eats it faster. At the heart of the
## cave, under a shaft of moonlight, the bear.

const Bear = preload("res://scripts/enemies/bear.gd")
const BASE := 590.0
const EMBERS := [430.0, 1850.0, 3080.0]

var bear
var bear_started := false
var walls: Array = []
var lit_once := false
var _far := 0.0           # the farthest he has come, for the goal


var out_x := 8120.0       # where the cave lets him out, far beyond the bear's floor
var searched := false     # he has looked through the bear's larder
var step_rock: Dictionary = {}

const POOL_X := 6800.0    # water standing in the rock
const SHELF_X := 7850.0   # the shelf the tracks go up over
const SHELF_UP := 136.0


func _setup() -> void:
	birds = false
	barren = true
	ambience = "night"
	mood = "ridge"
	backdrop_art = "res://art/den_backdrop.png"
	midground_art = "res://art/den_mid.png"
	mid_tint = Color(0.6, 0.66, 0.9)
	width = 8300.0
	pal.merge({
		"mist": Color(0.5, 0.6, 0.9, 0.05),
		"grass": Color(0.3, 0.34, 0.5), "ground": Color(0.3, 0.33, 0.48), "char": Color(0.72, 0.74, 0.92),
		"sky_top": Color(0.01, 0.01, 0.03), "sky_mid": Color(0.02, 0.03, 0.07), "sky_bot": Color(0.04, 0.05, 0.1),
		"sun_pos": Vector2(0.6, 0.2), "sun_col": Color(0.7, 0.8, 1.0), "sun_size": 0.0, "stars": 0.0,
		"far": Color(0.1, 0.12, 0.2), "near": Color(0.04, 0.05, 0.1), "rim": Color(0.6, 0.7, 1.0),
		"wool": Color(0.8, 0.84, 0.95), "mote": Color(0.7, 0.8, 1.0, 0.25),
	}, true)
	segments = [
		make_ground(0.0, 2480.0, BASE, 6.0, 0.4),
		make_ground(2600.0, 2820.0, BASE, 3.0, 1.0),
		make_ground(2950.0, 5400.0, BASE, 6.0, 2.0),
		make_ground(5540.0, SHELF_X + 10.0, BASE, 5.0, 0.8),       # the back passages, past the bear's larder
		make_ground(SHELF_X, width, BASE - SHELF_UP, 4.0, 1.6),    # and the shelf of rock the way out goes up over
	]
	checkpoints = [140.0, 1850.0, 3080.0, 4580.0, 5620.0, 6660.0, 7560.0]
	ledge(1340.0, 62.0, 110.0)
	ledge(1480.0, 124.0, 120.0)
	# a climb in the back passage, to a pocket under the roof
	ledge(5760.0, 62.0, 110.0)
	ledge(5900.0, 124.0, 110.0)
	ledge(6040.0, 186.0, 150.0)
	torch_max = 46.0
	Game.save["has_sling"] = true


func _populate() -> void:
	set_dark(0.95)
	add_light(Vector2(40.0, 470.0), 430.0)        # the last of the twilight at the cave mouth
	add_stone("den_pocket", Vector2(1540.0, platforms[1].position.y))

	for i in EMBERS.size():
		var at := on_ground(EMBERS[i])
		add_light(at + Vector2(0, -20), 150.0)
		add_glow(at + Vector2(0, -8), Color(1.0, 0.45, 0.15, 0.7), 150.0)
		# the painted hearth, seen low from the side, and its coals breathing
		var hearth := add_sprite("res://art/props/embers.png", at + Vector2(0, 9), 1.0, 3)
		var wide := 84.0 / hearth.texture.get_width()
		hearth.scale = Vector2(wide, wide * 0.5)
		add_painter(at + Vector2(0, -6), 3, func(ci: CanvasItem) -> void:
			var f := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004 + at.x)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
			ci.draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.4 + 0.2 * f, 0.1, 0.22 * f)), true)
		var tk := add_task(EMBERS[i] + (0.0 if i == 0 else 60.0), "light a torch at the embers", 0.7, _light)
		tk["again"] = true
	add_hint(1000.0, 150.0, "The torch burns down")

	add_jackal(1200.0, 900.0, 1680.0)
	add_jackal(1560.0, 900.0, 1680.0)
	add_jackal(2700.0, 2630.0, 2800.0)
	add_trigger(2180.0, 2300.0, func() -> void: say(["n_den_draught"]))

	# the heart of the cave: a shaft in the roof lets the moon in
	add_light(Vector2(3900.0, 400.0), 360.0)
	var shaft := add_glow(Vector2(3900.0, 300.0), Color(0.6, 0.75, 1.0, 0.35), 300.0)
	shaft.scale = Vector2(1.4, 7.0)
	shaft.z_index = 1
	# what the bear has left lying about its door
	for bx in [3215.0, 4640.0]:
		var bones := add_sprite("res://art/props/bones.png", on_ground(bx) + Vector2(0, 5), 1.0, 2, Color(0.62, 0.62, 0.72))
		bones.scale = Vector2.ONE * (92.0 / bones.texture.get_width())
		bones.flip_h = bx > 4000.0
	add_trigger(3380.0, 3500.0, _start_bear, false)
	add_light(Vector2(out_x + 80.0, 470.0 - SHELF_UP), 330.0)      # the way out, and the night beyond it
	add_trigger(out_x - 20.0, out_x + 90.0, _out, false)
	_back_passages()


func begin() -> void:
	if not Game.main.intro.has_story("den"):      # the film before this section speaks the line itself
		await say(["n_den_intro"])


func _light() -> void:
	light_torch()
	if not lit_once:
		lit_once = true
		say(["n_den_torch"])


func _start_bear() -> void:
	if bear_started:
		if walls.is_empty() and is_instance_valid(bear) and not bear.fleeing:      # come again after being beaten back
			walls = [add_wall(3270.0), add_wall(4540.0)]
			Game.music("battle", 0.8)
		return
	bear_started = true
	walls = [add_wall(3270.0), add_wall(4540.0)]
	await say(["n_den_bear"])
	bear = Bear.new()
	bear.level = self
	bear.player = player
	bear.min_x = 3310.0
	bear.max_x = 4500.0
	bear.position = on_ground(4250.0)
	bear.dir = -1
	add_child(bear)
	boss = bear
	boss_name = "The Bear"
	Game.music("battle", 0.8)
	bear.defeated.connect(func() -> void:
		boss = null
		Game.music(mood)
		for w in walls:
			w.queue_free()
		walls.clear()
		await give_here("heart")
		Game.find_line("p23_valley")
		say(["n_den_out"]))


func _out() -> void:
	if is_instance_valid(bear) and not bear.fleeing:
		return
	complete()


func _on_respawn() -> void:
	if lit_once:
		torch_t = torch_max
	if is_instance_valid(bear) and not bear.fleeing:
		bear.reset()
		bear.position = on_ground(4250.0)
		for w in walls:      # the way back in must be open, or he is shut out of his own fight
			w.queue_free()
		walls.clear()


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(player):
		var px: float = player.global_position.x
		draught = 3.0 if px > 2250.0 and px < 2990.0 else 1.0


## Behind the bear's floor the cave goes on. Its larder, where he must look for what he dreads to find; a break
## in the floor; a climb to a pocket under the roof; and the scavengers that live on what the bear leaves.
func _back_passages() -> void:
	if Game.backdrop:
		return
	for lx in [5080.0, 5680.0, 6240.0]:        # grey light leaks in from cracks above: he can see his way
		add_light(Vector2(lx, 440.0), 260.0)
	# the larder
	for bx in [5040.0, 5130.0, 5230.0]:
		var bones := add_sprite("res://art/props/bones.png", on_ground(bx) + Vector2(0, 5), 1.0, 2, Color(0.62, 0.62, 0.72))
		bones.scale = Vector2.ONE * (rng.randf_range(70.0, 110.0) / bones.texture.get_width())
		bones.flip_h = rng.randf() < 0.5
	add_wool(5170.0)
	add_task(5130.0, "Search the bear's larder", 1.5, func() -> void:
		searched = true
		show_tip("Old bones, and wool gone grey.  Nothing new.  The lamb was not brought here", 6.5))
	add_hint(5000.0, 150.0, "Its larder.  He has to look")
	add_beast("viper", 5700.0)      # a snake in the cold dark of the passage, where the bear's larder spills its bones
	# the pocket under the roof
	add_stone("den_roof", Vector2(6130.0, platforms[4].position.y))
	# the scavengers
	add_jackal(6300.0, 6180.0, 6600.0)
	add_jackal(6480.0, 6180.0, 6600.0)
	add_tracks(6560.0, SHELF_X - 60.0, true)
	add_tracks(SHELF_X + 50.0, out_x - 40.0, true)

	# water standing in the rock under a crack in the roof. He has not drunk since the well
	add_light(Vector2(POOL_X, 440.0), 250.0)
	var pool := on_ground(POOL_X)
	add_glow(pool + Vector2(0, -8), Color(0.55, 0.7, 1.0, 0.14), 150.0)
	add_pool(POOL_X, pal.get("char", Color(1, 1, 1)))
	add_task(POOL_X, "drink at the pool", 1.2, func() -> void:
		Game.sfx("step", -4.0, 0.3)
		player.hp = player.max_hp
		show_tip("Cold water, out of the rock.  He has not drunk since the well", 5.5))

	# beyond the pool there is no light but one crack of moon. What the bear left, the scavengers lived on;
	# with the bear gone they want the cave, and him out of it
	add_light(Vector2(7290.0, 430.0), 300.0)
	add_ambush(6980.0, 7600.0, [2, 3], func() -> void:
		Game.music("battle", 0.8)
		show_tip("Eyes in the dark.  Fight them where the moon comes in", 5.5), func() -> void:
		Game.music(mood, 2.5)
		show_tip("Quiet.  The broad tracks go on, and up"))

	# the way out goes up over a shelf of rock. A bear takes it in one heave; a boy needs a step
	add_light(Vector2(SHELF_X - 90.0, 450.0), 230.0)
	# the face of the shelf is the same painted rock as the outcrops, at its own size, so it is stone and not a dark block
	var face := add_sprite("res://art/props/rock_low.png", Vector2(SHELF_X - 30.0, BASE - SHELF_UP - 13.0), 1.0, 3, Color(0.33, 0.39, 0.6))      # as dark and cool as the cave it stands in
	face.offset = Vector2.ZERO
	add_rubble(on_ground(SHELF_X - 34.0) + Vector2(0, 8), [[-30.0, 0.7, false], [4.0, 0.95, true], [-62.0, 0.45, true]], Color(0.3, 0.35, 0.54))      # what has come down off its edge
	step_rock = add_pushable(7650.0, 58.0, 50.0, "res://art/props/rock_low.png", 7650.0, SHELF_X - 31.0)
	add_trigger(SHELF_X - 120.0, SHELF_X - 20.0, func() -> void:
		if step_rock["body"].position.x < SHELF_X - 60.0:
			show_tip("A shelf of rock, higher than he can leap.  The bear took it in one heave: he needs a step", 6.0))


## What he is to do now, from where things stand. Polled, so it is right at any checkpoint too.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_far = maxf(_far, player.global_position.x)
	set_goal(_goal_now())


func _goal_now() -> String:
	if bear_started:
		if not is_instance_valid(bear) or not bear.fleeing:
			return "Drive the bear off"
		return _goal_after()
	if _far > 4540.0:
		return _goal_after()
	if not lit_once:
		return "Light a torch at the embers"
	return "Follow the cave east, keep your torch lit"


## The back passages, once the bear is gone.
func _goal_after() -> String:
	var at: Vector2 = player.global_position
	if not ambush.is_empty() and not ambush["walls"].is_empty():
		return "Drive the scavengers off"
	if not searched and _far > 4900.0 and at.x < 5400.0:
		return "Search the bear's larder"
	if _far > SHELF_X - 320.0 and at.y > BASE - SHELF_UP + 20.0:
		if not step_rock.is_empty() and step_rock["body"].position.x < SHELF_X - 60.0:
			return "Roll the rock under the shelf for a step"
		return "Climb the shelf and leave the cave, east"
	return "Leave the cave, east"
