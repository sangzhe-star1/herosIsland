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
## rack:   all fourteen crops owned -- the compact rack needs no page arrows.
## rack_held: first seed held through real input before any motion.
## overflow_many/overflow_collection: all sixteen waiting foods, in the dock
##         summary or its collection sheet opened through real input.
## shop:   level 3, the batch that just went on sale and the level-5 batch
##         still standing as starred ground. SHOT_PAGE=1 flips to page two.
## book:   the recipe book, twelve recipes across two pages.
## orders: level 3 with five orders delivered -- work first, receipts pad.
## daily:  the ripe next task with today's three care stars complete and the
##         gentle golden-luck crest lit on the shelf.
## daily_board: real orders board; water claimed, harvest claimable, delivery
##         unfinished. Checks the real once-gate and three button states.
## overflow: real touches split a carrot harvest, then spill a full strawberry
##         harvest. SHOT_DIR receives flight/settled/barn PNGs for each step.
##         SHOT_FULL_RACK=1 includes all fourteen crops in the compact rack.
## friends: rabbit in the real farm, answering one real touch with a heart.
## friends_orders: new friend commissions, with a fillable rabbit picnic.
## friend_thanks: that picnic actually delivered through the visible card.
## challenge_picker: replay panel; SHOT_PAGE selects its page.
## inventory_full/empty/upgrade: the collection sheet, including all sixteen
##         foods or its empty state; upgrade captures the real confirmation.
## SHOT_PAGE=N flips the mode's paged surface to page N before the shot.
## SHOT_REDUCE_MOTION=1 enables the existing low-motion setting before entry.
## SHOT_FOCUS_FACILITY=bear_door centres the garden view on that facility.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

const NOON := 1_699_963_200

var _fixture_failures: Array[String] = []
var _daily_asked := 0
var _overflow_asked := 0


