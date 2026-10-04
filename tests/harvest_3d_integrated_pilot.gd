extends Node
## Isolated same-source 3D integration image test. Existing HarvestAction owns
## every target, hit zone, gesture, maturity rule, basket and order transition.

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const Maturity := preload("res://scripts/harvest/maturity.gd")
const VisualArt := preload("res://scripts/harvest/harvest_visual_art.gd")

const HARVEST_SCENE := "res://scenes/minigames/harvest_action/HarvestAction.tscn"
const WHOLE_PLANT_SCENE_GLB := "res://assets/harvest_3d/source/whole_plant/rendered/whole_plant_scene.glb"
const ENVIRONMENT_GLB := "res://assets/harvest_3d/source/whole_plant/environment_refined/passive_environment.glb"
const TOMATO_BODY_GLB := "res://assets/harvest_3d/source/whole_plant/rendered/plant001_body.glb"
const TOMATO_FRUIT_GLB := "res://assets/harvest_3d/source/whole_plant/rendered/tomato_fruit.glb"
const STRAWBERRY_GLB := "res://assets/harvest_3d/source/strawberry_readability/rendered/strawberry.glb"
const STRAWBERRY_PLANT_GLB := "res://assets/harvest_3d/source/strawberry_plant_candidate/rendered/strawberry_plant_body.glb"
const STRAWBERRY_BED_PLANT_GLB := "res://assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered/strawberry_plant.glb"
const STRAWBERRY_BED_GLB := "res://assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered/strawberry_bed.glb"
const BASKET_GLB := "res://assets/harvest_3d/source/whole_plant/rendered/basket.glb"
const CROP_CATALOG_ROOT := "res://assets/harvest_3d/runtime_candidates/crops/"
const SHADOW_RECEIVER_SHADER := "res://tests/harvest_shadow_receiver.gdshader"
const FIELD_GRADE_SHADER := "res://tests/harvest_field_grade.gdshader"
const FIELD_RECEIVE_SHADER := "res://tests/harvest_field_receive.gdshader"

const BACKGROUND_WIDTH := 18.488889
const TOMATO_SLOT_HEIGHT := 1.42

var _level: Node2D
var _field: Control
var _field_viewport: SubViewport
var _object_viewport: SubViewport
var _object_camera: Camera3D
var _field_camera: Camera3D
var _field_ground_mesh: MeshInstance3D
var _field_grade_material: ShaderMaterial
var _object_world: Node3D
var _shared_world_mode := false
var _strawberry_fruit_slots: Dictionary = {}
var _planting_bed_mesh: MeshInstance3D
var _raised_bed: Node3D
var _single_tomato_target: Node2D
var _local_shadow_receiver_mode := false
var _model_entries: Array[Dictionary] = []
var _body_count := 0
var _fruit_count := 0
var _basket_count := 0
var _shadow_receiver_count := 0
var _bed_row_count := 0
var _soil_mound_count := 0
var _soil_row_count := 0
var _field_grade_mesh_count := 0
var _viewport_size := Vector2i.ZERO
var _ground_hit_queries := 0
var _ground_missed_queries := 0
var _target_bed_hit_count := 0
var _target_bed_miss_count := 0
var _target_bed_occluded_count := 0
var _soil_plot_root_inside_count := 0
var _soil_plot_root_total := 0


func _ready() -> void:
	var requested_size := _requested_window()
	get_window().size = requested_size
	await get_tree().process_frame
	_viewport_size = Vector2i(get_viewport().get_visible_rect().size)

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
	if _field == null or not _install_scene_layers(requested_size):
		await ProbeLifecycle.finish(self, 2)
		return
	if not await _install_live_models():
		await ProbeLifecycle.finish(self, 3)
		return

	if OS.get_environment("PILOT_HELD") == "1":
		var pick_ok := false
		if _local_shadow_receiver_mode:
			pick_ok = await _pick_one_local_tomato()
		else:
			pick_ok = await _pick_one_strawberry()
		if not pick_ok:
			await ProbeLifecycle.finish(self, 4)
			return
		if OS.get_environment("PILOT_DELIVER") == "1" \
				and not await _deliver_held_crop():
			await ProbeLifecycle.finish(self, 7)
			return

	for _frame in range(6):
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var screenshot_path := OS.get_environment("SHOT_PATH")
	if screenshot_path.is_empty():
		push_error("set SHOT_PATH")
		await ProbeLifecycle.finish(self, 5)
		return
	var screenshot := get_viewport().get_texture().get_image()
	var content_ok := ProbeLifecycle.image_has_content(screenshot)
	var save_error := screenshot.save_png(screenshot_path)
	print("3D integrated pilot image=%s size=%s" % [screenshot_path, screenshot.get_size()])
	print("3D integrated pilot bodies=%d fruits=%d baskets=%d content=%s save=%s" % [
		_body_count, _fruit_count, _basket_count, str(content_ok), error_string(save_error)])
	if _shadow_receiver_count > 0:
		print("3D shadow receiver count=%d" % _shadow_receiver_count)
	if _bed_row_count > 0:
		print("3D target bed rows=%d" % _bed_row_count)
	if _soil_mound_count > 0:
		print("3D target soil mounds=%d" % _soil_mound_count)
	if _soil_row_count > 0:
		print("3D continuous soil rows=%d" % _soil_row_count)
	print("3D field grade mesh matches=%d" % _field_grade_mesh_count)
	if _shared_world_mode:
		print("3D shared ground ray hits=%d misses=%d" % [
			_ground_hit_queries, _ground_missed_queries])
	if _target_bed_hit_count + _target_bed_miss_count > 0:
		print("3D target roots visible on bed=%d/%d misses=%d occluded=%d" % [
			_target_bed_hit_count,
			_target_bed_hit_count + _target_bed_miss_count,
			_target_bed_miss_count,
			_target_bed_occluded_count])
	if _soil_plot_root_total > 0:
		print("3D target roots inside soil plot mask=%d/%d" % [
			_soil_plot_root_inside_count, _soil_plot_root_total])
	if _local_shadow_receiver_mode:
		_log_local_model_alignment()
	await ProbeLifecycle.finish(self, 0 if content_ok and save_error == OK else 6)


func _requested_window() -> Vector2i:
	var dimensions := OS.get_environment("SHOT_WINDOW").split("x")
	if dimensions.size() == 2:
		return Vector2i(int(dimensions[0]), int(dimensions[1]))
	return Vector2i(1280, 720)


func _install_scene_layers(requested_size: Vector2i) -> bool:
	if not FileAccess.file_exists(ENVIRONMENT_GLB):
		push_error("same-source environment GLB is not readable from res://")
		return false
	var aspect := float(requested_size.x) / maxf(float(requested_size.y), 1.0)
	var composition_width := 9.4 if aspect > 1.5 else 8.8
	if OS.get_environment("PILOT_SHARED_WORLD") == "1":
		_shared_world_mode = true
		var shared_layer := _make_layer(
			"UnifiedHarvestStage3D", -1, BACKGROUND_WIDTH)
		_field_viewport = shared_layer["viewport"] as SubViewport
		_field_camera = shared_layer["camera"] as Camera3D
		_object_viewport = _field_viewport
		_object_camera = _field_camera
		_object_world = shared_layer["world"] as Node3D
		var shared_environment := _load_packed_gltf_scene(
			"res://assets/harvest_3d/runtime/passive_environment.glb") \
			if OS.get_environment("PILOT_RUNTIME_IMPORT") == "1" \
			else _load_gltf_scene(ENVIRONMENT_GLB)
		if shared_environment == null:
			return false
		_apply_field_material(shared_environment)
		_object_world.add_child(shared_environment)
		print("3D pilot using one shared World3D/SubViewport camera_width=%s" % BACKGROUND_WIDTH)
		return true

	var environment_layer := _make_layer("SameSourceField3D", -15, BACKGROUND_WIDTH)
	var object_layer := _make_layer("HarvestObjects3D", -1, composition_width)
	if OS.get_environment("PILOT_HIDE_FIELD_LAYER") == "1":
		(environment_layer["container"] as Control).visible = false
	_field_viewport = environment_layer["viewport"] as SubViewport
	_field_camera = environment_layer["camera"] as Camera3D
	_object_viewport = object_layer["viewport"] as SubViewport
	_object_camera = object_layer["camera"] as Camera3D
	_object_world = object_layer["world"] as Node3D

	if OS.get_environment("PILOT_RAISED_BED") == "1":
		return _install_raised_bed()

	var environment_scene := _load_packed_gltf_scene(
		"res://assets/harvest_3d/runtime/passive_environment.glb") \
		if OS.get_environment("PILOT_RUNTIME_IMPORT") == "1" \
		else _load_gltf_scene(ENVIRONMENT_GLB)
	if environment_scene == null:
		return false
	_apply_field_material(environment_scene)
	(environment_layer["world"] as Node3D).add_child(environment_scene)
	return true


func _install_raised_bed() -> bool:
	var stage := _load_gltf_scene(WHOLE_PLANT_SCENE_GLB)
	if stage == null:
		return false
	var bed_meshes := 0
	for child in stage.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var is_bed := mesh_instance.name.begins_with("GardenBed")
		mesh_instance.visible = is_bed
		if is_bed:
			bed_meshes += 1
	if bed_meshes != 1:
		push_error("raised-bed source must contain exactly one independent GardenBed mesh")
		return false
	stage.name = "RaisedBedOnlyStage"
	stage.scale = Vector3.ONE * 1.28
	_object_world.add_child(stage)
	_raised_bed = stage
	return true


