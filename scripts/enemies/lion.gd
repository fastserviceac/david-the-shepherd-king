extends "res://scripts/enemies/enemy.gd"
## The lion. It is too quick to strike while it prowls: it slips a stone and springs back from the staff.
## It can only be hurt when it has committed itself: a stone while it crouches breaks the spring, a stone
## in the air brings it down hard, and after a pounce, a rake or a rush it stands spent for a moment.
## Three stages. First it pounces, and sometimes only pretends to. Then it starts to rake at close quarters,
## and to slink out of the light and come back along the ground at a run from whichever side its eyes show.
## Last, it springs twice together, and it turns on the lamb: get between them or turn it with a blow.

var state := "prowl"
var st := 1.6
var crouch := 0.0
var stage := 1
var home := Vector2.ZERO
var feint := false
var doubled := false
var rake_cd := 0.0
var rush_dir := 1
var edge_x := 0.0
var slips := 0
var lamb_x := NAN          # where the lamb lies, if the level has one for it to go after


func _init_enemy() -> void:
	anim = "lion"
	stride = 250.0
	hp = 16
	speed = 125.0
	hit_r = 38.0
	hit_h = 46.0
	body_r = 20.0
	touch_r = 40.0
	stagger = 0.0


func reset() -> void:
	hp = max_hp
	stage = 1
	state = "prowl"
	st = 1.8
	feint = false
	doubled = false
	modulate.a = 1.0
	global_position = home
	velocity = Vector2.ZERO


func is_open() -> bool:
	return state in ["recover", "reel"]


func can_clinch() -> bool:
	return is_open()


func hit(dmg: int, from_dir: int, kind: String) -> void:
	if fleeing or state == "roar" or state == "lurk":
		return
	if kind == "stone":
		match state:
			"crouch", "rake":           # caught as it gathers: the spring is broken
				state = "reel"
				st = 1.5
				super.hit(dmg, from_dir, kind)
			"pounce", "rush":           # struck in the air, or at full stretch: it comes down hard
				super.hit(dmg + 1, from_dir, kind)
				if not fleeing:
					state = "recover"
					st = 1.7
					velocity.x *= 0.3
			"hunt":                     # turned from the lamb
				super.hit(dmg, from_dir, kind)
				if not fleeing:
					state = "prowl"
					st = 0.6
			"recover", "reel":
				super.hit(dmg, from_dir, kind)
			_:
				_slip(from_dir)
	elif kind == "staff":
		if is_open() or player.opening_t > 0.0:
			super.hit(dmg, from_dir, kind)
		elif state == "hunt":
			super.hit(dmg, from_dir, kind)
			if not fleeing:
				state = "prowl"
				st = 0.5
		else:
			_slip(from_dir)
	else:
		super.hit(dmg, from_dir, kind)
	_stage_check()


## Too quick: it is gone from where the blow lands.
func _slip(from_dir: int) -> void:
	slips += 1
	kb = 0.22
	velocity = Vector2(from_dir * 330.0, -150.0)
	Game.sfx("swing", -10.0, 0.25)
	Game.burst(get_parent(), global_position + Vector2(0, -6), Color(0.75, 0.7, 0.62, 0.45), 6, 80.0)
	if slips == 2 or slips == 6:
		level.show_tip("Too quick to strike.  Catch it as it crouches, or when it is spent")


func _stage_check() -> void:
	if fleeing:
		return
	var s := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if s > stage:
		stage = s
		state = "roar"
		st = 1.1
		modulate.a = 1.0
		Game.sfx("lion_roar", 0.0, 0.0)
		level.player.shake = 10.0
		# the roar staggers a man standing in front of it; one crouched low keeps his feet
		if absf(to_player()) < 300.0 and not player.ducking and player.invuln <= 0.0:
			player.stun = maxf(player.stun, 0.7)
			player.velocity.x = signf(to_player()) * 220.0
		if stage == 3 and not is_nan(lamb_x):
			level.show_tip("It will go for the lamb.  Stand between them")


