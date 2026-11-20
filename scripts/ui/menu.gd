extends Control
## Title, section select and pause menus. Up/down to move, Enter to choose.

signal chosen(id: String)

var mode := ""
var items: Array = []    # [id, label, enabled]
var index := 0
var heading := ""
var sub := ""
var chapter := 0           # which chapter's sections are listed
var back_to := "main"      # where Back leads from the settings: the title or the pause
var listen := ""           # on the button screen: the action waiting for the button the player presses next
var last_button := ""      # on the controller test: the last button pressed, by its name and what it does


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(new_mode: String, at: int = -1) -> void:
	mode = new_mode
	items = []
	match mode:
		"main":
			heading = "DAVID"
			sub = "The Shepherd King"
			if Game.save.get("started", false) and (not Game.save.get("finished", false) or Game.chapter_of(int(Game.save.get("section", 0))) > 0):
				items.append(["continue", "Continue", true])
			items.append(["new", "New Game", true])
			items.append(["sections", "Sections", true])
			items.append(["map", "Map", true])
			if ResourceLoader.exists("res://video/intro.ogv"):
				items.append(["prologue", "Prologue", true])
			items.append(["lang", "Language: English", true])      # shown in the language it is set to
			items.append(["settings", "Settings", true])
			if not OS.has_feature("mobile"):      # a phone's games are left by the home gesture, not closed from inside
				items.append(["quit", "Quit", true])
		"settings":
			heading = "Settings"
			sub = ""
			var on_off := func(on: bool) -> String: return Game.t("On") if on else Game.t("Off")
			items.append(["set_diff", "%s: %s" % [Game.t("Difficulty"), Game.t(Game.diff()["name"])], true])
			items.append(["set_vol", "%s: %d%%" % [Game.t("Volume"), int(round(Game.volume() * 100.0))], true])
			items.append(["set_subs", "%s: %s" % [Game.t("Film subtitles"), on_off.call(Game.save.get("film_subs", false))], true])
			if Game.touch:
				items.append(["set_haptic", "%s: %s" % [Game.t("Vibration"), on_off.call(Game.save.get("haptics", true))], true])
			var tm := Game.touch_mode()
			items.append(["set_touch", "%s: %s" % [Game.t("On-screen controls"), Game.t({"auto": "Auto", "on": "On", "off": "Off"}[tm])], true])
			var ps := str(Game.save.get("pad_style", "auto"))
			var style := Game.t(Game.PAD_STYLE_NAMES[ps]) if Game.PAD_STYLE_NAMES.has(ps) else Game.t("Auto")
			if ps == "auto" and not Input.get_connected_joypads().is_empty():      # Auto, and the kind it took the pad in hand for
				style += " (%s)" % Game.PAD_STYLE_NAMES[Game.pad_style()]
			items.append(["set_pad", "%s: %s" % [Game.t("Controller"), style], true])
			items.append(["pad_buttons", "Controller buttons", true])
			items.append(["pad_test", "Controller test", true])
			items.append(["back", "Back", true])
		"remap":
			heading = "Controller buttons"
			sub = "Choose an action, then press its new button"
			for a in Game.PAD_ACTIONS:
				items.append(["rm_" + a, "%s: %s" % [Game.t(Game.PAD_ACTION_NAMES[a]), Game.pad_name(a)], true])
			items.append(["rm_move", "Move: stick or D-pad", false])
			items.append(["pad_reset", "Reset to preset", true])
			items.append(["back", "Back", true])
		"pad_test":
			heading = "Controller test"
			var pads := Input.get_connected_joypads()
			sub = Input.get_joy_name(Game.joy_dev if Game.joy_dev in pads else pads[0]) if not pads.is_empty() else "No controller found"
			items.append(["pad_dead", "%s: %d%%" % [Game.t("Dead zone"), int(round(Game.dead_zone() * 100.0))], true])
			items.append(["back", "Back", true])
		"sections":
			# one chapter's sections at a time; a row for each other chapter he can walk into leads to its list
			chapter = clampi(chapter, 0, Game.chapters.size() - 1)
			var ch: Dictionary = Game.chapters[chapter]
			heading = "Chapter %s" % str(ch["number"])
			sub = str(ch["title"])
			var first := Game.chapter_start(chapter)
			var secs: Array = Game.chapter_sections(chapter)
			for i in secs.size():
				if Game.interlude_ready(first + i):      # the night before a section, listed before it
					items.append(["interlude_%d" % (first + i), Game.interlude(first + i)["title"], Game.section_open(first + i)])
				items.append(["section_%d" % (first + i), secs[i]["title"], Game.section_open(first + i)])
			for c in Game.chapters.size():
				if c != chapter and Game.chapter_open(c):
					items.append(["chapter_%d" % c, Game.t("Chapter %s: %s") % [Game.t(Game.chapters[c]["number"]), Game.t(Game.chapters[c]["title"])], true])
			items.append(["back", "Back", true])
		"difficulty":
			heading = "Choose your path"
			sub = ""
			for i in Game.DIFFICULTY.size():
				items.append(["diff_%d" % i, Game.DIFFICULTY[i]["name"], true])
			items.append(["back", "Back", true])
		"pause":
			heading = "Paused"
			sub = ""
			items.append(["resume", "Resume", true])
			items.append(["map", "Map", true])
			items.append(["restart", "Back to the last watchfire", true])
			items.append(["settings", "Settings", true])
			items.append(["menu", "Main Menu", true])
	index = 1 if mode == "difficulty" else 0
	if at >= 0 and at < items.size():
		index = at
	while not items[index][2]:
		index += 1
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	mode = ""
	listen = ""


