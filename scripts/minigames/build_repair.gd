extends LevelManager
## "Build the thing, then watch it work." The most satisfying template here.
##
## A child drags parts into outlined slots and the machine grows under their
## hands. The brief is specific about two things and both are the whole point:
##
##   * every step gets its own animation, light and sound -- not a progress
##     bar, an EVENT
##   * when it is finished the thing has to actually RUN. A bridge you can
##     walk across, a tower whose light comes on, a robot that stands up and
##     waves. "Success!" on a card is what a spreadsheet says.
##
## The parts are drawn from the level's data, the slots are outlines of
## exactly the part that belongs there, and the drag comes from `DragField`,
## so it feels the same as the sorting levels a child played an hour ago.

const Field := preload("res://scripts/shared/drag_field.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")

var _field: Field
var _hud: Control
var _hints: Hints
var _picker: Picker
var _machine: Node2D               # everything that is being built
var _kind := "bridge"
var _parts: Array = []             # [{item, spec}]
var _slot_nodes: Array = []
var _placed := 0
var _wanted := 4
var _slips := 0
var _helped := false
var _golden_used := false
var _tally: HBoxContainer
var _finished_level := false

## The shapes each machine is made of: where the slots sit, and what a part
## that belongs there looks like. Hand-placed, because "generate a bridge"
## produces bridges nobody wants to cross.
const BLUEPRINTS := {
	"bridge": {
		"anchor": Vector2(640, 470),
		"slots": [Vector2(-210, 0), Vector2(-70, 0), Vector2(70, 0), Vector2(210, 0)],
		"part": "plank", "runs": "cross",
	},
	"tower": {
		"anchor": Vector2(640, 560),
		"slots": [Vector2(0, 0), Vector2(0, -110), Vector2(0, -220), Vector2(0, -320)],
		"part": "block", "runs": "light",
	},
	"robot": {
		"anchor": Vector2(640, 470),
		"slots": [Vector2(0, -110), Vector2(0, 0), Vector2(-120, -30),
			Vector2(120, -30), Vector2(0, 120)],
		"part": "limb", "runs": "wave",
	},
	"ship": {
		"anchor": Vector2(640, 420),
		"slots": [Vector2(-160, 0), Vector2(0, 0), Vector2(160, 0), Vector2(0, -110)],
		"part": "hull", "runs": "fly",
	},
}


func auto_complete_on_target() -> bool:
	return false


var _workshop_3d_vp: SubViewport
var _workshop_3d_world: Node3D
var _workshop_3d_cam: Camera3D

func _build_3d_workshop() -> void:
	var vp_container := SubViewportContainer.new()
	vp_container.name = "Workshop3DContainer"
	vp_container.custom_minimum_size = Vector2(1280, 720)
	vp_container.size = Vector2(1280, 720)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)

	_workshop_3d_vp = SubViewport.new()
	_workshop_3d_vp.name = "Workshop3DViewport"
	_workshop_3d_vp.size = Vector2i(1280, 720)
	_workshop_3d_vp.own_world_3d = true
	_workshop_3d_vp.transparent_bg = false
	_workshop_3d_vp.handle_input_locally = false
	_workshop_3d_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(_workshop_3d_vp)

	var world_root := Node3D.new()
	world_root.name = "WorkshopWorld"
	_workshop_3d_vp.add_child(world_root)
	_workshop_3d_world = world_root

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.52, 0.84)
	sky_mat.sky_horizon_color = Color(0.76, 0.84, 0.92)
	sky_mat.ground_bottom_color = Color(0.42, 0.35, 0.28)
	sky_mat.ground_horizon_color = Color(0.70, 0.64, 0.58)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.55, 0.70, 0.90)
	fill.light_energy = 0.20
	fill.rotation_degrees = Vector3(20.0, -145.0, 0.0)
	world_root.add_child(fill)

	_workshop_3d_cam = Camera3D.new()
	_workshop_3d_cam.name = "WorkshopCamera"
	_workshop_3d_cam.position = Vector3(0.0, 3.2, 7.2)
	_workshop_3d_cam.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	_workshop_3d_cam.fov = 46.0
	world_root.add_child(_workshop_3d_cam)

	var glb_path := "res://assets/scenes_3d/build_workshop.glb"
	if ResourceLoader.exists(glb_path):
		var ws_packed: PackedScene = load(glb_path)
		var ws_inst := ws_packed.instantiate()
		ws_inst.name = "BuildWorkshopMesh"
		world_root.add_child(ws_inst)


