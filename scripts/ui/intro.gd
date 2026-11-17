extends Control
## The prologue film: how Israel asked for a king, and how Saul lost the kingdom.
## Plays video/intro.ogv with subtitles and verse references from data/intro.json.

signal finished

const FILM := "res://video/intro.ogv"
const CUES := "res://data/intro.json"

var player: VideoStreamPlayer
var sub: Label
var spoken_local := false     # the film playing has its narration in the player's language
var ref: Label
var title: Label
var under: Label
var hint: Label
var shade: ColorRect
var cues: Array = []
var title_at := 1e9
var length := 0.0
var t := 0.0
var running := false
var hint_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.position = Vector2.ZERO
	player.size = Vector2(1280, 720)
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.volume_db = 3.0       # the film is mixed with headroom; this brings it up to the level of the game
	add_child(player)
	sub = _label(25, Rect2(140, 596, 1000, 76), Game.CREAM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ref = _label(16, Rect2(760, 684, 496, 24), Color(1.0, 0.82, 0.55, 0.85))      # only the book, chapter and verse, low in the corner
	ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title = _label(150, Rect2(0, 215, 1280, 170), Game.CREAM)
	under = _label(26, Rect2(0, 392, 1280, 36), Color(1.0, 0.82, 0.55))
	hint = _label(17, Rect2(0, 20, 1256, 24), Color(1, 1, 1, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = Game.keys("Enter: skip")
	title.text = "DAVID"
	under.text = "The Shepherd King"


func _label(px: int, r: Rect2, c: Color) -> Label:
	var l := Game.label("", px, c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = r.position
	l.size = r.size
	l.modulate.a = 0.0
	add_child(l)
	return l


func available() -> bool:
	return ResourceLoader.exists(FILM)


## A story film that plays before a section: video/story_<id>.ogv, with its subtitles in data/story_<id>.json.
func has_story(id: String) -> bool:
	return id != "" and ResourceLoader.exists("res://video/story_%s.ogv" % id)


func play_story(id: String) -> void:
	if has_story(id):
		await play("res://video/story_%s.ogv" % id, "res://data/story_%s.json" % id)


## Plays a film and returns when it ends or is skipped. With no arguments it plays the prologue.
func play(film: String = FILM, cue_file: String = CUES) -> void:
	if not ResourceLoader.exists(film) or Game.fast:
		return
	cues = []
	title_at = 1e9
	length = 0.0
	# the film with its narration spoken in the player's language, if one has been made
	spoken_local = false
	var local_film := film.replace(".ogv", ".%s.ogv" % Game.lang())
	if Game.lang() != "en" and ResourceLoader.exists(local_film):
		film = local_film
		spoken_local = true
	var local := cue_file.replace(".json", ".%s.json" % Game.lang())      # the subtitles in the player's language, if they exist
	if Game.lang() != "en" and FileAccess.file_exists(local):
		cue_file = local
	hint.text = Game.keys(Game.t("Enter: skip"))
	under.text = Game.t("The Shepherd King")
	if FileAccess.file_exists(cue_file):
		var d = JSON.parse_string(FileAccess.get_file_as_string(cue_file))
		if d is Dictionary:
			cues = d.get("cues", [])
			title_at = float(d.get("title_at", 1e9))
			length = float(d.get("length", 0.0))
	Game.music("", 1.0)
	Game.ambience("")
	for l in [sub, ref, title, under, hint]:
		l.modulate.a = 0.0
	t = 0.0
	hint_t = 0.0
	visible = true
	modulate.a = 1.0
	player.stream = load(film)
	player.play()
	running = true
	await finished


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	hint_t = maxf(0.0, hint_t - delta)
	hint.modulate.a = move_toward(hint.modulate.a, 1.0 if hint_t > 0.0 else 0.0, delta * 3.0)
	var line := ""
	var where := ""
	for c in cues:
		if t >= float(c["t"]) and t < float(c["t"]) + float(c["d"]):
			line = c["text"]
			where = c.get("ref", "")
	if line != "" and sub.text != line:
		sub.text = line
		ref.text = where
	var want := 1.0 if line != "" else 0.0
	# the narrator is heard, so his words are not printed over the picture unless subtitles are asked for
	# the words are printed when asked for, and when the voice is in another language than the reader's
	var show_sub: bool = Game.save.get("film_subs", false) or (Game.lang() != "en" and not spoken_local)
	sub.modulate.a = move_toward(sub.modulate.a, want if show_sub else 0.0, delta * 3.0)
	ref.modulate.a = move_toward(ref.modulate.a, want if where != "" else 0.0, delta * 3.0)
	var show_title := 1.0 if t >= title_at else 0.0
	title.modulate.a = move_toward(title.modulate.a, show_title, delta * 0.5)
	under.modulate.a = move_toward(under.modulate.a, 1.0 if t >= title_at + 1.6 else 0.0, delta * 0.6)
	if (length > 0.0 and t >= length) or (t > 2.0 and not player.is_playing()):
		_end()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed("accept") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if hint_t > 0.0 or event.is_action_pressed("pause"):
			_end()
		else:
			hint_t = 3.0        # first press shows how to skip, second press skips
	elif event is InputEventKey and event.pressed:
		hint_t = 3.0


func _end() -> void:
	if not running:
		return
	running = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	player.stop()
	player.stream = null
	visible = false
	finished.emit()
