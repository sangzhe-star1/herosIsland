extends Node2D
## 小熊农场: a friend's garden, and one strawberry with a star over it.
##
## ONE SCREEN, NO CAMERA
##
## The bear's farm fits on the glass whole. That is on purpose: a visit is a
## moment, not a place to manage, and a place that pans is a place a child can
## get lost in twice over -- once at home, once here. Six beds, the bear, a
## well, and the way back, all visible at once.
##
## WHAT A VISIT IS
##
## Look around; if the shared strawberry has grown back, pick it (a tap -- the
## strawberry's own gesture); it flies to the visitor basket and is HIS, kept,
## whatever happens next. The bear then points at the thirsty bed, and
## watering it clears the promise and grows the friendship by one. A child who
## leaves without watering keeps the strawberry and finds the bear still
## hoping next time -- the next share waits on the kindness, but nothing is
## ever taken back and nobody is ever cross. See npc_farm_manager.gd for the
## arithmetic; this file only draws it and hands taps over.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")

const TOP_BAR := 96.0

## Where the six beds sit on the glass, two rows of three on the left, leaving
## the right side to the bear and his well. Spaced by the same thumb rules as
## everything else: 236px between centres beats every reach in the game.
const BED_COLS := 3
const BED_FIRST := Vector2(240, 310)
const BED_STEP := Vector2(250, 210)

var _plots: Array = []
var _bed_views: Array = []
var _star: Node2D
var _basket_at := Vector2.ZERO
## Watered this visit, in memory only: the bear's farm has no save, and next
## visit the arithmetic will have dried the bed again, which is a garden being
## a garden.
var _watered_this_visit := false
var _t := 0.0
## Who owns the press: -1 nobody, a touch index, or -2 the mouse. The same
## claim the farm's world makes, for the same reason: with touch<->mouse
## emulation on, ONE physical tap arrives as BOTH event families, and a
## screen that answers each family separately does everything twice. The
## idempotence guards would eat the double quietly -- which is worse than
## loudly, because the probe proved it by removing one.
var _finger := -1
## How many presses this screen has actually dispatched. Read by the probe,
## which taps N times and requires exactly N -- the assertion that keeps the
## claim above from quietly rotting.
var presses := 0

var _meadow_3d_vp: SubViewport
var _meadow_3d_world: Node3D
var _meadow_3d_cam: Camera3D
var _basket_3d: Node3D

func _screen_to_ground_3d(screen_pos: Vector2, ground_y: float = 0.12) -> Vector3:
	if _meadow_3d_cam == null:
		return Vector3.ZERO
	var ray_origin := _meadow_3d_cam.project_ray_origin(screen_pos)
	var ray_normal := _meadow_3d_cam.project_ray_normal(screen_pos)
	if absf(ray_normal.y) < 0.0001:
		return Vector3.ZERO
	var t := (ground_y - ray_origin.y) / ray_normal.y
	return ray_origin + ray_normal * t


func _ready() -> void:
	_build()
	AudioManager.say("bear_welcome")
	if NpcFarm.can_pick(GameClock.now_unix()):
		# One beat later so the welcome is not talked over.
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_inside_tree() and NpcFarm.can_pick(GameClock.now_unix()):
				AudioManager.say("bear_share"))


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_bed_views.clear()
	_star = null
	var view := get_viewport_rect().size

	# The ground: the bear's meadow, rendered as a genuine 3D low-poly diorama
	_build_3d_meadow(view)

	_plots = NpcFarm.bear_beds(GameClock.now_unix())
	for i in range(_plots.size()):
		var bed := PlotView.new()
		add_child(bed)
		bed.setup(i)
		bed.position = _bed_centre(i)
		bed.refresh(_plots[i])
		_bed_views.append(bed)

	# The share star, slowly turning over the one strawberry that is his to
	# take. The star IS the rule: no star, nothing to take, nothing to refuse.
	for i in range(_plots.size()):
		if bool(_plots[i].get("share", false)) \
				and Farm.is_ready(_plots[i]):
			_star = Node2D.new()
			_star.position = _bed_centre(i) + Vector2(0, -96)
			add_child(_star)
			Shapes.fill(_star, Shapes.star_points(Vector2.ZERO, 26.0),
				Color(1.0, 0.86, 0.30), 1.0)
			Shapes.glow(_star, Vector2.ZERO, 44.0,
				Color(1.0, 0.88, 0.42), 4, 0.5)

	# The watering can by the 3D well, ready to water thirsty beds
	var can := UiKit.picture("watering_can", 58.0)
	if can != null:
		can.position = Vector2(view.x - 210.0, 350.0)
		add_child(can)
		Juice.idle_bob(can, 6.0, 2.0)

	# The visitor basket: where the shared strawberry lands. Anchored to the 3D basket.
	_basket_at = Vector2(view.x - 160.0, view.y - 120.0)
	if _meadow_3d_world != null:
		var b_glb := "res://assets/harvest_3d/runtime/basket.glb"
		if ResourceLoader.exists(b_glb):
			var b_scene: PackedScene = load(b_glb)
			if b_scene != null:
				var b_inst: Node3D = b_scene.instantiate() as Node3D
				if b_inst != null:
					_meadow_3d_world.add_child(b_inst)
					b_inst.position = _screen_to_ground_3d(_basket_at, 0.06)
					b_inst.scale = Vector3(1.35, 1.35, 1.35)
					_basket_3d = b_inst

	_top_bar(view)

	# Owed from last time: the bear points at the thirsty bed straight away.
	if bool(NpcFarm.bear_state().get("help_owed", false)):
		_point_at_thirsty()


