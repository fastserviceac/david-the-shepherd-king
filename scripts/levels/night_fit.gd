extends "res://scripts/levels/kings_hall.gd"
## 2.6 The Night Fit. The same hall in deep night (1 Samuel 16:14 and 16:23). The hardest playing of the chapter.
##
## It is the King's Hall's playing (one number, `shadow`; see that script), and what is new is this:
## - It comes in waves, each stronger than the last (WAVES). A wave is over when its shadow is all the way down;
##   the last one down, the king rests. In the last wave the swells shake the breath line and hurry it at once.
## - Between waves the lamps gutter (GUTTER). A guttering lamp burns low for a while (LOW_FOR) and then goes out.
##   He has to get up and tend each one (a task at its stand). While a lamp is out the dark lets the shadow grow
##   (DARK_CREEP for each lamp out); the next wave begins when all are burning, from wherever the shadow then
##   stands or from the wave's own height, whichever is taller. In the last wave the lamp by the king gutters
##   once in the middle of the playing: tend it, or play on in the dark.
## - A lost phrase costs more than in the evening (`up`).
## - What he already has is felt. The Steady Hand: the swells shake harder here than anywhere, and it is his
##   hand that holds the line (player.gd). The King's Favour: once in each wave, a loss that would have turned
##   the king away does not; the king looks at him and waits.
## - The king's spear stands by his seat. It is drawn and nothing more: no task, no trigger, never touched.
## - No one else is in the room.
##
## Failing is gentle, as in the evening: the king turns his face to the wall, the lamps are lit again, and he
## begins the same wave again. Bringing the king to rest gives the Night Song (Game.song_hold()).
## The darkness is level_base's own (set_dark, add_light): each lamp is a pool of light, and so is the taper he
## carries. Nothing is shown but lamps, dark, and the king's shadow.

const LAMPS := [230.0, 410.0, 660.0]      # the door, the middle of the room, and the one that throws the king's shadow
const LAMP_H := 120.0                     # the evening's lamp on a shorter stand: his raised taper reaches the wick
const LAMP_SCALE := 172.0 / 535.0         # the evening's lamp is drawn 172 high from 535 px: the same scale here
const SPEAR_X := KING_X + 104.0
const WAVES := [
	{"start": 0.55, "shake": 1.0, "hurry": 0.8, "every": 10.0, "long": 5.0, "creep": 0.014, "both": false},
	{"start": 0.68, "shake": 1.3, "hurry": 1.0, "every": 8.5, "long": 6.0, "creep": 0.017, "both": false},
	{"start": 0.8, "shake": 1.5, "hurry": 1.15, "every": 7.5, "long": 6.5, "creep": 0.02, "both": true},
]
const GUTTER := [[0], [0, 1]]             # which lamps gutter when that wave has been brought down
const MID_LAMP := 2                       # and the one that gutters in the middle of the last wave
const LOW_FOR := 9.0                      # seconds a guttering lamp burns low before it goes out
const DARK_CREEP := 0.022                 # what each lamp that is out adds to the shadow, a second
const REACH := 30.0                       # he stands this far short of a lamp to put the taper to it
const TEND := 1.3                         # seconds at a lamp stand to trim it and light it
const GRACE_AT := 0.93                    # where the shadow is held when the king waits for him (the Favour)
const NIGHT_ART := "res://art/c2_night_hall_backdrop.png"
const GOALS := ["The first wave: play (R), and bring the shadow down", "The second wave: play (R), and bring the shadow down",
	"The last wave: play (R), and bring the shadow down"]

var wave := 0
var lull := false              # a wave is down and the next has not come: the lamps want tending
var lull_t := 0.0
var lull_told := false
var lull_play_told := false
var grace_used := false        # the king has waited for him once in this wave
var mid_done := false          # the lamp by the king has guttered in this wave
var swells := 0                # swells since the wave began
var lamps: Array = []          # {x, state: "lit" | "low" | "out", t, level, lit, glow, light, task}
var pose_hold := 0


func _tune() -> void:
	ambience = "hall"
	if ResourceLoader.exists(NIGHT_ART):          # the hall's own night painting, when it has been made
		backdrop_art = NIGHT_ART
	up = 0.16
	down = 0.08
	turn_say = ["n_c2s6_turn"]
	pal.merge({"char": Color(0.95, 0.8, 0.66), "mote": Color(1.0, 0.8, 0.5, 0.16)}, true)
	_set_wave(0)


func _set_wave(k: int) -> void:
	wave = clampi(k, 0, WAVES.size() - 1)
	var w: Dictionary = WAVES[wave]
	start_shadow = float(w["start"])
	swell_shake = float(w["shake"])
	swell_hurry = float(w["hurry"])
	swell_every = float(w["every"])
	swell_long = float(w["long"])
	creep = float(w["creep"])
	if swell_kind != 0 and swell_kind != 1:
		swell_kind = 1


