extends Node
## 星光农场 as a place you can move around in.
##
## WHY THIS IS A TOUCH PROBE AND NOT A LOGIC ONE
##
## Everything this stage added is a drag. Panning is a drag, the brush that
## arrives next stage is a drag, telling a tap from a drag is the whole of how
## the farm decides what a finger meant. 丰收行动 shipped four levels that could
## not be played with a finger at all while three layers of checks stayed green,
## because nothing anywhere pushed a real InputEventScreenDrag -- the logic
## probe verified angles, the static check read text, and the screenshot showed
## a still picture. So every gesture below goes in through Input.parse_input_event
## and comes out the other side of the real pipeline.
##
##
## WHY BOTH SCREEN SHAPES
##
## The island stretches with aspect=expand: a 4:3 tablet hands the farm a
## 1280x960 viewport out of a 1024x768 window, so the farm's window is 240px
## taller and the opening zoom is a step closer in. That difference has already
## produced one real bug in this stage -- the closer zoom put the outermost bed
## 25px from the bezel, on the iPad and nowhere else.

const Layout := preload("res://scripts/garden/farm_layout.gd")
const FarmCamera := preload("res://scripts/garden/farm_camera_controller.gd")
const FarmWorld := preload("res://scripts/garden/farm_world_controller.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
const Stroke := preload("res://scripts/garden/continuous_action_controller.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]
const NOON := 1_699_963_200

## See garden_probe.gd. An empty failure list means nothing came back wrong, not
## that anything was asked -- and half of this file finds something on a screen
## before questioning it.
const CHECKS_EXPECTED := 807

var _failures: Array[String] = []
var _asked := 0
var _shape := ""
var _garden: Node = null


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _ready() -> void:
	ProbeLifecycle.isolate_desktop_pointer(self)
	var barn_upgrade_only := OS.get_cmdline_user_args().has(
		"--barn-upgrade-only")
	var market_sale_only := OS.get_cmdline_user_args().has(
		"--market-sale-only")
	var focused_probe := barn_upgrade_only or market_sale_only
	var probe_name := "farm barn upgrade probe" if barn_upgrade_only \
		else "farm market sale probe" if market_sale_only else "farm world probe"
	print("\n=== %s ===" % probe_name)
	if focused_probe:
		for shape in SHAPES:
			if barn_upgrade_only:
				await _run_barn_upgrade_on(shape)
			else:
				await _run_market_sale_on(shape)
	else:
		_an_old_npc_save_gains_friend_defaults()
		_the_layout_is_legal()
		_the_stroke_bookkeeping_refuses_seconds()
		_tool_action_controller_owns_plot_transitions()
		_golden_state_is_a_visual_input()
		for shape in SHAPES:
			_shape = "%dx%d" % [shape.x, shape.y]
			await _run_on_a(shape)

	var focused_checks := 17 if barn_upgrade_only else 10
	var expected := focused_checks * SHAPES.size() if focused_probe \
		else CHECKS_EXPECTED
	if _asked < expected:
		_failures.append("this probe only asked %d questions and expected at "
			% _asked + "least %d -- a section was skipped in silence" % expected)
	for failure in _failures:
		print("FAIL  %s" % failure)
	print("asked %d questions" % _asked)
	var label := "FARM BARN UPGRADE PROBE" if barn_upgrade_only \
		else "FARM MARKET SALE PROBE" if market_sale_only \
		else "FARM WORLD PROBE"
	print("%s %s\n" % [label,
		"PASSED" if _failures.is_empty() else "FAILED"])
	get_tree().quit(1 if _failures.size() > 0 else 0)


## Keep the roof's real confirm, payment, and regret flow cheap to run on both
## tablet shapes without stepping through every unrelated farm interaction.
func _run_barn_upgrade_on(window: Vector2i) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Vector2 = get_viewport().get_visible_rect().size
	_shape = "%dx%d" % [window.x, window.y]
	print("-- barn window %s -> viewport %s" % [str(window), str(view)])
	_fresh_farm()
	_open()
	await get_tree().process_frame
	await get_tree().process_frame
	await _the_barn_roof_is_bought_once(view)
	await _close()


## Exercise a refused stale sale and the same basket's later successful retry
## through the market panel's real thumb path, in both tablet shapes.
func _run_market_sale_on(window: Vector2i) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Vector2 = get_viewport().get_visible_rect().size
	_shape = "%dx%d" % [window.x, window.y]
	print("-- market window %s -> viewport %s" % [str(window), str(view)])
	_fresh_farm()
	_open()
	await get_tree().process_frame
	await get_tree().process_frame
	await _the_market_box_sells_the_pile_he_dragged(view)
	await _close()


func _run_on_a(window: Vector2i) -> void:
	get_window().size = window
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Vector2 = get_viewport().get_visible_rect().size
	print("-- window %s -> viewport %s" % [str(window), str(view)])

	_fresh_farm()
	_open()
	await get_tree().process_frame
	await get_tree().process_frame

	await _every_bed_is_on_the_glass_when_he_walks_in(view)
	await _golden_refresh_updates_the_live_plot()
	await _the_opening_view_keeps_a_complete_base_landmark()
	await _the_two_coordinate_spaces_agree()
	await _dragging_the_grass_moves_the_farm()
	await _dragging_from_a_bed_moves_the_farm_too()
	await _a_tap_is_not_a_drag()
	await _he_cannot_drag_the_farm_away(view)
	await _every_zoom_keeps_the_beds_far_enough_apart()
	await _the_overview_shows_the_whole_farm()
	await _two_taps_on_the_grass_bring_him_home()
	await _pressing_a_building_looks_at_it()
	await _landmark_scenery_stays_passive()
	await _the_furniture_is_not_a_hole_in_the_farm(view)
	await _the_drop_targets_follow_the_beds()
	await _a_seed_still_lands_where_he_aimed_after_panning()
	await _the_farm_holds_still_while_a_seed_is_in_the_air()
	# --- 阶段 2: the tool rack and the brushes ---
	await _the_tool_rack_is_on_the_shelf(view)
	await _a_grey_tool_stays_out_of_his_hand()
	await _the_shovel_sweeps_a_row()
	await _the_brush_skips_beds_that_do_not_need_it()
	await _one_stroke_never_pays_twice()
	await _one_brush_stroke_keeps_every_spill_on_the_same_basket_rim()
	await _the_last_job_hands_back_the_hand()
	await _the_seed_brush_plants_what_he_chose()
	await _grass_pans_and_buildings_answer_with_a_tool_in_hand()
	await _a_gentle_hand_gets_a_bigger_bed()
	# --- 阶段 3: the shop, the market box, and the barn's roof ---
	await _the_shop_asks_before_it_takes(view)
	await _the_market_box_sells_the_pile_he_dragged(view)
	await _the_barn_roof_is_bought_once(view)
	# --- 阶段 4: the bear's door, the visitor board, and the dog ---
	await _the_bear_door_waits_for_the_first_harvest()
	await _friend_farm_buttons_are_available()
	await _the_visitor_board_reads_and_clears(view)
	await _the_dog_minds_his_own_business()
	# --- 阶段 5: the stones, the ladder, and the market's one lesson ---
	await _the_stones_ask_before_they_move()
	await _the_barn_full_moment_points_at_the_market()

	await _close()
	# The bear's own farm is another scene; it gets the glass to itself,
	# exactly as it would in the game.
	await _a_visit_to_the_bears_farm()
	await _a_visit_to_a_friends_farm("rabbit")
	await _a_visit_to_a_friends_farm("puppy")


# --- the fixture ----------------------------------------------------------

func _fresh_farm() -> void:
	GameClock.set_test_now(NOON, 0)
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	SaveManager.data["farm"]["last_seen_at"] = NOON
	# No lesson: it moves the camera and talks over everything, and it has its
	# own probe. This one is about the ground.
	SaveManager.data["farm"]["tutorial_completed"] = true


func _open() -> void:
	GameManager.current_level_id = "star_garden"
	_garden = load("res://scenes/garden/Garden.tscn").instantiate()
	add_child(_garden)
	# No quiet clock either. Its 20 s beat runs on the wall clock, not the
	# frozen GameClock, and settle_farm() replaces SaveManager.data["farm"]
	# with a copy -- so a section holding `var farm := SaveManager.data["farm"]`
	# across that beat writes into a dictionary the garden no longer reads.
	# Under software GL the probe is long enough for the beat to land inside
	# a section (it did: the stones' confirm and the untouched growing bed).
	# The tick has clock_probe; this one is about the ground.
	_garden.set("_garden_tick_running", false)


func _close() -> void:
	if is_instance_valid(_garden):
		_garden.queue_free()
	_garden = null
	# The next shape starts a new Garden and sends real input at it. Let the
	# previous UI leave the tree first, or its still-live shelf buttons may
	# receive a 4:3 touch intended for the fresh scene.
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.clear_test_now()


func _world() -> FarmWorld:
	return _garden.get("_world")


func _camera() -> FarmCamera:
	return _world().camera


func _plots() -> Array:
	return SaveManager.data["farm"]["plots"]


## Golden is rendered by PlotView, so its value must participate in the
## incremental refresh key. Otherwise the crop can change rarity without the
## existing bed ever rebuilding its artwork.
func _golden_state_is_a_visual_input() -> void:
	var ordinary := Farm.fresh_plot(0)
	ordinary["state"] = Farm.GROWING
	ordinary["crop_id"] = "strawberry"
	ordinary["growth_stage"] = 1
	var rare: Dictionary = ordinary.duplicate(true)
	rare["golden"] = true
	var bed := PlotView.new()
	_ok(bed.call("_fingerprint", ordinary)
		!= bed.call("_fingerprint", rare),
		"golden rarity changes the PlotView incremental redraw fingerprint")
	bed.free()


func _golden_refresh_updates_the_live_plot() -> void:
	var original: Dictionary = _plots()[0].duplicate(true)
	_set_bed(0, {"state": Farm.GROWING, "crop_id": "strawberry",
		"growth_stage": 1, "planted_at": NOON - 300, "golden": false})
	_world().refresh(_plots())
	await get_tree().process_frame
	var beds: Array = _world().get("_beds")
	var planting: Node = beds[0].get("_planting")
	var ordinary_children := planting.get_child_count()
	_plots()[0]["golden"] = true
	_world().refresh(_plots())
	await get_tree().process_frame
	_ok(planting.get_child_count() > ordinary_children,
		"a growing golden crop adds its backlight on the already-open bed")
	_plots()[0]["golden"] = false
	_world().refresh(_plots())
	await get_tree().process_frame
	_ok(planting.get_child_count() == ordinary_children,
		"clearing golden rarity removes the stale backlight on refresh")
	_plots()[0] = original
	_world().refresh(_plots())
	await get_tree().process_frame


## Design coordinates to window pixels. The 4:3 tablet's window is 1024x768
## while its viewport is 1280x960, so an event pushed at design coordinates
## lands a quarter of the way off -- and "the drag missed" looks exactly like
## "the drag is broken".
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
	await get_tree().process_frame
	await get_tree().process_frame


## A real drag: down, several moves, up. `steps` matters -- the farm adds up how
## far the finger has travelled, so one giant jump and eight small ones are not
## the same question.
func _finger(from: Vector2, to: Vector2, steps: int = 8) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(from)
	Input.parse_input_event(down)
	await get_tree().process_frame

	var last := from
	for step in range(1, steps + 1):
		var at: Vector2 = from.lerp(to, float(step) / float(steps))
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


## Two taps in quick succession -- ONE await between them, so the gesture is
## quick whatever the frame rate. The probe runs under software rendering,
## where a frame can cost fifty times what it costs on a tablet, and a double
## tap built out of leisurely _tap() calls can drift past the window and fail
## on slowness that is the machine's, not the game's.
func _double_tap(at: Vector2) -> void:
	for _n in range(2):
		for pressed in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = pressed
			touch.position = _glass(at)
			Input.parse_input_event(touch)
			await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


## A point on the glass with no bed and no building under it.
func _bare_grass() -> Vector2:
	var window: Rect2 = _camera().window
	for y in range(int(window.position.y) + 40, int(window.end.y) - 40, 24):
		for x in range(40, int(window.size.x) - 40, 24):
			var at := Vector2(x, y)
			if _world().bed_under(at) < 0 and _world().facility_under(at) == "":
				return at
	return Vector2.ZERO


# --- what is checked ------------------------------------------------------

## The layout's own rules, asked of the layout. Free, instant, and the same
## arithmetic tools_check.py runs before anything is launched -- asked here too
## because the file it reads could be replaced at runtime by a bad merge and
## because a rule with only one reader is a rule with one place to be forgotten.
func _the_layout_is_legal() -> void:
	_shape = "layout"
	for count in [Farm.PLOT_COUNT, Layout.places_for_plots()]:
		for problem in Layout.problems(count):
			_ok(false, "with %d beds: %s" % [count, problem])
		_ok(true, "the layout is legal with %d beds" % count)
	_ok(Layout.world_size().x > 0.0 and Layout.world_size().y > 0.0,
		"the world has a size")
	_ok(Layout.zoom_steps().size() >= 2, "there is more than one zoom")
	_ok(Layout.min_zoom() > 0.0, "the smallest zoom is not zero")
	_ok(Layout.facilities().size() >= 6,
		"the farm has buildings on it, not just beds")


## Gate one of the brush, asked point-blank.
##
## Behind the game it can barely be seen: every job flips its own needs()
## answer (a harvested bed stops being READY), so gate two masks gate one for
## every tool that exists TODAY. That is luck, not design -- the first future
## job that leaves its bed wanting more (collecting eggs, picking berries off
## a bush that keeps them coming) would repeat on every wobble of the finger.
## So the bookkeeping is asked directly, on a bed that still LOOKS workable
## the second time: only the done list can say no here.
func _the_stroke_bookkeeping_refuses_seconds() -> void:
	_shape = "stroke"
	var stroke: Stroke = Stroke.new()
	var tools: Tools = Tools.new()
	tools.selected = "basket"
	var ripe: Dictionary = Farm.fresh_plot(0)
	ripe["state"] = Farm.READY
	ripe["crop_id"] = "carrot"
	var plots := [ripe]

	stroke.begin()
	_ok(stroke.may_apply(tools, plots, 0), "a ripe bed may be worked once")
	_ok(not stroke.may_apply(tools, plots, 0),
		"and the done list alone refuses the second visit -- the bed still "
		+ "reads as ripe, so nothing else here could have said no")
	_ok(stroke.applied == 0,
		"eligibility reserves the bed but does not claim work before a transition")
	var first_finish: Dictionary = stroke.finish()
	_ok(int(first_finish.get("applied", -1)) == 0
			and not bool(first_finish.get("did_work", true))
			and stroke.applied == 0,
		"an attempted no-op closes without saving and clears the old stroke")
	_ok(stroke.may_apply(tools, plots, 0),
		"a NEW stroke may work the same bed again -- once per stroke, not "
		+ "once per childhood")
	_ok(stroke.record_applied(0), "a changed bed is recorded as real work")
	_ok(not stroke.record_applied(0), "one bed cannot add work twice")
	_ok(not stroke.may_apply(tools, plots, -1)
			and not stroke.may_apply(tools, plots, 9),
		"and a bed that does not exist is never worked")
	var second_finish: Dictionary = stroke.finish()
	_ok(int(second_finish.get("applied", 0)) == 1
			and stroke.applied == 0,
		"bad bed indexes never add to the next stroke's commit count")
	var empty_finish: Dictionary = stroke.finish()
	_ok(not bool(empty_finish.get("did_work", true))
			and int(empty_finish.get("applied", -1)) == 0,
		"an empty stroke closes without asking the save layer to write")


## The toolbar is the shared rule for a tool's state change. The page supplies
## the clock and lesson/golden context; this controller joins that context to
## the old plot transitions without mutating their input snapshots.
func _tool_action_controller_owns_plot_transitions() -> void:
	_shape = "tool action rules"
	var tools: Tools = Tools.new()
	var grass: Dictionary = Farm.fresh_plot(0)
	var result := tools.apply_to_plot("shovel", grass)
	_ok(str(result.get("action", "")) == "till"
			and str(result.get("plot", {}).get("state", "")) == Farm.TILLED,
		"the shovel returns one turned-plot transition")
	_ok(str(grass.get("state", "")) == Farm.EMPTY,
		"turning preserves the caller's pre-action snapshot")
	var growing: Dictionary = Farm.fresh_plot(1)
	growing["state"] = Farm.GROWING
	_ok(tools.apply_to_plot("shovel", growing).is_empty(),
		"the shovel refuses a bed that is already in use")

	var tilled: Dictionary = Farm.fresh_plot(2)
	tilled["state"] = Farm.TILLED
	tilled["plant_cycle_id"] = 8
	result = tools.apply_to_plot("seed", tilled, 1234, "corn", 90, true)
	var planted: Dictionary = result.get("plot", {})
	_ok(str(result.get("action", "")) == "plant"
			and str(planted.get("crop_id", "")) == "corn"
			and str(planted.get("state", "")) == Farm.SEEDED
			and int(planted.get("plant_cycle_id", 0)) == 9
			and int(planted.get("growth_override_seconds", 0)) == 90
			and bool(planted.get("golden", false)),
		"planting keeps the lesson clock, golden choice, and cycle together")
	_ok(str(tilled.get("state", "")) == Farm.TILLED
			and str(tilled.get("crop_id", "")) == "",
		"planting preserves the turned-bed snapshot")
	_ok(tools.apply_to_plot("seed", tilled, 1234, "").is_empty(),
		"an empty seed selection is not recorded as a plot action")

	var thirsty: Dictionary = Farm.fresh_plot(3)
	thirsty["state"] = Farm.NEEDS_CARE
	thirsty["crop_id"] = "carrot"
	thirsty["care_event"] = Growth.CARE_THIRSTY
	thirsty["water_level"] = 0.2
	result = tools.apply_to_plot("water", thirsty, 5678)
	var watered: Dictionary = result.get("plot", {})
	_ok(str(result.get("action", "")) == "water"
			and str(watered.get("state", "")) == Farm.GROWING
			and str(watered.get("care_event", "")) == ""
			and float(watered.get("water_level", 0.0)) == 1.0
			and int(watered.get("last_updated_at", 0)) == 5678,
		"watering returns the shared, time-anchored care transition")

	var weeds: Dictionary = Farm.fresh_plot(4)
	weeds["state"] = Farm.NEEDS_CARE
	weeds["crop_id"] = "carrot"
	weeds["care_event"] = Growth.CARE_WEEDS
	result = tools.apply_to_plot("weed", weeds, 6789)
	_ok(str(result.get("action", "")) == "weed"
			and str(result.get("plot", {}).get("care_event", "")) == ""
			and bool(result.get("plot", {}).get("care_completed", false)),
		"the weed brush uses the same once-per-planting care transition")

	var bugs: Dictionary = Farm.fresh_plot(5)
	bugs["state"] = Farm.NEEDS_CARE
	bugs["crop_id"] = "carrot"
	bugs["care_event"] = Growth.CARE_BUG
	result = tools.apply_to_plot("bug", bugs, 7890)
	_ok(str(result.get("action", "")) == "shoo"
			and str(result.get("plot", {}).get("care_event", "")) == ""
			and bool(result.get("plot", {}).get("care_completed", false)),
		"the bug fan keeps its distinct shoo response")
	_ok(tools.apply_to_plot("water", weeds, 8000).is_empty()
			and str(weeds.get("care_event", "")) == Growth.CARE_WEEDS,
		"a mismatched brush cannot clear a different care job")

	var damaged: Dictionary = Farm.fresh_plot(0)
	damaged["state"] = Farm.NEEDS_CARE
	damaged["crop_id"] = "carrot"
	damaged["care_event"] = "unknown_old_job"
	result = tools.apply_to_plot(Tools.HAND, damaged, 9000)
	_ok(str(result.get("action", "")) == "repair"
			and str(result.get("plot", {}).get("state", "")) == Farm.GROWING
			and str(result.get("plot", {}).get("care_event", ""))
			== "unknown_old_job",
		"the hand retains the quiet recovery for an unfamiliar save marker")
	_ok(tools.apply_to_plot(Tools.HAND, Farm.fresh_plot(1)).is_empty(),
		"the hand does not invent work when a plot has nothing to do")
	var ripe: Dictionary = Farm.fresh_plot(2)
	ripe["state"] = Farm.READY
	ripe["crop_id"] = "carrot"
	_ok(tools.apply_to_plot("basket", ripe).is_empty()
			and str(ripe.get("state", "")) == Farm.READY,
		"harvest stays in the receipt-and-storage transaction boundary")


## The promise the whole opening view rests on.
##
## A child who walks in and cannot see his beds has to go looking, and a
## six-year-old who drags the ground the wrong way twice decides the game is
## broken. So this is not "most of them" and not "the camera is roughly right":
## every bed, whole, with a thumb's margin, on both shapes.
func _every_bed_is_on_the_glass_when_he_walks_in(view: Vector2) -> void:
	var beds := _plots().size()
	_ok(beds == Farm.PLOT_COUNT, "the farm has %d beds" % Farm.PLOT_COUNT)
	_ok(_world().bed_count() == beds, "and draws every one of them")
	var half: Vector2 = Layout.plot_box() * 0.5 * _camera().zoom
	for i in range(beds):
		var at: Vector2 = _garden.call("_bed_centre", i)
		_ok(at.x - half.x > Layout.EDGE
				and at.x + half.x < view.x - Layout.EDGE,
			"bed %d is fully on the glass, left to right" % i)
		_ok(at.y - half.y > 96.0 and at.y + half.y < view.y - 168.0,
			"bed %d is between the top bar and the shelf" % i)
	_ok(_camera().is_home(), "and that is the view he was given")
	await get_tree().process_frame


## The first picture is a farm, not a floating set of beds. The landmark must
## be complete on the glass rather than merely having its centre technically
## visible at an edge behind the HUD.
func _the_opening_view_keeps_a_complete_base_landmark() -> void:
	var landmark := Layout.facility(Layout.HOME_LANDMARK)
	_ok(not landmark.is_empty(), "the opening view has a stable base landmark")
	if landmark.is_empty():
		return
	var box := Layout.facility_size(landmark)
	var bounds := Rect2(Layout.facility_at(landmark) - box * 0.5, box)
	_ok(Layout.home_block(_plots().size()).encloses(bounds),
		"the opening composition includes the whole base landmark")
	for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y),
			bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		_ok(_camera().inside(_camera().world_to_screen(point)),
			"the complete base landmark stays on the farm glass")
	await get_tree().process_frame


## world_to_screen and screen_to_world are each other's opposite, at every zoom
## and after any pan. One pure function with a mistake in it would put every
## drop target, every pointing finger and both probes in the same wrong place,
## and they would all agree with each other.
func _the_two_coordinate_spaces_agree() -> void:
	for zoom in Layout.zoom_steps():
		_camera().zoom = float(zoom)
		_camera().centre = Vector2(900, 600)
		for point in [Vector2(0, 0), Vector2(470, 420), Vector2(1190, 780),
				Vector2(2200, 1150)]:
			var back: Vector2 = _camera().screen_to_world(
				_camera().world_to_screen(point))
			_ok(back.distance_to(point) < 0.5,
				"at zoom %s, %s survives the round trip" % [str(zoom), str(point)])
	_camera().go_home()
	_camera().apply(_world())
	await get_tree().process_frame


func _dragging_the_grass_moves_the_farm() -> void:
	var grass := _bare_grass()
	_ok(grass != Vector2.ZERO, "there is bare grass to drag")
	if grass == Vector2.ZERO:
		return
	var before: Vector2 = _camera().centre
	var bed_before: Vector2 = _garden.call("_bed_centre", 0)
	await _finger(grass, grass + Vector2(-220, 0))
	var after: Vector2 = _camera().centre
	_ok(after.x > before.x + 10.0,
		"dragging the grass to the left moves the farm to the right")
	var bed_after: Vector2 = _garden.call("_bed_centre", 0)
	_ok(bed_after.x < bed_before.x - 10.0,
		"and the beds move with it, on the glass")
	_world().go_home()
	await get_tree().process_frame


## A drag that STARTS on a bed still scrolls.
##
## Most of this farm is beds. If a press that began on one could not become a
## pan, then most of the screen would not scroll, and a child who happens to put
## his thumb down on a carrot and pull decides the farm does not move.
func _dragging_from_a_bed_moves_the_farm_too() -> void:
	var bed: Vector2 = _garden.call("_bed_centre", 0)
	var before: Vector2 = _camera().centre
	var state_before := str(_plots()[0].get("state", ""))
	await _finger(bed, bed + Vector2(0, -140))
	_ok(_camera().centre.y > before.y + 10.0,
		"a drag that starts on a bed scrolls the farm")
	_ok(str(_plots()[0].get("state", "")) == state_before,
		"and does NOT do the bed's job on the way past")
	_world().go_home()
	await get_tree().process_frame


## ...and a tap on a bed is still a tap. The other half of the same rule, and
## the half that breaks if the slop is set too small.
func _a_tap_is_not_a_drag() -> void:
	var before: Vector2 = _camera().centre
	var bed_index := -1
	for i in range(_plots().size()):
		if str(_plots()[i].get("state", "")) == Farm.EMPTY:
			bed_index = i
			break
	_ok(bed_index >= 0, "there is a patch of grass to turn over")
	if bed_index < 0:
		return
	await _tap(_garden.call("_bed_centre", bed_index))
	_ok(str(_plots()[bed_index].get("state", "")) == Farm.TILLED,
		"one tap on a bed turns it over")
	_ok(_camera().centre.distance_to(before) < 1.0,
		"and does not move the farm by a single pixel")

	# A wobble under the slop is still a tap. Six-year-olds do not press
	# cleanly, and a bed that only works for a perfectly still finger is a bed
	# that works for an adult testing it and for nobody else.
	var next := -1
	for i in range(_plots().size()):
		if str(_plots()[i].get("state", "")) == Farm.EMPTY:
			next = i
			break
	if next >= 0:
		var at: Vector2 = _garden.call("_bed_centre", next)
		await _finger(at, at + Vector2(9, 6), 2)
		_ok(str(_plots()[next].get("state", "")) == Farm.TILLED,
			"a press that wobbles a few pixels is still a press")
	await get_tree().process_frame


## He cannot drag the farm away and lose it.
##
## Four hard shoves, one per direction, each far enough to leave the world
## entirely if nothing stopped it. After all four, the camera is still inside
## its limits and there is still farm under the window.
func _he_cannot_drag_the_farm_away(view: Vector2) -> void:
	var grass := _bare_grass()
	if grass == Vector2.ZERO:
		return
	for push in [Vector2(-900, 0), Vector2(900, 0), Vector2(0, -700),
			Vector2(0, 700)]:
		for _repeat in range(3):
			await _finger(grass, grass + push, 4)
		var limits := Layout.centre_limits(_camera().window.size, _camera().zoom)
		var centre: Vector2 = _camera().centre
		_ok(centre.x >= limits.position.x - 0.5
				and centre.x <= limits.end.x + 0.5
				and centre.y >= limits.position.y - 0.5
				and centre.y <= limits.end.y + 0.5,
			"shoving %s cannot push the view outside the farm" % str(push))
		var corner: Vector2 = _camera().screen_to_world(
			_camera().window.get_center())
		_ok(corner.x >= 0.0 and corner.y >= 0.0
				and corner.x <= Layout.world_size().x
				and corner.y <= Layout.world_size().y,
			"and the middle of the window is still over the farm after %s"
				% str(push))
	_world().go_home()
	await get_tree().process_frame


## At EVERY zoom, two beds are further apart on the glass than DragField's snap.
##
## This is the rule that got harder when the farm started moving. SNAP is
## measured in screen pixels; the world distance between two beds is fixed; so
## the further out he zooms the closer they get, and a layout that is safe at
## full zoom can let a seed land in the wrong bed the moment he presses minus.
func _every_zoom_keeps_the_beds_far_enough_apart() -> void:
	var steps := Layout.zoom_steps()
	for zoom in steps:
		_camera().zoom = float(zoom)
		_camera().centre = Layout.default_centre(_plots().size())
		_camera().apply(_world())
		await get_tree().process_frame
		for a in range(_plots().size()):
			for b in range(a + 1, _plots().size()):
				var apart: float = (_garden.call("_bed_centre", a) as Vector2) \
					.distance_to(_garden.call("_bed_centre", b))
				_ok(apart > DragField.SNAP * 2.0,
					"at zoom %s, beds %d and %d are %.0fpx apart on the glass"
						% [str(zoom), a, b, apart])

	# And the buttons walk the whole range -- overview included -- both ways,
	# without falling off either end.
	var all: Array = _camera().all_steps()
	_world().go_home()
	var seen: Array = []
	for _up in range(6):
		seen.append(_camera().zoom)
		_world().zoom_by(1)
	_ok(is_equal_approx(_camera().zoom, float(all[all.size() - 1])),
		"pressing + repeatedly stops at the closest zoom")
	for _down in range(6):
		_world().zoom_by(-1)
	_ok(is_equal_approx(_camera().zoom, float(all[0])),
		"pressing - repeatedly stops at the furthest zoom")
	_ok(not _world().can_zoom(-1), "and says so, so the button can grey out")
	_world().go_home()
	await get_tree().process_frame


## The last press of minus shows the WHOLE farm -- and out there the rules
## change shape without changing meaning: beds stay a thumb apart for taps,
## and picking up a seed steps the camera back to a planting zoom before the
## drag exists, so the seed-spacing promises are never measured out here.
func _the_overview_shows_the_whole_farm() -> void:
	var all: Array = _camera().all_steps()
	_ok(float(all[0]) < Layout.min_zoom() - 0.004,
		"there is an overview step below the planting zooms")
	for _down in range(6):
		_world().zoom_by(-1)
	await get_tree().process_frame
	var world := Layout.world_size()
	for corner in [Vector2.ZERO, Vector2(world.x, 0), Vector2(0, world.y),
			world]:
		_ok(_camera().window.grow(2.0).has_point(
				_camera().world_to_screen(corner)),
			"the whole farm fits: corner %s is on the glass" % str(corner))
	var span: Vector2 = _camera().world_to_screen(world) \
		- _camera().world_to_screen(Vector2.ZERO)
	_ok(span.x <= _camera().window.size.x + 2.0
			and span.y <= _camera().window.size.y + 2.0,
		"...the drawn farm is no larger than the window it sits in")
	for a in range(_plots().size()):
		for b in range(a + 1, _plots().size()):
			var apart: float = _world().bed_screen_position(a) \
				.distance_to(_world().bed_screen_position(b))
			_ok(apart >= Layout.THUMB_APART,
				"at the overview, beds %d and %d still clear a thumb" % [a, b])

	# Pick a seed up from out here: the farm leans in BEFORE the drag is
	# anything, so no seed is ever in the air below min_zoom.
	_set_bed(1, {"state": Farm.TILLED})
	await _redraw()
	for _down in range(6):
		_world().zoom_by(-1)
	await get_tree().process_frame
	_ok(_camera().zoom < Layout.min_zoom(),
		"still at the overview after the redraw walked it back")
	var tile: Vector2 = _garden.call("_rack_tile_centre", 0)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(tile)
	Input.parse_input_event(down)
	await get_tree().process_frame
	var move := InputEventScreenDrag.new()
	move.index = 0
	move.position = _glass(tile + Vector2(0, -60))
	move.relative = _glass(tile + Vector2(0, -60)) - _glass(tile)
	Input.parse_input_event(move)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(_camera().zoom >= Layout.min_zoom() - 0.001,
		"a seed leaving the rack steps the farm in to a planting zoom")
	# Let go over nothing: the seed floats home, nothing is planted.
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(tile + Vector2(0, -60))
	Input.parse_input_event(up)
	await get_tree().process_frame
	_ok(str((_plots()[1] as Dictionary).get("state", "")) == Farm.TILLED,
		"...and a drop over nothing planted nothing")
	_world().go_home()
	await get_tree().process_frame


## Two taps on bare grass are the way back. The one gesture that has to work
## when a child is lost, so it is checked from somewhere he could actually get
## lost -- shoved to a corner and zoomed in.
func _two_taps_on_the_grass_bring_him_home() -> void:
	var grass := _bare_grass()
	if grass == Vector2.ZERO:
		return
	_world().zoom_by(1)
	await _finger(grass, grass + Vector2(-500, -300), 6)
	_ok(not _camera().is_home(), "he has moved away from the opening view")

	var lost := _bare_grass()
	if lost == Vector2.ZERO:
		lost = grass
	await _double_tap(lost)
	_ok(_camera().is_home(), "two taps on the grass put the view back")

	# And a double tap on a BED is not that gesture. He taps beds twice all the
	# time; yanking the camera home in the middle of it would be the farm
	# answering a question he did not ask.
	await _finger(grass, grass + Vector2(-300, 0), 6)
	var moved: Vector2 = _camera().centre
	var bed: Vector2 = _garden.call("_bed_centre", 0)
	await _double_tap(bed)
	_ok(_camera().centre.distance_to(moved) < 1.0,
		"but tapping a bed twice does not move the view")
	_world().go_home()
	await get_tree().process_frame


func _pressing_a_building_looks_at_it() -> void:
	for id in ["seed_shop", "market", "orders", "well"]:
		_world().go_home()
		await get_tree().process_frame
		var at: Vector2 = _world().facility_screen_position(id)
		if not _camera().inside(at):
			# Off the glass from the opening view -- which several of them are,
			# and on purpose. Walk over first, the way he would.
			_world().look_at_facility(id)
			await get_tree().process_frame
			at = _world().facility_screen_position(id)
		_ok(_world().facility_under(at) == id,
			"'%s' can be pressed where it is drawn" % id)
		await _tap(at)
		# Not "is the camera near it" -- near is impossible for a building by
		# the world's edge, where the clamp stops the centre short. The promise
		# is the visible one: after pressing it, it is on the glass.
		_ok(_camera().inside(_world().facility_screen_position(id)),
			"pressing '%s' brings it onto the glass" % id)
		# Every one of these doors opens a sheet now. Close it before walking
		# on, or its blocker eats the press on the next building.
		_garden.call("_close_panels")
		await get_tree().process_frame
		await get_tree().process_frame
	_world().go_home()
	await get_tree().process_frame


## The new world dressing is deliberately a picture of a farm, not another
## kind of thing a child has to avoid tapping. It must stay beneath every real
## facility, have no input-catching Controls, survive a building-only redraw,
## and leave a decorated patch of grass answerable as ordinary grass.
func _landmark_scenery_stays_passive() -> void:
	var ground: Node = _world().get("_ground")
	var scenery: Node = ground.get_node_or_null("LandmarkScenery")
	_ok(scenery is Node2D and bool(scenery.get_meta("input_passthrough", false)),
		"landmark scenery is a passive world node, not a new UI surface")
	_ok(_all_scenery_controls_ignore_input(scenery),
		"landmark scenery has no input-catching visual")

	var kept_id := scenery.get_instance_id() if scenery != null else 0
	_world().refresh_buildings()
	await get_tree().process_frame
	_ok(scenery != null and is_instance_valid(scenery)
			and scenery.get_instance_id() == kept_id,
		"redrawing facilities never removes or duplicates landmark scenery")

	# This little canopy sits in the established corridor between beds. It is
	# visible scenery but must still be unclaimed grass in the real hit path.
	var scenic_world := Vector2(1010.0, 602.0)
	_world().look_at_world(scenic_world)
	await get_tree().process_frame
	var scenic_glass := _camera().world_to_screen(scenic_world)
	_ok(_world().bed_under(scenic_glass) < 0
			and _world().facility_under(scenic_glass) == "",
		"a scenic canopy does not claim a plot or facility target")
	var heard := {"count": 0}
	var on_grass := func(_at: Vector2):
		heard["count"] = int(heard["count"]) + 1
	_world().grass_pressed.connect(on_grass)
	await _tap(scenic_glass)
	_world().grass_pressed.disconnect(on_grass)
	_ok(int(heard["count"]) == 1,
		"tapping visible scenery reaches the ordinary grass answer once")
	_world().go_home()
	await get_tree().process_frame


func _all_scenery_controls_ignore_input(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_scenery_controls_ignore_input(child):
			return false
	return true


## Furniture standing over the farm belongs to the GUI, and only to the GUI.
##
## Node._input runs before the GUI, so the farm hears every press on the zoom
## buttons and on the open order board too. Without the blocker list, a press
## on + is ALSO a tap on the ground under it, two presses are the go-home
## double tap, and a press on an order card is a tap on the bed behind the
## card. Each of those is the farm answering a question he did not ask.
func _the_furniture_is_not_a_hole_in_the_farm(view: Vector2) -> void:
	# A bed parked exactly under the + button, at the closest zoom -- where the
	# button is disabled, so the GUI ignores the press entirely and anything
	# that happens is the farm mishearing it. Two quick presses: the bed must
	# not be touched, and the pair must not read as the go-home double tap.
	var wc: Vector2 = _camera().window.get_center()
	var plus: Vector2 = ((_garden.get("_panel_buttons"))["zoom_in"] as Button) \
		.get_global_rect().get_center()
	_camera().zoom = float(Layout.zoom_steps().back())
	# The taller farm window can clamp an upper-row bed before it reaches the
	# button. Choose a live bed whose centre can actually get there while the
	# camera obeys its normal limits; do not move the world outside those limits.
	var parked_bed := -1
	for index in range(_plots().size()):
		_camera().centre = Layout.clamp_centre(
			Layout.plot_at(index) - (plus - wc) / _camera().zoom,
			_camera().window.size, _camera().zoom)
		if _camera().world_to_screen(Layout.plot_at(index)).distance_to(plus) <= 0.5:
			parked_bed = index
			break
	_camera().apply(_world())
	await get_tree().process_frame
	_ok(parked_bed >= 0 and _world().bed_under(plus) == parked_bed,
		"a bed can be parked under the + button")
	if parked_bed < 0:
		return
	var bed_state := str(_plots()[parked_bed].get("state", ""))
	var parked: Vector2 = _camera().centre
	await _double_tap(plus)
	_ok(str(_plots()[parked_bed].get("state", "")) == bed_state,
		"pressing the button does not reach the bed underneath it")
	_ok(_camera().centre.is_equal_approx(parked),
		"and two presses are not the go-home double tap")

	# A press on the shelf -- the seed rack, the barn -- is never the farm's.
	# The claimed-finger bug put the gate's hit box under the barn label, and
	# tapping the barn scrolled the farm to the gate.
	_world().go_home()
	await get_tree().process_frame
	var centre_before: Vector2 = _camera().centre
	await _tap(Vector2(view.x * 0.52, view.y - 60.0))
	await _tap(Vector2(view.x * 0.52, view.y - 60.0))
	_ok(_camera().centre == centre_before,
		"tapping the shelf never moves the farm")
	_ok(_camera().is_home(), "...or sends it anywhere at all")

	# The open order board covers a bed. Pressing where that bed is must do
	# nothing to it -- and the board's own X must still work, which is the
	# proof that the blockers keep the FARM out without keeping the GUI out.
	var orders_at := _world().facility_screen_position("orders")
	if not _camera().inside(orders_at):
		_world().look_at_facility("orders")
		await get_tree().process_frame
		orders_at = _world().facility_screen_position("orders")
	await _tap(orders_at)
	_ok(bool(_garden.get("_orders_open")), "the order board opens")

	# Bring the lower-row beds into the board area.  On a tall screen the world
	# clamp may stop a bed a little below the literal window centre, so find the
	# real bed that the existing GUI blocker covers instead of assuming a camera
	# centre the world is not allowed to reach.
	_camera().look_at(Layout.plot_at(4))
	_camera().apply(_world())
	await get_tree().process_frame
	var covered := -1
	var covered_at := Vector2.ZERO
	for i in range(_plots().size()):
		var candidate := _world().bed_screen_position(i)
		if _camera().inside(candidate) and bool(_world().call("_blocked", candidate)):
			covered = i
			covered_at = candidate
			break
	_ok(covered >= 0, "a bed is parked under the open board")
	if covered >= 0:
		var state := str(_plots()[covered].get("state", ""))
		var under_board: Vector2 = _camera().centre
		await _double_tap(covered_at)
		_ok(str(_plots()[covered].get("state", "")) == state,
			"pressing the board does not reach the bed behind it")
		_ok(_camera().centre.is_equal_approx(under_board),
			"nor does it count as taps on the grass")

	# The X still closes it: the GUI is blocked from nothing. Found by its
	# label, not by a copy of the sheet's arithmetic: the X moved off the
	# paper's corner on 2026-09-25 and the copy here aimed at the paper.
	var shut := _centre_of_button("X")
	_ok(shut != Vector2.ZERO, "the board has an X to press")
	await _tap(shut)
	await get_tree().process_frame
	_ok(not bool(_garden.get("_orders_open")),
		"and the board's own close button still works")
	_world().go_home()
	await get_tree().process_frame


## The invisible things a dropped seed clicks into have to follow the beds.
##
## They live on the glass, because DragField measures a release against a point
## on the glass. The beds live in the world. Those two agree only for as long as
## somebody keeps moving the targets -- and if nobody does, the seeds still land
## somewhere, just not where the beds are. Nothing about that looks wrong until
## a carrot appears in a bed he was not aiming at.
func _the_drop_targets_follow_the_beds() -> void:
	# Give him something to aim at: every bed turned and empty.
	for i in range(_plots().size()):
		_plots()[i]["state"] = Farm.TILLED
		_plots()[i]["crop_id"] = ""
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame

	var targets: Array = _garden.get("_drop_targets")
	_ok(targets.size() == _plots().size(),
		"every turned bed offers somewhere to drop a seed")
	for pair in targets:
		var node: Node2D = pair[1]
		_ok(node.position.distance_to(
			_garden.call("_bed_centre", int(pair[0]))) < 0.5,
			"bed %d's drop target sits on the bed" % int(pair[0]))

	var grass := _bare_grass()
	if grass != Vector2.ZERO:
		await _finger(grass, grass + Vector2(-180, -90), 6)
	for pair in targets:
		var node: Node2D = pair[1]
		_ok(node.position.distance_to(
			_garden.call("_bed_centre", int(pair[0]))) < 0.5,
			"and it is still on the bed after the farm has been dragged")
	_world().go_home()
	await get_tree().process_frame


## The regression this whole stage risks: pan, then plant.
##
## Everything about dropping a seed worked before the ground could move. This
## drags the farm sideways and then aims a seed at a bed from the rack, off
## centre, the way a thumb does -- and asks whether it landed in the bed he
## aimed at and in none of the others.
func _a_seed_still_lands_where_he_aimed_after_panning() -> void:
	for i in range(_plots().size()):
		_plots()[i]["state"] = Farm.TILLED
		_plots()[i]["crop_id"] = ""
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame

	# The pan is big on purpose: 260px is most of the gap between two beds on
	# the glass, so a drop matched against where the beds USED to be picks the
	# neighbour, while a drop matched against the target nodes themselves picks
	# the bed under his thumb. A smaller pan passes both ways and proves nothing.
	var grass := _bare_grass()
	if grass != Vector2.ZERO:
		await _finger(grass, grass + Vector2(-260, 10), 6)

	var target := 1
	var aim: Vector2 = (_garden.call("_bed_centre", target) as Vector2) \
		+ Vector2(34, -28)
	await _finger(_garden.call("_seed_rack_centre"), aim, 10)

	_ok(str(_plots()[target].get("crop_id", "")) == "carrot",
		"a seed dropped near a bed lands in it even after the farm has moved")
	for other in range(_plots().size()):
		if other == target:
			continue
		_ok(str(_plots()[other].get("crop_id", "")) == "",
			"and bed %d did not catch a seed aimed at bed %d" % [other, target])
	_world().go_home()
	await get_tree().process_frame


## While a seed is in the air the farm holds still.
##
## One finger cannot drag a carrot and the ground at once, so this can only
## happen if something else moves the camera mid-drag -- and if it does, the bed
## he is aiming at slides out from under the seed while he is looking at it. The
## four-bed garden already has the matching rule for rebuilds; this is the same
## rule for the camera, and it is enforced with one flag rather than by hoping.
func _the_farm_holds_still_while_a_seed_is_in_the_air() -> void:
	for i in range(_plots().size()):
		_plots()[i]["state"] = Farm.TILLED
		_plots()[i]["crop_id"] = ""
	SaveManager.save_game()
	_garden.call("_rebuild")
	await get_tree().process_frame

	var rack: Vector2 = _garden.call("_seed_rack_centre")
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(rack)
	Input.parse_input_event(down)
	await get_tree().process_frame

	_ok(bool(_world().locked), "picking a seed up holds the farm still")
	var before: Vector2 = _camera().centre
	for step in range(1, 6):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _glass(rack + Vector2(-60.0 * float(step), -40.0))
		drag.relative = _glass(Vector2(-60, 0))
		Input.parse_input_event(drag)
		await get_tree().process_frame
	_ok(_camera().centre.distance_to(before) < 1.0,
		"and dragging the seed does not scroll the farm underneath it")

	# A SECOND finger lands on the grass while the seed is in the air. That is
	# not an edge case, it is how a six-year-old holds a tablet -- the other
	# hand rests on the glass. One finger cannot pan and carry at once, so the
	# window check alone covers the carrying finger; only the lock covers this
	# one, and without it the farm pans while he is aiming, and the bed slides
	# out from under the seed.
	var thumb := _bare_grass()
	if thumb != Vector2.ZERO:
		var palm_down := InputEventScreenTouch.new()
		palm_down.index = 1
		palm_down.pressed = true
		palm_down.position = _glass(thumb)
		Input.parse_input_event(palm_down)
		await get_tree().process_frame
		for step in range(1, 6):
			var shove := InputEventScreenDrag.new()
			shove.index = 1
			shove.position = _glass(thumb + Vector2(-70.0 * float(step), 0.0))
			shove.relative = _glass(Vector2(-70, 0))
			Input.parse_input_event(shove)
			await get_tree().process_frame
		var palm_up := InputEventScreenTouch.new()
		palm_up.index = 1
		palm_up.pressed = false
		palm_up.position = _glass(thumb + Vector2(-350, 0))
		Input.parse_input_event(palm_up)
		await get_tree().process_frame
		_ok(_camera().centre.distance_to(before) < 1.0,
			"a second finger on the grass cannot pan the farm while a seed "
			+ "is in the air")

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(rack + Vector2(-300, -40))
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not bool(_world().locked), "letting go hands the farm back")
	await get_tree().process_frame


# --- 阶段 2: the tool rack and the brushes ---------------------------------

func _tools_state() -> Tools:
	return _garden.get("_tools")


func _buttons() -> Dictionary:
	return _garden.get("_tool_buttons")


func _tool_button(tool_id: String) -> Button:
	return _buttons().get(tool_id)


func _set_bed(index: int, fields: Dictionary) -> void:
	var plot: Dictionary = Farm.fresh_plot(index)
	for key in fields.keys():
		plot[key] = fields[key]
	_plots()[index] = plot


func _redraw() -> void:
	_garden.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var hit := _find_named(child, wanted)
		if hit != null:
			return hit
	return null


## A flight by node name: the live sprite's metas while it is on screen, else
## the receipt the garden kept of it (`harvest_flights`, the last eight).
func _flight_receipt(node_name: String) -> Dictionary:
	var live: Node = _find_named(_garden, node_name)
	if live != null:
		return {"node": node_name, "crop_id": str(live.get_meta("crop_id", "")),
			"amount": int(live.get_meta("amount", 0)),
			"destination": str(live.get_meta("destination", "")),
			"destination_at": live.get_meta("destination_at", Vector2.INF)}
	var flights: Array = _garden.get_meta("harvest_flights", [])
	for stamp in flights:
		if stamp is Dictionary and str((stamp as Dictionary).get("node", "")) == node_name:
			return stamp as Dictionary
	return {}


func _receipt_destination(stamp: Dictionary) -> Vector2:
	var destination: Variant = stamp.get("destination_at", Vector2.INF)
	if destination is Vector2:
		return destination as Vector2
	return Vector2.INF


## Scrub back and forth across one bed, in ONE stroke. What a child does when
## scrubbing is satisfying, which it is.
func _scrub(centre: Vector2, reach: float) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _glass(centre + Vector2(-reach, 0))
	Input.parse_input_event(down)
	await get_tree().process_frame
	var last := centre + Vector2(-reach, 0)
	for pass_end in [Vector2(reach, 0), Vector2(-reach, 0), Vector2(reach, 0)]:
		for step in range(1, 5):
			var at: Vector2 = last.lerp(centre + pass_end, float(step) / 4.0)
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = _glass(at)
			drag.relative = _glass(at) - _glass(last)
			Input.parse_input_event(drag)
			await get_tree().process_frame
		last = centre + pass_end
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _glass(last)
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


## Seven tools on the shelf, the hand first, and grey meaning exactly "no bed
## needs this today".
func _the_tool_rack_is_on_the_shelf(view: Vector2) -> void:
	_world().go_home()
	await _redraw()
	var buttons := _buttons()
	_ok(buttons.size() == Tools.TOOLS.size(),
		"all %d tools are on the shelf" % Tools.TOOLS.size())
	var ids: Array = buttons.keys()
	for i in range(mini(ids.size(), Tools.TOOLS.size())):
		_ok(str(ids[i]) == str(Tools.TOOLS[i].get("id", "")),
			"tool %d is '%s', in the rack's own order"
				% [i, str(Tools.TOOLS[i].get("id", ""))])
	_ok(str(ids[0]) == Tools.HAND, "and the hand comes first")
	for tool_id in ids:
		var button: Button = buttons[tool_id]
		_ok(button.position.y > view.y - 168.0 - 1.0
				and button.position.y + button.size.y < view.y,
			"'%s' sits on the shelf, not over the farm" % tool_id)
	_ok(_tools_state().selected == Tools.HAND,
		"he walks in holding the hand")

	# One bed of every kind of work: every tool has something to do.
	_set_bed(0, {})
	_set_bed(1, {"state": Farm.TILLED})
	_set_bed(2, {"state": Farm.NEEDS_CARE, "crop_id": "carrot",
		"growth_stage": 1, "care_event": Growth.CARE_THIRSTY, "water_level": 0.0})
	_set_bed(3, {"state": Farm.NEEDS_CARE, "crop_id": "corn",
		"growth_stage": 2, "care_event": Growth.CARE_WEEDS})
	_set_bed(4, {"state": Farm.NEEDS_CARE, "crop_id": "tomato",
		"growth_stage": 2, "care_event": Growth.CARE_BUG})
	_set_bed(5, {"state": Farm.READY, "crop_id": "carrot", "growth_stage": 4,
		"plant_cycle_id": 3})
	await _redraw()
	for tool_id in _buttons().keys():
		_ok(not (_tool_button(tool_id) as Button).disabled,
			"with one of everything to do, '%s' is awake" % tool_id)

	# Nothing to do at all: every brush greys, the hand never does.
	for i in range(6):
		_set_bed(i, {"state": Farm.GROWING, "crop_id": "carrot",
			"growth_stage": 1})
	await _redraw()
	for tool_id in _buttons().keys():
		if tool_id == Tools.HAND:
			_ok(not (_tool_button(tool_id) as Button).disabled,
				"the hand can never be taken away")
		else:
			_ok((_tool_button(tool_id) as Button).disabled,
				"'%s' greys out when no bed needs it" % tool_id)


func _a_grey_tool_stays_out_of_his_hand() -> void:
	# Everything is growing; the watering can is grey. Pressing it changes
	# nothing -- not the selection, not the arming.
	await _tap((_tool_button("water") as Button).position + Vector2(48, 38))
	_ok(_tools_state().selected == Tools.HAND,
		"pressing a grey tool leaves the hand in his hand")
	_ok(not _world().brush_armed, "and arms nothing")


func _the_shovel_sweeps_a_row() -> void:
	for i in [0, 1, 2]:
		_set_bed(i, {})
	for i in [3, 4, 5]:
		_set_bed(i, {"state": Farm.GROWING, "crop_id": "corn",
			"growth_stage": 1, "growth_progress": 0.4})
	await _redraw()

	await _tap((_tool_button("shovel") as Button).position + Vector2(48, 38))
	_ok(_tools_state().selected == "shovel", "the shovel can be picked up")
	_ok(_world().brush_armed, "and picking it up arms the brush")

	var before: Vector2 = _camera().centre
	await _finger(_garden.call("_bed_centre", 0),
		_garden.call("_bed_centre", 2), 12)
	_ok(_camera().centre.distance_to(before) < 1.0,
		"a stroke across three beds does not move the farm at all")
	for i in [0, 1, 2]:
		_ok(str(_plots()[i].get("state", "")) == Farm.TILLED,
			"bed %d was turned by the sweep" % i)
	# Beds 4-6 are growing, so the sweep turned the last EMPTY earth there
	# was -- and a tool with no work left does not stay in a child's hand.
	_ok(_tools_state().selected == Tools.HAND,
		"with nothing left anywhere to turn, the shovel hands back the hand")


func _the_brush_skips_beds_that_do_not_need_it() -> void:
	_set_bed(3, {})
	_set_bed(4, {"state": Farm.GROWING, "crop_id": "corn", "growth_stage": 1,
		"growth_progress": 0.4})
	_set_bed(5, {})
	await _redraw()
	if _tools_state().selected != "shovel":
		await _tap((_tool_button("shovel") as Button).position + Vector2(48, 38))
	var untouched := JSON.stringify(_plots()[4])

	await _finger(_garden.call("_bed_centre", 3),
		_garden.call("_bed_centre", 5), 12)
	_ok(str(_plots()[3].get("state", "")) == Farm.TILLED, "bed 4 was turned")
	_ok(str(_plots()[5].get("state", "")) == Farm.TILLED, "bed 6 was turned")
	_ok(JSON.stringify(_plots()[4]) == untouched,
		"and the growing bed between them was not touched by a single field")


## The money question. Scrubbing back and forth across a ripe bed in one
## stroke -- which a child will absolutely do -- harvests it ONCE: the barn
## gains exactly one yield, and the ledger holds exactly one transaction.
func _one_stroke_never_pays_twice() -> void:
	for i in range(6):
		_set_bed(i, {"state": Farm.TILLED})
	_set_bed(1, {"state": Farm.READY, "crop_id": "strawberry",
		"growth_stage": 4, "plant_cycle_id": 9})
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.data["farm"]["harvest_basket"] = {}
	SaveManager.data["farm"]["paid_harvests"] = []
	await _redraw()

	await _tap((_tool_button("basket") as Button).position + Vector2(48, 38))
	_ok(_tools_state().selected == "basket", "the basket can be picked up")
	if _garden.has_meta("last_harvest_flight"):
		_garden.remove_meta("last_harvest_flight")
	await _scrub(_garden.call("_bed_centre", 1), 70.0)

	var yield_count := maxi(int(GameData.get_crop("strawberry")
		.get("harvest_amount", 1)), 1)
	# The stroke itself is sixteen frames; under a slow software-GL window
	# that outlives the 0.4 s sprite. The screen keeps a receipt of the last
	# flight, so the question is answered either by the sprite or its stamp.
	var flight: Node = _find_named(_garden, "HarvestFlight_strawberry")
	var stamp: Dictionary = _garden.get_meta("last_harvest_flight", {})
	var flight_crop := str(flight.get_meta("crop_id", "")) if flight != null \
		else str(stamp.get("crop_id", ""))
	var flight_amount := int(flight.get_meta("amount", 0)) if flight != null \
		else int(stamp.get("amount", 0))
	_ok(flight != null or str(stamp.get("node", "")) == "HarvestFlight_strawberry",
		"brush harvesting keeps the strawberry visible while it flies")
	_ok(flight_crop == "strawberry",
		"the brush flight keeps the crop after the bed resets")
	_ok(flight_amount == yield_count,
		"the brush flight keeps the crop's real harvest amount")
	await _capture_probe_screen("harvest_feedback")
	var yield_label: Node = _find_named(_garden, "HarvestYield")
	_ok(yield_label is Label and str((yield_label as Label).text) == "x%d" % yield_count,
		"a brush harvest says the real yield, not one picked bed")
	_ok(Barn.count("strawberry") == yield_count,
		"three passes of one stroke fill the barn exactly once (%d, not %d)"
			% [yield_count, Barn.count("strawberry")])
	var paid: Array = SaveManager.data["farm"]["paid_harvests"]
	_ok(paid.count("farm_harvest_plot_2_9") == 1,
		"and the ledger holds the transaction exactly once")
	_ok(str(_plots()[1].get("state", "")) == Farm.TILLED,
		"the bed is turned earth again")
	_ok(_tools_state().selected == Tools.HAND,
		"the basket had nothing left to pick, so the hand came back on its own")

	# It survives the disk too.
	SaveManager.load_game()
	_ok(Barn.count("strawberry") == yield_count,
		"the one payment is what got written down")


## A real brush can collect more than one crop before the shelf redraws. When
## the barn is full, the first receipt must not fly to the old position of a
## pile that the second crop will extend. Both receipts belong to the one fixed
## basket rim the child sees after lifting his finger.
func _one_brush_stroke_keeps_every_spill_on_the_same_basket_rim() -> void:
	# The preceding scrub's normal flight is deliberately still visible for a
	# moment. Let it finish before testing that a FULL barn creates no normal
	# flights of its own.
	await get_tree().create_timer(0.5).timeout
	for i in range(6):
		_set_bed(i, {"state": Farm.TILLED})
	_set_bed(0, {"state": Farm.READY, "crop_id": "carrot",
		"growth_stage": 4, "plant_cycle_id": 61})
	_set_bed(1, {"state": Farm.READY, "crop_id": "strawberry",
		"growth_stage": 4, "plant_cycle_id": 62})
	SaveManager.data["farm"]["warehouse"] = {"corn": Barn.cap()}
	SaveManager.data["farm"]["harvest_basket"] = {}
	SaveManager.data["farm"]["paid_harvests"] = []
	# This test is about the two physical receipts, not the separate one-time
	# market lesson that a full barn normally offers.
	SaveManager.data["farm"]["market_taught"] = true
	_world().go_home()
	await _redraw()

	await _tap((_tool_button("basket") as Button).position + Vector2(48, 38))
	_ok(_tools_state().selected == "basket",
		"the full-barn basket brush is genuinely in the child's hand")
	# Two moves keep both 0 and 1 inside one real touch stroke. The carrot
	# flies on the first move and the strawberry on the last; under a slow
	# software-GL window the first 0.4 s sprite is gone before the stroke
	# ends, so each flight is read from the screen's receipt list, which
	# the live sprite only confirms.
	if _garden.has_meta("harvest_flights"):
		_garden.remove_meta("harvest_flights")
	await _finger(_garden.call("_bed_centre", 0),
		_garden.call("_bed_centre", 1), 2)

	var carrot_flight := _flight_receipt("HarvestSpillFlight_carrot")
	var strawberry_flight := _flight_receipt("HarvestSpillFlight_strawberry")
	var accidental_carrot := _flight_receipt("HarvestFlight_carrot")
	var accidental_strawberry := _flight_receipt("HarvestFlight_strawberry")
	_ok(not carrot_flight.is_empty() and not strawberry_flight.is_empty()
		and accidental_carrot.is_empty() and accidental_strawberry.is_empty(),
		"one full-barn brush makes two overflow receipts and no lying barn receipts")

	var carrot_yield := maxi(int(GameData.get_crop("carrot")
		.get("harvest_amount", 1)), 1)
	var strawberry_yield := maxi(int(GameData.get_crop("strawberry")
		.get("harvest_amount", 1)), 1)
	_ok(str(carrot_flight.get("crop_id", "")) == "carrot"
		and int(carrot_flight.get("amount", 0)) == carrot_yield
		and str(carrot_flight.get("destination", "")) == "harvest_basket",
		"the carrot receipt keeps its real crop, full yield, and overflow destination")
	_ok(str(strawberry_flight.get("crop_id", "")) == "strawberry"
		and int(strawberry_flight.get("amount", 0)) == strawberry_yield
		and str(strawberry_flight.get("destination", "")) == "harvest_basket",
		"the strawberry receipt keeps its real crop, full yield, and overflow destination")

	var carrot_landing := _receipt_destination(carrot_flight)
	var strawberry_landing := _receipt_destination(strawberry_flight)
	_ok(carrot_landing != Vector2.INF and strawberry_landing != Vector2.INF
		and carrot_landing.distance_to(strawberry_landing) < 0.5,
		"both crops from one stroke fly to the same fixed overflow basket rim")

	# `_queue_rebuild()` waits until the finger lifts. Two frames make this an
	# assertion about the actual rebuilt picture, rather than two agreeing
	# metadata values that could both point to the wrong place.
	await get_tree().process_frame
	await get_tree().process_frame
	var overflow: Node = _find_named(_garden, "HarvestOverflowBasket")
	var visible_rim := Vector2.INF
	if overflow is Control:
		# UiKit's basket is 30px wide and six pixels above the shelf.
		visible_rim = (overflow as Control).position + Vector2(15.0, 15.0)
	_ok(visible_rim != Vector2.INF
		and visible_rim.distance_to(carrot_landing) < 0.5
		and visible_rim.distance_to(strawberry_landing) < 0.5,
		"the rebuilt basket's visible centre is where both flights were headed")
	_ok(overflow != null and int(overflow.get_meta("crop_kinds", 0)) == 2,
		"the one rebuilt overflow basket displays both crop kinds")
	_ok(Barn.count("carrot", Barn.BASKET) == carrot_yield
		and Barn.count("strawberry", Barn.BASKET) == strawberry_yield
		and Barn.total(Barn.WAREHOUSE) == Barn.cap(),
		"both whole harvests wait in the basket while the full warehouse stays full")
	_ok(str(_plots()[0].get("state", "")) == Farm.TILLED
		and str(_plots()[1].get("state", "")) == Farm.TILLED,
		"both neighbouring ready beds were really collected by that one brush")

	await get_tree().create_timer(0.5).timeout
	_ok(_find_named(_garden, "HarvestSpillFlight_carrot") == null
		and _find_named(_garden, "HarvestSpillFlight_strawberry") == null,
		"the two full-barn receipts clean themselves up after their answer")
	# Later regressions deliberately reload and settle the farm. Leave them a
	# neutral store rather than smuggling this full-barn fixture into their setup.
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.data["farm"]["harvest_basket"] = {}
	SaveManager.save_game()


func _the_last_job_hands_back_the_hand() -> void:
	for i in range(6):
		_set_bed(i, {"state": Farm.GROWING, "crop_id": "carrot",
			"growth_stage": 1})
	for i in [2, 4]:
		_set_bed(i, {"state": Farm.NEEDS_CARE, "crop_id": "carrot",
			"growth_stage": 1, "care_event": Growth.CARE_THIRSTY,
			"water_level": 0.0})
	await _redraw()

	await _tap((_tool_button("water") as Button).position + Vector2(48, 38))
	_ok(_tools_state().selected == "water", "the can can be picked up")
	await _finger(_garden.call("_bed_centre", 2),
		_garden.call("_bed_centre", 4), 14)
	for i in [2, 4]:
		_ok(str(_plots()[i].get("care_event", "")) == "",
			"bed %d got its drink" % i)
		_ok(float(_plots()[i].get("water_level", 0.0)) > 0.99,
			"...a full one")
	_ok(_tools_state().selected == Tools.HAND,
		"watering the last thirsty bed hands him back the hand")
	_ok(not _world().brush_armed, "and disarms the brush")
	_ok((_tool_button("water") as Button).disabled,
		"and the can greys out, because there is nothing left for it")


func _the_seed_brush_plants_what_he_chose() -> void:
	for i in range(6):
		_set_bed(i, {"state": Farm.GROWING, "crop_id": "carrot",
			"growth_stage": 1})
	for i in [0, 1, 2]:
		_set_bed(i, {"state": Farm.TILLED, "plant_cycle_id": 5})
	await _redraw()

	# Tapping the strawberry tile IS choosing: it arms the seed brush with that
	# crop in one move. No separate "now pick a crop" step to teach.
	await _tap(_garden.call("_rack_tile_centre", 2))
	_ok(_tools_state().selected == "seed",
		"tapping a seed tile arms the seed brush")
	_ok(_tools_state().seed_crop == "strawberry",
		"...loaded with the crop he tapped")

	await _finger(_garden.call("_bed_centre", 0),
		_garden.call("_bed_centre", 1), 12)
	for i in [0, 1]:
		_ok(str(_plots()[i].get("crop_id", "")) == "strawberry",
			"bed %d got the strawberry he chose" % i)
		_ok(str(_plots()[i].get("state", "")) == Farm.SEEDED,
			"...as a seed in the ground")
		_ok(int(_plots()[i].get("plant_cycle_id", 0)) == 6,
			"...and a NEW planting cycle, so its harvest can be paid")

	# Sweeping back over a bed that is already planted plants nothing more.
	var again := JSON.stringify(_plots()[0])
	await _finger(_garden.call("_bed_centre", 1),
		_garden.call("_bed_centre", 0), 12)
	_ok(JSON.stringify(_plots()[0]) == again,
		"sweeping back over a planted bed changes nothing")
	await _tap((_tool_button(Tools.HAND) as Button).position + Vector2(48, 38))
	_ok(_tools_state().selected == Tools.HAND, "and he can put the hand back")

	# A damaged or migrating save may have no unlocked crop even though the
	# eligibility table sees a tilled bed. That is an attempt, not work: it must
	# not claim a commit or schedule a redraw.
	var unlocked_value: Variant = SaveManager.data["farm"].get("unlocked_crops", [])
	var old_unlocked: Array = unlocked_value.duplicate() if unlocked_value is Array else []
	SaveManager.data["farm"]["unlocked_crops"] = []
	_set_bed(2, {"state": Farm.TILLED, "plant_cycle_id": 7})
	await _redraw()
	_tools_state().selected = "seed"
	_world().brush_armed = true
	_garden.set("_rebuild_queued", false)
	var stroke: Stroke = _garden.get("_stroke")
	stroke.begin()
	var before: Dictionary = _plots()[2].duplicate(true)
	_garden.call("_on_stroke_swept", 2)
	var completion: Dictionary = stroke.finish()
	_ok(stroke.applied == 0 and not bool(completion.get("did_work", true)),
		"an empty seed choice does not report a successful brush commit")
	_ok(_plots()[2] == before,
		"the failed seed attempt leaves the turned bed untouched")
	_ok(not bool(_garden.get("_rebuild_queued")),
		"a no-op seed stroke does not schedule a farm redraw")
	SaveManager.data["farm"]["unlocked_crops"] = old_unlocked
	_tools_state().selected = Tools.HAND
	_world().brush_armed = false
	await _redraw()


func _grass_pans_and_buildings_answer_with_a_tool_in_hand() -> void:
	_set_bed(5, {})
	await _redraw()
	if _tools_state().selected != "shovel":
		await _tap((_tool_button("shovel") as Button).position + Vector2(48, 38))

	var grass := _bare_grass()
	_ok(grass != Vector2.ZERO, "there is still grass with a tool in hand")
	var before: Vector2 = _camera().centre
	if grass != Vector2.ZERO:
		await _finger(grass, grass + Vector2(-200, 0), 8)
		_ok(_camera().centre.x > before.x + 10.0,
			"dragging the grass still pans, whatever is in his hand")
	_world().go_home()
	await get_tree().process_frame

	# And a building still answers a tap: the tools are for beds, not doors.
	var at: Vector2 = _world().facility_screen_position("warehouse")
	if not _camera().inside(at):
		_world().look_at_facility("warehouse")
		await get_tree().process_frame
		at = _world().facility_screen_position("warehouse")
	await _tap(at)
	_ok(_camera().inside(_world().facility_screen_position("warehouse")),
		"a building still answers a press with a tool in hand")
	# The barn's door opens now (阶段 3), and an open sheet blocks whatever the
	# next test presses. Shut it behind us like everything else.
	await _shut_panels()
	await _tap((_tool_button(Tools.HAND) as Button).position + Vector2(48, 38))
	_world().go_home()
	await get_tree().process_frame


## The parent dial moves the edge of a bed, a little.
func _a_gentle_hand_gets_a_bigger_bed() -> void:
	_set_bed(0, {})
	await _redraw()
	var half_x: float = Layout.plot_box().x * 0.5 * _camera().zoom
	var beside: Vector2 = (_garden.call("_bed_centre", 0) as Vector2) \
		+ Vector2(half_x * 1.08, 0)

	# A press just off the edge: an ordinary hand misses it...
	await _tap(beside)
	_ok(str(_plots()[0].get("state", "")) == Farm.EMPTY,
		"an ordinary hand misses a press just past the bed's edge")

	# ...a gentle hand is forgiven it...
	SaveManager.set_setting("difficulty", 0)
	await _tap(beside)
	_ok(str(_plots()[0].get("state", "")) == Farm.TILLED,
		"the gentle setting forgives the same press")

	# ...and a brave hand has to be a little truer than an ordinary one.
	_set_bed(1, {})
	await _redraw()
	var near_edge: Vector2 = (_garden.call("_bed_centre", 1) as Vector2) \
		+ Vector2(half_x * 0.95, 0)
	SaveManager.set_setting("difficulty", 2)
	await _tap(near_edge)
	_ok(str(_plots()[1].get("state", "")) == Farm.EMPTY,
		"the brave setting asks for slightly truer aim")
	SaveManager.set_setting("difficulty", 1)
	await _tap(near_edge)
	_ok(str(_plots()[1].get("state", "")) == Farm.TILLED,
		"which the ordinary setting accepts")
	SaveManager.set_setting("difficulty", 1)


# --- 阶段 3: the shop, the market box, and the barn's roof ------------------

## Walk to a building and press it, the way a thumb does.
func _walk_and_tap(id: String) -> void:
	var at: Vector2 = _world().facility_screen_position(id)
	if not _camera().inside(at):
		_world().look_at_facility(id)
		await get_tree().process_frame
		at = _world().facility_screen_position(id)
	await _tap(at)


func _shut_panels() -> void:
	_garden.call("_close_panels")
	await get_tree().process_frame
	await get_tree().process_frame


## The red line, driven with a thumb: three numbers on the row, a confirm
## card before a single coin moves, a regret window that gives it all back,
## and no way to pay twice however the buttons are mashed.
func _the_shop_asks_before_it_takes(view: Vector2) -> void:
	SaveManager.set_setting("difficulty", 1)
	SaveManager.data["rewards"]["coins"] = 100
	SaveManager.save_game()
	_world().go_home()
	await _shut_panels()

	await _walk_and_tap("seed_shop")
	_ok(bool(_garden.get("_shop_open")), "pressing the shop opens the shop")
	var buttons: Dictionary = _garden.get("_panel_buttons")
	_ok(buttons.has("buy_potato"), "the potato row offers a buy button")
	_ok(not buttons.has("buy_carrot"),
		"the carrot row does not -- it is already his")

	# Pressing 买 does NOT buy: it asks.
	await _tap((buttons["buy_potato"] as Button).position + Vector2(75, 26))
	_ok(Coins.balance() == 100, "pressing the row's button moves no money")
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.has("confirm_buy"), "it opens the confirm card instead")

	# 算了 walks away whole.
	await _tap((buttons["cancel_buy"] as Button).position + Vector2(80, 30))
	_ok(Coins.balance() == 100, "'not now' costs nothing")
	_ok(not SaveManager.data["farm"]["unlocked_crops"].has("potato"),
		"...and hands nothing over")

	# Buy it for real.
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["buy_potato"] as Button).position + Vector2(75, 26))
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["confirm_buy"] as Button).position + Vector2(80, 30))
	_ok(Coins.balance() == 60, "confirming pays exactly the price")
	_ok(SaveManager.data["farm"]["unlocked_crops"].has("potato"),
		"and the potato joins the rack")
	buttons = _garden.get("_panel_buttons")
	_ok(not buttons.has("buy_potato"),
		"the row now says his, so there is nothing left to press twice")

	# The regret window gives the whole price back.
	_ok(buttons.has("undo"), "the regret window is open")
	await _tap((buttons["undo"] as Button).position + Vector2(80, 24))
	_ok(Coins.balance() == 100, "'put it back' returns every coin")
	_ok(not SaveManager.data["farm"]["unlocked_crops"].has("potato"),
		"...and takes the potato off the rack")

	# Buy again and let the window LAPSE: the offer goes away, the potato stays.
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["buy_potato"] as Button).position + Vector2(75, 26))
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["confirm_buy"] as Button).position + Vector2(80, 30))
	GameClock.set_test_now(NOON, 20000)
	_garden.call("_rebuild")
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	_ok(not buttons.has("undo"), "the regret window closes on its own")
	_ok(SaveManager.data["farm"]["unlocked_crops"].has("potato"),
		"...and what he bought is still his")
	GameClock.set_test_now(NOON, 0)

	# Too poor: the row shows how far he has to go, and offers no button.
	SaveManager.data["rewards"]["coins"] = 3
	_garden.call("_rebuild")
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	_ok(not buttons.has("buy_lettuce"),
		"a price he cannot pay is not a button he can press")
	_ok(Coins.balance() == 3, "and looking at it costs nothing")
	await _shut_panels()


