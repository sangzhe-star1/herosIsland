extends RefCounted
## Test shutdown waits for the audio server to release finished playbacks.
## Stopping during the final quit frame leaves Ogg cleanup warnings even when
## repeated playback keeps a stable resource count (Dummy and CoreAudio).

## Rendered automation injects real events through Input.parse_input_event.
## Keep the user's unrelated desktop pointer from moving a native Button's
## hover target between those presses. Synthetic mouse/touch still traverse
## the normal viewport and GUI pipeline; mixed-source tests inject both.
static func isolate_desktop_pointer(probe: Node) -> void:
	probe.get_window().unfocusable = true
	probe.get_window().mouse_passthrough = true


## Screenshot checks are explicit QA calls, never part of a product frame.
## A saved PNG may still be a uniform clear buffer. Sample the whole image
## cheaply; contact sheets also check each picture region independently.
static func image_has_content(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var size := image.get_size()
	var background := image.get_pixel(0, 0)
	var step_x := maxi(1, floori(float(size.x) / 64.0))
	var step_y := maxi(1, floori(float(size.y) / 64.0))
	var found := 0
	for y in range(0, size.y, step_y):
		for x in range(0, size.x, step_x):
			if _contrasts(image.get_pixel(x, y), background):
				found += 1
				if found >= 8:
					return true
	return false


## Map viewport coordinates to actual PNG pixels, including the 4:3 root
## viewport's 1280x960 logical area and 1024x768 window capture.
static func image_region(viewport: Viewport, image: Image, rect: Rect2) -> Rect2i:
	if viewport == null or image == null or image.is_empty() or not rect.has_area():
		return Rect2i()
	var visible := viewport.get_visible_rect()
	if not visible.has_area():
		return Rect2i()
	var scale := Vector2(image.get_size()) / visible.size
	var start := ((rect.position - visible.position) * scale).floor()
	var end := ((rect.end - visible.position) * scale).ceil()
	return Rect2i(Vector2i(start), Vector2i(end - start)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size()))


## Stop once enough pixels have been found. The result is capped at minimum,
## not total coverage or a recognition score. Use the captured background,
## so a wrong uniform clear colour cannot count as art.
static func contrasting_pixels(image: Image, region: Rect2i, background: Color,
		minimum: int = 8) -> int:
	if image == null or image.is_empty() or minimum <= 0:
		return 0
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var found := 0
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			if _contrasts(image.get_pixel(x, y), background):
				found += 1
				if found >= minimum:
					return found
	return found


static func _contrasts(pixel: Color, background: Color) -> bool:
	if pixel.a <= 0.05:
		return false
	return absf(pixel.r - background.r) + absf(pixel.g - background.g) \
		+ absf(pixel.b - background.b) + absf(pixel.a - background.a) > 0.15


static func finish(probe: Node, exit_code: int) -> void:
	var tree := probe.get_tree()
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null:
		for key in ["_music", "_sfx", "_voice"]:
			var player := audio.get(key) as AudioStreamPlayer
			if is_instance_valid(player):
				player.stop()
				player.stream = null
		await tree.create_timer(1.0).timeout
	await tree.process_frame
	await tree.process_frame
	tree.quit(exit_code)
