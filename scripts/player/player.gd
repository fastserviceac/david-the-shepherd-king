extends CharacterBody2D
## David. Origin is at his feet.

const D = preload("res://scripts/systems/draw_util.gd")
const Stone = preload("res://scripts/player/stone.gd")
const FA = preload("res://scripts/systems/frame_anim.gd")

signal died

const RUN := 270.0
const ACCEL := 2000.0
const FRICTION := 2400.0
const AIR_ACCEL := 1400.0
const JUMP := -540.0
const GRAVITY := 1500.0
const MAX_HP := 5
const STONE_GRAVITY := 900.0

var level
var cam: Camera2D
var max_hp := MAX_HP
var hp := MAX_HP
var facing := 1
var dead := false

var coyote := 0.0
var air_t := 0.0          # how long he has been off the ground
var grow_fx := 0.0        # 1 fading to 0 after he grows in a craft: light on him
var buffer := 0.0
var jumping := false
var attack_t := 0.0
var attack_cd := 0.0
var hit_done := true
var charging := false
var charge := 0.0
var sling_cd := 0.0
var invuln := 0.0
var stun := 0.0
var shake := 0.0
var anim_t := 0.0
var squash := 0.0
var combo := 0            # which staff move is playing: 0 strike, 1 sweep, 2 rising finisher
var combo_window := 0.0   # time left to chain the next move
var attack_dur := 0.3
var queued := false
var throw_t := 0.0
var hurt_t := 0.0
var act := ""             # story pose: "kneel", "kneel_up", "carry"
var move_t := 0.0         # how long he has kept moving: he sets off at a walk and breaks into a run
var carry_free := false   # while he carries the lamb, the player still chooses where he walks
var calm := false         # a level can ask him to walk, not run (the road home, a house of mourning)
var roll_t := 0.0         # time left in a dodge roll
var roll_cd := 0.0
var call_t := 0.0         # calling to a sheep that has just come to him
# ---- fighting: ways to avoid a blow, and what a clean escape earns
var ducking := false      # held low: a high swipe passes over him
var sway_t := 0.0         # leaning back out of reach for a moment
var hop_t := 0.0          # a quick skip backwards
var opening_t := 0.0      # after a clean escape his next blow lands twice as hard
var clinch_t := 0.0       # seizing a spent beast
var clinch_on = null
var clinch_hit := false
var low_strike := false
const SWAY_TIME := 0.42
const HOP_TIME := 0.34
const CLINCH_TIME := 0.95
const WALK := 132.0
const WALK_CYCLE_PX := 150.0      # ground covered by one full walking cycle of two steps
const ROLL_TIME := 0.66
const CALL_TIME := 1.3
var act_t := 0.0
var call_cd := 0.0
var ring_t := 0.0         # the call going out, drawn as a widening ring
var strike_set := "attack"   # which staff animation is playing
var leap_t := 0.0         # a running leap: a streak of dust behind him


func _ready() -> void:
	_set_hearts()
	hp = max_hp
	if not Game.grew.is_connected(_on_grew):
		Game.grew.connect(_on_grew)
		Game.gifted.connect(_on_gift)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 10.0
	z_index = 5
	var cs := CollisionShape2D.new()
	var sh := CapsuleShape2D.new()
	sh.radius = 13.0
	sh.height = 54.0
	cs.shape = sh
	cs.position = Vector2(0, -27)
	add_child(cs)

	var aura := Game.glow(Color(1.0, 0.85, 0.6, 0.16), 260.0)
	aura.position = Vector2(0, -34)
	aura.z_index = -1
	add_child(aura)

	cam = Camera2D.new()
	cam.position = Vector2(0, -110)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	add_child(cam)
	cam.zoom = Vector2(1.18, 1.18)
	cam.make_current()


func _set_hearts() -> void:
	var h := Game.rank("heart")
	max_hp = int(Game.diff()["hearts"]) + (1 if Game.has("heart") else 0) + (1 if h >= 3 else 0)


## A craft has strengthened: a small thing, marked quietly.
func _on_grew(craft: String, _rank: int) -> void:
	if craft == "heart":
		var was := max_hp
		_set_hearts()
		hp += max_hp - was
	if not Game.fast and is_inside_tree():
		Game.burst(get_parent(), global_position + Vector2(0, -50), Color(1.0, 0.9, 0.55, 0.7), 10, 120.0)


