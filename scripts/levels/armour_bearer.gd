extends "res://scripts/levels/level_base.gd"
## 2.5 The Armour-Bearer. The yard of the fortress at Gibeah, in the morning, over three days.
## "He loved him greatly; and he became his armor bearer" (1 Samuel 16:21). Service, not glory: he draws water
## and carries oil for the hall, takes a word to the steward, is given the king's shield and spear to carry and
## stands with them at the king's door; and on the third morning the old shield-man of the yard has him learn
## to raise the shield. The drill gives the Shield Arm.
##
## The yard is the Gate of Gibeah's (`gibeah_gate.gd`): the same wall, cistern, storehouse and door, each
## the same distance from the gate (which is out of sight to the west), re-lit for day by `tools/yard_day.py`. The king is not seen: this is the work done out of his sight.
##
## The shield is the king's, never David's (at Elah he puts off Saul's armour as untested, 17:39): the level
## puts it on his arm (`player.shield`) and nothing here is worn or struck with. All that scripture gives is
## "armor bearer"; the tasks, the shield-man and the drill are invention, and the journal says so.

const START_X := 400.0
const CISTERN_X := 800.0
const WALL_X := 1190.0         # where the king's son is seen from, up on the wall, as before
const WALL_TOP := 251.0
const MARK_X := 1140.0         # where he stands for the drill
const MASTER_X := 1262.0       # the shield-man, facing him
const STORE_X := 1550.0
const HALL_X := 2300.0         # the door of the hall: the king's place
const DOOR_TALL := 250.0
const DAY_TINT := Color(1, 1, 1)

const BOUTS := [3, 3, 3]       # blows to be stood under in each bout, one after another without a miss
const RAISE_LEN := 0.55        # seconds the pole takes to go up
const HIT_AT := 0.3            # seconds from the stroke's start to where it lands
const SWING_FPS := 14.0
const REACH := 100.0           # how far from his mark the pole still finds him

var steward: Node2D
var youth: Node2D
var master: Node2D             # the old shield-man who drills the young men
var jonathan: Node2D
var day := 1
var step := 0                  # how far through the work he is (see _goal_now)
var seen_drill := false
var drilling := false
var passed := false
var bout := 0
var stood := 0                 # blows taken on the shield in this bout
var phase := "rest"            # rest, raise, strike, after
var phase_t := 0.0
var miss_told := false
var away_told := false
var water_task: Dictionary
var pour_task: Dictionary
var oil_task: Dictionary
var lamps_task: Dictionary
var word_task: Dictionary
var steward_task: Dictionary
var door_task: Dictionary
var mark_task: Dictionary
var end_task: Dictionary


func _setup() -> void:
	mood = "theme_tender"
	ambience = "town"
	backdrop_art = "res://art/c2_yard_backdrop.png"
	midground_art = "res://art/c2_yard_mid.png"      # the Gate's wall band, re-lit for day by tools/yard_day.py
	width = 2650.0
	barren = true
	prompt_plate = true
	mid_tint = Color(1, 1, 1)
	mid_mirror = false
	flutters = 0
	pal.merge({
		"shafts": Color(1.0, 0.96, 0.84, 0.04), "mist": Color(0.95, 0.95, 0.92, 0.03),
		"sky_top": Color(0.42, 0.6, 0.86), "sky_mid": Color(0.66, 0.79, 0.92), "sky_bot": Color(0.9, 0.9, 0.86),
		"sun_pos": Vector2(0.2, 0.3), "sun_col": Color(1.0, 0.97, 0.86), "sun_size": 0.05,
		"far": Color(0.7, 0.68, 0.62), "near": Color(0.46, 0.4, 0.34), "rim": Color(1.0, 0.95, 0.82),
		"mote": Color(1.0, 0.96, 0.84, 0.3),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 6.0, 0.8)]
	checkpoints = [START_X]


