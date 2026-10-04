extends "res://tests/harvest_touch_probe.gd"
## Complete the real three-order celebration, including its result/save path.
## Run only through QASession: inherited _open() resets the isolated save.

const COMPLETION_LEVEL := "harvest_08"
const COMPLETION_RESULT_SCENE := "res://scenes/ui/ResultScreen.tscn"
const COMPLETION_NOW := 1_700_000_000
const COMPLETION_DELIVERIES := 17 # brave: 16 ordinary targets + one golden
const COMPLETION_CASES := 4

var _completion_local: Array[LevelResult] = []
var _completion_global: Array[LevelResult] = []
var _completion_case_count := 0
var _completion_order_count := 0
var _completion_delivery_count := 0


func _ready() -> void:
	# Keep the QA driver alive while the actual GameManager opens ResultScreen.
	# The harvested level remains our child and is explicitly released below.
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	GameManager.level_finished.connect(_completion_finished)
	for window in SHAPES:
		for low_motion in [false, true]:
			_shape = "%dx%d/%s" % [window.x, window.y,
				"still" if low_motion else "normal"]
			await _completion_case(window, low_motion)
			await _completion_cleanup()
			GameClock.clear_test_now()
	_ok(_completion_case_count == COMPLETION_CASES,
		"all four ratio/motion cases reach the real result screen")
	_ok(_completion_order_count == COMPLETION_CASES * 3,
		"all twelve orders advance through real deliveries")
	_ok(_completion_delivery_count == COMPLETION_CASES * COMPLETION_DELIVERIES,
		"all 68 expected target deliveries ran, including four golden carrots")
	_ok(_asked >= 300, "completion probe cannot pass after skipping its checks")
	GameManager.level_finished.disconnect(_completion_finished)
	for failure in _failures:
		print("FAIL ", failure)
	print("completion cases=%d orders=%d deliveries=%d checks=%d"
		% [_completion_case_count, _completion_order_count,
			_completion_delivery_count, _asked])
	print("HARVEST COMPLETION PROBE %s"
		% ("PASSED" if _failures.is_empty() else "FAILED"))
	await ProbeLifecycle.finish(self, 0 if _failures.is_empty() else 1)


func _completion_case(window: Vector2i, low_motion: bool) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	_completion_local.clear()
	_completion_global.clear()
	GameClock.set_test_now(COMPLETION_NOW, 0)
	await _open_with_settings(COMPLETION_LEVEL,
		{"difficulty": 2, "reduce_motion": low_motion})
	_level.connect("level_completed", _completion_reported)
	var orders: Array = (_level.get("_orders") as Array).duplicate(true)
	_ok(orders.size() == 3, "the celebration has exactly three real orders")
	if orders.size() != 3:
		return
	var garden_before := _completion_seed_garden()
	var coins_before := int(SaveManager.data["rewards"].get("coins", 0))
	var xp_before := int(SaveManager.data["profile"].get("xp", 0))
	var expected: Dictionary = {}
	var deliveries := 0
	for order_index in range(orders.size()):
		_ok(int(_level.get("_order_index")) == order_index,
			"order %d starts only after its predecessor lands" % (order_index + 1))
		var wanted: Dictionary = _level.call("_requirements_for_order", orders[order_index])
		for crop_id in wanted:
			expected[crop_id] = int(expected.get(crop_id, 0)) + int(wanted[crop_id])
		while int(_level.get("_order_index")) == order_index:
			# Both a hard ceiling and a progress assertion prevent a stuck loop.
			if deliveries >= COMPLETION_DELIVERIES:
				_ok(false, "an order is stuck after all expected deliveries")
				return
			var target := _completion_available_target()
			_ok(target != null, "the current order has an available pickable target")
			if target == null:
				return
			var crop_id := str(target.crop.get("id", ""))
			var before := int((_level.get("result") as LevelResult).correct)
			await _stroke(_move_for(target))
			var held := _in_hand()
			_ok(held == target, "%s reaches the hand through its real gesture" % crop_id)
			if held == null or held != target:
				return
			var destination: Node2D = _level.call("_destination_for", held)
			var homes := 0
			for basket in _baskets():
				if bool(_level.call("_basket_accepts", held, basket)):
					homes += 1
			_ok(destination != null and homes == 1,
				"%s has one home through the existing sorting resolver" % crop_id)
			if destination == null or homes != 1:
				return
			_ok(_level.call("_basket_for", destination.global_position) == destination,
				"the destination basket is selectable through the real hit test")
			if crop_id == "golden_carrot":
				_ok(str(destination.id) == "gift" and order_index == 2,
					"the final order sends its golden carrot to the gift basket")
			await _tap(destination.global_position)
			var after := int((_level.get("result") as LevelResult).correct)
			_ok(_in_hand() == null and after == before + 1,
				"one real basket touch delivers %s exactly once" % crop_id)
			if _in_hand() != null or after != before + 1:
				return
			deliveries += 1
			_completion_delivery_count += 1
		_ok(int(_level.get("_order_index")) == order_index + 1,
			"the filled order advances exactly once")
		_ok((_level.get("_delivered") as Dictionary) == expected,
			"landed quantities exactly match the requirements through this order")
		_completion_order_count += 1
		var checkpoint := SaveManager.get_harvest_checkpoint()
		if order_index < orders.size() - 1:
			_ok(_same_harvest_checkpoint(checkpoint, {"level_id": COMPLETION_LEVEL,
				"order_index": order_index + 1, "delivered": expected}),
				"each nonfinal order persists its next-order checkpoint")
		else:
			_ok(checkpoint.is_empty(), "the final order clears the challenge checkpoint")
	_ok(deliveries == COMPLETION_DELIVERIES, "all seventeen required targets were delivered")
	_ok(_completion_local.size() == 1, "the real level emits one completion result")
	if _completion_local.size() != 1:
		return
	var completed: LevelResult = _completion_local[0]
	_ok(completed.level_id == COMPLETION_LEVEL and completed.correct == deliveries
		and completed.mistakes == 0 and not completed.quit_early,
		"the final result records the real deliveries without mistakes or early quit")
	_ok(completed.objective_scoring and completed.reached_goal
		and completed.clean_run and completed.stars() == 3,
		"completing all orders opens the existing three result objectives")
	await _completion_wait_for_result()
	var result_scene: Node = get_tree().current_scene
	_ok(_completion_global.size() == 1 and GameManager.get_last_result() == completed,
		"GameManager settles the same completion exactly once")
	_ok(result_scene != null and result_scene.scene_file_path == COMPLETION_RESULT_SCENE,
		"the actual result scene opens after the final order")
	var progress := SaveManager.get_level_progress(COMPLETION_LEVEL)
	_ok(bool(progress.get("completed", false)) and int(progress.get("attempts", 0)) == 1
		and int(progress.get("stars", 0)) == 3,
		"the real reward path records one completed three-star attempt")
	_ok(int(SaveManager.data["rewards"].get("coins", 0)) - coins_before
		== RewardManager.last_coins_earned and RewardManager.last_coins_earned > 0,
		"coins come from the existing final reward path")
	_ok(int(SaveManager.data["profile"].get("xp", 0)) - xp_before
		== RewardManager.last_xp_earned and RewardManager.last_xp_earned > 0,
		"experience comes from the existing final reward path")
	_ok(_garden_economy_snapshot() == garden_before,
		"all three challenge orders leave daily garden inventory and plots unchanged")
	SaveManager.load_game()
	var reloaded := SaveManager.get_level_progress(COMPLETION_LEVEL)
	var garden_after_reload := _garden_economy_snapshot()
	_ok(bool(reloaded.get("completed", false)) and int(reloaded.get("attempts", 0)) == 1
		and int(reloaded.get("stars", 0)) == 3 and SaveManager.get_harvest_checkpoint().is_empty(),
		"disk reload preserves final completion and an empty checkpoint")
	_ok(_completion_values_equal(garden_after_reload, garden_before),
		"disk reload preserves the daily garden economy after challenge completion")
	if _completion_global.size() == 1 and result_scene != null \
			and result_scene.scene_file_path == COMPLETION_RESULT_SCENE:
		_completion_case_count += 1
	print("COMPLETION CASE ", _shape, " orders=3 deliveries=", deliveries)


