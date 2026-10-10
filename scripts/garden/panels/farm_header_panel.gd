extends "res://scripts/garden/panels/farm_panel_base.gd"
## The garden's compact, non-modal top lane and its harvest-challenge shortcut.
## Screen flow and state stay on GardenScreen; this component owns the HUD's
## geometry, artwork, and control construction.

const HarvestCrops := preload("res://scripts/harvest/harvest_crops.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")

const INSET := 20.0
const GAP := 12.0
const BACK_BOX := Vector2(64.0, 60.0)
const LEVEL_BOX := Vector2(102.0, 54.0)
const CHALLENGE_BOX := Vector2(88.0, 48.0)
const CHOOSER_BOX := Vector2(48.0, 48.0)
const PURSE_BOX := Vector2(126.0, 54.0)
const CARD_Y := 4.0


func build(view: Vector2, bar_height: float) -> void:
	# A fixed, pale strip prevents the moving farm from reaching the text. It is
	# deliberately flat: facts should read as one calm sentence above the farm,
	# not five raised cards competing with the island below.
	var strip := Panel.new()
	strip.name = "GardenTopBar"
	var strip_style := _surface(Color(0.99, 0.98, 0.93), 0,
		Color(0.53, 0.70, 0.42, 0.42), 0, 20)
	strip_style.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", strip_style)
	strip.position = Vector2.ZERO
	strip.custom_minimum_size = Vector2(view.x, bar_height)
	strip.size = Vector2(view.x, bar_height)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(strip)

	var back := UiKit.back_button(func(): screen.call("_one_step_back"), BACK_BOX)
	back.name = "GardenBack"
	back.position = Vector2(INSET, CARD_Y)
	play.add_child(back)

	# The farm is already recognisable from its map. Keep this compact lane
	# for controls and progress instead of repeating its large screen title.
	var badge := Panel.new()
	badge.name = "FarmLevelBadge"
	badge.add_theme_stylebox_override("panel", _surface(
		Color(0.99, 0.96, 0.86, 0.72), 18,
		Color(0.82, 0.68, 0.35, 0.38), 1, 20))
	badge.position = Vector2(INSET + BACK_BOX.x + GAP, 7.0)
	badge.custom_minimum_size = LEVEL_BOX
	badge.size = LEVEL_BOX
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var level_star := UiKit.picture("star", 28.0)
	if level_star != null:
		level_star.name = "FarmLevelIcon"
		level_star.position = Vector2(12.0, 8.0)
		badge.add_child(level_star)
	var level_tag := UiKit.title(str(Level.level()), 24)
	level_tag.name = "FarmLevelValue"
	level_tag.position = Vector2(47.0, 3.0)
	level_tag.size = Vector2(42.0, 32.0)
	level_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(level_tag)
	var rail := Panel.new()
	rail.name = "FarmLevelRail"
	rail.add_theme_stylebox_override("panel", UiKit.track_style())
	rail.position = Vector2(11.0, 42.0)
	rail.size = Vector2(80.0, 7.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(rail)
	var fill := Panel.new()
	fill.name = "FarmLevelFill"
	fill.add_theme_stylebox_override("panel",
		UiKit.fill_style(Color(1.0, 0.78, 0.22)))
	fill.position = rail.position + Vector2(2.0, 2.0)
	fill.size = Vector2(76.0 * Level.progress(), 3.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(fill)
	play.add_child(badge)

	_challenge_door(view)
	_build_purse(view)


func _build_purse(view: Vector2) -> void:
	# The purse stays read-only on this screen. A compact card keeps the number
	# familiar without letting its empty white area compete with the challenge.
	var purse := Panel.new()
	purse.name = "FarmCoinPurse"
	purse.add_theme_stylebox_override("panel", _surface(
		Color(1.0, 0.98, 0.90, 0.72), 18,
		Color(0.83, 0.70, 0.39, 0.38), 1, 20))
	purse.position = _purse_at(view)
	purse.custom_minimum_size = PURSE_BOX
	purse.size = PURSE_BOX
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := UiKit.picture("star_coin", 28.0)
	if coin != null:
		coin.name = "FarmCoinIcon"
		coin.position = Vector2(11.0, 13.0)
		purse.add_child(coin)
	var amount := UiKit.title(str(Coins.balance()), 24)
	amount.name = "FarmCoinValue"
	amount.position = Vector2(45.0, 8.0)
	amount.size = Vector2(72.0, 36.0)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.clip_text = true
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(amount)
	play.add_child(purse)


func _purse_at(view: Vector2) -> Vector2:
	return Vector2(view.x - INSET - PURSE_BOX.x, CARD_Y)


func _challenge_at(view: Vector2) -> Vector2:
	return _purse_at(view) - Vector2(
		GAP * 2.0 + CHALLENGE_BOX.x + CHOOSER_BOX.x, -6.0)


func _challenge_door(view: Vector2) -> void:
	var levels: Array = GameData.get_levels_for_mode("harvest")
	if levels.is_empty():
		return
	var next: Dictionary = levels[levels.size() - 1]
	var done := 0
	for level in levels:
		var id := str(level.get("id", ""))
		if int(SaveManager.get_level_progress(id).get("stars", 0)) > 0:
			done += 1
		else:
			next = level
			break

	# One warm side-quest chip, distinct from the tool dock and the gold
	# next-step ribbon. It shares the header's low-relief material so it reads
	# as useful context, not a second primary action.
	var door := Panel.new()
	door.name = "HarvestChallenge"
	door.add_theme_stylebox_override("panel", _surface(
		Color(0.98, 0.94, 0.78, 0.72), 18,
		Color(0.75, 0.58, 0.28, 0.38), 1, 20))
	door.custom_minimum_size = CHALLENGE_BOX
	door.size = CHALLENGE_BOX
	door.position = _challenge_at(view)
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(door)

	var play_icon := Control.new()
	play_icon.name = "ChallengePlayIcon"
	play_icon.position = Vector2(58.0, 8.0)
	play_icon.size = Vector2(12.0, 12.0)
	play_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Shapes.fill(play_icon, PackedVector2Array([
		Vector2.ZERO, Vector2(0.0, 12.0), Vector2(11.0, 6.0)]),
		Color(0.42, 0.48, 0.24), 0.0)
	door.add_child(play_icon)
	var count := UiKit.title("%d/%d" % [done, levels.size()], 13,
		Color(0.34, 0.27, 0.17))
	count.name = "ChallengeCount"
	count.position = Vector2(44.0, 25.0)
	count.size = Vector2(40.0, 18.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door.add_child(count)

	var press := Button.new()
	press.name = "HarvestChallengeShortcut"
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = Vector2.ZERO
	press.size = CHALLENGE_BOX
	press.custom_minimum_size = CHALLENGE_BOX
	press.tooltip_text = I18n.t("garden.harvest_challenge")
	var go := str(next.get("id", ""))
	press.pressed.connect(func(): GameManager.start_level(go))
	# Keep the hit target inside the animated card so its bounds follow every
	# breathing-scale frame instead of drifting away from the visible surface.
	door.add_child(press)

	var choose: Button = screen.call("_chip_button", "",
		Color(0.97, 0.91, 0.68), CHOOSER_BOX)
	choose.name = "HarvestChallengeChooser"
	choose.tooltip_text = I18n.t("garden.choose_challenge")
	choose.position = door.position + Vector2(CHALLENGE_BOX.x + GAP, 0.0)
	var grid := Control.new()
	grid.name = "ChallengeChooserIcon"
	grid.position = Vector2(13.0, 13.0)
	grid.size = Vector2(22.0, 22.0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in range(4):
		var cell := Panel.new()
		cell.position = Vector2((index % 2) * 13.0, (index / 2) * 13.0)
		cell.size = Vector2(9.0, 9.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_stylebox_override("panel", _surface(
			Color(0.48, 0.38, 0.22), 2, Color.TRANSPARENT, 0, 0))
		grid.add_child(cell)
	choose.add_child(grid)
	choose.pressed.connect(func(): screen.call("_open_panel", "challenges"))
	play.add_child(choose)

	# The next crop sits beside the challenge tally, inside the header on both
	# shapes. It no longer needs a separate card over the player's map.
	var preview := Control.new()
	preview.name = "ChallengeNext"
	preview.position = Vector2(6.0, 8.0)
	preview.custom_minimum_size = Vector2(32.0, 32.0)
	preview.size = Vector2(32.0, 32.0)
	# A look, not a button: the door above is the way in, and this card must
	# never eat a tap meant for the bed underneath it.
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shows := "star"
	var art_ref := "star"
	if done < levels.size():
		var targets: Array = (next.get("config", {}) as Dictionary).get("targets", [])
		if not targets.is_empty():
			var crop: Dictionary = HarvestCrops.get_crop(
				str(targets[0].get("crop_id", "")))
			if not crop.is_empty():
				art_ref = str(crop.get("asset", ""))
				shows = str(crop.get("id", ""))
	var art: Control
	if shows != "star":
		art = screen.call("_crop_picture", shows, 32.0)
	else:
		art = UiKit.picture(art_ref, 32.0)
	preview.set_meta("shows", shows)
	if art != null:
		preview.add_child(art)
	door.add_child(preview)
	var task: Dictionary = screen.call("_next_task")
	if not bool(screen.get("_lesson_running")) \
			and not bool(task.get("actionable", false)):
		UiKit.breathe(door, 0.018, 1.3)


func _surface(fill: Color, radius: int, edge: Color,
		edge_width: int, content_margin: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = screen.call("_quiet_surface_style", fill,
		radius, edge, edge_width, content_margin)
	return style
