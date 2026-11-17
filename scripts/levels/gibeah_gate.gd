extends "res://scripts/levels/level_base.gd"
## 2.3 The Gate of Gibeah. Sunset outside the fortress, then the yard as the light goes.
## A shepherd boy does not walk into a king's hall: someone has to bring him. The gate is barred for the night and
## the gatekeeper will not open it; the young man who spoke for him before the king (1 Samuel 16:18) is sent for
## and answers for him; the steward, at the end of a long day, would have the gift left in the yard till morning.
## What his father sent is handed over piece by piece, and then he waits at the door of the hall to be called.
##
## This is the first place the lyre is played to people. A man takes more phrases than a sheep, a phrase let go
## too soon is one taken back, and he does not stay quiet for long: what is asked of him has to be asked while
## the quiet lasts, and the playing taken up again when it has worn off.
##
## The gate is seen from in front, in the wall he walks along: going in is a step through it, so the section is
## two stretches of ground (outside the wall, and the yard) with the gate between them.

const Donkey = preload("res://scripts/world/donkey.gd")

const START_X := 330.0
const GATE_X := 1500.0         # the gate, from outside
const WATCH_X := 1400.0        # where the gatekeeper stands before it
const OUT_END := 1900.0        # the outside ground ends here
const YARD_X := 2200.0         # the yard begins here
const INNER_X := 2460.0        # the same gate, from inside
const CISTERN_X := 3000.0
const JONATHAN_X := 3390.0     # where the king's son is seen from, up on the wall: seen, never met
const WALL_TOP := 251.0        # the top of the wall band, in its own layer
const STORE_X := 3750.0        # the storehouse, and the steward before it
const HALL_X := 4500.0         # the door of the hall
const HEAR := 330.0            # how near a man must be to be played to
const GATE_NEED := 4           # phrases before the gatekeeper is quiet (a sheep takes three)
const GATE_CALM := 10.0        # and how long he stays so
const STORE_NEED := 5
const STORE_CALM := 8.0
const AGAIN := 2               # phrases to quiet a man again once he has been quiet
const KEEP := 2.5              # seconds a landed phrase adds while he is quiet
const TAKE := 2.5              # seconds of the steward's quiet that each thing received costs
const GATE_TALL := 300.0       # the gateway, lintel and all: the doors are about one and a half times a man
const DOOR_TALL := 250.0
const GATE_TINT := Color(0.84, 0.78, 0.8)      # set back in tone with the wall it stands in
const LOAD := ["Hand him the bread", "Hand him the skin of wine", "Give him the young goat"]

var donkey
var kid: Node2D
var watch: Node2D              # the gatekeeper
var youth: Node2D              # the young man who spoke for him
var steward: Node2D
var jonathan: Node2D
var gate: Sprite2D
var court: Sprite2D            # the yard's far view, shown once he is inside
var gate_wall: StaticBody2D
var refused := false           # the gatekeeper has said no
var asked := false             # the young man has been sent for, and has answered for him
var inside := false
var turned := false            # the steward has said "in the morning"
var given := 0                 # how many of the three things the steward has received
var lost_told := false
var placed := false
var ears := {}                 # who can be played to: name -> {x, need, heard, calm, hold, on, was}
var ask_task: Dictionary
var enter_task: Dictionary
var offer_task: Dictionary
var give_task: Dictionary
var wait_task: Dictionary


func _setup() -> void:
	mood = "theme_tender"
	ambience = "dusk"
	backdrop_art = "res://art/c2_gibeah_backdrop.png"
	midground_art = "res://art/c2_gibeah_mid.png"
	width = 4850.0
	barren = true                  # a hilltop trodden bare, outside the wall and in the yard
	mid_tint = Color(0.82, 0.74, 0.76)
	mid_mirror = false             # mirrored stonework shows as a pattern: the wall band carries a pier at its join instead
	flutters = 1
	pal.merge({
		"shafts": Color(1.0, 0.72, 0.42, 0.05), "mist": Color(0.9, 0.78, 0.7, 0.06),
		"sky_top": Color(0.36, 0.42, 0.68), "sky_mid": Color(0.82, 0.66, 0.66), "sky_bot": Color(0.98, 0.78, 0.56),
		"sun_pos": Vector2(0.78, 0.62), "sun_col": Color(1.0, 0.8, 0.52), "sun_size": 0.06,
		"far": Color(0.56, 0.5, 0.6), "near": Color(0.3, 0.22, 0.28), "rim": Color(1.0, 0.76, 0.48),
		"mote": Color(1.0, 0.84, 0.56, 0.4),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 6.0, 0.8)]
	checkpoints = [220.0, INNER_X + 330.0]


