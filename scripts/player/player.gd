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
var act := ""             # story pose: "kneel", "kneel_up", "carry", "rub", "gather"
var carry_set := "carry"  # what he carries in "carry": a grown lamb on his shoulders, or ("cradle") a newborn held to his chest
const GATHER_S := 4.0     # seconds to gather a newborn up and stand (the clip's own pace)
var move_t := 0.0         # how long he has kept moving: he sets off at a walk and breaks into a run
var carry_free := false   # while he carries the lamb, the player still chooses where he walks
var carry_tip_cd := 0.0   # so the reminder that his hands are full is not shown on every press
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
var wind := 0.0           # how long Staff has been held down: long enough, and letting go turns him right round
var spin_t := 0.0         # the round blow: the staff goes right round him and strikes on both sides
var plunge := 0           # struck from a leap: 1 coming down with the staff raised, 2 the blow landing
var plunge_t := 0.0
const WIND_TIME := 0.42
const SPIN_TIME := 0.54
const PLUNGE_LAND := 0.3
var leap_t := 0.0         # a running leap: a streak of dust behind him
# the lyre: while the key is held a breath rises and falls; let go at its top and a phrase lands
var lyre_t := 0.0         # seconds he has been seated with it (0: not playing)
var lyre_held := false    # the key is down and a breath is under way
var lyre_idle := 0.0      # seconds since he last let go: after a little he gets up
var breath := 0.0         # how far through the breath, 0..1
var breath_v := 0.0       # where the line stands now, 0..1
var breath_noise := 0.0   # a beast near: the line will not hold still
var phrases := 0          # phrases landed in this song, of three
var lyre_flash := 0.0     # a phrase just landed (above zero) or was let go too soon (below)
var lyre_feet := false    # this song is played on his feet (the Walking Song): he walks on, and what follows keeps following
# a song has a shape: three phrases are the three parts of one tune, and the third comes home on a chord. In the
# open the song then ends: he lowers the lyre and stands. Where he is still being listened to (a man, the king, a
# beast led on the road) the chord closes a verse instead, a breath of rest, and he plays on into the next.
var verse := 0            # verses closed in this sitting (which takes of the middle and closing parts are played)
var verse_rest := 0.0     # seconds of rest left after a verse closed
var lyre_end := 0.0       # seconds left of the song's last chord before he lowers the lyre and stands
var lyre_queued := false  # pressed again while he was getting up: he takes it up again once he is free
var song_wave := 0.0      # the closing chord going out over the ground, 1 to 0
var glow_v := 0.0         # how far the warmth of the song has spread around him
var song_glow: Sprite2D
var chord_in := 0.0       # seconds until the closing chord sounds (it waits for the last phrase to come home)
var chord_kind := ""
const CHORD_AT := 1.7     # the closing phrase reaches its home note 1.7 s in (measured): the chord comes with it
const VERSE_REST := 1.2
const SONG_END := 3.1     # from the third phrase to his getting up: the phrase comes home, the chord rings
const BREATH := 2.4       # seconds a breath takes to rise and fall
const BREATH_TOP := 0.8   # let go above this and the phrase lands
const LYRE_SIT := 0.5
const LYRE_RISE := 0.4

# The king's shield and spear (the Armour-Bearer). They are never his: a level puts them in his hands (`shield`)
# and takes them back. While he bears them he walks, and does nothing else with his hands but raise the shield.
var shield := false       # the king's shield is on his arm and the king's spear in his hand
var shield_learn := false # at the drill, before the Shield Arm is his, he is let raise it
var shield_up := false    # the key is held and his arm has not dropped
var blocking := false     # the shield is fully up: a blow from the front lands on it and does no harm
var block_t := 0.0        # how long it has been held up
var block_u := 0.0        # how far up it is, 0..1
var block_spent := false  # held too long: the arm has dropped, and he must let go before he can raise it again
var block_flash := 0.0    # a blow has just landed on it
const BLOCK_RAISE := 0.14 # seconds to bring it up
const BLOCK_HOLD := 1.3   # and how long the arm can keep it there


