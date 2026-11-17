extends Control
## Story overlay: narration with letterbox bars, title cards, screen fades.
## If audio/narration/<line id>.mp3 exists it is played with the line.

var busy := false

var bar_top: ColorRect
var bar_bot: ColorRect
var text: Label
var ref: Label
var who: Label
var box: PanelContainer
var card_top: Label
var card_title: Label
var card_sub: Label
var fade: ColorRect
var voice: AudioStreamPlayer
var _pressed := false

const FA = preload("res://scripts/systems/frame_anim.gd")
var dim: ColorRect
var shot: TextureRect
var shot_frames: Array = []
var shot_t := 0.0
var shot_fps := 8.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	bar_top = _rect(Rect2(0, -60, 1280, 60), Color(0.02, 0.02, 0.04))
	bar_bot = _rect(Rect2(0, 720, 1280, 190), Color(0.02, 0.02, 0.04))
	bar_top.visible = false      # no longer used, and on a screen taller than 16:9 they would show as black bands
	bar_bot.visible = false

	# Subtitles the way games show them: a small block low on the screen with a soft backing fitted to the words,
	# so they inform without covering the picture. The verse reference sits apart, in the bottom right corner.
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.04, 0.5)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 8.0
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	box.add_child(col)
	who = Game.label("", 14, Color(1.0, 0.82, 0.55))      # who is speaking, when it is not the narrator
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.visible = false
	col.add_child(who)
	text = Game.label("", 20, Color(1.0, 0.97, 0.9))
	text.add_theme_constant_override("outline_size", 3)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)

	ref = Game.label("", 15, Color(1.0, 0.82, 0.55, 0.9))
	ref.add_theme_constant_override("outline_size", 3)
	ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ref.position = Vector2(760, 688)
	ref.size = Vector2(496, 22)
	ref.modulate.a = 0.0
	add_child(ref)

	card_top = _card(22, 250, Color(1.0, 0.82, 0.55))
	card_title = _card(64, 284, Game.CREAM)
	card_sub = _card(22, 372, Color(1.0, 0.95, 0.85, 0.8))

	fade = _rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.02, 0.04, 0.0))
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)      # the whole screen, whatever its shape

	voice = AudioStreamPlayer.new()
	add_child(voice)

	# close-up shots sit under the letterbox bars and the text
	dim = _rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.01, 0.05, 0.0))
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shot = TextureRect.new()
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shot.modulate.a = 0.0
	var soft := ShaderMaterial.new()
	soft.shader = preload("res://shaders/softcut.gdshader")
	shot.material = soft
	add_child(shot)
	move_child(dim, 0)
	move_child(shot, 1)


func _rect(r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)
	return cr


func _card(size_px: int, y: float, c: Color) -> Label:
	var l := Game.label("", size_px, c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1280, size_px + 20)
	l.modulate.a = 0.0
	add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if busy and (event.is_action_pressed("accept") or event.is_action_pressed("attack")):
		_pressed = true
		get_viewport().set_input_as_handled()


func fade_to(alpha: float, seconds: float = 0.5) -> void:
	if Game.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, seconds)
	await tw.finished


func _bars(_on: bool) -> void:
	pass      # the picture stays whole: subtitles no longer bring black bars with them


## Plays narration lines in order. Holds the game still while it speaks.
func say(ids: Array) -> void:
	while busy:
		await get_tree().process_frame
	busy = true
	Game.cinematic = true
	Game.duck(true)
	await _bars(true)
	for id in ids:
		await _line(str(id))
	Game.duck(false)
	await _bars(false)
	Game.cinematic = false
	busy = false


