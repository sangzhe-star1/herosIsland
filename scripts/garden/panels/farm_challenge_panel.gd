extends "res://scripts/garden/panels/farm_panel_base.gd"
## Challenge level sheet: replaying harvest challenge levels.

const ROWS := 4


func build(view: Vector2) -> void:
	var levels: Array = GameData.get_levels_for_mode("harvest")
	var pages := maxi(1, int(ceil(float(levels.size()) / ROWS)))
	var page := clampi(int(screen.get("_challenge_page")), 0, pages - 1)
	screen.set("_challenge_page", page)

	var wide := 620.0
	var tall := 410.0
	var origin: Vector2 = screen.call("_panel_sheet", view, "garden.challenge_levels", wide, tall)
	for slot in range(ROWS):
		var index := page * ROWS + slot
		if index >= levels.size():
			break
		var level: Dictionary = levels[index]
		var level_id := str(level.get("id", ""))
		var stars := clampi(int(SaveManager.get_level_progress(level_id).get("stars", 0)), 0, 3)
		var row := chip_button("", Color(1.0, 0.99, 0.94), Vector2(wide - 56.0, 64.0))
		row.name = "ChallengeLevel_%s" % level_id
		row.position = origin + Vector2(28.0, 68.0 + slot * 74.0)
		row.set_meta("stars", stars)
		row.pressed.connect(func(): GameManager.start_level(level_id))
		play.add_child(row)
		var number := UiKit.title("%02d" % (index + 1), 24, Color(0.62, 0.43, 0.18))
		number.position = Vector2(12.0, 14.0)
		number.size = Vector2(42.0, 36.0)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(number)
		var title := UiKit.title(I18n.t(str(level.get("name_key", ""))), 22)
		title.name = "ChallengeLevelName"
		title.position = Vector2(64.0, 14.0)
		title.size = Vector2(340.0, 36.0)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		for star_index in range(3):
			var star := UiKit.picture("star", 24.0)
			if star != null:
				star.position = Vector2(wide - 150.0 + star_index * 27.0 - 56.0, 20.0)
				star.modulate = Color.WHITE if star_index < stars else Color(0.65, 0.64, 0.58, 0.38)
				star.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(star)
	var page_label := UiKit.title(I18n.t("garden.challenge_page")
		.replace("{page}", str(page + 1)).replace("{pages}", str(pages)), 18)
	page_label.position = origin + Vector2(28.0, tall - 38.0)
	page_label.size = Vector2(wide - 56.0, 26.0)
	page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(page_label)
	screen.call("_pager", origin, wide, tall, page, pages, func(step: int):
		screen.set("_challenge_page", clampi(int(screen.get("_challenge_page")) + step, 0, pages - 1))
		screen.call("_queue_rebuild"))
