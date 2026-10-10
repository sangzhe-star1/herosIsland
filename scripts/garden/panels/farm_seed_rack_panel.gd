extends "res://scripts/garden/panels/farm_panel_base.gd"
## The farm's seed pouch: visual slots, drag pieces and its own pager.
##
## The screen owns the live DragField and the choice callbacks. This panel
## owns how the familiar seeds sit together at the bottom of the glass.

const TILE_SIZE := Vector2(64.0, 60.0)
const PAGE_SIZE := 14
const FIRST_TILE_X := 16.0 + TILE_SIZE.x * 0.5
const TILE_STEP := TILE_SIZE.x + 4.0


static func tile_centre(index: int, lane_y: float) -> Vector2:
	return Vector2(FIRST_TILE_X + TILE_STEP * float(index), lane_y)


func _deck_width(slots: int) -> float:
	var last := FIRST_TILE_X + TILE_STEP * float(maxi(slots, 1) - 1)
	return last + TILE_SIZE.x * 0.5 - 12.0 + 2.0


func _page_button(direction: String) -> Button:
	var button := UiKit.compact_button(direction, Color(0.98, 0.94, 0.83),
		Vector2(60, 60), 26)
	button.add_theme_stylebox_override("normal", _surface(
		Color(0.98, 0.94, 0.83), Color(0.68, 0.49, 0.23, 0.28)))
	button.add_theme_stylebox_override("hover", _surface(
		Color(1.0, 0.97, 0.89), Color(0.68, 0.49, 0.23, 0.48)))
	button.add_theme_stylebox_override("pressed", _surface(
		Color(0.94, 0.86, 0.69), Color(0.60, 0.42, 0.19, 0.48)))
	for slot in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		button.add_theme_color_override(slot, Palette.INK)
	button.size = Vector2(60, 60)
	return button


func _surface(fill: Color, edge: Color) -> StyleBoxFlat:
	return screen.call("_quiet_surface_style", fill, 16, edge, 1, 8)


