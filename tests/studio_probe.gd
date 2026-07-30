extends Node
## 英雄基地 with a FINGER, not a mouse.
##
##   godot --headless --path . res://tests/StudioProbe.tscn
##
## The hero base is the one screen whose whole content is a drag: pick a
## sticker off the shelf, move it, let go. Every other check in this repo taps.
## The touch probe taps too -- and it taps by pushing a MOUSE event, which the
## desktop then emulates into a touch. So the one gesture that matters here,
## delivered the way an iPad delivers it, had never once been tested.
##
## It was broken. Two ways, both invisible on a Mac:
##
##   1. the tablet's screen is a different SHAPE. `stretch/aspect` is "expand",
##      so a 4:3 iPad gets a 1280x960 viewport rather than 1280x720, and this
##      screen had 720 written into it in three places -- including the rule
##      that says "dropped below y=600 means put it back on the shelf", which
##      on a taller screen covers a third of the room a child is drawing in.
##      Every sticker let go of in the lower part of the base vanished.
##
##   2. dragging with a real finger never moved anything, because the drag
##      event is delivered to the Control under it and stops there.
##
## So this probe uses InputEventScreenTouch and InputEventScreenDrag, at both
## screen shapes, and asks the only question the room has: did the thing the
## finger dragged end up where the finger left it?

const TRAY_FIRST := Vector2(88.0, 664.0)


func _ready() -> void:
	print("=== studio probe ===")
	var out: Array[String] = []
	out.append_array(_two_rooms_two_shelves())
	# A Mac (16:9) and an iPad (4:3). "expand" gives the second one a taller
	# viewport, which is the whole reason this runs twice.
	out.append_array(await _drag_on_a("Mac", Vector2i(1280, 720)))
	out.append_array(await _drag_on_a("iPad", Vector2i(1024, 768)))

	for f in out:
		print("  FAIL: ", f)
	print("STUDIO PROBE %s" % ("PASSED" if out.is_empty() else "FAILED"))
	get_tree().quit(0 if out.is_empty() else 1)


## Two creative rooms must write to two different shelves.
##
## The canvas key was the literal "base" for as long as exactly one room used
## the template. The moment 菜园二期 adds a second one, a shared key means
## decorating the garden SAVES OVER the hero base -- a child loses an
## afternoon of stickers by playing a different room. The key now comes from
## the level (config canvas_id, else the level id), and this holds it there.
func _two_rooms_two_shelves() -> Array[String]:
	var out: Array[String] = []
	var cp: Node = load("res://scripts/minigames/creative_play.gd").new()
	cp.level_data = {"id": "hero_studio", "config": {"canvas_id": "base"}}
	if str(cp.call("_canvas_id")) != "base":
		out.append("hero_studio must keep the shelf named 'base' -- renaming "
			+ "it orphans every sticker already saved there")
	cp.level_data = {"id": "garden_room", "config": {}}
	if str(cp.call("_canvas_id")) != "garden_room":
		out.append("a room with no canvas_id should shelve under its level id, "
			+ "got '%s'" % cp.call("_canvas_id"))
	cp.free()

	SaveManager.set_creation("base", [{"icon": "star", "x": 1.0, "y": 2.0}])
	SaveManager.set_creation("garden_room", [{"icon": "sprout", "x": 3.0, "y": 4.0}])
	var kept: Array = SaveManager.get_creation("base")
	if kept.size() != 1 or str(kept[0].get("icon", "")) != "star":
		out.append("saving the second room's work overwrote the first room's "
			+ "shelf -- the exact data loss the per-room key exists to prevent")
	SaveManager.set_creation("garden_room", [])
	print("  two rooms, two shelves: %s" % ("ok" if out.is_empty() else "BROKEN"))
	return out


