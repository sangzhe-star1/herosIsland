extends LevelManager
## "Cross the Road Safely" -- the first vertical slice, and the template that
## four different levels are built from via data/levels.json.
##
## The lesson, in this order:
##   1. red means stop, green means go        (difficulty 1)
##   2. still look for cars on a green light  (difficulty 2+, "runner" cars)
##   3. do all of that when it is harder      (difficulty 3, faster, rain)
##
## Getting it wrong is never punished. The hero steps back, a calm voice says
## why, and the child tries again. Only the star count reflects mistakes, and
## finishing always earns at least one star.

# The road takes a little over a third of the screen. It used to take half,
# which left the town on the far side as a strip too thin to read as a place.
const ROAD_TOP := 236.0
const ROAD_BOTTOM := 528.0
const CROSSWALK_LEFT := 545.0
const CROSSWALK_RIGHT := 735.0
const NEAR_SIDE_Y := 615.0
const FAR_SIDE_Y := 190.0
const WALK_SECONDS := 1.7
## How far ahead we look for traffic when the child taps. Roughly the time the
## hero needs to be inside the road.
const LOOKAHEAD_SECONDS := 2.2

enum Light { RED, GREEN }

var _light: int = Light.RED
var _light_timer := 0.0
var _spawn_timer := 0.0
var _walking := false
var _at_far_side := false

var _cars: Array = []
var _lane_ys: Array[float] = []

# Difficulty knobs, all read from the level's "config" block.
var _car_speed := 150.0
var _gap_min := 2.2
var _gap_max := 3.4
var _green_seconds := 5.0
var _red_seconds := 5.0
var _lanes := 1
var _late_cars := false
var _rain := false

var _hero: SkinnedCharacter
var _light_body: Polygon2D
var _light_tex: TextureRect
var _road_layer: Node2D
var _instruction: Label
var _progress: Label
var _cross_button: Button


## One moving car. Kept as a plain object so cars cost nothing to spawn.
class Car extends RefCounted:
	var node: Node2D
	var node_3d: Node3D = null
	var speed: float
	var direction: int   # 1 = left to right, -1 = right to left
	var runner: bool     # ignores the stop line; teaches "look anyway"
	var stopped: bool = false


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_car_speed = float(config.get("car_speed", 150.0))
	_gap_min = float(config.get("car_gap_min", 2.2))
	_gap_max = float(config.get("car_gap_max", 3.4))
	_green_seconds = float(config.get("green_seconds", 5.0))
	_red_seconds = float(config.get("red_seconds", 5.0))
	_lanes = int(config.get("lanes", 1))
	_rain = bool(config.get("rain", false))
	# Cars that run a late green only appear once the basic rule is learned.
	_late_cars = bool(config.get("late_cars", int(level_data.get("difficulty", 1)) >= 2))

	# Difficulty: denser traffic and a shorter green. Car SPEED is left
	# alone on purpose -- this level teaches patience at a kerb, and a
	# faster car only makes the same lesson scarier.
	_gap_min = maxf(harder(_gap_min, 0.86), 0.9)
	_gap_max = maxf(harder(_gap_max, 0.86), _gap_min + 0.5)
	_green_seconds = clampf(harder(_green_seconds, 0.88), 2.6, 9.0)
	if difficulty() >= BRAVE:
		_late_cars = true
	bump_target("correct_crossings", difficulty() - NORMAL)

	# Challenge scaling: more crossings and denser traffic. Deliberately NOT
	# faster cars or shorter greens -- this level teaches patience, and rank
	# must never turn it into a reflex test.
	var rank := challenge_rank()
	if rank > 0:
		_gap_min = maxf(_gap_min - 0.05 * rank, 1.0)
		_gap_max = maxf(_gap_max - 0.05 * rank, _gap_min + 0.6)
		bump_target("correct_crossings", mini(rank, 5))

	_build_scene()
	_build_ui()
	_set_light(Light.RED)
	if not _lane_ys.is_empty():
		_spawn_car(260.0)
	_spawn_timer = 0.8


var _street_3d_vp: SubViewport
var _street_3d_world: Node3D
var _street_3d_cam: Camera3D
var _hero_3d: Node3D

