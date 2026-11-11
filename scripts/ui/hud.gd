extends Control
## Hearts, flock count, sling marker and the boss bar.

const D = preload("res://scripts/systems/draw_util.gd")
const FA = preload("res://scripts/systems/frame_anim.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var notices: Array = []      # what he has just grown into: [title, line, seconds left]
var panel := 0.0             # the growth page, held open with Tab
var stone_t := 0.0
var toasts: Array = []       # a craft strengthened: [craft, rank, seconds left]
var place_t := 0.0
var place_name := ""


func _enter_tree() -> void:
	if not Game.grew.is_connected(_on_grew):
		Game.grew.connect(_on_grew)
		Game.gifted.connect(_on_gift)
		Game.stone_found.connect(_on_stone)
		Game.place_found.connect(func(n: String) -> void:
			place_name = n
			place_t = 6.0)


## A craft strengthened: one quiet line, no more.
func _on_grew(craft: String, rank: int) -> void:
	toasts.append([craft, rank, 5.5])
	Game.sfx("gather", -10.0, 0.0)


## A gift given: the emblem, its name written large, and what it is.
func _on_gift(id: String) -> void:
	var g: Dictionary = Game.GIFTS[id]
	notices.append([g["name"], g["line"], 7.0, g["craft"], 0])
	Game.sfx("anoint", -5.0, 0.0)
	Game.sfx("gather", -3.0, 0.0)
	Game.sfx("fire", -8.0, 0.0)


## The emblem of a craft, drawn in gold line: what the hand, eye, foot, heart or voice is for.
func _emblem(craft: String, at: Vector2, a: float) -> void:
	var gold := Color(1.0, 0.86, 0.5, a)
	match craft:
		"feet":       # a sandalled foot in stride, with lines of speed
			draw_polyline(PackedVector2Array([at + Vector2(-14, 10), at + Vector2(12, 10), at + Vector2(16, 4), at + Vector2(4, 0), at + Vector2(-4, -14), at + Vector2(-12, -14), at + Vector2(-14, 10)]), gold, 2.4, true)
			for k in 3:
				draw_line(at + Vector2(-30, -8 + k * 8), at + Vector2(-20, -8 + k * 8), gold, 2.0, true)
		"hand":       # the shepherd's crook
			draw_line(at + Vector2(-6, 22), at + Vector2(-6, -8), gold, 3.0, true)
			draw_arc(at + Vector2(3, -8), 9.0, PI, TAU + 0.6, 14, gold, 3.0, true)
		"eye":        # the sling and its stone
			draw_arc(at + Vector2(0, -2), 17.0, 0.5, PI - 0.5, 14, gold, 2.4, true)
			draw_line(at + Vector2(-15, 6), at + Vector2(-20, -18), gold, 2.0, true)
			draw_line(at + Vector2(15, 6), at + Vector2(20, -18), gold, 2.0, true)
			draw_circle(at + Vector2(0, 12), 5.0, gold)
		"heart":
			draw_arc(at + Vector2(-8, -4), 8.5, PI, TAU, 12, gold, 2.6, true)
			draw_arc(at + Vector2(8, -4), 8.5, PI, TAU, 12, gold, 2.6, true)
			draw_polyline(PackedVector2Array([at + Vector2(-16.5, -4), at + Vector2(0, 18), at + Vector2(16.5, -4)]), gold, 2.6, true)
		_:            # the voice: a ram's horn and the sound going out from it
			draw_arc(at + Vector2(-4, 4), 13.0, PI * 0.5, PI * 1.6, 12, gold, 4.0, true)
			for k in 3:
				draw_arc(at + Vector2(4, -6), 10.0 + k * 7.0, -0.7, 0.5, 8, Color(gold.r, gold.g, gold.b, a * (1.0 - k * 0.28)), 2.0, true)


func _on_stone(_total: int) -> void:
	stone_t = 4.0


var hurt_flash := 0.0
var hearts_t := 3.0      # seconds the hearts stay up
var last_hp := -1


func _process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.2)
	hearts_t = maxf(0.0, hearts_t - delta)
	stone_t = maxf(0.0, stone_t - delta)
	place_t = maxf(0.0, place_t - delta)
	if not toasts.is_empty():
		toasts[0][2] -= delta
		if toasts[0][2] <= 0.0:
			toasts.pop_front()
	panel = move_toward(panel, 1.0 if Input.is_action_pressed("growth") else 0.0, delta * 6.0)
	if not notices.is_empty() and (Game.gifting or not Game.cinematic):
		notices[0][2] -= delta
		if notices[0][2] <= 0.0:
			notices.pop_front()
	queue_redraw()


