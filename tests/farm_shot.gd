extends Node
## Renders the 阶段4 farm to a PNG, for the eyes that probes do not have.
## Development harness:
##   SHOT_WHAT=garden|bear|board|home|kitchen|thanks SHOT_WIN=1280x720 \
##     SHOT_PATH=/tmp/x.png \
##     xvfb-run -a godot --path . --rendering-driver opengl3 \
##     res://tests/FarmShot.tscn
##
## garden: mid-life farm -- bear door open, news on the board, the dog out
##         pointing at a ripe bed, one thirsty, one caterpillar.
## bear:   the bear's farm with the share star up.
## board:  the visitor board open over the farm, its one entry readable.
## kitchen: the workshop kitchen at level 5 -- one soup ready to cook, one
##         stew short of tomatoes, one cooked dish waiting on the shelf.
## thanks: the visit board with a thank-you entry over an ordinary visit.
## wink:   the visit board carrying the quiet-strawberry answer -- one amber
##         line, one strawberry icon, told over an ordinary visit.
## poke:   the farm with furniture standing -- captured mid-wiggle, one
##         decoration answering a tap.
## rack:   all fourteen crops owned -- the seed rack with its page arrows.
## shop:   level 3, the batch that just went on sale and the level-5 batch
##         still standing as starred ground. SHOT_PAGE=1 flips to page two.
## book:   the recipe book, twelve recipes across two pages.
## orders: level 3 with five orders delivered -- work first, receipts pad.
## daily:  the ripe next task with today's three care stars complete and the
##         gentle golden-luck crest lit on the shelf.
## SHOT_PAGE=N flips the mode's paged surface to page N before the shot.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")

const NOON := 1_699_963_200


