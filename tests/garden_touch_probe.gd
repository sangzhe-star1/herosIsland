extends Node
## 星光菜园, with thumbs. Everything here is driven through the real input
## pipeline in both screen shapes, because the two ways this screen can be
## broken -- a seed that lands in the wrong bed, and a garden that works on a
## Mac and not on an iPad -- are both invisible from the code.
##
## The iPad shape is not optional. The island stretches with aspect=expand, so
## a 4:3 tablet hands the garden a 1280x960 viewport while its window is
## 1024x768: a probe that pushes design coordinates straight in aims at the
## wrong place, and "the drag missed" and "the drag is broken" look identical.
## Everything below goes through _glass().

const Growth := preload("res://scripts/garden/offline_growth.gd")

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]
const NOON := 1_699_963_200

var _failures: Array[String] = []
var _garden: Node = null
var _shape := ""


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _ready() -> void:
	print("\n=== garden touch probe ===")
	for shape in SHAPES:
		_shape = "%dx%d" % [shape.x, shape.y]
		await _run_on_a(shape)

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("GARDEN TOUCH PROBE %s\n"
		% ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run_on_a(window: Vector2i) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Vector2 = get_viewport().get_visible_rect().size
	print("-- window %s -> viewport %s" % [str(window), str(view)])

	_fresh_garden()
	_open()
	await get_tree().process_frame
	await get_tree().process_frame

	await _the_beds_are_on_the_screen_he_is_holding(view)
	await _tapping_grass_turns_it_over()
	await _dragging_a_seed_lands_in_the_bed_he_aimed_at()
	await _one_bed_takes_one_crop()
	await _tapping_a_ripe_bed_fills_the_barn()
	await _there_is_a_way_out()

	_close()


func _fresh_garden() -> void:
	GameClock.set_test_now(NOON, 0)
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	SaveManager.data["farm"]["last_seen_at"] = NOON


func _open() -> void:
	GameManager.current_level_id = "star_garden"
	_garden = load("res://scenes/garden/Garden.tscn").instantiate()
	add_child(_garden)


func _close() -> void:
	if is_instance_valid(_garden):
		_garden.queue_free()
	_garden = null
	GameClock.clear_test_now()


func _plots() -> Array:
	return SaveManager.data["farm"]["plots"]


func _bed(index: int) -> Vector2:
	return _garden.call("_bed_centre", index)


func _glass(at: Vector2) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(get_window().size)
	return Vector2(at.x * win.x / view.x, at.y * win.y / view.y)


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = _glass(at)
		Input.parse_input_event(touch)
		await get_tree().process_frame
	# The screen rebuilds itself one frame after an action.
	await get_tree().process_frame
	await get_tree().process_frame


func _finger(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(from)
	Input.parse_input_event(down)
	await get_tree().process_frame

	var last := from
	for step in range(1, 8):
		var at: Vector2 = from.lerp(to, float(step) / 7.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _glass(at)
		drag.relative = _glass(at) - _glass(last)
		last = at
		Input.parse_input_event(drag)
		await get_tree().process_frame

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(to)
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


## Nothing he has to reach for is off the glass, and the beds are far enough
## apart that a seed cannot click into the wrong one.
func _the_beds_are_on_the_screen_he_is_holding(view: Vector2) -> void:
	for i in range(4):
		var at := _bed(i)
		_ok(at.x > 60.0 and at.x < view.x - 60.0,
			"bed %d is on the screen horizontally" % i)
		_ok(at.y > 96.0 and at.y < view.y - 168.0,
			"bed %d sits between the top bar and the seed rack" % i)

	# The rule that makes a mis-drop impossible: DragField clicks a released
	# piece into any slot within 118px, so two beds closer than 236px apart
	# would let a seed aimed at one land in the other.
	for a in range(4):
		for b in range(a + 1, 4):
			_ok(_bed(a).distance_to(_bed(b)) > 236.0,
				"beds %d and %d are further apart than the snap radius" % [a, b])
	await get_tree().process_frame


func _tapping_grass_turns_it_over() -> void:
	_ok(not bool(_plots()[0].get("tilled", true)), "bed 0 starts as grass")
	await _tap(_bed(0))
	_ok(bool(_plots()[0].get("tilled", false)),
		"one tap on grass turns it into earth -- no tool to pick first")
	# ...and the OTHER beds are untouched. One tap, one bed.
	_ok(not bool(_plots()[1].get("tilled", true)),
		"and only the bed he tapped")


func _dragging_a_seed_lands_in_the_bed_he_aimed_at() -> void:
	# Bed 0 is turned and empty. Aim a carrot at it from the rack, deliberately
	# releasing 40px off centre -- a thumb is not a cursor.
	var rack := _seed_tile(0)
	_ok(rack != Vector2.ZERO, "the seed rack has something in it")
	await _finger(rack, _bed(0) + Vector2(40, -34))

	_ok(str(_plots()[0].get("crop_id", "")) == "carrot",
		"a seed released near a bed is planted in it, not dropped on the floor")
	_ok(int(_plots()[0].get("planted_at", 0)) == NOON,
		"and it is planted at the time it was planted")
	for other in [1, 2, 3]:
		_ok(str(_plots()[other].get("crop_id", "")) == "",
			"bed %d did not catch a seed aimed at bed 0" % other)


## Acceptance #4. A bed holds one crop; a second seed is refused, and refused
## quietly -- nothing is lost and nothing is said.
func _one_bed_takes_one_crop() -> void:
	var before := str(_plots()[0].get("crop_id", ""))
	var planted_at := int(_plots()[0].get("planted_at", 0))
	var rack := _seed_tile(1)                   # a different crop
	await _finger(rack, _bed(0))
	_ok(str(_plots()[0].get("crop_id", "")) == before,
		"a second seed cannot be planted on top of the first")
	_ok(int(_plots()[0].get("planted_at", 0)) == planted_at,
		"and the first one's clock did not restart")


## Acceptance #10, the tap half. A ripe bed picked once fills the barn once,
## and goes back to bare earth -- which is what stops one planting ever paying
## out twice.
func _tapping_a_ripe_bed_fills_the_barn() -> void:
	var plots := _plots()
	plots[3]["tilled"] = true
	plots[3]["crop_id"] = "strawberry"
	plots[3]["growth_stage"] = 4
	plots[3]["ready_to_harvest"] = true
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame

	var expected := int(GameData.get_crop("strawberry").get("yield", 0))
	await _tap(_bed(3))
	var barn: Dictionary = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("strawberry", 0)) == expected,
		"picking a ripe bed puts exactly its yield in the barn")
	_ok(str(_plots()[3].get("crop_id", "")) == "",
		"and leaves bare earth behind")
	_ok(bool(_plots()[3].get("tilled", false)),
		"still turned over, so the next seed can go straight in")
	_ok(not bool(_plots()[3].get("ready_to_harvest", true)),
		"and nothing left to pick")

	# Tapping the empty bed again must not pay a second time.
	await _tap(_bed(3))
	barn = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("strawberry", 0)) == expected,
		"tapping the same bed again pays nothing -- one planting, one harvest")


## Acceptance #16. A child who wants out has to be able to get out.
func _there_is_a_way_out() -> void:
	var back := _find_back_button(_garden)
	_ok(back != null, "there is a way out of the garden")
	if back == null:
		return
	_ok(back.visible and back.size.x > 60.0 and back.size.y > 60.0,
		"...and it is big enough for a thumb")
	var view: Vector2 = get_viewport().get_visible_rect().size
	_ok(back.global_position.x >= 0.0 and back.global_position.y >= 0.0
			and back.global_position.x + back.size.x < view.x
			and back.global_position.y + back.size.y < view.y,
		"...and it is on the screen he is holding")
	await get_tree().process_frame


func _seed_tile(index: int) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	# Mirrors _seed_rack's layout: first tile at x = 90, then tile + 26 apart.
	return Vector2(90.0 + float(index) * 130.0, view.y - 84.0)


func _find_back_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and str(child.text) == "<":
			return child
		var found := _find_back_button(child)
		if found != null:
			return found
	return null
