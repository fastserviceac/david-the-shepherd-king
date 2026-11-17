extends "res://scripts/levels/level_base.gd"
## 1.0 Lambing Night. Late winter, weeks before the evening of the Pastures. The ewes are near their time; one has
## gone off alone among the rocks, which is how a shepherd knows. He takes a brand from the watchfire and goes after
## her, keeps a wolf off while she labours (the lyre keeps her quiet; a wolf near her undoes it), rubs the still
## lamb dry with grass until it breathes, lays it at its mother's head so she knows it by its smell, and carries it
## home in his cloak at her pace as dawn comes. The lamb is Shai, the one the lion takes.
## Not scripture: the customs are ordinary shepherd practice. Genesis 31:40 is Jacob, and Isaiah 40:11 is a prophet
## speaking of God; neither is about David.

const BASE := 572.0
const FOLD := 520.0
const FIRE := 780.0
const EMBERS := 2080.0
const GRASS_X := 3020.0       # dry grass, kept from the frost under a rock shelf
const BIRTH_X := 3420.0       # where she has gone to lamb, in the lee of the rocks
const LABOUR_S := 30.0        # seconds of quiet, with him by her, that the birth takes
const GATHER_S := 2.4

var flock: Array = []          # the seven in the fold
var rachel                     # the ewe that went off alone: Shai's mother
var lamb                       # Shai, once born
var part := 0                  # 0 at the fold, 1 searching, 2 labour, 3 born and still, 4 breathing, 5 with its mother, 6 carrying home, 7 home
var labour := 0.0              # 0..1
var has_grass := false
var carrying := false
var wolf = null
var wolves := 0                # how many have come
var fire_light: Dictionary
var bleat_t := 3.0
var spooked_t := 0.0           # seconds since the wolf last broke her quiet (for the tip)
var told_wolf := false
var grass_task: Dictionary
var rub_task: Dictionary
var lay_head_task: Dictionary
var gather_task: Dictionary
var lay_task: Dictionary
var lift_task: Dictionary
var song_spot: Dictionary


func _setup() -> void:
	birds = false
	ambience = "night"
	mood = "theme_still"
	backdrop_art = "res://art/watch_backdrop.png"
	midground_art = "res://art/watch_mid.png"
	mid_tint = Color(0.56, 0.62, 0.86)
	width = 4100.0
	pal.merge({
		"mist": Color(0.62, 0.72, 1.0, 0.1),
		"grass": Color(0.32, 0.4, 0.66), "ground": Color(0.28, 0.32, 0.5), "char": Color(0.62, 0.68, 0.9),
		"sky_top": Color(0.02, 0.03, 0.12), "sky_mid": Color(0.07, 0.11, 0.3), "sky_bot": Color(0.26, 0.33, 0.58),
		"sun_pos": Vector2(0.28, 0.24), "sun_col": Color(0.86, 0.9, 1.0), "sun_size": 0.026, "stars": 1.0,
		"far": Color(0.24, 0.3, 0.52), "near": Color(0.07, 0.09, 0.2), "rim": Color(0.72, 0.8, 1.0),
		"wool": Color(0.82, 0.85, 0.95), "mote": Color(0.85, 0.9, 1.0, 0.35),
	}, true)
	leaves = Color(0.9, 0.94, 1.0, 0.0)
	segments = [make_ground(0.0, width, BASE, 20.0, 0.9)]
	checkpoints = [180.0, EMBERS - 120.0, BIRTH_X - 300.0]
	torch_max = 75.0
	# the rocks she went off among: a climb up, a shelf, and down into the lee where she lies
	ledge(1420.0, 66.0, 150.0)
	ledge(1600.0, 132.0, 140.0)
	ledge(1790.0, 70.0, 130.0)
	ledge(2540.0, 72.0, 140.0)
	ledge(2720.0, 140.0, 150.0)
	ledge(GRASS_X, 112.0, 190.0)       # the rock shelf the dry grass is kept under


