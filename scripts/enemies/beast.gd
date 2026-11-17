extends "res://scripts/enemies/enemy.gd"
## What the wolf, the leopard, the viper and the hyena have in common: where their pictures come from, which
## sheep are fair game for them, and how they let go of what they hold when they are driven off.

# The tint the jackal's pictures wear when they stand in for a beast in the automated tests. It is never seen by
# a player: a level only makes a beast whose own pictures are painted (see add_beast in level_base.gd).
const STAND_IN := {"wolf": Color(0.6, 0.7, 1.0), "leopard": Color(1.0, 0.8, 0.4), "viper": Color(0.6, 1.0, 0.6),
		"hyena": Color(0.9, 0.6, 0.9)}

var stand_in := false      # tests only: the jackal's pictures, tinted, until the real ones are painted
var first_set := "walk"    # the set every one of this animal's actions can fall back on if its own is missing


func _ready() -> void:
	super._ready()
	if stand_in:
		tint = STAND_IN.get(anim, Color(1, 1, 1))


## The pictures of an action: its own set, or the animal's first set, or (tests only) the jackal's.
func frames_of(set_name: String) -> Array:
	var arr: Array = FA.frames(anim, set_name)
	if arr.is_empty():
		arr = FA.frames(anim, first_set)
	if arr.is_empty() and stand_in:
		arr = FA.frames("jackal", set_name)
		if arr.is_empty():
			arr = FA.frames("jackal", "walk")
	return arr


## A picture by how far through the action we are (0..1).
func by_u(set_name: String, u: float) -> Texture2D:
	var arr := frames_of(set_name)
	if arr.is_empty():
		return null
	return arr[clampi(int(clampf(u, 0.0, 1.0) * (arr.size() - 1) + 0.5), 0, arr.size() - 1)]


## A looping picture, kept in step with the ground covered (a gait).
func by_dist(set_name: String, per: float = 0.0) -> Texture2D:
	var arr := frames_of(set_name)
	if arr.is_empty():
		return null
	return arr[int(dist / (per if per > 0.0 else stride) * arr.size()) % arr.size()]


## A picture played forward and back by the clock, for a creature that is nearly still.
func by_clock(set_name: String, fps: float) -> Texture2D:
	var arr := frames_of(set_name)
	if arr.is_empty():
		return null
	return FA.pingpong(arr, t, fps)


func put(tex: Texture2D, sc: float, tall: float = 1.4, stretch: Vector2 = Vector2.ONE) -> void:
	if tex != null:
		show_frame(tex, sc, tall, stretch)


## Is this sheep fair game? The same rule the jackal keeps: not another man's (unless the story has left that
## man's sheep out for it: `prey` on a marked one, as on the road home), and not one the story has put away.
func is_prey(s) -> bool:
	return is_instance_valid(s) and (s.gathered or s.gatherable or s.prey) and s.leap < 0.0 and (s.mark.a <= 0.0 or s.prey) \
			and not s.safe and not s.carried


## Another of its own kind has this sheep already.
func claimed(s) -> bool:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n != self and n.get("anim") == anim and (n.get("prey") == s or n.get("carry") == s):
			return true
	return false


## It is not to wander out of the ground the level has: the land ends, and so does it.
func keep_in_level() -> void:
	global_position.x = clampf(global_position.x, 30.0, level.width - 30.0)
	if global_position.y > 1400.0:      # over the edge of a pit: gone
		_let_go(true)
		queue_free()


## Lets go of whatever it holds. `restore` puts it back where it was taken from.
func _let_go(_restore: bool = false) -> void:
	pass


func drive_off() -> void:
	_let_go(false)
	super.drive_off()
	Game.sfx("jackal_yelp", -4.0)
