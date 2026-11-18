extends Control
## The map. Its relief is drawn from real elevation data and every town stands at its true position
## (see tools/realmap.py and data/map.json). Left and right choose a place; Enter walks him there along the way
## he has come. The road inks itself in as he opens it, each place shows what it has given and still holds, and
## the places found off the path are marked beside it (a faint question mark where one is still hidden).
##
## There are three views. "hills" is Chapter One's ground and "land" the whole of Judah, both real relief. "gibeah"
## is the fortress of Chapter Two, a small model built here from boxes: scripture describes no fortress, so its plan
## follows the remains usually identified at Tell el-Ful. A view that has places lists the sections whose place in
## data/map.json names it ("view"; none means the hills); `index` counts along that list, `_g()` gives the section.
## The hills and the land are older than Chapter Two: a later chapter's place on them (his father's house, the ridge
## road) is not shown until he has come to it. The land has places only then; until then it is only looked at.

signal travel(idx: int)
signal closed

var data: Dictionary = {}
var view := "hills"
var index := 0
var ids: Array = []        # the sections (as numbered in Game.sections()) that have a place in the view shown
var kept := {}             # the place last chosen in each view
var sun: DirectionalLight3D
var tex := {}
var from_play := false
var t := 0.0
var lit := false          # drawing over the 3D ground: pale lettering with a dark edge
var reveal := 1.0        # the newest stretch of road inks itself in when the map opens
var walk := -1.0         # 0..1 while he walks to the chosen place; -1 when he stands
var walk_pts := PackedVector2Array()
var walk_pts3 := PackedVector3Array()
var walk_to := 0
const FA := preload("res://scripts/systems/frame_anim.gd")
const RED := Color(0.55, 0.16, 0.1)

# The hills are a real piece of ground in three dimensions: the same elevation data, built into a mesh, lit by a
# low sun, and looked down on from the south. Everything written on the map (road, marks, names, David) is drawn
# flat on top, at the point where its place on the ground falls on the screen.
const SPAN := 16.0            # the hills box is this wide in the 3D scene
const EXAG := {"hills": 2.4, "land": 7.0}      # relief drawn this much taller than true, so wadis read
const VP := Vector2i(1920, 1080)
const PULL := {"hills": 1.0, "gibeah": 1.72, "land": 1.95}      # how far back the camera rests in each view
const LAND_PULL := 1.3         # once the land has places the camera comes down towards the one chosen: at the whole land's scale
const LAND_ASIDE := -1.15      # the ridge from Bethlehem to Gibeah is a thumb's width, and its names lie on top of each other
const NEXT := {"hills": "the hills of Bethlehem", "gibeah": "the fortress at Gibeah", "land": "the wider land"}
# the fortress model, in the scene's own units (north is -z, as on the other grounds)
const FW := 7.4               # the walls' outer size, west to east
const FD := 4.4               # and north to south
const GATE_X := -1.7          # where the gate stands in the south wall
const CISTERN := Vector2(-0.5, 0.75)
const FORT_LOOK := Vector3(0.0, 0.0, 0.3)
var vp: SubViewport
var cam: Camera3D
var heights := PackedFloat32Array()
var gw := 0
var gh := 0
var depth := 9.0              # the box's north-south size in the scene
var look := Vector3.ZERO      # the point on the ground the camera rests on
var pull := 1.0               # 1 = close on a place, larger = drawn back
var decorated := false
var card_box: StyleBoxFlat
var grounds := {}             # each view's ground: its heights, grid and mesh


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
	for v in ["hills", "land"]:
		if not tex.has(v):
			tex[v] = load("res://art/map_%s.png" % v)
	tex["gibeah"] = tex["hills"]
	reveal = 1.0 if Game.fast else 0.0
	walk = -1.0
	_build_3d()
	kept = {}
	ids = []
	_show("hills")
	if not decorated:
		decorated = true
		_decorate()
	if _view_of(at_section) in ["gibeah", "land"]:      # he is in the fortress, or on a road of the wider land: that is the map he is shown
		_show(_view_of(at_section))
	index = ids.find(at_section) if ids.has(at_section) else clampi(at_section, 0, maxi(ids.size() - 1, 0))
	look = _want()
	pull = 1.0 if Game.fast else 2.3
	_aim()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	if visible:
		t += delta
		reveal = minf(1.0, reveal + delta / 1.5)
		if walk >= 0.0:
			walk += delta / clampf(_length(walk_pts) / 260.0, 0.5, 1.6)
			if walk >= 1.0:
				walk = -1.0
				travel.emit(_g(walk_to))
		if cam:      # the camera glides to whatever is chosen, and follows him when he walks
			var want := _want()
			if walk >= 0.0:
				want = _along3(walk_pts3, walk)
				if view == "gibeah":
					want = FORT_LOOK.lerp(want, 0.2)
			var k := 1.0 - exp(-delta * 4.0)
			look = look.lerp(want, k)
			pull = lerpf(pull, LAND_PULL if view == "land" and not ids.is_empty() else PULL[view], 1.0 - exp(-delta * 2.2))
			cam.h_offset = lerpf(cam.h_offset, (0.0 if ids.is_empty() else LAND_ASIDE) if view == "land" else -1.15, k)
			_aim()
		queue_redraw()


## Where the camera rests: on the place chosen in the hills, on the whole land, or on the fortress, leaning a
## little towards the place chosen in it (it is small enough to be seen whole).
func _want() -> Vector3:
	if view == "land":
		return _ground(Vector2(0.0, 0.6)) if ids.is_empty() else _world_of(index)
	if view == "gibeah":
		return FORT_LOOK.lerp(_world_of(index), 0.2)
	return _world_of(index)


## The section at place i of the view shown.
func _g(i: int) -> int:
	return int(ids[i]) if i >= 0 and i < ids.size() else i


