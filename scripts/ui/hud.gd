extends Control
## Hearts, flock count, sling marker and the boss bar.

const D = preload("res://scripts/systems/draw_util.gd")
const FA = preload("res://scripts/systems/frame_anim.gd")
const STONE = preload("res://art/props/smooth_stone.png")


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


## One heart of his life: a deep red stone with the light on its shoulder and a thin gold edge, like the
## emblems of the crafts. An empty one is only its edge.
var _heart_shape: PackedVector2Array
func _heart(at: Vector2, size: float, full: bool, a: float, glow: float = 0.0) -> void:
	if _heart_shape.is_empty():
		for k in 40:
			var t := TAU * k / 40.0
			_heart_shape.append(Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * 0.74)
	var edge := PackedVector2Array(_heart_shape)
	edge.append(_heart_shape[0])
	if glow > 0.0:
		for r in 4:
			draw_circle(at, (17.0 + r * 5.0) * size, Color(1.0, 0.8, 0.45, 0.09 * glow * a))
	draw_set_transform(at + Vector2(1.5, 2.0), 0.0, Vector2(size, size))
	draw_colored_polygon(_heart_shape, Color(0, 0, 0, 0.32 * a))
	draw_set_transform(at, 0.0, Vector2(size, size))
	if full:
		draw_colored_polygon(_heart_shape, Color(0.5, 0.09, 0.09, a))
		draw_set_transform(at + Vector2(-0.8, -1.2) * size, 0.0, Vector2(size, size) * 0.84)
		draw_colored_polygon(_heart_shape, Color(0.8, 0.2, 0.16, a))
		draw_set_transform(at + Vector2(-2.2, -3.0) * size, 0.0, Vector2(size, size) * 0.58)
		draw_colored_polygon(_heart_shape, Color(0.93, 0.36, 0.27, 0.85 * a))
		draw_set_transform(at + Vector2(-5.2, -6.0) * size, -0.5, Vector2(size, size * 0.6))
		draw_circle(Vector2.ZERO, 2.6, Color(1.0, 0.88, 0.8, 0.55 * a))
		draw_set_transform(at, 0.0, Vector2(size, size))
		draw_polyline(edge, Color(1.0, 0.82, 0.5, 0.7 * a), 1.3, true)
	else:
		draw_colored_polygon(_heart_shape, Color(0.05, 0.04, 0.06, 0.38 * a))
		draw_polyline(edge, Color(Game.CREAM.r, Game.CREAM.g, Game.CREAM.b, 0.32 * a), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _on_stone(total: int) -> void:
	stone_grew = total % 3 == 0 and total <= 15
	stone_t = 9.0 if stone_grew else 6.0
	stone_full = stone_t
	if stone_grew:
		Game.sfx("gather", -6.0, 0.0)


var stone_grew := false      # this stone made the pouch one larger
var stone_full := 6.0


var hurt_flash := 0.0
var hearts_t := 3.0      # seconds the hearts stay up
var new_heart_t := 0.0   # seconds the newest heart goes on glowing, when one has just been earned
var beat := 0.0
var last_hp := -1


func _process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.2)
	hearts_t = maxf(0.0, hearts_t - delta)
	new_heart_t = maxf(0.0, new_heart_t - delta)
	beat += delta
	if Game.heart_news != "" and not Game.cinematic and is_instance_valid(Game.main) and is_instance_valid(Game.main.level) and Game.main.state == "play":
		Game.main.level.show_tip(Game.heart_news, 7.0)
		Game.heart_news = ""
		new_heart_t = 6.0
		hearts_t = 7.0
		Game.sfx("gather", -4.0, 0.0)
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
		var c := Vector2(40.0 + i * 31.0, 38.0)
		var full: bool = i < player.hp
		var size := 1.0
		if full and player.hp == 1:                      # the last one beats
			size += 0.1 * maxf(0.0, sin(beat * 7.0))
		var glow := 0.0
		if i == player.max_hp - 1 and new_heart_t > 0.0:      # one just earned
			glow = clampf(new_heart_t / 1.5, 0.0, 1.0) * (0.6 + 0.4 * sin(beat * 5.0))
			size += 0.12 * glow
		_heart(c, size, full, ha, glow)

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

	# the pouch: one small stone for each it can hold, bright while it is in there. Always in the same place,
	# so nothing jumps; a found stone is announced by one line under it that comes and goes softly
	var cream := Game.CREAM
	var cap := Game.pouch_max()
	for k in cap:
		var at := Vector2(1196.0 - k * 21.0, 31.0)
		var full: bool = k < Game.pouch()
		draw_texture_rect(STONE, Rect2(at.x - 9.0, at.y, 18.0, 18.0 * STONE.get_height() / STONE.get_width()), false, Color(1, 1, 1, 0.95) if full else Color(0.5, 0.5, 0.6, 0.3))
	if stone_t > 0.0:
		var sa := clampf(minf(stone_t, stone_full - stone_t) * 1.5, 0.0, 1.0)
		# what the stone is for, said every time: how far to the next place in the pouch, or what a pouch stone does
		var n := Game.stones().size()
		var why := Game.t("The pouch holds %d.  Hold the sling to its full wind: a smooth stone strikes harder and staggers any beast.") % Game.pouch_max() if stone_grew else (Game.t("%d more and the pouch holds another") % (3 - n % 3) if n < 15 else "")
		draw_rect(Rect2(866.0, 58.0, 400.0, 74.0 if stone_grew else 52.0), Color(0.04, 0.03, 0.06, 0.55 * sa))
		draw_multiline_string(Game.serif, Vector2(880.0, 100.0), why, HORIZONTAL_ALIGNMENT_RIGHT, 370.0, 15, 3, Color(cream.r, cream.g, cream.b, 0.9 * sa))
		draw_string(Game.serif, Vector2(880.0, 78.0), Game.t("Smooth stone  %d of %d") % [Game.stones().size(), Game.stones_total], HORIZONTAL_ALIGNMENT_RIGHT, 370.0, 17, Color(1.0, 0.88, 0.6, sa))

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

	# what he is to do now: always there, top left, in plain words. When a step is done it is ticked off for a
	# moment and the next one is written in
	if is_instance_valid(level) and str(level.goal) != "" and not Game.cinematic:
		var gf := Game.serif
		var gy := 150.0 if level.sheep_total > 0 else 92.0
		var gt: float = level.goal_t
		var now_txt: String = Game.keys(Game.t(level.goal))
		var fresh := clampf(1.0 - gt / 2.2, 0.0, 1.0)
		if str(level.goal_was) != "" and gt < 3.0:
			var da := clampf(minf(gt * 4.0, (3.0 - gt) * 1.5), 0.0, 1.0)
			var was_txt: String = Game.keys(Game.t(level.goal_was))
			draw_string(gf, Vector2(30.0, gy), "✓  " + was_txt, HORIZONTAL_ALIGNMENT_LEFT, 560.0, 16, Color(0.6, 0.95, 0.6, 0.85 * da))
			gy += 26.0
		var gw := minf(gf.get_string_size(now_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 54.0, 620.0)
		draw_rect(Rect2(22.0, gy - 22.0, gw, 32.0), Color(0.04, 0.03, 0.06, 0.5 + 0.25 * fresh))
		draw_rect(Rect2(22.0, gy - 22.0, 4.0, 32.0), Color(1.0, 0.82, 0.45, 0.9))
		draw_string(gf, Vector2(36.0, gy), now_txt, HORIZONTAL_ALIGNMENT_LEFT, 590.0, 19, Color(1.0, 0.95 - 0.1 * fresh, 0.85 - 0.3 * fresh, 0.96))

	# a sheep in danger that he cannot see: a mark at the edge of the screen, on the side it is on
	if is_instance_valid(level) and is_instance_valid(level.player):
		var centre: float = level.player.cam.get_screen_center_position().x
		var half: float = 640.0 / maxf(level.player.cam.zoom.x, 0.01)
		for sh in get_tree().get_nodes_in_group("sheep"):
			if not is_instance_valid(sh) or sh.threat <= 0.02:
				continue
			var off: float = sh.global_position.x - centre
			if absf(off) < half:
				continue
			var side := signf(off)
			var at := Vector2(640.0 + side * 596.0, 380.0)
			var hot := Color(1.0, 0.36, 0.22, 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.009)))
			draw_arc(at, 17.0, 0.0, TAU, 28, Color(0.05, 0.03, 0.03, 0.7), 7.0, true)
			draw_arc(at, 17.0, -PI * 0.5, -PI * 0.5 + TAU * minf(sh.threat, 1.0), 28, hot, 5.0, true)
			draw_colored_polygon(PackedVector2Array([at + Vector2(side * 30.0, 0), at + Vector2(side * 21.0, -8), at + Vector2(side * 21.0, 8)]), hot)

	# the journal, held open with Tab: what he is doing and why, what has been given him and what has not,
	# how his crafts stand, and what the stones and places he has found are worth
	if panel > 0.01:
		_journal(panel)

	var boss = level.boss
	if boss != null and is_instance_valid(boss):
		var w := 460.0
		var x := 640.0 - w * 0.5
		draw_string(Game.serif, Vector2(x, 632), Game.t(level.boss_name), HORIZONTAL_ALIGNMENT_CENTER, w, 22, Game.CREAM)
		draw_rect(Rect2(x - 2, 644, w + 4, 14), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(x, 646, w * float(boss.hp) / float(boss.max_hp), 10), Color(1.0, 0.72, 0.25))
		for f in [0.33, 0.66]:      # where the fight changes
			draw_rect(Rect2(x + w * f - 1.0, 644, 2.0, 14), Color(0.05, 0.04, 0.08, 0.9))


