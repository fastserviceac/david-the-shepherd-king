extends "res://scripts/levels/level_base.gd"
## 1.6 The Lion's Ridge. Night. Above the cave, the lion that took the lamb.
## It is driven off and the lamb is rescued.

const Lion = preload("res://scripts/enemies/lion.gd")

var lion
var lamb
var arena_walls: Array = []
var lion_started := false
var end_x := 7750.0       # the foot of the ridge, where the way down ends
var carrying := false
var told := false
var descent := false      # the lamb has been lifted once: the way down has begun
var tended := false       # its wound is washed and bound
var spoken := false       # the last words of the night have begun
var rock: Dictionary = {} # what the lion's flight brought down across the path
var rock_rest := Vector2.ZERO
var water_wall: StaticBody2D
var pack: Array = []      # the jackals that have come to the smell of blood
var tend_task: Dictionary
var lay_task: Dictionary
var lift_task: Dictionary

const WATER_X := 4700.0   # rain standing in a hollow of the rock
const ROCK_X := 5010.0
const ROCK_LIP := 5298.0  # the edge of the step it goes over
const CLEFT_X := 6420.0   # a cleft in the crag, too narrow for a jackal
var _far := 0.0           # the farthest he has come, for the goal


func _setup() -> void:
	birds = false
	leaves = Color(0.6, 0.55, 0.6, 0.4)
	ambience = "night"
	backdrop_art = "res://art/s3_backdrop.png"
	midground_art = "res://art/s3_mid.png"
	mid_tint = Color(0.8, 0.84, 1.0)
	mood = "ridge"
	width = 8000.0
	pal.merge({
		"mist": Color(0.6, 0.72, 1.0, 0.11),
		"grass": Color(0.34, 0.44, 0.75), "ground": Color(0.3, 0.35, 0.56), "char": Color(0.6, 0.67, 0.92),
		"sky_top": Color(0.03, 0.05, 0.16), "sky_mid": Color(0.1, 0.16, 0.38), "sky_bot": Color(0.36, 0.45, 0.7),
		"sun_pos": Vector2(0.68, 0.3), "sun_col": Color(0.85, 0.9, 1.0), "sun_size": 0.085, "stars": 1.0,
		"far": Color(0.3, 0.38, 0.62), "near": Color(0.09, 0.11, 0.24), "rim": Color(0.7, 0.8, 1.0),
		"wool": Color(0.8, 0.84, 0.95), "mote": Color(0.7, 0.8, 1.0, 0.45),
	}, true)
	segments = [
		make_ground(0.0, 1210.0, 610.0, 10.0, 0.3),
		make_ground(1200.0, 2570.0, 530.0, 6.0, 1.2),
		make_ground(2560.0, 4420.0, 468.0, 5.0, 2.2),
		# the way down, in long steps, with the lamb on his shoulders
		make_ground(4410.0, 5320.0, 510.0, 6.0, 0.6),
		make_ground(5310.0, 6240.0, 556.0, 6.0, 1.7),
		make_ground(6230.0, width, 604.0, 8.0, 0.2),
	]
	platforms.append(Rect2(1110.0, 570.0, 100.0, 60.0))
	checkpoints = [150.0, 1290.0, 2440.0, 4300.0, 6300.0]
	ledge(1960.0, 114.0, 120.0)
	if Game.save.get("has_sling", false) == false:
		Game.save["has_sling"] = true


func _populate() -> void:
	# off the path: beyond the leap, the edge of the ridge and the whole wilderness below
	var look := add_perch(2140.0, 182.0, 230.0)
	add_place("outlook", look, "The Outlook", "eye")
	for tx in [260.0, 820.0, 1420.0, 2320.0, 2720.0, 4100.0]:
		add_tree(tx, rng.randf_range(0.9, 1.5), rng.randf() < 0.7)

	add_jackal(700.0, 420.0, 1050.0)
	add_stone("s3_start", on_ground(52.0))
	add_stone("s3_leap", Vector2(2020.0, platforms[1].position.y))

	# how to fight, as a reminder on the way up
	add_hint(820.0, 150.0, "L  dodge")
	add_hint(1150.0, 150.0, "↓  duck")
	add_hint(1420.0, 150.0, "E  seize a spent beast")
	# the ridge's own scavengers, drawn by the lion's kill
	add_jackal(1800.0, 1400.0, 2400.0)
	add_jackal(2150.0, 1400.0, 2400.0)
	# the gift of this place: the running leap. Its trial is a run: from the watchfire to the light before it fades,
	# with the jackals in the way. There is no time to fight them; they have to be got past
	add_gift("feet", 2330.0, func() -> bool: return run_ok, "The light fades.  Reach it from the watchfire at a run")
	add_block(Rect2(2575.0, on_ground(2500.0).y - 110.0, 90.0, 80.0))
	add_trigger(2950.0, 3100.0, _start_lion, false)

	# the lamb, waiting beyond the lion
	lamb = add_sheep(3950.0, null, true)
	lamb.gatherable = false
	sheep_total = 0
	_way_down()
	_resume(checkpoints[clampi(start_checkpoint, 0, checkpoints.size() - 1)])


