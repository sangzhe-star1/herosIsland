extends Node
## How many press events does ONE click deliver to a pad?
##
## project.godot turns on pointing/emulate_touch_from_mouse so the desktop
## build can be tested like a tablet. The question this probe answers is
## whether that emulation makes a single click arrive TWICE at the same
## Control -- once as a mouse button, once as an emulated screen touch --
## because every gui_input handler in this game accepts both.

var _presses := 0


func _ready() -> void:
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	await get_tree().process_frame

	GameManager.current_level_id = "bluey_park_03"
	var echo: Node = load("res://scenes/minigames/light_echo/LightEcho.tscn").instantiate()
	add_child(echo)
	for i in range(6):
		await get_tree().process_frame
	while not echo._listening:
		await get_tree().create_timer(0.1).timeout

	# Count the presses the SHARED rule reports for one pad. This is the
	# regression: it must be exactly one per click, forever.
	var pad: Panel = echo._pads[0]["node"]
	pad.gui_input.connect(func(event: InputEvent):
		if UiKit.is_press(event):
			_presses += 1
			print("    press from %s" % event.get_class())
	)

	# One click, dead centre of the pad, through the real input pipeline.
	echo._sequence = [0, 1]
	echo._position = 0
	echo.result.mistakes = 0
	var at: Vector2 = pad.position + pad.size / 2.0
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame

	print("  ONE CLICK delivered %d press event(s)" % _presses)
	print("  position=%d  mistakes=%d" % [echo._position, echo.result.mistakes])

	var failures: Array[String] = []
	if _presses != 1:
		failures.append("one click must deliver exactly one press, got %d" % _presses)
	if echo._position != 1:
		failures.append("a correct tap must advance the phrase once")
	if echo.result.mistakes != 0:
		failures.append("a correct tap must not also be judged wrong")
	for f in failures:
		print("FAIL  %s" % f)
	print("TAP PROBE %s\n" % ("PASSED" if failures.is_empty() else "FAILED"))
	get_tree().quit(1 if failures.size() > 0 else 0)
