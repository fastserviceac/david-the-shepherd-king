extends "res://scripts/enemies/beast.gd"
## The leopard. "Like a leopard I will lurk by the path" (Hosea 13:7).
## It lies still on a rock top above the way and only its tail moves. When a man or a sheep passes beneath it
## springs. If it is seen first and struck with a stone while it lurks it is flushed down, dazed, and has to fight
## in the open, where the staff lands. After any spring it stands open for a moment, then bounds back to the
## nearest perch and lies in wait again. It would sooner take a sheep that is nearer than the man.
## Frames (art/leopard/anim): lurk, spring, land, walk, run, hurt. Canvas height factor 1.4 (1.8 for spring and land).

const RANGE := 260.0          # how far to either side a passer-by is within its spring
const REST := 1.2             # after it is back on its perch, how long before it will spring again

var state := "lurk"
var st := 1.0
var perches: Array = []        # the tops of the rock it lies on, the middle of each, as the level gave them
var perch := Vector2.ZERO      # the one it is on or going to
var wind := 0.0                # the gather before the spring
var aim = null                 # the sheep it springs at (null: at him)
var at_sheep = null            # the sheep it has landed on
var arcing := false
var arc_a := Vector2.ZERO
var arc_b := Vector2.ZERO
var arc_u := 0.0
var arc_dur := 0.45
var arc_h := 90.0
var arc_then := "land"
var springs_hit := 0           # times it has caught him


func _init_enemy() -> void:
	anim = "leopard"
	first_set = "lurk"
	stride = 230.0
	hp = 6
	lesser = true
	speed = 160.0
	hit_r = 30.0
	hit_h = 32.0
	body_r = 15.0
	touch_dmg = 2
	touch_r = 34.0
	touch_on = false
	roams = true
	stagger = 0.1


func _ready() -> void:
	super._ready()
	if not perches.is_empty():
		perch = _nearest_perch()


func _on_touch() -> void:
	springs_hit += 1
	if springs_hit == 2:
		level.show_tip("It lies on the rocks above the path.  A stone flushes it down, and then the staff can reach", 6.0)


func _nearest_perch() -> Vector2:
	var best: Vector2 = perches[0]
	for p in perches:
		if absf(p.x - global_position.x) < absf(best.x - global_position.x):
			best = p
	return best


func _ai(delta: float) -> void:
	st -= delta
	touch_on = arcing and arc_then == "land"
	if arcing:
		_fly(delta)
		return
	match state:
		"lurk":
			_lurk()
		"spring":
			_wind(delta)
		"land":
			_land(delta)
		"dazed":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				state = "stalk"
		"stalk":
			_stalk(delta)
		"retreat":
			_retreat(delta)
	keep_in_level()
	track(state, st)


## Whoever passes beneath: he, or a sheep if one is nearer. Returns [position, sheep or null], or an empty array.
func _victim(below: bool, reach: float) -> Array:
	var best: Array = []
	var best_d := reach
	var cands: Array = [[player.global_position, null]]
	for s in get_tree().get_nodes_in_group("sheep"):
		if is_prey(s):
			cands.append([s.global_position, s])
	for c in cands:
		var p: Vector2 = c[0]
		var dx := absf(p.x - global_position.x)
		var under: bool = p.y - global_position.y > 30.0
		if dx < best_d and (under or not below) and absf(p.y - global_position.y) < 320.0:
			best_d = dx
			best = c
	return best


func _lurk() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * get_physics_process_delta_time())
	face_player()
	if st > 0.0:
		return
	var v := _victim(true, RANGE)
	if not v.is_empty():
		_gather(v[1])


func _gather(sheep) -> void:
	aim = sheep
	state = "spring"
	wind = 0.35 * float(Game.diff()["warning"])
	at_sheep = null


func _wind(delta: float) -> void:
	velocity.x = 0.0
	wind -= delta
	var to: float = (aim.global_position.x if is_instance_valid(aim) else player.global_position.x) - global_position.x
	dir = 1 if to >= 0.0 else -1
	if wind <= 0.0:
		var p: Vector2 = aim.global_position if is_instance_valid(aim) else player.global_position
		var bx := p.x + dir * 24.0
		var gy: float = level.ground_y(bx)
		_start_arc(Vector2(bx, p.y if is_nan(gy) else gy), 0.42, 90.0, "land")
		Game.sfx("lion_growl", -9.0, 0.2)


