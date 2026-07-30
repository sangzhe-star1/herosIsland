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
var _breathed: Dictionary = {}
var _drag_from := Vector2(-1, -1)
var _strip_start := 0.0
var _dragging := false
var _page_tween: Tween


func _ready() -> void:
	theme = UiKit.theme()
	# Sea behind everything: the gap that shows for a moment mid page-turn is
	# water between islands, which is exactly what it should be.
	UiKit.world_background(self, "island", "map")

	_worlds = GameData.worlds.duplicate()
	_worlds.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	# The page is as tall as the screen, not as tall as the drawing.
	#
	# Honest note: nothing reads these two sizes today -- the islands are drawn
	# by IslandMap, which measures the viewport itself, and the strip is
	# scrolled by position.x alone. Deliberately breaking this line does NOT
	# make the tablet probe go red, and that was checked rather than assumed.
	# It is here because a Control that says it is 720 tall on a 960-tall screen
	# is a lie sitting in wait for the first person who anchors something to the
	# bottom of it.
	var page_h: float = maxf(720.0, get_viewport_rect().size.y)

	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip.size = Vector2(PAGE_W * _worlds.size(), page_h)
	add_child(_strip)

	for wi in range(_worlds.size()):
		var world: Dictionary = _worlds[wi]
		var world_id: String = str(world.get("id", ""))
		var levels: Array = GameData.get_levels_for_world(world_id)

		var page := Control.new()
		page.mouse_filter = Control.MOUSE_FILTER_PASS
		page.position = Vector2(PAGE_W * float(wi), 0)
		page.size = Vector2(PAGE_W, page_h)
		_strip.add_child(page)
		_pages.append(page)

		var island := IslandMap.new()
		# Into the tree BEFORE it is built, so it can ask how tall the screen is.
		page.add_child(island)
		island.build([world], {world_id: levels}, true)

		_add_region_banner(page, island, world, levels)
		_add_markers(page, island, world, levels, wi)

	_add_header()
	_add_arrows()
	_add_dots()

	# Open on the island the child is actually looking at.
	#
	# Coming back from a level, that is THAT level's island. He pressed the
	# back arrow two seconds ago; the island he was standing on should still be
	# on screen. It used to always open on the frontier -- the first page with
	# an unfinished level -- so leaving the castle dropped him back at the park
	# and he had to swipe four times to get back to where he was. Worse with
	# the parent's unlock switch on, where every level is unfinished and the
	# frontier is always page one.
	#
	# The frontier is still the right answer for arriving fresh from the home
	# screen, which is what it was written for.
	_page = _page_for_world(str(GameManager.current_world_id))
	if _page < 0:
		_page = maxi(_frontier_page, 0)
	_strip.position.x = -PAGE_W * float(_page)
	_refresh_paging()


## Which page an island is on, or -1 if that is not a world with a page --
## the boot default, or a world id left over from an older save.
func _page_for_world(world_id: String) -> int:
	if world_id == "":
		return -1
	for i in range(_worlds.size()):
		if str(_worlds[i].get("id", "")) == world_id:
			return i
	return -1


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

	# When the parent's test switch is on, say so on the map.
	#
	# Not for the child -- for the adult who flipped it. The failure mode of an
	# unlock-everything switch is not a crash, it is forgetting: a six-year-old
	# who finds the whole island already open has lost the only thing the map
	# was ever for. Small, dim, out of the way, and impossible to miss if you
	# are looking for why nothing is locked.
	if SaveManager.test_unlock_all():
		var flag := UiKit.card(Color(0.28, 0.22, 0.10, 0.80))
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Above the island's clouds, which carry a z_index of their own and
		# will happily drift across anything that does not. The page dots hit
		# this exact wall a fortnight ago.
		flag.z_index = 25
		var note := Label.new()
		note.text = I18n.t("map.test_unlock")
		note.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
		note.add_theme_color_override("font_color", Palette.STAR_ON)
		flag.add_child(note)
		bar.add_child(flag)

	var title := UiKit.title_on_art(I18n.t("map.title"), UiKit.TYPE_DISPLAY)
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
	count.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tally_row.add_child(count)
	tally.add_child(tally_row)

	# A ring that fills as the island does, sitting INSIDE the card beside the
	# star count. Not a percentage -- a shape that closes. "How far am I" is
	# the one question a six-year-old asks about a game with more than one
	# screen, and a closing ring answers it without a single number.
	#
	# It lives in the row rather than floating below, because the first cut
	# hung it off the bottom edge of the card and dropped a second icon on
	# top of the star.
	var share: float = SaveManager.island_completion()
	var dial := Control.new()
	dial.custom_minimum_size = Vector2(58, 58)
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := Node2D.new()
	ring.position = Vector2(29, 29)
	dial.add_child(ring)
	var track := Line2D.new()
	track.points = Shapes.circle_points(Vector2.ZERO, 23.0, 30)
	track.closed = true
	track.width = 7.0
	track.default_color = Color(0.62, 0.70, 0.84, 0.55)
	track.antialiased = true
	ring.add_child(track)
	if share > 0.005:
		var done := Line2D.new()
		var steps: int = maxi(int(share * 30.0), 2)
		var arc := PackedVector2Array()
		for i in range(steps + 1):
			var a: float = -PI * 0.5 + TAU * share * float(i) / float(steps)
			arc.append(Vector2(cos(a), sin(a)) * 23.0)
		done.points = arc
		done.width = 7.0
		done.default_color = Palette.STAR_ON
		done.antialiased = true
		ring.add_child(done)
	Shapes.fill(ring, Shapes.circle_points(Vector2.ZERO, 8.0, 14),
		Palette.STAR_ON if share >= 0.999 else Color(0.62, 0.70, 0.84, 0.45), 0.0)
	tally_row.add_child(dial)
	bar.add_child(tally)