## The name the save knows this place by, for where each of his nine is.
func section_name() -> String:
	return "lambing"


func _way_back() -> void:      # it is not a place on the road: nothing to go back to, nor on to, from here
	pass


func _populate() -> void:
	set_dark(0.62)
	var at := on_ground(FOLD)
	add_sprite("res://art/props/fold.png", at + Vector2(0, 14), 1.6, 1)
	# the watchfire, where the night began
	var fp := on_ground(FIRE)
	var glow := Game.glow(Color(1.0, 0.6, 0.25, 0.9), 160.0)
	glow.position = fp + Vector2(0, -30)
	glow.z_index = 3
	add_child(glow)
	glow.add_child(_flames())
	fire_light = add_light(fp + Vector2(0, -40), 460.0)
	var brand := add_task(FIRE - 50.0, "take a brand from the fire", 0.7, light_torch)
	brand["again"] = true
	add_embers(EMBERS)      # an old shepherds' hearth on the way, still warm under the ash

	# where she has gone: the lee of the rocks, out of the wind
	rachel = add_sheep(BIRTH_X, null, false, "rachel")
	rachel.gathered = false
	rachel.gatherable = false
	rachel.safe = true
	rachel.stay = BIRTH_X
	rachel.face = 1.0
	rachel.pose = "ewe_labour"
	rachel.pose_fps = 6.0
	add_light(on_ground(BIRTH_X) + Vector2(0, -30), 90.0)      # starlight in the open lee
	lamb = add_sheep(BIRTH_X - 52.0, null, true, "lamb")
	lamb.size = 0.5
	lamb.gathered = false
	lamb.gatherable = false
	lamb.safe = true
	lamb.stay = BIRTH_X - 52.0
	lamb.face = 1.0
	lamb.visible = false
	lamb.pose = "lamb_wake"
	lamb.pose_once = true
	lamb.pose_fps = 0.0          # held still on its first frame until it breathes
	# seven ewes in the fold, all near their time; the eighth is gone. (The lamb of this year is not born yet.)
	for i in 7:
		var s = add_sheep(FOLD - 95.0 + i * 30.0)
		s.gathered = true
		s.gatherable = false
		s.safe = true
		s.stay = s.position.x
		s.home_x = s.position.x
		flock.append(s)
	sheep_total = 0
	sheep_count = 0

	# dry grass under the rock shelf, kept from the frost
	var tuft := add_sprite("res://art/props/d_grass.png", on_ground(GRASS_X) + Vector2(0, 8), 1.0, 2, Color(0.95, 0.85, 0.62))
	tuft.scale = Vector2.ONE * (120.0 / tuft.texture.get_width())
	grass_task = add_task(GRASS_X, "pull a handful of dry grass", 0.8, func() -> void:
		has_grass = true
		Game.sfx("gather", -8.0, 0.1)
		if part >= 3 and part < 4:
			show_tip("Dry grass.  Take it to the lamb"))
	grass_task["again"] = true
	rub_task = add_task(BIRTH_X - 52.0, "rub the lamb dry with grass", 2.6, _rub, 70.0)
	rub_task["on"] = false
	rub_task["again"] = true
	lay_head_task = add_task(BIRTH_X - 52.0, "lay it at its mother's head", 1.0, _to_mother, 70.0)
	lay_head_task["on"] = false
	gather_task = add_task(BIRTH_X + 60.0, "gather up the lamb", 0.9, _gather, 70.0)
	gather_task["on"] = false
	lay_task = add_task(0.0, "lay the lamb down", 0.6, _lay, 9999.0)
	lay_task["on"] = false
	lay_task["again"] = true
	lift_task = add_task(0.0, "take up the lamb again", 0.6, _lift_again, 60.0)
	lift_task["on"] = false
	lift_task["again"] = true
	song_spot = add_song(BIRTH_X, func() -> void: pass, 230.0)
	song_spot["again"] = true
	song_spot["on"] = false

	add_stone("lamb_lee", Vector2(2720.0, platforms[4].position.y))
	for tx in [260.0, 1180.0, 2300.0, 3800.0]:
		add_tree(tx, rng.randf_range(0.8, 1.15), rng.randf() < 0.5)
	add_hint(FIRE - 120.0, 150.0, "E  take a brand from the fire")
	add_trigger(FOLD - 140.0, FOLD + 160.0, _count, false)
	add_trigger(BIRTH_X - 260.0, BIRTH_X + 200.0, _found_her)