func _ai(delta: float) -> void:
	st -= delta
	rake_cd -= delta
	var dx := to_player()
	var warn := float(Game.diff()["warning"])
	var quick := 1.0 + 0.15 * (stage - 1)
	if state != "slink":
		modulate.a = move_toward(modulate.a, 1.0, delta * 4.0)
	match state:
		"prowl":
			touch_on = true
			face_player()
			var want := 0.0          # keep a stalking distance
			if absf(dx) > 330.0:
				want = dir * speed
			elif absf(dx) < 210.0:
				want = -dir * speed * 0.8
			velocity.x = move_toward(velocity.x, want, 700.0 * delta)
			if stage >= 2 and absf(dx) < 112.0 and rake_cd <= 0.0:
				state = "rake"       # he has come too close: a quick blow along the ground
				st = 0.4 * warn
				rake_cd = 2.4
			elif st <= 0.0:
				var r := randf()
				if stage == 3 and not is_nan(lamb_x) and r < 0.32:
					state = "hunt"
					Game.sfx("lion_growl", -1.0)
				elif stage >= 2 and r < (0.72 if stage == 3 else 0.5):
					state = "slink"
					edge_x = (min_x + 24.0) if global_position.x - min_x < max_x - global_position.x else (max_x - 24.0)
				else:
					state = "crouch"
					feint = randf() < 0.3
					Game.sfx("lion_growl", -3.0)
					st = (0.8 - 0.12 * (stage - 1)) * warn
		"roar":
			touch_on = false
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				state = "crouch"
				st = 0.5
		"crouch":
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if st <= 0.0 and is_on_floor():
				if feint:            # it only shifted its weight: now it comes
					feint = false
					st = 0.42 * warn
					_last_state = ""
				else:
					state = "pounce"
					st = 0.12
					touch_on = true
					velocity = Vector2(dir * clampf(absf(dx) * 1.55, 330.0, 640.0), -440.0)
		"pounce":
			if st <= 0.0 and is_on_floor():
				Game.sfx("lion_land", -2.0)
				level.player.shake = maxf(level.player.shake, 4.0)
				if stage == 3 and not doubled:      # it lands and is in the air again
					doubled = true
					state = "crouch"
					st = 0.3 * warn
					_last_state = ""
				else:
					doubled = false
					state = "recover"
					st = 1.15 / quick
		"rake":
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if st <= 0.0:
				var ahead := dx * dir
				if ahead > -10.0 and ahead < 130.0 and player.is_on_floor() and absf(player.global_position.y - global_position.y) < 90.0:
					player.hurt(1, global_position.x, "low")
				state = "recover"
				st = 0.75
		"slink":                 # out of the light, to the edge of the ridge
			touch_on = false
			dir = 1 if edge_x > global_position.x else -1
			velocity.x = move_toward(velocity.x, dir * 330.0, 1400.0 * delta)
			modulate.a = move_toward(modulate.a, 0.0, delta * 2.2)
			if absf(edge_x - global_position.x) < 30.0:
				if randf() < 0.45:      # it circles in the dark and may come from the other side
					edge_x = (max_x - 24.0) if edge_x < (min_x + max_x) * 0.5 else (min_x + 24.0)
					global_position.x = edge_x
				velocity.x = 0.0
				state = "lurk"
				st = 1.35 * warn
				Game.sfx("lion_growl", -6.0)
		"lurk":                  # only its eyes, low, on the side it will come from
			touch_on = false
			modulate.a = 1.0
			face_player()
			velocity.x = 0.0
			if st <= 0.0:
				state = "rush"
				st = 1.7
				rush_dir = dir
				Game.sfx("lion_roar", -6.0)
		"rush":                  # flat along the ground at full stretch: jump it, or roll through
			touch_on = true
			dir = rush_dir
			velocity.x = move_toward(velocity.x, rush_dir * 560.0, 3000.0 * delta)
			var past: bool = (player.global_position.x - global_position.x) * rush_dir < -210.0
			if st <= 0.0 or past or is_on_wall() or global_position.x <= min_x + 3.0 or global_position.x >= max_x - 3.0:
				state = "recover"
				st = 1.3 / quick
				Game.sfx("lion_land", -4.0)
		"hunt":                  # it has turned from him to the lamb
			touch_on = true
			dir = 1 if lamb_x > global_position.x else -1
			velocity.x = move_toward(velocity.x, dir * speed * 1.3, 700.0 * delta)
			if absf(lamb_x - global_position.x) < 70.0:
				if level.has_method("lamb_struck"):
					level.lamb_struck()
				hp = mini(max_hp, hp + 3)        # it takes heart from the kill it thinks it has
				state = "roar"
				st = 0.9
				Game.sfx("lion_roar", -2.0)
		"recover", "reel":
			touch_on = false
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if st <= 0.0:
				state = "prowl"
				st = randf_range(1.2, 2.0) / quick
	track(state, st)
	crouch = move_toward(crouch, 1.0 if state == "crouch" else 0.0, delta * 5.0)


func _draw() -> void:
	var u := 1.0 - st / st0
	match state:
		"lurk":     # nothing of it but two eyes in the dark
			eye(Vector2(dir * 26.0 - 6.0, -30.0), 2.8, 0.7 + 0.3 * sin(t * 7.0))
			eye(Vector2(dir * 26.0 + 6.0, -30.0), 2.8, 0.7 + 0.3 * sin(t * 7.0))
		"crouch", "rake":   # sinks low, haunches bunched: the warning before the spring
			show_frame(action_frame("crouch", u * 1.6), 0.66, 1.4)
		"pounce":   # the leap itself
			show_frame(action_frame("pounce", air_t / 0.6, 3, 21), 0.66, 1.8)
		"rush":     # low and long, eating the ground
			show_frame(walk_frame(), 0.66, 1.4, Vector2(1.12, 0.86))
		"recover":  # lands, then stands panting: the moment to strike
			if u < 0.25:
				show_frame(action_frame("pounce", u / 0.25, 21, 30), 0.66, 1.8)
			else:
				show_frame(FA.pingpong(FA.frames("lion", "pant"), t, 14.0), 0.66, 1.4)
		"reel":     # the spring broken: it shakes its head
			show_frame(FA.pingpong(FA.frames("lion", "pant"), t, 20.0), 0.66, 1.4, Vector2(1.0 + sin(t * 30.0) * 0.03, 0.96))
		"roar":
			show_frame(action_frame("roar", u), 0.66, 1.8)
		_:
			show_frame(walk_frame(), 0.66, 1.4)
