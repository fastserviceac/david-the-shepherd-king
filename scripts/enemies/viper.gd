extends "res://scripts/enemies/beast.gd"
## The viper. "An adder in the path, that bites the horse's heels" (Genesis 49:17); "a serpent bit him" in the
## wall (Amos 5:19). It is a hazard, not a hunter: it lies coiled where it lies and never moves from its spot.
## When he comes near it rears, which is the tell, and then strikes low and short. Hop back, lean back or jump over
## and it misses. A missed or spent strike leaves it open for one blow of the staff. A stone from afar also ends it.
## Sheep that stray up to it shy away; it takes no notice of them.
## Frames (art/viper/anim): coil, rear, strike, spent. Canvas height factor 1.0: it is low and long.

const WAKE := 120.0           # how near he must come before it rears

var state := "coil"
var st := 0.0
var home_x := 0.0
var bitten := 0               # times it has caught him
var struck_at := false        # this strike has been dodged or has landed: it counts only once


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
	FA.shadow(self, 46.0, 0.9)      # it is the colour of the stones it lies on: its shadow is what gives it away
	match state:
		"rear":
			put(by_u("rear", 1.0 - st / st0), sc, 1.5)
		"strike":
			put(by_u("strike", 1.0 - st / st0), sc, 1.5)
		"spent":
			put(by_clock("spent", 8.0), sc, 1.5)
		_:
			put(by_clock("coil", 5.0), sc, 1.5)