func _build_3d_meadow(view: Vector2) -> void:
	var glb_path := "res://assets/scenes_3d/harvest_meadow.glb"
	if ResourceLoader.exists(glb_path):
		var vp_container := SubViewportContainer.new()
		vp_container.name = "BearMeadow3DBackdrop"
		vp_container.stretch = true
		vp_container.custom_minimum_size = view
		vp_container.size = view
		vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp_container.z_index = -20
		add_child(vp_container)

		var vp := SubViewport.new()
		vp.name = "SubViewport"
		vp.own_world_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.size = Vector2i(int(view.x), int(view.y))
		vp_container.add_child(vp)

		var world_root := Node3D.new()
		world_root.name = "World3D"
		vp.add_child(world_root)

		var glb_scene: PackedScene = load(glb_path)
		if glb_scene != null:
			var glb_inst: Node = glb_scene.instantiate()
			world_root.add_child(glb_inst)

		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.28, 0.55, 0.88)
		sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.96)
		sky_mat.ground_bottom_color = Color(0.26, 0.38, 0.22)
		sky_mat.ground_horizon_color = Color(0.68, 0.74, 0.65)
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.34
		env.tonemap_mode = Environment.TONE_MAPPER_ACES

		var env_node := WorldEnvironment.new()
		env_node.environment = env
		world_root.add_child(env_node)

		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35.0, -28.0, 0.0)
		sun.light_color = Color(1.0, 0.96, 0.90)
		sun.light_energy = 0.76
		sun.shadow_enabled = true
		sun.shadow_blur = 1.8
		sun.shadow_bias = 0.03
		world_root.add_child(sun)

		var cam := Camera3D.new()
		cam.position = Vector3(0.0, 4.8, 11.2)
		cam.rotation_degrees = Vector3(-17.0, 0.0, 0.0)
		cam.fov = 39.0
		cam.current = true
		world_root.add_child(cam)

		_meadow_3d_vp = vp
		_meadow_3d_world = world_root
		_meadow_3d_cam = cam
		return

	# Fallback if 3D scene is not loaded
	Shapes.gradient_quad(self, Vector2.ZERO, view,
		Color(0.66, 0.82, 0.94), Color(0.80, 0.88, 0.72))


func _top_bar(view: Vector2) -> void:
	# Floating frosted glassmorphism capsule HUD: lets the 3D farm meadow breathe through!
	var pill := Panel.new()
	var pill_w: float = minf(view.x - 300.0, 520.0)
	pill.position = Vector2((view.x - pill_w) * 0.5, 14.0)
	pill.custom_minimum_size = Vector2(pill_w, 64.0)
	pill.size = Vector2(pill_w, 64.0)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.98, 0.98, 0.95, 0.88)
	pill_style.corner_radius_top_left = 32
	pill_style.corner_radius_top_right = 32
	pill_style.corner_radius_bottom_left = 32
	pill_style.corner_radius_bottom_right = 32
	pill_style.shadow_color = Color(0.08, 0.12, 0.18, 0.18)
	pill_style.shadow_size = 12
	pill_style.shadow_offset = Vector2(0, 4)
	pill.add_theme_stylebox_override("panel", pill_style)
	add_child(pill)

	var back := UiKit.back_button(_go_home)
	back.position = Vector2(24, 16)
	add_child(back)

	var title := UiKit.title_on_art(I18n.t("garden.bear_farm_title"), 44)
	title.position = Vector2(view.x * 0.5 - 220.0, 18)
	title.size = Vector2(440, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# The friendship so far: floating pill badge
	var badge := Panel.new()
	badge.position = Vector2(view.x - 170.0, 14.0)
	badge.custom_minimum_size = Vector2(146, 64)
	badge.size = Vector2(146, 64)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.98, 0.98, 0.95, 0.88)
	badge_style.corner_radius_top_left = 32
	badge_style.corner_radius_top_right = 32
	badge_style.corner_radius_bottom_left = 32
	badge_style.corner_radius_bottom_right = 32
	badge_style.shadow_color = Color(0.08, 0.12, 0.18, 0.18)
	badge_style.shadow_size = 12
	badge_style.shadow_offset = Vector2(0, 4)
	badge.add_theme_stylebox_override("panel", badge_style)
	add_child(badge)

	var star := UiKit.picture("star", 36.0)
	if star != null:
		star.position = Vector2(view.x - 156.0, 22)
		add_child(star)
	var count := UiKit.title(str(NpcFarm.friendship()), 32)
	count.position = Vector2(view.x - 110.0, 22)
	count.size = Vector2(80, 44)
	add_child(count)