func begin() -> void:
	await say(["n_s1_intro", "n_lamb_intro", "gen31_40"])


## At the fold he counts them, and one is missing.
func _count() -> void:
	if part != 0:
		return
	part = 1
	await say(["n_lamb_alone"])
	add_tracks(FOLD + 300.0, BIRTH_X - 240.0)


func _found_her() -> void:
	if part > 1:
		return
	part = 2
	song_spot["on"] = true
	Game.sfx("sheep", -6.0, 0.1)
	add_hint(BIRTH_X - 200.0, 150.0, "R  hold, and let go at the top: the lyre keeps her quiet")
	show_tip("She is lambing.  Stay by her, and keep her quiet", 6.0)


func song_noise(at: Vector2) -> float:
	return 0.75 if _wolf_near(at.x, 520.0) else 0.0


func _wolf_near(x: float, reach: float) -> bool:
	return wolf != null and is_instance_valid(wolf) and not wolf.fleeing and wolf.state != "flee" \
			and absf(wolf.global_position.x - x) < reach


func _spawn_wolf(x: float) -> void:
	wolves += 1
	wolf = add_beast("wolf", x, {"edge_x": width})
	Game.music("battle", 1.0)
	Game.sfx("jackal_snarl", -6.0)


## The labour: it goes on only while she is quiet and he is by her. A wolf near her undoes the quiet.
func _labour(delta: float) -> void:
	var near_her: bool = absf(player.global_position.x - BIRTH_X) < 320.0
	if _wolf_near(BIRTH_X, 560.0):
		if rachel.calm > 0.0:
			rachel.rouse()
			spooked_t = 0.0
			if not told_wolf:
				told_wolf = true
				show_tip("A wolf.  She will not be quiet while it is near: drive it off, then play again", 6.5)
		rachel.pose_fps = 12.0       # she strains and throws her head
		return
	rachel.pose_fps = 6.0
	if wolf != null and is_instance_valid(wolf) and wolf.fleeing:
		wolf = null
		Game.music(mood, 2.5)
	if rachel.calm > 0.0 and near_her:
		labour = minf(1.0, labour + delta / LABOUR_S)
	if labour >= 0.3 and wolves == 0 and not Game.fast:
		_spawn_wolf(width - 160.0)
	if labour >= 1.0 and wolf == null:
		_born()


func _born() -> void:
	part = 3
	song_spot["on"] = false
	rachel.calm = 0.0
	rachel.pose = "rest"         # spent, lying on her chest
	rachel.pose_once = false
	rachel.pose_fps = 6.0
	lamb.visible = true
	Game.sfx("lamb", -10.0, 0.1)
	Game.music("theme_tender", 3.0)
	rub_task["on"] = true
	if not has_grass:
		show_tip("It does not breathe.  Dry grass: under the rock shelf, back along the path", 7.0)


func _rub() -> void:
	if not has_grass:
		show_tip("Bare hands will not do it.  Dry grass is under the rock shelf, back along the path", 6.0)
		return
	if part != 3:
		return
	part = 4
	rub_task["on"] = false
	Game.cinematic = true
	player.facing = 1
	player.global_position = on_ground(BIRTH_X - 110.0)
	player.velocity = Vector2.ZERO
	player.act = "rub"
	player.act_t = 0.0
	await say(["n_lamb_born"])
	lamb.pose_fps = 7.0          # it lifts its wobbling head, shakes its ears
	Game.sfx("lamb", -8.0, 0.1)
	if not Game.fast:
		await get_tree().create_timer(1.2).timeout
	player.act = "kneel_up"
	player.act_t = 0.0
	if not Game.fast:
		await get_tree().create_timer(1.0).timeout
	player.act = ""
	Game.cinematic = false
	lay_head_task["on"] = true
	show_tip("It breathes.  Now its mother must know it")


