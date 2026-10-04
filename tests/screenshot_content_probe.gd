extends Node
## Pure Image checks; --headless is valid because no captured frame is used.

const Lifecycle := preload("res://tests/probe_lifecycle.gd")
var _failures: Array[String] = []
var _asked := 0


func _check(condition: bool, message: String) -> void:
	_asked += 1
	if not condition:
		_failures.append(message)


func _ready() -> void:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var background := Color(0.4, 0.4, 0.4, 1.0)
	image.fill(background)
	_check(not Lifecycle.image_has_content(null), "a missing image is empty")
	_check(not Lifecycle.image_has_content(Image.new()), "an unallocated image is empty")
	_check(not Lifecycle.image_has_content(image), "a uniform grey PNG is empty")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(10, 10, 30, 30), background) == 0,
		"a uniform cell has no contrasting pixels")
	for x in range(7):
		image.set_pixel(10 + x, 10, Color.WHITE)
	_check(Lifecycle.contrasting_pixels(image, Rect2i(10, 10, 30, 30), background) == 7,
		"seven painted pixels stay below the cell minimum")
	_check(not Lifecycle.image_has_content(image), "seven pixels stay below the page minimum")
	image.set_pixel(17, 10, Color.WHITE)
	_check(Lifecycle.contrasting_pixels(image, Rect2i(10, 10, 30, 30), background) == 8,
		"eight painted pixels satisfy the cell minimum")
	_check(Lifecycle.image_has_content(image), "eight painted pixels satisfy the page minimum")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(40, 40, 30, 30), background) == 0,
		"content in another cell cannot rescue an empty cell")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(10, 10, 30, 30), background, 3) == 3,
		"the count is capped at the requested minimum")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(-20, -20, 15, 15), background) == 0,
		"an off-image cell is empty")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(10, 10, 0, 0), background) == 0,
		"a zero-area cell is empty")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(10, 10, 30, 30), background, 0) == 0,
		"a nonpositive minimum cannot pass")
	image.fill(Color(0.9, 0.1, 0.8, 0.0))
	_check(not Lifecycle.image_has_content(image), "fully transparent colours are empty")
	_check(Lifecycle.contrasting_pixels(image, Rect2i(0, 0, 96, 96), Color.TRANSPARENT) == 0,
		"transparent coloured pixels cannot pass a cell")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 960)
	add_child(viewport)
	var capture := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	_check(Lifecycle.image_region(viewport, capture, Rect2(100, 200, 48, 48))
		== Rect2i(80, 160, 39, 39), "4:3 logical regions scale to physical pixels with outward rounding")
	_check(Lifecycle.image_region(viewport, capture, Rect2(-20, -20, 40, 40))
		== Rect2i(0, 0, 16, 16), "partly clipped regions stay inside the image")
	_check(not Lifecycle.image_region(viewport, capture, Rect2(1400, 100, 48, 48)).has_area(),
		"an entirely offscreen region is empty")
	_check(not Lifecycle.image_region(null, capture, Rect2(0, 0, 48, 48)).has_area(),
		"a missing viewport cannot supply a region")
	_check(not Lifecycle.image_region(viewport, null, Rect2(0, 0, 48, 48)).has_area(),
		"a missing capture cannot supply a region")
	viewport.size = Vector2i(1240, 1080)
	var catalogue := Image.create(1240, 1080, false, Image.FORMAT_RGBA8)
	_check(Lifecycle.image_region(viewport, catalogue, Rect2(240, 110, 48, 38))
		== Rect2i(240, 110, 48, 38), "native catalogue regions retain one-to-one coordinates")
	viewport.queue_free()
	for failure in _failures:
		print("FAIL ", failure)
	print("asked %d questions" % _asked)
	print("SCREENSHOT CONTENT PROBE ", "PASSED" if _failures.is_empty() else "FAILED")
	await Lifecycle.finish(self, 0 if _failures.is_empty() else 1)