var _view_k := 1.0        # the closeness the camera was last set to for the shape of the screen (Game.view_k)

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
	song_glow = Game.glow(Color(1.0, 0.8, 0.48, 0.0), 128.0)      # the warmth of the song, spreading over the ground
	song_glow.position = Vector2(0, -16)
	song_glow.z_index = -1
	song_glow.visible = false
	add_child(song_glow)

	cam = Camera2D.new()
	cam.position = Vector2(0, -110)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	add_child(cam)
	cam.zoom = Vector2(1.18, 1.18) * Game.view_k()
	_view_k = Game.view_k()
	cam.make_current()


func _set_hearts() -> void:
	var h := Game.rank("heart")
	max_hp = int(Game.diff()["hearts"]) + Game.earned_hearts() + (1 if Game.has("heart") else 0) + (1 if h >= 3 else 0) + (1 if Game.all_places() else 0)


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


## The lyre. He sits where he stands and plays for as long as the key is held: the breath line rises and falls,
## and letting go near its top lands a phrase. Three phrases and the song goes out to every sheep that can hear.
## A beast close by makes the line jump; a blow, a leap or any other act ends the playing.
## The Shield Arm: with the king's shield on his arm, the Staff key raises it. It comes up in a moment and cannot
## be kept up for long, so it has to be raised for the blow, not before it.
func _update_block(delta: float, able: bool) -> void:
	block_flash = move_toward(block_flash, 0.0, delta * 3.0)
	var down: bool = Input.is_action_pressed("attack")
	var held: bool = shield and able and down and (Game.has("shieldarm") or shield_learn)
	if not down:
		block_spent = false
	if not held:
		block_t = 0.0
	elif not block_spent:
		block_t += delta
		if block_t > BLOCK_HOLD:
			block_spent = true
	shield_up = held and not block_spent
	block_u = move_toward(block_u, 1.0 if shield_up else 0.0, delta / (BLOCK_RAISE if shield_up else 0.22))
	blocking = shield_up and block_u >= 0.99