func _build_3d_street() -> void:
	var vp_container := SubViewportContainer.new()
	vp_container.name = "Street3DContainer"
	vp_container.custom_minimum_size = Vector2(1280, 720)
	vp_container.size = Vector2(1280, 720)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)

	_street_3d_vp = SubViewport.new()
	_street_3d_vp.name = "Street3DViewport"
	_street_3d_vp.size = Vector2i(1280, 720)
	_street_3d_vp.own_world_3d = true
	_street_3d_vp.transparent_bg = false
	_street_3d_vp.handle_input_locally = false
	_street_3d_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(_street_3d_vp)

	var world_root := Node3D.new()
	world_root.name = "StreetWorld"
	_street_3d_vp.add_child(world_root)
	_street_3d_world = world_root

	var world_id := str(level_data.get("world", "safety"))
	var is_night := (world_id == "night_city" or world_id == "dark_castle")

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	if is_night:
		sky_mat.sky_top_color = Color(0.12, 0.15, 0.28)
		sky_mat.sky_horizon_color = Color(0.24, 0.28, 0.42)
		sky_mat.ground_bottom_color = Color(0.14, 0.16, 0.26)
		sky_mat.ground_horizon_color = Color(0.24, 0.28, 0.42)
	elif _rain:
		sky_mat.sky_top_color = Color(0.25, 0.32, 0.40)
		sky_mat.sky_horizon_color = Color(0.45, 0.50, 0.58)
		sky_mat.ground_bottom_color = Color(0.30, 0.35, 0.42)
		sky_mat.ground_horizon_color = Color(0.45, 0.50, 0.58)
	else:
		sky_mat.sky_top_color = Color(0.28, 0.54, 0.86)
		sky_mat.sky_horizon_color = Color(0.78, 0.86, 0.94)
		sky_mat.ground_bottom_color = Color(0.36, 0.35, 0.33)
		sky_mat.ground_horizon_color = Color(0.70, 0.68, 0.65)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32 if not is_night else 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.94, 0.88) if not is_night else Color(0.65, 0.75, 1.0)
	sun.light_energy = 0.72 if not is_night else 0.60
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.rotation_degrees = Vector3(-42.0, 36.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.55, 0.68, 0.90) if not is_night else Color(0.35, 0.45, 0.70)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(20.0, -140.0, 0.0)
	world_root.add_child(fill)

	_street_3d_cam = Camera3D.new()
	_street_3d_cam.name = "StreetCamera"
	_street_3d_cam.position = Vector3(0.0, 4.0, 8.4)
	_street_3d_cam.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	_street_3d_cam.fov = 46.0
	world_root.add_child(_street_3d_cam)

	var glb_path := "res://assets/scenes_3d/traffic_street.glb"
	if ResourceLoader.exists(glb_path):
		var street_packed: PackedScene = load(glb_path)
		var street_inst := street_packed.instantiate()
		street_inst.name = "TrafficStreetMesh"
		world_root.add_child(street_inst)


func _screen_to_road_3d(screen_pos: Vector2, road_y: float = 0.0) -> Vector3:
	if _street_3d_cam == null:
		return Vector3.ZERO
	var ray_origin := _street_3d_cam.project_ray_origin(screen_pos)
	var ray_normal := _street_3d_cam.project_ray_normal(screen_pos)
	if absf(ray_normal.y) < 0.0001:
		return Vector3.ZERO
	var t := (road_y - ray_origin.y) / ray_normal.y
	return ray_origin + ray_normal * t