func _line(id: String) -> void:
	var data: Dictionary = Game.line(id)
	var speaker: String = data.get("who", "")
	# a character's words are set in quotation marks under his name; the narrator's stand alone
	text.text = ("“%s”" % data.get("text", "")) if speaker != "" else data.get("text", "")
	ref.text = data.get("ref", "")
	who.text = speaker.to_upper()
	who.visible = speaker != ""
	if Game.fast:
		return
	# fit the block to the words: one line if it is short, else wrapped at a comfortable width
	var one: float = Game.serif.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8.0
	text.custom_minimum_size = Vector2(minf(one, 720.0), 0.0)
	box.size = Vector2.ZERO
	await get_tree().process_frame
	box.reset_size()
	box.position = Vector2(640.0 - box.size.x * 0.5, 676.0 - box.size.y)
	ref.modulate.a = 0.0

	var hold := maxf(3.0, text.text.length() * 0.065)
	var path := "res://audio/narration/%s.mp3" % id
	if Game.lang() != "en" and ResourceLoader.exists("res://audio/narration/%s/%s.mp3" % [Game.lang(), id]):
		path = "res://audio/narration/%s/%s.mp3" % [Game.lang(), id]      # the voice in that language, once it is recorded
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		voice.stream = stream
		voice.play()
		hold = stream.get_length() + 0.6
	var tin := create_tween().set_parallel(true)
	tin.tween_property(box, "modulate:a", 1.0, 0.25)
	if ref.text != "":
		tin.tween_property(ref, "modulate:a", 1.0, 0.6)
	var t := 0.0
	_pressed = false
	while t < hold:
		await get_tree().process_frame
		t += get_process_delta_time()
		if _pressed:
			_pressed = false
			if t > 0.35:
				break           # a press moves on to the next line
	voice.stop()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(box, "modulate:a", 0.0, 0.25)
	tw.tween_property(ref, "modulate:a", 0.0, 0.25)
	await tw.finished


## Chapter and section title, shown briefly over the game.
func title_card(top: String, title: String, sub: String = "") -> void:
	if Game.fast:
		return
	card_top.text = top
	card_title.text = title
	card_sub.text = sub
	var tw := create_tween()
	for l in [card_top, card_title, card_sub]:
		tw.parallel().tween_property(l, "modulate:a", 1.0, 0.9)
	tw.tween_interval(1.8 if sub == "" else 3.4)      # long enough to read what he is here to do
	for l in [card_top, card_title, card_sub]:
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	await tw.finished


## Full-screen card at the end of the chapter. Waits for a key press.
func end_card(top: String, title: String, sub: String) -> void:
	if Game.fast:
		return
	busy = true
	await fade_to(1.0, 1.2)
	card_top.text = top
	card_title.text = title
	card_sub.text = sub
	var tw := create_tween().set_parallel(true)
	for l in [card_top, card_title, card_sub]:
		tw.tween_property(l, "modulate:a", 1.0, 1.0)
	await tw.finished
	_pressed = false
	var t := 0.0
	while not _pressed and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	tw = create_tween().set_parallel(true)
	for l in [card_top, card_title, card_sub]:
		tw.tween_property(l, "modulate:a", 0.0, 0.6)
	await tw.finished
	busy = false


## Cuts to a close-up: a frame set played once over the dimmed scene, its
## lower edge hidden behind the bottom bar.
## A close shot of a figure over the dimmed scene. `tall` is how much of the screen height the image fills;
## it runs down behind the narration bar and fades out at its edges.
func closeup(who: String, set_name: String, fps: float = 8.0, tall: float = 0.92, x: float = 560.0) -> void:
	shot_frames = [] if Game.fast else FA.frames(who, set_name)
	if shot_frames.is_empty():
		return
	shot_t = 0.0
	shot_fps = fps
	var first: Texture2D = shot_frames[0]
	shot.texture = first
	var k := 720.0 * tall / first.get_height()
	var size := Vector2(first.get_width(), first.get_height())
	var at := Vector2(x, 740.0 - size.y * k)
	shot.pivot_offset = Vector2.ZERO
	shot.scale = Vector2(k, k)
	shot.position = at
	var tw := create_tween().set_parallel(true)
	tw.tween_property(shot, "modulate:a", 1.0, 0.8)
	tw.tween_property(dim, "color:a", 0.62, 0.8)
	# a slow push in, like a camera, holding the middle of the figure in place
	var grow := 1.06
	tw.tween_property(shot, "scale", Vector2(k, k) * grow, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(shot, "position", at - size * k * (grow - 1.0) * Vector2(0.5, 0.4), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func closeup_end() -> void:
	if shot_frames.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(shot, "modulate:a", 0.0, 0.8)
	tw.tween_property(dim, "color:a", 0.0, 0.8)
	await tw.finished
	shot_frames = []


func _process(delta: float) -> void:
	if shot_frames.is_empty():
		return
	shot_t += delta
	shot.texture = shot_frames[mini(int(shot_t * shot_fps), shot_frames.size() - 1)]