func _key(idx: int) -> String:
	return str(Game.sections()[_g(idx)]["script"]).get_file().get_basename()


## Which view a section's place is in: "hills" unless its place says otherwise, "" if it has no place.
func _view_of(sec: int) -> String:
	if sec < 0 or sec >= Game.sections().size():
		return ""
	var pl: Dictionary = data.get("places", {}).get(str(Game.sections()[sec]["script"]).get_file().get_basename(), {})
	return "" if pl.is_empty() else str(pl.get("view", "hills"))


func _ids_of(name: String) -> Array:
	var out: Array = []
	var reached := int(Game.save.get("unlocked", 0))
	for i in Game.sections().size():
		if _view_of(i) != name:
			continue
		if name != "gibeah" and Game.chapter_of(i) > 0 and i > reached:      # a later chapter's place on the old maps: not before he has come to it
			continue
		out.append(i)
	return out


## Has he come to the fortress yet? Until he has, the map does not show it.
func _fort_known() -> bool:
	for g in _ids_of("gibeah"):
		if g <= int(Game.save.get("unlocked", 0)) and Game.section_ready(g):
			return true
	return false


func _open_to(idx: int) -> bool:
	return _g(idx) <= int(Game.save.get("unlocked", 0)) and Game.section_ready(_g(idx))


## Where a latitude and longitude fall on the screen in the current view.
func _at(lat: float, lon: float) -> Vector2:
	if cam:
		return _screen(_world(lat, lon))
	var v: Dictionary = data["views"][view]
	return Vector2((lon - v["lon0"]) / (v["lon1"] - v["lon0"]) * 1280.0, (v["lat1"] - lat) / (v["lat1"] - v["lat0"]) * 720.0)


func _spot(i: int) -> Vector2:
	var pl: Dictionary = data["places"].get(_key(i), {})
	if pl.is_empty():
		return Vector2.ZERO
	if pl.has("x"):
		return _screen(_world_of(i)) if cam else Vector2(640.0 + float(pl["x"]) * 60.0, 360.0 + float(pl["z"]) * 60.0)
	return _at(pl["lat"], pl["lon"])


func _world_of(i: int) -> Vector3:
	var pl: Dictionary = data["places"].get(_key(i), {})
	if pl.is_empty():
		return Vector3.ZERO
	if pl.has("x"):        # a place on a plan, not on the land: where it stands on the model
		return Vector3(float(pl["x"]), 0.0, float(pl["z"]))
	return _world(pl["lat"], pl["lon"])


## A latitude and longitude as a point on the 3D ground.
func _world(lat: float, lon: float) -> Vector3:
	var v: Dictionary = data["views"][view]
	var u: float = (lon - v["lon0"]) / (v["lon1"] - v["lon0"])
	var w: float = (v["lat1"] - lat) / (v["lat1"] - v["lat0"])
	return _ground(Vector2((u - 0.5) * SPAN, (w - 0.5) * depth))


## The ground under a point of the scene's floor plan.
func _ground(xz: Vector2) -> Vector3:
	if heights.is_empty():
		return Vector3(xz.x, 0.0, xz.y)
	var fx := clampf((xz.x / SPAN + 0.5) * (gw - 1), 0.0, gw - 1.001)
	var fy := clampf((xz.y / depth + 0.5) * (gh - 1), 0.0, gh - 1.001)
	var x0 := int(fx)
	var y0 := int(fy)
	var a := lerpf(heights[y0 * gw + x0], heights[y0 * gw + x0 + 1], fx - x0)
	var b := lerpf(heights[(y0 + 1) * gw + x0], heights[(y0 + 1) * gw + x0 + 1], fx - x0)
	return Vector3(xz.x, lerpf(a, b, fy - y0), xz.y)


func _screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * (1280.0 / VP.x)


func _aim() -> void:
	if cam == null:
		return
	var sway := Vector3(sin(t * 0.23) * 0.28, 0.0, 0.0)      # it never sits quite still: a slow drift, as of someone looking
	cam.position = look + sway + Vector3(0.0, 5.4, 6.0) * pull
	cam.look_at(look + Vector3(0, 0.1, 0), Vector3.UP)


## The stretch of road that ends at place i, laid over the ground with a slight bow, as a hand would draw it.
func _leg3(i: int) -> PackedVector3Array:
	var a3 := _world_of(i - 1)
	var b3 := _world_of(i)
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	var side := (b - a).orthogonal().normalized() * minf(0.34, a.distance_to(b) * 0.16) * (1.0 if i % 2 == 0 else -1.0)
	var out := PackedVector3Array()
	for k in 25:
		var u := k / 24.0
		out.append(_ground(a.lerp(b, u) + side * sin(u * PI)) + Vector3(0, 0.02, 0))
	return out


func _leg(i: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _leg3(i):
		out.append(_screen(p))
	return out


func _along3(pts: PackedVector3Array, u: float) -> Vector3:
	if pts.is_empty():
		return look
	var f := clampf(u, 0.0, 1.0) * (pts.size() - 1)
	var k := mini(int(f), pts.size() - 2)
	return pts[k].lerp(pts[k + 1], f - k)


## The ground itself: a mesh from the elevation grid, its own colours, a low sun and a little haze.
func _build_3d() -> void:
	if vp != null:
		return
	vp = SubViewport.new()
	vp.size = VP
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	for name in ["hills", "land"]:
		grounds[name] = _build_ground(name)
		vp.add_child(grounds[name]["node"])
	grounds["gibeah"] = _build_fort()
	vp.add_child(grounds["gibeah"]["node"])
	# the table the land stands on, so its edges do not end in nothing
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200, 200)
	var fl := MeshInstance3D.new()
	fl.mesh = floor_mesh
	fl.position.y = -0.02
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.07, 0.055, 0.05)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.material_override = fmat
	vp.add_child(fl)
	sun = DirectionalLight3D.new()       # low and from the north-west, so every ridge throws its shadow
	sun.rotation_degrees = Vector3(-34.0, 128.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 0.95
	vp.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.055, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.78)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.48, 0.5)
	env.fog_density = 0.016
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 36.0
	cam.near = 0.1
	cam.far = 120.0
	vp.add_child(cam)
	cam.h_offset = -1.15      # the chosen place sits right of the card, not under it
	cam.current = true