## Begun again from a watchfire on the way down: the lion is beaten and the lamb is on his shoulders.
func _resume(from: float) -> void:
	if from < 4000.0 or Game.backdrop:
		return
	lion_started = true
	descent = true
	lamb.gathered = true
	_lift()
	if from > CLEFT_X - 200.0:
		tended = true
		water_wall.queue_free()
		rock["on"] = false
		rock["body"].position = rock_rest


const RUN_FROM := 1340.0
const RUN_TO := 2290.0
const RUN_TIME := 6.0
var run_ok := false
var run_t := -1.0          # seconds left of the run; below zero when he is not running it
var run_spent := false     # he has failed this attempt and must go back to begin again


func _process(delta: float) -> void:
	super._process(delta)
	if run_ok or Game.has("feet") or not is_instance_valid(player) or Game.cinematic or respawning:
		return
	var px: float = player.global_position.x
	if px < RUN_FROM - 40.0:            # back at the watchfire: the next crossing starts a new run
		run_spent = false
		run_t = -1.0
	elif run_t < 0.0 and not run_spent and px >= RUN_FROM and px < RUN_FROM + 120.0 and player.velocity.x > 60.0:
		run_t = RUN_TIME
		Game.sfx("gather", -8.0, 0.0)
	elif run_t >= 0.0:
		run_t -= delta
		if px >= RUN_TO:
			run_ok = true
			run_t = -1.0
			show_tip("In time", 2.5)
			Game.sfx("gather", -3.0, 0.0)
		elif run_t <= 0.0:
			run_t = -1.0
			run_spent = true
			show_tip("Too slow.  Go back to the watchfire and run it again", 5.0)
		else:
			show_tip(Game.t("Run!") + "   %d" % int(ceil(run_t)), 0.3)


func begin() -> void:
	if not Game.main.intro.has_story("ridge"):      # the film before this section speaks the line itself
		await say(["n_s3_intro"])


func _start_lion() -> void:
	if descent:
		return
	if lion_started:
		# he was beaten back to the watchfire and has come again: the ridge closes behind him once more
		if arena_walls.is_empty() and is_instance_valid(lion) and not lion.fleeing:
			arena_walls = [add_wall(2640.0), add_wall(4060.0)]
			Game.music("battle", 0.8)
		return
	lion_started = true
	arena_walls = [add_wall(2640.0), add_wall(4060.0)]
	await say(["1sam17_34"])
	lion = Lion.new()
	lion.level = self
	lion.player = player
	lion.min_x = 2680.0
	lion.max_x = 4020.0
	lion.home = on_ground(3800.0)
	lion.position = lion.home
	lion.dir = -1
	lion.lamb_x = lamb.position.x
	add_child(lion)
	boss = lion
	boss_name = "The Lion"
	Game.music("battle", 0.8)
	lion.defeated.connect(_lion_defeated)


## The lion has reached the lamb. It is not killed, but it is a blow to him, and heart to the lion.
func lamb_struck() -> void:
	lamb.hop = 1.0
	Game.sfx("lamb", 0.0, 0.1)
	player.shake = maxf(player.shake, 8.0)
	Game.burst(self, lamb.position + Vector2(0, -20), Color(1.0, 0.9, 0.8, 0.8), 12, 140.0)
	show_tip("The lamb!  Keep the lion from it")


func _lion_defeated() -> void:
	boss = null
	Game.music("anointing", 3.0)
	for w in arena_walls:
		w.queue_free()
	arena_walls.clear()
	lamb.gatherable = true
	add_glow(lamb.position + Vector2(0, -16), Color(1.0, 0.9, 0.7, 0.5), 200.0)
	add_hint(3950.0, 120.0, "Go to the lamb")


