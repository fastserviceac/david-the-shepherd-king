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


func _setup() -> void:
	birds = false
	barren = true
	ambience = "night"
	mood = "ridge"
	backdrop_art = "res://art/den_backdrop.png"
	midground_art = "res://art/den_mid.png"
	mid_tint = Color(0.6, 0.66, 0.9)
	width = 5000.0
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
		make_ground(2950.0, width, BASE, 6.0, 2.0),
	]
	checkpoints = [140.0, 1850.0, 3080.0, 4580.0]
	ledge(1340.0, 62.0, 110.0)
	ledge(1480.0, 124.0, 120.0)
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
	add_trigger(3380.0, 3500.0, _start_bear)
	add_light(Vector2(4980.0, 470.0), 330.0)      # the way out, and the night beyond it
	add_trigger(4880.0, 4990.0, _out, false)


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


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(player):
		var px: float = player.global_position.x
		draught = 3.0 if px > 2250.0 and px < 2990.0 else 1.0