func _the_market_box_sells_the_pile_he_dragged(view: Vector2) -> void:
	SaveManager.data["rewards"]["coins"] = 0
	SaveManager.data["farm"]["warehouse"] = {}
	SaveManager.data["farm"]["harvest_basket"] = {}
	Barn.put("carrot", 6)
	SaveManager.save_game()
	await _shut_panels()

	await _walk_and_tap("market")
	_ok(bool(_garden.get("_market_open")), "pressing the box opens the market")

	# Drag the carrot pile into the box. The chip sits where the panel drew
	# it; the box is on the panel's right.
	var origin := Vector2(view.x * 0.5 - 390.0, 96.0 + 16.0)
	var chip := origin + Vector2(46, 96)
	var box := origin + Vector2(780.0 - 190.0, 200.0)
	await _finger(chip, box, 10)

	var worth := 6 * GameData.market_price("carrot")
	var total: Label = _garden.get("_market_total")
	_ok(total != null and int(total.text) == worth,
		"the total shows what the pile is worth before anything moves")
	_ok(Barn.count("carrot") == 6,
		"and nothing has left the barn yet")

	# Another device can change the shelf after this receipt was drawn. Refuse
	# without consuming the remaining five carrots or losing the editable pile.
	var farm: Dictionary = SaveManager.data["farm"]
	Barn.take("carrot", 1)
	SaveManager.save_game()
	var buttons: Dictionary = _garden.get("_panel_buttons")
	await _tap((buttons["sell"] as Button).position + Vector2(90, 31))
	_ok(Coins.balance() == 0 and Barn.count("carrot") == 5,
		"a stale receipt refuses before taking the crops that remain")
	var pending: Dictionary = _garden.get("_market_sell")
	_ok(int(pending.get("carrot", 0)) == 6
		and int(farm.get("sale_receipt_id", 0)) == 0
		and (farm.get("paid_sales", []) as Array).is_empty(),
		"the refused sale stays editable and does not spend its receipt id")
	Barn.put("carrot", 1)
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["sell"] as Button).position + Vector2(90, 31))
	_ok(Coins.balance() == worth, "selling pays exactly the shown total")
	_ok(Barn.count("carrot") == 0, "and the carrots leave the barn")

	# Mash it: the box is empty now, so nothing more can ever come out of it.
	buttons = _garden.get("_panel_buttons")
	if buttons.has("sell"):
		await _tap((buttons["sell"] as Button).position + Vector2(90, 31))
		await _tap((buttons["sell"] as Button).position + Vector2(90, 31))
	_ok(Coins.balance() == worth, "pressing 卖掉 again pays nothing")

	# Dragging in and walking away sells nothing and loses nothing.
	Barn.put("tomato", 3)
	_garden.call("_rebuild")
	await get_tree().process_frame
	await _finger(origin + Vector2(46, 96), box, 10)
	await _shut_panels()
	_ok(Barn.count("tomato") == 3,
		"closing the box gives back everything that was only ever IN it")
	_ok(Coins.balance() == worth, "...and pays nothing for the visit")


