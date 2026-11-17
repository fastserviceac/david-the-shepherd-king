extends CharacterBody2D
## Base for the wild animals. Defeated animals are driven off, not killed.

const D = preload("res://scripts/systems/draw_util.gd")
const FA = preload("res://scripts/systems/frame_anim.gd")
const EYE := Color(1.0, 0.72, 0.25)

signal defeated

var level
var player
var hp := 2
var max_hp := 2
var lesser := false          # a jackal and its like: his blows tell more on these as his hand and eye grow
var hit_r := 22.0
var hit_h := 30.0
var body_r := 14.0
var speed := 100.0
var dir := 1
var min_x := 0.0
var max_x := 100000.0
var roams := false           # leaves its own ground to follow him; only the land itself stops it
var touch_dmg := 1
var touch_r := 28.0
var touch_on := true
var stagger := 0.2
var kb := 0.0
var flash := 0.0
var fleeing := false
var flee_dir := 1.0
var t := 0.0
var walk := 0.0
var anim := ""          # animal name: frames live in art/<anim>/anim
var dist := 0.0         # ground covered, drives the walk cycle
var stride := 200.0     # ground covered in one full walk cycle
var air_t := 0.0        # time since leaving the ground
var st0 := 1.0          # how long the current action lasts
var _last_state := ""
var recoil := 0.0        # 1 just after being struck, fading to 0
var recoil_dir := 1.0
var tint := Color(1, 1, 1)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 10.0
	z_index = 4
	_init_enemy()
	hp = maxi(1, int(round(hp * float(Game.diff()["enemy_hp"]))))
	max_hp = hp
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = body_r
	cs.shape = sh
	cs.position = Vector2(0, -body_r)
	add_child(cs)
	add_to_group("hittable")
	add_to_group("enemies")
	if is_instance_valid(level):
		tint = level.pal.get("char", Color(1, 1, 1))


var held := 0.0             # seconds left in David's grip
var touch_kind := "body"    # how its touch comes: "high", "low" or "body"


func _init_enemy() -> void:
	pass


## The shepherd's call startles the lesser beasts.
func startle() -> void:
	pass


## Can David seize it now? Only when it is spent.
func can_clinch() -> bool:
	return false


func _ai(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta)
	recoil = maxf(0.0, recoil - delta * 4.0)
	if fleeing:
		velocity = Vector2(move_toward(velocity.x, flee_dir * 420.0, 1600.0 * delta), 0.0)
		dir = int(flee_dir)
		modulate.a -= delta * 0.7
		if modulate.a <= 0.0:
			queue_free()
	else:
		velocity.y = minf(velocity.y + 1500.0 * delta, 900.0)
		if kb > 0.0:
			kb -= delta
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		elif Game.cinematic or Game.backdrop or not is_instance_valid(player) or player.dead:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		elif held > 0.0:           # seized by David: it cannot move
			held -= delta
			velocity.x = 0.0
		else:
			_ai(delta)
			_touch()
	move_and_slide()
	if not fleeing and not roams:
		global_position.x = clampf(global_position.x, min_x, max_x)
	walk += absf(velocity.x) * delta * 0.07
	air_t = 0.0 if is_on_floor() else air_t + delta
	dist += absf(velocity.x) * delta
	queue_redraw()


func _touch() -> void:
	if not touch_on:
		return
	var d: Vector2 = player.global_position - global_position
	if absf(d.x) < touch_r and absf(d.y) < hit_h + 20.0:
		if player.invuln <= 0.0 and player.hurt(touch_dmg, global_position.x, touch_kind):
			_on_touch()


func _on_touch() -> void:
	pass


func to_player() -> float:
	return player.global_position.x - global_position.x


func face_player() -> void:
	dir = 1 if to_player() >= 0.0 else -1


func patrol(delta: float, spd: float) -> void:
	if global_position.x >= max_x - 4.0:
		dir = -1
	elif global_position.x <= min_x + 4.0:
		dir = 1
	elif is_on_wall():
		dir = -dir
	velocity.x = move_toward(velocity.x, dir * spd, 900.0 * delta)


