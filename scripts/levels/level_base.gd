extends Node2D
## Base for every section. A section script overrides _setup() (layout and
## palette), _populate() (things in the world) and begin() (opening story).

const D = preload("res://scripts/systems/draw_util.gd")
const Painter = preload("res://scripts/systems/painter.gd")
const Player = preload("res://scripts/player/player.gd")
const Sheep = preload("res://scripts/world/sheep.gd")
const Bush = preload("res://scripts/world/bush.gd")
const Target = preload("res://scripts/world/target.gd")
const Jackal = preload("res://scripts/enemies/jackal.gd")
const SkyShader = preload("res://shaders/sky.gdshader")
const FA = preload("res://scripts/systems/frame_anim.gd")
const Birds = preload("res://scripts/world/birds.gd")
const Flutter = preload("res://scripts/world/flutter.gd")
const Sway = preload("res://shaders/sway.gdshader")
const Boulder = preload("res://scripts/world/boulder.gd")
const DarkShader = preload("res://shaders/dark.gdshader")

const ART := 2.0     # painted props and scenery are stored at twice their size in game units

var section_idx := 0
var start_checkpoint := 0

var width := 4000.0
var mood := "pastures"        # which music plays here
var ambience := "pastures"    # which background sounds play here
var hints: Array = []
var mists: Array = []
var shaft_glows: Array = []
var flowers_at: Array = []
var props: Array = []         # things along the path that answer a blow or a brush past: [sprite, kind, lean, speed]
var birds := true            # distant flocks cross the sky
var flutters := 0            # butterflies or moths round the flowers
var flutter_tint := Color(1.0, 0.96, 0.82)
var leaves := Color(0, 0, 0, 0)    # drifting leaves or petals; transparent for none
var backdrop_art := ""        # painted far background image, optional
var midground_art := ""       # painted midground strip with transparency, optional
var mid_tint := Color(0.6, 0.56, 0.7)
var pal: Dictionary = {}
var segments: Array = []      # ground surfaces, each a PackedVector2Array left to right
var platforms: Array = []     # Rect2 ledges
var checkpoints: Array = []   # x positions; index 0 is the start

var player
var boss = null
var boss_name := ""
var sheep_total := 0
var sheep_count := 0
var followers: Array = []
var cp_index := 0
var cp_fires: Array = []
var cp_cairns: Array = []
var triggers: Array = []
var layers: Array = []
var motes: CPUParticles2D
var leaf_fall: CPUParticles2D
var respawning := false
var done := false
var rng := RandomNumberGenerator.new()
var gift_spots: Array = []    # where a gift waits: {id, x, ready, wait, node, near}
var caves: Array = []         # side caves: rooms off the path, built far beyond the level's end and entered through a cave mouth
var in_cave = null
var finds: Array = []         # places off the path, not yet come upon: {id, at, name, craft, glow}
var keepsakes: Array = []     # smooth stones still lying here: [node, id]
var ambush := {}              # a pack closing in: walls, beasts and the trigger that starts it
var tasks: Array = []         # places where he does something with his hands by holding the grab key
var task_label: Label
var task_now = null
var pushables: Array = []     # heavy things he can lean on and move
var push_t := 0.0             # above zero while he is shoving one of them along
var dark: ColorRect           # darkness over the scene, with pools of light cut out of it
var dark_amount := 0.0
var lights: Array = []        # each {"pos": Vector2, "r": radius in game units}
var torch_max := 0.0          # seconds a torch burns; 0 means this section has none
var torch_t := 0.0
var draught := 1.0            # how fast the torch burns just now
var torch_node: Node2D
var player_light := 0.0       # the pool of light he carries, set each frame
var barren := false           # a cave or bare rock: no flowers or grass along the path


func _setup() -> void:
	pass


func _populate() -> void:
	pass


## Opening story for the section. Called once the screen has faded in.
func begin() -> void:
	pass


func _on_respawn() -> void:
	pass


func _ready() -> void:
	rng.seed = 7 + section_idx * 101
	pal = {
		"sky_top": Color(0.25, 0.35, 0.6), "sky_mid": Color(0.95, 0.65, 0.4), "sky_bot": Color(1.0, 0.86, 0.6),
		"sun_pos": Vector2(0.72, 0.52), "sun_col": Color(1.0, 0.92, 0.7), "sun_size": 0.07, "stars": 0.0,
		"far": Color(0.9, 0.6, 0.45), "near": Color(0.3, 0.22, 0.3), "rim": Color(1.0, 0.8, 0.5),
		"wool": Color(0.97, 0.9, 0.78), "mote": Color(1.0, 0.9, 0.6, 0.5),
	}
	_setup()
	if backdrop_art != "" and ResourceLoader.exists(backdrop_art):
		_build_painted()
	else:
		backdrop_art = ""
		_build_sky()
		_build_hills()
	_build_ground()
	_build_platforms()
	_build_bounds()
	_spawn_player()
	_build_checkpoints()
	_populate()
	_build_motes()
	_build_atmosphere()
	_build_life()
	_build_foreground()


# ---------------------------------------------------------------- terrain data

## Rolling ground between x0 and x1. Both ends sit exactly at `base`.
func make_ground(x0: float, x1: float, base: float, amp: float = 14.0, phase: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := x0
	while true:
		var u := (x - x0) / (x1 - x0)
		var window := smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.88, u)
		var y := base + (sin(x * 0.004 + phase) + sin(x * 0.011 + phase * 2.3) * 0.4) * amp * window
		pts.append(Vector2(x, y))
		if x >= x1:
			break
		x = minf(x + 40.0, x1)
	return pts


func ground_y(x: float) -> float:
	for seg in segments:
		var n: int = seg.size()
		if x >= seg[0].x and x <= seg[n - 1].x:
			for i in range(1, n):
				if x <= seg[i].x:
					var a: Vector2 = seg[i - 1]
					var b: Vector2 = seg[i]
					return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return NAN


func on_ground(x: float) -> Vector2:
	var y := ground_y(x)
	return Vector2(x, 560.0 if is_nan(y) else y)


## A ledge `up` pixels above the ground under it.
func ledge(x: float, up: float, w: float, h: float = 26.0) -> Rect2:
	var r := Rect2(x, on_ground(x + w * 0.5).y - up, w, h)
	platforms.append(r)
	return r


# -------------------------------------------------------------------- building

func _build_sky() -> void:
	var cl := CanvasLayer.new()
	cl.layer = -10
	add_child(cl)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SkyShader
	m.set_shader_parameter("top_color", pal["sky_top"])
	m.set_shader_parameter("mid_color", pal["sky_mid"])
	m.set_shader_parameter("bottom_color", pal["sky_bot"])
	m.set_shader_parameter("sun_pos", pal["sun_pos"])
	m.set_shader_parameter("sun_color", pal["sun_col"])
	m.set_shader_parameter("sun_size", pal["sun_size"])
	m.set_shader_parameter("stars", pal["stars"])
	rect.material = m
	cl.add_child(rect)


func _build_hills() -> void:
	var scales := [0.07, 0.18, 0.36, 0.6]
	for i in scales.size():
		var s: float = scales[i]
		var k := float(i) / float(scales.size() - 1)
		var col: Color = pal["far"].lerp(pal["near"], k)
		var base := 330.0 + k * 150.0
		var amp := 60.0 - k * 22.0
		var ph := rng.randf() * 20.0
		var freq := 0.0016 + k * 0.0012
		var x1 := width * s + 760.0
		var pts := PackedVector2Array()
		var trees: Array = []
		var x := -760.0
		while x <= x1:
			var y := base + sin(x * freq + ph) * amp + sin(x * freq * 2.7 + ph * 1.7) * amp * 0.35
			pts.append(Vector2(x, y))
			if i >= 1 and rng.randf() < 0.1 + k * 0.08:
				trees.append([Vector2(x, y), rng.randf_range(0.6, 1.2) * (0.45 + k * 0.75), rng.randf() < 0.45])
			x += 28.0
		pts.append(Vector2(x1, 1200.0))
		pts.append(Vector2(-760.0, 1200.0))
		var p := Painter.new()
		p.z_index = -50 + i
		p.paint = func(ci: CanvasItem) -> void:
			ci.draw_colored_polygon(pts, col)
			for tr in trees:
				_paint_tree(ci, tr[0], tr[1], tr[2], col)
		add_child(p)
		layers.append({"node": p, "s": s})


## Painted scenery: a far backdrop painting and an optional midground strip
## (tiled, mirrored every other tile so the joins match).
func _build_painted() -> void:
	var far := Node2D.new()
	far.z_index = -50
	var bg := Sprite2D.new()
	bg.texture = load(backdrop_art)
	bg.centered = false
	var need := 1280.0 + 0.06 * width + 80.0
	var sc := maxf(need / bg.texture.get_width(), 900.0 / bg.texture.get_height())
	bg.scale = Vector2(sc, sc)
	bg.position = Vector2(-620.0, -90.0)
	far.add_child(bg)
	add_child(far)
	layers.append({"node": far, "s": 0.06})

	if midground_art != "" and ResourceLoader.exists(midground_art):
		var mid := Node2D.new()
		mid.z_index = -40
		# pushed back in tone so David and the flock stand out in front of it
		mid.modulate = mid_tint
		var tex: Texture2D = load(midground_art)
		var msc := 0.75 * 1280.0 / tex.get_width()
		var tile_w := tex.get_width() * msc
		var x := -400.0
		var flip := false
		while x < 0.4 * width + 700.0:
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.flip_h = flip
			sp.scale = Vector2(msc, msc)
			sp.position = Vector2(x, 96.0)
			mid.add_child(sp)
			x += tile_w - 1.0
			flip = not flip
		add_child(mid)
		layers.append({"node": mid, "s": 0.4})


