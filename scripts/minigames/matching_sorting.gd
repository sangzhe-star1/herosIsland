extends LevelManager
## "Put each thing where it belongs." The dragging game.
##
## The old sorting levels asked a child to TAP a bin. This one asks them to
## carry the thing there, which is both what the brief asked for and a
## genuinely different act: tapping is choosing, dragging is doing. A
## six-year-old who drags a banana into the fruit basket has moved a banana.
##
## All the feel lives in `DragField` -- lift, glow, snap, float home -- so a
## drag here behaves exactly like a drag in the repair levels. This file only
## decides what the bins are, what the things are, and which goes where.
##
## Nothing can be failed. A wrong drop floats back and the bin shakes its
## head; the item is still there, the child is still there, and the only
## record kept is whether they needed help, which is the third star.

const Field := preload("res://scripts/shared/drag_field.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")

## Where the thing waiting to be sorted sits, and where the bins go. One item
## at a time in the middle, bins along the bottom: the shortest possible drag
## for the shortest possible arm.
## Where the thing to sort appears, against the design size. Everything reads
## it through _stage_at, which is the same point on the real screen.
const STAGE := Vector2(640, 300)

var _stage_at := STAGE
## Where the bins stand, against the 1280x720 the art was drawn at. Put on the
## real screen through Fit.at() -- the world's ground plane moves down on a
## tablet and bins left at a hard 560 hang in the air above it.
const BIN_Y := 560.0

var _field: Field
var _hud: Control
var _hints: Hints
var _picker: Picker
var _queue: Array = []            # the things still to come
var _current: Dictionary = {}
var _bins: Array = []
var _done := 0
var _wanted := 8
var _slips := 0
var _helped := false
var _gift_at := -1                # which item in the run is the shiny one
var _gift_found := false
var _pips: HBoxContainer          # one per thing to sort, lit as they go
var _note: Label                  # the odd sentence, on its own line
var _bin_glow: Node2D             # the level-one hint, so it can be put out
var _finished_level := false


func auto_complete_on_target() -> bool:
	return false


var _room_3d_vp: SubViewport
var _room_3d_cam: Camera3D
var _room_3d_world: Node3D

func _build_3d_toy_room() -> void:
	var vp_container := SubViewportContainer.new()
	vp_container.name = "ToyRoom3DContainer"
	vp_container.custom_minimum_size = Vector2(1280, 720)
	vp_container.size = Vector2(1280, 720)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)

	_room_3d_vp = SubViewport.new()
	_room_3d_vp.name = "ToyRoom3DViewport"
	_room_3d_vp.size = Vector2i(1280, 720)
	_room_3d_vp.own_world_3d = true
	_room_3d_vp.transparent_bg = false
	_room_3d_vp.handle_input_locally = false
	_room_3d_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(_room_3d_vp)

	var world_root := Node3D.new()
	world_root.name = "ToyRoomWorld"
	_room_3d_vp.add_child(world_root)
	_room_3d_world = world_root

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.88, 0.86, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.88, 0.82)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.70, 0.80, 0.95)
	fill.light_energy = 0.32
	fill.rotation_degrees = Vector3(20.0, -145.0, 0.0)
	world_root.add_child(fill)

	_room_3d_cam = Camera3D.new()
	_room_3d_cam.name = "RoomCamera"
	_room_3d_cam.position = Vector3(0.0, 3.8, 7.8)
	_room_3d_cam.rotation_degrees = Vector3(-16.0, 0.0, 0.0)
	_room_3d_cam.fov = 48.0
	world_root.add_child(_room_3d_cam)

	var glb_path := "res://assets/scenes_3d/toy_room_study.glb"
	if ResourceLoader.exists(glb_path):
		var rm_packed: PackedScene = load(glb_path)
		var rm_inst := rm_packed.instantiate()
		rm_inst.name = "ToyRoomMesh"
		world_root.add_child(rm_inst)