func _ready() -> void:
	var out := OS.get_environment("SHOT_PATH")
	var what := OS.get_environment("SHOT_WHAT")
	if what == "":
		what = "garden"
	var win := OS.get_environment("SHOT_WIN")
	if win != "":
		var parts := win.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
		await get_tree().process_frame

	GameClock.set_test_now(NOON, 0)
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	var farm: Dictionary = SaveManager.data["farm"]
	farm["tutorial_completed"] = true
	farm["last_seen_at"] = NOON
	farm["paid_harvests"] = ["farm_harvest_plot_0_1"]
	farm["npc_friendship"] = {"bear": 2}
	farm["visit_log"] = [{"who": "bear", "watered": 2, "star": 1,
		"at": NOON - 900}]
	farm["visit_log_unread"] = what == "garden"

	GameManager.current_level_id = "star_garden"
	var scene: Node
	if what == "home":
		scene = load("res://scenes/home/Home.tscn").instantiate()
		add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
	elif what == "bear":
		scene = load("res://scenes/garden/BearFarm.tscn").instantiate()
		add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		scene = load("res://scenes/garden/Garden.tscn").instantiate()
		add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
		# The beds are crafted AFTER the garden opens, against a re-fetched
		# farm: settle_farm REPLACES data["farm"], so the dictionary this
		# function held a moment ago is nobody's farm now. The first cut of
		# this harness wrote six beds into that orphan and photographed six
		# squares of grass.
		farm = SaveManager.data["farm"]
		farm["paid_harvests"] = ["farm_harvest_plot_0_1"]
		farm["npc_friendship"] = {"bear": 2}
		farm["visit_log"] = [{"who": "bear", "watered": 2, "star": 1,
			"at": NOON - 900}]
		farm["visit_log_unread"] = what == "garden"
		var plots: Array = farm["plots"]
		plots[0] = _bed(0, {"state": Farm.READY, "crop_id": "carrot",
			"growth_stage": 4, "planted_at": NOON - 7200})
		plots[1] = _bed(1, {"state": Farm.GROWING, "crop_id": "strawberry",
			"growth_stage": 1, "planted_at": NOON - 600})
		plots[2] = _bed(2, {"state": Farm.NEEDS_CARE, "crop_id": "corn",
			"care_event": Growth.CARE_THIRSTY, "growth_stage": 2,
			"planted_at": NOON - 3600})
		plots[3] = _bed(3, {"state": Farm.NEEDS_CARE, "crop_id": "tomato",
			"care_event": Growth.CARE_BUG, "growth_stage": 2,
			"planted_at": NOON - 3600})
		plots[4] = _bed(4, {"state": Farm.TILLED})
		farm["plots"] = plots
		if what == "daily":
			# A deterministic all-cared-for day: this fixture only makes the
			# existing daily manager's display state visible; it does not invent
			# a golden crop, extra money or a second reward ledger.
			farm["dailies"] = {"date": GameClock.now_date(),
				"progress": {"water": 3, "harvest": 5, "deliver": 1},
				"claimed": []}
		if what == "market":
			# The sell decision with numbers on it: three kinds of crop on the
			# shelf, each chip naming its unit price, and three carrots boxed
			# out of twelve -- the row under the crate is the "keep nine" half.
			farm["warehouse"] = {"carrot": 12, "strawberry": 6, "tomato": 3}
		if what == "kitchen":
			# 五级农场，两道会做的菜：汤下得了锅（草莓正好），炖菜还缺
			# 番茄，架上还有一份昨天的汤——面板的三种状态一屏看全。
			farm["farm_xp"] = 200
			farm["unlocked_recipes"] = ["strawberry_soup", "tomato_stew"]
			farm["warehouse"] = {"strawberry": 3, "tomato": 1}
			var pack: Dictionary = SaveManager.data.get("inventory", {})
			pack["dish_strawberry_soup"] = 1
			SaveManager.data["inventory"] = pack
		if what == "thanks":
			farm["visit_log"] = [
				{"who": "bear", "kind": "thanks", "at": NOON - 300,
					"dish_name_key": "recipe.strawberry_soup",
					"milestone_key": "garden.dish_thanks",
					"milestone_icon": "dish"},
				{"who": "bear", "watered": 2, "star": 1, "at": NOON - 900},
			]
		if what == "wink":
			farm["visit_log"] = [
				{"who": "bear", "kind": "", "watered": 1, "star": 1,
					"shared_back": 1, "at": NOON - 300,
					"milestone_key": "garden.visit_shared_back",
					"milestone_icon": "strawberry"},
				{"who": "bear", "watered": 2, "star": 1, "at": NOON - 900},
			]
		if what == "poke":
			SaveManager.set_creation("garden", [
				{"icon": "flag", "x": 477.0, "y": 377.0, "size": 96.0},
				{"icon": "balloon", "x": 700.0, "y": 300.0, "size": 84.0},
				{"icon": "heart", "x": 300.0, "y": 500.0, "size": 72.0},
			])
		if what == "rack":
			farm["farm_xp"] = 200
			farm["unlocked_crops"] = ["carrot", "corn", "strawberry",
				"tomato", "lettuce", "potato", "peas", "wheat", "broccoli",
				"pumpkin", "watermelon", "grape", "orange", "apple"]
		if what == "shop":
			farm["farm_xp"] = 60
			SaveManager.data["rewards"]["coins"] = 120
		if what == "book":
			farm["unlocked_recipes"] = ["strawberry_soup", "potato_cakes",
				"tomato_stew", "corn_chowder", "rainbow_salad",
				"harvest_platter", "pea_soup"]
		if what == "orders":
			farm["farm_xp"] = 60
			SaveManager.data["farm_orders"] = {"delivered": ["bear_carrots",
				"robot_supply", "puppy_berries", "robot_wheat_run",
				"bear_pumpkin_treat"]}
		scene.call("_rebuild")
		await get_tree().process_frame
		var page := int(OS.get_environment("SHOT_PAGE")) \
			if OS.get_environment("SHOT_PAGE") != "" else 0
		if what == "board" or what == "thanks" or what == "wink":
			scene.call("_tap_building", "visit_board")
			await get_tree().process_frame
		elif what == "kitchen":
			scene.call("_tap_building", "workshop")
			await get_tree().process_frame
			# SHOT_ASK=1: the moment between pressing 做一份 and saying yes --
			# the confirm strip up, nothing taken yet.
			if OS.get_environment("SHOT_ASK") == "1":
				scene.set("_confirm_cook", "strawberry_soup")
				scene.call("_queue_rebuild")
				await get_tree().process_frame
		elif what == "shop":
			scene.call("_open_panel", "shop")
			scene.set("_shop_page", page)
			scene.call("_queue_rebuild")
			await get_tree().process_frame
		elif what == "book":
			scene.call("_open_panel", "recipes")
			scene.set("_book_page", page)
			scene.call("_queue_rebuild")
			await get_tree().process_frame
		elif what == "orders":
			scene.call("_tap_building", "orders")
			await get_tree().process_frame
		elif what == "market":
			scene.call("_open_panel", "market")
			await get_tree().process_frame
			scene.call("_on_market_drop", {"key": "carrot"}, true, true)
			for i in range(9):
				scene.call("_market_step", "carrot", -1)
			await get_tree().process_frame
		elif what == "rack" and page > 0:
			scene.set("_rack_page", page)
			scene.call("_queue_rebuild")
			await get_tree().process_frame

	# SHOT_ZOOM=out presses minus until it stops: the whole-farm overview.
	if OS.get_environment("SHOT_ZOOM") == "out" and what != "bear" \
			and what != "home":
		for i in range(6):
			(scene.get("_world") as Node).call("zoom_by", -1)
		scene.call("_queue_rebuild")

	# Long enough for the dog to have RUN from his kennel to the ripe bed and
	# sat down beside it -- a farm standing at attention is not this farm.
	await get_tree().create_timer(3.4).timeout
	if what == "poke":
		# Fire the wiggle NOW and catch it mid-tilt: the answer lasts four
		# tenths of a second, which is the point -- and the reason it cannot
		# be photographed after the usual settle.
		var layer: Node = (scene.get("_world") as Node)\
			.get_node_or_null("Decorations")
		if layer != null and layer.get_child_count() > 0:
			var art := layer.get_child(0) as Control
			scene.call("_poke_decoration", (scene.get("_world") as Node)
				.get("camera").call("world_to_screen",
					art.position + art.size * 0.5))
			await get_tree().create_timer(0.1).timeout
	if what == "pet":
		# A hand on the dog's head: park him in the open, press him, and hold
		# the shutter while the hearts are still climbing. Nothing else on the
		# farm moves for this one -- the reaction is the whole picture.
		var dog: Node = scene.get("_world").get("_dog")
		dog.set("position", Vector2(640.0, 900.0))
		dog.set("_target", Vector2(640.0, 900.0))
		await get_tree().process_frame
		dog.call("pet")
		await get_tree().create_timer(0.35).timeout
	if what == "gold":
		# Pick the golden bed through the real tap path, then hold the shutter
		# a fifth of a second while the shower is still falling.
		var world2: Node = scene.get("_world")
		var bed: Vector2 = scene.call("_bed_centre", 0)
		var press2 := InputEventScreenTouch.new()
		press2.index = 0
		press2.pressed = true
		press2.position = bed
		Input.parse_input_event(press2)
		await get_tree().process_frame
		var lift := InputEventScreenTouch.new()
		lift.index = 0
		lift.pressed = false
		lift.position = bed
		Input.parse_input_event(lift)
		await get_tree().process_frame
		await get_tree().create_timer(0.22).timeout
	if what == "pull":
		# The gesture moment, caught mid-move: a finger pressed on the ripe
		# carrot, half way through the pull, camera holding still. The lean
		# is the whole point of the shot, and the spring needs a beat to
		# carry the plant over -- so the finger goes down, drags up in real
		# input events, and STAYS down while the shutter fires.
		var world: Node = scene.get("_world")
		var bed: Vector2 = scene.call("_bed_centre", 0)
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = bed
		Input.parse_input_event(press)
		await get_tree().process_frame
		await get_tree().process_frame
		for step in range(1, 4):
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = bed + Vector2(0.0, -70.0 * float(step))
			Input.parse_input_event(drag)
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("farm_shot -> ", error_string(image.save_png(out)))
	get_tree().quit(0)


func _bed(index: int, fields: Dictionary) -> Dictionary:
	var plot: Dictionary = Farm.fresh_plot(index)
	for key in fields.keys():
		plot[key] = fields[key]
	return plot