func _paint_tree(ci: CanvasItem, at: Vector2, sc: float, cypress: bool, col: Color) -> void:
	if cypress:
		D.ellipse(ci, at + Vector2(0, -44.0 * sc), 9.0 * sc, 48.0 * sc, col)
	else:
		ci.draw_line(at + Vector2(0, 4), at + Vector2(3.0 * sc, -30.0 * sc), col, 6.0 * sc, true)
		ci.draw_circle(at + Vector2(-12.0 * sc, -40.0 * sc), 17.0 * sc, col)
		ci.draw_circle(at + Vector2(10.0 * sc, -46.0 * sc), 20.0 * sc, col)
		ci.draw_circle(at + Vector2(24.0 * sc, -34.0 * sc), 13.0 * sc, col)


func _build_ground() -> void:
	# darkness inside the gaps between stretches of ground, so a pit reads as depth
	for i in range(1, segments.size()):
		var a: Vector2 = segments[i - 1][segments[i - 1].size() - 1]
		var b: Vector2 = segments[i][0]
		if b.x - a.x > 20.0:
			var pit := Polygon2D.new()
			var top := minf(a.y, b.y) + 26.0
			pit.polygon = PackedVector2Array([Vector2(a.x - 4, top), Vector2(b.x + 4, top), Vector2(b.x + 4, 1300), Vector2(a.x - 4, 1300)])
			pit.vertex_colors = PackedColorArray([Color(0.03, 0.02, 0.06, 0.0), Color(0.03, 0.02, 0.06, 0.0), Color(0.03, 0.02, 0.06, 1.0), Color(0.03, 0.02, 0.06, 1.0)])
			pit.z_index = 0
			add_child(pit)
			var deep := Polygon2D.new()
			deep.polygon = PackedVector2Array([Vector2(a.x - 4, top + 70), Vector2(b.x + 4, top + 70), Vector2(b.x + 4, 1300), Vector2(a.x - 4, 1300)])
			deep.color = Color(0.03, 0.02, 0.06)
			deep.z_index = 0
			add_child(deep)
	for seg in segments:
		var poly := PackedVector2Array(seg)
		poly.append(Vector2(seg[seg.size() - 1].x, 1300.0))
		poly.append(Vector2(seg[0].x, 1300.0))
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cp := CollisionPolygon2D.new()
		cp.polygon = poly
		body.add_child(cp)
		add_child(body)

		_skin_ground(poly, seg)
		_dress(seg)


func _dress(seg: PackedVector2Array) -> void:
	if not ResourceLoader.exists("res://art/props/d_flowers.png"):
		return
	var back := ["d_boulder", "d_shrub", "d_log", "d_grass", "d_stones", "d_flowers"]
	var front := ["d_flowers", "d_grass", "d_stones"]
	if barren:      # bare rock: nothing grows here
		back = ["d_boulder", "d_stones", "d_stones"]
		front = ["d_stones"]
	var tint: Color = pal.get("char", Color(1, 1, 1))
	var x: float = seg[0].x + rng.randf_range(60.0, 200.0)
	var x_end: float = seg[seg.size() - 1].x - 60.0
	while x < x_end:
		var in_front := rng.randf() < 0.3
		var list: Array = front if in_front else back
		var kind: String = list[rng.randi() % list.size()]
		var sp := Sprite2D.new()
		sp.texture = load("res://art/props/%s.png" % kind)
		sp.centered = false
		sp.offset = Vector2(-sp.texture.get_width() * 0.5, -sp.texture.get_height())
		if kind in ["d_flowers", "d_grass", "d_shrub"]:
			sp.material = _sway(0.05 if kind != "d_shrub" else 0.02, rng.randf_range(1.1, 1.6))
		if kind == "d_flowers":
			flowers_at.append(Vector2(x, ground_y(x) - 20.0))
		props.append([sp, kind, 0.0, 0.0])
		var sc := rng.randf_range(0.45, 0.8) / ART
		sp.scale = Vector2(sc * (-1.0 if rng.randf() < 0.5 else 1.0), sc)
		sp.position = Vector2(x, ground_y(x) + 6.0)
		sp.z_index = 7 if in_front else 1
		sp.modulate = tint if not in_front else Color(tint.r * 0.75, tint.g * 0.72, tint.b * 0.8)
		add_child(sp)
		x += rng.randf_range(150.0, 420.0)


## Draws a piece of ground. With painted textures present it gets rock,
## depth shading and a grass edge; otherwise the flat silhouette look.
func _skin_ground(poly: PackedVector2Array, top: PackedVector2Array, parent: Node = null, z: int = 2) -> void:
	if parent == null:
		parent = self
	var rock_path := "res://art/ground_rock.png"
	var grass_path := "res://art/ground_grass.png"
	var painted := ResourceLoader.exists(rock_path) and ResourceLoader.exists(grass_path)

	var vis := Polygon2D.new()
	vis.polygon = poly
	vis.z_index = z
	if painted:
		vis.texture = load(rock_path)
		vis.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		vis.texture_scale = Vector2(1.6, 1.6) * (vis.texture.get_width() / 1280.0)
		vis.color = pal.get("ground", Color(0.62, 0.56, 0.66))
	else:
		vis.color = Game.INK
	parent.add_child(vis)

	if not painted:
		var rim := Line2D.new()
		rim.points = top
		rim.width = 2.5
		rim.default_color = Color(pal["rim"].r, pal["rim"].g, pal["rim"].b, 0.55)
		rim.z_index = z
		parent.add_child(rim)
		var tufts: Array = []
		var x: float = top[0].x + 6.0
		while x < top[top.size() - 1].x - 6.0:
			var ty := 0.0
			for i in range(1, top.size()):
				if x <= top[i].x:
					ty = lerpf(top[i - 1].y, top[i].y, (x - top[i - 1].x) / maxf(top[i].x - top[i - 1].x, 0.001))
					break
			tufts.append([Vector2(x, ty), rng.randf_range(5.0, 15.0), rng.randf_range(-0.5, 0.5)])
			x += rng.randf_range(7.0, 20.0)
		var g := Painter.new()
		g.z_index = 6
		g.paint = func(ci: CanvasItem) -> void:
			for tf in tufts:
				var b: Vector2 = tf[0]
				ci.draw_line(b + Vector2(0, 2), b + Vector2(tf[2] * 8.0, -tf[1]), Game.INK, 2.0, true)
		parent.add_child(g)
		return

	# darken with depth so the surface reads as lit and the earth below as shadow
	var lo := INF
	var hi := -INF
	for p in poly:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var shade := Polygon2D.new()
	shade.polygon = poly
	var cols := PackedColorArray()
	for p in poly:
		var d := clampf((p.y - lo) / 150.0, 0.0, 1.0)
		cols.append(Color(0.03, 0.02, 0.06, 0.15 + d * 0.8))
	shade.vertex_colors = cols
	shade.z_index = z
	parent.add_child(shade)

	if not barren:
		_grass_edge(top, parent)


func _grass_edge(top: PackedVector2Array, parent: Node) -> void:
	var grass_path := "res://art/ground_grass.png"
	if not ResourceLoader.exists(grass_path):
		return
	# the turf runs a little past each end and thins out there, so it never stops on a straight cut
	var over := 20.0
	var ends := PackedVector2Array(top)
	var m := ends.size()
	ends[0] = ends[0] + (ends[0] - ends[1]).normalized() * over
	ends[m - 1] = ends[m - 1] + (ends[m - 1] - ends[m - 2]).normalized() * over
	# the fade is set per point, so a short straight ledge needs points along its length
	var pts := PackedVector2Array([ends[0]])
	for i in range(1, m):
		var steps := maxi(1, int(ends[i].distance_to(ends[i - 1]) / 16.0))
		for k in range(1, steps + 1):
			pts.append(ends[i - 1].lerp(ends[i], float(k) / steps))
	var n := pts.size()
	var length := 0.0
	for i in range(1, n):
		length += pts[i].distance_to(pts[i - 1])
	var col: Color = pal.get("grass", Color(1, 1, 1))
	var clear := Color(col.r, col.g, col.b, 0.0)
	var fade := clampf(46.0 / maxf(length, 1.0), 0.0, 0.45)
	var ramp := Gradient.new()
	ramp.set_color(0, clear)
	ramp.set_color(1, clear)
	ramp.add_point(fade, col)
	ramp.add_point(1.0 - fade, col)
	var grass := Line2D.new()
	grass.points = pts
	grass.width = 58.0
	grass.texture = load(grass_path)
	grass.texture_mode = Line2D.LINE_TEXTURE_TILE
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.joint_mode = Line2D.LINE_JOINT_ROUND
	grass.gradient = ramp
	grass.material = _sway(0.004, 1.2, 9.0)
	grass.z_index = 3
	parent.add_child(grass)
	# loose tufts over the ends break the outline further
	if ResourceLoader.exists("res://art/props/d_grass.png"):
		for at in [top[0] + Vector2(16, 0), top[top.size() - 1] - Vector2(16, 0)]:
			var tuft := Sprite2D.new()
			tuft.texture = load("res://art/props/d_grass.png")
			tuft.centered = false
			tuft.offset = Vector2(-tuft.texture.get_width() * 0.5, -tuft.texture.get_height())
			var sc := rng.randf_range(0.2, 0.3) / ART
			tuft.scale = Vector2(sc * (-1.0 if rng.randf() < 0.5 else 1.0), sc)
			tuft.position = at + Vector2(rng.randf_range(-6.0, 6.0), 8.0)
			tuft.modulate = col
			tuft.material = _sway(0.05, rng.randf_range(1.1, 1.6))
			tuft.z_index = 3
			parent.add_child(tuft)