func build(view: Vector2, shelf_height: float) -> void:
	var shelf := Panel.new()
	var shelf_style: StyleBoxFlat = screen.call("_quiet_surface_style",
		Color(0.97, 0.93, 0.83), 0, Color(0.68, 0.49, 0.23, 0.50))
	shelf_style.border_width_top = 2
	shelf.add_theme_stylebox_override("panel", shelf_style)
	shelf.position = Vector2(0, view.y - shelf_height)
	shelf.custom_minimum_size = Vector2(view.x, shelf_height)
	shelf.size = Vector2(view.x, shelf_height)
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(shelf)
	screen.set("_shelf", shelf)

	# Passive backers group the original touch targets without adding an input
	# layer of their own.
	var tool_deck := Panel.new()
	tool_deck.name = "GardenToolDeck"
	tool_deck.add_theme_stylebox_override("panel", screen.call(
		"_quiet_surface_style", Color(0.87, 0.77, 0.57, 0.30), 20,
		Color(0.65, 0.46, 0.21, 0.25), 1))
	tool_deck.position = Vector2(12.0, view.y - shelf_height + 2.0)
	tool_deck.custom_minimum_size = Vector2(minf(560.0, view.x - 24.0), 64.0)
	tool_deck.size = tool_deck.custom_minimum_size
	tool_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(tool_deck)

	var farm: Dictionary = screen.call("_farm")
	var unlocked: Array = farm.get("unlocked_crops", [])
	var tools: RefCounted = screen.get("_tools")
	var chosen: String = tools.crop_to_plant(unlocked)
	var pages := int(ceil(unlocked.size() / float(PAGE_SIZE)))
	var page := clampi(int(screen.get("_rack_page")), 0, maxi(pages - 1, 0))
	screen.set("_rack_page", page)
	var on_page: Array = unlocked.slice(page * PAGE_SIZE,
		(page + 1) * PAGE_SIZE)
	var lane_y: float = screen.call("_seed_lane_y", view)
	var seed_deck := Panel.new()
	seed_deck.name = "GardenSeedDeck"
	seed_deck.add_theme_stylebox_override("panel", screen.call(
		"_quiet_surface_style", Color(0.87, 0.77, 0.57, 0.30), 20,
		Color(0.65, 0.46, 0.21, 0.25), 1))
	seed_deck.position = Vector2(12.0, lane_y - 32.0)
	seed_deck.custom_minimum_size = Vector2(
		minf(_deck_width(on_page.size()), view.x - 24.0), 64.0)
	seed_deck.size = seed_deck.custom_minimum_size
	seed_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(seed_deck)
	var field: Variant = screen.get("_field")
	for i in range(on_page.size()):
		var crop_id := str(on_page[i])
		var crop: Dictionary = GameData.get_crop(crop_id)
		if crop.is_empty():
			continue
		var at := tile_centre(i, lane_y)
		var tile := Node2D.new()
		tile.name = "GardenSeedArt_%s" % crop_id
		tile.position = at
		tile.set_meta("grab_rect", Rect2(-TILE_SIZE * 0.5, TILE_SIZE))
		play.add_child(tile)
		var slot := Panel.new()
		slot.name = "SeedSlot_%s" % crop_id
		slot.position = -TILE_SIZE * 0.5
		slot.size = TILE_SIZE
		slot.add_theme_stylebox_override("panel",
			screen.call("_inventory_surface", true, crop_id == chosen))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(slot)
		var art: Control = screen.call("_crop_picture", crop_id, 46.0,
			"SeedPicture_%s" % crop_id)
		if art != null:
			art.position = Vector2(-23.0, -23.0)
			tile.add_child(art)
		if crop_id == chosen:
			var selected := Panel.new()
			selected.name = "SeedSelectedMark"
			selected.position = Vector2(TILE_SIZE.x * 0.5 - 23.0,
				-TILE_SIZE.y * 0.5 + 4.0)
			selected.size = Vector2(19.0, 19.0)
			selected.add_theme_stylebox_override("panel", screen.call(
				"_quiet_surface_style", Color(0.36, 0.42, 0.19), 8,
				Color(0.36, 0.42, 0.19), 0, 0))
			selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(selected)
			var tick := UiKit.picture("check", 15.0)
			if tick != null:
				tick.position = Vector2(2.0, 2.0)
				tick.modulate = Color(1.0, 0.98, 0.83)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				selected.add_child(tick)
		field.add_item(tile, at, crop_id)

		# A tap selects this crop; a drag keeps the original plant-in-bed path.
		var pick := Button.new()
		pick.name = "GardenSeed_%s" % crop_id
		pick.flat = true
		pick.focus_mode = Control.FOCUS_NONE
		pick.position = at - TILE_SIZE * 0.5
		pick.custom_minimum_size = TILE_SIZE
		pick.size = TILE_SIZE
		var this_crop := crop_id
		pick.pressed.connect(func(): screen.call("_choose_seed", this_crop))
		play.add_child(pick)

	if pages <= 1:
		return
	var arrow_y: float = lane_y - 30.0
	var pager_x: float = FIRST_TILE_X + TILE_STEP * float(on_page.size()) \
		- TILE_SIZE.x * 0.5
	var has_back := page > 0
	var has_next := page < pages - 1
	var pager_deck := Panel.new()
	pager_deck.name = "GardenSeedPagerDeck"
	pager_deck.add_theme_stylebox_override("panel", screen.call(
		"_quiet_surface_style", Color(0.87, 0.77, 0.57, 0.30), 18,
		Color(0.65, 0.46, 0.21, 0.25), 1))
	pager_deck.position = Vector2(pager_x - 2.0, lane_y - 32.0)
	pager_deck.custom_minimum_size = Vector2(132.0 if has_back and has_next else 64.0,
		64.0)
	pager_deck.size = pager_deck.custom_minimum_size
	pager_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(pager_deck)
	var buttons: Dictionary = screen.get("_panel_buttons")
	if has_back:
		var back := _page_button("<")
		back.position = Vector2(pager_x, arrow_y)
		back.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			screen.set("_rack_page", int(screen.get("_rack_page")) - 1)
			screen.call("_queue_rebuild"))
		play.add_child(back)
		buttons["rack_back"] = back
	if has_next:
		var next := _page_button(">")
		next.position = Vector2(pager_x + (68.0 if has_back and has_next else 0.0),
			arrow_y)
		next.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			screen.set("_rack_page", int(screen.get("_rack_page")) + 1)
			screen.call("_queue_rebuild"))
		play.add_child(next)
		buttons["rack_next"] = next