func _screen_to_table_3d(screen_pos: Vector2, table_y: float = 0.38) -> Vector3:
	if _workshop_3d_cam == null:
		return Vector3.ZERO
	var ray_origin := _workshop_3d_cam.project_ray_origin(screen_pos)
	var ray_normal := _workshop_3d_cam.project_ray_normal(screen_pos)
	if absf(ray_normal.y) < 0.0001:
		return Vector3.ZERO
	var t := (table_y - ray_origin.y) / ray_normal.y
	return ray_origin + ray_normal * t


func _create_3d_part(kind: String, golden: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Part3D_%s" % kind

	match kind:
		"plank":
			var mesh_inst := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.68, 0.16, 0.38)
			mesh_inst.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.82, 0.32) if golden else Color(0.72, 0.50, 0.30)
			mat.roughness = 0.50
			mesh_inst.set_surface_override_material(0, mat)
			root.add_child(mesh_inst)

			for nx in [-0.24, 0.24]:
				for nz in [-0.11, 0.11]:
					var nail := MeshInstance3D.new()
					var nm := CylinderMesh.new()
					nm.top_radius = 0.035
					nm.bottom_radius = 0.035
					nm.height = 0.05
					nail.mesh = nm
					nail.position = Vector3(nx, 0.09, nz)
					var nmat := StandardMaterial3D.new()
					nmat.albedo_color = Color(0.85, 0.70, 0.30)
					nmat.metallic = 0.8
					nmat.roughness = 0.3
					nail.set_surface_override_material(0, nmat)
					root.add_child(nail)

		"block":
			var mesh_inst := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.62, 0.25, 0.62)
			mesh_inst.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.82, 0.32) if golden else Color(0.52, 0.58, 0.70)
			mat.metallic = 0.65
			mat.roughness = 0.35
			mesh_inst.set_surface_override_material(0, mat)
			root.add_child(mesh_inst)

			var core := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.36, 0.10, 0.36)
			core.mesh = cm
			core.position = Vector3(0.0, 0.14, 0.0)
			var cmat := StandardMaterial3D.new()
			var core_col := Color(1.0, 0.95, 0.50) if golden else Color(0.35, 0.88, 1.0)
			cmat.albedo_color = core_col
			cmat.emission_enabled = true
			cmat.emission = core_col
			cmat.emission_energy_multiplier = 3.0
			core.set_surface_override_material(0, cmat)
			root.add_child(core)

		"limb":
			var mesh_inst := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.20
			cm.bottom_radius = 0.20
			cm.height = 0.55
			mesh_inst.mesh = cm
			mesh_inst.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.82, 0.32) if golden else Color(0.48, 0.68, 0.90)
			mat.metallic = 0.75
			mat.roughness = 0.28
			mesh_inst.set_surface_override_material(0, mat)
			root.add_child(mesh_inst)

			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.24
			sm.height = 0.48
			ball.mesh = sm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.85, 0.72, 0.35) if golden else Color(0.25, 0.30, 0.42)
			bmat.metallic = 0.85
			bmat.roughness = 0.25
			ball.set_surface_override_material(0, bmat)
			root.add_child(ball)

		"hull":
			var mesh_inst := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.72, 0.18, 0.45)
			mesh_inst.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.85, 0.35) if golden else Color(0.72, 0.78, 0.90)
			mat.metallic = 0.80
			mat.roughness = 0.30
			mesh_inst.set_surface_override_material(0, mat)
			root.add_child(mesh_inst)

			var seam := MeshInstance3D.new()
			var smm := BoxMesh.new()
			smm.size = Vector3(0.58, 0.05, 0.06)
			seam.mesh = smm
			seam.position = Vector3(0.0, 0.10, 0.0)
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(0.3, 0.9, 1.0)
			smat.emission_enabled = true
			smat.emission = Color(0.3, 0.9, 1.0)
			smat.emission_energy_multiplier = 2.8
			seam.set_surface_override_material(0, smat)
			root.add_child(seam)

		"junk", _:
			var mesh_inst := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.65, 0.16, 0.38)
			mesh_inst.mesh = bm
			mesh_inst.rotation_degrees = Vector3(0.0, 8.0, 0.0)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.48, 0.44, 0.40)
			mat.roughness = 0.85
			mat.metallic = 0.4
			mesh_inst.set_surface_override_material(0, mat)
			root.add_child(mesh_inst)

	if golden:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.45)
		light.light_energy = 1.2
		light.omni_range = 2.2
		root.add_child(light)

	return root


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_kind = str(config.get("machine", "bridge"))
	if not BLUEPRINTS.has(_kind):
		_kind = "bridge"

	_build_3d_workshop()
	_field = Field.new()
	add_child(_field)
	_field.dropped.connect(_on_dropped)

	_machine = Node2D.new()
	_field.add_child(_machine)
	_build_machine(config)
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_glow_next_slot, _show_the_drag, _do_it_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_play_tutorial()