func _the_barn_roof_is_bought_once(view: Vector2) -> void:
	SaveManager.data["rewards"]["coins"] = 100
	SaveManager.data["farm"]["warehouse_cap"] = Farm.WAREHOUSE_START
	SaveManager.data["inventory"] = {"plank": 3}
	SaveManager.save_game()
	await _shut_panels()

	await _walk_and_tap("warehouse")
	_ok(bool(_garden.get("_barn_open")), "pressing the barn opens the barn")
	var buttons: Dictionary = _garden.get("_panel_buttons")
	_ok(buttons.has("upgrade"), "with the planks and the coins, 升级 is awake")
	_ok(not (buttons["upgrade"] as Button).disabled, "...and pressable")

	# It asks first, like everything that spends.
	await _tap((buttons["upgrade"] as Button).position + Vector2(100, 29))
	_ok(Barn.cap() == Farm.WAREHOUSE_START,
		"pressing 升级 spends nothing yet")
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.has("confirm_upgrade"), "it asks first")
	await _tap((buttons["confirm_upgrade"] as Button).position + Vector2(90, 30))
	_ok(Barn.cap() == Farm.WAREHOUSE_UPGRADED, "confirming raises the roof")
	_ok(Coins.balance() == 100 - 60, "...for exactly sixty coins")
	_ok(Barn.count("plank", "inventory") == 0, "...and the three planks")

	# There is no second roof.
	buttons = _garden.get("_panel_buttons")
	_ok(not buttons.has("upgrade"),
		"a raised roof offers no second upgrade to press")

	# The regret window returns all of it.
	_ok(buttons.has("undo"), "the regret window is open")
	await _tap((buttons["undo"] as Button).position + Vector2(80, 24))
	_ok(Barn.cap() == Farm.WAREHOUSE_START, "'put it back' lowers the roof")
	_ok(Coins.balance() == 100, "...returns the coins")
	_ok(Barn.count("plank", "inventory") == 3, "...and the planks")

	# Two planks are not three: the button waits, and takes nothing.
	Barn.take("plank", 1, "inventory")
	_garden.call("_rebuild")
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.has("upgrade") and (buttons["upgrade"] as Button).disabled,
		"two planks leave 升级 visible but asleep")

	# Raise it for real again, then attack the purchase from BEHIND the panel.
	# The panel hides the button once the roof is up -- but the panel is
	# braces, and the guard inside _upgrade_confirmed is the belt. Today the
	# belt is also masked by a coincidence: the three friends leave exactly
	# three planks per save, so after one upgrade there are never planks for a
	# second. A rule that only holds because of the order data is not a rule,
	# so hand it planks and coins and call the confirm directly: it must find
	# the roof already raised and take NOTHING.
	Barn.put("plank", 1, "inventory")
	_garden.call("_rebuild")
	await get_tree().process_frame
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["upgrade"] as Button).position + Vector2(100, 29))
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["confirm_upgrade"] as Button).position + Vector2(90, 30))
	_ok(Barn.cap() == Farm.WAREHOUSE_UPGRADED, "the roof is up again")
	SaveManager.data["rewards"]["coins"] = 100
	SaveManager.data["inventory"] = {"plank": 3}
	_garden.call("_upgrade_confirmed")
	await get_tree().process_frame
	_ok(Coins.balance() == 100,
		"a stray confirm against a raised roof takes no coins")
	_ok(Barn.count("plank", "inventory") == 3, "...and no planks")
	await _shut_panels()


