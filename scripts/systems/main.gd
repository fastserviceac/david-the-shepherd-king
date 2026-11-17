extends Node
## The running game: owns the current level, the UI, and the flow between
## the menu, the sections and the end of the chapter.

const Overlay = preload("res://scripts/ui/overlay.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Menu = preload("res://scripts/ui/menu.gd")
const Intro = preload("res://scripts/ui/intro.gd")
const Vignette = preload("res://shaders/vignette.gdshader")

var world: Node2D
var level = null
var overlay
var hud
var menu
var intro
var section_idx := 0
var state := "boot"      # menu, play, paused, transition
var testing := false
var tester
var map
var map_from := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)

	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = Vignette
	vig.material = vm
	ui.add_child(vig)

	hud = Hud.new()
	ui.add_child(hud)
	menu = Menu.new()
	ui.add_child(menu)
	overlay = Overlay.new()
	ui.add_child(overlay)
	intro = Intro.new()
	ui.add_child(intro)
	menu.chosen.connect(_on_menu)
	map = preload("res://scripts/ui/map.gd").new()
	ui.add_child(map)
	ui.move_child(map, menu.get_index() + 1)
	map.closed.connect(_map_closed)

	var touch_layer := CanvasLayer.new()      # the on-screen controls sit above everything else
	touch_layer.layer = 40
	add_child(touch_layer)
	touch_layer.add_child(preload("res://scripts/ui/touch.gd").new())
	map.travel.connect(func(idx: int) -> void:
		map.close()
		Game.gifts_for(idx)
		start_section(idx))

	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			testing = true
			Game.fast = true
			tester = preload("res://scripts/systems/selftest.gd").new()
			tester.smoke(self)
			return
		if a.begins_with("--flow"):
			testing = false
			tester = preload("res://scripts/systems/selftest.gd").new()
			tester.flow(self, a.trim_prefix("--flow").trim_prefix("="))
			return
		if a.begins_with("--stuck="):
			Game.fast = true
			var t4 = load("res://scripts/systems/selftest.gd").new()
			set_meta("tester", t4)
			t4.stuck(self, a.trim_prefix("--stuck="))
			return
		if a.begins_with("--placeshots="):
			Game.fast = true
			var t3 = load("res://scripts/systems/selftest.gd").new()
			set_meta("tester", t3)
			t3.placeshots(self, a.trim_prefix("--placeshots="))
			return
		if a.begins_with("--newshots="):
			Game.fast = true
			var t2 = load("res://scripts/systems/selftest.gd").new()
			set_meta("tester", t2)
			t2.newshots(self, a.trim_prefix("--newshots="))
			return
		if a.begins_with("--shots="):
			testing = true
			Game.fast = true
			tester = preload("res://scripts/systems/selftest.gd").new()
			get_window().size = Vector2i(2560, 1440)      # the size the game is really seen at
			tester.shots(self, a.trim_prefix("--shots="))
			return
		if a.begins_with("--introtest="):      # plays the prologue and saves a few frames of it, for checking
			get_window().size = Vector2i(2560, 1440)
			_intro_test(a.trim_prefix("--introtest="))
			return
	get_window().mode = Window.MODE_FULLSCREEN
	show_menu()


func load_level(idx: int, checkpoint: int = 0) -> void:
	if level != null and is_instance_valid(level):
		level.queue_free()
		level = null
		await get_tree().process_frame
	Game.FA.keep_only(["david", "sheep", "jackal"])      # the last place's beasts and people are let go
	section_idx = idx
	var sec: Dictionary = Game.sections()[idx]
	level = load(sec["script"]).new()
	level.section_idx = idx
	level.start_checkpoint = checkpoint
	world.add_child(level)
	Game.music(level.mood)
	Game.ambience(level.ambience)


func show_menu() -> void:
	state = "transition"
	await overlay.fade_to(1.0, 0.4)
	get_tree().paused = false
	Game.cinematic = false
	Game.backdrop = true
	hud.visible = false
	await load_level(0, 0)
	level.player.position = level.on_ground(760.0)
	level.player.cam.reset_smoothing()
	menu.open("main")
	state = "menu"
	await overlay.fade_to(0.0, 0.8)


func start_section(idx: int, checkpoint: int = 0, seen_film: bool = false) -> void:
	state = "transition"
	menu.close()
	await overlay.fade_to(1.0, 0.5)
	get_tree().paused = false
	Game.backdrop = false
	Game.cinematic = false
	await load_level(idx, checkpoint)
	Game.save["section"] = idx
	Game.save["checkpoint"] = checkpoint
	Game.save["started"] = true
	Game.save_game()
	# a story film leads into the section, when one has been made for it
	var film: String = Game.sections()[idx].get("film", "")
	if checkpoint == 0 and not seen_film and intro.has_story(film) and not Game.fast and tester == null:
		Game.cinematic = true
		hud.visible = false
		intro.play_story(film)
		await overlay.fade_to(0.0, 0.05)
		await intro.finished
		await overlay.fade_to(1.0, 0.05)
		Game.cinematic = false
		Game.music(level.mood)
		Game.ambience(level.ambience)
	hud.visible = true
	state = "play"
	await overlay.fade_to(0.0, 0.7)
	if checkpoint == 0:
		var ch: Dictionary = Game.chapters[0]
		Game.cinematic = true
		await overlay.title_card(Game.t("Chapter %s  ·  %s") % [Game.t(ch["number"]), Game.t(ch["title"])], Game.t(Game.sections()[idx]["title"]), Game.t(str(Game.sections()[idx].get("aim", ""))))
		Game.cinematic = false
		if is_instance_valid(level) and section_idx == idx:
			level.begin()


