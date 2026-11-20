extends "res://scripts/levels/level_base.gd"
## 1.2 The Well. Evening outside Bethlehem. Four pieces of a shepherd's evening, each a small problem:
##  - the stone on the well is too heavy for a boy, until he finds something for his staff to bear on;
##  - the flocks have run together, and he must draw his own out of the crowd by voice;
##  - water is drawn by hand and there is never much of it, so other men's sheep must be kept off his troughs;
##  - at the fold the flock is counted in under the staff, and anything not his is turned back.
## What he learns here (lever, call, carry, the tap of the staff) is asked of him again in every later section.

const BASE := 580.0
const WELL_X := 2300.0
const OPEN_X := 2415.0
const TROUGHS := [2030.0, 1890.0]
const GATE := 3840.0
const HAND_REACH := 25.0     # his hands on the staff, ahead of him, while he bears down
const HAND_HIGH := 58.0
const HAND_DROP := 8.0
const LAMB := 8             # which of his own is the lamb: the flock is eight ewes and the lamb
const BUCKET_X := 1720.0

var stone: Dictionary
var fulcrum: Dictionary
var lever_task: Dictionary
var pack := {"run": 0, "beasts": [], "warning": 1.0}
var back_task: Dictionary
var heave_tilt := 0.0          # how far the stone is tipped while he bears on the staff
var heave_base := 0.0
var stone_moving := false      # the tween has the stone: the tilt lets go
var heave_dust := 0.0
var draw_task: Dictionary
var pour_tasks: Array = []
var carrying := false
var has_bucket := false     # the bucket and rope are kept by the terraces, out of the dust of the well-head
var bucket_prop: Sprite2D
var bucket_home: Vector2            # where the bucket stood before he took it up
var take_task: Dictionary
var bucket_down: Sprite2D           # set down at the well-head once all have drunk
var drinks: Array = [0, 0]          # mouthfuls left in each trough
var waters: Array = []              # the water sprite lying in each trough
var water_shown: Array = [0, 0]
var own: Array = []                 # his sheep: {"s": node, "state": mixed | led | drinking | watered | gone, "t": seconds at the water}
var others: Array = []              # other men's sheep: {"s", "home", "state": idle | going | drinking | shooed, "t"}
var opened := false
var watered := false
var closed := false
var tried := false
var mixed_up := false
var jackal
var jackal_sent := false
var hints_on: Array = []
# the count
var counting := false
var queue: Array = []
var passing: Variant = null
var in_fold := 0
var strangers_in := 0
var count_tries := 0
var _far := 0.0           # the farthest he has come, for the goal


func _setup() -> void:
	flutters = 2
	leaves = Color(1.0, 0.8, 0.6, 0.35)
	ambience = "dusk"
	mood = "theme_tender"
	backdrop_art = "res://art/well_backdrop.png"
	midground_art = "res://art/well_mid.png"
	mid_tint = Color(0.7, 0.6, 0.58)
	width = 4300.0
	pal.merge({
		"mist": Color(1.0, 0.7, 0.5, 0.07),
		"grass": Color(0.95, 0.72, 0.55), "ground": Color(0.7, 0.52, 0.45), "char": Color(1.0, 0.84, 0.74),
		"sky_top": Color(0.2, 0.25, 0.5), "sky_mid": Color(0.9, 0.5, 0.35), "sky_bot": Color(1.0, 0.7, 0.4),
		"sun_pos": Vector2(0.25, 0.7), "sun_col": Color(1.0, 0.7, 0.4), "sun_size": 0.09, "stars": 0.15,
		"far": Color(0.85, 0.5, 0.4), "near": Color(0.3, 0.2, 0.25), "rim": Color(1.0, 0.7, 0.45),
		"wool": Color(1.0, 0.88, 0.78), "mote": Color(1.0, 0.85, 0.5, 0.55),
	}, true)
	segments = [make_ground(0.0, width, BASE, 8.0, 0.6)]
	checkpoints = [160.0, 1640.0, 3300.0]
	ledge(760.0, 62.0, 150.0)
	ledge(950.0, 124.0, 170.0)
	ledge(1180.0, 186.0, 120.0)