## A gift is given: light comes down on him and he is made whole.
func _on_gift(id: String) -> void:
	if id == "heart":
		_set_hearts()
	grow_fx = 1.0
	hp = max_hp
	invuln = maxf(invuln, 2.2)
	shake = maxf(shake, 4.0)
	if not Game.fast and is_inside_tree():
		Game.burst(get_parent(), global_position + Vector2(0, -50), Color(1.0, 0.9, 0.55, 0.95), 46, 300.0)
		var z := cam.zoom
		var tw := create_tween()
		tw.tween_property(cam, "zoom", z * 1.16, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.5)
		tw.tween_property(cam, "zoom", z, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The shepherd's call: sheep that hear it come to him; later, jackals shy from it.
func _shepherd_call() -> void:
	call_cd = 2.2
	call_t = CALL_TIME
	ring_t = 1.0
	Game.sfx("gather", -3.0, 0.02)
	var v := Game.rank("voice")
	if level != null and level.has_method("shepherd_call"):
		level.shepherd_call(global_position, Game.call_reach(), v >= 2)


## Called when a sheep comes to him: he turns and calls it, if he is standing free.
func call_out() -> void:
	if is_on_floor() and absf(velocity.x) < 30.0 and attack_t <= 0.0 and not charging and act == "":
		call_t = CALL_TIME


func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	hp = max_hp
	dead = false
	charging = false
	attack_t = 0.0
	invuln = 1.0
	stun = 0.0
	cam.reset_smoothing()


func _physics_process(delta: float) -> void:
	var frozen: bool = Game.cinematic or Game.backdrop or dead
	var can_act: bool = not frozen and stun <= 0.0
	var on_floor := is_on_floor()

	var dir := 0.0
	if can_act:
		dir = Input.get_axis("move_left", "move_right")
	if charging:
		dir *= 0.35
	if act == "carry" and not dead:
		dir = Input.get_axis("move_left", "move_right") if carry_free else 0.2          # the lamb on his shoulders: led by the player on the road home, by himself in a story scene
	elif act != "":
		dir = 0.0

	coyote = 0.12 if on_floor else coyote - delta
	if can_act and Input.is_action_just_pressed("jump"):
		buffer = 0.12
	else:
		buffer -= delta

	# a dodge roll: low and quick, and nothing can touch him for most of it
	roll_cd = maxf(0.0, roll_cd - delta)
	call_t = maxf(0.0, call_t - delta)
	sway_t = maxf(0.0, sway_t - delta)
	hop_t = maxf(0.0, hop_t - delta)
	opening_t = maxf(0.0, opening_t - delta)
	var free: bool = can_act and on_floor and roll_t <= 0.0 and hop_t <= 0.0 and sway_t <= 0.0 and clinch_t <= 0.0 \
			and not charging and attack_t <= 0.0 and act == ""
	ducking = free and Input.is_action_pressed("move_down") and absf(dir) < 0.1
	# one dodge key, three escapes: towards the enemy he rolls through, away he skips back, standing he leans back
	if free and roll_cd <= 0.0 and Input.is_action_just_pressed("roll"):
		roll_cd = 0.7
		call_t = 0.0
		var quick := 0.7 if Game.rank("feet") >= 3 else 1.0
		ducking = false
		if absf(dir) < 0.1:
			sway_t = SWAY_TIME
		elif (dir > 0.0) == (facing > 0):
			roll_t = ROLL_TIME
			roll_cd = 0.95 * quick
			Game.sfx("land", -7.0, 0.1)
			Game.burst(get_parent(), global_position + Vector2(0, -2), Color(0.85, 0.78, 0.62, 0.3), 7, 60.0)
		else:
			hop_t = HOP_TIME
			velocity = Vector2(-facing * 330.0, -170.0)
			Game.sfx("jump", -10.0, 0.1)
		dir = 0.0 if roll_t <= 0.0 else dir
	call_cd = maxf(0.0, call_cd - delta)
	ring_t = maxf(0.0, ring_t - delta * 1.1)
	leap_t = maxf(0.0, leap_t - delta * 2.0)
	if free and call_cd <= 0.0 and Input.is_action_just_pressed("call") and Game.has("voice"):
		_shepherd_call()
	if free and Input.is_action_just_pressed("grab"):
		_try_clinch()
	_update_clinch(delta)
	if ducking or sway_t > 0.0 or clinch_t > 0.0:
		dir = 0.0
	if hop_t > 0.0:
		dir = 0.0
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	# He sets off at a walk and breaks into a run if he keeps going. Shift holds him to a walk.
	if absf(dir) > 0.1:
		move_t += delta
	elif on_floor and absf(velocity.x) < 20.0:
		move_t = 0.0
	var feet := Game.rank("feet")
	var run_top: float = RUN * [1.0, 1.04, 1.08, 1.13][feet]
	var top := lerpf(WALK, run_top, smoothstep(0.32, 0.75, move_t))
	if on_floor and not frozen:
		Game.grow("feet", absf(velocity.x) * delta / 100.0)
	if calm or Input.is_action_pressed("walk"):
		top = WALK
	if roll_t > 0.0:
		roll_t -= delta
		velocity.x = facing * lerpf(190.0, 470.0, clampf(roll_t / ROLL_TIME, 0.0, 1.0))
	elif hop_t > 0.0:
		pass
	elif absf(dir) > 0.1:
		call_t = 0.0
		velocity.x = move_toward(velocity.x, dir * top, (ACCEL if on_floor else AIR_ACCEL) * delta)
		facing = 1 if dir > 0.0 else -1
	elif stun <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, (FRICTION if on_floor else 500.0) * delta)

	var g := GRAVITY * (1.35 if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, 900.0)

	if buffer > 0.0 and coyote > 0.0 and not charging:
		velocity.y = JUMP
		if Game.has("feet") and absf(velocity.x) > RUN * 0.92:      # the running leap
			velocity.y = JUMP * 1.14
			velocity.x *= 1.08
			leap_t = 1.0
			Game.burst(get_parent(), global_position + Vector2(-facing * 10.0, -2), Color(0.9, 0.82, 0.62, 0.45), 12, 110.0)
		Game.sfx("jump", -6.0)
		buffer = 0.0
		coyote = 0.0
		jumping = true
		squash = -0.25
	if jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= 0.5
		jumping = false
	if velocity.y >= 0.0:
		jumping = false

	var fall := velocity.y
	move_and_slide()
	if is_on_floor():
		if OS.has_environment("DAVID_DBG") and not on_floor:
			print("LAND air=%.3f fall=%.0f x=%.0f" % [air_t, fall, global_position.x])
		# a real landing, not the blink of leaving the ground for a frame at a seam or a step down
		if not on_floor and (air_t > 0.14 or fall > 320.0):
			squash = 0.18
			land = 1.0
			Game.sfx("land", -4.0)
			Game.burst(get_parent(), global_position + Vector2(0, -2), Color(0.85, 0.78, 0.62, 0.35), 9, 70.0)      # dust
		air_t = 0.0
	else:
		air_t += delta

	shadow_drop = 0.0 if is_on_floor() else FA.ground_drop(self)
	_update_attack(delta, can_act)
	_update_sling(delta, can_act)

	invuln = maxf(0.0, invuln - delta)
	stun = maxf(0.0, stun - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	sling_cd = maxf(0.0, sling_cd - delta)
	squash = move_toward(squash, 0.0, delta * 1.8)
	anim_t += delta * (4.0 + absf(velocity.x) * 0.045)

	shake = move_toward(shake, 0.0, delta * 30.0)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	cam.position.x = lerpf(cam.position.x, facing * 70.0, delta * 2.0)
	var before := ph
	_update_pose(delta)
	if is_on_floor() and absf(velocity.x) > 40.0 and (int(before * 2.0) != int(ph * 2.0) or ph < before):
		Game.sfx("step", -13.0 if act == "carry" else -10.0, 0.14)
	Game.sfx_hold("sling_whirl", charging and not dead)
	queue_redraw()


const COMBO_TIME := [0.3, 0.34, 0.46]
const COMBO_DAMAGE := [1, 1, 2]


func _update_attack(delta: float, can_act: bool) -> void:
	combo_window = maxf(0.0, combo_window - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	throw_t = maxf(0.0, throw_t - delta)
	act_t += delta
	if can_act and not charging and Input.is_action_just_pressed("attack"):
		queued = true
	if queued and can_act and not charging and attack_cd <= 0.0:
		queued = false
		# pressing again soon after a move chains into the next one
		var chains := Game.has("hand")       # until the strong hand is given, each blow stands alone
		combo = (combo + 1) % 3 if combo_window > 0.0 and chains else 0
		low_strike = false
		if chains and Input.is_action_pressed("aim_up"):
			combo = 2            # rising blow
		elif chains and Input.is_action_pressed("move_down"):
			combo = 1            # low sweep under a guard
			low_strike = true
		# the third blow of a chain comes down from overhead; called for with Up, it rises instead
		strike_set = ["attack", "attack2", "attack3"][combo]
		if combo == 2 and not Input.is_action_pressed("aim_up") and not FA.frames("david", "attack4").is_empty():
			strike_set = "attack4"
		attack_dur = COMBO_TIME[combo]
		attack_t = attack_dur
		attack_cd = attack_dur * 0.82
		hit_done = false
		Game.sfx("swing_heavy" if combo == 2 else "swing", -3.0 if combo == 2 else -6.0)      # the rush of air stays well under the blow
	if attack_t > 0.0:
		attack_t -= delta
		if not hit_done and attack_t < attack_dur * 0.62:
			hit_done = true
			_staff_hit()
		if attack_t <= 0.0:
			combo_window = 0.62 if Game.rank("hand") >= 3 else 0.45


func _staff_hit() -> void:
	var hand := Game.rank("hand")
	var reach := 62.0 + (18.0 if combo >= 1 else 0.0) + (14.0 if hand >= 1 else 0.0)
	var dmg: int = COMBO_DAMAGE[combo]
	if (combo == 2 and hand >= 2) or (combo == 1 and hand >= 3):
		dmg += 1
	var landed := false
	for n in get_tree().get_nodes_in_group("hittable"):
		var ahead: float = (n.global_position.x - global_position.x) * facing
		var dy: float = absf((n.global_position.y - n.hit_h * 0.5) - (global_position.y - 30.0))
		if ahead > -18.0 and ahead < reach + n.hit_r and dy < 60.0 + n.hit_h * 0.5:
			n.hit(dmg * (2 if opening_t > 0.0 else 1), facing, "staff")
			if combo == 2 and hand >= 2 and n.get("kb") != null:      # thrown back
				n.kb = maxf(n.kb, 0.35)
				n.velocity.x = facing * 300.0
			Game.grow("hand", 1.0)
			landed = true
	# plants, stones and logs within the swing answer it too
	if level != null and level.has_method("strike") and level.strike(global_position + Vector2(facing * 48.0, 0.0), facing):
		shake = maxf(shake, 1.5)
	if landed:
		shake = maxf(shake, 3.0 + combo * 2.5)
		if opening_t > 0.0:        # the counter-blow
			opening_t = 0.0
			shake = maxf(shake, 9.0)
			Game.hitstop(0.08)


func _update_sling(delta: float, can_act: bool) -> void:
	if not Game.save.get("has_sling", false):
		return
	if can_act and not charging and sling_cd <= 0.0 and attack_t <= 0.0 and Input.is_action_just_pressed("sling"):
		charging = true
		charge = 0.0
	if charging:
		charge = minf(charge + delta * (1.45 if Game.rank("eye") >= 1 else 1.0), 0.8)
		if not can_act:
			charging = false
		elif not Input.is_action_pressed("sling"):
			charging = false
			sling_cd = 0.3
			_fire()


func _hand() -> Vector2:
	return Vector2(14.0 * facing, -70.0)


func _aim_velocity() -> Vector2:
	var ang := deg_to_rad(50.0) if Input.is_action_pressed("aim_up") else deg_to_rad(18.0)
	var speed := lerpf(430.0, 880.0 if Game.rank("eye") >= 2 else 780.0, charge / 0.8)
	return Vector2(facing, 0).rotated(-facing * ang) * speed


func _fire() -> void:
	var s = Stone.new()
	s.vel = _aim_velocity()
	s.dmg = (3 if Game.rank("eye") >= 3 else 2) if charge >= 0.75 else 1
	s.tint = tint.lerp(Color(1, 1, 1), 0.35)
	get_parent().add_child(s)
	s.global_position = global_position + _hand()
	throw_t = 0.34
	Game.sfx("sling_release", -2.0)


## kind says how the blow comes: "high" (a swipe or a leap at the head), "low" (a snap at the legs) or "body".
## Returns true if it landed.
func hurt(amount: int, from_x: float, kind: String = "body") -> bool:
	if invuln > 0.0 or dead or Game.cinematic or Game.backdrop or clinch_t > 0.0:
		return false
	var slipped: bool = roll_t > 0.12 or hop_t > 0.06 \
			or (sway_t > 0.05 and kind != "low") or (ducking and kind == "high")
	if slipped:
		_escaped(from_x)
		return false
	hp -= amount
	invuln = 1.3
	stun = 0.25
	hurt_t = 0.5
	Game.sfx("hurt", -1.0)
	if Game.main and Game.main.hud:
		Game.main.hud.hurt_flash = 1.0
	charging = false
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(280.0 * away, -300.0)
	shake = 7.0
	if hp <= 0:
		hp = 0
		dead = true
		died.emit()
	return true


## A blow avoided cleanly: a breath of slowed time, and an opening for a harder strike.
func _escaped(from_x: float) -> void:
	if opening_t > 0.6:
		return
	opening_t = [1.1, 1.6, 2.1, 2.1][Game.rank("heart")]
	Game.grow("heart", 1.0)
	invuln = maxf(invuln, 0.35)
	Game.sfx("swing", -9.0, 0.2)
	Game.slowmo(0.35, 0.22)
	Game.burst(get_parent(), global_position + Vector2(0, -60), Color(1.0, 0.95, 0.75, 0.7), 8, 120.0)


## Seizing a beast. Only one that is spent (panting after its own attack) can be held;
## any other throws him off.
func _try_clinch() -> void:
	var best = null
	var best_d := 96.0
	for n in get_tree().get_nodes_in_group("hittable"):
		if not n.has_method("can_clinch"):
			continue
		var ahead: float = (n.global_position.x - global_position.x) * facing
		if ahead > -20.0 and ahead < best_d and absf(n.global_position.y - global_position.y) < 80.0:
			best = n
			best_d = ahead
	if best == null:
		return
	if not best.can_clinch():
		hurt(1, best.global_position.x, "clinch")
		return
	clinch_on = best
	clinch_t = CLINCH_TIME
	clinch_hit = false
	velocity.x = 0.0
	best.held = CLINCH_TIME
	Game.sfx("swing_heavy", -4.0)


func _update_clinch(delta: float) -> void:
	if clinch_t <= 0.0:
		return
	clinch_t -= delta
	velocity.x = 0.0
	shake = maxf(shake, 1.5)
	if not clinch_hit and clinch_t < CLINCH_TIME * 0.4:
		clinch_hit = true
		if is_instance_valid(clinch_on):
			clinch_on.held = 0.0
			clinch_on.hit(3, facing, "staff")
			shake = maxf(shake, 9.0)
			Game.hitstop(0.09)
	if clinch_t <= 0.0:
		clinch_on = null


# ------------------------------------------------------------------ drawing
# David is a jointed painted figure. Everything below is worked out facing
# right, in the pixel units of the part images, then scaled and mirrored.

const K := 0.215                     # part pixels -> game pixels
const WOOD := Color(0.42, 0.28, 0.16)
const PARTS := {
	"head": {"pivot": Vector2(40, 100)},
	"torso": {"pivot": Vector2(62, 150)},
	"upper_arm": {"pivot": Vector2(20, 12), "end": Vector2(38, 162), "scale": 0.6},
	"forearm": {"pivot": Vector2(15, 8), "end": Vector2(33, 100), "scale": 0.7},
	"thigh": {"pivot": Vector2(24, 15), "end": Vector2(24, 180), "scale": 0.7},
	"shin": {"pivot": Vector2(22, 8), "end": Vector2(22, 131), "scale": 0.85},
}
var tex := {}
var tint := Color(1, 1, 1)
var _base := Transform2D()


func _load_parts() -> void:
	for n in PARTS:
		var img: Image = load("res://art/david/%s.png" % n).get_image()
		img.generate_mipmaps()
		tex[n] = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Direction for a limb angle: 0 hangs straight down, positive swings forward.
func _dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


## Draws a limb part from `joint` at angle `a`; returns where it ends.
func _bone(part: String, joint: Vector2, a: float, col: Color) -> Vector2:
	var d: Dictionary = PARTS[part]
	var rest: Vector2 = d["end"] - d["pivot"]
	var sc: float = d["scale"]
	var rot := atan2(rest.x, rest.y) - a
	draw_set_transform_matrix(_base * Transform2D(rot, Vector2(sc, sc), 0.0, joint))
	draw_texture(tex[part], -d["pivot"], col)
	return joint + _dir(a) * rest.length() * sc


func _piece(part: String, at: Vector2, rot: float, col: Color) -> void:
	draw_set_transform_matrix(_base * Transform2D(rot, at))
	draw_texture(tex[part], -PARTS[part]["pivot"], col)


# --- motion state (part-pixel units, facing right, origin under the hips)
const L1 := 115.5        # hip to knee
const L2 := 104.6        # knee to ankle
const SOLE := 18.0       # ankle to the sole of the sandal
const STRIDE := 200.0    # how far a planted foot travels under the body at full run
const CYCLE_PX := 185.0  # ground covered per full stride cycle, so feet do not slide

var ph := 0.0
var foot_a := Vector2(12, -SOLE)     # near ankle
var foot_b := Vector2(-14, -SOLE)    # far ankle
var hip_y := -234.0
var arm_near := Vector2(0.3, 1.35)   # upper arm angle, forearm angle
var arm_far := Vector2(0.05, 0.35)
var lean_s := 0.0
var carry := 0.0                     # 0 staff planted, 1 staff carried
var land := 0.0


## Where an ankle should be at point p (0..1) of the stride.
## First part: planted, sliding back under the body. Rest: lifted and swung forward.
func _foot_cycle(p: float, run: float) -> Vector2:
	var stance := 0.42
	var half := STRIDE * 0.5 * run
	if p < stance:
		return Vector2(lerpf(half, -half, p / stance), -SOLE)
	var u := (p - stance) / (1.0 - stance)
	var x := lerpf(-half, half, smoothstep(0.0, 1.0, u))
	# heel kicks up behind first, then the knee drives the foot forward
	var lift := (sin(u * PI) * 38.0 + sin(clampf(u * 1.7, 0.0, 1.0) * PI) * 52.0) * run
	return Vector2(x, -SOLE - lift)


func _update_pose(delta: float) -> void:
	var on_floor := is_on_floor()
	var run := clampf(absf(velocity.x) / RUN, 0.0, 1.0)
	var idle := 1.0 - run
	var stride := 95.0 if act == "carry" else (WALK_CYCLE_PX if absf(velocity.x) < WALK + 30.0 else CYCLE_PX)
	ph = fposmod(ph + absf(velocity.x) * delta / stride, 1.0)
	land = move_toward(land, 0.0, delta * 4.5)

	var ta: Vector2
	var tb: Vector2
	var hip_t: float
	var near_t: Vector2
	var far_t: Vector2
	var lean_t: float
	var carry_t := 1.0

	if on_floor:
		ta = _foot_cycle(ph, run) + Vector2(14.0 * idle, 0)
		tb = _foot_cycle(fposmod(ph + 0.5, 1.0), run) + Vector2(-16.0 * idle, 0)
		# the body sinks as each foot takes the weight and rises as it pushes off
		var bob := cos(ph * TAU * 2.0) * 9.0 * run
		var breathe := sin(anim_t * 0.45) * 2.5 * idle
		hip_t = -(L1 + L2 + SOLE) * (0.985 - 0.05 * run) + bob + breathe + land * 62.0
		lean_t = 0.2 * run + land * 0.12
		# arms pump opposite the legs, elbows bent when running
		var sw := cos(ph * TAU)
		var nu := lerpf(0.3, 0.15 - sw * 0.55, run)
		near_t = Vector2(nu, lerpf(1.35, nu + 1.15, run))
		var fu := 0.05 + sw * 0.85 * run
		far_t = Vector2(fu, fu + lerpf(0.3, 1.25, run))
		carry_t = smoothstep(0.15, 0.6, run)
	else:
		var up := clampf(-velocity.y / 420.0, -1.0, 1.0)     # 1 rising, -1 falling
		var w := smoothstep(-0.5, 0.6, up)
		hip_t = -(L1 + L2 + SOLE)
		var hip := Vector2(0, hip_t)
		# rising: front knee driven up, back leg trailing. falling: legs reach for the ground
		ta = hip + Vector2(48, 204).lerp(Vector2(86, 128), w)
		tb = hip + Vector2(-30, 214).lerp(Vector2(-92, 168), w)
		lean_t = lerpf(-0.06, 0.16, w)
		near_t = Vector2(0.5, 1.5).lerp(Vector2(0.95, 1.9), w)
		far_t = Vector2(2.2, 2.7).lerp(Vector2(-0.7, 0.1), w)   # falling: arm thrown up for balance

	var kf := 1.0 - exp(-delta * 34.0)
	var ka := 1.0 - exp(-delta * 16.0)
	foot_a = foot_a.lerp(ta, kf)
	foot_b = foot_b.lerp(tb, kf)
	hip_y = lerpf(hip_y, hip_t, 1.0 - exp(-delta * 26.0))
	arm_near = arm_near.lerp(near_t, ka)
	arm_far = arm_far.lerp(far_t, ka)
	lean_s = lerpf(lean_s, lean_t, ka)
	carry = lerpf(carry, carry_t, 1.0 - exp(-delta * 9.0))


## Two-bone leg: thigh and shin reach from the hip to the ankle, knee forward.
func _leg(hip: Vector2, ankle: Vector2, col: Color) -> void:
	var v := ankle - hip
	var d := clampf(v.length(), 30.0, L1 + L2 - 0.5)
	var a_hf := atan2(v.x, v.y)
	var bend := acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))
	var knee := _bone("thigh", hip, a_hf + bend, col)
	var s := hip + _dir(a_hf) * d - knee
	_bone("shin", knee, atan2(s.x, s.y), col)


