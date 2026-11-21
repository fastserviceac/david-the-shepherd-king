extends Node

const FA = preload("res://scripts/systems/frame_anim.gd")
## Global state: input map, save data, chapter data, shared resources.

const SAVE_PATH := "user://save.json"
const INK := Color(0.055, 0.05, 0.09)
const CREAM := Color(0.98, 0.93, 0.82)

var chapters: Array = []
var _sections: Array = []      # every section of every chapter that has any, in the order they are played
var _chapter_at: Array = []    # which chapter each of them belongs to
var force_ready := false       # the automated tests alone: a section whose pictures are not yet painted may be entered
var narration: Dictionary = {}
var narration_pt: Dictionary = {}     # the same lines in Brazilian Portuguese
var _ui_pt: Dictionary = {}
var save: Dictionary = {}
var main: Node = null

var stones_total := 0     # every smooth stone and every place there is to find, counted from the map
var places_total := 0
var pad := false          # the last thing touched was a controller: prompts name its buttons, not keys
var touch := false        # the screen was touched: the on-screen controls show, and prompts name them
## How much closer the camera is on a screen taller than 16:9: enough that it shows the same height of the
## world as a phone does, and the extra width of the phone is what is given up. The painted scenery is made to
## a 16:9 frame; shown taller it ends in a hard line across the treetops.
func view_k() -> float:
	return (720.0 + deck) / 720.0


var deck := 0.0           # height (in game pixels) of the strip under the picture that the touch controls stand in
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
	"town": [["dog_far", -20.0], ["goat", -24.0], ["voices_far", -19.0], ["gust", -18.0], ["bird2", -21.0]],
	"hall": [["lamp_sputter", -20.0], ["robe", -22.0], ["lamp_sputter", -23.0], ["voices_far", -26.0]],
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
	Input.joy_connection_changed.connect(func(_d, _c): apply_pad())
	touch = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if "--phone" in OS.get_cmdline_user_args():      # try the phone layout on the computer
		touch = true
	if OS.has_feature("mobile") or "--phone" in OS.get_cmdline_user_args():
		get_tree().root.size_changed.connect(_fit_screen)
		_fit_screen.call_deferred()
	_setup_resources()
	# what he does in the first seconds of any session, in the order he is likely to do it
	FA.warm("david", ["idle", "walk", "run", "jump", "attack", "roll", "hop", "sway", "duck", "hurt", "flinch",
		"sling", "throw", "attack2", "attack3", "attack4", "spin", "call", "pickup", "clinch"])
	FA.warm("jackal", ["walk", "run", "lunge"])
	FA.warm("sheep", ["walk", "graze", "run", "lie", "rest", "uneasy"])
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
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	_voice.finished.connect(func(): duck(false))
	_load_data()
	load_game()
	if has("favour"):      # in the king's house he may be given the king's shield to bear (only known once the save is read)
		FA.warm("david", FAVOUR_SETS)


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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
		touch = false
		if event.device != joy_dev:      # another controller: on Auto its kind may say yes with another button
			joy_dev = event.device
			apply_pad.call_deferred()
	elif event is InputEventKey and not "--phone" in OS.get_cmdline_user_args():      # trying the phone layout: stay in it
		pad = false
		touch = false


var joy_dev := 0          # the controller last used: its name says which kind it is

## The keyboard key a prompt is written with, and the action it stands for: a controller names that action's button.
const KEY_ACTION := {"Space": "jump", "Espaço": "jump", "J": "attack", "K": "sling", "E": "grab", "L": "roll", "Shift": "walk",
		"Q": "call", "Tab": "growth", "M": "map", "R": "lyre", "Enter": "accept", "Esc": "pause"}
const PAD_WORDS := ["Space", "Espaço", "Shift", "Tab", "Enter", "Esc"]

## The actions a controller's buttons can be given to, in the order the button screen lists them, with the button
## each has unless the player gives it another. A number under 100 is a button; 104 and 105 are the triggers.
const PAD_ACTIONS := ["jump", "attack", "sling", "roll", "grab", "walk", "call", "lyre", "growth", "map", "pause"]
const PAD_ACTION_NAMES := {"jump": "Jump", "attack": "Staff", "sling": "Sling", "roll": "Dodge", "grab": "Grab", "walk": "Walk",
		"call": "Call", "lyre": "Lyre", "growth": "Growth", "map": "Map", "pause": "Pause"}
const PAD_DEFAULT := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "sling": JOY_BUTTON_B, "roll": JOY_BUTTON_RIGHT_SHOULDER,
		"grab": JOY_BUTTON_Y, "walk": JOY_BUTTON_LEFT_SHOULDER, "call": JOY_BUTTON_LEFT_STICK, "lyre": 100 + JOY_AXIS_TRIGGER_RIGHT,
		"growth": JOY_BUTTON_BACK, "map": JOY_BUTTON_RIGHT_STICK, "pause": JOY_BUTTON_START}
const PAD_STYLES := ["auto", "xbox", "ps", "nintendo"]
const PAD_STYLE_NAMES := {"auto": "Auto", "xbox": "Xbox", "ps": "PlayStation", "nintendo": "Nintendo"}
## What is printed on each button. The game reads a button by where it sits (the bottom face button is always 0),
## so on a Nintendo pad the bottom one is B and the right one A, the other way round from an Xbox pad.
const PAD_NAMES := {
	"xbox": {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 5: "Guide", 6: "Start", 7: "LS", 8: "RS", 9: "LB", 10: "RB", 104: "LT", 105: "RT"},
	"ps": {0: "✕", 1: "○", 2: "□", 3: "△", 4: "Share", 5: "PS", 6: "Options", 7: "L3", 8: "R3", 9: "L1", 10: "R1", 104: "L2", 105: "R2"},
	"nintendo": {0: "B", 1: "A", 2: "Y", 3: "X", 4: "−", 5: "Home", 6: "+", 7: "LS", 8: "RS", 9: "L", 10: "R", 104: "ZL", 105: "ZR"},
}
const DEAD_ZONES := [0.15, 0.25, 0.4, 0.55]
const TOUCH_MODES := ["auto", "on", "off"]


