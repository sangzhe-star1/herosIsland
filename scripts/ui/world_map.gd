extends Control
## Growth Island. Every world and level is drawn from data/levels.json --
## adding a level here means adding a JSON entry, never editing this file.
##
## Styled the way the good children's apps do it (BabyBus, Toca Boca, Khan
## Kids): the scene art carries the mood, the chrome sits on top as bright
## rounded cards with white outlined text, a padlock BADGE marks locked
## levels instead of a word, and progress is a bar that fills plus stars to
## collect -- everything readable with zero reading.

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Palette.MEADOW, "res://assets/backgrounds/map.png")

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 12)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title_on_art(I18n.t("map.title"), 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var stars := UiKit.title_on_art(I18n.t("map.stars") % SaveManager.total_stars(), 36)
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
	var section_index := 0
	for world in worlds:
		var section := _build_world_section(world)
		list.add_child(section)
		# Islands drift in one after another instead of appearing as a wall.
		if Juice.motion_enabled():
			section.modulate.a = 0.0
			var t := section.create_tween()
			t.tween_interval(0.07 * float(section_index))
			t.tween_property(section, "modulate:a", 1.0, 0.25)
		section_index += 1


func _build_world_section(world: Dictionary) -> Control:
	var world_color := Color.from_string(world.get("color", "#888888"), Color.GRAY)

	var panel := PanelContainer.new()
	# The bundle's navy panel, tinted faintly toward the world's colour so the
	# five islands stay tellable-apart at a glance. Flat translucent fallback.
	var style: StyleBox = UiKit.texture_style(
		"res://assets/ui/panel.png", 46.0, 22.0, world_color.lerp(Color.WHITE, 0.55))
	if style == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = world_color
		flat.bg_color.a = 0.28
		flat.set_corner_radius_all(24)
		flat.set_content_margin_all(20)
		style = flat
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	# Header: world name, per-world star tally, and a progress bar that fills
	# as stars are earned -- which island still has treasure left in it is
	# visible from across the room.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var name_label := UiKit.title_on_art(I18n.t(world.get("name_key", "")), 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var world_levels: Array = GameData.get_levels_for_world(world.get("id", ""))
	var earned := 0
	for level in world_levels:
		earned += int(SaveManager.get_level_progress(level.get("id", "")).get("stars", 0))
	var possible: int = world_levels.size() * 3

	header.add_child(UiKit.star(earned > 0, 40))
	var tally := UiKit.title_on_art("%d / %d" % [earned, possible], 30)
	tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tally)
	box.add_child(header)

	box.add_child(_progress_bar(earned, possible))

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	box.add_child(row)

	for level in world_levels:
		row.add_child(_build_level_button(level))

	# When every arena monster has been befriended, they come back to wave
	# from the panel header -- the reward for finishing a world is getting to
	# SEE that its story ended happily.
	if str(world.get("id", "")) == "monster_arena":
		_maybe_add_parade(header, world_levels)

	return panel


func _maybe_add_parade(header: HBoxContainer, world_levels: Array) -> void:
	for level in world_levels:
		if not SaveManager.get_level_progress(str(level.get("id", ""))).get("completed", false):
			return
	var monsters := [
		{"id": "rocky", "body_color": "#d98a4a", "belly_color": "#f2c489", "accent_color": "#a8632f",
			"height": 300, "width": 0.85, "horns": 1, "eyes": 2, "spikes": 0},
		{"id": "blobbi", "body_color": "#7ec66a", "belly_color": "#b9e6a5", "accent_color": "#4f9e4a",
			"height": 270, "width": 0.95, "horns": 0, "eyes": 3, "spikes": 0},
		{"id": "spikelor", "body_color": "#8a5fc9", "belly_color": "#c9aef2", "accent_color": "#5e3f96",
			"height": 330, "width": 0.88, "horns": 2, "eyes": 2, "spikes": 5},
	]
	for config in monsters:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(64, 76)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var monster: Node2D = preload("res://scripts/battle/monster.gd").new()
		monster.position = Vector2(32, 74)
		monster.scale = Vector2.ONE * (66.0 / float(config["height"]))
		holder.add_child(monster)
		monster.build(config)
		header.add_child(holder)