func _create_3d_vehicle(direction: int, model_type: int, body_col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Vehicle3D"
	root.rotation_degrees.y = 90.0 if direction > 0 else -90.0

	var car_scale := 1.15
	var body_len := 2.2 * car_scale
	var body_wid := 1.1 * car_scale
	var body_hgt := 0.55 * car_scale

	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(body_len * 0.95, 0.14 * car_scale, body_wid * 0.88)
	chassis.mesh = cm
	chassis.position = Vector3(0.0, 0.18 * car_scale, 0.0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.18, 0.20, 0.22)
	cmat.roughness = 0.6
	chassis.set_surface_override_material(0, cmat)
	root.add_child(chassis)

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(body_len, body_hgt, body_wid)
	body.mesh = bm
	body.position = Vector3(0.0, 0.45 * car_scale, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = body_col
	bmat.metallic = 0.45
	bmat.roughness = 0.35
	body.set_surface_override_material(0, bmat)
	root.add_child(body)

	if model_type == 1:
		var box := MeshInstance3D.new()
		var bxm := BoxMesh.new()
		bxm.size = Vector3(body_len * 0.62, body_hgt * 1.5, body_wid * 0.96)
		box.mesh = bxm
		box.position = Vector3(-body_len * 0.18, 0.95 * car_scale, 0.0)
		var bxmat := StandardMaterial3D.new()
		bxmat.albedo_color = Color(0.92, 0.93, 0.95)
		bxmat.roughness = 0.55
		box.set_surface_override_material(0, bxmat)
		root.add_child(box)

		var cab := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(body_len * 0.32, body_hgt * 0.9, body_wid * 0.9)
		cab.mesh = cbm
		cab.position = Vector3(body_len * 0.32, 0.80 * car_scale, 0.0)
		cab.set_surface_override_material(0, bmat)
		root.add_child(cab)
	else:
		var cabin := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		var cab_len := body_len * (0.65 if model_type == 3 else 0.52)
		cbm.size = Vector3(cab_len, body_hgt * 0.85, body_wid * 0.86)
		cabin.mesh = cbm
		cabin.position = Vector3(-body_len * 0.05, 0.82 * car_scale, 0.0)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.72, 0.88, 0.98)
		gmat.roughness = 0.15
		gmat.metallic = 0.2
		cabin.set_surface_override_material(0, gmat)
		root.add_child(cabin)

		if model_type == 0 and body_col.r > 0.85 and body_col.g > 0.70:
			var sign := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.42, 0.16, 0.22)
			sign.mesh = sm
			sign.position = Vector3(0.0, 1.15 * car_scale, 0.0)
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color(1.0, 0.85, 0.20)
			smat.emission_enabled = true
			smat.emission = Color(1.0, 0.85, 0.20)
			smat.emission_energy_multiplier = 2.0
			sign.set_surface_override_material(0, smat)
			root.add_child(sign)

	var wheels: Array[Node3D] = []
	var wheel_rad := 0.24 * car_scale
	var wheel_wid := 0.12 * car_scale
	var wx_offsets := [-body_len * 0.34, body_len * 0.34]
	var wz_offsets := [-body_wid * 0.52, body_wid * 0.52]

	for wx in wx_offsets:
		for wz in wz_offsets:
			var wh_node := Node3D.new()
			wh_node.position = Vector3(wx, wheel_rad, wz)
			var wm := CylinderMesh.new()
			wm.top_radius = wheel_rad
			wm.bottom_radius = wheel_rad
			wm.height = wheel_wid
			var wh_mesh := MeshInstance3D.new()
			wh_mesh.mesh = wm
			wh_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.12, 0.12, 0.14)
			wmat.roughness = 0.85
			wh_mesh.set_surface_override_material(0, wmat)
			wh_node.add_child(wh_mesh)
			root.add_child(wh_node)
			wheels.append(wh_node)

	root.set_meta("wheels", wheels)

	var hl_mat := StandardMaterial3D.new()
	hl_mat.albedo_color = Color(1.0, 0.95, 0.80)
	hl_mat.emission_enabled = true
	hl_mat.emission = Color(1.0, 0.95, 0.80)
	hl_mat.emission_energy_multiplier = 3.5

	for lz in [-body_wid * 0.35, body_wid * 0.35]:
		var hl := MeshInstance3D.new()
		var hlm := BoxMesh.new()
		hlm.size = Vector3(0.08, 0.12, 0.18)
		hl.mesh = hlm
		hl.position = Vector3(body_len * 0.50, 0.45 * car_scale, lz)
		hl.set_surface_override_material(0, hl_mat)
		root.add_child(hl)

	var tl_mat := StandardMaterial3D.new()
	tl_mat.albedo_color = Color(0.95, 0.15, 0.10)
	tl_mat.emission_enabled = true
	tl_mat.emission = Color(0.95, 0.15, 0.10)
	tl_mat.emission_energy_multiplier = 2.5

	for lz in [-body_wid * 0.35, body_wid * 0.35]:
		var tl := MeshInstance3D.new()
		var tlm := BoxMesh.new()
		tlm.size = Vector3(0.08, 0.10, 0.18)
		tl.mesh = tlm
		tl.position = Vector3(-body_len * 0.50, 0.45 * car_scale, lz)
		tl.set_surface_override_material(0, tl_mat)
		root.add_child(tl)

	return root


func _create_3d_hero() -> Node3D:
	var h_root := Node3D.new()
	h_root.name = "Hero3D"

	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.28
	bm.height = 0.95
	body.mesh = bm
	body.position = Vector3(0.0, 0.65, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.28, 0.58, 0.92)
	bmat.roughness = 0.4
	body.set_surface_override_material(0, bmat)
	h_root.add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.32
	hm.height = 0.64
	head.mesh = hm
	head.position = Vector3(0.0, 1.25, 0.0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.98, 0.88, 0.35)
	head.set_surface_override_material(0, hmat)
	h_root.add_child(head)

	var cape := MeshInstance3D.new()
	var cpm := BoxMesh.new()
	cpm.size = Vector3(0.44, 0.72, 0.08)
	cape.mesh = cpm
	cape.position = Vector3(0.0, 0.75, 0.24)
	cape.rotation_degrees = Vector3(14.0, 0.0, 0.0)
	var cpmat := StandardMaterial3D.new()
	cpmat.albedo_color = Color(0.92, 0.28, 0.26)
	cape.set_surface_override_material(0, cpmat)
	h_root.add_child(cape)

	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.10
	sm.height = 0.20
	star.mesh = sm
	star.position = Vector3(0.0, 0.75, -0.26)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.92, 0.40)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.92, 0.40)
	smat.emission_energy_multiplier = 3.0
	star.set_surface_override_material(0, smat)
	h_root.add_child(star)

	return h_root


# --- construction -------------------------------------------------------

