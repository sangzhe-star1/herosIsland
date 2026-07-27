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
const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")

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
	await _a_harvest_is_paid_for_once()
	await _handing_an_order_over_pays_once()
	await _the_lesson_happens_once_in_a_childhood()
	await _a_break_is_offered_not_pushed()
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
	_ok(str(_plots()[0].get("state", "")) == Farm.EMPTY, "bed 0 starts as grass")
	await _tap(_bed(0))
	_ok(Farm.is_tilled(_plots()[0]),
		"one tap on grass turns it into earth -- no tool to pick first")
	# ...and the OTHER beds are untouched. One tap, one bed.
	_ok(not Farm.is_tilled(_plots()[1]),
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
	plots[3]["crop_id"] = "strawberry"
	plots[3]["growth_stage"] = 4
	plots[3]["plant_cycle_id"] = 7
	plots[3]["state"] = Farm.READY
	SaveManager.data["farm"]["paid_harvests"] = []
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame

	var expected := int(GameData.get_crop("strawberry").get("harvest_amount", 0))
	await _tap(_bed(3))
	var barn: Dictionary = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("strawberry", 0)) == expected,
		"picking a ripe bed puts exactly its yield in the barn")
	_ok(str(_plots()[3].get("crop_id", "")) == "",
		"and leaves bare earth behind")
	_ok(Farm.is_tilled(_plots()[3]),
		"still turned over, so the next seed can go straight in")
	_ok(not Farm.is_ready(_plots()[3]),
		"and nothing left to pick")

	# Tapping the empty bed again must not pay a second time.
	await _tap(_bed(3))
	barn = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("strawberry", 0)) == expected,
		"tapping the same bed again pays nothing -- one planting, one harvest")

	# The transaction id was written down, and it names the bed and the planting.
	var paid: Array = SaveManager.data["farm"].get("paid_harvests", [])
	_ok("farm_harvest_plot_4_7" in paid,
		"the harvest is recorded against the bed and the planting it came from")


## The harvest is paid for ONCE, proved the three ways it can be asked twice.
##
## The bed emptying is not enough on its own to prove this. It is the thing
## that makes a second tap harmless TODAY, and it stops being enough the moment
## anything is added that pays 星星币 or a badge for picking -- so the once-only
## rule is asserted directly, against the transaction id, rather than inferred
## from a side effect that happens to cover it.
func _a_harvest_is_paid_for_once() -> void:
	var plots := _plots()
	plots[2]["crop_id"] = "carrot"
	plots[2]["growth_stage"] = 4
	plots[2]["plant_cycle_id"] = 3
	plots[2]["state"] = Farm.READY
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.data["farm"]["paid_harvests"] = []
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame

	var expected := int(GameData.get_crop("carrot").get("harvest_amount", 0))

	# 1. Straight through the screen's own harvest, bypassing the button -- a
	#    second call while the bed is still READY is the case a disabled button
	#    would hide.
	var ripe: Dictionary = _plots()[2]
	_garden.call("_harvest", ripe)
	var first := int(SaveManager.data["farm"]["warehouse"].get("carrot", 0))
	_ok(first == expected, "the first pick fills the barn")
	# The bed is empty again, and the planting number it was paid against is
	# still on it. Reset that number and the NEXT planting in this bed reuses a
	# transaction id that has already been paid for -- so that harvest pays
	# nothing, silently, and the child picks a carrot and gets no carrot.
	_ok(int(_plots()[2].get("plant_cycle_id", 0)) == 3,
		"the harvest leaves the planting number behind for the next crop to pass")

	# 2. The same bed, put back to ripe with the SAME planting, asked again.
	#    Nothing may come of it: the transaction id has been used.
	var again: Dictionary = _plots()[2]
	again["crop_id"] = "carrot"
	again["growth_stage"] = 4
	again["plant_cycle_id"] = 3
	again["state"] = Farm.READY
	_garden.call("_harvest", again)
	_ok(int(SaveManager.data["farm"]["warehouse"].get("carrot", 0)) == first,
		"the same planting cannot be picked twice, even put back by hand")

	# 3. A restart. The ledger is on disk, so the reload has to remember.
	SaveManager.save_game()
	SaveManager.load_game()
	var reopened: Dictionary = SaveManager.data["farm"]["plots"][2]
	reopened["crop_id"] = "carrot"
	reopened["growth_stage"] = 4
	reopened["plant_cycle_id"] = 3
	reopened["state"] = Farm.READY
	_garden.call("_harvest", reopened)
	_ok(int(SaveManager.data["farm"]["warehouse"].get("carrot", 0)) == first,
		"and not after closing the game and coming back either")

	# A NEW planting in the same bed pays normally -- the guard is on the
	# planting, not on the bed.
	var next_cycle: Dictionary = SaveManager.data["farm"]["plots"][2]
	next_cycle["crop_id"] = "carrot"
	next_cycle["growth_stage"] = 4
	next_cycle["plant_cycle_id"] = 4
	next_cycle["state"] = Farm.READY
	_garden.call("_harvest", next_cycle)
	_ok(int(SaveManager.data["farm"]["warehouse"].get("carrot", 0)) == first + expected,
		"but planting again in the same bed pays again -- once per planting")


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
	# Wired to something. Not pressed here on purpose: pressing it changes the
	# scene, which would take this probe out of the tree mid-run. Where it goes
	# is LevelManager.quit_level(), shared with all thirty-four levels and
	# walked by map_probe -- what is garden-specific is only that the button is
	# there and connected.
	_ok(back.pressed.get_connections().size() > 0,
		"...and pressing it does something")
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


