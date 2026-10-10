extends "res://scripts/garden/panels/farm_panel_base.gd"
## The farm's compact tool shelf and its on-demand full rack.
##
## FarmToolController remains the only source of tool meaning and availability;
## this panel only lays out its buttons and asks GardenScreen to select one.

const Tools := preload("res://scripts/garden/farm_tool_controller.gd")

const TOOL_SIZE := Vector2(72.0, 60.0)
const TOOL_STEP := 80.0
const QUICK_TOOL_LIMIT := 3
const QUICK_TOOL_START := Vector2(16.0, 0.0)
const MORE_AT := Vector2(256.0, 0.0)
const DRAWER_SIZE := Vector2(336.0, 152.0)
const DRAWER_GRID_AT := Vector2(12.0, 12.0)
const DRAWER_GRID_SIZE := Vector2(312.0, 128.0)
const DRAWER_COLUMNS := 4
const DRAWER_X_STEP := 80.0
const DRAWER_Y_STEP := 68.0


func build(view: Vector2, shelf_height: float) -> void:
	screen.call("_auto_return")
	var tool_controller: Variant = screen.get("_tools")
	var plots: Array = screen.call("_plots")
	var expanded := bool(screen.get("_tool_rack_expanded"))
	var quick_ids := _quick_tool_ids(tool_controller, plots)

	var drawer_grid: GridContainer
	if expanded:
		var row_y: float = view.y - shelf_height + 6.0
		var drawer := Panel.new()
		drawer.name = "GardenToolDrawer"
		drawer.position = Vector2(12.0, row_y - DRAWER_SIZE.y - 10.0)
		drawer.custom_minimum_size = DRAWER_SIZE
		drawer.size = DRAWER_SIZE
		drawer.mouse_filter = Control.MOUSE_FILTER_STOP
		drawer.add_theme_stylebox_override("panel", screen.call(
			"_quiet_surface_style", Color(0.97, 0.93, 0.83), 20,
			Color(0.68, 0.49, 0.23, 0.50), 1, 10))
		play.add_child(drawer)
		drawer_grid = GridContainer.new()
		drawer_grid.name = "GardenToolDrawerGrid"
		drawer_grid.columns = DRAWER_COLUMNS
		drawer_grid.add_theme_constant_override("h_separation", 8)
		drawer_grid.add_theme_constant_override("v_separation", 8)
		drawer_grid.position = DRAWER_GRID_AT
		drawer_grid.custom_minimum_size = DRAWER_GRID_SIZE
		drawer_grid.size = DRAWER_GRID_SIZE
		# PASS lets the grid's child buttons receive the press before it reaches
		# the blocking drawer background; IGNORE would skip the whole subtree.
		drawer_grid.mouse_filter = Control.MOUSE_FILTER_PASS
		drawer.add_child(drawer_grid)
		block_world(drawer)

	var buttons: Dictionary = screen.get("_tool_buttons")
	buttons.clear()
	var row_y := view.y - shelf_height + 6.0
	for index in range(Tools.TOOLS.size()):
		var tool: Dictionary = Tools.TOOLS[index]
		var tool_id := str(tool.get("id", ""))
		var button := _tool_button(tool, tool_controller, plots)
		buttons[tool_id] = button
		if expanded:
			var col := index % DRAWER_COLUMNS
			var row := int(index / DRAWER_COLUMNS)
			button.position = DRAWER_GRID_AT + Vector2(
				float(col) * DRAWER_X_STEP, float(row) * DRAWER_Y_STEP)
			drawer_grid.add_child(button)
		else:
			var quick_index := quick_ids.find(tool_id)
			button.visible = quick_index >= 0
			button.position = QUICK_TOOL_START + Vector2(
				float(maxi(quick_index, 0)) * TOOL_STEP, row_y)
			play.add_child(button)

	var more := _more_button(expanded)
	more.position = MORE_AT + Vector2(0.0, row_y)
	more.set_meta("quick_tool_ids", quick_ids.duplicate())
	more.pressed.connect(func():
		screen.set("_tool_rack_expanded", not expanded)
		screen.call("_queue_rebuild", 2))
	play.add_child(more)


func _quick_tool_ids(tool_controller: Variant, plots: Array) -> Array[String]:
	var quick: Array[String] = [Tools.HAND]
	var task: Dictionary = screen.call("_next_task")
	var task_tool := str(task.get("tool_id", ""))
	if task_tool != "" and task_tool != Tools.HAND \
			and _is_live(task_tool, tool_controller, plots):
		quick.append(task_tool)
	var selected := str(tool_controller.get("selected"))
	if selected != Tools.HAND and _is_live(selected, tool_controller, plots) \
			and not quick.has(selected):
		quick.append(selected)
	for entry in Tools.TOOLS:
		var tool_id := str(entry.get("id", ""))
		if tool_id == Tools.HAND or quick.has(tool_id):
			continue
		if _is_live(tool_id, tool_controller, plots):
			quick.append(tool_id)
		if quick.size() >= QUICK_TOOL_LIMIT:
			break
	return quick


