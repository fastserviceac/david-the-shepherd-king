extends "res://scripts/levels/level_base.gd"
## 2.1 The Summons. Morning at Jesse's house on the edge of Bethlehem (1 Samuel 16:19-20).
## The king's messengers have come for him. The flock is still his to answer for, so before he can go he brings
## the nine out of the night fold, past the messengers' mules, to the keeper who will have them; makes the keeper
## able to keep them (their names, the count, the well); and brings the loaded donkey back past the same mules to
## his father, who adds the young goat and sends him.
##
## The lyre is what is played here. Seated, as in Chapter One, it quiets the flock so it can be called past the
## mules at a walk. Doing that earns the Walking Song, and the donkey is what asks for it straight away: a donkey
## stays quiet for only a few seconds, so it is brought through by playing as he walks.

const Donkey = preload("res://scripts/world/donkey.gd")

const JESSE_X := 420.0
const MESSENGER_X := 560.0
const GATE_X := 700.0          # the yard gate: where the donkey is brought, and the kid is tied on
const KID_X := 790.0
const NIGHT_FOLD_X := 1350.0
const BAR_X := 1150.0
const MULES := [2600.0, 3700.0]      # where the messengers have tethered their two mules, along the lane
const MULE_SCALE := 0.7
const MULE_REACH := 230.0      # how near a sheep or the donkey may come before the mule matters
const MULE_SHAKE := 300.0      # how near he may play before the stamping gets into his playing
const FLOOR_X := 4100.0        # the threshing floor and the storehouse: the donkey stands loaded there
const GIFT_X := 4340.0
const WELL_X := 4640.0
const KEEPER_X := 4880.0
const COUNT_X := 4960.0        # the gate of the day fold, where they are counted under the rod
const FOLD_X := 5120.0
const HUSH := 10.0             # seconds the flock stays quiet after a song, enough to be walked past one mule
const ASK := ["lamb", "rachel", "devorah", "noga"]      # the ones that answer to a name: the keeper must know each
const LOOKS := {
	"lamb": "Shai is this year's lamb: the smallest of the nine",
	"rachel": "Rachel is the biggest of the ewes",
	"devorah": "Devorah is a small ewe with a warm cream fleece",
	"noga": "Noga has the whitest fleece in the flock",
}

var jesse: Node2D
var messenger: Node2D
var keeper: Node2D
var kid: Node2D
var mules: Array = []          # the two of them, as they stand (null when unpainted and not under test)
var donkey
var bar_up := false            # the bar of the night fold is lifted: the nine can come out
var hush := 0.0                # seconds the flock is still quiet from the last song
var bray_cd := 0.0
var brays := 0                 # how many times a mule has scattered them (for the lesson, and the tests)
var penned := false            # the nine are in the day fold, with the keeper
var ask_i := 0                 # which of the named ones the keeper is being shown
var wrong := 0                 # wrong sheep shown for the one now asked
var pick_task: Dictionary
var pick_near = null
var counted := false
var well_shown := false
var handed := false            # the flock is the keeper's
var kid_tied := false
var bar_task: Dictionary
var count_task: Dictionary
var well_task: Dictionary
var halter_task: Dictionary
var kid_task: Dictionary
var leave_task: Dictionary


func _setup() -> void:
	mood = "theme_tender"
	ambience = "dawn"
	backdrop_art = "res://art/c2_home_backdrop.png"
	midground_art = "res://art/c2_home_mid.png"
	width = 5600.0
	flutters = 3
	pal.merge({
		"shafts": Color(1.0, 0.9, 0.65, 0.07), "mist": Color(1.0, 0.93, 0.8, 0.07),
		"sky_top": Color(0.36, 0.52, 0.78), "sky_mid": Color(0.98, 0.8, 0.6), "sky_bot": Color(1.0, 0.92, 0.72),
		"sun_pos": Vector2(0.22, 0.56), "sun_col": Color(1.0, 0.94, 0.75), "sun_size": 0.07,
		"far": Color(0.93, 0.76, 0.58), "near": Color(0.4, 0.32, 0.34), "rim": Color(1.0, 0.88, 0.6),
		"mote": Color(1.0, 0.93, 0.7, 0.5),
	}, true)
	segments = [make_ground(0.0, width, 566.0, 10.0, 1.1)]
	checkpoints = [220.0, 2080.0, 4230.0]


