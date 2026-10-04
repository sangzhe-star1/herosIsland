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
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")
const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

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
const CHECKS_EXPECTED := 1162

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
	await ProbeLifecycle.finish(self, 1 if _failures.size() > 0 else 0)


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

	_the_hero_base_hud_keeps_reading_lanes_open(view)
	await _the_beds_are_on_the_screen_he_is_holding(view)
	await _tapping_grass_turns_it_over()
	await _the_selected_tool_marks_its_possible_beds()
	await _dragging_a_seed_lands_in_the_bed_he_aimed_at()
	await _one_bed_takes_one_crop()
	await _tapping_a_ripe_bed_fills_the_barn()
	await _overflow_harvests_show_their_real_landing_places()
	await _a_harvest_is_paid_for_once()
	await _handing_an_order_over_pays_once()
	await _the_lesson_happens_once_in_a_childhood()
	await _a_resumed_garden_redraws_settled_beds()
	await _a_break_is_offered_not_pushed()
	await _there_is_a_way_out()
	await _the_decorating_door_and_its_furniture()
	await _the_bear_teaches_once_and_it_sticks()
	await _the_kitchen_asks_before_ingredients_leave()
	await _fourteen_seeds_take_turns()
	await _the_next_step_and_barn_shortcut_are_honest()
	await _a_ripe_bed_comes_out_when_pulled()
	await _the_garden_moves_while_he_watches()
	await _the_board_never_runs_dry()
	await _the_market_shows_what_things_are_worth(view)
	await _market_refusals_and_recipe_refills_keep_state()
	await _gold_shines_and_the_dog_says_hello()
	await _the_day_has_its_own_little_jobs()
	await _gold_blessing_from_the_days_care()
	await _the_challenge_door_shows_what_is_next(view)
	await _care_has_moves_of_its_own()
	await _no_button_grew_or_landed_on_another()
	await _a_bed_paid_twice_is_freed_not_frozen()
	await _a_card_he_cannot_fill_still_answers()
	await _the_lesson_clock_is_the_carrots_alone()
	await _the_bed_grows_the_same_crop_the_harvest_page_shows()

	_close()