func _sway(amp: float, speed: float = 1.3, ripple: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Sway
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("ripple", ripple)
	return m


func _build_platforms() -> void:
	for r in platforms:
		add_block(r)


## Solid rock ledge. Returns the body so it can be removed later.
func add_block(r: Rect2, visible_rock: bool = true) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
	if visible_rock:
		var hw := r.size.x * 0.5
		var hh := r.size.y * 0.5
		var shape := PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw - 6.0, hh * 0.4),
			Vector2(hw * 0.5, hh + 9.0), Vector2(-hw * 0.4, hh + 5.0), Vector2(-hw + 5.0, hh * 0.3)])
		var top_line := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh)])
		if _outcrop(r):
			if r.position.x < width:      # nothing grows on a ledge underground
				_grass_edge(top_line, body)
		else:
			_skin_ground(shape, top_line, body, 2)
	return body


## Rock rising from the ground up to a ledge, so the ledge is the top of an
## outcrop instead of floating. It stands behind the path: David walks past it.
func _outcrop(r: Rect2) -> bool:
	var cx := r.position.x + r.size.x * 0.5
	var gy := ground_y(cx)
	if is_nan(gy):
		return false
	var h := gy - r.position.y
	if h < 40.0 or not ResourceLoader.exists("res://art/props/rock_mid.png"):
		return false
	# pick the painted rock whose proportions are closest to this ledge
	var ratio := h / r.size.x
	var which := "rock_low" if ratio < 0.55 else ("rock_mid" if ratio < 1.25 else "rock_tall")
	var sp := Sprite2D.new()
	sp.texture = load("res://art/props/%s.png" % which)
	sp.centered = false
	var w := r.size.x + 46.0
	var full_h := h + 34.0
	sp.scale = Vector2(w / sp.texture.get_width(), full_h / sp.texture.get_height())
	sp.position = Vector2(cx - w * 0.5, r.position.y - 7.0)
	sp.z_index = 1
	sp.flip_h = rng.randf() < 0.5
	sp.modulate = pal.get("char", Color(1, 1, 1))
	add_child(sp)
	return true


func add_wall(x: float) -> StaticBody2D:
	return add_block(Rect2(x - 12.0, -1400.0, 24.0, 2800.0), false)


func _build_bounds() -> void:
	add_wall(-12.0)
	add_wall(width + 12.0)


func _spawn_player() -> void:
	if checkpoints.is_empty():
		checkpoints = [160.0]
	cp_index = clampi(start_checkpoint, 0, checkpoints.size() - 1)
	player = Player.new()
	player.level = self
	player.tint = pal.get("char", Color(1, 1, 1))
	player.position = on_ground(checkpoints[cp_index])
	add_child(player)
	player.cam.limit_left = 0
	player.cam.limit_right = int(width)
	player.cam.limit_bottom = 720
	player.cam.limit_top = -700
	player.cam.reset_smoothing()
	player.died.connect(respawn)


## Watchfires mark the checkpoints. They light as David reaches them.
func _build_checkpoints() -> void:
	for i in checkpoints.size():
		if i == 0:
			cp_fires.append(null)
			cp_cairns.append(null)
			continue
		var at := on_ground(checkpoints[i])
		var lit: bool = i <= cp_index
		var cairn := add_sprite("res://art/props/cairn.png", at + Vector2(0, 6), 0.42, 3, Color(1, 1, 1) if lit else Color(0.4, 0.4, 0.5))
		cp_cairns.append(cairn)
		var fire := Game.glow(Color(1.0, 0.6, 0.25, 0.9), 150.0)
		fire.position = at + Vector2(0, -52)
		fire.z_index = 3
		fire.visible = i <= cp_index
		add_child(fire)
		fire.add_child(_flames())
		cp_fires.append(fire)


func _build_motes() -> void:
	motes = CPUParticles2D.new()
	motes.texture = Game.glow_tex
	motes.material = Game.add_mat
	motes.amount = 46
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(760, 400)
	motes.direction = Vector2(1, -0.3)
	motes.spread = 180.0
	motes.gravity = Vector2(0, -3)
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 20.0
	motes.scale_amount_min = 0.05
	motes.scale_amount_max = 0.16
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 1))
	motes.color_ramp = ramp
	motes.color = pal["mote"]
	motes.z_index = 7
	motes.position = player.position + Vector2(0, -200)
	add_child(motes)


## The staff has swung through `at`. Whatever stands there answers: plants whip over and shed petals or
## seed, stones jolt and throw dust and chips, a log jumps and sheds bark. Returns true if anything was struck.
func strike(at: Vector2, dir: int, reach: float = 46.0) -> bool:
	var any := false
	for pr in props:
		var sp: Sprite2D = pr[0]
		if not is_instance_valid(sp) or absf(sp.position.x - at.x) > reach or absf(sp.position.y - at.y) > 110.0:
			continue
		any = true
		var kind: String = pr[1]
		var top := sp.position + Vector2(0, -sp.texture.get_height() * absf(sp.scale.y) * 0.6)
		match kind:
			"d_flowers":
				pr[3] = dir * 9.0
				Game.burst(self, top, Color(0.95, 0.3, 0.25, 0.9), 9, 150.0)
				Game.burst(self, top, Color(1.0, 0.85, 0.3, 0.9), 6, 120.0)
				Game.sfx("step", -9.0, 0.3)
			"d_grass", "d_shrub":
				pr[3] = dir * (10.0 if kind == "d_grass" else 6.0)
				Game.burst(self, top, Color(0.85, 0.8, 0.5, 0.8) if kind == "d_grass" else Color(0.55, 0.7, 0.45, 0.8), 10, 140.0)
				Game.sfx("step", -8.0, 0.3)
			"d_log":
				pr[3] = dir * 2.2
				_jolt(sp, 5.0)
				Game.burst(self, top, Color(0.55, 0.4, 0.28, 0.85), 9, 150.0)
				Game.sfx("hit", -9.0, 0.12)
			_:      # boulders and loose stones
				pr[3] = dir * 1.0
				_jolt(sp, 3.0)
				Game.burst(self, top, Color(0.85, 0.8, 0.7, 0.7), 8, 130.0)
				Game.burst(self, sp.position + Vector2(0, -4), Color(0.75, 0.68, 0.55, 0.5), 6, 70.0)
				Game.sfx("hit", -11.0, 0.1)        # a dull knock on stone, not a clink
	return any


## A short hop in place, for something heavy that has been knocked.
func _jolt(sp: Sprite2D, lift: float) -> void:
	var rest := sp.position
	var tw := create_tween()
	tw.tween_property(sp, "position", rest + Vector2(0, -lift), 0.05)
	tw.tween_property(sp, "position", rest, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Flames and rising sparks for a watchfire. Drawn in the fire's own space, so it hides and shows with it.
func _flames() -> Node2D:
	var holder := Node2D.new()
	holder.scale = Vector2.ONE * (128.0 / 150.0)
	for spark in [false, true]:
		var f := CPUParticles2D.new()
		f.texture = Game.glow_tex
		f.material = Game.add_mat
		f.amount = 10 if spark else 26
		f.lifetime = 1.6 if spark else 0.7
		f.position = Vector2(0, 26)
		f.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		f.emission_sphere_radius = 9.0
		f.direction = Vector2(0, -1)
		f.spread = 22.0 if spark else 12.0
		f.gravity = Vector2(0, -60.0 if spark else -90.0)
		f.initial_velocity_min = 30.0 if spark else 18.0
		f.initial_velocity_max = 80.0 if spark else 44.0
		f.scale_amount_min = 0.02 if spark else 0.16
		f.scale_amount_max = 0.05 if spark else 0.3
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.9, 0.55, 0.0))
		ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
		ramp.add_point(0.15, Color(1.0, 0.8, 0.4, 0.9))
		ramp.add_point(0.6, Color(1.0, 0.45, 0.12, 0.6))
		f.color_ramp = ramp
		holder.add_child(f)
	return holder


## Living things and loose things in the air: birds far off, butterflies at the flowers, leaves on the wind.
func _build_life() -> void:
	if birds:
		var b := Birds.new()
		b.z_index = -45
		b.span = 1280.0 + 0.12 * width + 400.0
		b.tint = pal.get("bird", Color(0.08, 0.06, 0.1, 0.7))
		add_child(b)
		layers.append({"node": b, "s": 0.12})
	if flutters > 0 and not flowers_at.is_empty():
		for i in flutters:
			var f := Flutter.new()
			f.position = flowers_at[rng.randi() % flowers_at.size()] + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-50.0, 0.0))
			f.wing = flutter_tint.lerp(Color(1.0, 0.8, 0.35), rng.randf() * 0.6)
			add_child(f)
	if leaves.a > 0.0:
		var img := Image.create(24, 12, false, Image.FORMAT_RGBA8)
		for y in 12:
			for x in 24:
				var d := Vector2((x - 11.5) / 12.0, (y - 5.5) / 6.0).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
		leaf_fall = CPUParticles2D.new()
		leaf_fall.texture = ImageTexture.create_from_image(img)
		leaf_fall.amount = 14
		leaf_fall.lifetime = 9.0
		leaf_fall.preprocess = 9.0
		leaf_fall.local_coords = false
		leaf_fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		leaf_fall.emission_rect_extents = Vector2(820, 40)
		leaf_fall.direction = Vector2(1, 0.5)
		leaf_fall.spread = 25.0
		leaf_fall.gravity = Vector2(14, 22)
		leaf_fall.initial_velocity_min = 30.0
		leaf_fall.initial_velocity_max = 75.0
		leaf_fall.angular_velocity_min = -160.0
		leaf_fall.angular_velocity_max = 160.0
		leaf_fall.angle_max = 360.0
		leaf_fall.scale_amount_min = 0.35
		leaf_fall.scale_amount_max = 0.7
		leaf_fall.color = leaves
		leaf_fall.z_index = 7
		add_child(leaf_fall)