func _ready() -> void:
	super._ready()
	if is_instance_valid(room) and backdrop_art != NIGHT_ART:          # without it, the evening's painting darkened: cooler, and the lamps do the rest
		room.modulate = Color(0.62, 0.64, 0.8)
	set_dark(0.8)
	if dark != null:          # under the line of the psalm, which is written on the screen and not in the room
		(dark.get_parent() as CanvasLayer).layer = 2


func _build_people() -> void:
	pass


func _build_lamps() -> void:
	var lit_art := "res://art/props/c2_hall_lamp_night.png"
	var out_art := "res://art/props/c2_hall_lamp_out.png"
	for i in LAMPS.size():
		var x: float = LAMPS[i]
		var L := {"x": x, "state": "lit", "t": 0.0, "level": 1.0, "lit": null, "glow": null, "light": null, "task": null}
		if ResourceLoader.exists(lit_art) and ResourceLoader.exists(out_art):
			var cold := add_sprite(out_art, Vector2(x, 556.0), 1.0, 1, Color(1, 1, 1))
			cold.scale = Vector2.ONE * LAMP_SCALE
			var warm := add_sprite(lit_art, Vector2(x, 556.0), 1.0, 1, Color(1, 1, 1))
			warm.scale = cold.scale
			L["lit"] = warm
			add_painter(Vector2(x, 558.0), 1, func(ci: CanvasItem) -> void: FA.shadow(ci, 54.0, 0.9))
			L["glow"] = add_glow(Vector2(x - 3.0, 556.0 - LAMP_H + 9.0), Color(1.0, 0.62, 0.28, 0.5), 110.0 if i < 2 else 130.0)
		L["light"] = add_light(Vector2(x, 556.0 - LAMP_H * 0.72), 270.0 if i < 2 else 330.0)
		if not Game.backdrop:
			var tk := add_task(x - REACH, "Light the lamp", TEND, _tend.bind(i), 44.0)
			tk["again"] = true
			tk["on"] = false
			if not FA._paths("david", "lamp").is_empty():
				tk["anim"] = "lamp"
			L["task"] = tk
		lamps.append(L)


func _populate() -> void:
	super._populate()
	add_light(Vector2(KING_X, 470.0), 150.0)          # the king is never lost in the dark: a little of the night's own light is on him
	# the king's spear, upright in its place by his seat. It is there to be seen, and that is all.
	add_painter(on_ground(SPEAR_X) + Vector2(0, 2.0 - WALL_UP), 2, _draw_spear)


func _draw_spear(ci: CanvasItem) -> void:
	var foot := Vector2.ZERO
	var tip := Vector2(-34.0, -176.0)          # it leans against the wall
	var along := (tip - foot).normalized()
	var across := Vector2(-along.y, along.x)
	var neck := tip - along * 27.0
	var wood := Color(0.27, 0.18, 0.12)
	var bronze := Color(0.4, 0.3, 0.19)
	for k in 3:          # its shade on the wall, soft
		ci.draw_line(foot + Vector2(5.0 + k * 1.5, 0), neck + Vector2(7.0 + k * 2.0, 2), Color(0.02, 0.01, 0.03, 0.14), 5.0, true)
	ci.draw_line(foot, neck, wood, 3.4, true)
	ci.draw_line(foot - across * 0.9, neck - across * 0.9, Color(0.4, 0.28, 0.18, 0.55), 1.0, true)      # the side the lamp is on
	ci.draw_line(neck - along * 6.0, neck + along * 2.0, Color(0.2, 0.14, 0.1), 4.6, true)      # the binding under the head
	var leaf := PackedVector2Array([neck + along * 1.0 - across * 1.6, neck + along * 9.0 - across * 4.2, neck + along * 17.0 - across * 3.0, tip,
		neck + along * 17.0 + across * 3.0, neck + along * 9.0 + across * 4.2, neck + along * 1.0 + across * 1.6])
	ci.draw_colored_polygon(leaf, bronze)
	leaf.append(leaf[0])
	ci.draw_polyline(leaf, bronze, 1.2, true)          # a clean edge
	ci.draw_line(neck + along * 2.0, tip - along * 3.0, Color(0.55, 0.43, 0.28, 0.7), 1.0, true)


func begin() -> void:
	await say(["n_c2s6_intro", "1sam16_14", "n_c2s6_alone"])


func _come_before() -> void:
	if trial or rested:
		return
	await say(["n_c2s6_before", "n_c2s6_spear"])
	_begin_trial()
	show_tip("Sit and play (R).  Tonight it comes in waves, and a phrase let go too soon costs more", 8.0)