## He lays it at its mother's head: she gets up, and knows it by its smell.
func _to_mother() -> void:
	if part != 4:
		return
	part = 5
	lay_head_task["on"] = false
	Game.cinematic = true
	lamb.global_position = on_ground(BIRTH_X + 70.0)
	lamb.stay = BIRTH_X + 70.0
	lamb.face = -1.0
	lamb.pose = "lamb_wake"
	lamb.pose_once = true
	lamb.pose_t = 99.0           # held with its head up
	rachel.pose = ""
	rachel.rest_t = -1.0
	rachel.rise_t = 0.0          # she gets up, hind legs first
	if not Game.fast:
		await get_tree().create_timer(1.2).timeout
	rachel.pose = "ewe_tend"
	rachel.pose_once = false
	rachel.pose_fps = 6.0
	await say(["n_lamb_mother"])
	lamb.name_t = 4.0
	await say(["n_lamb_name"])
	Game.save["lamb_born"] = true
	Game.cinematic = false
	gather_task["x"] = BIRTH_X + 70.0
	gather_task["on"] = true
	show_tip("Dawn is far off, and it is cold.  Carry it home to the fold", 6.0)


## He gathers it into his cloak, and they go home at her pace.
func _gather() -> void:
	if part != 5:
		return
	part = 6
	Game.cinematic = true
	player.facing = 1
	player.global_position = on_ground(BIRTH_X + 10.0)
	player.velocity = Vector2.ZERO
	player.act = "gather"
	player.act_t = 0.0
	if not Game.fast:
		await get_tree().create_timer(GATHER_S * 0.55).timeout
	lamb.visible = false
	if not Game.fast:
		await get_tree().create_timer(GATHER_S * 0.45).timeout
	_lift()
	rachel.pose = ""
	rachel.stay = NAN
	rachel.safe = false
	rachel.gathered = true
	rachel.max_speed = 118.0      # just lambed: she will not run, and a running boy leaves her behind
	rachel.follow_index = 0
	followers.append(rachel)
	Game.cinematic = false
	Game.music("theme_tender", 2.0)
	say(["isa40_11"])
	add_hint(BIRTH_X - 200.0, 150.0, "Walk.  She has just lambed and cannot keep up with a run")
	if not Game.fast:
		create_tween().tween_property(self, "dark_amount", 0.18, 70.0)      # the sky greys toward dawn
		await get_tree().create_timer(6.0).timeout
	if part == 6 and wolves < 2:
		_spawn_wolf(width - 80.0)      # it has followed the smell of the birth


func _lift() -> void:
	carrying = true
	lamb.visible = false
	player.carry_set = "cradle"
	player.act = "carry"
	player.act_t = 0.0
	player.carry_free = true
	player.calm = true


## He cannot fight with the lamb in his arms. He lays it down, and it lies still where it is put.
func _lay() -> void:
	carrying = false
	player.act = ""
	player.carry_free = false
	player.calm = false
	lamb.global_position = on_ground(player.global_position.x + player.facing * 30.0)
	lamb.stay = lamb.global_position.x
	lamb.pose = "lamb_wake"
	lamb.pose_once = true
	lamb.pose_t = 99.0
	lamb.safe = true
	lamb.visible = true
	show_tip("It lies where he put it.  His hands are free", 4.0)


func _lift_again() -> void:
	if part != 6 or carrying:
		return
	_lift()