# --- 阶段 4: the bear's door, the visitor board, and the dog ---------------

## The bear's door is not on a new child's farm at all -- and appears the
## moment the first harvest is paid, mid-visit, through refresh() alone,
## because that is the moment the game actually has when it happens.
##
## BOTH sides are asked, because they are decided in two places: what a tap
## finds (facility_under recomputes from the save) and what is DRAWN (the
## huts under _buildings only change when somebody redraws them). The first
## cut of this section asked only the tap side, and removing the mid-visit
## redraw entirely still passed -- an invisible door a tap could open.
func _the_bear_door_waits_for_the_first_harvest() -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	var kept_paid: Array = farm.get("paid_harvests", [])
	var kept_friends: Dictionary = farm.get("npc_friendship", {})
	var town := Layout.facilities().size()
	farm["paid_harvests"] = []
	farm["npc_friendship"] = {}
	_world().refresh(_plots())
	await get_tree().process_frame
	_world().look_at_facility("bear_door")
	await get_tree().process_frame
	var at: Vector2 = _world().facility_screen_position("bear_door")
	_ok(_world().facility_under(at) != "bear_door",
		"before the first paid harvest there is no bear door -- "
		+ "not locked, not grey, not there")
	_ok(_huts_drawn() == town - 1,
		"...and it is not drawn either: %d buildings stand, not %d"
		% [town - 1, town])
	farm["paid_harvests"] = ["farm_harvest_plot_0_1"]
	_world().refresh(_plots())
	await get_tree().process_frame
	_ok(_world().facility_under(at) == "bear_door",
		"the first paid harvest opens the bear's door mid-visit, "
		+ "no rebuild, no camera jump")
	_ok(_huts_drawn() == town,
		"...and the door is actually DRAWN, not just tappable")
	farm["paid_harvests"] = kept_paid
	farm["npc_friendship"] = kept_friends
	_world().refresh(_plots())
	await get_tree().process_frame
	_world().go_home()
	await get_tree().process_frame


