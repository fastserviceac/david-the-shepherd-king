extends "res://scripts/levels/level_base.gd"
## 1.7 The Night Watch. The lamb is home; the rest of the night is still to keep. Beasts come in the watches
## of the night from both sides, the flock breaks and must be called back, the fire must be fed. Then dawn.

const BASE := 575.0
const FOLD := 1500.0
const FIRE := 1720.0
const SEAT := 1290.0
var seat_rock: Sprite2D
var lyre_prop: Sprite2D
const X0 := 520.0
const X1 := 2480.0

var flock: Array = []
var out: Array = []            # sheep that have broken from the fold
var hour := 0
var holder := {"run": 0, "beasts": [], "warning": 1.0}
var fire_level := 1.0
var fire_light: Dictionary
var fire_glow: Sprite2D
var fire_task: Dictionary
var rest_task: Dictionary
var fed := false
var rested := false


func _setup() -> void:
	birds = false
	ambience = "night"
	mood = "theme_still"
	backdrop_art = "res://art/watch_backdrop.png"
	midground_art = "res://art/watch_mid.png"
	mid_tint = Color(0.6, 0.66, 0.9)
	width = 3000.0
	pal.merge({
		"mist": Color(0.6, 0.72, 1.0, 0.08),
		"grass": Color(0.34, 0.44, 0.75), "ground": Color(0.3, 0.35, 0.56), "char": Color(0.64, 0.7, 0.94),
		"sky_top": Color(0.02, 0.04, 0.14), "sky_mid": Color(0.08, 0.13, 0.33), "sky_bot": Color(0.3, 0.38, 0.62),
		"sun_pos": Vector2(0.7, 0.3), "sun_col": Color(0.85, 0.9, 1.0), "sun_size": 0.03, "stars": 1.0,
		"far": Color(0.26, 0.33, 0.56), "near": Color(0.08, 0.1, 0.22), "rim": Color(0.7, 0.8, 1.0),
		"wool": Color(0.82, 0.86, 0.96), "mote": Color(0.7, 0.8, 1.0, 0.4),
	}, true)
	segments = [make_ground(0.0, width, BASE, 8.0, 1.3)]
	checkpoints = [150.0, 1080.0]
	Game.save["has_sling"] = true


func _populate() -> void:
	# off the path: past the fold, a flat rock under the whole sky
	add_perch(2560.0, 62.0, 120.0)
	var rock := add_perch(2720.0, 124.0, 180.0)
	add_light(rock + Vector2(0, -40), 130.0)
	add_place("stars", rock, "The Star Rock", "voice")
	set_dark(0.5)
	add_stone("watch_far", on_ground(2940.0))
	var at := on_ground(FOLD)
	add_sprite("res://art/props/fold.png", at + Vector2(0, 14), 1.6, 1)
	for i in 6:
		var s = add_sheep(FOLD - 100.0 + i * 38.0)
		s.gathered = true
		s.gatherable = false
		s.stay = s.position.x
		s.home_x = s.position.x
		flock.append(s)
	var lamb = add_sheep(110.0, null, true)
	lamb.gathered = true
	lamb.follow_index = 0
	followers.append(lamb)
	sheep_total = 0

	# the watchfire
	var fp := on_ground(FIRE)
	fire_glow = Game.glow(Color(1.0, 0.6, 0.25, 0.9), 170.0)
	fire_glow.position = fp + Vector2(0, -30)
	fire_glow.z_index = 3
	add_child(fire_glow)
	fire_glow.add_child(_flames())
	fire_light = add_light(fp + Vector2(0, -40), 520.0)
	# a flat stone to sit on
	var seat := add_sprite("res://art/props/rock_low.png", on_ground(SEAT) + Vector2(0, 8), 0.2, 2, pal["char"])
	seat_rock = seat
	seat.scale = Vector2(70.0 / seat.texture.get_width(), 30.0 / seat.texture.get_height())

	fire_task = add_task(FIRE - 50.0, "feed the fire", 1.3, func() -> void:
		fed = true
		fire_level = 1.0
		Game.sfx("fire", -2.0)
		Game.burst(self, fp + Vector2(0, -30), Color(1.0, 0.7, 0.3, 0.9), 18, 160.0))
	fire_task["on"] = false
	var lyre := add_sprite("res://art/props/lyre.png", on_ground(SEAT + 58.0) + Vector2(0, 4), 1.0, 3, Color(0.7, 0.7, 0.85))      # his kinnor, laid down by the stone
	lyre.scale = Vector2.ONE * (64.0 / lyre.texture.get_width())
	lyre_prop = lyre
	rest_task = add_task(SEAT, "sit, and look up", 2.0, _rest)
	rest_task["on"] = false

	add_hint(600.0, 150.0, "Bring the lamb to the fold")
	add_trigger(FOLD - 150.0, FOLD + 150.0, _keep_watch)