## Which kind of controller the button names are for: the one chosen in the settings, or, left on Auto, the one
## the name of the controller in hand gives away.
func pad_style() -> String:
	var s := str(save.get("pad_style", "auto"))
	if s != "auto" and PAD_NAMES.has(s):
		return s
	return style_of(Input.get_joy_name(joy_dev) if joy_dev in Input.get_connected_joypads() else
			(Input.get_joy_name(Input.get_connected_joypads()[0]) if not Input.get_connected_joypads().is_empty() else ""))


var _ps_re: RegEx      # compiled once: prompts ask for button names every frame
var _key_re: RegEx

func style_of(joy_name: String) -> String:
	var n := joy_name.to_lower()
	for w in ["nintendo", "pro controller", "switch", "joy-con", "joycon"]:
		if n.contains(w):
			return "nintendo"
	if _ps_re == null:
		_ps_re = RegEx.create_from_string("\\b(ps[345]?|dualsense|dualshock|playstation|sony)\\b")
	if _ps_re.search(n) != null or n.contains("dualsense") or n.contains("dualshock"):
		return "ps"
	return "xbox"


## The button (or trigger) an action is given to on a controller.
func pad_code(action: String) -> int:
	if action == "accept":       # Nintendo's way: the right button says yes, the bottom one goes back
		return JOY_BUTTON_B if pad_style() == "nintendo" else JOY_BUTTON_A
	if action == "back":
		return JOY_BUTTON_A if pad_style() == "nintendo" else JOY_BUTTON_B
	var m: Dictionary = save.get("pad_map", {})
	return int(m.get(action, PAD_DEFAULT.get(action, -1)))


func button_name(code: int) -> String:
	var names: Dictionary = PAD_NAMES[pad_style()]
	if names.has(code):
		return str(names[code])
	match code:
		JOY_BUTTON_DPAD_UP: return "↑"
		JOY_BUTTON_DPAD_DOWN: return "↓"
		JOY_BUTTON_DPAD_LEFT: return "←"
		JOY_BUTTON_DPAD_RIGHT: return "→"
	return "%s %d" % [t("Button"), code]


## The name on the button that does an action, for the controller in hand.
func pad_name(action: String) -> String:
	return button_name(pad_code(action))


## Gives an action a button (or trigger). Whatever action had that button takes the one this action gave up,
## so no button is ever left doing two things or none.
func set_pad(action: String, code: int) -> void:
	var m: Dictionary = save.get("pad_map", {}).duplicate()
	var old := pad_code(action)
	for a in PAD_ACTIONS:
		if a != action and pad_code(a) == code:
			m[a] = old
	m[action] = code
	save["pad_map"] = m
	apply_pad()


func reset_pad() -> void:
	save.erase("pad_map")
	apply_pad()


func dead_zone() -> float:
	return clampf(float(save.get("dead_zone", 0.4)), 0.05, 0.9)


func touch_mode() -> String:
	var m := str(save.get("touch_ctl", "auto"))
	return m if m in TOUCH_MODES else "auto"


## Whether the buttons on the screen are drawn: on Auto once the screen is touched, or always, or never.
func touch_shown() -> bool:
	match touch_mode():
		"on": return true
		"off": return false
	return touch


## Puts the controller's buttons where the player (or the kind of controller) wants them, and sets how far the
## stick must lean before it counts. The keys are left as they are.
func apply_pad() -> void:
	for action in PAD_ACTIONS + ["accept", "back"]:
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton or (e is InputEventJoypadMotion and (e.axis == JOY_AXIS_TRIGGER_LEFT or e.axis == JOY_AXIS_TRIGGER_RIGHT)):
				InputMap.action_erase_event(action, e)
		var code := pad_code(action)
		if code >= 100:
			var m := InputEventJoypadMotion.new()
			m.axis = code - 100
			m.axis_value = 1.0
			InputMap.action_add_event(action, m)
		elif code >= 0:
			var b := InputEventJoypadButton.new()
			b.button_index = code
			InputMap.action_add_event(action, b)
	for action in ["move_left", "move_right", "aim_up", "move_down"]:
		InputMap.action_set_deadzone(action, dead_zone())


## A prompt as it should read for whatever the player is holding. Text is written for the keyboard ("J  staff");
## with a controller in hand the key at the front, and any key named in the words, becomes its button.
func keys(s: String) -> String:
	if touch:
		return _touch_keys(s)
	if not pad:
		return s
	var cut := s.find("  ")
	var head := s.substr(0, cut) if cut > 0 and cut <= 14 else ""
	var rest := s.substr(cut) if head != "" else s
	if head != "":
		var out: Array = []
		for tok in head.split(" ", false):
			var b: String = _pad_key(tok)
			if b != "" and not (b in out and b == "Stick"):
				out.append(b)
		head = " ".join(out)
	for w in PAD_WORDS:
		rest = rest.replace(w, pad_name(KEY_ACTION[w]))
	return head + rest


## A keyboard key as the controller's button that does the same.
func _pad_key(k: String) -> String:
	if k == "A":
		return ""
	if k == "D":
		return "Stick"
	if KEY_ACTION.has(k):
		return pad_name(KEY_ACTION[k])
	return k


const TOUCH_KEYS := {"Space": "Jump", "Espaço": "Jump", "Enter": "Tap", "J": "Staff", "K": "Sling", "L": "Dodge",
		"E": "Grab", "Q": "Call", "R": "Lyre", "Tab": "Growth", "M": "Map", "Esc": "II", "Shift": "Stick", "A": "", "D": "Stick"}


## One key as it should be named on a key-cap: the key itself, the controller's button, or the button on the screen.
func cap(key: String) -> String:
	if touch:
		return t(str(TOUCH_KEYS.get(key, key)))
	if pad:
		return _pad_key(key)
	return key

