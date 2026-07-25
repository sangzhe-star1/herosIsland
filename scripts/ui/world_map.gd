extends Control
## Growth Island, one world per page.
##
## The first map was one continuous island in a free-scrolling strip. Watching
## a six-year-old use it settled the argument: he slid, overshot, slid back,
## and could not tell where one world ended and the next began. So the strip
## is gone. Each world is now its OWN island on its own page, the page fits
## the screen exactly, and moving between islands is one tap on a big arrow
## (or a swipe) -- a page turn, not a scroll. Discrete beats continuous at
## six, every time.
##
## Every island and level is still drawn from data/levels.json: adding a level
## grows that world's path; adding a world adds a page and a dot. Nothing here
## is hand-placed.

const MARKER := 148.0
const PAGE_W := 1280.0
const SWIPE := 90.0            # finger travel that counts as a page turn

var _worlds: Array = []
var _strip: Control            # all pages side by side; slides one page at a time
var _pages: Array = []
var _dots: Array = []
var _left_arrow: Button
var _right_arrow: Button
var _page := 0
var _frontier_page := -1
var _drag_from := Vector2(-1, -1)


func _ready() -> void:
	theme = UiKit.theme()
	# Sea behind everything: the gap that shows for a moment mid page-turn is
	# water between islands, which is exactly what it should be.
	UiKit.world_background(self, "island", "map")

	_worlds = GameData.worlds.duplicate()
	_worlds.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip.size = Vector2(PAGE_W * _worlds.size(), 720)
	add_child(_strip)

	for wi in range(_worlds.size()):
		var world: Dictionary = _worlds[wi]
		var world_id: String = str(world.get("id", ""))
		var levels: Array = GameData.get_levels_for_world(world_id)

		var page := Control.new()
		page.mouse_filter = Control.MOUSE_FILTER_PASS
		page.position = Vector2(PAGE_W * float(wi), 0)
		page.size = Vector2(PAGE_W, 720)
		_strip.add_child(page)
		_pages.append(page)

		var island := IslandMap.new()
		island.build([world], {world_id: levels}, true)
		page.add_child(island)

		_add_region_banner(page, island, world, levels)
		_add_markers(page, island, world, levels, wi)

	_add_header()
	_add_arrows()
	_add_dots()

	# Open on the island where the child actually is: the first page holding a
	# playable level that is not yet finished.
	_page = maxi(_frontier_page, 0)
	_strip.position.x = -PAGE_W * float(_page)
	_refresh_paging()


# --- chrome ---------------------------------------------------------------

## The header floats over the island rather than pushing it down.
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


## One big arrow on each edge. Mid-height, round, and colour-ringed like the
## trail's control pad -- the same button language everywhere.
func _add_arrows() -> void:
	_left_arrow = _arrow_button(false)
	_left_arrow.position = Vector2(16, 296)
	add_child(_left_arrow)
	_right_arrow = _arrow_button(true)
	_right_arrow.position = Vector2(PAGE_W - 16.0 - 112.0, 296)
	add_child(_right_arrow)


func _arrow_button(forward: bool) -> Button:
	var b := Button.new()
	var size := 112.0
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.15, 0.30, 0.90)
	style.set_corner_radius_all(int(size / 2.0))
	style.border_width_bottom = 6
	style.border_width_top = 5
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_color = Color(1.0, 0.86, 0.40)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, style)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var c := Vector2(size, size) / 2.0
	var r: float = size * 0.23
	var dir: float = 1.0 if forward else -1.0
	Shapes.fill(icon, PackedVector2Array([
		c + Vector2(-dir * r * 0.7, -r), c + Vector2(-dir * r * 0.7, r),
		c + Vector2(dir * r * 1.1, 0),
	]), Color(1.0, 0.94, 0.62), 0.0)
	b.pivot_offset = Vector2(size, size) / 2.0
	b.pressed.connect(func():
		Juice.pop(b, 0.10)
		_go_page(_page + (1 if forward else -1))
	)
	return b


## One dot per island along the bottom: filled and world-coloured where you
## are, hollow elsewhere. The whole game's shape in a row of dots.
func _add_dots() -> void:
	# Up in the sky under the title, where no island content ever reaches --
	# at the bottom they sat exactly on the second row's star rows.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.offset_top = 96
	row.offset_bottom = 126
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above the weather. The island's clouds are drawn at exactly this height
	# and were painting straight over the dots -- with five worlds, two of
	# the five were behind a cloud and the map looked like it had three.
	row.z_index = 20
	add_child(row)
	for world in _worlds:
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var draw := Node2D.new()
		dot.add_child(draw)
		var tint := Color.from_string(str(world.get("color", "#888888")), Color.GRAY)
		# A dark collar round every dot. Tinted fill alone disappeared against
		# the white clouds that sit at exactly this height, and with five
		# worlds three of the five were simply not there.
		Shapes.fill(draw, Shapes.circle_points(Vector2(13, 13), 13.0, 18),
			Color(0.05, 0.12, 0.26, 0.75), 0.0)
		Shapes.fill(draw, Shapes.circle_points(Vector2(13, 13), 10.0, 16), tint, 0.0)
		dot.set_meta("tint", tint)
		row.add_child(dot)
		_dots.append(dot)