## Drifting mist near the ground and slanting shafts of light: the air of the place.
func _build_atmosphere() -> void:
	var mist_col: Color = pal.get("mist", Color(1.0, 0.95, 0.85, 0.07))
	var holder := Node2D.new()
	holder.z_index = 8
	add_child(holder)
	for i in 7:
		var m := Game.glow(mist_col, 128.0)
		m.scale = Vector2(rng.randf_range(7.0, 12.0), rng.randf_range(1.0, 1.9))
		m.position = Vector2(rng.randf_range(0.0, 2200.0), rng.randf_range(430.0, 600.0))
		holder.add_child(m)
		mists.append([m, rng.randf_range(6.0, 16.0)])
	layers.append({"node": holder, "s": 0.82})
	if pal.has("shafts"):
		var shafts := Node2D.new()
		shafts.z_index = -30
		add_child(shafts)
		var sc: Color = pal["shafts"]
		var n := int(width * 0.5 / 380.0) + 4
		for i in n:
			var sh := Game.glow(sc, 128.0)
			sh.scale = Vector2(rng.randf_range(0.7, 1.5), 9.0)
			sh.rotation = 0.5 + rng.randf_range(-0.06, 0.06)
			sh.position = Vector2(-300.0 + i * 380.0 + rng.randf_range(-90.0, 90.0), 250.0)
			shafts.add_child(sh)
			shaft_glows.append([sh, sc.a, rng.randf() * TAU, rng.randf_range(0.15, 0.4)])
		layers.append({"node": shafts, "s": 0.5})


## Dark grass close to the camera, out of focus and moving in the wind, for depth.
func _build_foreground() -> void:
	var holder := Node2D.new()
	holder.z_index = 20
	var path := "res://art/props/d_grass.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var x := -200.0
		while x < width * 1.4 + 400.0:
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
			var sc := rng.randf_range(0.8, 1.35) / ART
			sp.scale = Vector2(sc * (-1.0 if rng.randf() < 0.5 else 1.0), sc * rng.randf_range(0.7, 1.0))
			sp.position = Vector2(x, 748.0)
			sp.modulate = Color(0.035, 0.03, 0.06, 0.96)
			sp.material = _sway(0.07, rng.randf_range(0.9, 1.4))
			holder.add_child(sp)
			x += rng.randf_range(220.0, 640.0)
	add_child(holder)
	layers.append({"node": holder, "s": 1.4, "flat": true})


# --------------------------------------------------------------- placing things

func add_sheep(x: float, pos = null, lamb: bool = false):
	var s = Sheep.new()
	s.level = self
	s.wool = pal["wool"]
	s.size = 0.68 if lamb else 1.0
	s.face = -1.0 if rng.randf() < 0.5 else 1.0
	s.position = pos if pos != null else on_ground(x)
	add_child(s)
	sheep_total += 1
	return s


func add_bush(x: float) -> void:
	var b = Bush.new()
	b.position = on_ground(x)
	add_child(b)


func add_jackal(x: float, x0: float, x1: float):
	var j = Jackal.new()
	j.level = self
	j.player = player
	j.min_x = x0
	j.max_x = x1
	j.position = on_ground(x)
	add_child(j)
	return j


## Something worth telling the player at this spot. It is shown small, by David's head, only while he is
## near, and only until it has been read: after a few seconds on screen it is never shown again.
## Write it as "KEY  what it does" (two spaces) to have the key drawn as a key-cap, or as a few plain words.
func add_hint(x: float, _up: float, text: String) -> Dictionary:
	var h := {"x": x, "text": text, "on": true}
	hints.append(h)
	return h


func add_glow(pos: Vector2, color: Color, size: float) -> Sprite2D:
	var g := Game.glow(color, size)
	g.position = pos
	g.z_index = 3
	add_child(g)
	return g


## Large silhouette tree just behind the path.
func add_tree(x: float, sc: float = 1.0, cypress: bool = false) -> void:
	if backdrop_art != "":
		return   # painted sections carry their own trees
	var col: Color = Game.INK.lerp(pal["near"], 0.45)
	var p := Painter.new()
	p.position = on_ground(x) + Vector2(0, 6)
	p.z_index = 1
	p.paint = func(ci: CanvasItem) -> void:
		_paint_tree(ci, Vector2.ZERO, sc * 2.6, cypress, col)
	add_child(p)


## A painted prop standing on the ground: `at` is its bottom centre.
func add_sprite(path: String, at: Vector2, sc: float, z: int = 3, tint: Color = Color(1, 1, 1)) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.centered = false
	sp.offset = Vector2(-sp.texture.get_width() * 0.5, -sp.texture.get_height())
	sp.scale = Vector2(sc, sc) / ART
	sp.position = at
	sp.z_index = z
	sp.modulate = tint
	add_child(sp)
	return sp


## A living painted figure standing on the ground, gently moving. `at` is at its feet.
func add_actor(who: String, at: Vector2, sc: float, z: int = 3, tint: Color = Color(1, 1, 1), flip: bool = false) -> Node2D:
	var frames: Array = FA.frames(who, "idle")
	# Each figure drifts between moments of its footage and rests in between,
	# at its own irregular pace, so nobody visibly loops.
	var st := {"pos": float(rng.randi() % frames.size()), "target": float(rng.randi() % frames.size()), "wait": rng.randf_range(0.5, 3.0)}
	var p := Painter.new()
	p.position = at
	p.z_index = z
	p.animated = true
	p.paint = func(ci: CanvasItem) -> void:
		var dt := ci.get_process_delta_time()
		if st["wait"] > 0.0:
			st["wait"] -= dt
		elif absf(st["pos"] - st["target"]) < 0.5:
			st["wait"] = randf_range(1.5, 5.0)
			st["target"] = float(randi() % frames.size())
		else:
			st["pos"] = move_toward(st["pos"], st["target"], dt * 8.0)
		if st.has("act"):        # a staged action replaces the idle drift and holds on its last frame
			var act: Array = st["act"]
			st["act_t"] += dt
			var shot: Texture2D = act[mini(int(st["act_t"] * st["act_fps"]), act.size() - 1)]
			FA.shadow(ci, 46.0, 0.9)
			FA.draw(ci, shot, st["act_face"], st["act_sc"], tint, st["act_tall"])
			return
		var tex: Texture2D = frames[clampi(int(st["pos"]), 0, frames.size() - 1)]
		FA.shadow(ci, tex.get_width() * sc * 0.8, 0.9)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-sc if flip else sc, sc))
		ci.draw_texture(tex, Vector2(-tex.get_width() * 0.5, -tex.get_height()), tint)
	p.set_meta("st", st)
	add_child(p)
	return p


## Has a figure placed with add_actor perform a frame set once (cut with tools/anim.py), then hold its last frame.
func actor_play(actor: Node2D, who: String, set_name: String, fps: float, facing: float = 1.0, sc: float = 1.0, tall: float = 1.4) -> void:
	var act: Array = FA.frames(who, set_name)
	if act.is_empty():
		return
	var st: Dictionary = actor.get_meta("st")
	st["act"] = act
	st["act_t"] = 0.0
	st["act_fps"] = fps
	st["act_face"] = facing
	st["act_sc"] = sc
	st["act_tall"] = tall


func add_painter(pos: Vector2, z: int, fn: Callable, animated: bool = false) -> Node2D:
	var p := Painter.new()
	p.position = pos
	p.z_index = z
	p.paint = fn
	p.animated = animated
	add_child(p)
	return p


## A smooth stone, hidden off the path. Each one found sharpens his eye; they are kept for good.
func add_stone(id: String, pos: Vector2) -> void:
	if id in Game.stones() or Game.backdrop:
		return
	var glow := add_glow(pos + Vector2(0, -10), Color(1.0, 0.95, 0.8, 0.4), 90.0)
	var node := Sprite2D.new()      # painted, like the stones along the path, and lit like them
	node.texture = load("res://art/props/smooth_stone.png")
	node.scale = Vector2(0.19, 0.19)
	node.offset = Vector2(0, -node.texture.get_height() * 0.5)
	node.position = pos
	node.z_index = 4
	node.modulate = Color(1, 1, 1).lerp(pal.get("char", Color(1, 1, 1)), 0.55) * 1.25
	add_child(node)
	var tw := create_tween().set_loops()       # a slow breath of light, so the eye finds it
	tw.tween_property(glow, "modulate:a", 0.35, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE)
	keepsakes.append([node, id, glow, tw])


## A place where a gift waits: a shaft of light standing on the ground, faint until he has done what is asked
## of him there (`ready` returns true), then bright. Walking into it when it is bright gives the gift.
func add_gift(id: String, x: float, ready: Callable, wait: String = "") -> void:
	if Game.backdrop or Game.has(id):
		return
	var g := {"id": id, "x": x, "ready": ready, "wait": wait, "near": false, "lit": 0.28, "node": null}
	g["node"] = _light_shaft(on_ground(x), g)
	gift_spots.append(g)


func _light_shaft(at: Vector2, g: Dictionary) -> Node2D:
	var tm := {"t": 0.0}
	var shaft := _shaft_painter(at, g, tm)
	shaft.material = Game.add_mat
	return shaft


