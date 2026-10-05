extends Node
## 丰收行动, in numbers.
##
## The gestures are the whole of this template, and a gesture is a TOLERANCE:
## how far off vertical a pull can be and still count, how far a finger has to
## travel, how many reversals make a dig. Those are numbers, and a number that
## nobody asserts is a number that drifts until a six-year-old cannot pull a
## carrot up and nobody knows why.
##
## Everything here runs headless against pure functions. The same gestures are
## pushed through the real input pipeline in harvest_touch_probe.gd -- these two
## answer different questions, and both have to be asked: "is 34 degrees inside
## the fan" is arithmetic, and "does a real InputEventScreenDrag reach the fan
## at all" is not.

const Gesture := preload("res://scripts/harvest/gesture.gd")
const Maturity := preload("res://scripts/harvest/maturity.gd")
const Crops := preload("res://scripts/harvest/harvest_crops.gd")
const HarvestAction := preload("res://scripts/minigames/harvest_action.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const HarvestRoute := preload("res://scripts/harvest/harvest_route.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== harvest probe ===")
	await get_tree().process_frame

	_the_catalogue_is_readable()
	_balanced_grid_layout_is_safe_at_both_aspects()
	_visual_slot_row_balance_cost_is_phase_aware()
	_the_taught_path_obeys_the_real_gesture()
	_the_still_route_keeps_instruction_data()
	_the_basket_hint_routes_around_crops()
	_a_pull_up_has_a_fan_not_a_line()
	_a_drag_has_to_go_far_enough()
	_a_tap_is_not_a_short_drag()
	_a_twist_goes_either_way()
	_an_unknown_gesture_refuses()
	_unripe_is_not_pickable()
	_ripeness_is_said_more_than_one_way()
	_the_cheer_is_sparse()
	_every_level_can_actually_be_finished()
	_every_difficulty_has_whole_harvests_for_each_order()
	_the_relay_customer_follows_the_current_order()
	_clutter_is_never_asked_for()
	_an_exception_names_a_basket_that_exists()
	_every_pickable_target_has_one_sorting_home()
	_the_checkpoint_is_challenge_state_not_farm_state()
	_the_challenge_is_off_the_island_path()

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("HARVEST PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	await ProbeLifecycle.finish(self, 1 if _failures.size() > 0 else 0)


func _the_catalogue_is_readable() -> void:
	_ok(GameData.harvest_crops.size() > 0, "the harvest catalogue loaded")
	_ok(not Crops.get_crop("carrot").is_empty(), "the carrot is in it")
	_ok(Crops.get_crop("dragonfruit").is_empty(),
		"and a crop nobody has added answers with nothing, not with null")
	for crop in GameData.harvest_crops:
		var recogniser := str(crop.get("recogniser", ""))
		_ok(recogniser in Gesture.ALL,
			"%s asks for recogniser '%s', which nothing implements -- it would "
			% [str(crop.get("id", "?")), recogniser] + "be un-pickable")


## The screen-relative crop band must clear the order HUD's largest target
## reach, and both aspect-specific grids must preserve the thumb spacing floor.
func _balanced_grid_layout_is_safe_at_both_aspects() -> void:
	var layouts := [
		{"size": Vector2(1280.0, 720.0), "width": 772.0,
			"counts": {5: 2, 6: 2, 8: 2, 9: 2, 11: 2, 12: 2, 14: 3, 18: 3}},
		{"size": Vector2(1280.0, 960.0), "width": 751.0,
			"counts": {5: 2, 6: 2, 8: 3, 9: 3, 11: 3, 12: 3, 14: 4, 18: 4}},
	]
	for layout in layouts:
		var view: Vector2 = layout["size"]
		var safe := HarvestAction._safe_meadow_y_bounds(view.y, 96.0)
		var hud_clearance := HarvestAction.HARVEST_HUD_SAFE_BOTTOM + 96.0 \
			+ HarvestAction.HARVEST_HUD_TOUCH_MARGIN
		_ok(safe.x + 0.01 >= maxf(view.y * 0.34, hud_clearance),
			"the meadow top clears the order card and maximum crop hit radius")
		_ok(safe.y <= view.y * 0.81 + 0.01,
			"the meadow band stays above the basket row")
		var box := Rect2(Vector2(102.0, safe.x),
			Vector2(float(layout["width"]), maxf(safe.y - safe.x - 8.0, 0.0)))
		for key in layout["counts"]:
			var count := int(key)
			var expected_rows := int(layout["counts"][key])
			var rows := HarvestAction._preferred_grid_rows(count,
				view.x / view.y)
			var fitted := HarvestAction._fit_grid_shape(count, box, 176.0, rows)
			rows = int(fitted["rows"])
			var apart := float(fitted["apart"])
			var row_counts := HarvestAction._balanced_row_counts(count, rows)
			var points: Array = HarvestAction._balanced_grid_points(
				count, box, apart, rows)
			var fewest_in_row := count
			var most_in_row := 0
			for row_count in row_counts:
				fewest_in_row = mini(fewest_in_row, int(row_count))
				most_in_row = maxi(most_in_row, int(row_count))
			_ok(rows == expected_rows,
				"%d targets use the balanced %d-row layout at %dx%d"
				% [count, expected_rows, int(view.x), int(view.y)])
			_ok(apart >= HarvestAction.THUMB_APART
				and HarvestAction._grid_shape_holds(count, box, apart, rows),
				"%d targets fit their aspect-specific band at safe spacing" % count)
			_ok(points.size() == count and most_in_row - fewest_in_row <= 1,
				"%d targets split evenly across %d rows" % [count, rows])
			if rows >= 3:
				for row_index in range(int(rows / 2)):
					_ok(row_counts[row_index] == row_counts[rows - row_index - 1],
						"%d-target outer rows stay visually balanced" % count)
			for point_value in points:
				var point: Vector2 = point_value
				_ok(box.has_point(point),
					"%d-target grid centres stay inside the safe meadow band" % count)
				_ok(point.y - 96.0 >= HarvestAction.HARVEST_HUD_SAFE_BOTTOM
					+ HarvestAction.HARVEST_HUD_TOUCH_MARGIN - 0.01,
					"%d-target hit area stays below the order HUD" % count)
			for i in range(points.size()):
				for j in range(i + 1, points.size()):
					var point_a: Vector2 = points[i]
					var point_b: Vector2 = points[j]
					_ok(point_a.distance_to(point_b)
						>= HarvestAction.THUMB_APART - 0.01,
						"%d-target grid keeps every pair at thumb-safe spacing" % count)


## The visual ownership cost only separates targets that coexist in the same
## order, and this A/B correction is scoped to harvest_08's four-row tablet map.
func _visual_slot_row_balance_cost_is_phase_aware() -> void:
	var action := HarvestAction.new()
	_ok(bool(action.call("_visual_row_balance_enabled", "harvest_08", 4)),
		"the measured celebration tablet grid enables its row-balance cost")
	_ok(not bool(action.call("_visual_row_balance_enabled", "harvest_08", 3)),
		"the measured three-row widescreen grid keeps its ownership map")
	_ok(not bool(action.call("_visual_row_balance_enabled", "harvest_02", 4)),
		"unreviewed four-row levels do not inherit the celebration correction")
	var four_row_points: Array = [
		Vector2(100.0, 10.0), Vector2(200.0, 20.0),
		Vector2(100.0, 150.0), Vector2(200.0, 160.0),
		Vector2(100.0, 290.0), Vector2(200.0, 300.0),
		Vector2(100.0, 430.0), Vector2(200.0, 440.0),
	]
	_ok(int(action.call("_visual_row_count", four_row_points)) == 4,
		"the tablet's jittered target coordinates resolve to four rows")
	_ok(int(action.call("_visual_row_count", four_row_points.slice(0, 6))) == 3,
		"the three-row layout is recognized independently")

	var items: Array = [[], [], []]
	var masks: Array = [[true, false, false], [true, false, false],
		[false, true, false]]
	var terms: Array = action.call("_visual_pair_terms", items, 3, masks, true)
	var same_row_cost: float = action.call("_visual_pair_cost", terms, 3, 0, 1,
		Vector2(100.0, 100.0), Vector2(300.0, 150.0))
	var cross_row_cost: float = action.call("_visual_pair_cost", terms, 3, 0, 1,
		Vector2(100.0, 100.0), Vector2(300.0, 180.0))
	var never_co_visible_cost: float = action.call("_visual_pair_cost", terms, 3, 0, 2,
		Vector2(100.0, 100.0), Vector2(300.0, 100.0))
	_ok(is_equal_approx(same_row_cost, HarvestAction.VISUAL_ROW_BALANCE_WEIGHT),
		"one pair co-visible in one phase incurs one row cost")
	_ok(is_zero_approx(cross_row_cost),
		"targets in different rows incur no row cost")
	_ok(is_zero_approx(never_co_visible_cost),
		"targets from disjoint orders are not counted as an overlap")
	var three_row_terms: Array = action.call("_visual_pair_terms", items, 3, masks,
		bool(action.call("_visual_row_balance_enabled", "harvest_08", 3)))
	var disabled_cost: float = action.call("_visual_pair_cost", three_row_terms, 3, 0, 1,
		Vector2(100.0, 100.0), Vector2(300.0, 100.0))
	_ok(is_zero_approx(disabled_cost),
		"three-row layouts keep the row-balance term disabled")
	action.free()


## The demonstration is an example that the same recogniser accepts, not a
## nearby arrow drawn by a second set of rules. Check every catalogue entry so
## a future parameter tune cannot quietly teach an impossible move.
func _the_taught_path_obeys_the_real_gesture() -> void:
	var centre := Vector2(640, 360)
	for crop in GameData.harvest_crops:
		var recogniser := str(crop.get("recogniser", ""))
		var params: Dictionary = crop.get("gesture_params", {})
		var path := Gesture.demo_path(recogniser, params, centre)
		var id := str(crop.get("id", "?"))
		_ok(not path.is_empty(), "%s has a visible teaching path" % id)
		_ok(Gesture.satisfied(recogniser, params, path, centre),
			"%s's teaching path is accepted by its actual %s recogniser" % [id, recogniser])
		if recogniser in [Gesture.LINE, Gesture.SWEEP, Gesture.TWIST]:
			_ok(path.size() > 2,
				"%s's %s lesson is a route, not a misleading straight arrow"
				% [id, recogniser])


## Reduced-motion lessons use the same route data. The presentation may stop
## moving, but it may not collapse a cut or sweep into a misleading arrow.
func _the_still_route_keeps_instruction_data() -> void:
	var look := Vector2(240, 180)
	var path := PackedVector2Array([look, Vector2(260, 230), Vector2(300, 285)])
	var shown := Tutorial.still_route(look, path[path.size() - 1], path)
	_ok(shown.size() == path.size() and shown[0] == path[0]
		and shown[shown.size() - 1] == path[path.size() - 1],
		"a still gesture lesson keeps the complete recogniser route")
	var point := Vector2(460, 310)
	var carry := Tutorial.still_route(look, point, PackedVector2Array())
	_ok(carry.size() == 2 and carry[0] == look and carry[1] == point,
		"a still basket lesson keeps its crop-to-basket line")
	_ok(Tutorial.still_route(look, look, PackedVector2Array()).is_empty(),
		"a still tap needs no invented travel line")


## The carry hint is a temporary teaching route. Its line and moving hand must
## stay clear of the crop silhouettes between a far target and its basket.
func _the_basket_hint_routes_around_crops() -> void:
	var start := Vector2(10.0, 52.0)
	var finish := Vector2(205.0, 52.0)
	var obstacles: Array = [
		Rect2(Vector2(56.0, 28.0), Vector2(20.0, 46.0)),
		Rect2(Vector2(116.0, 31.0), Vector2(22.0, 50.0)),
	]
	var route := HarvestRoute.avoid_rectangles(start, finish, obstacles, 12.0)
	_ok(route.size() > 2,
		"a basket hint detours when crops occupy the direct route")
	_ok(route[0] == start and route[route.size() - 1] == finish,
		"a detour still starts at the held crop and ends at its basket")
	for index in range(1, route.size()):
		_ok(HarvestRoute.segment_is_clear_of_rectangles(route[index - 1],
			route[index], obstacles, 12.0),
			"each basket hint segment clears every neighboring crop")
	var overlapping_obstacles: Array = [
		Rect2(Vector2(70.0, 20.0), Vector2(45.0, 60.0)),
		Rect2(Vector2(90.0, 34.0), Vector2(45.0, 60.0)),
	]
	var overlap_route := HarvestRoute.avoid_rectangles(start, finish,
		overlapping_obstacles, 12.0)
	_ok(overlap_route.size() == 1 or overlap_route.size() > 2,
		"overlapping crop silhouettes produce a clear detour or hide the route")
	for index in range(1, overlap_route.size()):
		_ok(HarvestRoute.segment_is_clear_of_rectangles(overlap_route[index - 1],
			overlap_route[index], overlapping_obstacles, 12.0),
			"an overlapping-crop detour clears the whole silhouette cluster")
	var bounds := Rect2(Vector2(24.0, 24.0), Vector2(240.0, 160.0))
	var bounded_route := HarvestRoute.avoid_rectangles(Vector2(40.0, 85.0),
		Vector2(250.0, 85.0),
		[Rect2(Vector2(100.0, 55.0), Vector2(60.0, 60.0))], 12.0, bounds)
	_ok(bounded_route.size() > 2,
		"a basket hint still finds an in-screen detour when the field has room")
	for point in bounded_route:
		_ok(bounds.has_point(point), "route waypoints stay inside the field margin")
	for index in range(1, bounded_route.size()):
		_ok(HarvestRoute.segment_is_clear_of_rectangles(bounded_route[index - 1],
			bounded_route[index], [Rect2(Vector2(100.0, 55.0),
			Vector2(60.0, 60.0))], 12.0),
			"an in-screen detour clears the target")
	var unobstructed := HarvestRoute.avoid_rectangles(start, finish, [], 12.0)
	_ok(unobstructed.size() == 2 and unobstructed[0] == start
		and unobstructed[1] == finish,
		"an open basket hint stays a direct route")


## Straight up the middle is not the only way to pull a carrot.
##
## The fan is +/- 35 degrees by default. Both edges are checked, and so is just
## outside both -- a tolerance asserted only from the inside is a tolerance that
## can quietly become 180 degrees.
func _a_pull_up_has_a_fan_not_a_line() -> void:
	var up := Vector2(0, -1)
	var from := Vector2(400, 400)

	for angle in [0.0, 20.0, 34.0, -34.0, -20.0]:
		var to: Vector2 = from + up.rotated(deg_to_rad(angle)) * 120.0
		_ok(Gesture.drag_ok(PackedVector2Array([from, to]), up, 90.0, 35.0),
			"a pull %.0f degrees off vertical still counts" % angle)

	for angle in [36.0, -36.0, 60.0, 120.0, 180.0]:
		var to: Vector2 = from + up.rotated(deg_to_rad(angle)) * 120.0
		_ok(not Gesture.drag_ok(PackedVector2Array([from, to]), up, 90.0, 35.0),
			"a pull %.0f degrees off vertical does not" % angle)

	# Wandering on the way does not matter; where it ENDS does. A child pulling
	# a carrot up does not pull it in a straight line.
	var wobbly := PackedVector2Array([from, from + Vector2(60, -20),
		from + Vector2(-50, -60), from + Vector2(4, -130)])
	_ok(Gesture.drag_ok(wobbly, up, 90.0, 35.0),
		"a wandering pull that ends up above counts -- the wander is not the move")


func _a_drag_has_to_go_far_enough() -> void:
	var up := Vector2(0, -1)
	var from := Vector2(400, 400)
	_ok(Gesture.drag_ok(PackedVector2Array([from, from + Vector2(0, -91)]),
		up, 90.0, 35.0), "91 px is far enough for a 90 px pull")
	_ok(not Gesture.drag_ok(PackedVector2Array([from, from + Vector2(0, -89)]),
		up, 90.0, 35.0), "89 px is not")
	_ok(not Gesture.drag_ok(PackedVector2Array([from]), up, 90.0, 35.0),
		"and a press that never moved is not a pull at all")


## The two must not overlap. A tap that counts as a tiny drag would pick a
## carrot without pulling it; a pull that counts as a tap would pick a
## strawberry by dragging past it.
func _a_tap_is_not_a_short_drag() -> void:
	var at := Vector2(300, 300)
	_ok(Gesture.tap_ok(PackedVector2Array([at, at + Vector2(6, 4)])),
		"a finger that wobbled six pixels still tapped")
	_ok(not Gesture.tap_ok(PackedVector2Array([at, at + Vector2(0, -120)])),
		"a finger that travelled 120 px did not tap")
	_ok(not Gesture.drag_ok(PackedVector2Array([at, at + Vector2(6, 4)]),
		Vector2(0, -1), 90.0, 35.0), "and that same wobble is not a pull either")


func _a_twist_goes_either_way() -> void:
	var centre := Vector2(500, 500)
	var clockwise := PackedVector2Array()
	var anti := PackedVector2Array()
	for i in range(13):
		var a: float = deg_to_rad(float(i) * 8.0)
		clockwise.append(centre + Vector2(cos(a), sin(a)) * 70.0)
		anti.append(centre + Vector2(cos(-a), sin(-a)) * 70.0)
	_ok(Gesture.twist_ok(clockwise, centre, 90.0), "96 degrees clockwise is a twist")
	_ok(Gesture.twist_ok(anti, centre, 90.0),
		"and so is 96 degrees the other way -- nobody is told they turned wrong")

	var wobble := PackedVector2Array()
	for i in range(30):
		var a: float = deg_to_rad(sin(float(i)) * 12.0)
		wobble.append(centre + Vector2(cos(a), sin(a)) * 70.0)
	_ok(not Gesture.twist_ok(wobble, centre, 90.0),
		"a finger shaking back and forth does not add up to a quarter turn")


## A recogniser nothing implements must REFUSE, never succeed.
##
## The safe direction, and not the obvious one: a `match` with no default would
## fall through, and in GDScript that returns null which is falsy -- but a
## default of `true` would make every unwritten gesture pick on any touch, which
## nobody would notice until a level shipped that plays itself.
func _an_unknown_gesture_refuses() -> void:
	var track := PackedVector2Array([Vector2(1, 1), Vector2(2, 2)])
	for name in ["", "memory_pick", "charge_then_cut", "nonsense"]:
		_ok(not Gesture.satisfied(name, {}, track, Vector2.ZERO),
			"recogniser '%s' is not implemented, so it refuses" % name)


func _unripe_is_not_pickable() -> void:
	_ok(Maturity.pickable(Maturity.READY), "a ready one can be picked")
	_ok(Maturity.pickable(Maturity.GOLDEN), "so can a golden one")
	_ok(not Maturity.pickable(Maturity.UNRIPE), "an unripe one cannot")
	_ok(not Maturity.pickable(Maturity.ALMOST), "nor an almost-ready one")
	# A word nothing answers to is treated as unripe, never as ready.
	_ok(not Maturity.pickable(Maturity.normalise("banana_flavoured")),
		"and a ripeness nobody has heard of is un-pickable, not free to take")
	# An order may widen it, and never silently.
	_ok(Maturity.pickable(Maturity.ALMOST, [Maturity.ALMOST]),
		"an order that asks for almost-ready ones gets them")


## The streak cheer is decoration with a fixed table, not a mood.
##
## Three in a row earns the small one, every fifth the big one, anything else
## nothing -- asserted here so the mapping cannot drift into cheering every
## pick (wallpaper) or never cheering at all. Whether the counter itself moves
## is a thumb question, asked in harvest_touch_probe.
func _the_cheer_is_sparse() -> void:
	for quiet in [0, 1, 2, 4, 6, 7, 9, 11]:
		_ok(HarvestAction.cheer_for(quiet) == 0,
			"a streak of %d cheers nothing" % quiet)
	_ok(HarvestAction.cheer_for(3) == 1,
		"three in a row earns the small cheer")
	for big in [5, 10, 15]:
		_ok(HarvestAction.cheer_for(big) == 2,
			"a streak of %d earns the big cheer" % big)
##
## This is the colour-blindness rule, asserted rather than hoped for: if ready
## and unripe ever differ ONLY in tint, roughly one boy in twelve is playing a
## test he cannot pass.
func _ripeness_is_said_more_than_one_way() -> void:
	var unripe := Maturity.look(Maturity.UNRIPE)
	var ready := Maturity.look(Maturity.READY)
	var golden := Maturity.look(Maturity.GOLDEN)

	_ok(float(unripe["scale"]) < float(ready["scale"]) - 0.15,
		"an unripe one is visibly smaller, not just greener")
	_ok(str(unripe["halo"]) != str(ready["halo"]),
		"a ready one wears a ring an unripe one does not")
	_ok(float(unripe["sway"]) < float(ready["sway"]),
		"a ready one moves and an unripe one sits still")
	_ok(str(golden["halo"]) != str(ready["halo"]),
		"and a golden one is marked differently again")

	var channels := 0
	if float(unripe["scale"]) != float(ready["scale"]):
		channels += 1
	if Color(unripe["tint"]) != Color(ready["tint"]):
		channels += 1
	if str(unripe["halo"]) != str(ready["halo"]):
		channels += 1
	if float(unripe["sway"]) != float(ready["sway"]):
		channels += 1
	_ok(channels >= 3,
		"ripe and unripe differ in at least three ways, so colour is never the "
		+ "only one (they differ in %d)" % channels)


## Every harvest level has enough on the ground to fill its own order.
##
## The failure this catches is silent and total: an order asking for six when
## the level only plants five is a level that can never be finished, and
## nothing at runtime says so -- the child just keeps looking.
func _every_level_can_actually_be_finished() -> void:
	for level in GameData.levels:
		if str(level.get("game_type", "")) != "harvest_action":
			continue
		var id := str(level.get("id", ""))
		var config: Dictionary = level.get("config", {})
		var allowed: Array = config.get("allowed_maturity", Maturity.PICKABLE)

		var available: Dictionary = {}
		for entry in config.get("targets", []):
			if not Maturity.pickable(str(entry.get("maturity", Maturity.READY)),
					allowed):
				continue
			var crop_id := str(entry.get("crop_id", ""))
			var each: int = maxi(int(Crops.get_crop(crop_id).get(
				"harvest_count", 1)), 1)
			available[crop_id] = int(available.get(crop_id, 0)) \
				+ int(entry.get("count", 1)) * each

		# Every order in the level, not just the first: the celebration level
		# has three, and a shortfall in the third is a level that stops dead
		# two thirds of the way through with no way to say so.
		var asked: Dictionary = {}
		for order in _orders_of(level):
			for entry in order:
				var crop_id := str(entry.get("crop_id", ""))
				asked[crop_id] = int(asked.get(crop_id, 0)) \
					+ int(entry.get("count", 1))
		for crop_id in asked.keys():
			var need: int = int(asked[crop_id])
			_ok(int(available.get(crop_id, 0)) >= need,
				"%s asks for %d %s across its orders and only %d can be picked "
				% [id, need, crop_id, int(available.get(crop_id, 0))]
				+ "-- it can never be finished")
			_ok(not Crops.get_crop(str(crop_id)).is_empty(),
				"%s asks for '%s', which is not in the catalogue" % [id, crop_id])

## Nothing a level puts in the way is ever something an order asks for.
##
## A stone in the requirements would be a level that cannot be finished by
## doing the right thing, and clutter never goes in a basket, so the count
## could never rise. Cheap to get wrong by copy-paste and invisible until a
## child sits in front of it looking for a seventh potato.
func _clutter_is_never_asked_for() -> void:
	for level in GameData.levels:
		if str(level.get("game_type", "")) != "harvest_action":
			continue
		var id := str(level.get("id", ""))
		for order in _orders_of(level):
			for entry in order:
				var crop: Dictionary = Crops.get_crop(str(entry.get("crop_id", "")))
				_ok(not ("clutter" in crop.get("tags", [])),
					"%s asks for '%s', which is clutter -- it never reaches a "
					% [id, str(entry.get("crop_id", ""))] + "basket, so the "
					+ "order could never be filled")


## Multi-yield crops are consumed as whole plants. Excess peas from one order
## are not carried into the next, so enough total peas alone is insufficient.
## Ask the production difficulty resolver, including each brave-only extra.
func _every_difficulty_has_whole_harvests_for_each_order() -> void:
	var previous_tier := int(SaveManager.data["settings"].get("difficulty", 1))
	var action := HarvestAction.new()
	for tier in range(3):
		SaveManager.data["settings"]["difficulty"] = tier
		for level in GameData.get_levels_for_mode("harvest"):
			var config: Dictionary = level.get("config", {})
			var allowed: Array = config.get("allowed_maturity", Maturity.PICKABLE)
			var remaining: Dictionary = {}
			for entry in config.get("targets", []):
				if not Maturity.pickable(str(entry.get("maturity", "ready")), allowed):
					continue
				var crop_id := str(entry.get("crop_id", ""))
				remaining[crop_id] = int(remaining.get(crop_id, 0)) + int(entry.get("count", 1))
			var orders: Array = config.get("orders", [{"requirements": config.get("order", [])}])
			for order_index in range(orders.size()):
				var wanted: Dictionary = action.call("_requirements_for_order", orders[order_index])
				for crop_id in wanted:
					var yield_count := maxi(int(Crops.get_crop(str(crop_id)).get("harvest_count", 1)), 1)
					var quantity := int(wanted[crop_id])
					var context := "%s tier %d order %d %s" % [str(level["id"]), tier, order_index, crop_id]
					_ok(quantity > 0 and quantity % yield_count == 0,
						context + " asks for whole harvests, so a pod never loses a leftover pea")
					var needed := int(ceil(float(quantity) / float(yield_count)))
					_ok(int(remaining.get(crop_id, 0)) >= needed,
						context + " has fresh plants after the previous deliveries")
					remaining[crop_id] = int(remaining.get(crop_id, 0)) - needed
	SaveManager.data["settings"]["difficulty"] = previous_tier
	action.free()


func _the_relay_customer_follows_the_current_order() -> void:
	var action := HarvestAction.new()
	action.level_data = GameData.get_level("harvest_16").duplicate(true)
	action.set("_orders", action.level_data.get("config", {}).get("orders", []))
	var expected := ["res://assets/harvest_3d/props/rabbit.png", "paw", "teddy"]
	for index in range(expected.size()):
		action.set("_order_index", index)
		_ok(str(action.call("_current_customer_reference")) == expected[index],
			"the relay resolves the customer for order %d, including checkpoint restoration" % index)
	action.level_data = GameData.get_level("harvest_15").duplicate(true)
	action.set("_orders", action.level_data.get("config", {}).get("orders", []))
	action.set("_order_index", 1)
	_ok(str(action.call("_current_customer_reference")) == "robot",
		"an order with no portrait override keeps its level's customer")
	action.free()


## An exception has to name a basket the level actually has.
##
## "the starred one goes in the gift basket" with no gift basket on screen is
## a crop that can go NOWHERE: the exception refuses every basket there is, and
## the level is unfinishable in a way no other check would see -- the counts
## all add up, the crop is pickable, and every drop is simply rejected.
func _an_exception_names_a_basket_that_exists() -> void:
	for level in GameData.levels:
		if str(level.get("game_type", "")) != "harvest_action":
			continue
		var config: Dictionary = level.get("config", {})
		var have: Array = []
		for basket in config.get("baskets", []):
			have.append(str(basket.get("id", "")))
		for rule in config.get("exceptions", []):
			_ok(str(rule.get("basket", "")) in have,
				"%s sends '%s' to basket '%s', which the level does not have"
					% [str(level.get("id", "")), str(rule.get("tag", "")),
						str(rule.get("basket", ""))])


## A sorting lesson has one intended answer. "Any matching tag" is convenient
## for an inventory but wrong for a child asked to separate two things: if both
## baskets accept an orange, the lesson's rule is only an illusion.
func _every_pickable_target_has_one_sorting_home() -> void:
	for level in GameData.levels:
		if str(level.get("game_type", "")) != "harvest_action":
			continue
		var id := str(level.get("id", ""))
		var config: Dictionary = level.get("config", {})
		var allowed: Array = config.get("allowed_maturity", Maturity.PICKABLE)
		var baskets: Array = config.get("baskets", [])
		if baskets.is_empty():
			baskets = [{"id": "basket", "accepts_tags": []}]
		for target in config.get("targets", []):
			var step := str(target.get("maturity", Maturity.READY))
			if not Maturity.pickable(step, allowed):
				continue
			var crop_id := str(target.get("crop_id", ""))
			var crop: Dictionary = Crops.get_crop(crop_id)
			if "clutter" in crop.get("tags", []):
				continue
			var must := _exception_for(config.get("exceptions", []), crop, step)
			var homes := 0
			for basket in baskets:
				var welcome := str(basket.get("id", "")) == must if must != "" \
					else _basket_takes(basket, crop)
				if welcome:
					homes += 1
			_ok(homes == 1,
				"%s puts pickable %s in %d baskets, not exactly one"
				% [id, crop_id, homes])


func _exception_for(rules: Array, crop: Dictionary, step: String) -> String:
	for rule in rules:
		var tag := str(rule.get("tag", ""))
		if tag in crop.get("tags", []) or (tag == "golden" and step == Maturity.GOLDEN):
			return str(rule.get("basket", ""))
	return ""


func _basket_takes(basket: Dictionary, crop: Dictionary) -> bool:
	var accepts: Array = basket.get("accepts_tags", [])
	if accepts.is_empty():
		return true
	for tag in accepts:
		if tag in crop.get("tags", []):
			return true
	return false


## A checkpoint says where a scored challenge should resume. It is not a crop,
## a daily order or a farm upgrade, so farm normalisation must never own it.
## This simulates a save made by the short-lived old layout and verifies that
## migration carries it across before Farm.normalise_farm() drops unknown keys.
func _the_checkpoint_is_challenge_state_not_farm_state() -> void:
	var fresh := SaveManager._default_data()
	_ok(fresh.get("harvest_checkpoint", null) is Dictionary,
		"a fresh save has a dedicated harvest checkpoint branch")
	_ok(not fresh.get("farm", {}).has("harvest_checkpoint"),
		"a fresh daily farm has no challenge checkpoint field")

	var legacy := SaveManager._default_data()
	legacy.erase("harvest_checkpoint")
	var mark := {"level_id": "harvest_08", "order_index": 1,
		"delivered": {"carrot": 3, "strawberry": 4}}
	legacy["farm"]["harvest_checkpoint"] = mark.duplicate(true)
	var migrated: Dictionary = SaveManager._migrate(
		JSON.parse_string(JSON.stringify(legacy)))
	var carried: Dictionary = migrated.get("harvest_checkpoint", {})
	_ok(str(carried.get("level_id", "")) == "harvest_08"
		and int(carried.get("order_index", -1)) == 1
		and int((carried.get("delivered", {}) as Dictionary).get("carrot", 0)) == 3
		and int((carried.get("delivered", {}) as Dictionary).get("strawberry", 0)) == 4,
		"a legacy checkpoint moves into the dedicated challenge branch")
	_ok(not migrated.get("farm", {}).has("harvest_checkpoint"),
		"migration leaves the daily farm schema free of challenge state")


## The eight harvest levels are a MODE, not eight more stones on the island.
##
## Asserted rather than assumed, because the whole justification for eight
## levels of one template rests on it. The moment one of them appears on
## 阳光公园's path, the island really has gone monotonous and the static rule
## that says so was right after all.
func _the_challenge_is_off_the_island_path() -> void:
	var in_mode: Array = GameData.get_levels_for_mode("harvest")
	_ok(in_mode.size() >= 8, "there are at least eight harvest levels (%d)" % in_mode.size())
	for world in GameData.worlds:
		var path: Array = GameData.get_levels_for_world(str(world.get("id", "")))
		for level in path:
			_ok(str(level.get("game_type", "")) != "harvest_action",
				"%s is on %s's path -- the challenge belongs behind the "
				% [str(level.get("id", "")), str(world.get("id", ""))]
				+ "garden's door, not in the island's story")


## Every order in a level, whether it has one or several.
func _orders_of(level: Dictionary) -> Array:
	var config: Dictionary = level.get("config", {})
	var out: Array = []
	if config.has("orders"):
		for order in config["orders"]:
			out.append((order as Dictionary).get("requirements", []))
	else:
		out.append(config.get("order", []))
	return out
