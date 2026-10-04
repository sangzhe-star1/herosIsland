extends Node
## Verifies Godot's regular GLB import pipeline and maps imported models onto
## the real HarvestAction visual anchors without changing production logic.

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")
const Maturity := preload("res://scripts/harvest/maturity.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const VisualArt := preload("res://scripts/harvest/harvest_visual_art.gd")

const HARVEST_SCENE := "res://scenes/minigames/harvest_action/HarvestAction.tscn"
const IMPORTED_MODELS := {
	"strawberry": "res://assets/harvest_3d/runtime/strawberry.glb",
	"basket": "res://assets/harvest_3d/runtime/basket.glb",
	"tomato_body": "res://assets/harvest_3d/runtime/tomato_body.glb",
	"tomato_fruit": "res://assets/harvest_3d/runtime/tomato_fruit.glb",
	"environment": "res://assets/harvest_3d/runtime/passive_environment.glb",
}
var _level: Node2D
var _field: Control
var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D
var _fruit_entry: Dictionary = {}
var _fruit_count := 0
var _basket_count := 0


func _ready() -> void:
	var requested_size := _requested_window()
	get_window().size = requested_size
	await get_tree().process_frame
	GameManager.current_level_id = "harvest_02"
	SaveManager.clear_harvest_checkpoint("harvest_02")
	SaveManager.set_setting("difficulty", 2)
	SaveManager.set_setting("reduce_motion", true)
	SaveManager.set_setting("harvest_taught", ["sort_two"])
	_level = load(HARVEST_SCENE).instantiate() as Node2D
	add_child(_level)
	for _frame in range(8):
		await get_tree().process_frame

	_field = _level.get("_field") as Control
	if _field == null or not _verify_imported_scenes() or not _install_scene_layer():
		await ProbeLifecycle.finish(self, 2)
		return
	if not await _install_models():
		await ProbeLifecycle.finish(self, 3)
		return
	if OS.get_environment("PILOT_HELD") == "1" and not await _pick_imported_fruit():
		await ProbeLifecycle.finish(self, 6)
		return
	if OS.get_environment("PILOT_DELIVER") == "1" and not await _deliver_imported_fruit():
		await ProbeLifecycle.finish(self, 7)
		return

	for _frame in range(6):
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var screenshot_path := OS.get_environment("SHOT_PATH")
	if screenshot_path.is_empty():
		push_error("set SHOT_PATH")
		await ProbeLifecycle.finish(self, 4)
		return
	var screenshot := get_viewport().get_texture().get_image()
	var content_ok := ProbeLifecycle.image_has_content(screenshot)
	var save_error := screenshot.save_png(screenshot_path)
	print("HARVEST RUNTIME IMPORT PILOT models=%d crops=%d strawberry=%d baskets=%d size=%s save=%s" % [
		IMPORTED_MODELS.size(), VisualArt.CROP_IDS.size(), _fruit_count, _basket_count,
		str(screenshot.get_size()),
		error_string(save_error)])
	await ProbeLifecycle.finish(self, 0 if content_ok and save_error == OK else 5)


func _requested_window() -> Vector2i:
	var dimensions := OS.get_environment("SHOT_WINDOW").split("x")
	if dimensions.size() == 2:
		return Vector2i(int(dimensions[0]), int(dimensions[1]))
	return Vector2i(1280, 720)


func _verify_imported_scenes() -> bool:
	for model_name in IMPORTED_MODELS:
		var path := str(IMPORTED_MODELS[model_name])
		if not _verify_packed_scene(path, model_name):
			return false
	for crop_id in VisualArt.CROP_IDS:
		var path := "res://assets/harvest_3d/runtime_candidates/crops/%s.glb" % crop_id
		if not _verify_packed_scene(path, "crop:%s" % crop_id):
			return false
	return true


func _verify_packed_scene(path: String, resource_name: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("Godot has not imported runtime GLB: %s" % path)
		return false
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		push_error("runtime GLB did not load as PackedScene: %s" % path)
		return false
	var instance := scene.instantiate()
	if not instance is Node3D or instance.find_children("*", "MeshInstance3D", true, false).is_empty():
		push_error("runtime GLB has no instantiable 3D mesh: %s" % path)
		return false
	instance.free()
	print("RUNTIME GLB imported PackedScene: %s" % resource_name)
	return true


func _install_scene_layer() -> bool:
	var container := SubViewportContainer.new()
	container.name = "ImportedHarvestObjects"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	container.z_index = -1
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_field.add_child(container)

	_viewport = SubViewport.new()
	_viewport.name = "ImportedHarvestObjectsViewport"
	_viewport.size = Vector2i(_field.size)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)

	_world = Node3D.new()
	_world.name = "ImportedHarvestObjectsWorld"
	_viewport.add_child(_world)
	_add_lighting()

	_camera = Camera3D.new()
	_camera.name = "ImportedHarvestObjectsCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = 9.4 if _requested_window().x / float(_requested_window().y) > 1.5 else 8.8
	_camera.near = 0.05
	_camera.far = 100.0
	_camera.position = Vector3(6.7, 6.8, 9.8)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.14, 1.03, 0.12), Vector3.UP)
	_camera.current = true
	return true


