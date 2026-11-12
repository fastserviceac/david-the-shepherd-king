extends Node2D
## A hanging clay jar. Strike it with a sling stone to drop a bridge.

signal struck

var hit_r := 30.0
var hit_h := 0.0
var rope := 160.0
var t := 0.0
var tex: Texture2D
var tint := Color(1, 1, 1)
var swing := 0.0


func _ready() -> void:
	z_index = 4
	add_to_group("hittable")
	var g := Game.glow(Color(1.0, 0.8, 0.45, 0.55), 170.0)
	add_child(g)


func hit(_dmg: int, _dir: int, kind: String) -> void:
	if kind != "stone":      # a staff only sets it swinging
		swing = 0.5 * _dir
		Game.sfx("stone_hit", -8.0, 0.1)
		return
	Game.burst(get_parent(), global_position, Color(1.0, 0.8, 0.5, 0.9), 20, 220.0)
	Game.sfx("jar", -9.0)
	struck.emit()
	queue_free()


func _process(delta: float) -> void:
	t += delta
	swing = move_toward(swing, 0.0, delta * 0.25)
	rotation = sin(t * 1.3) * 0.06 + sin(t * 5.0) * swing
	queue_redraw()


func _draw() -> void:
	if tex == null:
		tex = load("res://art/props/jar.png")
	var sc := 0.17      # the jar painting is stored at twice its size
	var w := tex.get_width() * sc
	var h := tex.get_height() * sc
	# the jar body is centred here; its rope loop sits at the top of the image
	draw_line(Vector2(0, -rope), Vector2(0, -h * 0.62), Color(0.45, 0.36, 0.25), 2.5, true)
	for k in 3:      # where it is tied round the bough
		draw_line(Vector2(-5, -rope - 3.0 + k * 3.0), Vector2(5, -rope - 1.0 + k * 3.0), Color(0.45, 0.36, 0.25), 2.0, true)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.66, w, h), false, tint)
	draw_arc(Vector2(0, 2), 26.0, 0.0, TAU, 28, Color(1.0, 0.85, 0.55, 0.35 + sin(t * 3.0) * 0.25), 2.0, true)
