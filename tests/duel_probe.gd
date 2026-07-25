extends Node
## Interaction probe for the duel template: skill cooldowns gate, the ult
## economy charges and pays, the shield turns attacks into hits, and the
## duel completes into a stored result. Drives the skill methods the way
## thumbs would.

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


## The out-of-light card is the play area's own overlay: full-rect, and the
## only child that eats input.
func _find_card(play_area: Control) -> Control:
	for child in play_area.get_children():
		if child is Control and child.z_index == 90:
			return child
	return null


func _collect_buttons(node: Node, into: Array) -> void:
	for child in node.get_children():
		if child is Button:
			into.append(child)
		_collect_buttons(child, into)


func _ready() -> void:
	print("\n=== duel probe ===")
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	await get_tree().process_frame

	GameManager.current_level_id = "monster_arena_04"
	var packed: PackedScene = load("res://scenes/minigames/monster_duel/MonsterDuel.tscn")
	var duel: Node = packed.instantiate()
	add_child(duel)
	for i in range(10):
		await get_tree().process_frame

	_ok(duel._started, "a no-choice duel should start immediately")
	_ok(duel._monster != null and duel._hero != null, "duel actors missing")
	_ok(duel._meter_cells.size() == 8, "arena_04 meter should have 8 cells")

	# Beam: fires once, then the cooldown gate holds.
	_ok(duel.fire_beam_skill(), "first beam should fire")
	_ok(duel.result.correct == 1, "beam should land one hit")
	_ok(duel._ult_charge == 1, "beam should charge the ult")
	_ok(not duel.fire_beam_skill(), "second beam must be blocked by cooldown")
	_ok(duel.result.correct == 1, "blocked beam must not score")

	# Ult: gated until charged, pays three when fired.
	_ok(not duel.fire_ult(), "ult must refuse before charge is full")
	duel._ult_charge = duel._ult_needed
	var before: int = duel.result.correct
	_ok(duel.fire_ult(), "charged ult should fire")
	await get_tree().create_timer(1.2).timeout
	_ok(duel.result.correct == before + 3,
		"ult should land three hits, landed %d" % (duel.result.correct - before))
	_ok(duel._ult_charge == 0, "ult should spend its charge")

	# Shield: activates, gate holds, and a blocked attack becomes a hit.
	_ok(duel.activate_shield(), "shield should activate")
	_ok(duel.shield_active(), "shield should report active")
	_ok(not duel.activate_shield(), "second shield must be blocked by cooldown")
	var hits_before: int = duel.result.correct
	var fake := Panel.new()
	fake.size = Vector2(80, 80)
	fake.position = Vector2(240, 500)
	duel._play_area.add_child(fake)
	duel._threats.append(fake)
	duel._threat_arrives(fake)
	await get_tree().create_timer(0.7).timeout
	_ok(duel.result.correct == hits_before + 1,
		"a shielded attack should bounce back and count")

	# Unshielded hit: progress is never removed, but since the light-bar
	# redesign (the "no urgency" feedback) it DOES cost one light pip and one
	# star of accuracy -- that is the urgency. The level itself is never lost.
	duel._shield_until = 0.0
	var cd_before: float = duel._beam_ready_at
	var light_before: int = duel._light_left
	var fake2 := Panel.new()
	fake2.size = Vector2(80, 80)
	fake2.position = Vector2(240, 500)
	duel._play_area.add_child(fake2)
	duel._threats.append(fake2)
	duel._threat_arrives(fake2)
	_ok(duel.result.correct == hits_before + 1, "an unshielded hit must not remove progress")
	_ok(duel._beam_ready_at > cd_before, "an unshielded hit should rest the beam briefly")
	_ok(duel.result.mistakes == 1, "an unshielded hit costs one star of accuracy")
	_ok(duel._light_left == light_before - 1, "an unshielded hit dims one light pip")

	# --- the light bar has to MEAN something ---------------------------
	#
	# It used to refill itself after a beat, so a child could stand there
	# taking hits forever with an empty bar and nothing at all would happen.
	# Now an empty bar stops the duel and offers a choice.
	SaveManager.data["rewards"]["items"]["heart_potion"] = 1
	while duel._light_left > 0:
		duel._lose_light()
	await get_tree().process_frame
	_ok(get_tree().paused, "an empty light bar pauses the fight")
	var card: Control = _find_card(duel._play_area)
	_ok(card != null, "an empty light bar raises the choice card")
	var choices: Array = []
	if card != null:
		_collect_buttons(card, choices)
	_ok(choices.size() == 2, "with a potion owned there are two choices, got %d"
		% choices.size())

	# Spending the potion: light back, fight on, one potion gone.
	if choices.size() == 2:
		(choices[0] as Button).pressed.emit()
	await get_tree().process_frame
	_ok(not get_tree().paused, "spending a potion resumes the fight")
	_ok(duel._light_left == duel.LIGHT_PIPS, "a potion refills the light bar")
	_ok(SaveManager.item_count("heart_potion") == 0, "the potion is spent")
	_ok(_find_card(duel._play_area) == null, "the card goes away")

	# And with no potion left, the only way out is to finish here.
	while duel._light_left > 0:
		duel._lose_light()
	await get_tree().process_frame
	var card2: Control = _find_card(duel._play_area)
	var choices2: Array = []
	if card2 != null:
		_collect_buttons(card2, choices2)
	_ok(choices2.size() == 1, "with no potion there is one choice, got %d"
		% choices2.size())
	get_tree().paused = false
	if card2 != null:
		card2.queue_free()
	await get_tree().process_frame

	# Wipe the probe's deliberate hits, then finish: the stored result must
	# be the 3-star one an actually-clean run earns.
	duel.result.mistakes = 0
	while duel.result.correct < 8:
		duel._land_hit(1)
	var stored: LevelResult = await GameManager.level_finished
	_ok(stored != null and stored.stars() == 3, "a clean duel should store 3 stars")

	for f in _failures:
		print("FAIL  %s" % f)
	print("DUEL PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)
