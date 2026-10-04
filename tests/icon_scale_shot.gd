extends Node
## Existing production glyphs, rendered at review and actual caller sizes.
## This sheet does not replace in-context state or whole-page acceptance.

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const SIZES := [48, 72, 96]
const PAGES := [
	{"id": "rewards", "rows": [
		{"label": "HUD money", "icon": "star_coin", "native": 28},
		{"label": "Market money", "icon": "star_coin", "native": 14},
		{"label": "Farm level", "icon": "star", "native": 28},
		{"label": "Result earned", "star": true, "native": 96},
		{"label": "Result unearned", "star": false, "native": 96},
	]},
	{"id": "feedback", "rows": [
		{"label": "Order complete", "icon": "check", "native": 32},
		{"label": "Customer thanks", "icon": "heart", "native": 40},
		{"label": "Reward heading", "icon": "medal", "native": 40},
		{"label": "Barn material", "icon": "plank", "native": 34},
	]},
	{"id": "tools_a", "rows": [
		{"label": "Point", "icon": "tap", "native": 44},
		{"label": "Till", "icon": "shovel", "native": 44},
		{"label": "Seed", "icon": "seed", "native": 44},
		{"label": "Water", "icon": "watering_can", "native": 44},
		{"label": "Weed", "icon": "weed", "native": 44},
	]},
	{"id": "tools_b", "rows": [
		{"label": "Shoo", "icon": "fan", "native": 44},
		{"label": "Harvest", "icon": "basket", "native": 44},
	]},
	{"id": "plot_status", "rows": [
		{"label": "Empty soil", "plot": {"state": Farm.EMPTY}, "native": 61},
		{"label": "Ready harvest", "plot": {"state": Farm.READY}, "native": 61},
		{"label": "Needs water", "plot": {"state": Farm.NEEDS_CARE,
			"care_event": Growth.CARE_THIRSTY}, "native": 61},
		{"label": "Needs weeding", "plot": {"state": Farm.NEEDS_CARE,
			"care_event": Growth.CARE_WEEDS}, "native": 61},
		{"label": "Needs bug care", "plot": {"state": Farm.NEEDS_CARE,
			"care_event": Growth.CARE_BUG}, "native": 61},
	]},
]

var _failures: Array[String] = []
var _asked := 0
var _page_regions: Array[Dictionary] = []
var _region_checks := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("IconScaleShot requires a rendered window")
		print("ICON SCALE SHOT FAILED")
		await ProbeLifecycle.finish(self, 1)
		return
	var window := OS.get_environment("SHOT_WIN")
	if window != "":
		var parts := window.split("x")
		if parts.size() != 2 or int(parts[0]) <= 0 or int(parts[1]) <= 0:
			_failures.append("invalid SHOT_WIN")
		else:
			DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	await get_tree().process_frame
	await get_tree().process_frame
	var output_dir := OS.get_environment("SHOT_DIR")
	if output_dir == "" or not output_dir.is_absolute_path():
		_failures.append("SHOT_DIR must be an explicit absolute QA output directory")
	else:
		var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
		if mkdir_error != OK:
			_failures.append("cannot create SHOT_DIR: " + error_string(mkdir_error))
	if _failures.is_empty():
		for page in PAGES:
			var sheet := _make_sheet(page)
			add_child(sheet)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var output := output_dir.path_join(str(page["id"]) + ".png")
			var image := get_viewport().get_texture().get_image()
			_asked += 1
			if not ProbeLifecycle.image_has_content(image):
				_failures.append("rendered page has no content: " + str(page["id"]))
			if image != null and not image.is_empty() and image.get_width() > 8 and image.get_height() > 8:
				var background := image.get_pixel(8, 8)
				for sample in _page_regions:
					var glyph := sample["glyph"] as Control
					var region := ProbeLifecycle.image_region(get_viewport(), image, glyph.get_global_rect())
					var pixels := ProbeLifecycle.contrasting_pixels(image, region, background)
					_asked += 1
					_region_checks += 1
					if pixels < 8:
						_failures.append("rendered glyph is empty: " + str(sample["id"]))
			# Keep a failed but readable image for diagnosis as well.
			var save_error := image.save_png(output) if image != null and not image.is_empty() else ERR_INVALID_DATA
			_asked += 1
			if save_error != OK:
				_failures.append(output + ": " + error_string(save_error))
			print("ICON SCALE SHOT ", output, " -> ", error_string(save_error))
			sheet.queue_free()
			await get_tree().process_frame
	var expected_regions := 0
	for page in PAGES:
		expected_regions += (page["rows"] as Array).size() * 4
	_asked += 1
	if _region_checks != expected_regions:
		_failures.append("rendered glyph checks differ: %d, expected %d" % [_region_checks, expected_regions])
	for failure in _failures:
		print("FAIL ", failure)
	print("ICON RENDERED REGIONS ", _region_checks, " / ", expected_regions)
	print("asked %d questions" % _asked)
	print("ICON SCALE SHOT ", "PASSED" if _failures.is_empty() else "FAILED")
	await ProbeLifecycle.finish(self, 0 if _failures.is_empty() else 1)


