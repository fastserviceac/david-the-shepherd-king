extends Node2D
## A sheep (or lamb). Walk into it to gather it; gathered sheep follow David.

const FA = preload("res://scripts/systems/frame_anim.gd")

var rig
var gait := 0.0

var level
var gathered := false
var gatherable := true
var follow_index := 0
var size := 1.0
var wool := Color(1, 1, 1)
var face := 1.0
var t := 0.0
var hop := 0.0
var moving := false
var wild := false         # will not let him near at any pace: only his call brings it
var skittish := false     # bolts if he comes at a run: walk up to it, or call it
var called := 0.0         # seconds it keeps coming to his call
var bolt := 0.0
var bolt_dir := 1.0
var home_x := 0.0
var stay := NAN           # told to stay: the spot it keeps to instead of following
var max_speed := 300.0    # how fast it will go to keep up or to reach its spot
var vel := 0.0            # its speed along the ground just now
var going := false
var pace := 0.0
var mark := Color(0, 0, 0, 0)    # another man's mark daubed on its rump, if it is not David's
var leap := -1.0          # 0..1 while it jumps a gap
var leap_a := Vector2.ZERO
var leap_b := Vector2.ZERO
var leap_dur := 0.4
var threat := 0.0        # 0..1: how near a beast at its side is to carrying it off
var worried := 0.0       # seconds since a beast was last at it (counts down)
var bleat := 0.0


func _ready() -> void:
	z_index = 3
	t = randf() * 10.0
	home_x = position.x
	add_to_group("sheep")


func _process(delta: float) -> void:
	t += delta
	hop = maxf(0.0, hop - delta * 2.5)
	if worried > 0.0:          # a beast is at it: it cries out, and will be carried off if he does not come
		worried -= delta
		bleat -= delta
		if bleat <= 0.0:
			bleat = 0.7
			hop = 1.0
			Game.sfx("lamb" if size < 0.9 else "sheep", -3.0, 0.25)
		if threat >= 1.0:
			level.sheep_taken(self)
	else:
		threat = maxf(0.0, threat - delta * 0.3)
	var player = level.player
	if not is_instance_valid(player):
		return
	moving = false
	if not gathered and gatherable and not Game.backdrop and not Game.cinematic:
		var to: float = player.global_position.x - global_position.x
		if bolt > 0.0:            # running off a little way
			bolt -= delta
			_walk(bolt_dir * 230.0, delta)
		elif called > 0.0:        # coming to his voice
			called -= delta
			if absf(to) > 30.0:
				_walk(signf(to) * 120.0, delta)
		elif (wild and absf(to) < 170.0 and absf(player.global_position.y - global_position.y) < 90.0) \
				or (skittish and absf(to) < 150.0 and absf(player.global_position.y - global_position.y) < 90.0 \
				and absf(player.velocity.x) > 175.0):
			bolt = 0.75
			bolt_dir = -signf(to) if absf(global_position.x - home_x) < 330.0 else signf(home_x - global_position.x)
			hop = 1.0
			Game.sfx("sheep", -8.0, 0.2)
	if not gathered:
		if gatherable and not Game.backdrop and global_position.distance_to(player.global_position + Vector2(0, -20)) < 52.0:
			gathered = true
			Game.sfx("lamb" if size < 0.9 else "sheep", -6.0, 0.12)
			Game.sfx("gather", -8.0, 0.05)
			hop = 1.0
			level.on_sheep(self)
	elif leap >= 0.0:         # in the air over a gap
		leap += delta / leap_dur
		var u := minf(leap, 1.0)
		# the jump itself is in its frames now (it gathers, springs and lands); the path only carries it across
		global_position = leap_a.lerp(leap_b, u) + Vector2(0, -sin(u * PI) * (8.0 + absf(leap_b.x - leap_a.x) * 0.08))
		moving = true
		if leap >= 1.0:
			leap = -1.0
			global_position = leap_b
	else:
		var target: float = player.global_position.x - player.facing * (48.0 + follow_index * 32.0)
		if not is_nan(stay):
			target = stay
		var dx := target - global_position.x
		# it sets off only when he has drawn well ahead, and settles once it is close: no shuffling on the spot
		if going:
			going = absf(dx) > 10.0
		else:
			going = absf(dx) > (34.0 if is_nan(stay) else 18.0)
		var want := 0.0
		if going:
			want = signf(dx) * minf(absf(dx) * 2.6 + 26.0, max_speed)
		vel = move_toward(vel, want, (520.0 if want != 0.0 else 700.0) * delta)      # it gathers speed and slows; it does not snap
		if absf(vel) > 4.0:
			var step := vel * delta
			var gy: float = level.ground_y(global_position.x + step)
			if is_nan(gy):        # the ground ends: jump to the far side if there is one within reach, else wait at the edge
				var dir := signf(dx)
				vel = 0.0
				for k in range(1, 46):
					var lx := global_position.x + dir * k * 10.0
					var ly: float = level.ground_y(lx)
					if not is_nan(ly):
						if absf(target - global_position.x) > k * 10.0 - 20.0:
							leap = 0.0
							leap_a = global_position
							leap_b = Vector2(lx + dir * 14.0, level.ground_y(lx + dir * 14.0) if not is_nan(level.ground_y(lx + dir * 14.0)) else ly)
							leap_dur = clampf(k * 10.0 / 330.0, 0.3, 0.9)
							face = dir
						break
			else:
				moving = true
				if absf(vel) > 24.0:
					face = signf(vel)        # it turns only when it is really going that way
				global_position.x += step
				global_position.y = lerpf(global_position.y, gy, minf(1.0, delta * 14.0))
		pace = absf(vel)
	queue_redraw()


