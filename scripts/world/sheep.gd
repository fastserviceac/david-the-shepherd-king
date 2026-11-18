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
var kind := "sheep"       # whose pictures it wears (art/<kind>/anim): a wild goat is a sheep in everything but its looks
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
var mark_big := 1.0        # how large that daub is drawn (the road home wants it seen from a distance)
var leap := -1.0          # 0..1 while it jumps a gap
var leap_a := Vector2.ZERO
var leap_b := Vector2.ZERO
var leap_dur := 0.4
var threat := 0.0        # 0..1: how near a beast at its side is to carrying it off
var worried := 0.0       # seconds since a beast was last at it (counts down)
var bleat := 0.0
var safe := false         # no beast goes for it (the lamb once it has slipped away)
var prey := false         # a beast will go for it even though it is not yet his to gather (a strayed ewe)
var carried := false      # a beast has it in its jaws: it goes where the beast goes, and does not walk or answer a hand
var who := ""             # which of his own nine it is (its id in the save's flock); "" for another man's
var named := ""           # the name it answers to, if it has one
var name_t := 0.0         # seconds its name stays written over it
var restless := false     # will not stand: it paces, and trots off from his hand, until the lyre quiets it
var calm := 0.0           # seconds it stays settled by the song
var held_x := NAN         # where the song stopped it while it was following him
var rest_t := -1.0        # seconds since it lay down to the song (-1: on its feet)
var rise_t := -1.0        # seconds since it began to get up again (-1: not getting up)
var pose := ""            # a frame set of its own the story has it play (art/sheep/anim/<pose>_NN.png): labour, tending, a newborn's first stand
var pose_t := 0.0
var pose_fps := 8.0
var pose_once := false     # played once and held on its last frame, rather than back and forth
var pose_tall := 1.4       # the canvas height factor that set was cut with
const LIE_S := 1.6        # how long lying down takes, from its own frames (sheep_lie)
const RISE_S := 1.2       # and getting up again (the lying-down frames, backwards)
const TAKE := 4.0         # seconds with a beast at its side before it is carried off


func _ready() -> void:
	z_index = 3
	t = randf() * 10.0
	home_x = position.x
	add_to_group("sheep")


## The song has reached it. A beast at it is forgotten for a moment; it stops bolting; it stands for his hand;
## and if it was following him it holds where it is until he calls or the quiet wears off.
## `hold` false: played on his feet, so one that is following him goes on following, quieted.
func settle(seconds: float, hold: bool = true) -> void:
	calm = seconds
	bolt = 0.0
	called = 0.0
	worried = 0.0
	threat = maxf(0.0, threat - 0.5)
	name_t = 3.0
	if hold and gathered and is_nan(stay) and leap < 0.0:
		held_x = global_position.x
		stay = held_x
	if not Game.fast and not Game.backdrop:
		Game.burst(level, global_position + Vector2(0, -34.0 * size), Color(1.0, 0.9, 0.6, 0.7), 5, 50.0)


## The quiet is over: it follows him again.
func rouse() -> void:
	calm = 0.0
	if rest_t >= 0.0:
		rest_t = -1.0
		if not FA.frames(kind, "lie").is_empty():
			rise_t = 0.0          # it gets up the way a sheep does, hind legs first, before it goes anywhere
	if not is_nan(held_x) and stay == held_x:
		stay = NAN
		hop = 0.6
	held_x = NAN