func _screen_to_desk_3d(screen_pos: Vector2, lift_y: float = 0.0) -> Vector3:
	if _room_3d_cam == null:
		return Vector3.ZERO
	var ray_origin := _room_3d_cam.project_ray_origin(screen_pos)
	var ray_normal := _room_3d_cam.project_ray_normal(screen_pos)
	var target_z := 3.4
	if absf(ray_normal.z) < 0.0001:
		return Vector3.ZERO
	var t := (target_z - ray_origin.z) / ray_normal.z
	var p := ray_origin + ray_normal * t
	p.y += lift_y
	return p


func _create_3d_sort_item(key: String, icon: String, shiny: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "SortItem3D_%s" % key

	match key:
		"toy":
			# Cute 3D Teddy Bear Toy
			var fur_col := Color(0.92, 0.78, 0.42) if shiny else Color(0.72, 0.48, 0.28)
			var snout_col := Color(0.96, 0.88, 0.72)
			var dark_col := Color(0.12, 0.10, 0.10)

			var fur_mat := StandardMaterial3D.new()
			fur_mat.albedo_color = fur_col
			fur_mat.roughness = 0.65

			# Head
			var head := MeshInstance3D.new()
			var hm := SphereMesh.new()
			hm.radius = 0.38
			hm.height = 0.76
			head.mesh = hm
			head.set_surface_override_material(0, fur_mat)
			root.add_child(head)

			# Left Ear
			var l_ear := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.15
			em.height = 0.28
			l_ear.mesh = em
			l_ear.position = Vector3(-0.30, 0.30, 0.0)
			l_ear.set_surface_override_material(0, fur_mat)
			root.add_child(l_ear)

			# Right Ear
			var r_ear := MeshInstance3D.new()
			r_ear.mesh = em
			r_ear.position = Vector3(0.30, 0.30, 0.0)
			r_ear.set_surface_override_material(0, fur_mat)
			root.add_child(r_ear)

			# Snout
			var snout := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.18
			sm.height = 0.26
			snout.mesh = sm
			snout.position = Vector3(0.0, -0.08, 0.28)
			var smat := StandardMaterial3D.new()
			smat.albedo_color = snout_col
			smat.roughness = 0.6
			snout.set_surface_override_material(0, smat)
			root.add_child(snout)

			# Nose
			var nose := MeshInstance3D.new()
			var nm := SphereMesh.new()
			nm.radius = 0.06
			nm.height = 0.10
			nose.mesh = nm
			nose.position = Vector3(0.0, 0.02, 0.42)
			var dmat := StandardMaterial3D.new()
			dmat.albedo_color = dark_col
			dmat.roughness = 0.4
			nose.set_surface_override_material(0, dmat)
			root.add_child(nose)

			# Eyes
			for ex in [-0.14, 0.14]:
				var eye := MeshInstance3D.new()
				var eym := SphereMesh.new()
				eym.radius = 0.04
				eym.height = 0.08
				eye.mesh = eym
				eye.position = Vector3(ex, 0.10, 0.34)
				eye.set_surface_override_material(0, dmat)
				root.add_child(eye)

		"danger":
			# Glowing Caution Hazard Sign
			var mesh_inst := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.85, 0.85, 0.35)
			mesh_inst.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.85, 0.35) if shiny else Color(0.95, 0.62, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.62, 0.15)
			mat.emission_energy_multiplier = 1.4
			mat.roughness = 0.35
			mesh_inst.set_surface_override_material(0, mat)
			root.add_child(mesh_inst)

			# Exclamation dot
			var dot := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = 0.06
			dm.height = 0.12
			dot.mesh = dm
			dot.position = Vector3(0.0, -0.22, 0.18)
			var dmat := StandardMaterial3D.new()
			dmat.albedo_color = Color(0.1, 0.1, 0.12)
			dot.set_surface_override_material(0, dmat)
			root.add_child(dot)

			# Exclamation stem
			var bar := MeshInstance3D.new()
			var bm := CylinderMesh.new()
			bm.top_radius = 0.04
			bm.bottom_radius = 0.04
			bm.height = 0.26
			bar.mesh = bm
			bar.position = Vector3(0.0, -0.02, 0.18)
			bar.set_surface_override_material(0, dmat)
			root.add_child(bar)

		"plant", _:
			var glb_path := "res://assets/harvest_3d/runtime_candidates/crops/%s.glb" % icon
			if not ResourceLoader.exists(glb_path):
				glb_path = "res://assets/harvest_3d/runtime_candidates/crops/strawberry.glb"
			if ResourceLoader.exists(glb_path):
				var scene: PackedScene = load(glb_path)
				if scene != null:
					var inst := scene.instantiate()
					inst.scale = Vector3(1.3, 1.3, 1.3)
					root.add_child(inst)
			else:
				var pot := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.28
				cm.bottom_radius = 0.20
				cm.height = 0.38
				pot.mesh = cm
				pot.position = Vector3(0.0, -0.16, 0.0)
				var pmat := StandardMaterial3D.new()
				pmat.albedo_color = Color(0.82, 0.45, 0.30)
				pot.set_surface_override_material(0, pmat)
				root.add_child(pot)

				var plant := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.32
				sm.height = 0.48
				plant.mesh = sm
				plant.position = Vector3(0.0, 0.16, 0.0)
				var lmat := StandardMaterial3D.new()
				lmat.albedo_color = Color(0.35, 0.72, 0.40)
				plant.set_surface_override_material(0, lmat)
				root.add_child(plant)

	if shiny:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.45)
		light.light_energy = 1.5
		light.omni_range = 2.4
		root.add_child(light)

	return root


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_wanted = clampi(Hints.extra_things(harder_i(int(config.get("count", 8)), 2)), 4, 12)

	_build_3d_toy_room()
	_field = Field.new()
	add_child(_field)
	_field.dropped.connect(_on_dropped)
	_stage_at = Fit.at(_field, STAGE)

	# Plush leather staging coaster on desk mat
	var coaster := Node2D.new()
	coaster.position = _stage_at + Vector2(0, 16.0)
	_field.add_child(coaster)
	Shapes.ground_shadow(coaster, Vector2.ZERO, 150.0, 0.22)
	Shapes.fill(coaster, Shapes.circle_points(Vector2.ZERO, 68.0, 24),
		Color(0.88, 0.84, 0.76, 0.60), 0.0)
	Shapes.fill(coaster, Shapes.circle_points(Vector2.ZERO, 62.0, 24),
		Color(0.96, 0.94, 0.88, 0.85), 0.0)

	_build_bins(config)
	_build_queue(config)
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_glow_right_bin, _show_the_drag, _do_it_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)

	# The shiny one: somewhere in the middle of the run, so it is a surprise
	# rather than a first impression or a leftover.
	_gift_at = _picker.whole(2, maxi(_wanted - 2, 3))
	_play_tutorial()
	_next_item()


