extends "res://scripts/levels/level_base.gd"
## 2.4 The King's Hall. Evening in the hall at Gibeah (1 Samuel 16:21-23, with 16:16 quoted).
## He is brought in, and plays for the king for the first time. The playing is the whole section.
##
## The king's trouble is shown as one thing only: his own shadow on the wall behind him, cast by the lamp, standing
## taller than the lamp can account for. Nothing else is ever shown. Each phrase that lands brings the shadow
## down; a phrase let go too soon lets it grow; left alone it creeps up. It comes in swells: for a few seconds the
## breath line shakes, or runs faster, and the shadow rises quicker. A phrase landed inside a swell counts for
## more and cuts the swell short. As phrases land, the lines of Psalm 23 he already has are written in the
## psalm's order (the proposal's default: he plays the psalm the player made in Chapter One).
##
## When the shadow is all the way down the king rests, and the King's Favour is given. Failing is gentle: the
## king turns his face to the wall, the steward has him wait, and he begins again.
##
## The room is one screen: the camera is held still (VIEW_L to VIEW_R), so the painted wall and the shadow drawn
## on it never slide against each other, and he is walled in between the door and the king.
## Section 6 (the Night Fit) is meant to extend this script: everything it would tune is a `var` set in
## `_tune()`, and `_swell_begins()` / `_on_phrase()` are there to hang lamps and the rest on.

const VIEW_L := 100.0          # what the still camera shows of the room (it looks in at 1.18)
const VIEW_R := 1185.0
const PAINT_L := 0.47          # the part of the hall painting the view takes in, as fractions of its width
const PAINT_R := 0.86
const PAINT_FLOOR := 0.645     # where its back wall meets its floor, as a fraction of its height
const DOOR_X := 150.0
const START_X := 360.0
const LAMP_X := 660.0
const KING_X := 850.0
const NEAR := 230.0            # he does not sit down under the king's feet, nor beyond the lamp
const FAR := 430.0             # nor play from the door: within this of the king, the king hears
const WALL_UP := 16.0          # the foot of the wall behind the king is this far above the floor he sits on
const TOP_CREEP := 0.9         # left alone the shadow rises only this far: it takes a lost phrase to turn him away

# what the Night Fit would change
var start_shadow := 0.62       # how tall the shadow stands when he begins (0 the king at rest, 1 he turns away)
var down := 0.075              # a landed phrase brings it down this much
var up := 0.1                  # a lost one lets it grow this much
var creep := 0.012             # and every second it rises this much by itself
var swell_creep := 0.035       # more while a swell is on
var swell_every := 12.0        # seconds of quiet between swells
var swell_long := 5.0          # how long one lasts
var swell_shake := 0.9         # how hard a shaking swell shakes the breath line (song_noise)
var swell_hurry := 0.7         # how much faster a hurrying one makes it run (song_pace)
var swell_worth := 1.5         # a phrase landed inside a swell counts this many times

var shadow := 0.62
var shown := 0.62              # what is drawn: follows `shadow`, and lifts with a swell
var trial := false             # the playing has begun
var rested := false
var turning := false
var turned_once := false
var swell := 0.0               # 0 to 1: how strongly the trouble is rising just now
var swell_on := 0.0            # seconds left of the swell
var swell_wait := 6.0          # seconds to the next
var swell_kind := 0            # 0 it shakes the line, 1 it hurries it
var swell_told := false
var lost_told := false
var far_told := false
var landed := 0                # phrases landed since he last began
var lines: Array = []          # the lines of the psalm he has, in the psalm's order
var line_i := 0
var line_id := ""
var line_t := 0.0              # seconds the line has been on the screen
var king: Node2D
var king_tex: Texture2D
var king_clock := 0.0
var rest_t := -1.0             # seconds since he began to ease; below zero while he is troubled
var steward: Node2D
var youth: Node2D
var lamp_glow: Sprite2D
var room: Sprite2D             # the painting of the hall, for a later section to dim
var turn_say: Array = ["n_c2s4_turn"]      # what is told the first time the king turns away
var clock := 0.0
var placed := false
var pose_play := 0             # for a screenshot: frames until the lyre key is pressed for him


