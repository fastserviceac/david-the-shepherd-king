extends Node2D
## A boulder perched where a sling stone can dislodge it. It falls to `rest` and stays there as a step,
## a plug in a gap, or a blow to whatever was underneath.

signal fell

var level
var hit_r := 36.0
var hit_h := 0.0
var rest := Rect2()          # where it comes to lie: its top is then solid ground
var fallen := false
var gate := ""              # a gift he must have before a stone will bring this one down
var wob := 0.0
var t := 0.0
var tex: Texture2D
var tint := Color(1, 1, 1)
var glow: Sprite2D
var slab := false           # wider than it is tall: it has its own picture, and falls as a slab does
var mat: ShaderMaterial
var shade: Node2D
var phase := ""             # "tip", "drop", "slam" or "bounce", "settle"
var pt := 0.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var way := 1
var vy := 0.0
var spin := 0.0
var rock := 0.0
var drop_secs := 0.3
var hang_y := INF           # in a cave: the height of the roof it hangs from (drawn, so it is never loose in mid-air)
var sock: Node2D
var dust_t := 0.0

# Light from the sky: the top of the stone catches it and the underside is in shadow, whichever way up it is
# as it turns. Without this it is a flat picture; with it, it has a top and a belly.
const SHADE := """
shader_type canvas_item;
uniform float rot = 0.0;
uniform float aspect = 1.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float down = p.x * aspect * sin(rot) + p.y * cos(rot);
	COLOR.rgb *= mix(1.1, 0.5, smoothstep(-0.35, 0.55, down));
}
"""


func _ready() -> void:
	z_index = 2
	add_to_group("hittable")
	slab = rest.size.x > rest.size.y * 1.8
	tex = load("res://art/props/rock_low.png" if slab else "res://art/props/d_boulder.png")      # a boulder squashed flat reads as card
	var sh := Shader.new()
	sh.code = SHADE
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("aspect", (rest.size.x + 18.0) / (rest.size.y + 14.0))
	material = mat
	if is_instance_valid(level):
		tint = level.pal.get("char", Color(1, 1, 1))
	glow = Game.glow(Color(1.0, 0.85, 0.55, 0.4), 150.0)
	glow.position = Vector2(0, -rest.size.y * 0.5)
	add_child(glow)
	if hang_y < INF:      # the rock it hangs from: a root of stone down from the roof to the top of the boulder
		sock = Node2D.new()
		sock.position = position
		sock.z_index = 1
		sock.draw.connect(_draw_socket)
		get_parent().add_child.call_deferred(sock)


func hit(_dmg: int, from_dir: int, kind: String) -> void:
	if fallen:
		return
	if kind != "stone":       # the staff only rocks it
		wob = 0.5 * from_dir
		Game.sfx("hit", -9.0, 0.1)
		return
	if gate != "" and not Game.has(gate):      # the stone glances off: it sits too high and too firm for an untrained eye
		wob = 0.7 * from_dir
		Game.sfx("hit", -6.0, 0.1)
		if is_instance_valid(level):
			level.show_tip("It only rocks.  This one wants a surer eye")
		return
	fall(from_dir)


func fall(from_dir: int = 1) -> void:
	if fallen:
		return
	fallen = true
	remove_from_group("hittable")
	glow.queue_free()
	Game.sfx("hit", -3.0, 0.1)
	to = Vector2(rest.position.x + rest.size.x * 0.5, rest.position.y + rest.size.y)
	way = from_dir
	if Game.fast:
		position = to
		_landed(from_dir)
		return
	# its shadow waits for it where it will come down, and gathers as it nears
	shade = Node2D.new()
	shade.z_index = 1
	shade.position = to
	shade.draw.connect(_draw_shade)
	get_parent().add_child(shade)
	from = position
	phase = "tell" if hang_y < INF else "tip"
	pt = 0.0
	if hang_y < INF:
		Game.sfx("hit", -10.0, 0.3)