func _populate() -> void:
	var tint: Color = pal.get("char", Color(1, 1, 1))
	# his father's house: Jesse at the yard gate, and the king's man who brought the word
	if ResourceLoader.exists("res://art/jesse/anim/idle_00.png"):
		jesse = add_actor("jesse", on_ground(JESSE_X) + Vector2(0, 4), 0.31)
	messenger = add_person("messenger", MESSENGER_X, 1.0, true)
	kid = add_person("kid", KID_X)
	# the night fold beside the house, the nine still shut in it
	add_sprite("res://art/props/fold.png", on_ground(NIGHT_FOLD_X) + Vector2(0, 14), 1.5, 1)
	add_sheep(NIGHT_FOLD_X - 150.0, null, true)
	for i in 8:
		add_sheep(NIGHT_FOLD_X - 110.0 + i * 36.0)
	for s in get_tree().get_nodes_in_group("sheep"):
		if s.level == self:
			s.gatherable = false
	# the lane, and the two mules tethered along it
	for mx in MULES:
		mules.append(add_person("mule", mx, MULE_SCALE, true))      # painted far larger than the donkey at 1.0: a riding mule stands a hand above it, not twice its height
	# east of the lane: the threshing floor where the donkey was loaded before light, the well, and the day fold
	# sized in game units as in the well level (art/props are painted at many times these sizes): a 1.0 scale made
	# the floor, its fork and jars, the well and the trough giants beside David and the donkey
	_prop_wide("res://art/props/threshing.png", on_ground(FLOOR_X) + Vector2(0, 16), 400.0, 1, tint)
	donkey = Donkey.new()
	donkey.level = self
	donkey.position = on_ground(FLOOR_X + 20.0)
	add_child(donkey)
	_prop_wide("res://art/props/well.png", on_ground(WELL_X) + Vector2(0, 8), 170.0, 1, tint)
	_prop_wide("res://art/props/trough.png", on_ground(WELL_X + 150.0) + Vector2(0, 10), 128.0, 2, tint)
	keeper = add_person("keeper", KEEPER_X, 1.0, true)
	add_sprite("res://art/props/fold.png", on_ground(FOLD_X) + Vector2(0, 14), 1.5, 1)
	if Game.backdrop:
		return

	bar_task = add_task(BAR_X, "Lift the bar of the fold", 0.8, _lift_bar)
	add_hint(MULES[0] - 420.0, 150.0, "Strange beasts.  The flock will not pass them unquieted")
	add_gift("walksong", GIFT_X, func() -> bool: return sheep_count >= sheep_total and _clear_of_mules(),
			"Bring all nine past the mules.  Quiet them with the lyre, then call them on at a walk")
	pick_task = add_task(FOLD_X, "This one", 0.45, _pick, 44.0)
	pick_task["again"] = true
	pick_task["on"] = false
	count_task = add_task(COUNT_X, "Count them under the rod with him", 1.6, _count)
	count_task["on"] = false
	well_task = add_task(WELL_X, "Show him how the well is drawn", 1.2, _show_well)
	well_task["on"] = false
	halter_task = add_task(FLOOR_X + 20.0, "Take the donkey's halter", 0.7, _take_halter, 60.0)
	halter_task["on"] = false
	kid_task = add_task(GATE_X, "Tie the young goat behind the load", 1.2, _tie_kid, 70.0)
	kid_task["on"] = false
	leave_task = add_task(GATE_X, "Set out for Gibeah", 0.9, _leave, 70.0)
	leave_task["on"] = false


## A painted prop drawn `w` game units wide (its height follows the painting).
func _prop_wide(path: String, at: Vector2, w: float, z: int, tint: Color) -> Sprite2D:
	var sp := add_sprite(path, at, 1.0, z, tint)
	sp.scale = Vector2.ONE * (w / sp.texture.get_width())
	return sp


func begin() -> void:
	await say(["n_c2s1_intro", "1sam16_19", "n_c2s1_flock"])