func _make_layer(layer_name: String, z: int, orthographic_width: float) -> Dictionary:
	var container := SubViewportContainer.new()
	container.name = layer_name
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	container.z_index = z
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_field.add_child(container)

	var subviewport := SubViewport.new()
	subviewport.name = layer_name + "Viewport"
	subviewport.size = Vector2i(_field.size)
	subviewport.transparent_bg = true
	subviewport.own_world_3d = true
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(subviewport)

	var world := Node3D.new()
	world.name = layer_name + "World"
	subviewport.add_child(world)
	_configure_lighting(world, layer_name in ["SameSourceField3D", "UnifiedHarvestStage3D"])

	var camera := Camera3D.new()
	camera.name = layer_name + "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = orthographic_width
	camera.near = 0.05
	camera.far = 100.0
	camera.position = Vector3(6.7, 6.8, 9.8)
	world.add_child(camera)
	camera.look_at(Vector3(0.14, 1.03, 0.12), Vector3.UP)
	camera.current = true
	return {"container": container, "viewport": subviewport,
		"world": world, "camera": camera}


func _configure_lighting(world: Node3D, is_field_layer: bool = false) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.98, 0.97, 0.91)
	environment.ambient_light_energy = _pilot_float(
		"PILOT_AMBIENT_ENERGY", 0.62, 0.2, 0.9)
	world_environment.environment = environment
	world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SoftMeadowSun"
	var receive_field_shadows := is_field_layer \
		and OS.get_environment("PILOT_RECEIVE_FIELD_SHADOWS") == "1"
	sun.rotation_degrees = Vector3(-56.0, -28.0, -18.0) \
		if receive_field_shadows else Vector3(-34.0, -28.0, -18.0)
	sun.light_color = Color(1.0, 0.98, 0.93)
	sun.light_energy = _pilot_float("PILOT_SUN_ENERGY", 0.52, 0.2, 0.8)
	sun.shadow_enabled = not (is_field_layer \
		and OS.get_environment("PILOT_FIELD_SHADOWS") == "0")
	sun.shadow_bias = 0.03
	if receive_field_shadows:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 24.0
		sun.shadow_opacity = _pilot_float("PILOT_SHADOW_OPACITY", 0.28, 0.05, 0.8)
		sun.shadow_blur = _pilot_float("PILOT_SHADOW_BLUR", 2.6, 0.0, 8.0)
		sun.shadow_bias = 0.055
	world.add_child(sun)


func _apply_field_material(root: Node) -> void:
	var receive_field_shadows := _shared_world_mode \
		and OS.get_environment("PILOT_RECEIVE_FIELD_SHADOWS") == "1"
	var shader_path := FIELD_RECEIVE_SHADER if receive_field_shadows else FIELD_GRADE_SHADER
	if not ResourceLoader.exists(shader_path):
		push_error("candidate field grade shader is missing")
		return
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(shader_path) as Shader
	_field_grade_material = shader_material
	shader_material.set_shader_parameter("saturation", _pilot_float(
		"PILOT_FIELD_SATURATION", 0.52, 0.0, 1.0))
	shader_material.set_shader_parameter("brightness", _pilot_float(
		"PILOT_FIELD_BRIGHTNESS", 1.08, 0.75, 1.35))
	shader_material.set_shader_parameter("warm_mix", _pilot_float(
		"PILOT_FIELD_WARM_MIX", 0.22, 0.0, 0.65))
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if receive_field_shadows and mesh_instance != null:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance != null and mesh_instance.name.contains("restrained short grass") \
			and OS.get_environment("PILOT_HIDE_FIELD_GRASS") == "1":
			mesh_instance.visible = false
		if mesh_instance == null or mesh_instance.mesh == null \
				or not mesh_instance.name.contains("continuous gentle field"):
			continue
		_field_ground_mesh = mesh_instance
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(0) \
			if mesh_instance.mesh.get_surface_count() > 0 else []
		if arrays.is_empty() or (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty():
			push_error("passive field mesh does not contain its authored vertex colors")
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface_index, shader_material)
		_field_grade_mesh_count = 1


func _pilot_float(key: String, fallback: float, low: float, high: float) -> float:
	var raw := OS.get_environment(key)
	return clampf(float(raw) if not raw.is_empty() else fallback, low, high)


func _install_live_models() -> bool:
	_apply_test_layout_shift()
	var targets: Array = _level.get("_targets")
	if OS.get_environment("PILOT_FIELD_SOIL_PLOT") == "1" \
			and not _install_target_soil_plot(targets):
		return false
	if OS.get_environment("PILOT_STRAWBERRY_BED") == "1" \
			and not _install_target_strawberry_bed(targets):
		return false
	if OS.get_environment("PILOT_TARGET_SOIL_ROWS") == "1":
		_install_target_soil_rows(targets)
	elif OS.get_environment("PILOT_SOIL_ROWS") == "1":
		_tint_field_soil_rows(targets)
	elif OS.get_environment("PILOT_TARGET_BEDS") == "1":
		_install_target_beds(targets)
	elif OS.get_environment("PILOT_SOIL_MOUNDS") == "1":
		_install_target_soil_mounds(targets)
	if OS.get_environment("PILOT_TARGET_SHADOWS") == "1":
		_install_target_shadow_receivers(targets)
	_local_shadow_receiver_mode = OS.get_environment("PILOT_LOCAL_SHADOW_RECEIVER") == "1"
	if _local_shadow_receiver_mode:
		_single_tomato_target = _most_centered_target(targets, "tomato")
		if _single_tomato_target == null:
			push_error("no tomato target available for local shadow receiver")
			return false
		print("3D local tomato target step=%s pos=%s" % [
			_single_tomato_target.step, str(_single_tomato_target.position)])
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var crop_id := str(target.crop.get("id", ""))
		if _local_shadow_receiver_mode and target != _single_tomato_target:
			continue
		match crop_id:
			"tomato":
				if not _add_tomato_body(target, target == _single_tomato_target):
					return false
				if not _add_target_model(target, TOMATO_FRUIT_GLB, true):
					return false
			"strawberry":
				if OS.get_environment("PILOT_STRAWBERRY_PLANT") == "1" \
						and not _add_strawberry_body(target):
					return false
				if not _add_target_model(target, STRAWBERRY_GLB, false):
					return false

	if not _local_shadow_receiver_mode:
		var baskets: Array = _level.get("_baskets")
		for basket_variant in baskets:
			var basket := basket_variant as Node2D
			if basket == null or not _add_basket_model(basket):
				return false

	for _frame in range(3):
		await get_tree().process_frame
	for entry in _model_entries:
		var model := entry["node"] as Node3D
		var desired_height := float(entry["height"])
		var projected_height := _projected_height(model)
		if projected_height <= 0.01:
			push_error("3D model has no projectable mesh: %s" % str(entry["kind"]))
			return false
		var fit := desired_height / projected_height
		model.scale = Vector3.ONE * fit
		entry["fit"] = fit
		if entry["kind"] == "fruit":
			entry["target_scale"] = float(entry["maturity_scale"])
	for entry in _model_entries:
		if entry["kind"] != "strawberry_body":
			continue
		var body := entry["node"] as Node3D
		var slot := body.find_child("FruitSlot | strawberry GLB center", true, false) as Node3D
		if slot == null:
			slot = body.find_child("FruitSlot", true, false) as Node3D
		if slot == null:
			push_error("strawberry plant GLB is missing its named FruitSlot node")
			return false
		var target := entry["target"] as Node2D
		if target != null:
			_strawberry_fruit_slots[target.get_instance_id()] = slot
	for entry in _model_entries:
		if entry["kind"] != "fruit" or bool(entry.get("tomato", false)):
			continue
		var target := entry["target"] as Node2D
		if target == null:
			continue
		var slot := _strawberry_fruit_slots.get(target.get_instance_id()) as Node3D
		if slot != null:
			entry["fruit_slot"] = slot
			entry["ground_offset"] = 0.0
			entry["fruit_height"] = 0.0
	_update_dynamic_models()
	return _fruit_count > 0 and _body_count > 0 \
		and (_local_shadow_receiver_mode or _basket_count > 0)


func _most_centered_target(targets: Array, crop_id: String) -> Node2D:
	var centre := Vector2(_field.size.x * 0.52, _field.size.y * 0.60)
	var chosen: Node2D
	var best_distance := INF
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null or str(target.crop.get("id", "")) != crop_id:
			continue
		if target.step not in [Maturity.READY, Maturity.GOLDEN]:
			continue
		var distance := target.position.distance_to(centre)
		if distance < best_distance:
			best_distance = distance
			chosen = target
	return chosen


func _apply_test_layout_shift() -> void:
	if OS.get_environment("PILOT_RAISED_BED_LAYOUT") == "1" and _raised_bed != null:
		_apply_test_raised_bed_layout()
	elif OS.get_environment("PILOT_GRID_5X3") == "1":
		_apply_test_grid_layout()
	var amount := float(OS.get_environment("PILOT_SHIFT_UP"))
	if amount <= 0.0:
		return
	for target_variant in _level.get("_targets"):
		var target := target_variant as Node2D
		if target == null:
			continue
		target.position.y -= amount
		var passive_plant := target.get_meta("visual_plant") as Node2D \
			if target.has_meta("visual_plant") else null
		if passive_plant != null:
			passive_plant.position.y -= amount
		var mound := target.get_meta("visual_mound") as Node2D \
			if target.has_meta("visual_mound") else null
		if mound != null:
			mound.position.y -= amount


func _apply_test_raised_bed_layout() -> void:
	var targets: Array = _level.get("_targets")
	if targets.size() != 14:
		push_warning("raised-bed grid is calibrated for the 14-target harvest_02 page")
		return
	var row_depths := [-0.72, 0.0, 0.72]
	for index in range(targets.size()):
		var target := targets[index] as Node2D
		if target == null:
			continue
		var row := index / 5
		var column := index % 5
		var column_count := 5 if row < 2 else 4
		var spacing := 0.98
		var x := (float(column) - float(column_count - 1) * 0.5) * spacing
		var local_slot := Vector3(x, 0.08, float(row_depths[row]))
		var viewport_point := _object_camera.unproject_position(_raised_bed.to_global(local_slot))
		var field_local := viewport_point * Vector2(_field.size) / Vector2(_object_viewport.size)
		var desired_canvas := _field.get_global_transform_with_canvas() * field_local
		var parent := target.get_parent() as CanvasItem
		if parent == null:
			continue
		var previous_position := target.position
		target.position = parent.get_global_transform_with_canvas().affine_inverse() * desired_canvas
		var delta := target.position - previous_position
		var passive_plant := target.get_meta("visual_plant") as Node2D \
			if target.has_meta("visual_plant") else null
		if passive_plant != null:
			passive_plant.position += delta
		var mound := target.get_meta("visual_mound") as Node2D \
			if target.has_meta("visual_mound") else null
		if mound != null:
			mound.position += delta


