extends Node
## The first-upgrade story chain (the brief's 第十七节), walked end to end
## with real input, photographed at every beat. Development harness:
##
##   SHOT_DIR=/tmp/story xvfb-run -a godot --path . \
##     --rendering-driver opengl3 res://tests/StoryShots.tscn
##
## Twelve numbered frames: the dog finds ripe beds -> batch harvest -> the
## barn nearly full and the market pointed at -> selling -> coins -> buying
## the potato -> planting it -> the bear's door -> his farm -> the shared
## pick -> the watering -> home, where the board tells the story and the dog
## wears the scarf. The probes prove each link HOLDS; this file is the
## record that the chain can be WALKED, by a finger, in order.
##
## The one seam: stepping through the bear's door here swaps scenes by hand.
## SceneManager.goto_scene() replaces the whole tree, harness included --
## the probe asserts the door routes there; this film changes the set.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")

const NOON := 1_699_963_200

var _dir := "/tmp/story"
var _frame := 0
var _garden: Node = null


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = "/tmp/story"
	DirAccess.make_dir_recursive_absolute(_dir)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	# Unix pinned, ticks left REAL: the regret toast measures its five
	# seconds in ticks_ms, and a frozen tick clock makes it immortal.
	GameClock.set_test_now(NOON)
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	SaveManager.data["farm"]["tutorial_completed"] = true
	SaveManager.data["farm"]["last_seen_at"] = NOON
	SaveManager.data["rewards"]["coins"] = 0

	GameManager.current_level_id = "star_garden"
	_garden = load("res://scenes/garden/Garden.tscn").instantiate()
	add_child(_garden)
	await get_tree().process_frame
	await get_tree().process_frame

	# The morning this story starts on: a barn most of the way full, two beds
	# of carrots ready, one bed turned and waiting. Crafted AFTER the garden
	# opens -- settle_farm replaces data["farm"], the farm_shot lesson.
	var farm: Dictionary = SaveManager.data["farm"]
	farm["warehouse"] = {"carrot": 30}
	farm["market_taught"] = false
	var plots: Array = farm["plots"]
	for pair in [[0, 501], [1, 502]]:
		var bed: Dictionary = Farm.fresh_plot(int(pair[0]))
		bed["state"] = Farm.READY
		bed["crop_id"] = "carrot"
		bed["growth_stage"] = Farm.STAGES - 1
		bed["plant_cycle_id"] = int(pair[1])
		plots[int(pair[0])] = bed
	var turned: Dictionary = Farm.fresh_plot(2)
	turned["state"] = Farm.TILLED
	plots[2] = turned
	farm["plots"] = plots
	_garden.call("_rebuild")
	await get_tree().process_frame
	_world().go_home()

	# 1. The dog has already run to the ripe beds and sat down beside them.
	await _wait(3.2)
	await _snap("01_dog_finds_ripe_beds")

	# 2. The basket brush, swept across both beds in one stroke.
	var tools: Dictionary = _garden.get("_tool_buttons")
	await _tap((tools["basket"] as Button).position + Vector2(48, 38))
	await _stroke(_world().bed_screen_position(0),
		_world().bed_screen_position(1))
	await _wait(0.7)
	await _snap("02_batch_harvest")

	# 3. The barn is nearly full now, and the one lesson points at the box.
	await _wait(1.2)
	await _snap("03_market_pointed_at")

	# 4. The pile, dragged into the box; the total stands over it.
	await _tap(_world().facility_screen_position("market"))
	await _wait(0.4)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var origin := Vector2(view.x * 0.5 - 390.0, 96.0 + 16.0)
	await _drag(origin + Vector2(46, 96), origin + Vector2(590.0, 200.0))
	await _snap("04_pile_in_the_box")

	# 5. 卖掉 -- and the coins are his.
	var buttons: Dictionary = _garden.get("_panel_buttons")
	await _tap((buttons["sell"] as Button).position + Vector2(90, 31))
	await _wait(0.6)
	await _snap("05_coins_earned")

	# 6. The seed shop, and the potato's three numbers asked about. (Walk
	# first: the camera is still at the market, and a tap at an off-glass
	# position is the film missing, not the child.)
	_garden.call("_close_panels")
	await get_tree().process_frame
	_world().look_at_facility("seed_shop")
	await _wait(0.3)
	await _tap(_world().facility_screen_position("seed_shop"))
	await _wait(0.4)
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["buy_potato"] as Button).position + Vector2(80, 26))
	await _snap("06_potato_asked_about")

	# 7. Bought, brushed into the turned bed, growing.
	buttons = _garden.get("_panel_buttons")
	await _tap((buttons["confirm_buy"] as Button).position + Vector2(90, 30))
	_garden.call("_close_panels")
	await get_tree().process_frame
	await _tap((( _garden.get("_tool_buttons"))["seed"] as Button).position
		+ Vector2(48, 38))
	var state: Object = _garden.get("_tools")
	state.set("seed_crop", "potato")
	# Walk to the turned bed first -- the shop's pan left it off the glass,
	# and a stroke at an off-screen position plants nothing.
	_world().look_at_world(Layout.plot_at(2))
	await _wait(0.3)
	await _stroke(_world().bed_screen_position(2) + Vector2(-40, 0),
		_world().bed_screen_position(2) + Vector2(40, 0))
	await _wait(0.5)
	await _snap("07_potato_planted")

	# 8. And there, at the bottom of the farm: a door that was not there this
	# morning. (It opened with the first paid harvest, mid-visit.) The walk
	# waits out the seed purchase's regret toast first, so the door's frame
	# is about the door.
	await _wait(4.6)
	# The toast clears itself on the next redraw; standing still, the film
	# has to ask for one -- a child's next tap would be that redraw.
	_garden.call("_queue_rebuild")
	await _wait(0.3)
	_world().look_at_facility("bear_door")
	await _wait(0.8)
	await _snap("08_bear_door_appeared")

	# 9-11. Through it. (The film swaps the set by hand; see the header.)
	_garden.queue_free()
	await get_tree().process_frame
	var bear: Node = load("res://scenes/garden/BearFarm.tscn").instantiate()
	add_child(bear)
	await _wait(1.0)
	await _snap("09_bears_farm_the_share_star")

	var beds: Array = NpcFarm.bear_beds(GameClock.now_unix())
	var share := -1
	var thirsty := -1
	for i in range(beds.size()):
		if bool((beds[i] as Dictionary).get("share", false)):
			share = i
		elif bool((beds[i] as Dictionary).get("help_target", false)):
			thirsty = i
	await _tap(bear.call("_bed_centre", share))
	await _wait(0.9)
	await _snap("10_the_quiet_pick")

	await _tap(bear.call("_bed_centre", thirsty))
	await _wait(0.9)
	await _snap("11_watering_the_thanks")

	# 12. Home the front way: the board has the story, the dog has the scarf.
	bear.queue_free()
	await get_tree().process_frame
	_garden = load("res://scenes/garden/Garden.tscn").instantiate()
	add_child(_garden)
	await get_tree().process_frame
	await get_tree().process_frame
	_world().look_at_facility("visit_board")
	await _wait(0.3)
	await _tap(_world().facility_screen_position("visit_board"))
	await _wait(1.6)
	await _snap("12_home_board_and_scarf")

	print("story_shots -> %d frames in %s" % [_frame, _dir])
	get_tree().quit(0)


func _world() -> Node:
	return _garden.get("_world")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_frame += 1
	image.save_png("%s/%s.png" % [_dir, name])


func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = at
		Input.parse_input_event(touch)
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = from
	Input.parse_input_event(down)
	await get_tree().process_frame
	var last := from
	for step in range(1, 11):
		var at := from.lerp(to, float(step) / 10.0)
		var move := InputEventScreenDrag.new()
		move.index = 0
		move.position = at
		move.relative = at - last
		Input.parse_input_event(move)
		await get_tree().process_frame
		last = at
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = to
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


## A brush stroke: down on the first bed, a slow sweep to the second, up.
func _stroke(from: Vector2, to: Vector2) -> void:
	await _drag(from, to)
