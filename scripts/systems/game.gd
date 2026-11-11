extends Node
## Global state: input map, save data, chapter data, shared resources.

const SAVE_PATH := "user://save.json"
const INK := Color(0.055, 0.05, 0.09)
const CREAM := Color(0.98, 0.93, 0.82)

var chapters: Array = []
var narration: Dictionary = {}
var narration_pt: Dictionary = {}     # the same lines in Brazilian Portuguese
var _ui_pt: Dictionary = {}
var save: Dictionary = {}
var main: Node = null

var stones_total := 0     # every smooth stone and every place there is to find, counted from the map
var places_total := 0
var gifting := false     # a gift is being given: the world holds still, but its name is shown
var cinematic := false   # story scene playing: player and enemies hold still
var backdrop := false    # level is only a background for the menu
var fast := false        # automated test run: skip waits

var serif: Font

# music: two players so tracks can crossfade
const MUSIC_DB := -9.0
const DUCK_DB := -17.0
var _players: Array = []
var _active := 0
var _mood := ""
var _duck := false

# sound effects and ambience
const AMBIENT_EVENTS := {
	"pastures": [["bird1", -15.0], ["bird2", -16.0], ["bird1", -19.0], ["gust", -17.0], ["sheep", -22.0]],
	"dusk": [["cricket", -17.0], ["cricket", -20.0], ["gust", -16.0], ["owl", -18.0]],
	"night": [["gust", -13.0], ["owl", -17.0], ["cricket", -22.0], ["gust", -17.0]],
	"dawn": [["bird1", -14.0], ["bird2", -15.0], ["rooster", -19.0], ["bird2", -19.0]],
}
var _sfx_pool: Array = []
var _sfx_next := 0
var _beds: Array = []
var _loop_player: AudioStreamPlayer
var _loop_name := ""
var _ambience := ""
var _next_event := 3.0
var glow_tex: GradientTexture2D
var add_mat: CanvasItemMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_resources()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		add_child(p)
		_players.append(p)
	for i in 12:
		var sp := AudioStreamPlayer.new()
		add_child(sp)
		_sfx_pool.append(sp)
	for i in 2:
		var bed := AudioStreamPlayer.new()
		bed.volume_db = -60.0
		add_child(bed)
		_beds.append(bed)
	_loop_player = AudioStreamPlayer.new()
	add_child(_loop_player)
	_load_data()
	load_game()