# ------------------------------------------------------------------ the night fold

func _lift_bar() -> void:
	bar_up = true
	Game.sfx("logs", -8.0, 0.05)
	for s in get_tree().get_nodes_in_group("sheep"):
		if is_instance_valid(s) and s.level == self:
			s.gatherable = true
			s.hop = 0.6
	show_tip("They know him.  Walk in among them and they will come")


# ------------------------------------------------------------------ the mules

## Every one of the nine is with him and none is within reach of a mule.
func _clear_of_mules() -> bool:
	for s in followers:
		if is_instance_valid(s) and _mule_near(s.global_position.x, MULE_REACH + 40.0) >= 0.0:
			return false
	return true


## The mule within `reach` of x: where it stands, or -1.
func _mule_near(x: float, reach: float) -> float:
	for mx in MULES:
		if absf(x - float(mx)) < reach:
			return float(mx)
	return -1.0


## Stamping and blowing close by gets into his playing: the breath line will not hold still.
func song_noise(at: Vector2) -> float:
	return 1.0 if _mule_near(at.x, MULE_SHAKE) >= 0.0 else 0.0


func donkey_fear(x: float) -> float:
	return 1.0 if _mule_near(x, MULE_REACH) >= 0.0 else 0.0


## A song has gone out: for a little while the flock that heard it will pass what it would have bolted from.
func _on_song(_from: Vector2, settled: int) -> void:
	if settled > 0:
		hush = HUSH * float(Game.diff()["warning"])


func phrase(from: Vector2, feet: bool) -> void:
	if feet and is_instance_valid(donkey) and donkey.led:      # it will stand for any song; it will only walk for one that walks with it
		donkey.hear(from, 300.0)


func donkey_balked(d) -> void:
	if d.balks == 2:        # told only once it has happened twice
		show_tip("It will not pass the mules.  Play as you walk, and keep the phrases landing", 7.0)


## A mule throws up its head and brays: every sheep near it that is not quieted breaks away.
func _bray(mx: float) -> void:
	bray_cd = 2.5
	brays += 1
	Game.sfx("land", -4.0, 0.1, 0.7)      # a stamp of the hoof: the bray itself is a sound still to be made
	var k := MULES.find(mx)
	if k >= 0 and is_instance_valid(mules[k]):
		actor_play(mules[k], "mule", "bray", 10.0, -1.0, 1.0, 1.4, true)
	scatter_sheep(mx, MULE_REACH + 130.0)
	if brays == 2:          # told only once it has happened twice
		show_tip("They bolt from the mules.  Quiet them with the lyre first, then call them on, and go at a walk", 8.0)


func _update_mules(delta: float) -> void:
	hush = maxf(0.0, hush - delta)
	bray_cd = maxf(0.0, bray_cd - delta)
	if bray_cd > 0.0 or penned:
		return
	var running: bool = absf(player.velocity.x) > player.WALK + 25.0
	for s in followers:
		if not is_instance_valid(s) or not is_nan(s.stay) or s.leap >= 0.0:
			continue
		var mx := _mule_near(s.global_position.x, MULE_REACH)
		if mx >= 0.0 and (hush <= 0.0 or running):      # unquieted, or hurried past: either is enough
			_bray(mx)
			return


# ------------------------------------------------------------------ the keeper

func _at_fold() -> void:
	if penned or not Game.has("walksong") or sheep_count < sheep_total:
		return
	penned = true
	for i in followers.size():          # they go in and spread along the wall, each to its own place
		followers[i].stay = FOLD_X - 150.0 + i * 38.0
		followers[i].calm = 0.0
	pick_task["on"] = true
	await say(["n_c2s1_keeper", "n_c2s1_names"])


## The sheep he is standing by, of those in the fold.
func _nearest_penned():
	var best = null
	for s in followers:
		if is_instance_valid(s) and absf(s.global_position.x - player.global_position.x) < 30.0:
			if best == null or absf(s.global_position.x - player.global_position.x) < absf(best.global_position.x - player.global_position.x):
				best = s
	return best


func _asked_name() -> String:
	return Game.t(str(Game.flock_one(ASK[mini(ask_i, ASK.size() - 1)]).get("name", "")))


