extends RefCounted
## A jointed painted four-legged animal: body, head, front leg, hind leg and
## (for some) a tail. Poses are worked out facing right, then mirrored.

const RIGS := {
	"sheep": {"k": 0.21, "hip": Vector2(0.2, 0.62), "shoulder": Vector2(0.78, 0.62), "neck": Vector2(0.9, 0.38),
		"tail_at": Vector2(0.03, 0.35), "head_pivot": Vector2(0.25, 0.5), "leg": 0.6, "stride": 0.45, "tail": true},
	"jackal": {"k": 0.27, "hip": Vector2(0.14, 0.55), "shoulder": Vector2(0.8, 0.5), "neck": Vector2(0.92, 0.3),
		"tail_at": Vector2(0.03, 0.3), "head_pivot": Vector2(0.25, 0.62), "leg": 0.85, "stride": 0.6, "tail": true},
	"bear": {"k": 0.43, "hip": Vector2(0.2, 0.6), "shoulder": Vector2(0.78, 0.55), "neck": Vector2(0.93, 0.36),
		"tail_at": Vector2(0, 0), "head_pivot": Vector2(0.22, 0.55), "leg": 0.72, "stride": 0.4, "tail": false},
	"lion": {"k": 0.44, "hip": Vector2(0.14, 0.5), "shoulder": Vector2(0.84, 0.45), "neck": Vector2(0.97, 0.3),
		"tail_at": Vector2(0.02, 0.25), "head_pivot": Vector2(0.42, 0.52), "leg": 0.72, "stride": 0.55, "tail": true},
}

var rig: Dictionary
var tex := {}
var size := {}


func setup(animal: String) -> void:
	rig = RIGS[animal]
	var names := ["body", "head", "leg_f", "leg_h"]
	if rig["tail"]:
		names.append("tail")
	for n in names:
		var img: Image = load("res://art/%s/%s.png" % [animal, n]).get_image()
		img.generate_mipmaps()
		tex[n] = ImageTexture.create_from_image(img)
		size[n] = Vector2(img.get_width(), img.get_height())


## Standing height of the back above the ground, in game pixels.
func height(scale: float = 1.0) -> float:
	return (size["leg_h"].y * 0.86 * rig["leg"] + size["body"].y * rig["hip"].y) * rig["k"] * scale


## pose keys (all optional): phase, speed, bob, body_rot, head_rot, tail_rot,
## front, hind (extra leg angles, positive = forward), crouch (0..1), scale.
func draw(ci: CanvasItem, facing: float, col: Color, pose: Dictionary) -> void:
	var k: float = rig["k"] * pose.get("scale", 1.0)
	var base := Transform2D(0.0, Vector2(facing * k, k), 0.0, Vector2.ZERO)
	var far := Color(col.r * 0.6, col.g * 0.56, col.b * 0.66, col.a)
	var ls: float = rig["leg"]
	var hip: Vector2 = rig["hip"] * size["body"]
	var sh: Vector2 = rig["shoulder"] * size["body"]
	var len_h: float = size["leg_h"].y * 0.86 * ls
	var crouch: float = pose.get("crouch", 0.0)
	var drop := 0.34 * crouch
	var splay := acos(1.0 - drop)
	var body_rot: float = pose.get("body_rot", 0.0)
	var origin := Vector2(-(sh.x - hip.x) * 0.5, -len_h * (1.0 - drop) + pose.get("bob", 0.0))
	var body := Transform2D(body_rot, origin)

	var ph: float = pose.get("phase", 0.0)
	var amp: float = rig["stride"] * pose.get("speed", 0.0)
	var front: float = pose.get("front", 0.0) + splay
	var hind: float = pose.get("hind", 0.0) + splay
	var shoulder := body * (sh - hip)
	var hip_w := origin

	# far side first, darker
	_leg(ci, base, "leg_h", hip_w + Vector2(14, 0), sin(ph) * amp + hind, ls, far)
	_leg(ci, base, "leg_f", shoulder + Vector2(14, 0), sin(ph + PI) * amp + front, ls, far)
	if rig["tail"]:
		var t_at: Vector2 = body * (rig["tail_at"] * size["body"] - hip)
		ci.draw_set_transform_matrix(base * Transform2D(body_rot + 0.9 + pose.get("tail_rot", 0.0), t_at))
		ci.draw_texture(tex["tail"], Vector2(-size["tail"].x * 0.5, -size["tail"].y * 0.04), col)
	ci.draw_set_transform_matrix(base * body)
	ci.draw_texture(tex["body"], -hip, col)
	_leg(ci, base, "leg_h", hip_w + Vector2(-10, 0), sin(ph + PI) * amp + hind, ls, col)
	_leg(ci, base, "leg_f", shoulder + Vector2(-10, 0), sin(ph) * amp + front, ls, col)
	var neck: Vector2 = body * (rig["neck"] * size["body"] - hip)
	ci.draw_set_transform_matrix(base * Transform2D(body_rot * 0.6 + pose.get("head_rot", 0.0), neck))
	ci.draw_texture(tex["head"], -rig["head_pivot"] * size["head"], col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _leg(ci: CanvasItem, base: Transform2D, part: String, joint: Vector2, a: float, ls: float, col: Color) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(-a, Vector2(ls, ls), 0.0, joint))
	ci.draw_texture(tex[part], Vector2(-size[part].x * 0.5, -size[part].y * 0.1), col)
