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
const Layout := preload("res://scripts/garden/farm_layout.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]
const NOON := 1_699_963_200

## The fewest questions this probe may have asked by the time it decides.
##
## An empty failure list means "nothing came back wrong", not "I asked". Almost
## every check below starts by finding something on a screen it has just built
## -- a bed, a seed tile, a back button -- and a find that comes back empty
## skips its questions in silence and prints PASSED. That is not a hypothetical
## here: this probe locates the back button by its label and the seed tiles by
## a copy of the rack's arithmetic, so a change to either would have quietly
## removed a whole section rather than turning it red.
##
## Counted across BOTH screen shapes, because a probe that silently ran only one
## of them is the same failure wearing a different hat.
const CHECKS_EXPECTED := 184

var _failures: Array[String] = []
var _garden: Node = null
var _shape := ""
## How many questions actually got asked. See CHECKS_EXPECTED.
var _asked := 0


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _ready() -> void:
	print("\n=== garden touch probe ===")
	for shape in SHAPES:
		_shape = "%dx%d" % [shape.x, shape.y]
		await _run_on_a(shape)

	if _asked < CHECKS_EXPECTED:
		_failures.append(
			"this probe only asked %d questions across %d screen shapes and "
			% [_asked, SHAPES.size()]
			+ "expected at least %d -- something it looks for on the screen "
			% CHECKS_EXPECTED
			+ "is no longer there, so a section was skipped in silence")

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("asked %d questions" % _asked)
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
	await _the_decorating_door_and_its_furniture()

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


## How big one bed is ON THE GLASS -- the farm's own number, scaled by however
## far out the camera is. Written down a second time here it would be a copy
## that agrees rather than a check that measures.
func _bed_box() -> Vector2:
	return Layout.plot_box() * _camera().zoom


func _camera():
	return _garden.get("_world").camera


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
	# Every bed there is, asked from the save rather than from a number written
	# down here. Four became six; a probe holding its own copy of that count
	# would have gone on checking the first four and reported nothing at all
	# about the two new ones.
	var beds: int = _plots().size()
	_ok(beds == Farm.PLOT_COUNT,
		"the garden draws all %d beds" % Farm.PLOT_COUNT)
	for i in range(beds):
		var at := _bed(i)
		# Half a bed, so the check is about the whole thing being reachable
		# rather than about its centre being on the glass. A bed whose left
		# edge is under the bezel is a bed he cannot press the left half of.
		var half := _bed_box() * 0.5
		_ok(at.x - half.x > 60.0 and at.x + half.x < view.x - 60.0,
			"bed %d is on the screen horizontally" % i)
		_ok(at.y - half.y > 96.0 and at.y + half.y < view.y - 168.0,
			"bed %d sits between the top bar and the seed rack" % i)

	# The rule that makes a mis-drop impossible: DragField clicks a released
	# piece into any slot within 118px, so two beds closer than 236px apart
	# would let a seed aimed at one land in the other.
	for a in range(beds):
		for b in range(a + 1, beds):
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


## 二期阶段 1：装饰间的门开在菜园里，摆好的东西回来还在，且咬不到手指。
func _the_decorating_door_and_its_furniture() -> void:
	# The door: data names a real room with a real scene, the chip is on the
	# shelf, thumb-sized, wired, and it must not cover the barn card.
	var room_id := str(GameData.get_level("star_garden")\
		.get("config", {}).get("deco_room", ""))
	_ok(room_id != "", "star_garden has no deco_room -- 二期的门没了")
	if room_id != "":
		var room: Dictionary = GameData.get_level(room_id)
		_ok(not room.is_empty() and bool(room.get("room", false)),
			"deco_room '%s' is not a room the game knows" % room_id)
		var scene := GameData.get_minigame_scene(str(room.get("game_type", "")))
		_ok(scene != "" and ResourceLoader.exists(scene),
			"deco_room '%s' has no scene" % room_id)
		_ok(str(room.get("config", {}).get("exit_room", "")) == "star_garden",
			"the decorating room's back door must lead HOME to the garden")
		_ok(str(room.get("config", {}).get("canvas_id", "")) == "garden",
			"the decorating room must shelve under 'garden' -- anything else "
			+ "risks the hero base's stickers")

	var door: Node = _find_named(_garden, "DecoDoor")
	_ok(door != null, "the garden shows no decorating door")
	if door is Button:
		var b := door as Button
		_ok(b.size.y >= 60.0, "the deco door is %.0f tall -- under the thumb "
			% b.size.y + "floor")
		_ok(b.pressed.get_connections().size() > 0, "the deco door is not "
			+ "wired to anything")

	# The furniture: three saved decorations must stand in the farm world,
	# and none of them may accept input.
	SaveManager.set_creation("garden", [
		{"icon": "sprout", "x": 200.0, "y": 200.0, "size": 84.0},
		{"icon": "flag", "x": 640.0, "y": 300.0, "size": 84.0},
		{"icon": "leaf", "x": 1100.0, "y": 500.0, "size": 84.0},
	])
	_garden.call("_draw_decorations")
	await get_tree().process_frame
	var layer: Node = _find_named(_garden, "Decorations")
	_ok(layer != null, "three decorations are saved and none stand in the farm")
	if layer != null:
		var shown := 0
		for child in layer.get_children():
			if child is Control:
				shown += 1
				_ok((child as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
					"a decoration accepts input -- furniture must never "
					+ "swallow a tap meant for a plot")
		_ok(shown == 3, "saved 3 decorations, the farm shows %d" % shown)

	# And the hero base's shelf is exactly as it was.
	var base_before: Array = SaveManager.get_creation("base")
	SaveManager.set_creation("garden", [])
	_garden.call("_draw_decorations")
	_ok(SaveManager.get_creation("base") == base_before,
		"touching the garden's decorations moved the hero base's shelf")


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var hit := _find_named(child, wanted)
		if hit != null:
			return hit
	return null


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
	# scene, which would take this probe out of the tree mid-run.
	_ok(back.pressed.get_connections().size() > 0,
		"...and pressing it does something")

	# And it leads HOME, by data. 验收单第 16 条按原文落地（2026-07-29
	# Zane 拍板）：出口写在 star_garden.config.exit_room 里，必须指向一个
	# 真实存在、场景也真的在的房间。指错了代码会安静地退回世界地图——
	# 孩子出得去，但验收就名存实亡了，所以这里盯着数据本身。
	var exit_room := str(GameData.get_level("star_garden")\
		.get("config", {}).get("exit_room", ""))
	_ok(exit_room != "", "star_garden has no exit_room -- acceptance #16 says "
		+ "the garden goes home to 英雄基地, and nothing says where home is")
	if exit_room != "":
		var room := GameData.get_level(exit_room)
		_ok(not room.is_empty() and bool(room.get("room", false)),
			"exit_room '%s' is not a room the game knows" % exit_room)
		var scene := GameData.get_minigame_scene(str(room.get("game_type", "")))
		_ok(scene != "" and ResourceLoader.exists(scene),
			"exit_room '%s' has no scene to arrive in" % exit_room)
	await get_tree().process_frame


func _seed_tile(index: int) -> Vector2:
	# Asked of the screen, which used to be a hand-kept copy of the rack's
	# arithmetic -- the copy survived one shelf redesign only because
	# DragField's grab radius forgave the 42px it was off by.
	return _garden.call("_rack_tile_centre", index)


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
	await _open_the_board()

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
	_ok(Barn.count("plank", "inventory") == 1,
		"and the friend leaves exactly one plank as thanks")
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
	_ok(Barn.count("plank", "inventory") == 1,
		"and no second plank arrives however it is pressed")

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
	_ok(Barn.count("plank", "inventory") == 1,
		"...and the one plank")


## Walk up to the order board and press it, the way he does.
##
## The board is a building on the farm now, not a panel nailed to the right
## third of the screen -- that third is farm. So a card cannot be pressed until
## the board has been opened, and the probe opens it the same way a thumb does:
## by pressing the building. Setting the flag directly would test the panel and
## skip the only new thing there is to get wrong.
func _open_the_board() -> void:
	var world = _garden.get("_world")
	# From the opening view the board is off the glass -- the farm is bigger
	# than the window now, which is the whole point of it. Walk over first,
	# exactly the way a thumb does, then press the building where it is drawn.
	# (This used to "work" without walking, and that was the bug: a press
	# outside the window was being claimed and answered anyway.)
	var at: Vector2 = world.facility_screen_position("orders")
	if not world.camera.inside(at):
		world.look_at_facility("orders")
		await get_tree().process_frame
		at = world.facility_screen_position("orders")
	await _tap(at)
	_ok(bool(_garden.get("_orders_open")),
		"pressing the order board opens it")
	await get_tree().process_frame


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

## The first planting is taught once, all six steps of it, and then never again.
##
## Two halves, and both have gone wrong here.
##
## "All six steps" is the half that was missing. garden_tutorial.json described
## six -- greet, turn, plant, water, pick, hand over -- and the screen read one
## field out of that file and played a four-second finger animation instead. The
## four lines after the greeting had no way to play at all, so `garden_tut_water`
## was written down, recorded by a parent, and unreachable. This walks the whole
## lesson with a thumb and asks, at each step, whether the game said the thing
## that step is for.
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
	_ok(bool(_garden.get("_lesson_running")),
		"a child opening the garden for the first time gets the lesson")
	_ok(str(_garden.get("_lesson_said")) == "welcome",
		"and it opens by greeting him, not by giving him a job")

	# Step two: bare earth. Wait out the beat between the greeting and the
	# first instruction, then check it asked for the thing the garden needs.
	await get_tree().create_timer(2.4).timeout
	_ok(str(_garden.get("_lesson_said")) == "till",
		"pointing at bare earth, it asks him to turn it over")

	# He turns it over. The next thing the garden wants is a seed.
	await _tap(_bed(0))
	_ok(str(_plots()[0].get("state", "")) == Farm.TILLED,
		"the bed he was pointed at is the bed that got turned")
	_ok(str(_garden.get("_lesson_said")) == "plant",
		"and the lesson moves on by itself, to the seed rack")

	# He plants. THE CARROT IS THE FAST ONE, and only this one.
	await _finger(_seed_tile(0), _bed(0))
	_ok(str(_plots()[0].get("crop_id", "")) == "carrot",
		"the seed he dragged went into the bed")
	_ok(int(_plots()[0].get("growth_override_seconds", 0)) > 0,
		"the lesson's carrot runs on its own clock so he sees it finish")
	_ok(int(GameData.get_crop("carrot").get("stage_seconds", [0])[0]) == 300,
		"the lesson leaves the real carrot exactly as long as it always was")
	_ok(int(_plots()[1].get("growth_override_seconds", 0)) == 0,
		"and no other bed was sped up with it")

	# Nothing is said while it is simply growing: there is nothing he can do.
	_ok(str(_garden.get("_lesson_said")) == "plant",
		"a growing plant is not a job, so the lesson stays quiet through it")

	# Four seconds in, the six-second carrot is thirsty -- thirst_seconds is two
	# thirds of the way through every crop, and scaling has to keep that true or
	# the lesson reaches "give it a drink" with nothing to drink.
	await _let_the_garden_catch_up(4)
	_ok(str(_plots()[0].get("care_event", "")) == Growth.CARE_THIRSTY,
		"the lesson's carrot gets thirsty, exactly once, like every other crop")
	_ok(str(_garden.get("_lesson_said")) == "water",
		"and the lesson asks for water at the moment there is water to give")

	# He waters it, and the rest of the growing happens while he watches.
	await _tap(_bed(0))
	await _let_the_garden_catch_up(4)
	_ok(str(_plots()[0].get("state", "")) == Farm.READY,
		"watered, it finishes growing while he is standing there")
	_ok(str(_garden.get("_lesson_said")) == "harvest",
		"and he is asked to pick it")

	# He picks it. Three carrots, which is what the bear is waiting for -- the
	# tutorial crop and the first order were written to fit each other.
	await _tap(_bed(0))
	_ok(Barn.count("carrot") >= 3, "picking it fills the barn")
	_ok(str(_garden.get("_lesson_said")) == "order",
		"and the last step points at the person who wants them")
	_ok(bool(_garden.get("_lesson_running")),
		"the lesson is not over until he has handed something over")

	# He hands it over. That, and only that, ends the lesson.
	#
	# But first he has to walk up to the board, because the board is a building
	# on the farm now. That is the step the lesson's finger points at while the
	# board is shut -- and pressing it is what makes the finger move on to the
	# card. A probe that reached past this by setting the flag would skip the
	# only part of the last lesson step that is new.
	await _open_the_board()
	var card := _order_card("bear_carrots")
	_ok(card != null and not card.disabled,
		"the order the lesson pointed at is one he can actually press")
	if card != null:
		card.emit_signal("pressed")
		for i in range(4):
			await get_tree().process_frame
	_ok(bool(SaveManager.data["farm"].get("tutorial_completed", false)),
		"handing the first basket over is what finishes the lesson")
	_ok(not bool(_garden.get("_lesson_running")),
		"and the lesson stops running the moment it is finished")

	# Second visit: nothing.
	_close()
	_open()
	for i in range(4):
		await get_tree().process_frame
	_ok(not bool(_garden.get("_lesson_running")),
		"the second visit does not teach it again")

	# Nor after closing the game and coming back.
	SaveManager.save_game()
	SaveManager.load_game()
	_close()
	_open()
	for i in range(4):
		await get_tree().process_frame
	_ok(not bool(_garden.get("_lesson_running")),
		"nor tomorrow, nor on any day after that")


## Move the clock on and let the lesson's own tick notice.
##
## The garden re-settles twice a second while the lesson runs, so the test clock
## jumps and then real frames have to pass for the tick to pick it up. Waiting
## on wall-clock time here is deliberate: the thing being checked is that the
## garden updates itself with nobody touching it.
func _let_the_garden_catch_up(seconds: int) -> void:
	GameClock.advance_test(seconds)
	await get_tree().create_timer(0.9).timeout
	for i in range(4):
		await get_tree().process_frame


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