## The wave he is in begins (again): every lamp burning, the shadow at the wave's own height.
func _begin_trial() -> void:
	_set_wave(wave)
	for i in lamps.size():
		_light(i)
	lull = false
	lull_t = 0.0
	grace_used = false
	mid_done = false
	swells = 0
	super._begin_trial()


func _begun_again() -> void:
	show_tip("The lamps are lit again.  Begin the wave again, slowly", 6.0)


# ------------------------------------------------------------------ the lamps

func _light(i: int) -> void:
	var L: Dictionary = lamps[i]
	L["state"] = "lit"
	L["t"] = 0.0
	if L["task"] != null:
		L["task"]["on"] = false
		L["task"]["t"] = 0.0


func _gutter(i: int) -> void:
	var L: Dictionary = lamps[i]
	if L["state"] != "lit":
		return
	L["state"] = "low"
	L["t"] = LOW_FOR * float(Game.diff()["warning"])
	if L["task"] != null:
		L["task"]["on"] = true
	if not Game.fast:
		Game.sfx("lamp_gutter", -8.0, 0.1)


func _tend(i: int) -> void:
	_light(i)
	Game.sfx("lamp_light", -6.0, 0.08)


func lamps_out() -> int:
	var n := 0
	for L in lamps:
		if L["state"] == "out":
			n += 1
	return n


func lamps_wanting() -> int:
	var n := 0
	for L in lamps:
		if L["state"] != "lit":
			n += 1
	return n


# ------------------------------------------------------------------ the playing

func song_noise(_at: Vector2) -> float:
	return swell * swell_shake if trial and not lull and swell_kind != 1 else 0.0


func song_pace(_at: Vector2) -> float:
	return 1.0 + swell * swell_hurry if trial and not lull and swell_kind != 0 else 1.0


func phrase(from: Vector2, feet: bool) -> void:
	if lull:          # between waves the song holds what the dark is letting grow, and no more: the lamps want him
		if trial and not turning and hears(from.x):
			shadow = maxf(0.0, shadow - down * 0.5)
			if not lull_play_told:
				lull_play_told = true
				show_tip("The song holds it back, but it does not light a lamp.  Get up (Space) and tend them (hold E)", 6.0)
		return
	super.phrase(from, feet)


func phrase_lost(from: Vector2, feet: bool) -> void:
	if lull:
		return
	if Game.has("favour") and not grace_used and trial and not rested and not turning and hears(from.x) and shadow + up >= 1.0:
		grace_used = true          # the King's Favour: he is known here now, and is waited for. Once in a wave.
		shadow = GRACE_AT
		show_tip("The king looks at him, and waits.  He has asked for this boy.  He will not wait twice", 6.0)
		return
	super.phrase_lost(from, feet)


func _swell_begins() -> void:
	swells += 1
	if bool(WAVES[wave]["both"]):
		swell_kind = 2          # the last wave: it shakes the line and hurries it at once
	if not swell_told:
		swell_told = true
		if Game.has("steady"):
			show_tip("The trouble rises in him.  The breath shakes harder than on the road, and his hand holds it: the Steady Hand", 7.0)
		else:
			show_tip("The trouble rises in him, and the breath will not hold still.  A phrase landed now counts for more", 7.0)
	if wave == WAVES.size() - 1 and swells == 2 and not mid_done:
		mid_done = true
		_gutter(MID_LAMP)
		show_tip("The lamp by the king is going out.  Get up and tend it (hold E), or play on in the dark", 7.0)


## A wave is down. If it was the last, the king rests; if not, the lamps gutter and the next is coming.
func _shadow_down() -> void:
	if wave >= WAVES.size() - 1:
		_rest()
		return
	lull = true
	lull_t = 0.0
	shadow = 0.0
	swell_on = 0.0
	for i in GUTTER[wave]:
		_gutter(i)
	Game.sfx("anoint", -16.0, 0.0)
	_tell_lull()


func _tell_lull() -> void:
	if not lull_told:
		lull_told = true
		player.stop_lyre(true)
		await say(["n_c2s6_lull"])
	show_tip("The lamps are guttering.  Get up (Space) and tend each one (hold E) before it goes out: the dark lets the shadow grow", 8.0)


func _next_wave() -> void:
	_set_wave(wave + 1)
	lull = false
	grace_used = false
	mid_done = false
	swells = 0
	swell = 0.0
	swell_on = 0.0
	swell_wait = swell_every * 0.4
	shadow = maxf(shadow, start_shadow)
	if not Game.fast:
		Game.sfx("shadow_rise", -5.0, 0.0, 0.85)
	show_tip("It comes again, and stronger.  Sit and play (R)" if wave < WAVES.size() - 1 else "The last of it, and the worst.  Sit and play (R)", 6.0)


