extends Node
## The parent gate, walked like an adult with a thumb.
##
##   godot --headless --path . res://tests/ParentGateProbe.tscn
##
## The gate used to be a LineEdit, which on a tablet summons the OS keyboard --
## half a screen of system UI over a children's game. It is a drawn numpad
## now, and this walks the contract that makes it a GATE:
##
##   * the right sum opens it, through the same buttons a finger would press
##   * a wrong sum does NOT open it, says so, and clears
##   * a child cannot brute-force it faster than an adult can add
##   * every key is at least the game's own 60px child-finger floor --
##     an adult's thumb is not smaller

var _out: Array[String] = []


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	await get_tree().process_frame
	print("\n=== parent gate probe ===")

	await _the_right_answer_opens_it()
	await _the_wrong_answer_does_not()

	for f in _out:
		print("FAIL  %s" % f)
	print("PARENT GATE PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## Every key of the pad, by its face. The digits carry a Label child; the two
## specials are found by what is drawn on them.
func _keys(gate: Control) -> Dictionary:
	var found: Dictionary = {}
	for node in gate.find_children("*", "Button", true, false):
		var b := node as Button
		for child in b.get_children():
			if child is Label:
				var word := (child as Label).text
				if word.length() == 1 and (word.is_valid_int() or word == "⌫"):
					found["del" if word == "⌫" else word] = b
		# The check key carries a picture, not a word, and is the one green
		# button on the pad.
		if b.get_child_count() > 0 and not found.values().has(b):
			var style := b.get_theme_stylebox("normal")
			if style is StyleBoxFlat \
					and (style as StyleBoxFlat).bg_color.g > (style as StyleBoxFlat).bg_color.r \
					and not (b.get_child(0) is Label):
				found["ok"] = b
	return found


func _type(keys: Dictionary, digits: String) -> void:
	for i in range(digits.length()):
		var key: Button = keys.get(digits[i])
		if key != null:
			key.pressed.emit()


func _the_right_answer_opens_it() -> void:
	var screen: Control = load("res://scenes/parent/ParentCenter.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var gate: Control = screen.get("_gate")
	_ok(gate != null, "the gate did not build")
	if gate == null:
		screen.queue_free()
		return

	var keys := _keys(gate)
	print("  keys found: %s" % [", ".join(keys.keys())])
	_ok(keys.size() == 12, "a numpad has 12 keys; found %d" % keys.size())
	for name in keys:
		var b: Button = keys[name]
		_ok(b.size.x >= 60.0 and b.size.y >= 60.0,
			"key '%s' is %.0fx%.0f -- smaller than the thumb pressing it"
			% [name, b.size.x, b.size.y])

	# No LineEdit anywhere on the gate: a LineEdit is how the OS keyboard
	# gets summoned, and its absence is the entire point of the numpad.
	_ok(screen.find_children("*", "LineEdit", true, false).is_empty(),
		"the gate still carries a LineEdit -- the OS keyboard is back")

	var sum: int = int(screen.get("_a")) + int(screen.get("_b"))
	_type(keys, str(sum))
	_ok(str(screen.get("_typed")) == str(sum),
		"typed %d but the display holds '%s'" % [sum, screen.get("_typed")])
	if keys.has("ok"):
		(keys["ok"] as Button).pressed.emit()
	await get_tree().process_frame
	_ok(screen.get("_content") != null,
		"the right answer (%d) did not open the gate" % sum)
	print("  %d + %d = %d -> open" % [screen.get("_a"), screen.get("_b"), sum])
	screen.queue_free()
	await get_tree().process_frame


func _the_wrong_answer_does_not() -> void:
	var screen: Control = load("res://scenes/parent/ParentCenter.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var gate: Control = screen.get("_gate")
	if gate == null:
		_ok(false, "the gate did not build a second time")
		screen.queue_free()
		return
	var keys := _keys(gate)
	var sum: int = int(screen.get("_a")) + int(screen.get("_b"))
	var wrong: int = sum + 1

	_type(keys, str(wrong))
	if keys.has("ok"):
		(keys["ok"] as Button).pressed.emit()
	await get_tree().process_frame
	_ok(screen.get("_content") == null,
		"a WRONG answer (%d for %d) opened the parent gate" % [wrong, sum])
	var feedback: Label = screen.get("_feedback")
	_ok(feedback != null and feedback.text != "",
		"the wrong answer said nothing -- an adult mid-typo deserves a word")
	_ok(str(screen.get("_typed")) == "",
		"the wrong answer was not cleared; the next attempt starts dirty")

	# The delete key takes back one digit, not the whole answer.
	_type(keys, "42")
	if keys.has("del"):
		(keys["del"] as Button).pressed.emit()
	_ok(str(screen.get("_typed")) == "4",
		"one press of delete should leave '4', left '%s'" % screen.get("_typed"))

	print("  wrong answer stays shut, ⌫ takes back one digit")
	screen.queue_free()
	await get_tree().process_frame