## One big arrow on each edge. Mid-height, round, and colour-ringed like the
## trail's control pad -- the same button language everywhere.
func _add_arrows() -> void:
	# Mid-sky on the REAL screen. 296 was mid-sky on a 720-tall screen and
	# nowhere in particular on the 960-tall one a tablet provides.
	var view: Vector2 = get_viewport_rect().size
	var at_y: float = view.y * 0.41
	_left_arrow = _arrow_button(false)
	_left_arrow.position = Vector2(16, at_y)
	add_child(_left_arrow)
	_right_arrow = _arrow_button(true)
	_right_arrow.position = Vector2(view.x - 16.0 - 112.0, at_y)
	add_child(_right_arrow)


func _arrow_button(forward: bool) -> Button:
	var b := Button.new()
	var size := 112.0
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	# The same button language as everything else: a raised disc whose
	# bottom edge is its thickness, squashing when pressed. It used to be a
	# navy disc in a yellow ring -- a third button style on a screen that
	# already had two, and the only colour-ringed control in the game.
	var face := Color(0.13, 0.22, 0.42)
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.set_corner_radius_all(int(size / 2.0))
	style.border_width_bottom = 8
	style.border_color = Palette.edge(face)
	style.shadow_color = Color(0.0, 0.08, 0.20, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.border_width_bottom = 3
	pressed_style.bg_color = face.darkened(0.06)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", pressed_style)
	b.add_theme_stylebox_override("disabled", style)
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
	if target != _page:
		_page = target
		_refresh_paging()
		# The sound belongs to the PAGE TURNING, not to the finger -- a swipe
		# that was not big enough snaps back silently.
		AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
	_settle_to(_page)


## Slide the strip to a page's resting place, from wherever it is now --
## which, mid-swipe, is wherever the finger left it.
func _settle_to(page: int) -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	if not Juice.motion_enabled():
		_strip.position.x = -PAGE_W * float(page)
		return
	_page_tween = create_tween()
	_page_tween.tween_property(_strip, "position:x", -PAGE_W * float(page), 0.38)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Swipes: anywhere a marker or button does not swallow the touch, the strip
## FOLLOWS the finger -- with a rubber band past the first and last island --
## and settles on release. A page that only moves after the finger has left
## is a slideshow; a page that comes along is a thing being held. The arrows
## remain the primary way; this is for the child who tries the gesture the
## tablet taught them.
func _gui_input(event: InputEvent) -> void:
	# One press, one release, through the shared rule -- the hand-rolled
	# version handled mouse AND touch, and with touch emulation on that made
	# every drag turn two pages.
	if UiKit.is_press(event):
		_dragging = true
		_drag_from = _event_position(event)
		_strip_start = _strip.position.x
		if _page_tween != null and _page_tween.is_valid():
			_page_tween.kill()
	elif event is InputEventScreenDrag and _dragging:
		var dx: float = (event as InputEventScreenDrag).position.x - _drag_from.x
		var target: float = _strip_start + dx
		# The rubber band: past either end the strip comes along at a third
		# of the finger's speed, so the edge feels like an edge instead of a
		# wall -- and instead of a lie that there is more island that way.
		var last: float = -PAGE_W * float(_worlds.size() - 1)
		if target > 0.0:
			target *= 0.32
		elif target < last:
			target = last + (target - last) * 0.32
		_strip.position.x = target
	elif UiKit.is_release(event) and _dragging:
		_dragging = false
		var dx: float = _event_position(event).x - _drag_from.x
		_drag_from = Vector2(-1, -1)
		if absf(dx) >= SWIPE:
			_go_page(_page + (1 if dx < 0.0 else -1))
		else:
			_settle_to(_page)


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

	# Rooms are left out of BOTH halves of this. The signpost answers "how much
	# of this world is left to do", and a room is never left to do -- counting
	# 星光菜园 in the denominator would put three stars in it that no amount of
	# gardening can ever earn, and the world would read as unfinished forever.
	#
	# This does not touch total_stars(), which is what the shop unlocks read;
	# stars already banked stay banked, they just stop being described as part
	# of a world's remaining work.
	var earned := 0
	var counted := 0
	for level in levels:
		if bool(level.get("room", false)):
			continue
		counted += 1
		earned += int(SaveManager.get_level_progress(str(level.get("id", ""))).get("stars", 0))
	var possible: int = counted * 3

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
	name_label.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiKit.star(earned > 0, 30))
	var tally := Label.new()
	tally.text = "%d / %d" % [earned, possible]
	tally.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
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

	# What KIND of game this is, said in a picture.
	#
	# Every marker on the island was the same red flag. The table below only
	# knew the template names from before the rebuild, so all nine of the new
	# ones fell through to the default -- eight levels in a world, one picture
	# between them, and no way for a child who cannot read the label to tell
	# the sorting game from the bridge-building one. He picks a level by
	# looking; the marker was telling him nothing.
	#
	# One distinct picture per template, no exceptions -- tools_check enforces
	# it, because this is now the third time a rename has quietly left a
	# lookup table behind. Chosen by drawing all the candidates at marker size
	# on the marker's own blue and picking from the picture, not the name:
	# `tower` reads as a microscope at 83 px, `socket` as a robot's face, and
	# `bandage` disappears against the disc.
	var icons := {
		# the nine the island is built from
		"observation_search": "magnifier",   # find the hidden things
		"matching_sorting": "sort",          # shapes into the right boxes
		"build_repair": "blocks",            # put the pieces together
		"puzzle_mechanism": "gear",          # turn it until it works
		"memory_rhythm": "music",            # watch the order, play it back
		"roleplay_rescue": "heart",          # go and help somebody
		"creative_play": "crayon",
		"garden": "sprout", "harvest_action": "basket",           # no rules, make something
		"monster_duel": "lightning",         # a fight
		"platform_adventure": "flag",        # run and jump to the goal
		# the bonus rooms
		"keepy_uppy": "balloon", "light_defense": "target",
		"light_echo": "spark",
		# older templates, still shipping scenes
		"traffic_crossing": "traffic_light", "item_sorting": "sort",
		"collect_energy": "orb", "animal_rescue": "paw",
		"monster_battle": "monster", "memory_match": "blocks",
		"platformer": "flag", "monster_expedition": "compass",
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
		# The stone goes grey but KEEPS its picture, dimmed, with a small
		# lock in the corner. Replacing the picture with a lock was how five
		# locked stones in a row became identical -- the exact complaint
		# ("the icons are all the same") this marker system was built to fix,
		# reintroduced for every level a child had not reached yet. What is
		# behind a door is most interesting before it opens.
		face = Palette.MUTED

	var button := _stone_button(icon_name, face, playable)
	if playable:
		button.pressed.connect(func(): GameManager.start_level(level_id))
		if not completed:
			# The frontier -- playable but not yet cleared -- breathes gently:
			# "this one is next". ONE per page: with the parent's unlock-all
			# switch on, every stone used to breathe at once, and eight
			# things saying "press me" is none of them saying it.
			if not _breathed.has(world_index):
				_breathed[world_index] = true
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
	label.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	label.add_theme_color_override("font_color", Palette.ON_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.14, 0.10, 0.85))
	label.add_theme_constant_override("outline_size", 7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(MARKER + 40.0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)

	# No star row under a room. Three empty stars that can never fill is a
	# promise the garden is not able to keep, and a six-year-old reads an empty
	# row as "there is something here I have not managed yet".
	if not bool(level.get("room", false)):
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
	# Bottom edge only. The stones used to wear a border on all four sides
	# AND the shadow -- belt, braces and a rope. The bottom edge is the
	# thickness that squashes on press, same as every button in the game;
	# the other three sides said nothing.
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.set_corner_radius_all(int(MARKER * 0.5))
	normal.border_width_bottom = 9
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
		if not playable:
			icon.modulate = Color(1, 1, 1, 0.45)
		b.add_child(icon)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	if playable:
		b.pressed.connect(func():
			Juice.pop(b, 0.08)
			AudioManager.play_sfx("res://assets/audio/pop.ogg"))
	else:
		# The lock rides the corner, the same place the home cards keep
		# their marks, so "locked" reads as a STATE of the level rather
		# than as its identity.
		var lock: Control = UiKit.picture("lock", 44.0)
		if lock != null:
			lock.name = "LockBadge"
			lock.position = Vector2(MARKER - 48.0, 2.0)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lock)
		# A disabled button eats the tap and says nothing, and at six a tap
		# that does NOTHING is the screen being broken. The veil catches it:
		# the stone shakes its head, quietly. It answers; it never opens.
		var veil := Control.new()
		veil.name = "LockedAnswer"
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_STOP
		b.add_child(veil)
		veil.gui_input.connect(func(event: InputEvent):
			if UiKit.is_press(event):
				Juice.nudge(b)
				AudioManager.play_sfx("res://assets/audio/pop.ogg"))
	return b