func _on_respawn() -> void:
	if is_instance_valid(lion) and not lion.fleeing:
		lion.reset()
		for w in arena_walls:      # the way back up to it must be open, or he is shut out of his own fight
			w.queue_free()
		arena_walls.clear()


func _on_sheep(s) -> void:
	# he lifts the lamb onto his shoulders. The fight is over; what is left is the long way down with it
	descent = true
	player.facing = 1
	_lift()
	for w in arena_walls:
		if is_instance_valid(w):
			w.queue_free()
	arena_walls.clear()
	add_hint(4150.0, 150.0, "Carry it down off the ridge")
	say(["n_s3_end"])


func _lift() -> void:
	carrying = true
	lamb.visible = false
	lamb.stay = NAN
	player.act = "carry"
	player.act_t = 0.0
	player.carry_free = true
	player.calm = true


## The lion had it in its mouth. Before anything else he sees to the wound.
func _tend() -> void:
	tended = true
	if is_instance_valid(water_wall):
		water_wall.queue_free()
	Game.sfx("step", -4.0, 0.3)
	Game.sfx("lamb", -6.0, 0.1)
	player.hp = player.max_hp
	show_tip("He washes the torn shoulder and binds it with a strip from his cloak.  The lamb lies quiet", 6.5)


## Pushed to the edge of the step, the rock goes over and comes to rest at its foot.
func _rock_over() -> void:
	rock["on"] = false
	var body: StaticBody2D = rock["body"]
	if Game.fast:
		body.position = rock_rest
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(body, "position", rock_rest, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(rock["sp"], "rotation", TAU, 0.42)
	tw.chain().tween_callback(func() -> void:
		Game.sfx("hit", -2.0, 0.1)
		player.shake = maxf(player.shake, 6.0)
		Game.burst(self, rock_rest + Vector2(0, 25), Color(0.7, 0.72, 0.85, 0.6), 16, 150.0))


func _pack_left() -> int:
	var n := 0
	for j in pack:
		if is_instance_valid(j) and not j.fleeing:
			n += 1
	return n


## He cannot fight with the lamb on his shoulders. In the cleft no jackal can come at it.
func _lay() -> void:
	carrying = false
	player.act = ""
	player.carry_free = false
	player.calm = false
	lamb.global_position = on_ground(CLEFT_X - 6.0)
	lamb.stay = CLEFT_X - 6.0
	lamb.safe = true
	lamb.visible = true
	show_tip("It lies still in the cleft.  His hands are free", 4.5)


func _lift_again() -> void:
	_lift()
	if _pack_left() == 0:
		_last_words()


func _last_words() -> void:
	if spoken:
		return
	spoken = true
	await say(["n_s3_remember", "1sam17_37"])
	told = true
	if is_instance_valid(player) and carrying and player.global_position.x > end_x - 60.0:
		complete()


## The way down with the lamb. He walks, and cannot run, leap or fight; each thing in his way wants another answer.
func _way_down() -> void:
	if Game.backdrop:
		return
	for tx in [4560.0, 5420.0, 5700.0, 6600.0, 7050.0, 7450.0]:
		add_tree(tx, rng.randf_range(0.9, 1.5), rng.randf() < 0.7)

	# rain standing in a hollow of the rock: he washes the wound the lion's teeth left, and binds it
	var pool := on_ground(WATER_X)
	add_glow(pool + Vector2(0, -8), Color(0.6, 0.75, 1.0, 0.35), 150.0)
	add_painter(pool + Vector2(0, 4), 3, func(ci: CanvasItem) -> void:
		# seen low from the side: wet rock darkening to still water, and the moon broken on it. Soft-edged,
		# in the colours of the ground round it, until there is a painting of it
		var f := sin(Time.get_ticks_msec() * 0.002)
		var tone: Color = pal.get("char", Color(1, 1, 1))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.17))
		for k in 7:
			var u := k / 6.0
			ci.draw_circle(Vector2(0.0, -3.0 * k), 78.0 - 7.0 * k, (Color(0.06, 0.08, 0.14).lerp(Color(0.2, 0.28, 0.46), u) * tone).lerp(Color(0, 0, 0), 0.15) * Color(1, 1, 1, 0.18 + 0.1 * u))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.05))
		for g in [[10.0, -90.0, 22.0, 0.28], [-22.0, -30.0, 12.0, 0.2], [30.0, -150.0, 9.0, 0.16]]:
			ci.draw_circle(Vector2(g[0] + f * 4.0, g[1]), g[2], Color(0.85, 0.92, 1.0, g[3]))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE), true)
	tend_task = add_task(WATER_X, "wash the lamb's wound", 1.6, _tend)
	water_wall = add_wall(WATER_X + 250.0)
	add_trigger(WATER_X + 130.0, WATER_X + 236.0, func() -> void:
		if carrying and not tended:
			show_tip("The lamb is bleeding on his shoulders.  There was water in the rock just behind him", 5.0), false)

	# the lion went down this way in a hurry, and a rock came down after it. He cannot climb it with the lamb
	rock = add_pushable(ROCK_X, 58.0, 50.0, "res://art/props/rock_low.png", ROCK_X, ROCK_LIP)
	rock_rest = Vector2(5356.0, on_ground(5360.0).y - 17.0)
	rock["moved"] = func(nx: float) -> void:
		if nx >= ROCK_LIP - 0.5 and rock["on"]:
			_rock_over()
	add_trigger(ROCK_X - 140.0, ROCK_X - 50.0, func() -> void:
		if carrying:
			show_tip("A rock has come down across the path.  With the lamb he cannot climb it: he puts his shoulder to it", 6.0))

	# from the rocks above the path, two eyes: beaten, it watches him go
	var eyes := on_ground(5560.0) + Vector2(0, -150.0)
	for dx in [-7.0, 7.0]:
		add_glow(eyes + Vector2(dx, 0), Color(1.0, 0.85, 0.35, 0.9), 14.0)
	add_trigger(5420.0, 5520.0, func() -> void:
		if carrying:
			show_tip("It watches him go, from the rocks.  It does not come down", 5.5))
	add_trigger(5880.0, 5980.0, func() -> void:
		if carrying:
			show_tip("Far below, one spark in the dark: the watchfire at the fold", 5.5))

	# lower down the jackals have come to the smell of blood. He lays the lamb where they cannot reach it, and
	# takes up the staff once more
	var crag := add_sprite("res://art/props/rock_mid.png", on_ground(CLEFT_X) + Vector2(0, 10), 1.0, 1, pal.get("char", Color(1, 1, 1)))
	crag.scale = Vector2.ONE * (180.0 / crag.texture.get_width())
	lay_task = add_task(CLEFT_X, "lay the lamb in the cleft of the rock", 0.8, _lay)
	lay_task["again"] = true
	lift_task = add_task(CLEFT_X, "lift the lamb", 0.8, _lift_again)
	lift_task["again"] = true
	lift_task["on"] = false
	pack = [add_jackal(6840.0, 6620.0, 7220.0), add_jackal(7020.0, 6620.0, 7220.0)]
	add_trigger(6270.0, 6370.0, func() -> void:
		if carrying and _pack_left() > 0:
			show_tip("Jackals on the path below, come to the smell of blood.  He cannot fight with the lamb on his shoulders", 6.5))

	add_glow(on_ground(end_x + 160.0) + Vector2(0, -30.0), Color(1.0, 0.6, 0.25, 0.8), 120.0)
	add_trigger(end_x - 60.0, end_x + 90.0, func() -> void:
		if carrying and not spoken:
			_last_words()
		elif carrying and told:
			complete(), false)


## What he is to do now, from where things stand. Polled, so it is right at any checkpoint too.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_far = maxf(_far, player.global_position.x)
	if descent:
		lay_task["on"] = carrying and _pack_left() > 0
		lift_task["on"] = not carrying
	else:
		lay_task["on"] = false
		tend_task["on"] = false
	if descent and not tended:
		tend_task["on"] = true
	set_goal(_goal_now())


func _goal_now() -> String:
	if descent:
		if not tended:
			return "Wash the lamb's wound at the pool in the rock"
		if rock.get("on", false) and _far > ROCK_X - 140.0:
			return "Shoulder the fallen rock off the path"
		if _pack_left() > 0 and _far > 6260.0:
			if carrying:
				return "Lay the lamb in the cleft of the rock"
			return "Drive the jackals off the path"
		if not carrying:
			return "Lift the lamb"
		return "Carry the lamb down off the ridge, east"
	if not lion_started:
		return "Climb the ridge, east"
	if not is_instance_valid(lion) or boss != null:
		return "Beat the lion back from the lamb"
	if is_instance_valid(lamb) and not lamb.gathered:
		return "Go to the lamb, east"
	return "Carry the lamb down off the ridge, east"