func _shaft_painter(at: Vector2, g: Dictionary, tm: Dictionary) -> Node2D:
	return add_painter(at, 2, func(ci: CanvasItem) -> void:
		tm["t"] += 1.0 / 60.0
		var a: float = g["lit"]
		var breath := 0.85 + 0.15 * sin(tm["t"] * 1.7)
		for k in 5:          # a column of light, soft at its edges, fading upward
			var hw := 34.0 - k * 6.0
			var col := Color(1.0, 0.88, 0.58, 0.075 * a * breath)
			var top := Color(1.0, 0.88, 0.58, 0.0)
			ci.draw_polygon(PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw * 0.7, -520), Vector2(-hw * 0.7, -520)]), PackedColorArray([col, col, top, top]))
		ci.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.22))
		ci.draw_circle(Vector2.ZERO, 46.0, Color(1.0, 0.9, 0.6, 0.16 * a))
		ci.draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.6, 0.5 * a * breath), 2.0, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k in 7:          # motes rising in it
			var u := fmod(tm["t"] * 0.22 + k * 0.143, 1.0)
			ci.draw_circle(Vector2(sin(k * 2.4 + tm["t"] * 0.8) * 20.0, -u * 300.0), 1.8, Color(1.0, 0.95, 0.75, 0.7 * a * sin(u * PI))), true)


## The same moment, where he stands: for a gift that is earned by finishing something (a stone moved, a beast driven off).
func give_here(id: String) -> void:
	if Game.backdrop or Game.has(id):
		return
	var g := {"lit": 1.0}
	var node := _light_shaft(on_ground(player.global_position.x), g)
	await _give(id, player.global_position.x, node)


## The giving. The world holds still; he goes down on one knee in the light; the gift is named; he rises with it.
func _give(id: String, x: float, node: Node2D) -> void:
	var info: Dictionary = Game.GIFTS[id]
	Game.cinematic = true
	Game.gifting = true
	player.velocity = Vector2.ZERO
	player.global_position = on_ground(x)
	player.facing = 1
	player.act = "kneel"
	player.act_t = 0.0
	Game.sfx("anoint", -6.0, 0.0)
	Game.duck(true)
	if not Game.fast:
		await get_tree().create_timer(1.3).timeout
	Game.sfx("gather", -3.0, 0.0)
	Game.sfx("fire", -8.0, 0.0)
	Game.give(id)
	if not Game.fast:
		await get_tree().create_timer(4.6).timeout
		player.act = "kneel_up"
		player.act_t = 0.0
		await get_tree().create_timer(1.6).timeout
	player.act = ""
	Game.duck(false)
	Game.gifting = false
	Game.cinematic = false
	if is_instance_valid(node):
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 0.0, 2.0)
		tw.tween_callback(node.queue_free)
	if str(info["key"]) != "":
		show_tip(str(info["key"]), 8.0)


## A side cave: a room off the path with its own floor, dark inside, entered through a cave mouth at `door_x`.
## `floors` is a list of [length, height of this floor above the first]: each new floor is a step up or down.
## The room is built far past the level's right edge, so the level itself is untouched. Returns
## {"x0", "x1", "floors": [x where each floor starts], "base"}; build what is inside it with the usual calls.
func add_cave(door_x: float, floors: Array, mouth_tint: Color = Color(0.6, 0.55, 0.72)) -> Dictionary:
	var x0 := width + 4000.0 + caves.size() * 4000.0
	var base := 600.0
	var cave := {"x0": x0, "door": door_x, "floors": [], "base": base, "dark": 0.94}
	var was_barren := barren
	barren = true
	var x := x0
	for fl in floors:
		var seg := make_ground(x, x + float(fl[0]), base - float(fl[1]), 4.0, x * 0.01)
		segments.append(seg)
		var poly := PackedVector2Array(seg)
		poly.append(Vector2(seg[seg.size() - 1].x, 1300.0))
		poly.append(Vector2(seg[0].x, 1300.0))
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cp := CollisionPolygon2D.new()
		cp.polygon = poly
		body.add_child(cp)
		add_child(body)
		_skin_ground(poly, seg)
		cave["floors"].append(x)
		x += float(fl[0])
	barren = was_barren
	cave["x1"] = x
	add_wall(x0 - 12.0)
	add_wall(x + 12.0)
	# the rock all round: a dark wall behind everything, and the cave's own formations standing along it
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([Vector2(x0 - 1400, -1200), Vector2(x + 1400, -1200), Vector2(x + 1400, 1400), Vector2(x0 - 1400, 1400)])
	wall.color = Color(0.035, 0.035, 0.06)
	wall.z_index = -30
	add_child(wall)
	if ResourceLoader.exists("res://art/den_backdrop.png"):      # one painting of a cave's inside, standing behind the whole room
		var tex: Texture2D = load("res://art/den_backdrop.png")
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		var span := (x - x0) + 1500.0
		var msc := maxf(span / tex.get_width(), 1000.0 / tex.get_height())
		sp.scale = Vector2(msc, msc)
		sp.position = Vector2(x0 - 750.0, base + 170.0 - tex.get_height() * msc)
		sp.modulate = Color(0.62, 0.62, 0.74)
		sp.z_index = -20
		add_child(sp)
	# the mouth outside, on the path; and the same mouth seen from within, with the day behind it
	_cave_mouth(on_ground(door_x), false, mouth_tint)
	_cave_mouth(on_ground(x0 + 110.0), true, mouth_tint)
	add_light(on_ground(x0 + 110.0) + Vector2(0, -70), 300.0)
	var go_in := add_task(door_x, "go in", 0.35, func() -> void: _cave_pass(cave), 46.0)
	go_in["again"] = true
	var go_out := add_task(x0 + 110.0, "go out", 0.35, func() -> void: _cave_pass(null, cave), 46.0)
	go_out["again"] = true
	caves.append(cave)
	return cave


func _cave_mouth(at: Vector2, inside: bool, tint: Color) -> void:
	if inside:      # from within, the mouth is only the evening coming in: a soft pale light low on the wall
		var day := add_glow(at + Vector2(-30, -70), Color(0.62, 0.66, 0.85, 0.5), 330.0)
		day.z_index = 0
		return
	add_painter(at, 0, func(ci: CanvasItem) -> void:
		for k in 6:          # the opening: darkness deepening inward
			var f := 1.0 - k / 6.0
			var pts := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				pts.append(Vector2(-10.0 + cos(a) * 124.0 * f, -78.0 + sin(a) * 82.0 * f))
			ci.draw_colored_polygon(pts, Color(0.01, 0.01, 0.03, 0.55)))
	var arch := add_sprite("res://art/props/cave_arch.png", at + Vector2(0, 14), 1.0, 1, tint)
	arch.scale = Vector2(0.72, 0.72)


## Through the mouth, either way: a moment of black, and he is on the other side of it.
func _cave_pass(into, out_of = null) -> void:
	if respawning or Game.cinematic:
		return
	Game.cinematic = true
	player.velocity = Vector2.ZERO
	await Game.main.overlay.fade_to(1.0, 0.3)
	if into != null:
		_cave_state(into)
		player.global_position = on_ground(into["x0"] + 110.0)
	else:
		_cave_state(null)
		player.global_position = on_ground(out_of["door"])
	player.velocity = Vector2.ZERO
	player.cam.reset_smoothing()
	await Game.main.overlay.fade_to(0.0, 0.35)
	Game.cinematic = false


## What changes with being inside: where the camera may go, how dark it is, whether a torch can burn,
## and the flock, which waits at the mouth and does not follow him underground.
func _cave_state(cave) -> void:
	if cave != null:
		if in_cave == null:
			set_meta("out_dark", dark_amount)
			set_meta("out_torch", torch_max)
		in_cave = cave
		set_dark(float(cave["dark"]))
		torch_max = maxf(torch_max, 50.0)
		player.cam.limit_left = int(cave["x0"])
		player.cam.limit_right = int(cave["x1"])
		for i in followers.size():
			followers[i].stay = float(cave["door"]) - 40.0 - i * 34.0
		Game.ambience("")
	else:
		if in_cave == null:
			return
		in_cave = null
		set_dark(float(get_meta("out_dark", 0.0)))
		torch_max = float(get_meta("out_torch", 0.0))
		torch_t = 0.0
		if torch_max <= 0.0 and torch_node != null:
			for f in torch_node.get_node("fire").get_children():
				f.emitting = false
			torch_node.get_node("g").visible = false
			torch_node.get_node("stick").visible = false
			player_light = 0.0
		player.cam.limit_left = 0
		player.cam.limit_right = int(width)
		for sh in followers:
			sh.stay = NAN
		Game.ambience(ambience)


## A hearth of live embers where a torch can be lit (inside a cave, or anywhere it is dark).
func add_embers(x: float) -> void:
	var at := on_ground(x)
	add_light(at + Vector2(0, -20), 150.0)
	add_glow(at + Vector2(0, -8), Color(1.0, 0.45, 0.15, 0.7), 150.0)
	var hearth := add_sprite("res://art/props/embers.png", at + Vector2(0, 9), 1.0, 3)
	var wide := 84.0 / hearth.texture.get_width()
	hearth.scale = Vector2(wide, wide * 0.5)
	var tk := add_task(x, "light a torch at the embers", 0.7, light_torch)
	tk["again"] = true


## A rock shelf added off the path, standing on its own outcrop. Returns the middle of its top.
func add_perch(x: float, up: float, w: float) -> Vector2:
	var r := ledge(x, up, w)
	add_block(r)
	return Vector2(x + w * 0.5, r.position.y)


## A place off the path worth the climb: something old to come upon, named on the map once found.
## `at` is where he stands when he reaches it. Its story is the line "n_place_<id>".
func add_place(id: String, at: Vector2, name: String, craft: String, reach: float = 70.0) -> void:
	if Game.backdrop:
		return
	var pl := {"id": id, "at": at, "name": name, "craft": craft, "reach": reach, "glow": null}
	if id in Game.places():
		return
	var g := add_glow(at + Vector2(0, -46), Color(1.0, 0.88, 0.6, 0.3), 150.0)      # a faint warmth up there, for those who look
	var tw := create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.3, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	pl["glow"] = g
	pl["tw"] = tw
	finds.append(pl)