func _populate() -> void:
	var tint: Color = pal.get("char", Color(1, 1, 1))
	_build_court()
	# outside: the gate in the wall, shut, and the man who keeps it
	if ResourceLoader.exists("res://art/props/c2_gate.png"):
		gate = add_sprite("res://art/props/c2_gate.png", on_ground(GATE_X) + Vector2(0, 12), 1.0, 1, tint * GATE_TINT)
		gate.scale = Vector2.ONE * (GATE_TALL / gate.texture.get_height())
		if ResourceLoader.exists("res://art/props/c2_gate_open.png"):      # and the same gate from the yard, standing open
			var g2 := add_sprite("res://art/props/c2_gate_open.png", on_ground(INNER_X) + Vector2(0, 12), 1.0, 1, tint * GATE_TINT)
			g2.scale = Vector2.ONE * (GATE_TALL / g2.texture.get_height())
	watch = add_person("gatekeeper", WATCH_X, 1.0, true)
	donkey = Donkey.new()
	donkey.level = self
	donkey.position = on_ground(START_X - 92.0)
	donkey.face = 1.0
	donkey.led = true
	add_child(donkey)
	kid = add_person("kid", START_X - 160.0)
	# the yard: the cistern, the storehouse and its steward, the door of the hall
	youth = add_person("youth", INNER_X + 150.0, 1.0, true)
	add_sprite("res://art/props/well.png", on_ground(CISTERN_X) + Vector2(0, 8), 0.45, 1, tint)
	for k in 3:
		add_sprite("res://art/props/jar.png", on_ground(STORE_X + 80.0 + k * 40.0) + Vector2(0, 4), 0.62 - 0.05 * k, 2, tint)
	steward = add_person("steward", STORE_X, 1.0, true)
	# Jonathan is at Gibeah before David comes (1 Samuel 13:2, 14:49), but they do not meet until after Goliath
	# (18:1): he stands up on the wall, small against the evening sky, where the path does not go
	jonathan = add_person("jonathan", JONATHAN_X, 0.62, true, 0)
	if is_instance_valid(jonathan):
		for L in layers:
			if is_equal_approx(float(L["s"]), 0.4):      # the wall band: he goes with it, not with the ground
				remove_child(jonathan)
				(L["node"] as Node2D).add_child(jonathan)
				jonathan.position = Vector2(JONATHAN_X * 0.4, WALL_TOP)
				jonathan.modulate = Color(0.86, 0.8, 0.86)
	if ResourceLoader.exists("res://art/props/c2_hall_door.png"):      # the door of the hall, lamplit from inside
		var door := add_sprite("res://art/props/c2_hall_door.png", on_ground(HALL_X + 60.0) + Vector2(0, 12), 1.0, 1, tint * GATE_TINT)
		door.scale = Vector2.ONE * (DOOR_TALL / door.texture.get_height())
		add_glow(on_ground(HALL_X + 60.0) + Vector2(0, -90.0), Color(1.0, 0.62, 0.3, 0.4), 230.0)
	gate_wall = add_wall(OUT_END - 60.0)
	add_wall(YARD_X + 60.0)
	if Game.backdrop:
		return
	if is_instance_valid(youth):
		youth.visible = false

	ears = {
		"gate": {"x": WATCH_X, "need": GATE_NEED, "heard": 0, "calm": 0.0, "hold": GATE_CALM, "on": false, "was": false},
		"store": {"x": STORE_X, "need": STORE_NEED, "heard": 0, "calm": 0.0, "hold": STORE_CALM, "on": false, "was": false},
	}
	_pips("gate")
	_pips("store")
	add_trigger(WATCH_X - 330.0, WATCH_X - 60.0, _refuse)
	ask_task = add_task(WATCH_X - 70.0, "Ask for the young man who spoke of you", 1.0, _ask, 110.0)
	ask_task["on"] = false
	enter_task = add_task(GATE_X, "Lead the donkey in through the gate", 0.9, _enter, 90.0)
	enter_task["on"] = false
	add_trigger(CISTERN_X - 160.0, CISTERN_X + 160.0, func() -> void: say(["n_c2s3_cistern"]))
	add_trigger(JONATHAN_X - 210.0, JONATHAN_X + 60.0, func() -> void: say(["n_c2s3_jonathan", "n_c2s3_unmet"]))
	offer_task = add_task(STORE_X - 80.0, "Offer your father's gift", 0.9, _offer, 100.0)
	give_task = add_task(STORE_X - 80.0, LOAD[0], 1.1, _hand_over, 100.0)
	give_task["again"] = true
	give_task["on"] = false
	wait_task = add_task(HALL_X, "Sit down at the door and wait", 1.4, _wait_called, 90.0)
	wait_task["on"] = false