## The king is at rest, and it is the middle of the night. The Night Song is given.
func _rest() -> void:
	rested = true
	trial = false
	lull = false
	swell_on = 0.0
	rest_t = 0.0
	for i in lamps.size():
		_light(i)
	Game.sfx("anoint", -10.0, 0.0)
	if not Game.fast:
		await get_tree().create_timer(2.6).timeout
	player.stop_lyre(true)
	await say(["n_c2s6_rest", "1sam16_23", "n_c2s6_song"])
	await give_here("nightsong")
	await say(["n_c2s6_end"])
	complete()


func _physics_process(delta: float) -> void:
	player_light = 96.0          # the taper he carries
	var was_creep := creep
	if lull:
		creep = 0.0          # between waves only the dark lifts it
	super._physics_process(delta)
	creep = was_creep
	var gentle: float = float(Game.diff()["warning"])
	var live: bool = trial and not Game.cinematic and not done and not Game.backdrop
	for i in lamps.size():
		var L: Dictionary = lamps[i]
		if live and L["state"] == "low":
			L["t"] = float(L["t"]) - delta
			if float(L["t"]) <= 0.0:
				L["state"] = "out"
		var want := 1.0
		if L["state"] == "low":
			want = 0.36 + 0.22 * sin(clock * 17.0 + i) * sin(clock * 6.1 + i * 2.0)
		elif L["state"] == "out":
			want = 0.0
		L["level"] = move_toward(float(L["level"]), want, delta * (3.0 if L["state"] == "low" else 1.6))
		var lv: float = float(L["level"])
		var flick := 1.0 + 0.04 * sin(clock * 11.0 + i * 1.7) + 0.025 * sin(clock * 27.0 + i)
		if L["lit"] != null:
			(L["lit"] as Sprite2D).modulate.a = clampf(lv, 0.0, 1.0)          # a guttering flame is thin, and comes and goes
			(L["glow"] as Sprite2D).modulate.a = 0.5 * lv * flick
		L["light"]["on"] = lv > 0.03
		L["light"]["r"] = (270.0 if i < 2 else 330.0) * (0.25 + 0.75 * lv) * flick
		if L["task"] != null and task_now == L["task"] and float(L["task"]["t"]) > 0.0 and is_instance_valid(player):
			player.facing = 1          # he turns to the lamp he is tending, and steps to where the taper reaches it
			player.global_position.x = move_toward(player.global_position.x, float(L["x"]) - REACH, 140.0 * delta)
			if L["glow"] != null:          # the wick catches as the taper comes to it
				var u := clampf(float(L["task"]["t"]) / TEND, 0.0, 1.0)
				(L["glow"] as Sprite2D).modulate.a = maxf((L["glow"] as Sprite2D).modulate.a, 0.5 * smoothstep(0.55, 1.0, u))
	if not live:
		return
	var out := lamps_out()
	if out > 0 and shadow < TOP_CREEP:
		shadow = minf(TOP_CREEP, shadow + DARK_CREEP * out * delta / gentle)
	if lull:
		if lamps_wanting() == 0:
			lull_t += delta
			if lull_t > 1.6:
				_next_wave()
		else:
			lull_t = 0.0
			swell_wait = maxf(swell_wait, 2.0)          # no swell while he is at the lamps


func _goal_now() -> String:
	if rested:
		return "The king rests"
	if not trial:
		return "Go in to the king"
	if lull:
		return "Light the lamps (hold E) before the dark comes in" if lamps_wanting() > 0 else "The lamps are burning.  It is coming again"
	if lamps_wanting() > 0:
		return "A lamp is going out: light it (hold E), or play on"
	if not hears(player.global_position.x):
		return "Sit where the king can hear, this side of the lamp"
	return GOALS[wave]


## For screenshots (POSE=lit|gutter|dark|tend|rest): one moment of the night.
func pose(p: String) -> int:
	Game.give("lyre", true)
	trial = true
	swell_wait = 99.0
	line_t = 1.5
	match p:
		"lit":
			_set_wave(0)
			shadow = 0.5
			line_id = "p23_waters"
		"gutter":
			_set_wave(0)
			lull = true
			shadow = 0.12
			_gutter(0)
			_gutter(1)
			lamps[0]["state"] = "out"
			line_id = ""
			pose_play = 0
			shown = shadow
			return 0
		"dark":
			_set_wave(2)
			shadow = 0.9
			swell = 0.8
			swell_on = 4.0
			swell_kind = 2
			lamps[MID_LAMP]["state"] = "out"
			lamps[MID_LAMP]["level"] = 0.0
			line_id = "p23_valley"
		"tend":
			_set_wave(0)
			lull = true
			shadow = 0.1
			_gutter(1)
			line_id = ""
			shown = shadow
			return 62
		"rest":
			trial = false
			rested = true
			shadow = 0.0
			rest_t = 9.0
			line_id = "p23_soul"
	shown = shadow
	pose_play = 6
	return 0