func _refresh_paging() -> void:
	if _left_arrow != null:
		_left_arrow.visible = _page > 0
	if _right_arrow != null:
		_right_arrow.visible = _page < _worlds.size() - 1
	for i in range(_dots.size()):
		var dot: Control = _dots[i]
		# Even an "off" dot has to be findable: this is the only thing on
		# screen that says how many islands there are.
		dot.modulate = Color(1, 1, 1, 1.0) if i == _page else Color(1, 1, 1, 0.7)
		dot.scale = Vector2(1.25, 1.25) if i == _page else Vector2.ONE


func _go_page(index: int) -> void:
	var target: int = clampi(index, 0, _worlds.size() - 1)
	if target == _page:
		return
	_page = target
	_refresh_paging()
	if not Juice.motion_enabled():
		_strip.position.x = -PAGE_W * float(_page)
		return
	var t := create_tween()
	t.tween_property(_strip, "position:x", -PAGE_W * float(_page), 0.42)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Swipes: anywhere a marker or button does not swallow the touch, a sideways
## drag of a finger-width turns the page. The arrows remain the primary way --
## this is for the child who tries the gesture the tablet taught them.
func _gui_input(event: InputEvent) -> void:
	# One press, one release, through the shared rule -- the hand-rolled
	# version handled mouse AND touch, and with touch emulation on that made
	# every drag turn two pages.
	if UiKit.is_press(event):
		_drag_from = _event_position(event)
	elif UiKit.is_release(event) and _drag_from.x >= 0.0:
		var dx: float = _event_position(event).x - _drag_from.x
		_drag_from = Vector2(-1, -1)
		if absf(dx) >= SWIPE:
			_go_page(_page + (1 if dx < 0.0 else -1))


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2.ZERO


# --- the island's contents --------------------------------------------------

## The world's name on a signpost at the top of its island, with the stars
## still to be found there.
func _add_region_banner(page: Control, island: IslandMap, world: Dictionary,
		levels: Array) -> void:
	var world_id: String = str(world.get("id", ""))
	var tint := Color.from_string(str(world.get("color", "#888888")), Color.GRAY)
	var at: Vector2 = island.region_centre(world_id)

	var earned := 0
	for level in levels:
		earned += int(SaveManager.get_level_progress(str(level.get("id", ""))).get("stars", 0))
	var possible: int = levels.size() * 3

	# A fixed-size holder: a PanelContainer dropped straight onto a plain
	# Control grows to the parent's size (once 720px of signpost).
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(280, 116)
	holder.size = Vector2(280, 116)
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
	name_label.add_theme_font_size_override("font_size", 30)
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
	page.add_child(holder)
	holder.position = at - Vector2(140, 132)


func _add_markers(page: Control, island: IslandMap, world: Dictionary,
		levels: Array, world_index: int) -> void:
	var world_id: String = str(world.get("id", ""))
	for i in range(levels.size()):
		var marker := _build_marker(levels[i], world_index)
		page.add_child(marker)
		marker.position = island.node_position(world_id, i) \
			- Vector2((MARKER + 40.0) * 0.5, MARKER * 0.54)


## A level as a stone on the path, carrying the picture of what KIND of game
## it is -- an orb for collecting, a flag for the trail, a music note for the
## song. The playtest complaint was exact: "the icons are all the same, I
## don't know what's inside". A level may also name its own icon in JSON when
## the type picture is not specific enough.
func _build_marker(level: Dictionary, world_index: int) -> Control:
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
		"traffic_crossing": "traffic_light", "item_sorting": "sort",
		"collect_energy": "orb", "animal_rescue": "paw",
		"monster_battle": "monster", "memory_match": "blocks",
		"light_echo": "music", "monster_duel": "lightning",
		"platformer": "flag", "monster_expedition": "compass",
		"keepy_uppy": "balloon", "light_defense": "target",
	}
	var icon_name: String = str(level.get("icon",
		icons.get(str(level.get("game_type", "")), "flag")))
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
			# "this one is next". Its island is the page the map opens on.
			UiKit.breathe(button, 0.035, 1.0)
			if _frontier_page < 0:
				_frontier_page = world_index
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
	# physics as every other button in the game.
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