func _populate() -> void:
	# beside the road down to the well: a threshing floor, with its winnowing fork and jars
	var tf := on_ground(1470.0)
	var floor_sp := add_sprite("res://art/props/threshing.png", tf + Vector2(0, 16), 1.0, 1, pal.get("char", Color(1, 1, 1)))
	floor_sp.scale = Vector2.ONE * (250.0 / floor_sp.texture.get_width())
	add_place("threshing", tf + Vector2(60, 0), "The Threshing Floor", "hand")
	# his own flock comes down with him: eight ewes and the lamb
	for i in 9:
		var s = add_sheep(130.0 - i * 14.0, null, i == LAMB)
		s.gathered = true
		s.follow_index = i
		followers.append(s)
		own.append({"s": s, "state": "led", "t": 0.0})
	# other men's sheep, already crowding the far side of the well. Each carries its owner's mark
	for i in 6:
		var x := 2520.0 + i * 42.0
		var o = add_sheep(x, null, false, "other")
		o.gathered = true
		o.gatherable = false
		o.stay = x
		o.max_speed = 120.0
		o.wool = pal["wool"].darkened(0.14)
		o.mark = Color(0.52, 0.2, 0.12, 0.8) if i % 2 == 0 else Color(0.2, 0.2, 0.26, 0.8)      # ruddle from one flock, soot from another
		others.append({"s": o, "home": x, "state": "idle", "t": 2.0 + i * 1.3})
	sheep_total = 0

	add_stone("well_start", on_ground(44.0))
	add_stone("well_terrace", Vector2(1240.0, platforms[2].position.y))
	add_store("well_store", 1520.0)    # hung in the olive past the terraces: for when he has a sling
	add_leap("well_leap", 540.0)                     # and a ledge for when he can leap at a run

	_well_prop(on_ground(WELL_X) + Vector2(0, 8))
	for i in TROUGHS.size():
		var at := on_ground(TROUGHS[i]) + Vector2(0, 10)
		var tr := add_sprite("res://art/props/trough.png", at, 1.0, 2, pal["char"])
		tr.scale = Vector2.ONE * (128.0 / tr.texture.get_width())
		# the water: a painted surface fitted to the hollow of the trough, one picture for each level
		var wt := add_sprite("res://art/props/trough_water3.png", at, 1.0, 2, pal["char"].lerp(Color(1, 1, 1), 0.5))
		wt.scale = tr.scale
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/water.gdshader")
		wt.material = wm
		wt.modulate.a = 0.0
		waters.append(wt)

	stone = add_pushable(WELL_X, 88.0, 92.0, "res://art/props/wellstone.png", WELL_X, OPEN_X, true)
	stone["on"] = Game.rank("hand") >= 2          # a grown hand can roll it with nothing but his shoulder
	# the stone is round: its shoulders are lower than its crown. What he has to clear to get over it is the
	# shoulder, well inside his jump, not the full height of the painting
	var over: CollisionShape2D = stone["body"].get_child(0)
	(over.shape as RectangleShape2D).size.y = 80.0
	over.position.y = 6.0
	stone["moved"] = func(x: float) -> void:
		if not opened and x >= OPEN_X - 4.0:
			_open_well()
	# a block of stone lying by the path: something for a lever to bear on
	fulcrum = add_pushable(2150.0, 46.0, 34.0, "res://art/props/rock_low.png", 2125.0, 2233.0)
	fulcrum["moved"] = _fulcrum_moved
	lever_task = add_task(2205.0, "lever the stone with the staff", 1.1, _lever, 44.0)
	lever_task["on"] = false
	var char_tint: Color = pal["char"]
	# his staff, set under the stone: both hands on it, the foot under the stone's near edge, the rod resting on the block
	add_painter(Vector2.ZERO, 6, func(ci: CanvasItem) -> void:
		if task_now == null or float(task_now["t"]) <= 0.0 or not is_instance_valid(player):
			return
		if task_now != lever_task and task_now != back_task:
			return
		var u := clampf(float(task_now["t"]) / float(task_now["hold"]), 0.0, 1.0)
		var tip_hands := _lever_geometry(u)
		_staff(ci, tip_hands[0], tip_hands[1], char_tint)
		ci.draw_circle(tip_hands[0], 3.2, Color(0.5, 0.33, 0.22) * char_tint)       # his fist closed round the wood
		ci.draw_circle(tip_hands[0] + Vector2(player.facing * 1.5, -0.8), 1.6, Color(0.66, 0.46, 0.32) * char_tint), true)
	# he levers it home from the far side, so the stone rolls away from him and never onto him
	back_task = add_task(OPEN_X + 82.0, "lever the stone back over the well", 1.1, _close_well, 36.0)
	back_task["on"] = false
	lever_task["anim"] = "push"          # braced low, leaning his weight into the staff
	back_task["anim"] = "push"

	add_trigger(1700.0, 1860.0, func() -> void: say(["n_well_custom"]))
	add_trigger(1900.0, 1960.0, _run_ahead)
	# before the water is in sight they have smelt it, and will not walk quietly: the place to play them still
	add_trigger(1400.0, 1500.0, func() -> void:
		for o in own:
			if o["state"] == "led":
				o["s"].hop = 1.0
		Game.sfx("sheep", -6.0, 0.2))
	add_song(1570.0, func() -> void: pass, 130.0)
	add_trigger(2200.0, 2262.0, func() -> void:
		if opened or stone["on"]:
			return
		tried = true
		_hint(2180.0, 250.0, "Too heavy.  Push the block up against it, for the staff to bear on")
		say(["n_well_heavy"]))
	add_hint(430.0, 150.0, "Lead them to the well")
	# the bucket and its rope: kept by the watchfire on the path, in plain sight, where every shepherd takes them and puts them back
	has_bucket = Game.fast or Game.backdrop
	if not has_bucket:
		bucket_prop = add_sprite("res://art/props/bucket.png", on_ground(BUCKET_X) + Vector2(0, 4), 1.0, 4, pal.get("char", Color(1, 1, 1)))
		bucket_prop.scale = Vector2.ONE * (46.0 / bucket_prop.texture.get_width())
		add_glow(on_ground(BUCKET_X) + Vector2(0, -14), Color(1.0, 0.85, 0.6, 0.6), 150.0)
		add_hint(BUCKET_X, 150.0, "The bucket and rope.  He will need them at the well")
		bucket_home = bucket_prop.position
		take_task = add_task(BUCKET_X, "take the bucket and rope", 0.5, func() -> void:
			has_bucket = true
			bucket_prop.visible = false
			Game.sfx("gather", -8.0, 0.0)
			show_tip("Bucket and rope.  Now the stone, then the water"))

	draw_task = add_task(WELL_X - 14.0, "draw water", 1.3, _drew, 50.0)
	draw_task["again"] = true
	draw_task["anim"] = "draw"          # he hauls the rope up hand over hand
	draw_task["on"] = false
	for x in TROUGHS:
		var tk := add_task(x, "pour it into the trough", 0.5, _poured.bind(pour_tasks.size()))
		tk["again"] = true
		tk["on"] = false
		tk["anim"] = "pour"
		tk["hold"] = 0.9
		pour_tasks.append(tk)

	var bucket: Texture2D = load("res://art/props/bucket.png")      # the leather bucket from the well painting
	# the bucket: carried low at his side by its strap, in the far hand, so his body passes in front of it,
	# with the rope coiled over the same wrist. Empty from the watchfire to the well, full from the well to the troughs.
	add_painter(Vector2.ZERO, 4, func(ci: CanvasItem) -> void:
		if not has_bucket or watered or not is_instance_valid(player) or Game.backdrop:
			return
		var busy: bool = task_now != null and float(task_now["t"]) > 0.0
		if busy and task_now.has("anim") and task_now != lever_task and task_now != back_task:      # drawing and tipping: the bucket is in his hands, in his own frames
			return
		var w := 25.0
		var h := w * bucket.get_height() / bucket.get_width()
		if busy and (task_now == lever_task or task_now == back_task):      # both hands on the staff: the bucket stands at his heel
			var at := on_ground(player.global_position.x - player.facing * 64.0)
			ci.draw_texture_rect(bucket, Rect2(at.x - w * 0.5, at.y - h + 2.0, w, h), false, char_tint)
			_coil(ci, at + Vector2(-player.facing * 13.0, -4.0), Vector2(1.0, 0.45), char_tint)
			return
		var walking := clampf(absf(player.velocity.x) / 120.0, 0.0, 1.0)
		var swing := sin(Time.get_ticks_msec() * 0.009) * (0.12 + 0.9 * walking)
		var hand: Vector2 = player.global_position + Vector2(player.facing * (7.0 + swing * 3.0), -47.0)
		var top := hand + Vector2(swing * 2.5, 9.0)
		_coil(ci, hand + Vector2(-player.facing * 3.0, 9.0), Vector2(0.62, 1.0), char_tint)      # behind the bucket
		ci.draw_line(hand, top + Vector2(-5, 3), Color(0.3, 0.22, 0.15) * char_tint, 1.8, true)
		ci.draw_line(hand, top + Vector2(5, 3), Color(0.3, 0.22, 0.15) * char_tint, 1.8, true)
		ci.draw_set_transform(top, swing * 0.12, Vector2.ONE)
		ci.draw_texture_rect(bucket, Rect2(-w * 0.5, 0.0, w, h), false, char_tint)
		if carrying:      # the water standing in it
			ci.draw_line(Vector2(-w * 0.36, 3.5), Vector2(w * 0.36, 3.5), Color(0.55, 0.72, 0.92, 0.9) * char_tint.lerp(Color(1, 1, 1), 0.5), 2.8, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if carrying and walking > 0.5 and int(Time.get_ticks_msec() / 260) % 5 == 0:      # it slops a little when he hurries
			ci.draw_circle(top + Vector2(player.facing * 6.0, 2.0), 1.5, Color(0.75, 0.86, 1.0, 0.6)), true)
	# a mark over each of his own that has not yet drunk
	add_painter(Vector2.ZERO, 6, func(ci: CanvasItem) -> void:
		if not opened or watered:
			return
		for o in own:
			if o["state"] in ["mixed", "led", "drinking"]:
				var p: Vector2 = o["s"].global_position + Vector2(0, -66.0 * o["s"].size)
				var dc := Color(0.86, 0.93, 1.0, 0.7)      # a small pale drop: enough to tell, not enough to shout
				ci.draw_circle(p + Vector2(0, 2), 2.8, dc)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.3, 1), p + Vector2(2.3, 1), p + Vector2(0, -4.5)]), dc), true)

	var fold := on_ground(3990.0)
	add_sprite("res://art/props/fold.png", fold + Vector2(0, 14), 1.5, 1)
	add_glow(fold + Vector2(190, -40), Color(1.0, 0.6, 0.25, 0.7), 240.0)
	add_trigger(GATE - 150.0, GATE - 90.0, _begin_count, false)
	# the tally, scratched one stroke for each of his own that passes in
	add_painter(on_ground(GATE) + Vector2(0, -210), 8, func(ci: CanvasItem) -> void:
		if not counting:
			return
		for i in in_fold:
			var x := -40.0 + i * 16.0 + (6.0 if i >= 5 else 0.0)
			ci.draw_line(Vector2(x, 0), Vector2(x + 3.0, 26), Color(1.0, 0.93, 0.78, 0.95), 3.0, true), true)


