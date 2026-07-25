extends Node
## Drives Dance Mode / Light Song the way thumbs do: taps during the demo,
## taps after it, right notes, wrong notes. Written after a six-year-old
## reported "tapping does nothing".

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _tap(echo: Node, index: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	echo._on_pad_input(ev, index)


func _ready() -> void:
	print("\n=== echo probe ===")
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
	await get_tree().process_frame

	GameManager.current_level_id = "bluey_park_03"
	var packed: PackedScene = load("res://scenes/minigames/light_echo/LightEcho.tscn")
	var echo: Node = packed.instantiate()
	add_child(echo)
	for i in range(6):
		await get_tree().process_frame

	_ok(echo._pads.size() == 4, "dance mode should build four pads")
	print("  pads=%d  listening=%s  sequence=%s" % [
		echo._pads.size(), echo._listening, echo._sequence])

	# The bug that earned this probe: a phrase like [1, 1] is one pad
	# blinking twice, which at six is indistinguishable from one note.
	for i in range(1, echo._sequence.size()):
		_ok(int(echo._sequence[i]) != int(echo._sequence[i - 1]),
			"no phrase may repeat a pad back to back")
	_ok(echo._dots.size() == echo._sequence.size(),
		"one note lamp per note in the phrase")

	# The window a child actually taps in: while the island is still singing.
	var correct_before: int = echo.result.correct
	_tap(echo, 0)
	_ok(echo.result.correct == correct_before, "a tap during the demo scores nothing")
	print("  during demo: listening=%s (taps are ignored here)" % echo._listening)

	# How long until it IS the child's turn?
	var waited := 0.0
	while not echo._listening and waited < 12.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	print("  demo took %.1f s before the child's turn" % waited)
	_ok(echo._listening, "the demo must hand over within twelve seconds")

	# Now the real question: does a correct tap register at all?
	var sequence: Array = echo._sequence.duplicate()
	_tap(echo, int(sequence[0]))
	_ok(echo._position == 1, "the first correct tap must advance the song")
	_ok(echo._dots[0].get_node("Tick").visible,
		"a correct tap must tick a lamp -- visible proof it counted")
	_ok(not echo._dots[sequence.size() - 1].get_node("Tick").visible,
		"lamps still to come stay unticked")
	print("  after one correct tap: position=%d of %d, lamp ticked=%s" % [
		echo._position, sequence.size(), echo._dots[0].get_node("Tick").visible])

	# Finish the phrase and check the round scores.
	for i in range(1, sequence.size()):
		_tap(echo, int(sequence[i]))
	await get_tree().create_timer(0.2).timeout
	_ok(echo.result.correct == correct_before + 1, "a completed phrase scores one")
	print("  after the whole phrase: correct=%d" % echo.result.correct)

	# A hundred phrases at every length: none may repeat a pad. Generation is
	# pure, so this costs nothing and cannot pile up coroutines.
	for length in range(2, 9):
		for attempt in range(100):
			var phrase: Array = echo.make_phrase(length)
			_ok(phrase.size() == length, "phrase length %d honoured" % length)
			for i in range(1, phrase.size()):
				if int(phrase[i]) == int(phrase[i - 1]):
					_ok(false, "phrase repeats a pad at length %d" % length)
					break

	# The teaching rule: the lamps carry the phrase's colours while the
	# island sings, and the FIRST phrase of a level keeps them up while the
	# child answers -- a copy-the-recipe round.
	_ok(echo.has_method("_reveal"), "the lamps can reveal the phrase")
	echo._sequence = [0, 1]
	echo._build_dots(2)
	echo._reveal(true)
	var swatch: Polygon2D = echo._dots[0].get_node("Art/Swatch")
	_ok(swatch.color.a > 0.5, "a revealed lamp shows its note's colour")
	_ok(swatch.color.is_equal_approx(echo._pads[0]["color"]),
		"lamp one shows the colour of note one, in order")
	echo._reveal(false)
	_ok(echo._dots[0].get_node("Art/Swatch").color.a < 0.01,
		"hiding the phrase clears the colours")

	for f in _failures:
		print("FAIL  %s" % f)
	print("ECHO PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)