func _is_live(tool_id: String, tool_controller: Variant, plots: Array) -> bool:
	return tool_id == Tools.HAND or bool(tool_controller.call(
		"work_exists", tool_id, plots))


func _tool_button(tool: Dictionary, tool_controller: Variant,
		plots: Array) -> Button:
	var tool_id := str(tool.get("id", ""))
	var live := _is_live(tool_id, tool_controller, plots)
	var held := str(tool_controller.get("selected")) == tool_id
	var button := Button.new()
	button.name = "GardenTool_%s" % tool_id
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = TOOL_SIZE
	button.size = TOOL_SIZE
	button.pivot_offset = TOOL_SIZE * 0.5
	var fill := Color(0.98, 0.94, 0.83) if live else Color(0.91, 0.88, 0.81)
	var edge := Color(0.48, 0.34, 0.14) if held \
		else Color(0.69, 0.52, 0.28, 0.42)
	var normal = screen.call("_tool_tile_style", fill, edge, held)
	var hover = screen.call("_tool_tile_style", fill.lightened(0.025),
		edge, held, not held)
	var pressed = screen.call("_tool_tile_style", fill.darkened(0.025),
		edge, held, not held)
	var disabled = screen.call("_tool_tile_style",
		Color(0.91, 0.88, 0.81), Color(0.69, 0.62, 0.48, 0.28), false)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", disabled)
	button.tooltip_text = I18n.t(tool_controller.label_key(tool_id))
	button.disabled = not live
	button.modulate = Color(1.0, 1.0, 1.0, 1.0 if live else 0.82)
	var art: Control = screen.call("_tool_picture", tool, 30.0)
	if art != null:
		art.name = "GardenToolIcon"
		art.position = Vector2(21.0, 2.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.modulate.a = 1.0 if live else 0.40
		button.add_child(art)
	var label := UiKit.title(I18n.t(tool_controller.label_key(tool_id)), 14,
		Color(0.30, 0.28, 0.24) if live else Color(0.58, 0.57, 0.54))
	label.name = "GardenToolLabel"
	label.position = Vector2(2.0, 34.0)
	label.size = Vector2(68.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.button_down.connect(func():
		if Juice.motion_enabled():
			var tween := button.create_tween()
			tween.tween_property(button, "scale", Vector2(0.90, 0.90), 0.06))
	button.button_up.connect(func():
		if Juice.motion_enabled():
			var tween := button.create_tween()
			tween.tween_property(button, "scale", Vector2.ONE, 0.10) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	button.pressed.connect(func():
		screen.call("_select_tool", tool_id))
	return button


func _more_button(expanded: bool) -> Button:
	var button := Button.new()
	button.name = "GardenToolsExpand"
	button.flat = false
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = TOOL_SIZE
	button.size = TOOL_SIZE
	var fill := Color(0.95, 0.90, 0.76) if expanded \
		else Color(0.98, 0.94, 0.83)
	var edge := Color(0.48, 0.34, 0.14) if expanded \
		else Color(0.69, 0.52, 0.28, 0.42)
	button.add_theme_stylebox_override("normal",
		screen.call("_tool_tile_style", fill, edge, expanded))
	button.add_theme_stylebox_override("hover",
		screen.call("_tool_tile_style", fill.lightened(0.025), edge,
			expanded, not expanded))
	button.add_theme_stylebox_override("pressed",
		screen.call("_tool_tile_style", fill.darkened(0.025), edge,
			expanded, not expanded))
	button.add_theme_stylebox_override("focus",
		screen.call("_tool_tile_style", fill, edge, expanded))
	var tooltip_key := "garden.tools_less" if expanded else "garden.tools_more"
	button.tooltip_text = I18n.t(tooltip_key)
	for i in range(4):
		var square := Panel.new()
		square.name = "GardenToolsGridSquare_%d" % i
		square.position = Vector2(25.0 + float(i % 2) * 12.0,
			5.0 + float(int(i / 2)) * 11.0)
		square.size = Vector2(9.0, 9.0)
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.42, 0.54, 0.31) if not expanded \
			else Color(0.48, 0.34, 0.14)
		style.set_corner_radius_all(2)
		square.add_theme_stylebox_override("panel", style)
		button.add_child(square)
	var label := UiKit.title(I18n.t(tooltip_key), 12, Palette.INK)
	label.name = "GardenToolsExpandLabel"
	label.position = Vector2(2.0, 34.0)
	label.size = Vector2(68.0, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button