## The yard's own far view lies over the hill's, unseen until he is through the gate.
func _build_court() -> void:
	var path := "res://art/c2_court_backdrop.png"
	if backdrop_art == "" or not ResourceLoader.exists(path):
		return
	for L in layers:
		var n: Node = L["node"]
		if n.get_child_count() > 0 and n.get_child(0) is Sprite2D and (n.get_child(0) as Sprite2D).texture.resource_path == backdrop_art:
			var first := n.get_child(0) as Sprite2D
			court = Sprite2D.new()
			court.texture = load(path)
			court.centered = false
			court.scale = first.scale * (float(first.texture.get_width()) / court.texture.get_width())
			court.position = first.position
			court.visible = false
			n.add_child(court)
			return


func begin() -> void:
	if inside:
		return
	await say(["n_c2s3_intro", "n_c2s3_shut"])


# ------------------------------------------------------------------ playing to a man

## Marks over a man's head while he is being played to: one for each phrase he still wants, filling as they
## land, and when he is quiet a line that runs down as the quiet wears off.
func _pips(who: String) -> void:
	var e: Dictionary = ears[who]
	var draw := func(ci: CanvasItem) -> void:
		if not e["on"] or Game.cinematic:
			return
		var gold := Color(1.0, 0.86, 0.55)
		if e["calm"] > 0.0:
			var w: float = 64.0 * clampf(float(e["calm"]) / float(e["hold"]), 0.0, 1.0)
			ci.draw_rect(Rect2(-33.0, -3.0, 66.0, 6.0), Color(0, 0, 0, 0.45))
			ci.draw_rect(Rect2(-32.0, -2.0, w, 4.0), gold)
			return
		var n: int = _need(e)
		for k in n:
			var at := Vector2((k - (n - 1) * 0.5) * 16.0, 0.0)
			ci.draw_circle(at, 6.0, Color(0, 0, 0, 0.45))
			if k < int(e["heard"]):
				ci.draw_circle(at, 4.5, gold)
			else:
				ci.draw_arc(at, 4.5, 0.0, TAU, 16, Color(gold, 0.7), 1.2, true)
	add_painter(on_ground(float(e["x"])) + Vector2(0, -218.0), 6, draw, true)


func _need(e: Dictionary) -> int:
	return AGAIN if e["was"] else int(e["need"])


## The man within hearing of `x` who is being played to, or "".
func _ear_at(x: float) -> String:
	for who in ears:
		if ears[who]["on"] and absf(x - float(ears[who]["x"])) < HEAR:
			return who
	return ""


func phrase(from: Vector2, feet: bool) -> void:
	if feet and is_instance_valid(donkey) and donkey.led:
		donkey.hear(from, 300.0)
	var who := _ear_at(from.x)
	if who == "":
		return
	var e: Dictionary = ears[who]
	if e["calm"] > 0.0:
		e["calm"] = minf(float(e["hold"]), float(e["calm"]) + KEEP)
		return
	e["heard"] = int(e["heard"]) + 1
	if int(e["heard"]) >= _need(e):
		e["heard"] = 0
		e["calm"] = float(e["hold"]) * float(Game.diff()["warning"]) * Game.song_hold()
		e["hold"] = e["calm"]
		e["was"] = true
		Game.sfx("anoint", -14.0, 0.0)
		_quieted(who)


## A phrase let go too soon: with a man, one that had landed is taken back.
func phrase_lost(from: Vector2, _feet: bool) -> void:
	var who := _ear_at(from.x)
	if who == "" or ears[who]["calm"] > 0.0:
		return
	if int(ears[who]["heard"]) > 0:
		ears[who]["heard"] = int(ears[who]["heard"]) - 1
		if not lost_told:
			lost_told = true
			show_tip("A phrase let go too soon takes one back.  A man listens harder than a sheep", 6.0)


func _quieted(who: String) -> void:
	if who == "gate":
		show_tip("His face has eased.  Ask him now: it will not last", 5.0)
	elif given == 0:
		show_tip("He is listening.  Hand him the gift while he does, piece by piece", 6.0)


func _hardened(who: String) -> void:
	if who == "gate" and not asked:
		show_tip("The day's weariness is back in him.  Play again", 5.0)
	elif who == "store" and given < LOAD.size():
		show_tip("He has turned back to his tally.  Play again", 5.0)


# ------------------------------------------------------------------ the gate

func _refuse() -> void:
	if refused:
		return
	refused = true
	ears["gate"]["on"] = true
	await say(["n_c2s3_keeper", "n_c2s3_no"])
	show_tip("He will not hear a boy's word.  Play to him (R), and let each phrase go at the top of the breath", 8.0)


