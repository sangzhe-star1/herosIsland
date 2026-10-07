extends "res://scripts/garden/panels/farm_panel_base.gd"
## Recipe book sheet: all available recipes and their required crops.

const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const PANEL_PAGE := 6


func build(view: Vector2) -> void:
	var wide := 640.0
	var tall := 470.0
	var origin: Vector2 = screen.call("_panel_sheet", view, "garden.recipes_title", wide, tall)
	var book: Array = Recipes.all()
	var pages := int(ceil(book.size() / float(PANEL_PAGE)))
	var page := clampi(int(screen.get("_book_page")), 0, maxi(pages - 1, 0))
	screen.set("_book_page", page)

	screen.call("_pager", origin, wide, tall, page, pages, func(step: int):
		screen.set("_book_page", int(screen.get("_book_page")) + step)
		screen.call("_queue_rebuild"))

	var y := origin.y + 62.0
	for recipe in book.slice(page * PANEL_PAGE, (page + 1) * PANEL_PAGE):
		var known: bool = Recipes.is_unlocked(str(recipe.get("id", "")))
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(
			Color(1.0, 0.99, 0.95) if known else Color(0.93, 0.91, 0.86), 16))
		row.position = Vector2(origin.x + 24.0, y)
		row.custom_minimum_size = Vector2(wide - 48.0, 56.0)
		row.size = Vector2(wide - 48.0, 56.0)
		play.add_child(row)

		var x := row.position.x + 14.0
		for need in recipe.get("needs", []):
			var art := UiKit.picture(str(GameData.get_crop(
				str(need.get("crop_id", ""))).get("icon", "seed")), 30.0)
			if art != null:
				art.position = Vector2(x, y + 13.0)
				art.modulate = Color(1, 1, 1, 1.0) if known else Color(1, 1, 1, 0.35)
				play.add_child(art)
			var many := UiKit.title("x%d" % int(need.get("count", 1)), 16,
				Color(0.4, 0.38, 0.34) if known else Color(0.62, 0.60, 0.56))
			many.position = Vector2(x + 28.0, y + 20.0)
			many.size = Vector2(34.0, 20.0)
			play.add_child(many)
			x += 66.0

		var dish := UiKit.title(I18n.t(str(recipe.get("name_key", ""))) if known
			else "?", UiKit.TYPE_BODY,
			Color(0.30, 0.28, 0.24) if known else Color(0.62, 0.60, 0.56))
		dish.position = Vector2(row.position.x + row.size.x - 220.0, y + 12.0)
		dish.size = Vector2(200.0, 32.0)
		dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		play.add_child(dish)
		y += 62.0
