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


func _ready() -> void:
	z_index = 2
	add_to_group("hittable")
	tex = load("res://art/props/d_boulder.png")
	if is_instance_valid(level):
		tint = level.pal.get("char", Color(1, 1, 1))
	glow = Game.glow(Color(1.0, 0.85, 0.55, 0.4), 150.0)
	glow.position = Vector2(0, -rest.size.y * 0.5)
	add_child(glow)


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
	var to := Vector2(rest.position.x + rest.size.x * 0.5, rest.position.y + rest.size.y)
	var drop := maxf(to.y - position.y, 1.0)
	var secs := 0.0 if Game.fast else sqrt(2.0 * drop / 1500.0) + 0.15
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + from_dir * 8.0, 0.15 if not Game.fast else 0.0)
	tw.tween_property(self, "position", to, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation", from_dir * 1.6, secs)
	tw.tween_callback(_landed.bind(from_dir))


func _landed(from_dir: int) -> void:
	rotation = 0.0
	if not is_instance_valid(level):
		return
	level.add_block(rest, false)
	Game.sfx("bridge", -2.0)
	Game.burst(level, position, Color(0.8, 0.74, 0.62, 0.6), 22, 170.0)
	if is_instance_valid(level.player):
		level.player.shake = maxf(level.player.shake, 6.0)
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


func _draw() -> void:
	var w := rest.size.x + 18.0
	var h := rest.size.y + 14.0
	draw_texture_rect(tex, Rect2(-w * 0.5, -h + 4.0, w, h), false, tint)
