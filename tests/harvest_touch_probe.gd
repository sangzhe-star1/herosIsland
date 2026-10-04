extends Node
## 丰收行动, with thumbs.
##
## harvest_probe.gd asks the arithmetic questions -- is 34 degrees inside the
## fan, can this level's order be filled from what is on the ground. This one
## asks the only question that matters afterwards: **when a child does the move,
## does anything happen?**
##
## It was written the day the answer turned out to be no. Four of the eight
## levels -- every one with more than one basket -- could not be finished by any
## motion at all. Three separate causes, stacked:
##
##   * every gesture ends where it started or nearby, so letting go was always
##     "over nothing" and the crop was put back;
##   * carrying on to a basket afterwards broke the gesture instead, because a
##     tap that travels is not a tap and a pull that turns leaves its fan;
##   * the baskets sat 59px apart with a reach of 119 each, so only the first
##     one in the list could ever be chosen anyway.
##
## Every one of those passed tools_check, passed harvest_probe, and passed the
## screenshot pass -- because nothing anywhere pushed a real
## InputEventScreenDrag at the screen. harvest_probe.gd's own header had
## promised for a month that this file did it.
##
## Both screen shapes, always. The island stretches with aspect=expand, so a 4:3
## tablet hands this template a 1280x960 viewport inside a 1024x768 window, and
## a probe that pushes design coordinates straight in aims at the wrong place.
## Everything below goes through _glass().

