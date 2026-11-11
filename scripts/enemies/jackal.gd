extends "res://scripts/enemies/enemy.gd"
## Jackal: patrols its ground, chases and lunges when David comes close.

var lunge_cd := 0.0
var retreat := 0.0


func _init_enemy() -> void:
	anim = "jackal"
	stride = 170.0
	hp = 2
	speed = 95.0
	hit_r = 24.0
	hit_h = 30.0
	body_r = 13.0
	touch_r = 30.0
	touch_kind = "low"      # it snaps at the legs: ducking does not help, a skip back does


func can_clinch() -> bool:
	return retreat > 0.0 or lunge_cd > 0.9


func startle() -> void:
	retreat = maxf(retreat, 1.3)
	lunge_cd = maxf(lunge_cd, 1.6)
	Game.sfx("jackal_yelp", -9.0, 0.1)


func _on_touch() -> void:
	retreat = 0.7


func _ai(delta: float) -> void:
	lunge_cd -= delta
	var dx := to_player()
	var dy: float = absf(player.global_position.y - global_position.y)
	if retreat > 0.0:
		retreat -= delta
		dir = -1 if dx >= 0.0 else 1
		velocity.x = move_toward(velocity.x, dir * 150.0, 900.0 * delta)
	elif absf(dx) < 330.0 and dy < 130.0:
		face_player()
		if is_on_floor():
			if absf(dx) < 110.0 and lunge_cd <= 0.0:
				lunge_cd = 1.5
				Game.sfx("jackal_snarl", -5.0)
				velocity = Vector2(dir * 310.0, -250.0)
			else:
				velocity.x = move_toward(velocity.x, dir * 190.0, 900.0 * delta)
	else:
		patrol(delta, speed)


func _draw() -> void:
	if not is_on_floor() and not fleeing:
		show_frame(action_frame("lunge", air_t / 0.5, 6, 30), 0.5, 1.8)    # crouch, spring with jaws open, land
	else:
		show_frame(walk_frame(), 0.5, 1.4)