# --- the machine ----------------------------------------------------------------

func _build_machine(config: Dictionary) -> void:
	var plan: Dictionary = BLUEPRINTS[_kind]
	# The blueprint is written against 1280x720; the child may be holding
	# 1280x960. Only the anchor moves -- the slot offsets around it are the
	# SHAPE of the machine and must stay exactly as drawn, or a bridge built
	# on a tablet is a different bridge.
	var anchor: Vector2 = machine_anchor()
	var places: Array = plan["slots"]
	_wanted = places.size()

	# Who we are building it FOR. A machine with nobody waiting is homework.
	var who := str(config.get("waiting_for", "paw"))
	var friend := Node2D.new()
	friend.position = cross_path()[0]
	_field.add_child(friend)
	var art: Control = UiKit.picture(who, 92)
	if art != null:
		art.position = Vector2(-46, -46)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		friend.add_child(art)
	Juice.idle_bob(friend, 10.0, 1.3)
	_machine.set_meta("friend", friend)

	# The slots: dashed outlines of exactly the part that goes in them.
	for i in range(places.size()):
		var at: Vector2 = anchor + (places[i] as Vector2)
		var ghost := Node2D.new()
		_field.add_child(ghost)
		_draw_part(ghost, str(plan["part"]), true)
		var slot := _field.add_slot(ghost, at, "part", 1)
		slot["index"] = i
		_slot_nodes.append(ghost)

	# The parts, placed comfortably on the workbench tray
	var tray_y := Fit.y(_field, 580.0)
	var middle := Fit.x(_field, 640.0)
	var spread := Fit.x(_field, 960.0)
	var count: int = _wanted + 2
	var order: Array = []
	for i in range(_wanted):
		order.append("part")
	order.append("junk")
	order.append("junk")
	_picker.shuffle(order)
	for i in range(count):
		var x: float = middle + (float(i) - float(count - 1) * 0.5) * (spread / float(count))
		var node := Node2D.new()
		_field.add_child(node)
		var golden: bool = str(order[i]) == "part" and i == _picker.whole(0, count - 1)
		var part_kind := str(plan["part"]) if str(order[i]) == "part" else "junk"
		_draw_part(node, part_kind, false, golden)
		var item := _field.add_item(node, Vector2(x, tray_y),
			"part" if str(order[i]) == "part" else "junk")
		item["golden"] = golden
		_parts.append(item)
		if _workshop_3d_world != null:
			var p3d := _create_3d_part(part_kind, golden)
			_workshop_3d_world.add_child(p3d)
			p3d.position = _screen_to_table_3d(Vector2(x, tray_y), 0.42)
			node.set_meta("part_3d", p3d)
			node.tree_exited.connect(func():
				if is_instance_valid(p3d):
					p3d.queue_free()
			)
			node.modulate.a = 0.0


