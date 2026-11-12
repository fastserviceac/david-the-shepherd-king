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
var _far := 0.0           # the farthest he has come, for the goal
var strays: Array = []    # the five that are out, west to east
var bay_ewe               # the one a jackal has cut off
var bay_jackal
var wild_ewe              # the one that will come only to his voice
var bridged := false      # the footbridge is back across the washout
var lay_bridge: Callable
var bridge_task: Dictionary
var lift_task: Dictionary
var lip_wall: StaticBody2D
var thorn: Array = []     # the brake that has come up round Rachel's grave

const WASH_X0 := 4200.0   # the washout the winter rains cut across the road
const WASH_X1 := 4350.0
const LAMB_X := 4090.0
const SERVANT_X := 5100.0
const PILLAR_X := 5700.0
const SPRING_X := 6160.0
const TOP := 396.0        # the height of the town's terrace
const CALM_X := 7300.0
const SAMUEL_X := 7840.0


## At the washout the lamb lies down. The ewes leap it; a lamb with a night on the hills behind it will not.
## Lifting it is his to do; then he walks, and cannot run, fight or leap.
func _lamb_tires() -> void:
	if carrying or met:
		return
	lamb.stay = LAMB_X
	show_tip("The rains have cut the road.  The lamb lies down: it can go no farther", 6.0)
	lift_task = add_task(LAMB_X, "lift the lamb", 0.8, _lift, 60.0)


func _lift() -> void:
	carrying = true
	lamb.visible = false
	lamb.stay = NAN
	player.act = "carry"
	player.act_t = 0.0
	player.carry_free = true
	player.calm = true
	if not bridged:       # he will not walk off the edge with it
		lip_wall = add_wall(WASH_X0 - 10.0)


## The footbridge the town keeps here lies on the near bank where the flood left it. He drags it back across.
func _bridge_laid() -> void:
	bridged = true
	lay_bridge.call()
	if is_instance_valid(lip_wall):
		lip_wall.queue_free()
	show_tip("The footbridge is across.  It will bear him and the lamb", 5.0)


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
	_flock_stays()


## The flock stays behind with the servant, spread out grazing around him.
func _flock_stays() -> void:
	for i in followers.size():
		followers[i].stay = SERVANT_X - 160.0 + i * 40.0


func _setup() -> void:
	flutters = 3
	leaves = Color(1.0, 0.9, 0.75, 0.5)
	ambience = "dawn"
	backdrop_art = "res://art/s4_backdrop.png"
	midground_art = "res://art/s1_mid.png"
	mid_tint = Color(0.82, 0.78, 0.82)
	width = 8440.0
	pal.merge({
		"shafts": Color(1.0, 0.92, 0.7, 0.09), "mist": Color(1.0, 0.95, 0.85, 0.08),
		"grass": Color(1.0, 0.95, 0.86), "char": Color(1.0, 0.96, 0.9),
		"sky_top": Color(0.3, 0.45, 0.72), "sky_mid": Color(0.98, 0.78, 0.6), "sky_bot": Color(1.0, 0.93, 0.72),
		"sun_pos": Vector2(0.8, 0.6), "sun_col": Color(1.0, 0.95, 0.75), "sun_size": 0.08,
		"far": Color(0.98, 0.8, 0.62), "near": Color(0.42, 0.32, 0.36), "rim": Color(1.0, 0.9, 0.62),
		"mote": Color(1.0, 0.95, 0.7, 0.55),
	}, true)
	segments = [
		make_ground(0.0, WASH_X0, 570.0, 12.0, 0.9),
		make_ground(WASH_X1, 6300.0, 570.0, 10.0, 0.4),      # beyond the washout
		make_ground(6290.0, 6650.0, 512.0, 4.0, 1.3),        # Bethlehem stands on its ridge: three terraces of
		make_ground(6640.0, 7000.0, 454.0, 4.0, 2.1),        # olive and vine climb to it, each wall a step to get up
		make_ground(6990.0, width, TOP, 5.0, 0.7),
	]
	checkpoints = [180.0, 1640.0, 2700.0, 3950.0, 5540.0, 7240.0]
	ledge(700.0, 66.0, 150.0)
	ledge(900.0, 132.0, 170.0)