## It leaves its perch slowly, the way a great weight does, then drops; a slab comes down on one end and slams
## flat, a round stone turns over once and rocks itself still.
func _fall_step(delta: float) -> void:
	pt += delta
	match phase:
		"tell":      # the roof gives warning: it shudders, grit and dust sift down, and a crack runs, before it lets go
			var u := clampf(pt / 0.9, 0.0, 1.0)
			position.x = from.x + sin(pt * 70.0) * 2.5 * u
			position.y = from.y + sin(pt * 53.0) * 1.2 * u
			rotation = sin(pt * 41.0) * 0.035 * u
			dust_t -= delta
			if dust_t <= 0.0 and is_instance_valid(level):
				dust_t = 0.1
				Game.burst(level, Vector2(from.x + randf_range(-30.0, 30.0), hang_y + randf_range(10.0, 60.0)), Color(0.7, 0.66, 0.6, 0.6), 3, 40.0)
				if is_instance_valid(level.player):
					level.player.shake = maxf(level.player.shake, 2.5 * u)
			if sock != null and is_instance_valid(sock):
				sock.queue_redraw()
			if u >= 1.0:
				position = from
				rotation = 0.0
				phase = "tip"
				pt = 0.0
				Game.burst(level, Vector2(from.x, hang_y + 30.0), Color(0.75, 0.7, 0.62, 0.7), 18, 150.0)      # it parts from the roof
				if sock != null and is_instance_valid(sock):
					sock.queue_redraw()
		"tip":
			var u := clampf(pt / 0.34, 0.0, 1.0)
			position.x = from.x + way * 16.0 * u * u
			position.y = from.y + 5.0 * u * u
			rotation = way * 0.22 * u * u
			if u >= 1.0:
				phase = "drop"
				from = position
				vy = 40.0
				pt = 0.0
				drop_secs = maxf(0.12, (-vy + sqrt(vy * vy + 2.0 * 1500.0 * maxf(to.y - from.y, 1.0))) / 1500.0)
		"drop":
			vy += 1500.0 * delta
			position.y += vy * delta
			var u := clampf(pt / drop_secs, 0.0, 1.0)
			position.x = lerpf(from.x, to.x, u)
			rotation = way * (lerpf(0.22, 0.3, u) if slab else lerpf(0.22, TAU - 0.12, u))
			if position.y >= to.y - (absf(sin(rotation)) * rest.size.x * 0.5 if slab else 0.0):
				position.x = to.x
				if slab:      # one end is down: dust there, and the other end still has to fall
					position.y = to.y - absf(sin(rotation)) * rest.size.x * 0.5
					_thud(Vector2(way * rest.size.x * 0.46, 0.0), 0.6)
					phase = "slam"
					spin = 0.0
				else:
					position.y = to.y
					rotation = -way * 0.12
					_thud(Vector2.ZERO, 0.8)
					phase = "bounce"
					vy = -150.0
					spin = way * 1.2
				pt = 0.0
		"slam":      # the free end comes over and down, faster and faster
			spin += 26.0 * delta
			rotation = move_toward(rotation, 0.0, spin * delta)
			position.y = to.y - absf(sin(rotation)) * rest.size.x * 0.5
			if is_zero_approx(rotation):
				_landed(way)
				rock = -way * 0.035
				phase = "settle"
				pt = 0.0
		"bounce":
			vy += 1500.0 * delta
			position.y = minf(position.y + vy * delta, to.y)
			rotation += spin * delta
			if position.y >= to.y and vy > 0.0:
				rock = rotation
				_landed(way)
				phase = "settle"
				pt = 0.0
		"settle":      # it rocks once or twice and is still
			rotation = rock * exp(-pt * 7.0) * cos(pt * 17.0)
			if pt > 0.9:
				rotation = 0.0
				phase = ""
	if is_instance_valid(shade):
		shade.queue_redraw()
	queue_redraw()


## The stone it hangs from: a tapering root of the roof, with cracks, ending around the top of the boulder. Once it
## has fallen only a broken stub is left.
func _draw_socket() -> void:
	var top := hang_y - sock.position.y      # the roof, seen from the boulder's own spot
	var w := rest.size.x + 18.0
	var by := -(rest.size.y + 14.0) + 16.0      # where the boulder's top is
	var rock := Color(0.09, 0.1, 0.16)      # cave stone: dark and cool, like the walls it grows from
	var stub := fallen and phase != "tell"
	var end_y := lerpf(top, by + 34.0, 0.35 if stub else 1.0)      # it runs down into the top of the boulder
	var neck := w * (0.3 if not stub else 0.2)
	# a jagged cone: wide against the roof, narrowing to the stone
	var pts := PackedVector2Array([Vector2(-w * 0.95, top - 40.0), Vector2(w * 0.95, top - 40.0), Vector2(w * 0.8, top + 8.0)])
	var n := 6
	for i in n:
		var f := float(i + 1) / n
		pts.append(Vector2(lerpf(w * 0.62, neck, f) + (14.0 if i % 2 == 0 else -9.0), lerpf(top + 8.0, end_y, f)))
	pts.append(Vector2(-neck if not stub else -neck * 0.4, end_y))
	for i in range(n - 1, -1, -1):
		var f := float(i + 1) / n
		pts.append(Vector2(-lerpf(w * 0.62, neck, f) + (-12.0 if i % 2 == 0 else 8.0), lerpf(top + 8.0, end_y, f)))
	pts.append(Vector2(-w * 0.8, top + 8.0))
	sock.draw_colored_polygon(pts, rock)
	# the lit side and the shadowed side of the cone, and ledges of rock across it, so it reads as stone and not a flat shape
	var half := PackedVector2Array([Vector2(0.0, top - 40.0), Vector2(w * 0.95, top - 40.0), Vector2(w * 0.8, top + 8.0)])
	for i in n:
		var f := float(i + 1) / n
		half.append(Vector2(lerpf(w * 0.62, neck, f) + (14.0 if i % 2 == 0 else -9.0), lerpf(top + 8.0, end_y, f)))
	half.append(Vector2(0.0, end_y))
	sock.draw_colored_polygon(half, Color(0.0, 0.0, 0.03, 0.55))
	for i in 5:
		var fy := lerpf(top + 30.0, end_y - 10.0, float(i) / 4.0)
		var fw := lerpf(w * 0.55, neck, float(i) / 4.0) * (0.8 if i % 2 == 0 else 0.55)
		sock.draw_line(Vector2(-fw, fy + (i % 3) * 4.0), Vector2(fw * 0.7, fy - (i % 2) * 5.0), Color(0.03, 0.03, 0.06, 0.55), 2.2, true)
	sock.draw_polyline(PackedVector2Array([Vector2(-w * 0.1, top + 8.0), Vector2(-w * 0.04, lerpf(top, by, 0.3)), Vector2(w * 0.05, lerpf(top, by, 0.5)), Vector2(-w * 0.02, lerpf(top, by, 0.75))]), Color(0.02, 0.02, 0.04, 0.8), 1.6, true)
	sock.draw_polyline(PackedVector2Array([Vector2(-neck * 1.4, top + 20.0), Vector2(-neck * 1.0, lerpf(top, end_y, 0.7))]), Color(0.35, 0.4, 0.6, 0.35), 2.0, true)