func complete_section() -> void:
	if testing or state != "play":
		return
	state = "transition"
	var next := section_idx + 1
	if next < Game.sections().size():
		var hearts_before := Game.earned_hearts()
		Game.save["unlocked"] = maxi(int(Game.save.get("unlocked", 0)), next)
		if Game.earned_hearts() > hearts_before:
			Game.heart_news = str(Game.HEART_DEEDS.get(str(Game.sections()[section_idx]["script"]).get_file().get_basename(), ""))
		start_section(next)
	else:
		Game.save["finished"] = true
		Game.save["started"] = false
		Game.save["section"] = 0
		Game.save["checkpoint"] = 0
		Game.save_game()
		# the film that closes the chapter and opens the next: the prophet gone, the boy back with the sheep,
		# and a king who does not yet know
		if intro.has_story("end") and not Game.fast and tester == null:
			Game.cinematic = true
			hud.visible = false
			await overlay.fade_to(1.0, 0.6)
			intro.play_story("end")
			await intro.finished
			Game.cinematic = false
		var here: Dictionary = Game.chapters[0]
		var coming: Dictionary = Game.chapters[1]
		await overlay.end_card(Game.t("End of Chapter %s") % Game.t(here["number"]), Game.t(here["title"]),
			Game.t("Chapter %s: %s  ·  coming next") % [Game.t(coming["number"]), Game.t(coming["title"])])
		show_menu()


func _on_menu(id: String) -> void:
	match id:
		"continue":
			start_section(int(Game.save["section"]), 0, true)      # he has seen the film that leads in; it is not shown again      # a place is rebuilt whole when the game is reopened, so he begins it whole: its sheep, stones and tasks are not kept half done
		"new":
			menu.open("difficulty")
		"sections":
			menu.open("sections")
		"map":
			map_from = menu.mode
			menu.close()
			map.open(map_from == "pause", section_idx if map_from == "pause" else int(Game.save.get("section", 0)))
		"lang":
			Game.save["lang"] = "pt" if Game.lang() == "en" else "en"
			Game.save_game()
			menu.open(menu.mode, menu.index)
		"settings":
			menu.back_to = menu.mode
			menu.open("settings")
		"set_diff":
			Game.save["difficulty"] = (int(Game.save.get("difficulty", 1)) + 1) % Game.DIFFICULTY.size()
			Game.save_game()
			menu.open("settings", menu.index)
		"set_vol":
			var v := Game.volume() - 0.25
			Game.save["volume"] = 1.0 if v < -0.01 else v
			Game.apply_settings()
			Game.save_game()
			menu.open("settings", menu.index)
		"set_subs":
			Game.save["film_subs"] = not Game.save.get("film_subs", false)
			Game.save_game()
			menu.open("settings", menu.index)
		"set_haptic":
			Game.save["haptics"] = not Game.save.get("haptics", true)
			Game.save_game()
			Game.buzz(30)
			menu.open("settings", menu.index)
		"back":
			menu.open(menu.back_to if menu.mode == "settings" else "main")
		"prologue":
			await _prologue()
			show_menu()
		"quit":
			get_tree().quit()
		"resume":
			_resume()
		"restart":
			_resume()
			level.respawn()
		"menu":
			show_menu()
			menu.close()
		_:
			if id.begins_with("diff_"):
				Game.save["difficulty"] = id.trim_prefix("diff_").to_int()
				Game.new_game()
				await _prologue()
				start_section(0)
			elif id.begins_with("section_"):
				Game.gifts_for(id.trim_prefix("section_").to_int())
				start_section(id.trim_prefix("section_").to_int())


func _intro_test(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	intro.play()
	for at in [6.0, 16.0, 73.5, 112.0]:
		while intro.t < at and intro.running:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/intro_%03d.png" % [dir, int(at)])
	get_tree().quit()


## The opening film. The menu steps aside while it plays.
func _prologue() -> void:
	if not intro.available() or Game.fast or tester != null:      # the automated play-through checks the game, not the film
		return
	menu.close()
	state = "transition"
	await intro.play()


func _map_closed() -> void:
	map.close()
	if map_from == "play":
		_resume()
	else:
		menu.open(map_from)


func _resume() -> void:
	menu.close()
	get_tree().paused = false
	state = "play"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F11 or event.keycode == KEY_F):
		var w := get_window()       # F or F11 switches between full screen and a window
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		return
	if event.is_action_pressed("map") and state == "play" and not overlay.busy and not Game.cinematic:
		get_viewport().set_input_as_handled()
		state = "paused"
		get_tree().paused = true
		map_from = "play"
		map.open(true, section_idx)
		return
	if event.is_action_pressed("pause") and state == "play" and not overlay.busy and not Game.cinematic:
		get_viewport().set_input_as_handled()
		state = "paused"
		get_tree().paused = true
		menu.open("pause")