func _length(pts: PackedVector2Array) -> float:
	var d := 0.0
	for k in range(1, pts.size()):
		d += pts[k - 1].distance_to(pts[k])
	return d


## The point a fraction u of the way along a line, and which way it is heading there.
func _along(pts: PackedVector2Array, u: float) -> Array:
	var want := _length(pts) * clampf(u, 0.0, 1.0)
	for k in range(1, pts.size()):
		var d := pts[k - 1].distance_to(pts[k])
		if want <= d or k == pts.size() - 1:
			return [pts[k - 1].lerp(pts[k], want / maxf(d, 0.001)), pts[k].x - pts[k - 1].x]
		want -= d
	return [pts[0], 1.0]


## Where the places found off the path sit round a place's mark.
func _find_at(p: Vector2, k: int) -> Vector2:
	return p + Vector2.from_angle(deg_to_rad(35.0 + 75.0 * k)) * 27.0


## Where he stands, as a place of the view shown: -1 if he is somewhere this view does not show.
func _here() -> int:
	return ids.find(Game.main.section_idx) if is_instance_valid(Game.main) and from_play else -1


func _start_walk() -> void:
	var from := _here()
	if Game.fast or from < 0 or from == index:
		travel.emit(_g(index))
		return
	walk_pts3 = PackedVector3Array()
	if index > from:
		for i in range(from + 1, index + 1):
			walk_pts3.append_array(_leg3(i))
	else:
		for i in range(from, index, -1):
			var leg := _leg3(i)
			leg.reverse()
			walk_pts3.append_array(leg)
	walk_pts = PackedVector2Array()
	for p in walk_pts3:
		walk_pts.append(Vector2(p.x, p.z) * 80.0)      # only its length is used, to time the walk
	walk_to = index
	walk = 0.0
	Game.sfx("ui_select", -6.0)


