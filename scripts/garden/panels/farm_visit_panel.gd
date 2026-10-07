extends "res://scripts/garden/panels/farm_panel_base.gd"
## Visitor board sheet: today's guest craving and past visitor logs.

const VisitorManager := preload("res://scripts/garden/farm_visitor_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")


func build(view: Vector2) -> void:
	var wide := 640.0
	var tall := 470.0
	var origin: Vector2 = screen.call("_panel_sheet", view, "garden.visit_title", wide, tall)
	var farm: Dictionary = screen.call("_farm")
	var log: Array = farm.get("visit_log", [])
	var templates: Dictionary = GameData.farm_visit_texts

	# 1. Today's Guest Card
	var visitor := VisitorManager.today_visitor()
	var y := origin.y + 60.0
	if not visitor.is_empty():
		var who := str(visitor.get("who", "rabbit"))
		var dish_id := str(visitor.get("dish_id", ""))
		var coins := int(visitor.get("reward_coins", 15))
		var is_fed := VisitorManager.has_fed_today(farm)
		var can_feed := VisitorManager.can_feed_visitor(farm)

		var guest_card := Panel.new()
		guest_card.name = "TodayGuestCard"
		guest_card.add_theme_stylebox_override("panel", UiKit.panel_style(
			Color(1.0, 0.98, 0.92) if not is_fed else Color(0.94, 0.98, 0.92), 20))
		guest_card.position = Vector2(origin.x + 20.0, y)
		guest_card.custom_minimum_size = Vector2(wide - 40.0, 96.0)
		guest_card.size = Vector2(wide - 40.0, 96.0)
		play.add_child(guest_card)

		# Guest avatar
		var prop_key := "dog" if who == "puppy" else who
		var face := HarvestArt.prop_badge(prop_key, 64.0, "GuestAvatar")
		if face == null:
			face = UiKit.picture("teddy", 64.0)
		if face != null:
			face.position = guest_card.position + Vector2(16.0, 16.0)
			play.add_child(face)

		# Guest name & prompt
		var who_name := ""
		match who:
			"rabbit": who_name = I18n.t("friend.rabbit")
			"puppy": who_name = I18n.t("friend.puppy")
			"robot": who_name = I18n.t("friend.robot")
			_: who_name = I18n.t("friend.bear")
		var header := UiKit.title("%s: %s" % [I18n.t("garden.visitor_today"), who_name], 18, Color(0.35, 0.28, 0.18))
		header.position = guest_card.position + Vector2(90.0, 14.0)
		header.size = Vector2(300.0, 24.0)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		play.add_child(header)

		# Dish request info
		var recipe_name := ""
		for r in GameData.garden_recipes:
			if str(r.get("id", "")) == dish_id:
				recipe_name = I18n.t(str(r.get("name_key", dish_id)))
		var dish_label := UiKit.title("%s %s" % [I18n.t("garden.visitor_wants"), recipe_name], 16, Color(0.48, 0.40, 0.30))
		dish_label.position = guest_card.position + Vector2(90.0, 42.0)
		dish_label.size = Vector2(240.0, 24.0)
		dish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		play.add_child(dish_label)

		# Dish icon
		var dish_pic := UiKit.picture("dish", 28.0)
		if dish_pic != null:
			dish_pic.position = guest_card.position + Vector2(90.0, 64.0)
			play.add_child(dish_pic)

		# Reward coins tag
		var coin_pic := UiKit.picture("star_coin", 24.0)
		if coin_pic != null:
			coin_pic.position = guest_card.position + Vector2(130.0, 66.0)
			play.add_child(coin_pic)
		var coin_lbl := UiKit.title("+%d" % coins, 16, Color(0.72, 0.48, 0.12))
		coin_lbl.position = guest_card.position + Vector2(158.0, 66.0)
		coin_lbl.size = Vector2(60.0, 22.0)
		coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		play.add_child(coin_lbl)

		# Action button / status
		if is_fed:
			var fed_tag := UiKit.title(I18n.t("garden.visitor_fed_toast"), 16, Color(0.28, 0.52, 0.24))
			fed_tag.position = guest_card.position + Vector2(guest_card.size.x - 240.0, 36.0)
			fed_tag.size = Vector2(230.0, 28.0)
			fed_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			play.add_child(fed_tag)
		elif can_feed:
			var give_btn := chip_button(I18n.t("garden.visitor_give"), Color(1.0, 0.88, 0.55), Vector2(130.0, 52.0))
			give_btn.name = "GiveDishButton"
			give_btn.position = guest_card.position + Vector2(guest_card.size.x - 146.0, 22.0)
			give_btn.pressed.connect(func():
				AudioManager.play_sfx("res://assets/audio/correct.ogg")
				VisitorManager.feed_visitor(farm)
				screen.call("_queue_rebuild"))
			play.add_child(give_btn)
		else:
			var cook_btn := chip_button(I18n.t("garden.kitchen_title"), Color(0.92, 0.88, 0.80), Vector2(130.0, 52.0))
			cook_btn.name = "GoKitchenButton"
			cook_btn.position = guest_card.position + Vector2(guest_card.size.x - 146.0, 22.0)
			cook_btn.pressed.connect(func():
				screen.call("_open_panel", "kitchen"))
			play.add_child(cook_btn)

		y += 108.0

	# 2. Historical Visit Logs
	if log.is_empty():
		var empty_line := UiKit.title(I18n.t("garden.visit_empty"), 20, Color(0.55, 0.50, 0.42))
		empty_line.position = Vector2(origin.x + 30.0, y + 40.0)
		empty_line.size = Vector2(wide - 60.0, 36.0)
		empty_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play.add_child(empty_line)
		return

	for entry_index in range(mini(log.size(), 2)):
		var entry: Dictionary = log[entry_index]
		var who := str(entry.get("who", "bear"))
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1.0, 0.99, 0.95), 18))
		card.position = Vector2(origin.x + 20.0, y)
		card.custom_minimum_size = Vector2(wide - 40.0, 84.0)
		card.size = Vector2(wide - 40.0, 84.0)
		play.add_child(card)

		var prop_key := "dog" if who == "puppy" else who
		var face := HarvestArt.prop_badge(prop_key, 52.0)
		if face == null:
			face = UiKit.picture("teddy", 52.0)
		if face != null:
			face.position = card.position + Vector2(12.0, 16.0)
			play.add_child(face)

		var x := card.position.x + 80.0
		var set_key := "visited_lines" if str(entry.get("kind", "")) == "guest" else "lines"
		var lines: Array = templates.get(who, {}).get(set_key, [])
		for line_def: Dictionary in lines:
			var count_field := str(line_def.get("count_field", ""))
			var count := int(entry.get(count_field, 0)) if count_field != "" else 1
			if count <= 0:
				continue
			var art := UiKit.picture(str(line_def.get("icon", "star")), 34.0)
			if art != null:
				art.position = Vector2(x, card.position.y + 10.0)
				play.add_child(art)
			if count_field != "" and not entry.has("milestone_key"):
				var many := UiKit.title("x%d" % count, 18)
				many.position = Vector2(x + 4.0, card.position.y + 48.0)
				many.size = Vector2(48.0, 24.0)
				play.add_child(many)
			x += 64.0

		var note_key := str(entry.get("milestone_key", ""))
		if note_key == "" and not lines.is_empty():
			note_key = str((lines[0] as Dictionary).get("key", ""))
		if note_key != "":
			var note := UiKit.title(I18n.t(note_key), 16,
				Color(0.72, 0.52, 0.28) if entry.has("milestone_key")
				else Color(0.55, 0.51, 0.44))
			note.position = card.position + Vector2(80.0, 52.0)
			note.size = Vector2(wide - 180.0, 24.0)
			play.add_child(note)
		if entry.has("milestone_icon"):
			var keepsake := UiKit.picture(str(entry.get("milestone_icon", "heart")), 36.0)
			if keepsake != null:
				keepsake.position = Vector2(x, card.position.y + 10.0)
				play.add_child(keepsake)
		y += 92.0