func _found(pl: Dictionary) -> void:
	pl["tw"].kill()
	var out := create_tween()
	out.tween_property(pl["glow"], "modulate:a", 0.0, 1.5)
	out.tween_callback(pl["glow"].queue_free)
	Game.sfx("anoint", -9.0, 0.0)
	Game.sfx("gather", -6.0, 0.0)
	Game.burst(self, pl["at"] + Vector2(0, -40), Color(1.0, 0.9, 0.65, 0.8), 18, 110.0)
	player.hp = player.max_hp
	Game.find_place(pl["id"], pl["name"], pl["craft"])
	say(["n_place_" + pl["id"]])


## His call goes out: sheep within reach come to him, and (once his voice has grown) jackals shy away.
func shepherd_call(from: Vector2, reach: float, startle: bool) -> void:
	for c in get_children():
		if c is Sheep and not c.gathered and c.gatherable and absf(c.global_position.x - from.x) < reach:
			c.called = 6.0
			c.bolt = 0.0
			c.hop = 1.0
	if startle:
		for n in get_tree().get_nodes_in_group("enemies"):
			if absf(n.global_position.x - from.x) < reach * 0.6 and n.has_method("startle"):
				n.startle()


## A pack closes in. Between x0 and x1 the way is shut until every wave is driven off.
## `waves` lists how many jackals come each time; eyes show in the dark before they do.
func add_ambush(x0: float, x1: float, waves: Array, on_start: Callable, on_done: Callable) -> void:
	ambush = {"x0": x0, "x1": x1, "waves": waves, "start": on_start, "done": on_done,
			"walls": [], "beasts": [], "eyes": [], "run": 0, "cleared": false}
	_arm_ambush()


func _arm_ambush() -> void:
	add_trigger(ambush["x0"] + 260.0, ambush["x1"] - 260.0, _run_ambush)


func _clear_ambush() -> void:
	for n in ambush["walls"] + ambush["beasts"] + ambush["eyes"]:
		if is_instance_valid(n):
			n.queue_free()
	ambush["walls"] = []
	ambush["beasts"] = []
	ambush["eyes"] = []


func _run_ambush() -> void:
	ambush["run"] += 1
	var run: int = ambush["run"]
	var x0: float = ambush["x0"]
	var x1: float = ambush["x1"]
	ambush["walls"] = [add_wall(x0), add_wall(x1)]
	await ambush["start"].call()
	var side := 1
	for count: int in ambush["waves"]:
		# eyes in the dark, on the side they will come from
		var where: Array = []
		for k in count:
			side = -side
			var ex: float = (x0 + 70.0 + k * 34.0) if side < 0 else (x1 - 70.0 - k * 34.0)
			where.append(ex)
			var at := on_ground(ex) + Vector2(0, -24)
			ambush["eyes"].append(add_painter(at, 6, func(ci: CanvasItem) -> void:
				var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
				ci.draw_circle(Vector2(-5, 0), 2.6, Color(1.0, 0.75, 0.25, a))
				ci.draw_circle(Vector2(5, 0), 2.6, Color(1.0, 0.75, 0.25, a)), true))
		Game.sfx("jackal_snarl", -8.0, 0.2)
		if not Game.fast:
			await get_tree().create_timer(1.7).timeout
		if run != ambush["run"] or not is_inside_tree():
			return
		for e in ambush["eyes"]:
			if is_instance_valid(e):
				e.queue_free()
		ambush["eyes"] = []
		for ex in where:
			ambush["beasts"].append(add_jackal(ex, x0 + 30.0, x1 - 30.0))
		while true:
			await get_tree().physics_frame
			if run != ambush["run"] or not is_inside_tree():
				return
			var left := 0
			for b in ambush["beasts"]:
				if is_instance_valid(b) and not b.fleeing:
					left += 1
			if left == 0:
				break
	ambush["cleared"] = true
	_clear_ambush()
	ambush["done"].call()


## Calls fn when David walks into the x range. `once` triggers fire one time.
func add_trigger(x0: float, x1: float, fn: Callable, once: bool = true) -> void:
	triggers.append({"x0": x0, "x1": x1, "fn": fn, "once": once, "inside": false})


## A log bridge that falls into place across a gap when drop.call() runs.
func add_bridge(x0: float, x1: float, y: float) -> Callable:
	var r := Rect2(x0 - 24.0, y, x1 - x0 + 48.0, 20.0)
	var body := add_block(r, false)
	var cs: CollisionShape2D = body.get_child(0)
	cs.disabled = true
	var sp := Sprite2D.new()
	sp.texture = load("res://art/props/bridge.png")
	var w := r.size.x + 24.0
	var sc := w / sp.texture.get_width()
	sp.scale = Vector2(sc, sc * 1.15)
	sp.offset = Vector2(0, sp.texture.get_height() * 0.22)     # its flat top sits level with the ground
	sp.modulate = pal.get("char", Color(1, 1, 1))
	body.add_child(sp)
	body.z_index = 2
	body.visible = false
	return func() -> void:
		body.visible = true
		cs.set_deferred("disabled", false)
		if Game.fast:
			return
		get_tree().create_timer(0.42).timeout.connect(func() -> void: Game.sfx("logs", 1.0, 0.04))      # heard as the logs land, not as they start to fall
		sp.position = Vector2(0, -280)
		sp.rotation = -0.45
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sp, "position", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "rotation", 0.0, 0.5)
		tw.chain().tween_callback(func() -> void:
			player.shake = maxf(player.shake, 5.0)
			Game.burst(self, Vector2(r.position.x + r.size.x * 0.5, y), Color(0.8, 0.7, 0.55, 0.6), 18, 150.0))


# ------------------------------------------------------------------- game flow

func say(ids: Array) -> void:
	await Game.main.overlay.say(ids)


func on_sheep(s) -> void:
	sheep_count += 1
	s.follow_index = followers.size()
	followers.append(s)
	Game.burst(self, s.global_position + Vector2(0, -20), Color(1.0, 0.9, 0.6, 0.9), 10, 110.0)
	Game.grow("voice", 1.0)
	if is_instance_valid(player):
		player.facing = 1 if s.global_position.x >= player.global_position.x else -1
		player.call_out()
	_on_sheep(s)


func _on_sheep(_s) -> void:
	pass


func complete() -> void:
	if done:
		return
	done = true
	Game.main.complete_section()


func respawn() -> void:
	if respawning or done:
		return
	respawning = true
	player.dead = true
	await Game.main.overlay.fade_to(1.0, 0.35)
	if not is_instance_valid(player):
		return
	if in_cave != null:
		_cave_state(null)
	player.reset_to(on_ground(checkpoints[cp_index]))
	if not ambush.is_empty() and not ambush["cleared"] and not ambush["walls"].is_empty():
		ambush["run"] += 1          # the pack melts back into the dark; it will come again
		_clear_ambush()
		_arm_ambush()
	_on_respawn()
	await Game.main.overlay.fade_to(0.0, 0.35)
	respawning = false


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or Game.backdrop or done:
		return
	var px: float = player.global_position.x

	if player.global_position.y > 800.0 and not respawning:
		respawn()
		return

	for i in range(cp_index + 1, checkpoints.size()):
		if px >= checkpoints[i]:
			cp_index = i
			player.hp = player.max_hp
			if cp_fires[i] != null:
				cp_fires[i].visible = true
				cp_cairns[i].modulate = Color(1, 1, 1)
				Game.sfx("fire", -3.0)
				Game.burst(self, cp_fires[i].position, Color(1.0, 0.7, 0.3, 0.9), 14, 140.0)
			Game.save["checkpoint"] = i
			Game.save_game()

	for ks in keepsakes.duplicate():
		if player.global_position.distance_to(ks[0].global_position + Vector2(0, -24)) < 46.0:
			keepsakes.erase(ks)
			Game.burst(self, ks[0].global_position + Vector2(0, -10), Color(0.85, 0.95, 1.0, 0.9), 16, 150.0)
			Game.sfx("stone_hit", -4.0, 0.05)
			Game.sfx("gather", -9.0, 0.05)
			ks[3].kill()
			ks[0].queue_free()
			ks[2].queue_free()
			Game.find_stone(ks[1])
			if Game.stones().size() == 5:
				say(["n_five_stones"])

	for g in gift_spots.duplicate():
		var near: bool = absf(player.global_position.x - g["x"]) < 46.0 and absf(player.global_position.y - on_ground(g["x"]).y) < 40.0
		var ready: bool = g["ready"].call()
		g["lit"] = move_toward(g["lit"], 1.0 if ready else 0.28, _delta * 1.2)
		if near and player.is_on_floor() and not Game.cinematic and not respawning:
			if ready:
				gift_spots.erase(g)
				_give(g["id"], g["x"], g["node"])
			elif not g["near"] and g["wait"] != "":
				show_tip(g["wait"], 4.0)
		g["near"] = near

	for pl in finds.duplicate():
		var d: Vector2 = player.global_position - pl["at"]
		if absf(d.x) < pl["reach"] and d.y > -90.0 and d.y < 30.0 and player.is_on_floor() and not Game.cinematic:
			finds.erase(pl)
			_found(pl)

	_update_push(_delta)
	_update_tasks(_delta)
	if Game.cinematic or respawning:
		return
	for tr in triggers.duplicate():
		var inside: bool = px >= tr["x0"] and px <= tr["x1"]
		if inside and not tr["inside"]:
			tr["inside"] = true
			if tr["once"]:
				triggers.erase(tr)
			tr["fn"].call()
			return
		tr["inside"] = inside


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var c: Vector2 = player.cam.get_screen_center_position()
	for L in layers:
		var s: float = L["s"]
		var node: Node2D = L["node"]
		if L.has("flat"):
			node.position = Vector2(c.x * (1.0 - s), c.y + 360.0 / player.cam.zoom.y - 720.0)
		else:
			node.position = Vector2(c.x * (1.0 - s), (c.y - 360.0) * (1.0 - s * 0.6))
	if motes:
		motes.position = c
	_update_dark(_delta)
	if leaf_fall:
		leaf_fall.position = c + Vector2(-200.0, -420.0)
	# plants lean away as David pushes through, and anything struck swings and settles like a spring
	var pv: float = player.velocity.x
	for pr in props:
		var sp: Sprite2D = pr[0]
		if not is_instance_valid(sp):
			continue
		var soft: bool = pr[1] in ["d_flowers", "d_grass", "d_shrub"]
		var want := 0.0
		if soft and absf(sp.position.x - player.global_position.x) < 30.0 and absf(sp.position.y - player.global_position.y) < 40.0 and absf(pv) > 40.0:
			want = signf(pv) * 0.22
		pr[3] += ((want - pr[2]) * (60.0 if soft else 120.0) - pr[3] * (5.0 if soft else 14.0)) * _delta
		pr[2] += pr[3] * _delta
		sp.rotation = clampf(pr[2], -0.9, 0.9)
	var now := Time.get_ticks_msec() * 0.001
	for g in shaft_glows:       # the light through the haze breathes
		g[0].modulate.a = g[1] * (0.7 + 0.3 * sin(now * g[3] + g[2]))
	var px: float = player.global_position.x
	_update_prompt(_delta)
	for m in mists:
		m[0].position.x += m[1] * _delta
		if m[0].position.x > c.x * 0.82 + 1100.0:
			m[0].position.x = c.x * 0.82 - 1100.0
	for f in cp_fires:
		if f != null and f.visible:
			f.scale = Vector2.ONE * (150.0 / 128.0) * (1.0 + sin(Time.get_ticks_msec() * 0.012 + f.position.x) * 0.08)