## The button screen waits for the next button pressed on the controller, to give it to this action.
func listen_for(action: String) -> void:
	listen = action
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and mode == "pad_test":      # the sticks are drawn where they lean, every frame
		queue_redraw()


## While the button screen waits for a button, the next one pressed is taken for it before anything else sees
## it, so it cannot also move the choice or go back. A key or a tap gives up waiting.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if mode == "pad_test" and event is InputEventJoypadButton and event.pressed:
		var what := ""
		for a in Game.PAD_ACTIONS + ["accept", "back"]:
			if Game.pad_code(a) == event.button_index:
				what = Game.t({"accept": "Choose", "back": "Back"}.get(a, Game.PAD_ACTION_NAMES.get(a, a)))
				break
		last_button = Game.button_name(event.button_index) + ("  —  " + what if what != "" else "")
	if listen == "":
		return
	var code := -1
	if event is InputEventJoypadButton and event.pressed and not event.button_index in [JOY_BUTTON_GUIDE,
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:      # the cross moves him and the choice
		code = event.button_index
	elif event is InputEventJoypadMotion and (event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT) and event.axis_value > 0.6:
		code = 100 + event.axis
	elif event is InputEventKey and event.pressed and not event.echo:
		listen = ""
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if code < 0:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	Game.set_pad(listen, code)
	listen = ""
	Game.save_game()
	Game.sfx("ui_select", -6.0)
	open("remap", index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var step := 0
	if event.is_action_pressed("move_down"):
		step = 1
	elif event.is_action_pressed("aim_up"):
		step = -1
	elif _cols() > 1 and event.is_action_pressed("move_right"):
		step = _per()
	elif _cols() > 1 and event.is_action_pressed("move_left"):
		step = -_per()
	if step != 0:
		for i in items.size():
			index = posmod(index + step, items.size())
			if items[index][2]:
				break
		queue_redraw()
		Game.sfx("ui_move", -8.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accept") and mode == "pad_test" and event is InputEventJoypadButton and items[index][0] == "back":
		get_viewport().set_input_as_handled()      # every button is being tried: the pad leaves by its pause button
	elif event.is_action_pressed("accept"):
		Game.sfx("ui_select", -6.0)
		get_viewport().set_input_as_handled()
		chosen.emit(items[index][0])
	elif event.is_action_pressed("pause") and mode == "pause":
		get_viewport().set_input_as_handled()
		chosen.emit("resume")
	elif event.is_action_pressed("pause") and mode in ["sections", "difficulty", "settings", "remap", "pad_test"]:
		get_viewport().set_input_as_handled()
		chosen.emit("back")
	elif event.is_action_pressed("back") and mode == "pause":
		get_viewport().set_input_as_handled()
		chosen.emit("resume")
	elif event.is_action_pressed("back") and mode in ["sections", "difficulty", "settings", "remap"]:      # not on the test: every button is tried there
		get_viewport().set_input_as_handled()
		Game.sfx("ui_move", -8.0)
		chosen.emit("back")


## Where row i is written. Long lists start higher and sit closer, so the last row is never below the screen.
func _row_y(i: int) -> float:
	return _top() + (i % _per()) * _step()


## The button screen has too many rows for one column on a phone: it is laid out in two, side by side.
func _cols() -> int:
	return 2 if mode == "remap" else 1


func _per() -> int:
	return ceili(items.size() / float(_cols()))


func _col_x(i: int) -> float:
	if _cols() == 1:
		return 640.0
	return 380.0 if i < _per() else 900.0


func _half() -> float:      # half the width a row may be tapped across
	return 300.0 if _cols() == 1 else 255.0


func _top() -> float:
	return 380.0 if _per() <= 7 else 345.0


func _step() -> float:
	return 50.0 if _per() <= 7 else minf(50.0, (690.0 - _top()) / float(_per() - 1))


## A finger on the screen at p: a tap on a choice picks it. In the choice of difficulty the first tap only
## points at one, so its description can be read, and a second tap on it picks it.
func tap(p: Vector2) -> bool:
	if not visible:
		return false
	if listen != "":      # waiting for a button: a tap gives up waiting
		listen = ""
		queue_redraw()
		return true
	for i in items.size():
		var y := _row_y(i)
		if p.y >= y - _step() * 0.72 and p.y < y + _step() * 0.28 and absf(p.x - _col_x(i)) < _half() and items[i][2]:
			if mode == "difficulty" and i != index:
				index = i
				queue_redraw()
				Game.sfx("ui_move", -8.0)
				return true
			index = i
			queue_redraw()
			Game.sfx("ui_select", -6.0)
			chosen.emit(items[i][0])
			return true
	return false


func _draw() -> void:
	var f := Game.serif
	if mode == "pause":
		draw_rect(Rect2(0, 0, 1280, maxf(720.0, size.y)), Color(0.02, 0.02, 0.05, 0.6))
	else:
		draw_rect(Rect2(0, 0, 1280, maxf(720.0, size.y)), Color(0.02, 0.02, 0.05, 0.25))
	# soft dark band so the choices read against any backdrop
	var band := 240.0 if _cols() == 1 else 500.0
	for k in 6:
		draw_rect(Rect2(640.0 - band - k * 22.0, _top() - 40.0, band * 2.0 + k * 44.0, 40.0 + _per() * _step()), Color(0.02, 0.02, 0.05, 0.085))
	var big := 110 if mode == "main" else 60
	draw_string(f, Vector2(0, 230), Game.t(heading), HORIZONTAL_ALIGNMENT_CENTER, 1280, big, Game.CREAM)
	var sub_line := Game.t(sub)
	if listen != "":
		sub_line = Game.t("Press a button for %s") % Game.t(Game.PAD_ACTION_NAMES[listen]) + "      " + Game.t("a key or a tap: cancel")
	draw_string(f, Vector2(0, 280), sub_line, HORIZONTAL_ALIGNMENT_CENTER, 1280, 28 if listen == "" else 24, Color(1.0, 0.82, 0.55))
	var fs := 30 if _cols() == 1 else 27
	for i in items.size():
		var y := _row_y(i)
		var cx := _col_x(i)
		var col := Game.CREAM
		if not items[i][2]:
			col = Color(1, 1, 1, 0.28)
		elif i != index:
			col = Color(1.0, 0.95, 0.85, 0.65)
		if listen != "" and i == index:
			col = Color(1.0, 0.82, 0.55, 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 250.0)))
			queue_redraw()
		draw_string(f, Vector2(cx - 640.0, y), Game.t(items[i][1]), HORIZONTAL_ALIGNMENT_CENTER, 1280, fs, col)
		if i == index:
			var w := f.get_string_size(Game.t(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_circle(Vector2(cx - w * 0.5 - 24.0, y - 10.0), 5.0, Color(1.0, 0.82, 0.55))
			draw_circle(Vector2(cx + w * 0.5 + 24.0, y - 10.0), 5.0, Color(1.0, 0.82, 0.55))
	if mode == "pad_test":
		_draw_test(f)
	if mode == "difficulty" and index < Game.DIFFICULTY.size():
		draw_string(f, Vector2(0, 290), Game.t(Game.DIFFICULTY[index]["about"]), HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(1.0, 0.82, 0.55))
	if mode == "main":
		# under the last choice, however many there are, and never off the bottom of the screen
		var hint_y := minf(_top() + items.size() * _step() - 6.0, maxf(720.0, size.y) - 14.0)
		hint_y = maxf(hint_y, 690.0)
		draw_string(f, Vector2(0, hint_y), Game.t("Tap a choice") if Game.touch else Game.keys(Game.t("↑ ↓ to choose    ·    Enter to select")), HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(1, 1, 1, 0.5))


## The controller test: where each stick leans, the ring inside which a lean is not counted, how far each
## trigger is pressed, and the last button pressed with what it does.
func _draw_test(f: Font) -> void:
	var pads := Input.get_connected_joypads()
	var dev: int = Game.joy_dev if Game.joy_dev in pads else (pads[0] if not pads.is_empty() else 0)
	var gold := Color(1.0, 0.82, 0.55)
	var y0 := 560.0
	for side in 2:
		var c := Vector2(470.0 + side * 340.0, y0)
		var v := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X if side == 0 else JOY_AXIS_RIGHT_X),
				Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y if side == 0 else JOY_AXIS_RIGHT_Y))
		draw_circle(c, 62.0, Color(0.02, 0.02, 0.05, 0.45))
		draw_arc(c, 62.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
		if side == 0:      # only the left stick moves him, and only past this ring
			draw_arc(c, 62.0 * Game.dead_zone(), 0.0, TAU, 32, Color(gold, 0.6), 1.5)
		var out := v.length() > Game.dead_zone() if side == 0 else v.length() > 0.2
		draw_circle(c + v.limit_length(1.0) * 62.0, 10.0, gold if out else Color(1, 1, 1, 0.7))
		draw_string(f, c + Vector2(-140, 92), Game.t("Left stick" if side == 0 else "Right stick"), HORIZONTAL_ALIGNMENT_CENTER, 280, 20, Color(1, 1, 1, 0.6))
		# the trigger on that side, as a bar beside the stick
		var tv := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT if side == 0 else JOY_AXIS_TRIGGER_RIGHT)
		var bx := c.x + (-100.0 if side == 0 else 92.0)
		draw_rect(Rect2(bx, y0 - 60.0, 8.0, 120.0), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(bx, y0 + 60.0 - 120.0 * clampf(tv, 0.0, 1.0), 8.0, 120.0 * clampf(tv, 0.0, 1.0)), gold)
	var said := last_button if last_button != "" else Game.t("Press any button")
	said += "      %s  %s" % [Game.pad_name("pause"), Game.t("leave")]
	draw_string(f, Vector2(0, y0 + 136.0), said, HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Game.CREAM)
