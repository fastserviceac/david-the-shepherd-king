extends Control
## The map. Its relief is drawn from real elevation data and every town stands at its true position
## (see tools/realmap.py and data/map.json). Left and right choose a place; Enter goes there.

signal travel(idx: int)
signal closed

var data: Dictionary = {}
var view := "hills"
var index := 0
var tex := {}
var from_play := false
var t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var f := FileAccess.open("res://data/map.json", FileAccess.READ)
	if f:
		data = JSON.parse_string(f.get_as_text())


func open(playing: bool, at_section: int) -> void:
	from_play = playing
	view = "hills"
	index = clampi(at_section, 0, Game.sections().size() - 1)
	for v in ["hills", "land"]:
		if not tex.has(v):
			tex[v] = load("res://art/map_%s.png" % v)
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()


func _key(idx: int) -> String:
	return str(Game.sections()[idx]["script"]).get_file().get_basename()


func _open_to(idx: int) -> bool:
	return idx <= int(Game.save.get("unlocked", 0))


## Where a latitude and longitude fall on the screen in the current view.
func _at(lat: float, lon: float) -> Vector2:
	var v: Dictionary = data["views"][view]
	return Vector2((lon - v["lon0"]) / (v["lon1"] - v["lon0"]) * 1280.0, (v["lat1"] - lat) / (v["lat1"] - v["lat0"]) * 720.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var n := Game.sections().size()
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		index = posmod(index + 1, n)
		Game.sfx("ui_move", -8.0)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("aim_up"):
		index = posmod(index - 1, n)
		Game.sfx("ui_move", -8.0)
	elif event.is_action_pressed("growth"):
		view = "land" if view == "hills" else "hills"
		Game.sfx("ui_move", -8.0)
	elif event.is_action_pressed("accept"):
		if view == "hills" and _open_to(index):
			Game.sfx("ui_select", -6.0)
			get_viewport().set_input_as_handled()
			travel.emit(index)
			return
	elif event.is_action_pressed("pause") or event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		closed.emit()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _text(at: Vector2, s: String, size: int, col: Color, centre: bool = true) -> void:
	var f := Game.serif
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5 if centre else 0.0, 0.0)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.93, 0.87, 0.72, 0.7))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	if data.is_empty() or not tex.has(view):
		return
	var ink := Color(0.2, 0.13, 0.08)
	draw_texture_rect(tex[view], Rect2(0, 0, 1280, 720), false)
	var v: Dictionary = data["views"][view]
	for lb in data["labels"]:
		if view in lb["views"]:
			_text(_at(lb["lat"], lb["lon"]), Game.t(lb["text"]), 17 if lb.get("small", false) else 24, Color(ink.r, ink.g, ink.b, 0.55))
	for tw in data["towns"]:
		if view in tw["views"]:
			var p := _at(tw["lat"], tw["lon"])
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), ink)
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.93, 0.87, 0.72))
			_text(p + Vector2(0, -12), Game.t(tw["name"]), 20, ink)
	var secs: Array = Game.sections()
	if view == "hills":
		# the way he goes, place to place, as far as he has come
		var prev := Vector2.ZERO
		for i in secs.size():
			var pl: Dictionary = data["places"].get(_key(i), {})
			if pl.is_empty():
				continue
			var p := _at(pl["lat"], pl["lon"])
			if i > 0 and _open_to(i):
				var steps := int(prev.distance_to(p) / 9.0)
				for k in range(1, steps):
					if k % 2 == 0:
						draw_circle(prev.lerp(p, float(k) / steps), 1.7, Color(0.45, 0.16, 0.1, 0.8))
			prev = p
		for i in secs.size():
			var pl: Dictionary = data["places"].get(_key(i), {})
			if pl.is_empty():
				continue
			var p := _at(pl["lat"], pl["lon"])
			var known := _open_to(i)
			var col := Color(0.55, 0.16, 0.1) if known else Color(ink.r, ink.g, ink.b, 0.35)
			if i == index:
				draw_arc(p, 15.0 + sin(t * 4.0) * 2.0, 0.0, TAU, 40, Color(0.55, 0.16, 0.1), 2.5, true)
			draw_circle(p, 6.5, col)
			draw_circle(p, 3.0, Color(0.95, 0.9, 0.78))
			if is_instance_valid(Game.main) and from_play and Game.main.section_idx == i:      # where David is now
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(-7, -26), p + Vector2(7, -26)]), Color(0.55, 0.16, 0.1))
		# the place chosen, in a panel along the bottom
		var sel: Dictionary = data["places"].get(_key(index), {})
		draw_rect(Rect2(0, 600, 1280, 120), Color(0.09, 0.06, 0.04, 0.78))
		var f := Game.serif
		if _open_to(index):
			draw_string(f, Vector2(60, 646), "%d.  %s" % [index + 1, Game.t(secs[index]["title"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Game.CREAM)
			draw_string(f, Vector2(60, 680), Game.t(str(sel.get("about", ""))), HORIZONTAL_ALIGNMENT_LEFT, 900, 19, Color(1.0, 0.9, 0.75, 0.85))
			var stones: Array = sel.get("stones", [])
			if not stones.is_empty():
				var got := 0
				for id in stones:
					if id in Game.stones():
						got += 1
				draw_string(f, Vector2(980, 646), Game.t("Smooth stones  %d of %d") % [got, stones.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.86, 0.6))
			var fl: Array = sel.get("finds", [])
			if not fl.is_empty():
				var names: Array = []
				for e in fl:
					if e[0] in Game.places():
						names.append(Game.t(e[1]))
				var line := Game.t("Places found  %d of %d") % [names.size(), fl.size()]
				if not names.is_empty():
					line += ":  " + ", ".join(names)
				draw_string(f, Vector2(980, 622), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.86, 0.6, 0.9))
			draw_string(f, Vector2(980, 680), Game.keys(Game.t("Enter:  go there")), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1, 0.7))
		else:
			draw_string(f, Vector2(60, 646), Game.t("%d.  A place he has not yet come to") % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.5))
	# title, scale bar, keys
	_text(Vector2(640, 44), Game.t(v["title"]), 30, ink)
	var km := 5.0 if view == "hills" else 20.0
	var bar: float = km / float(v["km"]) * 1280.0
	var b0 := Vector2(60, 540.0 if view == "hills" else 660.0)
	draw_line(b0, b0 + Vector2(bar, 0), ink, 2.5)
	draw_line(b0 + Vector2(0, -5), b0 + Vector2(0, 5), ink, 2.5)
	draw_line(b0 + Vector2(bar, -5), b0 + Vector2(bar, 5), ink, 2.5)
	_text(b0 + Vector2(bar + 10, 6), "%d km" % int(km), 17, ink, false)
	_text(Vector2(1218, 84), "N", 22, ink)
	draw_line(Vector2(1218, 150), Vector2(1218, 96), ink, 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(1218, 90), Vector2(1212, 104), Vector2(1224, 104)]), ink)
	var keys := Game.t("← →  choose a place      Tab  the wider land      M or Esc  close" if view == "hills" else "Tab  back to the hills of Bethlehem      M or Esc  close")
	if Game.pad:
		keys = Game.t("← →  choose a place      Back  the wider land      Start  close" if view == "hills" else "Back  back to the hills of Bethlehem      Start  close")
	var ky := 590.0 if view == "hills" else 700.0
	_text(Vector2(640, ky), keys, 17, Color(ink.r, ink.g, ink.b, 0.8))
