extends "res://scripts/enemies/enemy.gd"
## The lion. It is too quick to strike while it prowls: it slips a stone and springs back from the staff.
## It can only be hurt when it has committed itself: a stone while it crouches breaks the spring, a stone
## in the air brings it down hard, and after a pounce, a rake or a rush it stands spent for a moment.
## Three stages. First it pounces, and sometimes only pretends to. Then it starts to rake at close quarters,
## and to slink out of the light and come back along the ground at a run from whichever side its eyes show.
## Last, it springs twice together, and it turns on the lamb: get between them or turn it with a blow.
## It also vaults clean over him and rakes from behind (duck the leap, then skip back), follows a pounce with a
## rake when he stands too near where it lands, and in its last stage roars to stagger him before it springs.
## It cannot be stoned to death (1 Samuel 17:35: he went after it, struck it, took it by the beard). A stone may wear
## it down to half its strength and may break a spring or bring it down from the air, but it shrugs the next stone
## for a moment, and a man who stands off slinging at it is come for. The rest is the staff, in the moments it is spent.

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
var vault := false          # this spring goes over his head, to come at him from behind
var lamb_x := NAN          # where the lamb lies, if the level has one for it to go after
var wary := 0.0            # after a stone has told it shrugs the next ones off for this long
var far_slings := 0        # stones slung at it from a distance, lately
var far_t := 0.0
var prev_throw := 0.0
var fdist := 0.0           # ground covered, signed by the way it is facing: a backward step plays the walk backward
var dust_t := 0.0
var told_cap := false
var told_close := false
const STONE_FLOOR := 0.5   # the share of its strength a stone cannot take from it


func _init_enemy() -> void:
	anim = "lion"
	stride = 250.0
	hp = 20
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
	vault = false
	touch_kind = "body"
	touch_on = true
	modulate.a = 1.0
	global_position = home
	velocity = Vector2.ZERO
	kb = 0.0
	held = 0.0
	wary = 0.0
	far_slings = 0
	far_t = 0.0
	rake_cd = 0.0
	_last_state = ""


func is_open() -> bool:
	return state in ["recover", "reel"]


func can_clinch() -> bool:
	return is_open()


func hit(dmg: int, from_dir: int, kind: String) -> void:
	if fleeing or state == "roar" or state == "lurk":
		return
	if kind == "smooth":          # a smooth stone from the pouch: whatever it was doing, it reels
		var air := state in ["pounce", "rush"]
		state = "recover" if air else "reel"
		st = 1.7 if air else 1.5
		if air:
			velocity.x *= 0.3
		_unspring()
		Game.sfx("lion_roar", -6.0)
		wary = 2.2
		super.hit(_stone_dmg(dmg), from_dir, "stone")
	elif kind == "stone":
		if wary > 0.0 or _stone_dmg(dmg) <= 0:
			_shrug(from_dir)          # it has had a stone, or has had all the stones it will take
			return
		match state:
			"crouch", "rake":           # caught as it gathers: the spring is broken
				state = "reel"
				st = 1.5
				wary = 2.2
				super.hit(_stone_dmg(dmg), from_dir, kind)
			"pounce", "rush":           # struck in the air, or at full stretch: it comes down hard
				wary = 2.2
				super.hit(_stone_dmg(dmg + 1), from_dir, kind)
				if not fleeing:
					state = "recover"
					st = 1.7
					velocity.x *= 0.3
					_unspring()
			"hunt":                     # turned from the lamb
				wary = 2.2
				super.hit(_stone_dmg(dmg), from_dir, kind)
				if not fleeing:
					state = "prowl"
					st = 0.6
			"recover", "reel":
				wary = 2.2
				super.hit(_stone_dmg(dmg), from_dir, kind)
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


## How much of a stone's blow it feels: never enough to take it below half its strength. The rest is the staff's.
func _stone_dmg(dmg: int) -> int:
	var floor_hp := int(ceil(max_hp * STONE_FLOOR))
	return clampi(hp - floor_hp, 0, dmg)


## A stone it does not trouble itself over: a flick of the head, a spark, nothing more.
func _shrug(_from_dir: int) -> void:
	recoil = maxf(recoil, 0.25)
	flash = 0.05
	Game.sfx("stone_hit", -8.0, 0.2)
	Game.burst(get_parent(), global_position + Vector2(0, -hit_h * 0.6), Color(0.85, 0.8, 0.7, 0.6), 5, 80.0)
	if _stone_dmg(1) <= 0 and not told_cap:
		told_cap = true
		level.show_tip("Stones will not finish it.  Close with the staff when it is spent", 5.0)


## A spring that was broken in the air: the leap is over, and so is whatever kind of leap it was.
func _unspring() -> void:
	vault = false
	feint = false
	touch_kind = "body"


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
		_unspring()
		doubled = false
		Game.sfx("lion_roar", 0.0, 0.0)
		level.player.shake = 10.0
		# the roar staggers a man standing in front of it; one crouched low keeps his feet
		if absf(to_player()) < 300.0 and not player.ducking and player.invuln <= 0.0:
			player.stun = maxf(player.stun, 0.7)
			player.velocity.x = signf(to_player()) * 220.0
		if stage == 3 and not is_nan(lamb_x):
			level.show_tip("It will go for the lamb.  Stand between them")


