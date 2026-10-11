extends "res://scripts/garden/panels/farm_panel_base.gd"
## Barn & warehouse sheet: inventory contents, storage capacity, and barn upgrades.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const SeedRack := preload("res://scripts/garden/panels/farm_seed_rack_panel.gd")

const UPGRADE_COINS := 60
const UPGRADE_PLANKS := 3
const SHELF_HEIGHT := 140.0
const BARN_CARD := Vector2(152.0, SeedRack.TILE_SIZE.y)


static func spilled_basket_anchor(view: Vector2) -> Vector2:
	return Vector2(view.x - 118.0, view.y - SHELF_HEIGHT + 27.0)


static func spill_flight_destination(view: Vector2) -> Vector2:
	return spilled_basket_anchor(view) + Vector2(15.0, 9.0)


func build_shelf(view: Vector2) -> void:
	# Keep the short capacity answer beside the seeds; the full pile lives one
	# tap away in this panel's warehouse sheet.
	var box := BARN_CARD
	var at := Vector2(view.x - 16.0 - box.x,
		float(screen.call("_seed_lane_y", view)) - box.y * 0.5)
	var card := Panel.new()
	card.name = "GardenBarnCard"
	card.add_theme_stylebox_override("panel",
		inventory_surface(true))
	card.position = at
	card.custom_minimum_size = box
	card.size = box
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(card)

	var basket := HarvestArt.prop_badge("basket_empty", 36.0, "BarnBasketPicture")
	if basket != null:
		basket.position = at + Vector2(12.0, box.y * 0.5 - 18.0)
		basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(basket)
	var label := UiKit.title(I18n.t("garden.barn"), 17,
		Color(0.55, 0.51, 0.44))
	label.position = at + Vector2(58.0, 6.0)
	label.size = Vector2(82.0, 18.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(label)
	var room := UiKit.title("%d/%d" % [Barn.total(), Barn.cap()], 22)
	room.position = at + Vector2(58.0, 24.0)
	room.size = Vector2(82.0, 25.0)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(room)

	var rail := Panel.new()
	rail.name = "BarnCapacityRail"
	rail.add_theme_stylebox_override("panel", UiKit.track_style())
	rail.position = at + Vector2(58.0, 51.0)
	rail.size = Vector2(82.0, 5.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(rail)
	var fill := Panel.new()
	fill.name = "BarnCapacityFill"
	fill.add_theme_stylebox_override("panel", UiKit.fill_style(
		Color(0.95, 0.66, 0.20)))
	fill.position = rail.position + Vector2(2.0, 2.0)
	fill.size = Vector2(78.0 * clampf(float(Barn.total())
		/ float(maxi(Barn.cap(), 1)), 0.0, 1.0), 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(fill)

	var press := Button.new()
	press.name = "BarnShortcut"
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = at
	press.custom_minimum_size = box
	press.size = box
	press.pressed.connect(func(): screen.call("_open_panel", "barn"))
	play.add_child(press)
	block_world(press)
	screen.set("_barn_button_at", at + Vector2(box.x * 0.5, box.y * 0.5))
	_build_spilled_basket(view)


## The basket by the barn door shows overflow as stored crops, never as an
## urgent warning. The barn absorbs it as space opens up.
func _build_spilled_basket(view: Vector2) -> void:
	var spilled := Barn.contents(Barn.BASKET)
	if spilled.is_empty():
		return
	var at := spilled_basket_anchor(view)
	var rim := Panel.new()
	rim.name = "OverflowBasketSlot"
	rim.position = at + Vector2(-6.0, -10.0)
	rim.size = Vector2(42.0, 38.0)
	rim.add_theme_stylebox_override("panel",
		inventory_surface(true))
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(rim)
	var pile := HarvestArt.prop_badge("basket_empty", 30.0,
		"HarvestOverflowBasket")
	if pile != null:
		pile.name = "HarvestOverflowBasket"
		pile.set_meta("crop_kinds", spilled.size())
		pile.set_meta("destination_at", at + Vector2(15.0, 9.0))
		pile.modulate = Color(1.0, 0.94, 0.78)
		pile.position = Vector2(at.x, at.y - 6.0)
		play.add_child(pile)
	var x := at.x - 8.0 - float(mini(spilled.size(), 2)) * 66.0
	for pair in spilled.slice(0, 2):
		var art: Control = crop_picture(str(pair[0]), 26.0,
			"OverflowPicture_%s" % str(pair[0]))
		if art != null:
			art.position = Vector2(x, at.y - 4.0)
			play.add_child(art)
		var many := UiKit.title("x%d" % int(pair[1]), 18)
		many.position = Vector2(x + 24.0, at.y)
		many.size = Vector2(44.0, 22.0)
		many.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(many)
		x += 66.0

	if spilled.size() > 2:
		var more_badge := Panel.new()
		more_badge.position = at + Vector2(-6.0, -20.0)
		more_badge.size = Vector2(40.0, 22.0)
		more_badge.add_theme_stylebox_override("panel",
			quiet_surface_style(Color(1.0, 0.91, 0.68),
				9, Color(0.60, 0.45, 0.22), 1, 0))
		more_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(more_badge)
		var more := UiKit.title("+%d" % (spilled.size() - 2), 14,
			Color(0.42, 0.32, 0.18))
		more.name = "OverflowMoreKinds"
		more.size = Vector2(40.0, 22.0)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more_badge.add_child(more)

	var press := Button.new()
	press.name = "OverflowShortcut"
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = Vector2(view.x - 268.0, view.y - SHELF_HEIGHT + 6.0)
	press.custom_minimum_size = Vector2(188.0, 60.0)
	press.size = press.custom_minimum_size
	press.pressed.connect(func(): screen.call("_open_panel", "basket"))
	play.add_child(press)


func build(view: Vector2) -> void:
	var wide := 700.0
	var barn_show_overflow: bool = bool(screen.get("_barn_show_overflow"))
	var title_key := "garden.waiting_harvest_title" if barn_show_overflow else "garden.warehouse_title"
	var contents := Barn.contents(Barn.BASKET if barn_show_overflow else Barn.WAREHOUSE)
	var tall := 456.0 if contents.size() > 16 else 390.0
	var origin: Vector2 = panel_sheet(view, title_key, wide, tall,
		Callable(screen, "_close_panels"))
	var basket := HarvestArt.prop_badge("basket_empty", 36.0, "BarnHeaderBasket")
	if basket != null:
		basket.position = origin + Vector2(28.0, 52.0)
		play.add_child(basket)
	var amount_text := "×%d" % Barn.total(Barn.BASKET) if barn_show_overflow \
		else "%d/%d" % [Barn.total(), Barn.cap()]
	var room := UiKit.title(amount_text, 20)
	room.name = "BarnCollectionCapacity"
	room.position = origin + Vector2(72.0, 50.0)
	room.size = Vector2(116.0, 36.0)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(room)

	if barn_show_overflow:
		var back := chip_button(I18n.t("garden.barn"), Color(0.98, 0.91, 0.73), Vector2(112.0, 60.0))
		back.name = "BarnStorageSwitch"
		back.add_theme_font_size_override("font_size", 16)
		back.position = origin + Vector2(wide - 140.0, 38.0)
		back.pressed.connect(func(): screen.call("_open_panel", "barn"))
		play.add_child(back)
	else:
		var book := chip_button("", Color(0.98, 0.91, 0.73), Vector2(60, 60))
		book.name = "RecipeBook"
		book.position = origin + Vector2(wide - 92.0, 38.0)
		var book_art := UiKit.picture("picture_book", 40.0)
		if book_art != null:
			book_art.position = Vector2(10, 10)
			book_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			book.add_child(book_art)
		book.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			screen.call("_open_panel", "recipes"))
		play.add_child(book)

	# A name and a count make every 3D collectible identifiable. Four columns
	# use up to twenty foods in five 60px rows, with no empty header-sized gap.
	var extra_items: Control = null
	if contents.size() > 20:
		var overflow := ScrollContainer.new()
		overflow.name = "BarnExtraItemsScroll"
		overflow.position = origin + Vector2(26.0, 106.0)
		overflow.size = Vector2(648.0, 330.0)
		overflow.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		overflow.clip_contents = true
		play.add_child(overflow)
		extra_items = Control.new()
		extra_items.custom_minimum_size = Vector2(636.0,
			float(int(ceil(contents.size() / 4.0))) * 66.0 - 2.0)
		overflow.add_child(extra_items)
	if contents.is_empty():
		var empty_basket := HarvestArt.prop_badge("basket_empty", 104.0, "BarnEmptyBasket")
		if empty_basket != null:
			empty_basket.position = origin + Vector2(298.0, 142.0)
			play.add_child(empty_basket)
		var empty_hint := UiKit.title(I18n.t("garden.waiting_harvest_empty" if barn_show_overflow else "garden.collection_empty"), 18, Color(0.49, 0.39, 0.25))
		empty_hint.name = "BarnEmptyHint"
		empty_hint.position = origin + Vector2(28.0, 266.0)
		empty_hint.size = Vector2(wide - 56.0, 36.0)
		empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(empty_hint)
	for index in range(contents.size()):
		var pair: Array = contents[index]
		var crop_id := str(pair[0])
		var slot := Panel.new()
		slot.name = "BarnCollectionSlot_%s" % crop_id
		slot.position = origin + Vector2(30.0 + (index % 4) * 162.0,
			108.0 + int(index / 4) * 66.0)
		slot.size = Vector2(154.0, 60.0)
		slot.add_theme_stylebox_override("panel", inventory_surface(true))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if extra_items != null:
			slot.position = Vector2(4.0 + (index % 4) * 158.0, 2.0 + int(index / 4) * 66.0)
			extra_items.add_child(slot)
		else:
			play.add_child(slot)
		var art: Control = crop_picture(crop_id, 40.0, "BarnPicture_%s" % crop_id)
		if art != null:
			art.position = Vector2(6.0, 10.0)
			slot.add_child(art)
		var name_key := str(GameData.get_crop(crop_id).get("name_key", ""))
		var crop_name := UiKit.title(I18n.t(name_key) if name_key != "" else crop_id, 14, Color(0.43, 0.33, 0.21))
		crop_name.name = "BarnName_%s" % crop_id
		crop_name.position = Vector2(54.0, 1.0)
		crop_name.size = Vector2(96.0, 24.0)
		crop_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		crop_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		crop_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(crop_name)
		var many := UiKit.title("×%d" % int(pair[1]), 16)
		many.name = "BarnQuantity_%s" % crop_id
		many.position = Vector2(54.0, 28.0)
		many.size = Vector2(96.0, 28.0)
		many.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		many.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(many)

	if barn_show_overflow or Barn.cap() >= Farm.WAREHOUSE_UPGRADED:
		return
	var planks := Barn.count("plank", "inventory")
	var can_do: bool = planks >= UPGRADE_PLANKS and Coins.can_afford(UPGRADE_COINS)
	var panel_buttons: Dictionary = screen.get("_panel_buttons")
	if bool(screen.get("_confirm_upgrade")):
		var yes := chip_button(I18n.t("garden.upgrade"), Color(0.98, 0.83, 0.50), Vector2(168.0, 60.0))
		yes.add_theme_font_size_override("font_size", 18)
		yes.position = origin + Vector2(232.0, 38.0)
		yes.pressed.connect(Callable(screen, "_upgrade_confirmed"))
		play.add_child(yes)
		panel_buttons["confirm_upgrade"] = yes
		var no := chip_button(I18n.t("garden.cancel"), Color(0.95, 0.90, 0.79), Vector2(168.0, 60.0))
		no.add_theme_font_size_override("font_size", 18)
		no.position = origin + Vector2(412.0, 38.0)
		no.pressed.connect(func():
			screen.set("_confirm_upgrade", false)
			screen.call("_queue_rebuild"))
		play.add_child(no)
		panel_buttons["cancel_upgrade"] = no
	else:
		var coin := UiKit.picture("star_coin", 24.0)
		if coin != null:
			coin.position = origin + Vector2(204.0, 53.0)
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(coin)
		var cost := UiKit.title(str(UPGRADE_COINS), 18)
		cost.position = origin + Vector2(232.0, 48.0)
		cost.size = Vector2(44.0, 36.0)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(cost)
		var plank_art := UiKit.picture("plank", 24.0)
		if plank_art != null:
			plank_art.position = origin + Vector2(290.0, 53.0)
			plank_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(plank_art)
		var plank_tag := UiKit.title("%d/%d" % [planks, UPGRADE_PLANKS], 18,
			Color(0.30, 0.43, 0.23) if planks >= UPGRADE_PLANKS else Color(0.62, 0.52, 0.36))
		plank_tag.position = origin + Vector2(318.0, 48.0)
		plank_tag.size = Vector2(64.0, 36.0)
		plank_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(plank_tag)
		var up := chip_button(I18n.t("garden.upgrade"), Color(0.98, 0.87, 0.62) if can_do else Color(0.90, 0.87, 0.79), Vector2(156.0, 60.0))
		up.add_theme_font_size_override("font_size", 18)
		up.position = origin + Vector2(402.0, 38.0)
		up.disabled = not can_do
		up.pressed.connect(func():
			screen.set("_confirm_upgrade", true)
			screen.call("_queue_rebuild"))
		play.add_child(up)
		panel_buttons["upgrade"] = up
