extends Node

const Gesture := preload("res://scripts/harvest/gesture.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var requested_window := OS.get_environment("SHOT_WINDOW").split("x")
	if requested_window.size() == 2:
		get_window().size = Vector2i(int(requested_window[0]), int(requested_window[1]))
	await get_tree().process_frame
	GameManager.current_level_id = "harvest_02"
	SaveManager.clear_harvest_checkpoint("harvest_02")
	SaveManager.set_setting("reduce_motion", true)
	var packed := load("res://scenes/minigames/harvest_action/HarvestAction.tscn") as PackedScene
	var level := packed.instantiate() as Node2D
	add_child(level)
	for _frame in range(10):
		await get_tree().process_frame

	var plant_target: Node2D
	var strawberry_targets: Array = level.get("_targets")
	var visible_plants := 0
	for candidate_variant in strawberry_targets:
		var candidate := candidate_variant as Node2D
		if candidate == null or str(candidate.crop.get("id", "")) != "strawberry":
			continue
		var body := candidate.get_meta("visual_plant", null) as Node2D
		if body == null:
			continue
		var art := body.get_node_or_null("HarvestPlantBody3DArt") as TextureRect
		_ok(art != null and art.texture != null
			and art.texture.resource_path.ends_with("strawberry_body.png"),
			"the strawberry target has the Blender-rendered passive plant sprite")
		_ok(body.visible, "the passive strawberry body is visible")
		visible_plants += 1
		if candidate.step in ["ready", "golden"] \
				and level.call("_target_is_available_now", candidate):
			plant_target = candidate
	_ok(visible_plants > 0, "harvest_02 creates at least one visible strawberry plant body")

	var state := OS.get_environment("SHOT_PLANT_STATE")
	if state == "held":
		_ok(plant_target != null, "harvest_02 has a ripe strawberry for the real touch path")
		if plant_target != null:
			var body_before := plant_target.get_meta("visual_plant", null) as Node2D
			var path: PackedVector2Array = Gesture.demo_path(
				str(plant_target.crop.get("recogniser", "")),
				plant_target.crop.get("gesture_params", {}),
				plant_target.global_position, float(plant_target.get("radius")))
			for index in range(path.size()):
				var at := _glass(path[index])
				if index == 0:
					var down := InputEventScreenTouch.new()
					down.index = 0
					down.pressed = true
					down.position = at
					Input.parse_input_event(down)
				else:
					var drag := InputEventScreenDrag.new()
					drag.index = 0
					drag.position = at
					drag.relative = at - _glass(path[index - 1])
					Input.parse_input_event(drag)
				await get_tree().process_frame
			var up := InputEventScreenTouch.new()
			up.index = 0
			up.pressed = false
			up.position = _glass(path[path.size() - 1])
			Input.parse_input_event(up)
			for _frame in range(6):
				await get_tree().process_frame
			await get_tree().create_timer(0.55).timeout
			_ok(level.get("_in_hand") != null,
				"the existing strawberry gesture puts its fruit in hand")
			_ok(is_instance_valid(body_before) and body_before.visible,
				"picking the fruit leaves the Blender-rendered plant rooted in the field")
			var held_shift: Vector2 = plant_target.get_meta("visual_held_shift", Vector2.ZERO)
			var shift_limit := float(level.get_script().get_script_constant_map().get(
				"HELD_SHIFT_LIMIT", 0.0))
			_ok(shift_limit > 0.0 and absf(held_shift.x) <= shift_limit + 0.01
				and absf(held_shift.y) < 0.01,
				"the held fruit clears its plant within the existing horizontal shift limit")

	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	var path_out := OS.get_environment("SHOT_PATH")
	var image_error := image.save_png(path_out)
	_ok(image_error == OK and ProbeLifecycle.image_has_content(image),
		"the actual harvest_02 page screenshot is visible and saved")
	for failure in _failures:
		push_error(failure)
	print("HARVEST PLANT SHOT %s state=%s plants=%d" % [
		"PASSED" if _failures.is_empty() else "FAILED", state, visible_plants])
	await ProbeLifecycle.finish(self, 0 if _failures.is_empty() else 1)


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _glass(at: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	return Vector2(at.x * window_size.x / viewport_size.x,
		at.y * window_size.y / viewport_size.y)