# --- the bins ------------------------------------------------------------------

func _build_bins(config: Dictionary) -> void:
	var kinds: Array = config.get("bins", [])
	if kinds.is_empty():
		kinds = [{"key": "toy", "icon": "teddy", "colour": "#5fb0e8"},
			{"key": "danger", "icon": "warning", "colour": "#e2703c"},
			{"key": "plant", "icon": "leaf", "colour": "#4fa86b"}]
	# Left to right in a shuffled order, so a child who memorised "the toy box
	# is the left one" has to look at the picture on their second play.
	var order: Array = kinds.duplicate()
	_picker.shuffle(order)
	var span: float = 780.0
	for i in range(order.size()):
		var kind: Dictionary = order[i]
		var x: float = 640.0 + (float(i) - float(order.size() - 1) * 0.5) \
			* (span / float(maxi(order.size(), 1)))
		var node := _draw_bin(kind)
		_field.add_child(node)
		var slot_pos := Fit.at(_field, Vector2(x, BIN_Y))
		var slot := _field.add_slot(node, slot_pos,
			str(kind.get("key", "")))
		slot["offset_y"] = -30.0
		_bins.append({"slot": slot, "kind": kind, "node": node})

		# The detailed 2D sorting bins sit on the desk surface;
		# draggable items are rendered as real 3D toys that elevate and drop into them.


