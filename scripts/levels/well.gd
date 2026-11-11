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

var stone: Dictionary
var fulcrum: Dictionary
var lever_task: Dictionary
var pack := {"run": 0, "beasts": [], "warning": 1.0}
var back_task: Dictionary
var draw_task: Dictionary
var pour_tasks: Array = []
var carrying := false
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
	# his own flock comes down with him: four ewes and the lamb
	for i in 5:
		var s = add_sheep(130.0 - i * 30.0, null, i == 4)
		s.gathered = true
		s.follow_index = i
		followers.append(s)
		own.append({"s": s, "state": "led", "t": 0.0})
	# other men's sheep, already crowding the far side of the well. Each carries its owner's mark
	for i in 6:
		var x := 2520.0 + i * 42.0
		var o = add_sheep(x)
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
	stone["moved"] = func(x: float) -> void:
		if not opened and x >= OPEN_X - 4.0:
			_open_well()
	# a block of stone lying by the path: something for a lever to bear on
	fulcrum = add_pushable(2150.0, 46.0, 34.0, "res://art/props/rock_low.png", 2125.0, 2233.0)
	fulcrum["moved"] = _fulcrum_moved
	lever_task = add_task(2205.0, "lever the stone with the staff", 1.1, _lever, 44.0)
	lever_task["on"] = false
	# he levers it home from the far side, so the stone rolls away from him and never onto him
	back_task = add_task(OPEN_X + 82.0, "lever the stone back over the well", 1.1, _close_well, 36.0)
	back_task["on"] = false

	add_trigger(1700.0, 1860.0, func() -> void: say(["n_well_custom"]))
	add_trigger(1900.0, 1960.0, _run_ahead)
	add_trigger(2200.0, 2262.0, func() -> void:
		if opened or stone["on"]:
			return
		tried = true
		_hint(2225.0, 250.0, "Too heavy.  Find something to lever it with")
		say(["n_well_heavy"]))
	add_hint(430.0, 150.0, "Lead them to the well")

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

	var char_tint: Color = pal["char"]
	var bucket: Texture2D = load("res://art/props/bucket.png")      # the leather bucket from the well painting
	# the bucket: carried low at his side by its strap, in the far hand, so his body passes in front of it
	add_painter(Vector2.ZERO, 4, func(ci: CanvasItem) -> void:
		if not carrying or (task_now != null and float(task_now["t"]) > 0.0):      # while he tips it, the bucket is in his hands, in his own frames
			return
		var walking := clampf(absf(player.velocity.x) / 120.0, 0.0, 1.0)
		var swing := sin(Time.get_ticks_msec() * 0.009) * (0.12 + 0.9 * walking)
		var hand: Vector2 = player.global_position + Vector2(player.facing * (7.0 + swing * 3.0), -47.0)
		var w := 25.0
		var h := w * bucket.get_height() / bucket.get_width()
		var top := hand + Vector2(swing * 2.5, 9.0)
		ci.draw_line(hand, top + Vector2(-5, 3), Color(0.3, 0.22, 0.15) * char_tint, 1.8, true)
		ci.draw_line(hand, top + Vector2(5, 3), Color(0.3, 0.22, 0.15) * char_tint, 1.8, true)
		ci.draw_set_transform(top, swing * 0.12, Vector2.ONE)
		ci.draw_texture_rect(bucket, Rect2(-w * 0.5, 0.0, w, h), false, char_tint)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if walking > 0.5 and int(Time.get_ticks_msec() / 260) % 5 == 0:      # it slops a little when he hurries
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
		own[i]["state"] = "mixed"
		own[i]["s"].stay = 2540.0 + i * 46.0
		own[i]["s"].hop = 1.0
	Game.sfx("sheep", -6.0, 0.2)


func _fulcrum_moved(x: float) -> void:
	if not opened and x >= 2226.0:
		fulcrum["on"] = false
		lever_task["on"] = true
		Game.sfx("hit", -8.0, 0.1)


func _lever() -> void:
	stone["on"] = false
	Game.sfx("bridge", -6.0)
	player.shake = maxf(player.shake, 3.0)
	var body: StaticBody2D = stone["body"]
	if Game.fast:
		body.position.x = OPEN_X
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(body, "position:x", OPEN_X, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(stone["sp"], "rotation", (OPEN_X - WELL_X) / 46.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	_open_well()


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
	_hint(WELL_X - 150.0, 265.0, "Q  call your own")
	await say(["n_well_stone", "n_well_voice", "n_well_draw"])


func _drew() -> void:
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
	drinks[which] = mini(3, drinks[which] + 2)
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
	for i in waters.size():          # the water stands at the level of what is left, and sinks as they drink
		var lvl: int = clampi(drinks[i], 0, 3)
		var wt: Sprite2D = waters[i]
		if lvl > 0 and lvl != water_shown[i]:
			wt.texture = load("res://art/props/trough_water%d.png" % lvl)
			water_shown[i] = lvl
		wt.modulate.a = move_toward(wt.modulate.a, 1.0 if lvl > 0 else 0.0, delta * 1.6)
		if lvl == 0 and wt.modulate.a <= 0.0:
			water_shown[i] = 0
	var lamb = own[4]["s"]
	if own[4]["state"] == "gone" and lamb.visible and lamb.global_position.x > 3700.0:
		lamb.visible = false          # gone, with nobody watching
	if counting:
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
				if s.global_position.distance_to(player.global_position) < 58.0:
					lead(o)
			"led":
				left += 1
				if wet >= 0:
					o["state"] = "drinking"
					o["at"] = wet
					o["t"] = 0.0
					s.stay = TROUGHS[wet] + (-52.0 + k * 22.0)
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
						s.stay = 1770.0 - k * 34.0
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
						drinks[tr] -= 1
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
	var lamb: Dictionary = own[4]
	if lamb["state"] != "gone":
		lamb["state"] = "gone"
		lamb["s"].max_speed = 70.0
		lamb["s"].stay = 4290.0
		followers.erase(lamb["s"])
	await say(["n_well_jackal"])


func _all_watered() -> void:
	watered = true
	draw_task["on"] = false
	for tk in pour_tasks:
		tk["on"] = false
	back_task["on"] = true
	_hint(OPEN_X + 82.0, 250.0, "Put the stone back over the well")
	await say(["ps23_2", "n_well_back"])


func _close_well() -> void:
	closed = true
	Game.sfx("bridge", -4.0)
	var body: StaticBody2D = stone["body"]
	# nothing that rolls may close on him: if he is anywhere in its path he is stood clear of it first
	if player.global_position.x < OPEN_X + 50.0 and player.global_position.x > WELL_X - 70.0:
		player.global_position = on_ground(OPEN_X + 82.0)
		player.velocity = Vector2.ZERO
	if Game.fast:
		body.position.x = WELL_X
	else:
		var tw := create_tween().set_parallel(true)
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
	var order := [0, 2, 0, 0, 1, 0] if count_tries % 2 == 1 else [1, 0, 0, 2, 0, 0]      # 0 one of his; 1 and 2 the two strangers, once each
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
	for i in queue.size():
		var s = queue[i]["s"]
		s.max_speed = 92.0
		s.global_position = on_ground(GATE - 250.0 - i * 44.0)
		s.stay = s.global_position.x
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
		s.stay = GATE - 250.0 - queue.size() * 44.0
		queue.append(u)
	else:
		s.max_speed = 160.0
		s.stay = GATE - 700.0
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
		passing["s"].stay = GATE + 110.0 + in_fold * 26.0 + strangers_in * 26.0
		for i in queue.size():      # the rest shuffle up
			queue[i]["s"].stay = GATE - 250.0 - i * 44.0
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