func _start_arc(to: Vector2, dur: float, h: float, then: String) -> void:
	arcing = true
	arc_a = global_position
	arc_b = to
	arc_u = 0.0
	arc_dur = dur
	arc_h = h
	arc_then = then


## A scripted flight: the spring, the bound back to the rock, the drop of a flushed beast.
func _fly(delta: float) -> void:
	arc_u += delta / arc_dur
	var u := minf(arc_u, 1.0)
	global_position = arc_a.lerp(arc_b, u) + Vector2(0, -sin(u * PI) * arc_h)
	velocity = Vector2.ZERO
	if arc_u >= 1.0:
		arcing = false
		global_position = arc_b
		match arc_then:
			"land":
				state = "land"
				st = 1.0 * float(Game.diff()["warning"])
				at_sheep = aim if is_instance_valid(aim) and absf(aim.global_position.x - global_position.x) < 70.0 else null
				Game.sfx("lion_land", -8.0)
			"lurk":
				state = "lurk"
				st = REST
				perch = arc_b
			"drop":
				state = "dazed"
				st = 1.8


## Open after a spring, hit or miss. On a sheep it stays to maul it until he comes: he must.
func _land(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if at_sheep != null:
		if not is_prey(at_sheep) or absf(at_sheep.global_position.x - player.global_position.x) > 620.0:
			at_sheep = null      # out of his sight it leaves the sheep alone: he must have the chance to stop it
		else:
			at_sheep.worried = 0.25
			level.sheep_in_danger()
			return
	if st <= 0.0:
		state = "retreat"
		st = 6.0


## Out in the open it goes on at them on foot, and springs from the ground.
func _stalk(delta: float) -> void:
	var v := _victim(false, 420.0)
	if v.is_empty():
		_return_to_perch()
		return
	var to: float = v[0].x - global_position.x
	dir = 1 if to >= 0.0 else -1
	velocity.x = move_toward(velocity.x, dir * speed, 900.0 * delta)
	if absf(to) < 190.0:
		_gather(v[1])


func _retreat(delta: float) -> void:
	if perches.is_empty():
		state = "stalk"
		return
	perch = _nearest_perch()
	dir = 1 if perch.x >= global_position.x else -1
	velocity.x = move_toward(velocity.x, dir * 430.0, 2400.0 * delta)
	if absf(perch.x - global_position.x) < 90.0 or st <= 0.0:
		_return_to_perch()


func _return_to_perch() -> void:
	if perches.is_empty():
		return
	perch = _nearest_perch()
	state = "retreat"
	_start_arc(perch, 0.7, 120.0, "lurk")


func hit(dmg: int, from_dir: int, kind: String) -> void:
	if fleeing or arcing or (state == "spring" and wind <= 0.0):
		return      # in the air, nothing of his reaches it
	var was := state
	super.hit(dmg, from_dir, kind)
	if fleeing:
		return
	at_sheep = null
	match was:
		"lurk", "spring":      # seen first and struck where it lay: down off the rock, dazed, to fight on the ground
			var to := Vector2(global_position.x - from_dir * 70.0, 0.0)
			var gy: float = level.ground_y(to.x)
			to.y = global_position.y if is_nan(gy) else gy
			_start_arc(to, 0.4, 30.0, "drop")
			state = "dazed"
		"land":
			state = "retreat"
			st = 6.0


func _draw() -> void:
	var sc := 0.52
	if arcing and arc_then == "land":      # the spring itself
		put(by_u("spring", 0.3 + 0.7 * arc_u), sc, 1.8)
	elif arcing and arc_then == "lurk":
		put(by_dist("run"), sc)
	elif arcing:
		put(by_clock("hurt", 14.0), sc)
	else:
		match state:
			"lurk":      # still, and only the tail moves
				put(by_clock("lurk", 6.0), sc)
			"spring":    # gathering itself
				put(by_u("spring", (1.0 - wind / (0.35 * float(Game.diff()["warning"]))) * 0.3), sc, 1.8)
			"land":
				put(by_u("land", 1.0 - st / st0), sc, 1.8)
			"dazed":
				put(by_clock("hurt", 14.0), sc)
			"retreat":
				put(by_dist("run"), sc)
			_:
				put(by_dist("walk"), sc)
