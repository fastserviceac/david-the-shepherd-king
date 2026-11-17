extends "res://scripts/enemies/beast.gd"
## The evening wolf. "The wolf snatches the sheep, and scatters them" (John 10:12).
## It will not close with a man who has a staff. It paces just outside his reach until a sheep strays far from him,
## then it dashes in, scatters the rest, takes that one and drags it toward the edge of the ground it came from.
## With a sheep in its jaws it is slow: a blow or a stone makes it let go and run. If it gets far enough away
## with the sheep, the sheep is lost. A stone while it paces only sends it off for a while.
## Frames (art/wolf/anim): walk, run, lunge, drag, hurt. They were built with a canvas height factor of 1.4.

const SIGHT := 800.0          # how far it sees a straggler
const STRAY := 260.0          # a sheep this far from him is on its own
const GONE := 700.0           # carried this far, the sheep is lost
const DRAG_SPEED := 110.0

var state := "circle"
var st := 0.0
var edge_x := NAN              # the edge of the ground it came from: where it drags what it takes
var prey = null                # the sheep it has marked
var carry = null               # the sheep in its jaws
var snatch_at := Vector2.ZERO  # where that sheep stood
var cool := 1.5                # seconds before it will dash again
var pace_t := 0.0
var losses := 0                # sheep it has got clean away with


func _init_enemy() -> void:
	anim = "wolf"
	first_set = "walk"
	stride = 190.0
	hp = 3
	lesser = true
	speed = 170.0
	hit_r = 28.0
	hit_h = 36.0
	body_r = 15.0
	touch_on = false      # it will not close with him
	roams = true          # the level's own edges keep it in, not a fence
	stagger = 0.15


func _ready() -> void:
	super._ready()
	if is_nan(edge_x):
		edge_x = 0.0 if global_position.x < level.width * 0.5 else level.width
	pace_t = randf() * 6.0


func _ai(delta: float) -> void:
	st -= delta
	cool -= delta
	match state:
		"circle":
			_circle(delta)
		"dash":
			_dash(delta)
		"drag":
			_drag(delta)
		"flee":
			_run_off(delta)
	keep_in_level()
	track(state, st)


## Just outside his reach, never in it: it backs off if he comes on, and comes on if he stands off.
func _circle(delta: float) -> void:
	face_player()
	var dx := to_player()
	pace_t += delta
	var want := sin(pace_t * 0.9) * speed * 0.7
	if absf(dx) < 210.0:
		want = -dir * speed
	elif absf(dx) > 330.0:
		want = dir * speed
	velocity.x = move_toward(velocity.x, want, 900.0 * delta)
	if cool <= 0.0:
		prey = _stray()
		if prey != null:
			_begin_dash()


## The sheep farthest from him that it can see, nearest to itself.
func _stray():
	var best = null
	var best_d := SIGHT
	for s in get_tree().get_nodes_in_group("sheep"):
		if not is_prey(s) or claimed(s):
			continue
		var sx: float = s.global_position.x
		if absf(sx - player.global_position.x) < STRAY or absf(s.global_position.y - global_position.y) > 90.0:
			continue
		if absf(sx - global_position.x) < best_d:
			best_d = absf(sx - global_position.x)
			best = s
	return best


## Its rush goes through the flock before it reaches the one it wants.
func _begin_dash() -> void:
	state = "dash"
	st = 4.0
	level.scatter_sheep(global_position.x, 560.0, prey)
	Game.sfx("jackal_snarl", -4.0)


func _dash(delta: float) -> void:
	if not is_prey(prey):
		prey = null
		state = "circle"
		cool = 2.0
		return
	var dx: float = prey.global_position.x - global_position.x
	dir = 1 if dx >= 0.0 else -1
	velocity.x = move_toward(velocity.x, dir * 520.0, 2400.0 * delta)
	if absf(dx) < 34.0:
		_snatch()
	elif st <= 0.0:          # it lost it in the scatter: it will try again
		prey = null
		state = "circle"
		cool = 3.0


func _snatch() -> void:
	carry = prey
	prey = null
	snatch_at = carry.global_position
	level.lose_follow(carry)
	carry.carried = true
	carry.hop = 1.0
	Game.sfx("sheep", -3.0, 0.2)
	state = "drag"


## Slowly, toward its own edge, with the sheep dragged along behind it.
func _drag(delta: float) -> void:
	if not is_instance_valid(carry):
		carry = null
		state = "flee"
		st = 4.0
		return
	dir = 1 if edge_x >= global_position.x else -1
	velocity.x = move_toward(velocity.x, dir * DRAG_SPEED, 900.0 * delta)
	carry.global_position = global_position + Vector2(-dir * 38.0, 0.0)
	carry.face = float(dir)
	if absf(global_position.x - snatch_at.x) >= GONE or absf(edge_x - global_position.x) < 24.0:
		_lose()


## It is away with the sheep: the shepherd answers for it. The sheep is set back where it stood for the second try.
func _lose() -> void:
	var s = carry
	_let_go(true)
	losses += 1
	level.sheep_taken(s)
	if losses == 2:
		level.show_tip("It is slow with a sheep in its jaws.  Strike it, or sling a stone, and it lets go", 6.0)
	state = "flee"
	st = 8.0


func _let_go(restore: bool = false) -> void:
	if carry == null:
		return
	var s = carry
	carry = null
	if not is_instance_valid(s):
		return
	s.carried = false
	s.hop = 1.0
	s.global_position = snatch_at if restore else level.on_ground(s.global_position.x)


func hit(dmg: int, from_dir: int, kind: String) -> void:
	if fleeing:
		return
	var had := carry != null
	super.hit(dmg, from_dir, kind)
	if fleeing:          # driven off for good: drive_off has let go of the sheep
		return
	_let_go(false)
	state = "flee"
	st = 8.0 if had else 6.0      # a blow with a sheep in its jaws, or a stone while it paced: it keeps away a while


## Back to the edge it came from, out of sight; then it comes again.
func _run_off(delta: float) -> void:
	dir = 1 if edge_x >= global_position.x else -1
	var far: bool = absf(to_player()) > 900.0
	modulate.a = move_toward(modulate.a, 0.0 if far else 1.0, delta * 2.0)
	velocity.x = move_toward(velocity.x, dir * 380.0 if absf(edge_x - global_position.x) > 40.0 else 0.0, 2000.0 * delta)
	if st <= 0.0:
		state = "circle"
		cool = 2.5
		modulate.a = 1.0


func _draw() -> void:
	if fleeing or (state == "flee" and kb <= 0.0 and absf(velocity.x) > 150.0):
		put(by_dist("run", 230.0), 0.62)
	elif kb > 0.0 or flash > 0.0:      # struck: it yelps and lets go
		put(by_clock("hurt", 14.0), 0.62)
	elif state == "drag":
		put(by_dist("drag", 150.0), 0.62)
	elif state == "dash" and is_instance_valid(prey) and absf(prey.global_position.x - global_position.x) < 120.0:
		put(by_u("lunge", 1.0 - absf(prey.global_position.x - global_position.x) / 120.0), 0.62, 1.8)      # the spring at the sheep
	elif state == "dash":
		put(by_dist("run", 230.0), 0.62)
	else:
		put(by_dist("walk"), 0.62)