func _populate() -> void:
	for tx in [420.0, 1250.0, 1700.0, 2150.0, 3050.0, 3600.0, 4560.0, 4800.0, 5330.0, 5950.0, 6420.0, 6800.0, 7150.0]:
		add_tree(tx, rng.randf_range(0.9, 1.4), rng.randf() < 0.5)

	# The road home is the last of the night's work, not a walk.
	# First: the flock scattered at first light. Three are with him, the lamb among them; five are not.
	for i in 3:
		var s = add_sheep(140.0 - i * 30.0, null, i == 0)
		s.gathered = true
		s.follow_index = i
		followers.append(s)
	sheep_total = 0
	lamb = followers[0]
	strays.append(add_sheep(520.0))
	strays.append(add_sheep(0.0, Vector2(985.0, platforms[1].position.y)))      # one has climbed
	var shy = add_sheep(1380.0)
	shy.skittish = true                                          # and one will only come if he does not rush her
	strays.append(shy)

	# Second: the jackals have followed the flock down, and try it once more in the grey light
	add_ambush(1760.0, 2560.0, [2, 3], func() -> void:
		Game.music("battle", 0.8)
		show_tip("They have followed the flock down"), func() -> void:
		Game.music(mood, 2.5)
		show_tip("Two are still out, farther along the road"))

	if not Game.backdrop:
		# one of the pack did not come to the fight: it has a ewe cut off by herself, farther down the road
		bay_ewe = add_sheep(3350.0)
		strays.append(bay_ewe)
		bay_jackal = add_jackal(3470.0, 3130.0, 3600.0)
		add_trigger(2740.0, 2840.0, func() -> void:
			if is_instance_valid(bay_ewe) and not bay_ewe.gathered:
				show_tip("A ewe alone on the road ahead, and a jackal that has found her", 5.5))
		# and one ran from the jackals and has not stopped being afraid. No hand will reach her; she knows his voice
		wild_ewe = add_sheep(3780.0)
		wild_ewe.wild = true
		strays.append(wild_ewe)
		add_hint(3600.0, 170.0, "She runs from him, but she knows his voice")

		# Third: the washout. The winter rains have cut the road, and the footbridge lies where the flood left it
		lay_bridge = add_bridge(WASH_X0, WASH_X1, 570.0, true)
		bridge_task = add_task(WASH_X0 - 34.0, "drag the footbridge across", 1.8, _bridge_laid, 46.0)
		add_trigger(LAMB_X - 110.0, LAMB_X - 20.0, _lamb_tires)
		add_trigger(WASH_X0 - 80.0, WASH_X0, func() -> void:
			if carrying and not bridged:
				show_tip("With the lamb on his shoulders he cannot leap it.  The footbridge lies on the bank", 5.0), false)

		# beside the road between the flock and the town: the pillar on Rachel's grave. Thorn comes up round it
		# with every rain, and the men of Bethlehem, whose mother's grave it is, cut it back when they pass
		for bx in [PILLAR_X - 150.0, PILLAR_X + 96.0]:
			thorn.append(add_bush(bx))
	var grave := on_ground(PILLAR_X)
	var pillar := add_sprite("res://art/props/pillar.png", grave + Vector2(0, 8), 1.0, 1, pal.get("char", Color(1, 1, 1)))
	pillar.scale = Vector2.ONE * (120.0 / pillar.texture.get_width())
	add_place("rachel", grave + Vector2(-70, 0), "Rachel's Pillar", "heart")

	# the spring at the foot of the terraces: a boy called in from a night on the hills washes before he comes to a sacrifice
	if not Game.backdrop:
		add_glow(on_ground(SPRING_X) + Vector2(0, -10), Color(0.7, 0.85, 1.0, 0.4), 150.0)
		if ResourceLoader.exists("res://art/props/trough.png"):
			var basin := add_sprite("res://art/props/trough.png", on_ground(SPRING_X) + Vector2(0, 8), 1.0, 1, pal.get("char", Color(1, 1, 1)))
			basin.scale = Vector2.ONE * (110.0 / basin.texture.get_width())
		add_task(SPRING_X, "wash at the spring", 1.6, func() -> void:
			Game.sfx("step", -4.0, 0.3)
			player.hp = player.max_hp
			show_tip("The dust and blood of the night come off.  He does not know yet what he is washing for", 6.5))
		add_trigger(6300.0, 6400.0, func() -> void:
			show_tip("The terraces of Bethlehem: olive and vine, one wall above another", 5.0))
		add_trigger(7050.0, 7150.0, func() -> void:
			show_tip("Smoke over the town: a sacrifice.  And the elders are standing in the gate", 6.0))

	# the servant sent to fetch him
	add_actor("servant", on_ground(SERVANT_X) + Vector2(0, 4), 0.31)
	add_trigger(SERVANT_X - 180.0, SERVANT_X - 60.0, _meet_servant, false)

	# Bethlehem, then Samuel, Jesse and the seven brothers
	add_sprite("res://art/s4_town.png", Vector2(SAMUEL_X + 80.0, TOP + 20.0), 1.3, 1, Color(0.86, 0.82, 0.86))
	samuel = add_actor("samuel", on_ground(SAMUEL_X) + Vector2(0, 4), 0.31)
	add_actor("jesse", on_ground(SAMUEL_X + 105.0) + Vector2(0, 4), 0.31)
	add_actor("brothers", on_ground(SAMUEL_X + 300.0) + Vector2(0, 4), 0.31)

	shaft = add_glow(on_ground(SAMUEL_X - 100.0) + Vector2(0, -300), Color(1.0, 0.95, 0.75, 0.0), 300.0)
	shaft.scale = Vector2(1.6, 7.0)
	shaft.z_index = 4

	# entering his father's courtyard he slows to a walk
	add_trigger(CALM_X, CALM_X + 80.0, func() -> void: player.calm = true)
	add_trigger(SAMUEL_X - 60.0, SAMUEL_X - 40.0, _anointing)      # David stops an arm's length in front of Samuel
	_resume(checkpoints[clampi(start_checkpoint, 0, checkpoints.size() - 1)])


