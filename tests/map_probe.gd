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
	await _a_locked_stone_keeps_its_face()
	await _opens_where_he_left_off()
	await _press_every_first_level()

	for f in _out:
		print("FAIL  %s" % f)
	print("MAP PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## A locked level is a promise, not a redaction.
##
## The playtest complaint the markers were built on was "the icons are all the
## same, I don't know what's inside" -- and replacing every locked stone's
## picture with the same yellow padlock had quietly reintroduced it for every
## level a child had not reached yet. The stone must keep its (dimmed) type
## picture, wear the lock as a corner badge, and ANSWER a tap with a shake
## instead of opening or going dead: a disabled button that eats the press and
## says nothing is, to a six-year-old, a broken screen.
func _a_locked_stone_keeps_its_face() -> void:
	# A fresh save, so most of the island is locked.
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	var map: Node = load("res://scenes/map/WorldMap.tscn").instantiate()
	add_child(map)
	for i in range(6):
		await get_tree().process_frame

	var checked := 0
	var scene_before: Node = get_tree().current_scene
	for stone in _stones_in(map):
		if not (stone as Button).disabled:
			continue
		checked += 1
		var lock: Node = stone.get_node_or_null("LockBadge")
		_ok(lock != null, "a locked stone has no lock badge in its corner")
		var veil: Node = stone.get_node_or_null("LockedAnswer")
		_ok(veil != null, "a locked stone has no answer to a tap -- disabled "
			+ "buttons eat the press and say nothing")
		var dimmed := false
		for child in stone.get_children():
			if child is Control and child.name != "LockBadge" \
					and child.name != "LockedAnswer" \
					and (child as Control).modulate.a < 0.8:
				dimmed = true
		_ok(dimmed, "a locked stone shows no dimmed type picture -- five locks "
			+ "in a row are five identical stones again")
		if veil != null:
			# The answer must never be a door. Push a press through the
			# veil's own handler and assert nothing navigated.
			var press := InputEventScreenTouch.new()
			press.pressed = true
			press.position = Vector2(10, 10)
			veil.emit_signal("gui_input", press)
			await get_tree().process_frame
			_ok(get_tree().current_scene == scene_before,
				"tapping a locked stone opened something")
		if checked >= 3:
			break
	print("  locked stones checked: %d (badge + dimmed face + answered tap)" % checked)
	_ok(checked > 0, "a fresh save had no locked stones to check -- this "
		+ "probe tested nothing")
	map.queue_free()
	await get_tree().process_frame


func _stones_in(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Button and (child as Control).custom_minimum_size.x >= 140.0:
			out.append(child)
		out.append_array(_stones_in(child))
	return out


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
			# Every CURRICULUM level must have said what its three stars mean
			# by now, or the result screen has nothing to show.
			#
			# The bonus levels are exempt on purpose. They are arcade treats --
			# keep the balloon up, hit the targets, repeat the tune -- where
			# "how well did you do" genuinely IS the question, and the older
			# count-the-slips star rule says it better than three doors would.
			#
			# Rooms are exempt too, and for a stronger reason: a room does not
			# score AT ALL. There is no version of the garden in which he has
			# done it wrong, so there are no three stars to explain, and making
			# it set a scoring flag it never reads would be state invented to
			# satisfy a test.
			if alive and level.get("result") != null \
					and not bool(entry.get("bonus", false)) \
					and not bool(entry.get("room", false)):
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


## Leaving a level puts him back on that level's island, not on page one.
##
## The map used to always open on the "frontier" -- the first page holding an
## unfinished level -- which is right when he arrives from the home screen and
## wrong the moment he backs out of a level. He would leave the castle and land
## in the park, four swipes from where he had been standing two seconds
## earlier. With the parent's unlock switch on it was every single time, because
## then every level is unfinished and the frontier is always page one.
func _opens_where_he_left_off() -> void:
	var worlds: Array = GameData.worlds.duplicate()
	worlds.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	for expected in range(worlds.size()):
		var world_id := str(worlds[expected].get("id", ""))
		GameManager.current_world_id = world_id
		var map: Control = load("res://scenes/map/WorldMap.tscn").instantiate()
		add_child(map)
		await get_tree().process_frame
		var page: int = int(map.get("_page"))
		print("  left %-16s -> map opens on page %d (want %d)"
			% [world_id, page, expected])
		_ok(page == expected,
			"leaving %s opens the map on page %d, not %d"
				% [world_id, page, expected])
		map.queue_free()
		await get_tree().process_frame

	# Arriving fresh instead of backing out of a level: no world to return to,
	# so the frontier rule still applies and it must not crash reaching for one.
	GameManager.current_world_id = "safety"          # the boot default
	var fresh: Control = load("res://scenes/map/WorldMap.tscn").instantiate()
	add_child(fresh)
	await get_tree().process_frame
	var fresh_page: int = int(fresh.get("_page"))
	print("  arriving fresh   -> map opens on page %d (the frontier)" % fresh_page)
	_ok(fresh_page >= 0 and fresh_page < worlds.size(),
		"a fresh arrival opened on page %d, which is not a page" % fresh_page)
	fresh.queue_free()
	await get_tree().process_frame