## One drawing routine for ghosts, real parts and junk, so a slot and the
## thing that fills it are unmistakably the same shape.
func _draw_part(node: Node2D, kind: String, ghost: bool, golden: bool = false) -> void:
	var box_size := Vector2(128, 44)
	match kind:
		"block":
			box_size = Vector2(116, 104)
		"limb":
			box_size = Vector2(92, 92)
		"hull":
			box_size = Vector2(140, 68)
		"plank", "junk":
			box_size = Vector2(128, 44)

	var half := box_size * 0.5
	var at_rect := -half

	if ghost:
		# Carved recessed wooden mortise slot on the timber workbench
		Shapes.fill(node, Shapes.rounded_rect(at_rect - Vector2(2.0, 2.0), box_size + Vector2(4.0, 4.0), 5.0),
			Color(0.32, 0.24, 0.16, 0.60), 0.0)
		# Recessed groove floor
		Shapes.fill(node, Shapes.rounded_rect(at_rect, box_size, 4.0),
			Color(0.40, 0.30, 0.20, 0.70), 0.0)

		# Soft warm gold guide glow
		Shapes.glow(node, Vector2.ZERO, box_size.x * 0.55, Color(1.0, 0.88, 0.45), 2, 0.22)

		# Brass corner alignment brackets
		var blen := 12.0
		var corners := [
			[at_rect, Vector2(blen, 0), Vector2(0, blen)],
			[at_rect + Vector2(box_size.x, 0), Vector2(-blen, 0), Vector2(0, blen)],
			[at_rect + Vector2(0, box_size.y), Vector2(blen, 0), Vector2(0, -blen)],
			[at_rect + box_size, Vector2(-blen, 0), Vector2(0, -blen)]
		]
		for c in corners:
			var cl := Line2D.new()
			cl.points = PackedVector2Array([c[0] + c[1], c[0], c[0] + c[2]])
			cl.width = 3.5
			cl.default_color = Color(0.85, 0.72, 0.38, 0.90)
			cl.antialiased = true
			node.add_child(cl)
		return

	# Real Physical Part
	Shapes.ground_shadow(node, Vector2(0, half.y + 6.0), box_size.x * 1.05, 0.32)

	if golden:
		Shapes.glow(node, Vector2.ZERO, 140.0, Color(1.0, 0.86, 0.40), 5, 0.45)


	if kind == "junk":
		node.rotation_degrees = 7.5

	match kind:
		"plank":
			var wood_front := Color(0.72, 0.50, 0.30) if not golden else Color(1.0, 0.82, 0.32)
			var wood_top := wood_front.lightened(0.24)
			var wood_bot := wood_front.darkened(0.28)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, box_size, 8.0), wood_front, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, Vector2(box_size.x, 10.0), 6.0), wood_top, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(0, box_size.y - 8.0), Vector2(box_size.x, 8.0), 6.0), wood_bot, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(8, 16), Vector2(box_size.x - 16, 3.5), 1.5), wood_bot.lightened(0.1), 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(16, 26), Vector2(box_size.x - 32, 3.0), 1.5), wood_bot.lightened(0.1), 0.0)
			var nail_col := Color(0.24, 0.22, 0.20) if not golden else Color(0.85, 0.60, 0.15)
			for nx in [at_rect.x + 12.0, at_rect.x + box_size.x - 12.0]:
				for ny in [at_rect.y + 10.0, at_rect.y + box_size.y - 10.0]:
					Shapes.fill(node, Shapes.circle_points(Vector2(nx, ny), 3.8, 12), nail_col, 0.0)
					Shapes.fill(node, Shapes.circle_points(Vector2(nx - 1.0, ny - 1.0), 1.6, 8), Color(1, 1, 1, 0.45), 0.0)

		"block":
			var base_tint := Color(0.52, 0.58, 0.70) if not golden else Color(1.0, 0.82, 0.32)
			var top_bevel := base_tint.lightened(0.25)
			var bot_shade := base_tint.darkened(0.30)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, box_size, 14.0), base_tint, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, Vector2(box_size.x, 14.0), 10.0), top_bevel, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(0, box_size.y - 12.0), Vector2(box_size.x, 12.0), 10.0), bot_shade, 0.0)
			for rx in [at_rect.x + 14.0, at_rect.x + box_size.x - 14.0]:
				for ry in [at_rect.y + 14.0, at_rect.y + box_size.y - 14.0]:
					Shapes.fill(node, Shapes.circle_points(Vector2(rx, ry), 4.5, 12), Color(0.25, 0.30, 0.40), 0.0)
					Shapes.fill(node, Shapes.circle_points(Vector2(rx - 1.2, ry - 1.2), 1.8, 8), Color(1, 1, 1, 0.5), 0.0)
			var well_w := 60.0
			var well_h := 50.0
			Shapes.fill(node, Shapes.rounded_rect(Vector2(-well_w * 0.5, -well_h * 0.5), Vector2(well_w, well_h), 8.0), Color(0.12, 0.16, 0.25), 0.0)
			var core_col := Color(0.35, 0.88, 1.0) if not golden else Color(1.0, 0.95, 0.50)
			Shapes.fill(node, Shapes.rounded_rect(Vector2(-well_w * 0.38, -well_h * 0.38), Vector2(well_w * 0.76, well_h * 0.76), 6.0), core_col, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(Vector2(-well_w * 0.25, -well_h * 0.30), Vector2(well_w * 0.50, well_h * 0.30), 3.0), Color(1, 1, 1, 0.75), 0.0)

		"limb":
			var limb_tint := Color(0.48, 0.68, 0.90) if not golden else Color(1.0, 0.82, 0.32)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, box_size, 20.0), limb_tint, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, Vector2(box_size.x, 14.0), 14.0), limb_tint.lightened(0.24), 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(0, box_size.y - 12.0), Vector2(box_size.x, 12.0), 14.0), limb_tint.darkened(0.26), 0.0)
			Shapes.fill(node, Shapes.circle_points(Vector2.ZERO, 26.0, 24), Color(0.22, 0.28, 0.40), 0.0)
			Shapes.fill(node, Shapes.circle_points(Vector2.ZERO, 19.0, 20), Color(0.68, 0.76, 0.88), 0.0)
			Shapes.fill(node, Shapes.circle_points(Vector2.ZERO, 9.0, 16), Color(0.18, 0.22, 0.32), 0.0)
			Shapes.fill(node, Shapes.circle_points(Vector2(-4, -4), 4.0, 10), Color(1, 1, 1, 0.65), 0.0)

		"hull":
			var hull_tint := Color(0.72, 0.78, 0.90) if not golden else Color(1.0, 0.85, 0.35)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, box_size, 22.0), hull_tint, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, Vector2(box_size.x, 12.0), 16.0), hull_tint.lightened(0.22), 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(0, box_size.y - 10.0), Vector2(box_size.x, 10.0), 16.0), hull_tint.darkened(0.28), 0.0)
			Shapes.fill(node, Shapes.rounded_rect(Vector2(at_rect.x + 18, -2.5), Vector2(box_size.x - 36, 5.0), 2.5), Color(0.25, 0.85, 1.0, 0.85), 0.0)

		"junk":
			var junk_col := Color(0.50, 0.46, 0.42)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, box_size, 8.0), junk_col, 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect, Vector2(box_size.x, 8.0), 6.0), junk_col.lightened(0.14), 0.0)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(0, box_size.y - 8.0), Vector2(box_size.x, 8.0), 6.0), junk_col.darkened(0.22), 0.0)
			var crack := Line2D.new()
			crack.points = PackedVector2Array([
				at_rect + Vector2(24, 0),
				at_rect + Vector2(40, 18),
				at_rect + Vector2(34, 26),
				at_rect + Vector2(58, box_size.y)
			])
			crack.width = 4.0
			crack.default_color = Color(0.18, 0.16, 0.14, 0.95)
			crack.antialiased = true
			node.add_child(crack)
			Shapes.fill(node, Shapes.rounded_rect(at_rect + Vector2(box_size.x - 16, 0), Vector2(16, 12), 3.0), Color(0.25, 0.22, 0.20), 0.0)