const SPRITE_SCALE := 0.7
var idle_clock := 0.0
var shadow_drop := 0.0
var still_t := 0.0      # how long he has stood doing nothing
var look_at := 6.0      # when he next looks about


## Which frame of which animation shows David right now.
func _current_frame() -> Texture2D:
	var stood := still_t
	still_t = 0.0
	var on_floor := is_on_floor()
	var run := clampf(absf(velocity.x) / RUN, 0.0, 1.0)

	# story poses come first
	if act == "kneel":
		if act_t < 1.1:
			return _one_shot("kneel", act_t / 1.1)
		return FA.pingpong(FA.frames("david", "kneel_hold"), act_t, 8.0)
	if act == "kneel_up":
		return _one_shot("kneel_up", act_t / 1.6)
	if act == "carry":
		var c: Array = FA.frames("david", "carry")
		return c[int(ph * c.size()) % c.size()]

	# shoving something heavy along: braced low, both hands on it
	if level != null and level.get("push_t") != null and level.push_t > 0.0 and not FA.frames("david", "push").is_empty():
		return FA.pingpong(FA.frames("david", "push"), idle_clock, 9.0)
	# working with his hands (drawing water, setting a lever, lighting a torch): he bends to it as the work goes on
	# a task with its own movement (hauling the rope, tipping the bucket) plays it across the time the key is held
	if level != null and level.get("task_now") != null and float(level.task_now["t"]) > 0.0 and level.task_now.has("anim") \
			and not FA.frames("david", str(level.task_now["anim"])).is_empty():
		return _one_shot(str(level.task_now["anim"]), clampf(float(level.task_now["t"]) / float(level.task_now["hold"]), 0.0, 1.0))
	if level != null and level.get("task_now") != null and float(level.task_now["t"]) > 0.0 and not FA.frames("david", "pickup").is_empty():
		return _one_shot("pickup", clampf(float(level.task_now["t"]) / 0.45, 0.0, 1.0))
	if clinch_t > 0.0:                    # seizes the beast, then the blow
		var cu := 1.0 - clinch_t / CLINCH_TIME
		if not FA.frames("david", "clinch").is_empty():
			return _one_shot("clinch", cu)
		return _one_shot("attack3", clampf((cu - 0.35) / 0.5, 0.0, 1.0) * 0.9)
	if roll_t > 0.0 and on_floor:         # dodge roll
		if FA.frames("david", "roll").is_empty():
			return _one_shot("jump", 0.14)
		return _one_shot("roll", 1.0 - roll_t / ROLL_TIME)
	if sway_t > 0.0:                      # leans back out of reach
		var su := 1.0 - sway_t / SWAY_TIME
		var arc := su * 2.0 if su < 0.5 else (1.0 - su) * 2.0
		if not FA.frames("david", "sway").is_empty():
			return _one_shot("sway", su)
		return _one_shot("hurt", arc * 0.8)
	if hop_t > 0.0:                       # skips back
		if not FA.frames("david", "hop").is_empty():
			return _one_shot("hop", 1.0 - hop_t / HOP_TIME)
		return _one_shot("jump", lerpf(10.0, 30.0, 1.0 - hop_t / HOP_TIME) / 40.0)
	if ducking:
		if not FA.frames("david", "duck").is_empty():
			return FA.pingpong(FA.frames("david", "duck"), idle_clock, 8.0)
		return _one_shot("jump", 0.14)
	if hurt_t > 0.0:                      # flinch from a blow
		var h := 1.0 - hurt_t / 0.5
		# the old flinch clip filmed him smaller and in other clothes, which read as a size glitch on every blow;
		# until a matching clip is cut, he recoils with the lean-back frames, which are the same David
		if not FA.frames("david", "sway").is_empty() and FA.frames("david", "flinch").is_empty():
			return _one_shot("sway", h)
		return _one_shot("flinch", h * 2.0 if h < 0.5 else (1.0 - h) * 2.0)
	if attack_t > 0.0:                    # strike, sweep, rising finisher
		return _one_shot(strike_set, 1.0 - attack_t / attack_dur)
	if throw_t > 0.0:                     # the sling let fly
		return _one_shot("throw", lerpf(0.25, 1.0, 1.0 - throw_t / 0.34))
	if charging:
		var sl: Array = FA.frames("david", "sling")
		return sl[int(idle_clock * 26.0) % sl.size()]
	if not on_floor and (air_t > 0.1 or velocity.y < -80.0):      # a frame off the ground at a seam is not a jump
		# the jump clip runs crouch, launch, tuck, fall, land: pick by how fast he is rising or falling
		if velocity.y < 0.0:
			return _one_shot("jump", lerpf(13.0, 17.0, clampf(1.0 + velocity.y / 540.0, 0.0, 1.0)) / 40.0)
		return _one_shot("jump", lerpf(17.0, 21.0, clampf(velocity.y / 650.0, 0.0, 1.0)) / 40.0)
	if land > 0.0:
		return _one_shot("jump", lerpf(22.0, 38.0, 1.0 - land) / 40.0)
	if run > 0.12:
		var w: Array = FA.frames("david", "walk")
		if absf(velocity.x) < WALK + 30.0 and not w.is_empty():      # an easy walk below running speed
			return w[int(ph * w.size()) % w.size()]
		var r: Array = FA.frames("david", "run")
		return r[int(ph * r.size()) % r.size()]
	if call_t > 0.0 and not FA.frames("david", "call").is_empty():   # he calls to the sheep that has come to him
		return _one_shot("call", 1.0 - call_t / CALL_TIME)
	# left standing for a while, he looks about: shades his eyes, glances back, settles his cloak
	still_t = stood + get_process_delta_time()
	var look: Array = FA.frames("david", "idle2")
	if not look.is_empty() and not Game.cinematic and still_t > look_at:
		var u := (still_t - look_at) * 10.0 / float(look.size())
		if u < 1.0:
			return look[int(u * float(look.size() - 1))]
		still_t = 0.0
		look_at = randf_range(6.0, 11.0)
	return FA.pingpong(FA.frames("david", "idle"), idle_clock, 9.0)


