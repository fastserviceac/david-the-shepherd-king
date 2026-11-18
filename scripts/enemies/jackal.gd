extends "res://scripts/enemies/enemy.gd"
## Jackal: patrols its ground, chases and lunges when David comes close.

var lunge_cd := 0.0
var retreat := 0.0
var worrying := 0.0      # seconds since it was last at a sheep's side
var home_y := INF        # the height of the ground it was set down on
var alert := 0.0         # seconds it will keep hunting after it has lost sight of him
var last_seen := 0.0     # where it last had him
var size := 1.0          # how large it is drawn: a pup is small
var dam = null           # a pup: the bitch it keeps beside, and goes wherever she goes
var lag := 0.0           # where a pup keeps to, measured from her
var going_to := NAN      # leaving quietly, the song still in its ears: where it walks to, and is gone
const DROP := 64.0       # it will go down a step this deep after him, and spring up one as high


func _init_enemy() -> void:
	anim = "jackal"
	stride = 170.0
	hp = 6          # five blows of a boy's staff; two when his hand is strong (Game.blow)
	lesser = true
	speed = 95.0
	hit_r = 24.0
	hit_h = 30.0
	body_r = 13.0
	touch_r = 30.0
	touch_kind = "low"      # it snaps at the legs: ducking does not help, a skip back does
	roams = true            # min_x and max_x are the ground it patrols and comes home to, not a fence


func can_clinch() -> bool:
	return retreat > 0.0 or lunge_cd > 0.9


func startle() -> void:
	retreat = maxf(retreat, 1.3)
	lunge_cd = maxf(lunge_cd, 1.6)
	Game.sfx("jackal_yelp", -9.0, 0.1)


func _on_touch() -> void:
	retreat = 0.7


## Is there ground to stand on that far ahead? A step down counts, a pit does not.
func _ground_ahead(d: int, far: float = 26.0) -> bool:
	var from := global_position + Vector2(d * far, -DROP - 12.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, DROP * 2.0 + 14.0), 1)
	q.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Nothing over the step in front of it: it can spring up.
func _clear_above(d: int) -> bool:
	var from := global_position + Vector2(0, -DROP - 14.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(d * 46.0, 0), 1)
	q.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## The land decides where it can go: it stops at the lip of a pit and springs up a low step.
func _footing() -> void:
	if not is_on_floor() or absf(velocity.x) < 1.0 or velocity.y < 0.0:
		return
	var d := 1 if velocity.x > 0.0 else -1
	if not _ground_ahead(d):
		velocity.x = 0.0
	elif is_on_wall() and get_wall_normal().x * d < 0.0 and _clear_above(d):
		velocity.y = -470.0


## One that has no quarrel with him: a pup keeping by its dam, or a beast the song has sent on its way.
func meek() -> bool:
	return dam != null or not is_nan(going_to)


func _meek(delta: float) -> void:
	touch_on = false
	var to := global_position.x
	if not is_nan(going_to):
		to = going_to
	elif is_instance_valid(dam):
		to = dam.global_position.x + lag
	var dx := to - global_position.x
	var want := 0.0 if absf(dx) < 12.0 else signf(dx) * minf(absf(dx) * 3.0 + 20.0, 120.0)
	velocity.x = move_toward(velocity.x, want, 600.0 * delta)
	if absf(velocity.x) > 6.0:
		dir = 1 if velocity.x > 0.0 else -1
	if not is_nan(going_to) and absf(dx) < 40.0:      # into the dark, and gone
		modulate.a -= delta * 1.2
		if modulate.a <= 0.0:
			queue_free()


func _ai(delta: float) -> void:
	if meek():
		_meek(delta)
		return
	if is_on_floor() and home_y == INF:
		home_y = global_position.y
	if global_position.y > home_y + 600.0:      # knocked into a pit: that is the end of its hunting
		drive_off()
		return
	_hunt(delta)
	_footing()


func _hunt(delta: float) -> void:
	lunge_cd -= delta
	worrying -= delta
	var dx := to_player()
	var dy: float = absf(player.global_position.y - global_position.y)
	if retreat > 0.0:
		retreat -= delta
		dir = -1 if dx >= 0.0 else 1
		velocity.x = move_toward(velocity.x, dir * 150.0, 900.0 * delta)
	elif _worry(delta, dx, dy):
		pass
	elif _track(delta, dx, dy):
		pass
	elif absf(dx) < 330.0 and dy < 130.0:
		face_player()
		if is_on_floor():
			if absf(dx) < 110.0 and lunge_cd <= 0.0 and _ground_ahead(dir, 70.0) and _ground_ahead(dir, 120.0):
				lunge_cd = 1.5
				Game.sfx("jackal_snarl", -5.0)
				velocity = Vector2(dir * 310.0, -250.0)
			else:
				velocity.x = move_toward(velocity.x, dir * 190.0, 900.0 * delta)
	else:
		patrol(delta, speed)


