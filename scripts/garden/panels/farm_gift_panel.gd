extends "res://scripts/garden/panels/farm_panel_base.gd"
## Gift Basket panel: send a gift basket of farm produce through the bear door,
## or walk through the door to visit the bear's farm.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Shapes := preload("res://scripts/world/shapes.gd")

const BASKET_LIMIT := 3


func build(view: Vector2) -> void:
	var wide := 680.0
	var tall := 490.0
	var origin: Vector2 = screen.call("_panel_sheet", view, "garden.gift_basket_title", wide, tall)
	var farm: Dictionary = screen.call("_farm")
	var basket: Dictionary = screen.get("_gift_basket") if screen.get("_gift_basket") != null else {}

	# 1. Bear Door Top Card: option to visit the bear
	var door_card := Panel.new()
	door_card.name = "BearDoorCard"
	door_card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1.0, 0.97, 0.90), 18))
	door_card.position = Vector2(origin.x + 20.0, origin.y + 60.0)
	door_card.custom_minimum_size = Vector2(wide - 40.0, 80.0)
	door_card.size = Vector2(wide - 40.0, 80.0)
	play.add_child(door_card)

	var bear_face := HarvestArt.prop_badge("bear", 56.0, "BearDoorFace")
	if bear_face == null:
		bear_face = UiKit.picture("teddy", 56.0)
	if bear_face != null:
		bear_face.position = door_card.position + Vector2(16.0, 12.0)
		play.add_child(bear_face)

	var door_prompt := UiKit.title(I18n.t("garden.gift_welcome"), 16, Color(0.35, 0.28, 0.18))
	door_prompt.position = door_card.position + Vector2(86.0, 26.0)
	door_prompt.size = Vector2(400.0, 26.0)
	door_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.add_child(door_prompt)

	var visit_btn := chip_button(I18n.t("garden.gift_visit_btn"), Color(1.0, 0.88, 0.55), Vector2(120.0, 48.0))
	visit_btn.name = "VisitBearFarmButton"
	visit_btn.position = door_card.position + Vector2(door_card.size.x - 136.0, 16.0)
	visit_btn.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/door.ogg")
		SceneManager.goto_scene("res://scenes/garden/BearFarm.tscn"))
	play.add_child(visit_btn)

	# 2. Gift Basket Packing Section
	var pack_y := origin.y + 154.0
	var shelf_panel := Panel.new()
	shelf_panel.name = "GiftShelfPanel"
	shelf_panel.add_theme_stylebox_override("panel", screen.call("_quiet_surface_style",
		Color(0.96, 0.94, 0.88, 0.7), 20, Color(0.65, 0.55, 0.40, 0.3), 1, 8))
	shelf_panel.position = Vector2(origin.x + 20.0, pack_y)
	shelf_panel.custom_minimum_size = Vector2(wide - 40.0, 250.0)
	shelf_panel.size = Vector2(wide - 40.0, 250.0)
	play.add_child(shelf_panel)

	var shelf_title := UiKit.title(I18n.t("garden.gift_basket_hint"), 16, Color(0.48, 0.42, 0.32))
	shelf_title.position = shelf_panel.position + Vector2(18.0, 12.0)
	shelf_title.size = Vector2(360.0, 24.0)
	shelf_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.add_child(shelf_title)

	# Warehouse produce choices (left 380px)
	var contents := Barn.contents()
	if contents.is_empty():
		var empty_lbl := UiKit.title(I18n.t("garden.gift_empty_barn"), 17, Color(0.55, 0.50, 0.40))
		empty_lbl.position = shelf_panel.position + Vector2(20.0, 80.0)
		empty_lbl.size = Vector2(360.0, 30.0)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play.add_child(empty_lbl)
	else:
		var grid_x := shelf_panel.position.x + 16.0
		var grid_y := shelf_panel.position.y + 44.0
		for i in range(mini(contents.size(), 8)):
			var pair: Array = contents[i]
			var crop_id := str(pair[0])
			var barn_count := Barn.count(crop_id)
			var in_basket := int(basket.get(crop_id, 0))
			var remaining := barn_count - in_basket

			var chip := Button.new()
			chip.name = "GiftPick_%s" % crop_id
			chip.flat = true
			chip.custom_minimum_size = Vector2(80.0, 86.0)
			chip.size = Vector2(80.0, 86.0)
			var col := i % 4
			var row := int(i / 4)
			chip.position = Vector2(grid_x + 92.0 * float(col), grid_y + 94.0 * float(row))
			chip.mouse_filter = Control.MOUSE_FILTER_PASS

			var chip_bg := Panel.new()
			chip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip_bg.size = chip.size
			chip_bg.add_theme_stylebox_override("panel", UiKit.panel_style(
				Color(0.99, 0.98, 0.94) if remaining > 0 else Color(0.92, 0.91, 0.88), 14))
			chip.add_child(chip_bg)

			var art := UiKit.picture(str(GameData.get_crop(crop_id).get("icon", "seed")), 40.0)
			if art != null:
				art.position = Vector2(20.0, 8.0)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				chip.add_child(art)

			var count_lbl := UiKit.title("x%d" % remaining, 15,
				Color(0.35, 0.28, 0.18) if remaining > 0 else Color(0.60, 0.55, 0.50))
			count_lbl.position = Vector2(6.0, 56.0)
			count_lbl.size = Vector2(68.0, 20.0)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(count_lbl)

			chip.pressed.connect(func():
				_add_to_basket(crop_id))
			play.add_child(chip)

	# Right side: Basket summary (x: +440px)
	var basket_box := Panel.new()
	basket_box.name = "BasketPreviewBox"
	basket_box.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1.0, 0.98, 0.92), 16))
	basket_box.position = shelf_panel.position + Vector2(shelf_panel.size.x - 220.0, 14.0)
	basket_box.size = Vector2(206.0, 156.0)
	play.add_child(basket_box)

	var basket_icon := HarvestArt.grounded_sprite(HarvestArt.prop_texture("basket"), 52.0, Vector2.ZERO, "BasketArt")
	if basket_icon != null:
		basket_icon.position = basket_box.position + Vector2(20.0, 20.0)
		play.add_child(basket_icon)

	var total_items := 0
	for count in basket.values():
		total_items += int(count)

	var basket_count_lbl := UiKit.title("礼篮: %d/%d" % [total_items, BASKET_LIMIT], 18, Color(0.72, 0.44, 0.12))
	basket_count_lbl.name = "BasketCountLabel"
	basket_count_lbl.position = basket_box.position + Vector2(80.0, 30.0)
	basket_count_lbl.size = Vector2(110.0, 24.0)
	basket_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.add_child(basket_count_lbl)

	# Display packed items
	var slot_x := basket_box.position.x + 20.0
	var slot_y := basket_box.position.y + 86.0
	for crop_id in basket.keys():
		var count := int(basket[crop_id])
		for n in range(count):
			var slot_pic := UiKit.picture(str(GameData.get_crop(crop_id).get("icon", "seed")), 36.0)
			if slot_pic != null:
				slot_pic.position = Vector2(slot_x, slot_y)
				play.add_child(slot_pic)
				slot_x += 42.0

	# Send Button
	var send_btn := chip_button(I18n.t("garden.gift_send_btn"), Color(1.0, 0.86, 0.52), Vector2(180.0, 52.0))
	send_btn.name = "SendGiftBasketButton"
	send_btn.position = shelf_panel.position + Vector2(shelf_panel.size.x - 208.0, 182.0)
	send_btn.disabled = total_items == 0
	send_btn.pressed.connect(Callable(self, "_on_send_pressed"))
	play.add_child(send_btn)


