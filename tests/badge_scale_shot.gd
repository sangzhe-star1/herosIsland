extends Node
## A QA contact sheet using the production badge builder and picture resolver.
## SHOT_DIR must be an explicit absolute directory. Requires a rendered window.
## Medal columns scale the complete production art; glyph columns rebuild the
## production icon at each requested size. Neither route grants any rewards.

const RewardsScene := preload("res://scenes/reward/RewardCenter.tscn")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")
const PAGE := Vector2i(1240, 1080)
const ROWS := 4
const MEDAL_WIDTHS := [48.0, 72.0, 96.0, 168.0]
const GLYPH_SIZES := [48.0, 72.0, 96.0, 62.0]
const NATIVE_TILE := Vector2(168, 208)
const NATIVE_MEDAL := Vector2(168, 132)

var _factory: Control
var _shot_dir := ""
var _badges: Dictionary = {}
var _ids: Array = []
var _failures: Array[String] = []
var _medal_coverage: Dictionary = {}
var _glyph_coverage: Dictionary = {}
var _files: Array[String] = []
var _medal_samples := 0
var _glyph_samples := 0
var _region_checks := 0


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	_ok(not _shot_dir.is_empty() and _shot_dir.is_absolute_path(),
		"SHOT_DIR must be an explicit absolute path")
	_ok(DisplayServer.get_name() != "headless", "Use a rendered window, not --headless")
	if not _failures.is_empty():
		await _finish()
		return
	_ok(DirAccess.make_dir_recursive_absolute(_shot_dir) == OK, "Cannot create SHOT_DIR")
	_badges = GameData.rewards.get("badges", {})
	_ids = _badges.keys()
	_ok(not _ids.is_empty(), "The production badge catalogue is empty")
	if not _failures.is_empty():
		await _finish()
		return
	# Keep this factory detached: its _ready builds the full reward/shop page.
	# Only the actual production _build_badge method is needed for this sheet.
	_factory = RewardsScene.instantiate() as Control
	_ok(_factory.has_method("_build_badge"), "Production badge builder is missing")
	if not _failures.is_empty():
		await _finish()
		return
	var states: Array[Dictionary] = []
	for badge_id in _ids:
		for earned in [true, false]:
			states.append({"id": str(badge_id), "earned": earned})
	await _medal_pages(states)
	await _glyph_pages()
	for badge_id in _ids:
		for earned in [true, false]:
			var key := _state_key(str(badge_id), earned)
			_ok(int(_medal_coverage.get(key, 0)) == MEDAL_WIDTHS.size(),
				"Missing medal scales for %s" % key)
		_ok(int(_glyph_coverage.get(str(badge_id), 0)) == GLYPH_SIZES.size(),
			"Missing glyph scales for %s" % badge_id)
	_ok(_medal_samples == _ids.size() * 2 * MEDAL_WIDTHS.size(), "Medal sample count differs")
	_ok(_glyph_samples == _ids.size() * GLYPH_SIZES.size(), "Glyph sample count differs")
	_ok(_region_checks == _ids.size() * (2 * MEDAL_WIDTHS.size() + GLYPH_SIZES.size()),
		"Not all medal and glyph visual regions were checked")
	var expected_files := ceili(float(states.size()) / ROWS) + ceili(float(_ids.size()) / ROWS)
	_ok(_files.size() == expected_files, "Not all PNG pages were saved")
	_write_manifest()
	await _finish()


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _state_key(badge_id: String, earned: bool) -> String:
	return badge_id + (":earned" if earned else ":locked")


func _label(parent: Control, text: String, at: Vector2, box: Vector2,
		font_size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = box
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.INK)
	parent.add_child(label)


func _new_page(title: String, columns: Array) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = PAGE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var page := Control.new()
	page.size = Vector2(PAGE)
	viewport.add_child(page)
	var background := ColorRect.new()
	background.color = Color(0.98, 0.97, 0.94)
	background.size = Vector2(PAGE)
	page.add_child(background)
	_label(page, title, Vector2(20, 10), Vector2(1200, 45), 22)
	for column in range(columns.size()):
		_label(page, str(columns[column]), Vector2(240 + column * 240, 60), Vector2(230, 36))
	return viewport