func _draw_bin(kind: Dictionary) -> Node2D:
	var node := Node2D.new()
	var key: String = str(kind.get("key", "toy")).to_lower()
	var color_str: String = str(kind.get("colour", "")).to_lower()
	var crate_color := "blue"
	if "green" in color_str or key == "plant" or key == "nature":
		crate_color = "green"
	elif "orange" in color_str or "red" in color_str or key == "danger":
		crate_color = "orange"
	elif "purple" in color_str:
		crate_color = "purple"
	elif "yellow" in color_str:
		crate_color = "yellow"
	node.set_meta("crate_color", crate_color)

	# Contact shadow onto desk mat
	Shapes.ground_shadow(node, Vector2(0, 68.0), 180.0, 0.28)

	var crate_path := "res://assets/props_3d/crate_%s.png" % crate_color
	if ResourceLoader.exists(crate_path):
		var spr := Sprite2D.new()
		spr.texture = load(crate_path) as Texture2D
		spr.scale = Vector2(0.58, 0.58)
		spr.position = Vector2(0, -30.0)
		node.add_child(spr)

	# Category Icon on front of crate: centered inside the crate's front chalkboard circle
	var art: Control = UiKit.picture(str(kind.get("icon", "")), 46)
	if art != null:
		art.position = Vector2(-23.0, 12.3 - 23.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)

	return node
# --- the things ----------------------------------------------------------------

func _build_queue(config: Dictionary) -> void:
	var pool: Array = config.get("items", [])
	if pool.is_empty():
		pool = [
			{"icon": "teddy", "key": "toy"},
			{"icon": "robot", "key": "toy"},
			{"icon": "blocks", "key": "toy"},
			{"icon": "crayon", "key": "toy"},
			{"icon": "warning", "key": "danger"},
			{"icon": "lightning", "key": "danger"},
			{"icon": "rock", "key": "danger"},
			{"icon": "star_bomb", "key": "danger"},
			{"icon": "leaf", "key": "plant"},
			{"icon": "carrot", "key": "plant"},
			{"icon": "strawberry", "key": "plant"},
			{"icon": "pumpkin", "key": "plant"},
		]
	# Only bins we actually built can be answered, or the level is unfinishable.
	var keys: Array = []
	for bin in _bins:
		keys.append(str(bin["kind"].get("key", "")))
	var usable: Array = []
	for item in pool:
		if keys.has(str(item.get("key", ""))):
			usable.append(item)
	_queue = _picker.some(usable, _wanted)
	# Short pools repeat rather than shorten the level.
	while _queue.size() < _wanted and not usable.is_empty():
		_queue.append(_picker.one(usable))


func _next_item() -> void:
	if _done >= _wanted:
		_finish()
		return
	var spec: Dictionary = _queue[_done % _queue.size()]
	var node := Node2D.new()
	var shiny: bool = _done == _gift_at
	if shiny:
		Shapes.glow(node, Vector2.ZERO, 140.0, Color(1.0, 0.88, 0.42), 5, 0.50)

	# Soft 3D contact ground shadow on desk mat
	Shapes.ground_shadow(node, Vector2(0, 48.0), 96.0, 0.28)

	var art: Control = UiKit.picture(str(spec.get("icon", "")), 96)
	if art != null:
		art.position = Vector2(-48, -48)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)
	_field.add_child(node)
	_current = _field.add_item(node, _stage_at, str(spec.get("key", "")))
	_current["shiny"] = shiny

	if _room_3d_world != null:
		var item_3d := _create_3d_sort_item(str(spec.get("key", "")), str(spec.get("icon", "")), shiny)
		_room_3d_world.add_child(item_3d)
		item_3d.position = _screen_to_desk_3d(_stage_at, 0.45)
		var itw := item_3d.create_tween()
		itw.tween_property(item_3d, "position", _screen_to_desk_3d(_stage_at, 0.0), 0.34)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		node.set_meta("sort_3d", item_3d)
		node.tree_exited.connect(func():
			if is_instance_valid(item_3d):
				item_3d.queue_free()
		)
		if art != null:
			art.modulate.a = 0.0

	# It floats down into place, so the child's eye follows it to the middle.
	if Juice.motion_enabled():
		node.position = _stage_at + Vector2(0, -120.0)
		var t := node.create_tween()
		t.tween_property(node, "position", _stage_at, 0.34)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("res://assets/audio/pop.ogg")


