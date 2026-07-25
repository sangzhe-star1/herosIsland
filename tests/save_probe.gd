extends Node
## Torture test for the save system: earn progress, tear the file the way a
## force-closed tablet tears it, and prove the history survives. This probe
## exists because the game shipped without it and a real child's real stars
## really vanished.

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== save probe ===")
	await get_tree().process_frame

	# A little history worth protecting.
	SaveManager.data = SaveManager._default_data()
	SaveManager.record_level_result("hero_city_01", 3, 1.0)
	SaveManager.add_coins(42)
	SaveManager.add_item("heart_potion")
	var stars_before: int = SaveManager.total_stars()
	_ok(stars_before == 3, "probe setup should bank three stars")

	# Both generations should now exist: the write rotated one back.
	SaveManager.save_game()
	_ok(FileAccess.file_exists(SaveManager.SAVE_PATH), "main save should exist")
	_ok(FileAccess.file_exists(SaveManager.SAVE_BACKUP), "backup save should exist")
	_ok(not FileAccess.file_exists(SaveManager.SAVE_TMP), "no temp file left behind")

	# Tear the main file mid-thought, the force-close way.
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"profi")
	f.close()
	SaveManager.load_game()
	_ok(SaveManager.total_stars() == stars_before,
		"a torn main save must recover the stars from backup")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 42,
		"a torn main save must recover the coins from backup")
	_ok(SaveManager.item_count("heart_potion") == 1,
		"a torn main save must recover the items from backup")

	# And the recovery must immediately re-shelve a good main file.
	SaveManager.save_game()
	var reread: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_ok(reread is Dictionary, "after recovery the main save is whole again")

	# The travel path: export here, "arrive" on a blank device, import,
	# and prove the merge is best-of in both directions.
	var exported := SaveManager.export_progress()
	_ok(exported != "" and FileAccess.file_exists(exported), "export writes a file")
	# Whatever else it manages, a copy must always land in the app's own
	# folder -- the one place no OS permission can refuse. macOS denying
	# Downloads is exactly how the first version came back empty-handed.
	var mirrored := false
	for entry in SaveManager.list_backups():
		if str(entry["path"]).begins_with(OS.get_user_data_dir()):
			mirrored = true
	_ok(mirrored, "a backup copy always exists in the app's own folder")
	SaveManager.data = SaveManager._default_data()
	SaveManager.record_level_result("piglet_town_01", 2, 0.8)   # local-only progress
	SaveManager.add_coins(10)
	var result: Dictionary = SaveManager.import_progress(exported)
	_ok(bool(result.get("ok", false)), "importing a real backup succeeds")
	_ok(SaveManager.total_stars() == 5,
		"merge keeps BOTH sides' levels (3 imported + 2 local)")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 42,
		"merge takes the higher coin count, never the sum")
	_ok(SaveManager.item_count("heart_potion") == 1, "items travel in the backup")
	var garbage := FileAccess.open("user://not_a_backup.json", FileAccess.WRITE)
	garbage.store_string("{\"hello\": 1}")
	garbage.close()
	var refused: Dictionary = SaveManager.import_progress("user://not_a_backup.json")
	_ok(not bool(refused.get("ok", true)), "a random JSON file is refused")
	_ok(SaveManager.total_stars() == 5, "a refused import changes nothing")
	DirAccess.remove_absolute(exported)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://not_a_backup.json"))

	# Only when BOTH generations are gone does the island start over.
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	_ok(SaveManager.total_stars() == 0, "with no saves at all, a true fresh start")

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("SAVE PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)
