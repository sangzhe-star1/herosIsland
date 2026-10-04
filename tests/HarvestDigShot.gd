extends Node

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

const Gesture := preload("res://scripts/harvest/gesture.gd")

func _ready() -> void:
	var wanted: String = OS.get_environment("SHOT_WINDOW")
	var parts: PackedStringArray = wanted.split("x") if wanted.contains("x") else PackedStringArray(["1280", "720"])
	get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	await get_tree().process_frame
	var requested_level := "harvest_04"
	GameManager.current_level_id = requested_level if requested_level != "" else "harvest_02"
	SaveManager.clear_harvest_checkpoint(GameManager.current_level_id)
	if OS.get_environment("SHOT_ORDER_INDEX") != "":
		SaveManager.set_harvest_checkpoint({"level_id": GameManager.current_level_id,
			"order_index": int(OS.get_environment("SHOT_ORDER_INDEX")), "delivered": {}})
	var requested_crop := OS.get_environment("SHOT_CROP_ID")
	if requested_crop == "":
		requested_crop = "potato"
	if OS.get_environment("SHOT_DIFFICULTY") != "":
		SaveManager.set_setting("difficulty", int(OS.get_environment("SHOT_DIFFICULTY")))
	SaveManager.set_setting("reduce_motion", OS.get_environment("SHOT_REDUCE_MOTION") == "1")
	var scene: PackedScene = load("res://scenes/minigames/harvest_action/HarvestAction.tscn")
	var level: Node2D = scene.instantiate() as Node2D
	add_child(level)
	for i in range(8):
		await get_tree().process_frame
	var target: Node2D = null
	for candidate: Node2D in level.get("_targets"):
		if str(candidate.crop.get("id", "")) == requested_crop \
				and candidate.step in ["ready", "golden"] \
				and level.call("_target_is_available_now", candidate):
			target = candidate
			break
	if target == null:
		push_error("no available ready/golden target for " + requested_crop)
		await ProbeLifecycle.finish(self, 2)
		return
	var path: PackedVector2Array = Gesture.demo_path(
		str(target.crop.get("recogniser", "")), target.crop.get("gesture_params", {}),
		target.global_position, float(target.get("radius")))
	path.resize(7)
	for i in range(path.size()):
		var at: Vector2 = _glass(path[i])
		if i == 0:
			var down := InputEventScreenTouch.new()
			down.index = 0
			down.pressed = true
			down.position = at
			Input.parse_input_event(down)
		else:
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = at
			drag.relative = at - _glass(path[i - 1])
			Input.parse_input_event(drag)
		await get_tree().process_frame
	var cover: Node2D = target.get("_cover") as Node2D
	if cover == null or cover.modulate.a >= 0.95 or cover.modulate.a <= 0.05 \
			or target.taken or level.get("_in_hand") != null:
		push_error("real partial dig did not expose soil progress without picking")
		await ProbeLifecycle.finish(self, 3)
		return
	RenderingServer.force_draw(false)
	var out_path: String = OS.get_environment("SHOT_PATH")
	var err: Error = get_viewport().get_texture().get_image().save_png(out_path)
	print("partial dig shot: %s (%s), cover_alpha=%.3f, taken=%s" % [out_path, error_string(err), cover.modulate.a, str(target.taken)])
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(path[path.size() - 1])
	Input.parse_input_event(up)
	await get_tree().process_frame
	await ProbeLifecycle.finish(self, 0 if err == OK else 1)

func _glass(at: Vector2) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(get_window().size)
	return Vector2(at.x * win.x / view.x, at.y * win.y / view.y)