# ------------------------------------------------------------ work for his hands

## A place where David does something by standing there and holding the grab key: draw water, light a torch.
## Returns the task; set task["on"] = false to close it, or task["again"] = true to let it be done repeatedly.
func add_task(x: float, text: String, hold: float, fn: Callable, reach: float = 50.0) -> Dictionary:
	var tk := {"x": x, "text": text, "hold": hold, "fn": fn, "reach": reach, "t": 0.0, "on": true, "again": false}
	tasks.append(tk)
	return tk


func do_task(tk: Dictionary) -> void:
	tk["t"] = 0.0
	if not tk["again"]:
		tk["on"] = false
	Game.grow("hand", 2.0)
	tk["fn"].call()


func _update_tasks(delta: float) -> void:
	if tasks.is_empty():
		return
	var best = null
	if not Game.cinematic and not respawning:
		for tk in tasks:
			if tk["on"] and absf(player.global_position.x - tk["x"]) < tk["reach"] \
					and absf(player.global_position.y - on_ground(tk["x"]).y) < 90.0:
				if best == null or absf(player.global_position.x - tk["x"]) < absf(player.global_position.x - best["x"]):
					best = tk
	for tk in tasks:
		if tk != best:
			tk["t"] = 0.0
	task_now = best
	if best == null:
		return
	if Input.is_action_pressed("grab") and player.is_on_floor() and absf(player.velocity.x) < 45.0:
		best["t"] += delta
		if best["t"] >= best["hold"]:
			do_task(best)
	else:
		best["t"] = maxf(0.0, best["t"] - delta * 2.0)


## Something heavy standing on the ground that he can lean into and move between x_min and x_max.
## The stronger his hand has grown, the faster it goes. `moved` is called with its new x each time it shifts.
func add_pushable(x: float, w: float, h: float, art: String, x_min: float, x_max: float, rolls: bool = false) -> Dictionary:
	var gy := on_ground(x).y
	var body := add_block(Rect2(x - w * 0.5, gy - h, w, h), false)
	var sp := Sprite2D.new()
	sp.texture = load(art)
	sp.scale = Vector2((w + 10.0) / sp.texture.get_width(), (h + 8.0) / sp.texture.get_height())
	sp.modulate = pal.get("char", Color(1, 1, 1))
	body.add_child(sp)
	body.z_index = 3
	var pb := {"body": body, "sp": sp, "w": w, "h": h, "min": x_min, "max": x_max, "rolls": rolls, "on": true, "moved": Callable(), "rumble": 0.0}
	pushables.append(pb)
	return pb


func _update_push(delta: float) -> void:
	push_t = maxf(0.0, push_t - delta)
	if pushables.is_empty() or Game.cinematic or respawning:
		return
	var dir := Input.get_axis("move_left", "move_right")
	for pb in pushables:
		var body: StaticBody2D = pb["body"]
		if not pb["on"] or not is_instance_valid(body) or absf(dir) < 0.3 or not player.is_on_floor():
			continue
		var gap: float = (body.position.x - player.global_position.x) * signf(dir)      # how far ahead of him it is
		if gap < pb["w"] * 0.5 or gap > pb["w"] * 0.5 + 30.0 or absf(player.global_position.y - (body.position.y + pb["h"] * 0.5)) > 30.0:
			continue
		var speed := 36.0 + 15.0 * Game.rank("hand")
		var nx := clampf(body.position.x + signf(dir) * speed * delta, pb["min"], pb["max"])
		var moved := nx - body.position.x
		if absf(moved) < 0.001:
			continue
		body.position.x = nx
		body.position.y = on_ground(nx).y - pb["h"] * 0.5
		if pb["rolls"]:
			pb["sp"].rotation += moved / (pb["h"] * 0.5)
		pb["rumble"] -= delta
		if pb["rumble"] <= 0.0:
			pb["rumble"] = 0.32
			Game.sfx("hit", -15.0, 0.25)
			Game.burst(self, Vector2(nx, body.position.y + pb["h"] * 0.5), Color(0.8, 0.72, 0.58, 0.4), 4, 50.0)
		push_t = 0.18
		Game.grow("hand", delta * 1.5)
		if pb["moved"].is_valid():
			pb["moved"].call(nx)


## A perched boulder. A sling stone brings it down onto `rest`, where its top becomes ground.
func add_boulder(at: Vector2, rest: Rect2):
	var b = Boulder.new()
	b.level = self
	b.rest = rest
	b.position = at
	add_child(b)
	return b


