extends LevelManager
## Sorting template: one item at a time, a row of bins, put it where it belongs.
##
## Everything -- the bins, the items, the answer key, the instruction -- comes
## from the level's "config" block, so this one file powers colour sorting,
## counting, danger spotting and tool choosing without a line of new code.
##
## Two ways to answer, because six-year-olds do both and neither should fail:
##   drag the item onto a bin, or tap the item and then tap a bin.
## A short drag that goes nowhere is treated as a tap rather than a mistake.

const ITEM_HOME := Vector2(640, 250)
const ITEM_SIZE := Vector2(150, 150)
const BIN_SIZE := Vector2(200, 190)
const BIN_ROW_Y := 470.0
const TAP_THRESHOLD := 14.0

var _bins: Array = []          # [{id, node, rect_source}]
var _item_pool: Array = []     # shuffled queue of item definitions
var _pool_index := 0

var _item: Control = null      # the item currently in play
var _item_answer: String = ""

var _dragging := false
var _selected := false
var _drag_offset := Vector2.ZERO
var _press_position := Vector2.ZERO
var _resolving := false

var _play_area: Control
var _instruction: Label
var _progress: Label


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_build_ui(config)
	_build_bins(config.get("bins", []))
	_load_pool(config)
	_next_item()


# --- construction -------------------------------------------------------

func _build_ui(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	var bg := ColorRect.new()
	bg.color = Color.from_string(str(config.get("background", "#cfe4f2")), Color(0.81, 0.89, 0.95))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(bg)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "sorting.instruction")))
	_instruction.add_theme_font_size_override("font_size", 38)
	_instruction.add_theme_color_override("font_color", UiKit.TEXT_DARK)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 40)
	_instruction.size = Vector2(600, 60)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", UiKit.TEXT_DARK)
	_progress.position = Vector2(1000, 40)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()


func _build_bins(definitions: Array) -> void:
	var count: int = definitions.size()
	if count == 0:
		push_error("item_sorting: level has no bins")
		return

	var spacing := 40.0
	var total_width: float = count * BIN_SIZE.x + (count - 1) * spacing
	var start_x: float = (1280.0 - total_width) / 2.0

	for i in range(count):
		var definition: Dictionary = definitions[i]
		var bin := Panel.new()
		bin.custom_minimum_size = BIN_SIZE
		bin.size = BIN_SIZE
		bin.position = Vector2(start_x + i * (BIN_SIZE.x + spacing), BIN_ROW_Y)
		bin.mouse_filter = Control.MOUSE_FILTER_STOP

		var color := Color.from_string(str(definition.get("color", "#bbbbbb")), Color.GRAY)
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(28)
		style.border_width_bottom = 8
		style.border_color = color.darkened(0.25)
		bin.add_theme_stylebox_override("panel", style)

		# A bin shows a label only if it has one. Colour-sorting bins are
		# deliberately wordless: the colour is the whole instruction.
		var label_text := ""
		if definition.has("label"):
			label_text = str(definition["label"])
		elif definition.has("label_key"):
			label_text = I18n.t(str(definition["label_key"]))
		if label_text != "":
			var label := Label.new()
			label.text = label_text
			label.add_theme_font_size_override("font_size", 34)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
			label.add_theme_constant_override("outline_size", 6)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bin.add_child(label)

		var bin_id := str(definition.get("id", ""))
		bin.gui_input.connect(_on_bin_input.bind(bin_id))
		_play_area.add_child(bin)
		_bins.append({"id": bin_id, "node": bin})


func _load_pool(config: Dictionary) -> void:
	_item_pool = (config.get("items", []) as Array).duplicate()
	if bool(config.get("shuffle", true)):
		_item_pool.shuffle()
	_pool_index = 0


# --- item lifecycle -----------------------------------------------------

func _next_item() -> void:
	if _item_pool.is_empty():
		return
	# The pool loops so a short list can serve a longer target.
	if _pool_index >= _item_pool.size():
		_item_pool.shuffle()
		_pool_index = 0

	var definition: Dictionary = _item_pool[_pool_index]
	_pool_index += 1
	_item_answer = str(definition.get("bin", ""))
	_item = _build_item(definition)
	_play_area.add_child(_item)

	# Drop in gently rather than appearing, so the eye follows it.
	_item.scale = Vector2(0.6, 0.6)
	_item.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_item, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	t.tween_property(_item, "modulate:a", 1.0, 0.18)


func _build_item(definition: Dictionary) -> Control:
	var item := Panel.new()
	item.custom_minimum_size = ITEM_SIZE
	item.size = ITEM_SIZE
	item.position = ITEM_HOME - ITEM_SIZE / 2.0
	item.pivot_offset = ITEM_SIZE / 2.0
	item.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.set_corner_radius_all(24)
	style.border_width_bottom = 6
	style.border_color = Color(0, 0, 0, 0.12)
	item.add_theme_stylebox_override("panel", style)

	match str(definition.get("render", "shape")):
		"dots":
			item.add_child(_render_dots(int(definition.get("count", 1))))
		"label":
			item.add_child(_render_label(definition))
		_:
			item.add_child(_render_shape(definition))

	item.gui_input.connect(_on_item_input)
	return item


## A cluster of dots the child counts. Laid out in rows of three so the shape
## itself does not give the answer away.
func _render_dots(count: int) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var columns := 3
	var rows: int = ceili(float(count) / float(columns))
	var spacing := 38.0
	for i in range(count):
		var dot := Panel.new()
		var radius := 26.0
		dot.size = Vector2(radius, radius)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.24, 0.42, 0.78)
		style.set_corner_radius_all(int(radius / 2.0))
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var row: int = i / columns
		var column: int = i % columns
		var in_row: int = mini(columns, count - row * columns)
		var x: float = ITEM_SIZE.x / 2.0 + (column - (in_row - 1) / 2.0) * spacing - radius / 2.0
		var y: float = ITEM_SIZE.y / 2.0 + (row - (rows - 1) / 2.0) * spacing - radius / 2.0
		dot.position = Vector2(x, y)
		holder.add_child(dot)
	return holder