func _walk(vx: float, delta: float) -> void:
	var nx := global_position.x + vx * delta
	var gy: float = level.ground_y(nx)
	if is_nan(gy) or absf(gy - global_position.y) > 40.0:      # it will not leave its own ground
		bolt = 0.0
		return
	moving = true
	pace = absf(vx)
	face = signf(vx)
	global_position = Vector2(nx, lerpf(global_position.y, gy, minf(1.0, delta * 14.0)))


func _draw() -> void:
	var lift := -absf(sin(hop * PI)) * 9.0 * hop      # one small start, not a bounce
	var tex: Texture2D
	var jump: Array = FA.frames("sheep", "leap")
	if leap >= 0.0 and not jump.is_empty():
		tex = jump[clampi(int(clampf(leap, 0.0, 1.0) * (jump.size() - 1)), 0, jump.size() - 1)]
		FA.draw(self, tex, face, 0.46 * size, wool, 2.7, 0.0, Vector2.ZERO, Vector2.ONE, lift)
		return
	if moving:
		var arr: Array = FA.frames("sheep", "walk")
		gait += get_process_delta_time() * clampf(8.0 + pace * 0.16, 10.0, 46.0)      # legs keep time with the ground covered
		tex = arr[int(gait) % arr.size()]
	else:
		# standing: graze, look up, graze again (played forward then back)
		var g: Array = FA.frames("sheep", "graze")
		var n := g.size()
		var k := int(t * 12.0) % maxi(1, 2 * n - 2)
		tex = g[k if k < n else 2 * n - 2 - k]
	FA.draw(self, tex, face, 0.46 * size, wool, 1.4, 0.0, Vector2.ZERO, Vector2.ONE, lift)
	if threat > 0.02:          # how close it is to being lost: a ring closing over it
		var at := Vector2(0, -62.0 * size + lift)
		var hot := Color(1.0, 0.36, 0.22, 0.55 + 0.4 * absf(sin(t * 9.0)))
		draw_arc(at, 11.0, 0.0, TAU, 24, Color(0.05, 0.03, 0.03, 0.6), 5.0, true)
		draw_arc(at, 11.0, -PI * 0.5, -PI * 0.5 + TAU * minf(threat, 1.0), 24, hot, 3.5, true)
	if mark.a > 0.0:
		var mc := Vector2(-face * 13.0 * size, -39.0 * size + lift)
		for k in 6:          # soft-edged: many faint layers, widest first
			var f := 1.0 - k / 6.0
			draw_set_transform(mc, -face * 0.35, Vector2(1.5, 0.8))
			draw_circle(Vector2.ZERO, 7.5 * size * f, Color(mark.r, mark.g, mark.b, mark.a * 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