func _completion_available_target() -> Node2D:
	for target in _targets():
		if not is_instance_valid(target) or target.taken or not target.is_visible_in_tree():
			continue
		if "clutter" in target.crop.get("tags", []):
			continue
		if not Maturity.pickable(str(target.step), _level.get("_allowed")):
			continue
		if bool(_level.call("_target_is_available_now", target)):
			return target
	return null


func _completion_seed_garden() -> Dictionary:
	var farm: Dictionary = SaveManager.data["farm"]
	farm["warehouse_cap"] = 3
	farm["warehouse"] = {"carrot": 3}
	farm["harvest_basket"] = {"strawberry": 2}
	for plot in farm["plots"]:
		plot["last_updated_at"] = COMPLETION_NOW
	SaveManager.save_game()
	return _garden_economy_snapshot()


func _completion_reported(completed: LevelResult) -> void:
	_completion_local.append(completed)


func _completion_finished(completed: LevelResult) -> void:
	_completion_global.append(completed)


func _completion_wait_for_result() -> void:
	# A real-time deadline remains bounded while the farm's test clock is fixed.
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		var scene: Node = get_tree().current_scene
		if _completion_global.size() == 1 and scene != null \
				and scene.scene_file_path == COMPLETION_RESULT_SCENE \
				and not bool(SceneManager.get("_busy")):
			return
		await get_tree().process_frame
	_ok(false, "final settlement and result scene must arrive within six seconds")


func _completion_cleanup() -> void:
	await _close()
	var scene: Node = get_tree().current_scene
	if scene != null and scene != self:
		get_tree().current_scene = null
		scene.queue_free()
	for _frame in range(4):
		await get_tree().process_frame


## Save files deserialize whole numbers as floats. Compare the farm snapshot's
## values semantically so a correct JSON round trip is not reported as an
## economy mutation just because `3` was read back as `3.0`.
func _completion_values_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] \
			and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(left), float(right))
	if left is Dictionary:
		if not right is Dictionary or left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _completion_values_equal(left[key], right[key]):
				return false
		return true
	if left is Array:
		if not right is Array or left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _completion_values_equal(left[index], right[index]):
				return false
		return true
	return typeof(left) == typeof(right) and left == right
