extends Node2D
## A node whose drawing is supplied by a function: paint.call(self).

var paint: Callable
var animated := false


func _draw() -> void:
	if paint.is_valid():
		paint.call(self)


func _process(_delta: float) -> void:
	if animated:
		queue_redraw()
