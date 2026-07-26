extends Node
## Can a child actually touch the game?
##
##   xvfb-run -a godot --path . res://tests/TouchProbe.tscn
##
## Every other check in this repo answers "does it build" or "does it look
## right", and a level can pass both while being completely dead. That is not
## hypothetical: five of the nine templates shipped with a zero-sized tap area,
## so twelve levels -- including the first one in the game -- drew perfectly
## and ignored every press. A screenshot could not tell. A parse check could
## not tell. The only thing that can tell is a finger.
##
## So this presses things.
##
## Two questions per level:
##   1. is the play area a real rectangle, or a zero-size one in the corner?
##   2. does pressing inside it change anything?
##
## Question 1 is the general form and catches templates this probe has never
## heard of. Question 2 is the specific one, and needs to know what "changed"
## means for each template.

const CASES := [
	# level id            template            the field    what a tap should move
	["sunny_park_01",     "observation_search", "_field",  "_found"],
	["sunny_park_04",     "memory_rhythm",      "_field",  ""],
	["night_city_02",     "puzzle_mechanism",   "_field",  "_pieces"],
	["night_city_03",     "roleplay_rescue",    "_field",  ""],
	["monster_valley_02", "puzzle_mechanism",   "_field",  "_pieces"],
	["sky_base_04",       "puzzle_mechanism",   "_field",  "_pieces"],
	["dark_castle_03",    "puzzle_mechanism",   "_field",  "_pieces"],
	["hero_studio",       "creative_play",      "_canvas", ""],
]

const SCENES := {
	"observation_search": "res://scenes/minigames/observation_search/ObservationSearch.tscn",
	"memory_rhythm": "res://scenes/minigames/memory_rhythm/MemoryRhythm.tscn",
	"puzzle_mechanism": "res://scenes/minigames/puzzle_mechanism/PuzzleMechanism.tscn",
	"roleplay_rescue": "res://scenes/minigames/roleplay_rescue/RoleplayRescue.tscn",
	"creative_play": "res://scenes/minigames/creative_play/CreativePlay.tscn",
}


func _ready() -> void:
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	await get_tree().process_frame

	print("=== touch probe ===")
	var failures: Array[String] = []
	for case in CASES:
		failures.append_array(await _check(str(case[0]), str(case[1]),
			str(case[2]), str(case[3])))

	if failures.is_empty():
		print("TOUCH PROBE PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			print("  FAIL: ", f)
		print("TOUCH PROBE FAILED")
		get_tree().quit(1)


func _check(level_id: String, template: String, field_name: String,
		_moves: String) -> Array[String]:
	var out: Array[String] = []
	GameManager.current_level_id = level_id
	var game: Node = load(str(SCENES[template])).instantiate()
	add_child(game)
	for i in range(6):
		await get_tree().process_frame

	var field: Control = game.get(field_name)
	if field == null:
		out.append("%s (%s): no %s at all" % [level_id, template, field_name])
		game.queue_free()
		await get_tree().process_frame
		return out

	# 1. A real rectangle. This is the one that was wrong everywhere: a Control
	# handed to a Node2D never resolves its anchors, so the tap area collapses
	# to (0, 0) while the level keeps drawing perfectly.
	var rect: Rect2 = field.get_global_rect()
	print("-- %s (%s): play area %s" % [level_id, template, rect])
	if rect.size.x < 640.0 or rect.size.y < 360.0:
		out.append("%s (%s): the play area is %.0fx%.0f -- nothing can be tapped"
			% [level_id, template, rect.size.x, rect.size.y])
		game.queue_free()
		await get_tree().process_frame
		return out

	# 2. Control really is handed back after the opening demo.
	var waited := 0.0
	while field.mouse_filter == Control.MOUSE_FILTER_IGNORE and waited < 15.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if field.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		out.append("%s: never hands control back -- taps do nothing, forever"
			% level_id)
		game.queue_free()
		await get_tree().process_frame
		return out

	# 3. Pressing does something. Where a template exposes a row of pieces the
	# probe presses one and watches its state; otherwise it presses the middle
	# of the field and only asks that the handler ran at all.
	var pieces: Variant = game.get("_pieces")
	if pieces is Array and not (pieces as Array).is_empty():
		var piece: Dictionary = (pieces as Array)[0]
		var before: int = int(piece.get("state", 0))
		await _tap(piece["at"])
		var after: int = int(piece.get("state", 0))
		print("   piece 0: state %d -> %d" % [before, after])
		if after == before:
			out.append("%s: tapping a piece does nothing (state stayed %d)"
				% [level_id, before])
		else:
			# ...and it can be finished the way a child would finish it.
			var taps := 0
			for p in (pieces as Array):
				while not game.call("_piece_ok", p) and taps < 40:
					await _tap(p["at"])
					taps += 1
			if not game.call("_solved"):
				out.append("%s: cannot be solved by tapping (%d taps)"
					% [level_id, taps])
			else:
				print("   solved by tapping, %d taps" % taps)
	else:
		var reached := [false]
		field.gui_input.connect(func(event: InputEvent):
			if UiKit.is_press(event):
				reached[0] = true)
		await _tap(rect.position + rect.size * 0.5)
		print("   a press in the middle reached the field: ", reached[0])
		if not reached[0]:
			out.append("%s: a press in the middle of the screen never arrives"
				% level_id)

	game.queue_free()
	await get_tree().process_frame
	return out


## One tap, through Input, exactly as a finger delivers it.
func _tap(at: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	Input.parse_input_event(up)
	await get_tree().process_frame