## The well: a low ring of stone, its dark mouth, a rope and a bucket. Painted when its picture has
## arrived (art/props/well.png); until then it is built from the stone of the trough painting.
func _well_prop(at: Vector2) -> void:
	if ResourceLoader.exists("res://art/props/well.png"):
		var sp := add_sprite("res://art/props/well.png", at, 1.0, 1, pal["char"])
		sp.scale = Vector2.ONE * (170.0 / sp.texture.get_width())
		return
	var src: Texture2D = load("res://art/props/trough.png")
	var wall := AtlasTexture.new()
	wall.atlas = src
	wall.region = Rect2(0, src.get_height() * 0.42, src.get_width(), src.get_height() * 0.46)
	var tint: Color = pal["char"]
	add_painter(at, 1, func(ci: CanvasItem) -> void:
		var w := 156.0
		var h := 58.0
		var rim := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			rim.append(Vector2(cos(a) * w * 0.5, -h + sin(a) * 11.0))
		ci.draw_colored_polygon(rim, Color(0.55, 0.47, 0.38) * tint)
		var mouth := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			mouth.append(Vector2(cos(a) * w * 0.38, -h + sin(a) * 7.0))
		ci.draw_colored_polygon(mouth, Color(0.03, 0.03, 0.05))
		ci.draw_texture_rect(wall, Rect2(-w * 0.5, -h, w, h + 4.0), false, tint)
		# the rope over the rim
		ci.draw_polyline(PackedVector2Array([Vector2(-20, -h - 2), Vector2(-34, -h + 6), Vector2(-40, -h + 30), Vector2(-52, -6)]), Color(0.5, 0.4, 0.26) * tint, 3.0, true))