## How near the ground it is: 0 on its perch, 1 lying where it fell.
func _nearness() -> float:
	return clampf(1.0 - (to.y - position.y) / 260.0, 0.0, 1.0)


func _draw_shade() -> void:
	var k := _nearness()
	var w := rest.size.x * lerpf(1.5, 1.04, k)
	shade.draw_set_transform(Vector2(0, 1.0), 0.0, Vector2(1.0, 0.16))
	shade.draw_circle(Vector2.ZERO, w * 0.5, Color(0.02, 0.01, 0.05, lerpf(0.06, 0.3, k)))
	shade.draw_circle(Vector2.ZERO, w * 0.36, Color(0.02, 0.01, 0.05, lerpf(0.04, 0.3, k)))
	shade.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Stone on stone: dust thrown out along the ground, chips, and the ground shakes.
func _thud(at: Vector2, weight: float) -> void:
	if not is_instance_valid(level):
		return
	var here := position + at
	Game.sfx("bridge", -8.0 + 6.0 * weight, 0.08)
	Game.sfx("land", -6.0 + 4.0 * weight, 0.1)
	Game.burst(level, here, Color(0.8, 0.74, 0.62, 0.55), int(26 * weight), 210.0 * weight)      # dust
	Game.burst(level, here + Vector2(0, -6), Color(0.62, 0.58, 0.55, 0.95), int(9 * weight), 330.0 * weight)      # chips of rock
	for side in [-1.0, 1.0]:      # and it rolls out low along the ground on both sides
		Game.burst(level, Vector2(to.x + side * rest.size.x * 0.5, to.y - 4.0), Color(0.78, 0.72, 0.62, 0.35), int(12 * weight), 90.0)
	if is_instance_valid(level.player):
		level.player.shake = maxf(level.player.shake, 9.0 * weight)


func _landed(from_dir: int) -> void:
	rotation = 0.0
	position = to
	if not is_instance_valid(level):
		return
	level.add_block(rest, false)
	if not Game.fast:
		_thud(Vector2.ZERO, 1.0)
		Game.hitstop(0.06)
	for n in get_tree().get_nodes_in_group("enemies"):      # anything under it is driven off
		if absf(n.global_position.x - position.x) < rest.size.x * 0.5 + 60.0 and absf(n.global_position.y - position.y) < 120.0:
			n.hit(9, from_dir, "stone")
	fell.emit()


func _process(delta: float) -> void:
	t += delta
	wob = move_toward(wob, 0.0, delta * 0.6)
	if not fallen:
		rotation = sin(t * 7.0) * wob * 0.2
		queue_redraw()
	elif phase != "":
		_fall_step(delta)
	elif sock != null and is_instance_valid(sock) and sock.get_meta("seen", false) == false:
		sock.set_meta("seen", true)
		sock.queue_redraw()
	mat.set_shader_parameter("rot", rotation)


func _draw() -> void:
	var w := rest.size.x + 18.0
	var h := rest.size.y + 14.0
	if fallen and phase == "" or phase == "settle":      # lying there: dark where it meets the ground, so it sits in it and not on it
		draw_set_transform(Vector2(0, 2.0), 0.0, Vector2(1.0, 0.14))
		draw_circle(Vector2.ZERO, w * 0.54, Color(0.02, 0.01, 0.05, 0.34))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h + 4.0, w, h), false, tint)
