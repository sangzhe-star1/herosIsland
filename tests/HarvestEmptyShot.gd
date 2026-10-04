extends "res://tests/harvest_touch_probe.gd"

func _ready() -> void:
	var want := OS.get_environment("SHOT_WINDOW").split("x")
	get_window().size = Vector2i(int(want[0]), int(want[1]))
	await get_tree().process_frame
	await _open_with_settings("harvest_07", {"reduce_motion": OS.get_environment("SHOT_REDUCE_MOTION") == "1"})
	var bodies: Array[CanvasItem] = []
	for target: Node2D in _level.get("_targets"):
		if str(target.crop.get("id", "")) == "tomato" and target.has_meta("visual_plant"):
			bodies.append(target.get_meta("visual_plant") as CanvasItem)
	_ok(bodies.size() == 3, "three available tomato Targets have passive plant bodies")
	await _fill_visible_delivery(["tomato"])
	await get_tree().create_timer(0.65).timeout
	_ok(_find("", "tomato") == null and _in_hand() == null,
		"all three tomatoes were picked and delivered through real input")
	_ok(_picked_total() == 3 and int(_level.get("_order_index")) == 0,
		"the tomato group is empty while broccoli keeps the first order active")
	for body in bodies:
		_ok(is_instance_valid(body) and body.visible, "a harvested tomato body remains rooted in the field")
	RenderingServer.force_draw(false)
	var out_path := OS.get_environment("SHOT_PATH")
	var err := get_viewport().get_texture().get_image().save_png(out_path)
	_ok(err == OK, "the actual emptied-group image saves")
	for failure in _failures:
		print("FAIL ", failure)
	print("HARVEST EMPTY SHOT %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	await ProbeLifecycle.finish(self, 0 if _failures.is_empty() else 1)