func _build_scene() -> void:
	_build_3d_street()

	var span := ROAD_BOTTOM - ROAD_TOP
	_lane_ys.clear()
	for i in range(_lanes):
		_lane_ys.append(ROAD_TOP + span * (float(i) + 0.5) / float(_lanes))

	_road_layer = Node2D.new()
	add_child(_road_layer)

	_build_traffic_light()

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(640, NEAR_SIDE_Y)
	add_child(_hero)
	_hero.set_height(150.0)
	Shapes.ground_shadow(_hero, Vector2(0, 10.0), 96.0, 0.35)

	if _street_3d_world != null:
		_hero_3d = _create_3d_hero()
		_street_3d_world.add_child(_hero_3d)
		_hero_3d.position = _screen_to_road_3d(_hero.position, 0.08)
		_hero.modulate.a = 0.0


func _build_traffic_light() -> void:
	var light_holder := Node2D.new()
	add_child(light_holder)

	var red_path := "res://assets/props_3d/traffic_light_post_red.png"
	if ResourceLoader.exists(red_path):
		var hud_card := Panel.new()
		hud_card.position = Vector2(1175, 96)
		hud_card.size = Vector2(78, 150)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.10, 0.14, 0.22, 0.72)
		card_style.set_corner_radius_all(18)
		card_style.border_width_top = 2
		card_style.border_width_left = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.40, 0.55, 0.75, 0.50)
		hud_card.add_theme_stylebox_override("panel", card_style)
		light_holder.add_child(hud_card)

		_light_tex = TextureRect.new()
		_light_tex.texture = load(red_path) as Texture2D
		_light_tex.custom_minimum_size = Vector2(64, 130)
		_light_tex.size = Vector2(64, 130)
		_light_tex.position = Vector2(7, 10)
		_light_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_light_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_light_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_card.add_child(_light_tex)

		_light_body = Polygon2D.new()
		add_child(_light_body)
		_light_body.visible = false
		return

	# Stone foundation plinth
	Shapes.fill(light_holder, Shapes.rounded_rect(Vector2(782, 630), Vector2(32, 24), 4.0),
		Color(0.68, 0.69, 0.72), 1.0)
	Shapes.fill(light_holder, Shapes.rounded_rect(Vector2(784, 630), Vector2(28, 4), 2.0),
		Color(0.85, 0.86, 0.89), 0.0)

	# 3D Steel post
	Shapes.fill(light_holder, Shapes.rounded_rect(Vector2(792, 455), Vector2(12, 180), 3.0),
		Color(0.28, 0.29, 0.33), 1.0)
	Shapes.fill(light_holder, Shapes.rounded_rect(Vector2(794, 455), Vector2(3, 180), 1.0),
		Color(0.42, 0.44, 0.48), 0.0)

	# Horizontal support bracket
	Shapes.fill(light_holder, Shapes.rounded_rect(Vector2(775, 450), Vector2(46, 8), 2.0),
		Color(0.24, 0.25, 0.28), 1.0)

	# 3D Housing box with beveled rim
	var housing_rect := Rect2(756, 360, 84, 130)
	Shapes.fill(light_holder, Shapes.rounded_rect(housing_rect.position, housing_rect.size, 8.0),
		Color(0.16, 0.17, 0.19), 1.0)
	Shapes.fill(light_holder, Shapes.rounded_rect(housing_rect.position + Vector2(2, 2), Vector2(housing_rect.size.x - 4, 4), 2.0),
		Color(0.35, 0.36, 0.40), 0.0)

	# Hood / Sun Visor over the lamp
	Shapes.fill(light_holder, PackedVector2Array([
		Vector2(764, 388), Vector2(798, 372), Vector2(832, 388),
		Vector2(830, 396), Vector2(798, 380), Vector2(766, 396),
	]), Color(0.10, 0.11, 0.12), 1.0)

	# Active signal lamp
	_light_body = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 32.0 + Vector2(798, 425))
	_light_body.polygon = pts
	add_child(_light_body)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	layer.add_child(root)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	root.add_child(back)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 34)
	_progress.add_theme_color_override("font_color", Color.WHITE)
	UiKit.on_art(_progress)
	# Right-aligned inside a fixed box that ends 24px short of the right edge,
	# so the text grows leftward and can never run off-screen. At x=980 with no
	# box it overflowed by 18px in every traffic level (the smoke test's one
	# standing warning).
	_progress.position = Vector2(650, 32)
	_progress.size = Vector2(490, 48)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_progress)
	_update_progress()

	_instruction = Label.new()
	_instruction.text = I18n.t("traffic.instruction")
	_instruction.add_theme_font_size_override("font_size", 38)
	_instruction.add_theme_color_override("font_color", Color.WHITE)
	UiKit.on_art(_instruction)
	_instruction.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_instruction.add_theme_constant_override("outline_size", 8)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# No anchor preset here: PRESET_CENTER_TOP anchors to the screen centre and
	# then treats `position` as an offset from it, which pushed this label to
	# x=980 and ran 300px off the right edge. Plain absolute positioning, like
	# every other label in the game.
	_instruction.position = Vector2(340, 40)
	_instruction.custom_minimum_size = Vector2(600, 0)
	_instruction.size = Vector2(600, 60)
	root.add_child(_instruction)

	# Bottom-right, not bottom-centre: centred it sat exactly on top of the
	# hero waiting at the kerb, hiding everything but his head -- and on a
	# landscape tablet the right corner is where the child's thumb already
	# rests anyway.
	_cross_button = UiKit.big_button(I18n.t("traffic.tap_to_cross"), Color(0.20, 0.62, 0.35))
	_cross_button.custom_minimum_size = Vector2(250, 78)
	_cross_button.position = Vector2(980, 608)
	_cross_button.pressed.connect(_on_cross_pressed)
	root.add_child(_cross_button)


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_tick_light(delta)
	_tick_spawn(delta)
	_tick_cars(delta)
	_sync_3d_hero(delta)