func _apply_test_grid_layout() -> void:
	var targets: Array = _level.get("_targets")
	if targets.size() != 14:
		push_warning("5x3 candidate is calibrated for the 14-target harvest_02 page")
		return
	var width := _field.size.x
	var height := _field.size.y
	var left := width * 0.18
	var horizontal_gap := width * 0.125
	var first_row_y := height * 0.42
	var row_gap := height * 0.165
	for index in range(targets.size()):
		var target := targets[index] as Node2D
		if target == null:
			continue
		var row := index / 5
		var column := index % 5
		var target_x := left + float(column) * horizontal_gap
		if row == 2:
			target_x += horizontal_gap * 0.5
			column = index - 10
		var desired := Vector2(target_x, first_row_y + float(row) * row_gap)
		var delta := desired - target.position
		target.position = desired
		var passive_plant := target.get_meta("visual_plant") as Node2D \
			if target.has_meta("visual_plant") else null
		if passive_plant != null:
			passive_plant.position += delta
		var mound := target.get_meta("visual_mound") as Node2D \
			if target.has_meta("visual_mound") else null
		if mound != null:
			mound.position += delta


## Build the soil rows from the same projected anchors used by HarvestTarget.
## This is deliberately test-only: the existing 2D targets remain the sole
## hit/state objects while the 3D bed tests a coherent visual stage.
func _install_target_beds(targets: Array) -> void:
	var entries: Array[Dictionary] = []
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var canvas_point := target.get_global_transform_with_canvas().origin
		var screen_point := _field_screen_point(canvas_point)
		entries.append({"screen_y": screen_point.y,
			"ground": _world_point_for_screen(screen_point, 0.0, _object_camera)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["screen_y"]) < float(b["screen_y"]))
	if entries.is_empty():
		return

	var groups: Array[Array] = []
	var group_centres: Array[float] = []
	var row_tolerance := maxf(float(_field.size.y) * 0.065, 38.0)
	for entry in entries:
		var screen_y := float(entry["screen_y"])
		if groups.is_empty() or absf(screen_y - group_centres.back()) > row_tolerance:
			groups.append([entry])
			group_centres.append(screen_y)
		else:
			var last_index := groups.size() - 1
			var group: Array = groups[last_index]
			group.append(entry)
			groups[last_index] = group
			group_centres[last_index] += (screen_y - group_centres[last_index]) \
				/ float(group.size())

	var right_axis := _object_camera.global_basis.x
	right_axis.y = 0.0
	right_axis = right_axis.normalized()
	var depth_axis := right_axis.cross(Vector3.UP).normalized()
	var bed_basis := Basis(right_axis, Vector3.UP, depth_axis)
	var soil_material := StandardMaterial3D.new()
	soil_material.albedo_color = Color(0.34, 0.22, 0.14)
	soil_material.roughness = 1.0
	var topsoil_material := StandardMaterial3D.new()
	topsoil_material.albedo_color = Color(0.43, 0.29, 0.18)
	topsoil_material.roughness = 1.0
	var timber_material := StandardMaterial3D.new()
	timber_material.albedo_color = Color(0.62, 0.39, 0.21)
	timber_material.roughness = 0.82

	for group_variant in groups:
		var group: Array = group_variant
		var along_values: Array[float] = []
		var depth_values: Array[float] = []
		for item_variant in group:
			var item: Dictionary = item_variant
			var point: Vector3 = item["ground"]
			along_values.append(point.dot(right_axis))
			depth_values.append(point.dot(depth_axis))
		var min_along := float(along_values.min())
		var max_along := float(along_values.max())
		var centre_along := (min_along + max_along) * 0.5
		var centre_depth := 0.0
		for depth in depth_values:
			centre_depth += depth
		centre_depth /= float(depth_values.size())
		var bed_width := maxf(max_along - min_along + 0.78, 1.30)
		var bed_depth := 0.92
		var centre := right_axis * centre_along + depth_axis * centre_depth
		_add_bed_piece("Harvest3DSoilBase", Vector3(bed_width, 0.16, bed_depth),
			centre, bed_basis, Vector3(0.0, -0.08, 0.0), soil_material)
		_add_bed_piece("Harvest3DTopsoil", Vector3(bed_width - 0.15, 0.025,
			bed_depth - 0.15), centre, bed_basis, Vector3(0.0, -0.008, 0.0),
			topsoil_material)
		var rail_height := 0.12
		var rail_width := 0.09
		var rail_y := 0.045
		for side in [-1.0, 1.0]:
			_add_bed_piece("Harvest3DTimberRail", Vector3(bed_width, rail_height,
				rail_width), centre, bed_basis,
				Vector3(0.0, rail_y, side * (bed_depth - rail_width) * 0.5),
				timber_material)
			_add_bed_piece("Harvest3DTimberRail", Vector3(rail_width, rail_height,
				bed_depth - rail_width * 2.0), centre, bed_basis,
				Vector3(side * (bed_width - rail_width) * 0.5, rail_y, 0.0),
				timber_material)
		_bed_row_count += 1


## A small earth contact patch per target keeps the crop rooted without
## introducing long rails that cross or hide the actual 2D hit anchors.
func _install_target_soil_mounds(targets: Array) -> void:
	var soil_material := StandardMaterial3D.new()
	soil_material.albedo_color = Color(0.34, 0.235, 0.155)
	soil_material.roughness = 1.0
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var crop_id := str(target.crop.get("id", ""))
		var ground_canvas := target.get_global_transform_with_canvas().origin
		var plant := VisualArt.plant_layout(crop_id, 1.0)
		if plant.is_empty():
			ground_canvas += Vector2(0.0, 42.0)
		else:
			ground_canvas += Vector2(plant["ground_at"])
		var screen := _field_screen_point(ground_canvas)
		var mound := MeshInstance3D.new()
		mound.name = "Harvest3DSoilContact"
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 0.22
		mesh.radial_segments = 24
		mesh.rings = 8
		mound.mesh = mesh
		mound.material_override = soil_material
		mound.scale = Vector3(0.7, 0.32, 0.48)
		mound.position = _world_point_for_screen(screen, 0.07, _object_camera)
		mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_object_world.add_child(mound)
		_soil_mound_count += 1


## Candidate-only field tint: alter a duplicate of the authored field mesh colors
## so the planting rows share the existing terrain surface and its light.
func _tint_field_soil_rows(targets: Array) -> void:
	if _field_ground_mesh == null or _field_ground_mesh.mesh == null \
			or _field_grade_material == null:
		push_error("field vertex-tint candidate has no authored ground mesh/material")
		return
	var entries: Array[Dictionary] = []
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var target_canvas := target.get_global_transform_with_canvas().origin
		var crop_id := str(target.crop.get("id", ""))
		var plant := VisualArt.plant_layout(crop_id, 1.0)
		var ground_canvas := target_canvas + Vector2(0.0, 42.0) \
			if plant.is_empty() else target_canvas + Vector2(plant["ground_at"])
		entries.append({
			"slot_y": _field_screen_point(target_canvas).y,
			"root": _field_screen_point(ground_canvas),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["slot_y"]) < float(b["slot_y"]))
	if entries.is_empty():
		return

	var groups: Array[Array] = []
	var group_y: Array[float] = []
	var row_tolerance := maxf(float(_field.size.y) * 0.075, 42.0)
	for entry in entries:
		var y := float(entry["slot_y"])
		if groups.is_empty() or absf(y - group_y.back()) > row_tolerance:
			groups.append([entry])
			group_y.append(y)
		else:
			var group_index := groups.size() - 1
			var group: Array = groups[group_index]
			group.append(entry)
			groups[group_index] = group
			group_y[group_index] += (y - group_y[group_index]) / float(group.size())

	var row_segments: Array[Dictionary] = []
	var row_extension := float(_field.size.x) * 0.045
	for group_variant in groups:
		var group: Array = group_variant
		if group.size() < 2:
			continue
		var min_x := INF
		var max_x := -INF
		var root_y := 0.0
		for entry_variant in group:
			var entry: Dictionary = entry_variant
			var root: Vector2 = entry["root"]
			min_x = minf(min_x, root.x)
			max_x = maxf(max_x, root.x)
			root_y += root.y
		root_y /= float(group.size())
		row_segments.append({
			"start": Vector2(min_x - row_extension, root_y),
			"end": Vector2(max_x + row_extension, root_y),
		})
	if row_segments.is_empty():
		push_warning("field tint candidate found no multi-target planting rows")
		return

	var source_mesh := _field_ground_mesh.mesh as ArrayMesh
	if source_mesh == null:
		push_error("authored field mesh cannot be duplicated as ArrayMesh")
		return
	var tinted_mesh := ArrayMesh.new()
	var touched_vertices := 0
	var inner_radius := maxf(float(_field.size.y) * 0.018, 12.0)
	var outer_radius := maxf(float(_field.size.y) * 0.070, 44.0)
	var soil_tint := Color(0.52, 0.47, 0.35)
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays: Array = source_mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			push_error("field surface %d has no vertex arrays" % surface_index)
			return
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if vertices.is_empty() or vertices.size() != colors.size():
			push_error("field surface vertex/color arrays do not match")
			return
		for vertex_index in range(vertices.size()):
			var world_position := _field_ground_mesh.global_transform * vertices[vertex_index]
			var screen_position := _field_camera.unproject_position(world_position)
			var influence := 0.0
			for row in row_segments:
				var distance := _distance_to_segment(screen_position,
					row["start"], row["end"])
				var row_weight := 1.0 - smoothstep(inner_radius, outer_radius, distance)
				influence = maxf(influence, row_weight)
			if influence <= 0.001:
				continue
			colors[vertex_index] = colors[vertex_index].lerp(soil_tint, influence * 0.18)
			touched_vertices += 1
		arrays[Mesh.ARRAY_COLOR] = colors
		tinted_mesh.add_surface_from_arrays(
			source_mesh.surface_get_primitive_type(surface_index), arrays)
		tinted_mesh.surface_set_material(surface_index,
			source_mesh.surface_get_material(surface_index))
	_field_ground_mesh.mesh = tinted_mesh
	for surface_index in range(tinted_mesh.get_surface_count()):
		_field_ground_mesh.set_surface_override_material(surface_index, _field_grade_material)
	_soil_row_count = row_segments.size()
	print("3D field vertex soil tint rows=%d touched_vertices=%d" % [
		_soil_row_count, touched_vertices])


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared < 0.001:
		return point.distance_to(start)
	var fraction := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * fraction)