func _tune() -> void:
	pass


func _setup() -> void:
	mood = "theme_tender"
	ambience = "dusk"
	backdrop_art = "res://art/c2_hall_backdrop.png"
	width = 1280.0
	barren = true
	birds = false
	flutters = 0
	pal.merge({
		"mist": Color(1.0, 0.8, 0.6, 0.03), "mote": Color(1.0, 0.8, 0.5, 0.3),
		"ground": Color(0.4, 0.31, 0.26), "char": Color(1.0, 0.86, 0.7),
		"near": Color(0.22, 0.16, 0.14), "rim": Color(1.0, 0.72, 0.42),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 0.0, 0.0)]
	checkpoints = [START_X]
	_tune()
	shadow = start_shadow
	shown = start_shadow


func _ready() -> void:
	super._ready()
	for L in layers:          # nothing grows in a hall: the dark grass at the foot of the screen is put away
		if L.get("flat", false):
			(L["node"] as Node2D).visible = false
	if backdrop_art != "" and not layers.is_empty() and (layers[0]["node"] as Node).get_child_count() > 0:
		# The painting is a whole room seen in perspective, with side walls that run down towards the viewer: figures
		# set before those would seem to stand on the wall. So only its back wall is used, drawn large and fixed to the
		# room (no parallax): the view takes in the painting from PAINT_L to PAINT_R of its width, and the line where
		# its back wall meets its floor (PAINT_FLOOR of its height) lies just behind the figures' feet.
		var far: Node2D = layers[0]["node"]
		var bg := far.get_child(0) as Sprite2D
		room = bg
		layers.remove_at(0)
		far.position = Vector2.ZERO
		var wide := (VIEW_R - VIEW_L) / (PAINT_R - PAINT_L)
		var k := wide / bg.texture.get_width()
		bg.scale = Vector2(k, k)
		bg.position = Vector2(VIEW_L - PAINT_L * wide, 566.0 - WALL_UP - PAINT_FLOOR * bg.texture.get_height() * k)


## The floor is the painting's own: no strip of hill ground is laid over it, and nothing is strewn on it.
func _skin_ground(_poly: PackedVector2Array, _top: PackedVector2Array, _parent: Node = null, _z: int = 2) -> void:
	pass


func _dress(_seg: PackedVector2Array) -> void:
	pass


func _populate() -> void:
	_build_lamps()
	# the corners of the room are beyond the lamp: the painting's side walls, and what the frame cuts through there, stand in the dark
	var dusk := Color(0.035, 0.025, 0.04)
	for side in [[VIEW_L - 40.0, VIEW_L + 70.0, VIEW_L + 230.0], [VIEW_R + 40.0, VIEW_R - 40.0, VIEW_R - 170.0]]:
		for part in [[side[0], side[1], 0.94, 0.94], [side[1], side[2], 0.94, 0.0]]:
			var pg := Polygon2D.new()
			pg.polygon = PackedVector2Array([Vector2(part[0], -200.0), Vector2(part[1], -200.0), Vector2(part[1], 900.0), Vector2(part[0], 900.0)])
			pg.vertex_colors = PackedColorArray([Color(dusk, part[2]), Color(dusk, part[3]), Color(dusk, part[3]), Color(dusk, part[2])])
			pg.z_index = -46
			add_child(pg)
	_build_people()
	_build_king()
	if Game.backdrop:
		return
	add_wall(VIEW_L + 24.0)
	add_wall(KING_X - 80.0)
	for e in Game.PSALM:
		if Game.has_line(str(e["id"])):
			lines.append(str(e["id"]))
	var over := CanvasLayer.new()          # written on the screen, not in the room
	over.layer = 3
	add_child(over)
	var words := Painter.new()
	words.paint = _draw_line
	words.animated = true
	over.add_child(words)
	add_trigger(KING_X - FAR + 20.0, KING_X, _come_before)