func _medal_pages(states: Array[Dictionary]) -> void:
	var count := ceili(float(states.size()) / ROWS)
	for page_index in range(count):
		var viewport := _new_page("Production medals: whole art scaled by native width 168; caption hidden only in QA",
			["48 px medal", "72 px medal", "96 px medal", "Native 168; inner icon 62"])
		var page := viewport.get_child(0) as Control
		var regions: Array[Dictionary] = []
		for row in range(ROWS):
			var index: int = page_index * ROWS + row
			if index >= states.size():
				break
			var badge_id: String = str(states[index]["id"])
			var earned: bool = bool(states[index]["earned"])
			var row_y: float = 110.0 + row * 236.0
			_label(page, badge_id + "\n" + ("Earned / 已解锁" if earned else "Locked / 未解锁")
				+ "\nicon: " + str(_badges[badge_id].get("icon", "star")),
				Vector2(20, row_y + 55), Vector2(210, 130))
			for column in range(MEDAL_WIDTHS.size()):
				var tile := _factory.call("_build_badge", badge_id, _badges[badge_id], earned) as Control
				_ok(tile != null, "Badge builder returned null for %s" % badge_id)
				if tile == null:
					continue
				tile.size = NATIVE_TILE
				var pictures: Array[Control] = []
				for child in tile.get_children():
					if child is Label:
						child.visible = false
					elif child is Control and child != tile.get_child(0):
						pictures.append(child)
				_ok(pictures.size() == (1 if earned else 2),
					"Production icon or lock missing for %s" % _state_key(badge_id, earned))
				if not pictures.is_empty():
					_ok(pictures[0].custom_minimum_size == Vector2(62, 62), "Native badge icon is not 62 px")
					_ok((pictures[0].modulate == Color.WHITE) if earned else (pictures[0].modulate != Color.WHITE),
						"Earned/locked icon appearance differs from production state for %s" % _state_key(badge_id, earned))
				if not earned and pictures.size() == 2:
					_ok(pictures[1].custom_minimum_size == Vector2(46, 46), "Locked badge lacks its native 46 px lock")
				var factor: float = float(MEDAL_WIDTHS[column]) / NATIVE_MEDAL.x
				# Scale the QA wrapper. The production button owns its pivot for
				# touch feedback; its resized callback must not shift this matrix.
				var holder := Node2D.new()
				holder.scale = Vector2.ONE * factor
				holder.position = Vector2(360 + column * 240, row_y + 110) - Vector2(84, 66) * factor
				page.add_child(holder)
				holder.add_child(tile)
				var key := _state_key(badge_id, earned)
				_medal_coverage[key] = int(_medal_coverage.get(key, 0)) + 1
				_medal_samples += 1
				regions.append({"id": "%s:medal:%s" % [key, MEDAL_WIDTHS[column]],
					"control": tile, "visual_size": NATIVE_MEDAL * factor})
		await _save_page(viewport, "badges_medal_%02d.png" % (page_index + 1), regions)


func _glyph_pages() -> void:
	var count := ceili(float(_ids.size()) / ROWS)
	for page_index in range(count):
		var viewport := _new_page("Production icon resolver: each glyph rebuilt at requested pixels; not a scaled medal",
			["48 px glyph", "72 px glyph", "96 px glyph", "Native badge glyph 62"])
		var page := viewport.get_child(0) as Control
		var regions: Array[Dictionary] = []
		for row in range(ROWS):
			var index: int = page_index * ROWS + row
			if index >= _ids.size():
				break
			var badge_id: String = str(_ids[index])
			var reference: String = str(_badges[badge_id].get("icon", "star"))
			var row_y: float = 110.0 + row * 236.0
			_label(page, badge_id + "\nicon: " + reference, Vector2(20, row_y + 55), Vector2(210, 130))
			for column in range(GLYPH_SIZES.size()):
				var pixels: float = float(GLYPH_SIZES[column])
				var icon: Control = UiKit.picture(reference, pixels)
				_ok(icon != null, "Production picture is null for %s at %s px" % [badge_id, pixels])
				if icon == null:
					continue
				icon.size = Vector2.ONE * pixels
				icon.position = Vector2(360 + column * 240, row_y + 110) - Vector2.ONE * pixels * 0.5
				page.add_child(icon)
				_glyph_coverage[badge_id] = int(_glyph_coverage.get(badge_id, 0)) + 1
				_glyph_samples += 1
				regions.append({"id": "%s:glyph:%s" % [badge_id, pixels],
					"control": icon, "visual_size": Vector2.ONE * pixels})
		await _save_page(viewport, "badges_glyph_%02d.png" % (page_index + 1), regions)