## Test-only continuous planting ridges; unlike contact pads these span a whole
## target row and fade into the shared field instead of outlining each crop.
func _install_target_soil_rows(targets: Array) -> void:
	var entries: Array[Dictionary] = []
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var crop_id := str(target.crop.get("id", ""))
		var target_canvas := target.get_global_transform_with_canvas().origin
		var ground_canvas := target_canvas
		var plant := VisualArt.plant_layout(crop_id, 1.0)
		if plant.is_empty():
			ground_canvas += Vector2(0.0, 42.0)
		else:
			ground_canvas += Vector2(plant["ground_at"])
		var screen := _field_screen_point(ground_canvas)
		var ground_point := _ground_point_for_screen(screen) if _shared_world_mode \
			else _world_point_for_screen(screen, 0.0, _object_camera)
		entries.append({"row_screen_y": screen.y,
			"ground": ground_point})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["row_screen_y"]) < float(b["row_screen_y"]))
	if entries.is_empty():
		return

	var row_tolerance := maxf(float(_field.size.y) * 0.075, 42.0)
	var rows: Array[Array] = []
	var row_y: Array[float] = []
	for entry in entries:
		var y := float(entry["row_screen_y"])
		if rows.is_empty() or absf(y - row_y.back()) > row_tolerance:
			rows.append([entry])
			row_y.append(y)
		else:
			var row_index := rows.size() - 1
			var row: Array = rows[row_index]
			row.append(entry)
			rows[row_index] = row
			row_y[row_index] += (y - row_y[row_index]) / float(row.size())

	var right_axis := _object_camera.global_basis.x
	right_axis.y = 0.0
	right_axis = right_axis.normalized()
	var depth_axis := right_axis.cross(Vector3.UP).normalized()
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		if row.size() < 2:
			continue
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left_ground: Vector3 = a["ground"]
			var right_ground: Vector3 = b["ground"]
			return left_ground.dot(right_axis) < right_ground.dot(right_axis))
		_add_continuous_soil_row(row, row_index, right_axis, depth_axis,
			row_y[row_index])


