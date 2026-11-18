extends "res://scripts/levels/level_base.gd"
## 2.7 Back and Forth. "David went back and forth from Saul to feed his father's sheep at Bethlehem" (1 Samuel 17:15).
## The last of Chapter Two, in three stretches of ground with a fade between them:
##
## - The road south (first light). No donkey and no load. Above the ford another man's sheep, red-daubed, stand out
##   by the road with two wolves at them and no one by: he drives the wolves off. A shepherd does, whoever's they are.
## - Bethlehem. The keeper has kept the count: nine go under the rod. But a count is not the flock. Called by name,
##   three of the four answer; Devorah is not there, and one of the nine is the ford man's, her daub nearly worn away.
##   One too many and one too few make nine. Devorah has gone where she always slept, the night fold by the house;
##   she is shy of him after these days and wants the lyre before his hand. The ten are watered, and he plays them
##   to rest: the Night Song holds them till morning.
## - The road north. The red ewe goes back to her own fold on his way. She does not know his voice and will not come
##   to a call, but she follows the lyre, so she is led by the Walking Song, and only while its quiet is on her.
##   Men come down the road at a run, calling Israel out: the Philistines are gathering at Socoh (17:1; only the
##   runners are invented). Their passing shakes his playing (the Steady Hand is what holds it) and eats her quiet.
##   It ends on the height, looking west toward Elah.
##
## No gift is given here: the chapter's five are given. Nothing is new to draw but the runners and the last far
## view: the road and the wolves are the Ridge Road's, the house, folds, well and keeper the Summons'.
##
## Playing it for the tests and for screenshots: arriving in a stretch by any means (a watchfire, a test) sets that
## stretch up (`_into`).

const ROAD := "res://art/c2_road_backdrop.png"
const ROAD_MID := "res://art/c2_road_mid.png"
const HOME := "res://art/c2_home_backdrop.png"
const HOME_MID := "res://art/c2_home_mid.png"
const ELAH := "res://art/c2_elah_backdrop.png"
const ROAD_AS := 9100.0        # the Ridge Road's own length: its painting is drawn here at the size it has there
const HOME_AS := 5600.0        # and the Summons'

# ---- the road south (0 to A_W)
const A_W := 4400.0
const A_JEBUS := 1950.0         # kept off the places where the nearer band of hills meets its own mirror image
const A_FOLD := 3050.0         # the ford man's fold, above the ford
const A_FORD := 3640.0
const A_DOWN := 4180.0         # where the road drops to Bethlehem

# ---- Bethlehem (H to H + H_W): the Summons' ground, moved along
const H := 4800.0
const H_W := 5600.0
const JESSE_X := H + 420.0
const GATE_X := H + 700.0
const NIGHT_FOLD_X := H + 1350.0
const BAR_X := H + 1150.0
const FLOOR_X := H + 4100.0
const WELL_X := H + 4640.0
const KEEPER_X := H + 4880.0
const COUNT_X := H + 4960.0
const FOLD_X := H + 5120.0
const SLOT0 := FOLD_X - 170.0  # ten places along the wall of the day fold
const SLOT_GAP := 36.0
const PEN := ["ewe4", "rachel", "ewe6", "other", "", "lamb", "ewe5", "noga", "ewe8", "ewe7"]      # "" is Devorah's place, empty
const CALLS := ["lamb", "rachel", "noga", "devorah"]

# ---- the road north (N to N + N_W)
const N := 10800.0
const N_W := 5100.0
const N_RUN1 := N + 700.0      # the first runner
const N_FORD := N + 1650.0
const FORD_REACH := 190.0
const N_RUN2 := N + 2250.0     # two more
const N_FOLD := N + 2800.0     # the ford man's fold again
const N_SLIDE := N + 3180.0
const N_JEBUS := N + 3520.0    # more of them, and the news called out
const N_ELAH := N + 4050.0     # from here the far view opens westward
const N_HEIGHT := N + 4700.0

const RANGES := [[0.0, A_W], [H, H + H_W], [N, N + N_W]]
const RUDDLE := Color(0.74, 0.15, 0.09, 0.95)      # a redder daub than the Well's: it has to be seen from the road
const EWE_QUIET := 5.0         # seconds one landed phrase keeps the red ewe following (the Night Song lengthens it)
const EWE_HEARS := 320.0
const RUN_SPEED := 300.0
const RUN_GAP := 1250.0         # they come one at a time, each out of sight before the next is seen: they are one man's pictures
const RUN_REACH := 150.0       # a runner this near her and she feels it
const RUN_SHAKE := 420.0       # and this near him, his playing does
const FRIGHT := 3.0            # seconds of her quiet one runner's passing eats