func _sync_3d_hero(_delta: float) -> void:
	if _hero_3d == null or not is_instance_valid(_hero_3d) or _hero == null or not is_instance_valid(_hero):
		return
	var hero_p := _screen_to_road_3d(_hero.position, 0.08)
	_hero_3d.position.x = hero_p.x
	_hero_3d.position.z = hero_p.z
	if _walking:
		_hero_3d.position.y = 0.08 + absf(sin(float(GameClock.ticks_ms()) * 0.016)) * 0.12
		_hero_3d.rotation_degrees.y = 180.0 if not _at_far_side else 0.0
	else:
		_hero_3d.position.y = 0.08
		_hero_3d.rotation_degrees.y = 180.0 if not _at_far_side else 0.0


func _tick_light(delta: float) -> void:
	_light_timer -= delta
	if _light_timer > 0.0:
		return
	_set_light(Light.GREEN if _light == Light.RED else Light.RED)


func _set_light(value: int) -> void:
	_light = value
	if _light_tex != null and is_instance_valid(_light_tex):
		var path := "res://assets/props_3d/traffic_light_post_%s.png" % ("green" if value == Light.GREEN else "red")
		if ResourceLoader.exists(path):
			_light_tex.texture = load(path) as Texture2D
	_sync_3d_traffic_light()
	if value == Light.GREEN:
		_light_timer = _green_seconds
		if _light_body: _light_body.color = Color(0.25, 0.85, 0.35)
		_instruction.text = I18n.t("traffic.go")
	else:
		_light_timer = _red_seconds
		if _light_body: _light_body.color = Color(0.90, 0.25, 0.25)
		_instruction.text = I18n.t("traffic.wait")


func _sync_3d_traffic_light() -> void:
	if _street_3d_vp == null or not is_instance_valid(_street_3d_vp):
		return
	var lens_red: MeshInstance3D = _street_3d_vp.find_child("LensRed", true, false) as MeshInstance3D
	var lens_green: MeshInstance3D = _street_3d_vp.find_child("LensGreen", true, false) as MeshInstance3D
	if lens_red != null:
		var mat_r := StandardMaterial3D.new()
		mat_r.roughness = 0.2
		if _light == Light.RED:
			mat_r.albedo_color = Color(1.0, 0.2, 0.15)
			mat_r.emission_enabled = true
			mat_r.emission = Color(1.0, 0.2, 0.15)
			mat_r.emission_energy_multiplier = 3.5
		else:
			mat_r.albedo_color = Color(0.20, 0.06, 0.06)
			mat_r.emission_enabled = false
		lens_red.set_surface_override_material(0, mat_r)
	if lens_green != null:
		var mat_g := StandardMaterial3D.new()
		mat_g.roughness = 0.2
		if _light == Light.GREEN:
			mat_g.albedo_color = Color(0.2, 0.95, 0.35)
			mat_g.emission_enabled = true
			mat_g.emission = Color(0.2, 0.95, 0.35)
			mat_g.emission_energy_multiplier = 3.5
		else:
			mat_g.albedo_color = Color(0.06, 0.20, 0.08)
			mat_g.emission_enabled = false
		lens_green.set_surface_override_material(0, mat_g)


