extends Node2D
## The loaded donkey of 1 Samuel 16:20. It follows the one who leads it, a few paces behind, and where something
## frightens it (`level.donkey_fear(x)` says how much) it plants its feet and will not go on. A phrase of the lyre
## quiets it for a few seconds, no longer: a donkey forgets sooner than a sheep, so it is brought through by
## playing as he walks, not by playing and then walking.
## Its pictures are art/donkey/anim/{idle,walk,balk,calm}_NN.png; until they are cut nothing is drawn.

const FA = preload("res://scripts/systems/frame_anim.gd")
const QUIET := 3.6        # seconds one landed phrase keeps it quiet
const SPEED := 118.0

var level
var led := false          # he has its halter: it follows him
var balking := false
var quiet := 0.0          # seconds of quiet left from the last phrase
var balks := 0            # how many times it has planted its feet (for the lesson, and the tests)
var face := -1.0
var moving := false
var t := 0.0
var gait := 0.0
var ease_t := 0.0         # the moment of letting go of its fright (the "calm" frames play once)


func _ready() -> void:
	z_index = 3
	add_to_group("donkey")


## A phrase has landed where it can hear.
func hear(from: Vector2, reach: float) -> void:
	if absf(from.x - global_position.x) > reach:
		return
	quiet = QUIET * float(Game.diff()["warning"])
	if balking:
		balking = false
		ease_t = 1.0


func _process(delta: float) -> void:
	t += delta
	quiet = maxf(0.0, quiet - delta)
	ease_t = maxf(0.0, ease_t - delta)
	moving = false
	var player = level.player
	if not led or not is_instance_valid(player) or Game.cinematic:
		queue_redraw()
		return
	var fear: float = level.donkey_fear(global_position.x) if level.has_method("donkey_fear") else 0.0
	if fear > 0.0 and quiet <= 0.0:
		if not balking:
			balking = true
			balks += 1
			Game.sfx("land", -6.0, 0.1, 0.8)
			if level.has_method("donkey_balked"):
				level.donkey_balked(self)
	elif fear <= 0.0:
		balking = false
	if not balking and ease_t <= 0.0:
		var target: float = player.global_position.x - player.facing * 92.0
		var dx := target - global_position.x
		if absf(dx) > 26.0 and absf(dx) < 520.0:      # left too far behind, it waits to be come back for
			var step := signf(dx) * minf(SPEED, absf(dx) * 2.4 + 20.0) * delta
			var gy: float = level.ground_y(global_position.x + step)
			if not is_nan(gy):
				global_position = Vector2(global_position.x + step, lerpf(global_position.y, gy, minf(1.0, delta * 14.0)))
				face = signf(dx)
				moving = true
				gait += delta * 11.0
	queue_redraw()


func _draw() -> void:
	var set_name := "idle"
	if balking:
		set_name = "balk"
	elif ease_t > 0.0:
		set_name = "calm"
	elif moving:
		set_name = "walk"
	var arr: Array = FA.frames("donkey", set_name)
	if arr.is_empty():
		return
	var tex: Texture2D
	if set_name == "walk":
		tex = arr[int(gait) % arr.size()]
	elif set_name == "calm":
		tex = arr[clampi(int((1.0 - ease_t) * arr.size()), 0, arr.size() - 1)]
	elif set_name == "balk":
		tex = FA.pingpong(arr.slice(arr.size() / 2), t, 6.0)      # braced: the held end of the clip, to and fro
	else:
		tex = FA.pingpong(arr, t, 7.0)
	FA.shadow(self, 74.0, 0.9)
	FA.draw(self, tex, face, 0.5, Color(1, 1, 1), 1.4)
