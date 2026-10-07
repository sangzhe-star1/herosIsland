extends Node

const OUT_DIR := "/Users/xhzhou/.gemini/antigravity/brain/2a762f9a-01f0-43fc-b355-5a304be9bd77"

var CASES := [
	{"type": "level", "id": "sunny_park_01", "name": "shot_observation_real_3d_v17.png"},
	{"type": "level", "id": "sunny_park_02", "name": "shot_sorting_real_3d_v17.png"},
	{"type": "level", "id": "sunny_park_03", "name": "shot_build_repair_real_3d_v17.png"},
	{"type": "level", "id": "sunny_park_05", "name": "shot_adventure_real_3d_v21.png"},
	{"type": "level", "id": "night_city_02", "name": "shot_puzzle_real_3d_v17.png"},
	{"type": "level", "id": "bonus_blaster", "name": "shot_defense_real_3d_v17.png"},
	{"type": "level", "id": "sunny_park_06", "name": "shot_duel_real_3d_v17.png"},
	{"type": "scene", "path": "res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn", "name": "shot_traffic_real_3d_v17.png"},
	{"type": "level", "id": "harvest_01", "name": "shot_harvest_action_real_3d_v17.png"},
	{"type": "scene", "path": "res://scenes/garden/BearFarm.tscn", "name": "shot_farm_garden_real_3d_v17.png"},
]

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	for case in CASES:
		if case["type"] == "level":
			await _shoot_level(case["id"], case["name"])
		else:
			await _shoot_scene(case["path"], case["name"])
	print("ALL REAL SHOWCASE SCREENSHOTS CAPTURED!")
	get_tree().quit(0)

func _shoot_level(level_id: String, file_name: String) -> void:
	var def: Dictionary = GameData.get_level(level_id)
	if def.is_empty():
		print("Unknown level: ", level_id)
		return
	var game_type: String = str(def.get("game_type", ""))
	var scene_path: String = GameData.get_minigame_scene(game_type)
	if not ResourceLoader.exists(scene_path):
		print("Scene missing: ", scene_path)
		return
	GameManager.current_level_id = level_id
	var scene: PackedScene = load(scene_path)
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in range(18):
		await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, file_name]
	var err := img.save_png(path)
	print("Saved: ", file_name, " (", error_string(err), ")")
	remove_child(inst)
	inst.queue_free()
	for i in range(6):
		await get_tree().process_frame

func _shoot_scene(scene_path: String, file_name: String) -> void:
	GameManager.current_level_id = "traffic_demo"
	var scene: PackedScene = load(scene_path)
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in range(18):
		await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, file_name]
	var err := img.save_png(path)
	print("Saved: ", file_name, " (", error_string(err), ")")
	remove_child(inst)
	inst.queue_free()
	for i in range(6):
		await get_tree().process_frame
