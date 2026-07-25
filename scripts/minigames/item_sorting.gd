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
var _bin_counts: Dictionary = {}   # bin id -> items sorted into it this level
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

	build_world(_play_area, 0.55)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "sorting.instruction")))
	_instruction.add_theme_font_size_override("font_size", 38)
	_instruction.add_theme_color_override("font_color", Palette.INK)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 40)
	_instruction.size = Vector2(600, 60)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.INK)
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
		# A bin can carry an icon too, which is what lets a pre-reader tell
		# "safe" from "dangerous" without decoding either word.
		var bin_icon_name: String = str(definition.get("icon", ""))
		var bin_icon: Control = null
		if bin_icon_name != "":
			bin_icon = UiKit.picture(bin_icon_name, BIN_SIZE.x * 0.44)
		if bin_icon != null:
			bin_icon.position = Vector2(BIN_SIZE.x * 0.28, BIN_SIZE.y * 0.10)
			bin.add_child(bin_icon)

		if label_text != "":
			var label := Label.new()
			label.text = label_text
			label.add_theme_font_size_override("font_size", 30 if bin_icon != null else 34)
			label.add_theme_color_override("font_color", Color.WHITE)
			UiKit.on_art(label)
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
			label.add_theme_constant_override("outline_size", 6)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if bin_icon != null:
				label.position = Vector2(0, BIN_SIZE.y * 0.62)
				label.size = Vector2(BIN_SIZE.x, BIN_SIZE.y * 0.30)
			else:
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
	style.bg_color = Palette.SURFACE
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


## Picture first, word underneath.
##
## The icon is what makes these levels playable by a child who cannot read; the
## caption rides along so the word is learned by association rather than being
## required. If no icon exists for the item, the word fills the card on its own
## and nothing breaks.
func _render_label(definition: Dictionary) -> Control:
	var key: String = str(definition.get("text_key", ""))
	var caption: String = I18n.t(key) if key != "" else str(definition.get("text", "?"))

	# "item.teddy" -> "teddy". An explicit "icon" field overrides the guess.
	var icon_name: String = str(definition.get("icon", ""))
	if icon_name == "" and key.begins_with("item."):
		icon_name = key.substr(5)

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: Control = UiKit.picture(icon_name, ITEM_SIZE.x * 0.62)

	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 22 if icon != null else 30)
	label.add_theme_color_override("font_color", Palette.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if icon == null:
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(label)
		return holder

	icon.position = Vector2(ITEM_SIZE.x * 0.19, ITEM_SIZE.y * 0.08)
	holder.add_child(icon)

	label.position = Vector2(0, ITEM_SIZE.y * 0.70)
	label.size = Vector2(ITEM_SIZE.x, ITEM_SIZE.y * 0.26)
	holder.add_child(label)
	return holder


func _render_shape(definition: Dictionary) -> Control:
	var color := Color.from_string(str(definition.get("color", "#e04b4b")), Color.RED)
	var shape := str(definition.get("shape", "circle"))
	var centre := ITEM_SIZE / 2.0
	var radius := 48.0

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Drawn through Shapes so a colour-sorting square is made of the same
	# material as a tree, a button and a hero: rounded corners, one outline
	# colour, lit from the same direction as everything else on screen.
	var points := PackedVector2Array()
	match shape:
		"square":
			points = Shapes.rounded_rect(centre - Vector2(radius, radius),
				Vector2(radius * 2.0, radius * 2.0), radius * 0.28)
		"triangle":
			points = PackedVector2Array([
				centre + Vector2(0, -radius * 1.05),
				centre + Vector2(radius, radius * 0.78),
				centre + Vector2(-radius, radius * 0.78),
			])
		"star":
			points = Shapes.star_points(centre, radius * 1.05, 0.46, 5)
		"circle", _:
			points = Shapes.circle_points(centre, radius)
	Shapes.lit(holder, points, color, 1.0)
	return holder


# --- input --------------------------------------------------------------

func _on_item_input(event: InputEvent) -> void:
	if _resolving or _item == null:
		return
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		_dragging = true
		_press_position = _play_area.get_global_mouse_position()
		_drag_offset = _item.global_position - _press_position
		_item.scale = Vector2(1.1, 1.1)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var released: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
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
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
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
	if target != null:
		Juice.burst(_play_area, target.position + BIN_SIZE / 2.0)
		Juice.pop(target)
		_bump_bin_count(_item_answer, target)
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
	Juice.nudge(_item)


## A little counter chip on the bin that ticks up as it gets fed -- the bin
## visibly "collects", which at six is half the pleasure of sorting.
func _bump_bin_count(bin_id: String, bin: Control) -> void:
	_bin_counts[bin_id] = int(_bin_counts.get(bin_id, 0)) + 1
	var chip: Label = bin.get_node_or_null("count_chip")
	if chip == null:
		chip = Label.new()
		chip.name = "count_chip"
		chip.add_theme_font_size_override("font_size", 24)
		chip.add_theme_color_override("font_color", Color.WHITE)
		UiKit.on_art(chip)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.13, 0.26, 0.85)
		style.set_corner_radius_all(19)
		chip.add_theme_stylebox_override("normal", style)
		chip.size = Vector2(38, 38)
		chip.position = Vector2(BIN_SIZE.x - 26, -12)
		chip.pivot_offset = chip.size / 2.0
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bin.add_child(chip)
	chip.text = str(_bin_counts[bin_id])
	Juice.pop(chip, 0.35)


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