## The same prompt for the on-screen controls: keys become the names on the buttons (in the player's language).
## In the words only a key on its own is changed: "(Q)", "hold K", ":  J" at the end, never a letter inside a word.
func _touch_keys(s: String) -> String:
	var cut := s.find("  ")
	var head := s.substr(0, cut) if cut > 0 and cut <= 14 else ""
	var rest := s.substr(cut) if head != "" else s
	if head != "" and Array(head.split(" ", false)).all(func(tok): return TOUCH_KEYS.has(tok.trim_suffix(":"))):
		var out: Array = []
		for tok in head.split(" ", false):
			var b: String = t(str(TOUCH_KEYS[tok.trim_suffix(":")]))
			if b != "" and tok.ends_with(":"):
				b += ":"
			if b != "" and not b in out:
				out.append(b)
		head = " ".join(out)
	else:
		rest = head + rest
		head = ""
	if _key_re == null:
		_key_re = RegEx.create_from_string("(?<![\\p{L}])(Space|Espaço|Enter|Shift|Tab|Esc|[JKLQEM])(?![\\p{L}])")
	var re := _key_re
	var out_s := ""
	var at := 0
	for m in re.search_all(rest):
		var k := m.get_string(1)
		var before := rest.substr(maxi(m.get_start() - 1, 0), 1)
		var after := rest.substr(m.get_end(), 1)
		# a lone capital letter is only a key when it sits in brackets, after "hold", or ends the line after a colon
		var lone := k.length() == 1
		var lead := rest.substr(0, m.get_start())
		var keyish := not lone or (before == "(" and after == ")") or ((lead == "" or lead.ends_with("  ")) and (after == "" or after == " ")) or rest.substr(0, m.get_start()).ends_with(":  ") \
				or rest.substr(0, m.get_start()).ends_with("hold ") or rest.substr(0, m.get_start()).ends_with("segure ") \
				or (after == "." and rest.substr(0, m.get_start()).ends_with(": "))
		out_s += rest.substr(at, m.get_start() - at)
		var name := t(str(TOUCH_KEYS[k])) if keyish else k
		if k == "Shift" and keyish:
			name = t("a gentle push of the stick")
		out_s += name
		at = m.get_end()
	out_s += rest.substr(at)
	return head + out_s


## A screen taller than 16:9 (a foldable opened, a tablet) keeps the picture at full width at the top and opens
## a strip under it for the touch controls; a wider one keeps the picture whole with bars at its sides.
func _fit_screen() -> void:
	var root := get_tree().root
	var ws := Vector2(DisplayServer.window_get_size())
	if ws.y <= 0.0:
		return
	# the game is only ever played lying on its side: a phone may still report its screen the upright way round
	# (before it has turned, or for good), which would read as a tall screen and open a strip under the picture.
	# The long side against the short side is the shape the picture is shown at.
	var aspect := maxf(ws.x, ws.y) / maxf(minf(ws.x, ws.y), 1.0)
	if aspect < 1.7 and not OS.get_model_name().begins_with("iPhone"):      # a phone is never that shape: the controls lie over the picture
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		deck = 1280.0 / aspect - 720.0
	else:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		deck = 0.0


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
	_bind("lyre", [KEY_R, KEY_U], [], [JOY_AXIS_TRIGGER_RIGHT, 1.0])
	_bind("growth", [KEY_TAB], [JOY_BUTTON_BACK])
	_bind("map", [KEY_M], [JOY_BUTTON_RIGHT_STICK])
	_bind("accept", [KEY_ENTER, KEY_SPACE, KEY_Z, KEY_J], [JOY_BUTTON_A])
	_bind("back", [KEY_BACKSPACE], [JOY_BUTTON_B])      # in the menus and the map only


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
	for c in chapters.size():
		for sec in chapters[c].get("sections", []):
			_sections.append(sec)
			_chapter_at.append(c)
	_ui_pt = _read_json("res://data/ui.pt.json")
	var places: Dictionary = _read_json("res://data/map.json").get("places", {})
	for k in places:
		stones_total += (places[k].get("stones", []) as Array).size()
		places_total += (places[k].get("finds", []) as Array).size()


## Every section there is to play, chapter after chapter. A section's place in this list is the number the save
## keeps ("section", "unlocked"), so Chapter One's sections keep the numbers they have always had and a later
## chapter's simply follow them.
func sections() -> Array:
	return _sections


## Which chapter (0 for Chapter One) the section at this place in the list belongs to.
func chapter_of(idx: int) -> int:
	if _chapter_at.is_empty():
		return 0
	return int(_chapter_at[clampi(idx, 0, _chapter_at.size() - 1)])


## Where a chapter's first section stands in the list (the length of the list for a chapter with none yet).
func chapter_start(ch: int) -> int:
	for i in _chapter_at.size():
		if int(_chapter_at[i]) >= ch:
			return i
	return _chapter_at.size()


func chapter_sections(ch: int) -> Array:
	if ch < 0 or ch >= chapters.size():
		return []
	return chapters[ch].get("sections", [])


## A section can be shown only when every picture it is made of has been painted: its "needs" in chapters.json
## are files, or sets of frames written "frames:who/set". Until then no player is let into it, so that nothing
## unpainted and no stand-in is ever seen. The automated tests go in regardless.
func section_ready(idx: int) -> bool:
	if idx < 0 or idx >= _sections.size():
		return false
	return fast or force_ready or section_lacks(idx).is_empty()


## What a section still waits for, of the pictures it needs.
func section_lacks(idx: int) -> Array:
	var out: Array = []
	if idx < 0 or idx >= _sections.size():
		return out
	for need in _sections[idx].get("needs", []):
		if _lacks(str(need)):
			out.append(str(need))
	return out


## A need is a frame set ("frames:who/name") or a file ("res://..."): true while it is not there.
func _lacks(n: String) -> bool:
	if n.begins_with("frames:"):
		var parts := n.trim_prefix("frames:").split("/")
		return parts.size() != 2 or FA._paths(parts[0], parts[1]).is_empty()
	return not ResourceLoader.exists(n)


## The night played before a section, once, when there is one ("then" in chapters.json: its own script, title,
## aim, why, needs and the save key that marks it done). Chapter One's lambing night comes before the Pastures,
## weeks before that evening, so that the lamb in the flock is one he brought into the world. It has no number of
## its own in the list: the save's section numbers stay as they have always been.
func interlude(idx: int) -> Dictionary:
	if idx < 0 or idx >= _sections.size():
		return {}
	return _sections[idx].get("then", {})


