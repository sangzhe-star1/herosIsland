extends Node
## Runtime import/size bench; this is not an extra gameplay page.
const Art := preload("res://scripts/harvest/harvest_visual_art.gd")
const Lifecycle := preload("res://tests/probe_lifecycle.gd")

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var size := float(OS.get_environment("SHOT_BADGE_SIZE"))
	if size <= 0.0:
		size = 72.0
	# 24/32覆盖篮标的小图，48/72/96保留订单与场内审图档位。
	if size not in [24.0, 32.0, 48.0, 72.0, 96.0]:
		push_error("catalog badge size must be native 24, 32, 48, 72 or 96 pixels")
		await Lifecycle.finish(self, 1)
		return
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.91, 0.94, 0.86)
	backdrop.size = Vector2(1280, 720)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var title := Label.new()
	title.text = "Runtime crop_badge imports: %d px / 17 source assets" % int(size)
	title.position = Vector2(32, 18)
	title.add_theme_color_override("font_color", Color(0.15, 0.2, 0.15))
	add_child(title)
	var failed := false
	var cells: Array[Dictionary] = []
	for i in range(Art.CROP_IDS.size()):
		var id: String = Art.CROP_IDS[i]
		var texture := Art.crop_texture(id)
		var badge := Art.crop_badge(id, size)
		if texture == null or badge == null:
			push_error("missing imported catalog artwork: " + id)
			failed = true
			continue
		var cell := Vector2(40 + (i % 6) * 205, 78 + (i / 6) * 205)
		badge.position = cell + Vector2((170 - size) * 0.5, (132 - size) * 0.5)
		add_child(badge)
		cells.append({"id": id, "badge": badge})
		var label := Label.new()
		label.text = id
		label.position = cell + Vector2(12, 146)
		label.add_theme_color_override("font_color", Color(0.15, 0.2, 0.15))
		add_child(label)
	# Control/Sprite 子节点刚挂树时，force_draw 不保证布局和Canvas已提交。
	# 等节点注册与布局提交，再强制绘制。frame_post_draw 在独立截图探针里
	# 可能不发信号；不把等待该信号当作 Canvas 已注册的证明。
	for _frame in range(3):
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var captured := get_viewport().get_texture().get_image()
	if not Lifecycle.image_has_content(captured) or cells.size() != Art.CROP_IDS.size():
		push_error("catalog capture is blank or missing badge cells")
		failed = true
	if captured == null or captured.is_empty():
		print("HARVEST CATALOG SHOT FAILED")
		await Lifecycle.finish(self, 1)
		return
	var background := captured.get_pixel(8, 8)
	for cell in cells:
		var badge: Control = cell["badge"]
		var region := Lifecycle.image_region(get_viewport(), captured,
			Rect2(badge.global_position, badge.size))
		if badge.size != Vector2.ONE * size or region.size != Vector2i.ONE * int(size):
			push_error("catalog badge did not retain native pixel size: " + str(cell["id"]))
			failed = true
		var visible_pixels := 0
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var pixel := captured.get_pixel(x, y)
				var contrast := absf(pixel.r - background.r) \
					+ absf(pixel.g - background.g) + absf(pixel.b - background.b)
				if contrast > 0.15:
					visible_pixels += 1
		if visible_pixels < 8:
			push_error("catalog cell rendered empty: " + str(cell["id"]))
			failed = true
		print("CATALOG CELL ", cell["id"], " visible_pixels=", visible_pixels)
	var err := captured.save_png(OS.get_environment("SHOT_PATH"))
	print("HARVEST CATALOG SHOT ", "PASSED" if not failed and err == OK else "FAILED")
	await Lifecycle.finish(self, 1 if failed or err != OK else 0)
