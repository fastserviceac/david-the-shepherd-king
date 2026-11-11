extends "res://scripts/enemies/enemy.gd"
## The bear. Its hide turns a staff: blows from the front do nothing unless it is spent, reeling or stunned.
## It can be opened three ways: a sling stone while it rears or gathers itself staggers it; a charge that
## ends against the rock leaves it stunned; and a roll past it puts David behind, where the staff bites.
## It fights in three stages, each adding something: the second a ground slam and a second, low swipe,
## the third speed, a doubled charge, and a roar that blows out his torch. A lit torch held close makes it
## give ground and charge instead of closing.

var state := "walk"
var st := 0.0
var rear := 0.0
var stage := 1
var next := ""            # the attack it means to make when it closes
var chain := 0
var wary := 0.0
var waves: Array = []     # shock running along the ground after a slam: {"x", "d", "left"}
var glances := 0
var landed := false      # its last attack found him: there is no opening after a blow he failed to answer
var open_hits := 0        # blows taken in this opening; it will not stand for more than three


func _init_enemy() -> void:
	anim = "bear"
	stride = 210.0
	hp = 16
	speed = 75.0
	hit_r = 36.0
	hit_h = 58.0
	body_r = 24.0
	touch_r = 34.0
	stagger = 0.0


func _on_touch() -> void:
	landed = true


## An attack is over. If he answered it (it missed him), the bear is spent and open; if it struck him, it presses on.
func _spent(seconds: float) -> void:
	next = ""
	open_hits = 0
	if landed:
		landed = false
		state = "walk"
		st = 0.0
	else:
		state = "rest"
		st = seconds


func is_open() -> bool:
	return state in ["rest", "stunned", "reel"]


func can_clinch() -> bool:
	return is_open()


func reset() -> void:
	hp = max_hp
	stage = 1
	state = "walk"
	st = 0.0
	next = ""
	chain = 0
	waves.clear()


func hit(dmg: int, from_dir: int, kind: String) -> void:
	if fleeing or state == "roar":
		return
	if kind == "stone":
		if state in ["rear", "brace", "slam_up"]:      # caught with its guard up: it staggers
			state = "reel"
			st = 1.9
			Game.sfx("bear_roar", -7.0)
			super.hit(dmg, from_dir, kind)
		else:
			super.hit(mini(dmg, 1), from_dir, kind)      # a stone hardly troubles that hide
	elif kind == "staff":
		var behind := from_dir == dir                # the blow travels the way it faces: he is at its back
		if is_open() or behind or player.opening_t > 0.0:
			super.hit(dmg, from_dir, kind)
			open_hits += 1
			if open_hits >= 3 and is_open() and not fleeing:      # it has had enough: it heaves up and throws him off
				open_hits = 0
				state = "walk"
				next = ""
				Game.sfx("bear_growl", -1.0)
				if is_instance_valid(player):
					player.velocity = Vector2(-from_dir * 380.0, -220.0)
					player.stun = maxf(player.stun, 0.3)
		else:
			_glance(from_dir)
	else:
		super.hit(dmg, from_dir, kind)
	_stage_check()


## The staff lands on the thick of its shoulder and does nothing.
func _glance(from_dir: int) -> void:
	flash = 0.05
	glances += 1
	Game.sfx("hit", -9.0, 0.25)
	Game.burst(get_parent(), global_position + Vector2(-from_dir * 20.0, -hit_h * 0.6), Color(0.7, 0.7, 0.75, 0.6), 5, 90.0)
	if is_instance_valid(player):
		player.velocity.x = -from_dir * 170.0
	if glances == 2 or glances == 6:
		level.show_tip("Its hide turns the staff.  Strike when it is spent, or from behind")


func _stage_check() -> void:
	if fleeing:
		return
	var s := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if s > stage:
		stage = s
		state = "roar"
		st = 1.1
		next = ""
		Game.sfx("bear_roar", 0.0, 0.0)
		level.player.shake = 10.0
		if stage == 3 and level.get("torch_t") != null and level.torch_t > 0.0:
			level.torch_t = 0.0
			Game.sfx("gust", -3.0)
			level.show_tip("Its roar has put out the torch")