## It turns to him, but not on every step of a man crossing under it: a hair's breadth either side of it, it keeps its facing.
func face_player() -> void:
	if absf(to_player()) > 26.0:
		dir = 1 if to_player() >= 0.0 else -1


func _ai(delta: float) -> void:
	st -= delta
	rake_cd -= delta
	wary = maxf(0.0, wary - delta)
	far_t -= delta
	if far_t <= 0.0:
		far_slings = 0
	var dx := to_player()
	# a man who stands off and slings at it is not left to: count his stones
	if player.throw_t > prev_throw + 0.15 and state != "hunt":
		if absf(dx) > 230.0:
			far_slings += 1
			far_t = 7.0
		else:
			far_slings = maxi(0, far_slings - 1)
	prev_throw = player.throw_t
	var need := 3 if float(Game.diff()["warning"]) <= 1.0 else 4
	var closing := far_slings >= need and state == "prowl"
	var warn := float(Game.diff()["warning"])
	var quick := 1.0 + 0.15 * (stage - 1)
	if state != "slink":
		modulate.a = move_toward(modulate.a, 1.0, delta * 4.0)
	match state:
		"prowl":
			touch_on = true
			face_player()
			var want := 0.0          # keep a stalking distance
			if closing:              # it will not stand to be stoned: it comes for him, low and fast
				want = dir * speed * 2.7
				if not told_close:
					told_close = true
					level.show_tip("It will not stand and be stoned: it comes for him", 4.0)
			elif absf(dx) > 330.0:
				want = dir * speed
			elif absf(dx) < 210.0:
				want = -dir * speed * 0.8
			velocity.x = move_toward(velocity.x, want, 700.0 * delta)
			if closing and absf(dx) < 250.0:
				far_slings = 0
				far_t = 0.0
				state = "crouch"
				feint = false
				vault = false
				st = 0.6 * warn
				Game.sfx("lion_growl", -1.0)
			elif absf(dx) < 112.0 and rake_cd <= 0.0:
				state = "rake"       # he has come too close: a quick blow along the ground
				st = (0.5 if stage == 1 else 0.4) * warn
				rake_cd = 2.4 if stage == 1 else 1.8
			elif st <= 0.0:
				var r := randf()
				if stage == 3 and not is_nan(lamb_x) and r < 0.32:
					state = "hunt"
					Game.sfx("lion_growl", -1.0)
				elif stage == 3 and r < 0.44:      # it roars to stagger him, and springs while he reels: crouch low
					state = "roar"
					st = 0.85
					Game.sfx("lion_roar", -1.0, 0.0)
					level.player.shake = 8.0
					if absf(dx) < 300.0 and not player.ducking and player.invuln <= 0.0:
						player.stun = maxf(player.stun, 0.6)
				elif r < [0.0, 0.22, 0.5, 0.66][stage]:
					state = "slink"
					st = 3.0             # by then it is long out of sight: it is at the edge whatever held it up
					edge_x = (min_x + 24.0) if global_position.x - min_x < max_x - global_position.x else (max_x - 24.0)
				else:
					state = "crouch"
					feint = randf() < 0.3
					vault = stage >= 2 and not feint and absf(dx) < 300.0 and randf() < 0.38
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
					touch_kind = "body"
					level.player.shake = maxf(level.player.shake, 2.5)
					Game.burst(get_parent(), global_position + Vector2(0, -2), Color(0.8, 0.74, 0.62, 0.5), 10, 130.0)
					if vault:        # high and long: clean over his head, to land behind him
						velocity = Vector2(dir * clampf((absf(dx) + 200.0) * 1.3, 430.0, 760.0), -560.0)
						touch_kind = "high"
					else:
						velocity = Vector2(dir * clampf(absf(dx) * 1.55, 330.0, 640.0), -440.0)
		"pounce":
			if st <= 0.0 and is_on_floor():
				Game.sfx("lion_land", -2.0)
				level.player.shake = maxf(level.player.shake, 5.5)
				Game.burst(get_parent(), global_position + Vector2(0, -2), Color(0.8, 0.74, 0.62, 0.55), 14, 160.0)
				touch_kind = "body"
				if vault or (stage >= 2 and absf(to_player()) < 150.0 and randf() < 0.5):
					vault = false      # it lands, turns and rakes before he has turned round
					doubled = false
					face_player()
					state = "rake"
					st = 0.36 * warn
					rake_cd = 1.8
					_last_state = ""
				elif stage == 3 and not doubled:      # it lands and is in the air again
					doubled = true
					state = "crouch"
					st = 0.3 * warn
					_last_state = ""
				else:
					doubled = false
					state = "recover"
					st = 0.95 / quick
		"rake":
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if st <= 0.0:
				var ahead := dx * dir
				if ahead > -10.0 and ahead < 130.0 and player.is_on_floor() and absf(player.global_position.y - global_position.y) < 90.0:
					player.hurt(1, global_position.x, "low")
				state = "recover"
				st = 0.65
		"slink":                 # out of the light, to the edge of the ridge
			touch_on = false
			dir = 1 if edge_x > global_position.x else -1
			velocity.x = move_toward(velocity.x, dir * 330.0, 1400.0 * delta)
			modulate.a = move_toward(modulate.a, 0.0, delta * 2.2)
			if absf(edge_x - global_position.x) < 30.0 or (modulate.a <= 0.01 and (st <= 0.0 or is_on_wall())):
				global_position.x = edge_x
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
			dust_t -= delta
			if dust_t <= 0.0 and is_on_floor():
				dust_t = 0.09
				Game.burst(get_parent(), global_position + Vector2(-rush_dir * 30.0, -3), Color(0.8, 0.74, 0.62, 0.4), 3, 70.0)
			var past: bool = (player.global_position.x - global_position.x) * rush_dir < -210.0
			if st <= 0.0 or past or is_on_wall() or global_position.x <= min_x + 3.0 or global_position.x >= max_x - 3.0:
				state = "recover"
				st = 1.05 / quick
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
	fdist += velocity.x * float(dir) * delta
	track(state, st)
	crouch = move_toward(crouch, 1.0 if state == "crouch" else 0.0, delta * 5.0)