## Prints in the dust: a line of small hoof marks, or the broad pads of something that hunts.
func add_tracks(x0: float, x1: float, big: bool = false) -> void:
	var x := x0
	var k := 0
	while x < x1:
		var at := on_ground(x) + Vector2(0, -3)
		var flip := k % 2 == 0
		var turn := rng.randf_range(-0.25, 0.25)
		add_painter(at, 2, func(ci: CanvasItem) -> void:
			# seen from the side, a print lies almost flat: draw it squashed, as a shallow dark press in the dust
			var sc := 1.0 if big else 0.55
			var side := -3.0 if flip else 3.0
			ci.draw_set_transform(Vector2(0, side * 0.4), turn, Vector2(sc, sc * 0.42))
			var sharp := Game.rank("eye") >= 1          # a trained eye picks them out a little more clearly
			var col := Color(0.03, 0.02, 0.04, 0.5 if sharp else 0.36)
			var pad := PackedVector2Array([Vector2(-7, 2), Vector2(-5, -4), Vector2(0, -6), Vector2(5, -4), Vector2(7, 2), Vector2(4, 7), Vector2(-4, 7)])
			ci.draw_colored_polygon(pad, col)
			for t in [Vector2(-8, -10), Vector2(-3, -14), Vector2(3, -14), Vector2(8, -10)]:
				ci.draw_circle(t, 2.6, col)
			if sharp:      # the low light catches the far lip of each print
				ci.draw_arc(Vector2(0, 0), 9.0, PI * 1.15, PI * 1.85, 8, Color(1.0, 0.9, 0.75, 0.16), 1.2, true)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
		x += rng.randf_range(84.0, 104.0) if big else rng.randf_range(40.0, 54.0)
		k += 1


## A tuft of wool caught on a thorn.
func add_wool(x: float, up: float = 26.0) -> void:
	var at := on_ground(x) + Vector2(0, -up)
	add_glow(at, Color(1.0, 0.92, 0.8, 0.35), 110.0)
	add_painter(at, 4, func(ci: CanvasItem) -> void:
		ci.draw_line(Vector2(-10, up), Vector2(2, 0), Color(0.2, 0.16, 0.14), 2.0, true)
		ci.draw_line(Vector2(2, 0), Vector2(12, -8), Color(0.2, 0.16, 0.14), 1.5, true)
		var sway := sin(Time.get_ticks_msec() * 0.004 + x) * 2.0
		for o in [Vector2(0, 0), Vector2(6, -3), Vector2(3, 4)]:
			ci.draw_circle(o + Vector2(sway, 0), 5.0, pal["wool"]), true)


# ------------------------------------------------------------- darkness and light

## Lays darkness over the section. `amount` 0 to 1. Light comes from `lights` and from the torch he carries.
func set_dark(amount: float) -> void:
	dark_amount = amount
	if dark == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		dark = ColorRect.new()
		dark.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = DarkShader
		dark.material = m
		layer.add_child(dark)


func add_light(pos: Vector2, r: float) -> Dictionary:
	var l := {"pos": pos, "r": r, "on": true}
	lights.append(l)
	return l


func light_torch() -> void:
	torch_t = torch_max
	Game.sfx("fire", -2.0)
	Game.burst(self, player.global_position + Vector2(player.facing * 20.0, -78), Color(1.0, 0.7, 0.3, 0.9), 12, 120.0)


func _update_dark(delta: float) -> void:
	if torch_max > 0.0:
		if torch_node == null:
			torch_node = Node2D.new()
			torch_node.z_index = 5
			add_child(torch_node)
			# a real flame, the same fire as the watchfires but small: it streams back as he runs and gutters in a draught
			var fire := _flames()
			fire.name = "fire"
			fire.scale = Vector2.ONE * 0.42
			fire.position = Vector2(0, -18)
			torch_node.add_child(fire)
			var g := Game.glow(Color(1.0, 0.65, 0.3, 0.55), 260.0)
			g.name = "g"
			torch_node.add_child(g)
			var stick := Sprite2D.new()          # the painted torch, held upright with its wrapped head in the flame
			stick.name = "stick"
			stick.texture = load("res://art/props/torch.png")
			stick.rotation = PI * 0.5
			stick.scale = Vector2.ONE * (58.0 / stick.texture.get_width())
			stick.position = Vector2(0, 16)
			stick.show_behind_parent = true
			torch_node.add_child(stick)
		torch_node.position = player.global_position + Vector2(player.facing * 22.0, -92.0)
		torch_node.get_node("g").visible = torch_t > 0.0
		torch_node.get_node("stick").visible = torch_t > 0.0
		var low := clampf(torch_t / (torch_max * 0.3), 0.3, 1.0) * (0.7 if draught > 1.5 else 1.0)
		for f in torch_node.get_node("fire").get_children():
			f.emitting = torch_t > 0.0
			f.scale_amount_max = (0.05 if f.amount < 20 else 0.3) * low
		torch_node.get_node("g").modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.013) * sin(Time.get_ticks_msec() * 0.0071)
		if torch_t > 0.0 and not Game.cinematic and not respawning:
			torch_t = maxf(0.0, torch_t - delta * draught)
			if torch_t <= 0.0:
				Game.sfx("gust", -6.0)
		player_light = 78.0 + 215.0 * clampf(torch_t / (torch_max * 0.3), 0.0, 1.0)
		if torch_t > 0.0:        # the lesser beasts keep to the edge of the light
			for n in get_tree().get_nodes_in_group("enemies"):
				if "retreat" in n and n.global_position.distance_to(player.global_position) < player_light * 0.72 and n.retreat < 0.2:
					n.retreat = 0.45
	if dark == null:
		return
	var m: ShaderMaterial = dark.material
	var view := get_viewport().get_visible_rect().size
	var xf := get_viewport().get_canvas_transform()
	var zoom: float = player.cam.zoom.y
	var arr := PackedVector3Array()
	if player_light > 0.0:
		var sp: Vector2 = xf * (player.global_position + Vector2(0, -60))
		arr.append(Vector3(sp.x / view.x, sp.y / view.y, player_light * zoom / 720.0))
	for i in cp_fires.size():
		if cp_fires[i] != null and cp_fires[i].visible:
			var fp: Vector2 = xf * cp_fires[i].position
			arr.append(Vector3(fp.x / view.x, fp.y / view.y, 250.0 * zoom / 720.0))
	for l in lights:
		if not l["on"] or arr.size() >= 12:
			continue
		var lp: Vector2 = xf * l["pos"]
		if lp.x < -view.x or lp.x > view.x * 2.0:
			continue
		arr.append(Vector3(lp.x / view.x, lp.y / view.y, float(l["r"]) * zoom / 720.0))
	var n := arr.size()
	while arr.size() < 12:
		arr.append(Vector3(-9, -9, 0.0))
	m.set_shader_parameter("lights", arr)
	m.set_shader_parameter("count", n)
	m.set_shader_parameter("amount", dark_amount)
	m.set_shader_parameter("aspect", view.x / view.y)


# ----------------------------------------------------------------- beasts in waves

## Eyes show in the dark, then that many jackals come from the named sides. Returns the beasts.
## `run` is a counter the caller bumps to call the wave off (a respawn): the wave then stops quietly.
func send_wave(x0: float, x1: float, count: int, from_left: bool, from_right: bool, holder: Dictionary) -> void:
	var run: int = holder["run"]
	var where: Array = []
	var eyes: Array = []
	for k in count:
		var left := from_left and (not from_right or k % 2 == 0)
		var ex: float = (x0 + 70.0 + k * 34.0) if left else (x1 - 70.0 - k * 34.0)
		where.append(ex)
		eyes.append(add_painter(on_ground(ex) + Vector2(0, -24), 6, func(ci: CanvasItem) -> void:
			var a := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
			ci.draw_circle(Vector2(-5, 0), 2.6, Color(1.0, 0.75, 0.25, a))
			ci.draw_circle(Vector2(5, 0), 2.6, Color(1.0, 0.75, 0.25, a)), true))
	holder["extra"] = eyes
	Game.sfx("jackal_snarl", -8.0, 0.2)
	if not Game.fast:
		await get_tree().create_timer(1.7 * float(holder.get("warning", 1.0))).timeout
	for e in eyes:
		if is_instance_valid(e):
			e.queue_free()
	if run != holder["run"] or not is_inside_tree():
		return
	for ex in where:
		holder["beasts"].append(add_jackal(ex, x0 + 30.0, x1 - 30.0))
	while true:
		await get_tree().physics_frame
		if run != holder["run"] or not is_inside_tree():
			return
		var left_n := 0
		for b in holder["beasts"]:
			if is_instance_valid(b) and not b.fleeing:
				left_n += 1
		if left_n == 0:
			return


func clear_wave(holder: Dictionary) -> void:
	holder["run"] += 1
	for n in holder["beasts"] + holder.get("extra", []):
		if is_instance_valid(n):
			n.queue_free()
	holder["beasts"] = []


# ------------------------------------------------------------------- the prompt

var prompt_node: Node2D
var prompt_a := 0.0
var prompt_key := ""
var prompt_words := ""
var prompt_bar := 0.0
var tip := ""            # something the fight itself has just taught him, shown for a few seconds
var tip_t := 0.0


## One small prompt near David's head: the thing he can do here (hold E), or else the nearest unread hint.
func _update_prompt(delta: float) -> void:
	if Game.backdrop:
		return
	if prompt_node == null:
		prompt_node = add_painter(Vector2.ZERO, 9, _draw_prompt, true)
	var show := false
	prompt_bar = 0.0
	if not Game.cinematic and not respawning:
		if task_now != null:
			show = true
			prompt_key = "E"
			prompt_words = Game.t(str(task_now["text"]))
			prompt_bar = clampf(task_now["t"] / task_now["hold"], 0.0, 1.0)
		elif tip_t > 0.0:
			tip_t -= delta
			show = true
			prompt_key = ""
			prompt_words = Game.t(tip)
		else:
			var seen: Dictionary = Game.save.get("seen", {})
			var best = null
			for h in hints:
				if h["on"] and absf(player.global_position.x - h["x"]) < 150.0 and float(seen.get(h["text"], 0.0)) < 4.5:
					if best == null or absf(player.global_position.x - h["x"]) < absf(player.global_position.x - best["x"]):
						best = h
			if best != null:
				show = true
				var txt := Game.t(str(best["text"]))
				var cut := txt.find("  ")
				if cut > 0 and cut <= 6:
					prompt_key = txt.substr(0, cut)
					prompt_words = txt.substr(cut).strip_edges()
				else:
					prompt_key = ""
					prompt_words = txt
				if prompt_a > 0.7:          # it counts as read once it has been up for a few seconds in all
					var was := float(seen.get(best["text"], 0.0))
					seen[best["text"]] = was + delta
					Game.save["seen"] = seen
					if was < 4.5 and was + delta >= 4.5:
						Game.save_game()
	prompt_a = move_toward(prompt_a, 1.0 if show else 0.0, delta * 4.0)
	prompt_node.position = player.global_position + Vector2(0, -150.0)


## A short lesson from the fight, said once it has been earned (a blow turned, a spring missed).
func show_tip(text: String, seconds: float = 4.5) -> void:
	tip = text
	tip_t = seconds


func _draw_prompt(ci: CanvasItem) -> void:
	if prompt_a <= 0.01:
		return
	var f := Game.serif
	var size := 16
	var words_w := f.get_string_size(prompt_words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var key_w := 0.0
	if prompt_key != "":
		key_w = maxf(26.0, f.get_string_size(prompt_key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 16.0)
	var gap := 9.0 if prompt_key != "" and prompt_words != "" else 0.0
	var total := key_w + gap + words_w
	var x := -total * 0.5
	var a := prompt_a
	if prompt_key != "":          # a key-cap: a small rounded tile with the key on it
		var r := Rect2(x, -19.0, key_w, 25.0)
		ci.draw_rect(r.grow(1.0), Color(0.02, 0.02, 0.05, 0.55 * a))
		ci.draw_rect(r, Color(1.0, 0.95, 0.84, 0.92 * a), false, 1.6)
		ci.draw_string(f, Vector2(x, -1.0), prompt_key, HORIZONTAL_ALIGNMENT_CENTER, key_w, size, Color(1.0, 0.95, 0.84, a))
	if prompt_words != "":
		var p := Vector2(x + key_w + gap, -1.0)
		ci.draw_string_outline(f, p, prompt_words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.02, 0.02, 0.05, 0.7 * a))
		ci.draw_string(f, p, prompt_words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.95, 0.84, 0.92 * a))
	if prompt_bar > 0.0:
		ci.draw_rect(Rect2(-40.0, 12.0, 80.0, 4.0), Color(0, 0, 0, 0.45 * a))
		ci.draw_rect(Rect2(-40.0, 12.0, 80.0 * prompt_bar, 4.0), Color(1.0, 0.88, 0.6, 0.95 * a))
