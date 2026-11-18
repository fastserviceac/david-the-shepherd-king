extends "res://scripts/levels/level_base.gd"
## 2.2 The Ridge Road. Afternoon going to dusk, from Bethlehem north along the ridge to Gibeah of Saul.
## He leads the loaded donkey, the young goat tied behind the load. What his father sent is the family's word to
## the king, so it has to arrive whole, and a donkey will not be dragged: three times it plants its feet (at the
## ford, at the stones a slide has left across the road, and at the wolves that come down to the road at dusk) and
## each time it is played through, walking. Between the stones and the wolves the road passes under Jebus, a
## walled city that is not Israel's (Judges 19:10-12): he does not turn in.
##
## Nothing here is new to draw but the road itself: the donkey, the kid and the lyre on foot come from the
## Summons, the wolves from the Night Watch.

const Donkey = preload("res://scripts/world/donkey.gd")

const START_X := 330.0
const FORD_X := 1900.0
const FORD_REACH := 250.0
const SLIDE_X := 3900.0        # the stones across the road
const SLIDE_REACH := 280.0
const SLIDE_SHAKE := 380.0     # how near he may play before the slipping stones get into his playing
const JEBUS_X := 5400.0
const DUSK_X := 6600.0         # where the road drops between the rocks, and the wolves come down
const WOLVES := [7150.0, 7650.0]
const WOLF_REACH := 430.0      # a wolf this near and the donkey will not go on unplayed
const PASS_X := 8050.0         # past here the rocks open and the wolves are behind
const GIFT_X := 8280.0
const GATE_X := 8760.0         # the foot of the climb to Gibeah

var donkey
var kid: Node2D
var cleared := false           # the stones are off the road
var wolves: Array = []
var wolves_out := false
var far := 0.0
var slide_task: Dictionary
var gate_task: Dictionary
var told := {}


func _setup() -> void:
	mood = "theme_tender"
	ambience = "dusk"
	backdrop_art = "res://art/c2_road_backdrop.png"
	midground_art = "res://art/c2_road_mid.png"
	width = 9100.0
	flutters = 2
	leaves = Color(1.0, 0.8, 0.5, 0.4)
	pal.merge({
		"shafts": Color(1.0, 0.78, 0.45, 0.06), "mist": Color(1.0, 0.85, 0.65, 0.06),
		"sky_top": Color(0.5, 0.64, 0.84), "sky_mid": Color(0.86, 0.8, 0.78), "sky_bot": Color(0.99, 0.86, 0.64),
		"sun_pos": Vector2(0.2, 0.6), "sun_col": Color(1.0, 0.86, 0.6), "sun_size": 0.07,
		"far": Color(0.6, 0.56, 0.62), "near": Color(0.34, 0.25, 0.3), "rim": Color(1.0, 0.8, 0.5),
		"mote": Color(1.0, 0.88, 0.6, 0.45),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 16.0, 2.3)]
	checkpoints = [220.0, 2500.0, 4700.0, 6450.0]


func _populate() -> void:
	var tint: Color = pal.get("char", Color(1, 1, 1))
	donkey = Donkey.new()
	donkey.level = self
	donkey.position = on_ground(START_X - 92.0)
	donkey.face = 1.0
	donkey.led = true
	add_child(donkey)
	kid = add_person("kid", START_X - 160.0)
	for tx in [140.0, 1180.0, 2780.0, 5050.0, 6100.0]:
		add_tree(tx, rng.randf_range(0.85, 1.2), rng.randf() < 0.3)
	add_pool(FORD_X, Color(0.62, 0.74, 0.86))
	add_rubble(on_ground(SLIDE_X) + Vector2(0, 14), [[-150.0, 0.55, false], [-60.0, 0.8, true], [40.0, 0.62, false], [130.0, 0.46, true]],
			Color(tint.r * 0.7, tint.g * 0.68, tint.b * 0.7))
	add_sprite("res://art/props/cairn.png", on_ground(JEBUS_X) + Vector2(0, 8), 1.0, 2, tint)      # a boundary heap: past it the land is not Israel's
	add_store("c2road_store", 6480.0)      # stones hung in the last tree before the rocks: for the wolves
	if Game.backdrop:
		return

	add_hint(START_X + 260.0, 150.0, "The donkey follows.  Do not leave it far behind")
	add_hint(FORD_X - 520.0, 150.0, "It will not put a foot in the water unplayed")
	slide_task = add_task(SLIDE_X - 200.0, "Roll the stones off the road", 1.6, _clear_slide, 70.0)
	add_trigger(JEBUS_X - 200.0, JEBUS_X + 200.0, func() -> void: say(["n_c2s2_jebus", "judg19_12", "n_c2s2_on"]))
	add_trigger(DUSK_X - 60.0, DUSK_X + 200.0, _dusk)
	add_gift("steady", GIFT_X, func() -> bool: return _through(),
			"Bring the donkey through the rocks.  Drive the wolves off, or play it past them")
	gate_task = add_task(GATE_X, "Go up to the gate of Gibeah", 0.9, _arrive, 80.0)
	gate_task["on"] = false