## Home: the lamb set down by the fold stands for the first time, and follows her in.
func _home() -> void:
	part = 7
	lay_task["on"] = false
	lift_task["on"] = false
	Game.cinematic = true
	player.act = ""
	player.carry_free = false
	player.calm = false
	carrying = false
	player.facing = -1
	lamb.global_position = on_ground(FOLD + 120.0)
	lamb.stay = FOLD + 120.0
	lamb.face = -1.0
	lamb.visible = true
	lamb.pose = "lamb_stand"
	lamb.pose_once = true
	lamb.pose_t = 0.0
	lamb.pose_fps = 6.0
	rachel.stay = FOLD + 40.0
	Game.music("anointing", 4.0)
	if not Game.fast:
		create_tween().tween_property(self, "dark_amount", 0.0, 6.0)
	await say(["n_lamb_dawn"])
	lamb.pose = "lamb_totter"
	lamb.pose_once = false
	lamb.pose_fps = 9.0
	lamb.stay = FOLD + 60.0          # it totters after her
	if not Game.fast:
		await get_tree().create_timer(3.0).timeout
	for id in ["rachel", "lamb"]:
		Game.flock_at(id, "")
	Game.cinematic = false
	complete()


func _on_respawn() -> void:
	if wolf != null and is_instance_valid(wolf):
		wolf.queue_free()
	wolf = null
	if part == 2:
		wolves = 0
		rachel.calm = 0.0
	if part == 6:
		# he is put back on the path home with the lamb in his arms, and she at his side
		wolves = 1
		_lift()
		rachel.carried = false
		rachel.global_position = on_ground(player.global_position.x + 60.0)
		if not rachel in followers:
			rachel.gathered = true
			rachel.follow_index = 0
			followers.append(rachel)
		_spawn_wolf(minf(width - 80.0, player.global_position.x + 900.0))


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player):
		return
	player_light = 150.0 if part >= 6 else 80.0
	fire_light["r"] = 420.0 + sin(Time.get_ticks_msec() * 0.007) * 30.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	# her cries carry from the rocks while he looks for her
	if part == 1 and not Game.cinematic:
		bleat_t -= delta
		if bleat_t <= 0.0:
			bleat_t = rng.randf_range(5.0, 8.0)
			var far := absf(BIRTH_X - player.global_position.x)
			Game.sfx("sheep", clampf(-4.0 - far / 160.0, -24.0, -4.0), 0.15, 0.92)
	if part == 2 and not Game.cinematic:
		_labour(delta)
	if part == 6:
		lay_task["x"] = player.global_position.x
		lay_task["on"] = carrying
		lift_task["x"] = lamb.global_position.x
		lift_task["on"] = not carrying
		if carrying:
			# the way back is where he would be set down again if she were taken
			if player.global_position.x < checkpoints[cp_index] - 500.0:
				checkpoints[cp_index] = player.global_position.x
			if player.global_position.x < FOLD + 170.0 and absf(rachel.global_position.x - player.global_position.x) < 420.0 \
					and not rachel.carried and not Game.cinematic:
				_home()
	set_goal(_goal_now())


func _goal_now() -> String:
	match part:
		0:
			return "Count the ewes in the fold"
		1:
			if torch_t <= 0.0 and absf(player.global_position.x - FIRE) < 900.0:
				return "Take a brand from the fire, and find the ewe that went off alone"
			return "Find the ewe that went off alone, east among the rocks"
		2:
			if _wolf_near(BIRTH_X, 560.0):
				return "Drive the wolf off"
			return "Keep her quiet with the lyre (R), and stay by her"
		3:
			return "Rub the lamb dry with grass" if has_grass else "Fetch dry grass from under the rock shelf"
		4:
			return "Lay the lamb at its mother's head"
		5:
			return "Gather up the lamb"
		6:
			if not carrying:
				return "Take up the lamb again" if not _wolf_near(player.global_position.x, 600.0) else "Drive the wolf off the ewe"
			if rachel.carried:
				return "Lay the lamb down, and go after the ewe"
			return "Walk home to the fold, west, at her pace"
	return "Home to the fold"
