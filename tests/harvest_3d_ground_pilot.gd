extends Node
## Isolated A/B render only. It overlays the same-source passive field GLB
## behind the real HarvestAction sprites without changing runtime gameplay.

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const ENVIRONMENT_GLB := "res://assets/harvest_3d/source/whole_plant/environment_refined/passive_environment.glb"
const HARVEST_SCENE := "res://scenes/minigames/harvest_action/HarvestAction.tscn"
const ENVIRONMENT_ORTHO_WIDTH := 18.488889

var _level: Node2D
var _viewport_size := Vector2.ZERO


func _ready() -> void:
	var window := _requested_window()
	get_window().size = window
	await get_tree().process_frame
	_viewport_size = get_viewport().get_visible_rect().size

	GameManager.current_level_id = "harvest_08"
	SaveManager.clear_harvest_checkpoint("harvest_08")
	SaveManager.set_setting("difficulty", 2)
	SaveManager.set_setting("reduce_motion", true)
	_level = load(HARVEST_SCENE).instantiate() as Node2D
	add_child(_level)
	for _frame in range(8):
		await get_tree().process_frame

	if not _install_same_source_environment():
		await ProbeLifecycle.finish(self, 2)
		return

	if OS.get_environment("PILOT_HELD") == "1":
		if not await _pick_one_strawberry():
			await ProbeLifecycle.finish(self, 3)
			return

	for _frame in range(5):
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
	print("3D ground pilot image=%s size=%s" % [screenshot_path, screenshot.get_size()])
	print("3D ground pilot content=%s save=%s" % [str(content_ok), error_string(save_error)])
	await ProbeLifecycle.finish(self, 0 if content_ok and save_error == OK else 5)


func _requested_window() -> Vector2i:
	var text := OS.get_environment("SHOT_WINDOW")
	if text.contains("x"):
		var dimensions := text.split("x")
		return Vector2i(int(dimensions[0]), int(dimensions[1]))
	return Vector2i(1280, 720)


func _install_same_source_environment() -> bool:
	var field := _level.get("_field") as Control
	if field == null:
		push_error("HarvestAction has no field Control")
		return false
	if not FileAccess.file_exists(ENVIRONMENT_GLB):
		push_error("same-source environment GLB not readable from res://")
		return false

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var load_error := gltf.append_from_file(ENVIRONMENT_GLB, state)
	if load_error != OK:
		push_error("GLTFDocument import failed: %s" % error_string(load_error))
		return false
	var source_scene := gltf.generate_scene(state)
	if source_scene == null:
		push_error("GLTFDocument did not generate the passive environment scene")
		return false
	_apply_vertex_color_material(source_scene)

	var container := SubViewportContainer.new()
	container.name = "IsolatedSameSourceGroundPilot"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	container.z_index = -15
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	container.material = _ground_edge_blend_material()
	field.add_child(container)
	field.move_child(container, 1)

	var subviewport := SubViewport.new()
	subviewport.name = "GroundPilotViewport"
	subviewport.transparent_bg = true
	subviewport.own_world_3d = true
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(subviewport)

	var world := Node3D.new()
	world.name = "SameSource3DWorld"
	subviewport.add_child(world)
	world.add_child(source_scene)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.88, 0.92, 1.0)
	environment.ambient_light_energy = 0.68
	world_environment.environment = environment
	world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SoftMeadowSun"
	sun.rotation_degrees = Vector3(-34.0, -28.0, -18.0)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	world.add_child(sun)

	var camera := Camera3D.new()
	camera.name = "SameSourceOrthographicCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = ENVIRONMENT_ORTHO_WIDTH
	camera.near = 0.05
	camera.far = 100.0
	# Converted from the frozen Blender profile (x, y, z-up) to Godot (x, y-up, z).
	camera.position = Vector3(6.7, 6.8, 9.8)
	world.add_child(camera)
	camera.look_at(Vector3(0.14, 1.03, 0.12), Vector3.UP)
	camera.current = true
	return true


func _ground_edge_blend_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
uniform float blend_start : hint_range(0.0, 1.0) = 0.09;
uniform float blend_end : hint_range(0.0, 1.0) = 0.25;
void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	color.a *= smoothstep(blend_start, blend_end, UV.y);
	COLOR = color;
}
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _apply_vertex_color_material(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if not mesh_instance.name.contains("continuous gentle field"):
			continue
		var colors := PackedColorArray()
		if mesh_instance.mesh.get_surface_count() > 0:
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
			colors = arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		if colors.is_empty():
			push_error("same-source ground mesh lost its authored vertex colors")
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.2, 1.05, 1.8)
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			mesh_instance.set_surface_override_material(surface_index, material)
		print("3D ground pilot: authored vertex colors=%d" % colors.size())


func _pick_one_strawberry() -> bool:
	var targets: Array = _level.get("_targets")
	for candidate in targets:
		if str(candidate.crop.get("id", "")) != "strawberry":
			continue
		if not candidate.step in ["ready", "golden"]:
			continue
		if not _level.call("_target_is_available_now", candidate):
			continue
		var path: PackedVector2Array = Gesture.demo_path(
			str(candidate.crop.get("recogniser", "")),
			candidate.crop.get("gesture_params", {}),
			candidate.global_position,
			float(candidate.get("radius")))
		for index in range(path.size()):
			var screen_point := _window_point(path[index])
			if index == 0:
				var down := InputEventScreenTouch.new()
				down.index = 0
				down.pressed = true
				down.position = screen_point
				Input.parse_input_event(down)
			else:
				var drag := InputEventScreenDrag.new()
				drag.index = 0
				drag.position = screen_point
				drag.relative = screen_point - _window_point(path[index - 1])
				Input.parse_input_event(drag)
			await get_tree().process_frame
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.pressed = false
		release.position = _window_point(path[path.size() - 1])
		Input.parse_input_event(release)
		for _frame in range(8):
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		if _level.get("_in_hand") == null:
			push_error("same-source 3D pilot could not create a held strawberry")
			return false
		return true
	push_error("no available ripe strawberry for the held-state A/B render")
	return false


func _window_point(point: Vector2) -> Vector2:
	var window_size := Vector2(get_window().size)
	return Vector2(
		point.x * window_size.x / _viewport_size.x,
		point.y * window_size.y / _viewport_size.y)