func _save_page(viewport: SubViewport, filename: String, regions: Array[Dictionary]) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_ok(image != null and image.get_size() == PAGE, "Rendered page size differs for %s" % filename)
	_ok(ProbeLifecycle.image_has_content(image), "Rendered page has no content for %s" % filename)
	if image != null and not image.is_empty() and image.get_width() > 8 and image.get_height() > 8:
		var background := image.get_pixel(8, 8)
		for sample in regions:
			var control := sample["control"] as Control
			# The medal's 168x208 button includes a hidden caption. Check only
			# its scaled 168x132 artwork, so page labels cannot hide empty art.
			var rect := Rect2(control.global_position, sample["visual_size"])
			var region := ProbeLifecycle.image_region(viewport, image, rect)
			var pixels := ProbeLifecycle.contrasting_pixels(image, region, background)
			_region_checks += 1
			_ok(pixels >= 8, "Rendered visual region is empty for %s" % sample["id"])
	if image != null and not image.is_empty():
		# A nonempty image can still fail its visual checks; retain that PNG.
		var path := _shot_dir.path_join(filename)
		var saved := image.save_png(path)
		_ok(saved == OK and FileAccess.file_exists(path), "Cannot save %s: %s" % [path, error_string(saved)])
		if saved == OK and FileAccess.file_exists(path):
			_files.append(filename)
			print("badge_scale_shot -> ", path)
	viewport.queue_free()
	await get_tree().process_frame


func _write_manifest() -> void:
	var icons: Dictionary = {}
	for badge_id in _ids:
		icons[str(_badges[badge_id].get("icon", "star"))] = true
	var manifest := {
		"badge_ids": _ids, "badges": _badges, "distinct_icon_count": icons.size(),
		"isolated_subviewport": true, "caption_hidden_for_review": true,
		"layout_scope": "Fixed pixel catalogue; does not verify RewardCenter screen ratios or layout",
		"page_pixels": [PAGE.x, PAGE.y], "native_tile": [168, 208],
		"native_medal_region": [168, 132], "native_inner_glyph": 62,
		"medal_widths": MEDAL_WIDTHS, "glyph_sizes": GLYPH_SIZES,
		"medal_samples": _medal_samples, "glyph_samples": _glyph_samples,
		"rendered_region_checks": _region_checks,
		"medal_coverage": _medal_coverage, "glyph_coverage": _glyph_coverage,
		"png_files": _files, "failures": _failures,
	}
	var output := FileAccess.open(_shot_dir.path_join("badge_scale_manifest.json"), FileAccess.WRITE)
	_ok(output != null, "Cannot write badge scale manifest")
	if output != null:
		output.store_string(JSON.stringify(manifest, "\t"))
		output.close()


func _finish() -> void:
	if is_instance_valid(_factory):
		_factory.free()
	for failure in _failures:
		print("FAIL  %s" % failure)
	print("badge catalogue: %d; medal samples: %d; glyph samples: %d; PNGs: %d"
		% [_ids.size(), _medal_samples, _glyph_samples, _files.size()])
	print("BADGE RENDERED REGIONS ", _region_checks)
	print("BADGE SCALE SHOT %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	await ProbeLifecycle.finish(self, 1 if not _failures.is_empty() else 0)