## Begun again from a watchfire beyond the servant: the flock was brought to him before that fire was lit.
func _resume(from: float) -> void:
	if from < SERVANT_X or Game.backdrop:
		return
	for s in strays:
		s.wild = false
		s.gathered = true
		s.follow_index = followers.size()
		followers.append(s)
		sheep_count += 1
	if is_instance_valid(bay_jackal):
		bay_jackal.queue_free()
	met = true
	bridged = true
	lay_bridge.call()
	bridge_task["on"] = false
	for i in followers.size():
		followers[i].position = on_ground(SERVANT_X - 160.0 + i * 40.0)
	_flock_stays()
	for b in thorn:
		if b.position.x < from:
			b.queue_free()


func begin() -> void:
	if not Game.main.intro.has_story("dawn"):      # the film before this section speaks the line itself
		await say(["n_s4_intro"])


## Samuel's own pouring animation, in the scene.
func pour() -> void:
	actor_play(samuel, "samuel", "anoint", 8.0, -1.0, 0.5, 1.45)


func _anointing() -> void:
	player.facing = 1
	Game.music("anointing", 3.0)
	# the film before this section has already shown the brothers passing before the prophet
	await say((["n_s4_brothers"] if not Game.main.intro.has_story("dawn") else []) + ["d_jesse_1", "1sam16_7"])
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

## What he is to do now, from where things stand. Polled, so it is right at any checkpoint too.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_far = maxf(_far, player.global_position.x)
	set_goal(_goal_now())


func _goal_now() -> String:
	var px: float = player.global_position.x
	if not ambush.is_empty() and not ambush["walls"].is_empty():
		return "Drive the jackals off the flock"
	if met:
		if _far >= CALM_X:
			return "Go to Samuel in the courtyard, east"
		for b in thorn:
			if is_instance_valid(b) and _far > PILLAR_X - 420.0 and px < b.position.x + 40.0:
				return "Cut the thorn back from Rachel's grave"
		if _far > 6200.0:
			return "Climb the terraces to Bethlehem, east"
		return "Go on to Bethlehem, east"
	if sheep_count < sheep_total:
		var next = null
		for s in strays:
			if is_instance_valid(s) and not s.gathered:
				next = s
				break
		if next == null:
			return "Gather the strays"
		if px > next.global_position.x + 500.0:
			return "Go back west and gather the strays"
		if next == bay_ewe:
			if _far < 2740.0:
				return "Lead the flock on, east: two are still out"
			if is_instance_valid(bay_jackal) and not bay_jackal.fleeing:
				return "Drive the jackal off the ewe"
			return "Gather the stray ewe"
		if next == wild_ewe:
			return "Call the frightened ewe (Q)"
		return "Gather the five strays"
	if carrying:
		if not bridged:
			return "Drag the footbridge across the washout"
		return "Carry the lamb to the servant, east"
	if is_instance_valid(lamb) and not is_nan(lamb.stay):
		return "Lift the lamb"
	return "Lead the flock to the servant, east"
