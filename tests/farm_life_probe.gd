extends Node
## Run through tests/qa_run.py: real mouse/touch input in an isolated project.
## Greeting is deliberately visual. It must not create a reward or a save fact.

const Art := preload("res://scripts/harvest/harvest_visual_art.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const World := preload("res://scripts/garden/farm_world_controller.gd")
const DogSprite := preload("res://scripts/garden/farm_dog_sprite.gd")
const Lifecycle := preload("res://tests/probe_lifecycle.gd")
const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]
const CHECKS_EXPECTED := 60

var _failures: Array[String] = []
var _asked := 0
var _shape := "portraits"
var _world: Node2D
var _life: Node
var _plot_hits: Array[int] = []
var _facility_hits: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _ready() -> void:
	print("=== farm life probe: portraits ===")
	var original: Dictionary = SaveManager.data.duplicate(true)
	_portraits_fill_their_boxes()
	for shape in SHAPES:
		await _run_shape(shape)
	SaveManager.data = original
	GameClock.clear_test_now()
	_ok(_asked >= CHECKS_EXPECTED, "all portrait, reaction and input sections ran")
	for failure in _failures:
		print("FAIL ", failure)
	print("asked %d questions" % _asked)
	print("FARM LIFE PROBE %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	await Lifecycle.finish(self, 0 if _failures.is_empty() else 1)


func _portraits_fill_their_boxes() -> void:
	for side in [44.0, 72.0]:
		var badge := Art.prop_badge("rabbit", side, "RabbitPortrait")
		_ok(badge != null, "rabbit portrait resolves at %d pixels" % int(side))
		if badge == null:
			continue
		_ok(badge.size == Vector2.ONE * side, "portrait keeps the requested UI box")
		_ok(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "portrait is passive")
		var sprite := badge.get_child(0) as Sprite2D
		_ok(sprite != null and sprite.texture != null and sprite.region_rect.has_area(),
			"portrait contains the actual rabbit picture")
		_ok(is_equal_approx(maxf(sprite.region_rect.size.x, sprite.region_rect.size.y)
			* sprite.scale.x, side), "visible silhouette fills the badge")
		badge.free()
	var crop := Art.crop_badge("carrot", 44.0)
	_ok(crop != null and crop.size == Vector2(44, 44), "existing crop badge still resolves")
	if crop != null:
		crop.free()
	_ok(Art.prop_badge("missing_friend", 44.0) == null, "unknown portrait has no phantom image")


func _run_shape(shape: Vector2i) -> void:
	_shape = "%dx%d" % [shape.x, shape.y]
	print("-- FarmLife ", _shape, " build world")
	get_window().size = shape
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.data["farm"] = Farm.default_farm()
	SaveManager.data["settings"]["reduce_motion"] = false
	GameClock.set_test_now(1_699_963_200, 0)
	var farm: Dictionary = SaveManager.data["farm"]
	farm["tutorial_completed"] = true
	farm["farm_xp"] = 200
	_world = World.new()
	add_child(_world)
	_world.call("build", get_viewport().get_visible_rect().size, 64.0, 150.0, farm["plots"])
	await get_tree().process_frame
	await get_tree().process_frame
	_life = _find(_world, "SceneryLife")
	_ok(_life != null, "the existing scenery controller owns the friend")
	if _life == null:
		_world.queue_free()
		return
	_life.set_process(false)
	var rabbit := _entry("rabbit")
	_ok(not rabbit.is_empty(), "rabbit is actually placed, not skipped by target protection")
	if rabbit.is_empty():
		_world.queue_free()
		return
	var sprite: Control = rabbit["sprite"]
	_ok(sprite.mouse_filter == Control.MOUSE_FILTER_IGNORE, "world rabbit stays input-passive")
	_world.call("look_at_world", Vector2(1530, 600))
	await get_tree().process_frame
	var point := _friend_point(rabbit)
	_ok(_world.call("bed_under", point) == -1 and _world.call("facility_under", point) == ""
		and _world.call("expansion_under", point) == -1, "friend stands clear of gameplay hit regions")
	var cam: RefCounted = _world.get("camera")
	_ok(cam.call("inside", point), "friend can be reached inside the farm viewport")
	var before: Dictionary = SaveManager.data.duplicate(true)
	print("-- FarmLife ", _shape, " mouse greeting")
	await _press(point, false)
	_ok(_find(sprite, "FriendGreeting") != null, "a real mouse press gets a hello")
	_ok(SaveManager.data == before, "hello changes no save, stock, coins or friendship")
	for i in range(32):
		_world.call("press_at", point)
	_ok(_count(sprite, "FriendGreeting") == 1, "repeated presses keep one bounded reply")
	_life.call("_process", 0.18)
	_ok(not sprite.position.is_equal_approx(rabbit["base"]), "the moving version answers visibly")
	SaveManager.data["settings"]["reduce_motion"] = true
	_life.call("_process", 0.01)
	_ok(_at_rest(rabbit), "switching to reduced motion restores the grounded pose")
	var heart := _find(sprite, "FriendGreeting") as Control
	_ok(heart != null and heart.position == rabbit["greeting_base"] and heart.modulate.a == 1.0,
		"reduced motion keeps a readable stationary heart")
	_life.call("_process", 1.0)
	await get_tree().process_frame
	_ok(_count(sprite, "FriendGreeting") == 0, "the reply clears without leaving nodes")
	SaveManager.data["settings"]["reduce_motion"] = false
	print("-- FarmLife ", _shape, " touch greeting")
	await _press(_friend_point(rabbit), true)
	_ok(_count(sprite, "FriendGreeting") == 1, "a real touch press uses the same hello")
	await _capture("rabbit_greeting")
	_life.call("_process", 1.0)
	await get_tree().process_frame
	print("-- FarmLife ", _shape, " input priority / existing animals / dog")
	await _old_input_paths_keep_priority()
	_existing_animals_still_answer()
	await _dog_returns_to_ground()
	SaveManager.data["settings"]["reduce_motion"] = true
	print("-- FarmLife ", _shape, " reduced-motion greeting")
	_life.call("_process", 0.1)
	_ok(_all_at_rest(), "all registered scenery restores its pose in reduced motion")
	_world.call("look_at_world", Vector2(1530, 600))
	await get_tree().process_frame
	await _press(_friend_point(rabbit), true)
	_life.call("_process", 0.2)
	_ok(_count(sprite, "FriendGreeting") == 1, "a still-mode tap also has visible feedback")
	_ok(_at_rest(rabbit), "a still-mode hello never moves or scales the friend")
	await _capture("rabbit_reduce_motion")
	_life.call("_process", 1.0)
	await get_tree().process_frame
	_ok(_count(sprite, "FriendGreeting") == 0, "still-mode feedback has a bounded lifetime")
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("-- FarmLife ", _shape, " complete")


func _old_input_paths_keep_priority() -> void:
	_plot_hits.clear()
	_facility_hits.clear()
	_world.plot_pressed.connect(func(index: int): _plot_hits.append(index))
	_world.facility_pressed.connect(func(id: String): _facility_hits.append(id))
	_world.call("go_home")
	await get_tree().process_frame
	await _press(_world.call("bed_screen_position", 0), true)
	_ok(_plot_hits == [0], "touching a bed still belongs to the bed")
	_world.call("look_at_facility", "well")
	await get_tree().process_frame
	await _press(_world.call("facility_screen_position", "well"), false)
	_ok(_facility_hits == ["well"], "pressing a facility still belongs to the facility")


func _existing_animals_still_answer() -> void:
	for id in ["duck", "chicken"]:
		var life := _entry(id)
		_ok(not life.is_empty(), "existing %s is registered" % id)
		if life.is_empty():
			continue
		_life.call("poke_kind", id)
		_life.call("_process", 0.1)
		var sprite: Control = life["sprite"]
		var base: Vector2 = life["base"]
		_ok(sprite.position.y < base.y, "%s still hops after a greeting" % id)
		_ok(_find(sprite, "FriendGreeting") == null, "animal feedback does not become a friend reward")


func _dog_returns_to_ground() -> void:
	var pup := DogSprite.new()
	add_child(pup)
	pup.set_process(false)
	var art: Control = pup.get("_art")
	_ok(art != null, "the existing dog still has its studio picture")
	if art == null:
		pup.queue_free()
		return
	var rest := -art.size.y * Art.GROUND_ORIGIN_PIXEL_Y / Art.SOURCE_CANVAS_SIZE
	pup.set_pose(HeroArt.Pose.WALK)
	pup.call("_process", 0.05)
	_ok(art.position.y < rest and not is_zero_approx(art.rotation), "dog still trots")
	pup.set_pose(HeroArt.Pose.CHEER)
	pup.call("_process", 0.08)
	_ok(art.position.y < rest, "dog still cheers")
	SaveManager.data["settings"]["reduce_motion"] = true
	pup.call("_process", 0.01)
	_ok(is_equal_approx(art.position.y, rest) and is_zero_approx(art.rotation),
		"turning down motion cannot strand the dog mid-hop")
	pup.queue_free()
	await get_tree().process_frame


func _entry(id: String) -> Dictionary:
	for life: Dictionary in _life.get("_alive"):
		var sprite: Control = life["sprite"]
		if str(sprite.get_meta("prop_id", "")) == id:
			return life
	return {}


func _friend_point(life: Dictionary) -> Vector2:
	var sprite: Control = life["sprite"]
	var hit: Rect2 = life["hit"]
	return sprite.get_global_transform_with_canvas() * hit.get_center()


func _at_rest(life: Dictionary) -> bool:
	var sprite: Control = life["sprite"]
	return sprite.position.is_equal_approx(life["base"]) \
		and sprite.scale.is_equal_approx(life["base_scale"]) \
		and is_equal_approx(sprite.rotation, float(life["base_rotation"]))


func _all_at_rest() -> bool:
	for life: Dictionary in _life.get("_alive"):
		if not _at_rest(life):
			return false
	return true


func _press(at: Vector2, touch: bool) -> void:
	var view := get_viewport().get_visible_rect().size
	var glass := at * Vector2(get_window().size) / view
	for down in [true, false]:
		var event: InputEvent
		if touch:
			var finger := InputEventScreenTouch.new()
			finger.index = 0
			finger.pressed = down
			finger.position = glass
			event = finger
		else:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = down
			mouse.position = glass
			event = mouse
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		_ok(false, "FarmLifeProbe requires a rendered window")
		return
	# Match FarmShot's bounded capture path. frame_post_draw can stop arriving
	# for an occluded/static macOS window even while process_frame continues.
	print("-- FarmLife ", _shape, " capture ", label)
	for _frame in range(3):
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	_ok(Lifecycle.image_has_content(image), "%s has rendered content" % label)
	var folder := OS.get_environment("SHOT_DIR")
	if folder.is_empty():
		folder = "user://farm_life_probe"
	DirAccess.make_dir_recursive_absolute(folder)
	_ok(image.save_png(folder.path_join("%s_%s.png" % [label, _shape])) == OK,
		"%s screenshot saved" % label)
	print("-- FarmLife ", _shape, " captured ", label)


func _find(root: Node, node_name: String) -> Node:
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _count(root: Node, node_name: String) -> int:
	var count := 1 if str(root.name) == node_name else 0
	for child in root.get_children():
		count += _count(child, node_name)
	return count