## The lamp that throws the king's shadow. The Night Fit has more than one, and they go out.
func _build_lamps() -> void:
	if not ResourceLoader.exists("res://art/props/c2_hall_lamp.png"):
		return
	var lamp := add_sprite("res://art/props/c2_hall_lamp.png", Vector2(LAMP_X, 556.0), 1.0, 1, Color(1, 1, 1))
	lamp.scale = Vector2.ONE * (172.0 / lamp.texture.get_height())
	add_painter(Vector2(LAMP_X, 558.0), 1, func(ci: CanvasItem) -> void: FA.shadow(ci, 54.0, 0.9))
	lamp_glow = add_glow(Vector2(LAMP_X, 556.0 - 160.0), Color(1.0, 0.66, 0.32, 0.5), 210.0)


## Who else is in the room: in the evening, the two who brought him. At night, no one.
func _build_people() -> void:
	steward = add_person("steward", 196.0, 1.0, false, 2)
	youth = add_person("youth", 286.0, 1.0, false, 2)
	for who in [steward, youth]:          # in the room's light, and a little back from the two the lamp is on
		if is_instance_valid(who):
			who.modulate = Color(0.94, 0.78, 0.6)


## The king on his seat, and his shadow on the wall behind him. Unpainted, a player sees neither (and the
## section stays shut); the tests get a bare point.
func _build_king() -> void:
	var at := on_ground(KING_X) + Vector2(0, 4)
	if FA._paths("saul", "idle").is_empty():
		if Game.fast or Game.force_ready:
			king = Node2D.new()
			king.position = at
			add_child(king)
		return
	FA.frames("saul", "rest")
	king_tex = FA.frames("saul", "idle")[0]
	add_painter(at + Vector2(0, -WALL_UP), -45, _draw_shadow, true)
	king = add_painter(at, 3, _draw_king, true)


func _draw_king(ci: CanvasItem) -> void:
	var idle: Array = FA.frames("saul", "idle")
	var rest: Array = FA.frames("saul", "rest")
	var tint: Color = pal.get("char", Color(1, 1, 1))
	FA.shadow(ci, 70.0, 0.9)
	var troubled: Texture2D = FA.pingpong(idle, king_clock, 9.0)
	if rest_t < 0.0 or rest.is_empty():
		king_tex = troubled
		FA.draw(ci, troubled, -1.0, 1.0, tint, 1.4)
		return
	# he eases: the troubled frame gives way to the resting ones, which are played once and held
	var k := mini(int(rest_t * 10.0), rest.size() - 1)
	king_tex = rest[k]
	var mix := clampf(rest_t / 0.5, 0.0, 1.0)
	if mix < 1.0:
		FA.draw(ci, troubled, -1.0, 1.0, Color(tint, 1.0 - mix), 1.4)
	FA.draw(ci, rest[k], -1.0, 1.0, Color(tint, mix), 1.4)


## The shadow: the king's own shape, thrown up the wall away from the lamp. At rest it is a little larger than
## he is, as a lamp makes it; troubled it stands to the beams and leans over the room. Drawn several times a
## little apart, so that its edge is soft.
func _draw_shadow(ci: CanvasItem) -> void:
	if king_tex == null or Game.backdrop:
		return
	var s := clampf(shown, 0.0, 1.15)
	var flick := 1.0 + 0.012 * sin(clock * 9.0) + 0.008 * sin(clock * 23.0) + 0.03 * swell * sin(clock * 5.0)
	var sx := (1.12 + 0.75 * s) * flick / FA.RES
	var sy := (1.15 + 1.5 * s) * flick / FA.RES
	var w := float(king_tex.get_width())
	var h := float(king_tex.get_height())
	var foot := Vector2(w * 0.5, h * 1.4 / 1.5)
	var base := Vector2(30.0 + 30.0 * s, 0.0)
	var soft := 3.0 + 1.5 * s
	var each := 0.09 + 0.05 * s
	var xa := Vector2(-sx, 0.0)
	var ya := Vector2(-0.1 * s * sy, sy)          # it leans away from the lamp as it grows
	# across the floor from his seat to the foot of the wall
	for k in 4:
		var d := k * 7.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-52.0 + d, WALL_UP + 6.0 - d * 0.3), Vector2(48.0 - d, WALL_UP + 6.0 - d * 0.3),
				base + Vector2(60.0 + 30.0 * s - d, -4.0 + d * 0.3), base + Vector2(-58.0 - 30.0 * s + d, -4.0 + d * 0.3)]), Color(0.05, 0.03, 0.07, 0.08 + 0.05 * s))
	for k in 9:
		var off := Vector2.ZERO if k == 0 else Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * soft
		ci.draw_set_transform_matrix(Transform2D(xa, ya, base + off))
		ci.draw_texture(king_tex, -foot, Color(0.05, 0.03, 0.07, each))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The line of the psalm that the last phrase carried, written over the room.