func _ready() -> void:
	ProbeLifecycle.isolate_desktop_pointer(self)
	if DisplayServer.get_name() == "headless":
		print("FAIL FarmShot requires a rendered window")
		await ProbeLifecycle.finish(self, 1)
		return
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
	if OS.get_environment("SHOT_LOCALE") != "":
		I18n.set_locale(OS.get_environment("SHOT_LOCALE"))
	if OS.get_environment("SHOT_REDUCE_MOTION") == "1":
		SaveManager.set_setting("reduce_motion", true)
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
		if what == "overflow":
			if OS.get_environment("SHOT_FULL_RACK") == "1":
				farm["farm_xp"] = 200
				farm["unlocked_crops"] = []
				for crop in GameData.crops:
					(farm["unlocked_crops"] as Array).append(str(crop.get("id", "")))
			farm["warehouse"] = {"corn": Barn.cap() - 2}
			farm["harvest_basket"] = {}
			farm["paid_harvests"] = []
			farm["market_taught"] = true
			farm["unlocked_recipes"] = []
			for recipe in Recipes.all():
				(farm["unlocked_recipes"] as Array).append(str(recipe.get("id", "")))
			plots[4] = _bed(4, {"state": Farm.READY, "crop_id": "carrot",
				"growth_stage": 4, "plant_cycle_id": 51, "planted_at": NOON - 7200})
			SaveManager.data["settings"]["reduce_motion"] = \
				OS.get_environment("SHOT_REDUCE_MOTION") == "1"
		if what == "daily":
			# A deterministic all-cared-for day: this fixture only makes the
			# existing daily manager's display state visible; it does not invent
			# a golden crop, extra money or a second reward ledger.
			farm["dailies"] = {"date": GameClock.now_date(),
				"progress": {"water": 3, "harvest": 5, "deliver": 1},
				"claimed": []}
		if what == "daily_board":
			# Set the existing task tallies, then let the production claim path
			# produce the earned/claimable/unfinished states on the real board.
			var water_task := Dailies.task_by_id("water")
			var harvest_task := Dailies.task_by_id("harvest")
			farm["dailies"] = {"date": GameClock.now_date(),
				"progress": {"water": int(water_task.get("target", 0)),
					"harvest": int(harvest_task.get("target", 0)), "deliver": 0},
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
		if what == "coop":
			farm["farm_xp"] = 200
			farm["coop"] = {"fed_at": 0, "eggs": 2}
			farm["mill"] = {"started_at": 0, "done": 1}
			farm["warehouse"] = {"corn": 3, "wheat": 4}
		if what in ["rack", "rack_held", "overflow_many", "overflow_collection"]:
			farm["farm_xp"] = 200
			farm["unlocked_crops"] = ["carrot", "corn", "strawberry",
				"tomato", "lettuce", "potato", "peas", "wheat", "broccoli",
				"pumpkin", "watermelon", "grape", "orange", "apple"]
		if what in ["overflow_many", "overflow_collection"]:
			farm["warehouse"] = {"corn": Farm.WAREHOUSE_START}
			farm["harvest_basket"] = {}
			for crop in GameData.crops:
				farm["harvest_basket"][str(crop["id"])] = 2
			farm["harvest_basket"]["egg"] = 2
			farm["harvest_basket"]["flour"] = 2
		if what in ["inventory_full", "inventory_empty", "inventory_upgrade"]:
			farm["farm_xp"] = 200
			farm["unlocked_crops"] = []
			farm["warehouse"] = {}
			for crop in GameData.crops:
				(farm["unlocked_crops"] as Array).append(str(crop["id"]))
				if what != "inventory_empty":
					farm["warehouse"][str(crop["id"])] = 2
			if what != "inventory_empty":
				farm["warehouse"]["egg"] = 2
				farm["warehouse"]["flour"] = 2
			SaveManager.data["inventory"]["plank"] = 3
			SaveManager.data["rewards"]["coins"] = 120
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
		if what in ["friends_orders", "friend_thanks"]:
			farm["farm_xp"] = 200
			var delivered: Array = []
			for order in GameData.garden_orders:
				if not bool(order.get("recurring", false)) and not order.has("purpose_key"):
					delivered.append(str(order["id"]))
			SaveManager.data["farm_orders"] = {"delivered": delivered}
			farm["warehouse"] = {"carrot": 4, "strawberry": 2, "corn": 2}
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
		elif what == "daily_board":
			var water_task := Dailies.task_by_id("water")
			var before := Coins.balance()
			scene.call("_claim_daily", water_task)
			_daily_check(Coins.balance() == before + int(water_task.get("coins", 0)),
				"real water claim pays its configured reward")
			scene.call("_claim_daily", water_task)
			_daily_check(Coins.balance() == before + int(water_task.get("coins", 0)),
				"repeated water claim does not pay twice")
			await get_tree().process_frame
			scene.call("_tap_building", "orders")
			await get_tree().process_frame
			await get_tree().process_frame
			_validate_daily_board(scene)
		elif what == "orders":
			scene.call("_tap_building", "orders")
			await get_tree().process_frame
		elif what in ["friends_orders", "friend_thanks"]:
			scene.call("_tap_building", "orders")
			await get_tree().process_frame
			await get_tree().process_frame
			_daily_check(scene.find_child("OrderCard_rabbit_picnic", true, false) != null,
				"new rabbit order is actually present on the board")
		elif what == "challenge_picker":
			scene.call("_open_panel", "challenges")
			scene.set("_challenge_page", page)
			scene.call("_rebuild")
			await get_tree().process_frame
			_daily_check(scene.find_child("ChallengeLevel_harvest_%02d" % (page * 4 + 1), true, false) != null,
				"the requested replay page contains real level buttons")
		elif what in ["inventory_full", "inventory_empty", "inventory_upgrade"]:
			var shortcut := scene.find_child("BarnShortcut", true, false) as Control
			_daily_check(shortcut != null, "the actual collection shortcut exists")
			if shortcut != null:
				await _overflow_tap(shortcut.get_global_rect().get_center())
			_daily_check(bool(scene.get("_barn_open")), "real input opens the collection panel")
			if what == "inventory_upgrade":
				var upgrade := (scene.get("_panel_buttons") as Dictionary).get("upgrade") as Control
				_daily_check(upgrade != null, "collection has its real upgrade button")
				if upgrade != null:
					await _overflow_tap(upgrade.get_global_rect().get_center())
				_daily_check(bool(scene.get("_confirm_upgrade")), "real input opens the upgrade confirmation")
			var sheet := scene.find_child("BarnCollectionPanel", true, false) as Control
			_daily_check(sheet != null, "the styled collection sheet exists")
			var slots := scene.find_children("BarnCollectionSlot_*", "Panel", true, false)
			_daily_check(slots.size() == (0 if what == "inventory_empty" else 16),
				"the collection displays exactly the stock in the fixture")
			_daily_check(Barn.total() == (0 if what == "inventory_empty" else 32),
				"collection capacity counts eggs and flour")
			for slot in slots:
				_daily_check(sheet != null and sheet.get_global_rect().encloses(slot.get_global_rect()),
					"each food slot remains inside its collection sheet")
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
	if what == "rack_held":
		var seed := scene.find_child("GardenSeed_carrot", true, false) as Control
		_daily_check(seed != null, "the compact carrot seed is visible")
		if seed != null:
			var down := InputEventScreenTouch.new()
			down.index = 0
			down.pressed = true
			down.position = seed.get_global_rect().get_center() \
				* Vector2(get_window().size) / get_viewport().get_visible_rect().size
			Input.parse_input_event(down)
			await get_tree().create_timer(0.16).timeout
			var field: DragField = scene.get("_field")
			_daily_check(str(field.held().get("key", "")) == "carrot",
				"the seed is held through the real touch path")
			var visual := scene.find_child("SeedSlot_carrot", true, false) as Control
			_daily_check(visual != null and get_viewport().get_visible_rect().encloses(visual.get_global_rect()),
				"the enlarged seed stays inside the screen before dragging")
	if what in ["overflow_many", "overflow_collection"]:
		var before := Barn.total() + Barn.total(Barn.BASKET)
		_daily_check(Barn.contents(Barn.BASKET).size() == 16 and Barn.total(Barn.BASKET) == 32,
			"all sixteen waiting foods remain in the overflow ledger")
		var shortcut := scene.find_child("OverflowShortcut", true, false) as Control
		_daily_check(shortcut != null, "the waiting-food summary can be opened")
		if what == "overflow_collection" and shortcut != null:
			await _overflow_tap(shortcut.get_global_rect().get_center())
			var slots := scene.find_children("BarnCollectionSlot_*", "Panel", true, false)
			_daily_check(slots.size() == 16, "real input reveals all sixteen waiting foods")
		_daily_check(Barn.total() + Barn.total(Barn.BASKET) == before,
			"viewing the waiting foods does not move or duplicate stock")
	if what == "friends":
		var friend: Control = null
		var life := scene.find_child("SceneryLife", true, false)
		if life != null:
			for entry: Dictionary in life.get("_alive"):
				var sprite: Control = entry["sprite"]
				if str(sprite.get_meta("prop_id", "")) == "rabbit":
					friend = sprite
					break
		_daily_check(friend != null, "the Blender rabbit is in the farm")
		if friend != null:
			var world: Node = scene.get("_world")
			world.call("look_at_world", friend.get_parent().position)
			await get_tree().process_frame
			var source := (friend as TextureRect).texture.get_image().get_used_rect()
			var centre := Vector2(source.get_center()) * friend.size / 512.0
			await _overflow_tap(friend.get_global_transform_with_canvas() * centre)
			await get_tree().create_timer(0.16).timeout
			_daily_check(friend.find_child("FriendGreeting", true, false) != null,
				"a real touch makes the rabbit greet")
	if what == "friend_thanks":
		var card := scene.find_child("OrderCard_rabbit_picnic", true, false) as Button
		if card != null:
			await _overflow_tap(card.get_global_rect().get_center())
			await get_tree().create_timer(0.2).timeout
		_daily_check("rabbit_picnic" in SaveManager.data["farm_orders"].get("delivered", []),
			"the visible friend order is paid through real input")
		_daily_check(scene.find_child("OrderThanks", true, false) != null,
			"delivery shows the friend's actual thank-you")
	if what == "overflow":
		await _overflow_sequence(scene)
		for failure in _fixture_failures:
			print("FAIL ", failure)
		print("asked %d questions" % _overflow_asked)
		print("OVERFLOW SHOT ", "PASSED" if _fixture_failures.is_empty() else "FAILED")
		await ProbeLifecycle.finish(self, 0 if _fixture_failures.is_empty() else 1)
		return
	if what == "coop":
		(scene.get("_world") as Node).call("look_at_facility", "coop")
		await get_tree().process_frame
	var focus_facility := OS.get_environment("SHOT_FOCUS_FACILITY")
	if focus_facility != "" and what != "bear" and what != "home":
		(scene.get("_world") as Node).call("look_at_facility", focus_facility)
		await get_tree().process_frame
	print("FarmShot options reduce_motion=", SaveManager.get_setting("reduce_motion", false),
		" focus_facility=", focus_facility)
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
	# Static reduced-motion scenes may not emit a fresh frame_post_draw.
	# Submit the tree changes, then request a draw instead of waiting forever.
	for _frame in range(3):
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	var rendered := ProbeLifecycle.image_has_content(image)
	var save_error := image.save_png(out)
	print("farm_shot -> ", error_string(save_error))
	if what == "daily_board":
		_daily_check(rendered, "daily board screenshot contains rendered content")
		_daily_check(save_error == OK, "daily board PNG was saved")
		for failure in _fixture_failures:
			print("FAIL ", failure)
		print("asked %d questions" % _daily_asked)
		print("DAILY BOARD SHOT ", "PASSED" if _fixture_failures.is_empty() else "FAILED")
	elif not rendered:
		print("FAIL farm screenshot contains no rendered content")
	if what in ["friends", "friends_orders", "friend_thanks", "challenge_picker", "rack", "rack_held",
			"overflow_many", "overflow_collection",
			"inventory_full", "inventory_empty", "inventory_upgrade"]:
		for failure in _fixture_failures:
			print("FAIL ", failure)
		print("FARM FRIENDS SHOT ", "PASSED" if _fixture_failures.is_empty() and rendered and save_error == OK else "FAILED")
	await ProbeLifecycle.finish(self, 0 if rendered and save_error == OK and _fixture_failures.is_empty() else 1)


func _daily_check(condition: bool, label: String) -> void:
	_daily_asked += 1
	if not condition:
		_fixture_failures.append(label)


func _overflow_check(condition: bool, label: String) -> void:
	_overflow_asked += 1
	if not condition:
		_fixture_failures.append(label)


func _overflow_tap(at: Vector2) -> void:
	# Input.parse_input_event receives window pixels, as in GardenTouchProbe.
	var view := get_viewport().get_visible_rect().size
	var window_size := Vector2(get_window().size)
	var glass := Vector2(at.x * window_size.x / view.x, at.y * window_size.y / view.y)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = glass
	touch.pressed = true
	Input.parse_input_event(touch)
	await get_tree().process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = glass
	touch.pressed = false
	Input.parse_input_event(touch)
	await get_tree().process_frame
	await get_tree().process_frame


func _overflow_save(name: String) -> void:
	RenderingServer.force_draw(false)
	var path := OS.get_environment("SHOT_DIR").path_join(name + ".png")
	var image := get_viewport().get_texture().get_image()
	_overflow_check(ProbeLifecycle.image_has_content(image), "overflow screenshot contains rendered content: " + name)
	var saved := image.save_png(path)
	_overflow_check(saved == OK, "overflow PNG saved: " + name)
	print("overflow_shot -> ", path, " ", error_string(saved))


func _overflow_flight(scene: Node, node_name: String, destination: String,
		amount: int, at: Vector2) -> void:
	var flight := scene.find_child(node_name, true, false) as Control
	_overflow_check(flight != null, "the real receipt flight exists: " + node_name)
	if flight == null:
		return
	_overflow_check(int(flight.get_meta("amount", 0)) == amount
		and str(flight.get_meta("destination", "")) == destination,
		"the receipt flight carries the real split amount and destination")
	var target: Vector2 = flight.get_meta("destination_at", Vector2.INF)
	_overflow_check(target.distance_to(at) < 0.5, "the receipt heads to its visible destination")
	_overflow_check(get_viewport().get_visible_rect().encloses(flight.get_global_rect()),
		"the in-flight crop remains inside the viewport")
	print("OVERFLOW RECEIPT ", node_name, " amount=", amount, " destination=", target)


func _overflow_sequence(scene: Node) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	_overflow_check(not directory.is_empty() and directory.is_absolute_path(), "SHOT_DIR is explicit and absolute")
	if directory.is_empty() or not directory.is_absolute_path():
		return
	_overflow_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "overflow output directory exists")
	var amount := int(GameData.get_crop("carrot").get("harvest_amount", 0))
	var bed: Vector2 = scene.call("_bed_centre", 4)
	await _overflow_tap(bed)
	await get_tree().create_timer(0.22).timeout
	var shortcut := scene.find_child("BarnShortcut", true, false) as Control
	var basket := scene.find_child("HarvestOverflowBasket", true, false) as Control
	_overflow_check(shortcut != null and basket != null, "both real receipt destinations exist")
	if shortcut == null or basket == null:
		return
	var landing := basket.get_global_rect().get_center()
	_overflow_layout(scene, basket)
	_overflow_check(Barn.count("carrot") == 2 and Barn.count("carrot", Barn.BASKET) == amount - 2,
		"the real partial harvest stores two and spills the remainder")
	_overflow_flight(scene, "HarvestFlight_carrot", "warehouse", 2, shortcut.get_global_rect().get_center())
	_overflow_flight(scene, "HarvestSpillFlight_carrot", Barn.BASKET, amount - 2, landing)
	_overflow_save("partial_flight")
	await get_tree().create_timer(0.3).timeout
	_overflow_check(scene.find_child("HarvestFlight_carrot", true, false) == null
		and scene.find_child("HarvestSpillFlight_carrot", true, false) == null,
		"both partial receipt flights clean up")
	_overflow_save("partial_settled")
	await _overflow_tap(shortcut.get_global_rect().get_center())
	_overflow_check(bool(scene.get("_barn_open")), "the real shortcut opens the barn")
	_overflow_save("partial_barn")
	scene.call("_close_panels")
	await get_tree().process_frame
	await get_tree().process_frame
	var plots: Array = SaveManager.data["farm"]["plots"]
	plots[5] = _bed(5, {"state": Farm.READY, "crop_id": "strawberry",
		"growth_stage": 4, "plant_cycle_id": 52, "planted_at": NOON - 7200})
	scene.call("_rebuild")
	await get_tree().process_frame
	await get_tree().process_frame
	bed = scene.call("_bed_centre", 5)
	await _overflow_tap(bed)
	await get_tree().create_timer(0.22).timeout
	amount = int(GameData.get_crop("strawberry").get("harvest_amount", 0))
	_overflow_check(Barn.count("strawberry") == 0 and Barn.count("strawberry", Barn.BASKET) == amount,
		"the real full harvest sends every strawberry to the basket")
	_overflow_check(scene.find_child("HarvestFlight_strawberry", true, false) == null,
		"a full barn has no false warehouse flight")
	_overflow_flight(scene, "HarvestSpillFlight_strawberry", Barn.BASKET, amount, landing)
	basket = scene.find_child("HarvestOverflowBasket", true, false) as Control
	_overflow_check(basket != null and int(basket.get_meta("crop_kinds", 0)) == 2,
		"the real basket displays both crop kinds")
	_overflow_check(basket != null and basket.get_global_rect().get_center().distance_to(landing) < 0.5,
		"a new crop row preserves the visible basket landing point")
	if basket != null:
		_overflow_layout(scene, basket)
	_overflow_save("full_flight")
	await get_tree().create_timer(0.3).timeout
	_overflow_check(scene.find_child("HarvestSpillFlight_strawberry", true, false) == null,
		"the full spill receipt flight cleans up")
	_overflow_save("full_settled")
	shortcut = scene.find_child("BarnShortcut", true, false) as Control
	if shortcut != null:
		await _overflow_tap(shortcut.get_global_rect().get_center())
	_overflow_check(bool(scene.get("_barn_open")), "the full barn opens through its real shortcut")
	_overflow_save("full_barn")