## The base HUD is the one part of the farm that must be understood before a
## child touches anything.  Do not test colours here -- rendering is a better
## judge of that -- but make the spatial promise explicit: the five top-bar
## jobs have their own lanes, and the two shelf rows leave real air between a
## picture and its words.  Names are intentional test seams, not a second HUD:
## GardenScreen still owns the existing buttons and UiKit still owns their look.
func _the_hero_base_hud_keeps_reading_lanes_open(view: Vector2) -> void:
	var screen := Rect2(Vector2.ZERO, view)
	var top: Node = _find_named(_garden, "GardenTopBar")
	_ok(top is Control, "the garden has one named top-bar reading lane")
	_ok(_visible_control_inside(top, screen),
		"the whole top-bar reading lane stays on the screen")
	_ok(top is Control and (top as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the painted top bar itself never eats a farm touch")

	var back: Node = _find_back_button(_garden)
	var level: Node = _find_named(_garden, "FarmLevelBadge")
	var plaque: Node = _find_named(_garden, "GardenTitlePlaque")
	var title: Node = _find_named(_garden, "GardenTitle")
	var challenge: Node = _find_named(_garden, "HarvestChallenge")
	var purse: Node = _find_named(_garden, "FarmCoinPurse")
	var top_items: Array[Node] = [back, level, plaque, challenge, purse]
	var top_names := ["back", "level", "garden title", "harvest challenge", "coin purse"]
	for i in range(top_items.size()):
		var item: Node = top_items[i]
		_ok(_visible_control_inside(item, screen),
			"the %s is visible and fully on-screen" % str(top_names[i]))
		_ok(_control_contains(top, item),
			"the %s stays inside the top reading lane" % str(top_names[i]))

	_ok(_control_contains(plaque, title) and _title_has_side_gutters(plaque, title, 8.0),
		"the garden title leaves real side gutters inside its plaque")
	for left_index in range(top_items.size()):
		for right_index in range(left_index + 1, top_items.size()):
			_ok(_controls_are_separate(top_items[left_index], top_items[right_index], 2.0),
				"top-bar cards never sit on top of each other")
	_ok(_horizontal_gutter(back, level) >= 10.0,
		"back and level keep a thumb-width visual gutter")
	_ok(_horizontal_gutter(level, plaque) >= 12.0,
		"level and title keep separate reading lanes")
	_ok(_horizontal_gutter(plaque, challenge) >= 12.0,
		"title words do not run into the harvest challenge")
	_ok(_horizontal_gutter(challenge, purse) >= 10.0,
		"the challenge and coin count do not stick together")

	var challenge_press: Node = _find_named(_garden, "HarvestChallengeShortcut")
	_ok(_visible_control_inside(challenge_press, screen),
		"the visible harvest challenge keeps an equally visible press target")
	var challenge_rect := (challenge as Control).get_global_rect() \
		if challenge is Control else Rect2()
	var challenge_press_rect := (challenge_press as Control).get_global_rect() \
		if challenge_press is Control else Rect2()
	_ok(challenge is Control and challenge_press is Control
			and challenge_rect.position.is_equal_approx(challenge_press_rect.position)
			and challenge_rect.size.is_equal_approx(challenge_press_rect.size),
		"the harvest challenge picture and its tap target remain the same card")
	var challenge_label: Node = _find_named(_garden, "ChallengeLabel")
	var challenge_count: Node = _find_named(_garden, "ChallengeCount")
	var challenge_icon: Node = _find_named(_garden, "ChallengeIcon")
	_ok(challenge_label is Label and challenge_count is Label
			and _control_contains(challenge, challenge_label)
			and _control_contains(challenge, challenge_count),
		"challenge words and tally both stay inside their own warm card")
	_ok(_controls_are_separate(challenge_label, challenge_count, 2.0),
		"challenge title and progress tally do not stack on the same reading line")
	_ok(challenge_icon is Control and _horizontal_gutter(challenge_icon, challenge_label) >= 6.0
			and _horizontal_gutter(challenge_icon, challenge_count) >= 6.0,
		"challenge words leave a clear gutter after their basket picture")
	var level_value: Node = _find_named(_garden, "FarmLevelValue")
	var level_rail: Node = _find_named(_garden, "FarmLevelRail")
	var level_icon: Node = _find_named(_garden, "FarmLevelIcon")
	_ok(level_value is Label and level_rail is Control
			and _control_contains(level, level_value)
			and _control_contains(level, level_rail),
		"farm level number and progress rail stay inside their badge")
	_ok(_controls_are_separate(level_value, level_rail, 2.0),
		"farm level number leaves air above its progress rail")
	_ok(level_icon is Control and _horizontal_gutter(level_icon, level_value) >= 6.0,
		"farm level number leaves a clear gutter after its star picture")
	var coin_icon: Node = _find_named(_garden, "FarmCoinIcon")
	var coin_value: Node = _find_named(_garden, "FarmCoinValue")
	_ok(coin_icon is Control and coin_value is Label
			and _horizontal_gutter(coin_icon, coin_value) >= 6.0,
		"coin number leaves a clear gutter after its star-coin picture")

	var shelf: Node = _garden.get("_shelf")
	_ok(shelf is Control and (shelf as Control).visible,
		"the bottom shelf is a visible home for tools and seeds")
	_ok(_visible_control_inside(shelf, screen),
		"the full bottom shelf remains on the screen")
	var tool_deck: Node = _find_named(_garden, "GardenToolDeck")
	var seed_deck: Node = _find_named(_garden, "GardenSeedDeck")
	for deck_and_name in [[tool_deck, "tool deck"], [seed_deck, "seed deck"]]:
		var deck: Node = deck_and_name[0]
		var deck_name := str(deck_and_name[1])
		_ok(_visible_control_inside(deck, screen),
			"the %s is visible and fully on-screen" % deck_name)
		_ok(_control_contains(shelf, deck),
			"the %s stays inside the bottom shelf" % deck_name)
		_ok(deck is Control and (deck as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"the painted %s never blocks a seed drag or a tool tap" % deck_name)

	var tools: Dictionary = _garden.get("_tool_buttons")
	_ok(tools.size() == Tools.TOOLS.size(),
		"the hero base keeps all seven familiar tool choices")
	var previous_tool: Node = null
	var lowest_tool_edge := -INF
	for tool_data in Tools.TOOLS:
		var tool_id := str((tool_data as Dictionary).get("id", ""))
		var tool: Node = _find_named(_garden, "GardenTool_%s" % tool_id)
		_ok(tool is Button and tools.get(tool_id) == tool,
			"the %s tool has one named, reused button" % tool_id)
		_ok(_visible_control_inside(tool, screen),
			"the %s tool remains a visible touch target" % tool_id)
		_ok(_control_contains(tool_deck, tool),
			"the %s tool belongs inside the blue tool lane" % tool_id)
		if previous_tool != null:
			_ok(_horizontal_gutter(previous_tool, tool) >= 8.0,
				"neighbouring tools have a finger-sized horizontal gutter")
		previous_tool = tool
		if tool is Control:
			lowest_tool_edge = maxf(lowest_tool_edge,
				(tool as Control).get_global_rect().end.y)

		var icon: Node = tool.get_node_or_null("GardenToolIcon") if tool != null else null
		var label: Node = tool.get_node_or_null("GardenToolLabel") if tool != null else null
		_ok(icon is Control and label is Label and (icon as Control).visible
			and (label as Label).visible,
			"the %s tool keeps both its picture and its word" % tool_id)
		_ok(_control_contains(tool, icon, 2.0) and _control_contains(tool, label, 2.0),
			"the %s picture and word stay inside their own button" % tool_id)
		_ok(_vertical_gutter(icon, label) >= 6.0,
			"the %s tool leaves at least six pixels between picture and word" % tool_id)
		_ok(_controls_are_separate(icon, label),
			"the %s picture and word never overlap" % tool_id)

	var unlocked: Array = SaveManager.data.get("farm", {}).get("unlocked_crops", [])
	var visible_seed_slots := mini(7, unlocked.size())
	var actual_seed_slots := 0
	var highest_seed_edge := INF
	var previous_seed: Node = null
	for index in range(visible_seed_slots):
		var seed: Node = _rack_seed_button(index)
		_ok(seed is Button and (seed as Button).flat,
			"seed slot %d keeps its direct tap-and-drag target" % (index + 1))
		_ok(_visible_control_inside(seed, screen),
			"seed slot %d stays visible on this screen shape" % (index + 1))
		_ok(_control_contains(seed_deck, seed),
			"seed slot %d belongs inside the green seed lane" % (index + 1))
		if previous_seed != null:
			_ok(_horizontal_gutter(previous_seed, seed) >= 8.0,
				"neighbouring seed choices do not touch")
		previous_seed = seed
		if seed is Control:
			actual_seed_slots += 1
			highest_seed_edge = minf(highest_seed_edge,
				(seed as Control).get_global_rect().position.y)
	_ok(actual_seed_slots == visible_seed_slots,
		"the seed rack carries every unlocked first-page choice as a reachable target")
	_ok(highest_seed_edge - lowest_tool_edge >= 6.0,
		"the tool row and seed row keep a clear vertical gutter")

	var barn: Node = _find_named(_garden, "BarnShortcut")
	var deco: Node = _find_named(_garden, "DecoDoor")
	for utility_and_name in [[barn, "barn"], [deco, "sticker book"]]:
		var utility: Node = utility_and_name[0]
		var utility_name := str(utility_and_name[1])
		_ok(_visible_control_inside(utility, screen),
			"the %s shortcut stays visible in the base shelf" % utility_name)
		_ok(_controls_are_separate(seed_deck, utility, 4.0),
			"the seed lane leaves the %s shortcut tappable" % utility_name)
	_ok(shelf is Control and top is Control
		and not (shelf as Control).get_global_rect().intersects(
			(top as Control).get_global_rect()),
		"top information and bottom tools leave the farm window between them")


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
	# The quiet clock stays off: its 20 s beat is wall-clock, and settle_farm()
	# swaps SaveManager.data["farm"] for a copy, which strands any `farm`
	# reference a section is holding. The beat itself is tested below by
	# calling _garden_tick_once() directly, where the probe chooses the moment.
	_garden.set("_garden_tick_running", false)


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


func _finger(from: Vector2, to: Vector2, after_press: Callable = Callable()) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(from)
	Input.parse_input_event(down)
	await get_tree().process_frame
	if after_press.is_valid():
		await after_press.call()

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


## A brush should make its honest targets easy to spot before a small hand
## starts a sweep. At this point bed 0 is the only turned patch, so the seed
## brush has exactly one true target; restoring the hand leaves the following
## real rack-to-bed drag in its original state.
func _the_selected_tool_marks_its_possible_beds() -> void:
	var seed: Variant = (_garden.get("_tool_buttons") as Dictionary).get("seed")
	_ok(seed is Button and not (seed as Button).disabled,
		"the seed brush is live when one bed has been turned")
	if seed is Button:
		await _tap((seed as Control).get_global_rect().get_center())
	var tool_controller: Variant = _garden.get("_tools")
	_ok(tool_controller != null and str(tool_controller.get("selected")) == "seed"
			and _lit_tool_target_indices() == [0],
		"choosing seed circles only the turned bed it can really plant in")

	var world: Node = _garden.get("_world")
	var beds: Array = world.get("_beds") if world != null else []
	var halo: Node = beds[0].get_node_or_null("ToolTargetHalo") if not beds.is_empty() else null
	var ring: Node = halo.get_node_or_null("ToolTargetRing") if halo != null else null
	_ok(halo is Node2D and ring is Node2D
			and not (halo is Control) and not (ring is Control),
		"a possible-bed halo is world art, never a control that can eat a drag")

	var hand: Variant = (_garden.get("_tool_buttons") as Dictionary).get(Tools.HAND)
	_ok(hand is Button, "the familiar hand remains available to leave brush mode")
	if hand is Button:
		await _tap((hand as Control).get_global_rect().get_center())
	tool_controller = _garden.get("_tools")
	_ok(tool_controller != null and str(tool_controller.get("selected")) == Tools.HAND
			and _lit_tool_target_indices().is_empty(),
		"returning to the hand clears every possible-bed halo")


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
	var flight: Node = _find_named(_garden, "HarvestFlight_strawberry")
	_ok(flight != null, "tap harvesting keeps the strawberry visible while it flies")
	if flight != null:
		_ok(str(flight.get_meta("crop_id", "")) == "strawberry",
			"the flight remembers the crop after the bed is reset")
		_ok(int(flight.get_meta("amount", 0)) == expected,
			"the flight remembers the crop's real harvest amount")
	var yield_label: Node = _find_named(_garden, "HarvestYield")
	_ok(yield_label is Label and str((yield_label as Label).text) == "x%d" % expected,
		"tap harvesting says the real yield, not one picked bed")
	await get_tree().create_timer(0.5).timeout
	_ok(_find_named(_garden, "HarvestFlight_strawberry") == null,
		"the short harvest flight cleans itself up")

	# Tapping the empty bed again must not pay a second time.
	await _tap(_bed(3))
	barn = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("strawberry", 0)) == expected,
		"tapping the same bed again pays nothing -- one planting, one harvest")

	# The transaction id was written down, and it names the bed and the planting.
	var paid: Array = SaveManager.data["farm"].get("paid_harvests", [])
	_ok("farm_harvest_plot_4_7" in paid,
		"the harvest is recorded against the bed and the planting it came from")


## A full barn is not a failure state. The child must see the same split the
## receipt really made: what fitted flies to the barn; what did not fits in the
## fixed overflow basket by its door. Run both partial and fully-full cases on
## the real tap path, in each screen shape.
func _overflow_harvests_show_their_real_landing_places() -> void:
	var plots := _plots()
	var split: Dictionary = Farm.fresh_plot(4)
	split["crop_id"] = "carrot"
	split["growth_stage"] = 4
	split["plant_cycle_id"] = 51
	split["state"] = Farm.READY
	plots[4] = split
	var farm: Dictionary = SaveManager.data["farm"]
	farm["warehouse"] = {"corn": Barn.cap() - 2}
	farm["harvest_basket"] = {}
	farm["paid_harvests"] = []
	# This fixture reaches the capacity lesson by design; it is not testing the
	# market's finger, which would add an unrelated guide to the flight layer.
	farm["market_taught"] = true
	SaveManager.data["farm"] = farm
	SaveManager.save_game()
	_garden.call("_rebuild")
	for i in range(2):
		await get_tree().process_frame

	var partial_amount := int(GameData.get_crop("carrot").get("harvest_amount", 0))
	await _tap(_bed(4))
	var stored: Node = _find_named(_garden, "HarvestFlight_carrot")
	var spilled: Node = _find_named(_garden, "HarvestSpillFlight_carrot")
	_ok(Barn.count("carrot", Barn.WAREHOUSE) == 2
		and Barn.count("carrot", Barn.BASKET) == partial_amount - 2,
		"a nearly full barn stores two carrots and spills the truthful remainder")
	_ok(stored != null and spilled != null,
		"a partial harvest creates one receipt flight to each real destination")
	if stored != null:
		_ok(int(stored.get_meta("amount", 0)) == 2
			and str(stored.get_meta("destination", "")) == "warehouse",
			"the barn flight carries only the two carrots that fitted")
		var stored_count: Node = stored.get_node_or_null("FlightAmount")
		_ok(stored_count is Label and str((stored_count as Label).text) == "×2",
			"the partial barn receipt says x2 instead of pretending it carried all")
		var shortcut: Node = _find_named(_garden, "BarnShortcut")
		var shortcut_centre := Vector2.INF
		if shortcut is Control:
			shortcut_centre = (shortcut as Control).get_global_rect().get_center()
		var stored_landing: Variant = stored.get_meta("destination_at", Vector2.INF)
		_ok(stored_landing is Vector2 and shortcut_centre != Vector2.INF
			and (stored_landing as Vector2).distance_to(shortcut_centre) < 0.5,
			"the barn receipt actually lands on the rebuilt barn shortcut")
	var partial_landing := Vector2.INF
	if spilled != null:
		var landing: Variant = spilled.get_meta("destination_at", Vector2.INF)
		if landing is Vector2:
			partial_landing = landing as Vector2
		_ok(int(spilled.get_meta("amount", 0)) == partial_amount - 2
			and str(spilled.get_meta("destination", "")) == "harvest_basket"
			and partial_landing != Vector2.INF,
			"the overflow flight carries only the remainder to the real basket")
		var spill_count: Node = spilled.get_node_or_null("FlightAmount")
		_ok(spill_count is Label and str((spill_count as Label).text)
				== "×%d" % (partial_amount - 2),
			"the partial overflow receipt says exactly what is waiting")
	var overflow: Node = _find_named(_garden, "HarvestOverflowBasket")
	var basket_landing: Variant = overflow.get_meta("destination_at", Vector2.INF) \
		if overflow != null else Vector2.INF
	_ok(overflow != null and basket_landing is Vector2
		and (basket_landing as Vector2).distance_to(partial_landing) < 0.5,
		"the rebuilt overflow basket is exactly where the spill flight is headed")
	var visible_basket_landing := Vector2.INF
	if overflow is Control:
		# UiKit's picture is 30px wide and sits six pixels above the shelf,
		# so this is the centre of the basket the child actually sees.
		visible_basket_landing = (overflow as Control).position + Vector2(15.0, 15.0)
		var door := _find_named(_garden, "DecoDoor") as Control
		_ok(door == null or not (overflow as Control).get_global_rect().intersects(door.get_global_rect()),
			"the decorating door does not hide the partial overflow basket")
	_ok(visible_basket_landing != Vector2.INF
		and visible_basket_landing.distance_to(partial_landing) < 0.5,
		"the spill receipt lands on the visible centre of the overflow basket")
	await get_tree().create_timer(0.5).timeout
	_ok(_find_named(_garden, "HarvestFlight_carrot") == null
		and _find_named(_garden, "HarvestSpillFlight_carrot") == null,
		"both split receipts clean up after their short answer")

	# A second crop while the barn is full must use the SAME basket rim. The
	# rebuilt pile gains another row to the left, but an earlier flight cannot
	# chase a moving target halfway through one brush/tap sequence.
	var full: Dictionary = Farm.fresh_plot(5)
	full["crop_id"] = "strawberry"
	full["growth_stage"] = 4
	full["plant_cycle_id"] = 52
	full["state"] = Farm.READY
	plots[5] = full
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	_garden.call("_rebuild")
	for i in range(2):
		await get_tree().process_frame

	var full_amount := int(GameData.get_crop("strawberry").get("harvest_amount", 0))
	await _tap(_bed(5))
	var should_not_exist: Node = _find_named(_garden, "HarvestFlight_strawberry")
	var full_spill: Node = _find_named(_garden, "HarvestSpillFlight_strawberry")
	_ok(should_not_exist == null and full_spill != null,
		"a full barn sends the whole harvest only to the overflow basket")
	_ok(Barn.count("strawberry", Barn.WAREHOUSE) == 0
		and Barn.count("strawberry", Barn.BASKET) == full_amount,
		"a full barn keeps every strawberry in the overflow basket, not nowhere")
	if full_spill != null:
		var full_landing: Variant = full_spill.get_meta("destination_at", Vector2.INF)
		_ok(int(full_spill.get_meta("amount", 0)) == full_amount
			and str(full_spill.get_meta("destination", "")) == "harvest_basket"
			and full_landing is Vector2
			and (full_landing as Vector2).distance_to(partial_landing) < 0.5,
			"new crop kinds extend left but every spill keeps the same basket rim")
	overflow = _find_named(_garden, "HarvestOverflowBasket")
	_ok(overflow != null and int(overflow.get_meta("crop_kinds", 0)) == 2,
		"the shelf redraws both spilled crop kinds under the fixed basket")
	if overflow is Control:
		visible_basket_landing = (overflow as Control).position + Vector2(15.0, 15.0)
		var door := _find_named(_garden, "DecoDoor") as Control
		_ok(door == null or not (overflow as Control).get_global_rect().intersects(door.get_global_rect()),
			"the decorating door does not hide the full overflow basket")
	_ok(visible_basket_landing != Vector2.INF
		and visible_basket_landing.distance_to(partial_landing) < 0.5,
		"a new crop row grows left without moving the visible basket rim")
	await get_tree().create_timer(0.5).timeout
	_ok(_find_named(_garden, "HarvestSpillFlight_strawberry") == null,
		"the full-overflow receipt also cleans itself up")
	# Do not make the next independent regression inherit a full barn and a
	# waiting basket. Its reload path deliberately asks SaveManager to settle
	# storage, which would otherwise turn this fixture into its starting state.
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.data["farm"]["harvest_basket"] = {}
	SaveManager.save_game()


## The app settles the save on resume. The world stays in place, so this asks
## whether its existing PlotView redraws instead of showing the old seed.
func _a_resumed_garden_redraws_settled_beds() -> void:
	var now := GameClock.now_unix()
	var plots := _plots()
	var plot: Dictionary = plots[0]
	plot["state"] = Farm.SEEDED
	plot["crop_id"] = "carrot"
	plot["growth_stage"] = 0
	plot["growth_progress"] = 0.0
	plot["water_level"] = 1.0
	plot["care_event"] = ""
	plot["care_completed"] = false
	plot["growth_override_seconds"] = 0
	plot["planted_at"] = now
	plot["last_updated_at"] = now
	plots[0] = plot
	var farm: Dictionary = SaveManager.data["farm"]
	farm["plots"] = plots
	farm["last_seen_at"] = now
	farm["clock_high_water"] = now
	SaveManager.data["farm"] = farm
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node = _garden.get("_world")
	var beds: Array = world.get("_beds")
	var bed: Node = beds[0]
	var before := str(bed.get("_looked_like"))
	GameClock.advance_test(5 * 60)
	GameManager._notification(NOTIFICATION_APPLICATION_RESUMED)
	for i in range(3):
		await get_tree().process_frame

	var grown: Dictionary = _plots()[0]
	var after := str(bed.get("_looked_like"))
	_ok(int(grown.get("growth_stage", 0)) > 0
			or float(grown.get("growth_progress", 0.0)) > 0.0,
		"resume settles the planted crop before the garden continues")
	_ok(after != before,
		"resume redraws the existing bed instead of leaving the old seed picture")
	_ok(after == str(bed.call("_fingerprint", grown)),
		"the resumed bed fingerprint matches the newly settled save")


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


## 二期阶段 2：凑齐配料小熊教一次，教过的写进存档，菜谱本亮对行。
func _the_bear_teaches_once_and_it_sticks() -> void:
	var Recipes := preload("res://scripts/garden/recipe_manager.gd")
	var Barn := preload("res://scripts/garden/inventory_manager.gd")
	# 凑齐草莓甜汤的三颗草莓
	Barn.put("strawberry", 3)
	var fresh: Array = Recipes.check_barn()
	_ok(fresh.size() == 1 and str(fresh[0].get("id", "")) == "strawberry_soup",
		"three strawberries in the barn should teach exactly the soup, got %s"
		% [fresh])
	_ok(Recipes.check_barn().is_empty(),
		"checking again re-taught something -- a child congratulated twice "
		+ "for one dish learns the praise is a machine")
	_ok(Recipes.is_unlocked("strawberry_soup"), "the ledger did not keep it")

	# 存档往返
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(Recipes.is_unlocked("strawberry_soup"),
		"the recipe vanished across a save round-trip")
	_ok(Barn.has("strawberry", 3),
		"unlocking a recipe took the strawberries -- collecting must never "
		+ "confiscate the harvest it praises")

	# 菜谱本面板：知道的亮着，不知道的只有暗配料。十二道菜翻两页，
	# 每一页的行数和翻完见到的总数都要对上——一页 6 行不是"只有 6 道"。
	_garden.call("_open_panel", "recipes")
	await get_tree().process_frame
	await get_tree().process_frame
	var total := GameData.garden_recipes.size()
	var seen := 0
	var pages_walked := 0
	while true:
		pages_walked += 1
		var rows := _recipe_rows()
		_ok(rows == mini(6, total - seen),
			"page %d of the recipe book shows %d rows, wanted %d"
			% [pages_walked, rows, mini(6, total - seen)])
		seen += rows
		var next: Variant = (_garden.get("_panel_buttons") as Dictionary)\
			.get("page_next")
		if not (next is Button) or pages_walked > 8:
			break
		(next as Button).pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	_ok(seen == total,
		"flipping to the end of the book met %d recipes of %d" % [seen, total])
	_garden.call("_close_panels")
	await get_tree().process_frame


## Count the recipe rows standing on the sheet right now.
func _recipe_rows() -> int:
	var rows := 0
	for child in (_garden.get("_play") as Node).get_children():
		if child is Panel and (child as Panel).size == Vector2(640.0 - 48.0, 56.0):
			rows += 1
	return rows


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

	# 三期阶段 3：家具会答话，但排在最后。一件摆在 0 号地正中的家具，
	# 点下去必须还是地在答（翻土）、家具一动不动；一件摆在空草地上的，
	# 点下去它才答应（歪头回弹）。红线原文——家具从不吞掉给地里的
	# 手指——两头都被按过才算数。
	var world = _garden.get("_world")
	# Where the room would have saved them on THIS screen: the room lays
	# its canvas out on the real viewport, and the garden reads the
	# fractions against it, so a 4:3 tablet writes taller y's.
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	SaveManager.set_creation("garden", [
		{"icon": "heart", "x": 259.0, "y": 255.0 * canvas.y / 720.0, "size": 84.0},
		{"icon": "flag", "x": 477.0, "y": 377.0 * canvas.y / 720.0, "size": 84.0},
	])
	var plots := _plots()
	plots[0]["state"] = Farm.EMPTY
	plots[0]["crop_id"] = ""
	SaveManager.save_game()
	world.call("go_home")
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	layer = _find_named(_garden, "Decorations")
	_ok(layer != null and layer.get_child_count() == 2,
		"two pieces of furniture stand for the poke test")
	# 数的是世界的 grass_pressed：家具只可能从这里被问到。地认领的
	# 点击必须一次都没流到草地上——这是红线的可观测形状。
	# （翻土会触发重建、家具节点会换新，所以断言不抓旧节点，抓信号。）
	var grass_taps := [0]
	world.grass_pressed.connect(func(_at: Vector2): grass_taps[0] += 1)
	await _tap(_bed(0))
	_ok(str(_plots()[0].get("state", "")) == Farm.TILLED,
		"a tap on the bed a decoration covers still turns the earth")
	_ok(grass_taps[0] == 0,
		"...and that tap was never offered to the furniture")
	layer = _find_named(_garden, "Decorations")
	_ok(layer != null and layer.get_child_count() == 2,
		"the till's rebuild set the furniture back up")
	if layer != null and layer.get_child_count() == 2:
		var open_air := layer.get_child(1) as Control
		var spot: Vector2 = world.camera.world_to_screen(
			open_air.position + open_air.size * 0.5)
		await _tap(spot)
		await get_tree().create_timer(0.12).timeout
		_ok(grass_taps[0] == 1,
			"a tap nothing else claimed is offered to the grass exactly once")
		# The stamp, not the rotation: the wiggle is 0.39 s long and a frame
		# on a loaded machine can land after it.
		_ok(open_air.has_meta("poked_at"),
			"...and the furniture answers it with a wiggle")

	# And the hero base's shelf is exactly as it was.
	var base_before: Array = SaveManager.get_creation("base")
	SaveManager.set_creation("garden", [])
	_garden.call("_draw_decorations")
	_ok(SaveManager.get_creation("base") == base_before,
		"touching the garden's decorations moved the hero base's shelf")


## 三期阶段 1：加工小屋。先问再扣是这面板的脾气——按「做一份」只竖起
## 确认条，食材要等那个绿勾才离开，和仓库升级同一个规矩。这里全程用
## 屏幕上的东西驱动：小屋是走过去按的（路由是新东西，直接拨 flag 就
## 测不到它），面板上的片子从 _panel_buttons 的把手上按。
func _the_kitchen_asks_before_ingredients_leave() -> void:
	var Recipes := preload("res://scripts/garden/recipe_manager.gd")
	# 5 级农场，会做甜汤，仓库里正好一锅的量，架上还有一份昨天做的。
	var farm: Dictionary = SaveManager.data["farm"]
	farm["farm_xp"] = 200
	farm["unlocked_recipes"] = ["strawberry_soup"]
	farm["warehouse"] = {"strawberry": 3}
	SaveManager.data["inventory"] = {"dish_strawberry_soup": 1}
	SaveManager.save_game()
	_garden.call("_close_panels")
	_garden.call("_rebuild")
	await get_tree().process_frame

	# 走到小屋跟前，像拇指一样按下去。
	var world = _garden.get("_world")
	var at: Vector2 = world.facility_screen_position("workshop")
	if not world.camera.inside(at):
		world.look_at_facility("workshop")
		await get_tree().process_frame
		at = world.facility_screen_position("workshop")
	await _tap(at)
	_ok(bool(_garden.get("_kitchen_open")),
		"at level 5 pressing the workshop opens the kitchen")

	var buttons: Dictionary = _garden.get("_panel_buttons")
	var cook: Variant = buttons.get("cook_strawberry_soup")
	_ok(cook is Button, "the kitchen shows a cook chip for the soup he knows")
	if cook is Button:
		_ok((cook as Button).pressed.get_connections().size() > 0,
			"and the chip is wired to something")
		(cook as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		# 按了「做一份」，什么都还不许离开——先问，是这面板的脾气。
		_ok(Barn.count("strawberry") == 3,
			"pressing cook must take nothing yet -- ingredients leave only "
			+ "after the confirm")
		_ok(str(_garden.get("_confirm_cook")) == "strawberry_soup",
			"the confirm strip is up instead")

	# 说不：条子收起来，锅是冷的，架上还是那一份。
	buttons = _garden.get("_panel_buttons")
	var no: Variant = buttons.get("cancel_cook")
	_ok(no is Button, "the strip has a way to say no")
	if no is Button:
		(no as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		_ok(str(_garden.get("_confirm_cook")) == "", "saying no puts the strip away")
		_ok(Barn.count("strawberry") == 3
				and Recipes.dish_count("strawberry_soup") == 1,
			"and the no took nothing and cooked nothing")

	# 再来一次，这次点绿勾：三颗草莓恰好离开，架上多恰好一份。
	buttons = _garden.get("_panel_buttons")
	var cook_again: Variant = buttons.get("cook_strawberry_soup")
	if cook_again is Button:
		(cook_again as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	var yes: Variant = buttons.get("confirm_cook")
	_ok(yes is Button, "the strip has its green yes")
	if yes is Button:
		(yes as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		_ok(Barn.count("strawberry") == 0,
			"the confirmed cook takes exactly the recipe's ingredients")
		_ok(Recipes.dish_count("strawberry_soup") == 2,
			"and exactly one more dish is on the shelf")

	# 送给小熊：一份出门，友谊多一颗星，谢饭条目登上访客板。
	var stars := int((SaveManager.data["farm"].get("npc_friendship", {})
		as Dictionary).get("bear", 0))
	buttons = _garden.get("_panel_buttons")
	var give: Variant = buttons.get("give_strawberry_soup")
	_ok(give is Button, "a dish on the shelf shows the give chip")
	if give is Button:
		(give as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		_ok(Recipes.dish_count("strawberry_soup") == 1,
			"giving hands over exactly one dish")
		_ok(int((SaveManager.data["farm"]["npc_friendship"] as Dictionary)
				.get("bear", 0)) == stars + 1,
			"and the friendship grows by exactly one star")
		var log: Array = SaveManager.data["farm"].get("visit_log", [])
		_ok(not log.is_empty()
				and str((log[0] as Dictionary).get("kind", "")) == "thanks",
			"and the thank-you is the newest thing on the visit board")

	_garden.call("_close_panels")
	await get_tree().process_frame

	# 4 级农场再按同一块地：不开门，也没有锁——只有还没长到。
	farm = SaveManager.data["farm"]
	farm["farm_xp"] = 120
	_garden.call("_rebuild")
	await get_tree().process_frame
	at = world.facility_screen_position("workshop")
	if not world.camera.inside(at):
		world.look_at_facility("workshop")
		await get_tree().process_frame
		at = world.facility_screen_position("workshop")
	await _tap(at)
	_ok(not bool(_garden.get("_kitchen_open")),
		"below level 5 the workshop stays quiet ground -- no kitchen and no lock")
	_garden.call("_close_panels")
	await get_tree().process_frame


## 三期阶段 2：十四种种子轮流站上货架。货架翻页翻到的种子拖出去真能种；
## 种子铺没长到的排是暗剪影加星章（连能按的芽都没有——按不了的买 chip
## 是戴着笑脸的锁）；厨房学到第七道菜时也翻页；订单板只挂长到了的活，
## 先挂没干完的，干完的回执垫空位，永远三张。
func _fourteen_seeds_take_turns() -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	var everything := ["carrot", "corn", "strawberry", "tomato", "lettuce",
		"potato", "peas", "wheat", "broccoli", "pumpkin", "watermelon",
		"grape", "orange", "apple"]
	farm["farm_xp"] = 200
	farm["unlocked_crops"] = everything.duplicate()
	SaveManager.data["rewards"]["coins"] = 500
	SaveManager.save_game()
	_garden.call("_close_panels")
	# The kitchen section walked the camera to the workshop; the drag below
	# aims at bed 0, so walk home first the way the screen itself would.
	(_garden.get("_world") as Node).call("go_home")
	_garden.call("_rebuild")
	await get_tree().process_frame

	# 货架第一页：七块整整齐齐，向右的箭头站在第八块的位置上。
	_ok(_rack_tiles() == 7, "page one of the rack holds seven tiles")
	var buttons: Dictionary = _garden.get("_panel_buttons")
	_ok(not (buttons.get("rack_back") is Button),
		"no back arrow on the first page -- an arrow that shakes its head "
		+ "is a lock")
	var next: Variant = buttons.get("rack_next")
	_ok(next is Button, "fourteen crops give the rack a next arrow")
	var seed_deck: Node = _find_named(_garden, "GardenSeedDeck")
	var pager_deck: Node = _find_named(_garden, "GardenSeedPagerDeck")
	_ok(next is Button and seed_deck is Control and pager_deck is Control
			and (pager_deck as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
			and absf((pager_deck as Control).get_global_rect().position.x
				- (seed_deck as Control).get_global_rect().end.x) <= 4.0
			and _control_contains(pager_deck, next, 2.0),
		"the first-page arrow lives in a passive eighth seed slot, not empty shelf space")

	# 翻到第二页，把第二页的第一颗（小麦）真的拖进地里。
	if next is Button:
		(next as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		_ok(_rack_tiles() == 7, "page two holds the other seven")
		var back: Variant = (_garden.get("_panel_buttons") as Dictionary).get("rack_back")
		_ok(back is Button, "and now there is a way back")
		seed_deck = _find_named(_garden, "GardenSeedDeck")
		pager_deck = _find_named(_garden, "GardenSeedPagerDeck")
		_ok(back is Button and seed_deck is Control and pager_deck is Control
			and absf((pager_deck as Control).get_global_rect().position.x
				- (seed_deck as Control).get_global_rect().end.x) <= 4.0
			and _control_contains(pager_deck, back, 2.0),
		"the return arrow keeps the same eighth-slot home beside the seed pouch")
		var plots := _plots()
		plots[0]["state"] = Farm.TILLED
		plots[0]["crop_id"] = ""
		SaveManager.save_game()
		_garden.call("_rebuild")
		await get_tree().process_frame
		await _finger(_seed_tile(0), _bed(0))
		_ok(str(_plots()[0].get("crop_id", "")) == "wheat",
			"a seed dragged off page two lands in the bed like any seed")

	# 种子铺：2 级农场翻到第二页，没长到的排上一个能按的芽都没有。
	farm = SaveManager.data["farm"]
	farm["unlocked_crops"] = ["carrot", "corn", "strawberry", "tomato",
		"lettuce", "potato"]
	farm["farm_xp"] = 20
	SaveManager.save_game()
	_garden.call("_open_panel", "shop")
	await get_tree().process_frame
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	var flip: Variant = buttons.get("page_next")
	_ok(flip is Button, "fourteen seeds give the shop a second page")
	if flip is Button:
		(flip as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		_ok(_buy_chip_count() == 0,
			"at level 2 the whole second page is quiet ground -- not one "
			+ "buy chip on a seed the farm has not grown to")

	# 3 级：这一批开卖，下一批还站着。
	SaveManager.data["farm"]["farm_xp"] = 60
	_garden.call("_open_panel", "shop")
	await get_tree().process_frame
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	if buttons.get("page_next") is Button:
		(buttons.get("page_next") as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.get("buy_peas") is Button,
		"at level 3 the peas grow a buy chip")
	_ok(not (buttons.get("buy_watermelon") is Button),
		"and the watermelon still waits for level 5")

	# 5 级：果园开门。
	SaveManager.data["farm"]["farm_xp"] = 200
	_garden.call("_open_panel", "shop")
	await get_tree().process_frame
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	if buttons.get("page_next") is Button:
		(buttons.get("page_next") as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.get("buy_watermelon") is Button,
		"level 5 lets the watermelon onto the counter")

	# 厨房：会做第七道菜的那天，锅台也学会翻页。
	SaveManager.data["farm"]["unlocked_recipes"] = ["strawberry_soup",
		"potato_cakes", "tomato_stew", "corn_chowder", "rainbow_salad",
		"harvest_platter", "pea_soup"]
	_garden.call("_open_panel", "kitchen")
	await get_tree().process_frame
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.get("page_next") is Button,
		"seven known dishes give the kitchen a second page")
	if buttons.get("page_next") is Button:
		(buttons.get("page_next") as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		buttons = _garden.get("_panel_buttons")
		_ok(buttons.get("cook_pea_soup") is Button,
			"and the seventh dish has its cook chip on page two")
	_garden.call("_close_panels")
	await get_tree().process_frame

	# 订单板：长到了才挂出来，没干完的先挂，回执垫空位，永远三张。
	SaveManager.data["farm"]["farm_xp"] = 0
	var board: Array = _garden.call("_orders_for_board", [])
	_ok(board.size() == 3 and _board_ids(board) == ["bear_carrots",
		"robot_supply", "puppy_berries"],
		"at level 1 the board hangs exactly the three first orders")
	SaveManager.data["farm"]["farm_xp"] = 60
	board = _garden.call("_orders_for_board",
		["bear_carrots", "robot_supply", "puppy_berries"])
	_ok(_board_ids(board) == ["robot_wheat_run", "bear_pumpkin_treat",
		"puppy_pea_picnic"],
		"level 3 work replaces finished work, oldest receipts leave first")
	var all_l3 := ["bear_carrots", "robot_supply", "puppy_berries",
		"robot_wheat_run", "bear_pumpkin_treat", "puppy_pea_picnic"]
	board = _garden.call("_orders_for_board", all_l3)
	# 不只数张数：3 级农场干完了 3 级的活，板上不许有 5 级的活提前挂
	# 出来——只数 size 的话，等级门被拆了这里照样绿。故事单谢完之后，
	# 板上的活是本级别的周期单（看板永远有活干，这是周期单的职责）；
	# 回执只在故事单还没谢完的时候垫空位。
	var no_future_work := board.size() == 3
	for entry in board:
		var gate := str((entry as Dictionary).get("unlock_condition", ""))
		if gate.begins_with("level:") and int(gate.substr(6)) > 3:
			no_future_work = false
	_ok(no_future_work,
		"a level-3 board with the story work done shows its own level's "
		+ "recurring work, never level-5 work ahead of its level")
	SaveManager.data["farm"]["farm_xp"] = 200
	board = _garden.call("_orders_for_board", ["bear_carrots", "robot_supply",
		"puppy_berries", "robot_wheat_run", "bear_pumpkin_treat",
		"puppy_pea_picnic"])
	_ok(_board_ids(board).slice(0, 2) == ["robot_melon_delivery",
		"bear_orchard_basket"],
		"level 5 hangs the orchard orders the day the orchard opens")

	# 真的画出来也一样多：开一次板子数卡片。
	_garden.call("_open_panel", "orders")
	await get_tree().process_frame
	await get_tree().process_frame
	var cards: Array = []
	_collect_order_cards(_garden, cards)
	_ok(cards.size() == 3, "the drawn board holds exactly three cards")
	_garden.call("_close_panels")
	await get_tree().process_frame


## The added guidance is not a second quest system: when a ripe crop exists it
## names that crop, leaves the bed uncovered, and the visible barn card really
## opens the old barn panel. This is run through both screen shapes because the
## ribbon belongs in the spare shelf lane and must never cover a target bed.
func _the_next_step_and_barn_shortcut_are_honest() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var compact := view.x / maxf(view.y, 1.0) < 1.6
	_garden.call("_close_panels")
	var farm: Dictionary = SaveManager.data["farm"]
	farm["tutorial_completed"] = true
	farm["farm_xp"] = 0
	farm["unlocked_crops"] = ["carrot", "corn", "strawberry", "tomato"]
	var plots: Array = []
	for i in range(Farm.PLOT_COUNT):
		plots.append(Farm.fresh_plot(i))
	var ripe: Dictionary = plots[0]
	ripe["state"] = Farm.READY
	ripe["crop_id"] = "carrot"
	ripe["growth_stage"] = 4
	ripe["growth_progress"] = 1.0
	ripe["plant_cycle_id"] = 17
	plots[0] = ripe
	farm["plots"] = plots
	# Two of the three familiar daily verbs are already cared for. The ribbon
	# must show that derived fact without changing which ripe bed is next.
	farm["dailies"] = {"date": GameClock.now_date(),
		"progress": {"water": 3, "harvest": 5}, "claimed": []}
	SaveManager.data["farm"] = farm
	SaveManager.data["farm_orders"] = {"delivered": []}
	SaveManager.data["farm"]["warehouse"] = {"carrot": 20}
	_garden.set("_lesson_running", false)
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame

	var task: Node = _find_named(_garden, "NextTask")
	_ok(task is Button, "the garden gives one visible next step after the lesson")
	var task_rect := Rect2()
	if task is Button:
		var ribbon := task as Button
		task_rect = Rect2(ribbon.global_position, ribbon.size)
		_ok(ribbon.visible and ribbon.size.x >= 240.0,
			"the next-step card remains a readable, visible touch target")
		_ok(Rect2(Vector2.ZERO, view).encloses(task_rect),
			"the hero task card stays entirely inside this screen shape")
		_ok(str(ribbon.get_meta("kind", "")) == "harvest",
			"a ripe crop wins the next-step ribbon")
		_ok(int(ribbon.get_meta("plot_index", -1)) == 0,
			"the ribbon names the same ripe plot the farm points at")
		var hero_icon := ribbon.get_node_or_null("HeroTaskIconBadge/HeroTaskIcon") as Control
		var hero_badge := ribbon.get_node_or_null("HeroTaskIconBadge") as Control
		var hero_action := ribbon.get_node_or_null("HeroTaskAction") as Label
		var hero_preview := ribbon.get_node_or_null("HeroTaskPreview/HeroTaskProgress") as Label
		_ok(hero_icon != null and hero_icon.visible and hero_action != null \
			and hero_action.visible and (compact or (hero_preview != null \
			and hero_preview.visible)),
			"the hero task card keeps its picture and one clear action, plus an order preview when it fits")
		var daily := ribbon.get_node_or_null("HeroTaskDaily") as Control
		var daily_icon := ribbon.get_node_or_null("HeroTaskDaily/HeroTaskDailyIcon") as Control
		var daily_progress := ribbon.get_node_or_null("HeroTaskDaily/HeroTaskDailyProgress") as Label
		if compact:
			_ok(daily == null,
				"the compact task card yields its secondary daily row to one action")
			_ok(daily_icon == null and daily_progress == null,
				"the compact card leaves no hidden daily picture or words beside the action")
			_ok(hero_preview == null,
				"the compact task card also yields its optional order preview")
			_ok(hero_action != null and absf(hero_action.get_global_rect().get_center().y
				- task_rect.get_center().y) <= 1.0,
				"the one compact next-action line is vertically centred in its card")
			_ok(hero_action != null
				and hero_action.get_global_rect().position.y >= task_rect.position.y + 12.0
				and hero_action.get_global_rect().end.y <= task_rect.end.y - 12.0,
				"the compact next-action line keeps real top and bottom breathing room")
		else:
			_ok(daily != null and int(daily.get_meta("done", -1)) == 2
				and int(daily.get_meta("total", -1)) == 3
				and not bool(daily.get_meta("all_done", true)),
				"the task card shows the same two-of-three daily care state as the save")
			_ok(daily_progress != null and daily_progress.text == "2/3"
				and ribbon.get_node_or_null("HeroTaskDaily/HeroTaskDailyStar_0") != null
				and ribbon.get_node_or_null("HeroTaskDaily/HeroTaskDailyStar_2") != null,
				"the daily crest keeps both a readable tally and all three small stars")
			_ok(daily_progress != null and hero_action != null
				and not daily_progress.get_global_rect().intersects(hero_action.get_global_rect()),
				"daily words and the next action keep separate reading lines")
			_ok(daily_icon != null and daily_progress != null
				and daily_progress.get_global_rect().position.x - daily_icon.get_global_rect().end.x >= 7.0,
				"the daily reward words do not stick to their crest icon")
			var daily_star := ribbon.get_node_or_null("HeroTaskDaily/HeroTaskDailyStar_0") as Control
			_ok(daily_star != null and daily_progress != null
				and daily_star.get_global_rect().position.x
				- daily_progress.get_global_rect().end.x >= 6.0,
				"the daily tally words leave air before their decorative stars")
		_ok(hero_badge != null and hero_action != null
			and hero_action.get_global_rect().position.x - hero_badge.get_global_rect().end.x >= 11.0,
			"the primary task words leave a clear gutter after their picture badge")
		if hero_action != null and hero_preview != null:
			_ok(not hero_action.get_global_rect().intersects(hero_preview.get_global_rect()),
				"the next action and order words keep separate reading lines")
			var preview_icon := ribbon.get_node_or_null("HeroTaskPreview/HeroTaskPreviewIcon") as Control
			_ok(preview_icon != null and hero_preview.get_global_rect().position.x
				- preview_icon.get_global_rect().end.x >= 6.0,
				"order progress words do not stick to their crop picture")
		else:
			_ok(compact,
				"a compact shelf yields optional order text before squeezing three reading lines")
			_ok(compact,
				"a compact shelf has no hidden order icon next to the next-action words")
		var arrow := ribbon.get_node_or_null("HeroTaskArrow") as Label
		_ok(hero_action != null and arrow != null
			and arrow.get_global_rect().position.x - hero_action.get_global_rect().end.x >= 10.0,
			"the next-action words leave a clear gutter before their arrow")
		var derived: Dictionary = _garden.call("_next_task")
		_ok(hero_action != null and hero_action.text == _garden.call("_next_task_text", derived),
			"the hero task words come from the one derived garden task")
		var half := _bed_box() * 0.5
		var bed := Rect2(_bed(0) - half, half * 2.0)
		_ok(not task_rect.intersects(bed),
			"the next-step ribbon leaves its target crop tappable")
		var shelf: Control = _garden.get("_shelf")
		_ok(shelf != null and ribbon.get_index() > shelf.get_index(),
			"the next-step ribbon sits above the shelf instead of behind it")
		_ok(shelf != null and Rect2(shelf.global_position, shelf.size) \
			.encloses(task_rect.grow(5.0)),
			"the breathing next-step card stays inside the shelf")
		var tools: Dictionary = _garden.get("_tool_buttons")
		var basket_tool: Variant = tools.get("basket")
		if basket_tool is Control:
			_ok(not task_rect.grow(5.0).intersects(Rect2(
				(basket_tool as Control).global_position,
				(basket_tool as Control).size)),
				"the next-step card leaves the harvest tool tappable")
		if compact:
			var right_tool_edge := 0.0
			var tool_row_y := -1.0
			for item in tools.values():
				if item is Control:
					var tool: Control = item as Control
					right_tool_edge = maxf(right_tool_edge,
						tool.global_position.x + tool.size.x)
					tool_row_y = maxf(tool_row_y, tool.global_position.y)
			_ok(right_tool_edge > 0.0 and task_rect.position.x >= right_tool_edge + 8.0
				and task_rect.end.x <= view.x - 20.0,
				"the compact next step fills only the empty right end of the tool row")
			_ok(tool_row_y >= 0.0 and absf(task_rect.position.y - tool_row_y) <= 4.0,
				"the compact next step stays aligned with the tools, not the seed row")
		var decor: Node = _find_named(_garden, "DecoDoor")
		if decor is Control:
			_ok(not task_rect.grow(5.0).intersects(Rect2((decor as Control).global_position,
				(decor as Control).size)),
				"the next-step card leaves the sticker-book door tappable")
		var farm_world = _garden.get("_world")
		if farm_world != null:
			var beds: Array = farm_world.get("_beds")
			var beacon: Node = beds[0].get_node_or_null("TaskBeacon/TaskBeaconFlag") \
				if not beds.is_empty() else null
			_ok(beacon != null and farm_world.bed_under(_bed(0)) == 0,
				"the harvest flag points to the same bed without changing its hit target")
			var status_badge: Node = beds[0].get("_badge") if not beds.is_empty() else null
			_ok(status_badge is CanvasItem and not (status_badge as CanvasItem).visible,
				"the primary harvest flag replaces its duplicate state badge")
			var other_beacons := 0
			for i in range(1, beds.size()):
				if beds[i].get_node_or_null("TaskBeacon/TaskBeaconFlag") != null:
					other_beacons += 1
			_ok(other_beacons == 0,
				"one next task draws one world flag, never a field of competing arrows")
			await _tap(task_rect.get_center())
			_ok(farm_world.camera.inside(_bed(0)),
				"pressing the harvest task brings its ripe bed into the farm window")
			_ok(Farm.is_ready(_plots()[0]),
				"pressing the task card points at the crop without harvesting it")
		else:
			_ok(false, "a harvest task has the existing farm camera to focus")
			_ok(false, "a harvest task keeps its crop until the child touches the bed")
	# A ready crop is now gone; the already-full basket should be handed over
	# before the screen asks for another planting turn.
	plots = _plots()
	plots[0]["state"] = Farm.TILLED
	plots[0]["crop_id"] = ""
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	var delivery: Node = _find_named(_garden, "NextTask")
	_ok(delivery is Button and str((delivery as Button).get_meta("kind", "")) == "deliver",
		"a fillable order comes before asking for another planting turn")
	var delivery_world = _garden.get("_world")
	var facility_beacon: Node = delivery_world.get_node_or_null(
		"TaskBeaconLayer/TaskFacilityBeacon") if delivery_world != null else null
	var delivery_beds: Array = delivery_world.get("_beds") if delivery_world != null else []
	var old_plot_beacon: Node = delivery_beds[0].get_node_or_null(
		"TaskBeacon/TaskBeaconFlag") if not delivery_beds.is_empty() else null
	_ok(facility_beacon != null and old_plot_beacon == null,
		"delivery moves the one world flag from the crop to the real order board")
	var delivery_rect := Rect2((delivery as Control).global_position,
		(delivery as Control).size) if delivery is Control else Rect2()
	# This is the actual shelf press, not a direct call to the hint helper. The
	# board begins outside the farm window, so the delivery ribbon must first
	# reuse the FarmWorld camera and only then draw its existing finger. The
	# child still has to open and hand over the physical order himself.
	var world = _garden.get("_world")
	var delivered_before_press: Array = SaveManager.data["farm_orders"]["delivered"].duplicate()
	if delivery is Button and world != null:
		var hints_before_press := _tutorial_count()
		await _tap(delivery_rect.get_center())
		var board_at: Vector2 = world.facility_screen_position("orders")
		_ok(world.camera.inside(board_at),
			"pressing the delivery ribbon brings the visitor board into the farm window")
		_ok(_tutorial_count() == hints_before_press + 1,
			"the delivery ribbon replays the existing finger after moving to the board")
		_ok(SaveManager.data["farm_orders"]["delivered"] == delivered_before_press,
			"pressing the delivery ribbon never hands the order over by itself")
		await _tap(board_at)
		_ok(bool(_garden.get("_orders_open")),
			"the visible visitor board still opens its existing order panel after guidance")
		var beacon_layer: Node = world.get_node_or_null("TaskBeaconLayer")
		_ok(beacon_layer != null and beacon_layer.get_child_count() == 0,
			"opening a paper panel clears the world flag until the farm is playable again")
		_garden.call("_close_panels")
		await get_tree().process_frame
		_clear_tutorials()
	else:
		_ok(false, "a delivery ribbon can be pressed to find the visitor board")
		_ok(false, "a delivery ribbon has a visible board target in the farm window")
		_ok(false, "a delivery ribbon replays the order-board finger")
		_ok(false, "a delivery ribbon leaves the order for the child to hand over")
	var before_hints := _tutorial_count()
	_garden.call("_show_the_move")
	await get_tree().process_frame
	_ok(_tutorial_count() == before_hints + 1,
		"a fillable order is guided to the existing visitor board")
	_clear_tutorials()
	var delivered_before: Array = SaveManager.data["farm_orders"]["delivered"].duplicate()
	_garden.call("_do_the_hard_part")
	await get_tree().process_frame
	_ok(SaveManager.data["farm_orders"]["delivered"] == delivered_before,
		"the strongest delivery hint still leaves handing the order over to the child")
	_clear_tutorials()

	var barn: Node = _find_named(_garden, "BarnShortcut")
	_ok(barn is Button and (barn as Button).pressed.get_connections().size() > 0,
		"the visible barn count is a real shortcut to the existing barn panel")
	# Opening the real board rebuilds the shelf and frees the old button; the
	# rectangle recorded before the touch is the stable thing to compare here.
	if barn is Control and delivery_rect.size != Vector2.ZERO:
		_ok(not delivery_rect.grow(5.0).intersects(Rect2((barn as Control).global_position,
			(barn as Control).size)),
			"the rebuilt delivery card leaves the barn shortcut tappable")
	var fill: Node = _find_named(_garden, "BarnCapacityFill")
	_ok(fill is Control and (fill as Control).size.x > 0.0,
		"the barn count also has a visible capacity fill")
	if barn is Button:
		(barn as Button).pressed.emit()
		for i in range(3):
			await get_tree().process_frame
		_ok(bool(_garden.get("_barn_open")),
			"pressing the shelf barn opens the existing barn panel")
	_garden.call("_close_panels")
	await get_tree().process_frame


## Seed tiles standing on the rack right now.  Find each one at the screen's
## own rack centre rather than copying SEED_TILE: a shelf redesign is supposed
## to make this test describe a real reachable seed, not silently count an old
## 96×72 rectangle that no longer exists.
func _rack_tiles() -> int:
	var found := 0
	for index in range(7):
		if _rack_seed_button(index) != null:
			found += 1
	return found


## Which beds currently carry the selected-brush's purely visual halo. The
## test names the paint node instead of copying tool or plot rules: if a future
## renderer stops drawing it, this turns red even when the underlying gesture
## remains valid.
func _lit_tool_target_indices() -> Array:
	var out: Array = []
	var world: Node = _garden.get("_world") if _garden != null else null
	var beds: Array = world.get("_beds") if world != null else []
	for i in range(beds.size()):
		var halo: Node = (beds[i] as Node).get_node_or_null("ToolTargetHalo")
		var ring: Node = halo.get_node_or_null("ToolTargetRing") if halo != null else null
		if ring != null and ring.is_visible_in_tree():
			out.append(i)
	return out


## The seed's transparent Button is deliberately the object under the rack
## centre: both a tap and a drag begin there.  This stays independent of the
## art card so a smaller art icon cannot accidentally make the seed unreachable.
func _rack_seed_button(index: int) -> Button:
	if _garden == null:
		return null
	var at := _seed_tile(index)
	for node in _every_control(_garden):
		if not (node is Button):
			continue
		var button := node as Button
		if button.flat and button.is_visible_in_tree() \
				and button.get_global_rect().has_point(at):
			return button
	return null


## Buy chips standing in the shop right now.
func _buy_chip_count() -> int:
	var found := 0
	for key in (_garden.get("_panel_buttons") as Dictionary).keys():
		if str(key).begins_with("buy_"):
			found += 1
	return found


func _board_ids(board: Array) -> Array:
	var ids: Array = []
	for order in board:
		ids.append(str((order as Dictionary).get("id", "")))
	return ids


func _tutorial_count() -> int:
	var found := 0
	for child in (_garden.get("_play") as Node).get_children():
		if child is Tutorial:
			found += 1
	return found


func _clear_tutorials() -> void:
	for child in (_garden.get("_play") as Node).get_children():
		if child is Tutorial:
			(child as Tutorial).skip()


## HUD geometry helpers.  They deliberately accept Nodes, so a renamed panel
## is a red assertion instead of a null-method error that skips the rest of a
## screen shape.
func _visible_control_inside(node: Node, bounds: Rect2) -> bool:
	if not (node is Control) or not is_instance_valid(node):
		return false
	var control := node as Control
	return control.is_visible_in_tree() \
		and bounds.encloses(control.get_global_rect())


func _control_contains(outer: Node, inner: Node, breathing: float = 0.0) -> bool:
	if not (outer is Control) or not (inner is Control) \
			or not is_instance_valid(outer) or not is_instance_valid(inner):
		return false
	return (outer as Control).get_global_rect().encloses(
		(inner as Control).get_global_rect().grow(breathing))


func _title_has_side_gutters(plaque: Node, title: Node, minimum: float) -> bool:
	if not (plaque is Control) or not (title is Control) \
			or not is_instance_valid(plaque) or not is_instance_valid(title):
		return false
	var plaque_rect := (plaque as Control).get_global_rect()
	var title_rect := (title as Control).get_global_rect()
	return title_rect.position.x - plaque_rect.position.x >= minimum \
		and plaque_rect.end.x - title_rect.end.x >= minimum


func _controls_are_separate(left: Node, right: Node, breathing: float = 0.0) -> bool:
	if not (left is Control) or not (right is Control) \
			or not is_instance_valid(left) or not is_instance_valid(right):
		return false
	return not (left as Control).get_global_rect().grow(breathing).intersects(
		(right as Control).get_global_rect().grow(breathing))


func _horizontal_gutter(left: Node, right: Node) -> float:
	if not (left is Control) or not (right is Control) \
			or not is_instance_valid(left) or not is_instance_valid(right):
		return -INF
	return (right as Control).get_global_rect().position.x \
		- (left as Control).get_global_rect().end.x


func _vertical_gutter(top: Node, bottom: Node) -> float:
	if not (top is Control) or not (bottom is Control) \
			or not is_instance_valid(top) or not is_instance_valid(bottom):
		return -INF
	return (bottom as Control).get_global_rect().position.y \
		- (top as Control).get_global_rect().end.y


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

	await _the_way_out_leads_where_he_came_from()
	await _the_back_button_shuts_the_paper_first()
	await _the_panel_has_a_visible_way_out()
	await get_tree().process_frame


## Where "out" goes, by data. 验收单第 16 条 2026-07-30 结案。
##
## Two attempts failed the same way before this one. 7-29: exit to 英雄基地 --
## the only "come from the map, do not go back to the map" door in the game,
## and the base had no back button of its own. 7-30 morning: exit to the world
## map like the other 34 levels -- still lost, because he does not ARRIVE from
## the island. He arrives from the card on the home screen.
##
## So the garden is off the island entirely (`mode`, which is what
## get_levels_for_world filters on) and its exit is the home screen. One rule:
## 从哪进就从哪出.
func _the_way_out_leads_where_he_came_from() -> void:
	var garden := GameData.get_level("star_garden")
	var config: Dictionary = garden.get("config", {})

	_ok(str(garden.get("mode", "")) != "",
		"star_garden 没有 mode —— 它会重新出现在成长岛上，而它的门在首页。"
		+ "两个入口一个出口，孩子从卡片进、从岛上出（2026-07-30 拿掉的）")

	var on_the_island := false
	for level in GameData.get_levels_for_world(str(garden.get("world", ""))):
		if str(level.get("id", "")) == "star_garden":
			on_the_island = true
	_ok(not on_the_island,
		"菜园又出现在 sunny_park 的地图关卡里了 —— 岛上会画出它的图钉")

	_ok(str(config.get("exit_to", "")) == "home",
		"star_garden.config.exit_to 是 '%s'，不是 'home' —— "
		% str(config.get("exit_to", ""))
		+ "他从首页那张卡片进来的，退出就该回首页")
	_ok(str(config.get("exit_room", "")) == "",
		"star_garden 同时配了 exit_room '%s'，它会盖过 exit_to"
		% str(config.get("exit_room", "")))

	# 丰收八关的门开在菜园里，所以它们回菜园。同一条规则的第二个例子——写在
	# 这里是因为一条只有一个例子的规则，读起来像一个特例。
	var harvest := GameData.get_levels_for_mode("harvest")
	_ok(harvest.size() > 0, "丰收模式一关都没有了")
	for level in harvest:
		_ok(str(level.get("config", {}).get("exit_room", "")) == "star_garden",
			"丰收关 '%s' 退出后不回菜园 —— 它的门开在菜园里，"
			% str(level.get("id", "")) + "而菜园已经不在岛上了")
	await get_tree().process_frame


## The back button, with a sheet of paper over the farm.
##
## This is the one he actually pressed. With the market open there are two
## exits on the glass, and the big dark one in the corner used to mean "throw
## away the whole garden". A six-year-old presses the one he can see.
func _the_back_button_shuts_the_paper_first() -> void:
	_garden.call("_open_panel", "market")
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(bool(_garden.get("_market_open")),
		"the market did not open, so the rest of this proves nothing")

	var back := _find_back_button(_garden)
	if back == null:
		_ok(false, "the back button vanished when the market opened")
		return
	back.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(is_instance_valid(_garden) and _garden.is_inside_tree(),
		"按返回键把整个菜园退掉了 —— 市场开着的时候，那一按应该只是关掉市场。"
		+ "他会按这个键，因为它是屏幕上最大最显眼的那个，而不是因为他想走")
	_ok(not bool(_garden.get("_market_open")),
		"...and the market is shut afterwards")
	# Re-found, not reused: closing the panel rebuilds the screen, so the
	# button pressed a moment ago is a freed object by now. Reading `back`
	# here faults, and a probe that faults skips the rest of its own checks
	# and still prints PASSED -- which is what this line did on its first run.
	var back_again := _find_back_button(_garden)
	_ok(back_again != null
			and back_again.pressed.get_connections().size() > 0,
		"...and the button is still there and still wired for the second "
		+ "press, which is the one that does leave")


## The panel's own close button, measured rather than eyeballed.
##
## It shipped at 1.11:1 against its own fill AND against the paper behind it.
## Screenshots existed; nobody could see it in them either. 3:1 is the floor
## for a control a child is expected to find.
func _the_panel_has_a_visible_way_out() -> void:
	_garden.call("_open_panel", "market")
	await get_tree().process_frame
	await get_tree().process_frame

	var shut := _find_button_labelled(_garden, "X")
	_ok(shut != null, "the market panel has no close button of its own")
	if shut == null:
		_garden.call("_close_panels")
		return

	_ok(shut.size.x >= 60.0 and shut.size.y >= 60.0,
		"面板的关闭键 %.0fx%.0f，比拇指小" % [shut.size.x, shut.size.y])

	var box := shut.get_theme_stylebox("normal")
	var fill: Color = box.bg_color if box is StyleBoxFlat else Color(1, 1, 1)
	var glyph := shut.get_theme_color("font_color")
	var paper := Color(0.99, 0.97, 0.90)  # _panel_sheet's own paper
	_ok(_contrast(glyph, fill) >= 3.0,
		"关闭键的字和它自己的底色对比度只有 %.2f:1 —— 看不见的出口等于没有出口"
		% _contrast(glyph, fill))
	_ok(_contrast(fill, paper) >= 3.0,
		"关闭键的底色和面板的纸对比度只有 %.2f:1 —— 按钮和纸糊在一起，找不到边"
		% _contrast(fill, paper))
	var grass := Color(0.71, 0.84, 0.58)  # FarmWorld's ground, where it stands now
	_ok(_contrast(fill, grass) >= 3.0,
		"关闭键的底色和它身后的草地对比度只有 %.2f:1 —— 它现在站在纸外面的草地上"
		% _contrast(fill, grass))

	_garden.call("_close_panels")
	await get_tree().process_frame


## Every chip on every sheet is the size it was given, and no two of them
## share a pixel.
##
## Found by a screenshot, 2026-09-25: the shop's two 买下 chips sat on top of
## each other and the kitchen's 送给小熊 covered the bottom half of the X.
## The layout code asked for 48-tall chips 56 apart and 46-tall chips 62
## apart -- and got 70 and 68, because the button style carried the panel's
## 20px content margins and Godot raises a Button to fit its margins without
## a word. Every rebuild since the kitchen was written drew it that way.
## Twelve probes were green: they asked whether the chips were WIRED, not
## whether they were on top of each other.
func _no_button_grew_or_landed_on_another() -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	farm["farm_xp"] = 60
	farm["unlocked_recipes"] = ["strawberry_soup", "tomato_stew"]
	farm["warehouse"] = {"strawberry": 3, "tomato": 1, "carrot": 2}
	SaveManager.data["inventory"] = {"dish_strawberry_soup": 1}
	SaveManager.data["rewards"]["coins"] = 120
	SaveManager.save_game()

	for panel in ["shop", "kitchen", "orders", "market", "barn", "recipes",
			"visits"]:
		_garden.call("_close_panels")
		_garden.call("_rebuild")
		await get_tree().process_frame
		_garden.call("_open_panel", panel)
		await get_tree().process_frame
		await get_tree().process_frame

		# The sheet's own chips: what stands on _play.
		var buttons: Array = []
		for node in _every_control(_garden.get("_play")):
			if node is Button and (node as Control).is_visible_in_tree():
				buttons.append(node)

		var grew: Array = []
		for b in buttons:
			var want: Vector2 = (b as Control).custom_minimum_size
			var got: Vector2 = (b as Control).size
			if want != Vector2.ZERO and not got.is_equal_approx(want):
				grew.append("'%s' 要的是 %s 拿到的是 %s"
					% [str((b as Button).text), str(want), str(got)])
		_ok(grew.is_empty(),
			"%s 面板上有按钮比布局要的大 —— %s。样式的内边距在替布局改尺寸，"
			% [panel, "; ".join(grew)]
			+ "而排版是按要的那个数算的")

		var overlaps: Array = []
		for i in range(buttons.size()):
			for j in range(i + 1, buttons.size()):
				var a: Rect2 = (buttons[i] as Control).get_global_rect()
				var c: Rect2 = (buttons[j] as Control).get_global_rect()
				if a.intersects(c):
					overlaps.append("'%s' 压着 '%s' %s"
						% [str((buttons[i] as Button).text),
							str((buttons[j] as Button).text),
							str(a.intersection(c).size)])
		_ok(overlaps.is_empty(),
			"%s 面板上有两个按钮叠在一起 —— %s。叠住的那半截按下去是另一个键"
			% [panel, "; ".join(overlaps)])

	_garden.call("_close_panels")
	await get_tree().process_frame


## A ripe bed whose harvest id is already in the ledger is freed, not frozen.
##
## The tap used to return in silence when RewardManager refused the id, and
## the bed stayed READY for ever: no sound, no crops, no way out. Two
## tablets merging their saves can make one (the ledger is unioned, the beds
## are kept from one side). Now the bed goes back to earth, pays nothing,
## and its next planting gets an id the ledger has not seen.
func _a_bed_paid_twice_is_freed_not_frozen() -> void:
	_garden.call("_close_panels")
	var farm: Dictionary = SaveManager.data["farm"]
	var plots: Array = farm["plots"]
	var plot: Dictionary = plots[0]
	var plot_id := str(plot.get("plot_id", ""))
	plot["state"] = Farm.READY
	plot["crop_id"] = "carrot"
	plot["growth_stage"] = 4
	plot["care_event"] = ""
	plot["plant_cycle_id"] = 3
	farm["paid_harvests"] = ["farm_harvest_%s_3" % plot_id,
		"farm_harvest_%s_4" % plot_id]
	plots[0] = plot
	farm["plots"] = plots
	SaveManager.save_game()
	# With the hand, and with the camera home.
	_garden.call("_select_tool", "hand")
	(_garden.get("_world") as Node).call("go_home")
	_garden.call("_rebuild")
	for i in range(2):
		await get_tree().process_frame

	var coins := Coins.balance()
	var carrots := Barn.count("carrot")
	await _tap(_bed(0))
	var after: Dictionary = _plots()[0]
	_ok(str(after.get("state", "")) == Farm.TILLED,
		"账本里已经付过款的熟地，点一下还是 '%s' —— 原来这一按悄悄什么都不做，"
		% str(after.get("state", "")) + "这块地永远收不了")
	_ok(Coins.balance() == coins and Barn.count("carrot") == carrots,
		"...and freeing it pays nothing and stores nothing")
	var next_key := "farm_harvest_%s_%d" % [plot_id,
		int(after.get("plant_cycle_id", 0)) + 1]
	_ok(not (next_key in (SaveManager.data["farm"].get("paid_harvests", []) as Array)),
		"下一次种下去的编号 %s 账本已经见过 —— 下一茬又会收不了" % next_key)


## An order card he cannot fill yet answers the press.
##
## It used to be a disabled Button: no sound, no motion. Three cards on a
## board, and the one he taps does nothing. _deliver refuses a short barn
## on its own, so the card is free to shrug.
func _a_card_he_cannot_fill_still_answers() -> void:
	_garden.call("_close_panels")
	var farm: Dictionary = SaveManager.data["farm"]
	farm["warehouse"] = {}
	SaveManager.data["farm_orders"] = {"delivered": []}
	SaveManager.save_game()
	await _open_the_board()
	var cards: Array = []
	_collect_order_cards(_garden, cards)
	_ok(not cards.is_empty(), "the board has a card on it")
	if cards.is_empty():
		return
	var card: Button = cards[0]
	_ok(not card.disabled,
		"填不满的订单卡是 disabled 的 —— 一张按下去毫无反应的卡")
	_ok(card.pressed.get_connections().size() > 0,
		"...and it is wired to answer")
	var coins := Coins.balance()
	card.emit_signal("pressed")
	for i in range(3):
		await get_tree().process_frame
	_ok(Coins.balance() == coins
			and (SaveManager.data["farm_orders"]["delivered"] as Array).is_empty(),
		"...and the answer is a shrug, not a delivery")
	_garden.call("_close_panels")
	await get_tree().process_frame


## The lesson's clock belongs to the lesson's carrot, in the lesson's bed.
##
## The override used to be "anything planted while the lesson is on": corn
## in bed three grew in six seconds, every visit, until the first order was
## handed over.
func _the_lesson_clock_is_the_carrots_alone() -> void:
	_garden.call("_close_panels")
	var farm: Dictionary = SaveManager.data["farm"]
	var plots: Array = farm["plots"]
	for index in [0, 2]:
		var fresh: Dictionary = Farm.fresh_plot(index)
		fresh["state"] = Farm.TILLED
		plots[index] = fresh
	farm["plots"] = plots
	_garden.set("_lesson_running", true)
	_garden.set("_tutorial_growth", 6)
	_garden.call("_plant_in", 2, "corn")
	_garden.call("_plant_in", 0, "carrot")
	_ok(int(_plots()[2].get("growth_override_seconds", 0)) == 0,
		"课上种的玉米也走 6 秒 —— 课没上完之前，任何地里种任何东西都是 6 秒")
	_ok(int(_plots()[0].get("growth_override_seconds", 0)) == 6,
		"课上那颗胡萝卜还是 6 秒")
	_garden.set("_lesson_running", false)
	_garden.set("_tutorial_growth", 0)
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame


## One carrot, not two: the bed draws the same rendered sprite the harvest
## page uses, standing with its root in the hollow, the golden one in gold,
## and a seedling smaller than a ripe plant. A child walks between the two
## rooms; the vegetable must not change species on the way.
func _the_bed_grows_the_same_crop_the_harvest_page_shows() -> void:
	_garden.call("_close_panels")
	var farm: Dictionary = SaveManager.data["farm"]
	var plots: Array = farm["plots"]
	for index in [0, 1, 2]:
		var fresh: Dictionary = Farm.fresh_plot(index)
		fresh["state"] = Farm.READY if index < 2 else Farm.GROWING
		fresh["crop_id"] = "carrot"
		fresh["growth_stage"] = 4 if index < 2 else 1
		fresh["growth_progress"] = 1.0 if index < 2 else 0.2
		fresh["golden"] = index == 1
		fresh["plant_cycle_id"] = 7000 + index
		plots[index] = fresh
	farm["plots"] = plots
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	var beds: Array = _garden.get("_world").get("_beds")
	var ripe := _find_named(beds[0].get("_planting"), "Crop3D") as TextureRect
	var golden := _find_named(beds[1].get("_planting"), "Crop3D") as TextureRect
	var young := _find_named(beds[2].get("_planting"), "Crop3D") as TextureRect
	_ok(ripe != null and ripe.texture != null
		and ripe.texture.resource_path == "res://assets/harvest_3d/crops/carrot.png",
		"a ripe carrot bed shows the harvest page's rendered carrot, not the flat icon")
	_ok(golden != null and golden.texture != null
		and golden.texture.resource_path == "res://assets/harvest_3d/crops/golden_carrot.png",
		"...and the rare bed shows the golden render")
	if ripe != null:
		var root := ripe.position + Vector2(ripe.size.x * 0.5,
			ripe.size.y * 467.0 / 512.0)
		_ok(root.distance_to(Vector2(0.0, 12.0)) < 1.0,
			"the render's ground pivot stands in the bed's hollow (%s)" % root)
		_ok(ripe.pivot_offset.is_equal_approx(root - ripe.position),
			"...and it sways about its root, not its corner")
	_ok(ripe != null and young != null and young.size.y < ripe.size.y * 0.7,
		"a seedling is drawn clearly smaller than the ripe plant")
	# The bed under it and the scenery around it come out of the same studio.
	var patch := _find_named(beds[0].get("_ground"), "BedPatch") as TextureRect
	_ok(patch != null and patch.texture != null
		and patch.texture.resource_path == "res://assets/harvest_3d/props/soil_grass_patch.png",
		"a turned bed is the studio's soil patch, not a brown blob")
	var scenery := _find_named(_garden.get("_world"), "LandmarkScenery")
	_ok(scenery != null and _find_named(scenery, "Scenery_tree") is TextureRect
		and _find_named(scenery, "Scenery_hedge") is TextureRect,
		"the trees and hedges are rendered props from the same pipeline")
	for index in [0, 1, 2]:
		plots[index] = Farm.fresh_plot(index)
	farm["plots"] = plots
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame


## WCAG relative luminance, so "can he see it" is a number and not an opinion.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var parts := [c.r, c.g, c.b]
	var out := []
	for v in parts:
		out.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2]


func _find_button_labelled(node: Node, label: String) -> Button:
	for child in node.get_children():
		if child is Button and str(child.text) == label:
			return child
		var found := _find_button_labelled(child, label)
		if found != null:
			return found
	return null


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

	# Reload only after the garden is gone.  The order card queues a redraw and
	# the live scene deliberately writes farm-entry facts while it is around;
	# reloading underneath that fixture made this test race its own old screen.
	# A real close -> load -> reopen is the child path we are promising here.
	_close()
	GameClock.set_test_now(NOON, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.load_game()
	_ok(str(order.get("id", ""))
			in SaveManager.data["farm_orders"].get("delivered", []),
		"the delivery is on disk, not just in memory")
	_ok(Coins.balance() == before + price,
		"...and so are the 星星币 it paid")
	_ok(Barn.count("plank", "inventory") == 1,
		"...and the one plank")

	_open()
	await get_tree().process_frame
	await get_tree().process_frame
	await _open_the_board()

	# Press the card again, if it is still there at all.
	var again := _order_card(str(order.get("id", "")))
	if again != null:
		# Not disabled any more: a receipt answers a press with a nod, and
		# _deliver is what keeps it from paying twice. The coin check below
		# is the one that matters.
		_ok(again.pressed.get_connections().size() > 0,
			"a delivered order's card still answers a press")
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


## The card for one order, found by where the board puts it. Walks the same
## _orders_for_board the screen draws from -- the board no longer mirrors the
## file (level gates, pending-first, receipts pad), so an index into the file
## would find the wrong card the moment any of that mattered.
func _order_card(order_id: String) -> Button:
	var delivered: Array = SaveManager.data.get("farm_orders", {})\
		.get("delivered", [])
	var board: Array = _garden.call("_orders_for_board", delivered)
	var index := -1
	for i in range(board.size()):
		if str((board[i] as Dictionary).get("id", "")) == order_id:
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



## Force a bed ripe, with a fresh planting id and an empty barn, the way every
## other ripening in this probe does: through the save, then a rebuild. The
## wait at the top is the harvest lock expiring -- 0.45 seconds of real time
## during which the bed refuses hands, and a probe that forgets it tests a
## lock instead of a gesture.
func _ripen(index: int, crop_id: String, cycle: int) -> void:
	await get_tree().create_timer(0.6).timeout
	var plots := _plots()
	plots[index]["crop_id"] = crop_id
	plots[index]["growth_stage"] = 4
	plots[index]["plant_cycle_id"] = cycle
	plots[index]["state"] = Farm.READY
	SaveManager.data["farm"]["paid_harvests"] = []
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame


## Which horizontal direction still has world left to pan into, from where the
## camera stands. The camera clamps at the world's edge, and the edge is close
## enough to the opening view that "drag sideways and watch it move" needs the
## answer ASKED, not assumed -- the same drag can be free on one screen shape
## and pinned on the other.
func _roomiest_side() -> float:
	var cam = _camera()
	# A finger dragged left moves the camera right (and vice versa).  The old
	# opening frame happened to start far enough from the left edge that testing
	# the opposite direction still worked; the base-aware frame can start exactly
	# at that edge, so select the direction that actually has world left to pan.
	var right := Layout.clamp_centre(
		cam.centre + Vector2(160.0, 0.0) / maxf(cam.zoom, 0.05),
		cam.window.size, cam.zoom)
	return -1.0 if not is_equal_approx(right.x, cam.centre.x) else 1.0


## The pull. A ripe bed, a bare hand, and the carrot's own move -- up.
##
## Through the REAL input pipeline, because the thing being tested is a
## routing decision no handler-level poke can reach: a drag that STARTS on a
## ripe bed belongs to the crop, not to the camera. Everything the farm used
## to do with that drag -- pan, and only pan -- has to still be true for every
## other bed and every other drag.
func _a_ripe_bed_comes_out_when_pulled() -> void:
	var world: Node = _garden.get("_world")
	_ok(world.get("gesture_bed_check").is_valid(),
		"the farm asks the screen which beds want a pull")
	_camera().go_home()
	await get_tree().process_frame
	await get_tree().process_frame

	# The move itself: press the bed, drag up 130px, let go. Up is the carrot's
	# own direction (drag, cone 35 degrees, 90px minimum).
	await _ripen(3, "carrot", 11)
	await _finger(_bed(3), _bed(3) + Vector2(0.0, -130.0))
	var barn: Dictionary = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("carrot", 0)) == int(GameData.get_crop("carrot")
			.get("harvest_amount", 0)),
		"pulling a ripe carrot up out of its bed picks it")
	_ok(str(_plots()[3].get("crop_id", "")) == "",
		"and the bed is empty behind it")
	_ok("farm_harvest_plot_4_11" in SaveManager.data["farm"]
			.get("paid_harvests", []),
		"the pulled harvest is paid for exactly once, like a tapped one")

	# Too short to be a pull: not a harvest, and not silence either -- the
	# camera catches up by what the finger did, so a pan that started on a
	# carrot still pans.
	await _ripen(3, "carrot", 12)
	await _finger(_bed(3), _bed(3) + Vector2(0.0, -40.0))
	barn = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("carrot", 0)) == 0,
		"a 40px tug is not a harvest -- the crop did not come loose")
	_ok(str(_plots()[3].get("state", "")) == Farm.READY,
		"and the bed is still holding its carrot")

	# The wrong direction: sideways is a pan that happened to start on a
	# carrot. The plant leans while it lasts, then settles, and nothing is
	# picked and nothing is scolded.
	await _ripen(3, "carrot", 13)
	var side := _roomiest_side()
	var before: Vector2 = _camera().centre
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(_bed(3))
	Input.parse_input_event(down)
	await get_tree().process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _glass(_bed(3) + Vector2(130.0 * side, 0.0))
	Input.parse_input_event(drag)
	await get_tree().process_frame
	var beds: Array = world.get("_beds")
	var bed: Node = beds[3]
	_ok(absf(float(bed.get("_lean_rot_to"))) > 0.0,
		"a sideways drag leans the plant while the finger is down")
	_ok(is_equal_approx(float(bed.get("_lean_lift_to")), 0.0),
		"and only sideways -- the lift answers an upward pull")
	_ok(is_equal_approx(_camera().centre.x, before.x),
		"and the camera holds still while the finger holds the crop")
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(_bed(3) + Vector2(130.0 * side, 0.0))
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(is_equal_approx(float(bed.get("_lean_rot_to")), 0.0),
		"the plant settles the moment the finger leaves")
	barn = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("carrot", 0)) == 0,
		"a sideways drag picks nothing")
	_ok(not is_equal_approx(_camera().centre.x, before.x),
		"and the camera pans at the release -- a missed pull is still a pan")

	# A bed that is NOT ripe never claims the drag at all. The proof that the
	# pan is the LIVE one, not the gesture's catch-up jump, is that the camera
	# has already moved while the finger is still down.
	await _ripen(2, "corn", 21)
	var plots := _plots()
	plots[2]["state"] = Farm.GROWING
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	side = _roomiest_side()
	before = _camera().centre
	down = InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(_bed(2))
	Input.parse_input_event(down)
	await get_tree().process_frame
	drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _glass(_bed(2) + Vector2(130.0 * side, 0.0))
	Input.parse_input_event(drag)
	await get_tree().process_frame
	_ok(not is_equal_approx(_camera().centre.x, before.x),
		"a drag on a growing bed pans WHILE the finger moves, as it always did")
	up = InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(_bed(2) + Vector2(130.0 * side, 0.0))
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(str(_plots()[2].get("state", "")) == Farm.GROWING,
		"and the growing corn is still growing")
	_ok(int(SaveManager.data["farm"].get("warehouse", {})
			.get("corn", 0)) == 0,
		"nothing was picked from it either")

	# The tap still picks. The gesture may be the show, but "there is no wrong
	# tap" is written above the whole screen and the routing change must not
	# have cost it.
	await _ripen(3, "carrot", 31)
	await _tap(_bed(3))
	_ok(int(SaveManager.data["farm"].get("warehouse", {})
			.get("carrot", 0)) == int(GameData.get_crop("carrot")
			.get("harvest_amount", 0)),
		"a plain tap on a ripe bed still picks it")




## The garden's quiet clock: every twenty seconds it re-asks the clock, so a
## bed whose minute arrives mid-visit turns ripe IN FRONT of him instead of on
## his next visit. Three rules here: growth that crosses a boundary rebuilds
## the furniture; growth that only inches a plant taller redraws the bed but
## never rebuilds over his head; and produce waiting by the barn's door slips
## in on the same beat. Driven through the tick's own body, not the wallclock
## timer -- a probe that waits twenty seconds per beat is a probe nobody runs.
##
## The crop is corn on purpose: its one job (weeds) is answered for this
## planting and corn never thirsts, so the tick's growth is uninterrupted and
## every timing below reads off the catalogue instead of off a wall clock.
##
## ATOMIC ON PURPOSE. Sections before this one close and reopen the garden
## with the test clock cleared for a frame, and a real-time beat can write
## real-wall-clock anchors in that gap -- anchors in the FUTURE of the test
## clock freeze every settle after them. So the anchors are pinned and every
## clock-step, tick and verdict below runs in ONE frame with no await for a
## real-time beat to slip into; the rebuilds the beats queue are drained at
## the two marked pauses, where every verdict is either already read or
## interleaving-proof.
func _the_garden_moves_while_he_watches() -> void:
	var scene: Node = _garden
	var world: Node = scene.get("_world")
	# The clock comes first, and it is not paranoia: the lesson and break
	# sections close and reopen the garden with the clock cleared for a frame,
	# and nothing after them sets it again -- this is the one section that
	# needs a KNOWN clock rather than a hand-crafted state, so it sets its own.
	GameClock.set_test_now(NOON, 0)
	var stages: Array = GameData.get_crop("corn").get("stage_seconds", [])
	_ok(stages.size() >= 3, "corn has the stages the quiet tick needs to cross")
	var plots := _plots()
	plots[1]["state"] = Farm.GROWING
	plots[1]["crop_id"] = "corn"
	plots[1]["growth_stage"] = 1
	plots[1]["growth_progress"] = 0.5
	plots[1]["water_level"] = 1.0
	plots[1]["care_event"] = ""
	plots[1]["care_completed"] = true    # this cycle's weeds are pulled, so
	# the one pause corn can ask for is already answered
	plots[1]["growth_override_seconds"] = 0
	plots[1]["planted_at"] = NOON - 600
	plots[1]["last_updated_at"] = NOON - 600
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	# Pin the anchors NOW, after the drains -- this and every clock-step below
	# stay in one frame, so no real-time beat can move them again.
	SaveManager.data["farm"]["last_seen_at"] = NOON
	SaveManager.data["farm"]["clock_high_water"] = NOON
	plots[1]["last_updated_at"] = NOON - 600
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()

	# A beat with no time in it: nothing grows, and nothing is asked of the
	# ribbon, the dog or the hints.
	scene.call("_garden_tick_once")
	_ok(int(_plots()[1].get("growth_stage", 0)) == 1,
		"a quiet tick with no time in it grows nothing")
	_ok(not bool(scene.get("_rebuild_queued")),
		"and asks nothing of the furniture")

	# The stage boundary crosses mid-visit: the bed moves, and the furniture
	# moves with it -- "the corn is taller" is also a fact the ribbon says.
	GameClock.set_test_now(NOON + int(float(stages[1]) * 0.6), 0)
	scene.call("_garden_tick_once")
	_ok(int(_plots()[1].get("growth_stage", 0)) == 2,
		"a stage boundary that passes mid-visit crosses in front of him")
	_ok(bool(scene.get("_rebuild_queued")),
		"and the furniture rebuilds to say what it means")
	await get_tree().process_frame
	await get_tree().process_frame        # drain the beat's rebuild

	# A few more seconds: the plant inches taller on its bed, and the
	# furniture stays put. A rebuild for every inch would take a pointing
	# finger down with it, twenty seconds at a time.
	var beds: Array = world.get("_beds")
	var looked_before: String = str(beds[1].get("_looked_like"))
	GameClock.set_test_now(NOON + int(float(stages[1]) * 0.6) \
		+ maxi(int(float(stages[2]) * 0.02), 5), 0)
	scene.call("_garden_tick_once")
	_ok(not bool(scene.get("_rebuild_queued")),
		"a plant that only inched taller rebuilds no furniture")
	_ok(str(beds[1].get("_looked_like")) != looked_before,
		"but the bed itself was redrawn -- the inch is on screen")
	await get_tree().process_frame
	await get_tree().process_frame        # drain

	# And the minute that matters: the corn ripens while he stands there,
	# with one pop and one wave, and the screen points at it.
	var total := 0
	for s in stages:
		total += int(s)
	GameClock.set_test_now(NOON + total, 0)
	scene.call("_garden_tick_once")
	_ok(Farm.is_ready(_plots()[1]),
		"a corn whose minute arrives mid-visit turns ripe in front of him")
	_ok(bool(scene.get("_rebuild_queued")),
		"and the screen says so -- the ribbon follows the ripeness")
	await get_tree().process_frame
	await get_tree().process_frame        # drain

	# The same beat does the housekeeping: whatever has been waiting by the
	# barn's door goes in when there is room, and the shelf count follows --
	# even though not one bed has moved.
	var before_count := int(Barn.count("carrot"))
	Barn.put("carrot", 2, Barn.BASKET)
	scene.call("_garden_tick_once")
	_ok(int(Barn.count("carrot")) == before_count + 2,
		"produce waiting by the door slips into the barn on the quiet tick")
	_ok(bool(scene.get("_rebuild_queued")),
		"and the shelf count on screen hears about it")
	await get_tree().process_frame
	await get_tree().process_frame        # let the last rebuild land


## The board after the story. Every friend's order thanked, the farm grown up,
## and the board STILL offering work -- recurring cards, delivered again and
## again, paying again and again, never ticking grey. This is the loop the
## whole farm rests on once the narrative runs out, so it gets the same
## once-only scrutiny the story orders got.
func _the_board_never_runs_dry() -> void:
	var scene: Node = _garden
	# Max the farm out: every story order delivered, every band showing, and
	# every bed turned but empty -- so the ribbon's best advice is "deliver".
	var story_ids: Array = []
	for order in GameData.garden_orders:
		if not bool(order.get("recurring", false)):
			story_ids.append(str(order.get("id", "")))
	var plots := _plots()
	for i in range(plots.size()):
		plots[i] = Farm.fresh_plot(i)
		plots[i]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.data["farm"]["farm_xp"] = 200          # level 5: every band is on
	SaveManager.data["farm_orders"] = {"delivered": story_ids}
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame

	var board: Array = scene.call("_orders_for_board",
		SaveManager.data["farm_orders"].get("delivered", []))
	var recurring_on_board := 0
	for entry in board:
		if bool(entry.get("recurring", false)):
			recurring_on_board += 1
	_ok(recurring_on_board == 3,
		"with every friend's order thanked, the board is three recurring cards")
	_ok(board.size() == 3, "and the board is still full of work")

	# One basket, exactly what the card asks: the delivery takes all of it,
	# and the empty barn behind it is what makes the double-press honest.
	var order: Dictionary = board[0]
	var wants: Dictionary = order.get("requirements", {})
	var price := int(order.get("rewards", {}).get("coins", 0))
	for crop_id in wants.keys():
		Barn.put(str(crop_id), int(wants[crop_id]))
	SaveManager.save_game()

	var before := Coins.balance()
	scene.call("_deliver", order)
	_ok(Coins.balance() == before + price,
		"delivering a recurring order pays what the card promises")
	_ok(not (str(order.get("id", ""))
			in SaveManager.data["farm_orders"]["delivered"]),
		"and it is never written down as done -- the card stays alive")
	_ok(int(SaveManager.data["farm_orders"].get("counts", {})
			.get(str(order.get("id", "")), 0)) == 1,
		"the delivery is counted, once")

	# Press it again on the same basket: the barn is empty now, so nothing is
	# taken and nothing is paid -- the barn gate the story orders lean on.
	scene.call("_deliver", order)
	_ok(Coins.balance() == before + price,
		"a second press on the same basket takes nothing and pays nothing")

	# A real second delivery, from a real second basket, pays again.
	for crop_id in wants.keys():
		Barn.put(str(crop_id), int(wants[crop_id]))
	SaveManager.save_game()
	scene.call("_deliver", order)
	_ok(Coins.balance() == before + price * 2,
		"a real second delivery pays again -- the board is a loop, not a lamp")
	_ok(int(SaveManager.data["farm_orders"].get("counts", {})
			.get(str(order.get("id", "")), 0)) == 2,
		"and the count says two")
	_ok(not (str(order.get("id", ""))
			in SaveManager.data["farm_orders"]["delivered"]),
		"while the friends' own ledger stays untouched")

	# One more basket, so the ribbon keeps its oldest instruction.
	for crop_id in wants.keys():
		Barn.put(str(crop_id), int(wants[crop_id]))
	SaveManager.save_game()
	var task: Dictionary = scene.call("_next_task")
	_ok(str(task.get("kind", "")) == "deliver",
		"the next step is still deliver when a recurring order can be filled")

	# Grown-to, not greyed-out: a level 1 farm is offered no recurring work it
	# cannot grow yet -- the late-band cards are simply not there.
	SaveManager.data["farm"]["farm_xp"] = 0
	SaveManager.save_game()
	board = scene.call("_orders_for_board",
		SaveManager.data["farm_orders"]["delivered"])
	var gated := 0
	for entry in board:
		var gate := str(entry.get("unlock_condition", ""))
		if gate.begins_with("level:") and int(gate.substr(6)) > 1:
			gated += 1
	_ok(gated == 0,
		"a level 1 farm is offered no work it cannot grow yet")


## The market, with numbers on it. The unit price -- what ONE of a crop is
## worth -- sits on its chip, and the box he drags piles into grew a way to
## take things back OUT, one at a time. "Sell three, keep nine" is the number
## sense the whole barn-to-purse loop teaches, and a trapdoor that swallowed
## whole piles taught none of it.
func _market_item(items: Array, crop_id: String) -> Dictionary:
	for item in items:
		if str(item.get("key", "")) == crop_id:
			return item
	return {}


func _drag_market_crop_to_box(crop_id: String, refresh_mid_drag: bool = false) -> void:
	var field_value: Variant = _garden.get("_market_field")
	if not (field_value is DragField):
		_ok(false, "the market has a real crop drag field")
		return
	var field := field_value as DragField
	var item := _market_item(field.items(), crop_id)
	var slots := field.slots()
	if item.is_empty() or slots.is_empty():
		_ok(false, "the stocked crop and its box slot are both present")
		return
	var card := item.get("node") as Node2D
	var box := (slots[0] as Dictionary).get("node") as Node2D
	if card == null or box == null:
		_ok(false, "the crop card and box have visible drag nodes")
		return
	# DragField lifts the piece by 34px above the finger; aim the finger below
	# the slot so the piece itself lands in its centre, just as a child would.
	var after_press := Callable()
	if refresh_mid_drag:
		after_press = func():
			_ok(not field.held().is_empty(),
				"a real market touch holds the crop before the refresh")
			_garden.call("_queue_rebuild")
			for frame in range(3):
				await get_tree().process_frame
			_ok(is_instance_valid(field) and not field.is_queued_for_deletion()
					and _garden.get("_market_field") == field
					and is_instance_valid(card),
				"a clock refresh keeps the market card and drag field alive mid-drag")
			_ok(bool(_garden.get("_rebuild_queued")),
				"the market refresh remains pending until the finger releases")
	await _finger(card.get_global_transform_with_canvas().origin,
		box.get_global_transform_with_canvas().origin + Vector2(0.0, 34.0), after_press)
	if refresh_mid_drag:
		_ok(not is_instance_valid(field)
				and _garden.get("_market_field") is DragField,
			"the pending market refresh finishes after the crop lands")


func _the_market_shows_what_things_are_worth(view: Vector2) -> void:
	var scene: Node = _garden
	# The barn arrives with whatever the sections before this one left in it;
	# every number below is written against an exactly-twelve barn, so it is
	# emptied first -- the same courtesy every other ripening here pays.
	SaveManager.data["farm"]["warehouse"] = {}
	Barn.put("carrot", 12)
	Barn.put("corn", 3)
	Barn.put("strawberry", 2)
	Barn.put("tomato", 1)
	SaveManager.save_game()
	scene.call("_open_panel", "market")
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(bool(_garden.get("_market_open")),
		"the market did not open, so this proves nothing")

	# The receipt and the barn shelf are one glanceable screen in both window
	# shapes. Check the actual controls and the card bounds rather than trusting
	# that a panel with the right dimensions happened to stay on the glass.
	var screen := Rect2(Vector2.ZERO, view)
	var shelf_surface: Node = _find_named(scene, "MarketBarnShelf")
	var receipt_surface: Node = _find_named(scene, "MarketReceipt")
	var drop_hint: Node = _find_named(scene, "MarketDropHint")
	var total_label: Node = _garden.get("_market_total")
	var sell_button: Node = (_garden.get("_panel_buttons") as Dictionary).get("sell")
	_ok(_visible_control_inside(shelf_surface, screen),
		"the barn shelf stays fully on the glass")
	_ok(_visible_control_inside(receipt_surface, screen),
		"the receipt stays fully on the glass")
	_ok(_horizontal_gutter(shelf_surface, receipt_surface) >= 8.0,
		"the shelf and receipt leave their eight-pixel divider")
	_ok(_visible_control_inside(drop_hint, screen)
			and _control_contains(receipt_surface, drop_hint),
		"the empty-box hint sits inside the receipt before anything is dragged")
	_ok(_visible_control_inside(sell_button, screen),
		"the sale action stays fully reachable on the glass")
	_ok(_control_contains(receipt_surface, sell_button),
		"the whole sale action fits inside the receipt counter")
	_ok(_vertical_gutter(sell_button, _garden.get("_shelf")) >= 8.0,
		"the sale action keeps eight pixels above the tool dock")
	_ok(_visible_control_inside(total_label, screen),
		"the quoted total stays on the glass")
	_ok(_horizontal_gutter(total_label, sell_button) >= 2.0,
		"the quote and sale action have a clear two-pixel gutter")
	var market_field_value: Variant = _garden.get("_market_field")
	var market_field := market_field_value as DragField
	var market_items: Array = market_field.items() if market_field != null else []
	_ok(market_items.size() == 4,
		"the four stocked crops all have shelf cards")
	for market_item in market_items:
		var card := market_item.get("node") as Node2D
		var card_centre: Vector2 = card.get_global_transform_with_canvas().origin
		var card_rect := Rect2(card_centre - Vector2(48.0, 36.0), Vector2(96.0, 72.0))
		_ok((shelf_surface as Control).get_global_rect().encloses(card_rect),
			"each thumb-sized crop card sits inside the barn shelf")

	var unit := int(GameData.market_price("carrot"))
	var price: Node = _find_named(scene, "UnitPrice_carrot")
	_ok(price is Label and (price as Label).text == str(unit),
		"the carrot chip says what ONE carrot is worth")

	# The pile, dragged in: the box holds all twelve, exactly as it always
	# did -- the real DragField path also marks its crop as placed in the box.
	await _drag_market_crop_to_box("carrot", true)
	market_field = _garden.get("_market_field") as DragField
	drop_hint = _find_named(scene, "MarketDropHint")
	market_items = market_field.items() if market_field != null else []
	var carrot_item: Dictionary = _market_item(market_items, "carrot")
	var carrot_node := carrot_item.get("node") as Node2D
	var box_slot: Dictionary = carrot_item.get("slot", {})
	var box_node := box_slot.get("node") as Node2D
	await get_tree().create_timer(0.18).timeout
	_ok(bool(carrot_item.get("placed", false))
			and int(box_slot.get("held", 0)) == 1
			and carrot_node.position.distance_to(box_node.position) < 2.0,
		"the actual drag places the carrot card in the box slot")
	var rows_scroll: Node = _find_named(scene, "MarketReceiptRows")
	_ok(rows_scroll is Control and (rows_scroll as Control).visible
			and drop_hint is Control and not (drop_hint as Control).visible,
		"a filled box replaces its hint with visible receipt rows")
	for crop_id in ["corn", "strawberry", "tomato"]:
		await _drag_market_crop_to_box(str(crop_id))
	await get_tree().process_frame
	await get_tree().process_frame
	var before_refresh := _find_named(scene, "MarketReceiptRows") as ScrollContainer
	before_refresh.scroll_vertical = 10000
	await get_tree().process_frame
	var receipt_offset := before_refresh.scroll_vertical
	# The resize path rebuilds presentation from the basket dictionary. Force the
	# same rebuild here while four crops are boxed, then verify DragField's slot
	# bookkeeping is reconstructed alongside the receipt rows.
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	market_field = _garden.get("_market_field") as DragField
	market_items = market_field.items() if market_field != null else []
	carrot_item = _market_item(market_items, "carrot")
	carrot_node = carrot_item.get("node") as Node2D
	box_slot = carrot_item.get("slot", {})
	box_node = box_slot.get("node") as Node2D
	var every_crop_restored := market_items.size() == 4
	for market_item in market_items:
		var restored_slot: Dictionary = market_item.get("slot", {})
		var restored_card := market_item.get("node") as Node2D
		every_crop_restored = every_crop_restored \
			and bool(market_item.get("placed", false)) \
			and restored_slot.get("node") == box_node \
			and restored_card.position.distance_to(box_node.position) < 2.0
	_ok(every_crop_restored and int(box_slot.get("held", -1)) == 4,
		"a market rebuild restores every crop to its shared box slot")
	rows_scroll = _find_named(scene, "MarketReceiptRows")
	_ok(receipt_offset > 0 and rows_scroll is ScrollContainer
			and (rows_scroll as ScrollContainer).scroll_vertical == receipt_offset,
		"a rebuilt long receipt keeps the row the child was reading")
	(rows_scroll as ScrollContainer).scroll_vertical = 0
	await get_tree().process_frame
	drop_hint = _find_named(scene, "MarketDropHint")
	total_label = _garden.get("_market_total")
	sell_button = (_garden.get("_panel_buttons") as Dictionary).get("sell")
	var rows_list_value: Variant = _garden.get("_market_rows_list")
	var rows_list := rows_list_value as VBoxContainer
	var receipt_scroll := rows_scroll as ScrollContainer
	_ok(rows_list != null and rows_list.get_child_count() == 4,
		"one receipt row appears for each crop in the box")
	_ok(rows_list != null and receipt_scroll != null
			and rows_list.size.y > receipt_scroll.size.y,
		"the receipt content grows beyond its viewport instead of covering the action")
	_ok(receipt_scroll != null and receipt_scroll.clip_contents,
		"overflowing receipt rows stay clipped inside their scroll area")
	_ok(int(_garden.get("_market_sell").get("carrot", 0)) == 12,
		"dragging the pile in offers the whole pile, as always")
	var count: Node = _find_named(scene, "BoxCount_carrot")
	_ok(count is Label and (count as Label).text == "x12",
		"and the box says what it holds")
	_ok(count is Control and _visible_control_inside(count, screen)
			and _control_contains(rows_scroll, count),
		"the crop count stays visible inside the scrollable receipt")
	var expected_quote := 12 * unit \
		+ 3 * int(GameData.market_price("corn")) \
		+ 2 * int(GameData.market_price("strawberry")) \
		+ int(GameData.market_price("tomato"))
	_ok(str((_garden.get("_market_total") as Label).text)
			== str(expected_quote),
		"the fixed quote matches every crop in the box")
	# The total briefly scales for its price-change feedback. Let that visual
	# response finish before comparing its bounds across a scroll movement.
	await get_tree().create_timer(0.18).timeout
	var total_before_scroll := (_garden.get("_market_total") as Control).get_global_rect()
	var sell_before_scroll := (sell_button as Control).get_global_rect()
	if receipt_scroll != null:
		receipt_scroll.scroll_vertical = 10000
		await get_tree().process_frame
	_ok(receipt_scroll != null and receipt_scroll.scroll_vertical > 0
			and (_garden.get("_market_total") as Control).get_global_rect()
				== total_before_scroll
			and (sell_button as Control).get_global_rect() == sell_before_scroll,
		"scrolling a long receipt leaves its total and sale button fixed")
	if receipt_scroll != null:
		receipt_scroll.scroll_vertical = 0
		await get_tree().process_frame

	# One back out. The box counts down, and the shelf chip answers with what
	# is still on the shelf -- the pair of numbers IS the decision.
	var minus: Node = _find_named(scene, "BoxMinus_carrot")
	_ok(minus is Button, "the box row has a way to take one back out")
	if minus is Button:
		(minus as Button).emit_signal("pressed")
		await get_tree().process_frame
	_ok(int(_garden.get("_market_sell")["carrot"]) == 11,
		"one press takes one carrot back out")
	for i in range(8):
		(minus as Button).emit_signal("pressed")
	await get_tree().process_frame
	_ok(int(_garden.get("_market_sell")["carrot"]) == 3,
		"and nine presses leave three in the box")
	var shelf: Node = _find_named(scene, "PileCount_carrot")
	_ok(shelf is Label and (shelf as Label).text == "x9",
		"while the shelf chip says the nine that stayed home")

	# Back in, one at a time, and never past the barn itself.
	var plus: Node = _find_named(scene, "BoxPlus_carrot")
	if plus is Button:
		for i in range(2):
			(plus as Button).emit_signal("pressed")
		for i in range(20):
			(plus as Button).emit_signal("pressed")
	await get_tree().process_frame
	_ok(int(_garden.get("_market_sell")["carrot"]) == 12,
		"the plus stops at everything the barn holds")

	# Down to nothing: the row leaves, the entry leaves, the shelf is whole.
	if minus is Button:
		for i in range(12):
			(minus as Button).emit_signal("pressed")
	await get_tree().process_frame
	_ok(not _garden.get("_market_sell").has("carrot"),
		"minus to zero empties the box for that crop")
	_ok(_find_named(scene, "BoxMinus_carrot") == null,
		"and the row leaves with it")
	shelf = _find_named(scene, "PileCount_carrot")
	_ok(shelf is Label and (shelf as Label).text == "x12",
		"and the shelf chip is whole again")
	_ok(not bool(carrot_item.get("placed", true))
			and int(box_slot.get("held", -1)) == 3
			and carrot_node.position.distance_to(carrot_item["home"]) < 2.0
			and carrot_node.scale.is_equal_approx(Vector2.ONE)
			and carrot_node.z_index == 0,
		"taking the last carrot out returns its card and releases one box slot")
	for crop_id in ["corn", "strawberry", "tomato"]:
		_garden.call("_market_step", str(crop_id), -Barn.count(str(crop_id)))
	await get_tree().process_frame
	_ok(int(box_slot.get("held", -1)) == 0,
		"returning every boxed crop frees the shared slot")
	_ok(rows_scroll is Control and not (rows_scroll as Control).visible
			and drop_hint is Control and (drop_hint as Control).visible,
		"an emptied receipt returns to its clear drop hint")

	# The whole point: box five, sell, and SEVEN are still his.
	await _drag_market_crop_to_box("carrot")
	minus = _find_named(scene, "BoxMinus_carrot")
	if minus is Button:
		for i in range(7):
			(minus as Button).emit_signal("pressed")
	await get_tree().process_frame
	var purse_before := Coins.balance()
	var sell_rect := (sell_button as Button).get_global_rect()
	await _tap(sell_rect.get_center())
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(Coins.balance() == purse_before + 5 * unit,
		"selling a part of the pile pays exactly the boxed crop's worth")
	_ok(Barn.count("carrot") == 7,
		"and the seven he kept are still in the barn")
	_ok(_garden.get("_market_sell").is_empty(),
		"the box is empty after the sale, whatever it sold")
	var empty_receipt := _find_named(scene, "MarketReceiptRows") as ScrollContainer
	_ok(empty_receipt != null and empty_receipt.scroll_vertical == 0,
		"an empty receipt starts at the top after a sale")
	# A second finger may close the panel while the first still holds produce.
	# Its eventual drop must not refill the selection that closing cleared.
	var closing_field := _garden.get("_market_field") as DragField
	var closing_item := _market_item(closing_field.items(), "carrot")
	var closing_card := closing_item.get("node") as Node2D
	var closing_box := (closing_field.slots()[0] as Dictionary).get("node") as Node2D
	await _finger(closing_card.get_global_transform_with_canvas().origin,
		closing_box.get_global_transform_with_canvas().origin + Vector2(0.0, 34.0), func():
			_ok(not closing_field.held().is_empty(),
				"the closing regression starts with a crop actually held")
			_garden.call("_close_panels")
			_ok(not bool(_garden.get("_market_open")),
				"closing the market takes effect while a crop is still held"))
	_ok(_garden.get("_market_sell").is_empty(),
		"releasing a crop after closing cannot refill the forgotten sale basket")
	scene.call("_open_panel", "market")
	for frame in range(3):
		await get_tree().process_frame
	_ok(_garden.get("_market_sell").is_empty(),
		"a new market visit starts with an empty sale basket after that release")
	# The market STAYS open in real play, but a probe that leaves a 780x430
	# sheet of blocker standing over the middle of the farm blocks every tap
	# the sections after it make -- close it the way the child would.
	scene.call("_close_panels")
	await get_tree().process_frame


## Identify the existing recipe notification by its caption and dish name,
## without adding test-only names or state to the product component.
func _recipe_lesson_cards(recipe_name_key: String = "") -> Array[Control]:
	var cards: Array[Control] = []
	var layer := _find_named(_garden, "HarvestFeedbackLayer")
	if layer == null:
		return cards
	for child in layer.get_children():
		if not (child is Panel):
			continue
		var has_caption := false
		var has_dish := recipe_name_key == ""
		for label in child.get_children():
			if label is Label:
				has_caption = has_caption \
					or label.text == I18n.t("garden.recipe_learned")
				if recipe_name_key != "":
					has_dish = has_dish or label.text == I18n.t(recipe_name_key)
		if has_caption and has_dish:
			cards.append(child as Control)
	return cards


func _new_recipe_lesson_card(recipe_name_key: String,
		previous_ids: Array[int]) -> Control:
	for card in _recipe_lesson_cards(recipe_name_key):
		if card.get_instance_id() not in previous_ids:
			return card
	return null


## Every refill fixture starts one strawberry short of its recipe and with
## exactly the other two outside the full barn. Opening a panel must not
## already unlock it; only the tested sale or resume moves those ingredients.
func _stage_recipe_refill() -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	farm["warehouse_cap"] = Farm.WAREHOUSE_START
	farm["warehouse"] = {"carrot": Farm.WAREHOUSE_START - 1, "strawberry": 1}
	farm["harvest_basket"] = {"strawberry": 2}
	farm["unlocked_recipes"] = []
	SaveManager.save_game()


## A refused sale, an immediate refill, and a storage-only app resume. These
## three regressions restore their complete save so later sections inherit
## neither the synthetic legacy crop nor a reset recipe ledger or coin purse.
func _market_refusals_and_recipe_refills_keep_state() -> void:
	var Recipes := preload("res://scripts/garden/recipe_manager.gd")
	var saved_data: Dictionary = SaveManager.data.duplicate(true)
	var previous_notices: Array[int] = []
	for card in _recipe_lesson_cards():
		previous_notices.append(card.get_instance_id())
	var seen_notices: Array[int] = previous_notices.duplicate()
	# Stable, empty beds prevent an unrelated growth transition from serving as
	# the reason for the storage-only resume to redraw its furniture.
	var quiet_plots: Array = []
	for plot in _plots():
		var quiet: Dictionary = Farm.fresh_plot(quiet_plots.size())
		quiet["plot_id"] = str(plot.get("plot_id", quiet["plot_id"]))
		quiet["state"] = Farm.TILLED
		quiet_plots.append(quiet)
	var farm: Dictionary = SaveManager.data["farm"]
	farm["plots"] = quiet_plots
	farm["warehouse"] = {"probe_zero_price_crop": 2}
	farm["harvest_basket"] = {}
	farm["unlocked_recipes"] = []
	SaveManager.save_game()
	_garden.call("_open_panel", "market")
	for frame in range(3):
		await get_tree().process_frame
	var legacy_crop := "probe_zero_price_crop"
	_ok(GameData.get_crop(legacy_crop).is_empty()
			and int(GameData.market_price(legacy_crop)) == 0,
		"the refused-sale fixture is a real unknown crop with a zero market price")
	await _drag_market_crop_to_box(legacy_crop)
	var field := _garden.get("_market_field") as DragField
	var item := _market_item(field.items(), legacy_crop) if field != null else {}
	var card := item.get("node") as Node2D
	var slot: Dictionary = item.get("slot", {})
	var home: Vector2 = item.get("home", Vector2.INF)
	_ok(int(_garden.get("_market_sell").get(legacy_crop, 0)) == 2
			and bool(item.get("placed", false)) and int(slot.get("held", 0)) == 1,
		"the real touch puts the complete legacy pile in the sale box")
	var row_entry: Dictionary = _garden.get("_market_rows").get(legacy_crop, {})
	var row := row_entry.get("row") as Control
	var count := row_entry.get("count") as Label
	_ok(is_instance_valid(row) and is_instance_valid(count) and count.text == "x2",
		"the legacy pile owns a live receipt row before attempting the sale")
	var sell := (_garden.get("_panel_buttons") as Dictionary).get("sell") as Button
	_ok(is_instance_valid(sell), "the zero-price sale still has its real sale button")
	var purse_before := Coins.balance()
	if is_instance_valid(sell):
		await _tap(sell.get_global_rect().get_center())
	_ok(int(_garden.get("_market_sell").get(legacy_crop, 0)) == 2
			and Barn.count(legacy_crop) == 2 and Coins.balance() == purse_before,
		"a refused zero-price sale keeps its selected quantity, produce and purse")
	var kept_entry: Dictionary = _garden.get("_market_rows").get(legacy_crop, {})
	_ok(is_instance_valid(row) and is_instance_valid(count)
			and kept_entry.get("row") == row and kept_entry.get("count") == count,
		"the refused sale preserves the same row and count references")
	_ok(is_instance_valid(card) and bool(item.get("placed", false))
			and int(slot.get("held", 0)) == 1
			and card.position.distance_to(slot.get("at", Vector2.INF)) < 2.0,
		"the refused sale keeps its crop card in the same live box slot")
	var minus := _find_named(_garden, "BoxMinus_%s" % legacy_crop) as Button
	_ok(is_instance_valid(minus), "the preserved legacy row still has its minus button")
	if is_instance_valid(minus):
		for step in range(2):
			await _tap(minus.get_global_rect().get_center())
	_ok(not _garden.get("_market_sell").has(legacy_crop)
			and not _garden.get("_market_rows").has(legacy_crop)
			and not is_instance_valid(row),
		"minus to zero removes the selected legacy pile and its old receipt row")
	_ok(is_instance_valid(card) and not bool(item.get("placed", true))
			and int(slot.get("held", -1)) == 0
			and card.position.distance_to(home) < 2.0
			and card.scale.is_equal_approx(Vector2.ONE),
		"minus to zero after a refused sale returns the card to its original shelf")
	# Keep the immediate assertion above: finishing an old snap tween must not
	# be allowed to undo the child's rapid return to the shelf afterward either.
	await get_tree().create_timer(0.22).timeout
	_ok(is_instance_valid(card) and not bool(item.get("placed", true))
			and card.position.distance_to(home) < 2.0
			and card.scale.is_equal_approx(Vector2.ONE),
		"an unfinished snap cannot later pull the returned card off its shelf")

	_stage_recipe_refill()
	_garden.call("_open_panel", "market")
	for frame in range(3):
		await get_tree().process_frame
	_ok(Barn.total() == Barn.cap() and Barn.count("strawberry") == 1
			and Barn.count("strawberry", Barn.BASKET) == 2
			and not Recipes.is_unlocked("strawberry_soup"),
		"a full barn and two waiting strawberries have not yet earned the soup")
	await _drag_market_crop_to_box("carrot")
	_ok(int(_garden.get("_market_sell").get("carrot", 0)) == Farm.WAREHOUSE_START - 1,
		"the real carrot drag selects only the pile whose sale will free space")
	sell = (_garden.get("_panel_buttons") as Dictionary).get("sell") as Button
	_ok(is_instance_valid(sell), "the full-barn refill uses the real sale action")
	purse_before = Coins.balance()
	if is_instance_valid(sell):
		await _tap(sell.get_global_rect().get_center())
	for frame in range(3):
		await get_tree().process_frame
	_ok(Barn.count("strawberry") == 3 and Barn.count("strawberry", Barn.BASKET) == 0,
		"selling another crop immediately tips both waiting strawberries into the barn")
	_ok(Recipes.is_unlocked("strawberry_soup"),
		"the sale refill teaches strawberry soup without a manual recipe check")
	_ok(Barn.count("carrot") == 0 and Coins.balance() == purse_before \
			+ (Farm.WAREHOUSE_START - 1) * int(GameData.market_price("carrot")),
		"the refill still pays exactly the sold carrot pile and consumes no strawberries")
	var sale_notice := _new_recipe_lesson_card("recipe.strawberry_soup", seen_notices)
	_ok(is_instance_valid(sale_notice)
			and sale_notice.get_parent() == _find_named(_garden, "HarvestFeedbackLayer"),
		"the newly earned soup uses the existing collection feedback layer")
	if is_instance_valid(sale_notice):
		seen_notices.append(sale_notice.get_instance_id())
	_garden.call("_queue_rebuild")
	for frame in range(3):
		await get_tree().process_frame
	_ok(is_instance_valid(sale_notice) and not sale_notice.is_queued_for_deletion(),
		"the sale-earned recipe notification survives a later furniture rebuild")

	_stage_recipe_refill()
	_garden.call("_open_panel", "barn")
	for frame in range(3):
		await get_tree().process_frame
	_ok(Barn.total() == Barn.cap() and not Recipes.is_unlocked("strawberry_soup"),
		"the storage-only resume starts with a full barn and an unknown soup")
	var beds_before: String = str(_garden.call("_how_the_beds_look"))
	var play_before := _garden.get("_play") as Control
	var play_id := play_before.get_instance_id() if is_instance_valid(play_before) else 0
	# Space appears while the app is paused; resume is responsible for settling
	# the waiting basket and notifying the current screen about that change.
	Barn.take("carrot", 2)
	SaveManager.save_game()
	_ok(Barn.total() == Barn.cap() - 2 and Barn.count("strawberry") == 1
			and Barn.count("strawberry", Barn.BASKET) == 2,
		"the paused fixture has storage room but has not manually tipped its basket")
	var resume_changes: Array[bool] = []
	var observe_resume := func(changed: bool): resume_changes.append(changed)
	GameManager.farm_resumed.connect(observe_resume)
	GameManager._notification(NOTIFICATION_APPLICATION_RESUMED)
	for frame in range(3):
		await get_tree().process_frame
	GameManager.farm_resumed.disconnect(observe_resume)
	_ok(resume_changes.size() == 1 and resume_changes[0],
		"the real application resume announces a changed farm after its storage refill")
	_ok(_garden.call("_how_the_beds_look") == beds_before,
		"the storage-only resume leaves every bed's visible fingerprint unchanged")
	var play_after := _garden.get("_play") as Control
	_ok(is_instance_valid(play_after) and play_after.get_instance_id() != play_id,
		"resume refreshes the furniture even when its beds did not change")
	_ok(Barn.count("strawberry") == 3 and Barn.count("strawberry", Barn.BASKET) == 0
			and Recipes.is_unlocked("strawberry_soup"),
		"the resumed warehouse refill and soup knowledge agree on their new state")
	var resume_notice := _new_recipe_lesson_card("recipe.strawberry_soup", seen_notices)
	_ok(is_instance_valid(resume_notice)
			and resume_notice.get_parent() == _find_named(_garden, "HarvestFeedbackLayer")
			and resume_notice.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the resume-earned recipe notification is passive collection feedback")
	_garden.call("_queue_rebuild")
	for frame in range(3):
		await get_tree().process_frame
	_ok(is_instance_valid(resume_notice) and not resume_notice.is_queued_for_deletion(),
		"the resume-earned notification also survives the next furniture rebuild")

	for notice in _recipe_lesson_cards():
		if notice.get_instance_id() not in previous_notices:
			notice.queue_free()
	SaveManager.data = saved_data
	SaveManager.save_game()
	_garden.call("_close_panels")
	for frame in range(3):
		await get_tree().process_frame


## Gold, and the dog. Two rare treats, and the same question about both: does
## the treat cost anything? Gold must celebrate without moving a single
## number -- same yield, same purse -- and the dog must answer a hand on his
## head without growing anything a child could forget to feed.
func _gold_shines_and_the_dog_says_hello() -> void:
	var scene: Node = _garden
	# A golden carrot, forced rare-for-the-probe: ripe, golden, barn empty.
	await get_tree().create_timer(0.6).timeout
	var plots := _plots()
	plots[3]["crop_id"] = "carrot"
	plots[3]["growth_stage"] = 4
	plots[3]["plant_cycle_id"] = 41
	plots[3]["state"] = Farm.READY
	plots[3]["golden"] = true
	SaveManager.data["farm"]["paid_harvests"] = []
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame

	var amount := int(GameData.get_crop("carrot").get("harvest_amount", 0))
	var purse_before := Coins.balance()
	await _tap(_bed(3))
	var barn: Dictionary = SaveManager.data["farm"].get("warehouse", {})
	_ok(int(barn.get("carrot", 0)) == amount,
		"a golden carrot yields exactly what an ordinary one does -- gold is never a bonus")
	_ok(Coins.balance() == purse_before,
		"and the purse did not move either -- gold buys a celebration, not coins")
	var flight: Node = _find_named(scene, "HarvestFlight_carrot")
	_ok(flight != null and bool(flight.get_meta("golden", false)),
		"the flight remembers it flew gold")
	var fresh_golden: bool = bool(_plots()[3].get("golden", false))
	_ok(not fresh_golden,
		"the bed's gold leaves with the harvest, like the crop did")

	# The roll that MAKES gold is a real chance, not a constant true: plant a
	# batch of beds through the real planting path and expect mostly brown.
	var golden_plantings := 0
	var fresh := _plots()
	for i in range(fresh.size()):
		fresh[i] = Farm.fresh_plot(i)
		fresh[i]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"] = fresh
	SaveManager.save_game()
	for i in range(fresh.size()):
		scene.call("_plant_in", i, "carrot")
	var planted: Array = _plots()
	var always: bool = true
	for plot in planted:
		if not bool(plot.get("golden", false)):
			always = false
	_ok(not always,
		"plantings do not all come up golden -- the roll rolls")
	_ok(planted.all(func(p: Dictionary) -> bool: return p.has("golden")),
		"and every planting carries the field, golden or not")

	# The dog. A press on his head gets a reaction -- hearts, not a ledger.
	var world: Node = scene.get("_world")
	var dog: Node = world.get("_dog")
	_ok(dog != null and is_instance_valid(dog), "the farm has its dog")
	if dog != null and is_instance_valid(dog):
		var cam = world.get("camera")
		# Put the dog somewhere nothing else claims -- he follows beds and
		# boards, and a press that lands on what he is STANDING BESIDE belongs
		# to that thing, not to him. Walk east until the spot under him is
		# bed-free and facility-free, park him there, then press his head.
		var spot: Vector2 = dog.get("position")
		for i in range(12):
			var here: Vector2 = cam.call("world_to_screen", spot)
			if world.call("bed_under", here) < 0 \
					and world.call("facility_under", here) == "":
				break
			spot += Vector2(150.0, 0.0)
		dog.set("position", spot)
		dog.set("_target", spot)
		await get_tree().process_frame
		# press_at's contract, for direct calls, is the same space its own
		# helpers answer in -- the viewport's. (Real input events arrive
		# stretched; a direct call bypasses that pipeline, which is exactly
		# why it must NOT pre-convert.)
		var dog_screen: Vector2 = cam.call("world_to_screen",
			spot + Vector2(0.0, -48.0))
		world.call("press_at", dog_screen)
		await get_tree().process_frame
		_ok(bool(dog.get("_petting")),
			"a press on the dog is answered with a wag")
		_ok(_find_named(dog, "PetHeart") != null,
			"and a heart or two, with nothing written down anywhere")
	# Let the reaction end before the next section borrows the screen.
	await get_tree().create_timer(1.2).timeout


## The day's little jobs. The three verbs the farm teaches, tallied for one
## day, claimed once, and rolled clean while he sleeps -- driven through the
## real verbs (a tap-water, a real pick, a real delivery) because the tally
## lives in the same actions the child performs.
func _the_day_has_its_own_little_jobs() -> void:
	var scene: Node = _garden
	var view: Vector2 = get_viewport().get_visible_rect().size
	var compact := view.x / maxf(view.y, 1.0) < 1.6
	# A fresh day, clean tallies.
	GameClock.set_test_now(NOON, 0)
	SaveManager.data["farm"]["dailies"] = {"date": GameClock.now_date(),
		"progress": {}, "claimed": []}
	SaveManager.data["farm"]["paid_harvests"] = []
	SaveManager.data["farm_orders"] = {"delivered": []}
	SaveManager.save_game()

	# Water: a thirsty bed, one tap, one tally.
	var plots := _plots()
	plots[0]["state"] = Farm.NEEDS_CARE
	plots[0]["crop_id"] = "carrot"
	plots[0]["care_event"] = "thirsty"
	plots[0]["care_completed"] = false
	plots[0]["growth_stage"] = 1
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	await _tap(_bed(0))
	var dailies: Dictionary = SaveManager.data["farm"].get("dailies", {})
	_ok(int(dailies.get("progress", {}).get("water", 0)) == 1,
		"watering a thirsty bed fills today's water tally")
	var water_beds: Array = (_garden.get("_world") as Node).get("_beds")
	var water_feedback: Node = water_beds[0].get_node_or_null("PlotActionFeedback") \
		if not water_beds.is_empty() else null
	_ok(water_feedback is Node2D and _find_named(water_feedback, "WaterDrop_0") != null,
		"a tap-water keeps its visible drop through the immediate redraw")
	# The day asks for THREE waterings, and each bed is thirsty once per
	# planting -- so two more beds get thirsty and two more taps go out.
	plots = _plots()
	for i in [1, 2]:
		plots[i]["state"] = Farm.NEEDS_CARE
		plots[i]["crop_id"] = "carrot"
		plots[i]["care_event"] = "thirsty"
		plots[i]["care_completed"] = false
		plots[i]["growth_stage"] = 1
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	# No paper over the farm: the sections before this one may have left a
	# panel open, and a tap that lands on a blocked bed is a tap the farm
	# never hears.
	scene.call("_close_panels")
	await get_tree().process_frame
	await _tap(_bed(1))
	await _tap(_bed(2))
	dailies = SaveManager.data["farm"].get("dailies", {})
	_ok(int(dailies.get("progress", {}).get("water", 0)) == 3,
		"three waterings fill the tally to its target")

	# Pick: a ripe carrot, one tap, three crops into the tally.
	await _ripen(3, "carrot", 51)
	await _tap(_bed(3))
	dailies = SaveManager.data["farm"].get("dailies", {})
	_ok(int(dailies.get("progress", {}).get("harvest", 0)) == 3,
		"picking a bed counts its crops toward the harvest tally")

	# Deliver: the bear's three carrots, handed over through the real path.
	var order: Dictionary = GameData.garden_orders[0]
	for crop_id in order.get("requirements", {}).keys():
		Barn.put(str(crop_id), int(order["requirements"][crop_id]))
	SaveManager.save_game()
	scene.call("_deliver", order)
	dailies = SaveManager.data["farm"].get("dailies", {})
	_ok(int(dailies.get("progress", {}).get("deliver", 0)) == 1,
		"handing an order over fills the delivery tally")
	await get_tree().process_frame
	await get_tree().process_frame
	# The real verbs above have lit water and delivery; the crop tally is still
	# two short. Finish that one existing tally through the screen helper, then
	# rebuild the real shelf to prove the last star becomes the same golden-luck
	# state that planting uses -- no separate UI counter is allowed here.
	var partial_daily: Node = _find_named(scene, "HeroTaskDaily")
	if compact:
		_ok(partial_daily == null,
			"the compact task card keeps the daily tally out of the one action line")
	else:
		_ok(partial_daily != null and int(partial_daily.get_meta("done", -1)) == 2
			and not bool(partial_daily.get_meta("all_done", true)),
			"two finished daily verbs light two stars before the final little job")
	scene.call("_daily_progress", "harvest", 2)
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	var lucky_daily: Node = _find_named(scene, "HeroTaskDaily")
	var lucky_label: Node = _find_named(scene, "HeroTaskDailyProgress")
	if compact:
		var summary: Dictionary = Dailies.summary(SaveManager.data["farm"].get("dailies", {}))
		_ok(lucky_daily == null and lucky_label == null
			and bool(summary.get("all_done", false)),
			"the compact card hides the completed crest without changing its derived state")
		_ok(is_equal_approx(scene.call("_golden_chance"), 0.08),
			"the compact action-only card keeps today's golden luck active")
	else:
		_ok(lucky_daily != null and int(lucky_daily.get_meta("done", -1)) == 3
			and int(lucky_daily.get_meta("total", -1)) == 3
			and bool(lucky_daily.get_meta("all_done", false)),
			"the final daily star lights the complete care crest on the real task card")
		_ok(lucky_label is Label and (lucky_label as Label).text
			== I18n.t("garden.daily.lucky"),
			"the complete crest tells the child that today's golden luck is active")

	# Claim on the board, once. The second press meets a tick, not a purse.
	Barn.put("carrot", 2)   # room is irrelevant; the tally is what gates
	SaveManager.save_game()
	scene.call("_open_panel", "orders")
	await get_tree().process_frame
	var job: Node = _find_named(scene, "DailyJob_water")
	_ok(job is Button and not (job as Button).disabled,
		"the finished water job lights up on the board")
	var purse_before := Coins.balance()
	if job is Button:
		(job as Button).emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
	_ok(Coins.balance() == purse_before
			+ int(GameData.garden_dailies[0].get("coins", 0)),
		"claiming the day's job pays what the card promised")
	dailies = SaveManager.data["farm"].get("dailies", {})
	_ok(Dailies.claimed(dailies, Dailies.task_by_id("water")),
		"and the claim is written down for the rest of the day")
	# The claim's rebuild threw the old card away; the way out is re-found,
	# never reused -- a freed button is a fault, and a faulted section skips
	# its own tail and still prints PASSED.
	job = _find_named(scene, "DailyJob_water")
	if job is Button and is_instance_valid(job):
		(job as Button).emit_signal("pressed")
		await get_tree().process_frame
	_ok(Coins.balance() == purse_before
			+ int(GameData.garden_dailies[0].get("coins", 0)),
		"a second press on the same claim pays nothing again")

	# Midnight rolls the list while nobody is looking: progress gone, claims
	# gone, and the tallies restart from zero through the real progress path.
	GameClock.set_test_now(NOON + 86400, 0)
	scene.call("_daily_progress", "water")
	dailies = SaveManager.data["farm"].get("dailies", {})
	_ok(int(dailies.get("progress", {}).get("water", 0)) == 1,
		"a new day rolls a clean list and starts counting again")
	_ok(not Dailies.claimed(dailies, Dailies.task_by_id("water")),
		"and yesterday's claims do not follow him into it")
	# The claim section opened the board; a probe that leaves a sheet of
	# blocker standing over the farm blocks every tap after it.
	scene.call("_close_panels")
	await get_tree().process_frame



## The day's list, finished, doubles the gold: 王者农场's blessing-to-mutation
## loop in its kindest form -- earned by CARING, never by paying, and a child
## who never opens the list is never told he lost anything.
func _gold_blessing_from_the_days_care() -> void:
	var scene: Node = _garden
	var base: float = scene.call("_golden_chance")
	_ok(is_equal_approx(base, 0.04),
		"an unfinished day leaves the gold chance where it was")
	var dailies_now: Dictionary = SaveManager.data["farm"].get("dailies", {})
	var prog: Dictionary = dailies_now.get("progress", {})
	for task in GameData.garden_dailies:
		prog[str(task.get("id", ""))] = int(task.get("target", 1))
	dailies_now["progress"] = prog
	SaveManager.data["farm"]["dailies"] = dailies_now
	var boosted: float = scene.call("_golden_chance")
	_ok(is_equal_approx(boosted, 0.08),
		"a day fully cared for doubles the gold chance -- the blessing, earned")


## The harvest door, restored after a parallel-edit collision took the first
## draft: the chip names the tally honestly against the save, the shortcut
## under it starts the next unstarred level, and the little card beside it
## shows what that level asks for -- the crop, or a star when the shelf is
## empty.
func _the_challenge_door_shows_what_is_next(view: Vector2) -> void:
	var scene: Node = _garden
	_ok(OS.is_debug_build(),
		"orphan-art checks run with a debug engine that exposes node lifetime counts")
	var levels: Array = GameData.get_levels_for_mode("harvest")
	_ok(not levels.is_empty(), "the harvest challenge has levels to show")
	var door: Node = _find_named(scene, "HarvestChallenge")
	_ok(door != null, "the challenge door stands in the top bar")
	var press: Node = _find_named(scene, "HarvestChallengeShortcut")
	_ok(press is Button and not (press as Button).disabled,
		"and its way in is pressable")
	var next_card: Node = _find_named(scene, "ChallengeNext")
	_ok(next_card != null and next_card.has_meta("shows"),
		"and what comes next has a card that names it")
	var door_rect := (door as Control).get_global_rect() if door is Control else Rect2()
	var press_rect := (press as Control).get_global_rect() if press is Control else Rect2()
	_ok(door is Control and press is Control and door_rect.size.is_equal_approx(press_rect.size),
		"the whole visible challenge card is the whole press target")
	var compact := view.x / maxf(view.y, 1.0) < 1.6
	_ok(next_card is Control and (next_card as Control).visible == not compact,
		"the next-crop card stays out of the farm window on a compact tablet")

	# The tally, honest against the save: no stars anywhere reads zero.
	var count: Node = _find_named(scene, "ChallengeCount")
	_ok(count is Label and (count as Label).text
			== "0/%d" % levels.size(),
		"a fresh save reads 0 over every harvest level")
	# The first look must be concrete, not merely "some preview": a fresh
	# garden points at the very crop in the first unfinished challenge.
	var first_config: Dictionary = levels[0].get("config", {})
	var first_targets: Array = first_config.get("targets", [])
	var first_crop := ""
	if not first_targets.is_empty():
		var first_target: Dictionary = first_targets[0]
		first_crop = str(first_target.get("crop_id", ""))
	_ok(not first_crop.is_empty() and next_card != null
			and str(next_card.get_meta("shows", "")) == first_crop,
		"a fresh garden previews the first challenge crop '%s'" % first_crop)
	await _challenge_preview_keeps_its_art_owned(scene, first_crop)

	# One star lands on the first harvest level: the tally moves to one, and
	# the door keeps standing in its slot -- the number is the promise.
	var first: String = str(levels[0].get("id", ""))
	SaveManager.data["levels"][first] = {"stars": 1, "best_accuracy": 1.0,
		"attempts": 1, "completed": true, "found_hidden": false}
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	count = _find_named(scene, "ChallengeCount")
	_ok(count is Label and (count as Label).text
			== "1/%d" % levels.size(),
		"one starred level moves the tally to one")
	press = _find_named(scene, "HarvestChallengeShortcut")
	_ok(press is Button and not (press as Button).disabled,
		"and the door still opens the next unstarred level")
	if press is Button:
		# This probe owns the current scene, so let the real press reach
		# GameManager but hold SceneManager's transition for this one frame.
		# It verifies the connected shortcut without replacing the probe itself.
		var expected := str(levels[1].get("id", ""))
		var was_busy := bool(SceneManager.get("_busy"))
		SceneManager.set("_busy", true)
		(press as Button).emit_signal("pressed")
		await get_tree().process_frame
		_ok(GameManager.current_level_id == expected,
			"pressing the door starts the next unstarred harvest challenge")
		SceneManager.set("_busy", was_busy)

	# Once every challenge has a star, there is no crop left to promise. The
	# same card becomes a clear completion star instead of retaining stale art.
	for level in levels:
		var level_id: String = str(level.get("id", ""))
		SaveManager.data["levels"][level_id] = {"stars": 1, "best_accuracy": 1.0,
			"attempts": 1, "completed": true, "found_hidden": false}
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	next_card = _find_named(scene, "ChallengeNext")
	_ok(next_card != null and str(next_card.get_meta("shows", "")) == "star",
		"a completed harvest shelf previews a star, not a stale crop")
	await _challenge_preview_keeps_its_art_owned(scene, "star")


## A crop preview used to build its fallback star and then overwrite the
## variable. Those unparented shapes survived every refresh and screen exit.
## Exercise both the crop and completion paths through the real rebuild.
func _challenge_preview_keeps_its_art_owned(scene: Node, expected: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for refresh in range(8):
		scene.call("_rebuild")
		await get_tree().process_frame
		await get_tree().process_frame
	var card: Node = _find_named(scene, "ChallengeNext")
	_ok(card != null and str(card.get_meta("shows", "")) == expected
			and card.get_child_count() == 1,
		"repeated refreshes leave exactly the selected '%s' picture in its card" % expected)
	_ok(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphans_before,
		"repeated '%s' previews never accumulate unparented art nodes" % expected)


## Care with moves of its own: water pours DOWN, a weed pulls UP like a
## carrot, a bug is shooed side to side -- judged by the same Gesture
## recognisers the harvest moves are. A tap still does every one of these
## jobs; the moves are the expressive path, never a gate.
func _care_has_moves_of_its_own() -> void:
	var scene: Node = _garden
	var moves: Dictionary = scene.get("CARE_MOVES")
	for event in ["thirsty", "weeds", "bug"]:
		_ok(moves.has(event),
			"the %s care event has a move of its own" % event)
	for key in moves:
		_ok(str(moves[key].get("recogniser", "")) in Gesture.ALL,
			"the %s care move is one Gesture can judge" % key)
	await get_tree().create_timer(0.6).timeout

	# Water pours from above: press the thirsty bed, drag DOWN, let go.
	var plots: Array = SaveManager.data["farm"]["plots"]
	plots[0]["state"] = Farm.NEEDS_CARE
	plots[0]["crop_id"] = "carrot"
	plots[0]["care_event"] = "thirsty"
	plots[0]["care_completed"] = false
	plots[0]["growth_stage"] = 1
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	var world_care: Node = scene.get("_world")
	print("DBG care ctx: garden_valid=%s world=%s finger=%s locked=%s blockers=%s level_id=%s" % [
		str(is_instance_valid(_garden)), str(world_care != null),
		str(world_care.get("_finger") if world_care else "?"),
		str(world_care.get("locked") if world_care else "?"),
		str((world_care.get("blockers") as Array).size() if world_care else "?"),
		str(GameManager.current_level_id)])
	await _finger(_bed(0), _bed(0) + Vector2(0.0, 120.0))
	print("DBG care after pour: state=%s care='%s' dailies_water=%s" % [
		str(_plots()[0].get("state")),
		str(_plots()[0].get("care_event", "")),
		str(SaveManager.data["farm"].get("dailies", {}).get("progress", {}).get("water", 0))])
	_ok(str(_plots()[0].get("state", "")) == Farm.GROWING
			and str(_plots()[0].get("care_event", "")) == "",
		"pouring down onto a thirsty bed waters it")
	# The state refresh happens in the same path as the pour.  The drops must
	# therefore live beside the redrawable badge layer: checking them after the
	# real gesture catches the old version that queued all five for deletion
	# before a frame could paint them.
	var water_world: Node = scene.get("_world")
	var water_beds: Array = water_world.get("_beds") if water_world != null else []
	var water_bed: Node = water_beds[0] if not water_beds.is_empty() else null
	var water_feedback: Node = water_bed.get_node_or_null("PlotActionFeedback") \
		if water_bed != null else null
	_ok(water_feedback is Node2D and _find_named(water_feedback, "WaterDrop_0") != null,
		"the water drop is still visible after its state redraw")
	await get_tree().create_timer(0.72).timeout
	_ok(water_feedback != null and water_feedback.get_child_count() == 0,
		"the short water answer cleans itself up after landing")

	# A weed pulls up like a carrot.
	plots = _plots()
	plots[1]["state"] = Farm.NEEDS_CARE
	plots[1]["care_event"] = "weeds"
	plots[1]["care_completed"] = false
	plots[1]["growth_stage"] = 1
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	await _finger(_bed(1), _bed(1) + Vector2(0.0, -120.0))
	_ok(str(_plots()[1].get("state", "")) == Farm.GROWING
			and str(_plots()[1].get("care_event", "")) == "",
		"pulling up on a weedy bed weeds it")

	# A bug is shooed side to side: a real zigzag, two real reversals.
	plots = _plots()
	plots[2]["state"] = Farm.NEEDS_CARE
	plots[2]["care_event"] = "bug"
	plots[2]["care_completed"] = false
	plots[2]["growth_stage"] = 1
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	var mid: Vector2 = _bed(2)
	var legs := [Vector2(-70.0, 0.0), Vector2(70.0, 0.0),
		Vector2(-70.0, 0.0), Vector2(70.0, 0.0)]
	var at: Vector2 = mid + legs[0]
	var zig_down := InputEventScreenTouch.new()
	zig_down.index = 0
	zig_down.pressed = true
	zig_down.position = _glass(at)
	Input.parse_input_event(zig_down)
	await get_tree().process_frame
	for i in range(1, legs.size()):
		var zig := InputEventScreenDrag.new()
		zig.index = 0
		zig.position = _glass(mid + legs[i])
		Input.parse_input_event(zig)
		await get_tree().process_frame
	var zig_up := InputEventScreenTouch.new()
	zig_up.index = 0
	zig_up.pressed = false
	zig_up.position = _glass(mid + legs[legs.size() - 1])
	Input.parse_input_event(zig_up)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(str(_plots()[2].get("state", "")) == Farm.GROWING
			and str(_plots()[2].get("care_event", "")) == "",
		"shooing side to side chases the bug off")

	# The wrong move is not an error: a downward drag on a WEEDY bed weeds
	# nothing -- the camera pans instead, the way any drag from a bed does.
	plots = _plots()
	plots[3]["state"] = Farm.NEEDS_CARE
	plots[3]["care_event"] = "weeds"
	plots[3]["care_completed"] = false
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	var cam_before: Vector2 = _camera().centre
	var side := _roomiest_side()
	await _finger(_bed(3), _bed(3) + Vector2(150.0 * side, 0.0))
	_ok(str(_plots()[3].get("care_event", "")) == "weeds",
		"the wrong move does no care -- the weeds wait for the right one")
	_ok(not is_equal_approx(_camera().centre.x, cam_before.x),
		"and the camera pans instead -- a missed move is still a pan")

	# The tap still cares. There is no wrong tap on this screen.
	plots = _plots()
	plots[0]["state"] = Farm.NEEDS_CARE
	plots[0]["care_event"] = "thirsty"
	plots[0]["care_completed"] = false
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	var world_t: Node = scene.get("_world")
	var bed_t: Vector2 = _bed(0)
	print("DBG final tap: bed=%s inside=%s blocked=%s under=%s wants=%s state=%s care='%s'" % [
		str(bed_t),
		str(world_t.get("camera").call("inside", bed_t)),
		str(world_t.call("_blocked", bed_t)),
		str(world_t.call("bed_under", bed_t)),
		str(world_t.get("gesture_bed_check").call(0)),
		str(_plots()[0].get("state")), str(_plots()[0].get("care_event", ""))])
	# The camera has wandered (the failed-move pans); walk it back to the bed
	# the way the world walks to the expansion slots, then tap.
	world_t.call("look_at_world", Layout.plot_at(0))
	await get_tree().process_frame
	await get_tree().process_frame
	await _tap(_bed(0))
	var after_t: Dictionary = _plots()[0]
	print("DBG final after: state=%s care='%s'" % [
		str(after_t.get("state")), str(after_t.get("care_event", ""))])
	_ok(str(_plots()[0].get("care_event", "")) == "",
		"a plain tap still waters, weeds and shoos -- no wrong tap here")
