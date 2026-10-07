extends Node
## One-off interaction probe for the Monster Arena template. Not part of the
## regular smoke test (which proves scenes instantiate); this drives the battle
## the way a finger would and asserts the loop actually plays: sparks spawn,
## taps score, duds nudge without scoring, the meter fills, the win sequence
## fires, and the game lands on the result screen.

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== monster battle probe ===")
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	await get_tree().process_frame

	# Prime the game exactly the way the map does, for the dud-heavy level.
	SaveManager.set_setting("difficulty", LevelManager.NORMAL)
	GameManager.current_level_id = "monster_arena_03"
	var packed: PackedScene = load("res://scenes/minigames/monster_battle/MonsterBattle.tscn")
	var battle: Node = packed.instantiate()
	add_child(battle)
	for i in range(10):
		await get_tree().process_frame

	_ok(battle._monster != null, "monster was not built")
	_ok(battle._hero != null, "hero was not built")
	var goal: int = battle.target_value("correct", 12)
	_ok(battle._meter_cells.size() == goal,
		"the meter should have one cell per spark needed (%d)" % goal)
	_ok(battle._hero.core_position() != Vector2.ZERO, "hero core position unavailable")

	# Let sparks accumulate.
	for i in range(240):
		await get_tree().process_frame

	var tap := InputEventScreenTouch.new()
	tap.pressed = true

	# Drive a dud first: score must NOT move, mistake must.
	var before_correct: int = battle.result.correct
	var before_mistakes: int = battle.result.mistakes
	battle._on_spark_input(tap, _make_fake_spark(battle), true)
	_ok(battle.result.correct == before_correct, "dud tap raised the score")
	_ok(battle.result.mistakes == before_mistakes + 1, "dud tap did not register a mistake")

	# Now win the level with real taps through the input handler. Tap as
	# many times as the LEVEL asks for -- the target moves whenever the
	# island is retuned, and a probe that counts to a remembered number
	# stops testing and starts hanging.
	for i in range(goal):
		battle._on_spark_input(tap, _make_fake_spark(battle), false)
		await get_tree().process_frame
	_ok(battle.result.correct >= goal,
		"%d spark taps did not reach the target (got %d)" % [goal, battle.result.correct])
	_ok(battle._won, "level did not enter the won state")

	var lit: int = 0
	for cell in battle._meter_cells:
		if is_instance_valid(cell) and cell.modulate.a > 0.9:
			lit += 1
	_ok(lit == goal, "meter shows %d lit cells, expected %d" % [lit, goal])

	# The win sequence holds ~2.2s of real time before finish_level fires
	# level_finished (and then swaps scenes, which would free this probe).
	# Await the signal itself and assert before the swap lands.
	var result: LevelResult = await GameManager.level_finished
	_ok(result != null, "level_finished carried no result")
	if result != null:
		_ok(result.stars() == 2,
			"one mistake on a finished run should score 2 stars, got %d" % result.stars())
		_ok(result.correct >= 12, "stored result lost the correct count")
	_ok(GameManager.get_last_result() == result, "finish_level did not store last_result")

	for f in _failures:
		print("FAIL  %s" % f)
	print("BATTLE PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


## A stand-in spark Panel at a plausible position, so the input handler can be
## driven without synthesising real touch routing.
func _make_fake_spark(battle: Node) -> Panel:
	var node := Panel.new()
	node.size = Vector2(116, 116)
	node.position = Vector2(940, 320) - node.size / 2.0
	node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	battle._play_area.add_child(node)
	return node