func _make_sheet(page: Dictionary) -> Control:
	_page_regions.clear()
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.background(root, Palette.SURFACE)
	var title := UiKit.title("QA glyph sizes / " + str(page["id"]), 26)
	title.position = Vector2(24, 10)
	root.add_child(title)
	var view := get_viewport().get_visible_rect().size
	var physical := DisplayServer.window_get_size()
	var factor := float(physical.x) / view.x
	var subtitle := UiKit.title("Logical px; screenshot scale %.2f. Native = existing caller size." % factor, 18)
	subtitle.position = Vector2(24, 44)
	root.add_child(subtitle)
	var column_x := [350.0, 580.0, 810.0, 1040.0]
	for column in range(4):
		var heading := UiKit.title(str(SIZES[column]) if column < 3 else "Native", 22)
		heading.position = Vector2(column_x[column], 80.0)
		root.add_child(heading)
	var rows: Array = page["rows"]
	for row_index in range(rows.size()):
		var spec: Dictionary = rows[row_index]
		var y := 166.0 + row_index * 114.0
		var label := UiKit.title(str(spec["label"]) + " / " + str(spec["native"]), 20)
		label.position = Vector2(24, y - 12)
		root.add_child(label)
		for column in range(4):
			var pixels: int = int(SIZES[column]) if column < 3 else int(spec["native"])
			var glyph := _glyph(spec, pixels)
			_asked += 1
			if glyph == null:
				_failures.append("missing glyph: " + str(spec["label"]))
				continue
			if str(spec.get("icon", "")) == "star_coin":
				_asked += 1
				var expected_children := 4 if pixels <= 32 else 9
				if glyph.get_child_count() != expected_children:
					_failures.append("star coin detail did not match size %d" % pixels)
			glyph.name = "%s_%d" % [str(page["id"]), _asked]
			glyph.size = Vector2.ONE * pixels
			glyph.position = Vector2(column_x[column] + 28, y) - Vector2.ONE * pixels * 0.5
			root.add_child(glyph)
			_page_regions.append({"id": "%s:%s:%d:%d" % [str(page["id"]), str(spec["label"]), pixels, column],
				"glyph": glyph})
	return root


func _glyph(spec: Dictionary, pixels: int) -> Control:
	if spec.has("star"):
		return UiKit.star(bool(spec["star"]), pixels)
	if not spec.has("plot"):
		return UiKit.picture(str(spec["icon"]), float(pixels))
	# Extract the existing badge after asking PlotView to draw the real state.
	# No copy of its icon mapping, fill/rim colours or care rules lives here.
	var plot := PlotView.new()
	plot.setup(0)
	plot.call("_draw_badge", spec["plot"])
	var badge := plot.get("_badge") as Node2D
	if badge == null:
		plot.free()
		return null
	badge.get_parent().remove_child(badge)
	plot.free()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * pixels
	badge.position = Vector2.ONE * pixels * 0.5
	badge.scale = Vector2.ONE * float(pixels) / 61.0
	holder.add_child(badge)
	return holder