func interlude_lacks(idx: int) -> Array:
	var out: Array = []
	for need in interlude(idx).get("needs", []):
		if _lacks(str(need)):
			out.append(str(need))
	return out


func interlude_ready(idx: int) -> bool:
	return not interlude(idx).is_empty() and (fast or force_ready or interlude_lacks(idx).is_empty())


## Walking into this section from its beginning, does its night come first?
func interlude_due(idx: int) -> bool:
	return interlude_ready(idx) and not bool(save.get(str(interlude(idx).get("done", "")), false))


## He has come far enough to walk into this section, and it is there to walk into.
func section_open(idx: int) -> bool:
	return idx >= 0 and idx < _sections.size() and idx <= int(save.get("unlocked", 0)) and section_ready(idx)


func chapter_open(ch: int) -> bool:
	return not chapter_sections(ch).is_empty() and section_open(chapter_start(ch))


func default_save() -> Dictionary:
	return {"section": 0, "checkpoint": 0, "has_sling": false, "unlocked": 0, "started": false, "finished": false, "difficulty": 1, "v": 2,
			"growth": {}, "stones": [], "gifts": [], "psalm": [], "flock": [], "lamb_born": false, "interlude": false}


func load_game() -> void:
	var on_disk := _read_json(SAVE_PATH)
	if on_disk.is_empty():      # no journey, or one cut short while it was being written: the copy kept from the time before
		on_disk = _read_json(SAVE_PATH + ".bak")
	take_save(on_disk)
	apply_settings()
	_gc_sign_in()


## Makes a journey read from disk the one being played. Whatever it holds is kept; whatever a newer game needs
## and an older file lacks (gifts, the pouch, the psalm, his nine sheep, the lyre) is added beside it.
func take_save(on_disk: Dictionary) -> void:
	save = default_save()
	save.merge(on_disk, true)
	# a file from an older game, or one touched by hand, may hold the wrong kind of thing under a name
	var fresh := default_save()
	for k in fresh:
		if typeof(save[k]) != typeof(fresh[k]) and not (save[k] is float and fresh[k] is int):
			save[k] = fresh[k]
	if not on_disk.is_empty() and not on_disk.has("gifts"):
		# a journey begun before gifts were given at set places: he keeps what he had earned
		save["gifts"] = []
		gifts_for(int(save.get("section", 0)))
		if save.get("has_sling", false):
			give("sling", true)
		for pair in [["voice", 1], ["feet", 2], ["eye", 2], ["heart", 1]]:
			if rank(pair[0]) >= int(pair[1]):
				give(pair[0], true)
	if not on_disk.is_empty() and not on_disk.has("lamb_born"):
		# a journey begun before the lambing night was played: Shai has been with the flock all along
		save["lamb_born"] = int(save.get("unlocked", 0)) > 0 or bool(save.get("finished", false)) or int(save.get("section", 0)) > 0
	if not on_disk.has("pouch"):      # a journey begun before the pouch: it starts full
		fill_pouch()
	if not on_disk.is_empty() and not on_disk.has("psalm"):
		# a journey begun before the psalm was gathered line by line: he has the lines of the places he has been through
		lines_for(99 if save.get("finished", false) else int(save.get("section", 0)))
	_from_the_start()
	save["section"] = clampi(int(save["section"]), 0, maxi(0, sections().size() - 1))
	save["checkpoint"] = maxi(0, int(save["checkpoint"]))
	save["unlocked"] = maxi(0, int(save["unlocked"]))
	save["difficulty"] = clampi(int(save["difficulty"]), 0, DIFFICULTY.size() - 1)
	# A journey saved when there was one chapter: "unlocked" counted only Chapter One's sections, and a finished
	# chapter was written as 99. Now the count runs on through the chapters, so it is brought back inside Chapter One.
	var first := chapter_sections(0).size()
	if not on_disk.is_empty() and int(on_disk.get("v", 1)) < 2:
		save["unlocked"] = mini(save["unlocked"], maxi(0, first - 1))
	save["v"] = 2
	if save.get("finished", false):      # whoever has finished Chapter One may walk into any part of it, sections added since included, and on into Chapter Two
		save["unlocked"] = maxi(save["unlocked"], first)
	save["unlocked"] = mini(save["unlocked"], sections().size())


## How loud the whole game is, as the player set it (1.0 when never set).
func volume() -> float:
	return clampf(float(save.get("volume", 1.0)), 0.0, 1.0)


func apply_settings() -> void:
	apply_pad()
	if touch_mode() == "off" and touch:      # no buttons on the screen: prompts name the controller's, or the keys
		touch = false
		pad = not Input.get_connected_joypads().is_empty()
	var v := volume()
	AudioServer.set_bus_mute(0, v <= 0.01)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.01)))


## A short tap in the hand on a phone, when a blow lands or he is hurt. Nothing on a computer.
func buzz(ms: int = 18) -> void:
	if touch and not fast and save.get("haptics", true):
		Input.vibrate_handheld(ms)


signal save_failed(reason: String)
var save_error := ""          # why the last save did not reach the disk; "" when it did
var save_path := SAVE_PATH    # the automated tests point this at a file of their own


## Writes the journey to disk. False (and `save_failed`) when it could not be written: the file there before is
## left as it was, and the player is told, with the chance to try again.
func save_game() -> bool:
	if fast:
		return true
	check_deeds()
	save_error = write_save(save_path, save)
	if save_error != "":
		push_warning("The journey could not be saved: " + save_error)
		save_failed.emit(save_error)
	return save_error == ""


## Written beside the file and then put in its place, so being closed mid-write cannot leave half a file. The
## file as it stood before is first kept as a second copy (.bak); if that copy cannot be made the file is not
## replaced. Returns "" when the journey is on disk, or the step that failed.
func write_save(path: String, data: Dictionary) -> String:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "write: " + error_string(FileAccess.get_open_error())
	var wrote := f.store_string(JSON.stringify(data))
	f.close()
	if not wrote or _read_json(tmp).is_empty():
		return "write: the new copy does not read back"
	if not _read_json(path).is_empty():
		var e := DirAccess.copy_absolute(path, path + ".bak")
		if e != OK:
			return "backup: " + error_string(e)
	var e2 := DirAccess.rename_absolute(tmp, path)
	if e2 != OK:
		return "replace: " + error_string(e2)
	return ""