func _draw_line(ci: CanvasItem) -> void:
	if line_id == "" or Game.cinematic or line_t > 7.0:
		return
	var a := clampf(minf(line_t * 2.0, (7.0 - line_t) * 0.8), 0.0, 1.0)
	var txt := str(Game.line(line_id)["text"])
	var cream := Game.CREAM
	# at the foot of the screen, over the dark of the floor: the wall and the shadow on it are left clear
	ci.draw_string(Game.serif, Vector2(240.0, 628.0), Game.t("Psalm 23").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 13, Color(1.0, 0.85, 0.5, 0.9 * a))
	ci.draw_multiline_string_outline(Game.serif, Vector2(240.0, 656.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 22, 2, 6, Color(0.02, 0.01, 0.03, 0.7 * a))
	ci.draw_multiline_string(Game.serif, Vector2(240.0, 656.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 22, 2, Color(cream.r, cream.g, cream.b, a))


func begin() -> void:
	await say(["n_c2s4_intro", "n_c2s4_servants", "1sam16_16"])


func _come_before() -> void:
	if trial or rested:
		return
	await say(["1sam16_21a", "n_c2s4_shadow", "n_c2s4_song"])
	_begin_trial()
	show_tip("Sit and play (R).  Each phrase let go at the top of the breath brings the shadow down", 8.0)


func _begin_trial() -> void:
	trial = true
	shadow = start_shadow
	swell = 0.0
	swell_on = 0.0
	swell_wait = swell_every * 0.5
	landed = 0
	line_i = 0
	line_id = ""


## Is he where the king can hear him?
func hears(x: float) -> bool:
	return x > KING_X - FAR and x < KING_X - NEAR


# ------------------------------------------------------------------ the playing

func song_noise(_at: Vector2) -> float:
	return swell * swell_shake if trial and swell_kind == 0 else 0.0


func song_pace(_at: Vector2) -> float:
	return 1.0 + swell * swell_hurry if trial and swell_kind == 1 else 1.0


func phrase(from: Vector2, _feet: bool) -> void:
	if not trial or rested or turning:
		return
	if not hears(from.x):
		if not far_told:
			far_told = true
			show_tip("Too far, or too near.  Sit where the king can hear it, this side of the lamp", 5.0)
		return
	var worth := down
	if swell > 0.25:
		worth *= swell_worth
		swell_on = minf(swell_on, swell_long * 0.2)      # it breaks on the phrase
	shadow = maxf(0.0, shadow - worth)
	landed += 1
	if not lines.is_empty():
		line_id = lines[line_i % lines.size()]
		line_i += 1
		line_t = 0.0
	_on_phrase()
	if shadow <= 0.0:
		_shadow_down()


## The shadow is all the way down. Here that is the end of it; at night it is the end of one wave.
func _shadow_down() -> void:
	_rest()


func phrase_lost(from: Vector2, _feet: bool) -> void:
	if not trial or rested or turning or not hears(from.x):
		return
	shadow += up
	if not lost_told:
		lost_told = true
		show_tip("A phrase let go too soon, and the shadow grows.  Wait for the top of the breath", 6.0)
	if shadow >= 1.0:
		_turn_away()


## For a later section to answer a landed phrase (a lamp steadied, a hand eased).
func _on_phrase() -> void:
	pass


func _swell_begins() -> void:
	if not swell_told:
		swell_told = true
		show_tip("The trouble rises in him, and the breath will not hold still.  A phrase landed now counts for more", 7.0)


## The shadow is down. The king rests; the favour is given; he is kept.
func _rest() -> void:
	rested = true
	trial = false
	swell_on = 0.0
	rest_t = 0.0
	Game.sfx("anoint", -10.0, 0.0)
	if not Game.fast:
		await get_tree().create_timer(2.6).timeout
	player.stop_lyre(true)
	await say(["n_c2s4_rest", "1sam16_23"])
	await give_here("favour")
	await say(["1sam16_22", "n_c2s4_kept"])
	complete()


## Too much was lost. Nothing is thrown and no one is struck: the king turns his face to the wall, the steward
## has the boy wait, and he begins again.
func _turn_away() -> void:
	turning = true
	trial = false
	player.stop_lyre(true)
	Game.cinematic = true
	if not turned_once:
		turned_once = true
		await say(turn_say)
	Game.cinematic = true
	await Game.main.overlay.fade_to(1.0, 0.6)
	player.reset_to(on_ground(START_X))
	_begin_trial()
	shown = shadow
	await Game.main.overlay.fade_to(0.0, 0.7)
	Game.cinematic = false
	turning = false
	_begun_again()


func _begun_again() -> void:
	show_tip("Begin again.  Slowly: let go only at the top of the breath", 6.0)


func _on_respawn() -> void:
	if trial:
		_begin_trial()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	clock += delta
	king_clock += delta * (0.35 + 0.9 * clampf(shown, 0.0, 1.0))
	if rest_t >= 0.0:
		rest_t += delta
	line_t += delta
	if is_instance_valid(lamp_glow):
		lamp_glow.modulate.a = 0.5 + 0.05 * sin(clock * 11.0) + 0.03 * sin(clock * 27.0)
	shown = move_toward(shown, shadow + 0.08 * swell, delta * 0.5)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	if pose_play > 0:
		pose_play -= 1
		if pose_play == 0:
			Input.action_press("lyre")
	if not placed:
		placed = true
		player.cam.limit_left = int(VIEW_L)
		player.cam.limit_right = int(VIEW_R)
		player.cam.reset_smoothing()
	if trial and not Game.cinematic:
		var gentle: float = float(Game.diff()["warning"])
		if swell_on > 0.0:
			swell_on -= delta
			var u := 1.0 - clampf(swell_on / swell_long, 0.0, 1.0)
			swell = move_toward(swell, sin(u * PI), delta * 1.6)
		else:
			swell = move_toward(swell, 0.0, delta * 1.2)
			swell_wait -= delta
			if swell_wait <= 0.0:
				swell_wait = swell_every * gentle
				swell_on = swell_long
				swell_kind = 1 - swell_kind
				_swell_begins()
		if shadow < TOP_CREEP:
			shadow = minf(TOP_CREEP, shadow + (creep + swell_creep * swell) * delta / gentle)
	else:
		swell = move_toward(swell, 0.0, delta * 1.2)
	set_goal(_goal_now())


func _goal_now() -> String:
	if rested:
		return "The king rests"
	if not trial:
		return "Go in before the king"
	if not hears(player.global_position.x):
		return "Sit where the king can hear, this side of the lamp"
	return "Play before the king (R): bring the shadow down"


## For screenshots (selftest placeshots, POSE=tall|mid|rest|court): one moment of the playing, or the journal's
## new page. Returns how many frames the work key is to be held (none: the lyre key is held here instead).
func pose(p: String) -> int:
	Game.give("lyre", true)
	trial = true
	swell_wait = 99.0
	line_t = 1.5
	match p:
		"tall":
			shadow = 0.95
			swell = 0.8
			swell_on = 4.0
			line_id = "p23_valley"
		"mid":
			shadow = 0.42
			line_id = "p23_waters"
		"rest":
			trial = false
			rested = true
			shadow = 0.0
			rest_t = 9.0
			line_id = "p23_soul"
		"court":
			Game.give("favour", true)
			Game.main.hud.page = 2
			Input.action_press("growth")
			return 0
	shown = shadow
	pose_play = 6          # once he is standing on the floor
	return 0