func _setup_resources() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino", "Georgia", "Times New Roman", "serif"])
	serif = f

	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 0.38))
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.width = 128
	glow_tex.height = 128
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)

	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0])
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0])
	_bind("aim_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0])
	_bind("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0])
	_bind("jump", [KEY_SPACE, KEY_Z], [JOY_BUTTON_A])
	_bind("attack", [KEY_J, KEY_X], [JOY_BUTTON_X])
	_bind("sling", [KEY_K, KEY_C], [JOY_BUTTON_B])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("roll", [KEY_L, KEY_V], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("grab", [KEY_E, KEY_I], [JOY_BUTTON_Y])
	_bind("walk", [KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("call", [KEY_Q, KEY_O], [JOY_BUTTON_LEFT_STICK])
	_bind("growth", [KEY_TAB], [JOY_BUTTON_BACK])
	_bind("map", [KEY_M], [JOY_BUTTON_RIGHT_STICK])
	_bind("accept", [KEY_ENTER, KEY_SPACE, KEY_Z, KEY_J], [JOY_BUTTON_A])


func _bind(action: String, keys: Array, buttons: Array = [], axis: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	if axis.size() == 2:
		var e := InputEventJoypadMotion.new()
		e.axis = axis[0]
		e.axis_value = axis[1]
		InputMap.action_add_event(action, e)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


## The language of the words on screen: "en" or "pt" (Brazilian Portuguese).
func lang() -> String:
	return str(save.get("lang", "en"))


## A piece of on-screen text in the player's language. English is the key; anything not yet translated stays English.
func t(s: String) -> String:
	if lang() == "pt":
		return str(_ui_pt.get(s, s))
	return s


## A line of narration or speech in the player's language.
func line(id: String) -> Dictionary:
	if lang() == "pt" and narration_pt.has(id):
		return narration_pt[id]
	return narration.get(id, {"text": id})


func _load_data() -> void:
	chapters = _read_json("res://data/chapters.json").get("chapters", [])
	for ch in chapters:
		if ch.has("narration"):
			narration.merge(_read_json(ch["narration"]).get("lines", {}))
			narration_pt.merge(_read_json(str(ch["narration"]).replace(".json", ".pt.json")).get("lines", {}))
	_ui_pt = _read_json("res://data/ui.pt.json")
	var places: Dictionary = _read_json("res://data/map.json").get("places", {})
	for k in places:
		stones_total += (places[k].get("stones", []) as Array).size()
		places_total += (places[k].get("finds", []) as Array).size()


## Sections of the playable chapter.
func sections() -> Array:
	return chapters[0].get("sections", [])


func default_save() -> Dictionary:
	return {"section": 0, "checkpoint": 0, "has_sling": false, "unlocked": 0, "started": false, "finished": false, "difficulty": 1,
			"growth": {}, "stones": [], "gifts": []}


func load_game() -> void:
	save = default_save()
	var on_disk := _read_json(SAVE_PATH)
	save.merge(on_disk, true)
	if not on_disk.is_empty() and not on_disk.has("gifts"):
		# a journey begun before gifts were given at set places: he keeps what he had earned
		save["gifts"] = []
		gifts_for(int(save.get("section", 0)))
		if save.get("has_sling", false):
			give("sling", true)
		for pair in [["voice", 1], ["feet", 2], ["eye", 2], ["heart", 1]]:
			if rank(pair[0]) >= int(pair[1]):
				give(pair[0], true)
	if not on_disk.has("pouch"):      # a journey begun before the pouch: it starts full
		fill_pouch()
	save["section"] = int(save["section"])
	save["checkpoint"] = int(save["checkpoint"])
	save["unlocked"] = int(save["unlocked"])
	if save.get("finished", false):      # whoever has finished the chapter may walk into any part of it, sections added since included
		save["unlocked"] = maxi(save["unlocked"], 99)


func save_game() -> void:
	if fast:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func new_game() -> void:
	var unlocked: int = save.get("unlocked", 0)
	var finished: bool = save.get("finished", false)
	var difficulty: int = int(save.get("difficulty", 1))
	var language := lang()
	save = default_save()      # a new journey: his crafts begin again
	save["difficulty"] = difficulty
	save["lang"] = language
	save["unlocked"] = unlocked
	save["finished"] = finished
	save["started"] = true
	save_game()


# ------------------------------------------------------------- David's growth
## What David can do comes to him in two ways.
## A gift is something new: the call, the chained blow, the sling, the seen flight of a stone, a steadier heart,
## the running leap. Each is given once, at one place, after he has done something there to earn it, and the
## ground that follows asks for it straight away.
## A craft is the slow strengthening of what he already has: it fills as he uses it, and at each of three marks
## it grows a little. A craft never gives him anything he could not already do.
signal grew(craft: String, rank: int)
signal gifted(id: String)
signal stone_found(total: int)
signal place_found(name: String)

const GIFTS := {
	"voice": {"name": "The Shepherd's Voice", "line": "Sheep that hear his call come to him.", "key": "Q  call", "craft": "voice", "why": "A flock is led, not driven. The shepherd goes ahead, and they follow his voice.", "how": "In the Pastures: bring in four sheep by hand.", "after": 0},
	"hand": {"name": "The Strong Hand", "line": "Blow follows blow: strike again as each one lands.", "key": "J  J  J  chain the blows", "craft": "hand", "why": "His staff is all there is between the flock and what hunts it.", "how": "At the Well: move the stone, and hold the water.", "after": 1},
	"sling": {"name": "The Sling", "line": "A stone, whirled and let fly.", "key": "K  hold, then release", "craft": "eye", "why": "It reaches what the staff cannot.", "how": "In the ravine: drive the pack from the brook.", "after": 2},
	"eye": {"name": "The Sure Eye", "line": "He sees the whole flight of the stone before he lets it go.", "key": "↑ ↓  aim as he winds", "craft": "eye", "why": "A stone that misses is a stone wasted, and the beast is already moving.", "how": "In the Wadi: break the three jars, and bring every boulder down.", "after": 3},
	"heart": {"name": "The Steady Heart", "line": "One more heart.", "key": "", "craft": "heart", "why": "He stood where he could have run. That is kept.", "how": "In the Bear's Den: drive off the bear.", "after": 4},
	"feet": {"name": "The Swift Feet", "line": "The running leap: jump at a full run to go higher and farther.", "key": "Run, then Space", "craft": "feet", "why": "A lamb in a lion's mouth is lost in the time it takes to walk.", "how": "On the Ridge: reach the light at a run.", "after": 5},
}
const GIFT_ORDER := ["voice", "hand", "sling", "eye", "heart", "feet"]

const CRAFTS := {
	"feet": {"name": "Swift Feet", "by": "ground covered", "marks": [120, 420, 1500], "gift": "feet", "gifts": [
		"He runs a little faster.",
		"He runs faster.",
		"Faster still, and he is ready to dodge again sooner."]},
	"hand": {"name": "Strong Hand", "by": "blows landed with the staff", "marks": [30, 150, 450], "gift": "hand", "gifts": [
		"The staff reaches farther.",
		"The rising blow lands harder and throws a beast back.",
		"The low sweep lands harder, and blows chain more easily."]},
	"eye": {"name": "Sure Eye", "by": "stones that find their mark", "marks": [6, 30, 90], "gift": "sling", "gifts": [
		"The sling comes up to speed sooner.",
		"A full-wound stone flies faster.",
		"A full-wound stone strikes harder."]},
	"heart": {"name": "Steady Heart", "by": "blows escaped and beasts driven off", "marks": [10, 45, 140], "gift": "heart", "gifts": [
		"After a clean escape the opening lasts longer.",
		"The opening lasts longer still.",
		"One more heart."]},
	"voice": {"name": "Shepherd's Voice", "by": "sheep brought in", "marks": [2, 14, 45], "gift": "voice", "gifts": [
		"His call carries farther.",
		"Farther still, and jackals shy from it.",
		"His call carries across the whole hillside."]},
}
const CRAFT_ORDER := ["feet", "hand", "eye", "heart", "voice"]


func craft_xp(craft: String) -> float:
	return float(save.get("growth", {}).get(craft, 0.0))


func rank(craft: String) -> int:
	var xp := craft_xp(craft)
	var r := 0
	for m in CRAFTS[craft]["marks"]:
		if xp >= float(m):
			r += 1
	return r


func grow(craft: String, amount: float = 1.0) -> void:
	if backdrop or not CRAFTS.has(craft):
		return
	var g: Dictionary = save.get("growth", {})
	var before := rank(craft)
	g[craft] = float(g.get(craft, 0.0)) + amount
	save["growth"] = g
	var now := rank(craft)
	if now > before:
		grew.emit(craft, now)
		save_game()


func has(id: String) -> bool:
	return id in save.get("gifts", [])


## How far his call carries.
func call_reach() -> float:
	return [430.0, 540.0, 640.0, 1000.0][rank("voice")] if has("voice") else 0.0


## A gift is given: once, and for good.
func give(id: String, quiet: bool = false) -> void:
	if has(id) or not GIFTS.has(id):
		return
	var list: Array = save.get("gifts", [])
	list.append(id)
	save["gifts"] = list
	if id == "sling":
		save["has_sling"] = true
	if not quiet:
		save_game()
		gifted.emit(id)


## Whoever walks into a later section by the map or the menu has what the earlier ones would have given him.
func gifts_for(section_idx: int) -> void:
	for id in GIFT_ORDER:
		if int(GIFTS[id]["after"]) < section_idx:
			give(id, true)
	if has("sling"):
		save["has_sling"] = true


## The shepherd's pouch. Smooth stones are what the sling was made for: for every three he has found, the pouch
## holds one more (five at most, as at the brook of Elah). A full-wound shot takes a smooth stone from the pouch
## if there is one: it flies true, strikes harder, and staggers even a bear or a lion. The pouch is filled again
## at every watchfire.
func pouch_max() -> int:
	return mini(5, stones().size() / 3)


func pouch() -> int:
	return clampi(int(save.get("pouch", 0)), 0, pouch_max())


func fill_pouch() -> void:
	save["pouch"] = pouch_max()


func stones() -> Array:
	return save.get("stones", [])


func find_stone(id: String) -> void:
	var list: Array = stones()
	if id in list:
		return
	list.append(id)
	save["stones"] = list
	if list.size() % 3 == 0 and list.size() <= 15:      # the pouch has grown: it is filled on the spot
		fill_pouch()
	grow("eye", 1.0)
	save_game()
	stone_found.emit(list.size())


func places() -> Array:
	return save.get("places", [])


## A place off the path, come upon for the first time.
func find_place(id: String, name: String, craft: String) -> void:
	var list: Array = places()
	if id in list:
		return
	list.append(id)
	save["places"] = list
	grow(craft, 3.0)
	save_game()
	place_found.emit(name)


## Soft additive light blob.
func glow(color: Color, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_tex
	s.material = add_mat
	s.modulate = color
	s.scale = Vector2.ONE * (size / 128.0)
	return s


func label(text: String, size: int, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Brief freeze on a hit, for weight.
func hitstop(seconds: float = 0.06) -> void:
	if fast:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## One-shot burst of soft particles.
func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12, speed: float = 120.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = glow_tex
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	p.color = color
	p.z_index = 8
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Crossfade to the music for a mood (a file in audio/music). "" fades out.
func music(mood: String, seconds: float = 2.0) -> void:
	if mood == _mood:
		return
	_mood = mood
	var old_p: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var new_p: AudioStreamPlayer = _players[_active]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old_p, "volume_db", -60.0, seconds)
	tw.chain().tween_callback(old_p.stop)
	var path := "res://audio/music/%s.mp3" % mood
	if mood == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = true
	new_p.stream = stream
	new_p.volume_db = -60.0
	new_p.play()
	create_tween().tween_property(new_p, "volume_db", DUCK_DB if _duck else MUSIC_DB, seconds)


## Lower the music under the narrator's voice.
func duck(on: bool) -> void:
	_duck = on
	var p: AudioStreamPlayer = _players[_active]
	if p.playing:
		create_tween().tween_property(p, "volume_db", DUCK_DB if on else MUSIC_DB, 0.6)


const DIFFICULTY := [
	{"name": "Gentle", "about": "More hearts. Animals are weaker and give longer warnings.", "hearts": 7, "enemy_hp": 0.7, "warning": 1.35},
	{"name": "Shepherd", "about": "The intended challenge.", "hearts": 5, "enemy_hp": 1.0, "warning": 1.0},
	{"name": "Warrior", "about": "Fewer hearts. Animals are tougher and strike with little warning.", "hearts": 4, "enemy_hp": 1.4, "warning": 0.75},
]


func diff() -> Dictionary:
	return DIFFICULTY[clampi(int(save.get("difficulty", 1)), 0, 2)]


## Brief slow motion, for the moment a great beast is driven off.
func slowmo(scale: float = 0.3, seconds: float = 0.9) -> void:
	if fast:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


## Plays a sound effect from audio/sfx. Pitch varies a little each time so
## repeated sounds (steps, hits) never sound mechanical.
func sfx(sound: String, volume_db: float = 0.0, pitch_vary: float = 0.07) -> void:
	if fast:
		return
	var path := "res://audio/sfx/%s.mp3" % sound
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = load(path)
	p.volume_db = volume_db - 5.0
	p.pitch_scale = 1.0 + randf_range(-pitch_vary, pitch_vary)
	p.play()


## A sound that holds while something continues, like the sling whirling.
func sfx_hold(sound: String, on: bool, volume_db: float = -8.0) -> void:
	if fast:
		return
	if on and _loop_name != sound:
		var path := "res://audio/sfx/%s.mp3" % sound
		if not ResourceLoader.exists(path):
			return
		var stream: AudioStream = load(path)
		if stream is AudioStreamMP3:
			stream.loop = true
		_loop_player.stream = stream
		_loop_player.volume_db = volume_db
		_loop_player.play()
		_loop_name = sound
	elif not on and _loop_name == sound:
		_loop_player.stop()
		_loop_name = ""


## The living sound of a place: a quiet bed, plus birds, crickets, owls or
## gusts at irregular moments so it never audibly repeats.
func ambience(kind: String) -> void:
	if kind == _ambience or fast:
		return
	_ambience = kind
	_next_event = randf_range(2.0, 5.0)
	var path := "res://audio/sfx/amb_%s.mp3" % kind
	for i in _beds.size():
		var bed: AudioStreamPlayer = _beds[i]
		create_tween().tween_property(bed, "volume_db", -60.0, 1.5)
		if kind == "" or not ResourceLoader.exists(path):
			continue
		var stream: AudioStream = load(path).duplicate()
		if stream is AudioStreamMP3:
			stream.loop = true
		bed.stream = stream
		bed.pitch_scale = [0.82, 1.0][i]      # two copies out of step with each other hide the loop
		bed.play()
		create_tween().tween_property(bed, "volume_db", -25.0 - i * 2.0, 2.5)


func _process(delta: float) -> void:
	if _ambience == "" or get_tree().paused:
		return
	_next_event -= delta
	if _next_event <= 0.0:
		_next_event = randf_range(2.5, 8.0)
		var events: Array = AMBIENT_EVENTS.get(_ambience, [])
		if not events.is_empty():
			var e: Array = events[randi() % events.size()]
			sfx(e[0], e[1] + (9.0 if _duck else 0.0) * -1.0, 0.12)