## The walk cycle by ground covered, run backward when it gives ground, so its feet never skate.
func _walk_frame() -> Texture2D:
	var arr: Array = FA.frames(anim, "walk")
	if arr.is_empty():
		return walk_frame()
	return arr[posmod(int(fdist / stride * arr.size()), arr.size())]


func _run_frame() -> Texture2D:
	var rn: Array = FA.frames("lion", "run")
	return rn[int(dist / 330.0 * rn.size()) % rn.size()] if not rn.is_empty() else _walk_frame()


func _draw() -> void:
	var u := 1.0 - st / st0
	# the ground under it: a broad, soft shadow, thinner as it leaves the ground, so it sits in the scene
	if not fleeing and state != "lurk":
		FA.shadow(self, 210.0, 0.8, 0.0 if is_on_floor() else FA.ground_drop(self))
	match state:
		"lurk":     # nothing of it but two eyes in the dark
			eye(Vector2(dir * 26.0 - 6.0, -30.0), 2.8, 0.7 + 0.3 * sin(t * 7.0))
			eye(Vector2(dir * 26.0 + 6.0, -30.0), 2.8, 0.7 + 0.3 * sin(t * 7.0))
		"crouch":   # sinks low, haunches bunched: the warning before the spring
			var c := clampf(u * 1.6, 0.0, 1.0)
			show_frame(action_frame("crouch", u * 1.6), 0.66, 1.4, Vector2(1.0 + 0.05 * c, 1.0 - 0.07 * c))
		"rake":     # drops its chest and sweeps a forepaw along the ground
			show_frame(action_frame("rake", u), 0.66, 1.4)
		"slink":    # away into the dark at a run
			show_frame(_run_frame(), 0.66, 1.4)
		"pounce":   # the leap itself: stretched along its flight, and larger at the top of it, as it comes at the camera
			var f := clampf(air_t / (0.8 if vault else 0.6), 0.0, 1.0)
			var d := 1.0 + 0.07 * sin(f * PI)
			var stretch := Vector2(d * (1.0 + 0.05 * sin(f * PI)), d * (1.0 - 0.04 * sin(f * PI)))
			if vault:      # the high, long leap clean over him
				show_frame(action_frame("vault", f), 0.66, 1.8, stretch)
			else:
				show_frame(action_frame("pounce", f, 3, 21), 0.66, 1.8, stretch)
		"rush":     # flat out, low and long
			show_frame(_run_frame(), 0.66, 1.4, Vector2(1.04, 0.97))
		"recover":  # lands, then stands panting: the moment to strike
			if u < 0.25:
				var k := 1.0 - u / 0.25      # the landing takes it in the legs
				show_frame(action_frame("pounce", u / 0.25, 21, 30), 0.66, 1.8, Vector2(1.0 + 0.08 * k, 1.0 - 0.08 * k))
			else:
				show_frame(FA.pingpong(FA.frames("lion", "pant"), t, 14.0), 0.66, 1.4)
		"reel":     # the spring broken: it shakes its head
			show_frame(FA.pingpong(FA.frames("lion", "pant"), t, 20.0), 0.66, 1.4, Vector2(1.0 + sin(t * 30.0) * 0.03, 0.96))
		"roar":
			show_frame(action_frame("roar", u), 0.66, 1.8)
		_:
			if absf(velocity.x) > 200.0:      # closing in on him, not stalking
				show_frame(_run_frame(), 0.66, 1.4)
			else:
				show_frame(_walk_frame(), 0.66, 1.4)
