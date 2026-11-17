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
			items.append(["lang", "Language: English", true])      # shown in the language it is set to
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var step := 0
	if event.is_action_pressed("move_down"):
		step = 1
	elif event.is_action_pressed("aim_up"):
		step = -1
	if step != 0:
		for i in items.size():
			index = posmod(index + step, items.size())
			if items[index][2]:
				break
		queue_redraw()
		Game.sfx("ui_move", -8.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accept"):
		Game.sfx("ui_select", -6.0)
		get_viewport().set_input_as_handled()
		chosen.emit(items[index][0])
	elif event.is_action_pressed("pause") and mode == "pause":
		get_viewport().set_input_as_handled()
		chosen.emit("resume")
	elif event.is_action_pressed("pause") and (mode == "sections" or mode == "difficulty" or mode == "settings"):
		get_viewport().set_input_as_handled()
		chosen.emit("back")


## Where row i is written. Long lists start higher and sit closer, so the last row is never below the screen.
func _row_y(i: int) -> float:
	return _top() + i * _step()


func _top() -> float:
	return 380.0 if items.size() <= 7 else 345.0


func _step() -> float:
	return 50.0 if items.size() <= 7 else minf(50.0, (690.0 - _top()) / float(items.size() - 1))


## A finger on the screen at p: a tap on a choice picks it. In the choice of difficulty the first tap only
## points at one, so its description can be read, and a second tap on it picks it.
func tap(p: Vector2) -> bool:
	if not visible:
		return false
	for i in items.size():
		var y := _row_y(i)
		if p.y >= y - _step() * 0.72 and p.y < y + _step() * 0.28 and absf(p.x - 640.0) < 300.0 and items[i][2]:
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
	for k in 6:
		draw_rect(Rect2(400.0 - k * 22.0, _top() - 40.0, 480.0 + k * 44.0, 40.0 + items.size() * _step()), Color(0.02, 0.02, 0.05, 0.085))
	var big := 110 if mode == "main" else 60
	draw_string(f, Vector2(0, 230), Game.t(heading), HORIZONTAL_ALIGNMENT_CENTER, 1280, big, Game.CREAM)
	draw_string(f, Vector2(0, 280), Game.t(sub), HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color(1.0, 0.82, 0.55))
	for i in items.size():
		var y := _row_y(i)
		var col := Game.CREAM
		if not items[i][2]:
			col = Color(1, 1, 1, 0.28)
		elif i != index:
			col = Color(1.0, 0.95, 0.85, 0.65)
		draw_string(f, Vector2(0, y), Game.t(items[i][1]), HORIZONTAL_ALIGNMENT_CENTER, 1280, 30, col)
		if i == index:
			var w := f.get_string_size(Game.t(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_circle(Vector2(640.0 - w * 0.5 - 24.0, y - 10.0), 5.0, Color(1.0, 0.82, 0.55))
			draw_circle(Vector2(640.0 + w * 0.5 + 24.0, y - 10.0), 5.0, Color(1.0, 0.82, 0.55))
	if mode == "difficulty" and index < Game.DIFFICULTY.size():
		draw_string(f, Vector2(0, 290), Game.t(Game.DIFFICULTY[index]["about"]), HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(1.0, 0.82, 0.55))
	if mode == "main":
		# under the last choice, however many there are, and never off the bottom of the screen
		var hint_y := minf(_top() + items.size() * _step() - 6.0, maxf(720.0, size.y) - 14.0)
		hint_y = maxf(hint_y, 690.0)
		draw_string(f, Vector2(0, hint_y), Game.t("Tap a choice") if Game.touch else Game.keys(Game.t("↑ ↓ to choose    ·    Enter to select")), HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(1, 1, 1, 0.5))