func _ask() -> void:
	asked = true
	ears["gate"]["on"] = false
	if is_instance_valid(youth):
		youth.position = on_ground(GATE_X + 70.0) + Vector2(0, 4)
		youth.visible = true
	await say(["n_c2s3_ask", "1sam16_18", "n_c2s3_open"])
	Game.sfx("logs", -6.0, 0.05, 0.8)
	enter_task["on"] = true


func _enter() -> void:
	Game.cinematic = true
	await Game.main.overlay.fade_to(1.0, 0.4)
	_into_yard()
	await Game.main.overlay.fade_to(0.0, 0.5)
	Game.cinematic = false
	await say(["n_c2s3_yard"])


## He is in the yard: the ground outside is behind the wall, and the far view is the yard's.
func _into_yard() -> void:
	inside = true
	refused = true
	asked = true
	ears["gate"]["on"] = false
	ask_task["on"] = false
	enter_task["on"] = false
	if court != null:
		court.visible = true
	if player.global_position.x < YARD_X + 80.0:
		player.reset_to(on_ground(INNER_X + 40.0))
	donkey.global_position = on_ground(player.global_position.x - 92.0)
	donkey.face = 1.0
	donkey.balking = false
	if is_instance_valid(kid):
		kid.global_position = on_ground(player.global_position.x - 158.0) + Vector2(0, 4)
	if is_instance_valid(youth):          # he goes ahead, to the door of the hall
		youth.position = on_ground(HALL_X - 90.0) + Vector2(0, 4)
		youth.visible = true
	player.cam.limit_left = int(YARD_X)
	player.cam.limit_right = int(width)
	player.cam.reset_smoothing()


# ------------------------------------------------------------------ the steward

func _near_load() -> bool:
	return is_instance_valid(donkey) and absf(donkey.global_position.x - STORE_X) < 330.0


func _offer() -> void:
	turned = true
	ears["store"]["on"] = true
	await say(["n_c2s3_steward", "n_c2s3_morning"])
	show_tip("He is too tired to hear it.  Play to him (R).  A man takes more than a sheep, and does not stay quiet long", 8.0)


func _hand_over() -> void:
	if given >= LOAD.size():
		return
	given += 1
	Game.sfx("gather", -8.0, 0.05)
	ears["store"]["calm"] = maxf(0.0, float(ears["store"]["calm"]) - TAKE)
	if given < LOAD.size():
		give_task["text"] = LOAD[given]
		return
	give_task["on"] = false
	ears["store"]["on"] = false
	donkey.led = false
	Game.sfx("lamb", -10.0, 0.1)
	if is_instance_valid(kid):
		kid.visible = false          # the steward's boy has taken it to the pens
	wait_task["on"] = true
	await say(["n_c2s3_received", "1sam16_20", "n_c2s3_whole"])


func _wait_called() -> void:
	await say(["n_c2s3_wait", "n_c2s3_called"])
	complete()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	if not placed:
		placed = true
		player.cam.limit_right = int(OUT_END)
	if not inside and player.global_position.x > OUT_END:      # he comes back to a watchfire inside the yard
		_into_yard()
	if not Game.cinematic:
		for who in ears:
			var e: Dictionary = ears[who]
			if e["calm"] > 0.0:
				e["calm"] = maxf(0.0, float(e["calm"]) - delta)
				if e["calm"] <= 0.0 and e["on"]:
					_hardened(who)
	if is_instance_valid(donkey) and is_instance_valid(kid) and kid.visible:      # the young goat goes where the load goes
		var at: Vector2 = donkey.global_position + Vector2(-donkey.face * 66.0, 0.0)
		kid.global_position = kid.global_position.lerp(Vector2(at.x, ground_y(at.x)), minf(1.0, delta * 6.0))
	ask_task["on"] = refused and not asked and ears["gate"]["calm"] > 0.0
	offer_task["on"] = inside and not turned and _near_load()
	give_task["on"] = turned and given < LOAD.size() and ears["store"]["calm"] > 0.0 and _near_load()
	set_goal(_goal_now())


func _goal_now() -> String:
	if not inside:
		if not refused:
			return "Go up to the gate of Gibeah"
		if asked:
			return "Lead the donkey in through the gate"
		if ears["gate"]["calm"] > 0.0:
			return "Ask for the young man who spoke of you"
		return "Play to the gatekeeper (R)"
	if given >= LOAD.size():
		return "Wait at the door of the hall, east"
	if is_instance_valid(donkey):
		if player.global_position.x - donkey.global_position.x > 480.0:
			return "Go back for the donkey, west"
	if not turned:
		return "Bring the gift to the steward at the storehouse, east"
	if not _near_load():
		return "Bring the donkey up to the storehouse"
	if ears["store"]["calm"] > 0.0:
		return LOAD[given]
	return "Play to the steward (R)"
