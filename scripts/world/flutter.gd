extends Node2D
## A butterfly (or, at dusk, a moth) wandering round one patch of flowers.

var home := Vector2.ZERO
var wing := Color(1.0, 0.95, 0.8)
var t := 0.0
var goal := Vector2.ZERO
var rest := 0.0
var seed_f := 0.0


func _ready() -> void:
	home = position
	seed_f = randf() * 100.0
	goal = home
	z_index = 7


func _process(delta: float) -> void:
	t += delta
	if rest > 0.0:
		rest -= delta
	elif position.distance_to(goal) < 6.0:
		if randf() < 0.3:
			rest = randf_range(0.8, 2.5)        # settles for a moment
		goal = home + Vector2(randf_range(-150.0, 150.0), randf_range(-110.0, -8.0))
	else:
		var want := (goal - position).normalized() * 46.0
		position += (want + Vector2(sin(t * 5.0 + seed_f) * 26.0, cos(t * 6.3 + seed_f) * 30.0)) * delta
	queue_redraw()


func _draw() -> void:
	var open := absf(sin(t * (5.0 if rest > 0.0 else 17.0) + seed_f))       # wings seen edge-on, then flat
	var dark := Color(wing.r * 0.6, wing.g * 0.5, wing.b * 0.4, wing.a)
	for side in [-1.0, 1.0]:
		draw_set_transform(Vector2(side * (0.4 + 1.5 * open), -0.9), side * 0.35, Vector2(0.25 + 0.75 * open, 1.0))
		draw_circle(Vector2.ZERO, 2.2, wing)
		draw_set_transform(Vector2(side * (0.3 + 1.1 * open), 1.3), -side * 0.3, Vector2(0.25 + 0.75 * open, 1.0))
		draw_circle(Vector2.ZERO, 1.6, dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(0, -2.0), Vector2(0, 2.4), Color(0.12, 0.1, 0.1, wing.a), 0.9, true)
