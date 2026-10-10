extends Node2D
## A neighbour's small, deterministic farm. Layout and crops come from
## npc_farms.json; the save only remembers the child's share/help promise.

const Farm := preload("res://scripts/garden/farm_save.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")

const BED_COLS := 3
const BED_FIRST := Vector2(240, 310)
const BED_STEP := Vector2(250, 210)

@export var npc_id := "rabbit"

var _plots: Array = []
var _bed_views: Array = []
var _star: Node2D
var _friend_model: Node3D
var _basket_at := Vector2.ZERO
var _finger := -1
var presses := 0


func _ready() -> void:
	if GameData.get_npc_farm(npc_id).is_empty():
		npc_id = "rabbit"
	_build()
	AudioManager.play_sfx("res://assets/audio/door.ogg")


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_bed_views.clear()
	_star = null
	_friend_model = null
	var view := get_viewport_rect().size
	_build_meadow(view)
	_plots = NpcFarm.friend_beds(npc_id, GameClock.now_unix())
	for i in range(_plots.size()):
		var bed := PlotView.new()
		add_child(bed)
		bed.setup(i)
		bed.position = _bed_centre(i)
		bed.refresh(_plots[i])
		_bed_views.append(bed)

	for i in range(_plots.size()):
		if bool(_plots[i].get("share", false)) \
				and NpcFarm.can_pick_friend_share(npc_id, GameClock.now_unix()):
			_star = Node2D.new()
			_star.name = "ShareStar"
			_star.position = _bed_centre(i) + Vector2(0, -96)
			add_child(_star)
			Shapes.fill(_star, Shapes.star_points(Vector2.ZERO, 24.0),
				Color(1.0, 0.86, 0.30), 1.0)
			Shapes.glow(_star, Vector2.ZERO, 40.0,
				Color(1.0, 0.88, 0.42), 4, 0.45)

	_basket_at = Vector2(view.x - 112.0, view.y - 110.0)
	var basket := UiKit.picture("basket", 54.0)
	if basket != null:
		basket.name = "FriendShareBasket"
		basket.position = _basket_at - Vector2(27.0, 27.0)
		basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(basket)
	_top_bar(view)
	if bool(NpcFarm.friend_state(npc_id).get("help_owed", false)):
		_point_at_thirsty()


func _build_meadow(view: Vector2) -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "FriendMeadow3DBackdrop"
	viewport_container.stretch = true
	viewport_container.custom_minimum_size = view
	viewport_container.size = view
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.z_index = -20
	add_child(viewport_container)

	var vp := SubViewport.new()
	vp.name = "SubViewport"
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(int(view.x), int(view.y))
	viewport_container.add_child(vp)

	var root := Node3D.new()
	root.name = "FriendFarmWorld3D"
	vp.add_child(root)
	var meadow_path := "res://assets/scenes_3d/harvest_meadow.glb"
	if ResourceLoader.exists(meadow_path):
		var meadow: PackedScene = load(meadow_path)
		if meadow != null:
			root.add_child(meadow.instantiate())

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.55, 0.88)
	sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.96)
	sky_mat.ground_bottom_color = Color(0.26, 0.38, 0.22)
	sky_mat.ground_horizon_color = Color(0.68, 0.74, 0.65)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var environment_node := WorldEnvironment.new()
	environment_node.environment = environment
	root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 0.76
	sun.shadow_enabled = true
	root.add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.8, 11.2)
	camera.rotation_degrees = Vector3(-17.0, 0.0, 0.0)
	camera.fov = 39.0
	camera.current = true
	root.add_child(camera)

	var model_path := "res://assets/harvest_3d/runtime/friends/%s.glb" \
		% str(GameData.get_npc_farm(npc_id).get("character_model", npc_id))
	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene != null:
			_friend_model = model_scene.instantiate() as Node3D
			if _friend_model != null:
				_friend_model.name = "FriendCharacter3D"
				_friend_model.position = Vector3(3.4, 0.0, 0.2)
				root.add_child(_friend_model)


func _top_bar(view: Vector2) -> void:
	var back := UiKit.back_button(_go_home)
	back.position = Vector2(24.0, 16.0)
	add_child(back)

	var friend_def: Dictionary = GameData.get_npc_farm(npc_id)
	var friend_name := I18n.t(str(friend_def.get("name_key", "friend.rabbit")))
	var title := UiKit.title_on_art(
		I18n.t("garden.friend_farm_title") % [friend_name], 36)
	title.position = Vector2(view.x * 0.5 - 240.0, 14.0)
	title.size = Vector2(480.0, 48.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var prompt_key := "garden.friend_farm_help_hint" \
		if bool(NpcFarm.friend_state(npc_id).get("help_owed", false)) \
		else "garden.friend_farm_share_hint"
	var prompt := UiKit.title(I18n.t(prompt_key), 16, Color(0.38, 0.33, 0.25))
	prompt.position = Vector2(view.x * 0.5 - 260.0, 58.0)
	prompt.size = Vector2(520.0, 24.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt)

	var badge := Panel.new()
	badge.position = Vector2(view.x - 174.0, 14.0)
	badge.size = Vector2(146.0, 56.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.98, 0.98, 0.95, 0.90), 26))
	add_child(badge)
	var star := UiKit.picture("star", 32.0)
	if star != null:
		star.position = Vector2(view.x - 158.0, 25.0)
		add_child(star)
	var count := UiKit.title(str(NpcFarm.friend_friendship(npc_id)), 26)
	count.position = Vector2(view.x - 112.0, 23.0)
	count.size = Vector2(70.0, 36.0)
	add_child(count)