## Where the machine stands on the REAL screen. One answer for the slots, the
## friend's walk across the bridge and the tower's flash of light, so the three
## cannot disagree: they did once, and on a tablet the friend walked 240 px
## above the bridge the child had just built.
func machine_anchor() -> Vector2:
	return Fit.at(_field, BLUEPRINTS[_kind]["anchor"])


## The friend's walk across the finished bridge, [from, to], in field space.
## Public so the tablet probe can check that the walk is ON the planks.
func cross_path() -> PackedVector2Array:
	var anchor := machine_anchor()
	return PackedVector2Array([anchor + Vector2(430, -40), anchor + Vector2(-330, -60)])


func _on_dropped(item: Dictionary, slot: Dictionary, correct: bool) -> void:
	if _finished_level:
		return
	# Let go over empty grass: not a wrong answer, just a part that was not
	# put anywhere. It has already floated home; scoring it as a mistake
	# punished a child for a slipped thumb.
	if slot.is_empty():
		return
	if not correct:
		_slips += 1
		score_mistake()
		_hints.missed()
		return
	_placed += 1
	score_correct()
	_hints.progress()
	if bool(item.get("golden", false)):
		_golden_used = true

	var item_node: Node2D = item.get("node", null)
	if item_node != null and item_node.has_meta("part_3d"):
		var p3d: Node3D = item_node.get_meta("part_3d", null) as Node3D
		if p3d != null and is_instance_valid(p3d):
			var tw := p3d.create_tween()
			tw.tween_property(p3d, "scale", Vector3(1.25, 0.72, 1.25), 0.08)
			tw.tween_property(p3d, "scale", Vector3.ONE, 0.16)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_celebrate_step(slot)
	_refresh_tally()
	if _placed >= _wanted:
		_run_the_machine()


