extends RefCounted
## Shared silhouette drawing helpers.


static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, rot), col)


## Rounded line: a limb, tail or staff.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


## Robed standing figure. `base` is at the feet.
static func person(ci: CanvasItem, base: Vector2, h: float, col: Color, facing: float = 1.0, beard: bool = false, staff: bool = false, raise: float = 0.0) -> void:
	var sh := base + Vector2(0, -h * 0.8)
	var robe := PackedVector2Array([
		sh + Vector2(-h * 0.12, 0), sh + Vector2(h * 0.12, 0),
		base + Vector2(h * 0.17, 0), base + Vector2(-h * 0.17, 0)])
	ci.draw_colored_polygon(robe, col)
	var head := base + Vector2(facing * h * 0.02, -h * 0.9)
	ci.draw_circle(head, h * 0.1, col)
	if beard:
		ci.draw_colored_polygon(PackedVector2Array([
			head + Vector2(facing * h * 0.02, h * 0.03), head + Vector2(facing * h * 0.11, h * 0.04),
			head + Vector2(facing * h * 0.07, h * 0.24)]), col)
	# arm: hangs at the side, or lifts as `raise` goes to 1
	var hand := sh + Vector2(facing * h * 0.2, h * 0.3).lerp(Vector2(facing * h * 0.3, -h * 0.28), raise)
	limb(ci, sh + Vector2(facing * h * 0.08, h * 0.04), hand, h * 0.07, col)
	if raise > 0.05:
		# horn of oil in the raised hand
		ci.draw_colored_polygon(PackedVector2Array([
			hand + Vector2(-h * 0.04, -h * 0.02), hand + Vector2(h * 0.04, -h * 0.02),
			hand + Vector2(facing * h * 0.1, -h * 0.16)]), col)
	if staff:
		var foot := base + Vector2(-facing * h * 0.24, 0)
		limb(ci, foot, foot + Vector2(0, -h * 1.05), h * 0.035, col)