func _bed_centre(index: int) -> Vector2:
	return BED_FIRST + Vector2(float(index % BED_COLS) * BED_STEP.x,
		float(index / BED_COLS) * BED_STEP.y)


func _bed_under(at: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for i in range(_plots.size()):
		var centre := _bed_centre(i)
		var half: Vector2 = (_bed_views[i] as Node2D).call("reach")
		if absf(at.x - centre.x) > half.x or absf(at.y - centre.y) > half.y:
			continue
		var distance := centre.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1:
			_finger = touch.index
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			_press(touch.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _finger == -1:
			_finger = -2
		elif not click.pressed and _finger == -2:
			_finger = -1
			_press(click.position)


func _press(at: Vector2) -> void:
	presses += 1
	var index := _bed_under(at)
	if index < 0:
		return
	var plot: Dictionary = _plots[index]
	if bool(plot.get("share", false)):
		_pick_share(index)
	elif bool(plot.get("help_target", false)):
		_water_for_friend(index)
	else:
		Juice.nudge(_bed_views[index], 8.0)


func _pick_share(index: int) -> void:
	var now := GameClock.now_unix()
	if not NpcFarm.can_pick_friend_share(npc_id, now):
		Juice.nudge(_bed_views[index], 8.0)
		return
	if not NpcFarm.record_friend_share(npc_id, now):
		return
	var farm_def: Dictionary = GameData.get_npc_farm(npc_id)
	var crop_id := str(farm_def.get("share_crop", "carrot"))
	Barn.store_harvest(crop_id, 1)
	preload("res://scripts/garden/recipe_manager.gd").check_barn(false)
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	if _star != null and is_instance_valid(_star):
		_star.queue_free()
		_star = null
	_fly_share_crop(crop_id, _bed_centre(index))
	_refresh_plots(now)
	if _friend_model != null and is_instance_valid(_friend_model) and Juice.motion_enabled():
		var cheer := _friend_model.create_tween()
		cheer.tween_property(_friend_model, "rotation_degrees:y", 14.0, 0.16)
		cheer.tween_property(_friend_model, "rotation_degrees:y", -14.0, 0.16)
		cheer.tween_property(_friend_model, "rotation_degrees:y", 0.0, 0.18)
	_point_at_thirsty()


func _fly_share_crop(crop_id: String, from: Vector2) -> void:
	if not Juice.motion_enabled():
		return
	var crop: Dictionary = GameData.get_crop(crop_id)
	var icon := UiKit.picture(str(crop.get("icon", crop_id)), 54.0)
	if icon == null:
		return
	icon.name = "FriendShareFlight"
	icon.position = from - Vector2(27.0, 27.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	var tween := icon.create_tween()
	tween.tween_property(icon, "position", _basket_at - Vector2(27.0, 27.0), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(icon.queue_free)


func _water_for_friend(index: int) -> void:
	if not bool(NpcFarm.friend_state(npc_id).get("help_owed", false)):
		return
	if not NpcFarm.record_friend_help(npc_id):
		return
	var now := GameClock.now_unix()
	NpcFarm.record_friend_visit(npc_id, now)
	Level.award("help")
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	AudioManager.play_sfx("res://assets/audio/star.ogg")
	_refresh_plots(now)
	if Juice.motion_enabled():
		Juice.burst(self, _bed_centre(index), 16)
	if _friend_model != null and is_instance_valid(_friend_model) and Juice.motion_enabled():
		var cheer := _friend_model.create_tween()
		cheer.tween_property(_friend_model, "position:y", 0.35, 0.12)
		cheer.tween_property(_friend_model, "position:y", 0.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var thank_you := UiKit.title(I18n.t("garden.friend_farm_thanks"), 22,
		Color(0.35, 0.52, 0.25))
	thank_you.name = "FriendFarmThanks"
	thank_you.position = Vector2(viewport_size().x * 0.5 - 230.0, 116.0)
	thank_you.size = Vector2(460.0, 34.0)
	thank_you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(thank_you)
	if Juice.motion_enabled():
		var fade := thank_you.create_tween()
		fade.tween_interval(1.8)
		fade.tween_property(thank_you, "modulate:a", 0.0, 0.35)
		fade.tween_callback(thank_you.queue_free)


func _refresh_plots(now: int) -> void:
	_plots = NpcFarm.friend_beds(npc_id, now)
	for i in range(mini(_plots.size(), _bed_views.size())):
		(_bed_views[i] as Node2D).call("refresh", _plots[i], true)
	if _star == null and NpcFarm.can_pick_friend_share(npc_id, now):
		for i in range(_plots.size()):
			if bool(_plots[i].get("share", false)):
				_star = Node2D.new()
				_star.name = "ShareStar"
				_star.position = _bed_centre(i) + Vector2(0, -96)
				add_child(_star)
				Shapes.fill(_star, Shapes.star_points(Vector2.ZERO, 24.0),
					Color(1.0, 0.86, 0.30), 1.0)
				Shapes.glow(_star, Vector2.ZERO, 40.0,
					Color(1.0, 0.88, 0.42), 4, 0.45)
				break


func _point_at_thirsty() -> void:
	for i in range(_plots.size()):
		if bool(_plots[i].get("help_target", false)) \
				and bool(NpcFarm.friend_state(npc_id).get("help_owed", false)):
			var hand := Tutorial.new()
			add_child(hand)
			hand.add_step(_bed_centre(i), _bed_centre(i), 1.2)
			hand.play()
			return


func _go_home() -> void:
	SceneManager.goto_scene("res://scenes/garden/Garden.tscn")


func viewport_size() -> Vector2:
	return get_viewport_rect().size


func _process(delta: float) -> void:
	if _star != null and is_instance_valid(_star) and Juice.motion_enabled():
		_star.rotation += delta * 0.35