## The bundle's progress frame and fill as a real bar; plain styleboxes when
## the art is missing. Godot draws the fill inside the background's content
## margins, so the frame's border width doubles as the fill inset.
func _progress_bar(earned: int, possible: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(float(possible), 1.0)
	bar.value = float(earned)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 30)

	var frame: StyleBox = UiKit.texture_style("res://assets/ui/progress_frame.png", 24.0, 7.0)
	var fill: StyleBox = UiKit.texture_style("res://assets/ui/progress_fill.png", 18.0, 0.0)
	if frame == null or fill == null:
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.08, 0.12, 0.22, 0.55)
		back.set_corner_radius_all(15)
		back.set_content_margin_all(5)
		frame = back
		var flat_fill := StyleBoxFlat.new()
		flat_fill.bg_color = Palette.STAR_ON
		flat_fill.set_corner_radius_all(10)
		fill = flat_fill
	bar.add_theme_stylebox_override("background", frame)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _build_level_button(level: Dictionary) -> Control:
	var level_id: String = level.get("id", "")
	var progress := SaveManager.get_level_progress(level_id)
	var unlocked := SaveManager.is_level_unlocked(level_id)
	var scene_path := GameData.get_minigame_scene(level.get("game_type", ""))
	var implemented := scene_path != "" and ResourceLoader.exists(scene_path)
	var playable := implemented and unlocked

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)

	var label := I18n.t(level.get("name_key", ""))
	if not implemented:
		label += "\n(" + I18n.t("common.coming_soon") + ")"

	# The picture tells a pre-reader what kind of game this is before they can
	# read its name -- and a padlock, not a word, says "not yet".
	var icons := {
		"traffic_crossing": "car",
		"item_sorting": "sort",
		"collect_energy": "spark",
		"animal_rescue": "paw",
		"monster_battle": "monster",
		"memory_match": "blocks",
		"light_echo": "sound_on",
		"monster_duel": "shield",
	}
	var icon_name: String = str(icons.get(level.get("game_type", ""), ""))
	var challenge := bool(level.get("challenge", false))
	if challenge:
		# Challenges wear the gold star and show their rank: this is the
		# level that grows every time it is beaten.
		icon_name = "star"
		var rank := SaveManager.get_challenge_rank(level_id)
		if rank > 0:
			label += "  %d" % (rank + 1)
	if not playable:
		icon_name = "lock"

	var button := _card_button(label, icon_name, playable)
	if challenge and playable:
		button.modulate = Color(1.10, 1.04, 0.86)
	if playable:
		button.pressed.connect(func(): GameManager.start_level(level_id))
		# The frontier level -- playable but not yet cleared -- breathes
		# gently: "this one is next". At most a couple per screen, since
		# each world has a single frontier.
		if not progress.get("completed", false):
			UiKit.breathe(button, 0.025, 1.1)
	column.add_child(button)

	column.add_child(UiKit.star_row(int(progress.get("stars", 0)), 3, 40))
	return column


## A level as one of the bundle's navy spotlight cards: icon badge on top,
## white name beneath, the card itself the touch target. Falls back to the
## drawn chunky button when the card art is missing.
func _card_button(text: String, icon_name: String, playable: bool) -> Button:
	var box := Vector2(300, 200)
	var normal: StyleBoxTexture = UiKit.texture_style("res://assets/ui/level_card.png", 40.0, 16.0)
	if normal == null:
		var fallback := UiKit.icon_button(text, icon_name,
			Palette.BLUE if playable else Palette.MUTED, box)
		fallback.add_theme_font_size_override("font_size", 26)
		fallback.disabled = not playable
		return fallback

	var button := Button.new()
	button.text = text
	button.custom_minimum_size = box
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not playable
	button.add_theme_font_size_override("font_size", 26)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Palette.ON_COLOR)
	button.add_theme_color_override("font_disabled_color", Color(0.75, 0.78, 0.88, 0.9))
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.7))
	button.add_theme_constant_override("outline_size", 6)

	# Playable cards glow brighter than the panel; locked ones sink well below
	# it. The gap between the two is the affordance -- a pre-reader picks the
	# pressable card by brightness alone, before the lock badge even registers.
	normal.modulate_color = Color(1.35, 1.32, 1.28)
	var hover: StyleBoxTexture = UiKit.texture_style("res://assets/ui/level_card.png", 40.0, 16.0,
		Color(1.55, 1.5, 1.42))
	var pressed: StyleBoxTexture = UiKit.texture_style("res://assets/ui/level_card.png", 40.0, 16.0,
		Color(1.1, 1.08, 1.05))
	var disabled: StyleBoxTexture = UiKit.texture_style("res://assets/ui/level_card.png", 40.0, 16.0,
		Color(0.42, 0.44, 0.54, 0.85))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

	# Icon badge above, label pushed to the card's lower band.
	var icon: Control = UiKit.picture(icon_name, box.x * 0.36)
	if icon != null:
		icon.position = Vector2(box.x * 0.32, box.y * 0.10)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not playable:
			icon.modulate = Color(1, 1, 1, 0.85)
		button.add_child(icon)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := button.get_theme_stylebox(state)
			if style is StyleBoxTexture:
				(style as StyleBoxTexture).content_margin_top = box.y * 0.62
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return button