func _process(delta: float) -> void:
	if _parts.is_empty() or _field == null:
		return
	var held_item: Dictionary = _field.held()
	for item in _parts:
		var node: Node2D = item.get("node", null)
		if node == null or not is_instance_valid(node) or not node.has_meta("part_3d"):
			continue
		var p3d: Node3D = node.get_meta("part_3d", null) as Node3D
		if p3d == null or not is_instance_valid(p3d):
			continue
		var is_held: bool = (held_item == item)
		var is_placed: bool = bool(item.get("placed", false))
		var target_y := 1.15 if is_held else (0.38 if is_placed else 0.42)
		var target_pos := _screen_to_table_3d(node.position, target_y)
		p3d.position = p3d.position.lerp(target_pos, clampf(delta * (28.0 if is_held else 16.0), 0.0, 1.0))
		var target_rot_x := 15.0 if is_held else 0.0
		p3d.rotation_degrees.x = lerpf(p3d.rotation_degrees.x, target_rot_x, clampf(delta * 15.0, 0.0, 1.0))
		var target_s := Vector3(1.18, 1.18, 1.18) if is_held else Vector3.ONE
		p3d.scale = p3d.scale.lerp(target_s, clampf(delta * 18.0, 0.0, 1.0))


## Every step is an event: the ghost fills in, a light comes on, the note goes
## up. The brief asks for this by name and it is the difference between
## building something and filling in a form.
func _celebrate_step(slot: Dictionary) -> void:
	var node: Node2D = slot["node"]
	if not is_instance_valid(node):
		return
	Juice.burst(_field, node.position, 16)
	Juice.impact_sparks(_field, node.position, Color(1.0, 0.92, 0.45), 10)
	Shapes.glow(node, Vector2.ZERO, 150.0, Color(1.0, 0.92, 0.55), 4, 0.34)
	Juice.pop(node, 0.3)
	AudioManager.play_sfx("res://assets/audio/build_step.ogg")
	# The note climbs with each part, so the machine sings itself together.
	var step: int = clampi(_placed, 1, 8)
	get_tree().create_timer(0.12).timeout.connect(func():
		AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % step))


# --- and then it works ------------------------------------------------------------

## The payoff. Whatever was built now does its job, on screen, before the
## result card ever appears.
func _run_the_machine() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	AudioManager.play_sfx("res://assets/audio/machine.ogg")
	Juice.burst(_field, machine_anchor(), 32)
	Juice.shockwave(_field, machine_anchor(), 260.0, Color(0.45, 0.88, 1.0))
	var plan: Dictionary = BLUEPRINTS[_kind]
	match str(plan["runs"]):
		"light":
			_run_light()
		"wave":
			_run_wave()
		"fly":
			_run_fly()
		_:
			_run_cross()
	await get_tree().create_timer(2.4).timeout
	_finish()


func _run_light() -> void:
	# The tower lights from the bottom up, one slot at a time.
	for i in range(_slot_nodes.size()):
		var node: Node2D = _slot_nodes[i]
		get_tree().create_timer(0.18 * float(i)).timeout.connect(func():
			if not is_instance_valid(node):
				return
			Shapes.glow(node, Vector2.ZERO, 190.0, Color(1.0, 0.94, 0.55), 5, 0.55)
			Juice.pop(node, 0.24))
	get_tree().create_timer(0.9).timeout.connect(func():
		AudioManager.play_sfx("res://assets/audio/power_on.ogg")
		Juice.shockwave(_field, machine_anchor() + Vector2(0, -320.0), 420.0,
			Color(1.0, 0.94, 0.55)))


