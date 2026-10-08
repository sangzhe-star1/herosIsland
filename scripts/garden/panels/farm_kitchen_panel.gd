extends "res://scripts/garden/panels/farm_panel_base.gd"
## Kitchen sheet: cooking known dishes and sharing food with friends.

const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const Juice := preload("res://scripts/ui/juice.gd")
const PANEL_PAGE := 6


func build(view: Vector2) -> void:
	var wide := 660.0
	var tall := 470.0
	var origin: Vector2 = screen.call("_panel_sheet", view, "garden.kitchen_title", wide, tall)
	var known: Array = []
	for recipe in Recipes.all():
		if Recipes.is_unlocked(str(recipe.get("id", ""))):
			known.append(recipe)
	var pages := int(ceil(known.size() / float(PANEL_PAGE)))
	var page := clampi(int(screen.get("_kitchen_page")), 0, maxi(pages - 1, 0))
	screen.set("_kitchen_page", page)

	screen.call("_pager", origin, wide, tall, page, pages, func(step: int):
		screen.set("_kitchen_page", int(screen.get("_kitchen_page")) + step)
		screen.set("_confirm_cook", "")
		screen.call("_queue_rebuild"))

	if known.is_empty():
		var face := UiKit.picture("picture_book", 84.0)
		if face != null:
			face.position = origin + Vector2(wide * 0.5 - 42.0, 130.0)
			play.add_child(face)
		var line := UiKit.title(I18n.t("garden.kitchen_empty"), UiKit.TYPE_CAPTION, Color(0.52, 0.48, 0.40))
		line.position = origin + Vector2(50.0, 240.0)
		line.size = Vector2(wide - 100.0, 40)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play.add_child(line)
		return

	var panel_buttons: Dictionary = screen.get("_panel_buttons")
	var y := origin.y + 62.0
	for recipe in known.slice(page * PANEL_PAGE, (page + 1) * PANEL_PAGE):
		var rid := str(recipe.get("id", ""))
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1.0, 0.99, 0.95), 16))
		row.position = Vector2(origin.x + 24.0, y)
		row.custom_minimum_size = Vector2(wide - 48.0, 56.0)
		row.size = Vector2(wide - 48.0, 56.0)
		play.add_child(row)

		var x := row.position.x + 14.0
		var cookable := Recipes.can_cook(recipe)
		for need in recipe.get("needs", []):
			var art := UiKit.picture(str(GameData.get_crop(
				str(need.get("crop_id", ""))).get("icon", "seed")), 30.0)
			if art != null:
				art.position = Vector2(x, y + 6.0)
				art.modulate = Color(1, 1, 1, 1.0 if cookable else 0.4)
				play.add_child(art)
			var many := UiKit.title("x%d" % int(need.get("count", 1)), 16,
				Color(0.4, 0.38, 0.34) if cookable else Color(0.66, 0.64, 0.60))
			many.position = Vector2(x + 26.0, y + 12.0)
			many.size = Vector2(34.0, 20.0)
			play.add_child(many)
			x += 62.0
		var dish_label := UiKit.title(I18n.t(str(recipe.get("name_key", ""))), 16, Color(0.30, 0.28, 0.24))
		dish_label.position = Vector2(row.position.x + 14.0, y + 34.0)
		dish_label.size = Vector2(220.0, 20.0)
		dish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		play.add_child(dish_label)

		var owned := Recipes.dish_count(rid)
		if owned > 0:
			var plate := UiKit.picture("dish", 34.0)
			if plate != null:
				plate.position = Vector2(row.position.x + row.size.x - 318.0, y + 11.0)
				play.add_child(plate)
			var have := UiKit.title("x%d" % owned, 20)
			have.position = Vector2(row.position.x + row.size.x - 282.0, y + 17.0)
			have.size = Vector2(44.0, 24.0)
			play.add_child(have)

		var cook := chip_button(I18n.t("garden.cook_one"),
			Color(0.28, 0.64, 0.34) if cookable else Color(0.86, 0.84, 0.78),
			Vector2(92, 46))
		cook.position = Vector2(row.position.x + row.size.x - 236.0, y + 5.0)
		var this_row: Panel = row
		cook.pressed.connect(func():
			if not Recipes.can_cook(recipe):
				Juice.nudge(this_row)
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				return
			screen.set("_confirm_cook", rid)
			screen.call("_queue_rebuild"))
		play.add_child(cook)
		panel_buttons["cook_%s" % rid] = cook

		if owned > 0:
			var give := chip_button(I18n.t("garden.give_bear"),
				Color(0.88, 0.56, 0.22), Vector2(120, 46))
			give.position = Vector2(row.position.x + row.size.x - 134.0, y + 5.0)
			give.pressed.connect(func():
				if Recipes.give_to_bear(rid):
					AudioManager.play_sfx("res://assets/audio/correct.ogg")
					screen.call("_queue_rebuild"))
			play.add_child(give)
			panel_buttons["give_%s" % rid] = give
		y += 62.0

	var confirm_cook := str(screen.get("_confirm_cook"))
	if confirm_cook != "":
		var picked: Dictionary = {}
		for recipe in known:
			if str(recipe.get("id", "")) == confirm_cook:
				picked = recipe
		if not picked.is_empty():
			var strip := Panel.new()
			strip.add_theme_stylebox_override("panel",
				UiKit.panel_style(Color(0.99, 0.95, 0.85), 16))
			strip.position = Vector2(origin.x + 24.0, origin.y + 380.0)
			strip.custom_minimum_size = Vector2(wide - 48.0, 54.0)
			strip.size = Vector2(wide - 48.0, 54.0)
			play.add_child(strip)

			var sx := strip.position.x + 14.0
			for need in picked.get("needs", []):
				for i in range(int(need.get("count", 1))):
					var art := UiKit.picture(str(GameData.get_crop(
						str(need.get("crop_id", ""))).get("icon", "seed")), 28.0)
					if art != null:
						art.position = Vector2(sx, strip.position.y + 13.0)
						play.add_child(art)
					sx += 34.0
				sx += 8.0
			var arrow := UiKit.title("→", 22, Color(0.5, 0.46, 0.4))
			arrow.position = Vector2(sx + 2.0, strip.position.y + 14.0)
			arrow.size = Vector2(30, 26)
			play.add_child(arrow)
			var plate2 := UiKit.picture("dish", 32.0)
			if plate2 != null:
				plate2.position = Vector2(sx + 36.0, strip.position.y + 11.0)
				play.add_child(plate2)
			var yes := chip_button("", Color(0.55, 0.74, 0.42), Vector2(64, 42))
			var tick := UiKit.picture("check", 30.0)
			if tick != null:
				tick.position = Vector2(17, 6)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				yes.add_child(tick)
			yes.position = Vector2(strip.position.x + strip.size.x - 146.0,
				strip.position.y + 6.0)
			yes.pressed.connect(func():
				if Recipes.cook(confirm_cook):
					AudioManager.play_sfx("res://assets/audio/correct.ogg")
				screen.set("_confirm_cook", "")
				screen.call("_queue_rebuild"))
			play.add_child(yes)
			panel_buttons["confirm_cook"] = yes
			var no := chip_button("<", Color(0.72, 0.74, 0.78), Vector2(64, 42))
			no.position = Vector2(strip.position.x + strip.size.x - 74.0,
				strip.position.y + 6.0)
			no.pressed.connect(func():
				screen.set("_confirm_cook", "")
				screen.call("_queue_rebuild"))
			play.add_child(no)
			panel_buttons["cancel_cook"] = no