func _populate() -> void:
	var tint: Color = pal.get("char", Color(1, 1, 1))
	add_sprite("res://art/props/well.png", on_ground(CISTERN_X) + Vector2(0, 8), 0.45, 1, tint)
	for k in 3:
		add_sprite("res://art/props/jar.png", on_ground(STORE_X + 80.0 + k * 40.0) + Vector2(0, 4), 0.62 - 0.05 * k, 2, tint)
	add_sprite("res://art/props/jar.png", on_ground(HALL_X - 70.0) + Vector2(0, 4), 0.6, 2, tint)      # the hall's water jar
	steward = add_person("steward", STORE_X, 1.0, true)
	youth = add_person("youth", HALL_X + 30.0, 1.0, true)
	master = add_person("spearman", MASTER_X, 1.0, true)
	# the king's son is at Gibeah, and they do not meet until after Goliath (18:1): up on the wall, as at the gate
	jonathan = add_person("jonathan", WALL_X, 0.62, true, 0)
	if is_instance_valid(jonathan):
		for L in layers:
			if is_equal_approx(float(L["s"]), 0.4):
				remove_child(jonathan)
				(L["node"] as Node2D).add_child(jonathan)
				jonathan.position = Vector2(WALL_X * 0.4, WALL_TOP)
				jonathan.modulate = Color(0.92, 0.9, 0.88)
	if ResourceLoader.exists("res://art/props/c2_hall_door_day.png"):
		var door := add_sprite("res://art/props/c2_hall_door_day.png", on_ground(HALL_X + 120.0) + Vector2(0, 12), 1.0, 1, tint * DAY_TINT)
		door.scale = Vector2.ONE * (DOOR_TALL / door.texture.get_height())
	if Game.backdrop:
		return
	_marks()
	add_trigger(MARK_X - 200.0, MASTER_X + 80.0, _see_drill)
	water_task = add_task(CISTERN_X - 46.0, "Draw water for the hall", 1.6, _water, 70.0)
	water_task["anim"] = "draw"
	pour_task = _later(HALL_X - 110.0, "Fill the hall's jar", 1.1, _pour, 70.0)
	pour_task["anim"] = "pour"
	oil_task = _later(STORE_X - 80.0, "Ask the steward for lamp oil", 0.9, _oil, 100.0)
	lamps_task = _later(HALL_X, "Carry the oil in to the lamps", 1.2, _lamps, 80.0)
	word_task = _later(HALL_X - 40.0, "Hear the young man's word", 0.8, _word, 90.0)
	steward_task = _later(STORE_X - 80.0, "Give the steward the king's word", 0.9, _arms, 100.0)
	door_task = _later(HALL_X - 30.0, "Stand at the king's door", 1.4, _stand, 80.0)
	mark_task = _later(MARK_X, "Take your place before the shield-man", 0.7, _begin_drill, 70.0)
	end_task = _later(HALL_X - 30.0, "Take your place at the king's door", 1.2, _end, 80.0)


## The yard's floor by day: a painted earth texture made to repeat by tools/yard_day.py
## (the dark rock skin is for dusk and caves), darkening a little toward the foot of the screen.
func _skin_ground(poly: PackedVector2Array, top: PackedVector2Array, parent: Node = null, z: int = 2) -> void:
	var path := "res://art/ground_yard.png"
	if not ResourceLoader.exists(path):
		super._skin_ground(poly, top, parent, z)
		return
	if parent == null:
		parent = self
	var vis := Polygon2D.new()
	vis.polygon = poly
	vis.z_index = z
	vis.texture = load(path)
	vis.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	vis.texture_scale = Vector2(1.4, 1.4)
	parent.add_child(vis)
	var y: float = top[0].y
	var x0: float = top[0].x
	var x1: float = top[top.size() - 1].x
	var deep := Polygon2D.new()
	deep.polygon = PackedVector2Array([Vector2(x0, y + 20.0), Vector2(x1, y + 20.0), Vector2(x1, y + 240.0), Vector2(x0, y + 240.0)])
	deep.vertex_colors = PackedColorArray([Color(0.2, 0.15, 0.1, 0.0), Color(0.2, 0.15, 0.1, 0.0), Color(0.2, 0.15, 0.1, 0.5), Color(0.2, 0.15, 0.1, 0.5)])
	deep.z_index = z
	parent.add_child(deep)
	# and the wall's own shade lies along its foot, so the wall stands on the earth and not over it
	var foot := Polygon2D.new()
	foot.polygon = PackedVector2Array([Vector2(x0, y - 16.0), Vector2(x1, y - 16.0), Vector2(x1, y + 30.0), Vector2(x0, y + 30.0)])
	foot.vertex_colors = PackedColorArray([Color(0.16, 0.12, 0.09, 0.42), Color(0.16, 0.12, 0.09, 0.42), Color(0.16, 0.12, 0.09, 0.0), Color(0.16, 0.12, 0.09, 0.0)])
	foot.z_index = z
	parent.add_child(foot)