func _tick_spawn(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(_gap_min, _gap_max)
	_spawn_car()


func _spawn_car(start_x: float = -999.0) -> void:
	if _lane_ys.is_empty():
		return
	var lane := randi() % _lane_ys.size()
	var direction := 1 if lane % 2 == 0 else -1

	var car := Car.new()
	car.speed = _car_speed * randf_range(0.9, 1.15)
	car.direction = direction
	car.runner = _late_cars and _light == Light.RED and randf() < 0.35

	var car_colors: Array[Color] = [
		Color(0.96, 0.76, 0.22), # Taxi Sunshine Yellow
		Color(0.28, 0.68, 0.65), # Nordic Teal
		Color(0.88, 0.34, 0.32), # Cherry Red
		Color(0.35, 0.62, 0.88), # Sky Blue
		Color(0.92, 0.55, 0.25), # Tangerine
		Color(0.68, 0.54, 0.82), # Lavender
		Color(0.35, 0.65, 0.42), # Forest Green
		Color(0.94, 0.92, 0.85)  # Warm Ivory
	]
	var body_col: Color = car_colors[randi() % car_colors.size()]
	var model_type: int = randi() % 4

	var node := Node2D.new()
	_build_voxel_car(node, direction, body_col, model_type)

	var spawn_x := start_x if start_x != -999.0 else (-160.0 if direction > 0 else 1440.0)
	node.position = Vector2(spawn_x, _lane_ys[lane])
	_road_layer.add_child(node)

	car.node = node

	if _street_3d_world != null:
		var car_3d := _create_3d_vehicle(direction, model_type, body_col)
		_street_3d_world.add_child(car_3d)
		car_3d.position = _screen_to_road_3d(node.position, 0.0)
		car.node_3d = car_3d
		node.modulate.a = 0.0

	_cars.append(car)


func _build_voxel_car(node: Node2D, direction: int, body_col: Color, model_type: int) -> void:

	var w: float = 126.0
	var h: float = 54.0
	if model_type == 1:   # Delivery Box Truck
		w = 144.0
		h = 64.0
	elif model_type == 2: # Compact Hatchback
		w = 110.0
		h = 52.0
	elif model_type == 3: # Minibus
		w = 138.0
		h = 58.0

	# 1. Ground Drop Shadow
	Shapes.fill(node, Shapes.rounded_rect(Vector2(-w * 0.5, 18.0), Vector2(w, 14.0), 6.0),
		Color(0.06, 0.07, 0.10, 0.35), 0.0)

	# 2. Chunky 3D Voxel Wheels
	var wheel_xs := [-w * 0.28, w * 0.28]
	if model_type == 1: # Truck has dual wheels in back
		wheel_xs = [-w * 0.34, -w * 0.18, w * 0.30] if direction > 0 else [-w * 0.30, w * 0.18, w * 0.34]

	for wx in wheel_xs:
		# Rubber tire
		Shapes.fill(node, Shapes.rounded_rect(Vector2(wx - 13.0, 10.0), Vector2(26.0, 22.0), 5.0),
			Color(0.14, 0.14, 0.16), 1.0)
		# Tread top highlight
		Shapes.fill(node, Shapes.rounded_rect(Vector2(wx - 11.0, 10.0), Vector2(22.0, 3.0), 1.0),
			Color(0.30, 0.30, 0.34), 0.0)
		# Silver wheel rim
		Shapes.fill(node, Shapes.rounded_rect(Vector2(wx - 7.0, 14.0), Vector2(14.0, 14.0), 3.0),
			Color(0.85, 0.86, 0.90), 0.0)
		# Hubcap center
		Shapes.fill(node, Shapes.circle_points(Vector2(wx, 21.0), 2.5, 6),
			Color(0.35, 0.35, 0.38), 0.0)

	# 3. Lower Chassis Frame
	Shapes.fill(node, Shapes.rounded_rect(Vector2(-w * 0.5, 8.0), Vector2(w, 10.0), 3.0),
		Color(0.20, 0.21, 0.24), 1.0)

	# 4. Main Body & Cabin
	var front_x: float = w * 0.5 * float(direction)
	var back_x: float = -front_x

	if model_type == 1: # Delivery Box Truck
		var cab_w: float = 46.0
		var box_w: float = w - cab_w
		var cab_x: float = (w * 0.5 - cab_w) if direction > 0 else -w * 0.5
		var box_x: float = -w * 0.5 if direction > 0 else (-w * 0.5 + cab_w)

		# Cargo Box (Ivory/White with ribbing)
		var box_col := Color(0.92, 0.93, 0.95)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(box_x, -h * 0.65), Vector2(box_w, h * 0.85), 4.0),
			box_col, 1.0)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(box_x, -h * 0.65), Vector2(box_w, 5.0), 2.0),
			box_col.lightened(0.15), 0.0)
		# Corrugated ribs
		for ri in range(3):
			var rx: float = box_x + 10.0 + float(ri) * (box_w - 20.0) * 0.5
			Shapes.fill(node, Shapes.rounded_rect(Vector2(rx, -h * 0.58), Vector2(2.5, h * 0.72), 1.0),
				box_col.darkened(0.14), 0.0)
		# Accent stripe on cargo box
		Shapes.fill(node, Shapes.rounded_rect(Vector2(box_x, -h * 0.15), Vector2(box_w, 9.0), 1.0),
			body_col, 0.0)

		# Front Cab
		Shapes.fill(node, Shapes.rounded_rect(Vector2(cab_x, -h * 0.35), Vector2(cab_w, h * 0.55), 4.0),
			body_col, 1.0)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(cab_x, -h * 0.35), Vector2(cab_w, 4.0), 2.0),
			body_col.lightened(0.20), 0.0)
		# Cab Windshield
		var win_x: float = cab_x + (6.0 if direction > 0 else 8.0)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(win_x, -h * 0.30), Vector2(cab_w - 14.0, 18.0), 3.0),
			Color(0.72, 0.88, 0.96), 0.0)

	else: # Sedan / Hatchback / Minibus
		# Main Body Block
		Shapes.fill(node, Shapes.rounded_rect(Vector2(-w * 0.5, -h * 0.15), Vector2(w, h * 0.40), 5.0),
			body_col, 1.0)
		# Sunlit top body highlight
		Shapes.fill(node, Shapes.rounded_rect(Vector2(-w * 0.48, -h * 0.15), Vector2(w * 0.96, 4.0), 2.0),
			body_col.lightened(0.22), 0.0)
		# Lower body shadow
		Shapes.fill(node, Shapes.rounded_rect(Vector2(-w * 0.48, h * 0.15), Vector2(w * 0.96, 6.0), 2.0),
			body_col.darkened(0.16), 0.0)

		# Raised Cabin Roof
		var roof_w: float = w * (0.58 if model_type == 0 else (0.50 if model_type == 2 else 0.72))
		var roof_h: float = h * 0.44
		var roof_x: float = -roof_w * 0.5 - (8.0 * float(direction) if model_type == 0 else 0.0)
		var roof_y: float = -h * 0.15 - roof_h

		var roof_col: Color = Color(0.96, 0.96, 0.95) if (model_type == 2 or model_type == 3) else body_col
		Shapes.fill(node, Shapes.rounded_rect(Vector2(roof_x, roof_y), Vector2(roof_w, roof_h + 3.0), 4.0),
			roof_col, 1.0)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(roof_x, roof_y), Vector2(roof_w, 4.0), 2.0),
			roof_col.lightened(0.20), 0.0)

		# Cabin Windows (Windshield & Side windows)
		var glass_col := Color(0.72, 0.88, 0.96)
		var win_margin := 5.0
		var win_w: float = (roof_w - win_margin * 3.0) * 0.5
		var win_h: float = roof_h - 7.0
		# Front & Rear windows
		Shapes.fill(node, Shapes.rounded_rect(Vector2(roof_x + win_margin, roof_y + 4.0), Vector2(win_w, win_h), 2.0),
			glass_col, 0.0)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(roof_x + win_margin * 2.0 + win_w, roof_y + 4.0), Vector2(win_w, win_h), 2.0),
			glass_col, 0.0)
		# Window gleam
		Shapes.fill(node, Shapes.rounded_rect(Vector2(roof_x + win_margin + 2.0, roof_y + 6.0), Vector2(win_w - 4.0, 3.0), 1.0),
			Color(1.0, 1.0, 1.0, 0.85), 0.0)

		# Special roof accessories
		if model_type == 0 and body_col.r > 0.85 and body_col.g > 0.70:
			# Taxi Sign on roof
			Shapes.fill(node, Shapes.rounded_rect(Vector2(-14.0, roof_y - 10.0), Vector2(28.0, 10.0), 3.0),
				Color(1.0, 0.85, 0.20), 1.0)
			Shapes.fill(node, Shapes.rounded_rect(Vector2(-10.0, roof_y - 8.0), Vector2(20.0, 6.0), 1.0),
				Color(0.12, 0.12, 0.14), 0.0)
		elif model_type == 3:
			# Minibus Roof Rack
			Shapes.fill(node, Shapes.rounded_rect(Vector2(roof_x + 4.0, roof_y - 5.0), Vector2(roof_w - 8.0, 4.0), 1.0),
				Color(0.75, 0.76, 0.80), 0.0)

	# 5. Bumpers, Headlights & Taillights (Facing direction)
	# Front bumper & grill
	var f_bumper_x: float = front_x - (4.0 if direction > 0 else 0.0)
	Shapes.fill(node, Shapes.rounded_rect(Vector2(f_bumper_x, 6.0), Vector2(4.0, 11.0), 2.0),
		Color(0.82, 0.84, 0.88), 1.0)
	# Rear bumper
	var b_bumper_x: float = back_x - (0.0 if direction > 0 else 4.0)
	Shapes.fill(node, Shapes.rounded_rect(Vector2(b_bumper_x, 6.0), Vector2(4.0, 11.0), 2.0),
		Color(0.40, 0.42, 0.46), 1.0)

	# Front Glowing Headlight
	var head_x: float = front_x - (6.0 if direction > 0 else 2.0)
	Shapes.fill(node, Shapes.rounded_rect(Vector2(head_x, -4.0), Vector2(8.0, 10.0), 2.0),
		Color(1.0, 0.95, 0.65), 0.0)
	# Headlight soft forward glow
	var glow_offs: float = 8.0 * float(direction)
	Shapes.fill(node, Shapes.rounded_rect(Vector2(head_x + glow_offs, -6.0), Vector2(12.0 * float(direction), 14.0), 3.0),
		Color(1.0, 0.95, 0.65, 0.35), 0.0)

	# Rear Brake Taillight
	var tail_x: float = back_x - (2.0 if direction > 0 else 6.0)
	Shapes.fill(node, Shapes.rounded_rect(Vector2(tail_x, -2.0), Vector2(6.0, 9.0), 2.0),
		Color(0.96, 0.22, 0.24), 0.0)