## What a new journey keeps of the old one: how the game is set up to be played, not anything he has done.
const PREFS := ["lang", "difficulty", "volume", "film_subs", "haptics", "touch_ctl", "pad_style", "pad_map", "dead_zone",
		"deeds_told"]

func new_game() -> void:
	var unlocked: int = save.get("unlocked", 0)
	var finished: bool = save.get("finished", false)
	var keep := {}
	for k in PREFS:
		if save.has(k):
			keep[k] = save[k].duplicate(true) if (save[k] is Dictionary or save[k] is Array) else save[k]
	save = default_save()      # a new journey: his crafts begin again
	save.merge(keep, true)
	save["unlocked"] = unlocked
	save["finished"] = finished
	save["started"] = true
	_from_the_start()
	apply_settings()
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
	"hand": {"name": "The Strong Hand", "line": "Blow follows blow. Hold the staff back and let go, and it goes right round him. Struck from a leap, it comes down on them.", "key": "J  J  J  chain the blows", "craft": "hand", "why": "His staff is all there is between the flock and what hunts it.", "how": "At the Well: move the stone, and hold the water.", "after": 1},
	"sling": {"name": "The Sling", "line": "A stone, whirled and let fly.", "key": "K  hold, then release", "craft": "eye", "why": "It reaches what the staff cannot.", "how": "In the ravine: drive the pack from the brook.", "after": 2},
	"eye": {"name": "The Sure Eye", "line": "He sees the whole flight of the stone before he lets it go.", "key": "↑ ↓  aim as he winds", "craft": "eye", "why": "A stone that misses is a stone wasted, and the beast is already moving.", "how": "In the Wadi: break the three jars, and bring every boulder down.", "after": 3},
	"heart": {"name": "The Steady Heart", "line": "One more heart.", "key": "", "craft": "heart", "why": "He stood where he could have run. That is kept.", "how": "In the Bear's Den: drive off the bear.", "after": 4},
	"feet": {"name": "The Swift Feet", "line": "The running leap: jump at a full run to go higher and farther.", "key": "Run, then Space", "craft": "feet", "why": "A lamb in a lion's mouth is lost in the time it takes to walk.", "how": "On the Ridge: reach the light at a run.", "after": 5},
	"lyre": {"name": "The Lyre", "line": "Hold, and let each phrase go at the top of the breath. Three phrases settle the sheep that hear them.", "key": "R  hold, release at the top", "craft": "voice", "why": "A frightened flock cannot be driven quiet. It can be played quiet.", "how": "From his father's house.", "after": -1},
	"walksong": {"name": "The Walking Song", "line": "He plays on his feet. Begin while walking and he keeps walking; what follows him keeps following, quieted, for as long as the phrases land.", "key": "R  while walking", "craft": "voice", "why": "A flock can be left standing while it is played quiet. A beast on a road cannot: it has to be brought along.", "how": "At his father's house: bring the nine past the king's mules to the keeper.", "after": 8, "chapter": 1, "emblem": "lyre"},
	"steady": {"name": "The Steady Hand", "line": "His playing holds through a fright: what shakes the breath shakes it less.", "key": "", "craft": "voice", "why": "A hand that only plays in quiet is no use to a frightened beast, or to a troubled man.", "how": "On the Ridge Road: bring the loaded donkey through the wolves.", "after": 9, "chapter": 1, "emblem": "lyre"},
	# "after" is Chapter Two's fourth section (Game.chapter_start(1) + 3). The proposal gives this gift two things: the journal gains
	# the court (built: its third page), and doors in the fortress open to him (not built: there are no such doors yet, and the gift says so).
	"favour": {"name": "The King's Favour", "line": "The king has asked that he stay. The journal gains a page: the court at Gibeah, and those he has met there. The inner doors of the fortress will open to him when they are built; there are none yet.", "key": "Tab  the journal, then ← →", "craft": "voice", "why": "A boy sent for once is a visitor. One the king asks to keep belongs to the house.", "how": "In the king's hall: play until the shadow on the wall is down.", "after": 11, "chapter": 1, "emblem": "lyre"},
	# "after" is Chapter Two's fifth section (Game.chapter_start(1) + 4). The shield is the king's: `player.shield` is set by a level
	# that puts it on his arm, and without it this gift does nothing. He never wears armour (1 Samuel 17:39).
	"shieldarm": {"name": "The Shield Arm", "line": "With the king's shield on his arm he can raise it, and a blow from the front that lands on it does no harm. It comes up for the blow and cannot be held up long. The shield is the king's and never his: where he does not bear it, there is nothing to raise.", "key": "J  hold, while he bears the king's shield", "craft": "hand", "why": "An armour-bearer stands between his lord and the blow. He is not there to strike.", "how": "In the yard at Gibeah: stand through the shield-man's drill.", "after": 12, "chapter": 1},
	# "after" is Chapter Two's sixth section (Game.chapter_start(1) + 5). What it does is one number, song_hold(): the quiet his
	# playing leaves lasts that many times longer, wherever a quiet is counted down (sheep, the donkey, a man played to).
	"nightsong": {"name": "The Night Song", "line": "The quiet his playing leaves holds longer after he stops: half as long again and more, for sheep, for a beast on the road, and for a man who has been played to.", "key": "", "craft": "voice", "why": "A song that only holds while it is played is no use to a man who must sleep, or to a flock that must be left.", "how": "In the king's hall at night: play through every wave, and keep the lamps burning.", "after": 13, "chapter": 1, "emblem": "lyre"},
}
const GIFT_ORDER := ["lyre", "voice", "hand", "sling", "eye", "heart", "feet", "walksong", "steady", "favour", "shieldarm", "nightsong"]

