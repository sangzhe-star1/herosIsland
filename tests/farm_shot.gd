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
		scene.call("_rebuild")
		await get_tree().process_frame
		if what == "board" or what == "thanks":
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

	# SHOT_ZOOM=out presses minus until it stops: the whole-farm overview.
	if OS.get_environment("SHOT_ZOOM") == "out" and what != "bear" \
			and what != "home":
		for i in range(6):
			(scene.get("_world") as Node).call("zoom_by", -1)
		scene.call("_queue_rebuild")

	# Long enough for the dog to have RUN from his kennel to the ripe bed and
	# sat down beside it -- a farm standing at attention is not this farm.
	await get_tree().create_timer(3.4).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("farm_shot -> ", error_string(image.save_png(out)))
	get_tree().quit(0)


func _bed(index: int, fields: Dictionary) -> Dictionary:
	var plot: Dictionary = Farm.fresh_plot(index)
	for key in fields.keys():
		plot[key] = fields[key]
	return plot