func _add_continuous_soil_row(row: Array, row_index: int,
		right_axis: Vector3, depth_axis: Vector3, row_screen_y: float) -> void:
	var anchors: Array[Vector3] = []
	for entry_variant in row:
		var entry: Dictionary = entry_variant
		var ground: Vector3 = entry["ground"]
		var projected := _field_camera.unproject_position(ground)
		anchors.append(_ground_point_for_screen(Vector2(projected.x, row_screen_y)))
	if anchors.size() < 2:
		return
	var half_width := 0.42
	var path_extension := 0.34
	var control_points: Array[Vector3] = [anchors[0] - right_axis * path_extension]
	control_points.append_array(anchors)
	control_points.append(anchors.back() + right_axis * path_extension)
	var path: Array[Vector3] = []
	for segment_index in range(control_points.size() - 1):
		var p0: Vector3 = control_points[maxi(segment_index - 1, 0)]
		var p1: Vector3 = control_points[segment_index]
		var p2: Vector3 = control_points[segment_index + 1]
		var p3: Vector3 = control_points[mini(segment_index + 2, control_points.size() - 1)]
		var sample_count := maxi(4, ceili(p1.distance_to(p2) / 0.16))
		for sample_index in range(sample_count):
			var t := float(sample_index) / float(sample_count)
			var t2 := t * t
			var t3 := t2 * t
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	path.append(control_points.back())

	var cross_offsets := [-1.0, -0.72, 0.0, 0.72, 1.0]
	var cross_heights := [0.0, 0.012, 0.026, 0.012, 0.0]
	var cross_colors := [
		Color(0.56, 0.63, 0.45, 0.0), Color(0.55, 0.56, 0.40, 0.24),
		Color(0.53, 0.47, 0.33, 0.38), Color(0.55, 0.56, 0.40, 0.24),
		Color(0.56, 0.63, 0.45, 0.0)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path_index in range(path.size() - 1):
		for cross_index in range(cross_offsets.size() - 1):
			var corners: Array[Vector3] = []
			var end_fades: Array[float] = []
			for point_index in [path_index, path_index + 1]:
				var endpoint_distance := mini(point_index, path.size() - 1 - point_index)
				end_fades.append(smoothstep(0.0, 3.0, float(endpoint_distance)))
				for side_index in [cross_index, cross_index + 1]:
					var point: Vector3 = path[point_index]
					var width_fade := smoothstep(0.0, 2.5, float(endpoint_distance))
					point += depth_axis * (cross_offsets[side_index] * half_width * width_fade)
					point.y += cross_heights[side_index]
					corners.append(point)
			var start_inner: Color = cross_colors[cross_index]
			var end_inner: Color = cross_colors[cross_index]
			var start_outer: Color = cross_colors[cross_index + 1]
			var end_outer: Color = cross_colors[cross_index + 1]
			start_inner.a *= end_fades[0]
			end_inner.a *= end_fades[1]
			start_outer.a *= end_fades[0]
			end_outer.a *= end_fades[1]
			_add_soil_triangle(surface, corners[0], start_inner,
				corners[1], end_inner,
				corners[2], start_outer)
			_add_soil_triangle(surface, corners[1], end_inner,
				corners[3], end_outer,
				corners[2], start_outer)
	surface.generate_normals()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Harvest3DContinuousSoilRow_%02d" % row_index
	mesh_instance.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_object_world.add_child(mesh_instance)
	_soil_row_count += 1


func _add_soil_triangle(surface: SurfaceTool,
		first: Vector3, first_color: Color,
		second: Vector3, second_color: Color,
		third: Vector3, third_color: Color) -> void:
	surface.set_color(first_color)
	surface.add_vertex(first)
	surface.set_color(second_color)
	surface.add_vertex(second)
	surface.set_color(third_color)
	surface.add_vertex(third)


func _add_bed_piece(piece_name: String, size: Vector3, centre: Vector3,
		basis: Basis, local_offset: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = piece_name
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = Transform3D(basis, centre + basis * local_offset)
	_object_world.add_child(instance)


func _add_tomato_body(target: Node2D, use_shadow_receiver: bool = false) -> bool:
	var passive_plant := target.get_meta("visual_plant", null) as Node2D
	var body_art := passive_plant.get_node_or_null("HarvestPlantBody3DArt") as TextureRect \
		if passive_plant != null else null
	if body_art == null:
		push_error("tomato target has no existing passive body art anchor")
		return false
	var base_layout := VisualArt.plant_layout("tomato", 1.0)
	if base_layout.is_empty():
		push_error("tomato body layout metadata is missing")
		return false
	var body_scale := body_art.size.x * 0.5 / float(base_layout["body_size"])
	var layout := VisualArt.plant_layout("tomato", body_scale)
	var body_ground_canvas := target.get_global_transform_with_canvas() \
		* Vector2(layout["ground_at"])
	var screen := _field_screen_point(body_ground_canvas)
	if use_shadow_receiver:
		var old_mound := target.get_meta("visual_mound", null) as Node2D
		if old_mound != null:
			old_mound.visible = false
	var body := _load_packed_gltf_scene(
		"res://assets/harvest_3d/runtime/tomato_body.glb") \
		if OS.get_environment("PILOT_RUNTIME_IMPORT") == "1" \
		else _load_gltf_scene(TOMATO_BODY_GLB)
	if body == null:
		return false
	_object_world.add_child(body)
	body.position = _ground_point_for_screen(screen)
	var art_height := _texture_art_height(body_art)
	_model_entries.append({"node": body, "kind": "body", "height": art_height,
		"target": target, "screen_anchor": screen, "ground_anchor": body.position})
	if use_shadow_receiver:
		_hide_body_art_preserving_route_bounds(body_art)
	else:
		_hide_body_art_preserving_route_bounds(body_art)
	if use_shadow_receiver and not _add_local_shadow_receiver(screen):
		return false
	_body_count += 1
	return true


func _add_strawberry_body(target: Node2D) -> bool:
	var source_path := OS.get_environment("PILOT_STRAWBERRY_BODY_GLB")
	if source_path.is_empty():
		source_path = STRAWBERRY_BED_PLANT_GLB if OS.get_environment("PILOT_STRAWBERRY_BED") == "1" \
			else STRAWBERRY_PLANT_GLB
	var body := _load_gltf_scene(source_path)
	if body == null:
		return false
	var art := target.get("_art") as Control
	if art == null:
		push_error("strawberry target art anchor is missing")
		return false
	_tune_candidate_model(body, "strawberry_plant")
	var screen := _field_screen_point(_target_ground_canvas_point(target))
	_object_world.add_child(body)
	body.position = _ground_point_for_screen(screen)
	var desired_height := _texture_art_height(art) * _pilot_float(
		"PILOT_STRAWBERRY_BODY_HEIGHT_FACTOR", 1.20, 0.9, 2.4)
	_model_entries.append({"node": body, "kind": "strawberry_body",
		"target": target, "height": desired_height,
		"screen_anchor": screen, "ground_anchor": body.position})
	if art is TextureRect:
		_hide_body_art_preserving_route_bounds(art as TextureRect)
	else:
		_hide_control(art)
	_body_count += 1
	return true


func _install_target_strawberry_bed(targets: Array) -> bool:
	var source_path := OS.get_environment("PILOT_STRAWBERRY_BED_GLB")
	if source_path.is_empty():
		source_path = STRAWBERRY_BED_GLB
	var bed_root := _load_gltf_scene(source_path)
	if bed_root == null:
		return false
	var soil_mesh: MeshInstance3D
	var fringe_meshes: Array[MeshInstance3D] = []
	for child_variant in bed_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child_variant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var node_name := mesh_instance.name.to_lower()
		if node_name.contains("continuous loam"):
			soil_mesh = mesh_instance
		elif node_name.contains("edge fringe"):
			fringe_meshes.append(mesh_instance)
	if soil_mesh == null:
		push_error("strawberry bed GLB is missing its continuous loam mesh")
		return false
	var show_fringe := OS.get_environment("PILOT_STRAWBERRY_BED_FRINGE") == "1"
	for fringe in fringe_meshes:
		fringe.visible = show_fringe

	var roots: Array[Vector2] = []
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		roots.append(_field_screen_point(_target_ground_canvas_point(target)))
	if roots.is_empty():
		push_error("strawberry bed pilot has no target ground anchors")
		return false
	var min_x := roots[0].x
	var max_x := roots[0].x
	var min_y := roots[0].y
	var max_y := roots[0].y
	for root in roots:
		min_x = minf(min_x, root.x)
		max_x = maxf(max_x, root.x)
		min_y = minf(min_y, root.y)
		max_y = maxf(max_y, root.y)
	var padding_x := _pilot_float("PILOT_STRAWBERRY_BED_PADDING_X", 58.0, 16.0, 140.0)
	var padding_y := _pilot_float("PILOT_STRAWBERRY_BED_PADDING_Y", 38.0, 16.0, 100.0)
	var desired_width_px := maxf(max_x - min_x + padding_x * 2.0, 1.0)
	var desired_depth_px := maxf(max_y - min_y + padding_y * 2.0, 1.0)
	var centre_screen := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var ground_centre := _ground_point_for_screen(centre_screen)
	var projected_centre := _object_camera.unproject_position(ground_centre)
	var right_axis := _object_camera.global_basis.x
	right_axis.y = 0.0
	right_axis = right_axis.normalized()
	var depth_axis := right_axis.cross(Vector3.UP).normalized()
	var projected_right := _object_camera.unproject_position(ground_centre + right_axis)
	var projected_depth := _object_camera.unproject_position(ground_centre + depth_axis)
	var pixels_per_world_x := absf(projected_right.x - projected_centre.x)
	var pixels_per_world_depth := absf(projected_depth.y - projected_centre.y)
	if pixels_per_world_x <= 0.001 or pixels_per_world_depth <= 0.001:
		push_error("strawberry bed has no stable screen projection")
		return false
	# Read the exported soil mesh's actual bounds after imported-node transforms;
	# source manifests can lag behind regenerated GLBs and must not drive fit.
	var mesh_to_bed_root := Transform3D.IDENTITY
	var bounds_node: Node = soil_mesh
	while bounds_node != null and bounds_node != bed_root:
		if bounds_node is Node3D:
			mesh_to_bed_root = (bounds_node as Node3D).transform * mesh_to_bed_root
		bounds_node = bounds_node.get_parent()
	if bounds_node != bed_root:
		push_error("strawberry bed soil mesh is not parented to the imported bed root")
		return false
	var soil_bounds := soil_mesh.mesh.get_aabb()
	var source_min := Vector3(INF, INF, INF)
	var source_max := Vector3(-INF, -INF, -INF)
	for corner_index in range(8):
		var corner := Vector3(
			soil_bounds.position.x if (corner_index & 1) == 0 else soil_bounds.end.x,
			soil_bounds.position.y if (corner_index & 2) == 0 else soil_bounds.end.y,
			soil_bounds.position.z if (corner_index & 4) == 0 else soil_bounds.end.z)
		var root_corner := mesh_to_bed_root * corner
		source_min = source_min.min(root_corner)
		source_max = source_max.max(root_corner)
	var source_width := maxf(source_max.x - source_min.x, 0.1)
	var source_depth := maxf(source_max.z - source_min.z, 0.1)
	var source_centre := (source_min + source_max) * 0.5
	var scale_x := desired_width_px / (source_width * pixels_per_world_x)
	var scale_z := desired_depth_px / (source_depth * pixels_per_world_depth)
	var yaw := atan2(-right_axis.z, right_axis.x)
	bed_root.rotation.y = yaw
	bed_root.scale = Vector3(scale_x, 1.0, scale_z)
	# Center the actual soil footprint on the targets while preserving its
	# authored y=0 ground-contact plane (the mound height is not scaled).
	bed_root.position = ground_centre - bed_root.basis * Vector3(
		source_centre.x, 0.0, source_centre.z)
	_object_world.add_child(bed_root)
	_planting_bed_mesh = soil_mesh
	if OS.get_environment("PILOT_BED_CONFORM_TO_FIELD") == "1" \
			and not _conform_bed_mesh_to_field(soil_mesh, bed_root):
		return false
	for root_index in range(roots.size()):
		var root_screen: Vector2 = roots[root_index]
		var bed_hit: Variant = _screen_ray_hit_mesh(root_screen, soil_mesh)
		if not bed_hit is Vector3:
			_target_bed_miss_count += 1
			print("3D strawberry bed missed root index=%d screen=%s" % [
				root_index, str(root_screen)])
			continue
		var field_hit: Variant = _screen_ray_hit_mesh(root_screen, _field_ground_mesh)
		var ray_origin := _object_camera.project_ray_origin(root_screen)
		if field_hit is Vector3 \
				and ray_origin.distance_to(field_hit) + 0.002 < ray_origin.distance_to(bed_hit):
			_target_bed_miss_count += 1
			_target_bed_occluded_count += 1
			print("3D strawberry bed occluded root index=%d screen=%s" % [
				root_index, str(root_screen)])
		else:
			_target_bed_hit_count += 1
	print("3D strawberry bed bounds_px=%.1fx%.1f soil_mesh_m=%.2fx%.2f scale=%.2fx%.2f fringe=%s" % [
		desired_width_px, desired_depth_px, source_width, source_depth,
		scale_x, scale_z, str(show_fringe)])
	if OS.get_environment("PILOT_REQUIRE_BED_ROOT_COVERAGE") == "1" \
			and _target_bed_hit_count != roots.size():
		push_error("strawberry bed misses %d target ground anchors" % _target_bed_miss_count)
		return false
	return true


func _install_target_soil_plot(targets: Array) -> bool:
	if _field_grade_material == null or _field_ground_mesh == null:
		push_error("terrain soil plot requires the shared field grade material")
		return false
	var root_screens: Array[Vector2] = []
	var root_world_points: Array[Vector3] = []
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var screen := _field_screen_point(_target_ground_canvas_point(target))
		root_screens.append(screen)
		root_world_points.append(_ground_point_for_screen(screen))
	if root_world_points.is_empty():
		push_error("terrain soil plot has no target ground anchors")
		return false
	var right_axis := _object_camera.global_basis.x
	right_axis.y = 0.0
	right_axis = right_axis.normalized()
	var depth_axis := right_axis.cross(Vector3.UP).normalized()
	var min_screen_x := root_screens[0].x
	var max_screen_x := root_screens[0].x
	var min_screen_y := root_screens[0].y
	var max_screen_y := root_screens[0].y
	for screen in root_screens:
		min_screen_x = minf(min_screen_x, screen.x)
		max_screen_x = maxf(max_screen_x, screen.x)
		min_screen_y = minf(min_screen_y, screen.y)
		max_screen_y = maxf(max_screen_y, screen.y)
	var screen_centre := Vector2(
		(min_screen_x + max_screen_x) * 0.5, (min_screen_y + max_screen_y) * 0.5)
	var world_centre := _ground_point_for_screen(screen_centre)
	var projected_centre := _object_camera.unproject_position(world_centre)
	var projected_right := _object_camera.unproject_position(world_centre + right_axis)
	var projected_depth := _object_camera.unproject_position(world_centre + depth_axis)
	var pixels_per_world_right := absf(projected_right.x - projected_centre.x)
	var pixels_per_world_depth := absf(projected_depth.y - projected_centre.y)
	if pixels_per_world_right <= 0.001 or pixels_per_world_depth <= 0.001:
		push_error("terrain soil plot has no stable screen projection")
		return false
	var right_2d := Vector2(right_axis.x, right_axis.z)
	var depth_2d := Vector2(depth_axis.x, depth_axis.z)
	var minimum_right := INF
	var maximum_right := -INF
	var minimum_depth := INF
	var maximum_depth := -INF
	for point in root_world_points:
		var offset := Vector2(point.x - world_centre.x, point.z - world_centre.z)
		var along_right := offset.dot(right_2d)
		var along_depth := offset.dot(depth_2d)
		minimum_right = minf(minimum_right, along_right)
		maximum_right = maxf(maximum_right, along_right)
		minimum_depth = minf(minimum_depth, along_depth)
		maximum_depth = maxf(maximum_depth, along_depth)
	var pad_x := _pilot_float("PILOT_SOIL_PLOT_PADDING_X", 76.0, 0.0, 180.0) \
		/ pixels_per_world_right
	var pad_depth := _pilot_float("PILOT_SOIL_PLOT_PADDING_Y", 56.0, 0.0, 180.0) \
		/ pixels_per_world_depth
	var half_size := Vector2(
		(maximum_right - minimum_right) * 0.5 + pad_x,
		(maximum_depth - minimum_depth) * 0.5 + pad_depth)
	var centre_right := (maximum_right + minimum_right) * 0.5
	var centre_depth := (maximum_depth + minimum_depth) * 0.5
	var centre_xz := Vector2(world_centre.x, world_centre.z) \
		+ right_2d * centre_right + depth_2d * centre_depth
	var outside_roots: Array[int] = []
	for point_index in range(root_world_points.size()):
		var point: Vector3 = root_world_points[point_index]
		var offset := Vector2(point.x, point.z) - centre_xz
		var plot_point := Vector2(offset.dot(right_2d), offset.dot(depth_2d)) / half_size
		var root_shape := pow(absf(plot_point.x), 4.0) + pow(absf(plot_point.y), 4.0)
		_soil_plot_root_total += 1
		if root_shape <= 0.90:
			_soil_plot_root_inside_count += 1
		else:
			outside_roots.append(point_index)
	_field_grade_material.set_shader_parameter("soil_plot_enabled", true)
	_field_grade_material.set_shader_parameter("soil_plot_center_xz", centre_xz)
	_field_grade_material.set_shader_parameter("soil_plot_right_axis", right_2d)
	_field_grade_material.set_shader_parameter("soil_plot_depth_axis", depth_2d)
	_field_grade_material.set_shader_parameter("soil_plot_half_size", half_size)
	_field_grade_material.set_shader_parameter("soil_plot_color", Color(
		_pilot_float("PILOT_SOIL_PLOT_COLOR_R", 0.43, 0.18, 0.55),
		_pilot_float("PILOT_SOIL_PLOT_COLOR_G", 0.25, 0.12, 0.42),
		_pilot_float("PILOT_SOIL_PLOT_COLOR_B", 0.15, 0.08, 0.36)))
	_field_grade_material.set_shader_parameter("soil_plot_strength",
		_pilot_float("PILOT_SOIL_PLOT_STRENGTH", 0.58, 0.0, 1.0))
	_field_grade_material.set_shader_parameter("soil_plot_edge_softness",
		_pilot_float("PILOT_SOIL_PLOT_EDGE_SOFTNESS", 0.035, 0.01, 0.30))
	print("3D terrain soil plot roots=%d inside=%d bounds_m=%.2fx%.2f ppu=%.1f/%.1f" % [
		root_world_points.size(), _soil_plot_root_inside_count,
		half_size.x * 2.0, half_size.y * 2.0,
		pixels_per_world_right, pixels_per_world_depth])
	if OS.get_environment("PILOT_REQUIRE_SOIL_PLOT_ROOT_COVERAGE") == "1" \
			and not outside_roots.is_empty():
		push_error("soil plot misses target roots %s" % str(outside_roots))
		return false
	return true


func _conform_bed_mesh_to_field(soil_mesh: MeshInstance3D, bed_root: Node3D) -> bool:
	var source_mesh := soil_mesh.mesh as ArrayMesh
	if source_mesh == null or _field_ground_mesh == null:
		push_error("bed conform pilot requires an ArrayMesh and the shared field mesh")
		return false
	var field_triangles := _world_triangle_cache(_field_ground_mesh)
	var root_inverse := bed_root.global_transform.affine_inverse()
	var mesh_inverse := soil_mesh.global_transform.affine_inverse()
	var mesh_transform := soil_mesh.global_transform
	var conformed_mesh := ArrayMesh.new()
	var conformed_vertices := 0
	var missed_vertices := 0
	var lift := _pilot_float("PILOT_BED_CONFORM_LIFT", 0.012, 0.0, 0.20)
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays: Array = source_mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue
		for vertex_index in range(vertices.size()):
			var world_vertex: Vector3 = mesh_transform * vertices[vertex_index]
			var root_vertex: Vector3 = root_inverse * world_vertex
			var terrain_y := _field_height_from_cache(world_vertex.x, world_vertex.z, field_triangles)
			if not is_finite(terrain_y):
				missed_vertices += 1
				continue
			var conform_world := Vector3(
				world_vertex.x, terrain_y + root_vertex.y + lift, world_vertex.z)
			vertices[vertex_index] = mesh_inverse * conform_world
			conformed_vertices += 1
		arrays[Mesh.ARRAY_VERTEX] = vertices
		conformed_mesh.add_surface_from_arrays(
			source_mesh.surface_get_primitive_type(surface_index), arrays)
		var material := source_mesh.surface_get_material(surface_index)
		if material != null:
			conformed_mesh.surface_set_material(surface_index, material)
	soil_mesh.mesh = conformed_mesh
	print("3D bed conforms to field vertices=%d misses=%d lift=%.3f" % [
		conformed_vertices, missed_vertices, lift])
	return conformed_vertices > 0 and missed_vertices == 0


func _world_triangle_cache(mesh_instance: MeshInstance3D) -> Dictionary:
	var triangles_a := PackedVector3Array()
	var triangles_b := PackedVector3Array()
	var triangles_c := PackedVector3Array()
	var min_x := PackedFloat32Array()
	var max_x := PackedFloat32Array()
	var min_z := PackedFloat32Array()
	var max_z := PackedFloat32Array()
	var transform := mesh_instance.global_transform
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle_index in range(triangle_count):
			var first_index := triangle_index * 3
			var second_index := first_index + 1
			var third_index := first_index + 2
			if not indices.is_empty():
				first_index = indices[first_index]
				second_index = indices[second_index]
				third_index = indices[third_index]
			var first: Vector3 = transform * vertices[first_index]
			var second: Vector3 = transform * vertices[second_index]
			var third: Vector3 = transform * vertices[third_index]
			triangles_a.append(first)
			triangles_b.append(second)
			triangles_c.append(third)
			min_x.append(minf(first.x, minf(second.x, third.x)))
			max_x.append(maxf(first.x, maxf(second.x, third.x)))
			min_z.append(minf(first.z, minf(second.z, third.z)))
			max_z.append(maxf(first.z, maxf(second.z, third.z)))
	return {"a": triangles_a, "b": triangles_b, "c": triangles_c,
		"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}


func _field_height_from_cache(world_x: float, world_z: float,
		triangles: Dictionary) -> float:
	var triangles_a := triangles["a"] as PackedVector3Array
	var triangles_b := triangles["b"] as PackedVector3Array
	var triangles_c := triangles["c"] as PackedVector3Array
	var min_x := triangles["min_x"] as PackedFloat32Array
	var max_x := triangles["max_x"] as PackedFloat32Array
	var min_z := triangles["min_z"] as PackedFloat32Array
	var max_z := triangles["max_z"] as PackedFloat32Array
	var ray_origin := Vector3(world_x, 10000.0, world_z)
	var highest_hit := -INF
	for triangle_index in range(triangles_a.size()):
		if world_x < min_x[triangle_index] - 0.0001 \
				or world_x > max_x[triangle_index] + 0.0001 \
				or world_z < min_z[triangle_index] - 0.0001 \
				or world_z > max_z[triangle_index] + 0.0001:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			ray_origin, Vector3.DOWN, triangles_a[triangle_index],
			triangles_b[triangle_index], triangles_c[triangle_index])
		if hit is Vector3:
			highest_hit = maxf(highest_hit, (hit as Vector3).y)
	return highest_hit if is_finite(highest_hit) else NAN


func _add_local_shadow_receiver(screen: Vector2,
		receiver_size: Vector2 = Vector2(2.6, 1.9)) -> bool:
	if not ResourceLoader.exists(SHADOW_RECEIVER_SHADER):
		push_error("local shadow receiver shader is missing")
		return false
	var plane := PlaneMesh.new()
	plane.size = receiver_size
	var receiver := MeshInstance3D.new()
	receiver.name = "LocalPlantShadowReceiver"
	receiver.mesh = plane
	receiver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load(SHADOW_RECEIVER_SHADER) as Shader
	receiver.material_override = material
	receiver.position = _world_point_for_screen(screen, 0.015, _object_camera)
	_object_world.add_child(receiver)
	_shadow_receiver_count += 1
	return true


func _install_target_shadow_receivers(targets: Array) -> void:
	for target_variant in targets:
		var target := target_variant as Node2D
		if target == null:
			continue
		var crop_id := str(target.crop.get("id", ""))
		var plant := VisualArt.plant_layout(crop_id, 1.0)
		var receiver_size := Vector2(1.18, 0.82) if not plant.is_empty() \
			else Vector2(0.72, 0.5)
		var ground_canvas := _target_ground_canvas_point(target, plant)
		var screen := _field_screen_point(ground_canvas)
		if not _add_local_shadow_receiver(screen, receiver_size):
			return


func _target_ground_canvas_point(target: Node2D, plant: Dictionary = {}) -> Vector2:
	var ground_canvas := target.get_global_transform_with_canvas().origin
	if plant.is_empty():
		plant = VisualArt.plant_layout(str(target.crop.get("id", "")), 1.0)
	if plant.is_empty():
		return ground_canvas + Vector2(0.0, 42.0)
	return ground_canvas + Vector2(plant["ground_at"])


func _hide_body_art_preserving_route_bounds(body_art: TextureRect) -> void:
	# HarvestAction computes held-route obstacles from this existing source-art
	# rectangle. Keep that shared geometry queryable while replacing only its
	# pixels with the GLB; otherwise the 3D body would not participate in route
	# avoidance at all.
	body_art.visible = true
	body_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_art.material = null
	body_art.self_modulate = Color(1.0, 1.0, 1.0, 0.0)


func _add_target_model(target: Node2D, source_path: String, tomato: bool) -> bool:
	var art := target.get("_art") as Control
	if art == null:
		push_error("target art anchor is missing for %s" % str(target.crop.get("id", "")))
		return false
	var active_source_path := source_path
	var crop_id := str(target.crop.get("id", ""))
	if OS.get_environment("PILOT_CROP_CATALOG") == "1":
		active_source_path = CROP_CATALOG_ROOT + crop_id + ".glb"
	elif OS.get_environment("PILOT_RUNTIME_IMPORT") == "1":
		active_source_path = "res://assets/harvest_3d/runtime/%s.glb" % (
			"tomato_fruit" if tomato else "strawberry")
	var model := _load_packed_gltf_scene(active_source_path) \
		if OS.get_environment("PILOT_CROP_CATALOG") == "1" \
		or OS.get_environment("PILOT_RUNTIME_IMPORT") == "1" \
		else _load_gltf_scene(source_path)
	if model == null:
		return false
	_object_world.add_child(model)
	if tomato:
		_apply_fruit_maturity_material(model, "tomato", str(target.step))
	else:
		_apply_fruit_maturity_material(model, "strawberry", str(target.step))
	_tune_candidate_model(model, crop_id, str(target.step))
	var model_height := _texture_art_height(art)
	var ground_offset := 0.0 if tomato else 42.0
	var fruit_height := _pilot_float("PILOT_TOMATO_SLOT_HEIGHT",
		TOMATO_SLOT_HEIGHT, 0.0, 2.0) if tomato else 0.0
	if OS.get_environment("PILOT_CROP_CATALOG") == "1":
		if tomato:
			var plant := VisualArt.plant_layout(crop_id, 1.0)
			if not plant.is_empty():
				var fruit_center: Vector2 = plant["fruit_center_pixel"]
				var source_to_art := art.size.x * VisualArt.SPRITE_CANVAS_MULTIPLIER \
					/ VisualArt.SOURCE_CANVAS_SIZE
				ground_offset = (VisualArt.GROUND_ORIGIN_PIXEL_Y - fruit_center.y) \
					* source_to_art
	_model_entries.append({
		"node": model,
		"kind": "fruit",
		"target": target,
		"tomato": tomato,
		"height": model_height,
		"maturity_scale": float(Maturity.look(str(target.step), target.crop).get("scale", 1.0)),
		"fruit_height": fruit_height,
		"ground_offset": ground_offset,
	})
	if art is TextureRect:
		_hide_body_art_preserving_route_bounds(art as TextureRect)
	else:
		_hide_control(art)
	if OS.get_environment("PILOT_CROP_CATALOG") == "1":
		print("3D crop catalog model=%s source=%s" % [crop_id, active_source_path])
	_fruit_count += 1
	return true


func _load_packed_gltf_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_error("imported crop catalog scene is missing: %s" % path)
		return null
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_error("crop catalog GLB did not import as PackedScene: %s" % path)
		return null
	var scene := packed.instantiate() as Node3D
	if scene == null or scene.find_children("*", "MeshInstance3D", true, false).is_empty():
		push_error("crop catalog scene has no 3D mesh: %s" % path)
		return null
	return scene


func _add_basket_model(basket: Node2D) -> bool:
	var basket_art := basket.get_node_or_null("HarvestBasket3DArt") as TextureRect
	if basket_art == null:
		push_error("basket art anchor is missing")
		return false
	var model := _load_packed_gltf_scene("res://assets/harvest_3d/runtime/basket.glb") \
		if OS.get_environment("PILOT_RUNTIME_IMPORT") == "1" \
		else _load_gltf_scene(BASKET_GLB)
	if model == null:
		return false
	_tune_candidate_model(model, "basket")
	_object_world.add_child(model)
	var size := float(basket.get("_size"))
	var ground_canvas_position := basket.get_global_transform_with_canvas().origin \
		+ Vector2(0.0, size * 0.52)
	var screen_anchor := _field_screen_point(ground_canvas_position)
	model.position = _ground_point_for_screen(screen_anchor)
	_model_entries.append({
		"node": model,
		"kind": "basket",
		"height": _texture_art_height(basket_art),
		"screen_anchor": screen_anchor,
		"ground_anchor": model.position,
	})
	_hide_control(basket_art)
	_basket_count += 1
	return true


## Local candidate-only response tuning. Keep authored GLB source materials
## untouched so the runtime-import pilot can still validate those originals.
func _tune_candidate_model(root: Node, model_kind: String,
		maturity_step: String = Maturity.READY) -> void:
	var tint := Color.WHITE
	var roughness_floor := 0.82
	match model_kind:
		"basket":
			# Pull the pale studio wicker back toward the warm, matte basket already
			# used by the HUD and field; diffuse the sharp highlights.
			tint = Color(0.84, 0.78, 0.69)
			roughness_floor = 0.94
		"strawberry_plant":
			# The candidate is lit again in the live field; mute its pale studio
			# greens so foliage sits with the existing field and berry materials.
			tint = Color(
				_pilot_float("PILOT_STRAWBERRY_PLANT_TINT_R", 0.62, 0.35, 1.4),
				_pilot_float("PILOT_STRAWBERRY_PLANT_TINT_G", 0.68, 0.35, 1.4),
				_pilot_float("PILOT_STRAWBERRY_PLANT_TINT_B", 0.92, 0.35, 1.4))
			roughness_floor = 0.96
		"strawberry":
			# Keep the source asset's authored berry color in this same-source pilot.
			tint = Color.WHITE
			roughness_floor = 0.94
		"tomato":
			tint = Color.WHITE
			roughness_floor = 0.94
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if model_kind == "basket" and _shared_world_mode \
				and OS.get_environment("PILOT_RECEIVE_FIELD_SHADOWS") == "1":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index) \
				as StandardMaterial3D
			if source == null:
				continue
			var material_name := source.resource_name.to_lower()
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color *= tint
			if maturity_step == Maturity.READY:
				if model_kind == "strawberry" and material_name.contains("ripe berry"):
					material.albedo_color *= Color(0.82, 0.62, 0.60)
				elif model_kind == "tomato" and material_name.contains("ripe red"):
					material.albedo_color *= Color(0.82, 0.54, 0.58)
			material.roughness = maxf(material.roughness, roughness_floor)
			material.metallic = 0.0
			mesh_instance.set_surface_override_material(surface_index, material)


func _apply_fruit_maturity_material(root: Node3D, crop_id: String, step: String) -> void:
	if step == Maturity.READY:
		return
	var ripe_color := Color(0.82, 0.045, 0.025)
	var target_color := Color(0.46, 0.70, 0.20)
	if step == Maturity.ALMOST:
		target_color = Color(0.70, 0.75, 0.24)
	elif step == Maturity.GOLDEN:
		target_color = Color(0.98, 0.66, 0.12)
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index) \
				as StandardMaterial3D
			if source_material == null:
				continue
			var name := source_material.resource_name.to_lower()
			var is_berry_body := crop_id == "strawberry" and name.contains("ripe berry")
			var is_tomato_body := crop_id == "tomato" \
				and (name.contains("ripe red") or name.contains("shoulder red"))
			if not is_berry_body and not is_tomato_body:
				continue
			var material := source_material.duplicate() as StandardMaterial3D
			material.albedo_color = target_color
			mesh_instance.set_surface_override_material(surface_index, material)


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


