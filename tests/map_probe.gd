extends Node
## Can a child actually GET INTO a level from the map?
##
## Written because the father reported that picking a level in 怪兽擂台
## errors, and every test written so far reaches the levels the way a
## programmer does -- instantiating the scene with the id already set. The
## map is the only door a child has, and it was the one door nobody opened.
##
## It also plays a save file from BEFORE the rebuild, full of level ids that
## no longer exist. That is the state every existing player is in, and it is
## the state none of the tests were in.

var _out: Array[String] = []


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	await get_tree().process_frame

	print("\n=== map probe ===")
	_plant_an_old_save()
	await _open_the_map()
	await _press_every_first_level()

	for f in _out:
		print("FAIL  %s" % f)
	print("MAP PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## The save a child who has been playing since spring actually has: stars and
## completions against fifty-four levels that were deleted this afternoon.
func _plant_an_old_save() -> void:
	for old_id in ["hero_city_01", "hero_city_02", "piglet_town_01",
			"safety_traffic_01", "monster_arena_04", "bluey_park_02",
			"star_trials_05", "adventure_valley_01", "hero_city_challenge"]:
		SaveManager.data["levels"][old_id] = {
			"completed": true, "stars": 3, "best_score": 12,
		}
	SaveManager.data["challenges"] = {"hero_city_challenge": 2}
	SaveManager.data["rewards"]["coins"] = 240
	print("  planted a pre-rebuild save: %d levels, %d of them gone" % [
		SaveManager.data["levels"].size(), 9])
	# Reading the totals must not care that the ids are strangers.
	var stars: int = SaveManager.total_stars()
	print("  total stars still readable: %d" % stars)
	_ok(stars >= 27, "an old save's stars vanished (%d)" % stars)


func _open_the_map() -> void:
	var map: Node = load("res://scenes/map/WorldMap.tscn").instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	print("  map built over %d worlds" % GameData.worlds.size())
	map.queue_free()
	await get_tree().process_frame


## EVERY level, entered the way the map enters it.
##
## Not just the first of each world: nine templates and thirty-one levels is
## exactly the situation where one config typo takes down one screen and
## nothing else notices. Building each one and letting it run ten physics
## frames catches the whole class of "it errors the moment you pick it".
func _press_every_first_level() -> void:
	var kinds := {}
	for world in GameData.worlds:
		var world_id := str(world.get("id", ""))
		var levels: Array = GameData.get_levels_for_world(world_id)
		_ok(levels.size() > 0, "world %s has no levels" % world_id)
		if levels.is_empty():
			continue
		_ok(SaveManager.is_level_unlocked(str(levels[0].get("id", ""))),
			"the first level of %s is locked -- nobody can get in" % world_id)

		var line := "  %-15s" % world_id
		for entry in levels:
			var lid := str(entry.get("id", ""))
			var kind := str(entry.get("game_type", ""))
			kinds[kind] = int(kinds.get(kind, 0)) + 1

			# Everything `GameManager.start_level` checks, without the last
			# line of it -- that one swaps the running scene and would take
			# this probe out of the tree with it.
			_ok(not GameData.get_level(lid).is_empty(),
				"start_level(%s) would find nothing" % lid)
			GameManager.current_level_id = lid
			GameManager.current_world_id = world_id

			var scene_path: String = GameData.get_minigame_scene(kind)
			_ok(scene_path != "" and ResourceLoader.exists(scene_path),
				"%s has no scene for game_type '%s'" % [lid, kind])
			if scene_path == "" or not ResourceLoader.exists(scene_path):
				continue

			var level: Node = load(scene_path).instantiate()
			add_child(level)
			for i in range(10):
				await get_tree().physics_frame
			var alive: bool = is_instance_valid(level)
			_ok(alive, "%s died while building" % lid)
			# Every template must have said what its three stars mean by now,
			# or the result screen has nothing to show.
			if alive and level.get("result") != null:
				_ok((level.result as LevelResult).objective_scoring,
					"%s does not score by objectives" % lid)
			line += " " + kind.substr(0, 4)
			if alive:
				level.queue_free()
			await get_tree().process_frame
		print(line)
	print("  templates in play: %d" % kinds.size())
	for kind in kinds:
		print("     %-20s %d" % [kind, int(kinds[kind])])
	_ok(kinds.size() >= 8,
		"only %d templates are actually used by a level" % kinds.size())