func hit(dmg: int, from_dir: int, _kind: String) -> void:
	if fleeing:
		return
	hp -= dmg
	flash = 0.12
	recoil = 1.0
	recoil_dir = float(from_dir)
	if stagger > 0.0:
		kb = stagger
		velocity.x = from_dir * 230.0
		velocity.y = -140.0
	# sparks fly the way the blow went, plus dust from the ground
	var at := global_position + Vector2(0, -hit_h * 0.55)
	Game.burst(get_parent(), at, Color(1.0, 0.92, 0.7, 0.95), 10 + dmg * 6, 170.0 + dmg * 60.0)
	Game.burst(get_parent(), global_position + Vector2(from_dir * 10.0, -4), Color(0.75, 0.65, 0.5, 0.5), 6, 70.0)
	if is_instance_valid(player):
		player.shake = maxf(player.shake, 2.5 + dmg * 2.0)
	Game.sfx("hit", -1.0 + dmg, 0.05)
	Game.hitstop(0.05 + dmg * 0.025)
	if hp <= 0:
		hp = 0
		drive_off()


func drive_off() -> void:
	fleeing = true
	collision_mask = 0
	remove_from_group("hittable")
	remove_from_group("enemies")
	flee_dir = -1.0 if (is_instance_valid(player) and to_player() > 0.0) else 1.0
	if not lesser:      # a great beast driven off: let the moment land
		Game.burst(get_parent(), global_position + Vector2(0, -hit_h * 0.5), Color(1.0, 0.9, 0.6, 0.9), 40, 320.0)
		if is_instance_valid(player):
			player.shake = 12.0
		Game.sfx("defeat", 0.0, 0.0)
		Game.sfx("bear_roar" if anim == "bear" else "lion_roar", -3.0, 0.0)
		Game.slowmo(0.3, 0.9)
	elif anim == "jackal":
		Game.sfx("jackal_yelp", -4.0)
	Game.grow("heart", 3.0 if not lesser else 1.0)
	defeated.emit()


func ink() -> Color:
	return Color(2.2, 2.0, 1.8) if flash > 0.0 else tint


func eye(pos: Vector2, r: float, bright: float = 1.0) -> void:
	draw_circle(pos, r * 2.6, Color(EYE.r, EYE.g, EYE.b, 0.22 * bright))
	draw_circle(pos, r, Color(EYE.r, EYE.g, EYE.b, minf(1.0, bright)))


## The walk-cycle frame for the ground covered so far.
func walk_frame() -> Texture2D:
	var arr: Array = FA.frames(anim, "walk")
	return arr[int(dist / stride * arr.size()) % arr.size()]


## Call after changing state: remembers how long the new action lasts.
func track(state_name: String, remaining: float) -> void:
	if state_name != _last_state:
		_last_state = state_name
		st0 = maxf(remaining, 0.01)


## A frame from an action set, by how far through it we are (0..1).
func action_frame(set_name: String, u: float, first: int = 0, last: int = -1) -> Texture2D:
	var arr: Array = FA.frames(anim, set_name)
	if arr.is_empty():
		return walk_frame()
	if last < 0 or last >= arr.size():
		last = arr.size() - 1
	return arr[clampi(int(lerpf(float(first), float(last), clampf(u, 0.0, 1.0)) + 0.5), 0, arr.size() - 1)]


## Draws a frame with the creature's reaction to being struck: it rocks back,
## compresses and is knocked a little the way the blow went.
func show_frame(tex: Texture2D, sc: float, tall: float, stretch: Vector2 = Vector2.ONE) -> void:
	var r := recoil * recoil
	if not fleeing:
		FA.shadow(self, hit_r * 2.6, 1.0, 0.0 if is_on_floor() else FA.ground_drop(self))      # stays on the ground under a leap
	var lean := -r * 0.16 * recoil_dir * float(dir)
	FA.draw(self, tex, float(dir), sc, ink(), tall, lean, Vector2(0, -hit_h * 0.4),
		Vector2(stretch.x * (1.0 - r * 0.07), stretch.y * (1.0 + r * 0.05)), 0.0, recoil_dir * r * 9.0)
