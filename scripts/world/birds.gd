extends Node2D
## Far-off birds crossing the sky in loose flocks, now and then.
## Each bird is a real wingbeat cut into frames (art/bird/anim/fly_NN.png); without them, simple strokes.

const FA = preload("res://scripts/systems/frame_anim.gd")
var wing: Array = []

var span := 2400.0          # width of sky they cross, in this layer's own coordinates
var tint := Color(0.08, 0.06, 0.1, 0.75)
var every := Vector2(7.0, 18.0)
var flocks: Array = []
var wait := 2.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	wing = FA.frames("bird", "fly")
	rng.randomize()
	wait = rng.randf_range(0.2, 1.5)


func _process(delta: float) -> void:
	wait -= delta
	if wait <= 0.0:
		wait = rng.randf_range(every.x, every.y)
		_launch()
	for f in flocks:
		f["x"] += f["v"] * delta
		f["t"] += delta
	flocks = flocks.filter(func(f): return f["x"] > -400.0 and f["x"] < span + 400.0)
	queue_redraw()


func _launch() -> void:
	var dir := -1.0 if rng.randf() < 0.5 else 1.0
	var birds: Array = []
	var n := rng.randi_range(2, 9)
	for i in n:
		# a loose V behind the leader
		var row := float((i + 1) / 2)
		var side := -1.0 if i % 2 == 0 else 1.0
		birds.append([Vector2(-dir * row * rng.randf_range(20.0, 30.0), side * row * rng.randf_range(9.0, 15.0) + rng.randf_range(-5.0, 5.0)), rng.randf() * TAU, rng.randf_range(0.85, 1.15)])
	flocks.append({"x": -300.0 if dir > 0.0 else span + 300.0, "y": rng.randf_range(60.0, 260.0), "v": dir * rng.randf_range(46.0, 80.0),
		"t": 0.0, "birds": birds, "size": rng.randf_range(0.7, 1.5), "drift": rng.randf_range(-6.0, 6.0)})


func _draw() -> void:
	# real feathers, dimmed a little by the distance
	var feather := Color(0.62, 0.58, 0.62, minf(1.0, tint.a + 0.2))
	for f in flocks:
		var s: float = f["size"]
		var dir := signf(f["v"])
		for b in f["birds"]:
			var at: Vector2 = Vector2(f["x"], f["y"] + f["drift"] * sin(f["t"] * 0.4)) + b[0] * s
			# wings beat, then glide for a moment
			var glide := smoothstep(0.55, 0.95, sin(f["t"] * 0.9 + b[1]))
			if not wing.is_empty():
				var n := wing.size()
				var beat_ph := fposmod(f["t"] * 3.4 * b[2] + b[1], 1.0)
				var k := int(beat_ph * n) % n
				if glide > 0.5:
					k = n - 1           # wings held out, gliding
				var tex: Texture2D = wing[k]
				var w := 46.0 * s
				var h := w * tex.get_height() / tex.get_width()
				at.y += sin(beat_ph * TAU) * 1.2 * s          # the body lifts a little on each downstroke
				draw_set_transform(at, 0.0, Vector2(dir, 1.0))
				draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, feather)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				continue
			var beat: float = sin(f["t"] * 7.5 * b[2] + b[1])
			var lift: float = lerpf(beat, 0.25, glide) * 5.0 * s
			var wd := 8.0 * s
			var body := at + Vector2(0, 1.0 * s)
			draw_polyline(PackedVector2Array([at + Vector2(-wd, -lift), at + Vector2(-wd * 0.45, -lift * 0.35 - 1.0 * s), body,
				at + Vector2(wd * 0.45, -lift * 0.35 - 1.0 * s), at + Vector2(wd, -lift)]), tint, 1.6 * s, true)
			draw_line(body, body + Vector2(dir * 2.5 * s, 0.3 * s), tint, 2.0 * s, true)