## Where his hands and the foot of the staff are while he heaves (u: 0 to 1 across the hold). Returns [hands, tip].
## Levering up: the rod lies over the block, its foot under the stone's near edge, and as his hands go down the foot rises.
## Closing: the foot is dug in at the stone's near foot and he leans on it.
func _lever_geometry(u: float) -> Array:
	var f: float = player.facing
	var gy: float = on_ground(player.global_position.x).y
	var hands := Vector2(player.global_position.x + f * HAND_REACH, gy - HAND_HIGH + HAND_DROP * u)
	var tip: Vector2
	if task_now == lever_task and is_instance_valid(fulcrum["body"]):
		var block: StaticBody2D = fulcrum["body"]
		var top := Vector2(block.global_position.x + 8.0, block.global_position.y - 17.0)       # the stone's side of the block's top
		tip = top + (top - hands).normalized() * 34.0
		tip.y = minf(tip.y, gy - 4.0)
	else:
		var sx: float = stone["body"].global_position.x
		var side := signf(player.global_position.x - sx)
		tip = Vector2(sx + side * 36.0, gy - 5.0 - 9.0 * u)
	return [hands, tip]


## His staff as a lever: a long, round, slightly crooked rod of olive wood, the crook curling over his hands.
## Drawn to match the staff in his own hand (player.gd _draw_staff): the same wood, a lit edge, a dark under-side.
func _staff(ci: CanvasItem, hands: Vector2, tip: Vector2, tint: Color) -> void:
	var d := (tip - hands).normalized()
	var n := Vector2(-d.y, d.x)
	if n.y > 0.0:
		n = -n       # n points up, to the light
	var butt := hands - d * 9.0
	var length := butt.distance_to(tip)
	var pts := PackedVector2Array()
	for i in 13:          # a gentle bow along its length, and a kink where a branch was cut
		var f := i / 12.0
		var bow := sin(f * PI) * 2.6 + (1.2 if f > 0.55 and f < 0.7 else 0.0)
		pts.append(butt + d * length * f + n * bow)
	var wood := Color(0.34, 0.21, 0.11) * tint
	var dark := Color(0.15, 0.09, 0.05) * tint
	var lit := Color(0.55, 0.38, 0.22) * tint
	var shade := PackedVector2Array()
	for p in pts:
		shade.append(p - n * 1.2 + Vector2(0, 1.5))
	ci.draw_polyline(shade, Color(0.04, 0.03, 0.02, 0.45), 7.5, true)
	ci.draw_polyline(pts, dark, 6.6, true)
	ci.draw_polyline(pts, wood, 4.6, true)
	var hi := PackedVector2Array()
	for k in range(1, 12):
		hi.append(pts[k] + n * 1.4)
	ci.draw_polyline(hi, lit, 1.4, true)
	# round ends: a worn foot under the stone, the crook at the top end
	ci.draw_circle(tip, 3.2, dark)
	ci.draw_circle(tip, 2.2, wood)
	var a0 := atan2(-n.y, -n.x)
	var c := butt + n * 5.5
	var crook := PackedVector2Array()
	for k in 11:      # the hook curls up and back over his hands
		var a := a0 - (PI * 1.15) * (k / 10.0) * signf(d.cross(n))
		crook.append(c + Vector2(cos(a), sin(a)) * 5.5)
	ci.draw_polyline(crook, dark, 6.2, true)
	ci.draw_polyline(crook, wood, 4.2, true)
	ci.draw_circle(crook[crook.size() - 1], 2.0, wood)
	for f in [0.33, 0.62]:      # knots in the wood
		var kp: Vector2 = butt + d * length * f + n * sin(f * PI) * 2.6
		ci.draw_circle(kp, 1.3, dark)


