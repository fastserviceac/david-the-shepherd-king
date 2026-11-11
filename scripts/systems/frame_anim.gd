extends RefCounted
## Frame-by-frame animation sets: res://art/<who>/anim/<name>_00.png, _01 ...
## Every frame of a set shares one canvas, with the figure's feet on a fixed
## ground line, so frames can be swapped without the figure jumping about.

const RES := 2.0      # frame images hold this many pixels per game unit

static var _cache := {}


static func frames(who: String, anim: String) -> Array:
	var id := who + "/" + anim
	if _cache.has(id):
		return _cache[id]
	var arr: Array = []
	var i := 0
	while true:
		var path := "res://art/%s/anim/%s_%02d.png" % [who, anim, i]
		if not ResourceLoader.exists(path):
			break
		arr.append(load(path))
		i += 1
	_cache[id] = arr
	return arr


## Draws a frame with its ground point (centre of the feet) at the origin.
## tall = canvas height factor used when the set was built (1.65 people, 1.4 animals).
static func draw(ci: CanvasItem, tex: Texture2D, facing: float, sc: float, col: Color, tall: float = 1.4,
		rot: float = 0.0, pivot: Vector2 = Vector2.ZERO, stretch: Vector2 = Vector2.ONE, lift: float = 0.0, shift_x: float = 0.0) -> void:
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var ground := Vector2(w * 0.5, h * tall / (tall + 0.1))
	sc /= RES
	pivot *= RES
	var base := Transform2D(0.0, Vector2(facing * sc * stretch.x, sc * stretch.y), 0.0, Vector2(shift_x, lift))
	ci.draw_set_transform_matrix(base * Transform2D(0.0, pivot) * Transform2D(rot, Vector2.ZERO) * Transform2D(0.0, -pivot))
	ci.draw_texture(tex, -ground, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Forward then backward through a set, so a non-looping clip plays smoothly forever.
static func pingpong(arr: Array, clock: float, fps: float) -> Texture2D:
	var n := arr.size()
	if n <= 1:
		return arr[0]
	var k := int(clock * fps) % (2 * n - 2)
	return arr[k if k < n else 2 * n - 2 - k]


## Soft contact shadow on the ground under a figure. `drop` is how far below the figure's feet the
## ground is: the shadow stays down there, and thins and spreads as the figure rises.
static func shadow(ci: CanvasItem, width: float, strength: float = 1.0, drop: float = 0.0) -> void:
	var high := clampf(drop / 260.0, 0.0, 1.0)
	var k := strength * (1.0 - high * 0.75)
	var w := width * (1.0 + high * 0.5)
	ci.draw_set_transform(Vector2(0, 3.0 + drop), 0.0, Vector2(1.0, 0.22))
	ci.draw_circle(Vector2.ZERO, w * 0.5, Color(0.02, 0.01, 0.05, 0.22 * k))
	ci.draw_circle(Vector2.ZERO, w * 0.32, Color(0.02, 0.01, 0.05, 0.22 * k))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How far below `body` the ground is, by a ray straight down. Large when over a pit.
static func ground_drop(body: Node2D, reach: float = 420.0) -> float:
	var from := body.global_position + Vector2(0, -6)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, reach), 1)
	if body is CollisionObject2D:
		q.exclude = [body.get_rid()]
	var hit := body.get_world_2d().direct_space_state.intersect_ray(q)
	return maxf(0.0, hit["position"].y - body.global_position.y) if not hit.is_empty() else reach