# what he is doing at Bethlehem, in order
enum {ARRIVE, COUNT, CALL, PICK, FIND, BRING, WATER, REST, MORNING, LEAD, LEFT}

var part := -1                 # which stretch he is in: 0 the road south, 1 Bethlehem, 2 the road north
var fars: Array = []           # the far view of each stretch
var mids: Array = []           # and its nearer band
var elah: Sprite2D             # the last far view, shown as he comes up onto the height
var told := {}

# the road south
var red_a: Array = []
var wolves: Array = []
var wolves_out := false
var wolves_gone := false
var down_task: Dictionary

# Bethlehem
var jesse: Node2D
var keeper: Node2D
var step := ARRIVE
var pen := {}                  # his own in the day fold, by id
var stranger                   # the ford man's ewe
var devorah
var call_i := 0
var wrong := 0
var pick_near = null
var count_task: Dictionary
var call_task: Dictionary
var pick_task: Dictionary
var bar_task: Dictionary
var well_task: Dictionary
var rest_song: Dictionary
var ewe_task: Dictionary
var leave_task: Dictionary

# the red ewe on the road
var led := false               # she is his to bring: she follows while the song's quiet is on her
var quiet := 0.0
var bolt_t := 0.0
var bolt_to := 0.0
var bolts := 0                 # times a runner has sent her back down the road (for the lesson, and the tests)
var held := 0                  # times she has stood through one
var runners: Array = []        # {x, t, passed, node}
var run_still := false         # for a screenshot: they run on the spot
var given := false             # she is in with her own
var news := false
var give_task: Dictionary
var end_task: Dictionary


func _setup() -> void:
	mood = "theme_tender"
	ambience = "dawn"
	backdrop_art = ROAD
	midground_art = ROAD_MID
	width = N + N_W
	flutters = 3
	leaves = Color(1.0, 0.8, 0.5, 0.3)
	pal.merge({
		"shafts": Color(1.0, 0.86, 0.58, 0.06), "mist": Color(1.0, 0.9, 0.72, 0.06),
		"sky_top": Color(0.42, 0.58, 0.82), "sky_mid": Color(0.92, 0.8, 0.7), "sky_bot": Color(1.0, 0.9, 0.68),
		"sun_pos": Vector2(0.2, 0.58), "sun_col": Color(1.0, 0.9, 0.68), "sun_size": 0.07,
		"far": Color(0.76, 0.66, 0.6), "near": Color(0.37, 0.28, 0.32), "rim": Color(1.0, 0.84, 0.55),
		"mote": Color(1.0, 0.9, 0.65, 0.45),
	}, true)
	segments = [make_ground(0.0, A_W, 566.0, 16.0, 2.3), make_ground(H, H + H_W, 566.0, 10.0, 1.1), make_ground(N, N + N_W, 566.0, 16.0, 2.3)]
	checkpoints = [330.0, 2460.0, H + 240.0, H + 4230.0, N + 240.0, N + 3050.0]


## Each stretch has its own far view and its own nearer band, drawn as they are in the section they come from;
## only the one he is in is shown. The road south is the road's painting seen the other way.
func _build_painted() -> void:
	var far := Node2D.new()
	far.z_index = -50
	add_child(far)
	layers.append({"node": far, "s": 0.06})
	for k in 3:
		var path: String = HOME if k == 1 else ROAD
		var sp := _far_sprite(path, RANGES[k][0], HOME_AS if k == 1 else ROAD_AS)
		sp.flip_h = k == 0
		sp.visible = false
		far.add_child(sp)
		fars.append(sp)
	if ResourceLoader.exists(ELAH):
		elah = _far_sprite(ELAH, N + N_W - 4200.0, 4200.0)
		elah.modulate.a = 0.0
		far.add_child(elah)
	for k in 3:
		var mid := Node2D.new()
		mid.z_index = -40
		mid.modulate = mid_tint
		mid.visible = false
		var mpath: String = HOME_MID if k == 1 else ROAD_MID
		if ResourceLoader.exists(mpath):
			var tex: Texture2D = load(mpath)
			var msc := 0.75 * 1280.0 / tex.get_width()
			var x: float = 0.4 * float(RANGES[k][0]) - 400.0
			var flip := k == 0
			while x < 0.4 * float(RANGES[k][1]) + 700.0:
				var tile := Sprite2D.new()
				tile.texture = tex
				tile.centered = false
				tile.flip_h = flip
				tile.scale = Vector2(msc, msc)
				tile.position = Vector2(x, 96.0)
				mid.add_child(tile)
				x += tex.get_width() * msc - 1.0
				flip = not flip
		add_child(mid)
		layers.append({"node": mid, "s": 0.4})
		mids.append(mid)


