extends "res://scripts/enemies/beast.gd"
## The viper. "An adder in the path, that bites the horse's heels" (Genesis 49:17); "a serpent bit him" in the
## wall (Amos 5:19). It is a hazard, not a hunter: it lies coiled where it lies and never moves from its spot.
## When he comes near it rears, which is the tell, and then strikes low and short. Hop back, lean back or jump over
## and it misses. A missed or spent strike leaves it open for one blow of the staff. A stone from afar also ends it.
## Sheep that stray up to it shy away; it takes no notice of them.
## Frames (art/viper/anim): coil, rear, strike, spent. Canvas height factor 1.0: it is low and long.

const WAKE := 120.0           # how near he must come before it rears
const STIR := 300.0           # nearer than this it is uneasy: a shiver and a few pebbles, so a careful eye finds it first

var state := "coil"
var st := 0.0
var home_x := 0.0
var bitten := 0               # times it has caught him
var struck_at := false        # this strike has been dodged or has landed: it counts only once
var stir_t := 0.0             # clock for the unease pebbles
var bits: Array = []          # skittered grit: [x, y, vx, vy, life, size]


func _init_enemy() -> void:
	anim = "viper"
	first_set = "coil"
	stride = 120.0
	hp = 1
	lesser = true
	speed = 0.0
	hit_r = 26.0
	hit_h = 16.0
	body_r = 8.0
	touch_dmg = 1
	touch_r = 46.0
	touch_on = false
	touch_kind = "low"      # at the heels: ducking does not help, a skip back does, and so does a jump
	roams = true
	stagger = 0.0


func _ready() -> void:
	super._ready()
	home_x = global_position.x


func _on_touch() -> void:
	bitten += 1
	if bitten == 2:
		level.show_tip("Do not walk up to a coiled snake.  Step back as it strikes, then strike it while it is spent", 6.5)


func _ai(delta: float) -> void:
	st -= delta
	touch_on = state == "strike" and st > 0.08
	var dx := to_player()
	var dy: float = absf(player.global_position.y - global_position.y)
	_grit(delta, absf(dx) < STIR and dy < 90.0 and state == "coil")
	match state:
		"coil":
			velocity.x = move_toward(velocity.x, signf(home_x - global_position.x) * 90.0 if absf(home_x - global_position.x) > 4.0 else 0.0, 600.0 * delta)
			if absf(dx) < WAKE and dy < 70.0:
				face_player()
				state = "rear"
				st = 0.5 * float(Game.diff()["warning"])
				Game.sfx("jackal_snarl", -12.0, 0.3)
			_shy_sheep()
		"rear":
			velocity.x = 0.0
			face_player()
			if st <= 0.0:
				state = "strike"
				st = 0.2
				struck_at = false
				velocity.x = dir * 520.0
		"strike":
			velocity.x = move_toward(velocity.x, 0.0, 2200.0 * delta) if st < 0.1 else dir * 520.0
			if st <= 0.0:
				state = "spent"
				st = 0.9
		"spent":
			velocity.x = 0.0
			if st <= 0.0:
				state = "coil"
	track(state, st)


## Grit and pebbles thrown off the ground by the snake: `n` bits, flung `k` times as hard.
func _spray(n: int, k: float) -> void:
	for i in n:
		bits.append([randf_range(-18.0, 18.0), -1.0, randf_range(-60.0, 60.0) * k, randf_range(-70.0, -25.0) * k,
				randf_range(0.35, 0.6), randf_range(1.2, 2.2)])


## Moves the grit; and while he is near but not yet in reach the coil shivers and kicks up a pebble now and then.
func _grit(delta: float, uneasy: bool) -> void:
	if uneasy:
		stir_t -= delta
		if stir_t <= 0.0:
			stir_t = randf_range(0.7, 1.2)
			_spray(1 + randi() % 2, 0.6)
	for b in bits:
		b[4] -= delta
		b[3] += 260.0 * delta
		b[0] += b[2] * delta
		b[1] = minf(b[1] + b[3] * delta, 0.0)
		if b[1] >= 0.0:
			b[3] = 0.0
			b[2] *= 0.5
	bits = bits.filter(func(b): return b[4] > 0.0)


## Leaning back out of the way beats a bite at the heels too; the others (a skip back, a jump) the player judges itself.
func _touch() -> void:
	if state == "strike" and not struck_at and absf(player.global_position.x - global_position.x) < touch_r \
			and player.sway_t > 0.05:
		struck_at = true
		player._escaped(global_position.x)
		return
	super._touch()


## A sheep that wanders up to it that is not gathered shies away: nothing teaches it, it is the snake.
func _shy_sheep() -> void:
	for s in get_tree().get_nodes_in_group("sheep"):
		if is_instance_valid(s) and not s.gathered and s.gatherable and s.bolt <= 0.0 and not s.carried \
				and absf(s.global_position.x - global_position.x) < 60.0:
			s.bolt = 0.5
			s.bolt_dir = 1.0 if s.global_position.x >= global_position.x else -1.0
			s.hop = 1.0


## Only when it is spent does the staff find it; a stone finds it at any time.
func hit(dmg: int, from_dir: int, kind: String) -> void:
	if fleeing:
		return
	if kind == "staff" and state != "spent":
		Game.sfx("swing", -10.0, 0.2)      # it is not there when the staff comes down
		return
	super.hit(dmg, from_dir, kind)


func _draw() -> void:
	var sc := 0.5
	# Its colour is the stones': so it is set apart from them by a dark pool under it and a thin dark rim round it.
	FA.shadow(self, 62.0, 1.8)
	FA.shadow(self, 38.0, 1.6)
	var tex: Texture2D = null
	var shake := 0.0
	var tall_k := 1.0
	match state:
		"rear":
			tex = by_u("rear", 1.0 - st / st0)
			shake = sin(t * 55.0) * 1.2 * (1.0 - st / st0)      # the tail rattles and the neck draws up before it strikes
			tall_k = 1.0 + 0.06 * sin(minf(1.0 - st / st0, 1.0) * PI)
		"strike":
			tex = by_u("strike", 1.0 - st / st0)
		"spent":
			tex = by_clock("spent", 8.0)
		_:
			tex = by_clock("coil", 5.0)
			if absf(to_player()) < STIR and absf(player.global_position.y - global_position.y) < 90.0:
				shake = sin(t * 38.0) * 0.7      # uneasy: a shiver
	if tex != null:
		var rim := Color(0.06, 0.04, 0.03, 0.6)
		for o in [Vector2(-1.8, 0), Vector2(1.8, 0), Vector2(0, -1.8), Vector2(0, 1.2), Vector2(-1.3, -1.3), Vector2(1.3, -1.3)]:
			FA.draw(self, tex, float(dir), sc, rim, 1.5, 0.0, Vector2.ZERO, Vector2(1.0, tall_k), o.y, o.x + shake)
		FA.draw(self, tex, float(dir), sc, ink(), 1.5, 0.0, Vector2.ZERO, Vector2(1.0, tall_k), 0.0, shake)
	for b in bits:
		var a: float = clampf(b[4] * 2.5, 0.0, 1.0)
		draw_circle(Vector2(b[0], b[1]), b[5], Color(0.32, 0.27, 0.2, 0.85 * a))
		draw_circle(Vector2(b[0], b[1] + 1.0), b[5] * 0.8, Color(0.05, 0.04, 0.03, 0.5 * a))