func _update_lyre(delta: float, free: bool, able: bool) -> void:
	lyre_flash = move_toward(lyre_flash, 0.0, delta * 1.5)
	song_wave = maxf(0.0, song_wave - delta / 1.1)
	if chord_in > 0.0:
		chord_in -= delta
		if chord_in <= 0.0:
			song_wave = 1.0
			glow_v = 1.45            # the bloom of the closing chord
			Game.lyre(chord_kind)
	_song_glow(delta)
	if not Input.is_action_pressed("lyre"):
		lyre_queued = false
	if act == "play_up":
		if Input.is_action_just_pressed("lyre"):
			lyre_queued = true
		if act_t >= LYRE_RISE:
			act = ""
		return
	if act != "play":
		lyre_t = 0.0
		lyre_end = 0.0           # whatever took him from the lyre (a gift, a fall) took the song with it
		verse_rest = 0.0
		# begun at a stand he sits to it, as he always has. With the Walking Song, begun while walking he plays on his feet
		var walking: bool = Game.has("walksong") and absf(velocity.x) >= 40.0
		var take: bool = Input.is_action_just_pressed("lyre") or (lyre_queued and Input.is_action_pressed("lyre"))
		if free and Game.has("lyre") and take and (walking or absf(velocity.x) < 90.0):
			lyre_queued = false
			verse = 0
			verse_rest = 0.0
			lyre_end = 0.0
			lyre_feet = walking
			act = "play"
			act_t = 0.0
			lyre_t = 0.001
			lyre_held = true
			lyre_idle = 0.0
			breath = 0.0
			breath_v = 0.0
			phrases = 0
			call_t = 0.0
			if not lyre_feet:
				velocity.x = 0.0
			Game.duck(true)
			Game.lyre("sit")
		return
	lyre_t += delta
	if not able or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") \
			or Input.is_action_just_pressed("roll") or Input.is_action_just_pressed("sling"):
		stop_lyre(false)
		return
	if lyre_end > 0.0:        # the last chord rings; then he lowers the lyre and gets up
		lyre_end -= delta
		lyre_held = false
		breath_v = move_toward(breath_v, 0.0, delta * 1.2)
		if lyre_end <= 0.0:
			stop_lyre(true)
		return
	if verse_rest > 0.0:      # a verse has closed: a breath of rest before the next begins
		verse_rest -= delta
		breath = 0.0
		breath_v = move_toward(breath_v, 0.0, delta * 1.8)
		lyre_idle = 0.0
		lyre_held = Input.is_action_pressed("lyre")      # letting go in the rest loses nothing
		return
	breath_noise = 0.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(n) and absf(n.global_position.x - global_position.x) < 340.0 and absf(n.global_position.y - global_position.y) < 200.0:
			breath_noise = 1.0
	if level != null and level.has_method("song_noise"):       # or something else that will not let the line hold still
		breath_noise = maxf(breath_noise, level.song_noise(global_position))
	if Input.is_action_pressed("lyre"):
		if not lyre_held:
			lyre_held = true
			breath = 0.0
		lyre_idle = 0.0
		var pace := 1.0          # something may hurry the breath as well as shake it
		if level != null and level.has_method("song_pace"):
			pace = level.song_pace(global_position)
		breath = fmod(breath + delta / BREATH * pace, 1.0)
		var jump := breath_noise * (0.09 if Game.has("steady") else 0.2) * sin(lyre_t * 23.0) * sin(lyre_t * 7.3)      # the Steady Hand: a fright shakes it less
		breath_v = clampf(0.5 - 0.5 * cos(breath * TAU) + jump, 0.0, 1.0)
	elif lyre_held:           # let go
		lyre_held = false
		if breath_v >= BREATH_TOP:
			phrases += 1
			lyre_flash = 1.0
			Game.buzz(14)
			Game.lyre("phrase", phrases - 1 + 3 * verse)      # the next part of the tune, not any phrase
			glow_v = maxf(glow_v, 0.3 + 0.7 * phrases / 3.0 + 0.15)
			_heed_sheep()
			if level != null and level.has_method("phrase"):
				level.phrase(global_position, lyre_feet)
			if phrases >= 3 and act == "play" and lyre_end <= 0.0:
				phrases = 0
				var on: bool = lyre_feet or (level != null and level.has_method("plays_on") and level.plays_on(global_position))
				verse += 1
				chord_in = CHORD_AT
				if on:
					verse_rest = VERSE_REST
					chord_kind = "verse"
				else:
					lyre_end = SONG_END
					chord_kind = "song"
				if level != null and level.has_method("song"):
					level.song(global_position, Game.song_reach(), lyre_feet)
		else:
			lyre_flash = -1.0
			Game.lyre("lost")
			if level != null and level.has_method("phrase_lost"):
				level.phrase_lost(global_position, lyre_feet)
	else:
		lyre_idle += delta
		breath_v = move_toward(breath_v, 0.0, delta * 1.8)
		if lyre_idle > 1.7:
			stop_lyre(true)


func stop_lyre(rising: bool) -> void:
	if act != "play":
		return
	act = "play_up" if rising and not lyre_feet else ""      # on his feet there is nothing to rise from
	lyre_feet = false
	act_t = 0.0
	lyre_t = 0.0
	lyre_held = false
	phrases = 0
	verse = 0
	verse_rest = 0.0
	lyre_end = 0.0
	if not Game.cinematic:
		Game.duck(false)