func _add_to_basket(crop_id: String) -> void:
	var basket: Dictionary = screen.get("_gift_basket") if screen.get("_gift_basket") != null else {}
	var total_items := 0
	for count in basket.values():
		total_items += int(count)
	if total_items >= BASKET_LIMIT:
		return
	var barn_count := Barn.count(crop_id)
	var in_basket := int(basket.get(crop_id, 0))
	if in_basket >= barn_count:
		return

	basket[crop_id] = in_basket + 1
	screen.set("_gift_basket", basket)
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	screen.call("_queue_rebuild")


func _on_send_pressed() -> void:
	var basket: Dictionary = screen.get("_gift_basket") if screen.get("_gift_basket") != null else {}
	if basket.is_empty():
		return
	if not Barn.pay(basket):
		return

	var farm: Dictionary = SaveManager.data["farm"]
	var friends: Dictionary = farm.get("npc_friendship", {})
	friends["bear"] = int(friends.get("bear", 0)) + 1
	farm["npc_friendship"] = friends

	# Award friendship star coins
	Coins.earn(20)

	# Remember visit with thanks
	Farm.remember_visit(farm, {
		"who": "bear",
		"kind": "thanks",
		"at": GameClock.now_unix(),
		"milestone_key": "garden.gift_thanks",
		"milestone_icon": "heart"
	})
	farm["visit_log_unread"] = true
	SaveManager.save_game()

	AudioManager.play_sfx("res://assets/audio/star.ogg")
	screen.set("_gift_basket", {})
	screen.call("_close_panels")
