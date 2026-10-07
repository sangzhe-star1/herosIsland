extends "res://scripts/garden/panels/farm_panel_base.gd"
## Barn & warehouse sheet: inventory contents, storage capacity, and barn upgrades.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")

const UPGRADE_COINS := 60
const UPGRADE_PLANKS := 3


func build(view: Vector2) -> void:
	var wide := 700.0
	var barn_show_overflow: bool = bool(screen.get("_barn_show_overflow"))
	var title_key := "garden.waiting_harvest_title" if barn_show_overflow else "garden.warehouse_title"
	var contents := Barn.contents(Barn.BASKET if barn_show_overflow else Barn.WAREHOUSE)
	var tall := 456.0 if contents.size() > 16 else 390.0
	var origin: Vector2 = screen.call("_panel_sheet", view, title_key, wide, tall)
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
		back.add_theme_font_size_override("font_size", 18)
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
		slot.add_theme_stylebox_override("panel", screen.call("_inventory_surface", true))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if extra_items != null:
			slot.position = Vector2(4.0 + (index % 4) * 158.0, 2.0 + int(index / 4) * 66.0)
			extra_items.add_child(slot)
		else:
			play.add_child(slot)
		var art: Control = screen.call("_crop_picture", crop_id, 40.0, "BarnPicture_%s" % crop_id)
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
