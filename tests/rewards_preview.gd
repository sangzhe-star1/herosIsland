extends Node
## Renders the Reward Centre with some progress already made, because on a
## fresh save every badge is locked and the earned state is never seen.
## Nothing is written to disk: only the in-memory save is touched.
## SHOT_WIN uses the real game aspect; without it the legacy tall sheet remains.
## SHOT_BADGE_ROW selects a real HFlow row after layout, not a cloned badge wall.
## SHOT_ALL_BADGES_EARNED=1 covers every real caption; SHOT_SECTION selects
## stickers or growth on the production page after its layout has settled.

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

var _failures: Array[String] = []
var _asked := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("RewardsPreview requires a rendered window")
		print("REWARDS PREVIEW FAILED")
		await ProbeLifecycle.finish(self, 1)
		return
	SaveManager.data["rewards"]["coins"] = 250
	SaveManager.data["rewards"]["badges"] = [
		"road_guardian", "sharp_eyes", "energy_collector", "color_expert",
		"tracker", "night_walker", "monster_friend",
	]
	if OS.get_environment("SHOT_ALL_BADGES_EARNED") == "1":
		SaveManager.data["rewards"]["badges"] = (GameData.rewards.get("badges", {}) as Dictionary).keys()
	SaveManager.data["rewards"]["stickers"] = ["star", "heart", "paw"]
	for pair in [["courage", 18], ["wisdom", 11], ["kindness", 24],
			["focus", 7], ["safety", 15]]:
		SaveManager.data["growth"][str(pair[0])] = int(pair[1])
	# A tall window so the whole scrolling page is captured at once; the
	# screen itself is still laid out for 1280x720.
	var window := get_window()
	if window != null:
		var requested := OS.get_environment("SHOT_WIN")
		if requested == "":
			window.size = Vector2i(1280, 2150)
			window.content_scale_size = Vector2i(1280, 2150)
		else:
			var parts := requested.split("x")
			if parts.size() == 2 and int(parts[0]) > 0 and int(parts[1]) > 0:
				window.size = Vector2i(int(parts[0]), int(parts[1]))
			else:
				_failures.append("invalid SHOT_WIN")
	var scene: Control = load("res://scenes/reward/RewardCenter.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.6).timeout
	if OS.get_environment("SHOT_ALL_BADGES_EARNED") == "1":
		_validate_badge_captions(scene)
	var section := OS.get_environment("SHOT_SECTION")
	if not section.is_empty():
		var scroll := _find_scroll(scene)
		_check(scroll != null, "the real rewards page has a scroll container")
		var target: Control
		if section == "stickers":
			target = scene.get("_sticker_row") as Control
		elif section == "growth":
			var bars := _growth_bars(scene)
			if not bars.is_empty():
				# The production card owns the heading, all five rows and padding.
				target = bars[0].get_parent().get_parent().get_parent() as Control
		else:
			_failures.append("invalid SHOT_SECTION")
		_check(target != null, "the requested real section exists")
		if target != null and scroll != null:
			await _scroll_to(scroll, target.get_global_rect().position.y)
			if section == "stickers":
				_validate_stickers(scene, scroll)
			elif section == "growth":
				_validate_growth(scene, scroll)
	var requested_row := OS.get_environment("SHOT_BADGE_ROW")
	if requested_row != "":
		var tiles := _badge_tiles(scene)
		_check(tiles.size() == (GameData.rewards.get("badges", {}) as Dictionary).size(),
			"the real badge wall contains the whole catalogue")
		var scroll := _find_scroll(scene)
		_check(scroll != null, "the real rewards page has a scroll container")
		var row_tops: Array[int] = []
		for tile in tiles:
			var top := roundi(tile.get_global_rect().position.y)
			if top not in row_tops:
				row_tops.append(top)
		row_tops.sort()
		print("REWARD BADGE ROWS ", row_tops.size(), " / tiles ", tiles.size())
		var row := int(requested_row)
		_check(requested_row.is_valid_int() and row >= 0 and row < row_tops.size(),
			"SHOT_BADGE_ROW selects an existing row")
		if scroll != null and row >= 0 and row < row_tops.size():
			scroll.scroll_vertical = roundi(float(row_tops[row]) - scroll.get_global_rect().position.y)
			await get_tree().process_frame
			await get_tree().process_frame
			_check(get_viewport().get_visible_rect().encloses(scroll.get_global_rect()),
				"the rewards scroll area stays inside the viewport")
	# Static scrolled pages may not produce another automatic draw. Capture
	# explicitly on the main thread after layout; no gameplay time is advanced.
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	_check(ProbeLifecycle.image_has_content(image), "rewards screenshot contains rendered content")
	var saved := image.save_png(OS.get_environment("SHOT_PATH"))
	print("rewards_preview -> ", error_string(saved))
	_check(saved == OK, "rewards PNG was saved")
	for failure in _failures:
		print("FAIL ", failure)
	print("asked %d questions" % _asked)
	print("REWARDS PREVIEW ", "PASSED" if _failures.is_empty() else "FAILED")
	await ProbeLifecycle.finish(self, 0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_asked += 1
	if not condition:
		_failures.append(message)


func _scroll_to(scroll: ScrollContainer, content_y: float) -> void:
	scroll.scroll_vertical += roundi(content_y - scroll.get_global_rect().position.y)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_viewport().get_visible_rect().encloses(scroll.get_global_rect()),
		"the rewards scroll area stays inside the viewport")


func _validate_badge_captions(scene: Node) -> void:
	var tiles := _badge_tiles(scene)
	var catalogue: Dictionary = GameData.rewards.get("badges", {})
	var ids := catalogue.keys()
	_check(tiles.size() == ids.size(), "the earned wall contains every badge")
	for index in range(mini(tiles.size(), ids.size())):
		var caption: Label
		for child in tiles[index].get_children():
			if child is Label:
				caption = child as Label
		_check(caption != null, "the badge has a real caption: " + str(ids[index]))
		if caption == null:
			continue
		_check(caption.text == RewardManager.badge_name(str(ids[index])) and not caption.text.is_empty(),
			"every earned badge shows its configured translated name")
		_check(tiles[index].get_global_rect().encloses(caption.get_global_rect()),
			"the earned caption stays inside its tile")
		var line_height := caption.get_theme_font("font").get_height(caption.get_theme_font_size("font_size"))
		_check(caption.get_line_count() * line_height <= caption.size.y + 0.5,
			"all wrapped caption lines fit their reserved height")
	print("REWARD EARNED CAPTIONS ", tiles.size())


func _validate_stickers(scene: Node, scroll: ScrollContainer) -> void:
	var row := scene.get("_sticker_row") as HFlowContainer
	var entries: Array = GameData.rewards.get("stickers", [])
	_check(row != null and row.get_child_count() == entries.size(), "all real sticker tiles exist")
	if row == null:
		return
	for index in range(mini(row.get_child_count(), entries.size())):
		var tile := row.get_child(index) as Control
		var entry: Dictionary = entries[index]
		var owned := SaveManager.has_sticker(str(entry.get("id", "")))
		_check(scroll.get_global_rect().encloses(tile.get_global_rect()), "the whole sticker tile is visible")
		var price: HBoxContainer
		var picture: Control
		for child in tile.get_children():
			if child is HBoxContainer:
				price = child as HBoxContainer
			elif child is Control:
				picture = child as Control
		_check(picture != null, "the sticker has its real picture")
		_check((price == null) == owned, "only unowned stickers show a price")
		if price != null:
			_check(tile.get_global_rect().encloses(price.get_global_rect()), "the sticker price fits its tile")
			var amount := price.get_child(price.get_child_count() - 1) as Label
			_check(amount != null and amount.text == str(int(entry.get("cost", 10))), "the price matches catalogue data")
	print("REWARD STICKERS ", entries.size())


func _growth_bars(node: Node) -> Array[ProgressBar]:
	var found: Array[ProgressBar] = []
	for child in node.get_children():
		if child is ProgressBar:
			found.append(child as ProgressBar)
		found.append_array(_growth_bars(child))
	return found


func _validate_growth(scene: Node, scroll: ScrollContainer) -> void:
	var bars := _growth_bars(scene)
	var entries: Array = GameData.rewards.get("growth_attributes", [])
	_check(bars.size() == entries.size(), "all configured growth bars exist")
	for index in range(mini(bars.size(), entries.size())):
		var bar: ProgressBar = bars[index]
		var entry: Dictionary = entries[index]
		var expected := mini(int(SaveManager.data["growth"].get(str(entry.get("id", "")), 0)), 30)
		_check(is_equal_approx(bar.value, float(expected)), "growth bar uses the real saved attribute")
		var row := bar.get_parent() as Control
		_check(scroll.get_global_rect().encloses(row.get_global_rect()), "the whole growth row is visible")
		for child in row.get_children():
			if child is Control:
				_check(row.get_global_rect().encloses((child as Control).get_global_rect()),
					"growth icon, name and bar remain inside the row")
	print("REWARD GROWTH BARS ", bars.size())


func _badge_tiles(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in node.get_children():
		if child is Button and child.custom_minimum_size == Vector2(168, 208):
			found.append(child as Control)
		found.append_array(_badge_tiles(child))
	return found


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node as ScrollContainer
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null
