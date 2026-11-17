extends Control
## On-screen controls for a phone or tablet. A stick on the left half of the screen (it appears where the thumb
## lands) and buttons on the right. Every touch is turned into the same input actions the keyboard and the
## controller send, so the game, the menus and the map need nothing of their own to be played by touch.
## Shown once the screen is touched, hidden again when a key or a controller is used.

const STICK_R := 70.0        # how far the knob travels from where the thumb landed
const DEAD := 0.28           # a tilt smaller than this is no tilt
const WALK := 0.62           # a tilt smaller than this (and past DEAD) walks instead of running
const VERT := 0.6            # how far up or down before the stick also means up or down

# name, label, centre, radius, actions it holds down. The first ones are the main buttons under the right thumb.
var buttons: Array = [
	# the thumb buttons in a cluster in the corner, all in reach of the right thumb, big enough not to be missed
	{"id": "jump", "label": "Jump", "pos": Vector2(1196, 642), "r": 64.0, "acts": ["jump", "accept"]},
	{"id": "attack", "label": "Staff", "pos": Vector2(1066, 650), "r": 54.0, "acts": ["attack"]},
	{"id": "sling", "label": "Sling", "pos": Vector2(1206, 512), "r": 50.0, "acts": ["sling"]},
	{"id": "roll", "label": "Dodge", "pos": Vector2(1084, 530), "r": 48.0, "acts": ["roll"]},
	{"id": "grab", "label": "Grab", "pos": Vector2(944, 660), "r": 44.0, "acts": ["grab"]},
	{"id": "call", "label": "Call", "pos": Vector2(962, 546), "r": 42.0, "acts": ["call"]},
	{"id": "lyre", "label": "Lyre", "pos": Vector2(1118, 424), "r": 40.0, "acts": ["lyre"]},
	{"id": "growth", "label": "Growth", "pos": Vector2(1040, 132), "r": 30.0, "acts": ["growth"]},
	{"id": "map", "label": "Map", "pos": Vector2(1124, 132), "r": 30.0, "acts": ["map"]},
	{"id": "pause", "label": "II", "pos": Vector2(1208, 132), "r": 30.0, "acts": ["pause"]},
]

var OVER := {}                    # where each button sits on a 16:9 screen, filled from `buttons` at the start
const TOP := ["growth", "map", "pause"]      # these keep to the top of the screen, the rest to its bottom

var _stick_touch := -1            # which finger holds the stick
var _stick_from := Vector2.ZERO
var _stick_at := Vector2.ZERO
var _held_by: Dictionary = {}      # finger -> button id
var _down: Dictionary = {}         # action -> true while this layer holds it down


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = Game.touch
	for b in buttons:
		OVER[b["id"]] = [b["pos"], b["r"]]
	_place()


var _placed_for := -1.0

## Where the buttons go: over the picture, the thumb buttons held to the bottom corner of the screen. On a screen
## taller than 16:9 (a foldable opened) the picture runs on below the ground, and the buttons go down with the
## bottom edge, over the earth under his feet rather than over the ground and the flock.
func _place() -> void:
	_placed_for = Game.deck
	for b in buttons:
		var id: String = b["id"]
		b["pos"] = OVER[id][0] + (Vector2.ZERO if id in TOP else Vector2(0, Game.deck))
		b["r"] = OVER[id][1]


func _process(_delta: float) -> void:
	if _placed_for != Game.deck:
		_place()
	if visible != Game.touch:
		visible = Game.touch
		if not visible:
			_release_all()
	if visible:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not Game.touch:
			Game.touch = true
			Game.pad = false
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _stick_touch:
			_stick_at = event.position
			_update_stick()
		get_viewport().set_input_as_handled()


## A menu or the map is up: it is played by tapping it, so the buttons for playing step aside.
func _ui_open() -> bool:
	var m = Game.main
	return m != null and ((m.menu != null and m.menu.visible) or (m.map != null and m.map.visible))


func _shown(b: Dictionary) -> bool:
	if _ui_open() and not b["id"] in TOP:
		return false
	var m = Game.main
	if m != null and m.menu != null and m.menu.visible:      # in the menus only II is any use: it goes back
		return b["id"] == "pause" and m.menu.mode != "main"
	if b["id"] == "call":
		return Game.has("voice")
	if b["id"] == "lyre":
		return Game.has("lyre")
	return true