func _process(delta: float) -> void:
	t += delta
	hop = maxf(0.0, hop - delta * 2.5)
	name_t = maxf(0.0, name_t - delta)
	if calm > 0.0:
		calm -= delta
		if calm <= 0.0:
			rouse()
	if worried > 0.0:          # a beast is at it: it cries out, and will be carried off if he does not come
		worried -= delta
		bleat -= delta
		threat += delta / (TAKE * float(Game.diff()["warning"]))       # however many are at it, it is one sheep and one count; a gentler game gives him longer
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
	if carried or worried > 0.0 or bolt > 0.0:
		rest_t = -1.0             # a fright: it is up at once, no slow rising
		rise_t = -1.0
	if rise_t >= 0.0:
		rise_t += delta
		if rise_t < RISE_S:
			queue_redraw()
			return                # still getting to its feet
		rise_t = -1.0
	if carried:
		queue_redraw()
		return
	if not gathered and gatherable and not Game.backdrop and not Game.cinematic:
		var to: float = player.global_position.x - global_position.x
		if bolt > 0.0:            # running off a little way
			bolt -= delta
			_walk(bolt_dir * 230.0, delta)
		elif called > 0.0:        # coming to his voice
			called -= delta
			if absf(to) > 30.0:
				_walk(signf(to) * 120.0, delta)
		elif calm > 0.0 and not wild:
			pass          # settled by the song: it stands where it is, and will stand for his hand
		elif (wild and absf(to) < 170.0 and absf(player.global_position.y - global_position.y) < 90.0) \
				or (restless and absf(to) < 150.0 and absf(player.global_position.y - global_position.y) < 90.0) \
				or (skittish and absf(to) < 150.0 and absf(player.global_position.y - global_position.y) < 90.0 \
				and absf(player.velocity.x) > 175.0):
			bolt = 0.75
			bolt_dir = -signf(to) if absf(global_position.x - home_x) < 330.0 else signf(home_x - global_position.x)
			hop = 1.0
			Game.sfx("sheep", -8.0, 0.2)
		elif restless:            # to and fro over the same few paces, never grazing
			if absf(global_position.x - home_x) > 70.0:
				bolt_dir = signf(home_x - global_position.x)
			_walk(bolt_dir * 62.0, delta)
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
	var jump: Array = FA.frames(kind, "leap")
	if leap >= 0.0 and not jump.is_empty():
		tex = jump[clampi(int(clampf(leap, 0.0, 1.0) * (jump.size() - 1)), 0, jump.size() - 1)]
		FA.draw(self, tex, face, 0.46 * size, wool, 2.7, 0.0, Vector2.ZERO, Vector2.ONE, lift)
		return
	var tall := 1.4
	if pose != "" and not FA.frames(kind, pose).is_empty():
		var pf: Array = FA.frames(kind, pose)
		pose_t += get_process_delta_time()
		tex = pf[mini(int(pose_t * pose_fps), pf.size() - 1)] if pose_once else FA.pingpong(pf, pose_t, pose_fps)
		tall = pose_tall
	elif moving:
		rest_t = -1.0
		var arr: Array = FA.frames(kind, "walk")
		var rn: Array = FA.frames(kind, "run")
		if (bolt > 0.0 or pace > 185.0) and not rn.is_empty():      # bolting, or hurrying to keep up: a real run
			arr = rn
		gait += get_process_delta_time() * clampf(8.0 + pace * 0.16, 10.0, 46.0)      # legs keep time with the ground covered
		tex = arr[int(gait) % arr.size()]
	elif rise_t >= 0.0 and not FA.frames(kind, "lie").is_empty():
		# getting up: its own lying down played back (the same cut sheep, so it leaves the rest pose exactly)
		var up: Array = FA.frames(kind, "lie")
		tex = up[clampi(up.size() - 1 - int(rise_t / RISE_S * up.size()), 0, up.size() - 1)]
	elif calm > 0.0 and not FA.frames(kind, "lie").is_empty() and not FA.frames(kind, "rest").is_empty():
		# quieted by the song and standing still: it lies down on its chest, then rests there, chewing
		if rest_t < 0.0:
			rest_t = 0.0
		rest_t += get_process_delta_time()
		var down: Array = FA.frames(kind, "lie")
		if rest_t < LIE_S:
			tex = down[clampi(int(rest_t / LIE_S * down.size()), 0, down.size() - 1)]
		else:
			tex = FA.pingpong(FA.frames(kind, "rest"), rest_t - LIE_S, 6.0)
	elif (worried > 0.0 or (restless and calm <= 0.0)) and not FA.frames(kind, "uneasy").is_empty():
		tex = FA.pingpong(FA.frames(kind, "uneasy"), t, 9.0)      # head high, a stamp, a look behind
	else:
		# standing: graze, look up, graze again (played forward then back)
		var g: Array = FA.frames(kind, "graze")
		var n := g.size()
		var k := int(t * (5.0 if calm > 0.0 else 12.0)) % maxi(1, 2 * n - 2)      # settled, it grazes slowly
		tex = g[k if k < n else 2 * n - 2 - k]
	FA.draw(self, tex, face, 0.46 * size, wool, tall, 0.0, Vector2.ZERO, Vector2.ONE, lift)
	if threat > 0.02:          # how close it is to being lost: a ring closing over it
		var at := Vector2(0, -62.0 * size + lift)
		var hot := Color(1.0, 0.36, 0.22, 0.55 + 0.4 * absf(sin(t * 9.0)))
		draw_arc(at, 14.0, 0.0, TAU, 28, Color(0.05, 0.03, 0.03, 0.65), 6.0, true)
		draw_arc(at, 14.0, -PI * 0.5, -PI * 0.5 + TAU * minf(threat, 1.0), 28, hot, 4.5, true)
		draw_line(at + Vector2(0, -6), at + Vector2(0, 2), hot, 3.0, true)      # and a mark inside it, so it reads from across the screen
		draw_circle(at + Vector2(0, 6.5), 1.8, hot)
	if named != "" and name_t > 0.0 and not Game.backdrop:      # the name it answers to, for a moment
		var na := clampf(minf(name_t, 3.0 - name_t) * 2.0, 0.0, 1.0)
		var label := Game.t(named)
		var lw := Game.serif.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var lp := Vector2(-lw * 0.5, -78.0 * size + lift)
		draw_string_outline(Game.serif, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.02, 0.02, 0.05, 0.6 * na))
		draw_string(Game.serif, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.93, 0.8, 0.95 * na))
	if mark.a > 0.0:
		var mc := Vector2(-face * 13.0 * size, -39.0 * size + lift)
		for k in 6:          # soft-edged: many faint layers, widest first
			var f := 1.0 - k / 6.0
			draw_set_transform(mc, -face * 0.35, Vector2(1.5, 0.8))
			draw_circle(Vector2.ZERO, 7.5 * size * f * mark_big, Color(mark.r, mark.g, mark.b, mark.a * 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