func _tick_cars(delta: float) -> void:
	var survivors: Array = []
	for car in _cars:
		var stop_x: float = CROSSWALK_LEFT - 90.0 if car.direction > 0 else CROSSWALK_RIGHT + 90.0
		var before_line: bool = (car.node.position.x < stop_x) if car.direction > 0 \
			else (car.node.position.x > stop_x)

		# On a green pedestrian light, ordinary cars wait at the line. Cars that
		# are already inside the crossing drive on through, which is exactly the
		# situation the child needs to learn to wait out.
		car.stopped = _light == Light.GREEN and not car.runner and before_line

		if not car.stopped:
			car.node.position.x += car.speed * car.direction * delta

		if car.node_3d != null and is_instance_valid(car.node_3d):
			var pos_3d := _screen_to_road_3d(car.node.position, 0.0)
			car.node_3d.position.x = pos_3d.x
			car.node_3d.position.z = pos_3d.z
			if not car.stopped:
				var wh_list: Array = car.node_3d.get_meta("wheels", [])
				for wh in wh_list:
					if wh is Node3D and is_instance_valid(wh):
						wh.rotation_degrees.z -= car.speed * float(car.direction) * delta * 4.0

		if car.node.position.x < -300.0 or car.node.position.x > 1580.0:
			if car.node_3d != null and is_instance_valid(car.node_3d):
				car.node_3d.queue_free()
			car.node.queue_free()
		else:
			survivors.append(car)
	_cars = survivors