func _pick() -> String:
	var r := randf()
	match stage:
		1:
			return "charge" if r < 0.35 else "swipe"
		2:
			return "charge" if r < 0.3 else ("slam" if r < 0.6 else "swipe")
	return "charge" if r < 0.4 else ("slam" if r < 0.7 else "swipe")


func _claw(kind: String) -> void:
	var ahead := to_player() * dir
	if ahead > -10.0 and ahead < 125.0 and absf(player.global_position.y - global_position.y) < 100.0:
		if kind == "low":
			if player.is_on_floor() and player.hurt(1, global_position.x, "low"):      # the sweep comes along the ground: jump it, or be out of reach
				landed = true
		elif player.hurt(1, global_position.x, "high"):      # the swipe comes down from above: duck under it
			landed = true
	level.player.shake = maxf(level.player.shake, 4.0)


func _slam() -> void:
	waves.append({"x": global_position.x, "d": 1.0, "left": 460.0})
	waves.append({"x": global_position.x, "d": -1.0, "left": 460.0})
	level.player.shake = maxf(level.player.shake, 10.0)
	Game.sfx("bridge", -1.0)
	Game.burst(get_parent(), global_position + Vector2(dir * 30.0, -4.0), Color(0.8, 0.75, 0.65, 0.6), 22, 180.0)


func _update_waves(delta: float) -> void:
	for w in waves.duplicate():
		w["x"] += w["d"] * 430.0 * delta
		w["left"] -= 430.0 * delta
		if w["left"] <= 0.0 or w["x"] < min_x - 40.0 or w["x"] > max_x + 40.0:
			waves.erase(w)
		elif player.is_on_floor() and absf(player.global_position.x - w["x"]) < 24.0 and absf(player.global_position.y - global_position.y) < 40.0:
			if player.hurt(1, w["x"] - w["d"] * 10.0, "low"):      # jump it: on the ground it throws him
				waves.erase(w)
				if state == "rest":      # caught by the shock while it rested: the opening is gone
					state = "walk"
				else:
					landed = true


