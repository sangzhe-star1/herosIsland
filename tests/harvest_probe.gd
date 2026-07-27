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
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== harvest probe ===")
	await get_tree().process_frame

	_the_catalogue_is_readable()
	_a_pull_up_has_a_fan_not_a_line()
	_a_drag_has_to_go_far_enough()
	_a_tap_is_not_a_short_drag()
	_a_twist_goes_either_way()
	_an_unknown_gesture_refuses()
	_unripe_is_not_pickable()
	_ripeness_is_said_more_than_one_way()
	_every_level_can_actually_be_finished()

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("HARVEST PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


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


## Five channels, and no two steps identical in only one of them.
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

		for entry in config.get("order", []):
			var crop_id := str(entry.get("crop_id", ""))
			var need := int(entry.get("count", 1))
			_ok(int(available.get(crop_id, 0)) >= need,
				"%s asks for %d %s and only %d can be picked -- it can never "
				% [id, need, crop_id, int(available.get(crop_id, 0))]
				+ "be finished")
			_ok(not Crops.get_crop(crop_id).is_empty(),
				"%s asks for '%s', which is not in the catalogue" % [id, crop_id])