func _projected_height(root: Node3D) -> float:
	var top := INF
	var bottom := -INF
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var bounds := mesh_instance.mesh.get_aabb()
		for corner in _aabb_corners(bounds):
			var screen := _object_camera.unproject_position(mesh_instance.global_transform * corner)
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


func _update_dynamic_models() -> void:
	var expired: Array[Node3D] = []
	for entry in _model_entries:
		if entry["kind"] == "strawberry_body":
			var plant_target_ref: Variant = entry.get("target")
			var plant_ref: Variant = entry.get("node")
			if is_instance_valid(plant_ref) and is_instance_valid(plant_target_ref):
				(plant_ref as Node3D).visible = (plant_target_ref as Node2D).is_visible_in_tree()
			continue
		if entry["kind"] != "fruit":
			continue
		if not entry.has("fit"):
			continue
		var target_ref: Variant = entry.get("target")
		if not is_instance_valid(target_ref):
			var expired_model: Variant = entry.get("node")
			if is_instance_valid(expired_model):
				expired.append(expired_model as Node3D)
			continue
		var target := target_ref as Node2D
		var model_ref: Variant = entry.get("node")
		if target == null or not is_instance_valid(model_ref):
			if is_instance_valid(model_ref):
				expired.append(model_ref as Node3D)
			continue
		var model := model_ref as Node3D
		var local_anchor := Vector2.ZERO
		var visual := target.get("_visual") as Node2D
		if visual != null:
			local_anchor = visual.position
		local_anchor.y += float(entry["ground_offset"])
		var canvas_position := target.get_global_transform_with_canvas() * local_anchor
		var viewport_point := _field_screen_point(canvas_position)
		var fruit_slot_ref: Variant = entry.get("fruit_slot")
		var fruit_slot: Node3D = null
		if is_instance_valid(fruit_slot_ref):
			fruit_slot = fruit_slot_ref as Node3D
		if target.taken:
			if not entry.has("carry_origin_screen"):
				entry["carry_origin_screen"] = entry.get("screen_anchor", viewport_point)
				entry["carry_origin_position"] = model.position
			var carry_origin_screen: Vector2 = entry["carry_origin_screen"]
			var carry_origin_position: Vector3 = entry["carry_origin_position"]
			model.position = carry_origin_position + _world_offset_for_screen_delta(
				viewport_point - carry_origin_screen)
		else:
			entry.erase("carry_origin_screen")
			entry.erase("carry_origin_position")
			if fruit_slot != null:
				model.position = fruit_slot.global_position
				viewport_point = _object_camera.unproject_position(model.position)
				entry["ground_anchor"] = model.position
			else:
				var previous_screen_anchor: Vector2 = entry.get("screen_anchor", viewport_point)
				var screen_delta := viewport_point.distance_to(previous_screen_anchor)
				var ground_anchor: Vector3
				if _shared_world_mode and screen_delta <= 1.25 \
						and entry.has("ground_anchor"):
					ground_anchor = entry["ground_anchor"]
				else:
					ground_anchor = _ground_point_for_screen(viewport_point)
					entry["ground_anchor"] = ground_anchor
				model.position = ground_anchor + Vector3.UP * float(entry["fruit_height"])
			entry["screen_anchor"] = viewport_point
		model.rotation.y = deg_to_rad(float(target.rotation_degrees))
		var state_scale := float(entry["maturity_scale"]) * absf(target.scale.x)
		var fruit_scale_key := "PILOT_TOMATO_FRUIT_SCALE" \
			if bool(entry.get("tomato", false)) else "PILOT_FRUIT_SCALE"
		var fruit_scale := _pilot_float(fruit_scale_key, 1.0, 0.85, 1.7)
		model.scale = Vector3.ONE * float(entry["fit"]) * state_scale * fruit_scale
		model.visible = target.is_visible_in_tree()
	for model in expired:
		_model_entries = _model_entries.filter(func(entry: Dictionary) -> bool:
			return entry["node"] != model)
		model.queue_free()