func _drag_on_a(label: String, window_px: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var w := get_window()
	if w != null:
		w.size = window_px
	await get_tree().process_frame
	await get_tree().process_frame

	var view: Vector2 = get_viewport().get_visible_rect().size
	print("-- %s: window %s, viewport %.0fx%.0f" % [label, window_px, view.x, view.y])

	SaveManager.set_creation("base", [])
	GameManager.current_level_id = "hero_studio"
	var game: Node = load("res://scenes/minigames/creative_play/CreativePlay.tscn")\
		.instantiate()
	add_child(game)
	for i in range(6):
		await get_tree().process_frame

	# Where the shelf actually is on THIS screen, asked of the game rather than
	# assumed -- the point of the second run is that it moves.
	var shelf_y := 618.0
	if game.has_method("shelf_y"):
		shelf_y = float(game.call("shelf_y"))
	var from := Vector2(TRAY_FIRST.x, shelf_y + 46.0)
	# Let go in the middle of the room, well clear of the shelf.
	var to := Vector2(640.0, shelf_y * 0.45)

	var before: int = (game.get("_placed") as Array).size()
	await _finger(from, to)
	var placed: Array = game.get("_placed") as Array
	print("   dragged from %s to %s -- stickers %d -> %d"
		% [from, to, before, placed.size()])

	if placed.size() != before + 1:
		out.append("%s: a finger dragged a sticker out of the shelf and "
			% label + "nothing was placed")
	else:
		var at: Vector2 = placed[placed.size() - 1]["at"]
		print("   it came to rest at %s" % at)
		if at.distance_to(to) > 2.0:
			out.append("%s: the sticker was let go at %s but sits at %s"
				% [label, to, at])

	# The shelf has to be ON the screen this child is holding.
	if shelf_y + 92.0 > view.y + 1.0:
		out.append("%s: the shelf runs %.0f px off the bottom"
			% [label, shelf_y + 92.0 - view.y])
	elif view.y - (shelf_y + 92.0) > 60.0:
		out.append("%s: the shelf floats %.0f px above the bottom of the screen"
			% [label, view.y - (shelf_y + 92.0)])

	# Now the low drop: let go NEAR the shelf but not on it. This is the half
	# that a 4:3 screen breaks. "Dropped on the shelf means put it away" was a
	# fixed y=600, which on a 960-tall viewport is the middle of the room --
	# so every sticker placed in the lower half of the base quietly vanished
	# the moment the finger came off it.
	var low := Vector2(880.0, shelf_y - 70.0)
	var had: int = placed.size()
	await _finger(Vector2(TRAY_FIRST.x + 74.0, shelf_y + 46.0), low)
	print("   a low drop at %s -- stickers %d -> %d" % [low, had, placed.size()])
	if placed.size() != had + 1:
		out.append("%s: a sticker let go at y=%.0f, %.0f px clear of the shelf, "
			% [label, low.y, shelf_y - low.y] + "was swallowed")

	# And it is still there after the room is closed and reopened, because a
	# room that forgets is not a room he made.
	game.queue_free()
	await get_tree().process_frame
	var saved: Array = SaveManager.get_creation("base")
	if saved.size() != placed.size():
		out.append("%s: %d stickers on the wall, %d in the save file"
			% [label, placed.size(), saved.size()])
	return out


## A finger touches GLASS, not the design grid.
##
## Input events arrive in window pixels and Godot's stretch transform turns
## them into viewport coordinates. Those are the same number only when the
## window happens to be 1280x720; on the iPad shape the window is smaller than
## the viewport it is stretched from, so a probe that pushes design
## coordinates straight in aims at the wrong place -- and "the drag missed"
## and "the drag is broken" look identical in the result.
func _glass(at: Vector2) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(get_window().size)
	return Vector2(at.x * win.x / view.x, at.y * win.y / view.y)


## One finger: down, a few steps across the screen, up. This is what an iPad
## sends. It is deliberately NOT a mouse event -- the desktop turns mouse into
## touch for free, which is exactly how this stayed broken.
func _finger(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(from)
	Input.parse_input_event(down)
	await get_tree().process_frame

	var last := from
	for step in range(1, 7):
		var at: Vector2 = from.lerp(to, float(step) / 6.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _glass(at)
		drag.relative = _glass(at) - _glass(last)
		last = at
		Input.parse_input_event(drag)
		await get_tree().process_frame

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(to)
	Input.parse_input_event(up)
	await get_tree().process_frame
