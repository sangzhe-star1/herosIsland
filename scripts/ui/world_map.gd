extends Control
## Growth Island: the island itself, with the levels standing on it.
##
## Every world and level is drawn from data/levels.json -- adding a level here
## means adding a JSON entry, never editing this file. The island grows a new
## marker, the path bends to include it, and the coastline stretches to fit.
##
## Why this is a map now and not a list: this is the only screen that shows a
## child the shape of the whole game. A stack of panels says "here are some
## categories". One island with a path running along it says "you started
## there, you are here, and the road keeps going" -- which is the entire
## motivation structure of a level-based game, delivered without a word.
##
## The screen opens scrolled to whichever level is next, so a child never has
## to go looking for their place.

const MARKER := 148.0

var _island: IslandMap
var _scroll: ScrollContainer
var _frontier_x := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	# Sea and sky behind the island, so the edges of the scroll never show a
	# bare background colour.
	UiKit.world_background(self, "island", "map")

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	var worlds: Array = GameData.worlds.duplicate()
	worlds.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	var levels_by_world := {}
	for world in worlds:
		levels_by_world[str(world.get("id", ""))] = GameData.get_levels_for_world(
			str(world.get("id", "")))

	_island = IslandMap.new()
	_island.build(worlds, levels_by_world)

	var canvas := Control.new()
	canvas.custom_minimum_size = _island.canvas_size()
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(_island)
	_scroll.add_child(canvas)

	for world in worlds:
		var levels: Array = levels_by_world.get(str(world.get("id", "")), [])
		_add_region_banner(canvas, world, levels)
		_add_markers(canvas, world, levels)

	_add_header()
	# Wait for layout before scrolling: the scroll bar has no range until the
	# canvas has been sized.
	call_deferred("_scroll_to_frontier")


## The header floats over the island rather than pushing it down, so the map
## keeps the full height of the screen.
func _add_header() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = 20
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)

	bar.add_child(UiKit.back_button(func(): SceneManager.goto_home()))

	var title := UiKit.title_on_art(I18n.t("map.title"), 48)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)

	var tally := UiKit.card(Color(1.0, 0.99, 0.96, 0.94))
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tally_row := HBoxContainer.new()
	tally_row.add_theme_constant_override("separation", 8)
	tally_row.add_child(UiKit.star(true, 38))
	var count := Label.new()
	count.text = str(SaveManager.total_stars())
	count.add_theme_font_size_override("font_size", 34)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tally_row.add_child(count)
	tally.add_child(tally_row)
	bar.add_child(tally)


## A world's name on a signpost planted in its own stretch of coast, with the
## stars still to be found there. Replaces the panel that used to wrap a whole
## world and, in doing so, cut it off from the rest of the island.
func _add_region_banner(canvas: Control, world: Dictionary, levels: Array) -> void:
	var world_id: String = str(world.get("id", ""))
	var tint := Color.from_string(str(world.get("color", "#888888")), Color.GRAY)
	var at: Vector2 = _island.region_centre(world_id)

	var earned := 0
	for level in levels:
		earned += int(SaveManager.get_level_progress(str(level.get("id", ""))).get("stars", 0))
	var possible: int = levels.size() * 3

	# A fixed-size holder. A PanelContainer dropped straight onto a plain
	# Control grows to the parent's size, and the parent here is the whole
	# island -- which is how the first version got signposts 720px tall.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(240, 116)
	holder.size = Vector2(240, 116)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sign_post := PanelContainer.new()
	sign_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := UiKit.panel_style(tint.lerp(Color(1.0, 0.99, 0.96), 0.72), 20)
	style.border_width_bottom = 6
	style.border_color = tint.darkened(0.25)
	style.set_content_margin_all(14)
	sign_post.add_theme_stylebox_override("panel", style)
	sign_post.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	sign_post.add_child(column)

	var name_label := Label.new()
	name_label.text = I18n.t(str(world.get("name_key", "")))
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiKit.star(earned > 0, 30))
	var tally := Label.new()
	tally.text = "%d / %d" % [earned, possible]
	tally.add_theme_font_size_override("font_size", 24)
	tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tally)
	column.add_child(row)

	holder.add_child(sign_post)
	canvas.add_child(holder)
	holder.position = at - Vector2(120, 130)


