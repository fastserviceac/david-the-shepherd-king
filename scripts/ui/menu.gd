extends Control
## Title, section select and pause menus. Up/down to move, Enter to choose.

signal chosen(id: String)

var mode := ""
var items: Array = []    # [id, label, enabled]
var index := 0
var heading := ""
var sub := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(new_mode: String) -> void:
	mode = new_mode
	items = []
	match mode:
		"main":
			heading = "DAVID"
			sub = "The Shepherd King"
			if Game.save.get("started", false) and not Game.save.get("finished", false):
				items.append(["continue", "Continue", true])
			items.append(["new", "New Game", true])
			items.append(["sections", "Sections", true])
			items.append(["map", "Map", true])
			if ResourceLoader.exists("res://video/intro.ogv"):
				items.append(["prologue", "Prologue", true])
			items.append(["lang", "Language: English", true])      # shown in the language it is set to
			items.append(["quit", "Quit", true])
		"sections":
			heading = "Chapter One"
			sub = "The Shepherd"
			var secs: Array = Game.sections()
			for i in secs.size():
				items.append(["section_%d" % i, secs[i]["title"], i <= int(Game.save.get("unlocked", 0))])
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
			items.append(["menu", "Main Menu", true])
	index = 1 if mode == "difficulty" else 0
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
	elif event.is_action_pressed("pause") and (mode == "sections" or mode == "difficulty"):
		get_viewport().set_input_as_handled()
		chosen.emit("back")


func _draw() -> void:
	var f := Game.serif
	if mode == "pause":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.05, 0.6))
	else:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.05, 0.25))
	# soft dark band so the choices read against any backdrop
	for k in 6:
		draw_rect(Rect2(400.0 - k * 22.0, 340, 480.0 + k * 44.0, 40.0 + items.size() * 50.0), Color(0.02, 0.02, 0.05, 0.085))
	var big := 110 if mode == "main" else 60
	draw_string(f, Vector2(0, 230), Game.t(heading), HORIZONTAL_ALIGNMENT_CENTER, 1280, big, Game.CREAM)
	draw_string(f, Vector2(0, 280), Game.t(sub), HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color(1.0, 0.82, 0.55))
	for i in items.size():
		var y := 380.0 + i * 50.0
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
		draw_string(f, Vector2(0, 690), Game.keys(Game.t("↑ ↓ to choose    ·    Enter to select")), HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(1, 1, 1, 0.5))
