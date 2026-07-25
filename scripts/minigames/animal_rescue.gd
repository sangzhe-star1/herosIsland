extends LevelManager
## Sequencing template: follow the trail in the right order.
##
## Powers the three remaining levels from one file:
##   rescue_forest_01  Follow the Footprints  tap the trail 1, 2, 3...
##   rescue_forest_03  Plan the Rescue Route  longer trail, hazards to avoid
##   safety_fire_01    Find the Fire Exit     trail to the door, fire to avoid
##
## Order is shown as countable dots, never numerals, so the level needs no
## reading and quietly rehearses the same counting skill as Piglet Town.
##
## Difficulty 1 pulses the next step as a hint. Higher difficulties do not:
## the child has to work out what comes next by counting.

const MARGIN := Vector2(220.0, 190.0)
const STEP_SIZE := 104.0
const HAZARD_SIZE := 92.0
const MIN_SPACING := 150.0

var _trail_length := 4
var _hazard_count := 0
var _hint := true
var _goal_icon := "paw"

var _steps: Array = []          # Control per step, in order
var _next_step := 0
var _rounds_done := 0
var _resolving := false

var _play_area: Control
var _instruction: Label
var _progress: Label
var _round_holder: Control


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_trail_length = int(config.get("trail_length", 4))
	_hazard_count = int(config.get("hazards", 0))
	_goal_icon = str(config.get("goal_icon", "paw"))
	_hint = bool(config.get("hint", int(level_data.get("difficulty", 1)) <= 1))

	# Challenge scaling: longer trails through more hazards, more rounds.
	var rank := challenge_rank()
	if rank > 0:
		_trail_length = mini(_trail_length + (rank + 1) / 2, 8)
		_hazard_count = mini(_hazard_count + rank / 2, 6)
		bump_target("correct", mini(rank, 4))

	_build_ui(config)
	_start_round()


# --- construction -------------------------------------------------------

func _build_ui(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	build_world(_play_area, 0.25)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "rescue.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.INK)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 34)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.INK)
	_progress.position = Vector2(1020, 38)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()

	# Everything belonging to one trail lives here, so a round is cleared by
	# freeing a single node rather than tracking each piece.
	_round_holder = Control.new()
	_round_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_round_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_round_holder)


# --- rounds -------------------------------------------------------------

func _start_round() -> void:
	_next_step = 0
	_steps.clear()
	for child in _round_holder.get_children():
		child.queue_free()

	var placed: Array[Vector2] = []
	for i in range(_trail_length):
		var at: Vector2 = _find_spot(placed)
		placed.append(at)
		_steps.append(_build_step(i, at))

	for i in range(_hazard_count):
		var at: Vector2 = _find_spot(placed)
		placed.append(at)
		_build_hazard(at)

	_refresh_hint()

	# The goal breathes very gently the whole round: "this is where the trail
	# is going". Softer and slower than the next-step hint, so they never
	# compete for the eye.
	if Juice.motion_enabled() and not _steps.is_empty():
		var goal: Control = _steps[_steps.size() - 1]
		var tween := goal.create_tween().set_loops()
		tween.tween_property(goal, "scale", Vector2(1.05, 1.05), 1.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(goal, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE)


## Random placement that keeps everything reachable and non-overlapping.
## Falls back to the last candidate after enough tries rather than looping
## forever if the board is crowded.
func _find_spot(taken: Array[Vector2]) -> Vector2:
	var candidate := Vector2.ZERO
	for attempt in range(40):
		candidate = Vector2(
			randf_range(MARGIN.x, 1280.0 - MARGIN.x),
			randf_range(MARGIN.y, 720.0 - MARGIN.y)
		)
		var clear := true
		for other in taken:
			if candidate.distance_to(other) < MIN_SPACING:
				clear = false
				break
		if clear:
			return candidate
	return candidate


## A step in the trail. Shows its position in the sequence as dots, and the
## last one carries the goal icon so the child can see where the trail leads.
func _build_step(index: int, at: Vector2) -> Control:
	var step := Panel.new()
	step.size = Vector2(STEP_SIZE, STEP_SIZE)
	step.custom_minimum_size = step.size
	step.position = at - step.size / 2.0
	step.pivot_offset = step.size / 2.0
	step.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_goal: bool = index == _trail_length - 1
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE if not is_goal else Color(0.98, 0.92, 0.74)
	style.set_corner_radius_all(int(STEP_SIZE / 2.0))
	style.border_width_bottom = 6
	style.border_color = Color(0, 0, 0, 0.14)
	step.add_theme_stylebox_override("panel", style)

	if is_goal:
		var icon: Control = UiKit.picture(_goal_icon, STEP_SIZE * 0.62)
		if icon != null:
			icon.position = Vector2(STEP_SIZE * 0.19, STEP_SIZE * 0.19)
			step.add_child(icon)
	else:
		step.add_child(_dots(index + 1))

	step.gui_input.connect(_on_step_input.bind(index))
	_round_holder.add_child(step)
	return step


## Countable dots rather than a numeral: no reading, and it rehearses the same
## one-to-one counting the Piglet Town levels teach.
func _dots(count: int) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var columns := 2
	var rows: int = ceili(float(count) / float(columns))
	var spacing := 26.0
	for i in range(count):
		var dot := Panel.new()
		var radius := 18.0
		dot.size = Vector2(radius, radius)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.30, 0.48, 0.36)
		style.set_corner_radius_all(int(radius / 2.0))
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var row: int = i / columns
		var column: int = i % columns
		var in_row: int = mini(columns, count - row * columns)
		dot.position = Vector2(
			STEP_SIZE / 2.0 + (float(column) - float(in_row - 1) / 2.0) * spacing - radius / 2.0,
			STEP_SIZE / 2.0 + (float(row) - float(rows - 1) / 2.0) * spacing - radius / 2.0
		)
		holder.add_child(dot)
	return holder


