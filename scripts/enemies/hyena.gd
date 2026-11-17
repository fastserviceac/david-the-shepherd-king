extends "res://scripts/enemies/beast.gd"
## The hyena, a timid scavenger of the night. It never fights. It slinks in out of the dark toward the sheep that
## is farthest from him and comes on only while he is far off or looking elsewhere. Faced within reach it cringes
## and backs away. A blow, a stone, or his running at it sends it off into the dark; it comes back after a pause,
## each time from the side he is not facing. Left at a sheep for a few seconds it takes it. After it has been
## sent off three times it gives up for good.
## Frames (art/hyena/anim): slink, run, cringe, hurt. Canvas height factor 1.4.

const NEAR := 260.0           # faced this close it stops and cringes
const FAR := 380.0            # farther than this it needs no care
const HOLD := 2.5             # seconds at a sheep before it takes it
const GIVE_UP := 3

var state := "slink"
var st := 0.0
var prey = null                # the sheep it is slinking toward
var at_t := 0.0                # how long it has been left at the sheep
var sends := 0                 # times he has sent it off
var taken := 0                 # sheep it has got
var hurt_t := 0.0


func _init_enemy() -> void:
	anim = "hyena"
	first_set = "slink"
	stride = 150.0
	hp = 99          # it has no strength to wear down: it is only ever sent off, three times
	lesser = true
	speed = 170.0
	hit_r = 26.0
	hit_h = 30.0
	body_r = 14.0
	touch_on = false      # it never fights
	roams = true
	stagger = 0.0


## Is he looking at it, from a distance short enough to matter?
func _watched(within: float) -> bool:
	var toward: bool = (global_position.x - player.global_position.x) * float(player.facing) > 0.0
	return toward and absf(to_player()) < within


func _ai(delta: float) -> void:
	st -= delta
	hurt_t = maxf(0.0, hurt_t - delta)
	match state:
		"slink":
			_slink(delta)
		"flee":
			_run_off(delta)
		"gone":
			velocity.x = 0.0
			if st <= 0.0:
				_return()
	keep_in_level()
	track(state, st)


func _slink(delta: float) -> void:
	if not is_prey(prey) or claimed(prey):
		prey = _weakest()
	var dx := to_player()
	# a man running at it: it does not wait to see whether he means it
	if absf(dx) < 300.0 and absf(player.velocity.x) > 175.0 and signf(player.velocity.x) == signf(-dx):
		_send_off()
		return
	if _watched(NEAR):      # faced within reach: it cringes, and backs away
		face_player()
		at_t = maxf(0.0, at_t - delta)
		velocity.x = move_toward(velocity.x, -dir * 110.0, 900.0 * delta)
		return
	if _watched(FAR) or prey == null:      # watched from a little farther: it holds still
		face_player()
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	var to: float = prey.global_position.x - global_position.x
	dir = 1 if to >= 0.0 else -1
	if absf(to) > 34.0:
		at_t = 0.0
		velocity.x = move_toward(velocity.x, dir * speed, 900.0 * delta)
		return
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)      # at the sheep: left there, it takes it
	at_t += delta
	prey.worried = 0.25
	prey.threat = maxf(prey.threat, minf(at_t / (HOLD * float(Game.diff()["warning"])), 1.0) * 0.97)
	level.sheep_in_danger()
	if at_t >= HOLD * float(Game.diff()["warning"]):
		var s = prey
		taken += 1
		prey = null
		at_t = 0.0
		level.sheep_taken(s)
		_go_dark(3.0)
		if taken == 2:
			level.show_tip("It comes on only while you look away.  Face it and it will not come near", 6.0)


## The sheep farthest from him: the one nobody is watching.
func _weakest():
	var best = null
	var far := -1.0
	for s in get_tree().get_nodes_in_group("sheep"):
		if not is_prey(s) or absf(s.global_position.y - global_position.y) > 120.0:
			continue
		var d: float = absf(s.global_position.x - player.global_position.x)
		if d > far:
			far = d
			best = s
	return best


func hit(_dmg: int, from_dir: int, _kind: String) -> void:
	if fleeing or state != "slink":
		return
	flash = 0.12
	Game.burst(get_parent(), global_position + Vector2(0, -hit_h * 0.46), Color(1.0, 0.92, 0.7, 0.9), 8, 140.0)
	Game.sfx("hit", -4.0, 0.1)
	recoil = 1.0
	recoil_dir = float(from_dir)
	hurt_t = 0.4
	_send_off()


## Away into the dark, as fast as it can go. The third time it does not come back.
func _send_off() -> void:
	sends += 1
	at_t = 0.0
	if sends >= GIVE_UP:
		drive_off()
		return
	state = "flee"
	st = 2.0
	flee_dir = -1.0 if to_player() > 0.0 else 1.0


func _run_off(delta: float) -> void:
	dir = int(flee_dir)
	velocity.x = move_toward(velocity.x, flee_dir * 420.0, 2000.0 * delta)
	modulate.a = move_toward(modulate.a, 0.0, delta * 0.9)
	if st <= 0.0:
		_go_dark(2.5)


func _go_dark(seconds: float) -> void:
	state = "gone"
	st = seconds + randf() * 1.5
	modulate.a = 0.0
	velocity.x = 0.0
	touch_on = false


## It is back, out of the dark on the side he is not facing.
func _return() -> void:
	var side: float = -float(player.facing)
	var x := clampf(player.global_position.x + side * 640.0, 60.0, level.width - 60.0)
	if absf(x - player.global_position.x) < 400.0:      # no room on that side: the other
		x = clampf(player.global_position.x - side * 640.0, 60.0, level.width - 60.0)
	global_position = level.on_ground(x)
	velocity = Vector2.ZERO
	modulate.a = 1.0
	prey = null
	at_t = 0.0
	state = "slink"


func _draw() -> void:
	if state == "gone":
		return
	if fleeing or state == "flee":
		put(by_dist("run", 210.0), 0.46)
	elif hurt_t > 0.0:
		put(by_clock("hurt", 14.0), 0.46)
	elif _watched(FAR):      # watched: crouched low, tail tucked
		put(by_clock("cringe", 10.0), 0.46)
	else:
		put(by_dist("slink"), 0.46)