func _on_dropped(item: Dictionary, slot: Dictionary, correct: bool) -> void:
	if _finished_level:
		return
	# Let go over empty ground: a fumble, not an answer. The field has already
	# floated the thing home, which is all the reply it needs. Counting it as a
	# mistake cost a star for a slipped thumb, and hints.missed() would have
	# escalated straight to a hint (misses_before_help is 1) and cost the
	# third star as well.
	if slot.is_empty():
		return
	if not correct:
		_slips += 1
		score_mistake()
		_hints.missed()
		_say("sorting.try_again")
		return
	_done += 1
	score_correct()
	_hints.progress()
	_unglow_bin()

	var slot_node: Node2D = slot.get("node", null)
	if slot_node != null and is_instance_valid(slot_node):
		var ctw2 := slot_node.create_tween()
		ctw2.tween_property(slot_node, "scale", Vector2(1.12, 0.88), 0.08)
		ctw2.tween_property(slot_node, "scale", Vector2.ONE, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Juice.burst(_field, slot_node.position + Vector2(0, -30.0), 12)
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		if slot_node.has_meta("crate_3d"):
			var c3d: Node3D = slot_node.get_meta("crate_3d", null) as Node3D
			if c3d != null and is_instance_valid(c3d):
				var ctw := c3d.create_tween()
				ctw.tween_property(c3d, "scale", Vector3(1.15, 0.82, 1.15), 0.08)
				ctw.tween_property(c3d, "scale", Vector3.ONE, 0.16)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var item_node: Node2D = item.get("node", null)
	if item_node != null and item_node.has_meta("sort_3d"):
		var s3d: Node3D = item_node.get_meta("sort_3d", null) as Node3D
		if s3d != null and is_instance_valid(s3d):
			var stw := s3d.create_tween()
			stw.tween_property(s3d, "scale", Vector3.ZERO, 0.18)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	if bool(item.get("shiny", false)):
		_gift_found = true
		Juice.shockwave(_field, (item["node"] as Node2D).position, 200.0,
			Color(1.0, 0.88, 0.42))
		AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	_refresh_tally()
	# A beat before the next one, so the click-in gets to be the whole event.
	get_tree().create_timer(0.42).timeout.connect(func():
		if not _finished_level:
			_next_item())


func _process(delta: float) -> void:
	if _current.is_empty() or _field == null:
		return
	var node: Node2D = _current.get("node", null)
	if node == null or not is_instance_valid(node) or not node.has_meta("sort_3d"):
		return
	var s3d: Node3D = node.get_meta("sort_3d", null) as Node3D
	if s3d == null or not is_instance_valid(s3d):
		return
	var is_held: bool = (_field.held() == _current)
	var is_placed: bool = bool(_current.get("placed", false))
	var lift := 0.35 if is_held else 0.0
	var target_p := _screen_to_desk_3d(node.position, lift)
	s3d.position = s3d.position.lerp(target_p, clampf(delta * (28.0 if is_held else 16.0), 0.0, 1.0))
	if is_held:
		s3d.rotation_degrees.y += delta * 70.0
		s3d.rotation_degrees.x = lerpf(s3d.rotation_degrees.x, 18.0, clampf(delta * 15.0, 0.0, 1.0))
		s3d.scale = s3d.scale.lerp(Vector3(1.2, 1.2, 1.2), clampf(delta * 18.0, 0.0, 1.0))
	elif is_placed:
		s3d.scale = s3d.scale.lerp(Vector3(0.5, 0.5, 0.5), clampf(delta * 20.0, 0.0, 1.0))
	else:
		s3d.rotation_degrees.x = lerpf(s3d.rotation_degrees.x, 0.0, clampf(delta * 16.0, 0.0, 1.0))
		s3d.scale = s3d.scale.lerp(Vector3.ONE, clampf(delta * 16.0, 0.0, 1.0))


# --- the screen ----------------------------------------------------------------

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

	# One star per thing to sort, lit as they go in. Centred on the REAL
	# screen width, clear of the back button on the left.
	var view: Vector2 = _hud.get_viewport_rect().size
	_pips = UiKit.pip_row("star", _wanted)
	_pips.position = Vector2(view.x * 0.5 - UiKit.pip_row_width(_wanted) * 0.5, 26)
	_hud.add_child(_pips)

	# The sentence ("not that box") lives under the counter, never on it: the
	# old label was both, and every wrong drop wiped the score for a second.
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 32)
	_note.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_note)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(view.x * 0.5 - 300.0, 88)
	_note.size = Vector2(600, 46)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_note)
	_refresh_tally()