## In the dark a jackal hunts by sound and scent, not sight: it notices him from much farther off, and when he
## slips out of reach it goes to where it last had him, and then casts about, for a few seconds, before it gives up
## and goes home. (In daylight it keeps the old, short reach.) The closer fight is left to _hunt.
func _track(delta: float, dx: float, dy: float) -> bool:
	var dark: float = float(level.get("dark_amount")) if is_instance_valid(level) and level.get("dark_amount") != null else 0.0
	if dark < 0.5:
		alert = 0.0
		return false
	if absf(dx) < 640.0 and dy < 200.0:
		alert = 4.0
		last_seen = player.global_position.x
		if absf(dx) < 330.0 and dy < 130.0:
			return false      # close: the ordinary fight takes over
	elif alert > 0.0:
		alert -= delta
	else:
		return false
	var to_x := last_seen - global_position.x
	if absf(to_x) < 40.0:      # at the spot: it noses about, then gives up in a moment
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		alert -= delta * 1.5
		return true
	dir = 1 if to_x > 0.0 else -1
	if is_on_floor():
		velocity.x = move_toward(velocity.x, dir * 175.0, 900.0 * delta)
	return true


## A jackal would sooner have a sheep than a fight. If a sheep is on its ground and the shepherd is in sight of
## it, the jackal goes for the sheep and worries it, and only turns on him when he is right on top of it. Left at
## a sheep's side long enough, it carries the sheep off. It never does this out of his sight: he must have the
## chance to stop it.
func _worry(_delta: float, dx: float, dy: float) -> bool:
	var prey = null
	var best := 420.0
	for s in get_tree().get_nodes_in_group("sheep"):
		if not is_instance_valid(s) or not (s.gathered or s.gatherable or s.prey) or s.leap >= 0.0 or s.mark.a > 0.0 or s.safe:
			continue      # another man's sheep, or one the story has taken out of his keeping, is not his to lose
		var sx: float = s.global_position.x
		if sx < min_x - 30.0 or sx > max_x + 30.0 or absf(s.global_position.y - global_position.y) > 80.0:
			continue
		if absf(sx - player.global_position.x) > 620.0:      # out of his sight: it leaves that one alone
			continue
		if absf(sx - global_position.x) < best:
			best = absf(sx - global_position.x)
			prey = s
	if prey == null:
		return false
	if absf(dx) < 62.0 and dy < 130.0 and best > 140.0:      # he is on it and no sheep is close: it has him to deal with
		return false
	dir = 1 if prey.global_position.x >= global_position.x else -1
	if best > 30.0:
		velocity.x = move_toward(velocity.x, dir * 200.0, 900.0 * get_physics_process_delta_time())
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * get_physics_process_delta_time())
		prey.worried = 0.25
		worrying = 0.2
		level.sheep_in_danger()
	return true


func _draw() -> void:
	if meek():
		var idle: Array = FA.frames(anim, "idle")
		if absf(velocity.x) < 8.0 and not idle.is_empty():
			show_frame(FA.pingpong(idle, t, 8.0), 0.5 * size, 1.4)
		else:
			show_frame(walk_frame(), 0.5 * size, 1.4)
		return
	var wr: Array = FA.frames("jackal", "worry")
	var rn: Array = FA.frames("jackal", "run")
	if not is_on_floor() and not fleeing:
		show_frame(action_frame("lunge", air_t / 0.5, 6, 30), 0.5, 1.8)    # crouch, spring with jaws open, land
	elif worrying > 0.0 and not wr.is_empty():      # head down at the sheep, snapping and tugging
		show_frame(wr[int(t * 16.0) % wr.size()], 0.5, 1.4)
	elif (fleeing or absf(velocity.x) > 165.0) and not rn.is_empty():      # flat out: fleeing, or closing on its prey
		show_frame(rn[int(dist / 210.0 * rn.size()) % rn.size()], 0.5, 1.4)
	else:
		show_frame(walk_frame(), 0.5, 1.4)