func _go_home() -> void:
	# Home is the garden, entered the front way so its own setup runs -- growth
	# settles, the dog re-aims, the shared strawberry he is carrying shows up
	# in the barn. current_level_id is still the garden's: it was set walking
	# IN and nothing here ever changes it.
	SceneManager.goto_scene("res://scenes/garden/Garden.tscn")


func _bed_centre(index: int) -> Vector2:
	return BED_FIRST + Vector2(
		float(index % BED_COLS) * BED_STEP.x,
		float(index / BED_COLS) * BED_STEP.y)


func _bed_under(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in range(_plots.size()):
		var centre := _bed_centre(i)
		var half: Vector2 = (_bed_views[i] as Node2D).call("reach")
		if absf(at.x - centre.x) > half.x or absf(at.y - centre.y) > half.y:
			continue
		var d := centre.distance_to(at)
		if d < best_d:
			best_d = d
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
		_pick_the_shared_one(index)
	elif bool(plot.get("sneak", false)):
		_sneak_the_quiet_one(index)
	elif bool(plot.get("help_target", false)):
		_water_for_the_bear(index)
	else:
		# The bear's own beds are the bear's. A wobble says "not this one"
		# without a refusal, a sound, or a lesson.
		Juice.nudge(_bed_views[index], 8.0)


## The pick. A tap is the strawberry's own harvest gesture, and the ONE
## allowed target is the bed wearing the star -- everything else already
## turned the tap away above.
func _pick_the_shared_one(index: int) -> void:
	var now := GameClock.now_unix()
	if not NpcFarm.can_pick(now):
		# The star is down: nothing here to take. The bed shrugs.
		Juice.nudge(_bed_views[index], 8.0)
		return
	# Written down FIRST, saved at once: a tablet closed mid-flight must come
	# back knowing the strawberry was his and the watering is owed.
	NpcFarm.record_pick(now)
	var farm_def: Dictionary = GameData.get_npc_farm("bear")
	Barn.store_harvest(str(farm_def.get("share_crop", "strawberry")), 1)
	# The shared berry can be the last ingredient of something. Unlock the
	# ledger quietly -- the celebration card belongs to the garden screen,
	# and this screen is the bear's own moment.
	preload("res://scripts/garden/recipe_manager.gd").check_barn()
	SaveManager.save_game()

	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	# The strawberry flies to HIS basket; the star goes out; the bed starts
	# growing the next one.
	if _star != null and is_instance_valid(_star):
		_star.queue_free()
		_star = null
	var art := UiKit.picture("strawberry", 56.0)
	if art != null:
		art.position = _bed_centre(index) - Vector2(28, 28)
		add_child(art)
		if Juice.motion_enabled():
			var t := art.create_tween()
			t.tween_property(art, "position", _basket_at - Vector2(28, 28), 0.5)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(art.queue_free)
		else:
			art.queue_free()
	_plots = NpcFarm.bear_beds(now)
	(_bed_views[index] as Node2D).call("refresh", _plots[index], true)
	_fly_3d_strawberry(_bed_centre(index))

	AudioManager.say("bear_thirsty")
	_point_at_thirsty()


## 悄悄摘一颗。The bed with ripe strawberries and NO star: taking one is
## allowed, quiet, and unremarked -- no sound of celebration, no voice line,
## the bear does not turn around. The answer comes later, on his next visit,
## as one extra strawberry and one amber line ("小熊什么都没说，悄悄多分了
## 你一颗草莓"). Once per growth cycle, same clock as the share; written
## down first, like every pick, so a tablet closed mid-flight still knows.
func _sneak_the_quiet_one(index: int) -> void:
	var now := GameClock.now_unix()
	if not NpcFarm.can_sneak(now):
		# Still growing back: the bed shrugs, same as any bed of the bear's.
		Juice.nudge(_bed_views[index], 8.0)
		return
	NpcFarm.record_sneak(now)
	var farm_def: Dictionary = GameData.get_npc_farm("bear")
	Barn.store_harvest(str(farm_def.get("share_crop", "strawberry")), 1)
	preload("res://scripts/garden/recipe_manager.gd").check_barn()
	SaveManager.save_game()

	# A rustle, not a fanfare. The berry flies to his basket like the shared
	# one -- what a child DID is never hidden from him -- but nobody says a
	# word, which is the whole texture of the moment.
	AudioManager.play_sfx("res://assets/audio/rustle.ogg")
	var art := UiKit.picture("strawberry", 56.0)
	if art != null:
		art.position = _bed_centre(index) - Vector2(28, 28)
		add_child(art)
		if Juice.motion_enabled():
			var t := art.create_tween()
			t.tween_property(art, "position", _basket_at - Vector2(28, 28), 0.5)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(art.queue_free)
		else:
			art.queue_free()
	_plots = NpcFarm.bear_beds(now)
	(_bed_views[index] as Node2D).call("refresh", _plots[index], true)
	_fly_3d_strawberry(_bed_centre(index))


func _fly_3d_strawberry(from_screen: Vector2) -> void:
	if _meadow_3d_world == null or _meadow_3d_cam == null:
		return
	var sb_path := "res://assets/harvest_3d/runtime_candidates/crops/strawberry.glb"
	if not ResourceLoader.exists(sb_path):
		return
	var sb_scene: PackedScene = load(sb_path)
	if sb_scene == null:
		return
	var sb_inst: Node3D = sb_scene.instantiate() as Node3D
	if sb_inst == null:
		return
	_meadow_3d_world.add_child(sb_inst)
	var start_p := _screen_to_ground_3d(from_screen, 0.28)
	var end_p := _screen_to_ground_3d(_basket_at, 0.36)
	var mid_p := (start_p + end_p) * 0.5 + Vector3(0.0, 2.4, 0.0)
	sb_inst.position = start_p
	sb_inst.scale = Vector3(1.35, 1.35, 1.35)
	var tw := sb_inst.create_tween()
	tw.tween_property(sb_inst, "position", mid_p, 0.24).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(sb_inst, "position", end_p, 0.24).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sb_inst, "rotation_degrees:y", 360.0, 0.48)
	tw.parallel().tween_property(sb_inst, "scale", Vector3(0.4, 0.4, 0.4), 0.48)
	tw.tween_callback(func():
		if is_instance_valid(sb_inst):
			sb_inst.queue_free()
		if _basket_3d != null and is_instance_valid(_basket_3d):
			var bt := _basket_3d.create_tween()
			var base_s := Vector3(1.35, 1.35, 1.35)
			bt.tween_property(_basket_3d, "scale", Vector3(base_s.x * 1.2, base_s.y * 0.8, base_s.z * 1.2), 0.08)
			bt.tween_property(_basket_3d, "scale", base_s, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func _water_for_the_bear(index: int) -> void:
	if _watered_this_visit:
		return
	_watered_this_visit = true
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	# The bed drinks, on screen, this visit.
	var plot: Dictionary = _plots[index]
	plot["care_event"] = ""
	plot["water_level"] = 1.0
	plot["state"] = Farm.GROWING
	_plots[index] = plot
	(_bed_views[index] as Node2D).call("refresh", plot, true)

	if NpcFarm.record_help():
		# The whole exchange, written on the board at home: went visiting,
		# brought back the shared one, earned the star. Same board the bear's
		# own visits go on, so "who has been kind lately" is one place --
		# and the entry is a GUEST entry, telling the story from this side.
		var farm: Dictionary = SaveManager.data["farm"]
		Farm.remember_visit(farm, {"who": "bear", "kind": "guest",
			"shared": 1, "star": 1, "at": GameClock.now_unix()})
		# Helping a friend grows the farm too -- inside the help_owed gate,
		# so it pays exactly as many times as the kindness happened.
		Level.award("help")
		SaveManager.save_game()
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		AudioManager.say("bear_thanks")
		if Juice.motion_enabled():
			Juice.burst(self, _bed_centre(index), 16)


func _point_at_thirsty() -> void:
	for i in range(_plots.size()):
		if bool(_plots[i].get("help_target", false)):
			var hand := Tutorial.new()
			add_child(hand)
			hand.add_step(_bed_centre(i), _bed_centre(i), 1.3)
			hand.play()
			return


func _process(delta: float) -> void:
	_t += delta
	if _star != null and is_instance_valid(_star) and Juice.motion_enabled():
		_star.rotation = sin(_t * 1.4) * 0.4
		_star.position.y += sin(_t * 2.2) * 0.08