func begin() -> void:
	if Game.main.intro.has_story("c2_road"):      # the film before this section speaks the first line itself
		await say(["n_c2s2_load"])
	else:
		await say(["n_c2s2_intro", "n_c2s2_load"])


# ------------------------------------------------------------------ what it will not pass

func donkey_fear(x: float) -> float:
	if absf(x - FORD_X) < FORD_REACH:
		return 1.0
	if absf(x - SLIDE_X) < SLIDE_REACH:
		return 1.0
	if _wolf_near(x, WOLF_REACH):
		return 1.0
	return 0.0


## The stones are still settling: close to the slide his playing will not hold still.
func song_noise(at: Vector2) -> float:
	return 1.0 if not cleared and absf(at.x - SLIDE_X) < SLIDE_SHAKE else 0.0


func phrase(from: Vector2, feet: bool) -> void:
	if feet and is_instance_valid(donkey) and donkey.led:
		donkey.hear(from, 300.0)


func donkey_balked(d) -> void:
	var where := "ford" if absf(d.global_position.x - FORD_X) < FORD_REACH + 60.0 else ("slide" if absf(d.global_position.x - SLIDE_X) < SLIDE_REACH + 60.0 else "wolves")
	if told.has(where):
		return
	told[where] = true
	match where:
		"ford":
			show_tip("It will not cross.  Go back to it, play as you walk (R), and keep the phrases landing", 7.0)
		"slide":
			show_tip("The road is blocked, and the stones are still slipping.  Roll them off before you bring it through", 7.0)
		_:
			show_tip("It smells the wolves.  Drive them off with staff or stone, or play it past them", 7.0)


func _clear_slide() -> void:
	cleared = true
	Game.sfx("stone_hit", -6.0, 0.1, 0.8)
	Game.sfx("land", -6.0, 0.1, 0.7)
	show_tip("The road is open.  It still does not like the place: play it past", 6.0)


# ------------------------------------------------------------------ the wolves

func _dusk() -> void:
	if wolves_out:
		return
	wolves_out = true
	for wx in WOLVES:
		var w := add_beast("wolf", wx, {"edge_x": width})
		if w != null:
			wolves.append(w)
	await say(["n_c2s2_dusk"])


func _wolf_near(x: float, reach: float) -> bool:
	for w in wolves:
		if is_instance_valid(w) and absf(w.global_position.x - x) < reach:
			return true
	return false


## The donkey is with him and the rocks are behind them both.
func _through() -> bool:
	return is_instance_valid(donkey) and donkey.global_position.x > PASS_X and absf(donkey.global_position.x - player.global_position.x) < 320.0


func _arrive() -> void:
	donkey.led = false
	await say(["n_c2s2_gibeah", "n_c2s2_whole"])
	complete()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	far = maxf(far, player.global_position.x)
	if is_instance_valid(donkey):
		if not cleared and absf(donkey.global_position.x - SLIDE_X) < SLIDE_REACH:
			donkey.quiet = 0.0          # no song takes it over stones it cannot climb
		if is_instance_valid(kid):      # the young goat goes where the load goes
			var at: Vector2 = donkey.global_position + Vector2(-donkey.face * 66.0, 0.0)
			kid.global_position = kid.global_position.lerp(Vector2(at.x, ground_y(at.x)), minf(1.0, delta * 6.0))
	slide_task["on"] = not cleared
	gate_task["on"] = Game.has("steady") and _through()
	set_goal(_goal_now())


func _goal_now() -> String:
	if not is_instance_valid(donkey):
		return ""
	var gap: float = player.global_position.x - donkey.global_position.x
	if gap > 480.0:
		return "Go back for the donkey, west"
	if donkey.balking:
		if not cleared and absf(donkey.global_position.x - SLIDE_X) < SLIDE_REACH + 60.0:
			return "Roll the stones off the road"
		return "Play to the donkey (R) and walk it on"
	if Game.has("steady"):
		return "Go up to the gate of Gibeah, north"
	if _through():
		return "Stand in the shaft of light, north"
	if wolves_out and _wolf_near(donkey.global_position.x, WOLF_REACH + 200.0):
		return "Bring the donkey through the wolves"
	return "Lead the donkey north to Gibeah"