## Buildings actually standing in the world right now: the huts under
## _buildings that are not already on their way out of the tree.
func _huts_drawn() -> int:
	var buildings: Node2D = _world().get("_buildings")
	var standing := 0
	for child in buildings.get_children():
		if not child.is_queued_for_deletion():
			standing += 1
	return standing


## The middle of the first visible Button carrying this label, on the glass.
func _centre_of_button(label: String) -> Vector2:
	var stack: Array = [_garden]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and str((node as Button).text) == label \
				and (node as Control).is_visible_in_tree():
			return (node as Control).get_global_rect().get_center()
		for child in node.get_children():
			stack.append(child)
	return Vector2.ZERO


## The visitor board opens its sheet where it is pressed, reading it makes
## the news old, and an empty board is a warm picture, not a blank sheet.
func _the_visitor_board_reads_and_clears(view: Vector2) -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	farm["visit_log"] = [{"who": "bear", "watered": 2, "star": 1,
		"at": NOON - 600}]
	farm["visit_log_unread"] = true
	_world().look_at_facility("visit_board")
	await get_tree().process_frame
	var at: Vector2 = _world().facility_screen_position("visit_board")
	_ok(_world().facility_under(at) == "visit_board",
		"the board can be pressed where it is drawn")
	await _tap(at)
	_ok(bool(_garden.get("_visit_open")), "pressing the board opens it")
	_ok(not bool(SaveManager.data["farm"].get("visit_log_unread", true)),
		"reading the board is what makes its news old")
	# The sheet's X: same scaffolding as every panel -- origin.x + wide - 74,
	# +31 to the button's centre. Pressed for real, because this sheet is new.
	await _tap(_centre_of_button("X"))
	_ok(not bool(_garden.get("_visit_open")), "the X closes the board")
	farm["visit_log"] = []
	farm["visit_log_unread"] = false
	await get_tree().process_frame
	await _tap(_world().facility_screen_position("visit_board"))
	_ok(bool(_garden.get("_visit_open")),
		"a board nobody has visited still opens, warmly, without crashing")
	_garden.call("_close_panels")
	await get_tree().process_frame
	await get_tree().process_frame
	_world().go_home()
	await get_tree().process_frame