## A finger on the map at p: a tap on a place picks it out, a second tap on it sets him walking there.
func tap(p: Vector2) -> bool:
	if not visible:
		return false
	if walk >= 0.0 or ids.is_empty():
		return true
	var best := -1
	var best_d := 46.0
	for i in ids.size():
		var pl: Dictionary = data["places"].get(_key(i), {})
		if pl.is_empty():
			continue
		var d := p.distance_to(_spot(i))
		if d < best_d:
			best = i
			best_d = d
	if best < 0:
		return true
	if best == index and _open_to(best):
		_start_walk()
		return true
	index = best
	Game.sfx("ui_move", -8.0)
	queue_redraw()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if walk >= 0.0:        # he is on his way
		get_viewport().set_input_as_handled()
		return
	var n := ids.size()
	if n > 0 and (event.is_action_pressed("move_right") or event.is_action_pressed("move_down")):
		index = posmod(index + 1, n)
		Game.sfx("ui_move", -8.0)
	elif n > 0 and (event.is_action_pressed("move_left") or event.is_action_pressed("aim_up")):
		index = posmod(index - 1, n)
		Game.sfx("ui_move", -8.0)
	elif event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + n:
		index = event.keycode - KEY_1      # a place by its number
		Game.sfx("ui_move", -8.0)
	elif event.is_action_pressed("growth"):
		_toggle()
		Game.sfx("ui_move", -8.0)
	elif event.is_action_pressed("accept"):
		if not ids.is_empty() and _open_to(index):
			get_viewport().set_input_as_handled()
			_start_walk()
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
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.08, 0.05, 0.03, 0.75) if lit else Color(0.93, 0.87, 0.72, 0.7))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	if data.is_empty() or not tex.has(view):
		return
	var ink := Color(0.2, 0.13, 0.08)
	lit = vp != null
	if lit:
		draw_texture_rect(vp.get_texture(), Rect2(0, 0, 1280, 720), false)
		# distance: the far ground goes into a warm haze under a dusk sky, and the corners fall away
		var sky_top := Color(0.16, 0.13, 0.2, 1.0)
		var haze := Color(0.86, 0.66, 0.5, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 120), Vector2(0, 120)]), PackedColorArray([sky_top, sky_top, Color(0.86, 0.66, 0.5, 0.62), Color(0.86, 0.66, 0.5, 0.62)]))
		draw_polygon(PackedVector2Array([Vector2(0, 120), Vector2(1280, 120), Vector2(1280, 330), Vector2(0, 330)]), PackedColorArray([Color(0.86, 0.66, 0.5, 0.62), Color(0.86, 0.66, 0.5, 0.62), haze, haze]))
		draw_polygon(PackedVector2Array([Vector2(0, 560), Vector2(1280, 560), Vector2(1280, 720), Vector2(0, 720)]), PackedColorArray([Color(0.03, 0.02, 0.03, 0.0), Color(0.03, 0.02, 0.03, 0.0), Color(0.03, 0.02, 0.03, 0.7), Color(0.03, 0.02, 0.03, 0.7)]))
		ink = Color(0.98, 0.94, 0.84)
	else:
		draw_texture_rect(tex[view], Rect2(0, 0, 1280, 720), false)
	var v: Dictionary = data["views"][view]
	for lb in data["labels"]:
		if view in lb["views"]:
			var lp: Vector2 = _screen(Vector3(float(lb["x"]), float(lb.get("y", 0.0)), float(lb["z"]))) if lb.has("x") else _at(lb["lat"], lb["lon"])
			_text(lp, Game.t(lb["text"]), 17 if lb.get("small", false) else 24, Color(ink.r, ink.g, ink.b, 0.8 if lb.has("x") else 0.55))
	for tw in data["towns"]:
		if view in tw["views"]:
			var p := _at(tw["lat"], tw["lon"])
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), ink)
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.93, 0.87, 0.72))
			_text(p + Vector2(0, -12), Game.t(tw["name"]), 20, ink)
	var secs: Array = []
	for g in ids:
		secs.append(Game.sections()[g])
	if not secs.is_empty():
		var last := int(Game.save.get("unlocked", 0))
		# the way he has come, inked in; the way still ahead, only pricked out
		for i in range(1, secs.size()):
			var leg := _leg(i)
			if _open_to(i):
				var part := reveal if _g(i) == last else 1.0
				var n := maxi(2, int(ceil(leg.size() * part)))
				draw_polyline(leg.slice(0, n), Color(0.1, 0.04, 0.02, 0.45), 7.0, true)
				draw_polyline(leg.slice(0, n), Color(1.0, 0.82, 0.5), 3.0, true)
			else:
				for k in range(1, leg.size(), 2):
					draw_circle(leg[k], 1.8, Color(ink.r, ink.g, ink.b, 0.45))
		var here := _here()
		for i in secs.size():
			var pl: Dictionary = data["places"].get(_key(i), {})
			if pl.is_empty():
				continue
			var p := _spot(i)
			var known := _open_to(i)
			if known:      # what lies off the path here: marked once found, a faint question while it hides
				var fl: Array = pl.get("finds", [])
				for k in fl.size():
					var q := _find_at(p, k)
					if fl[k][0] in Game.places():
						draw_line(p, q, Color(ink.r, ink.g, ink.b, 0.45), 1.2, true)
						draw_colored_polygon(PackedVector2Array([q + Vector2(0, -6), q + Vector2(6, 0), q + Vector2(0, 6), q + Vector2(-6, 0)]), Color(0.78, 0.56, 0.2))
						draw_polyline(PackedVector2Array([q + Vector2(0, -6), q + Vector2(6, 0), q + Vector2(0, 6), q + Vector2(-6, 0), q + Vector2(0, -6)]), ink, 1.4, true)
						if i == index:
							_text(q + Vector2(10, 5), Game.t(fl[k][1]), 15, ink, false)
					else:
						draw_arc(q, 7.0, 0.0, TAU, 20, Color(ink.r, ink.g, ink.b, 0.4), 1.2, true)
						_text(q + Vector2(0, 5), "?", 14, Color(ink.r, ink.g, ink.b, 0.6))
			var foot := p
			p = _screen(_world_of(i) + Vector3(0, 0.22, 0))       # the mark stands on a pin above its spot
			draw_line(foot, p, Color(0.08, 0.05, 0.03, 0.8), 2.0, true)
			draw_circle(foot, 2.5, Color(0.08, 0.05, 0.03, 0.8))
			var col := Color(0.8, 0.22, 0.12) if known else Color(0.5, 0.5, 0.5, 0.7)
			if i == index:
				draw_arc(p, 16.0 + sin(t * 4.0) * 2.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.5), 2.5, true)
			draw_circle(p, 9.0, Color(0.08, 0.05, 0.03, 0.85))
			draw_circle(p, 7.0, col)
			draw_circle(p, 3.0, Color(0.95, 0.9, 0.78))
			if known and i != index:      # its name, small, so the map can be read without stepping through it
				_text(p + Vector2(0, -16), Game.t(secs[i]["title"]), 14, Color(ink.r, ink.g, ink.b, 0.82))
			elif i == index and known:
				_text(p + Vector2(0, -24), Game.t(secs[i]["title"]), 19, Color(1.0, 0.9, 0.62))
			if known and _reach_now(pl):       # a gift given since opens something here: a beckoning ring
				draw_arc(p, 13.0 + fmod(t * 9.0, 12.0), 0.0, TAU, 30, Color(1.0, 0.86, 0.5, 1.0 - fmod(t * 9.0, 12.0) / 12.0), 2.0, true)
			if known and _all_found(pl):       # nothing left to find here
				draw_arc(p, 9.5, 0.0, TAU, 30, Color(0.78, 0.56, 0.2), 2.0, true)
		# David himself: standing where he is, or walking the road to the place chosen
		if here >= 0:
			var at := _spot(here)
			var facing := 1.0
			var fr: Array = FA.frames("david", "idle")
			var tex_d: Texture2D = FA.pingpong(fr, t, 8.0) if not fr.is_empty() else null
			if walk >= 0.0:
				at = _screen(_along3(walk_pts3, walk))
				var ahead := _screen(_along3(walk_pts3, walk + 0.03))
				facing = -1.0 if ahead.x < at.x - 0.2 else 1.0
				var wf: Array = FA.frames("david", "walk")
				if not wf.is_empty():
					tex_d = wf[int(t * 14.0) % wf.size()]
			if tex_d != null:
				var hgt := 132.0
				var wid := hgt * tex_d.get_width() / tex_d.get_height()
				draw_circle(at + Vector2(0, -2), 9.0, Color(0, 0, 0, 0.18))
				draw_texture_rect(tex_d, Rect2(at + Vector2(-wid * 0.5, -hgt + 10.0), Vector2(wid * facing, hgt)), false)
			else:
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(-7, -26), at + Vector2(7, -26)]), RED)
		_card(secs)
	# title, scale bar, keys
	if view == "land" and lit:      # the road the story takes next: north along the ridge, to the king at Gibeah
		var from_t := {}
		var to_t := {}
		for tw in data["towns"]:
			if tw["name"] == "Bethlehem":
				from_t = tw
			elif str(tw["name"]).begins_with("Gibeah"):
				to_t = tw
		if not from_t.is_empty() and not to_t.is_empty():
			var done: bool = Game.save.get("finished", false)
			var road_col := Color(1.0, 0.82, 0.5, 0.95 if done else 0.45)
			for k in range(1, 24):
				var u := k / 24.0
				var q := _at(lerpf(from_t["lat"], to_t["lat"], u), lerpf(from_t["lon"], to_t["lon"], u) + sin(u * PI) * 0.012)
				draw_circle(q, 2.2, road_col)
			var gp := _at(to_t["lat"], to_t["lon"])
			draw_arc(gp, 13.0 + fmod(t * 8.0, 12.0), 0.0, TAU, 30, Color(1.0, 0.82, 0.5, (1.0 - fmod(t * 8.0, 12.0) / 12.0) * (1.0 if done else 0.5)), 2.0, true)
			if ids.is_empty():      # once the road is a place of its own, its mark says this
				_text(gp + Vector2(-215, 8), Game.t("Chapter Two  ·  The Lyre") if done else Game.t("The road north"), 17, road_col)
	if view == "land" and lit:      # where the hills of this chapter lie in the whole land
		var hb: Dictionary = data["views"]["hills"]
		var box := PackedVector2Array()
		for c in [[hb["lat1"], hb["lon0"]], [hb["lat1"], hb["lon1"]], [hb["lat0"], hb["lon1"]], [hb["lat0"], hb["lon0"]], [hb["lat1"], hb["lon0"]]]:
			box.append(_at(c[0], c[1]))
		draw_polyline(box, Color(1.0, 0.82, 0.5, 0.9), 2.0, true)
	_text(Vector2(640, 44), Game.t(v["title"]), 30, ink)
	var km := 20.0
	if view == "land" and ids.is_empty():      # a scale bar means nothing on ground seen at a slant, or from closer than the whole
		var bar: float = km / float(v["km"]) * 1280.0
		var b0 := Vector2(420.0 if view == "hills" else 60.0, 660.0)
		draw_line(b0, b0 + Vector2(bar, 0), ink, 2.5)
		draw_line(b0 + Vector2(0, -5), b0 + Vector2(0, 5), ink, 2.5)
		draw_line(b0 + Vector2(bar, -5), b0 + Vector2(bar, 5), ink, 2.5)
		_text(b0 + Vector2(bar + 10, 6), "%d km" % int(km), 17, ink, false)
	_text(Vector2(1218, 84), "N", 22, ink)
	draw_line(Vector2(1218, 150), Vector2(1218, 96), ink, 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(1218, 90), Vector2(1212, 104), Vector2(1224, 104)]), ink)
	var keys := Game.keys(Game.t(("Tap a place, and again to go there      Tab  the wider land      M or Esc  close" if Game.touch else "← →  or  1–8  choose a place      Enter  go there      Tab  the wider land      M or Esc  close") if view == "hills" else "Tab  back to the hills of Bethlehem      M or Esc  close"))
	if Game.pad:
		keys = Game.t("← →  choose a place      Back  the wider land      Start  close" if view == "hills" else "Back  back to the hills of Bethlehem      Start  close")
	if int(Game.save.get("unlocked", 0)) >= Game.chapter_start(1):      # Chapter Two: more views and more places, so the line is put together
		var order := _order()
		var nxt: String = Game.t(NEXT[order[(order.find(view) + 1) % order.size()]])
		var gap := "      "
		if Game.pad:
			keys = ("" if ids.is_empty() else Game.t("← →  choose a place") + gap) + "Back  " + nxt + gap + Game.t("Start  close")
		else:
			var choose: String = "" if ids.is_empty() else (Game.t("Tap a place, and again to go there") if Game.touch else Game.t("← →  choose a place") + gap + Game.t("Enter  go there")) + gap
			keys = Game.keys(choose + "Tab  " + nxt + gap + Game.t("M or Esc  close"))
	var ky := 700.0
	_text(Vector2(640, ky), keys, 17, Color(ink.r, ink.g, ink.b, 0.8))