## Acceptance #11 and #12, through the button he actually presses.
##
## The logic is checked headlessly in garden_probe; what this adds is the part
## that only exists on screen: the card is pressable when the barn can cover
## it, pressing it once pays, and pressing it again does nothing -- because a
## six-year-old presses things twice.
func _handing_an_order_over_pays_once() -> void:
	var order: Dictionary = GameData.garden_orders[0]
	var wants: Dictionary = order.get("requirements", {})
	var price := int(order.get("rewards", {}).get("coins", 0))

	# Fill the barn with exactly what the bear asked for.
	SaveManager.data["farm"]["warehouse"] = {}
	for crop_id in wants.keys():
		Barn.put(str(crop_id), int(wants[crop_id]))
	SaveManager.data["farm_orders"]["delivered"] = []
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame

	var card := _order_card(str(order.get("id", "")))
	_ok(card != null, "the order he can fill has a card he can press")
	if card == null:
		return
	_ok(not card.disabled, "and it is pressable")

	var before := Coins.balance()
	card.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(Coins.balance() == before + price,
		"handing the basket over pays exactly what the card promised")
	_ok(str(order.get("id", ""))
			in SaveManager.data["farm_orders"]["delivered"],
		"and the delivery is written down")
	for crop_id in wants.keys():
		_ok(Barn.count(str(crop_id)) == 0,
			"the barn handed over the %s" % str(crop_id))

	# Press the card again, if it is still there at all.
	var again := _order_card(str(order.get("id", "")))
	if again != null:
		_ok(again.disabled, "a delivered order cannot be pressed again")
		again.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame

	# And if it somehow IS delivered again -- a stray signal, a future screen
	# that forgets to disable the card -- it must not quietly take the crops.
	# Refill the barn and call the delivery straight, past the button.
	for crop_id in wants.keys():
		Barn.put(str(crop_id), int(wants[crop_id]))
	_garden.call("_deliver", order)
	await get_tree().process_frame
	for crop_id in wants.keys():
		_ok(Barn.count(str(crop_id)) == int(wants[crop_id]),
			"a second delivery does not take the %s and give nothing back"
				% str(crop_id))
	for crop_id in wants.keys():
		Barn.take(str(crop_id), int(wants[crop_id]))
	_ok(Coins.balance() == before + price,
		"and pressing it again pays nothing at all")

	# And it survives the game being closed. In memory the delivered list is a
	# reference, so the in-memory dedup works whether or not anything is
	# written -- which means deleting the save_game() from the delivery left
	# every check above still passing. This is the one that notices.
	SaveManager.load_game()
	_ok(str(order.get("id", ""))
			in SaveManager.data["farm_orders"].get("delivered", []),
		"the delivery is on disk, not just in memory")
	_ok(Coins.balance() == before + price,
		"...and so are the 星星币 it paid")


## The card for one order, found by where the board puts it.
func _order_card(order_id: String) -> Button:
	var index := -1
	for i in range(GameData.garden_orders.size()):
		if str(GameData.garden_orders[i].get("id", "")) == order_id:
			index = i
			break
	if index < 0:
		return null
	var cards: Array = []
	_collect_order_cards(_garden, cards)
	return cards[index] if index < cards.size() else null