const Maturity := preload("res://scripts/harvest/maturity.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const HarvestRoute := preload("res://scripts/harvest/harvest_route.gd")
const HarvestVisualArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const HarvestAction := preload("res://scripts/minigames/harvest_action.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]

var _failures: Array[String] = []
var _level: Node = null
var _shape := ""


## Counted as well as checked. Half of this file is "find a target of this kind
## and then ask about it", and a find that quietly comes back empty would skip
## its questions and still print PASSED -- a probe that tested nothing and said
## so in green. The number is printed at the end; if it drops, something stopped
## being asked.
var _asked := 0


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _ready() -> void:
	print("\n=== harvest touch probe ===")
	for shape in SHAPES:
		_shape = "%dx%d" % [shape.x, shape.y]
		await _run_on_a(shape)

	# This one has no layout question, but it must travel through the real
	# touch -> order -> SaveManager -> fresh scene path. Run it once so the
	# two display shapes do not manufacture two unrelated save histories.
	_shape = "checkpoint"
	await _a_completed_delivery_survives_a_real_reload()

	# The difficulty table is shape-independent; once is enough.
	_shape = "difficulty"
	await _the_difficulty_table_is_real()
	_the_late_levels_hold_their_shape()

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("  questions asked with a thumb: %d" % _asked)
	# A run that asks far fewer than it used to has stopped finding things to
	# ask about, which looks exactly like a pass from here.
	if _asked < 60:
		_failures.append("only %d checks ran -- something stopped being found"
			% _asked)
		print("FAIL  only %d checks ran" % _asked)
	print("HARVEST TOUCH PROBE %s\n"
		% ("PASSED" if _failures.is_empty() else "FAILED"))
	await ProbeLifecycle.finish(self, 1 if _failures.size() > 0 else 0)


func _run_on_a(window: Vector2i) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	print("-- window %s -> viewport %s"
		% [str(window), str(get_viewport().get_visible_rect().size)])

	await _one_basket_needs_one_move()
	await _mouse_path_uses_the_same_targets_and_baskets()
	await _delivery_stops_the_lift_and_bob()
	await _the_sort_pointer_tracks_the_lifting_crop()
	await _refusals_keep_the_input_anchor()
	await _soil_cover_uses_the_existing_gesture()
	await _orchard_cues_fit_their_fruit()
	await _the_plant_body_stays_after_a_pick()
	await _every_gesture_reaches_the_hand()
	await _the_lesson_starts_on_its_named_gesture()
	await _the_baskets_are_telling_apart()
	await _the_static_lesson_and_sort_route_are_still()
	await _the_matching_basket_stays_marked_without_motion()
	await _rapid_still_landings_replace_their_receipts()
	await _a_wrong_basket_costs_him_nothing()
	await _only_the_starred_one_goes_in_the_gift_basket()
	await _later_order_crops_wait_for_their_turn()
	await _the_help_points_to_the_matching_basket()
	await _unripe_is_refused_and_costs_nothing()
	await _a_touch_on_nothing_while_holding_is_not_a_mistake()
	await _the_third_hint_picks_it_but_does_not_choose()
	await _clutter_is_moved_not_collected()
	await _a_big_crop_is_easier_to_hit_than_a_small_one()
	await _nothing_is_planted_closer_than_a_thumb()
	await _the_streak_cheers_and_resets()
	await _the_customer_watches_the_order()
	await _one_finger_at_a_time()
	await _the_landed_order_gets_its_check()
	await _the_first_pick_teaches_the_loop()
	await _the_order_hud_is_legible()


# --- the harness ---------------------------------------------------------

func _fresh() -> void:
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()


## Boot a level AT a difficulty. _open()'s _fresh() wipes the save, so the
## setting has to land after the wipe and before the scene reads it.
func _open_at(level_id: String, tier: int) -> void:
	await _open_with_settings(level_id, {"difficulty": tier})


## Low motion changes the tutorial during scene construction, so the setting
## belongs in the save before the scene is instantiated, not after it appears.
func _open_low_motion(level_id: String) -> void:
	await _open_with_settings(level_id, {"reduce_motion": true})


func _open_with_settings(level_id: String, settings: Dictionary) -> void:
	_fresh()
	for setting in settings:
		SaveManager.set_setting(str(setting), settings[setting])
	GameManager.current_level_id = level_id
	_level = load(
		"res://scenes/minigames/harvest_action/HarvestAction.tscn").instantiate()
	add_child(_level)
	for i in range(6):
		await get_tree().process_frame


## Every row of the difficulty table, measured on the real field at all three
## tiers. Before this, the table lived in HARVEST_DESIGN.md and exactly ONE of
## its eight rows was wired -- the seven others were design fiction, and
## nothing said so because nothing asked.
func _the_difficulty_table_is_real() -> void:
	var decoys := {}
	var angles := {}
	var hints := {}
	var turns := {}
	var twist := {}
	var clock := {}
	var extra := {}
	for tier in [0, 1, 2]:
		# Row 2+3+8, read off the ripeness level.
		await _open_at("harvest_02", tier)
		var not_pickable := 0
		for node in _level.get("_targets"):
			if not node.get("taken") \
					and str(node.get("step")) not in ["ready", "golden"]:
				not_pickable += 1
		decoys[tier] = not_pickable
		hints[tier] = int((_level.get("_hints") as Node).get("misses_before_help"))
		clock[tier] = _level.get("_clock") != null
		if tier == 2:
			var label: Label = _level.get("_clock") as Label
			_ok(label != null and label.get_parent() == _level.get("_hud")
				and label.position.x >= get_viewport().get_visible_rect().size.x - 180.0,
				"the brave clock is in the clear HUD corner, above field artwork")
		await _close()

		# Row 4, read off a carrot's tuned cone.
		await _open_at("harvest_01", tier)
		angles[tier] = _angle_of_first_target()
		await _close()

		# Rows 5 and 6, read off the orchard's twist and the dig's passes.
		await _open_at("harvest_05", tier)
		twist[tier] = _param_of("orange", "turn")
		await _close()
		await _open_at("harvest_04", tier)
		turns[tier] = _param_of("potato", "turns")
		await _close()

		# Row 7, read off the celebration's last order.
		await _open_at("harvest_07", tier)
		_level.set("_order_index", 1)
		_level.call("_load_order")
		extra[tier] = (_level.get("_wanted") as Dictionary).has("golden_carrot")
		await _close()

	print("  decoys g/n/b: %s/%s/%s   hints: %s/%s/%s   angle: %.0f/%.0f/%.0f"
		% [decoys[0], decoys[1], decoys[2], hints[0], hints[1], hints[2],
			angles[0], angles[1], angles[2]])
	_ok(decoys[0] < decoys[1] and decoys[1] < decoys[2],
		"the decoy share does not grow with difficulty (%s/%s/%s)"
		% [decoys[0], decoys[1], decoys[2]])
	_ok(hints[0] == 1 and hints[1] == 2 and hints[2] == 3,
		"errors-before-help should be 1/2/3, got %s/%s/%s"
		% [hints[0], hints[1], hints[2]])
	_ok(angles[0] > angles[1] and angles[1] > angles[2],
		"the drag cone does not tighten with difficulty (%.0f/%.0f/%.0f)"
		% [angles[0], angles[1], angles[2]])
	_ok(twist[0] < twist[1] and twist[1] < twist[2],
		"the twist does not ask more of the circle with difficulty")
	_ok(turns[0] < turns[1] and turns[1] < turns[2],
		"dig passes should be 2/3/4-ish, got %s/%s/%s"
		% [turns[0], turns[1], turns[2]])
	_ok(not clock[0] and not clock[1] and clock[2],
		"the clock should exist at 勇敢 and only there (%s/%s/%s)"
		% [clock[0], clock[1], clock[2]])
	_ok(not extra[0] and not extra[1] and extra[2],
		"the brave-only order line should appear at 勇敢 and only there")

	# The probe leaves the house as it found it: NORMAL, clean save.
	_fresh()


func _angle_of_first_target() -> float:
	for node in _level.get("_targets"):
		var params: Dictionary = (node.get("crop") as Dictionary)\
			.get("gesture_params", {})
		if params.has("angle"):
			return float(params["angle"])
	return -1.0


func _param_of(crop_id: String, key: String) -> float:
	for node in _level.get("_targets"):
		var crop: Dictionary = node.get("crop")
		if str(crop.get("id", "")) == crop_id \
				and (crop.get("gesture_params", {}) as Dictionary).has(key):
			return float(crop["gesture_params"][key])
	return -1.0


## The two late levels, held to the design table by data: the seventh level
## is the 1→2→3 order STEP (two orders, the pumpkin's roll makes its first
## entrance), the celebration fields wheat and watermelon so the two spare
## gestures finally have somewhere to live, and the ripeness level carries
## the almost-ready step so the fourth maturity stops being dead data.
func _the_late_levels_hold_their_shape() -> void:
	var c7: Dictionary = GameData.get_level("harvest_07").get("config", {})
	_ok((c7.get("orders", []) as Array).size() == 2,
		"harvest_07 should carry TWO orders -- the step between one and three")
	var ids7 := []
	for t in c7.get("targets", []):
		ids7.append(str(t.get("crop_id", "")))
	_ok("pumpkin" in ids7, "harvest_07 lost its pumpkin -- roll_to_basket "
		+ "never gets taught before the celebration needs it")

	var c8: Dictionary = GameData.get_level("harvest_08").get("config", {})
	var ids8 := []
	for t in c8.get("targets", []):
		ids8.append(str(t.get("crop_id", "")))
	_ok("wheat" in ids8 and "watermelon" in ids8,
		"harvest_08 should field wheat and watermelon (%s)" % [ids8])
	var takes_grain := false
	for basket in c8.get("baskets", []):
		if "grain" in (basket.get("accepts_tags", []) as Array):
			takes_grain = true
	_ok(takes_grain, "wheat is on the field and no basket accepts grain -- "
		+ "a crop that can be picked and never put down. (A fourth basket was "
		+ "tried and failed the thumb rule at 16:9 -- the veg basket carries "
		+ "the grain tag instead.)")

	var c2: Dictionary = GameData.get_level("harvest_02").get("config", {})
	var has_almost := false
	for t in c2.get("targets", []):
		if str(t.get("maturity", "")) == "almost_ready":
			has_almost = true
	_ok(has_almost, "harvest_02 should ask the almost-ready question -- "
		+ "the fourth maturity step exists and no level uses it")

	# The ninth level is the 2-basket line step: broccoli and wheat ride the
	# veg basket on the grain tag, grape rides fruit, and the cut lesson
	# starts on an actual cut. The tenth is the golden bounty: two orders,
	# the starred carrot in the second, gift basket waiting with its rule.
	var c9: Dictionary = GameData.get_level("harvest_09").get("config", {})
	_ok(not c9.has("orders"),
		"harvest_09 should be ONE order -- the line lesson before the bounty")
	var ids9 := []
	for t in c9.get("targets", []):
		ids9.append(str(t.get("crop_id", "")))
	_ok("grape" in ids9 and "wheat" in ids9,
		"harvest_09 should field grape and wheat (%s)" % [ids9])
	var grain_home := false
	for basket in c9.get("baskets", []):
		if "grain" in (basket.get("accepts_tags", []) as Array):
			grain_home = true
	_ok(grain_home, "wheat is on the field and no basket accepts grain -- "
		+ "a crop that can be picked and never put down")
	_ok(str(c9.get("teaches", "")) == "cut_cluster",
		"harvest_09 should teach the cut it actually asks for")

	var c10: Dictionary = GameData.get_level("harvest_10").get("config", {})
	_ok((c10.get("orders", []) as Array).size() == 2,
		"harvest_10 should carry TWO orders -- the step after the celebration")
	var golden_late := false
	for order in c10.get("orders", []):
		for entry in (order as Dictionary).get("requirements", []):
			if str(entry.get("crop_id", "")) == "golden_carrot":
				golden_late = true
	_ok(golden_late, "harvest_10 hides its starred carrot in a later order")


func _open(level_id: String) -> void:
	await _open_with_settings(level_id, {})


func _close() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
	_level = null
	for i in range(4):
		await get_tree().process_frame


## Design coordinates to window coordinates. See the header.
func _glass(at: Vector2) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(get_window().size)
	return Vector2(at.x * win.x / view.x, at.y * win.y / view.y)


## One press, a path, one release -- the whole of a gesture, as a thumb.
func _stroke(points: Array) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(points[0])
	Input.parse_input_event(down)
	await get_tree().process_frame

	var last: Vector2 = points[0]
	for i in range(1, points.size()):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _glass(points[i])
		drag.relative = _glass(points[i]) - _glass(last)
		last = points[i]
		Input.parse_input_event(drag)
		await get_tree().process_frame

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(points[points.size() - 1])
	Input.parse_input_event(up)
	for i in range(4):
		await get_tree().process_frame


## Desktop equivalent of `_stroke()`. Send actual mouse events through the
## viewport so Control routing, emulation settings and HUD pass-through are
## covered along with the crop gesture recogniser.
func _mouse_stroke(points: Array) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = _glass(points[0])
	down.global_position = down.position
	Input.parse_input_event(down)
	await get_tree().process_frame

	for i in range(1, points.size()):
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = _glass(points[i])
		motion.global_position = motion.position
		motion.relative = motion.position - _glass(points[i - 1])
		Input.parse_input_event(motion)
		await get_tree().process_frame

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = _glass(points[points.size() - 1])
	up.global_position = up.position
	Input.parse_input_event(up)
	for i in range(4):
		await get_tree().process_frame


func _mouse_tap(at: Vector2) -> void:
	await _mouse_stroke([at, at])


func _tap(at: Vector2) -> void:
	await _stroke([at, at])


## Mouse is still a supported path on desktop, and the passive order-folder HUD
## must not intercept it. Exercise a real harvest and basket delivery rather
## than only checking the Control's mouse_filter value.
func _mouse_path_uses_the_same_targets_and_baskets() -> void:
	await _open("harvest_07")
	var target := _find("", "tomato")
	_ok(target != null, "多作物订单 exposes a ready tomato to the mouse path")
	if target != null:
		var before := _picked_total()
		await _mouse_stroke(_move_for(target))
		var held := _in_hand()
		_ok(held == target, "mouse drag picks the same tomato the touch path accepts")
		var basket: Node2D = _level.call("_destination_for", held) if held != null else null
		_ok(basket != null and basket.id == "veg",
			"mouse-held tomato resolves through the existing vegetable basket")
		if basket != null:
			await _mouse_tap(basket.global_position)
			_ok(_in_hand() == null and _picked_total() == before + 1,
				"one mouse delivery lands once and clears the held crop")
	await _close()


## Fast delivery cancels the unfinished lift; delayed delivery cancels the
## held bob. Neither can start writing the transform again during the flight.
func _delivery_stops_the_lift_and_bob() -> void:
	for pause in [0.0, 0.36]:
		await _open("harvest_02")
		var target := _find("", "strawberry")
		_ok(target != null, "the lift transition has a ready strawberry")
		if target == null:
			await _close()
			continue
		await _stroke(_move_for(target))
		_ok(_in_hand() == target, "the lift transition starts from a real pick")
		if pause > 0.0:
			await get_tree().create_timer(pause).timeout
		var previous_lift: Tween = target.get("_move_tween") as Tween
		var previous_bob: Tween = target.get("_held_bob") as Tween
		if pause > 0.0:
			_ok(previous_bob != null and previous_bob.is_valid(),
				"the delayed delivery exercises a running held bob")
		var basket: Node2D = _level.call("_destination_for", target)
		_ok(basket != null, "the held strawberry has a delivery destination")
		if basket == null:
			await _close()
			continue
		await _tap(basket.global_position)
		_ok(_in_hand() == null and _picked_total() == 1,
			"delivery during a lift or bob lands exactly once")
		_ok(previous_lift == null or not previous_lift.is_valid(),
			"delivery cancels the previous lift and its pending callback")
		_ok(previous_bob == null or not previous_bob.is_valid(),
			"delivery cancels the previous held bob")
		await get_tree().create_timer(0.25).timeout
		_ok(not is_instance_valid(target) or target.get("_held_bob") == null,
			"no delayed lift callback starts a bob during delivery")
		await get_tree().create_timer(0.18).timeout
		_ok(not is_instance_valid(target), "a delivered crop leaves the scene")
		await _close()


## Plant art is a passive field sibling. Picking and delivering only moves
## the existing fruit Target and leaves its plant rooted in the same place.
func _the_plant_body_stays_after_a_pick() -> void:
	await _open("harvest_07")
	var target := _find("", "tomato")
	_ok(target != null, "the planted crop has one available fruit target")
	if target == null:
		await _close()
		return
	var body: Node2D = target.get_meta("visual_plant", null) as Node2D
	var mound: Node2D = target.get_meta("visual_mound", null) as Node2D
	_ok(body != null and mound != null, "the crop has a plant body and ground contact")
	if body == null or mound == null:
		await _close()
		return
	_ok(body.get_parent() == _level.get("_field"), "plant art lives in the field")
	var planted_at := body.global_position
	var rooted_at := mound.global_position
	await _stroke(_move_for(target))
	_ok(_in_hand() == target, "only the picked fruit becomes the held target")
	_ok(body.visible and mound.visible and body.global_position == planted_at
		and mound.global_position == rooted_at, "the plant and contact stay after picking")
	var basket: Node2D = _level.call("_destination_for", target)
	_ok(basket != null, "the picked fruit uses the existing basket resolver")
	if basket != null:
		await _tap(basket.global_position)
		await get_tree().create_timer(0.45).timeout
		_ok(not is_instance_valid(target), "the delivered fruit leaves the scene")
		_ok(is_instance_valid(body) and body.visible and body.global_position == planted_at
			and mound.visible and mound.global_position == rooted_at,
			"the passive plant stays rooted after delivery")
	await _close()
	await _open("harvest_08")
	var future := _find_any("tomato", "ready")
	var future_body: CanvasItem = future.get_meta("visual_plant", null) as CanvasItem \
		if future != null else null
	_ok(future != null and not future.visible and future_body != null and not future_body.visible,
		"a future order hides both its fruit and passive plant body")
	await _close()


## The sorting guide follows the actual held fruit during the lift, while
## its existing trace names the basket from the first visible beat.
func _the_sort_pointer_tracks_the_lifting_crop() -> void:
	await _open("harvest_07")
	var tomato := _find("", "tomato")
	_ok(tomato != null, "the moving sorting guide has a ready tomato")
	if tomato == null:
		await _close()
		return
	var expected_height: float = tomato.call("held_lift_height")
	_ok(expected_height >= 46.0, "the held lift retains its minimum clearance")
	await _stroke(_move_for(tomato))
	var held := _in_hand()
	var pointer: Node = _level.get("_basket_pointer")
	var destination: Node2D = _level.call("_destination_for", held) if held != null else null
	_ok(held != null and pointer != null and destination != null,
		"the first held crop immediately has one sorting pointer")
	if held == null or pointer == null or destination == null:
		await _close()
		return
	var trace: Line2D = pointer.get_node_or_null("MotionTrace") as Line2D
	var spot: Node2D = pointer.get("_spot") as Node2D
	_ok(trace != null and trace.visible and trace.points.size() >= 2
		and _guide_endpoint_points_into_basket(trace, destination),
		"normal motion guides into the matching basket mouth without covering its sample")
	await get_tree().create_timer(0.12).timeout
	var fruit_art: TextureRect = held.get("_art") as TextureRect
	var fruit_anchor := _world_texture_alpha_rect(fruit_art).get_center() \
		if fruit_art != null else held.global_position
	_ok(spot != null and spot.position.distance_to(fruit_anchor) < 3.0,
		"the LOOK spotlight tracks the visible fruit during its real lift")
	_ok(trace != null and trace.points.size() >= 2
		and trace.points[0].distance_to(fruit_anchor) < 3.0,
		"the obstacle-aware route starts at the visible lifted fruit")
	await get_tree().create_timer(0.16).timeout
	fruit_anchor = _world_texture_alpha_rect(fruit_art).get_center() \
		if fruit_art != null else held.global_position
	_ok(spot != null and spot.position.distance_to(fruit_anchor) < 2.0,
		"the guide remains attached to the held pose after the spring finishes")
	if held.has_meta("visual_plant"):
		var body: Node2D = held.get_meta("visual_plant") as Node2D
		var body_art: TextureRect = body.get_node_or_null("HarvestPlantBody3DArt") as TextureRect
		_ok(body_art != null and fruit_art != null,
			"the plant clearance check uses the actual source textures")
		if body_art != null and fruit_art != null:
			var body_bounds := _world_texture_alpha_rect(body_art)
			var fruit_bounds := _world_texture_alpha_rect(fruit_art)
			_ok(body_bounds.position.y - fruit_bounds.end.y >= 12.0,
				"the held fruit visibly clears the actual top of its passive plant")
			if trace != null and trace.points.size() > 1 and body_art.is_visible_in_tree():
				var rooted_plant_obstacles: Array = [body_bounds]
				for point_index in range(1, trace.points.size()):
					var route_segment_clear := HarvestRoute.segment_is_clear_of_rectangles(
						trace.points[point_index - 1], trace.points[point_index],
						rooted_plant_obstacles, 4.0)
					if not route_segment_clear:
						print("rooted route collision viewport=%s segment=%d points=%s bounds=%s start=%s held=%s" % [
							str(get_viewport().get_visible_rect().size), point_index,
							str(trace.points), str(body_bounds), str(trace.points[point_index - 1]),
							str(held.global_position)])
					_ok(route_segment_clear,
						"the basket pointer routes around the picked crop's rooted plant")
			var field: Node = _level.get("_field")
			for child in field.get_children():
				var neighbour: TextureRect = child.get_node_or_null("HarvestPlantBody3DArt") as TextureRect
				if neighbour != null and neighbour != body_art and neighbour.is_visible_in_tree():
					_ok(not fruit_bounds.grow(8.0).intersects(_world_texture_alpha_rect(neighbour)),
						"the detached fruit also clears neighbouring plant bodies")
	await _tap(destination.global_position)
	for i in range(3):
		await get_tree().process_frame
	_ok(_in_hand() == null and _live_guides().is_empty(),
		"delivery clears the following pointer and its trace")
	await _close()


func _world_texture_alpha_rect(sprite: TextureRect) -> Rect2:
	var image := sprite.texture.get_image()
	var used := Rect2(image.get_used_rect())
	var factor := sprite.size / Vector2(image.get_size())
	var transform := sprite.get_global_transform()
	return Rect2(transform * (used.position * factor),
		used.size * factor * transform.get_scale())


## Rejection feedback changes only the local visual group, even when a lift
## or held bob owns the target transform. Real touches still use the same anchor.
func _refusals_keep_the_input_anchor() -> void:
	await _open_at("harvest_02", 2)
	var unripe := _find_any("strawberry", Maturity.UNRIPE)
	_ok(unripe != null, "the refusal test has an unripe target")
	if unripe != null:
		var home: Vector2 = unripe.position
		var visual: Node2D = unripe.get("_visual") as Node2D
		_ok(visual != null, "rejection feedback has a local display group")
		for retry in range(2):
			await _stroke(_move_for(unripe))
			await get_tree().create_timer(0.04).timeout
			_ok(unripe.position.distance_to(home) < 0.001,
				"a refused gesture never moves the crop input anchor")
			_ok(visual != null and visual.position.length() > 0.1,
				"refusal still gives visible local shake feedback")
		await get_tree().create_timer(0.28).timeout
		_ok(visual != null and visual.position.length() < 0.001,
			"rapid refused gestures return the display to its original position")
	await _close()

	await _open("harvest_04")
	var potato := _find(Gesture.SWEEP, "potato")
	_ok(potato != null, "the visual refusal test has a covered potato")
	if potato != null:
		var home: Vector2 = potato.position
		var visual: Node2D = potato.get("_visual") as Node2D
		var cover: Node2D = potato.get("_cover") as Node2D
		_ok(visual != null and cover != null and cover.get_parent() == visual,
			"the opaque soil cover shares the rejection display group")
		await _stroke([potato.global_position, potato.global_position + Vector2(12, 0)])
		await get_tree().create_timer(0.04).timeout
		_ok(potato.position.distance_to(home) < 0.001,
			"a failed dig preserves the potato input anchor")
		_ok(visual != null and visual.position.length() > 0.1,
			"the soil covering the potato visibly shakes on refusal")
		await get_tree().create_timer(0.28).timeout
		_ok(visual != null and visual.position.length() < 0.001,
			"the soil cover returns to the crop origin after refusal")
	await _close()

	await _open("harvest_02")
	var target := _find("", "strawberry")
	_ok(target != null, "the held refusal test has a ready berry")
	if target == null:
		await _close()
		return
	await _stroke(_move_for(target))
	_ok(_in_hand() == target, "the held refusal test starts with a real pick")
	var lift: Tween = target.get("_move_tween") as Tween
	var wrong := _basket("veg")
	var visual: Node2D = target.get("_visual") as Node2D
	_ok(wrong != null and visual != null, "the held crop has a wrong destination and visual group")
	if wrong == null or visual == null:
		await _close()
		return
	await _tap(wrong.global_position)
	_ok(_in_hand() == target and _picked_total() == 0,
		"a wrong basket during the lift retains the held crop")
	_ok(target.get("_move_tween") == lift,
		"a wrong basket does not replace the crop lift transform")
	await get_tree().create_timer(0.35).timeout
	var bob: Tween = target.get("_held_bob") as Tween
	_ok(bob != null and bob.is_valid(), "the lifting callback still starts the held bob")
	await _tap(wrong.global_position)
	await get_tree().create_timer(0.03).timeout
	await _tap(wrong.global_position)
	_ok(target.get("_held_bob") == bob and bob != null and bob.is_valid(),
		"rapid wrong baskets preserve the independent held bob")
	_ok(_in_hand() == target and _picked_total() == 0,
		"rapid wrong baskets do not lose or count the crop")
	await get_tree().create_timer(0.28).timeout
	_ok(visual.position.length() < 0.001, "wrong-basket feedback returns its display to the held origin")
	var right: Node2D = _level.call("_destination_for", target)
	if right != null:
		await _tap(right.global_position)
		_ok(_in_hand() == null and _picked_total() == 1,
			"the same held crop still delivers once after wrong baskets")
		await get_tree().create_timer(0.43).timeout
		_ok(not is_instance_valid(target), "the delivered crop leaves after visual refusal")
	await _close()


## The move a child makes for this crop, ending where it naturally ends -- ON
## the plant, never over at the baskets. That is the point: the gesture is the
## picking and nothing else.

## The soil mesh is only artwork. Real partial strokes still drive the same
## cover opacity, and a release before the required turns restores the cover.
func _soil_cover_uses_the_existing_gesture() -> void:
	await _open("harvest_04")
	var target := _find(Gesture.SWEEP, "potato")
	_ok(target != null, "the soil-cover QA has the existing potato Target")
	if target == null:
		await _close()
		return
	var cover: Node2D = target.get("_cover") as Node2D
	var art: Control = cover.get_node_or_null("HarvestSoilCover3DArt") as Control \
		if cover != null else null
	_ok(art != null, "the matching-profile loose-earth image is present")
	if art == null:
		await _close()
		return
	_ok(art.mouse_filter == Control.MOUSE_FILTER_IGNORE and art.get_script() == null,
		"the soil image does not receive input or own gesture state")
	_ok(not HarvestVisualArt.prop_has_baked_contact_shadow("soil_cover"),
		"the source soil image leaves contact shadows to the existing field")
	var fitted := HarvestVisualArt.soil_cover_layout(90.0)
	var fitted_bounds: Rect2 = fitted.get("rect", Rect2())
	_ok(absf(fitted_bounds.size.x - 117.0) < 0.5,
		"soil width is measured from the image alpha rather than its full canvas")
	var before: int = _picked_total()
	var at: Vector2 = target.global_position
	var params: Dictionary = target.crop.get("gesture_params", {})
	var leg := float(params.get("leg", 60.0)) + 26.0
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(at)
	Input.parse_input_event(down)
	await get_tree().process_frame
	var last := at
	for point in [at + Vector2(leg, 0), at + Vector2(leg - 14.0, 0)]:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _glass(point)
		drag.relative = _glass(point) - _glass(last)
		last = point
		Input.parse_input_event(drag)
		await get_tree().process_frame
	_ok(cover.modulate.a > 0.05 and cover.modulate.a < 0.95,
		"a real unfinished dig gradually uncovers the crop")
	_ok(cover.scale.x < 1.0 and cover.scale.x > 0.80,
		"the passive earth follows the existing dig shrink feedback")
	_ok(_picked_total() == before and not target.taken and target.global_position.distance_to(at) < 0.001,
		"partial digging preserves the existing count and input origin")
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(last)
	Input.parse_input_event(up)
	for i in range(4):
		await get_tree().process_frame
	_ok(is_equal_approx(cover.modulate.a, 1.0) and cover.scale.distance_to(Vector2.ONE) < 0.001,
		"releasing an unfinished dig restores the same cover")
	_ok(_picked_total() == before and not target.taken,
		"an unfinished dig does not consume the potato")
	await get_tree().create_timer(0.25).timeout
	await _stroke(_move_for(target))
	_ok(_picked_total() == before + 1, "the original full sweep still delivers once to its only basket")
	await _close()

func _move_for(target: Node2D) -> Array:
	# The probe is a real thumb, but it does not carry a private answer to
	# "what move works". The tutorial and recogniser share this exact path.
	return Array(Gesture.demo_path(str(target.crop.get("recogniser", "")),
		target.crop.get("gesture_params", {}), target.global_position,
		float(target.get("radius"))))


func _targets() -> Array:
	return _level.get("_targets")


func _baskets() -> Array:
	return _level.get("_baskets")


func _basket(id: String) -> Node2D:
	for b in _baskets():
		if b.id == id:
			return b
	return null


func _in_hand() -> Node2D:
	var held = _level.get("_in_hand")
	return held if held != null and is_instance_valid(held) else null


func _picked_total() -> int:
	var total := 0
	for value in (_level.get("_picked") as Dictionary).values():
		total += int(value)
	return total


## The first pickable target matching a filter. `recogniser` or `crop_id` may
## be "" for "any".
func _find(recogniser: String = "", crop_id: String = "",
		ripeness: String = Maturity.READY) -> Node2D:
	for t in _targets():
		if not is_instance_valid(t) or t.taken or not t.visible:
			continue
		if recogniser != "" and str(t.crop.get("recogniser", "")) != recogniser:
			continue
		if crop_id != "" and str(t.crop.get("id", "")) != crop_id:
			continue
		if ripeness != "" and str(t.step) != ripeness:
			continue
		if "clutter" in t.crop.get("tags", []):
			continue
		return t
	return null


## Same lookup, but intentionally sees a future-order crop. It is used only to
## prove that a touch cannot consume something which is not yet on the glass.
func _find_any(crop_id: String, ripeness: String = "") -> Node2D:
	for t in _targets():
		if not is_instance_valid(t) or t.taken:
			continue
		if str(t.crop.get("id", "")) != crop_id:
			continue
		if ripeness != "" and str(t.step) != ripeness:
			continue
		return t
	return null


## Somewhere on the soil with nothing on it -- for testing a touch that means
## nothing. Far from every target and every basket.
func _empty_ground() -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var candidate := Vector2(view.x * 0.16, view.y * 0.62)
	for t in _targets():
		if is_instance_valid(t) and t.global_position.distance_to(candidate) < 130.0:
			candidate += Vector2(0.0, 90.0)
	return candidate


# --- what a thumb can do -------------------------------------------------

## One basket: the gesture is the whole move, and the crop puts itself away.
func _one_basket_needs_one_move() -> void:
	await _open("harvest_01")
	_ok(_baskets().size() == 1, "拔胡萝卜 has one basket, so there is nothing to decide")
	var carrot := _find(Gesture.DRAG, "carrot")
	_ok(carrot != null, "there is a carrot to pull")
	if carrot != null:
		await _stroke(_move_for(carrot))
		_ok(_picked_total() >= 1,
			"one pull, let go where he pulled it, and it is in the basket")
	await _close()


## Every gesture in the game picks something up, in a level that also sorts.
##
## The move ENDS ON THE PLANT. Not near a basket, not on the way to one -- the
## reason four levels were unplayable is that those two things were asked of the
## same stroke, and no stroke can do both.
func _orchard_cues_fit_their_fruit() -> void:
	await _open("harvest_03")
	var corn := _find(Gesture.DRAG, "corn")
	_ok(corn != null, "the short down-swipe cue has a real corn target")
	if corn != null:
		var cue: Node2D = corn.get("_affordance") as Node2D
		var arrow := cue.get_node_or_null("HarvestDirectionCue") as Line2D \
			if cue != null else null
		var arrowhead := cue.get_node_or_null("HarvestDirectionArrowhead") as Polygon2D \
			if cue != null else null
		_ok(arrow != null and arrowhead != null,
			"the short corn down-swipe keeps a visible directional cue")
		if arrow != null and arrow.points.size() >= 2:
			_ok(arrow.points[-1].y > arrow.points[0].y,
				"the compact corn cue follows its configured downward gesture")
			_ok(arrow.points[0].distance_to(arrow.points[-1]) <= 60.0,
				"the short down-swipe cue stays compact around its crop")
		var passive := cue != null and arrow != null and arrowhead != null \
			and cue.get_script() == null and arrow.get_script() == null \
			and arrowhead.get_script() == null
		_ok(passive,
			"the direction cue is passive artwork under the existing Target")
	await _close()
	await _open("harvest_06")
	var peas := _find(Gesture.DRAG, "peas")
	_ok(peas != null, "the short pod-opening cue has a real pea target")
	if peas != null:
		var cue: Node2D = peas.get("_affordance") as Node2D
		var arrow := cue.get_node_or_null("HarvestDirectionCue") as Line2D \
			if cue != null else null
		var follows_down := arrow != null and arrow.points.size() >= 2
		if follows_down:
			follows_down = arrow.points[-1].y > arrow.points[0].y
		_ok(follows_down,
			"the short pod-opening cue follows its configured downward gesture")
	await _close()

	await _open("harvest_05")
	var orange := _find(Gesture.TWIST, "orange")
	_ok(orange != null, "the rotation cue has a real orange Target")
	if orange != null:
		var cue: Node2D = orange.get("_affordance") as Node2D
		var arc := cue.get_node_or_null("HarvestTwistArc") as Line2D \
			if cue != null else null
		var start_arrowhead := cue.get_node_or_null("HarvestTwistArrowheadStart") as Polygon2D \
			if cue != null else null
		var end_arrowhead := cue.get_node_or_null("HarvestTwistArrowheadEnd") as Polygon2D \
			if cue != null else null
		_ok(arc != null and start_arrowhead != null and end_arrowhead != null \
			and arc.points.size() == 13,
			"the orange shows both possible directions on a curved rotation cue")
		if arc != null and start_arrowhead != null and end_arrowhead != null:
			var art: TextureRect = orange.get("_art") as TextureRect
			var fruit := HarvestVisualArt.texture_used_bounds(art.texture,
				art.size.x * 0.5, Vector2.ZERO, art.position) if art != null else Rect2()
			var centre := fruit.get_center()
			var max_radius := 0.0
			for point in arc.points:
				max_radius = maxf(max_radius, point.distance_to(centre))
			for point in start_arrowhead.polygon:
				max_radius = maxf(max_radius, point.distance_to(centre))
			for point in end_arrowhead.polygon:
				max_radius = maxf(max_radius, point.distance_to(centre))
			_ok(max_radius < float(orange.get("radius")) - 8.0,
				"the twist art stays inside the existing orange touch radius")
			_ok(start_arrowhead.polygon[0].distance_to(arc.points[0]) < 0.01 \
				and end_arrowhead.polygon[0].distance_to(arc.points[-1]) < 0.01,
				"opposing arrowheads sit at both ends of the rotation arc")
			_ok(cue.get_script() == null and arc.get_script() == null \
				and start_arrowhead.get_script() == null \
				and end_arrowhead.get_script() == null,
				"the orange rotation cue is passive artwork only")
	var branches := 0
	for target in _targets():
		if str(target.crop.get("sweep_cover", "")) != "branch":
			continue
		branches += 1
		var cue: Node2D = target.get("_affordance") as Node2D
		var twig := cue.get_node_or_null("HarvestBranchTwig") as Polygon2D \
			if cue != null else null
		var art: TextureRect = target.get("_art") as TextureRect
		_ok(cue != null and cue.name == "HarvestBranchCue" and twig != null,
			"orchard shaking keeps a visible short hanging twig")
		if twig == null or art == null:
			continue
		var bounds := Rect2(twig.polygon[0], Vector2.ZERO)
		for point in twig.polygon:
			bounds = bounds.expand(point)
		var fruit := HarvestVisualArt.texture_used_bounds(art.texture,
			art.size.x * 0.5, Vector2.ZERO, art.position)
		_ok(bounds.size.x >= 44.0 and bounds.size.x <= 72.0,
			"the curved bough stays within one fruit slot")
		_ok(bounds.end.y >= fruit.position.y - 4.0 \
			and bounds.end.y <= fruit.position.y + 3.0,
			"the bough meets the actual smaller or full fruit crown")
		_ok(cue.get_script() == null and cue.get_parent() == target.get("_visual"),
			"the branch remains passive artwork under the existing Target")
		for child in cue.get_children():
			_ok(child is Polygon2D and child.get_script() == null,
				"the twig adds neither an input node nor a dark outline")
	_ok(branches > 0, "the branch checks found real orchard targets")
	var apple := _find(Gesture.SWEEP, "apple")
	_ok(apple != null, "the compact branch has a ripe apple to shake")
	if apple != null:
		var before := _picked_total()
		await _stroke(_move_for(apple))
		_ok(_in_hand() == apple and _picked_total() == before,
			"a real shaking stroke still picks into the existing held state")
		var basket: Node2D = _level.call("_destination_for", apple)
		_ok(basket != null, "the shaken apple still uses the shared destination resolver")
		if basket != null:
			await _tap(basket.global_position)
			_ok(_in_hand() == null and _picked_total() == before + 1,
				"the shortened visual branch still delivers exactly one apple")
	await _close()


func _every_gesture_reaches_the_hand() -> void:
	# tap and line and drag all appear in 多作物订单; sweep and twist in 果园摇一摇.
	for level_id in ["harvest_07", "harvest_05"]:
		for recogniser in Gesture.ALL:
			await _open(level_id)
			# Carrot and pumpkin are the second delivery in L7. A realistic
			# field hides them until that delivery starts, so the probe changes
			# orders before asking the thumb to practise their drag.
			if level_id == "harvest_07" and recogniser == Gesture.DRAG:
				_level.set("_order_index", 1)
				_level.call("_load_order")
			var target := _find(recogniser)
			if target == null:
				await _close()
				continue
			_ok(_baskets().size() > 1, "%s sorts into more than one basket" % level_id)
			var taught_path: PackedVector2Array = _level.call("_gesture_path", target)
			_ok(Gesture.satisfied(str(target.crop.get("recogniser", "")),
				target.crop.get("gesture_params", {}), taught_path, target.global_position),
				"the %s lesson path really satisfies its %s recogniser (%s)"
				% [str(target.crop.get("id", "crop")), recogniser, level_id])
			await _stroke(_move_for(target))
			var held := _in_hand()
			_ok(held != null,
				"a %s, done on the plant and let go there, comes off in his hand (%s)"
					% [recogniser, level_id])
			if held == null:
				await _close()
				continue

			# ...and the second touch puts it away.
			var want: Node2D = null
			for b in _baskets():
				if b.takes(held.crop):
					want = b
					break
			if want == null:
				await _close()
				continue
			await _tap(want.global_position)
			_ok(_picked_total() >= 1,
				"and tapping the basket it belongs in puts it there (%s, %s)"
					% [recogniser, level_id])
			_ok(_in_hand() == null, "his hand is empty again (%s)" % recogniser)
			await _close()


## L7 says "cut the stem". Its teaching hand must begin on the broccoli's
## cut-stem gesture, rather than the first tomato in the layout.
func _the_lesson_starts_on_its_named_gesture() -> void:
	await _open("harvest_07")
	var taught: Node2D = _level.call("_teaching_target", "cut_stem")
	_ok(taught != null and str(taught.crop.get("harvest_gesture", "")) == "cut_stem",
		"the cut-stem lesson starts on a crop that actually uses cut_stem")
	var demo: Node = _level.get("_demo")
	var path := PackedVector2Array()
	if demo != null and is_instance_valid(demo):
		var steps: Array = demo.get("_steps")
		if not steps.is_empty():
			path = steps[0].get("path", PackedVector2Array())
	_ok(taught != null and path.size() > 2,
		"the on-screen cut lesson keeps its full route, not just one arrow")
	if taught != null:
		_ok(Gesture.satisfied(str(taught.crop.get("recogniser", "")),
			taught.crop.get("gesture_params", {}), path, taught.global_position),
			"the route the tutorial actually plays satisfies the cut-stem recogniser")
	await _close()


## Two baskets a finger cannot tell apart are one basket with two pictures.
##
## The same rule as the garden's beds and this template's own targets, and the
## only one of the three that was never written down: 59px apart with a reach of
## 119 meant the second and third baskets could not be chosen at all.
func _the_baskets_are_telling_apart() -> void:
	for level_id in ["harvest_02", "harvest_05", "harvest_07", "harvest_08"]:
		await _open(level_id)
		var baskets := _baskets()
		var view: Vector2 = get_viewport().get_visible_rect().size
		for i in range(baskets.size()):
			var here: Node2D = baskets[i]
			if "golden" in here.accepts:
				var marker := here.get_node_or_null("BasketSampleTag/GoldenBasketMarker") as Control
				_ok(marker != null and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE,
					"the gift basket has a passive star matching golden crops")
				_ok(here.get("_label") != null,
					"the golden basket keeps its crop sample beside the star")
			_ok(here.global_position.x + here.radius <= view.x
					and here.global_position.x - here.radius >= 0.0,
				"%s: basket '%s' is on the glass" % [level_id, here.id])
			_ok(here.radius >= 44.0,
				"%s: basket '%s' is big enough for a thumb (reach %.0f)"
					% [level_id, here.id, here.radius])
			for j in range(i + 1, baskets.size()):
				var there: Node2D = baskets[j]
				var gap: float = here.global_position.distance_to(there.global_position)
				_ok(gap > here.radius + there.radius,
					"%s: baskets '%s' and '%s' are further apart than their reaches (%.0f vs %.0f)"
						% [level_id, here.id, there.id, gap, here.radius + there.radius])
		await _close()


## The line-cut lesson begins already still: the route is the actual gesture,
## but its spotlight and hand do not travel. Once the child has picked a crop,
## the same tutorial component turns that route into the direct answer from
## held crop to matching basket.
func _the_static_lesson_and_sort_route_are_still() -> void:
	await _open_low_motion("harvest_07")
	var taught: Node2D = _level.call("_teaching_target", "cut_stem")
	var lesson: Node = _level.get("_demo")
	var trace: Line2D = lesson.get_node_or_null("MotionTrace") as Line2D \
		if lesson != null else null
	var spot: Node2D = lesson.get("_spot") as Node2D if lesson != null else null
	var hand: Node2D = lesson.get("_hand") as Node2D if lesson != null else null
	var path := PackedVector2Array()
	if taught != null:
		path = _level.call("_gesture_path", taught)
	_ok(taught != null and trace != null and trace.visible
		and _same_path(trace.points, path),
		"low-motion cut lesson shows its real full route as a fixed trace")
	var hand_art: Control = hand.get_node_or_null("GuideHandArt") as Control \
		if hand != null else null
	_ok(taught != null and spot != null and hand != null and hand_art != null
		and spot.position.distance_to(taught.global_position) < 0.5
		and hand.position.distance_to(path[path.size() - 1]) < 0.5,
		"the still lesson anchors its hero glove on the real final touch point")
	var spot_at := spot.position if spot != null else Vector2.INF
	var hand_at := hand.position if hand != null else Vector2.INF
	var trace_at := PackedVector2Array(trace.points) if trace != null else PackedVector2Array()
	await get_tree().create_timer(0.9).timeout
	_ok(spot != null and hand != null and trace != null
		and spot.position.distance_to(spot_at) < 0.5
		and hand.position.distance_to(hand_at) < 0.5
		and _same_path(trace.points, trace_at),
		"the low-motion lesson stays still instead of replaying a travel tween")

	var tomato := _find(Gesture.TAP, "tomato")
	_ok(tomato != null, "多作物订单 has a tomato for the still sorting route")
	if tomato == null:
		await _close()
		return
	var origin := tomato.global_position
	await _stroke(_move_for(tomato))
	var held := _in_hand()
	_ok(held != null and held.global_position.distance_to(origin + held.held_lift_displacement()) < 0.5
		and held.scale.distance_to(Vector2(1.12, 1.12)) < 0.001
		and held.z_index >= 2 and held.get_node_or_null("HarvestTargetVisual/HeldCue") != null,
		"a low-motion pick lands immediately in the visible held pose")
	if held == null:
		await _close()
		return
	var held_shift: Vector2 = held.get_meta("visual_held_shift", Vector2.ZERO)
	var held_art := held.get("_art") as TextureRect
	var rooted_plant := held.get_meta("visual_plant", null) as Node2D
	var rooted_art := rooted_plant.get_node_or_null("HarvestPlantBody3DArt") as TextureRect \
		if rooted_plant != null else null
	var held_alpha: Rect2 = _level.call("_world_art_bounds", held_art) \
		if held_art != null else Rect2()
	var rooted_alpha: Rect2 = _level.call("_world_art_bounds", rooted_art) \
		if rooted_art != null else Rect2()
	print("  held-shift shape=%s crop=%s x=%.1f fruit_alpha=%s plant_alpha=%s" % [
		_shape, str(held.crop.get("id", "")), held_shift.x,
		str(held_alpha), str(rooted_alpha)])
	var shift_limit := float(_level.get_script().get_script_constant_map().get(
		"HELD_SHIFT_LIMIT", 0.0))
	_ok(rooted_art != null and held_alpha.has_area() and rooted_alpha.has_area()
		and shift_limit > 0.0 and absf(held_shift.x) <= shift_limit + 0.01,
		"held alpha-bounds stay within the configured horizontal plant reach %.0fpx (shift %.1f)"
			% [shift_limit, held_shift.x])
	var destination: Node2D = _level.call("_destination_for", held)
	var guides := _live_guides()
	var pointer: Node = guides[0] if guides.size() == 1 else null
	var pointer_trace: Line2D = pointer.get_node_or_null("MotionTrace") as Line2D \
		if pointer != null else null
	var carry: PackedVector2Array = _level.call("_basket_hint_route", held,
		destination) if destination != null else PackedVector2Array()
	_ok(destination != null and guides.size() == 1 and pointer_trace != null
		and pointer_trace.visible and _same_path(pointer_trace.points, carry),
		"the still basket pointer reuses the held crop's clear route and resolver")
	var held_at := held.global_position
	var held_scale := held.scale
	await get_tree().create_timer(0.65).timeout
	_ok(is_instance_valid(held) and held.global_position.distance_to(held_at) < 0.5
		and held.scale.distance_to(held_scale) < 0.001,
		"the held crop does not start an idle bob in low-motion mode")
	await _close()


## Reduce-motion makes the page quieter, never less understandable. After a
## real pick, the same shared destination resolver must leave exactly one
## basket visibly marked even though the optional breathing tween is absent.
func _the_matching_basket_stays_marked_without_motion() -> void:
	await _open_low_motion("harvest_02")
	var berry := _find(Gesture.TAP, "strawberry")
	_ok(berry != null, "草莓红了吗 has a strawberry for the still target cue")
	if berry == null:
		await _close()
		return
	var origin := berry.global_position
	await _stroke(_move_for(berry))
	var held := _in_hand()
	_ok(held != null and held.global_position.distance_to(origin + Vector2(0, -46)) < 0.5
		and held.scale.distance_to(Vector2(1.12, 1.12)) < 0.001
		and held.z_index >= 2 and held.get_node_or_null("HarvestTargetVisual/HeldCue") != null,
		"the strawberry is immediately shown in its final held pose")
	if held == null:
		await _close()
		return
	var target: Node2D = _level.call("_destination_for", held)
	_ok(target != null and target.id == "fruit",
		"the shared target resolver chooses the fruit basket for the still cue")
	if target == null:
		await _close()
		return
	var cue: Node2D = target.get("_waiting_cue")
	var glow: Node2D = cue.get_node_or_null("WaitingGlow") if cue != null else null
	var ring: Line2D = cue.get_node_or_null("TargetRing") if cue != null else null
	_ok(cue != null and cue.visible and glow != null and glow.visible
		and ring != null and ring.width >= 8.0,
		"reduce-motion keeps a clear static glow and ring around the matching basket")
	_ok(target.get("_pulse") == null
		and target.scale.distance_to(Vector2.ONE) < 0.001,
		"reduce-motion does not need the optional basket breathing tween")
	for basket in _baskets():
		if basket == target:
			continue
		var other_cue: Node2D = basket.get("_waiting_cue")
		_ok(other_cue != null and not other_cue.visible,
			"only the matching basket wears the static answer ring")
	var held_at := held.global_position
	var held_scale := held.scale
	await get_tree().create_timer(0.65).timeout
	_ok(target.scale.distance_to(Vector2.ONE) < 0.001,
		"the low-motion answer remains still after time passes")
	_ok(is_instance_valid(held) and held.global_position.distance_to(held_at) < 0.5
		and held.scale.distance_to(held_scale) < 0.001,
		"the held strawberry does not begin bobbing after the instant lift")
	var wrong: Node2D = null
	for basket in _baskets():
		if basket != target:
			wrong = basket
			break
	_ok(wrong != null, "the strawberry has a different basket to refuse")
	if wrong != null:
		await _tap(wrong.global_position)
		_ok(cue.visible and _in_hand() == held,
			"a wrong basket leaves the still target cue and held crop intact")
	await _tap(target.global_position)
	var receipt: Node2D = target.get_node_or_null("AcceptedCue") as Node2D
	_ok(not cue.visible and _in_hand() == null and receipt != null and receipt.visible,
		"the static answer clears and a fixed check confirms the instant landing")
	await _close()


## Three quick real deliveries replace the still receipt before its expiry.
## The discarded receipts must not leave timer callbacks holding freed Nodes.
func _rapid_still_landings_replace_their_receipts() -> void:
	await _open_low_motion("harvest_07")
	var previous_receipt_id := 0
	var basket: Node2D = null
	for i in range(3):
		var tomato := _find("", "tomato")
		_ok(tomato != null, "rapid still landing %d has a ready tomato" % i)
		if tomato == null:
			break
		await _stroke(_move_for(tomato))
		var held := _in_hand()
		basket = _level.call("_destination_for", held) if held != null else null
		_ok(basket != null, "rapid still landing %d resolves its real basket" % i)
		if basket == null:
			break
		await _tap(basket.global_position)
		var receipt: Node2D = basket.get("_accepted_cue") as Node2D
		_ok(receipt != null and is_instance_valid(receipt) and receipt.visible,
			"each rapid still landing has a current visible receipt")
		if previous_receipt_id != 0:
			_ok(instance_from_id(previous_receipt_id) == null,
				"the next landing frees the replaced receipt")
		previous_receipt_id = receipt.get_instance_id() if receipt != null else 0
		_ok(_in_hand() == null and _picked_total() == i + 1,
			"each rapid still landing clears the held crop and counts once")
	await get_tree().create_timer(0.82).timeout
	_ok(basket != null and basket.get("_accepted_cue") == null
		and instance_from_id(previous_receipt_id) == null,
		"the last still receipt expires and clears its owner")
	_ok(_picked_total() == 3 and int(_level.get("_order_index")) == 0,
		"receipt expiry does not alter delivery or advance the unfinished order")
	await _close()

	# Also leave while a receipt is pending: its lifetime ends with the basket.
	await _open_low_motion("harvest_07")
	var tomato := _find("", "tomato")
	if tomato != null:
		await _stroke(_move_for(tomato))
		basket = _level.call("_destination_for", _in_hand())
		if basket != null:
			await _tap(basket.global_position)
			var receipt: Node2D = basket.get("_accepted_cue") as Node2D
			previous_receipt_id = receipt.get_instance_id() if receipt != null else 0
	await _close()
	await get_tree().create_timer(0.82).timeout
	_ok(previous_receipt_id != 0 and instance_from_id(previous_receipt_id) == null,
		"leaving the page also cancels the pending receipt lifetime")


## A wrong basket says no and gives it back. Nothing is ever lost.
func _a_wrong_basket_costs_him_nothing() -> void:
	await _open("harvest_02")
	var berry := _find(Gesture.TAP, "strawberry")
	_ok(berry != null, "there is a ripe strawberry")
	if berry == null:
		await _close()
		return
	await _stroke(_move_for(berry))
	var held := _in_hand()
	_ok(held != null, "the strawberry is in his hand")
	if held == null:
		await _close()
		return

	var wrong := _basket("veg")
	if wrong != null:
		await _tap(wrong.global_position)
		_ok(_picked_total() == 0, "a strawberry in the vegetable basket is not counted")
		_ok(_in_hand() == held, "and it is still in his hand, not gone")

	var right := _basket("fruit")
	if right != null:
		await _tap(right.global_position)
		_ok(_picked_total() >= 1, "and putting it in the fruit basket still works")
	await _close()


## "The ones with a star go in the gift basket" -- both ways round.
##
## It was enforced one way only. A golden carrot could go nowhere else, and
## every ordinary tomato could ALSO go in the gift basket and be told it was
## right, because a basket with no tags takes everything. A child who tipped the
## whole field into it would have been correct every single time.
func _only_the_starred_one_goes_in_the_gift_basket() -> void:
	await _open_at("harvest_07", 2)
	var gift := _basket("gift")
	_ok(gift != null, "多作物订单 has a gift basket")
	if gift == null:
		await _close()
		return

	# An ordinary crop is refused by it.
	var plain := _find(Gesture.TAP, "tomato")
	if plain != null:
		await _stroke(_move_for(plain))
		if _in_hand() != null:
			await _tap(gift.global_position)
			_ok(_picked_total() == 0,
				"a tomato is NOT welcome in the gift basket just because it has no rule")
			_ok(_in_hand() != null, "and it stays in his hand")
			var veg := _basket("veg")
			if veg != null:
				await _tap(veg.global_position)

	# ...and the starred one is refused everywhere else. It belongs to the
	# second delivery, so bring that delivery onto the field first.
	_level.set("_order_index", 1)
	_level.call("_load_order")
	var golden := _find("", "golden_carrot", Maturity.GOLDEN)
	if golden != null:
		var before := _picked_total()
		await _stroke(_move_for(golden))
		if _in_hand() != null:
			var veg := _basket("veg")
			if veg != null:
				await _tap(veg.global_position)
				_ok(_picked_total() == before,
					"the starred carrot cannot go in the vegetable basket")
			await _tap(gift.global_position)
			_ok(_picked_total() > before, "it goes in the gift basket")
	await _close()


## A future delivery must stay in the field until its own order arrives. This
## is a real thumb path: before the fix, one early tomato made the second order
## impossible because `_load_order()` cleared the count but not the picked crop.
func _later_order_crops_wait_for_their_turn() -> void:
	await _open("harvest_08")
	var tomato := _find_any("tomato")
	_ok(tomato != null, "丰收庆典 has tomatoes for its second order")
	if tomato == null:
		await _close()
		return
	var strip: Control = _level.get("_order_strip")
	_ok(strip != null and strip.visible and strip.get_child_count() == 3,
		"three deliveries get a visible three-step order route")
	_ok(not tomato.visible, "a second-order tomato is not touchable during order one")
	await _stroke(_move_for(tomato))
	_ok(not tomato.taken and _picked_total() == 0,
		"touching the hidden tomato does not consume or count it")

	# Complete the first delivery through the same two-touch path a child uses.
	await _fill_visible_delivery(["carrot", "strawberry"])

	_ok(int(_level.get("_order_index")) == 1,
		"filling the first delivery advances to the tomato order")
	_ok(tomato.visible and not tomato.taken,
		"the deferred tomato becomes available intact in its own order")
	await _close()


## The checkpoint is written after an order lands, never mid-order. Simulate
## exactly the interruption it protects against: deliver order one, close the
## scene, reload SaveManager, then open the level again. The garden snapshot is
## deliberately non-empty and full so an accidental write is visible instead
## of passing on a fresh, all-empty save.
func _a_completed_delivery_survives_a_real_reload() -> void:
	const TEST_NOW := 1_700_000_000
	GameClock.set_test_now(TEST_NOW, 0)
	_a_legacy_checkpoint_migrates_through_save_manager()
	_fresh()

	var farm: Dictionary = SaveManager.data["farm"]
	farm["warehouse_cap"] = 3
	farm["warehouse"] = {"carrot": 3}
	farm["harvest_basket"] = {"strawberry": 2}
	var plots: Array = farm["plots"]
	# Growth settlement stamps every plot it visits. Give even the untouched
	# beds the same fixed anchor so this checkpoint test detects challenge
	# writes, not the garden's ordinary clock bookkeeping.
	for i in range(plots.size()):
		var stable: Dictionary = plots[i]
		stable["last_updated_at"] = TEST_NOW
		plots[i] = stable
	var growing: Dictionary = plots[0]
	growing["state"] = Farm.GROWING
	growing["crop_id"] = "carrot"
	growing["growth_stage"] = 1
	growing["growth_progress"] = 0.25
	growing["planted_at"] = TEST_NOW
	growing["last_updated_at"] = TEST_NOW
	plots[0] = growing
	farm["plots"] = plots
	SaveManager.data["farm"] = farm
	SaveManager.data["farm_orders"] = {
		"active": [], "delivered": ["bear_carrots"]}
	SaveManager.save_game()
	# Establish the same post-load baseline a child has before entering the
	# challenge. Fixed time keeps ordinary garden growth out of this test.
	SaveManager.load_game()
	var garden_before := _garden_economy_snapshot()

	await _open_saved("harvest_08")
	await _fill_visible_delivery(["carrot", "strawberry"])
	var delivered_before: Dictionary = _level.get("_delivered").duplicate(true)
	_ok(int(_level.get("_order_index")) == 1,
		"filling the first celebration delivery advances before the interruption")
	var mark := SaveManager.get_harvest_checkpoint()
	_ok(str(mark.get("level_id", "")) == "harvest_08"
		and int(mark.get("order_index", -1)) == 1,
		"the landed delivery writes its next-order checkpoint to challenge state")
	_ok(not SaveManager.data["farm"].has("harvest_checkpoint"),
		"the live daily farm never receives the challenge checkpoint")
	_ok(_garden_economy_snapshot() == garden_before,
		"playing a harvest challenge does not alter barn, spill basket, plots or orders")
	await _close()

	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_ok(raw is Dictionary and (raw as Dictionary).get("harvest_checkpoint", {}) is Dictionary,
		"the checkpoint is on disk in the challenge branch")
	if raw is Dictionary:
		_ok(not (raw as Dictionary).get("farm", {}).has("harvest_checkpoint"),
			"the on-disk daily farm stays free of challenge checkpoint data")

	SaveManager.load_game()
	_ok(_same_harvest_checkpoint(SaveManager.get_harvest_checkpoint(), mark),
		"SaveManager reload keeps the next-order checkpoint")
	_ok(_garden_economy_snapshot() == garden_before,
		"SaveManager reload keeps daily barn, basket, plots and orders unchanged")

	await _open_saved("harvest_08")
	_ok(int(_level.get("_order_index")) == 1,
		"re-entering the challenge resumes at its second delivery")
	_ok((_level.get("_delivered") as Dictionary) == delivered_before,
		"re-entering keeps only the earlier delivered crops, not a free current order")
	var tomato := _find("", "tomato")
	_ok(tomato != null and tomato.visible,
		"the second delivery's tomato is available after the reload")
	_ok(_garden_economy_snapshot() == garden_before,
		"resuming the challenge still leaves all daily garden economy untouched")
	await _close()

	GameClock.clear_test_now()
	_fresh()


## The old build wrote this mark under `farm`. Exercise the public loader,
## rather than only calling `_migrate`, so a real saved child can cross the
## schema boundary before the new run below proves it keeps crossing reloads.
func _a_legacy_checkpoint_migrates_through_save_manager() -> void:
	_fresh()
	var legacy_mark := {"level_id": "harvest_07", "order_index": 1,
		"delivered": {"tomato": 3, "broccoli": 2}}
	SaveManager.data.erase("harvest_checkpoint")
	SaveManager.data["farm"]["harvest_checkpoint"] = legacy_mark.duplicate(true)
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(_same_harvest_checkpoint(
		SaveManager.get_harvest_checkpoint(), legacy_mark),
		"SaveManager.load_game migrates a legacy farm checkpoint")
	_ok(not SaveManager.data["farm"].has("harvest_checkpoint"),
		"legacy reload removes the checkpoint from the live daily farm")

	# A normal write after migration must leave the file at the new ownership
	# boundary too, so the next launch does not depend on the compatibility path.
	SaveManager.save_game()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_ok(raw is Dictionary and _same_harvest_checkpoint(
		(raw as Dictionary).get("harvest_checkpoint", {}), legacy_mark),
		"the migrated checkpoint is persisted in the challenge branch")
	if raw is Dictionary:
		_ok(not (raw as Dictionary).get("farm", {}).has("harvest_checkpoint"),
			"the persisted daily farm has no legacy checkpoint field")


## Open a level against the save the caller deliberately prepared. `_open()`
## creates a new child save, which is useful elsewhere but would erase the
## very checkpoint this regression is exercising.
func _open_saved(level_id: String) -> void:
	GameManager.current_level_id = level_id
	_level = load(
		"res://scenes/minigames/harvest_action/HarvestAction.tscn").instantiate()
	add_child(_level)
	for i in range(6):
		await get_tree().process_frame


func _garden_economy_snapshot() -> Dictionary:
	var farm: Dictionary = SaveManager.data.get("farm", {})
	return {
		"warehouse": (farm.get("warehouse", {}) as Dictionary).duplicate(true),
		"harvest_basket": (farm.get("harvest_basket", {}) as Dictionary).duplicate(true),
		"plots": (farm.get("plots", []) as Array).duplicate(true),
		"orders": (SaveManager.data.get("farm_orders", {}) as Dictionary).duplicate(true),
	}


## JSON returns all numbers as floats, while the live checkpoint is made of
## ints. Compare the actual checkpoint facts so an on-disk round trip is not
## mistaken for a missing delivery merely because `1` became `1.0`.
func _same_harvest_checkpoint(left: Dictionary, right: Dictionary) -> bool:
	if str(left.get("level_id", "")) != str(right.get("level_id", "")):
		return false
	if int(left.get("order_index", -1)) != int(right.get("order_index", -1)):
		return false
	var left_done: Dictionary = left.get("delivered", {})
	var right_done: Dictionary = right.get("delivered", {})
	if left_done.size() != right_done.size():
		return false
	for crop_id in left_done.keys():
		if int(left_done[crop_id]) != int(right_done.get(crop_id, -1)):
			return false
	return true


## The real, two-touch child path for every crop in the current delivery.
## Both the future-order and save/reload probes use it so neither gets a
## convenient test-only way to land an order.
func _fill_visible_delivery(crop_ids: Array) -> void:
	for crop_id in crop_ids:
		while true:
			var current := _find("", str(crop_id))
			if current == null:
				break
			await _stroke(_move_for(current))
			var held := _in_hand()
			_ok(held != null, "%s can be picked while its order is current" % crop_id)
			if held == null:
				break
			var basket: Node2D = _level.call("_destination_for", held)
			_ok(basket != null, "%s has a matching basket" % crop_id)
			if basket == null:
				break
			await _tap(basket.global_position)


## Help is part of the rule, not a decorative animation. Its destination must
## be the exact basket the same resolver accepts for both ordinary and starred
## crops.
func _the_help_points_to_the_matching_basket() -> void:
	await _open_at("harvest_07", 2)
	var tomato := _find("", "tomato")
	_ok(tomato != null, "多作物订单 starts with a tomato to sort")
	if tomato == null:
		await _close()
		return
	await _stroke(_move_for(tomato))
	var held := _in_hand()
	var veg: Node2D = _level.call("_destination_for", held)
	_ok(veg != null and veg.id == "veg", "tomato help resolves to the vegetable basket")
	if veg != null:
		_assert_help_points_at(veg, "tomato")
		await _tap(veg.global_position)

	_level.set("_order_index", 1)
	_level.call("_load_order")
	var golden := _find("", "golden_carrot", Maturity.GOLDEN)
	_ok(golden != null, "勇敢的第二单 shows its golden carrot")
	if golden != null:
		await _stroke(_move_for(golden))
		var gift: Node2D = _level.call("_destination_for", _in_hand())
		_ok(gift != null and gift.id == "gift",
			"golden-carrot help resolves to the gift basket before ordinary tags")
		if gift != null:
			_assert_help_points_at(gift, "golden carrot")
	await _close()


func _assert_help_points_at(expected: Node2D, crop_name: String) -> void:
	_level.call("_point_at_the_baskets")
	var guide := _level.get("_basket_pointer") as Node
	var steps: Variant = guide.get("_steps") if guide != null else []
	var pointed := Vector2.ZERO
	var route_path := PackedVector2Array()
	if steps is Array and not steps.is_empty():
		var step: Dictionary = steps[0]
		pointed = step.get("then", Vector2.ZERO)
		route_path = step.get("path", PackedVector2Array())
	var path_matches_step := not route_path.is_empty() \
		and pointed.distance_to(route_path[route_path.size() - 1]) < 0.5
	var endpoint_ok := _guide_point_points_into_basket(pointed, expected)
	if not endpoint_ok or not path_matches_step:
		print("help endpoint debug crop=%s guide=%s steps=%s path=%s pointed=%s" % [
			crop_name, str(guide), str(steps), str(route_path), str(pointed)])
	_ok(endpoint_ok and path_matches_step,
		"the help finger points %s into its matching basket mouth" % crop_name)
	_ok(_level.call("_basket_for", expected.global_position) == expected,
		"the matching basket keeps its original hit-centre resolver")
	if guide != null and guide.has_method("skip"):
		guide.call("skip")


func _guide_endpoint_points_into_basket(trace: Line2D, basket: Node2D) -> bool:
	if trace == null or trace.points.size() < 2 or basket == null:
		print("guide endpoint missing trace/basket trace=%s basket=%s" % [
			str(trace), str(basket)])
		return false
	return _guide_point_points_into_basket(
		trace.points[trace.points.size() - 1], basket)


func _guide_point_points_into_basket(point: Vector2, basket: Node2D) -> bool:
	if basket == null:
		return false
	var art := basket.get_node_or_null("HarvestBasket3DArt") as TextureRect
	var sample := basket.get("_label") as Control
	if art == null or sample == null or art.texture == null:
		print("guide endpoint missing basket visual basket=%s art=%s sample=%s texture=%s" % [
			basket.id, str(art), str(sample), str(art.texture) if art != null else "none"])
		return false
	var basket_bounds: Rect2 = _level.call("_world_art_bounds", art)
	var sample_bounds := sample.get_global_rect()
	var inside_art := basket_bounds.has_point(point)
	var above_sample := point.y < sample_bounds.position.y
	var clear_of_center := point.distance_to(basket.global_position) > 30.0
	var result := inside_art and above_sample and clear_of_center
	if not result:
		print("guide endpoint debug basket=%s point=%s center=%s art=%s sample=%s size=%s checks=%s/%s/%s" % [
			basket.id, str(point), str(basket.global_position), str(basket_bounds),
			str(sample_bounds), str(basket.get("_size")), str(inside_art),
			str(above_sample), str(clear_of_center)])
	return result


## An unripe one shakes its head, and that is all it does.
func _unripe_is_refused_and_costs_nothing() -> void:
	await _open("harvest_02")
	var green := _find(Gesture.TAP, "", Maturity.UNRIPE)
	_ok(green != null, "草莓红了吗 has unripe ones on the plant")
	if green == null:
		await _close()
		return
	await _stroke(_move_for(green))
	_ok(_in_hand() == null, "an unripe one does not come off in his hand")
	_ok(_picked_total() == 0, "and it is not counted")
	_ok(is_instance_valid(green) and not green.taken,
		"and it is still there to come back to when it is red")
	await _close()


## Holding something and touching bare earth is not a mistake.
##
## He may have been reaching for another crop, or simply missed. Nothing is
## said, nothing is lost, and what he gets is the answer to the question he was
## actually asking -- a finger pointing at where the thing in his hand goes.
func _a_touch_on_nothing_while_holding_is_not_a_mistake() -> void:
	await _open("harvest_07")
	var target := _find(Gesture.TAP)
	if target == null:
		await _close()
		return
	await _stroke(_move_for(target))
	var held := _in_hand()
	if held == null:
		await _close()
		return
	await _tap(_empty_ground())
	_ok(_in_hand() == held, "touching bare earth does not drop what he is holding")
	_ok(_picked_total() == 0, "and does not count it as put away")
	await _close()


## Stuck three times: the game does the hard half and leaves him the choice.
##
## This template used to answer all three levels of help with the same finger
## animation -- the third step was one line, `_show_the_move()`, and a child who
## was stuck got shown the same thing three times. Picking is the hard half of a
## sorting level; which basket it belongs in is the half worth having.
func _the_third_hint_picks_it_but_does_not_choose() -> void:
	await _open("harvest_07")
	_ok(_in_hand() == null, "nothing is in his hand to begin with")
	_level.call("_do_the_hard_part")
	for i in range(4):
		await get_tree().process_frame
	_ok(_in_hand() != null,
		"the third level of help takes one off the plant for him")
	_ok(_picked_total() == 0,
		"...and stops there -- which basket it goes in is still his to choose")
	await _close()

	# With one basket, picking IS the level, so it must NOT do it for him.
	await _open("harvest_01")
	_level.call("_do_the_hard_part")
	for i in range(4):
		await get_tree().process_frame
	_ok(_picked_total() == 0,
		"with one basket the third level of help does not finish the level for him")
	await _close()


## A pumpkin is easier to hit than a strawberry, because it is bigger.
##
## harvest_crops.json has said so from the beginning -- touch_tolerance runs
## from 74 for a berry to 96 for a pumpkin -- and for months nothing read it.
## Every target on every level used the same 78, so the data was a description
## of a game that was not being played.
##
## Checked against the crops actually on the field rather than against numbers
## typed in here: the assertion is "the catalogue is obeyed", not "a pumpkin is
## 96", and retuning the catalogue must not turn this red.
func _a_big_crop_is_easier_to_hit_than_a_small_one() -> void:
	await _open("harvest_08")
	var seen := {}
	for t in _targets():
		if not is_instance_valid(t):
			continue
		var want: float = float(t.crop.get("touch_tolerance", 0.0))
		if want <= 0.0:
			continue
		seen[str(t.crop.get("id", ""))] = [want, t.radius]
	_ok(seen.size() >= 2, "丰收庆典 has more than one kind of crop on the ground")

	# Every target's reach is in proportion to what its crop asked for.
	var ratios: Array = []
	for crop_id in seen.keys():
		var pair: Array = seen[crop_id]
		ratios.append(float(pair[1]) / float(pair[0]))
	var spread := 0.0
	for r in ratios:
		spread = maxf(spread, absf(r - float(ratios[0])))
	_ok(spread < 0.02,
		"every crop's reach is its own touch_tolerance times the same difficulty step")

	# ...and crops that asked for different numbers really did get different
	# reaches, or the check above would pass on a field where they all match.
	var wants: Array = []
	var reaches: Array = []
	for crop_id in seen.keys():
		wants.append(float(seen[crop_id][0]))
		reaches.append(float(seen[crop_id][1]))
	wants.sort()
	reaches.sort()
	_ok(wants[wants.size() - 1] > wants[0],
		"and this level really does mix a big crop with a small one")
	_ok(reaches[reaches.size() - 1] > reaches[0] + 1.0,
		"so the big one ends up with a bigger reach on screen, not the same one")
	await _close()


## No two things on any bed are closer together than a thumb wanders.
##
## The layout used to throw sixty darts at the bed and, if none of them cleared
## the spacing it wanted, keep the roomiest miss -- however bad. On 丰收庆典,
## eighteen things on a strip 796 by 176, that left two of them 57px apart:
## closer than a six-year-old can aim, so "I meant the other one" stopped being
## bad luck and became the layout's fault. Nothing said so, because a crowded
## field is not an error, it just quietly costs him picks.
##
## Every level, both shapes -- the bed is a fraction of the screen and a 4:3
## tablet has half as much again, so the shape that fails is always 16:9.
func _nothing_is_planted_closer_than_a_thumb() -> void:
	var floor_px := 92.0            # harvest_action.THUMB_APART
	for level in GameData.get_levels_for_mode("harvest"):
		var level_id := str(level.get("id", ""))
		await _open(level_id)
		var targets := _targets()
		var closest := 1e9
		var pair := ""
		for i in range(targets.size()):
			for j in range(i + 1, targets.size()):
				var gap: float = targets[i].global_position.distance_to(
					targets[j].global_position)
				if gap < closest:
					closest = gap
					pair = "%s/%s" % [str(targets[i].crop.get("id", "")),
						str(targets[j].crop.get("id", ""))]
		if targets.size() < 2:
			await _close()
			continue
		_ok(closest >= floor_px - 0.5,
			"%s: the closest two things on the bed are %.0fpx apart (%s), floor is %.0f"
				% [level_id, closest, pair, floor_px])
		_assert_crop_art_layout(level_id, targets)
		await _close()


## The art can be smaller than the input circle, but each visible crop must
## still answer at its centre and on its own side of a neighbour's midpoint.
func _assert_crop_art_layout(level_id: String, targets: Array) -> void:
	if level_id == "harvest_08":
		_ok(targets.size() == 18, "the celebration retains all 18 targets across orders")
	var config: Dictionary = _level.level_data.get("config", {})
	var box: Rect2 = _level.call("_planting_bounds", config)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var station_left := view.x
	for basket in _baskets():
		station_left = minf(station_left, basket.position.x - float(basket.get("_size")) * 0.64)
	for target in targets:
		_ok(box.grow(0.5).has_point(target.position),
			"%s: crop centre is inside its final planting rectangle" % level_id)
		_ok(is_equal_approx(target.radius, float(_level.call("_reach", target.crop))),
			"%s: visual scale preserves the crop touch radius" % level_id)
		var mound: CanvasItem = target.get_meta("visual_mound", null) as CanvasItem
		_ok(mound != null and mound.visible == target.visible,
			"%s: contact patch follows the current order visibility" % level_id)
		if _baskets().size() >= 3:
			_ok(target.position.x + 64.0 + 14.0 <= station_left + 0.5,
				"%s: crop footprint clears the three basket station" % level_id)
		if not target.visible:
			continue
		_ok(_level.call("_nearest", target.global_position) == target,
			"%s: a visible crop answers at its centre" % level_id)
		var neighbour: Node2D = null
		var closest := INF
		for other in targets:
			if other == target or not other.visible:
				continue
			var gap: float = target.position.distance_to(other.position)
			if gap < closest:
				closest = gap
				neighbour = other
		if neighbour != null:
			var edge: Vector2 = target.global_position.lerp(neighbour.global_position, 0.4)
			if edge.distance_to(target.global_position) <= target.radius:
				_ok(_level.call("_nearest", edge) == target,
					"%s: the crop side of a midpoint answers to that crop" % level_id)
	if level_id == "harvest_08":
		_assert_celebration_row_balance(targets, view)


## The multi-order celebration must use all four tablet rows without disturbing
## its established three-row widescreen ownership map. Check each order against
## the actual target visibility, including the persistent clutter stone.
func _assert_celebration_row_balance(targets: Array, view: Vector2) -> void:
	var wide := view.x / maxf(view.y, 1.0) >= 1.55
	var expected_by_phase: Array = []
	if wide:
		expected_by_phase = [[1, 3, 4], [2, 3, 1], [3, 2, 0]]
	else:
		expected_by_phase = [[2, 2, 2, 2], [2, 1, 2, 1], [1, 1, 2, 1]]
	var orders: Array = _level.get("_orders")
	_ok(orders.size() == expected_by_phase.size(),
		"harvest_08 retains three measured order phases")
	for phase in range(mini(orders.size(), expected_by_phase.size())):
		if int(_level.get("_order_index")) != phase:
			_level.set("_order_index", phase)
			_level.call("_load_order")
		var actual := _visible_row_counts(targets)
		var expected: Array = expected_by_phase[phase]
		_ok(actual == expected,
			"harvest_08 phase %d visible rows are %s (expected %s)"
			% [phase + 1, str(actual), str(expected)])


func _visible_row_counts(targets: Array) -> Array[int]:
	var ordered: Array[int] = []
	for index in range(targets.size()):
		ordered.append(index)
	ordered.sort_custom(func(a: int, b: int) -> bool:
			return (targets[a] as Node2D).position.y \
				< (targets[b] as Node2D).position.y)
	var row_ids: Array[int] = []
	row_ids.resize(targets.size())
	var row_id := -1
	var previous_y := -INF
	for index in ordered:
		var target := targets[index] as Node2D
		if row_id < 0 or target.position.y - previous_y \
				> HarvestAction.VISUAL_ROW_BALANCE_BAND:
			row_id += 1
		row_ids[index] = row_id
		previous_y = target.position.y
	var counts: Array[int] = []
	counts.resize(row_id + 1)
	counts.fill(0)
	for index in range(targets.size()):
		if (targets[index] as Node2D).visible:
			counts[row_ids[index]] += 1
	return counts


## A stone is moved out of the way. It is not picked, not counted, not sorted.
func _clutter_is_moved_not_collected() -> void:
	await _open("harvest_04")
	var stone: Node2D = null
	for t in _targets():
		if is_instance_valid(t) and "clutter" in t.crop.get("tags", []):
			stone = t
			break
	_ok(stone != null, "土豆在哪里 has stones in the way")
	if stone == null:
		await _close()
		return
	await _stroke(_move_for(stone))
	_ok(_picked_total() == 0, "a stone is never counted towards the order")
	_ok(_in_hand() == null, "and it never ends up in his hand waiting for a basket")
	await _close()


## The first pick of a sorting run teaches the loop, once.
##
## The waiting ring on the right basket is the permanent visual answer, but a
## ring alone does not say "now carry it there" the first time a child holds
## something. So the first hold also speaks the two-basket line and points the
## Tutorial finger at the matching basket -- and the second hold does neither,
## because help that narrates every strawberry is wallpaper.
func _the_first_pick_teaches_the_loop() -> void:
	await _open("harvest_02")
	_ok(not bool(_level.get("_sort_hinted")), "nothing taught before the first pick")
	var first := _find(Gesture.TAP, "strawberry")
	_ok(first != null, "there is a strawberry for the first lesson")
	if first == null:
		await _close()
		return
	await _stroke(_move_for(first))
	var held := _in_hand()
	_ok(held != null, "the first strawberry comes off in his hand")
	_ok(bool(_level.get("_sort_hinted")), "the first hold marks the loop taught")
	# The demo makes way instead of stacking: still exactly one finger, and
	# it is the pointer, not the lesson.
	_ok(_guide_count() == 1,
		"the first hold trades the demo for one pointer, not two fingers")
	var want: Node2D = _level.call("_destination_for", held)
	if want != null:
		_assert_help_points_at(want, "first strawberry")
		await _tap(want.global_position)
	# Second pick: the ring still answers, the finger stays away.
	var second := _find(Gesture.TAP, "strawberry")
	if second == null:
		await _close()
		return
	var guides_after_first := _guide_count()
	await _stroke(_move_for(second))
	_ok(_in_hand() != null, "a second strawberry still comes off in his hand")
	_ok(_guide_count() == guides_after_first,
		"the second hold teaches nothing new -- the ring is the answer now")
	await _close()


func _guide_count() -> int:
	var field: Node = _level.get("_field")
	if field == null:
		return -1
	return _live_guides().size()


## The streak counts clean picks and forgets any refuse, silently.
##
## Three in a row is the small cheer, every fifth the big one -- the mapping
## itself is asserted without a screen in harvest_probe. What is asked here,
## with a thumb: the counter climbs on real picks and a single unripe tap
## quiets it back to zero, with the pick uncounted and the crop still there.
func _the_streak_cheers_and_resets() -> void:
	await _open("harvest_01")
	for want in [1, 2, 3]:
		var carrot := _find(Gesture.DRAG, "carrot")
		_ok(carrot != null, "there is a carrot for streak %d" % want)
		if carrot == null:
			await _close()
			return
		await _stroke(_move_for(carrot))
		_ok(int(_level.get("_streak")) == want,
			"pick %d in a row raises the streak to %d" % [want, want])
	await _close()

	await _open("harvest_02")
	var berry := _find(Gesture.TAP, "strawberry")
	_ok(berry != null, "there is a strawberry to start a streak")
	if berry == null:
		await _close()
		return
	await _stroke(_move_for(berry))
	var held := _in_hand()
	if held != null:
		var basket: Node2D = _level.call("_destination_for", held)
		await _tap(basket.global_position)
	_ok(int(_level.get("_streak")) == 1,
		"a sorted pick counts towards the streak too")
	var green := _find(Gesture.TAP, "", Maturity.UNRIPE)
	_ok(green != null, "there is an unripe one to refuse")
	if green == null:
		await _close()
		return
	await _stroke(_move_for(green))
	_ok(int(_level.get("_streak")) == 0,
		"one unripe tap quiets the streak back to zero")
	_ok(_picked_total() == 1,
		"and the refuse itself counts nothing and takes nothing back")
	await _close()


## An order from somebody has a face; an order from nobody does not.
##
## customer_icon is optional per level. A level naming one shows that face at
## the head of the tally; a level naming none leaves the tally exactly where
## it always sat, with nothing blank holding its place.
func _the_customer_watches_the_order() -> void:
	await _open("harvest_02")
	_ok(_customer_face() != null,
		"草莓红了吗 names a customer, so a face watches the order")
	await _close()
	await _open("harvest_05")
	_ok(_customer_face() == null,
		"果园摇一摇 names none, so the tally sits as it always did")
	await _close()


func _customer_face() -> Node:
	var tally: Node = _level.get("_tally")
	if tally == null:
		return null
	var row: Node = tally.get_parent()
	if row == null:
		return null
	return row.get_node_or_null("OrderCustomer")


## One finger on screen at a time, whatever the help is doing.
##
## The entry lesson demonstrates the gesture -- then the child picks faster
## than the demo and the held crop ends up wearing its own lesson while a
## second finger points at the basket. From that moment the demo is about the
## half just finished, so taking in hand skips it, and the second level of
## help while holding points at the baskets instead of demonstrating.
func _one_finger_at_a_time() -> void:
	await _open("harvest_02")
	_ok(_live_guides().size() >= 1,
		"the entry lesson demonstrates the move")
	var berry := _find(Gesture.TAP, "strawberry")
	_ok(berry != null, "there is a strawberry to pick mid-demo")
	if berry == null:
		await _close()
		return
	await _stroke(_move_for(berry))
	var held := _in_hand()
	_ok(held != null, "the strawberry comes off in his hand")
	var guides := _live_guides()
	_ok(guides.size() == 1,
		"holding quiets the demo -- exactly one finger remains")
	if held != null and guides.size() == 1:
		var want: Node2D = _level.call("_destination_for", held)
		_ok(want != null and _guide_point_points_into_basket(
			_guide_then(guides[0]), want)
			and _level.call("_basket_for", want.global_position) == want,
			"and it points into the matching basket, not the plant")
	var before := _live_guides().size()
	_level.call("_show_the_move")
	for i in range(6):
		await get_tree().process_frame
	var after := _live_guides()
	_ok(before == 1 and after.size() == 1,
		"help while holding replaces its basket finger instead of stacking another")
	if held != null and after.size() == 1:
		var want2: Node2D = _level.call("_destination_for", held)
		_ok(want2 != null and _guide_point_points_into_basket(
			_guide_then(after[0]), want2)
			and _level.call("_basket_for", want2.global_position) == want2,
			"and that finger also answers which basket")
		if want2 != null:
			await _tap(want2.global_position)
			for i in range(3):
				await get_tree().process_frame
			_ok(_live_guides().is_empty(),
				"putting the crop away clears the now-stale basket finger")
	await _close()


func _live_guides() -> Array:
	var out: Array = []
	var field: Node = _level.get("_field")
	if field == null:
		return out
	for child in field.get_children():
		if child.get("_steps") != null:
			out.append(child)
	return out


func _guide_then(guide: Node) -> Vector2:
	var steps: Array = guide.get("_steps")
	if steps.is_empty():
		return Vector2.INF
	return steps[0].get("then", Vector2.INF)


func _same_path(actual: PackedVector2Array, expected: PackedVector2Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in actual.size():
		if actual[i].distance_to(expected[i]) > 0.5:
			return false
	return true


## A landed order is said once in pictures before the next one arrives.
##
## The fresh tally underneath is the permanent record; the big check that
## pops and fades with it is the moment itself. The last order of a level
## gets the result screen instead, so this is asked of a celebration middle.
func _the_landed_order_gets_its_check() -> void:
	await _open("harvest_08")
	await _fill_visible_delivery(["carrot", "strawberry"])
	_ok(int(_level.get("_order_index")) == 1,
		"the first celebration delivery lands")
	var hud: Node = _level.get("_hud")
	var party: Node = hud.get_node_or_null("OrderDone") \
		if hud != null else null
	_ok(party != null, "the landed order gets its big check")
	await _close()


## The order HUD has to be readable from across the room, not just present.
##
## The tally used to be 62px pictures with 26pt counts and the multi-order
## route 48x42 chips -- correct numbers a child could not see. This holds the
## bigger sizes the redesign promises: 80px tally art, 32pt counts, 64x56
## route chips.
func _the_order_hud_is_legible() -> void:
	await _open("harvest_07")
	var tally: Control = _level.get("_tally")
	_ok(tally != null, "多作物订单 shows what the order wants as pictures")
	if tally != null:
		for box in tally.get_children():
			var art: Control = box.get_child(0) if box.get_child_count() > 0 else null
			_ok(art != null and art.size.x >= 79.0,
				"tally pictures are big enough to recognise (%.0f)" % (art.size.x if art != null else -1.0))
			var count: Label = box.get_child(1) if box.get_child_count() > 1 else null
			_ok(count != null and count.get_theme_font_size("font_size") >= 32,
				"tally counts are big enough to read")
	var strip: Control = _level.get("_order_strip")
	_ok(strip != null and strip.visible, "two deliveries get a visible route")
	if strip != null and strip.visible:
		for chip in strip.get_children():
			_ok((chip as Control).custom_minimum_size.x >= 64.0,
				"route chips are big enough for a thumb")
	await _close()