func begin() -> void:
	await say(["n_watch_intro"])


## The whole night, from whichever watch he had reached.
func _keep_watch() -> void:
	var run: int = holder["run"]
	if hour == 0:
		for s in followers:          # the lamb goes in with the rest
			s.stay = FOLD + 30.0
		await say(["n_watch_fold"])
		hour = 1
	Game.music("battle", 1.0)
	if hour == 1:
		await send_wave(X0, X1, 2, false, true, holder)
		if run != holder["run"]: return
		hour = 2
	if hour == 2:
		Game.music(mood, 2.0)
		await _stir()
		if run != holder["run"]: return
		hour = 3
	if hour == 3:
		Game.music("battle", 1.0)
		await send_wave(X0, X1, 3, true, true, holder)
		if run != holder["run"]: return
		hour = 4
	if hour == 4:
		Game.music(mood, 2.0)
		fire_level = 0.4
		fire_task["on"] = not fed
		rest_task["on"] = not rested
		if not fed:
			add_hint(FIRE - 50.0, 240.0, "The fire is low")
			await say(["n_watch_fire"])
		while not (fed and rested):
			await get_tree().physics_frame
			if run != holder["run"] or not is_inside_tree(): return
		hour = 5
	if hour == 5:
		Game.music("battle", 1.0)
		await send_wave(X0, X1, 4, true, true, holder)
		if run != holder["run"]: return
		await send_wave(X0, X1, 3, true, true, holder)
		if run != holder["run"]: return
		hour = 6
	# dawn
	Game.music("anointing", 4.0)
	if not Game.fast:
		create_tween().tween_property(self, "dark_amount", 0.0, 6.0)
	await say(["n_watch_dawn"])
	complete()


## The flock has the smell of the lion on it still: two break from the fold, one each way.
func _stir() -> void:
	var run: int = holder["run"]
	out = [flock[0], flock[5]]
	flock[0].stay = 800.0
	flock[5].stay = 2260.0
	for s in out:
		s.hop = 1.0
	Game.sfx("sheep", -5.0, 0.2)
	add_hint(FOLD, 240.0, "Q  call them back")
	await say(["n_watch_stir"])
	while not out.is_empty():
		await get_tree().physics_frame
		if run != holder["run"] or not is_inside_tree():
			return


func bring_back(s) -> void:
	if s in out:
		out.erase(s)
		s.stay = s.home_x
		s.hop = 1.0
		Game.sfx("sheep", -7.0, 0.15)
		Game.grow("voice", 1.0)


func shepherd_call(from: Vector2, reach: float, startle: bool) -> void:
	super.shepherd_call(from, reach, startle)
	for s in out.duplicate():
		if absf(s.global_position.x - from.x) < reach:
			bring_back(s)


## Between the watches he sits, and looks up.
func _rest() -> void:
	Game.cinematic = true
	player.facing = 1
	# he sits on the stone, takes up the kinnor and plays; at the psalm he lifts his face to the stars
	player.global_position = on_ground(SEAT + 22.0)
	player.velocity = Vector2.ZERO
	seat_rock.visible = false          # the stone he sits on is in his own frames
	lyre_prop.visible = false
	player.act = "lyre"
	player.act_t = 0.0
	Game.music("theme_tender", 3.0)
	await say(["n_watch_stars"])
	player.act = "lyre_up"
	player.act_t = 0.0
	await say(["ps8_3"])
	player.act = "lyre_rise"
	player.act_t = 0.0
	if not Game.fast:
		await get_tree().create_timer(1.0).timeout
	player.act = ""
	seat_rock.visible = true
	lyre_prop.visible = true
	player.hp = player.max_hp
	Game.cinematic = false
	rested = true


func _on_respawn() -> void:
	clear_wave(holder)
	for s in out.duplicate():
		bring_back(s)
	add_trigger(FOLD - 150.0, FOLD + 150.0, _keep_watch)


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player):
		return
	player_light = 120.0
	for s in out.duplicate():
		if s.global_position.distance_to(player.global_position) < 70.0:
			bring_back(s)
	# the fire sinks through the night unless it is fed
	if hour >= 1 and hour < 6 and not Game.cinematic:
		fire_level = maxf(0.3, fire_level - delta * 0.006)
	fire_light["r"] = 210.0 + 330.0 * fire_level
	fire_glow.scale = Vector2.ONE * (0.6 + 0.6 * fire_level) * (1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.06)
	holder["warning"] = 0.7 + 0.6 * fire_level        # a good fire shows their eyes sooner