func _run_cross() -> void:
	# The friend walks across the bridge the child just built.
	var friend: Node2D = _machine.get_meta("friend")
	if not is_instance_valid(friend):
		return
	var path := cross_path()
	var far_side: Vector2 = path[path.size() - 1]
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	if not Juice.motion_enabled():
		friend.position = far_side
		return
	var t := friend.create_tween()
	t.tween_property(friend, "position", far_side, 1.9)\
		.set_trans(Tween.TRANS_SINE)
	# A little hop per plank, so it reads as walking rather than sliding.
	for i in range(4):
		var hop := friend.create_tween()
		hop.tween_interval(0.3 + 0.4 * float(i))
		hop.tween_callback(func():
			if is_instance_valid(friend):
				Juice.pop(friend, 0.18)
				AudioManager.play_sfx("res://assets/audio/footstep.ogg"))


func _run_wave() -> void:
	var arms: Array = []
	for i in range(_slot_nodes.size()):
		if i == 2 or i == 3:
			arms.append(_slot_nodes[i])
	AudioManager.play_sfx("res://assets/audio/power_on.ogg")
	for arm in arms:
		if not is_instance_valid(arm) or not Juice.motion_enabled():
			continue
		var t := (arm as Node2D).create_tween().set_loops(3)
		t.tween_property(arm, "rotation_degrees", -26.0, 0.28)
		t.tween_property(arm, "rotation_degrees", 12.0, 0.28)


func _run_fly() -> void:
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	if not Juice.motion_enabled():
		return
	for node in _slot_nodes:
		if not is_instance_valid(node):
			continue
		var t := (node as Node2D).create_tween()
		t.tween_interval(0.4)
		t.tween_property(node, "position:y", (node as Node2D).position.y - 240.0, 1.6)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# --- the screen ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UiKit.theme()
	layer.add_child(_hud)
	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_hud.add_child(back)

	# One pip per part, lit as it goes in: the same counter observation,
	# sorting and the rest use now. "0 / 4" at 40 px was the last sentence
	# on this screen he could not read.
	_tally = UiKit.pip_row("gear", _wanted)
	_tally.position = Vector2(
		_hud.get_viewport_rect().size.x * 0.5 - UiKit.pip_row_width(_wanted) * 0.5, 26)
	_hud.add_child(_tally)
	_refresh_tally()


func _refresh_tally() -> void:
	if _tally != null and is_instance_valid(_tally):
		UiKit.pip_fill(_tally, _placed)


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	if not _parts.is_empty() and not _slot_nodes.is_empty():
		demo.add_step((_parts[0]["node"] as Node2D).position,
			(_slot_nodes[0] as Node2D).position, 1.2)
	demo.play()


# --- the three levels of help ---------------------------------------------------

func _next_slot() -> Node2D:
	for slot in _field.slots():
		if int(slot["held"]) == 0 and is_instance_valid(slot["node"]):
			return slot["node"]
	return null


func _next_part() -> Dictionary:
	for item in _field.items():
		if not bool(item["placed"]) and str(item["key"]) == "part":
			return item
	return {}


func _glow_next_slot() -> void:
	var node := _next_slot()
	if node == null:
		return
	Juice.pop(node, 0.3)
	Shapes.glow(node, Vector2.ZERO, 170.0, Color(1.0, 0.94, 0.55), 4, 0.45)


func _show_the_drag() -> void:
	var node := _next_slot()
	var part := _next_part()
	if node == null or part.is_empty():
		return
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step((part["node"] as Node2D).position, node.position, 1.1)
	demo.play()


## The last resort, done the brief's way: the game does the hard part and
## leaves the final piece, so the child is the one who finishes the machine.
func _do_it_for_them() -> void:
	var left: Array = []
	for item in _field.items():
		if not bool(item["placed"]) and str(item["key"]) == "part":
			left.append(item)
	if left.size() <= 1:
		return                    # already down to the last one: theirs to place
	for i in range(left.size() - 1):
		_field.place_for_them(left[i])
		_placed += 1
	_refresh_tally()
	_glow_next_slot()


func _finish() -> void:
	result.reached_goal = true
	result.found_hidden = _golden_used
	result.clean_run = _slips == 0 and not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	Juice.burst(_field, Fit.at(_field, Vector2(640, 380)), 44)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(1.0).timeout
	complete_level()