const CRAFTS := {
	"feet": {"name": "Swift Feet", "by": "ground covered", "marks": [120, 420, 1500], "gift": "feet", "gifts": [
		"He runs a little faster.",
		"He runs faster.",
		"Faster still, and he is ready to dodge again sooner."]},
	"hand": {"name": "Strong Hand", "by": "blows landed with the staff", "marks": [14, 110, 380], "gift": "hand", "gifts": [
		"The staff reaches farther and strikes harder: three blows drive off a jackal, not five.",
		"Harder again: two blows drive off a jackal. The rising blow throws a beast back.",
		"The low sweep lands harder, and blows chain more easily."]},
	"eye": {"name": "Sure Eye", "by": "stones that find their mark", "marks": [6, 30, 90], "gift": "sling", "gifts": [
		"The sling comes up to speed sooner.",
		"A full-wound stone flies faster, and every stone strikes harder.",
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


## How hard one blow lands on a lesser beast (a jackal has 6). It grows with him: the staff with the Strong Hand,
## the sling with hand and eye both, and a stone always tells more than the staff does.
##   staff, hand 0-3:  1, 2, 3, 3 a blow (the third of a chain one more)  ->  5, 3, 2, 2 blows to drive a jackal off
##   stone, loosed quick:  one more than the staff.   Full-wound: twice that, and more again with the Sure Eye
func blow(kind: String, full: bool = false) -> int:
	var staff: int = [1, 2, 3, 3][clampi(rank("hand"), 0, 3)]
	if kind == "staff":
		return staff
	var quick := staff + 1 + (1 if rank("eye") >= 2 else 0)
	return quick * 2 + (2 if rank("eye") >= 3 else 0) if full else quick


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


## How far the lyre is heard.
func song_reach() -> float:
	return 420.0 + 50.0 * rank("voice")


## The Night Song: how many times longer the quiet his playing leaves lasts after he stops.
func song_hold() -> float:
	return 1.6 if has("nightsong") else 1.0


## A gift is given: once, and for good.
const FAVOUR_SETS := ["bear", "bear_idle", "block"]

func give(id: String, quiet: bool = false) -> void:
	if has(id) or not GIFTS.has(id):
		return
	var list: Array = save.get("gifts", [])
	list.append(id)
	save["gifts"] = list
	if id == "favour":      # the shield is borne from now on: its pictures are read before he first lifts it
		FA.warm("david", FAVOUR_SETS)
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
	lines_for(section_idx)


# ------------------------------------------------------------- the psalm, and his own nine
## Psalm 23 comes to him a line at a time, each at the place that taught it. The lines are kept in the order of
## the psalm; `after` is the section that gives each one (99: only when the whole psalm is played, at the end).
signal line_found(id: String)

const PSALM := [
	{"id": "p23_shepherd", "after": 0}, {"id": "p23_pastures", "after": 0}, {"id": "p23_waters", "after": 1},
	{"id": "p23_soul", "after": 5}, {"id": "p23_paths", "after": 99}, {"id": "p23_valley", "after": 4},
	{"id": "p23_rod", "after": 5}, {"id": "p23_table", "after": 6}, {"id": "p23_oil", "after": 7},
	{"id": "p23_goodness", "after": 99},
]


func psalm() -> Array:
	return save.get("psalm", [])


func has_line(id: String) -> bool:
	return id in psalm()


## A line of the psalm, come to him for the first time.
func find_line(id: String, quiet: bool = false) -> void:
	var list: Array = psalm()
	if id in list or not PSALM.any(func(e): return e["id"] == id):
		return
	list.append(id)
	save["psalm"] = list
	if not quiet:
		save_game()
		line_found.emit(id)


## A line of the psalm spoken aloud, in the player's language, over the music (audio/narration[/pt]/<id>.mp3).
## Returns how long it takes, or 0 when there is no recording (or nothing is to be heard).
var _voice: AudioStreamPlayer

func voice_line(id: String) -> float:
	if fast or backdrop or _voice == null:
		return 0.0
	var path := "res://audio/narration/%s.mp3" % id
	if lang() != "en" and ResourceLoader.exists("res://audio/narration/%s/%s.mp3" % [lang(), id]):
		path = "res://audio/narration/%s/%s.mp3" % [lang(), id]
	if not ResourceLoader.exists(path):
		return 0.0
	var stream: AudioStream = load(path)
	_voice.stream = stream
	_voice.play()
	duck(true)
	return stream.get_length()


## Seconds still to run of the line being spoken (0: none).
func voice_left() -> float:
	if _voice == null or not _voice.playing or _voice.stream == null:
		return 0.0
	return maxf(0.0, _voice.stream.get_length() - _voice.get_playback_position())


## Whoever walks into a later section has the lines the earlier ones would have given him.
func lines_for(section_idx: int) -> void:
	for e in PSALM:
		if int(e["after"]) < section_idx:
			find_line(str(e["id"]), true)


## The whole psalm: every line that was still missing, in the psalm's order. Returns the ones that were new.
func psalm_whole() -> Array:
	var fresh: Array = []
	for e in PSALM:
		if not has_line(str(e["id"])):
			fresh.append(str(e["id"]))
			find_line(str(e["id"]), true)
	save_game()
	return fresh


## His father's flock: eight ewes and this year's lamb, the same nine in every section. Each has its own look
## (`wool` multiplies the section's wool colour, `size` its height; `mark` is kept clear, because at the Well a
## daubed rump is how another man's sheep is told from his), four answer to a name, and `at` says where it is: "" with him, the name of a section it is still out in, or "taken".
const FLOCK := [
	{"id": "lamb", "name": "Shai", "wool": [1.0, 1.0, 1.0], "size": 0.68, "mark": [0, 0, 0, 0]},
	{"id": "rachel", "name": "Rachel", "wool": [0.93, 0.9, 0.85], "size": 1.08, "mark": [0, 0, 0, 0]},
	{"id": "devorah", "name": "Devorah", "wool": [1.0, 0.97, 0.9], "size": 0.94, "mark": [0, 0, 0, 0]},
	{"id": "noga", "name": "Noga", "wool": [1.08, 1.08, 1.1], "size": 1.0, "mark": [0, 0, 0, 0]},
	{"id": "ewe4", "name": "", "wool": [0.9, 0.86, 0.8], "size": 1.03, "mark": [0, 0, 0, 0]},
	{"id": "ewe5", "name": "", "wool": [1.0, 1.0, 1.0], "size": 0.97, "mark": [0, 0, 0, 0]},
	{"id": "ewe6", "name": "", "wool": [0.97, 0.93, 0.86], "size": 1.05, "mark": [0, 0, 0, 0]},
	{"id": "ewe7", "name": "", "wool": [0.86, 0.84, 0.82], "size": 0.92, "mark": [0, 0, 0, 0]},
	{"id": "ewe8", "name": "", "wool": [1.03, 1.0, 0.94], "size": 1.0, "mark": [0, 0, 0, 0]},
]


func flock() -> Array:
	var list = save.get("flock", [])
	if not (list is Array) or list.size() != FLOCK.size() or not list.all(func(e): return e is Dictionary and e.has("id")):
		list = []
		for e in FLOCK:
			var one: Dictionary = e.duplicate(true)
			one["at"] = ""
			list.append(one)
		save["flock"] = list
	return list


func flock_one(id: String) -> Dictionary:
	for e in flock():
		if str(e["id"]) == id:
			return e
	return {}


## Where one of the nine is now: "" with him, a section's name, or "taken".
func flock_at(id: String, where: String) -> void:
	var e := flock_one(id)
	if not e.is_empty():
		e["at"] = where


## What every journey has from its first step, old or new: the lyre from his father's house, and his nine.
func _from_the_start() -> void:
	give("lyre", true)
	flock()


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
	if all_stones():
		_tell("Every smooth stone in these hills is his.  From the pouch they strike harder still")


## Every smooth stone in the hills found: the pouch's stones strike harder still.
func all_stones() -> bool:
	return stones_total > 0 and stones().size() >= stones_total


## Deeds: what he has done in these hills, counted from how far he has come, so the count is right in any saved
## game. Each is told once to the phone's own record of achievements, where there is one (Game Center).
const DEEDS := ["gift_voice", "gift_hand", "gift_sling", "gift_eye", "gift_heart", "gift_feet",
	"bear", "lion", "stones", "places", "chapter1"]


func _past(script_name: String) -> bool:
	for i in sections().size():
		if str(sections()[i]["script"]).get_file().get_basename() == script_name:
			return int(save.get("unlocked", 0)) > i or (chapter_of(i) == 0 and save.get("finished", false))
	return false


func deed_done(id: String) -> bool:
	if id.begins_with("gift_"):
		return has(id.trim_prefix("gift_"))
	match id:
		"bear": return _past("den")
		"lion": return _past("section3")
		"stones": return all_stones()
		"places": return all_places()
		"chapter1": return bool(save.get("finished", false))
	return false


func deeds_done() -> int:
	var n := 0
	for id in DEEDS:
		if deed_done(id):
			n += 1
	return n


## Tells the record of achievements each deed done and not yet taken in by it. A deed is earned when it is done
## (deed_done); it is only marked told ("deeds_told") once Game Center answers that it has it. Until then it is
## sent again: when the player signs in, and when the game comes back to the front (the network may be back).
## Safe to call at any time, and as often as wanted.
var gc_override: Object = null      # the automated tests stand a pretend Game Center in here
var _gc_signed_in := false
var _deeds_sent: Array = []        # sent and not yet answered, in the order sent

func _gc() -> Object:
	if gc_override != null:
		return gc_override
	return Engine.get_singleton("GameCenter") if Engine.has_singleton("GameCenter") else null


func deeds_pending() -> Array:
	var told: Array = save.get("deeds_told", [])
	return DEEDS.filter(func(id): return deed_done(id) and not id in told)


func check_deeds() -> void:
	var gc := _gc()
	if gc == null or not _gc_signed_in:
		return
	for id in deeds_pending():
		if id in _deeds_sent:
			continue
		if gc.award_achievement({"name": "david." + id, "progress": 100.0, "show_completion_banner": true}) == OK:
			_deeds_sent.append(id)


## Game Center's answers: sign-in, and each achievement taken in or refused.
func _gc_events() -> void:
	var gc := _gc()
	if gc == null:
		return
	while gc.get_pending_event_count() > 0:
		var ev: Dictionary = gc.pop_pending_event()
		match str(ev.get("type", "")):
			"authentication":
				_gc_signed_in = str(ev.get("result", "")) == "ok"
				_deeds_sent.clear()
				check_deeds()
			"award_achievement":
				var id := str(ev.get("name", "")).trim_prefix("david.")
				if not id in _deeds_sent:
					id = "" if _deeds_sent.is_empty() else str(_deeds_sent[0])      # answers that do not say which: the oldest sent
				_deeds_sent.erase(id)
				if str(ev.get("result", "")) == "ok" and id != "":
					var told: Array = save.get("deeds_told", [])
					if not id in told:
						told.append(id)
					save["deeds_told"] = told
					save_game()


func _gc_sign_in() -> void:
	var gc := _gc()
	if gc != null:
		gc.authenticate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_deeds_sent.clear()      # whatever was in flight when the game went to the back is sent again
		if _gc() != null and not _gc_signed_in:
			_gc_sign_in()
		else:
			check_deeds()


## Hearts are earned. He begins with few, and each time he brings the flock through something, one more is his
## to keep: counted from how far he has come, so it is right in any saved game.
const HEART_DEEDS := {
	"well": "The flock watered and counted in.  One more heart",
	"section3": "The lamb brought down from the lion.  One more heart",
	"watch": "The night kept, and not one lost.  One more heart",
}
var heart_news := ""      # a heart just earned, told at the start of what comes next


func earned_hearts() -> int:
	var n := 0
	var reached := int(save.get("unlocked", 0))
	for i in sections().size():
		if (i < reached or (chapter_of(i) == 0 and save.get("finished", false))) and HEART_DEEDS.has(str(sections()[i]["script"]).get_file().get_basename()):
			n += 1
	return n


## Every place off the path found: he knows these hills as no one else does, and it steadies him (one more heart).
func all_places() -> bool:
	return places_total > 0 and places().size() >= places_total


func _tell(text: String) -> void:
	if is_instance_valid(main) and is_instance_valid(main.level):
		main.level.show_tip(text, 8.0)


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
	if all_places():
		grew.emit("heart", rank("heart"))      # the hearts are counted again
		_tell("He knows every corner of these hills now.  It steadies him: one more heart")


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
	buzz(18)
	hold_time(0.05, seconds)


## Slows the world for a while. Holds may overlap (a blow's hitstop inside a beast's slow motion): the world runs
## at the slowest of those still running, and at full speed only once the last has ended.
var _time_holds := {}
var _time_next := 0

func hold_time(scale: float, seconds: float) -> void:
	_time_next += 1
	var id := _time_next
	_time_holds[id] = scale
	Engine.time_scale = _time_holds.values().min()
	await get_tree().create_timer(seconds, true, false, true).timeout
	_time_holds.erase(id)
	Engine.time_scale = 1.0 if _time_holds.is_empty() else _time_holds.values().min()


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
	fade(old_p, -60.0, seconds, true)
	var path := "res://audio/music/%s.mp3" % mood
	if mood == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = true
	new_p.stream = stream
	new_p.volume_db = -60.0
	new_p.play()
	fade(new_p, DUCK_DB if _duck else MUSIC_DB, seconds)      # also ends the fade (and stop) it had for the mood before last


## The one volume fade a player has (music, ambience). Starting another ends it, and the stop it would have made
## at its end: a player taken up again for another track is never stopped by a fade from before.
var _fades := {}

func fade(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool = false) -> Tween:
	var old: Tween = _fades.get(p)
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, maxf(seconds, 0.001))
	if stop_after:
		tw.tween_callback(p.stop)
	_fades[p] = tw
	return tw


## Lower the music under the narrator's voice.
func duck(on: bool) -> void:
	_duck = on
	var p: AudioStreamPlayer = _players[_active]
	if p.playing:
		fade(p, DUCK_DB if on else MUSIC_DB, 0.6)


const DIFFICULTY := [
	{"name": "Gentle", "about": "More hearts. Animals are weaker and give longer warnings.", "hearts": 5, "enemy_hp": 0.7, "warning": 1.35},
	{"name": "Shepherd", "about": "The intended challenge.", "hearts": 3, "enemy_hp": 1.0, "warning": 1.0},
	{"name": "Warrior", "about": "Fewer hearts. Animals are tougher and strike with little warning.", "hearts": 2, "enemy_hp": 1.4, "warning": 0.75},
]


func diff() -> Dictionary:
	return DIFFICULTY[clampi(int(save.get("difficulty", 1)), 0, 2)]


## Brief slow motion, for the moment a great beast is driven off.
func slowmo(scale: float = 0.3, seconds: float = 0.9) -> void:
	if fast:
		return
	hold_time(scale, seconds)


## Plays a sound effect from audio/sfx. Pitch varies a little each time so
## repeated sounds (steps, hits) never sound mechanical.
func sfx(sound: String, volume_db: float = 0.0, pitch_vary: float = 0.07, pitch: float = 1.0) -> void:
	if fast:
		return
	var path := "res://audio/sfx/%s.mp3" % sound
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = load(path)
	p.volume_db = volume_db - 5.0
	p.pitch_scale = pitch + randf_range(-pitch_vary, pitch_vary)
	p.play()


## The lyre's own sounds, from audio/sfx/lyre_*.mp3 once they are recorded:
## "sit" he takes it up; "phrase" a phrase lands (`n` = which part: n % 3 is the part of the tune, n / 3 the verse);
## "lost" a phrase let go too soon; "song" the closing chord of a song that ends; "verse" the same chord, softer,
## closing a verse he plays on from.
## The tune is in D, from the recorded phrases (pitches measured): the opening rises A to E, the middle D to E and
## stays open, the close falls G to D and comes home; the chord is a low D. Middle and close have two takes each,
## which change with the verse.
const LYRE_TUNE := [["lyre_phrase_00"], ["lyre_phrase_05", "lyre_phrase_10"], ["lyre_phrase_03", "lyre_phrase_08"]]

func lyre(kind: String, n: int = 0) -> void:
	if fast:
		return
	match kind:
		"phrase":
			var takes: Array = LYRE_TUNE[n % 3]
			var take: String = takes[(n / 3) % takes.size()]
			if ResourceLoader.exists("res://audio/sfx/%s.mp3" % take):
				sfx(take, -2.0, 0.0)
			else:
				sfx("gather", -4.0, 0.0, [1.0, 1.122, 1.335][n % 3])      # stand-in: three rising notes
		"song", "verse":
			if ResourceLoader.exists("res://audio/sfx/lyre_song.mp3"):
				sfx("lyre_song", -4.0 if kind == "song" else -9.0, 0.0)
			else:
				sfx("anoint", -12.0, 0.0)
		"lost":
			if ResourceLoader.exists("res://audio/sfx/lyre_lost.mp3"):
				sfx("lyre_lost", -6.0, 0.03)
			else:
				sfx("ui_move", -9.0, 0.0, 0.7)
		"sit":
			sfx("lyre_sit", -6.0, 0.03)      # nothing until it is recorded


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
		if kind == "" or not ResourceLoader.exists(path):
			fade(bed, -60.0, 1.5, true)      # faded out and stopped, not left playing unheard
			continue
		var stream: AudioStream = load(path).duplicate()
		stream.resource_name = kind      # the copy has no path of its own: this says which place's bed it is
		if stream is AudioStreamMP3:
			stream.loop = true
		# the old bed fades out first, then the new one is put in and fades up: never both on one player at once
		var tw := fade(bed, -60.0, 1.2 if bed.playing else 0.0)
		var pitch: float = [0.82, 1.0][i]      # two copies out of step with each other hide the loop
		tw.tween_callback(func() -> void:
			bed.stream = stream
			bed.pitch_scale = pitch
			bed.volume_db = -60.0
			bed.play())
		tw.tween_property(bed, "volume_db", -25.0 - i * 2.0, 2.5)


func _process(delta: float) -> void:
	FA.pump()
	_gc_events()
	if _ambience == "" or get_tree().paused:
		return
	_next_event -= delta
	if _next_event <= 0.0:
		_next_event = randf_range(2.5, 8.0)
		var events: Array = AMBIENT_EVENTS.get(_ambience, [])
		if not events.is_empty():
			var e: Array = events[randi() % events.size()]
			sfx(e[0], e[1] + (9.0 if _duck else 0.0) * -1.0, 0.12)
