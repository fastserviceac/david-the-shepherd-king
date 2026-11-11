extends "res://scripts/levels/level_base.gd"
## 1.4 The Anointing. Dawn. David brings the flock home, is called to
## Bethlehem, and is anointed by Samuel.

var samuel_raise := 0.0
var shaft: Sprite2D
var figures: Node2D


var samuel: Node2D
var lamb
var carrying := false
var met := false


## The lamb lies down in the road. Lifting it is his to do; then he walks, and cannot run or fight.
func _lamb_tires() -> void:
	if carrying or met:
		return
	lamb.stay = lamb.global_position.x
	show_tip("The lamb can go no farther", 5.0)
	var tk := add_task(lamb.global_position.x, "lift the lamb", 0.8, func() -> void:
		carrying = true
		lamb.visible = false
		lamb.stay = NAN
		player.act = "carry"
		player.act_t = 0.0
		player.carry_free = true
		player.calm = true, 60.0)
	tk["follow"] = lamb


func _meet_servant() -> void:
	if met:
		return
	if sheep_count < sheep_total:
		show_tip("The flock is not all here", 4.0)
		return
	if is_instance_valid(lamb) and not is_nan(lamb.stay) and not carrying:
		show_tip("The lamb is still lying in the road", 4.0)
		return
	met = true
	player.facing = 1
	if carrying:          # he sets the lamb down among the others
		carrying = false
		player.act = ""
		player.carry_free = false
		player.calm = false
		lamb.global_position = on_ground(player.global_position.x - 40.0)
		lamb.visible = true
	await say(["d_servant_1", "d_david_1", "d_servant_2", "d_david_2"])
	# the flock stays behind with the servant, spread out grazing around him
	for i in followers.size():
		followers[i].stay = 3760.0 + i * 40.0


func _setup() -> void:
	flutters = 3
	leaves = Color(1.0, 0.9, 0.75, 0.5)
	ambience = "dawn"
	backdrop_art = "res://art/s4_backdrop.png"
	midground_art = "res://art/s1_mid.png"
	mid_tint = Color(0.82, 0.78, 0.82)
	width = 6540.0
	pal.merge({
		"shafts": Color(1.0, 0.92, 0.7, 0.09), "mist": Color(1.0, 0.95, 0.85, 0.08),
		"grass": Color(1.0, 0.95, 0.86), "char": Color(1.0, 0.96, 0.9),
		"sky_top": Color(0.3, 0.45, 0.72), "sky_mid": Color(0.98, 0.78, 0.6), "sky_bot": Color(1.0, 0.93, 0.72),
		"sun_pos": Vector2(0.8, 0.6), "sun_col": Color(1.0, 0.95, 0.75), "sun_size": 0.08,
		"far": Color(0.98, 0.8, 0.62), "near": Color(0.42, 0.32, 0.36), "rim": Color(1.0, 0.9, 0.62),
		"mote": Color(1.0, 0.95, 0.7, 0.55),
	}, true)
	segments = [make_ground(0.0, width, 570.0, 12.0, 0.9)]
	checkpoints = [180.0, 1640.0, 2700.0, 4340.0, 5340.0]
	ledge(700.0, 66.0, 150.0)
	ledge(900.0, 132.0, 170.0)


func _populate() -> void:
	for tx in [420.0, 1250.0, 1700.0, 2150.0, 3050.0, 3600.0, 4100.0, 4540.0, 4990.0]:
		add_tree(tx, rng.randf_range(0.9, 1.4), rng.randf() < 0.5)

	# The road home is the last of the night's work, not a walk. Three things stand between him and the town.
	# First: the flock scattered at first light. Three are with him, the lamb among them; three are not.
	for i in 3:
		var s = add_sheep(140.0 - i * 30.0, null, i == 0)
		s.gathered = true
		s.follow_index = i
		followers.append(s)
	sheep_total = 0
	lamb = followers[0]
	add_sheep(520.0)
	add_sheep(0.0, Vector2(985.0, platforms[1].position.y))      # one has climbed
	var shy = add_sheep(1380.0)
	shy.skittish = true                                          # and one will only come to his voice

	# Second: the jackals have followed the flock down, and try it once more in the grey light
	add_ambush(1760.0, 2560.0, [2, 3], func() -> void:
		Game.music("battle", 0.8)
		show_tip("They have followed the flock down"), func() -> void:
		Game.music(mood, 2.5))

	# Third: the lamb, a night on the hills behind it, can go no farther. He carries it the rest of the way
	add_trigger(2900.0, 2990.0, _lamb_tires)

	# the servant sent to fetch him
	add_actor("servant", on_ground(3900.0) + Vector2(0, 4), 0.31)
	add_trigger(3720.0, 3840.0, _meet_servant, false)

	# Bethlehem, then Samuel, Jesse and the seven brothers
	add_sprite("res://art/s4_town.png", Vector2(6020.0, 590.0), 1.3, 1, Color(0.86, 0.82, 0.86))
	samuel = add_actor("samuel", on_ground(5940.0) + Vector2(0, 4), 0.31)
	add_actor("jesse", on_ground(6045.0) + Vector2(0, 4), 0.31)
	add_actor("brothers", on_ground(6240.0) + Vector2(0, 4), 0.31)

	shaft = add_glow(on_ground(5840.0) + Vector2(0, -300), Color(1.0, 0.95, 0.75, 0.0), 300.0)
	shaft.scale = Vector2(1.6, 7.0)
	shaft.z_index = 4

	# entering his father's courtyard he slows to a walk
	add_trigger(5400.0, 5480.0, func() -> void: player.calm = true)
	add_trigger(5880.0, 5900.0, _anointing)      # David stops an arm's length in front of Samuel


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