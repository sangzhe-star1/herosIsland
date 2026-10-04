extends Node
## Every tap gets an answer, and the answer is about the right thing.
##
##   godot --headless --path . res://tests/FeedbackProbe.tscn
##
## Five templates, one question each way: when the child does something, does
## the screen say so -- and does it stop saying the OLD thing? Written from an
## audit that found a hint glow left burning on a bin after the item was sorted
## (so the next hint pointed at two bins), a fumbled drag on empty ground that
## cost a star, a tap during the phrase that got silence, and a finished piece
## that swallowed its tap. None of that shows in a screenshot; all of it is a
## six-year-old walking away.

const SORT := "res://scenes/minigames/matching_sorting/MatchingSorting.tscn"
const RHYTHM := "res://scenes/minigames/memory_rhythm/MemoryRhythm.tscn"
const PUZZLE := "res://scenes/minigames/puzzle_mechanism/PuzzleMechanism.tscn"
const DUEL := "res://scenes/minigames/monster_duel/MonsterDuel.tscn"
const KEEPY := "res://scenes/minigames/keepy_uppy/KeepyUppy.tscn"

var _failures: Array[String] = []
var _asked := 0
## One fewer means a section bailed out early and its checks never ran.
const CHECKS_EXPECTED := 28


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== feedback probe ===")
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
	await get_tree().process_frame

	await _sorting_answers_every_drop()
	await _rhythm_answers_a_tap_during_the_phrase()
	await _puzzle_answers_a_tap_on_a_finished_piece()
	await _duel_answers_a_stroke_it_did_not_recognise()
	await _keepy_counts_in_balloons()

	if _asked < CHECKS_EXPECTED:
		_failures.append("only %d questions asked, expected at least %d -- a section"
			% [_asked, CHECKS_EXPECTED] + " was skipped silently")
	for f in _failures:
		print("FAIL  ", f)
	print("asked %d questions" % _asked)
	print("FEEDBACK PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- helpers ------------------------------------------------------------------

func _all(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out.append_array(_all(c))
	return out


## A Shapes.glow is a Node2D holding one Sprite2D with a radial gradient. Count
## them under `root`, so "does this bin still glow" is a number.
func _glows_under(root: Node) -> int:
	var n := 0
	for node in _all(root):
		if node is Sprite2D and (node as Sprite2D).texture is GradientTexture2D:
			n += 1
	return n


func _lit_pips(row: HBoxContainer) -> int:
	var n := 0
	for pip in row.get_children():
		if pip is Control and (pip as Control).modulate.a > 0.9:
			n += 1
	return n


func _touch(at: Vector2, pressed: bool = true) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = at
	return ev


func _spawn(scene: String, level: String, frames: int = 12) -> Node:
	GameManager.current_level_id = level
	var node: Node = load(scene).instantiate()
	add_child(node)
	for i in frames:
		await get_tree().process_frame
	return node


func _drop(node: Node) -> void:
	node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# --- sorting ------------------------------------------------------------------

func _sorting_answers_every_drop() -> void:
	var sorter: Node = await _spawn(SORT, "sunny_park_02")
	var field: Node = sorter.get("_field")
	var bins: Array = sorter.get("_bins")
	_ok(bins.size() >= 2 and not (sorter.get("_current") as Dictionary).is_empty(),
		"sorting level did not build bins and a first item -- nothing below ran")
	if bins.size() < 2 or (sorter.get("_current") as Dictionary).is_empty():
		await _drop(sorter)
		return
	var view: Vector2 = field.get_viewport_rect().size

	# The counter is pictures, centred, and clear of the back button.
	var pips: Variant = sorter.get("_pips")
	_ok(pips is HBoxContainer and (pips as HBoxContainer).get_child_count()
		== int(sorter.get("_wanted")),
		"the sorting counter is not one pip per thing to sort -- '3 / 8' is a"
		+ " sentence in a language he does not have yet")
	if pips is HBoxContainer:
		var row := pips as HBoxContainer
		var w: float = UiKit.pip_row_width(row.get_child_count())
		_ok(absf(row.position.x + w * 0.5 - view.x * 0.5) < 1.5,
			"pip row is not centred: x=%.0f width=%.0f on a %.0f-wide screen"
			% [row.position.x, w, view.x])
		_ok(row.position.x > 136.0,
			"pip row at x=%.0f runs into the back button" % row.position.x)
		_ok(_lit_pips(row) == 0, "a pip is lit before anything was sorted")

	# A hint at level one glows the right bin. That is fine WHILE the item is
	# waiting; the bug was that it stayed.
	sorter.call("_glow_right_bin")
	await get_tree().process_frame
	var right: Dictionary = sorter.call("_right_bin")
	_ok(_glows_under(right["node"]) > 0, "the level-one hint did not glow the right bin")

	# A drop on empty ground: the item floats home and nothing else happens.
	var item: Dictionary = sorter.get("_current")
	var result: LevelResult = sorter.get("result")
	var mistakes_before: int = result.mistakes
	var sounds_before: int = AudioManager.sfx_plays
	field.emit_signal("dropped", item, {}, false)
	await get_tree().process_frame
	_ok(result.mistakes == mistakes_before,
		"dropping the thing on empty ground counted as a mistake -- a fumbled drag"
		+ " costs a star")
	_ok(AudioManager.sfx_plays == sounds_before,
		"dropping the thing on empty ground played a sound (try_again?) -- a fumble"
		+ " is not a wrong answer")

	# A drop on the WRONG bin is still a mistake.
	var wrong: Dictionary = {}
	for bin in bins:
		if bin != right:
			wrong = bin
			break
	var before_wrong: int = result.mistakes
	field.emit_signal("dropped", item, wrong["slot"], false)
	await get_tree().process_frame
	_ok(result.mistakes == before_wrong + 1,
		"a drop on the wrong bin no longer counts -- the fix went too far")

	# Now sort it properly, the way a finger does: grab, carry, let go.
	var node: Node2D = item["node"]
	var done_before: int = int(sorter.get("_done"))
	field.call("_grab", node.position)
	field.call("_move", (right["node"] as Node2D).position)
	field.call("_release", (right["node"] as Node2D).position)
	for i in 3:
		await get_tree().process_frame
	_ok(int(sorter.get("_done")) == done_before + 1, "a correct drop did not count")
	var burning := 0
	for bin in bins:
		burning += _glows_under(bin["node"])
	_ok(burning == 0,
		"%d hint glow(s) still burning on the bins after the item was sorted -- the"
		% burning + " next hint will point at two bins")
	if pips is HBoxContainer:
		_ok(_lit_pips(pips) == done_before + 1,
			"the pip row shows %d lit after %d sorted" % [_lit_pips(pips), done_before + 1])

	# The sentence gets its own label, so it can never eat the counter.
	sorter.call("_say", "sorting.try_again")
	await get_tree().process_frame
	var note: Variant = sorter.get("_note")
	_ok(note is Label and str((note as Label).text) != "",
		"the 'try again' sentence has nowhere of its own to go")
	if pips is HBoxContainer:
		_ok((pips as HBoxContainer).get_child_count() == int(sorter.get("_wanted")),
			"saying a sentence changed the counter")
	await _drop(sorter)


# --- rhythm -------------------------------------------------------------------

func _rhythm_answers_a_tap_during_the_phrase() -> void:
	var rhythm: Node = await _spawn(RHYTHM, "sunny_park_04")
	var pads: Array = rhythm.get("_pads")
	_ok(pads.size() == 4, "rhythm level did not build four pads -- nothing below ran")
	if pads.size() != 4:
		await _drop(rhythm)
		return

	# The phrase is playing: the child taps anyway, as children do.
	rhythm.call("_build_phrase", 2)
	rhythm.set("_listening", false)
	var pad: Dictionary = pads[1]
	var sounds_before: int = AudioManager.sfx_plays
	rhythm.call("_on_tap", _touch(pad["at"]))
	await get_tree().process_frame
	var answered: bool = (pad["node"] as Node).has_meta("_nudge_tween") \
		or (pad["node"] as Node).has_meta("_flash_tween")
	_ok(answered, "a tap on a pad while the phrase plays moved nothing on screen")
	_ok(AudioManager.sfx_plays > sounds_before,
		"a tap on a pad while the phrase plays made no sound -- to him the pad is broken")
	_ok(int(rhythm.get("_typed")) == 0, "a tap during the phrase must not count as an answer")

	# The level-two hint glows the next pad; a new phrase must put it out.
	rhythm.call("_flash_next")
	await get_tree().process_frame
	var glowing := 0
	for p in pads:
		glowing += _glows_under(p["node"])
	_ok(glowing > 0, "the level-two hint did not glow a pad")
	rhythm.call("_build_phrase", 3)
	await get_tree().process_frame
	glowing = 0
	for p in pads:
		glowing += _glows_under(p["node"])
	_ok(glowing == 0,
		"%d hint glow(s) still burning on the pads after the phrase moved on -- the"
		% glowing + " old answer stays lit through the new question")
	await _drop(rhythm)


# --- puzzle -------------------------------------------------------------------

func _puzzle_answers_a_tap_on_a_finished_piece() -> void:
	# night_city_02 is the wires puzzle: a joined wire cannot be re-pulled, so
	# a tap on it used to fall into silence.
	var puzzle: Node = await _spawn(PUZZLE, "night_city_02")
	var pieces: Array = puzzle.get("_pieces")
	_ok(pieces.size() >= 3, "puzzle level did not build its pieces -- nothing below ran")
	if pieces.size() < 3:
		await _drop(puzzle)
		return
	var pips: Variant = puzzle.get("_pips")
	_ok(pips is HBoxContainer and (pips as HBoxContainer).get_child_count()
		== int(puzzle.get("_steps")),
		"the puzzle counter is not one pip per piece")

	var piece: Dictionary = pieces[0]
	puzzle.call("_use", piece)
	await get_tree().process_frame
	_ok(bool(puzzle.call("_piece_ok", piece)), "joining a wire did not solve it")
	if pips is HBoxContainer:
		_ok(_lit_pips(pips) == 1, "one piece done, %d pips lit" % _lit_pips(pips))

	# The tap that used to vanish. The first tap left its own pop behind, so
	# forget that one: this is about the SECOND tap.
	var node: Node = piece["node"]
	if node.has_meta("_pop_tween"):
		node.remove_meta("_pop_tween")
	if node.has_meta("_flash_tween"):
		node.remove_meta("_flash_tween")
	var sounds_before: int = AudioManager.sfx_plays
	puzzle.call("_use", piece)
	await get_tree().process_frame
	var answered: bool = node.has_meta("_pop_tween") or node.has_meta("_flash_tween")
	_ok(answered and AudioManager.sfx_plays > sounds_before,
		"tapping a finished wire does nothing at all (moved=%s, sounded=%s)"
		% [answered, AudioManager.sfx_plays > sounds_before])
	_ok(bool(puzzle.call("_piece_ok", piece)), "tapping a finished wire un-did it")
	await _drop(puzzle)


# --- duel ---------------------------------------------------------------------

func _duel_answers_a_stroke_it_did_not_recognise() -> void:
	var duel: Node = await _spawn(DUEL, "battle_05", 20)
	_ok(duel.get("_stroke") != null, "the duel has no stroke layer -- nothing below ran")
	if duel.get("_stroke") == null:
		await _drop(duel)
		return
	duel.set("_started", true)
	# Fifty degrees off: outside every move's fan, as battle_feel_probe proves.
	# Long enough (about 106 px) to be a real attempt, not a button slip.
	var points := [Vector2(200, 500), Vector2(280, 430), Vector2(320, 400)]
	var sounds_before: int = AudioManager.sfx_plays
	duel.call("_on_stroke_input", _touch(points[0], true))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = points[1]
	duel.call("_on_stroke_input", drag)
	duel.call("_on_stroke_input", _touch(points[2], false))
	await get_tree().process_frame
	_ok(AudioManager.sfx_plays > sounds_before,
		"a stroke that matched no move got silence -- and with reduce-motion the"
		+ " trail is off too, so the child saw and heard nothing")
	var card: Variant = duel.get("_move_card")
	_ok(card is Node and ((card as Node).has_meta("_nudge_tween")
		or (card as Node).has_meta("_flash_tween")),
		"the move card did not answer an unrecognised stroke")
	await _drop(duel)


# --- keepy uppy ---------------------------------------------------------------

func _keepy_counts_in_balloons() -> void:
	var keepy: Node = await _spawn(KEEPY, "bonus_keepy")
	var area: Control = keepy.get("_play_area")
	var view: Vector2 = area.get_viewport_rect().size
	var pips: Variant = keepy.get("_pips")
	var target: int = int(keepy.call("target_value", "correct", 8))
	_ok(pips is HBoxContainer and (pips as HBoxContainer).get_child_count() == target,
		"keepy's counter is not one balloon per bounce to go (target %d)" % target)
	if pips is HBoxContainer:
		var row := pips as HBoxContainer
		var w: float = UiKit.pip_row_width(row.get_child_count())
		_ok(absf(row.position.x + w - (view.x - 24.0)) < 1.5 and absf(row.position.y - 24.0) < 0.5,
			"keepy's pips are not right-aligned 24 px from the real edge: x=%.0f w=%.0f view=%.0f"
			% [row.position.x, w, view.x])
		keepy.call("_bounce")
		await get_tree().process_frame
		_ok(_lit_pips(row) == 1, "one bounce, %d balloons lit" % _lit_pips(row))
	var vel: Vector2 = keepy.get("_velocity")
	_ok(vel.y < 0.0, "a fresh balloon should drift up first, vy=%.0f" % vel.y)
	await _drop(keepy)
