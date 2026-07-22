extends Control
## Growth Island. Every world and level is drawn from data/levels.json --
## adding a level here means adding a JSON entry, never editing this file.

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Palette.MEADOW, "res://assets/backgrounds/map.png")

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 12)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title(I18n.t("map.title"), 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var stars := UiKit.title(I18n.t("map.stars") % SaveManager.total_stars(), 36)
	stars.custom_minimum_size = Vector2(220, 0)
	header.add_child(stars)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 24)
	scroll.add_child(list)

	var worlds: Array = GameData.worlds.duplicate()
	worlds.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	for world in worlds:
		list.add_child(_build_world_section(world))


func _build_world_section(world: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.from_string(world.get("color", "#888888"), Color.GRAY)
	style.bg_color.a = 0.28
	style.set_corner_radius_all(24)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	# Header: world name, and how many of this world's stars are collected.
	# Per-world progress rather than one global total, so a child can see which
	# island still has something left in it.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var name_label := UiKit.title(I18n.t(world.get("name_key", "")), 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var world_levels: Array = GameData.get_levels_for_world(world.get("id", ""))
	var earned := 0
	for level in world_levels:
		earned += int(SaveManager.get_level_progress(level.get("id", "")).get("stars", 0))
	var possible: int = world_levels.size() * 3

	header.add_child(UiKit.star(earned > 0, 34))
	var tally := UiKit.title("%d / %d" % [earned, possible], 30)
	tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tally)
	box.add_child(header)

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	box.add_child(row)

	for level in GameData.get_levels_for_world(world.get("id", "")):
		row.add_child(_build_level_button(level))

	return panel


func _build_level_button(level: Dictionary) -> Control:
	var level_id: String = level.get("id", "")
	var progress := SaveManager.get_level_progress(level_id)
	var unlocked := SaveManager.is_level_unlocked(level_id)
	var scene_path := GameData.get_minigame_scene(level.get("game_type", ""))
	var implemented := scene_path != "" and ResourceLoader.exists(scene_path)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var label := I18n.t(level.get("name_key", ""))
	if not implemented:
		label += "\n(" + I18n.t("common.coming_soon") + ")"
	elif not unlocked:
		label += "\n(" + I18n.t("common.locked") + ")"

	var color: Color = Palette.BLUE if implemented and unlocked else Palette.MUTED

	# The picture tells a pre-reader what kind of game this is before they can
	# read its name: a car for crossing, sorting shapes, a spark for collecting.
	var icons := {
		"traffic_crossing": "car",
		"item_sorting": "sort",
		"collect_energy": "spark",
		"animal_rescue": "paw",
	}
	var icon_name: String = str(icons.get(level.get("game_type", ""), ""))
	var button := UiKit.icon_button(label, icon_name, color, Vector2(300, 200))
	button.add_theme_font_size_override("font_size", 26)
	button.disabled = not (implemented and unlocked)
	if not button.disabled:
		button.pressed.connect(func(): GameManager.start_level(level_id))
	column.add_child(button)

	column.add_child(UiKit.star_row(int(progress.get("stars", 0)), 3, 40))
	return column
