extends Node2D
## A sling stone. Flies in an arc, stops on ground or on anything hittable.

const GRAVITY := 900.0

var vel := Vector2.ZERO
var dmg := 1
var lesser_dmg := 0          # what it does to a jackal: grows with him (Game.blow)
var life := 3.0
var trail: Array = []
var tex: Texture2D
var spin := 0.0
var tint := Color(1, 1, 1)
var smooth := false      # one of the smooth stones from his pouch: it staggers what it strikes


func _ready() -> void:
	z_index = 6


func _physics_process(delta: float) -> void:
	var from := global_position
	vel.y += GRAVITY * delta
	var to := from + vel * delta

	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	var ray := get_world_2d().direct_space_state.intersect_ray(q)
	if not ray.is_empty():
		_end(ray["position"])
		return

	global_position = to
	for n in get_tree().get_nodes_in_group("hittable"):
		var c: Vector2 = n.global_position + Vector2(0, -n.hit_h * 0.5)
		var reach: float = n.hit_r + 7.0
		if absf(c.x - to.x) < reach and absf(c.y - to.y) < maxf(reach, n.hit_h * 0.5 + 7.0):
			n.hit(lesser_dmg if n.get("lesser") == true and lesser_dmg > 0 else dmg, 1 if vel.x >= 0.0 else -1, "smooth" if smooth and n.has_method("is_open") else "stone")
			if smooth:
				Game.hitstop(0.09)
				Game.burst(get_parent(), to, Color(1.0, 0.95, 0.8, 0.95), 16, 190.0)
			Game.grow("eye", 1.0)
			_end(to)
			return

	spin += delta * 14.0
	trail.push_front(to)
	if trail.size() > 6:
		trail.pop_back()
	life -= delta
	if life <= 0.0 or to.y > 900.0:
		queue_free()
	queue_redraw()


func _end(pos: Vector2) -> void:
	Game.sfx("stone_hit", -6.0, 0.15)
	Game.burst(get_parent(), pos, Color(1.0, 0.9, 0.7, 0.8), 6, 90.0)
	queue_free()


func _draw() -> void:
	for i in trail.size():          # a faint streak of dust behind it, not a glowing tail
		draw_circle(to_local(trail[i]), 2.2 - i * 0.3, Color(0.8, 0.74, 0.62, 0.22 - i * 0.03))
	if tex == null:
		tex = load("res://art/props/smooth_stone.png")
	var w := 13.0
	var h := w * tex.get_height() / tex.get_width()
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
