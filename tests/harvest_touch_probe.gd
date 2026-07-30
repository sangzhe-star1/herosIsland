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
	await _the_baskets_are_telling_apart()
	await _a_wrong_basket_costs_him_nothing()
	await _only_the_starred_one_goes_in_the_gift_basket()
	await _unripe_is_refused_and_costs_nothing()
	await _a_touch_on_nothing_while_holding_is_not_a_mistake()
	await _the_third_hint_picks_it_but_does_not_choose()
	await _clutter_is_moved_not_collected()
	await _a_big_crop_is_easier_to_hit_than_a_small_one()
	await _nothing_is_planted_closer_than_a_thumb()


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
		if not is_instance_valid(t) or t.taken:
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
	await _open("harvest_07")
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

	# ...and the starred one is refused everywhere else.
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
	for n in range(1, 9):
		var level_id := "harvest_%02d" % n
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