func _add_markers(canvas: Control, world: Dictionary, levels: Array) -> void:
	var world_id: String = str(world.get("id", ""))
	for i in range(levels.size()):
		var marker := _build_marker(levels[i], world_id, i)
		canvas.add_child(marker)
		marker.position = _island.node_position(world_id, i) \
			- Vector2((MARKER + 40.0) * 0.5, MARKER * 0.54)


## A level as a stone on the path: round, chunky, carrying the picture that
## says what kind of game it is, with its stars underneath. Round because
## everything else a child taps in this game is a slab -- the map should not
## feel like another menu.
func _build_marker(level: Dictionary, world_id: String, index: int) -> Control:
	var level_id: String = str(level.get("id", ""))
	var progress: Dictionary = SaveManager.get_level_progress(level_id)
	var unlocked: bool = SaveManager.is_level_unlocked(level_id)
	var scene_path: String = GameData.get_minigame_scene(str(level.get("game_type", "")))
	var implemented: bool = scene_path != "" and ResourceLoader.exists(scene_path)
	var playable: bool = implemented and unlocked
	var completed: bool = bool(progress.get("completed", false))
	var challenge: bool = bool(level.get("challenge", false))

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(MARKER + 40.0, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)

	var icons := {
		"traffic_crossing": "car", "item_sorting": "sort", "collect_energy": "spark",
		"animal_rescue": "paw", "monster_battle": "monster", "memory_match": "blocks",
		"light_echo": "sound_on", "monster_duel": "shield",
	}
	var icon_name: String = str(icons.get(str(level.get("game_type", "")), "flag"))
	var face: Color = Palette.BLUE
	if challenge:
		icon_name = "star"
		face = Palette.ORANGE
	if completed:
		face = Palette.GREEN
	if not playable:
		icon_name = "lock"
		face = Palette.MUTED

	var button := _stone_button(icon_name, face, playable)
	if playable:
		button.pressed.connect(func(): GameManager.start_level(level_id))
		if not completed:
			# The frontier -- playable but not yet cleared -- breathes gently:
			# "this one is next". One per world, so the screen never pulses.
			UiKit.breathe(button, 0.035, 1.0)
			if _frontier_x <= 0.0:
				_frontier_x = _island.node_position(world_id, index).x
	column.add_child(button)

	var label := Label.new()
	label.text = I18n.t(str(level.get("name_key", "")))
	if challenge:
		var rank: int = SaveManager.get_challenge_rank(level_id)
		if rank > 0:
			label.text += "  %d" % (rank + 1)
	if not implemented:
		label.text = I18n.t("common.coming_soon")
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Palette.ON_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.14, 0.10, 0.85))
	label.add_theme_constant_override("outline_size", 7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(MARKER + 40.0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)

	var stars := UiKit.star_row(int(progress.get("stars", 0)), 3, 28)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stars)
	return column


func _stone_button(icon_name: String, face: Color, playable: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(MARKER, MARKER)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not playable

	# A raised disc with the same "thick bottom edge that squashes on press"
	# physics as every other button in the game, so a child who has learned how
	# one button behaves already knows how this one behaves.
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.set_corner_radius_all(int(MARKER * 0.5))
	normal.border_width_bottom = 9
	normal.border_width_left = 5
	normal.border_width_right = 5
	normal.border_width_top = 5
	normal.border_color = Palette.edge(face)
	normal.shadow_color = Color(0.0, 0.08, 0.20, 0.28)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 6)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = face.darkened(0.06)
	pressed.border_width_bottom = 3
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Palette.lift(face)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Palette.MUTED
	disabled.border_color = Palette.edge(Palette.MUTED)
	disabled.shadow_size = 4

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)

	var icon: Control = UiKit.picture(icon_name, MARKER * 0.56)
	if icon != null:
		icon.position = Vector2(MARKER * 0.22, MARKER * 0.20)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	if playable:
		b.pressed.connect(func(): Juice.pop(b, 0.08))
	return b


## Open where the child left off. Without this the map always starts at the
## first island, and a child several worlds in has to swipe past everything
## they have already finished to reach the level they actually want.
func _scroll_to_frontier() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	if _frontier_x <= 0.0:
		return
	var target: int = int(maxf(_frontier_x - 560.0, 0.0))
	if not Juice.motion_enabled():
		_scroll.scroll_horizontal = target
		return
	var t := create_tween()
	t.tween_property(_scroll, "scroll_horizontal", target, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