## No black grass against the sky here: those silhouettes belong to the hills at dusk.
func _build_foreground() -> void:
	pass


func _later(x: float, text: String, hold: float, fn: Callable, reach: float) -> Dictionary:
	var tk := add_task(x, text, hold, fn, reach)
	tk["on"] = false
	return tk


func begin() -> void:
	await say(["n_c2s5_intro", "n_c2s5_serve"])


# ------------------------------------------------------------------ the first day: water and oil

func _water() -> void:
	step = 1
	Game.sfx("gather", -8.0, 0.05)
	pour_task["on"] = true
	await say(["n_c2s5_water"])


func _pour() -> void:
	step = 2
	Game.sfx("step_wet", -6.0, 0.05)
	oil_task["on"] = true


func _oil() -> void:
	step = 3
	lamps_task["on"] = true
	await say(["n_c2s5_oil"])


func _lamps() -> void:
	step = 4
	await say(["n_c2s5_lamps"])
	await _next_day(["n_c2s5_days", "n_c2s5_word"])
	word_task["on"] = true


func _see_drill() -> void:
	if seen_drill or day > 2:
		return
	seen_drill = true
	await say(["n_c2s5_drillsee"])


## A day ends: the picture goes dark, he is found at the door of the hall, and the next morning is told.
func _next_day(ids: Array) -> void:
	Game.cinematic = true
	await Game.main.overlay.fade_to(1.0, 0.5)
	day += 1
	player.reset_to(on_ground(HALL_X - 60.0))
	player.facing = -1
	player.cam.reset_smoothing()
	await Game.main.overlay.fade_to(0.0, 0.6)
	Game.cinematic = false
	await say(ids)


# ------------------------------------------------------------------ the second day: the king's shield and spear

func _word() -> void:
	step = 5
	steward_task["on"] = true
	show_tip("Bring the word to the steward at the storehouse, west", 5.0)


func _arms() -> void:
	step = 6
	await say(["n_c2s5_arms", "1sam16_21b"])
	bear(true)
	door_task["on"] = true
	show_tip("He bears the king's shield and spear.  He walks, and his hands are full", 6.0)


## The king's shield and spear are put into his hands, or taken back.
func bear(on: bool) -> void:
	player.shield = on
	Game.sfx("armour", -6.0, 0.05, 1.0 if on else 0.9)
	if on:
		player.stop_lyre(false)
		player.charging = false
	else:
		player.shield_learn = false


func _stand() -> void:
	step = 7
	await say(["n_c2s5_place"])
	await _next_day(["n_c2s5_called"])
	mark_task["on"] = true


# ------------------------------------------------------------------ the third day: the drill

func _begin_drill() -> void:
	step = 8
	drilling = true
	player.shield_learn = true
	player.facing = 1
	bout = 0
	stood = 0
	_rest(1.6)
	show_tip("Hold Staff (J) to raise the shield for the blow.  It cannot be held up long", 9.0)


func _rest(seconds: float) -> void:
	phase = "rest"
	phase_t = seconds


## Is he standing where the shield-man can reach him, and facing him?
func in_place() -> bool:
	return absf(player.global_position.x - MARK_X) < REACH and player.facing > 0


func _drill(delta: float) -> void:
	if Game.cinematic:
		return
	phase_t -= delta
	if phase_t > 0.0:
		return
	match phase:
		"rest":
			if not in_place():      # he waits for the boy to stand before him
				phase_t = 0.3
				if not away_told and absf(player.global_position.x - MARK_X) > REACH:
					away_told = true
					show_tip("The shield-man is waiting.  Stand before him, facing him", 5.0)
				return
			phase = "raise"
			# the pole goes up and is held there: a short hold at first, then one he cannot count on
			var hold: float = [0.45, rng.randf_range(0.15, 0.95), rng.randf_range(0.05, 1.25)][mini(bout, 2)]
			phase_t = RAISE_LEN + hold * float(Game.diff().get("warning", 1.0))
			_play("raise", false)
		"raise":
			phase = "strike"
			phase_t = HIT_AT
			_play("swing", true)
			Game.sfx("swing", -8.0, 0.1, 0.8)
		"strike":
			_land()
		"after":
			_rest(rng.randf_range(0.7, 1.2))