func _overflow_layout(scene: Node, basket: Control) -> void:
	var door := scene.find_child("DecoDoor", true, false) as Control
	var next_task := scene.find_child("NextTask", true, false) as Control
	_overflow_check(door != null, "the real decoration door exists")
	_overflow_check(next_task != null, "the real task ribbon exists")
	_overflow_check(door != null and not door.get_global_rect().intersects(basket.get_global_rect()),
		"the decoration door does not hide the overflow basket")
	_overflow_check(door != null and get_viewport().get_visible_rect().encloses(door.get_global_rect()),
		"the moved decoration door stays fully in the viewport")
	_overflow_check(door != null and next_task != null and not door.get_global_rect().intersects(next_task.get_global_rect()),
		"the decoration door does not hide the task ribbon")
	if OS.get_environment("SHOT_FULL_RACK") == "1":
		var seeds := scene.find_children("GardenSeed_*", "Button", true, false)
		_overflow_check(seeds.size() == GameData.crops.size(),
			"the compact rack shows all fourteen real crops beside the overflow basket")
		var buttons: Dictionary = scene.get("_panel_buttons")
		var arrow := buttons.get("rack_next") as Control
		_overflow_check(arrow == null, "all current seeds fit without an extra page control")
		for seed in seeds:
			_overflow_check(get_viewport().get_visible_rect().encloses(seed.get_global_rect())
				and not seed.get_global_rect().intersects(basket.get_global_rect()),
				"each compact seed target stays visible and clear of the overflow basket")