func _one_shot(set_name: String, u: float) -> Texture2D:
	var arr: Array = FA.frames("david", set_name)
	if arr.is_empty():
		arr = FA.frames("david", "idle")
	return arr[clampi(int(clampf(u, 0.0, 1.0) * float(arr.size() - 1) + 0.5), 0, arr.size() - 1)]


func _draw() -> void:
	idle_clock += get_process_delta_time()
	var col := tint
	if invuln > 0.0 and not dead and int(invuln * 14.0) % 2 == 0:
		col = Color(1.6, 1.4, 1.3, 0.8)
	var tex := _current_frame()
	if grow_fx > 0.0:          # a shaft of light from above, and rings going out from his feet
		grow_fx = maxf(0.0, grow_fx - get_process_delta_time() * 0.33)
		var g := grow_fx
		var rise := 1.0 - g
		for k in 7:
			var w := 70.0 - k * 9.0
			draw_rect(Rect2(-w * 0.5, -620.0, w, 620.0), Color(1.0, 0.92, 0.65, 0.05 * g))
		for k in 3:
			var rr := fmod(rise * 2.2 + k * 0.33, 1.0)
			draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.24))
			draw_arc(Vector2.ZERO, 20.0 + rr * 230.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.6, (1.0 - rr) * 0.55 * g), 3.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		col = col.lerp(Color(1.7, 1.5, 1.15), g * 0.55)
	FA.shadow(self, 58.0, 1.0, 0.0 if is_on_floor() else shadow_drop)      # the shadow stays on the ground when he leaves it
	var tall := 2.1 if tex.get_height() > 600 else 1.65      # sets with the staff raised high are cut on a taller canvas
	FA.draw(self, tex, float(facing), SPRITE_SCALE, col, tall, 0.0, Vector2.ZERO, Vector2.ONE)      # the footage already crouches and stretches; scaling it as well read as a size glitch
	if charging:
		_draw_aim()
	if ring_t > 0.0:      # the call going out across the hillside
		var q := 1.0 - ring_t
		var reach: float = Game.call_reach()
		for k in 3:
			var r := reach * clampf(q * 1.25 - k * 0.12, 0.0, 1.0)
			if r > 4.0:
				draw_arc(Vector2(0, -60), r, PI * 1.08, PI * 1.92, 40, Color(1.0, 0.93, 0.75, 0.32 * ring_t), 2.5 - k * 0.6, true)
	if leap_t > 0.0 and not is_on_floor():      # the running leap leaves a streak
		for k in 5:
			draw_circle(Vector2(-facing * (16.0 + k * 13.0), -34.0 + k * 3.0), 5.0 - k * 0.7, Color(1.0, 0.92, 0.7, 0.16 * leap_t))