func _draw() -> void:
	var level = Game.main.level
	if level == null or not is_instance_valid(level) or not is_instance_valid(level.player) or (Game.cinematic and not Game.gifting):
		return
	var player = level.player
	if hurt_flash > 0.0:
		for k in 5:   # red closing in from the edges
			var inset := k * 26.0
			draw_rect(Rect2(inset, inset, 1280.0 - inset * 2.0, 720.0 - inset * 2.0), Color(0.8, 0.08, 0.05, 0.07 * hurt_flash), false, 54.0)

	# hearts show when health changes or is low, then fade away
	if player.hp != last_hp:
		last_hp = player.hp
		hearts_t = 3.5
	var ha := 1.0 if player.hp < player.max_hp else clampf(hearts_t, 0.0, 1.0)
	for i in player.max_hp:
		var c := Vector2(38.0 + i * 28.0, 36.0)
		var col := Color(0.92, 0.36, 0.3, ha) if i < player.hp else Color(0, 0, 0, 0.3 * ha)
		draw_set_transform(c, 0.0, Vector2(0.8, 0.8))
		c = Vector2.ZERO
		draw_circle(c + Vector2(-6, -4), 7.5, col)
		draw_circle(c + Vector2(6, -4), 7.5, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -1), c + Vector2(13, -1), c + Vector2(0, 14)]), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if level.sheep_total > 0:
		# a small painted sheep and the count, quiet in the corner
		var icon: Array = FA.frames("sheep", "walk")
		if not icon.is_empty():
			var tex: Texture2D = icon[0]
			var k := 46.0 / tex.get_height()
			draw_texture_rect(tex, Rect2(26.0, 62.0, tex.get_width() * k, 46.0), false, Color(1, 1, 1, 0.92))
		draw_string(Game.serif, Vector2(112.0, 96.0), "%d / %d" % [level.sheep_count, level.sheep_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Game.CREAM.r, Game.CREAM.g, Game.CREAM.b, 0.9))

	if Game.save.get("has_sling", false):
		var s := Vector2(1232.0, 40.0)
		draw_arc(s + Vector2(0, -6), 12.0, 0.3, PI - 0.3, 12, Game.CREAM, 2.5, true)
		draw_circle(s + Vector2(0, 5), 4.0, Game.CREAM)

	# smooth stones: shown for a moment when one is found
	var cream := Game.CREAM
	if stone_t > 0.0 or panel > 0.0:
		var sa := maxf(clampf(stone_t, 0.0, 1.0), panel)
		var sp := Vector2(1150.0, 40.0)
		var st: Texture2D = load("res://art/props/smooth_stone.png")
		draw_texture_rect(st, Rect2(sp.x - 17.0, sp.y - 13.0, 34.0, 34.0 * st.get_height() / st.get_width()), false, Color(1, 1, 1, sa))
		draw_string(Game.serif, sp + Vector2(16, 8), "%d" % Game.stones().size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(cream.r, cream.g, cream.b, sa))

	# a place come upon: its name, quietly, under the top edge
	if place_t > 0.0:
		var pa := clampf(minf(place_t, 6.0 - place_t) * 1.6, 0.0, 1.0)
		var gold := Color(1.0, 0.86, 0.55, pa)
		draw_string(Game.serif, Vector2(0, 96), Game.t("A place found").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 1280, 15, Color(gold.r, gold.g, gold.b, pa * 0.8))
		draw_line(Vector2(590, 106), Vector2(690, 106), Color(gold.r, gold.g, gold.b, pa * 0.6), 1.0)
		draw_string_outline(Game.serif, Vector2(0, 140), Game.t(place_name), HORIZONTAL_ALIGNMENT_CENTER, 1280, 32, 6, Color(0.03, 0.02, 0.05, pa * 0.6))
		draw_string(Game.serif, Vector2(0, 140), Game.t(place_name), HORIZONTAL_ALIGNMENT_CENTER, 1280, 32, Color(Game.CREAM.r, Game.CREAM.g, Game.CREAM.b, pa))

	# what he has just grown into: an emblem in a ring of light, his new craft named large, and what it gives him
	if not notices.is_empty():
		var n: Array = notices[0]
		var age: float = 7.0 - n[2]
		var na := clampf(minf(age * 2.5, n[2] * 1.4), 0.0, 1.0)
		var open := clampf(age / 0.6, 0.0, 1.0)
		open = 1.0 - pow(1.0 - open, 3.0)
		var c0 := Vector2(640.0, 150.0)
		draw_rect(Rect2(0, 60, 1280, 250), Color(0.02, 0.02, 0.05, 0.34 * na))
		for k in 12:          # rays turning slowly behind the emblem
			var ang := TAU * k / 12.0 + age * 0.35
			draw_line(c0 + Vector2(cos(ang), sin(ang)) * 46.0 * open, c0 + Vector2(cos(ang), sin(ang)) * (62.0 + 10.0 * sin(age * 3.0 + k)) * open, Color(1.0, 0.86, 0.5, 0.55 * na), 2.0, true)
		draw_circle(c0, 40.0 * open, Color(0.04, 0.03, 0.06, 0.7 * na))
		draw_arc(c0, 40.0 * open, 0.0, TAU, 48, Color(1.0, 0.86, 0.5, na), 2.4, true)
		if open > 0.6:
			_emblem(str(n[3]), c0, na)
		var title: String = Game.t(n[0]).to_upper()
		draw_string(Game.serif, Vector2(0, 248.0), title, HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 46, Color(cream.r, cream.g, cream.b, na))
		var half := 150.0 * open
		draw_line(Vector2(640.0 - half, 262.0), Vector2(640.0 + half, 262.0), Color(1.0, 0.86, 0.5, 0.8 * na), 1.6, true)
		for k in (3 if int(n[4]) > 0 else 0):           # how far he has come in this craft
			var filled: bool = k < int(n[4])
			draw_circle(Vector2(640.0 - 18.0 + k * 18.0, 262.0), 5.0, Color(0.04, 0.03, 0.06, na))
			draw_circle(Vector2(640.0 - 18.0 + k * 18.0, 262.0), 3.6, Color(1.0, 0.86, 0.5, na) if filled else Color(1, 1, 1, 0.25 * na))
		draw_string(Game.serif, Vector2(240.0, 292.0), Game.t(n[1]), HORIZONTAL_ALIGNMENT_CENTER, 800.0, 20, Color(cream.r, cream.g, cream.b, 0.9 * na))

	# a craft strengthened: its name, its marks and what changed, small, low on the left
	if not toasts.is_empty():
		var tt: Array = toasts[0]
		var ta := clampf(minf(5.5 - tt[2], tt[2]) * 2.0, 0.0, 1.0)
		var tc: Dictionary = Game.CRAFTS[tt[0]]
		var tp := Vector2(40.0, 560.0)
		draw_string(Game.serif, tp, Game.t(tc["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.86, 0.55, ta))
		var tw := Game.serif.get_string_size(Game.t(tc["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		for k in 3:
			draw_circle(tp + Vector2(tw + 16.0 + k * 13.0, -6.0), 3.6, Color(1.0, 0.86, 0.5, ta) if k < int(tt[1]) else Color(1, 1, 1, 0.25 * ta))
		draw_string(Game.serif, tp + Vector2(0, 22), Game.t(tc["gifts"][int(tt[1]) - 1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(cream.r, cream.g, cream.b, 0.85 * ta))

	# the growth page
	if panel > 0.01:
		var x0 := 330.0
		var y0 := 190.0
		draw_rect(Rect2(x0 - 30.0, y0 - 50.0, 680.0, 400.0), Color(0.03, 0.03, 0.07, 0.78 * panel))
		draw_string(Game.serif, Vector2(x0, y0 - 14.0), Game.t("The making of a shepherd"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.85, 0.5, panel))
		for i in Game.CRAFT_ORDER.size():
			var id: String = Game.CRAFT_ORDER[i]
			var c: Dictionary = Game.CRAFTS[id]
			var r: int = Game.rank(id)
			var y := y0 + 30.0 + i * 64.0
			var his: bool = Game.has(c["gift"])       # not yet given: shown faint
			draw_string(Game.serif, Vector2(x0, y), Game.t(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(cream.r, cream.g, cream.b, panel * (1.0 if his else 0.4)))
			for k in 3:
				draw_circle(Vector2(x0 + 214.0 + k * 20.0, y - 7.0), 6.0, Color(1.0, 0.8, 0.4, panel) if k < r else Color(1, 1, 1, 0.16 * panel))
			# how far towards the next mark
			var marks: Array = c["marks"]
			var lo: float = 0.0 if r == 0 else float(marks[r - 1])
			var hi: float = float(marks[mini(r, 2)])
			var f := 1.0 if r >= 3 else clampf((Game.craft_xp(id) - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
			draw_rect(Rect2(x0 + 290.0, y - 12.0, 300.0, 8.0), Color(1, 1, 1, 0.12 * panel))
			draw_rect(Rect2(x0 + 290.0, y - 12.0, 300.0 * f, 8.0), Color(1.0, 0.8, 0.4, 0.9 * panel))
			var line: String = (Game.t("Grows by %s.") % Game.t(c["by"])) if r == 0 else Game.t(c["gifts"][r - 1])
			if not his:
				line = Game.t("Not yet given.")
			draw_string(Game.serif, Vector2(x0, y + 22.0), line, HORIZONTAL_ALIGNMENT_LEFT, 620.0, 16, Color(cream.r, cream.g, cream.b, 0.7 * panel))

	var boss = level.boss
	if boss != null and is_instance_valid(boss):
		var w := 460.0
		var x := 640.0 - w * 0.5
		draw_string(Game.serif, Vector2(x, 632), Game.t(level.boss_name), HORIZONTAL_ALIGNMENT_CENTER, w, 22, Game.CREAM)
		draw_rect(Rect2(x - 2, 644, w + 4, 14), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(x, 646, w * float(boss.hp) / float(boss.max_hp), 10), Color(1.0, 0.72, 0.25))
		for f in [0.33, 0.66]:      # where the fight changes
			draw_rect(Rect2(x + w * f - 1.0, 644, 2.0, 14), Color(0.05, 0.04, 0.08, 0.9))