## A coil of rope, hung from a wrist or lying in the dust.
func _coil(ci: CanvasItem, at: Vector2, squash: Vector2, tint: Color) -> void:
	var rope := Color(0.6, 0.48, 0.3) * tint
	var dark := Color(0.32, 0.24, 0.15) * tint
	for k in 3:
		ci.draw_set_transform(at + Vector2(k * 1.2 - 1.2, k * 1.0), 0.15 * (k - 1), squash)
		ci.draw_arc(Vector2.ZERO, 8.0 - k * 0.6, 0.0, TAU, 20, dark, 2.6, true)
		ci.draw_arc(Vector2.ZERO, 8.0 - k * 0.6, 0.0, TAU, 20, rope, 1.6, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hint(x: float, up: float, text: String) -> void:
	for h in hints_on:
		h["on"] = false
	hints_on = [add_hint(x, up, text)]


func begin() -> void:
	if not Game.main.intro.has_story("well"):      # the film before this section speaks the line itself
		await say(["n_well_intro"])


## They smell the water, and run on ahead into the other flocks.
func _run_ahead() -> void:
	if mixed_up:
		return
	mixed_up = true
	for i in own.size():
		if own[i]["s"].calm > 0.0:      # held by the lyre: it stays where he played, and comes on when he calls
			continue
		own[i]["state"] = "mixed"
		own[i]["s"].stay = 2530.0 + i * 34.0
		own[i]["s"].hop = 1.0
	Game.sfx("sheep", -6.0, 0.2)


## The stone answers the staff: while he bears down it tips about its far edge, a shudder in it, dust under the foot of the staff.
func _heave(delta: float) -> void:
	if stone_moving:
		return
	var heaving: bool = task_now != null and (task_now == lever_task or task_now == back_task) and float(task_now["t"]) > 0.0
	var sp: Sprite2D = stone["sp"] if stone.has("sp") and is_instance_valid(stone["sp"]) else null
	if sp == null:
		return
	var u := 0.0
	if heaving:
		u = clampf(float(task_now["t"]) / float(task_now["hold"]), 0.0, 1.0)
	var want := 0.0
	if u > 0.0:
		want = smoothstep(0.0, 0.85, u) * 0.13 + sin(Time.get_ticks_msec() * 0.03) * 0.006 * smoothstep(0.3, 0.8, u)
	if absf(want) < 0.0001 and absf(heave_tilt) < 0.0001:
		return
	if heave_tilt == 0.0:
		heave_base = sp.rotation          # the roll it already has, which the tilt rides on
	heave_tilt = move_toward(heave_tilt, want, delta * 0.6)
	var side := 1.0           # it tips about the edge away from him
	if is_instance_valid(player) and player.global_position.x > stone["body"].global_position.x:
		side = -1.0
	var a: float = heave_tilt * side
	var pv := Vector2(side * 42.0, 46.0)           # the far foot of the stone, in its own frame
	sp.rotation = heave_base + a
	sp.position = pv - pv.rotated(a)
	if heaving and u > 0.15:
		heave_dust -= delta
		if heave_dust <= 0.0:
			heave_dust = 0.28
			var at: Vector2 = _lever_geometry(u)[1]
			Game.burst(self, Vector2(at.x + side * 6.0, on_ground(at.x).y - 2.0), Color(0.78, 0.7, 0.56, 0.5), 3, 38.0)
	if not heaving and absf(heave_tilt) < 0.0002:
		heave_tilt = 0.0
		sp.position = Vector2.ZERO


func _fulcrum_moved(x: float) -> void:
	if not opened and x >= 2226.0:
		fulcrum["on"] = false
		lever_task["on"] = true
		Game.sfx("hit", -8.0, 0.1)
		_hint(2205.0, 250.0, "E  hold: set the staff under the stone and heave")


func _lever() -> void:
	stone_moving = true
	heave_tilt = 0.0
	stone["on"] = false
	Game.sfx("bridge", -6.0)
	player.shake = maxf(player.shake, 3.0)
	var body: StaticBody2D = stone["body"]
	if Game.fast:
		body.position.x = OPEN_X
		stone["sp"].position = Vector2.ZERO
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(body, "position:x", OPEN_X, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(stone["sp"], "position", Vector2.ZERO, 0.6)
		tw.tween_property(stone["sp"], "rotation", (OPEN_X - WELL_X) / 46.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	# the block has done its work: it tips aside into the dust, and the well-head is clear to stand at
	for part in [fulcrum["body"], fulcrum["sp"]]:
		if is_instance_valid(part):
			part.queue_free()
	fulcrum["on"] = false
	_open_well()


func _on_respawn() -> void:
	carrying = false
	if is_instance_valid(player):
		player.calm = false
	if opened and not watered:
		draw_task["on"] = true
		for tk in pour_tasks:
			tk["on"] = false


func _open_well() -> void:
	if opened:
		return
	opened = true
	stone["on"] = false
	lever_task["on"] = false
	draw_task["on"] = true
	Game.sfx("bridge", -4.0)
	if not mixed_up:
		_run_ahead()
	if not Game.has("hand"):       # the trial of this place: the water has been smelt, and he must hold the well with what he has
		show_tip("Something has smelt the water", 4.0)
		Game.music("battle", 0.8)
		await send_wave(WELL_X - 560.0, WELL_X + 520.0, 3, true, true, pack)
		Game.music(mood, 2.0)
	await give_here("hand")        # held: the gift of this place
	_hint(WELL_X - 14.0, 265.0, "E  hold: draw water")
	await say(["n_well_stone", "n_well_voice", "n_well_draw"])


func _drew() -> void:
	if not has_bucket:          # he passed them by: the bucket and rope kept at the well-head will do, so he is never turned away
		has_bucket = true
		if is_instance_valid(bucket_prop):
			bucket_prop.visible = false
	carrying = true
	player.calm = true
	draw_task["on"] = false
	Game.sfx("step", -4.0, 0.2)
	for tk in pour_tasks:
		tk["on"] = true


func _poured(which: int) -> void:
	carrying = false
	player.calm = false
	for tk in pour_tasks:
		tk["on"] = false
	draw_task["on"] = not watered
	drinks[which] = mini(6, drinks[which] + 4)      # a bucket waters four; the trough holds six mouthfuls
	Game.sfx("step", -3.0, 0.3)
	Game.burst(self, on_ground(TROUGHS[which]) + Vector2(0, -40), Color(0.6, 0.8, 1.0, 0.8), 12, 90.0)
	if not hints_on.is_empty() and not watered:
		_hint(TROUGHS[0] - 60.0, 265.0, "J  drive off the strangers")


## One of his own leaves the crowd and comes to him.
func lead(o: Dictionary) -> void:
	if o["state"] != "mixed":
		return
	o["state"] = "led"
	o["s"].stay = NAN
	o["s"].hop = 1.0
	Game.sfx("lamb" if o["s"].size < 0.9 else "sheep", -7.0, 0.15)
	Game.grow("voice", 1.0)


func shepherd_call(from: Vector2, reach: float, startle: bool) -> void:
	super.shepherd_call(from, reach, startle)
	for o in own:      # his own know his voice. The others do not so much as lift their heads
		if absf(o["s"].global_position.x - from.x) < reach:
			lead(o)


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player) or Game.backdrop:
		return
	_heave(delta)
	if not has_bucket and is_instance_valid(bucket_prop) and not take_task.is_empty():      # as he bends to it, it comes up into his hand
		var u := smoothstep(0.35, 1.0, float(take_task["t"]) / float(take_task["hold"])) if task_now == take_task else 0.0
		var held: Vector2 = player.global_position + Vector2(player.facing * 7.0, -6.0)      # where the bottom of the carried bucket hangs
		bucket_prop.position = bucket_home.lerp(held, u)
		bucket_prop.scale = Vector2.ONE * lerpf(46.0, 25.0, u) / bucket_prop.texture.get_width()
	if not has_bucket and absf(player.global_position.x - BUCKET_X) < 44.0:      # he takes it up as he passes: no key to find
		has_bucket = true
		if is_instance_valid(bucket_prop):
			bucket_prop.visible = false
		Game.sfx("gather", -8.0, 0.0)
		show_tip("Bucket and rope.  Now the stone, then the water")
	for i in waters.size():          # the water stands at the level of what is left, and sinks as they drink
		var lvl: int = clampi((drinks[i] + 1) / 2, 0, 3)
		var wt: Sprite2D = waters[i]
		if lvl > 0 and lvl != water_shown[i]:
			wt.texture = load("res://art/props/trough_water%d.png" % lvl)
			water_shown[i] = lvl
		wt.modulate.a = move_toward(wt.modulate.a, 1.0 if lvl > 0 else 0.0, delta * 1.6)
		if lvl == 0 and wt.modulate.a <= 0.0:
			water_shown[i] = 0
	var lamb = own[LAMB]["s"]
	if own[LAMB]["state"] == "gone" and lamb.visible and lamb.global_position.x > 3700.0 \
			and absf(lamb.global_position.x - player.global_position.x) > 800.0:
		lamb.visible = false          # gone, with nobody watching
	if counting:
		if is_instance_valid(player):      # he stands at the gate with his hand out: nothing reaches him until the count is told
			player.invuln = maxf(player.invuln, 0.3)
		_count_step()
		return
	if not opened or watered or Game.cinematic:
		return
	var wet := -1          # a trough with water in it, the nearer to him first
	for i in drinks.size():
		if drinks[i] > 0 and (wet < 0 or absf(TROUGHS[i] - player.global_position.x) < absf(TROUGHS[wet] - player.global_position.x)):
			wet = i
	var left := 0
	for k in own.size():
		var o: Dictionary = own[k]
		var s = o["s"]
		match o["state"]:
			"mixed":
				left += 1
				# only once it is in among the others: running past him on its way there, it is not yet his to lead
				if s.global_position.distance_to(player.global_position) < 58.0 and (is_nan(s.stay) or absf(s.global_position.x - s.stay) < 40.0):
					lead(o)
			"led":
				left += 1
				if wet >= 0:
					o["state"] = "drinking"
					o["at"] = wet
					o["t"] = 0.0
					s.stay = TROUGHS[wet] + (-80.0 + k * 20.0)
			"drinking":
				left += 1
				var tr: int = o["at"]
				if drinks[tr] <= 0:
					o["state"] = "led"
					s.stay = NAN
				elif absf(s.global_position.x - s.stay) < 20.0:
					o["t"] += delta
					if o["t"] > 2.0:
						drinks[tr] -= 1
						o["state"] = "watered"
						s.stay = 1770.0 - k * 30.0
						s.hop = 0.6
						Game.burst(self, s.global_position + Vector2(0, -40), Color(0.6, 0.8, 1.0, 0.8), 6, 70.0)
						Game.grow("heart", 0.5)
	# other men's sheep smell the water and come for it, one at a time
	var busy := false
	for o in others:
		if o["state"] in ["going", "drinking"]:
			busy = true
	for o in others:
		var s = o["s"]
		match o["state"]:
			"idle":
				o["t"] -= delta
				if wet >= 0 and o["t"] <= 0.0 and not busy:
					busy = true
					o["state"] = "going"
					o["at"] = wet
					s.stay = TROUGHS[wet] + 60.0
			"going", "drinking":
				var tr: int = o["at"]
				if player.attack_t > 0.0 and absf(s.global_position.x - player.global_position.x) < 84.0:
					o["state"] = "shooed"       # the tap of the staff: it knows what that means
					o["t"] = 11.0
					s.stay = o["home"]
					s.hop = 1.0
					Game.sfx("sheep", -6.0, 0.25)
					Game.grow("hand", 1.0)
				elif drinks[tr] <= 0:
					o["state"] = "shooed"
					o["t"] = 4.0
					s.stay = o["home"]
				elif absf(s.global_position.x - s.stay) < 20.0:
					o["state"] = "drinking"
					o["t"] = float(o.get("sip", 0.0)) + delta
					o["sip"] = o["t"]
					if o["t"] > 2.6:
						o["sip"] = 0.0
						drinks[tr] = maxi(0, drinks[tr] - 2)      # a stranger at the trough costs him half a bucket
						o["state"] = "shooed"
						o["t"] = 7.0
						s.stay = o["home"]
			"shooed":
				o["t"] -= delta
				if o["t"] <= 0.0:
					o["state"] = "idle"
					o["t"] = 3.0
	var done_n := 0
	for o in own:
		if o["state"] == "watered":
			done_n += 1
	if done_n >= 3 and not jackal_sent:
		_jackal_comes()
	if left == 0 and done_n > 0:
		_all_watered()


## Dusk. Something has come down from the hills to see what is unguarded. And while every eye is on it, the lamb strays.
func _jackal_comes() -> void:
	jackal_sent = true
	jackal = add_jackal(3250.0, 1700.0, 3300.0)
	jackal.dir = -1
	Game.music("battle", 0.8)
	jackal.defeated.connect(func() -> void: Game.music(mood, 2.0))
	var lamb: Dictionary = own[LAMB]
	if lamb["state"] != "gone":
		lamb["state"] = "gone"
		lamb["s"].safe = true
		lamb["s"].max_speed = 70.0
		lamb["s"].stay = 4290.0
		followers.erase(lamb["s"])
	await say(["n_well_jackal"])


func _all_watered() -> void:
	watered = true
	carrying = false
	_set_bucket_down()
	player.calm = false
	draw_task["on"] = false
	for tk in pour_tasks:
		tk["on"] = false
	back_task["on"] = true
	_hint(OPEN_X + 82.0, 250.0, "Put the stone back over the well")
	await say(["n_well_back"])      # the verse itself comes just after, as his own line
	await line_here("p23_waters")


## His work at the troughs done, he sets the bucket and rope down at the well-head for the next man.
func _set_bucket_down() -> void:
	if is_instance_valid(bucket_down):
		return
	bucket_down = add_sprite("res://art/props/bucket.png", on_ground(WELL_X - 110.0) + Vector2(0, 4), 1.0, 2, pal.get("char", Color(1, 1, 1)))
	bucket_down.scale = Vector2.ONE * (34.0 / bucket_down.texture.get_width())
	bucket_down.modulate.a = 0.0          # it is set down, not switched on
	create_tween().tween_property(bucket_down, "modulate:a", 1.0, 0.5)
	add_painter(Vector2.ZERO, 2, func(ci: CanvasItem) -> void:
		_coil(ci, on_ground(WELL_X - 86.0) + Vector2(0, -3), Vector2(1.0, 0.45), pal["char"] * Color(1, 1, 1, bucket_down.modulate.a)))


## For screenshots (selftest placeshots, POSE=...): set the well up for one moment of the work.
## Returns how many frames the work key is to be held before the picture is taken.
func pose(p: String) -> int:
	if p == "take":
		return 22
	has_bucket = true
	if is_instance_valid(bucket_prop):
		bucket_prop.visible = false
	match p:
		"carry":
			return 0
		"full":
			carrying = true
			return 0
		"lever":
			player.facing = 1
			fulcrum["body"].position.x += 80.0
			_fulcrum_moved(2230.0)
			return 40
	# the rest are at the open well
	opened = true
	stone["on"] = false
	lever_task["on"] = false
	stone["body"].position.x = OPEN_X
	stone["sp"].rotation = (OPEN_X - WELL_X) / 46.0
	match p:
		"draw":
			player.facing = 1
			draw_task["on"] = true
			return 45
		"close":
			player.facing = -1
			watered = true
			_set_bucket_down()
			back_task["on"] = true
			return 40
	return 0


func _close_well() -> void:
	stone_moving = true
	heave_tilt = 0.0
	closed = true
	Game.sfx("bridge", -4.0)
	var body: StaticBody2D = stone["body"]
	# nothing that rolls may close on him: if he is anywhere in its path he is stood clear of it first
	if player.global_position.x < OPEN_X + 50.0 and player.global_position.x > WELL_X - 70.0:
		player.global_position = on_ground(OPEN_X + 82.0)
		player.velocity = Vector2.ZERO
	if Game.fast:
		body.position.x = WELL_X
		stone["sp"].position = Vector2.ZERO
		stone["sp"].rotation = 0.0
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(stone["sp"], "position", Vector2.ZERO, 0.6)
		tw.tween_property(body, "position:x", WELL_X, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(stone["sp"], "rotation", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for o in own:
		if o["state"] != "gone":
			o["s"].stay = NAN
	_hint(3300.0, 150.0, "Count them in at the fold")


# ------------------------------------------------------------------ the count

## At the gate he holds the staff across the gap and they pass under it one at a time. Two that are not his
## have followed the flock up from the well: a tap of the staff turns each back. Tap one of his own and it balks.
func _begin_count() -> void:
	if not closed or counting or done:
		return
	counting = true
	in_fold = 0
	strangers_in = 0
	count_tries += 1
	player.velocity.x = 0.0
	player.position = on_ground(GATE)
	player.facing = -1
	player.act = "count"
	queue = []
	var mine: Array = []
	for o in own:
		if o["state"] != "gone":
			mine.append({"s": o["s"], "mine": true})
	var theirs: Array = [{"s": others[0]["s"], "mine": false}, {"s": others[1]["s"], "mine": false}]
	var order := [0, 0, 2, 0, 0, 0, 1, 0, 0, 0] if count_tries % 2 == 1 else [0, 1, 0, 0, 0, 0, 2, 0, 0, 0]      # 0 one of his; 1 and 2 the two strangers, once each
	var mi := 0
	for code in order:
		if code == 0 and mi < mine.size():
			queue.append(mine[mi])
			mi += 1
		elif code > 0:
			queue.append(theirs[code - 1])
	while mi < mine.size():
		queue.append(mine[mi])
		mi += 1
	# the queue forms where they are: nothing in view is lifted and set down. Anything far off, or that is
	# to be called back out of the fold, comes in from beyond the edge of the screen and walks to its place
	var half_view := get_viewport_rect().size.x * 0.5 / maxf(0.1, player.cam.zoom.x) + 80.0
	for i in queue.size():
		var s = queue[i]["s"]
		s.max_speed = 92.0
		var place := GATE - 250.0 - i * 40.0
		var seen: bool = absf(s.global_position.x - player.global_position.x) < half_view
		if not seen:
			var from := minf(place, player.global_position.x - half_view - 20.0)
			s.global_position = on_ground(from)
		s.stay = place
	passing = null
	_hint(GATE - 60.0, 290.0, "J  turn back the marked ones")
	if count_tries == 1:
		await say(["n_well_count"])


func under_rod() -> Variant:
	if passing != null and passing["s"].global_position.x > GATE - 96.0 and passing["s"].global_position.x < GATE - 22.0:
		return passing
	return null


## The tap of the staff at the gate.
func rod() -> void:
	var u: Variant = under_rod()
	if u == null:
		return
	var s: Node2D = u["s"]
	s.hop = 1.0
	Game.sfx("sheep", -6.0, 0.25)
	if u["mine"]:           # one of his own: it shies, and must come round again
		s.stay = GATE - 250.0 - queue.size() * 40.0
		queue.append(u)
	else:
		s.max_speed = 160.0
		s.stay = GATE - 820.0
		Game.grow("eye", 2.0)
	passing = null


func _count_step() -> void:
	if Input.is_action_just_pressed("attack"):
		rod()
	if passing == null:
		if queue.is_empty():
			_count_done()
			return
		passing = queue.pop_front()
		passing["s"].stay = GATE + 110.0 + in_fold * 20.0 + strangers_in * 20.0
		for i in queue.size():      # the rest shuffle up
			queue[i]["s"].stay = GATE - 250.0 - i * 40.0
	elif passing["s"].global_position.x > GATE - 20.0:
		if passing["mine"]:
			in_fold += 1
			Game.sfx("gather", -10.0, 0.05)
		else:
			strangers_in += 1
		passing = null


func _count_done() -> void:
	counting = false
	player.act = ""
	if strangers_in > 0:      # another man's ewe is in among them: out they all come, and again
		await say(["n_well_count_wrong"])
		_begin_count()
		return
	for h in hints_on:
		h["on"] = false
	await say(["n_s1_end"])
	complete()


## What he is to do now, from where things stand. Polled, so it is right at any checkpoint too.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_far = maxf(_far, player.global_position.x)
	set_goal(_goal_now())


func _goal_now() -> String:
	if counting:
		return "Turn back the marked sheep (J)"
	if closed:
		return "Count the flock in at the gate, east"
	if watered:
		return "Put the stone back over the well"
	if not opened:
		if not has_bucket:
			if player.global_position.x > BUCKET_X + 300.0:
				return "Fetch the bucket and rope, back west"
			return "Find the bucket and rope by the watchfire"
		if stone["on"]:
			return "Roll the stone off the well"
		if fulcrum["on"]:
			return "Push the block against the well stone"
		return "Set the staff under the stone and heave"
	if not Game.has("hand"):
		return "Drive off the beasts at the well"
	if is_instance_valid(jackal) and jackal_sent and not jackal.fleeing:
		return "Drive off the jackal"
	if carrying:
		return "Pour the water into a trough, west"
	var mixed_n := 0
	var unwatered := 0
	for o in own:
		if o["state"] == "mixed":
			mixed_n += 1
		if o["state"] in ["mixed", "led", "drinking"]:
			unwatered += 1
	if mixed_n > 0:
		return "Call your own out of the crowd (Q)"
	var wet := int(drinks[0]) + int(drinks[1])
	for o in others:
		if o["state"] in ["going", "drinking"]:
			return "Drive the strange sheep off the troughs (J)"
	if wet < unwatered:
		return "Draw water from the well"
	return "Guard the troughs while they drink"