func _process(_delta: float) -> void:
	_update_dynamic_models()


func _field_screen_point(canvas_position: Vector2) -> Vector2:
	var field_to_canvas := _field.get_global_transform_with_canvas()
	var local_point := field_to_canvas.affine_inverse() * canvas_position
	var scale := Vector2(_object_viewport.size) / Vector2(_field.size)
	return local_point * scale


func _world_point_for_screen(screen_point: Vector2, height: float, camera: Camera3D) -> Vector3:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	if absf(direction.y) < 0.0001:
		return Vector3(screen_point.x, height, screen_point.y)
	var distance := (height - origin.y) / direction.y
	return origin + direction * distance


func _ground_point_for_screen(screen_point: Vector2) -> Vector3:
	if not _shared_world_mode or _field_ground_mesh == null \
			or _field_ground_mesh.mesh == null:
		return _world_point_for_screen(screen_point, 0.0, _object_camera)
	_ground_hit_queries += 1

	var ray_origin := _object_camera.project_ray_origin(screen_point)
	var ray_direction := _object_camera.project_ray_normal(screen_point).normalized()
	var nearest_distance := INF
	var nearest_hit := Vector3.ZERO
	var found_hit := false
	var surfaces: Array[MeshInstance3D] = [_field_ground_mesh]
	if _planting_bed_mesh != null and is_instance_valid(_planting_bed_mesh):
		surfaces.append(_planting_bed_mesh)
	for surface_mesh in surfaces:
		if surface_mesh == null or surface_mesh.mesh == null:
			continue
		var transform := surface_mesh.global_transform
		for surface_index in range(surface_mesh.mesh.get_surface_count()):
			var arrays: Array = surface_mesh.mesh.surface_get_arrays(surface_index)
			if arrays.is_empty():
				continue
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if vertices.is_empty():
				continue
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			for triangle_index in range(triangle_count):
				var first_index := indices[triangle_index * 3] if not indices.is_empty() \
					else triangle_index * 3
				var second_index := indices[triangle_index * 3 + 1] if not indices.is_empty() \
					else triangle_index * 3 + 1
				var third_index := indices[triangle_index * 3 + 2] if not indices.is_empty() \
					else triangle_index * 3 + 2
				var first := transform * vertices[first_index]
				var second := transform * vertices[second_index]
				var third := transform * vertices[third_index]
				var hit: Variant = Geometry3D.ray_intersects_triangle(
					ray_origin, ray_direction, first, second, third)
				if not hit is Vector3:
					continue
				var hit_point := hit as Vector3
				var distance := ray_origin.distance_to(hit_point)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_hit = hit_point
					found_hit = true
	if found_hit:
		return nearest_hit + Vector3.UP * 0.012
	_ground_missed_queries += 1
	push_warning("shared-world screen anchor missed the field mesh; using flat fallback")
	return _world_point_for_screen(screen_point, 0.0, _object_camera)