func _draw_staff(hand: Vector2, fa: float, swinging: bool, col: Color) -> void:
	draw_set_transform_matrix(_base)
	var wood := Color(WOOD.r * col.r, WOOD.g * col.g, WOOD.b * col.b, col.a)
	var up: Vector2
	var bottom: Vector2
	var top: Vector2
	if swinging:
		up = _dir(fa)
		bottom = hand - up * 70.0
		top = hand + up * 300.0
		var q := 1.0 - attack_t / 0.3
		var a_mid := atan2(up.y, up.x)
		draw_arc(hand, 290.0, a_mid - 1.0, a_mid, 14, Color(1.0, 0.95, 0.8, 0.45 * (1.0 - q)), 26.0, true)
	else:
		# standing: planted on the ground. moving: carried at an angle in the hand
		up = Vector2(0.06, -1.0).rotated(carry * 0.6).normalized()
		var planted := Vector2(hand.x + 0.06 * hand.y, 0.0)
		bottom = planted.lerp(hand - up * 125.0, carry)
		top = hand + up * lerpf(230.0, 195.0, carry)
	draw_line(bottom, top, wood, 19.0, true)
	draw_line(bottom.lerp(top, 0.1), top, Color(wood.r * 1.5, wood.g * 1.45, wood.b * 1.3, col.a * 0.6), 5.0, true)
	# the crook
	var side := up.rotated(PI * 0.5)
	var c := top + side * 34.0
	draw_arc(c, 34.0, atan2(-side.y, -side.x), atan2(-side.y, -side.x) + PI * 1.25, 14, wood, 19.0, true)


func _draw_aim() -> void:
	var p := _hand()
	var v := _aim_velocity()
	# at first he can only judge the start of the throw; with a sure eye he sees its whole flight
	var n := 26 if Game.has("eye") else 6
	for i in n:
		v.y += STONE_GRAVITY * 0.06
		p += v * 0.06
		draw_circle(p, 2.4, Color(1.0, 0.95, 0.8, 0.75 * (1.0 - float(i) / float(n))))