func _validate_daily_board(scene: Node) -> void:
	_daily_check(bool(scene.get("_orders_open")), "the actual orders board is open")
	var daily: Dictionary = SaveManager.data["farm"].get("dailies", {})
	_daily_check(Dailies.claimed(daily, Dailies.task_by_id("water")),
		"water has today's real claim key")
	_daily_check(not Dailies.claimed(daily, Dailies.task_by_id("harvest")),
		"harvest remains unclaimed")
	_daily_check(not Dailies.done(daily, Dailies.task_by_id("deliver")),
		"delivery remains unfinished")
	var view := get_viewport().get_visible_rect()
	for task in GameData.garden_dailies:
		var task_id := str(task.get("id", ""))
		var job := scene.find_child("DailyJob_" + task_id, true, false) as Button
		_daily_check(is_instance_valid(job), "real job button exists: " + task_id)
		if not is_instance_valid(job):
			continue
		_daily_check(job.disabled == (not Dailies.done(daily, task) or Dailies.claimed(daily, task)),
			"button state matches the daily manager: " + task_id)
		_daily_check(view.encloses(job.get_global_rect()),
			"job button stays inside the viewport: " + task_id)


func _bed(index: int, fields: Dictionary) -> Dictionary:
	var plot: Dictionary = Farm.fresh_plot(index)
	for key in fields.keys():
		plot[key] = fields[key]
	return plot