func _refresh_tally() -> void:
	UiKit.pip_fill(_pips, _done)


func _say(key: String) -> void:
	if _note == null or not is_instance_valid(_note):
		return
	_note.text = I18n.t(key)
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(_note):
			_note.text = "")


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(_stage_at, _stage_at, 0.9)
	if not _bins.is_empty():
		demo.add_step(_stage_at, ((_bins[0]["slot"] as Dictionary)["node"] as Node2D).position,
			1.2)
	demo.play()


# --- the three levels of help ---------------------------------------------------

func _right_bin() -> Dictionary:
	if _current.is_empty():
		return {}
	for bin in _bins:
		if str(bin["kind"].get("key", "")) == str(_current["key"]):
			return bin
	return {}


func _glow_right_bin() -> void:
	var bin := _right_bin()
	if bin.is_empty():
		return
	var node: Node2D = bin["node"]
	if is_instance_valid(node):
		Juice.pop(node, 0.3)
		# One glow, on the bin the CURRENT thing wants. It used to be added and
		# never removed, so after the drop the old bin kept shining and the
		# next hint lit a second one: two answers to a one-answer question.
		_unglow_bin()
		_bin_glow = Shapes.glow(node, Vector2(0, -60.0), 190.0,
			Color(1.0, 0.94, 0.55), 4, 0.45)
		_bin_glow.set_meta("hint_glow", true)


func _unglow_bin() -> void:
	if _bin_glow != null and is_instance_valid(_bin_glow):
		_bin_glow.queue_free()
	_bin_glow = null


func _show_the_drag() -> void:
	var bin := _right_bin()
	if bin.is_empty() or _current.is_empty():
		return
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step((_current["node"] as Node2D).position,
		(bin["node"] as Node2D).position, 1.1)
	demo.play()


func _do_it_for_them() -> void:
	if _current.is_empty() or bool(_current["placed"]):
		return
	_field.place_for_them(_current)
	_done += 1
	_unglow_bin()
	_refresh_tally()
	get_tree().create_timer(0.5).timeout.connect(func():
		if not _finished_level:
			_next_item())


func _finish() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	result.reached_goal = true
	result.found_hidden = _gift_found
	result.clean_run = _slips == 0 and not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	# The bins do a little bow: the child put everything away and the room
	# says thank you.
	for bin in _bins:
		Juice.pop(bin["node"], 0.34)
	Juice.burst(_field, Fit.at(_field, Vector2(640, 420)), 40)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(1.3).timeout
	complete_level()