## The dog runs to what matters and never gets in the way: ripe first, then
## the caterpillar, then unread news, then home -- always a full sit_gap
## clear of the bed's centre, never in the blockers, never taking a tap.
func _the_dog_minds_his_own_business() -> void:
	var dog: Node2D = _world().get("_dog")
	_ok(dog != null and is_instance_valid(dog), "there is a dog")
	if dog == null or not is_instance_valid(dog):
		return
	_ok(not (dog in _world().blockers),
		"the dog is not furniture -- he blocks nothing")

	for i in range(_plots().size()):
		_set_bed(i, {})
	SaveManager.data["farm"]["visit_log_unread"] = false
	_world().refresh(_plots())
	var kennel: Vector2 = Layout.facility_at(Layout.facility("kennel")) \
		+ Vector2(0, 40)
	_ok((dog.get("_target") as Vector2).distance_to(kennel) < 1.0,
		"with nothing to point at, the dog goes home to his kennel")

	_set_bed(2, {"state": Farm.READY, "crop_id": "carrot", "growth_stage": 4})
	_world().refresh(_plots())
	var bed: Vector2 = Layout.plot_at(2)
	var sit_gap: float = dog.get("_sit_gap")
	var target: Vector2 = dog.get("_target")
	_ok(absf(target.distance_to(bed) - sit_gap) < 2.0,
		"a ripe bed pulls the dog to it -- beside it, exactly, never on it")
	_ok(target.distance_to(bed) >= 96.0,
		"...far enough out that a thumb aiming at the bed cannot land on him")

	_set_bed(1, {"state": Farm.NEEDS_CARE, "crop_id": "tomato",
		"care_event": Growth.CARE_BUG, "growth_stage": 2})
	_world().refresh(_plots())
	_ok((dog.get("_target") as Vector2).distance_to(bed) < sit_gap + 2.0,
		"something to pick matters more than something to grumble at")
	_set_bed(2, {})
	_world().refresh(_plots())
	_ok((dog.get("_target") as Vector2).distance_to(Layout.plot_at(1))
		<= sit_gap + 2.0,
		"with nothing ripe, the caterpillar is what he grumbles at")
	_set_bed(1, {})
	SaveManager.data["farm"]["visit_log_unread"] = true
	_world().refresh(_plots())
	var board: Vector2 = Layout.facility_at(Layout.facility("visit_board")) \
		+ Vector2(0, 52)
	_ok((dog.get("_target") as Vector2).distance_to(board) < 1.0,
		"unread news sends him to stand by the visitor board")
	SaveManager.data["farm"]["visit_log_unread"] = false
	_world().refresh(_plots())
	_ok((dog.get("_target") as Vector2).distance_to(kennel) < 1.0,
		"read news is old news -- back to the kennel")

	# The scarf: not before the friendship, always after. Derived from the
	# save on every retarget, so it cannot be lost and cannot be early.
	_ok(dog.get("_scarf") == null,
		"a dog whose child has no friend yet wears no scarf")
	SaveManager.data["farm"]["npc_friendship"] = {"bear": 1}
	_world().refresh(_plots())
	_ok(dog.get("_scarf") != null,
		"the first friendship star ties the red scarf on")
	SaveManager.data["farm"]["npc_friendship"] = {}