## A far view for the stretch that begins at x0, at the size it would have in a section `as_width` long.
func _far_sprite(path: String, x0: float, as_width: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.centered = false
	var sc := maxf((1280.0 + 0.06 * as_width + 80.0) / sp.texture.get_width(), 900.0 / sp.texture.get_height())
	sp.scale = Vector2(sc, sc)
	sp.position = Vector2(0.06 * x0 - 620.0, -90.0)
	return sp


func _populate() -> void:
	var tint: Color = pal.get("char", Color(1, 1, 1))
	add_wall(A_W - 12.0)
	add_wall(H + 12.0)
	add_wall(H + H_W - 12.0)
	add_wall(N + 12.0)

	# ---- the road south
	for tx in [150.0, 1040.0, 2050.0, 2700.0, 3950.0]:
		add_tree(tx, rng.randf_range(0.85, 1.2), rng.randf() < 0.3)
	add_sprite("res://art/props/cairn.png", on_ground(A_JEBUS) + Vector2(0, 8), 1.0, 2, tint)
	red_a = _red_fold(A_FOLD, [-250.0, -200.0, 170.0, 215.0, 262.0], true)
	add_pool(A_FORD, Color(0.62, 0.74, 0.86))

	# ---- Bethlehem
	if ResourceLoader.exists("res://art/jesse/anim/idle_00.png"):
		jesse = add_actor("jesse", on_ground(JESSE_X) + Vector2(0, 4), 0.31)
	add_sprite("res://art/props/fold.png", on_ground(NIGHT_FOLD_X) + Vector2(0, 14), 1.5, 1)
	devorah = add_sheep(NIGHT_FOLD_X - 40.0, null, false, "devorah")
	devorah.gatherable = false
	# the same yard as the Summons, at the Summons' sizes (at 1.0 the painted props stand giant beside David)
	add_seated("res://art/props/threshing.png", on_ground(FLOOR_X), 400.0, 1, tint, 30.0)
	_prop_wide("res://art/props/well.png", on_ground(WELL_X) + Vector2(0, 8), 170.0, 1, tint)
	_prop_wide("res://art/props/trough.png", on_ground(WELL_X + 150.0) + Vector2(0, 10), 128.0, 2, tint)
	keeper = add_person("keeper", KEEPER_X, 1.0, true)
	add_sprite("res://art/props/fold.png", on_ground(FOLD_X) + Vector2(0, 14), 1.5, 1)
	for i in PEN.size():
		var id: String = PEN[i]
		if id == "":
			continue
		var s = add_sheep(_slot(i), null, id == "lamb", id)
		s.gathered = true
		s.gatherable = false
		s.stay = _slot(i)
		s.max_speed = 120.0
		if id == "other":
			s.wool = pal["wool"].darkened(0.1)
			s.size = 1.02
			s.mark = Color(RUDDLE.r, RUDDLE.g, RUDDLE.b, 0.62)      # nearly worn away: it wants a shepherd's eye
			s.mark_big = 1.5
			s.safe = true
			stranger = s
		else:
			pen[id] = s

	# ---- the road north
	for tx in [N + 180.0, N + 1000.0, N + 2420.0, N + 3760.0, N + 4380.0]:
		add_tree(tx, rng.randf_range(0.85, 1.2), rng.randf() < 0.3)
	add_pool(N_FORD, Color(0.62, 0.74, 0.86))
	_red_fold(N_FOLD, [150.0, 196.0, 240.0, 288.0], false)
	add_rubble(on_ground(N_SLIDE) + Vector2(0, 14), [[-120.0, 0.5, false], [-40.0, 0.36, true], [90.0, 0.44, false]],
			Color(tint.r * 0.7, tint.g * 0.68, tint.b * 0.7))      # the stones he rolled off the road, where he left them
	add_sprite("res://art/props/cairn.png", on_ground(N_JEBUS) + Vector2(0, 8), 1.0, 2, tint)
	sheep_total = 0          # none of these is to be gathered and counted on the way: the count is the keeper's
	if Game.backdrop:
		return

	# the road south
	add_trigger(A_JEBUS - 200.0, A_JEBUS + 200.0, func() -> void: say(["n_c2s7_jebus"]))
	add_trigger(A_FOLD - 430.0, A_FOLD + 200.0, _wolves_come)
	down_task = add_task(A_DOWN, "Go down to Bethlehem", 0.9, _to_home, 80.0)
	down_task["on"] = false

	# Bethlehem
	count_task = add_task(COUNT_X, "Count them under the rod with the keeper", 1.6, _count)
	count_task["on"] = false
	call_task = add_task(COUNT_X, "Call them by name", 0.7, _call)
	call_task["again"] = true
	call_task["on"] = false
	pick_task = add_task(FOLD_X, "This one is not ours", 0.45, _pick, 44.0)
	pick_task["again"] = true
	pick_task["on"] = false
	bar_task = add_task(BAR_X, "Lift the bar of the fold", 0.8, _lift_bar)
	bar_task["on"] = false
	well_task = add_task(WELL_X, "Draw water for the ten", 1.2, _water)
	well_task["on"] = false
	rest_song = add_song(FOLD_X - 60.0, _night, 330.0)
	rest_song["on"] = false
	ewe_task = add_task(_slot(3), "Take the red-daubed ewe out", 0.8, _take_ewe, 60.0)
	ewe_task["on"] = false
	leave_task = add_task(GATE_X, "Set out for Gibeah", 0.9, _leave, 80.0)
	leave_task["on"] = false

	# the road north
	add_trigger(N_RUN1 - 60.0, N_RUN1 + 200.0, func() -> void: _first_runner())
	add_hint(N_FORD - 520.0, 150.0, "Water eats her quiet.  Keep the phrases close together through the ford")
	add_trigger(N_RUN2 - 60.0, N_RUN2 + 200.0, func() -> void: _runners(2))
	give_task = add_task(N_FOLD - 60.0, "Put her in with her own", 0.9, _give_back, 90.0)
	give_task["on"] = false
	end_task = add_task(N_HEIGHT, "Look west, toward the valley of Elah", 1.0, _end, 90.0)
	end_task["on"] = false


func begin() -> void:
	await say(["n_c2s7_intro", "n_c2s7_light"])


func _slot(i: int) -> float:
	return SLOT0 + i * SLOT_GAP


## The ford man's fold and his red-daubed sheep, standing at `offsets` from it. `out`: left out by the road, where a
## beast can come at them.
func _red_fold(x: float, offsets: Array, out: bool) -> Array:
	add_sprite("res://art/props/fold.png", on_ground(x) + Vector2(0, 14), 1.5, 1)
	var list: Array = []
	for off in offsets:
		var s = add_sheep(x + float(off), null, false, "other")
		s.gatherable = false
		s.wool = pal["wool"].darkened(0.1)
		s.mark = RUDDLE
		s.mark_big = 1.9          # a fresh daub, to be seen from the road
		s.prey = out
		s.safe = not out
		list.append(s)
	return list


# ------------------------------------------------------------------ the stretches

## He is in stretch `k`: its own far view, the camera kept to it, and whatever must be true there made true.
func _into(k: int) -> void:
	part = k
	for i in 3:
		fars[i].visible = i == k
		mids[i].visible = i == k
	var lo: float = RANGES[k][0]
	var hi: float = RANGES[k][1]
	if player.global_position.x < lo or player.global_position.x > hi:
		player.reset_to(on_ground(lo + 300.0))
		player.facing = 1
	player.cam.limit_left = int(lo)
	player.cam.limit_right = int(hi)
	player.cam.reset_smoothing()
	if k >= 1:
		for w in wolves:
			if is_instance_valid(w):
				w.queue_free()
		wolves.clear()
		wolves_out = true
		wolves_gone = true
		down_task["on"] = false
	if k == 2:
		# he has come onto the road north by a watchfire or a test: Bethlehem is behind him, and she is with him
		for tk in [count_task, call_task, pick_task, bar_task, well_task, ewe_task, leave_task]:
			tk["on"] = false
		rest_song["on"] = false
		step = LEFT
		if not given:
			led = true
			stranger.safe = true
			if stranger.global_position.x < N:
				stranger.global_position = on_ground(player.global_position.x - 70.0)
				stranger.stay = stranger.global_position.x
		Game.ambience("dusk")
	_clear_runners()


func _to_home() -> void:
	await _cross(1)
	await say(["n_c2s7_home", "n_c2s7_jesse"])


## The picture goes dark, and he is in the next stretch.
func _cross(k: int) -> void:
	Game.cinematic = true
	await Game.main.overlay.fade_to(1.0, 0.5)
	if is_instance_valid(player):
		player.reset_to(on_ground(float(RANGES[k][0]) + 300.0))
		player.facing = 1
		_into(k)
	await Game.main.overlay.fade_to(0.0, 0.6)
	Game.cinematic = false


# ------------------------------------------------------------------ the road south: the wolves at another man's sheep

func _wolves_come() -> void:
	if wolves_out:
		return
	wolves_out = true
	for wx in [A_FOLD + 360.0, A_FOLD + 560.0]:
		var w := add_beast("wolf", wx, {"edge_x": A_W - 70.0})
		if w != null:
			wolves.append(w)
	await say(["n_c2s7_wolves"])
	show_tip("Another man's sheep, and no one by.  Stay near them, and drive the wolves off with staff or stone", 8.0)


func _wolves_left() -> bool:
	for w in wolves:
		if is_instance_valid(w) and not w.fleeing:
			return false
	return true


func _wolves_off() -> void:
	wolves_gone = true
	for s in red_a:
		if is_instance_valid(s):
			s.prey = false
			s.safe = true
	down_task["on"] = true
	await say(["n_c2s7_kept"])


# ------------------------------------------------------------------ Bethlehem: the count, and the names

func _at_fold() -> void:
	step = COUNT
	count_task["on"] = true
	await say(["n_c2s7_keeper"])


func _count() -> void:
	step = CALL
	if is_instance_valid(keeper):
		actor_play(keeper, "keeper", "count", 10.0, -1.0, 1.0, 1.4, true)
	call_task["on"] = true
	await say(["n_c2s7_count"])
	show_tip("A count is not the flock.  Call the ones that answer to a name", 7.0)


func _name_of(id: String) -> String:
	return Game.t(str(Game.flock_one(id).get("name", "")))


func _call() -> void:
	if call_i >= CALLS.size():
		return
	var id: String = CALLS[call_i]
	player.facing = 1
	player.call_out()
	call_i += 1
	if pen.has(id):
		var s = pen[id]
		s.name_t = 3.0
		s.hop = 1.0
		s.face = -1.0
		s.stay = s.stay - 12.0          # a step toward his voice
		Game.sfx("lamb" if s.size < 0.9 else "sheep", -6.0, 0.1)
		Game.sfx("gather", -8.0, 0.05)
		return
	# Devorah: nothing in the fold lifts its head
	call_task["on"] = false
	step = PICK
	pick_task["on"] = true
	await say(["n_c2s7_eight"])
	show_tip("Nine by the rod, eight by name.  One of these is not his father's: walk along them and look", 8.0)


## The sheep he is standing by, of those in the day fold.
func _nearest_penned():
	var best = null
	var px: float = player.global_position.x
	var all: Array = pen.values()
	all.append(stranger)
	for s in all:
		if is_instance_valid(s) and absf(s.global_position.x - px) < 30.0:
			if best == null or absf(s.global_position.x - px) < absf(best.global_position.x - px):
				best = s
	return best


func _pick() -> void:
	var s = pick_near
	if s == null or not is_instance_valid(s) or step != PICK:
		return
	if s == stranger:
		s.hop = 1.0
		Game.sfx("sheep", -6.0, 0.1)
		pick_task["on"] = false
		step = FIND
		bar_task["on"] = true
		await say(["n_c2s7_stranger", "n_c2s7_where"])
		return
	wrong += 1
	s.hop = 0.5
	if s.named != "":
		s.name_t = 3.0
	Game.sfx("ui_move", -8.0, 0.0, 0.7)
	show_tip("Not that one: she is his father's.  Look for a daub of red on the rump, nearly worn away", 6.0)
	if wrong >= 2 and is_instance_valid(stranger):          # twice wrong: the strange one shifts and shows her flank
		stranger.hop = 0.8
		stranger.face = -stranger.face


func _lift_bar() -> void:
	Game.sfx("logs", -8.0, 0.05)
	if is_instance_valid(devorah) and not devorah.gathered:
		devorah.gatherable = true
		devorah.restless = true
		devorah.home_x = devorah.global_position.x
		devorah.hop = 0.6
	show_tip("She is shy of him after these days.  Quiet her with the lyre (R) before going to her", 8.0)


func _on_sheep(s) -> void:
	if s != devorah:
		return
	s.restless = false
	bar_task["on"] = false
	if step < BRING:
		step = BRING
	sheep_count = 0
	await say(["n_c2s7_devorah"])


## Devorah is back at the day fold: she goes to her own place among the rest.
func _pen_devorah() -> void:
	step = WATER
	followers.erase(devorah)
	sheep_count = 0
	devorah.calm = 0.0
	devorah.held_x = NAN
	devorah.stay = _slot(4)
	devorah.max_speed = 120.0
	pen["devorah"] = devorah
	Game.flock_at("devorah", "")
	well_task["on"] = true
	await say(["n_c2s7_nine"])


func _water() -> void:
	step = REST
	Game.sfx("step_wet", -6.0, 0.1)
	rest_song["on"] = true
	await say(["n_c2s7_water"])
	show_tip("Sit by the fold and play them to rest (R)", 7.0)


## Three phrases by the fold at evening: the night passes, and they have not stirred.
func _night() -> void:
	if step != REST:
		return
	step = MORNING
	await say(["n_c2s7_night"])
	Game.cinematic = true
	await Game.main.overlay.fade_to(1.0, 0.6)
	if is_instance_valid(player):
		player.reset_to(on_ground(COUNT_X - 30.0))
		player.facing = 1
		player.cam.reset_smoothing()
	await Game.main.overlay.fade_to(0.0, 0.7)
	Game.cinematic = false
	ewe_task["on"] = true
	await say(["n_c2s7_morning"])


func _take_ewe() -> void:
	step = LEAD
	led = true
	quiet = 0.0
	stranger.stay = stranger.global_position.x
	await say(["n_c2s7_voice"])
	show_tip("She does not know his voice.  Play as you walk (R): she follows the lyre, and only while its quiet is on her", 9.0)


func _leave() -> void:
	step = LEFT
	await say(["n_c2s7_leave"])
	await _cross(2)
	await say(["n_c2s7_north"])


# ------------------------------------------------------------------ the red ewe, led by the song

func phrase(from: Vector2, _feet: bool) -> void:
	if led and is_instance_valid(stranger) and absf(from.x - stranger.global_position.x) < EWE_HEARS:
		quiet = EWE_QUIET * float(Game.diff()["warning"]) * Game.song_hold()
		bolt_t = 0.0


## Men pounding past get into his playing: the breath line will not hold still. (The Steady Hand is what damps it.)
func song_noise(at: Vector2) -> float:
	for r in runners:
		if absf(float(r["x"]) - at.x) < RUN_SHAKE:
			return 1.0
	return 0.0


func _update_ewe(delta: float) -> void:
	if not led or not is_instance_valid(stranger):
		return
	var ex: float = stranger.global_position.x
	var in_water: bool = part == 2 and absf(ex - N_FORD) < FORD_REACH
	var was := quiet
	quiet = maxf(0.0, quiet - delta * (2.0 if in_water else 1.0))
	if bolt_t > 0.0:          # running back down the road from what frightened her
		bolt_t -= delta
		stranger.stay = bolt_to
		stranger.max_speed = 300.0
		return
	stranger.max_speed = 150.0
	if quiet > 0.0:
		stranger.stay = NAN          # she follows him
	elif is_nan(stranger.stay) or was > 0.0:
		stranger.stay = ex           # the quiet has worn off: she stops where she is
		if not told.has("stopped") and absf(player.global_position.x - ex) > 120.0:
			told["stopped"] = true
			show_tip("She has stopped.  She follows the lyre and nothing else: go back to her and play as you walk (R)", 8.0)


func _ewe_near(x: float, reach: float) -> bool:
	return is_instance_valid(stranger) and absf(stranger.global_position.x - x) < reach


# ------------------------------------------------------------------ the runners

func _first_runner() -> void:
	_runners(1)
	await say(["n_c2s7_runner"])
	show_tip("Men are coming down the road at a run.  Keep her quiet as they pass: have a phrase landed before they reach her", 9.0)


## `n` men come down the road toward him at a run, one behind another, and go by.
func _runners(n: int) -> void:
	if part != 2:
		return
	var from: float = player.global_position.x + 820.0
	for i in n:
		_add_runner(from + i * RUN_GAP, runners.size() + i)


func _add_runner(x: float, k: int) -> void:
	var r := {"x": x, "t": rng.randf() * 2.0, "passed": false, "node": null}
	var frames: Array = FA.frames("runner", "run")
	var sc: float = [1.0, 0.96, 1.03][k % 3]
	var col: Color = [Color(1, 1, 1), Color(0.93, 0.9, 0.86), Color(0.88, 0.9, 0.94)][k % 3]
	var tint: Color = pal.get("char", Color(1, 1, 1))
	col = Color(col.r * tint.r, col.g * tint.g, col.b * tint.b)
	r["node"] = add_painter(on_ground(x) + Vector2(0, 4), 3, func(ci: CanvasItem) -> void:
		if frames.is_empty():
			return
		var tex: Texture2D = frames[int(float(r["t"]) * 22.0) % frames.size()]
		FA.shadow(ci, 46.0 * sc, 0.9)
		FA.draw(ci, tex, -1.0, sc, col, 1.4), true)
	runners.append(r)


func _update_runners(delta: float) -> void:
	for r in runners.duplicate():
		r["x"] = float(r["x"]) - (0.0 if run_still else RUN_SPEED) * delta
		r["t"] = float(r["t"]) + delta
		var x: float = r["x"]
		var node: Node2D = r["node"]
		if x < N + 20.0 or (is_instance_valid(player) and x < player.global_position.x - 1100.0):
			runners.erase(r)
			if is_instance_valid(node):
				node.queue_free()
			continue
		if is_instance_valid(node):
			node.position = on_ground(x) + Vector2(0, 4)
			node.visible = x < N + N_W - 30.0          # still beyond the end of the ground: not yet come
		if not r["passed"] and led and _ewe_near(x, RUN_REACH):
			r["passed"] = true
			_passed_her()


## A runner has gone by her. Quieted, she stands through it and it costs some of her quiet; unquieted, she bolts.
func _passed_her() -> void:
	Game.sfx("land", -8.0, 0.1, 0.9)
	if quiet > 0.0:
		held += 1
		quiet = maxf(0.0, quiet - FRIGHT)
		stranger.hop = 0.4
		return
	bolts += 1
	bolt_t = 1.5
	bolt_to = maxf(N + 120.0, stranger.global_position.x - 340.0)
	stranger.hop = 1.0
	Game.sfx("sheep", -5.0, 0.2)
	if bolts == 1:
		show_tip("She bolted from the runners.  Go back, play to her, and keep the phrases landing as they pass", 8.0)


func _clear_runners() -> void:
	for r in runners:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	runners.clear()


func _give_back() -> void:
	led = false
	given = true
	quiet = 0.0
	bolt_t = 0.0
	stranger.stay = N_FOLD + 104.0
	stranger.max_speed = 120.0
	stranger.hop = 0.8
	Game.sfx("sheep", -6.0, 0.15)
	await say(["n_c2s7_given"])


func _news() -> void:
	news = true
	_runners(3)
	end_task["on"] = true
	await say(["n_c2s7_news", "1sam17_1", "n_c2s7_called"])


func _end() -> void:
	if Game.main.intro.has_story("end2"):      # the film that closes the chapter speaks the last two lines itself
		await say(["n_c2s7_west"])
	else:
		await say(["n_c2s7_west", "n_c2s7_end", "1sam17_15"])
	complete()


func _on_respawn() -> void:
	_clear_runners()
	bolt_t = 0.0
	if led and part == 2 and is_instance_valid(stranger):
		quiet = 0.0
		stranger.global_position = on_ground(maxf(N + 80.0, player.global_position.x - 70.0))
		stranger.stay = stranger.global_position.x


# ------------------------------------------------------------------ every frame

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	var px: float = player.global_position.x
	var k := 0 if px < (A_W + H) * 0.5 else (1 if px < (H + H_W + N) * 0.5 else 2)
	if k != part:
		_into(k)
	_update_runners(delta)
	if respawning:
		return
	match part:
		0:
			if wolves_out and not wolves_gone and not Game.cinematic and _wolves_left():
				_wolves_off()
		1:
			_at_home(px)
		2:
			if not given:
				give_task["on"] = led and _ewe_near(N_FOLD, 210.0)
			elif not news and not Game.cinematic and px > N_JEBUS - 200.0:
				_news()
	_update_ewe(delta)
	set_goal(_goal_now())


func _at_home(px: float) -> void:
	if Game.cinematic:
		return
	if step == ARRIVE and absf(px - KEEPER_X) < 170.0:
		_at_fold()
	if step == CALL and call_i < CALLS.size():
		call_task["text"] = Game.t("Call %s") % _name_of(CALLS[call_i])
	if step == PICK:
		pick_near = _nearest_penned()
		pick_task["x"] = pick_near.global_position.x if pick_near != null else -9999.0
	if step == BRING and is_instance_valid(devorah) and devorah.gathered \
			and absf(devorah.global_position.x - FOLD_X) < 230.0 and absf(px - FOLD_X) < 280.0:
		_pen_devorah()
	if step == LEAD:
		leave_task["on"] = _ewe_near(GATE_X, 230.0)


func _process(delta: float) -> void:
	super._process(delta)
	if elah != null and is_instance_valid(player):
		var a := clampf((player.global_position.x - N_ELAH) / 480.0, 0.0, 1.0) if part == 2 else 0.0
		elah.modulate.a = move_toward(elah.modulate.a, a, delta * 2.0)


func _goal_now() -> String:
	match part:
		0:
			if wolves_out and not wolves_gone:
				return "Drive the wolves from the red-daubed sheep"
			if wolves_gone:
				return "Go down to Bethlehem, south"
			return "Take the road south to Bethlehem"
		1:
			match step:
				ARRIVE:
					return "Go to the keeper at the day fold, east"
				COUNT:
					return "Count the nine under the rod with the keeper"
				CALL:
					return "Call them by name at the gate of the fold"
				PICK:
					return "Find the one of the nine that is not his father's"
				FIND:
					if is_instance_valid(devorah) and devorah.gatherable:
						return "Quiet Devorah with the lyre (R), then go to her"
					return "Find Devorah where she has always slept: the night fold, west"
				BRING:
					return "Bring Devorah to the day fold, east"
				WATER:
					return "Draw water for them at the well"
				REST:
					return "Sit by the fold and play them to rest (R)"
				MORNING:
					return "Take the red-daubed ewe out of the fold"
				LEAD:
					if _ewe_near(GATE_X, 230.0):
						return "Set out for Gibeah"
					if not _ewe_near(player.global_position.x, 420.0):
						return "Go back for the red ewe: she follows only the lyre"
					return "Lead the red ewe west to your father's gate.  Play as you walk (R)"
			return ""
		2:
			if news:
				return "Go up onto the height and look west"
			if given:
				return "Go on north, up the road"
			if bolt_t > 0.0 or not _ewe_near(player.global_position.x, 420.0):
				return "Go back for the red ewe: she follows only the lyre"
			if _ewe_near(N_FOLD, 210.0):
				return "Put her in with her own"
			return "Lead the red ewe north to her fold.  Play as you walk (R)"
	return ""


## For screenshots (selftest placeshots, POSE=wolves|fold|pick|lead|runners|elah).
func pose(p: String) -> int:
	var px: float = player.global_position.x
	var k := 0 if px < (A_W + H) * 0.5 else (1 if px < (H + H_W + N) * 0.5 else 2)
	if k != part:
		_into(k)
	match p:
		"wolves":
			_wolves_come()
		"fold":
			step = CALL
			call_task["on"] = true
		"pick":
			step = PICK
			pick_task["on"] = true
		"lead":
			step = LEAD
			led = true
			quiet = 99.0
			stranger.global_position = on_ground(player.global_position.x - 70.0)
		"runners":
			run_still = true
			led = true
			quiet = 99.0
			stranger.global_position = on_ground(player.global_position.x - 70.0)
			for i in 2:
				_add_runner(player.global_position.x + 190.0 + i * RUN_GAP, i)
			for r in runners:
				r["passed"] = true
		"elah":
			given = true
			news = true
			led = false
			end_task["on"] = true
			if elah != null:
				elah.modulate.a = 1.0
	return 0


func _prop_wide(path: String, at: Vector2, w: float, z: int, tint: Color) -> Sprite2D:
	var sp := add_sprite(path, at, 1.0, z, tint)
	sp.scale = Vector2.ONE * (w / sp.texture.get_width())
	return sp