func _play(set_name: String, back: bool) -> void:
	if is_instance_valid(master) and master.has_meta("st") and not FA.frames("spearman", set_name).is_empty():
		actor_play(master, "spearman", set_name, SWING_FPS, -1.0, 1.0, 1.4, back)


## The stroke comes down where he stands.
func _land() -> void:
	phase = "after"
	phase_t = 0.5
	if absf(player.global_position.x - MARK_X) > REACH:
		return                     # he has stepped away: it falls on nothing, and counts for nothing
	if player.hurt(0, MASTER_X, "drill"):      # on the shield it does no harm, and the player tells us so (`blocked`)
		stood = 0
		if not miss_told:
			miss_told = true
			show_tip("It stung, and it taught.  The bout begins again: raise the shield for the blow, not before it", 7.0)


## A blow has landed on the king's shield (called by the player).
func blocked(_from_x: float) -> void:
	if not drilling or passed:
		return
	stood += 1
	if stood < int(BOUTS[bout]):
		return
	stood = 0
	bout += 1
	if bout >= BOUTS.size():
		_passed()
	elif bout == 1:
		show_tip("Again, and he will not swing when you expect it", 5.0)
	else:
		show_tip("Once more.  Watch the pole, not the man", 5.0)


func _passed() -> void:
	passed = true
	drilling = false
	step = 9
	Game.sfx("anoint", -12.0, 0.0)
	await say(["n_c2s5_done", "n_c2s5_untested"])
	await give_here("shieldarm")
	end_task["on"] = true


func _end() -> void:
	await say(["n_c2s5_end"])
	bear(false)
	complete()


## Marks over the shield-man's head at the drill: one for each blow of this bout, filling as they are stood under.
func _marks() -> void:
	var draw := func(ci: CanvasItem) -> void:
		if not drilling or Game.cinematic:
			return
		var gold := Color(1.0, 0.86, 0.55)
		var n: int = int(BOUTS[mini(bout, BOUTS.size() - 1)])
		for k in n:
			var at := Vector2((k - (n - 1) * 0.5) * 16.0, 0.0)
			ci.draw_circle(at, 6.0, Color(0, 0, 0, 0.45))
			if k < stood:
				ci.draw_circle(at, 4.5, gold)
			else:
				ci.draw_arc(at, 4.5, 0.0, TAU, 16, Color(gold, 0.7), 1.2, true)
	add_painter(on_ground(MASTER_X) + Vector2(0, -206.0), 6, draw, true)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	if drilling:
		_drill(delta)
	set_goal(_goal_now())


func _goal_now() -> String:
	match step:
		0: return "Draw water at the cistern"
		1: return "Carry the water to the hall, east"
		2: return "Ask the steward for lamp oil, west"
		3: return "Carry the oil to the hall, east"
		4: return "Hear the young man at the door of the hall"
		5: return "Bring the king's word to the steward, west"
		6: return "Carry the king's shield and spear to his door, east"
		7: return "Go to the shield-man in the middle of the yard, west"
		8: return "Stand through the drill: raise the shield (J) for each blow"
	return "Carry the king's shield and spear back to his door, east"


## For screenshots (selftest placeshots, POSE=bear|block|drill).
func pose(p: String) -> int:
	match p:
		"bear":
			step = 6
			bear(true)
		"block":
			step = 8
			bear(true)
			player.shield_learn = true
			player.facing = 1
			player.block_t = -30.0      # held for the picture
			Input.action_press("attack")
		"drill":
			step = 8
			day = 3
			bear(true)
			player.global_position = on_ground(MARK_X)
			player.cam.reset_smoothing()
			_begin_drill()
			stood = 2
			phase = "raise"
			phase_t = 0.2
			_play("raise", false)
			player.block_t = -30.0
			Input.action_press("attack")
	return 0