func _pick() -> void:
	var s = pick_near
	if s == null or not is_instance_valid(s) or ask_i >= ASK.size():
		return
	if s.who == ASK[ask_i]:
		s.name_t = 3.0
		s.hop = 1.0
		Game.sfx("lamb" if s.size < 0.9 else "sheep", -6.0, 0.1)
		Game.sfx("gather", -8.0, 0.05)
		ask_i += 1
		wrong = 0
		if ask_i >= ASK.size():
			pick_task["on"] = false
			count_task["on"] = true
			show_tip("He knows them now.  Count them in with him at the gate of the fold", 6.0)
		return
	wrong += 1
	s.hop = 0.5
	Game.sfx("ui_move", -8.0, 0.0, 0.7)
	show_tip(Game.t("Not that one.") + "  " + Game.t(LOOKS[ASK[ask_i]]), 6.0)
	if wrong >= 2:          # twice wrong: she lifts her head at her name
		for f in followers:
			if is_instance_valid(f) and f.who == ASK[ask_i]:
				f.name_t = 3.0
				f.hop = 0.6


func _count() -> void:
	counted = true
	if is_instance_valid(keeper):
		actor_play(keeper, "keeper", "count", 10.0, -1.0, 1.0, 1.4, true)
	well_task["on"] = true
	await say(["n_c2s1_count"])


func _show_well() -> void:
	well_shown = true
	Game.sfx("step_wet", -6.0, 0.1)
	handed = true
	halter_task["on"] = true
	await say(["n_c2s1_well", "n_c2s1_handed"])


# ------------------------------------------------------------------ the donkey, and the road

func _take_halter() -> void:
	donkey.led = true
	show_tip("The donkey follows him.  It has not been past the king's mules either", 6.0)


func _tie_kid() -> void:
	kid_tied = true
	donkey.led = false
	if is_instance_valid(kid) and is_instance_valid(donkey):
		kid.position = donkey.position + Vector2(-donkey.face * 64.0, 0.0)
	leave_task["on"] = true
	await say(["1sam16_20", "n_c2s1_gift"])


func _leave() -> void:
	await say(["n_c2s1_leave"])
	complete()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Game.backdrop or done or not is_instance_valid(player):
		return
	_update_mules(delta)
	if not penned and absf(player.global_position.x - FOLD_X) < 150.0:
		_at_fold()
	if penned and ask_i < ASK.size():
		pick_near = _nearest_penned()
		if pick_near != null:
			pick_task["x"] = pick_near.global_position.x
			pick_task["text"] = Game.t("This is %s") % _asked_name()
		else:
			pick_task["x"] = -9999.0
	if is_instance_valid(donkey) and donkey.led and not kid_tied:
		kid_task["on"] = absf(donkey.global_position.x - GATE_X) < 150.0
	set_goal(_goal_now())


func _goal_now() -> String:
	if kid_tied:
		return "Set out for Gibeah"
	if is_instance_valid(donkey) and donkey.led:
		if absf(donkey.global_position.x - GATE_X) < 150.0:
			return "Tie the young goat behind the load"
		if donkey.balking:
			return "Play to the donkey (R) and walk it on"
		return "Lead the donkey home to your father, west.  Play as you walk (R) past the mules"
	if handed:
		return "Take the donkey at the threshing floor, west"
	if counted:
		return "Show the keeper how the well is drawn"
	if penned and ask_i >= ASK.size():
		return "Count the nine in with the keeper at the gate"
	if penned:
		return Game.t("Show the keeper which is %s") % _asked_name()
	if not bar_up:
		return "Let the nine out of the night fold"
	if sheep_count < sheep_total:
		return "Gather the nine sheep"
	if Game.has("walksong") and _clear_of_mules() and player.global_position.x > MULES[1]:
		return "Bring the nine to the keeper at the fold, east"
	if _clear_of_mules() and player.global_position.x > MULES[1]:
		return "Stand in the shaft of light, east"
	if hush > 0.0:
		return "Call them on (Q) and walk them past the mule"
	return "Quiet the flock with the lyre (R) before the mules"