func _screen_ray_hit_mesh(screen_point: Vector2, surface_mesh: MeshInstance3D) -> Variant:
	if surface_mesh == null or surface_mesh.mesh == null:
		return null
	var ray_origin := _object_camera.project_ray_origin(screen_point)
	var ray_direction := _object_camera.project_ray_normal(screen_point).normalized()
	var transform := surface_mesh.global_transform
	var nearest_distance := INF
	var nearest_hit := Vector3.ZERO
	var found_hit := false
	for surface_index in range(surface_mesh.mesh.get_surface_count()):
		var arrays: Array = surface_mesh.mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		if vertices.is_empty():
			continue
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle_index in range(triangle_count):
			var first_index := indices[triangle_index * 3] if not indices.is_empty() \
				else triangle_index * 3
			var second_index := indices[triangle_index * 3 + 1] if not indices.is_empty() \
				else triangle_index * 3 + 1
			var third_index := indices[triangle_index * 3 + 2] if not indices.is_empty() \
				else triangle_index * 3 + 2
			var first := transform * vertices[first_index]
			var second := transform * vertices[second_index]
			var third := transform * vertices[third_index]
			var hit: Variant = Geometry3D.ray_intersects_triangle(
				ray_origin, ray_direction, first, second, third)
			if not hit is Vector3:
				continue
			var hit_point := hit as Vector3
			var distance := ray_origin.distance_to(hit_point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_hit = hit_point
				found_hit = true
	return nearest_hit if found_hit else null


func _world_offset_for_screen_delta(delta: Vector2) -> Vector3:
	var pixels_per_world_unit := float(_object_viewport.size.x) \
		/ maxf(_object_camera.size, 0.001)
	if pixels_per_world_unit <= 0.001:
		return Vector3.ZERO
	return _object_camera.global_basis.x * (delta.x / pixels_per_world_unit) \
		- _object_camera.global_basis.y * (delta.y / pixels_per_world_unit)


func _load_gltf_scene(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		push_error("same-source GLB is not readable: %s" % path)
		return null
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var error := gltf.append_from_file(path, state)
	if error != OK:
		push_error("GLB load failed for %s: %s" % [path, error_string(error)])
		return null
	var scene := gltf.generate_scene(state) as Node3D
	if scene == null:
		push_error("GLB scene is not a Node3D: %s" % path)
	return scene


func _hide_control(control: Control) -> void:
	control.visible = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pick_one_strawberry() -> bool:
	var targets: Array = _level.get("_targets")
	var chosen: Node2D = null
	var shortest_route := INF
	for candidate_variant in targets:
		var candidate := candidate_variant as Node2D
		if candidate == null or str(candidate.crop.get("id", "")) != "strawberry":
			continue
		if candidate.step not in [Maturity.READY, Maturity.GOLDEN] \
				or not _level.call("_target_is_available_now", candidate):
			continue
		var destination := _level.call("_destination_for", candidate) as Node2D
		if destination == null:
			continue
		var route := candidate.global_position.distance_to(destination.global_position)
		if route < shortest_route:
			shortest_route = route
			chosen = candidate
	if chosen == null:
		push_error("no available ripe strawberry for held-state render")
		return false
	return await _pick_target_for_held_render(chosen)


func _pick_one_local_tomato() -> bool:
	if _single_tomato_target == null \
			or not _level.call("_target_is_available_now", _single_tomato_target):
		push_error("local ripe tomato is not available for held-state render")
		return false
	return await _pick_target_for_held_render(_single_tomato_target)


func _pick_target_for_held_render(chosen: Node2D) -> bool:
	print("3D held render requested crop=%s pos=%s" % [
		str(chosen.crop.get("id", "")), str(chosen.global_position)])
	var path: PackedVector2Array = Gesture.demo_path(
		str(chosen.crop.get("recogniser", "")),
		chosen.crop.get("gesture_params", {}), chosen.global_position,
		float(chosen.get("radius")))
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
	var held_target := _level.get("_in_hand") as Node2D
	if held_target != chosen:
		push_error("integrated pilot held a different target than requested")
		print("3D held render actual=%s pos=%s" % [
			str(held_target.crop.get("id", "")) if held_target != null else "none",
			str(held_target.global_position) if held_target != null else "none"])
		return false
	return true


func _deliver_held_crop() -> bool:
	var held := _level.get("_in_hand") as Node2D
	if held == null:
		push_error("runtime crop delivery has no held target")
		return false
	var basket := _level.call("_destination_for", held) as Node2D
	if basket == null or not bool(_level.call("_basket_accepts", held, basket)):
		push_error("existing basket resolver rejected the runtime crop")
		return false
	var crop_id := str(held.crop.get("id", ""))
	var picked_before: Dictionary = (_level.get("_picked") as Dictionary).duplicate(true)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _window_point(basket.global_position)
	Input.parse_input_event(down)
	await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = down.position
	Input.parse_input_event(release)
	for _frame in range(12):
		await get_tree().process_frame
	var picked_after: Dictionary = _level.get("_picked")
	var delivered := _level.get("_in_hand") == null \
		and int(picked_after.get(crop_id, 0)) \
		== int(picked_before.get(crop_id, 0)) + 1
	print("3D catalog touch delivery=%s basket=%s picked=%s" % [
		str(delivered), str(basket.get("id")), str(picked_after)])
	if not delivered:
		push_error("runtime crop did not follow existing basket touch delivery")
	return delivered


func _log_local_model_alignment() -> void:
	var target_point := _field_screen_point(
		_single_tomato_target.get_global_transform_with_canvas().origin)
	print("3D local target screen=%s" % str(target_point))
	for entry in _model_entries:
		if entry.get("target") != _single_tomato_target:
			continue
		var model := entry["node"] as Node3D
		var anchor := _object_camera.unproject_position(model.global_position)
		var screen_anchor: Variant = entry.get("screen_anchor", Vector2.INF)
		print("3D local %s requested_screen=%s root_screen=%s projected_bounds=%s" % [
			str(entry["kind"]), str(screen_anchor), str(anchor),
			str(_projected_bounds(model))])


func _projected_bounds(root: Node3D) -> Rect2:
	var bounds := Rect2(Vector2(INF, INF), Vector2(-INF, -INF))
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for corner in _aabb_corners(mesh_instance.mesh.get_aabb()):
			var point := _object_camera.unproject_position(mesh_instance.global_transform * corner)
			bounds.position.x = minf(bounds.position.x, point.x)
			bounds.position.y = minf(bounds.position.y, point.y)
			bounds.end.x = maxf(bounds.end.x, point.x)
			bounds.end.y = maxf(bounds.end.y, point.y)
	return bounds


func _window_point(point: Vector2) -> Vector2:
	var window_size := Vector2(get_window().size)
	return Vector2(point.x * window_size.x / float(_viewport_size.x),
		point.y * window_size.y / float(_viewport_size.y))