func _all_found(pl: Dictionary) -> bool:
	for id in pl.get("stones", []):
		if not id in Game.stones():
			return false
	for e in pl.get("finds", []):
		if not e[0] in Game.places():
			return false
	return true


## The place chosen, on a card: why he goes there, what it has given him, and what it still holds.
func _card(secs: Array) -> void:
	var f := Game.serif
	var x := 28.0
	var w := 332.0
	var gold := Color(1.0, 0.86, 0.6)
	if card_box == null:
		card_box = StyleBoxFlat.new()
		card_box.bg_color = Color(0.07, 0.05, 0.05, 0.86)
		card_box.border_color = Color(0.85, 0.64, 0.3, 0.55)
		card_box.set_border_width_all(1)
		card_box.set_corner_radius_all(16)
		card_box.shadow_color = Color(0, 0, 0, 0.45)
		card_box.shadow_size = 18
	draw_style_box(card_box, Rect2(x, 76, w, 560))
	var tx := x + 22.0
	var tw := w - 44.0
	if not _open_to(index):
		draw_multiline_string(f, Vector2(tx, 124), Game.t("%d.  A place he has not yet come to") % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, tw, 26, -1, Color(1, 1, 1, 0.5))
		return
	var sec: Dictionary = secs[index]
	var pl: Dictionary = data["places"].get(_key(index), {})
	var y := 118.0
	var head := "%d.  %s" % [index + 1, Game.t(sec["title"])]
	var head_size := 29
	while head_size > 20 and f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, head_size).x > tw:      # a long title is set smaller, not cut off
		head_size -= 1
	draw_string(f, Vector2(tx, y), head, HORIZONTAL_ALIGNMENT_LEFT, tw, head_size, Game.CREAM)
	y += 14.0
	draw_line(Vector2(tx, y), Vector2(tx + tw, y), Color(0.78, 0.56, 0.2, 0.5), 1.0)
	y += 26.0
	for part in [[str(sec.get("aim", "")), 19, Game.CREAM], [str(sec.get("why", "")), 16, Color(1.0, 0.9, 0.75, 0.8)], [str(pl.get("about", "")), 15, Color(1.0, 0.9, 0.75, 0.55)]]:
		if part[0] == "":
			continue
		var txt: String = Game.t(part[0])
		draw_multiline_string(f, Vector2(tx, y), txt, HORIZONTAL_ALIGNMENT_LEFT, tw, part[1], -1, part[2])
		y += f.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, tw, part[1]).y + 12.0
	y += 6.0
	draw_line(Vector2(tx, y - 14.0), Vector2(tx + tw, y - 14.0), Color(0.78, 0.56, 0.2, 0.3), 1.0)
	# the gift of this place
	for id in Game.GIFT_ORDER:
		var g: Dictionary = Game.GIFTS[id]
		if int(g["after"]) != _g(index):
			continue
		var got: bool = Game.has(id)
		draw_string(f, Vector2(tx, y + 6.0), Game.t(g["name"]), HORIZONTAL_ALIGNMENT_LEFT, tw, 20, gold if got else Color(1, 1, 1, 0.75))
		var state: String = Game.t("given") if got else Game.t("still to earn")
		draw_string(f, Vector2(tx, y + 6.0), state, HORIZONTAL_ALIGNMENT_RIGHT, tw, 15, gold if got else Color(1, 1, 1, 0.5))
		y += 28.0
		if not got:
			var how: String = Game.t(str(g.get("how", "")))
			draw_multiline_string(f, Vector2(tx, y), how, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, -1, Color(1, 1, 1, 0.6))
			y += f.get_multiline_string_size(how, HORIZONTAL_ALIGNMENT_LEFT, tw, 15).y + 6.0
		y += 8.0
	# smooth stones, as pips
	var stones: Array = pl.get("stones", [])
	if not stones.is_empty():
		draw_string(f, Vector2(tx, y + 6.0), Game.t("Smooth stones"), HORIZONTAL_ALIGNMENT_LEFT, tw, 18, Color(1, 1, 1, 0.8))
		for k in stones.size():
			var c := Vector2(tx + tw - 10.0 - (stones.size() - 1 - k) * 20.0, y)
			if stones[k] in Game.stones():
				draw_circle(c, 6.5, gold)
			else:
				draw_arc(c, 6.0, 0.0, TAU, 20, Color(1, 1, 1, 0.4), 1.4, true)
		y += 32.0
	# places off the path
	var fl: Array = pl.get("finds", [])
	if not fl.is_empty():
		draw_string(f, Vector2(tx, y + 6.0), Game.t("Off the path"), HORIZONTAL_ALIGNMENT_LEFT, tw, 18, Color(1, 1, 1, 0.8))
		y += 26.0
		for e in fl:
			var found: bool = e[0] in Game.places()
			draw_string(f, Vector2(tx + 14.0, y + 4.0), Game.t(e[1]) if found else Game.t("?   a place not yet found"), HORIZONTAL_ALIGNMENT_LEFT, tw - 14.0, 16, gold if found else Color(1, 1, 1, 0.45))
			y += 24.0
	# what waits here for a gift given later: the reason to come back
	var later: Dictionary = pl.get("later", {})
	for sid in later:
		if sid in Game.stones() or sid in Game.places():
			continue
		var gname: String = Game.t(Game.GIFTS[later[sid]]["name"])
		var can: bool = Game.has(later[sid])
		var line: String = (Game.t("Within his reach now, with %s") if can else Game.t("Something here waits for %s")) % gname
		y += 8.0
		draw_multiline_string(f, Vector2(tx, y + 4.0), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, -1, gold if can else Color(1, 1, 1, 0.5))
		y += f.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, tw, 15).y
	var go := Game.t("He is here") if _here() == index else Game.keys(Game.t("Enter:  go there"))
	draw_string(f, Vector2(tx, 618), go, HORIZONTAL_ALIGNMENT_LEFT, tw, 18, Color(1, 1, 1, 0.7))