## A visit to the bear's farm on its real screen, with real taps: the starred
## one can be picked exactly once and is kept; the thirsty bed can be watered
## for exactly one star; the bear's own beds give nothing; the way home is on
## the glass. Pressing home is a scene change, which would end this probe --
## its existence is the assertion.
func _a_visit_to_the_bears_farm() -> void:
	_fresh_farm()
	SaveManager.data["farm"]["paid_harvests"] = ["farm_harvest_plot_0_1"]
	var bear: Node = load("res://scenes/garden/BearFarm.tscn").instantiate()
	add_child(bear)
	await get_tree().process_frame
	await get_tree().process_frame

	var beds: Array = NpcFarm.bear_beds(GameClock.now_unix())
	var share := -1
	var thirsty := -1
	var sneak := -1
	var own := -1
	for i in range(beds.size()):
		var plot: Dictionary = beds[i]
		if bool(plot.get("share", false)):
			share = i
		elif bool(plot.get("sneak", false)):
			sneak = i
		elif bool(plot.get("help_target", false)):
			thirsty = i
		elif own < 0:
			own = i
	_ok(share >= 0 and thirsty >= 0 and sneak >= 0 and own >= 0,
		"the bear's farm has a share bed, a quiet bed, a thirsty bed, "
		+ "and his own")
	_ok(bear.get("_star") != null, "the share star is up for a new friend")

	var strawberries := Barn.count("strawberry")
	await _tap(bear.call("_bed_centre", share))
	_ok(Barn.count("strawberry") == strawberries + 1,
		"the starred strawberry lands in HIS barn, kept whatever happens next")
	_ok(bool(NpcFarm.bear_state().get("help_owed", false)),
		"...and the watering is now owed")
	_ok(bear.get("_star") == null, "the star goes out")
	await _tap(bear.call("_bed_centre", share))
	_ok(Barn.count("strawberry") == strawberries + 1,
		"a second tap takes no second strawberry")

	var barn_before := JSON.stringify(Barn.contents())
	await _tap(bear.call("_bed_centre", own))
	_ok(JSON.stringify(Barn.contents()) == barn_before,
		"the bear's own beds give nothing to a tap -- what is his is his")

	await _tap(bear.call("_bed_centre", thirsty))
	_ok(not bool(NpcFarm.bear_state().get("help_owed", false)),
		"watering the thirsty bed clears the promise")
	_ok(NpcFarm.friendship() == 1, "...and grows the friendship by one")
	_ok(int(SaveManager.data["farm"].get("farm_xp", 0))
		== GameData.farm_xp_for("help"),
		"...and the help pays its listed xp, through the same gate")
	var log: Array = SaveManager.data["farm"].get("visit_log", [])
	_ok(log.size() >= 1
		and str((log[0] as Dictionary).get("kind", "")) == "guest",
		"the visit writes itself on the board at home, told as a GUEST story")
	_ok(bool(SaveManager.data["farm"].get("visit_log_unread", false)),
		"...and the board counts it as news for the dog to point at")
	await _tap(bear.call("_bed_centre", thirsty))
	_ok(NpcFarm.friendship() == 1, "a second watering pays no second star")
	_ok(int(SaveManager.data["farm"].get("farm_xp", 0))
		== GameData.farm_xp_for("help"),
		"...and no second xp either")

	var doors := 0
	for child in bear.get_children():
		if child is Button:
			doors += 1
	_ok(doors >= 1, "there is a way home")

	# 悄悄摘一颗：星星旁边那畦熟着，头顶上什么都没有——没有星，才是
	# 这个玩笑的全部。摘一颗是允许的、拿回家的、不发星也不挨说的；
	# 一个生长周期只有一颗。
	var quiet_before := Barn.count("strawberry")
	await _tap(bear.call("_bed_centre", sneak))
	_ok(Barn.count("strawberry") == quiet_before + 1,
		"the quiet strawberry is his to take, and kept")
	_ok(bool(NpcFarm.bear_state().get("sneak_owed", false)),
		"...and the bear now owes one wink for next visit")
	_ok(NpcFarm.friendship() == 1,
		"no star for mischief -- the friendship count does not move")
	await _tap(bear.call("_bed_centre", sneak))
	_ok(Barn.count("strawberry") == quiet_before + 1,
		"once per growth cycle: a second tap takes nothing more")

	# Seven taps landed above. With touch<->mouse emulation on, one physical
	# tap arrives as BOTH event families; if the screen answered both, this
	# would read fourteen, and every guard upstream would be silently eating
	# a double it should never have been fed.
	_ok(int(bear.get("presses")) == 7,
		"seven taps were dispatched exactly seven times, not fourteen")

	bear.queue_free()
	await get_tree().process_frame
	GameClock.clear_test_now()