func _add_lighting() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.98, 0.97, 0.91)
	environment.ambient_light_energy = 0.62
	world_environment.environment = environment
	_world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SoftMeadowSun"
	sun.rotation_degrees = Vector3(-34.0, -28.0, -18.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	_world.add_child(sun)


func _install_models() -> bool:
	var targets: Array = _level.get("_targets")
	var chosen: Node2D
	var centre := Vector2(_field.size.x * 0.52, _field.size.y * 0.60)
	var best_distance := INF
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null or str(target.crop.get("id", "")) != "strawberry":
			continue
		if target.step not in [Maturity.READY, Maturity.GOLDEN]:
			continue
		var distance := target.position.distance_to(centre)
		if distance < best_distance:
			best_distance = distance
			chosen = target
	if chosen == null:
		push_error("harvest_02 has no ripe strawberry target")
		return false

	var art := chosen.get("_art") as Control
	var strawberry := _instantiate_model("strawberry")
	if art == null or strawberry == null:
		push_error("strawberry target art or imported model is missing")
		return false
	_world.add_child(strawberry)
	var ground_offset := Vector2(0.0, 42.0)
	_fruit_entry = {"node": strawberry, "target": chosen, "art": art,
		"ground_offset": ground_offset, "desired_height": _texture_art_height(art)}
	_update_fruit()
	for _frame in range(3):
		await get_tree().process_frame
	var projected := _projected_height(strawberry)
	if projected <= 0.01:
		push_error("imported strawberry mesh has no projected height")
		return false
	strawberry.scale = Vector3.ONE * float(_fruit_entry["desired_height"]) / projected
	_fruit_entry["fit"] = true
	_update_fruit()
	_hide_control(art)
	_fruit_count += 1

	var baskets: Array = _level.get("_baskets")
	for basket_variant in baskets:
		var basket := basket_variant as Node2D
		if basket == null:
			continue
		var basket_art := basket.get_node_or_null("HarvestBasket3DArt") as Control
		var basket_model := _instantiate_model("basket")
		if basket_art == null or basket_model == null:
			push_error("basket art or imported basket scene is missing")
			return false
		_world.add_child(basket_model)
		var size := float(basket.get("_size"))
		var ground_canvas_position := basket.get_global_transform_with_canvas().origin \
			+ Vector2(0.0, size * 0.52)
		basket_model.position = _world_point_for_screen(_field_screen_point(ground_canvas_position),
			0.0)
		var desired_height := _texture_art_height(basket_art)
		for _frame in range(2):
			await get_tree().process_frame
		var basket_height := _projected_height(basket_model)
		if basket_height <= 0.01:
			push_error("imported basket mesh has no projected height")
			return false
		basket_model.scale = Vector3.ONE * desired_height / basket_height
		_hide_control(basket_art)
		_basket_count += 1
	return _fruit_count == 1 and _basket_count > 0


func _instantiate_model(model_name: String) -> Node3D:
	var packed := ResourceLoader.load(str(IMPORTED_MODELS[model_name])) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _pick_imported_fruit() -> bool:
	var target := _fruit_entry["target"] as Node2D
	var path: PackedVector2Array = Gesture.demo_path(
		str(target.crop.get("recogniser", "")), target.crop.get("gesture_params", {}),
		target.global_position, float(target.get("radius")))
	if path.is_empty():
		push_error("strawberry gesture path is empty")
		return false
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = path[0]
	_level.call("_on_field_input", down)
	await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = path[path.size() - 1]
	_level.call("_on_field_input", release)
	for _frame in range(8):
		await get_tree().process_frame
	var held := _level.get("_in_hand") as Node2D
	print("IMPORTED STRAWBERRY HELD=%s model_visible=%s" % [
		str(held == target), str((_fruit_entry["node"] as Node3D).visible)])
	return held == target


func _deliver_imported_fruit() -> bool:
	var target := _fruit_entry["target"] as Node2D
	var basket := _level.call("_destination_for", target) as Node2D
	if basket == null or not bool(_level.call("_basket_accepts", target, basket)):
		push_error("existing basket rules do not resolve the imported strawberry")
		return false
	var picked: Dictionary = (_level.get("_picked") as Dictionary).duplicate(true)
	await _tap_at(basket.global_position)
	for _frame in range(12):
		await get_tree().process_frame
	var picked_after: Dictionary = _level.get("_picked")
	var successful := _level.get("_in_hand") == null \
		and int(picked_after.get("strawberry", 0)) \
		== int(picked.get("strawberry", 0)) + 1
	print("IMPORTED STRAWBERRY BASKET DELIVERY=%s basket=%s picked=%s" % [
		str(successful), basket.id, str(picked_after)])
	return successful


func _update_fruit() -> void:
	if _fruit_entry.is_empty():
		return
	var target_ref: Variant = _fruit_entry["target"]
	var model_ref: Variant = _fruit_entry["node"]
	if not is_instance_valid(target_ref) or not is_instance_valid(model_ref):
		if is_instance_valid(model_ref):
			(model_ref as Node3D).queue_free()
		_fruit_entry.clear()
		return
	var target := target_ref as Node2D
	var model := model_ref as Node3D
	var visual := target.get("_visual") as Node2D
	var local_anchor := visual.position if visual != null else Vector2.ZERO
	local_anchor += _fruit_entry["ground_offset"]
	var canvas_position := target.get_global_transform_with_canvas() * local_anchor
	var screen := _field_screen_point(canvas_position)
	model.position = _world_point_for_screen(screen, 0.0)
	model.rotation.y = deg_to_rad(float(target.rotation_degrees))
	model.visible = target.is_visible_in_tree()
	if _fruit_entry.has("fit"):
		model.scale = Vector3.ONE * float(_fruit_entry["desired_height"]) \
			/ maxf(_projected_height_at_unit(model), 0.01) \
			* absf(target.scale.x)


func _projected_height_at_unit(root: Node3D) -> float:
	var current_scale := root.scale
	root.scale = Vector3.ONE
	var height := _projected_height(root)
	root.scale = current_scale
	return height


func _process(_delta: float) -> void:
	_update_fruit()


func _tap_at(at: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	var point := Vector2(at.x * window_size.x / viewport_size.x,
		at.y * window_size.y / viewport_size.y)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = point
	Input.parse_input_event(down)
	await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = point
	Input.parse_input_event(release)
	for _frame in range(5):
		await get_tree().process_frame


func _field_screen_point(canvas_position: Vector2) -> Vector2:
	var field_to_canvas := _field.get_global_transform_with_canvas()
	var local_point := field_to_canvas.affine_inverse() * canvas_position
	return local_point * Vector2(_viewport.size) / Vector2(_field.size)


func _world_point_for_screen(screen_point: Vector2, height: float) -> Vector3:
	var origin := _camera.project_ray_origin(screen_point)
	var direction := _camera.project_ray_normal(screen_point)
	if absf(direction.y) < 0.0001:
		return Vector3(screen_point.x, height, screen_point.y)
	var distance := (height - origin.y) / direction.y
	return origin + direction * distance


func _projected_height(root: Node3D) -> float:
	var top := INF
	var bottom := -INF
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for corner in _aabb_corners(mesh_instance.mesh.get_aabb()):
			var screen := _camera.unproject_position(mesh_instance.global_transform * corner)
			top = minf(top, screen.y)
			bottom = maxf(bottom, screen.y)
	return maxf(bottom - top, 0.0) if is_finite(top) and is_finite(bottom) else 0.0


func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				corners.append(Vector3(x, y, z))
	return corners


func _texture_art_height(art: Control) -> float:
	var texture_art := art as TextureRect
	if texture_art == null or texture_art.texture == null:
		return maxf(art.size.y, 1.0)
	var image := texture_art.texture.get_image()
	if image == null:
		return maxf(texture_art.size.y * 0.6, 1.0)
	var used := image.get_used_rect()
	if used.size.y <= 0:
		return maxf(texture_art.size.y * 0.6, 1.0)
	return maxf(float(used.size.y) / float(image.get_height()) * texture_art.size.y, 1.0)


func _hide_control(control: Control) -> void:
	control.visible = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