func _render_label(definition: Dictionary) -> Control:
	var label := Label.new()
	var key := str(definition.get("text_key", ""))
	label.text = I18n.t(key) if key != "" else str(definition.get("text", "?"))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", UiKit.TEXT_DARK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _render_shape(definition: Dictionary) -> Control:
	var color := Color.from_string(str(definition.get("color", "#e04b4b")), Color.RED)
	var shape := str(definition.get("shape", "circle"))
	var centre := ITEM_SIZE / 2.0
	var radius := 48.0

	var polygon := Polygon2D.new()
	polygon.color = color
	var points := PackedVector2Array()
	match shape:
		"square":
			points = PackedVector2Array([
				centre + Vector2(-radius, -radius), centre + Vector2(radius, -radius),
				centre + Vector2(radius, radius), centre + Vector2(-radius, radius),
			])
		"triangle":
			points = PackedVector2Array([
				centre + Vector2(0, -radius),
				centre + Vector2(radius, radius * 0.8),
				centre + Vector2(-radius, radius * 0.8),
			])
		"star":
			for i in range(10):
				var a: float = -PI / 2.0 + TAU * float(i) / 10.0
				var r: float = radius if i % 2 == 0 else radius * 0.45
				points.append(centre + Vector2(cos(a), sin(a)) * r)
		_:
			for i in range(24):
				var a: float = TAU * float(i) / 24.0
				points.append(centre + Vector2(cos(a), sin(a)) * radius)
	polygon.polygon = points

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(polygon)
	return holder


# --- input --------------------------------------------------------------

func _on_item_input(event: InputEvent) -> void:
	if _resolving or _item == null:
		return
	var pressed := (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_dragging = true
		_press_position = _play_area.get_global_mouse_position()
		_drag_offset = _item.global_position - _press_position
		_item.scale = Vector2(1.1, 1.1)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var released := (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if released:
		_end_drag()


func _process(delta: float) -> void:
	super._process(delta)
	if _dragging and _item != null:
		_item.global_position = _play_area.get_global_mouse_position() + _drag_offset


func _end_drag() -> void:
	_dragging = false
	if _item == null:
		return
	_item.scale = Vector2.ONE

	var travelled := _play_area.get_global_mouse_position().distance_to(_press_position)
	if travelled < TAP_THRESHOLD:
		# Barely moved: treat as "I have picked this up", not as an answer.
		_select_item()
		_return_item_home()
		return

	var bin_id := _bin_under_item()
	if bin_id == "":
		_return_item_home()
		return
	_resolve(bin_id)


func _on_bin_input(event: InputEvent, bin_id: String) -> void:
	if _resolving or _item == null or not _selected:
		return
	var pressed := (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_resolve(bin_id)


func _select_item() -> void:
	_selected = true
	_item.modulate = Color(1.08, 1.08, 1.0)


func _bin_under_item() -> String:
	var centre := _item.global_position + ITEM_SIZE / 2.0
	for bin in _bins:
		var node: Control = bin["node"]
		if node.get_global_rect().has_point(centre):
			return str(bin["id"])
	return ""


# --- answering ----------------------------------------------------------

func _resolve(bin_id: String) -> void:
	if _resolving:
		return
	_resolving = true
	_selected = false
	if bin_id == _item_answer:
		_accept()
	else:
		_reject()


func _accept() -> void:
	var target := _bin_node(_item_answer)
	var destination: Vector2 = target.global_position + BIN_SIZE / 2.0 - ITEM_SIZE / 2.0 \
		if target != null else _item.global_position

	AudioManager.play_voice("res://assets/audio/voice/level/well_done.ogg")
	var t := create_tween().set_parallel(true)
	t.tween_property(_item, "global_position", destination, 0.25).set_trans(Tween.TRANS_SINE)
	t.tween_property(_item, "scale", Vector2(0.35, 0.35), 0.25)
	t.tween_property(_item, "modulate:a", 0.0, 0.25)
	await t.finished

	if _item != null:
		_item.queue_free()
		_item = null

	score_correct()
	_update_progress()
	_resolving = false
	# score_correct may have completed the level; do not queue another item.
	if not _is_finished():
		_next_item()


func _reject() -> void:
	_instruction.text = I18n.t("sorting.not_there")
	AudioManager.play_voice("res://assets/audio/voice/level/try_again.ogg")
	_shake_item()
	score_mistake()
	await _return_item_home()
	_resolving = false


## Wrong answers put the item back and let the child try again with the same
## item. Nothing is removed, nothing is lost.
func _return_item_home() -> Signal:
	var home := ITEM_HOME - ITEM_SIZE / 2.0
	var t := create_tween()
	t.tween_property(_item, "position", home, 0.22).set_trans(Tween.TRANS_SINE)
	return t.finished


func _shake_item() -> void:
	if _item == null:
		return
	var origin := _item.position
	var t := create_tween()
	t.tween_property(_item, "position", origin + Vector2(16, 0), 0.06)
	t.tween_property(_item, "position", origin - Vector2(16, 0), 0.06)
	t.tween_property(_item, "position", origin, 0.06)


func _bin_node(bin_id: String) -> Control:
	for bin in _bins:
		if str(bin["id"]) == bin_id:
			return bin["node"]
	return null


func _is_finished() -> bool:
	return result.met_target()


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", 8)]