## What he was playing for has come to pass (a man quieted, the king at rest): the tune comes home on its last
## chord wherever it had got to, and he lowers the lyre and gets up.
func end_song() -> void:
	if act != "play" or lyre_end > 0.0:
		return
	phrases = 0
	verse_rest = 0.0
	lyre_end = SONG_END
	chord_in = CHORD_AT
	chord_kind = "song"


## Each sheep in hearing lifts its head to a phrase and turns to him.
func _heed_sheep() -> void:
	var reach: float = Game.song_reach()
	for s in get_tree().get_nodes_in_group("sheep"):
		if is_instance_valid(s) and s.has_method("heed") and not s.carried and absf(s.global_position.x - global_position.x) < reach \
				and absf(s.global_position.y - global_position.y) < 260.0:
			s.heed(global_position.x)


## The warmth of the song on the ground around him: it grows with each phrase, blooms on the closing chord, and
## goes as he gets up.
func _song_glow(delta: float) -> void:
	var aim := 0.0
	if act == "play" and (lyre_end <= 0.0 or chord_in > 0.0):
		aim = 1.0 if verse_rest > 0.0 or chord_in > 0.0 else 0.3 + 0.7 * phrases / 3.0
	glow_v = move_toward(glow_v, aim, delta * (0.9 if glow_v > aim else 1.5))
	song_glow.visible = glow_v > 0.01 and not Game.backdrop
	if song_glow.visible:
		var size: float = Game.song_reach() * (0.55 + 0.75 * minf(glow_v, 1.2))
		song_glow.scale = Vector2(size, size * 0.42) / 128.0
		song_glow.modulate.a = 0.1 + 0.16 * glow_v


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
	if act == "play" or act == "play_up":
		act = ""
	lyre_t = 0.0
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
	elif act != "" and not (act == "play" and lyre_feet):
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
			and not charging and attack_t <= 0.0 and act == "" and not shield
	_update_block(delta, can_act and on_floor)
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
	if act == "play" and can_act and call_cd <= 0.0 and Input.is_action_just_pressed("call") and Game.has("voice"):
		stop_lyre(false)          # he need not wait to get up: his voice brings on those the song has stilled
		_shepherd_call()
	elif free and call_cd <= 0.0 and Input.is_action_just_pressed("call") and Game.has("voice"):
		_shepherd_call()
	_update_lyre(delta, free, can_act and on_floor)
	if free and Input.is_action_just_pressed("grab"):
		_try_clinch()
	_update_clinch(delta)
	if ducking or sway_t > 0.0 or clinch_t > 0.0 or shield_up:
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
	if calm or shield or Input.is_action_pressed("walk"):
		top = WALK
	if act == "play" and lyre_feet:
		top = WALK * 0.8          # a man playing does not hurry
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

	if buffer > 0.0 and coyote > 0.0 and not charging and act != "carry" and not shield:      # with a lamb on his shoulders he does not leap
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
	# the staff and the sling are not in his hands while he bears the king's arms, nor while the lamb is on his shoulders
	# (there is no clip of him fighting with it, and the story says he lays it down first)
	var hands_full: bool = shield or act == "carry"
	if act == "carry" and can_act and carry_tip_cd <= 0.0 and level != null \
			and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("sling")):
		carry_tip_cd = 3.0
		level.show_tip("His hands are full: he cannot fight with the lamb on his shoulders", 3.0)
	carry_tip_cd = maxf(0.0, carry_tip_cd - delta)
	_update_attack(delta, can_act and not hands_full)
	_update_sling(delta, can_act and not hands_full)

	invuln = maxf(0.0, invuln - delta)
	stun = maxf(0.0, stun - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	sling_cd = maxf(0.0, sling_cd - delta)
	squash = move_toward(squash, 0.0, delta * 1.8)
	anim_t += delta * (4.0 + absf(velocity.x) * 0.045)

	shake = move_toward(shake, 0.0, delta * 30.0)
	# a screen taller than 16:9 (an iPad) shows more of the sky and the hills above, not more earth below: the
	# ground keeps to the same height off the bottom edge as on a phone, and the controls stand over the earth.
	# (Looking lower by the extra height, as it once did, filled half an iPad with the dark under his feet.)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	if not is_equal_approx(Game.view_k(), _view_k):      # the screen changed shape (turned, or a window resized)
		cam.zoom *= Game.view_k() / _view_k
		_view_k = Game.view_k()
	cam.position.x = lerpf(cam.position.x, facing * 70.0, delta * 2.0)
	var before := ph
	_update_pose(delta)
	if is_on_floor() and absf(velocity.x) > 40.0 and (int(before * 2.0) != int(ph * 2.0) or ph < before):
		var wet = level.pool_at(global_position) if level != null else null
		if wet != null:       # a foot in standing water
			Game.sfx("step_wet", -9.0 if act == "carry" else -7.0, 0.16)
			level.ripple(wet, global_position.x + facing * 8.0, clampf(absf(velocity.x) / 200.0, 0.6, 1.2))
		else:
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
	var skilled := Game.has("hand")      # the round blow and the blow from a leap come with the strong hand
	if not can_act:
		if plunge == 1 or spin_t > 0.0:
			attack_t = 0.0
		plunge = 0
		spin_t = 0.0
		wind = 0.0
	if spin_t > 0.0:
		spin_t -= delta
		attack_t = maxf(spin_t, 0.0)
		queued = false
		if not hit_done and spin_t < SPIN_TIME * 0.62:
			hit_done = true
			_round_hit(100.0 + (14.0 if Game.rank("hand") >= 1 else 0.0), 1 + (1 if Game.rank("hand") >= 2 else 0), 330.0)
		return
	if plunge == 1:
		queued = false
		attack_t = 9.0
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if is_on_floor():
			plunge = 2
			plunge_t = PLUNGE_LAND
			attack_t = PLUNGE_LAND
			squash = 1.0
			Game.sfx("land", -2.0, 0.05)
			Game.burst(get_parent(), global_position + Vector2(0, -2), Color(0.85, 0.78, 0.62, 0.45), 18, 150.0)
			_round_hit(88.0, 2 + (1 if Game.rank("hand") >= 2 else 0), 280.0)
			shake = maxf(shake, 6.0)
		return
	if plunge == 2:
		queued = false
		plunge_t -= delta
		attack_t = maxf(plunge_t, 0.0)
		if plunge_t <= 0.0:
			plunge = 0
			attack_cd = 0.12
		return
	# held down, the staff is drawn back; let go, and it goes right round him
	var holding: bool = skilled and can_act and is_on_floor() and not charging and roll_t <= 0.0 and hop_t <= 0.0 \
			and clinch_t <= 0.0 and act == ""
	if holding and Input.is_action_pressed("attack"):
		var was := wind
		wind += delta
		if was < WIND_TIME and wind >= WIND_TIME:
			Game.sfx("swing", -12.0, 0.0)      # the staff comes to rest behind him: ready
	else:
		if holding and wind >= WIND_TIME and attack_t <= 0.0:
			spin_t = SPIN_TIME
			attack_t = SPIN_TIME
			attack_cd = SPIN_TIME + 0.12
			hit_done = false
			combo = 0
			combo_window = 0.0
			queued = false
			wind = 0.0
			Game.sfx("swing_heavy", -2.0)
			return
		wind = 0.0
	if can_act and not charging and Input.is_action_just_pressed("attack"):
		if skilled and not is_on_floor() and air_t > 0.1 and attack_t <= 0.0:      # from a leap he comes down on them, staff first
			plunge = 1
			attack_t = 9.0
			hit_done = true
			strike_set = "attack4"
			velocity.y = maxf(velocity.y, 560.0)
			velocity.x *= 0.45
			Game.sfx("swing_heavy", -4.0)
			return
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
			var d := dmg
			if n.get("lesser") == true:      # on a jackal the blow is as strong as he has grown
				d = Game.blow("staff") + dmg - 1
			n.hit(d * (2 if opening_t > 0.0 else 1), facing, "staff")
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


## A blow that goes out on both sides of him at once: everything within reach is struck and thrown outward.
func _round_hit(reach: float, dmg: int, push: float) -> void:
	var landed := false
	for n in get_tree().get_nodes_in_group("hittable"):
		var dx: float = n.global_position.x - global_position.x
		var dy: float = absf((n.global_position.y - n.hit_h * 0.5) - (global_position.y - 30.0))
		if absf(dx) < reach + n.hit_r and dy < 60.0 + n.hit_h * 0.5:
			var side := 1 if dx >= 0.0 else -1
			var d := dmg
			if n.get("lesser") == true:
				d = Game.blow("staff") + dmg - 1
			n.hit(d * (2 if opening_t > 0.0 else 1), side, "staff")
			if n.get("kb") != null:
				n.kb = maxf(n.kb, 0.38)
				n.velocity.x = side * push
			Game.grow("hand", 1.0)
			landed = true
	if level != null and level.has_method("strike"):
		for side in [-1, 1]:
			if level.strike(global_position + Vector2(side * 48.0, 0.0), side):
				shake = maxf(shake, 1.5)
	for side in [-1.0, 1.0]:      # the staff's end raises the dust on both sides
		Game.burst(get_parent(), global_position + Vector2(side * reach * 0.7, -4.0), Color(0.85, 0.78, 0.62, 0.3), 6, 70.0)
	if landed:
		shake = maxf(shake, 6.0)
		if opening_t > 0.0:
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
	if charge >= 0.75 and Game.pouch() > 0:      # a smooth stone from the pouch
		Game.save["pouch"] = Game.pouch() - 1
		s.smooth = true
		s.dmg += 3 if Game.all_stones() else 2
	s.lesser_dmg = Game.blow("stone", charge >= 0.75) + (3 if s.smooth else 0)
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
	if blocking and (from_x - global_position.x) * facing >= 0.0:      # it lands on the king's shield
		block_flash = 1.0
		shake = 3.0
		velocity.x = -facing * 70.0
		Game.buzz(20)
		Game.sfx("shield_block", -6.0, 0.1)
		if level != null and level.has_method("blocked"):
			level.blocked(from_x)
		return false
	stop_lyre(false)
	hp -= amount
	invuln = 1.3
	stun = 0.25
	hurt_t = 0.5
	Game.buzz(45)
	Game.sfx("hurt", -1.0 if amount > 0 else -9.0)
	if Game.main and Game.main.hud and amount > 0:      # a padded pole at the drill stings and costs nothing
		Game.main.hud.hurt_flash = 1.0
	charging = false
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(280.0 * away, -300.0)
	shake = 7.0
	if amount <= 0:            # a knock, not a wound: a step back and no more
		velocity = Vector2(110.0 * away, -110.0)
		invuln = 0.5
		shake = 4.0
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
	var lv = get_parent()
	if lv != null and lv.get("task_now") != null:      # E is for the work at his feet, not for the beast beside him
		return
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
var shove := 0.0          # with the lamb on his shoulders he cannot set his hands to a rock: he leans his weight into it
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
	var stride := (WALK_CYCLE_PX if carry_set == "cradle" else 95.0) if act == "carry" else (WALK_CYCLE_PX if absf(velocity.x) < WALK + 30.0 else CYCLE_PX)
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
	if act == "rub":          # on his knees, rubbing a newborn dry with handfuls of grass
		if FA.frames("david", "rub").is_empty():
			return FA.pingpong(FA.frames("david", "kneel_hold"), act_t, 8.0)
		return FA.pingpong(FA.frames("david", "rub"), act_t, 10.0)
	if act == "gather":       # he slides his hands under it, lifts it to his chest in his cloak, and stands
		if FA.frames("david", "gather").is_empty():
			return _one_shot("kneel_up", act_t / 1.6)
		return _one_shot("gather", act_t / GATHER_S)
	if act.begins_with("lyre") and not FA.frames("david", _lyre_set()).is_empty():
		# seated with the kinnor: he sits down, plays with his head bowed, then lifts his face and plays on
		var ly: Array = FA.frames("david", _lyre_set())
		if act == "lyre_rise":
			return ly[clampi(8 - int(act_t / 1.0 * 8.0), 0, 8)]
		if act == "lyre_up":
			return FA.pingpong(ly.slice(34, ly.size()), act_t, 6.0)
		if act_t < 1.3:
			return ly[clampi(int(act_t / 1.3 * 9.0), 0, 8)]
		return FA.pingpong(ly.slice(9, 34), act_t - 1.3, 6.0)
	if act == "play" and lyre_feet:
		# on his feet with the kinnor against his chest: walking, or standing when he stops. (Until those are cut,
		# only the automated tests come here, and they see him simply walk.)
		var lf: Array = FA.frames("david", "lyre_walk" if absf(velocity.x) > 20.0 else "lyre_stand")
		if not lf.is_empty():
			return lf[int(act_t * 10.0) % lf.size()] if absf(velocity.x) > 20.0 else FA.pingpong(lf, act_t, 8.0)
	if (act == "play" and not lyre_feet) or act == "play_up":
		# the same seated playing as at the watchfire, quicker to sit and to rise; without those frames, he kneels
		var ly: Array = FA.frames("david", _lyre_set())
		if ly.size() < 34:
			return _one_shot("kneel", clampf(act_t / LYRE_SIT, 0.0, 1.0) if act == "play" else 1.0 - clampf(act_t / LYRE_RISE, 0.0, 1.0))
		if act == "play_up":
			return ly[clampi(8 - int(act_t / LYRE_RISE * 8.0), 0, 8)]
		if act_t < LYRE_SIT:
			return ly[clampi(int(act_t / LYRE_SIT * 9.0), 0, 8)]
		return FA.pingpong(ly.slice(9, 34), act_t - LYRE_SIT, 6.0 if lyre_held else 3.0)
	if act == "carry":
		var c: Array = FA.frames("david", carry_set)
		if c.is_empty():
			c = FA.frames("david", "carry")
		return c[int(ph * c.size()) % c.size()]
	if shield and act == "" and not FA.frames("david", "bear").is_empty():
		# the king's shield on his arm and the king's spear upright in his hand: raising the shield, walking, standing
		if block_u > 0.0 and not FA.frames("david", "block").is_empty():
			return _one_shot("block", block_u)
		if run > 0.12:
			var bw: Array = FA.frames("david", "bear")
			return bw[int(ph * bw.size()) % bw.size()]
		var bi: Array = FA.frames("david", "bear_idle")
		return FA.pingpong(bi if not bi.is_empty() else FA.frames("david", "bear").slice(0, 1), idle_clock, 6.0)

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
	if spin_t > 0.0:                      # the round blow
		var su := 1.0 - spin_t / SPIN_TIME
		var sp: Array = FA.frames("david", "spin")
		if not sp.is_empty():
			return _one_shot("spin", su)
		# until he has a clip of his own for it: the sweep out in front, and the same sweep carried on behind him
		return _one_shot("attack2", su * 1.3 if su < 0.5 else 0.3 + (su - 0.5) * 1.4)
	if plunge == 1:                       # coming down with the staff raised over his head
		return _one_shot("attack4", 0.34)
	if plunge == 2:                       # and the blow itself as his feet meet the ground
		return _one_shot("attack4", lerpf(0.42, 1.0, 1.0 - plunge_t / PLUNGE_LAND))
	if wind > 0.16 and attack_t <= 0.0 and is_on_floor():      # the staff drawn back, held
		return _one_shot("attack2", 0.1 * smoothstep(0.16, WIND_TIME, wind))
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
	var shoving: bool = act == "carry" and level != null and level.get("push_t") != null and level.push_t > 0.0
	shove = move_toward(shove, 1.0 if shoving else 0.0, get_process_delta_time() * 5.0)
	var face := float(facing)
	if spin_t > 0.0:
		var su := 1.0 - spin_t / SPIN_TIME
		if su >= 0.5 and FA.frames("david", "spin").is_empty():
			face = -face      # he has turned: the second half of the round is struck behind where he stood
		# the path of the staff's end, low and right round him
		var a0 := (PI if facing > 0 else 0.0) + facing * su * TAU * 1.05
		draw_set_transform(Vector2(0, -52.0), 0.0, Vector2(1.0, 0.3))
		for k in 3:
			draw_arc(Vector2.ZERO, 104.0 - k * 9.0, a0 - facing * (1.9 - k * 0.4), a0, 28,
				Color(1.0, 0.94, 0.78, (0.34 - k * 0.09) * sin(su * PI)), 5.0 - k * 1.2, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif wind >= WIND_TIME and is_on_floor():      # ready: a glint, so the thumb knows it can let go
		col = col.lerp(Color(1.5, 1.4, 1.15), 0.35 + 0.2 * sin(anim_t * 18.0))
	if plunge == 2:      # the ground answers the blow: a ring going out along it
		var pu := 1.0 - plunge_t / PLUNGE_LAND
		draw_set_transform(Vector2(0, -3.0), 0.0, Vector2(1.0, 0.22))
		draw_arc(Vector2.ZERO, 24.0 + pu * 96.0, 0.0, TAU, 40, Color(1.0, 0.93, 0.76, (1.0 - pu) * 0.5), 3.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	FA.draw(self, tex, face, SPRITE_SCALE, col, tall, shove * 0.27, Vector2.ZERO, Vector2.ONE)      # the footage already crouches and stretches; scaling it as well read as a size glitch
	if block_flash > 0.0:      # the blow on the shield: a short bright ring before him
		for k in 2:
			draw_arc(Vector2(facing * 30.0, -62.0), 16.0 + (1.0 - block_flash) * (26.0 + k * 12.0), (0.0 if facing > 0 else PI) - 1.1, (0.0 if facing > 0 else PI) + 1.1, 14,
				Color(1.0, 0.93, 0.72, block_flash * (0.6 - k * 0.25)), 3.0 - k, true)
	if charging:
		_draw_aim()
	if ring_t > 0.0:      # the call going out across the hillside
		var q := 1.0 - ring_t
		var reach: float = Game.call_reach()
		for k in 3:
			var r := reach * clampf(q * 1.25 - k * 0.12, 0.0, 1.0)
			if r > 4.0:
				draw_arc(Vector2(0, -60), r, PI * 1.08, PI * 1.92, 40, Color(1.0, 0.93, 0.75, 0.32 * ring_t), 2.5 - k * 0.6, true)
	if song_wave > 0.0:      # the closing chord going out over the ground, as far as the song is heard
		var q := 1.0 - song_wave
		var sr: float = Game.song_reach()
		draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.32))
		for k in 3:
			var r := sr * clampf(1.0 - pow(1.0 - clampf(q * 1.15 - k * 0.1, 0.0, 1.0), 2.0), 0.0, 1.0)
			if r > 6.0:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.88, 0.58, 0.55 * song_wave * (1.0 - k * 0.3)), 5.0 - k * 1.5, true)
		draw_set_transform(Vector2.ZERO)
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


## The seated playing: on a stone out of doors, on a stool in a hall (when those frames have been cut).
func _lyre_set() -> String:
	if level != null and level.get("indoors") and not FA.frames("david", "lyre_in").is_empty():
		return "lyre_in"
	return "lyre"
