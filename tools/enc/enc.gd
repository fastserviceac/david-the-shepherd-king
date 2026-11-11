extends Node
## usage: godot --path <this folder> --write-movie out.ogv --fixed-fps 24 -- <frames_dir> <audio.wav>
var frames: PackedStringArray = []
var i := 0
var rect: TextureRect
var tex: ImageTexture


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0]
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".jpg"):
			frames.append(dir + "/" + f)
	frames.sort()
	rect = TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(rect)
	var a := AudioStreamPlayer.new()
	a.stream = AudioStreamWAV.load_from_file(args[1])
	add_child(a)
	a.play()


func _process(_delta: float) -> void:
	if i >= frames.size():
		get_tree().quit()
		return
	var img := Image.load_from_file(frames[i])
	if tex == null:
		tex = ImageTexture.create_from_image(img)
		rect.texture = tex
	else:
		tex.update(img)
	i += 1