# --- the decision -------------------------------------------------------

func _on_cross_pressed() -> void:
	# Mid-hop taps wait: a walk starting while the landing is still playing
	# left two tweens fighting over the hero's position.
	if _hero != null and _hero.is_moving():
		return
	if _walking:
		return

	if _light == Light.RED:
		_reject("traffic.too_soon", "wrong_light")
		return

	if _traffic_in_the_way():
		_reject("traffic.car_coming", "car_coming")
		return

	_walk_across()


## True if any moving car is inside the crossing, or will reach it before the
## hero is clear. Stopped cars are safe and deliberately do not block, otherwise
## a queue at the line would make the level unwinnable.
func _traffic_in_the_way() -> bool:
	for car in _cars:
		if car.stopped:
			continue
		var x: float = car.node.position.x
		var future_x: float = x + car.speed * car.direction * LOOKAHEAD_SECONDS
		var lo: float = minf(x, future_x)
		var hi: float = maxf(x, future_x)
		if hi >= CROSSWALK_LEFT - 80.0 and lo <= CROSSWALK_RIGHT + 80.0:
			return true
	return false


func _reject(message_key: String, voice_clip: String) -> void:
	_instruction.text = I18n.t(message_key)
	AudioManager.play_voice("res://assets/audio/voice/level/%s.ogg" % voice_clip)
	_shake_hero()
	score_mistake()


## A small step backwards, not a scary noise or a lost life.
func _shake_hero() -> void:
	if not Juice.motion_enabled():
		return
	# Steps back rather than sideways: the hero retreating from the kerb is
	# the correction being shown, not just motion.
	var origin := _hero.position
	var t := create_tween()
	t.tween_property(_hero, "position", origin + Vector2(0, 26), 0.12)
	t.tween_property(_hero, "position", origin, 0.18)


func _walk_across() -> void:
	_walking = true
	_cross_button.disabled = true
	var destination := FAR_SIDE_Y if not _at_far_side else NEAR_SIDE_Y

	# Legs actually walk while the crossing happens -- the rig has a walk
	# cycle, and a hero who glides across a road is teaching levitation, not
	# road safety.
	_hero.walk(true)
	var t := create_tween()
	t.tween_property(_hero, "position:y", destination, WALK_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_hero.walk(false)

	_at_far_side = not _at_far_side
	_walking = false
	_cross_button.disabled = false
	_instruction.text = I18n.t("traffic.well_done")
	AudioManager.say("praise_1")
	Juice.burst(self, _hero.position)
	# A little hop on the safe kerb: relief with feet.
	_hero.hop()
	score_correct()
	_update_progress()


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = I18n.t("traffic.progress") % [
		result.correct, target_value("correct_crossings", 3)
	]
