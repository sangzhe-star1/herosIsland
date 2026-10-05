extends Node
## Real-input coverage for the harvest levels that were missing focused paths.
## Run through qa_run.py so the save file and result-screen transitions stay isolated.

const Maturity := preload("res://scripts/harvest/maturity.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]
const HARVEST_SCENE := "res://scenes/minigames/harvest_action/HarvestAction.tscn"
const RESULT_SCENE := "res://scenes/ui/ResultScreen.tscn"

var _failures: Array[String] = []
var _asked := 0
var _level: Node = null
var _shape := ""
var _finished_levels: Array[LevelResult] = []
var _mouse_path := false
var _last_pointer_track := PackedVector2Array()


func _ready() -> void:
	# Keep this harness alive when a completed level opens the real result page.
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	GameManager.level_finished.connect(_on_level_finished)
	for window in SHAPES:
		_shape = "%dx%d" % [window.x, window.y]
		await _almost_ready_refusal(window)
		await _clear_case()
		await _corn_order(window)
		await _clear_case()
		await _peas_and_bugs(window)
		await _clear_case()
		await _grain_and_fruit_order(window)
		await _clear_case()
		await _golden_second_order(window)
		await _clear_case()
		await _friend_challenges(window)

	GameManager.level_finished.disconnect(_on_level_finished)
	for failure in _failures:
		print("FAIL ", failure)
	if _failures.is_empty():
		print("HARVEST COVERAGE PROBE PASSED checks=%d shapes=%d"
			% [_asked, SHAPES.size()])
	else:
		print("HARVEST COVERAGE PROBE FAILED checks=%d failures=%d"
			% [_asked, _failures.size()])
	await ProbeLifecycle.finish(self, 0 if _failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _open_case(level_id: String, window: Vector2i, difficulty: int = 1) -> void:
	get_window().size = window
	for _frame in range(2):
		await get_tree().process_frame
	# Every run must be invoked from qa_run.py, which redirects these paths to a
	# temporary user directory before this probe removes the isolated save.
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	SaveManager.set_setting("difficulty", difficulty)
	SaveManager.clear_harvest_checkpoint(level_id)
	GameManager.current_level_id = level_id
	var packed := load(HARVEST_SCENE) as PackedScene
	if packed == null:
		_check(false, "%s scene loads" % level_id)
		return
	_level = packed.instantiate()
	add_child(_level)
	for _frame in range(6):
		await get_tree().process_frame
	var level_data := _level.get("level_data") as Dictionary
	_check(str(level_data.get("id", "")) == level_id,
		"the real %s level is active" % level_id)


func _corn_order(window: Vector2i) -> void:
	await _open_case("harvest_03", window)
	if not _has_level():
		return
	_check((_level.get("_wanted") as Dictionary) == {"corn": 4},
		"h03 asks for four corn")
	_check((_level.get("_baskets") as Array).size() == 1,
		"h03 uses its real single-basket path")
	for index in range(4):
		var target := _available("corn", Maturity.READY)
		_check(target != null, "h03 exposes ready corn %d/4" % (index + 1))
		if target == null:
			return
		await _stroke(_gesture_points(target))
		_check(_in_hand() == null,
			"h03 corn %d completes its real drag-to-single-basket input" % (index + 1))
		if index < 3:
			_check(int((_level.get("_picked") as Dictionary).get("corn", 0))
				== index + 1, "h03 records corn progress after real input")
	_check(int((_level.get("_delivered") as Dictionary).get("corn", 0)) == 4,
		"h03 delivers the full corn order")
	await _wait_for_result("harvest_03")


func _almost_ready_refusal(window: Vector2i) -> void:
	await _open_case("harvest_02", window, 2)
	if not _has_level():
		return
	var target := _available("strawberry", Maturity.ALMOST, false)
	_check(target != null, "h02 includes an almost-ready strawberry for refusal input")
	if target == null:
		return
	var picked_before := _picked_total()
	var taken_before: bool = target.taken
	await _stroke(_gesture_points(target))
	_check(_in_hand() == null and _picked_total() == picked_before
		and target.taken == taken_before,
		"a real touch cannot pick an almost-ready h02 crop")


func _peas_and_bugs(window: Vector2i) -> void:
	await _open_case("harvest_06", window)
	if not _has_level():
		return
	_check((_level.get("_wanted") as Dictionary) == {"peas": 9},
		"h06 asks for nine peas")
	var bugs: Array[Node2D] = []
	for target: Node2D in _targets():
		if str(target.crop.get("id", "")) == "bug":
			bugs.append(target)
	_check(bugs.size() == 2, "h06 has both real bug clutter targets")
	for index in range(bugs.size()):
		var bug: Node2D = bugs[index]
		var before := int((_level.get("result") as LevelResult).correct)
		await _stroke(_gesture_points(bug))
		_check(not _targets().has(bug),
			"h06 bug %d moves aside through a real tap" % (index + 1))
		_check(_in_hand() == null and _picked_total() == 0
			and int((_level.get("result") as LevelResult).correct) == before,
			"h06 bug clutter never enters the hand, basket or score")
	_check((_level.get("_baskets") as Array).size() == 1,
		"h06 peas use the existing single-basket path")
	for index in range(3):
		var target := _available("peas", Maturity.READY)
		_check(target != null, "h06 exposes pea pod %d/3" % (index + 1))
		if target == null:
			return
		_check(int(target.crop.get("harvest_count", 1)) == 3,
			"each pea pod contributes its configured three peas")
		await _stroke(_gesture_points(target))
		_check(_in_hand() == null,
			"h06 pea pod %d reaches the real basket" % (index + 1))
		if index < 2:
			_check(int((_level.get("_picked") as Dictionary).get("peas", 0))
				== (index + 1) * 3, "h06 counts peas, not pod targets")
	_check(int((_level.get("_delivered") as Dictionary).get("peas", 0)) == 9,
		"h06 delivers its complete nine-pea order")
	await _wait_for_result("harvest_06")


func _grain_and_fruit_order(window: Vector2i) -> void:
	await _open_case("harvest_09", window)
	if not _has_level():
		return
	_check((_level.get("_wanted") as Dictionary)
		== {"broccoli": 3, "grape": 2, "wheat": 2},
		"h09 starts its real broccoli/grape/wheat order")
	_check((_level.get("_baskets") as Array).size() == 2,
		"h09 presents exactly the vegetable-grain and fruit baskets")
	var deliveries: Array[Dictionary] = [
		{"crop": "broccoli", "basket": "veg"},
		{"crop": "broccoli", "basket": "veg"},
		{"crop": "broccoli", "basket": "veg"},
		{"crop": "grape", "basket": "fruit"},
		{"crop": "grape", "basket": "fruit"},
		{"crop": "wheat", "basket": "veg"},
		{"crop": "wheat", "basket": "veg"},
	]
	for index in range(deliveries.size()):
		var spec: Dictionary = deliveries[index]
		var target := _available(str(spec["crop"]), Maturity.READY)
		_check(target != null, "h09 exposes %s %d" % [spec["crop"], index + 1])
		if target == null:
			return
		await _pick_and_deliver(target, str(spec["basket"]), "h09",
			index == 0)
	_check(int((_level.get("_delivered") as Dictionary).get("broccoli", 0)) == 3
		and int((_level.get("_delivered") as Dictionary).get("grape", 0)) == 2
		and int((_level.get("_delivered") as Dictionary).get("wheat", 0)) == 2,
		"h09 lands the full grain/fruit two-basket order")
	await _wait_for_result("harvest_09")


func _golden_second_order(window: Vector2i) -> void:
	await _open_case("harvest_10", window)
	if not _has_level():
		return
	_check((_level.get("_orders") as Array).size() == 2,
		"h10 contains its two real orders")
	_check((_level.get("_wanted") as Dictionary)
		== {"carrot": 3, "tomato": 2}, "h10 opens on carrot and tomato")
	var golden := _available("golden_carrot", Maturity.GOLDEN, false)
	_check(golden != null and not golden.visible,
		"h10 golden carrot waits hidden until its later order")
	if golden != null:
		await _stroke([golden.global_position, golden.global_position])
		_check(not golden.taken and _picked_total() == 0,
			"a real touch cannot consume h10's future golden carrot")
	for index in range(3):
		var carrot := _available("carrot", Maturity.READY)
		_check(carrot != null, "h10 exposes first-order carrot %d/3" % (index + 1))
		if carrot == null:
			return
		await _pick_and_deliver(carrot, "veg", "h10 first order")
	for index in range(2):
		var tomato := _available("tomato", Maturity.READY)
		_check(tomato != null, "h10 exposes first-order tomato %d/2" % (index + 1))
		if tomato == null:
			return
		await _pick_and_deliver(tomato, "veg", "h10 first order")
	_check(int(_level.get("_order_index")) == 1,
		"real delivery advances h10 from order one to order two")
	_check(int((_level.get("_delivered") as Dictionary).get("carrot", 0)) == 3
		and int((_level.get("_delivered") as Dictionary).get("tomato", 0)) == 2,
		"h10 checkpoints the first order before revealing the next")
	_check(golden != null and golden.visible
		and bool(_level.call("_target_is_available_now", golden)),
		"the same golden carrot becomes touchable in order two")
	if golden == null or not golden.visible:
		return
	await _pick_and_deliver(golden, "gift", "h10 golden order")
	_check(int((_level.get("_picked") as Dictionary).get("golden_carrot", 0)) == 1
		and int(_level.get("_order_index")) == 1,
		"the golden carrot lands in gift while strawberries remain for order two")
	for index in range(3):
		var strawberry := _available("strawberry", Maturity.READY)
		_check(strawberry != null, "h10 exposes second-order strawberry %d/3" % (index + 1))
		if strawberry == null:
			return
		await _pick_and_deliver(strawberry, "fruit", "h10 second order")
	_check(int((_level.get("_delivered") as Dictionary).get("golden_carrot", 0)) == 1
		and int((_level.get("_delivered") as Dictionary).get("strawberry", 0)) == 3,
		"h10 completes both second-order crop types")
	await _wait_for_result("harvest_10")


## The new errands are completed through gestures, basket taps and the real
## result page. 16:9 uses touch, 4:3 mouse; the shared gameplay must accept both.
## Expected deliveries describe the level's promise independently of its JSON.
func _friend_challenges(window: Vector2i) -> void:
	_mouse_path = window.x == 1024
	var cases := [
		{"id": "harvest_11", "orders": [{"lettuce": 2, "carrot": 2, "tomato": 2}]},
		{"id": "harvest_12", "orders": [{"orange": 2, "apple": 2, "grape": 2}]},
		{"id": "harvest_13", "orders": [{"potato": 3}, {"carrot": 2}]},
		{"id": "harvest_14", "orders": [{"peas": 6, "corn": 2}, {"pumpkin": 1, "watermelon": 1}]},
		{"id": "harvest_15", "orders": [{"wheat": 3, "apple": 2}, {"corn": 2, "strawberry": 2}]},
		{"id": "harvest_16", "orders": [{"lettuce": 2, "tomato": 2}, {"carrot": 2, "strawberry": 2}, {"wheat": 2, "grape": 2}]},
		{"id": "harvest_13", "tier": 2, "orders": [{"potato": 3}, {"carrot": 2, "golden_carrot": 1}]},
		{"id": "harvest_16", "tier": 2, "orders": [{"lettuce": 2, "tomato": 2}, {"carrot": 2, "strawberry": 2}, {"wheat": 2, "grape": 2, "golden_carrot": 1}]},
	]
	for scenario in cases:
		await _complete_friend_challenge(scenario, window)
		await _clear_case()
	_mouse_path = false


func _complete_friend_challenge(scenario: Dictionary, window: Vector2i) -> void:
	var level_id := str(scenario["id"])
	var tier := int(scenario.get("tier", 1))
	var expected_orders: Array = scenario["orders"]
	await _open_case(level_id, window, tier)
	if not _has_level():
		return
	var farm_before: Dictionary = SaveManager.data.get("farm", {}).duplicate(true)
	var daily_before: Dictionary = SaveManager.data.get("farm_orders", {}).duplicate(true)
	var slot := _level.get("_order_customer") as Control
	_check(slot != null and slot.visible, "%s shows the friend who requested this order" % level_id)
	var expected_delivered: Dictionary = {}
	for order_index in range(expected_orders.size()):
		var expected: Dictionary = expected_orders[order_index]
		var context := "%s tier %d order %d" % [level_id, tier, order_index]
		_check(int(_level.get("_order_index")) == order_index
			and (_level.get("_wanted") as Dictionary) == expected,
			context + " reaches the promised delivery")
		_check(_level.get("_order_customer") == slot,
			context + " keeps the same customer slot as the order changes")
		if level_id == "harvest_16" and slot != null:
			var portraits := ["res://assets/harvest_3d/props/rabbit.png", "paw", "teddy"]
			_check(str(slot.get_meta("customer_reference", "")) == portraits[order_index]
				and slot.get_node_or_null("CustomerPortrait") != null,
				context + " changes to the next friend's visible portrait")
		# A gesture at a future-only crop must not consume it or satisfy this
		# order. Check each order, since a later delivery must stay equally safe.
		var future: Node2D
		for candidate: Node2D in _targets():
			if not candidate.taken and not candidate.visible \
					and not expected.has(str(candidate.crop.get("id", ""))) \
					and candidate.step in [Maturity.READY, Maturity.GOLDEN]:
				future = candidate
				break
		if future != null:
			var picked_before: Dictionary = (_level.get("_picked") as Dictionary).duplicate(true)
			await _stroke(_gesture_points(future))
			_check(not future.taken and (_level.get("_picked") as Dictionary) == picked_before
				and _in_hand() == null, context + " cannot pick a future delivery early")
		if level_id == "harvest_11":
			var almost := _available("lettuce", Maturity.ALMOST, false)
			_check(almost != null, context + " includes young lettuce to distinguish")
			if almost != null:
				await _stroke(_gesture_points(almost))
				_check(not almost.taken and _in_hand() == null,
					context + " leaves young lettuce growing after a real cut")
		for crop_id in expected:
			var delivered_count := 0
			while delivered_count < int(expected[crop_id]):
				var target := _available(str(crop_id))
				_check(target != null, context + " exposes a fresh " + str(crop_id))
				if target == null:
					return
				var yield_count := int(target.crop.get("harvest_count", 1))
				var basket := _level.call("_destination_for", target) as Node2D
				_check(basket != null, context + " has a destination for " + str(crop_id))
				if basket == null:
					return
				if (_level.get("_baskets") as Array).size() == 1:
					await _stroke(_gesture_points(target))
					_check(target.taken and _in_hand() == null,
						context + " completes the single-basket gesture")
				else:
					await _pick_and_deliver(target, str(basket.id), context,
						str(crop_id) == "golden_carrot")
				delivered_count += yield_count
				expected_delivered[crop_id] = int(expected_delivered.get(crop_id, 0)) + yield_count
		_check((_level.get("_delivered") as Dictionary) == expected_delivered,
			context + " records whole harvests exactly once across completed orders")
		if order_index < expected_orders.size() - 1:
			var mark := SaveManager.get_harvest_checkpoint()
			_check(str(mark.get("level_id", "")) == level_id
				and int(mark.get("order_index", -1)) == order_index + 1
				and mark.get("delivered", {}) == expected_delivered,
				context + " checkpoints delivery before the next friend arrives")
	_check(SaveManager.data.get("farm", {}) == farm_before
		and SaveManager.data.get("farm_orders", {}) == daily_before,
		level_id + " leaves the real garden, barn and daily orders untouched")
	await _wait_for_result(level_id)


func _pick_and_deliver(target: Node2D, basket_id: String, context: String,
		try_wrong_basket: bool = false) -> void:
	var destination := _level.call("_destination_for", target) as Node2D
	_check(destination != null and destination.id == basket_id,
		"%s resolves %s to %s" % [context, str(target.crop.get("id", "?")), basket_id])
	if destination == null:
		return
	var accepting_baskets := 0
	for basket: Node2D in _level.get("_baskets"):
		if bool(_level.call("_basket_accepts", target, basket)):
			accepting_baskets += 1
	_check(accepting_baskets == 1,
		"%s has exactly one accepted basket" % context)
	await _stroke(_gesture_points(target))
	_check(_in_hand() == target,
		"%s reaches the hand through the crop's real gesture" % context)
	if _in_hand() != target:
		print("gesture failure context=%s crop=%s recogniser=%s mouse=%s params=%s track=%s"
			% [context, str(target.crop.get("id", "")), str(target.crop.get("recogniser", "")),
				str(_mouse_path), str(target.crop.get("gesture_params", {})), str(_last_pointer_track)])
		return
	if try_wrong_basket:
		var wrong_basket: Node2D
		for basket: Node2D in _level.get("_baskets"):
			if basket.id != basket_id:
				wrong_basket = basket
				break
		_check(wrong_basket != null, "%s has a distinct wrong basket for feedback" % context)
		if wrong_basket != null:
			var delivered_before: Dictionary = (_level.get("_delivered") as Dictionary).duplicate(true)
			await _stroke([wrong_basket.global_position, wrong_basket.global_position])
			_check(_in_hand() == target
				and (_level.get("_delivered") as Dictionary) == delivered_before,
				"%s wrong-basket touch leaves the crop safely in hand" % context)
	_check(_level.call("_basket_for", destination.global_position) == destination,
		"%s basket is selected by its real hit test" % context)
	await _stroke([destination.global_position, destination.global_position])
	_check(_in_hand() == null,
		"%s basket tap delivers the crop exactly once" % context)


func _gesture_points(target: Node2D) -> Array:
	return Array(Gesture.demo_path(str(target.crop.get("recogniser", "")),
		target.crop.get("gesture_params", {}), target.global_position,
		float(target.get("radius"))))


func _available(crop_id: String, maturity: String = "", require_available: bool = true) -> Node2D:
	for target: Node2D in _targets():
		if not is_instance_valid(target) or target.taken:
			continue
		if str(target.crop.get("id", "")) != crop_id:
			continue
		if maturity != "" and str(target.step) != maturity:
			continue
		if require_available and (not target.visible
				or not bool(_level.call("_target_is_available_now", target))):
			continue
		return target
	return null


func _targets() -> Array:
	return _level.get("_targets") as Array


func _picked_total() -> int:
	var total := 0
	for value in (_level.get("_picked") as Dictionary).values():
		total += int(value)
	return total


func _in_hand() -> Node2D:
	var held = _level.get("_in_hand")
	return held if held != null and is_instance_valid(held) else null


func _stroke(points: Array) -> void:
	if points.is_empty():
		_check(false, "real touch path is not empty")
		return
	if _mouse_path:
		await _mouse_stroke(points)
		return
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(points[0])
	Input.parse_input_event(down)
	await get_tree().process_frame
	var last: Vector2 = points[0]
	for index in range(1, points.size()):
		var point: Vector2 = points[index]
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _glass(point)
		drag.relative = _glass(point) - _glass(last)
		last = point
		Input.parse_input_event(drag)
		await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(points[points.size() - 1])
	Input.parse_input_event(up)
	for _frame in range(5):
		await get_tree().process_frame


func _mouse_stroke(points: Array) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = _glass(points[0])
	down.global_position = down.position
	Input.parse_input_event(down)
	await get_tree().process_frame
	var last: Vector2 = points[0]
	for index in range(1, points.size()):
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = _glass(points[index])
		motion.global_position = motion.position
		motion.relative = motion.position - _glass(last)
		last = points[index]
		Input.parse_input_event(motion)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = _glass(points[points.size() - 1])
	up.global_position = up.position
	_last_pointer_track = _level.get("_track")
	Input.parse_input_event(up)
	for _frame in range(5):
		await get_tree().process_frame


func _glass(at: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	return Vector2(at.x * window_size.x / viewport_size.x,
		at.y * window_size.y / viewport_size.y)


func _has_level() -> bool:
	return is_instance_valid(_level)


func _wait_for_result(level_id: String) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		var signalled := false
		for result: LevelResult in _finished_levels:
			if result.level_id == level_id:
				signalled = true
		var scene := get_tree().current_scene
		if signalled and scene != null and str(scene.scene_file_path) == RESULT_SCENE \
				and not bool(SceneManager.get("_busy")):
			_check(true, "%s completes through the real result path" % level_id)
			return
		await get_tree().process_frame
	_check(false, "%s did not reach the real result page" % level_id)


func _clear_case() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
	_level = null
	var scene := get_tree().current_scene
	if scene != null and scene != self:
		get_tree().current_scene = null
		scene.queue_free()
	for _frame in range(4):
		await get_tree().process_frame


func _on_level_finished(result: LevelResult) -> void:
	_finished_levels.append(result)
