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
const Farm := preload("res://scripts/garden/farm_save.gd")

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
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _run_on_a(window: Vector2i) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	print("-- window %s -> viewport %s"
		% [str(window), str(get_viewport().get_visible_rect().size)])

	await _one_basket_needs_one_move()
	await _every_gesture_reaches_the_hand()
	await _the_lesson_starts_on_its_named_gesture()
	await _the_baskets_are_telling_apart()
	await _the_matching_basket_stays_marked_without_motion()
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
	_fresh()
	SaveManager.set_setting("difficulty", tier)
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
	_fresh()
	GameManager.current_level_id = level_id
	_level = load(
		"res://scenes/minigames/harvest_action/HarvestAction.tscn").instantiate()
	add_child(_level)
	for i in range(6):
		await get_tree().process_frame


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


func _tap(at: Vector2) -> void:
	await _stroke([at, at])


func _line(from: Vector2, to: Vector2, steps: int) -> Array:
	var out: Array = []
	for i in range(steps + 1):
		out.append(from.lerp(to, float(i) / float(steps)))
	return out


## The move a child makes for this crop, ending where it naturally ends -- ON
## the plant, never over at the baskets. That is the point: the gesture is the
## picking and nothing else.
func _move_for(target: Node2D) -> Array:
	var at: Vector2 = target.global_position
	var params: Dictionary = target.crop.get("gesture_params", {})
	match str(target.crop.get("recogniser", "")):
		Gesture.TAP:
			return [at, at]
		Gesture.DRAG:
			var dir := Vector2(float(params.get("direction_x", 0.0)),
				float(params.get("direction_y", -1.0))).normalized()
			var far: float = float(params.get("distance", 90.0)) + 24.0
			return _line(at, at + dir * far, 7)
		Gesture.LINE:
			var half: float = float(params.get("line_half_width", 74.0))
			return _line(at + Vector2(-minf(30.0, half * 0.4), -46.0),
				at + Vector2(minf(30.0, half * 0.4), 46.0), 7)
		Gesture.SWEEP:
			var leg: float = float(params.get("leg", 60.0)) + 26.0
			var turns: int = int(params.get("turns", 3)) + 1
			var path: Array = [at]
			var here := at
			for i in range(turns + 1):
				var next := here + Vector2(leg if i % 2 == 0 else -leg, 0.0)
				path.append_array(_line(here, next, 3))
				here = next
			return path
		Gesture.TWIST:
			var turn: float = float(params.get("turn", 90.0))
			var steps := int(ceil(turn / 20.0)) + 3
			var path: Array = []
			for i in range(steps + 1):
				var a: float = TAU * (turn + 60.0) / 360.0 * float(i) / float(steps)
				path.append(at + Vector2(cos(a), sin(a)) * 62.0)
			return path
	return [at, at]


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


## Reduce-motion makes the page quieter, never less understandable. After a
## real pick, the same shared destination resolver must leave exactly one
## basket visibly marked even though the optional breathing tween is absent.
func _the_matching_basket_stays_marked_without_motion() -> void:
	await _open("harvest_02")
	var was: Variant = SaveManager.get_setting("reduce_motion", false)
	SaveManager.set_setting("reduce_motion", true)
	var berry := _find(Gesture.TAP, "strawberry")
	_ok(berry != null, "草莓红了吗 has a strawberry for the still target cue")
	if berry == null:
		SaveManager.set_setting("reduce_motion", was)
		await _close()
		return
	await _stroke(_move_for(berry))
	var held := _in_hand()
	_ok(held != null, "the strawberry is held before its basket is marked")
	if held == null:
		SaveManager.set_setting("reduce_motion", was)
		await _close()
		return
	var target: Node2D = _level.call("_destination_for", held)
	_ok(target != null and target.id == "fruit",
		"the shared target resolver chooses the fruit basket for the still cue")
	if target == null:
		SaveManager.set_setting("reduce_motion", was)
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
	await get_tree().create_timer(0.65).timeout
	_ok(target.scale.distance_to(Vector2.ONE) < 0.001,
		"the low-motion answer remains still after time passes")
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
	_ok(not cue.visible and _in_hand() == null,
		"the static answer ring clears after the crop is put away")
	SaveManager.set_setting("reduce_motion", was)
	await _close()


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
	var field: Node = _level.get("_field")
	var guide: Node = field.get_child(field.get_child_count() - 1) \
		if field != null and field.get_child_count() > 0 else null
	var steps: Variant = guide.get("_steps") if guide != null else []
	var pointed := Vector2.ZERO
	if steps is Array and not steps.is_empty():
		var step: Dictionary = steps[0]
		pointed = step.get("then", Vector2.ZERO)
	_ok(pointed.distance_to(expected.global_position) < 0.5,
		"the help finger points %s at its matching basket" % crop_name)
	if guide != null and guide.has_method("skip"):
		guide.call("skip")


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
		await _close()


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
		_ok(_guide_then(guides[0]).distance_to(want.global_position) < 0.5,
			"and it points at the matching basket, not the plant")
	var before := _live_guides().size()
	_level.call("_show_the_move")
	for i in range(6):
		await get_tree().process_frame
	var after := _live_guides()
	_ok(after.size() == before + 1,
		"help while holding points instead of demonstrating")
	if held != null and after.size() == before + 1:
		var want2: Node2D = _level.call("_destination_for", held)
		_ok(_guide_then(after[after.size() - 1]).distance_to(
			want2.global_position) < 0.5,
			"and that finger also answers which basket")
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