## Something to route around. Tapping one is a mistake, but a gentle one --
## the trail is untouched and the child simply tries again.
func _build_hazard(at: Vector2) -> void:
	var hazard := Panel.new()
	hazard.size = Vector2(HAZARD_SIZE, HAZARD_SIZE)
	hazard.position = at - hazard.size / 2.0
	hazard.pivot_offset = hazard.size / 2.0
	hazard.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.86, 0.80)
	style.set_corner_radius_all(18)
	style.border_width_bottom = 6
	style.border_color = Color(0.70, 0.34, 0.28, 0.5)
	hazard.add_theme_stylebox_override("panel", style)

	var icon: Control = UiKit.picture("warning", HAZARD_SIZE * 0.62)
	if icon != null:
		icon.position = Vector2(HAZARD_SIZE * 0.19, HAZARD_SIZE * 0.19)
		hazard.add_child(icon)

	hazard.gui_input.connect(_on_hazard_input.bind(hazard))
	_round_holder.add_child(hazard)


## On the easiest difficulty the next step breathes gently, which turns the
## level into "follow the moving thing" -- playable before counting is solid.
func _refresh_hint() -> void:
	if not _hint or not Juice.motion_enabled():
		return
	if _next_step >= _steps.size():
		return
	var step: Control = _steps[_next_step]
	if not is_instance_valid(step):
		return
	var tween := step.create_tween().set_loops()
	tween.tween_property(step, "scale", Vector2(1.10, 1.10), 0.55)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(step, "scale", Vector2.ONE, 0.55)\
		.set_trans(Tween.TRANS_SINE)


# --- input --------------------------------------------------------------

func _on_step_input(event: InputEvent, index: int) -> void:
	if _resolving:
		return
	var pressed: bool = UiKit.is_press(event)
	if not pressed:
		return

	if index != _next_step:
		_wrong_step(index)
		return

	_take_step(index)


func _on_hazard_input(event: InputEvent, hazard: Control) -> void:
	if _resolving:
		return
	var pressed: bool = UiKit.is_press(event)
	if not pressed:
		return
	_instruction.text = I18n.t("rescue.avoid")
	AudioManager.play_voice("res://assets/audio/voice/level/try_again.ogg")
	Juice.nudge(hazard)
	score_mistake()


func _take_step(index: int) -> void:
	var step: Control = _steps[index]
	if not is_instance_valid(step):
		return

	# Taken steps stay on screen -- greened, ticked, and joined to the previous
	# stone by a dotted path, so the child watches the route they are building
	# grow across the screen rather than vanish behind them.
	step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step.modulate = Color(0.72, 1.0, 0.78, 0.85)
	var tick: Control = UiKit.picture("check", 44)
	if tick != null:
		tick.position = Vector2(STEP_SIZE - 34, -12)
		step.add_child(tick)
	if index > 0:
		_draw_path_segment(index - 1, index)
	Juice.pop(step)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")

	_next_step += 1
	if _next_step < _steps.size():
		_refresh_hint()
		return

	_finish_round(step)


## The dotted trail between two taken stones. Drawn behind the stones, one
## soft dot at a time so the path appears to be walked rather than stamped.
func _draw_path_segment(from_index: int, to_index: int) -> void:
	if from_index < 0 or to_index >= _steps.size():
		return
	var from_step: Control = _steps[from_index]
	var to_step: Control = _steps[to_index]
	if not (is_instance_valid(from_step) and is_instance_valid(to_step)):
		return
	var from: Vector2 = from_step.position + from_step.size / 2.0
	var to: Vector2 = to_step.position + to_step.size / 2.0
	var span := to - from
	var count := maxi(int(span.length() / 34.0), 2)
	for i in range(1, count):
		var dot := Panel.new()
		dot.size = Vector2(12, 12)
		dot.position = from + span * (float(i) / float(count)) - dot.size / 2.0
		dot.pivot_offset = dot.size / 2.0
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.75)
		style.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_round_holder.add_child(dot)
		_round_holder.move_child(dot, 0)
		if Juice.motion_enabled():
			dot.scale = Vector2.ZERO
			var t := dot.create_tween()
			t.tween_interval(0.03 * float(i))
			t.tween_property(dot, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _wrong_step(_index: int) -> void:
	_instruction.text = I18n.t("rescue.not_next")
	AudioManager.play_voice("res://assets/audio/voice/level/try_again.ogg")
	if _next_step < _steps.size():
		Juice.nudge(_steps[_next_step], 10.0)
	score_mistake()


func _finish_round(goal: Control) -> void:
	_resolving = true
	_rounds_done += 1
	_instruction.text = I18n.t("rescue.found")
	AudioManager.play_voice("res://assets/audio/voice/level/well_done.ogg")
	Juice.burst(_play_area, goal.position + goal.size / 2.0, 26)

	score_correct()
	_update_progress()

	await get_tree().create_timer(0.8).timeout
	_resolving = false
	if not result.met_target():
		_start_round()


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", 6)]