func _ai(delta: float) -> void:
	st -= delta
	var dx := to_player()
	var quick := 1.3 if stage == 3 else 1.0
	var warn := float(Game.diff()["warning"])
	_update_waves(delta)
	touch_on = not is_open() and state != "roar"
	match state:
		"walk":
			face_player()
			var torch: bool = level.get("torch_t") != null and level.torch_t > 0.0
			if torch and absf(dx) < 170.0:
				# it will not come in on the flame: it gives ground, and gathers itself to charge him down
				velocity.x = move_toward(velocity.x, -dir * speed * 0.8, 500.0 * delta)
				wary += delta
				if wary > 1.1:
					wary = 0.0
					state = "brace"
					landed = false
					Game.sfx("bear_growl", 0.0)
					st = 0.7 * warn
			else:
				velocity.x = move_toward(velocity.x, dir * speed * quick, 600.0 * delta)
				if next == "":
					next = _pick()
				if next == "charge" and absf(dx) <= 120.0 and wary < 1.0:
					# too close to run him down: it backs off to make room
					wary += delta * 2.0
					velocity.x = move_toward(velocity.x, -dir * speed * 1.1, 700.0 * delta)
				elif next == "charge" and absf(dx) < 320.0:
					next = ""
					wary = 0.0
					state = "brace"
					landed = false
					Game.sfx("bear_growl", 0.0)
					st = 0.7 * warn
				elif absf(dx) < 105.0:
					Game.sfx("bear_growl", -2.0)
					if next == "slam":
						state = "slam_up"
						landed = false
						st = 0.9 * warn
					else:
						state = "rear"
						landed = false
						st = 0.75 * warn
		"brace":
			velocity.x = move_toward(velocity.x, -dir * 45.0, 500.0 * delta)
			if st <= 0.0:
				state = "charge"
				st = 0.85
				Game.sfx("bear_roar", -5.0)
		"charge":
			velocity.x = move_toward(velocity.x, dir * 345.0 * quick, 2600.0 * delta)
			if is_on_wall() or global_position.x <= min_x + 3.0 or global_position.x >= max_x - 3.0:
				# it has run itself into the rock: dazed, and open
				state = "stunned"
				st = 2.2
				chain = 0
				velocity.x = -dir * 60.0
				level.player.shake = maxf(level.player.shake, 9.0)
				Game.sfx("lion_land", 0.0)
				Game.burst(get_parent(), global_position + Vector2(dir * 30.0, -30.0), Color(0.8, 0.75, 0.65, 0.6), 20, 170.0)
			elif st <= 0.0:
				if stage == 3 and chain == 0:      # it wheels and comes again
					chain = 1
					face_player()
					state = "brace"
					landed = false
					st = 0.45 * warn
				else:
					chain = 0
					_spent(1.0 / quick)
		"rear":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				state = "swipe"
				Game.sfx("bear_roar", -3.0)
				st = 0.25
				_claw("high")
		"swipe":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				if stage >= 2 and next != "done" and randf() < 0.6:
					next = "done"
					state = "swipe2"         # it does not straighten: a second blow is coming, low
					st = 0.45 * warn
				else:
					_spent(1.1 / quick)
		"swipe2":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				_claw("low")
				Game.sfx("bear_roar", -5.0)
				_spent(1.25 / quick)
		"slam_up":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				state = "slam"
				st = 0.3
				_slam()
		"slam":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				_spent(1.5 / quick)
		"rest", "stunned", "reel", "roar":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if st <= 0.0:
				state = "walk"
				next = ""
	track(state, st)
	var want := 1.0 if state in ["rear", "slam_up", "roar"] else 0.0
	rear = move_toward(rear, want, delta * (4.0 if want > 0.0 else 9.0))


func _draw() -> void:
	for w in waves:          # the shock running out along the ground
		var lx: float = w["x"] - global_position.x
		var a: float = clampf(w["left"] / 460.0, 0.0, 1.0)
		draw_set_transform(Vector2(lx, -2.0), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 20.0, Color(0.85, 0.78, 0.65, 0.5 * a))
		draw_arc(Vector2.ZERO, 26.0, PI, TAU, 14, Color(1.0, 0.92, 0.75, 0.8 * a), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var u := 1.0 - st / st0
	match state:
		"rear", "slam_up":     # rises onto its hind legs, paws high
			show_frame(action_frame("rear", u), 0.68, 2.3)
		"roar":
			show_frame(action_frame("rear", 1.0), 0.68, 2.3, Vector2(1.0 + sin(t * 46.0) * 0.012, 1.0))
		"swipe", "slam":       # crashes forward and down
			show_frame(action_frame("swipe", u, 0, 12), 0.68, 2.3)
		"swipe2":              # stays low, shoulders bunched, for the second blow
			show_frame(walk_frame(), 0.68, 1.4, Vector2(1.06, 0.86 + 0.03 * sin(t * 34.0)))
		"rest":                # back on all fours, heaving
			if u < 0.2:
				show_frame(action_frame("swipe", u / 0.2, 12, 18), 0.68, 2.3)
			else:
				show_frame(walk_frame(), 0.68, 1.4, Vector2(1.0, 1.0 + sin(t * 9.0) * 0.025))
		"reel":                # staggered by the stone: it shakes its head and gives ground
			show_frame(walk_frame(), 0.68, 1.4, Vector2(1.0 + sin(t * 30.0) * 0.03, 0.95))
		"stunned":             # dazed against the rock, head down
			show_frame(walk_frame(), 0.68, 1.4, Vector2(1.03, 0.88 + sin(t * 5.0) * 0.02))
		"brace":               # sinks low before the charge
			show_frame(walk_frame(), 0.68, 1.4, Vector2(1.04, 0.9 + 0.04 * sin(t * 30.0)))
		_:
			show_frame(walk_frame(), 0.68, 1.4)
