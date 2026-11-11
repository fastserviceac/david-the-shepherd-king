extends "res://scripts/levels/level_base.gd"
## 1.6 The Lion's Ridge. Night. Above the cave, the lion that took the lamb.
## It is driven off and the lamb is rescued.

const Lion = preload("res://scripts/enemies/lion.gd")

var lion
var lamb
var arena_walls: Array = []
var lion_started := false


func _setup() -> void:
	birds = false
	leaves = Color(0.6, 0.55, 0.6, 0.4)
	ambience = "night"
	backdrop_art = "res://art/s3_backdrop.png"
	midground_art = "res://art/s3_mid.png"
	mid_tint = Color(0.8, 0.84, 1.0)
	mood = "ridge"
	width = 5400.0
	pal.merge({
		"mist": Color(0.6, 0.72, 1.0, 0.11),
		"grass": Color(0.34, 0.44, 0.75), "ground": Color(0.3, 0.35, 0.56), "char": Color(0.6, 0.67, 0.92),
		"sky_top": Color(0.03, 0.05, 0.16), "sky_mid": Color(0.1, 0.16, 0.38), "sky_bot": Color(0.36, 0.45, 0.7),
		"sun_pos": Vector2(0.68, 0.3), "sun_col": Color(0.85, 0.9, 1.0), "sun_size": 0.085, "stars": 1.0,
		"far": Color(0.3, 0.38, 0.62), "near": Color(0.09, 0.11, 0.24), "rim": Color(0.7, 0.8, 1.0),
		"wool": Color(0.8, 0.84, 0.95), "mote": Color(0.7, 0.8, 1.0, 0.45),
	}, true)
	segments = [
		make_ground(0.0, 1210.0, 610.0, 10.0, 0.3),
		make_ground(1200.0, 2570.0, 530.0, 6.0, 1.2),
		make_ground(2560.0, width, 468.0, 5.0, 2.2),
	]
	platforms.append(Rect2(1110.0, 570.0, 100.0, 60.0))
	checkpoints = [150.0, 1290.0, 2440.0]
	ledge(1960.0, 114.0, 120.0)
	if Game.save.get("has_sling", false) == false:
		Game.save["has_sling"] = true


func _populate() -> void:
	# off the path: beyond the leap, the edge of the ridge and the whole wilderness below
	var look := add_perch(2140.0, 182.0, 230.0)
	add_place("outlook", look, "The Outlook", "eye")
	for tx in [260.0, 820.0, 1420.0, 2320.0, 2720.0, 4100.0]:
		add_tree(tx, rng.randf_range(0.9, 1.5), rng.randf() < 0.7)

	add_jackal(700.0, 420.0, 1050.0)
	add_stone("s3_start", on_ground(52.0))
	add_stone("s3_leap", Vector2(2020.0, platforms[1].position.y))

	# how to fight, as a reminder on the way up
	add_hint(820.0, 150.0, "L  dodge")
	add_hint(1150.0, 150.0, "↓  duck")
	add_hint(1420.0, 150.0, "E  seize a spent beast")
	# the ridge's own scavengers, drawn by the lion's kill
	var j1 = add_jackal(1800.0, 1400.0, 2400.0)
	var j2 = add_jackal(2150.0, 1400.0, 2400.0)
	# the gift of this place: the running leap. Both jackals driven off; then the rock step that needs it
	add_gift("feet", 2330.0, func() -> bool: return (not is_instance_valid(j1) or j1.fleeing) and (not is_instance_valid(j2) or j2.fleeing), "Drive off the jackals on the slope")
	add_block(Rect2(2575.0, on_ground(2500.0).y - 110.0, 90.0, 80.0))
	add_trigger(2950.0, 3100.0, _start_lion)

	# the lamb, waiting beyond the lion
	lamb = add_sheep(3950.0, null, true)
	lamb.gatherable = false
	sheep_total = 0


func begin() -> void:
	await say(["n_s3_intro"])


func _start_lion() -> void:
	if lion_started:
		return
	lion_started = true
	arena_walls = [add_wall(2640.0), add_wall(4060.0)]
	await say(["1sam17_34"])
	lion = Lion.new()
	lion.level = self
	lion.player = player
	lion.min_x = 2680.0
	lion.max_x = 4020.0
	lion.home = on_ground(3800.0)
	lion.position = lion.home
	lion.dir = -1
	lion.lamb_x = lamb.position.x
	add_child(lion)
	boss = lion
	boss_name = "The Lion"
	Game.music("battle", 0.8)
	lion.defeated.connect(_lion_defeated)


## The lion has reached the lamb. It is not killed, but it is a blow to him, and heart to the lion.
func lamb_struck() -> void:
	lamb.hop = 1.0
	Game.sfx("lamb", 0.0, 0.1)
	player.shake = maxf(player.shake, 8.0)
	Game.burst(self, lamb.position + Vector2(0, -20), Color(1.0, 0.9, 0.8, 0.8), 12, 140.0)
	show_tip("The lamb!  Keep the lion from it")


func _lion_defeated() -> void:
	boss = null
	Game.music("anointing", 3.0)
	for w in arena_walls:
		w.queue_free()
	arena_walls.clear()
	lamb.gatherable = true
	add_glow(lamb.position + Vector2(0, -16), Color(1.0, 0.9, 0.7, 0.5), 200.0)
	add_hint(3950.0, 120.0, "Go to the lamb")


func _on_respawn() -> void:
	if is_instance_valid(lion) and not lion.fleeing:
		lion.reset()


func _on_sheep(s) -> void:
	# he lifts the lamb onto his shoulders and walks on with it as the narrator speaks
	s.visible = false
	player.facing = 1
	player.act = "carry"
	player.act_t = 0.0
	await say(["n_s3_end", "n_s3_remember", "1sam17_37"])
	complete()