## Brings one view's ground forward: its mesh is shown and its heights are the ones places are set on.
func _show(name: String) -> void:
	if not ids.is_empty():
		kept[view] = index
	view = name
	for k in grounds:
		grounds[k]["node"].visible = k == name
	var g: Dictionary = grounds[name]
	heights = g["heights"]
	gw = g["gw"]
	gh = g["gh"]
	depth = g["depth"]
	if sun:
		sun.shadow_enabled = name == "gibeah"      # walls throw shadows; the hills are shaded by their own slopes
	ids = _ids_of(name)
	var here := _here()
	index = clampi(int(kept.get(name, here if here >= 0 else 0)), 0, maxi(ids.size() - 1, 0))


func _build_ground(name: String) -> Dictionary:
	var rel: Dictionary = data["relief"][name]
	var w := int(rel["w"])
	var h := int(rel["h"])
	var img: Image = (load("res://art/map_%s_height.png" % name) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var dep := SPAN * h / w
	var unit: float = SPAN / (float(rel["km"]) * 1000.0) * float(EXAG[name])       # scene units for a metre of height
	var lo := float(rel["lo"])
	var hi := float(rel["hi"])
	var hs := PackedFloat32Array()
	hs.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			hs[y * w + x] = ((c.r8 * 256 + c.g8) / 65535.0 * (hi - lo)) * unit
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(w * h)
	norms.resize(w * h)
	uvs.resize(w * h)
	var dx := SPAN / (w - 1)
	var dz := dep / (h - 1)
	for y in h:
		for x in w:
			var k := y * w + x
			verts[k] = Vector3(x * dx - SPAN * 0.5, hs[k], y * dz - dep * 0.5)
			uvs[k] = Vector2(float(x) / (w - 1), float(y) / (h - 1))
			var hl := hs[y * w + maxi(x - 1, 0)]
			var hr := hs[y * w + mini(x + 1, w - 1)]
			var hu := hs[maxi(y - 1, 0) * w + x]
			var hd := hs[mini(y + 1, h - 1) * w + x]
			norms[k] = Vector3((hl - hr) / (2.0 * dx), 1.0, (hu - hd) / (2.0 * dz)).normalized()
	for y in h - 1:
		for x in w - 1:
			var k := y * w + x
			idx.append_array(PackedInt32Array([k, k + 1, k + w, k + 1, k + w + 1, k + w]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://art/map_%s_ground.png" % name)
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	return {"heights": hs, "gw": w, "gh": h, "depth": dep, "node": node}


## The views in the order Tab goes through them: the fortress only once he has come to it.
func _order() -> Array:
	return ["hills", "gibeah", "land"] if _fort_known() else ["hills", "land"]


## On to the next view: the hills, the fortress, the whole land.
func _toggle() -> void:
	var order := _order()
	_show(order[(order.find(view) + 1) % order.size()])
	pull = 2.6 if view == "land" else 1.6      # the camera draws back to the whole land, or comes down to a place
	look = _want()


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, turn: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = mat
	n.position = at + Vector3(0, size.y * 0.5, 0)
	n.rotation.y = turn
	parent.add_child(n)
	return n


## Trodden earth: a painting spread over the ground and tinted, so it is mottled and not one flat colour.
func _ground_mat(pic: Texture2D, tint: Color, scale: float) -> StandardMaterial3D:
	var m := _flat(tint)
	m.albedo_texture = pic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	return m


func _flat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


## The fortress at Gibeah as a model on the table: a casemate wall with a tower at each corner and one gate in the
## south wall, and inside it the yard with its cistern, the storehouse against the east wall and the hall against
## the north. Where things stand matches data/map.json (the places and labels of the "gibeah" view).
func _build_fort() -> Dictionary:
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://art/map_gibeah_stone.png")
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3(0.85, 0.85, 0.85)
	stone.roughness = 1.0
	stone.metallic_specular = 0.0
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var soil: Texture2D = load("res://art/ground_yard.png")      # the painted earth of the yard by day
	var earth := _ground_mat(soil, Color(0.8, 0.68, 0.54), 0.3)
	var yard := _ground_mat(soil, Color(1.0, 0.92, 0.8), 0.45)
	var roof := _flat(Color(0.74, 0.64, 0.5))
	var wood := _flat(Color(0.33, 0.22, 0.14))
	var dark := _flat(Color(0.07, 0.05, 0.04))
	# the hilltop it stands on, the trodden yard inside, and the road up to the gate
	_box(root, Vector3(0, -0.06, 0), Vector3(SPAN, 0.06, 9.0), earth)
	_box(root, Vector3(0, 0.0, 0), Vector3(FW, 0.012, FD), yard)
	_box(root, Vector3(GATE_X, 0.0, FD * 0.5 + 1.1), Vector3(0.5, 0.012, 2.2), yard)
	_box(root, Vector3(GATE_X - 0.9, 0.0, FD * 0.5 + 2.6), Vector3(0.5, 0.012, 2.6), yard, 0.75)
	# the wall: north, west and east whole, the south in two lengths with the gate between them
	var t := 0.46
	var h := 0.72
	_box(root, Vector3(0, 0, -FD * 0.5), Vector3(FW, h, t), stone)
	_box(root, Vector3(-FW * 0.5, 0, 0), Vector3(t, h, FD), stone)
	_box(root, Vector3(FW * 0.5, 0, 0), Vector3(t, h, FD), stone)
	var gl := GATE_X - 0.42
	var gr := GATE_X + 0.42
	_box(root, Vector3((-FW * 0.5 + gl) * 0.5, 0, FD * 0.5), Vector3(gl + FW * 0.5, h, t), stone)
	_box(root, Vector3((FW * 0.5 + gr) * 0.5, 0, FD * 0.5), Vector3(FW * 0.5 - gr, h, t), stone)
	for gx in [gl - 0.11, gr + 0.11]:          # the gate: two jambs standing proud of the wall, a timber lintel, the leaves open inward
		_box(root, Vector3(gx, 0, FD * 0.5), Vector3(0.24, h + 0.12, t + 0.16), stone)
	_box(root, Vector3(GATE_X, h - 0.02, FD * 0.5), Vector3(1.1, 0.13, t + 0.04), wood)
	_box(root, Vector3(gl + 0.06, 0, FD * 0.5 - 0.42), Vector3(0.05, h - 0.14, 0.42), wood)
	_box(root, Vector3(gr - 0.06, 0, FD * 0.5 - 0.42), Vector3(0.05, h - 0.14, 0.42), wood)
	for cx in [-1.0, 1.0]:                      # a tower at each corner, standing out from the wall
		for cz in [-1.0, 1.0]:
			_box(root, Vector3(cx * (FW * 0.5 + 0.1), 0, cz * (FD * 0.5 + 0.1)), Vector3(1.1, 1.08, 1.1), stone)
			_box(root, Vector3(cx * (FW * 0.5 + 0.1), 1.08, cz * (FD * 0.5 + 0.1)), Vector3(0.84, 0.012, 0.84), roof)
	# the hall against the north wall, its door to the yard lamplit; the storehouse against the east wall
	_box(root, Vector3(1.5, 0, -FD * 0.5 + t * 0.5 + 0.72), Vector3(3.3, 0.62, 1.44), stone)
	_box(root, Vector3(1.5, 0.62, -FD * 0.5 + t * 0.5 + 0.72), Vector3(3.14, 0.014, 1.3), roof)
	var glow := _flat(Color(1.0, 0.62, 0.28))
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(root, Vector3(1.0, 0, -FD * 0.5 + t * 0.5 + 1.445), Vector3(0.26, 0.4, 0.02), glow)
	_box(root, Vector3(FW * 0.5 - t * 0.5 - 0.5, 0, 1.0), Vector3(1.0, 0.48, 1.3), stone)
	_box(root, Vector3(FW * 0.5 - t * 0.5 - 0.5, 0.48, 1.0), Vector3(0.88, 0.014, 1.18), roof)
	_box(root, Vector3(FW * 0.5 - t * 0.5 - 1.01, 0, 1.0), Vector3(0.02, 0.32, 0.24), dark)
	var jar := CylinderMesh.new()
	jar.top_radius = 0.05
	jar.bottom_radius = 0.075
	jar.height = 0.19
	jar.radial_segments = 10
	for k in 3:
		var j := MeshInstance3D.new()
		j.mesh = jar
		j.material_override = _flat(Color(0.62, 0.4, 0.26))
		j.position = Vector3(FW * 0.5 - t * 0.5 - 1.2, 0.095, 0.5 + k * 0.2)
		root.add_child(j)
	# the cistern in the yard: a ring of stone and the dark of its mouth
	var ring := CylinderMesh.new()
	ring.top_radius = 0.3
	ring.bottom_radius = 0.33
	ring.height = 0.16
	ring.radial_segments = 20
	var rn := MeshInstance3D.new()
	rn.mesh = ring
	rn.material_override = stone
	rn.position = Vector3(CISTERN.x, 0.08, CISTERN.y)
	root.add_child(rn)
	var mouth := CylinderMesh.new()
	mouth.top_radius = 0.2
	mouth.bottom_radius = 0.2
	mouth.height = 0.165
	mouth.radial_segments = 20
	var mn := MeshInstance3D.new()
	mn.mesh = mouth
	mn.material_override = dark
	mn.position = Vector3(CISTERN.x, 0.0835, CISTERN.y)
	root.add_child(mn)
	# the town on the slope below, and a few trees: Gibeah was a town before it was a king's seat (Judges 19:14)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var house := _flat(Color(0.86, 0.77, 0.62))
	for k in 13:
		var at := Vector3(rng.randf_range(-7.2, -4.9), 0, rng.randf_range(0.6, 4.1))
		if k > 8:
			at = Vector3(rng.randf_range(4.9, 7.3), 0, rng.randf_range(1.6, 4.1))
		_box(root, at, Vector3(rng.randf_range(0.42, 0.7), rng.randf_range(0.26, 0.38), rng.randf_range(0.42, 0.7)), house, rng.randf() * 0.7)
	var tree := CylinderMesh.new()
	tree.top_radius = 0.0
	tree.bottom_radius = 0.16
	tree.height = 0.42
	tree.radial_segments = 6
	for k in 26:
		var tn := MeshInstance3D.new()
		tn.mesh = tree
		tn.material_override = _flat(Color(0.2, 0.26, 0.14))
		var p := Vector2(rng.randf_range(-7.6, 7.6), rng.randf_range(-4.2, 4.2))
		if absf(p.x) < FW * 0.5 + 0.9 and absf(p.y) < FD * 0.5 + 0.9:
			continue
		tn.position = Vector3(p.x, 0.21, p.y)
		tn.scale = Vector3.ONE * rng.randf_range(0.7, 1.3)
		root.add_child(tn)
	return {"heights": PackedFloat32Array(), "gw": 0, "gh": 0, "depth": 9.0, "node": root}


## Is there something here he could not reach before and can now?
func _reach_now(pl: Dictionary) -> bool:
	var later: Dictionary = pl.get("later", {})
	for sid in later:
		if not sid in Game.stones() and not sid in Game.places() and Game.has(later[sid]):
			return true
	return false


## Life on the ground: small dark trees wherever the land is green, and the towns as clusters of pale flat-roofed
## houses standing where they really stand.
func _decorate() -> void:
	var node: Node3D = grounds["hills"]["node"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var img: Image = (load("res://art/map_hills_ground.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var spots: Array = []
	for k in 14000:
		var u := rng.randf()
		var v := rng.randf()
		var c := img.get_pixel(int(u * (img.get_width() - 1)), int(v * (img.get_height() - 1)))
		if c.g > c.r * 0.9 and c.g > c.b * 1.3:      # green ground: olive and oak
			spots.append(_ground(Vector2((u - 0.5) * SPAN, (v - 0.5) * depth)))
	var tree := CylinderMesh.new()
	tree.top_radius = 0.0
	tree.bottom_radius = 0.5
	tree.height = 1.3
	tree.radial_segments = 6
	tree.rings = 1
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.2, 0.26, 0.14)
	tmat.roughness = 1.0
	tree.material = tmat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tree
	mm.instance_count = spots.size()
	for k in spots.size():
		var sc := rng.randf_range(0.035, 0.075)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), spots[k] + Vector3(0, sc * 0.6, 0)))
	var trees := MultiMeshInstance3D.new()
	trees.multimesh = mm
	node.add_child(trees)
	# the towns
	var house := BoxMesh.new()
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.9, 0.82, 0.68)
	hmat.roughness = 1.0
	house.material = hmat
	var homes: Array = []
	for tw in data["towns"]:
		if not "hills" in tw["views"]:
			continue
		var at := _world(tw["lat"], tw["lon"])
		for k in 16:
			var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.3)
			var g := _ground(Vector2(at.x + off.x, at.z + off.y))
			var sz := Vector3(rng.randf_range(0.07, 0.12), rng.randf_range(0.05, 0.09), rng.randf_range(0.07, 0.12))
			homes.append(Transform3D(Basis(Vector3.UP, rng.randf() * 0.6).scaled(sz), g + Vector3(0, sz.y * 0.5, 0)))
	var hm := MultiMesh.new()
	hm.transform_format = MultiMesh.TRANSFORM_3D
	hm.mesh = house
	hm.instance_count = homes.size()
	for k in homes.size():
		hm.set_instance_transform(k, homes[k])
	var town := MultiMeshInstance3D.new()
	town.multimesh = hm
	node.add_child(town)