func _friend_farm_buttons_are_available() -> void:
	_garden.call("_open_panel", "gift")
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_probe_screen("friend_door")
	for button_name in ["VisitBearFarmButton", "VisitRabbitFarmButton",
			"VisitPuppyFarmButton"]:
		_ok(_find_named(_garden, button_name) is Button,
			"the friends door exposes %s" % button_name)
	_garden.call("_close_panels")
	await get_tree().process_frame


func _an_old_npc_save_gains_friend_defaults() -> void:
	var legacy := {"bear": {"last_share_cycle": 8, "help_owed": false,
		"last_visit_at": 42, "last_sneak_cycle": 7, "sneak_owed": true}}
	var migrated: Dictionary = Farm.normalise_npc(legacy)
	_ok(int(migrated["bear"]["last_share_cycle"]) == 8
		and bool(migrated["bear"]["sneak_owed"])
		and migrated.has("rabbit") and migrated.has("puppy")
		and int(migrated["rabbit"]["last_share_cycle"]) == -1
		and not bool(migrated["puppy"]["help_owed"]),
		"an older farm keeps bear state and receives empty rabbit/puppy state")


## Rabbit and puppy use the same no-loss share loop: one deterministic crop,
## one help promise, then one friendship and one guest log entry.
func _a_visit_to_a_friends_farm(who: String) -> void:
	_fresh_farm()
	var scene_path := "res://scenes/garden/RabbitFarm.tscn" \
		if who == "rabbit" else "res://scenes/garden/PuppyFarm.tscn"
	var friend_farm: Node = load(scene_path).instantiate()
	add_child(friend_farm)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_probe_screen("%s_farm" % who)

	var definition: Dictionary = GameData.get_npc_farm(who)
	var beds: Array = NpcFarm.friend_beds(who, GameClock.now_unix())
	var share_index := -1
	var help_index := -1
	for i in range(beds.size()):
		var plot: Dictionary = beds[i]
		if bool(plot.get("share", false)):
			share_index = i
		if bool(plot.get("help_target", false)):
			help_index = i
	_ok(beds.size() == 6 and share_index >= 0 and help_index >= 0
		and ResourceLoader.exists("res://assets/harvest_3d/runtime/friends/%s.glb"
		% str(definition.get("character_model", ""))),
		"%s's farm has six beds, a share crop, a help bed, and a 3D friend" % who)
	_ok(friend_farm.get("_friend_model") != null,
		"%s's 3D character loads inside the farm scene" % who)
	_ok(friend_farm.get("_star") != null,
		"%s's extra share crop is marked with a star" % who)

	var crop_id := str(definition.get("share_crop", ""))
	var before := Barn.count(crop_id)
	await _tap(friend_farm.call("_bed_centre", share_index))
	_ok(Barn.count(crop_id) == before + 1
		and bool(NpcFarm.friend_state(who).get("help_owed", false)),
		"taking %s's share records exactly one extra crop and the help promise" % who)
	await _tap(friend_farm.call("_bed_centre", share_index))
	_ok(Barn.count(crop_id) == before + 1,
		"a second tap cannot take another crop from %s" % who)
	await _tap(friend_farm.call("_bed_centre", help_index))
	var farm: Dictionary = SaveManager.data["farm"]
	var log: Array = farm.get("visit_log", [])
	_ok(not bool(NpcFarm.friend_state(who).get("help_owed", true))
		and NpcFarm.friend_friendship(who) == 1,
		"helping %s clears the promise and awards one friendship" % who)
	_ok(not log.is_empty() and str(log[0].get("who", "")) == who
		and str(log[0].get("kind", "")) == "guest",
		"the finished %s visit appears on the shared visitor board" % who)
	_ok(int(friend_farm.get("presses")) == 3,
		"the %s farm dispatches three real taps exactly once each" % who)

	friend_farm.queue_free()
	await get_tree().process_frame
	GameClock.clear_test_now()


func _capture_probe_screen(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var folder := ProjectSettings.globalize_path("user://friend_farm_shots")
	DirAccess.make_dir_recursive_absolute(folder)
	var shape := _shape.replace("x", "_")
	var path := folder.path_join("%s_%s.png" % [label, shape])
	var saved := image.save_png(path) if image != null and not image.is_empty() \
		else ERR_INVALID_DATA
	print("farm world screenshot: %s" % path)
	_ok(saved == OK and ProbeLifecycle.image_has_content(image),
		"%s has a rendered screenshot for %s" % [label, _shape])


# --- 阶段 5: the stones, the ladder, and the market's one lesson -----------

## The seventh bed, bought with real taps: the stones answer a press, the
## confirm card stands between the press and the money, the earth appears
## without the camera moving, and the regret window gives it back WHOLE --
## including the ghost of its view, which the first cut of undo left behind,
## tappable, under the returned stones.
func _the_stones_ask_before_they_move() -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	farm["farm_xp"] = 0
	farm["farm_level"] = 1
	_world().refresh(_plots())
	await get_tree().process_frame
	_world().look_at_world(Layout.plot_at(6))
	await get_tree().process_frame
	var at: Vector2 = _camera().world_to_screen(Layout.plot_at(6))
	_ok(_world().expansion_under(at) == 6,
		"the stones stand where bed seven will, and a press finds them")
	_ok(_world().bed_under(at) == -1,
		"...and they are stones, not a bed the tools could reach")
	await _tap(at)
	_ok(int(_garden.get("_confirm_expand")) == -1,
		"at level 1 the press opens nothing -- the star badge is the answer")
	_ok(int(farm["plot_count"]) == 6, "...and no land moved")

	# Grown and funded: the press asks, the card answers.
	farm["farm_xp"] = 999
	farm["farm_level"] = 5
	SaveManager.data["rewards"]["coins"] = 200
	_world().refresh(_plots())
	await get_tree().process_frame
	await _tap(_camera().world_to_screen(Layout.plot_at(6)))
	_ok(int(_garden.get("_confirm_expand")) == 6,
		"grown and funded, the stones ask the question")
	var buttons: Dictionary = _garden.get("_panel_buttons")
	_ok(buttons.has("confirm_expand") and buttons.has("cancel_expand"),
		"...with a yes and a no standing between the press and the money")
	await _tap((buttons["confirm_expand"] as Button).position + Vector2(85, 29))
	_ok(int(farm["plot_count"]) == 7 and _world().bed_count() == 7,
		"one confirm clears the land, on screen and in the save")
	_ok(_world().bed_under(_camera().world_to_screen(Layout.plot_at(6))) == 6,
		"...and the new bed answers a thumb where the stones stood")
	_ok(not (_world().get("_slots") as Dictionary).has(6),
		"...whose stones are gone, not hiding under the earth")
	_ok(Coins.balance() == 200 - Expand.cost_of(6), "...at exactly its price")

	# The regret window, through the real toast.
	buttons = _garden.get("_panel_buttons")
	_ok(buttons.has("undo"), "the regret window is open")
	await _tap((buttons["undo"] as Button).position + Vector2(80, 24))
	_ok(int(farm["plot_count"]) == 6 and Coins.balance() == 200,
		"undo puts the stones back and the whole price with them")
	_ok(_world().bed_count() == 6,
		"...and takes the bed's VIEW with it -- no ghost under the stones")
	_ok(_world().bed_under(_camera().world_to_screen(Layout.plot_at(6))) == -1
		and _world().expansion_under(
			_camera().world_to_screen(Layout.plot_at(6))) == 6,
		"...so a thumb there finds stones again, not a bed")
	_world().go_home()
	await get_tree().process_frame


## The one other thing the garden ever teaches: the first time the barn gets
## close to full, one sentence and one finger point at the market box. A
## flag, not a schedule -- and the flag is on disk, so it happens once in a
## childhood, not once per visit.
func _the_barn_full_moment_points_at_the_market() -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	farm["market_taught"] = false
	farm["warehouse"] = {"carrot": Barn.cap() - 4}
	_tools_state().selected = "hand"
	_set_bed(0, {"state": Farm.READY, "crop_id": "carrot", "growth_stage": 4,
		"plant_cycle_id": 9001})
	await _redraw()
	_world().go_home()
	await get_tree().process_frame
	await _tap(_world().bed_screen_position(0))
	_ok(bool(farm.get("market_taught", false)),
		"the nearly-full barn is the moment the market gets its sentence")
	var fingers := 0
	for child in _garden.get_children():
		if child is Tutorial:
			fingers += 1
	_ok(fingers >= 1, "...and its finger")
	# Again, fuller still: the harvest still pays, the teaching does not
	# repeat -- taught is taught, on disk. (After the pick-lock breathes out:
	# the same bed was harvested a moment ago and holds its half-second.)
	await get_tree().create_timer(0.6).timeout
	var held := Barn.total() + Barn.total(Barn.BASKET)
	_set_bed(0, {"state": Farm.READY, "crop_id": "carrot", "growth_stage": 4,
		"plant_cycle_id": 9002})
	await _redraw()
	# The finger's pan walked the camera to the market box; walk back so the
	# bed is on the glass at all -- a tap at an off-screen position is the
	# probe missing, not the game refusing.
	_world().go_home()
	await get_tree().process_frame
	await _tap(_world().bed_screen_position(0))
	_ok(Barn.total() + Barn.total(Barn.BASKET) > held,
		"the second harvest is an ordinary harvest -- crops in")
	_ok(bool(farm.get("market_taught", false)),
		"...and the flag never un-teaches itself")
	farm["warehouse"] = {}
	farm["harvest_basket"] = {}
	Barn.tip_basket_in()