func _journal(a: float) -> void:
	var f := Game.serif
	var cream := Game.CREAM
	var gold := Color(1.0, 0.85, 0.5, a)
	var ink := Color(cream.r, cream.g, cream.b, a)
	var dim := Color(cream.r, cream.g, cream.b, 0.62 * a)
	draw_rect(Rect2(50, 46, 1180, 628), Color(0.03, 0.03, 0.07, 0.9 * a))
	draw_rect(Rect2(50, 46, 1180, 628), Color(1.0, 0.85, 0.5, 0.25 * a), false, 1.5)
	draw_string(f, Vector2(86, 94), Game.t("The shepherd's journal"), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, gold)
	draw_line(Vector2(86, 108), Vector2(1194, 108), Color(1.0, 0.85, 0.5, 0.3 * a), 1.0)

	# --- where he is, what he is doing there, and why
	var x := 86.0
	var sec: Dictionary = Game.sections()[clampi(Game.main.section_idx, 0, Game.sections().size() - 1)]
	draw_string(f, Vector2(x, 142), Game.t("What he is doing").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	draw_string(f, Vector2(x, 172), Game.t(sec["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
	draw_multiline_string(f, Vector2(x, 198), Game.t(str(sec.get("aim", ""))), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 18, 3, ink)
	draw_string(f, Vector2(x, 272), Game.t("Why").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	draw_multiline_string(f, Vector2(x, 296), Game.t(str(sec.get("why", ""))), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 17, 6, dim)

	# --- what he has found, and what it is worth to him
	draw_line(Vector2(x, 430), Vector2(x + 320, 430), Color(1.0, 0.85, 0.5, 0.2 * a), 1.0)
	draw_texture_rect(STONE, Rect2(x, 446, 22, 22.0 * STONE.get_height() / STONE.get_width()), false, Color(1, 1, 1, a))
	draw_string(f, Vector2(x + 32, 464), Game.t("Smooth stones  %d of %d") % [Game.stones().size(), Game.stones_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
	draw_string(f, Vector2(x + 32, 488), Game.t("In the pouch  %d of %d") % [Game.pouch(), Game.pouch_max()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
	draw_multiline_string(f, Vector2(x, 512), Game.t("For every three found, the pouch holds one more. A full-wound shot spends one: it strikes harder and staggers any beast. Watchfires refill it.") + "  " + Game.t("All of them found: they strike harder still." if Game.all_stones() else "Find them all, and they strike harder still."), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 13, 6, dim)
	draw_string(f, Vector2(x, 618), Game.t("Places found  %d of %d") % [Game.places().size(), Game.places_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
	draw_multiline_string(f, Vector2(x, 637), Game.t("Each place found makes him whole and strengthens a craft.") + "  " + Game.t("All of them found: one more heart." if Game.all_places() else "Find them all for one more heart."), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 13, 3, dim)

	# --- the six gifts: given, or still to earn and where
	x = 452.0
	draw_string(f, Vector2(x, 142), Game.t("Gifts").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	for i in Game.GIFT_ORDER.size():
		var g: Dictionary = Game.GIFTS[Game.GIFT_ORDER[i]]
		var y := 174.0 + i * 82.0
		var his: bool = Game.has(Game.GIFT_ORDER[i])
		draw_circle(Vector2(x + 8, y - 7), 7.0, Color(1.0, 0.82, 0.45, a) if his else Color(1, 1, 1, 0.14 * a))
		if not his:
			draw_arc(Vector2(x + 8, y - 7), 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.4 * a), 1.2, true)
		draw_string(f, Vector2(x + 26, y), Game.t(g["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink if his else dim)
		if his:
			draw_multiline_string(f, Vector2(x + 26, y + 20), Game.t(g["line"]) + "  " + Game.t(g["why"]), HORIZONTAL_ALIGNMENT_LEFT, 360.0, 14, 3, dim)
		else:
			draw_string(f, Vector2(x + 26, y + 20), Game.t("Still to earn").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5, 0.75 * a))
			draw_multiline_string(f, Vector2(x + 26, y + 38), Game.t(g["how"]), HORIZONTAL_ALIGNMENT_LEFT, 360.0, 15, 2, ink)

	# --- the five crafts: slow strengthening of what he has
	x = 866.0
	draw_string(f, Vector2(x, 142), Game.t("Crafts").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)
	for i in Game.CRAFT_ORDER.size():
		var id: String = Game.CRAFT_ORDER[i]
		var c: Dictionary = Game.CRAFTS[id]
		var r: int = Game.rank(id)
		var y := 174.0 + i * 96.0
		var his: bool = Game.has(c["gift"])
		draw_string(f, Vector2(x, y), Game.t(c["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink if his else dim)
		for k in 3:
			draw_circle(Vector2(x + 270.0 + k * 18.0, y - 7.0), 5.5, Color(1.0, 0.8, 0.4, a) if k < r else Color(1, 1, 1, 0.16 * a))
		var marks: Array = c["marks"]
		var lo: float = 0.0 if r == 0 else float(marks[r - 1])
		var hi: float = float(marks[mini(r, 2)])
		var fill := 1.0 if r >= 3 else clampf((Game.craft_xp(id) - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
		draw_rect(Rect2(x, y + 10.0, 320.0, 6.0), Color(1, 1, 1, 0.12 * a))
		draw_rect(Rect2(x, y + 10.0, 320.0 * fill, 6.0), Color(1.0, 0.8, 0.4, 0.9 * a))
		var line: String = (Game.t("Grows by %s.") % Game.t(c["by"])) if r == 0 else Game.t(c["gifts"][r - 1])
		if not his:
			line = Game.t("Not yet given.")
		draw_multiline_string(f, Vector2(x, y + 36.0), line, HORIZONTAL_ALIGNMENT_LEFT, 320.0, 14, 2, dim)
