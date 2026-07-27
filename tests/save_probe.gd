extends Node
## Torture test for the save system: earn progress, tear the file the way a
## force-closed tablet tears it, and prove the history survives. This probe
## exists because the game shipped without it and a real child's real stars
## really vanished.

const Coins := preload("res://scripts/shop/currency_manager.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")

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
	Coins.earn(42, "probe setup")
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
	Coins.earn(10, "local-only progress")
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

	# --- what an import must actually bring ---
	#
	# For months this merged stars, coins, badges and experience and nothing
	# else. A parent moving to a new tablet got a child with his score intact
	# and no clothes, an empty 怪兽图鉴, no skills, none of the things he had
	# made and no garden -- with no way to notice and no way back once the old
	# device was wiped.
	SaveManager.data = SaveManager._default_data()
	SaveManager.record_level_result("sunny_park_01", 3, 1.0, true)
	SaveManager.data["rewards"]["album"] = ["stone_cub", "twin_horn"]
	SaveManager.data["rewards"]["skills"] = ["double_jump"]
	SaveManager.data["rewards"]["creations"] = {"base": ["star"]}
	SaveManager.data["shop"]["owned"] = ["hat_crown", "cape_star"]
	SaveManager.data["shop"]["worn"] = {"tiga": {"head": "hat_crown"}}
	SaveManager.data["shop"]["wishlist"] = ["dress_fairy"]
	SaveManager.data["shop"]["free_gift_taken"] = true
	SaveManager.data["farm"]["plots"][0]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"][0]["crop_id"] = "carrot"
	SaveManager.data["farm"]["warehouse"] = {"strawberry": 5}
	SaveManager.data["farm_orders"]["delivered"] = ["bear_carrots"]
	SaveManager.data["inventory"] = {"seed_rare": 2}
	SaveManager.save_game()
	var travelled := SaveManager.export_progress()

	# ...arriving on a blank tablet.
	SaveManager.data = SaveManager._default_data()
	SaveManager._settle_after_load()
	SaveManager.import_progress(travelled)

	_ok(SaveManager.data["rewards"]["album"].size() == 2,
		"a backup carries the 怪兽图鉴")
	_ok(SaveManager.data["rewards"]["skills"].size() == 1, "...and the skills")
	_ok(SaveManager.data["rewards"]["creations"].has("base"),
		"...and the things he made")
	_ok(SaveManager.data["shop"]["owned"].size() == 2,
		"...and every 星星币 he ever spent on clothes")
	_ok(str(SaveManager.data["shop"]["worn"].get("tiga", {}).get("head", ""))
			== "hat_crown", "...and what each hero was wearing")
	_ok(SaveManager.data["shop"]["wishlist"].size() == 1, "...and the wish list")
	_ok(str(SaveManager.data["farm"]["plots"][0].get("crop_id", "")) == "carrot",
		"...and the carrot that was in the ground")
	_ok(Barn.count("strawberry") == 5, "...and what was in the barn")
	_ok("bear_carrots" in SaveManager.data["farm_orders"]["delivered"],
		"...and which orders were already paid for, so none can be paid twice")
	_ok(int(SaveManager.data["inventory"].get("seed_rare", 0)) == 2,
		"...and the seeds")
	_ok(bool(SaveManager.data["shop"]["free_gift_taken"]),
		"and two devices do not add up to two free gifts")

	# The other half: a merge must not overwrite what THIS device has.
	SaveManager.data = SaveManager._default_data()
	SaveManager.data["rewards"]["creations"] = {"base": ["local_thing"]}
	SaveManager.data["shop"]["worn"] = {"tiga": {"head": "cap_cloud"}}
	SaveManager.data["farm"]["plots"][0]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"][0]["crop_id"] = "tomato"
	SaveManager.import_progress(travelled)
	_ok(str(SaveManager.data["rewards"]["creations"]["base"][0]) == "local_thing",
		"an import never paints over something he made on THIS device")
	_ok(str(SaveManager.data["shop"]["worn"]["tiga"]["head"]) == "cap_cloud",
		"...nor over what a hero is wearing here")
	_ok(str(SaveManager.data["farm"]["plots"][0]["crop_id"]) == "tomato",
		"...nor over a garden with something growing in it")
	_ok(SaveManager.data["shop"]["owned"].size() == 2,
		"but the clothes still travel")
	DirAccess.remove_absolute(travelled)

	# --- what an import must not quietly undo ---
	#
	# found_hidden is a latch: it turns true when the child finds the hidden gem
	# and never turns back, which is what stops the 5 星星币 bonus being paid a
	# second time. _merge_progress rewrites the whole level entry, and it used to
	# rewrite it without this field -- so one trip through the Parent Center's
	# import reset the latch on EVERY level and the bonus became repeatable.
	SaveManager.data = SaveManager._default_data()
	SaveManager.record_level_result("sunny_park_01", 3, 1.0, true)
	SaveManager._merge_progress({"levels": {"sunny_park_01": {
		"stars": 2, "best_accuracy": 0.5, "attempts": 1,
		"completed": true, "found_hidden": false,
	}}})
	_ok(bool(SaveManager.get_level_progress("sunny_park_01").get("found_hidden", false)),
		"importing a backup must not reset found_hidden -- the gem bonus pays once")

	# --- a save of the wrong SHAPE ---
	#
	# has(key) was the only test, so a rewards that came back as an Array (a
	# hand-edited file, a half-written one, a save from some other build) went
	# straight through and the next data["rewards"]["coins"] read took the game
	# down during autoload -- a grey window with nothing to say.
	var bent: Dictionary = SaveManager._migrate(
		{"version": 1, "rewards": [], "levels": {}, "profile": {}})
	_ok(bent.get("rewards") is Dictionary,
		"a top-level key of the wrong type is replaced, not carried through")
	_ok(bent.get("levels") is Dictionary, "a correctly-typed key is left alone")

	# ...and the tolerance that has to come with it. JSON has ONE number type,
	# so an xp of 359 written as an int comes back as a float. If that counted
	# as damage, every load would reset the child's experience to zero.
	var lived_in := SaveManager._default_data()
	lived_in["profile"]["xp"] = 359
	lived_in["rewards"]["coins"] = 120
	lived_in["levels"]["sunny_park_01"] = {"stars": 3, "best_accuracy": 1.0,
		"attempts": 4, "completed": true, "found_hidden": true}
	lived_in.erase("save_version")
	var round_trip: Dictionary = SaveManager._migrate(
		JSON.parse_string(JSON.stringify(lived_in)))
	_ok(int(round_trip["profile"]["xp"]) == 359,
		"a save that has been to disk and back keeps its xp")
	_ok(int(round_trip["rewards"]["coins"]) == 120, "...and its coins")
	_ok(bool(round_trip["levels"]["sunny_park_01"]["found_hidden"]),
		"...and its hidden gem")
	_ok(int(round_trip.get("save_version", -1)) == 1,
		"a save with no save_version is version 1, not version unknown")

	# Only when BOTH generations are gone does the island start over.
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	_ok(SaveManager.total_stars() == 0, "with no saves at all, a true fresh start")

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("SAVE PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)