func _touch_down(finger: int, p: Vector2) -> void:
	# Each button owns the ground nearest to it, measured against its size, out to almost twice its radius:
	# a thumb that lands between two buttons or just off one still gets the one it was reaching for.
	var best := ""
	var best_d := INF
	for b in buttons:
		if not _shown(b):
			continue
		var reach := 1.35 if b["id"] in TOP else 1.9
		var d: float = p.distance_to(b["pos"]) / float(b["r"])
		if d < reach and d < best_d:
			best = b["id"]
			best_d = d
	if best != "":
		_held_by[finger] = best
		for a in _button(best)["acts"]:
			_press(a)
		return
	var m0 = Game.main
	var telling: bool = m0 != null and ((m0.intro != null and m0.intro.running) or (m0.overlay != null and m0.overlay.busy))
	if telling and not _ui_open():
		# a film or a spoken line: there is nowhere to walk, so a tap anywhere moves the story on
		_held_by[finger] = "_tap"
		_press("accept")
	elif p.x < 640.0 and _stick_touch < 0 and not _ui_open():
		_stick_touch = finger
		_stick_from = p
		_stick_at = p
		_update_stick()
	elif _ui_open():
		# a menu or the map takes the tap itself: a choice, or a place
		var m = Game.main
		if m.menu.visible:
			m.menu.tap(p)
		elif m.map.visible:
			m.map.tap(p)
	elif p.x >= 640.0:
		# a tap anywhere else stands for the accept button: it moves the story on
		_held_by[finger] = "_tap"
		_press("accept")


func _touch_up(finger: int) -> void:
	if finger == _stick_touch:
		_stick_touch = -1
		_stick_at = _stick_from
		_update_stick()
		return
	if _held_by.has(finger):
		var id: String = _held_by[finger]
		_held_by.erase(finger)
		if id == "_tap":
			_release("accept")
			return
		for a in _button(id)["acts"]:
			if not _held_elsewhere(a):
				_release(a)


func _held_elsewhere(action: String) -> bool:
	for f in _held_by:
		var id: String = _held_by[f]
		if id != "_tap" and action in _button(id)["acts"]:
			return true
	return false


func _button(id: String) -> Dictionary:
	for b in buttons:
		if b["id"] == id:
			return b
	return {}


func _stick() -> Vector2:
	if _stick_touch < 0:
		return Vector2.ZERO
	var v := (_stick_at - _stick_from) / STICK_R
	return v.limit_length(1.0)


func _update_stick() -> void:
	var v := _stick()
	var x := v.x
	_hold("move_left", x < -DEAD)
	_hold("move_right", x > DEAD)
	_hold("walk", absf(x) > DEAD and absf(x) < WALK)
	_hold("aim_up", v.y < -VERT)
	_hold("move_down", v.y > VERT)


func _hold(action: String, on: bool) -> void:
	if on and not _down.has(action):
		_press(action)
	elif not on and _down.has(action):
		_release(action)


func _press(action: String) -> void:
	_down[action] = true
	_send(action, true)


func _release(action: String) -> void:
	_down.erase(action)
	_send(action, false)


func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	# the action is held at once (so the player sees it this frame), and the event goes to the menus and the map
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	get_viewport().push_input(e)


func _release_all() -> void:
	for a in _down.keys():
		_release(a)
	_held_by.clear()
	_stick_touch = -1


func _draw() -> void:
	var dim := 0.45 if (Game.cinematic or get_tree().paused) else 1.0
	var f: Font = Game.serif
	# the stick: a faint ring where the thumb landed, the knob where it is now; a hint of it when untouched
	if _stick_touch >= 0:
		draw_circle(_stick_from, STICK_R + 18.0, Color(1, 1, 1, 0.08 * dim))
		draw_arc(_stick_from, STICK_R + 18.0, 0, TAU, 48, Color(1, 1, 1, 0.3 * dim), 2.0, true)
		draw_circle(_stick_from + _stick() * STICK_R, 34.0, Color(1, 1, 1, 0.32 * dim))
	elif not _ui_open():      # in a menu or on the map the stick has nothing to do, so it is not shown
		var c := Vector2(120, 654.0 + Game.deck)      # where the stick is, small and low: the thumb can land anywhere
		draw_arc(c, 44.0, 0, TAU, 40, Color(1, 1, 1, 0.14 * dim), 2.0, true)
		draw_circle(c, 18.0, Color(1, 1, 1, 0.1 * dim))
	for b in buttons:
		if not _shown(b):
			continue
		var held := false
		for fg in _held_by:
			if _held_by[fg] == b["id"]:
				held = true
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		draw_circle(p, r, Color(0.08, 0.06, 0.04, (0.55 if held else 0.4) * dim))      # dark enough to read on bright sky
		draw_arc(p, r, 0, TAU, 48, Color(1, 0.95, 0.85, (0.75 if held else 0.4) * dim), 2.0, true)
		var label: String = Game.t(str(b["label"]))
		var size := 19 if r > 50.0 else (17 if r > 40.0 else 14)
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		# a dark edge round the letters keeps them readable over bright sky as well as dark earth
		draw_string_outline(f, p + Vector2(-w * 0.5, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4,
				Color(0.03, 0.02, 0.02, 0.75 * dim))
		draw_string(f, p + Vector2(-w * 0.5, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(1, 0.97, 0.9, (1.0 if held else 0.8) * dim))
