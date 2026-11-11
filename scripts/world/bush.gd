extends StaticBody2D
## Thorn thicket that blocks the path until cleared with the staff.

const W := 64.0
const H := 132.0

var hp := 5
var full := 5
var hit_r := 32.0
var hit_h := H
var wobble := 0.0
var blobs: Array = []
var tex: Texture2D
var tint := Color(1, 1, 1)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	add_to_group("hittable")
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sway.gdshader")
	m.set_shader_parameter("amp", 0.012)
	material = m
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(W, H)
	cs.shape = sh
	cs.position = Vector2(0, -H * 0.5)
	add_child(cs)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x)
	for i in 16:
		blobs.append([Vector2(rng.randf_range(-W * 0.5, W * 0.5), -rng.randf_range(4.0, H - 8.0)), rng.randf_range(13.0, 24.0), rng.randf() * TAU])


func hit(_dmg: int, dir: int, kind: String) -> void:
	if kind != "staff":
		return
	hp -= 1
	Game.sfx("bush", 0.0, 0.06)
	wobble = 1.0 * dir
	queue_redraw()
	Game.burst(get_parent(), global_position + Vector2(0, -H * 0.5), Color(0.6, 0.8, 0.5, 0.7), 10, 160.0)
	if hp <= 0:
		Game.burst(get_parent(), global_position + Vector2(0, -H * 0.35), Color(0.6, 0.8, 0.5, 0.7), 22, 240.0)
		queue_free()


func _process(delta: float) -> void:
	if wobble != 0.0:
		wobble = move_toward(wobble, 0.0, delta * 4.0)
		queue_redraw()


func _draw() -> void:
	if tex == null:
		tex = load("res://art/props/bush.png")
	var sc := (H + 10.0) / tex.get_height()
	# each blow breaks some of it down
	var left := float(hp) / float(full)
	draw_set_transform(Vector2.ZERO, wobble * 0.12, Vector2(sc * (0.82 + 0.18 * left), sc * (0.6 + 0.4 * left)))
	draw_texture(tex, Vector2(-tex.get_width() * 0.5, -tex.get_height() + 12.0), tint)
