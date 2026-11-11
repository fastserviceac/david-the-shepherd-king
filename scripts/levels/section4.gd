extends "res://scripts/levels/level_base.gd"
## 1.4 The Anointing. Dawn. David brings the flock home, is called to
## Bethlehem, and is anointed by Samuel.

var samuel_raise := 0.0
var shaft: Sprite2D
var figures: Node2D


var samuel: Node2D


func _setup() -> void:
	flutters = 3
	leaves = Color(1.0, 0.9, 0.75, 0.5)
	ambience = "dawn"
	backdrop_art = "res://art/s4_backdrop.png"
	midground_art = "res://art/s1_mid.png"
	mid_tint = Color(0.82, 0.78, 0.82)
	width = 3700.0
	pal.merge({
		"shafts": Color(1.0, 0.92, 0.7, 0.09), "mist": Color(1.0, 0.95, 0.85, 0.08),
		"grass": Color(1.0, 0.95, 0.86), "char": Color(1.0, 0.96, 0.9),
		"sky_top": Color(0.3, 0.45, 0.72), "sky_mid": Color(0.98, 0.78, 0.6), "sky_bot": Color(1.0, 0.93, 0.72),
		"sun_pos": Vector2(0.8, 0.6), "sun_col": Color(1.0, 0.95, 0.75), "sun_size": 0.08,
		"far": Color(0.98, 0.8, 0.62), "near": Color(0.42, 0.32, 0.36), "rim": Color(1.0, 0.9, 0.62),
		"mote": Color(1.0, 0.95, 0.7, 0.55),
	}, true)
	segments = [make_ground(0.0, width, 570.0, 12.0, 0.9)]
	checkpoints = [180.0, 1500.0, 2500.0]


func _populate() -> void:
	for tx in [420.0, 1250.0, 1700.0, 2150.0]:
		add_tree(tx, rng.randf_range(0.9, 1.4), rng.randf() < 0.5)

	# the flock, with the rescued lamb, follows from the start
	for i in 6:
		var s = add_sheep(140.0 - i * 30.0, null, i == 0)
		s.gathered = true
		s.follow_index = i
		followers.append(s)
	sheep_total = 0

	# the servant sent to fetch him
	add_actor("servant", on_ground(1060.0) + Vector2(0, 4), 0.31)
	add_trigger(880.0, 1000.0, func() -> void:
		player.facing = 1
		await say(["d_servant_1", "d_david_1", "d_servant_2", "d_david_2"])
		# the flock stays behind with the servant, spread out grazing around him
		for i in followers.size():
			followers[i].stay = 930.0 + i * 44.0)

	# Bethlehem, then Samuel, Jesse and the seven brothers
	add_sprite("res://art/s4_town.png", Vector2(3180.0, 590.0), 1.3, 1, Color(0.86, 0.82, 0.86))
	samuel = add_actor("samuel", on_ground(3100.0) + Vector2(0, 4), 0.31)
	add_actor("jesse", on_ground(3205.0) + Vector2(0, 4), 0.31)
	add_actor("brothers", on_ground(3400.0) + Vector2(0, 4), 0.31)

	shaft = add_glow(on_ground(3000.0) + Vector2(0, -300), Color(1.0, 0.95, 0.75, 0.0), 300.0)
	shaft.scale = Vector2(1.6, 7.0)
	shaft.z_index = 4

	# entering his father's courtyard he slows to a walk
	add_trigger(2560.0, 2640.0, func() -> void: player.calm = true)
	add_trigger(3040.0, 3060.0, _anointing)      # David stops an arm's length in front of Samuel


func begin() -> void:
	await say(["n_s4_intro"])


## Samuel's own pouring animation, in the scene.
func pour() -> void:
	actor_play(samuel, "samuel", "anoint", 8.0, -1.0, 0.5, 1.45)


func _anointing() -> void:
	player.facing = 1
	Game.music("anointing", 3.0)
	await say(["n_s4_brothers", "d_jesse_1", "1sam16_7"])
	# David kneels before the prophet; the light comes down on him
	Game.cinematic = true
	player.act = "kneel"
	player.act_t = 0.0
	shaft.position.x = player.position.x
	var tw := create_tween()
	tw.tween_property(shaft, "modulate:a", 0.8, 2.4)
	if not Game.fast:
		await get_tree().create_timer(1.6).timeout
	# Samuel lifts the horn and pours the oil over him, and the camera moves in on the two of them
	Game.sfx("anoint", 2.0, 0.0)
	pour()
	if not Game.fast:
		create_tween().tween_property(player.cam, "zoom", Vector2(1.55, 1.55), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await say(["1sam16_12", "1sam16_13"])
	Game.cinematic = true
	player.act = "kneel_up"       # he lifts his face
	player.act_t = 0.0
	if not Game.fast:
		await get_tree().create_timer(2.4).timeout
	complete()