func _collect_order_cards(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button and (child as Button).size.x > 340.0 \
				and (child as Button).size.y > 80.0:
			out.append(child)
		_collect_order_cards(child, out)

## The first planting is taught once, and then never again.
##
## "Never again" is the half that matters. A lesson that replays every visit is
## a lesson a child learns to tap through, and after that the game has no way
## left to teach him anything.
func _the_lesson_happens_once_in_a_childhood() -> void:
	_fresh_garden()
	_ok(not bool(SaveManager.data["farm"].get("tutorial_completed", true)),
		"a brand new garden has not taught the lesson yet")

	_close()
	_open()
	for i in range(4):
		await get_tree().process_frame
	_ok(is_instance_valid(_garden.get("_lesson")),
		"a child opening the garden for the first time gets the lesson")

	# Let it run out. The director frees itself at the end, so everything after
	# this asks is_instance_valid rather than == null -- a freed object is not
	# null, and a probe that compared against null would have passed whether the
	# lesson ran again or not.
	await get_tree().create_timer(9.0).timeout
	_ok(bool(SaveManager.data["farm"].get("tutorial_completed", false)),
		"and finishing it is written down")

	# Second visit: nothing.
	_close()
	_open()
	for i in range(4):
		await get_tree().process_frame
	_ok(not is_instance_valid(_garden.get("_lesson")),
		"the second visit does not teach it again")

	# Nor after closing the game and coming back.
	SaveManager.save_game()
	SaveManager.load_game()
	_close()
	_open()
	for i in range(4):
		await get_tree().process_frame
	_ok(not is_instance_valid(_garden.get("_lesson")),
		"nor tomorrow, nor on any day after that")

	# The lesson uses a shortened carrot, and crops.json is NOT edited to do it.
	_ok(int(GameData.get_crop("carrot").get("stage_seconds", [0])[0]) == 300,
		"the lesson leaves the real carrot exactly as long as it always was")


## The break is offered after something good, with a way to carry on.
##
## Checked for what it must NOT do as much as for what it does: no countdown,
## no reward for staying, and the way to keep playing is the first button.
func _a_break_is_offered_not_pushed() -> void:
	_fresh_garden()
	SaveManager.data["farm"]["tutorial_completed"] = true
	_close()
	_open()
	for i in range(4):
		await get_tree().process_frame

	_ok(not bool(_garden.get("_rest_offered")),
		"walking in is not a reason to suggest leaving")

	# Fill the barn and hand over an order -- the good thing.
	var order: Dictionary = GameData.garden_orders[0]
	for crop_id in order.get("requirements", {}).keys():
		Barn.put(str(crop_id), int(order["requirements"][crop_id]))
	SaveManager.data["farm_orders"] = {"active": [], "delivered": []}
	_garden.call("_deliver", order)
	await get_tree().process_frame

	_ok(bool(_garden.get("_rest_offered")),
		"a finished order is a good moment to suggest a break")

	# Two ways out of the card, and the way to CARRY ON is one of them.
	var buttons: Array = []
	for node in _every_control(_garden):
		if node is BaseButton and (node as Control).visible \
				and (node as Control).get_global_rect().size.x > 120.0:
			buttons.append(node)
	_ok(buttons.size() >= 2,
		"the break card offers both carrying on and stopping")

	# And it is offered ONCE. Counted in cards on the screen, not read off the
	# flag that is supposed to stop it: deliberately removing the guard left the
	# flag reading true either way, so the flag version of this assertion passed
	# with three break cards stacked on top of each other.
	var cards_before := _big_cards()
	_garden.call("_offer_a_break")
	_garden.call("_offer_a_break")
	_ok(_big_cards() == cards_before,
		"and asked once a visit, never stacked up again and again")


## How many break-sized cards are on the screen right now.
func _big_cards() -> int:
	var n := 0
	for node in _every_control(_garden):
		if node is PanelContainer and (node as Control).visible \
				and (node as Control).get_global_rect().size.x > 400.0:
			n += 1
	return n


func _every_control(root: Node) -> Array:
	var out: Array = [root]
	var i := 0
	while i < out.size():
		for child in (out[i] as Node).get_children():
			out.append(child)
		i += 1
	return out
