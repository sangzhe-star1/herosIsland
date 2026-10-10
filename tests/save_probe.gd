extends Node
## Torture test for the save system: earn progress, tear the file the way a
## force-closed tablet tears it, and prove the history survives. This probe
## exists because the game shipped without it and a real child's real stars
## really vanished.

const Coins := preload("res://scripts/shop/currency_manager.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const OrderDelivery := preload("res://scripts/garden/farm_order_delivery_controller.gd")
const Pen := preload("res://scripts/garden/farm_pen_manager.gd")
const Maker := preload("res://scripts/garden/farm_maker_manager.gd")

const SETTLEMENT_TIME := 1_800_000_000

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

	# Garden entry owns a larger transaction (growth, dew, dailies, and visit
	# stamps). Settling may update memory without rotating the backup; the owner
	# then writes the combined state exactly once.
	var farm: Dictionary = SaveManager.data["farm"]
	farm["last_seen_at"] = 0
	farm["clock_high_water"] = 0
	SaveManager.data["farm"] = farm
	var marker := "deferred farm settlement must not rotate this backup"
	var marker_file := FileAccess.open(SaveManager.SAVE_BACKUP, FileAccess.WRITE)
	_ok(marker_file != null, "settlement write boundary can be observed")
	if marker_file != null:
		marker_file.store_string(marker)
		marker_file.close()
	GameClock.set_test_now(SETTLEMENT_TIME)
	var settled := SaveManager.settle_farm(false)
	_ok(settled, "deferred settlement reports its in-memory change")
	_ok(int(SaveManager.data["farm"].get("last_seen_at", 0)) == SETTLEMENT_TIME,
		"deferred settlement updates the farm in memory")
	_ok(FileAccess.get_file_as_string(SaveManager.SAVE_BACKUP) == marker,
		"deferred settlement leaves backup rotation to its transaction owner")
	SaveManager.save_game()
	var settled_save: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_ok(settled_save is Dictionary
		and int(settled_save.get("farm", {}).get("last_seen_at", 0)) == SETTLEMENT_TIME,
		"the owner save commits the deferred farm settlement")
	GameClock.clear_test_now()

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
	SaveManager.data["profile"]["name"] = "Ari"
	SaveManager.data["profile"]["character_id"] = "sprout"
	SaveManager.data["profile"]["created_at"] = 1_600_000_000
	SaveManager.data["harvest_checkpoint"] = {
		"level_id": "harvest_12", "order_index": 2,
		"delivered": {"carrot": 4, "corn": 2},
	}
	SaveManager.data["farm"]["plots"][0]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"][0]["crop_id"] = "carrot"
	SaveManager.data["farm"]["warehouse"] = {"strawberry": 5}
	SaveManager.data["farm_orders"]["delivered"] = ["bear_carrots"]
	var recurring_order: Dictionary = {}
	for candidate in GameData.garden_orders:
		if bool(candidate.get("recurring", false)):
			recurring_order = candidate
			break
	_ok(not recurring_order.is_empty(), "the backup fixture has a recurring order")
	var recurring_id := str(recurring_order.get("id", ""))
	var recurring_key := str(recurring_order.get("completion_transaction_key", recurring_id))
	SaveManager.data["farm_orders"]["counts"][recurring_id] = 2
	SaveManager.data["farm_orders"]["recurring_paid"] = [
		"%s:1" % recurring_key, "%s:2" % recurring_key,
	]
	var travel_farm: Dictionary = SaveManager.data["farm"]
	travel_farm["coop"] = {"fed_at": 0, "eggs": 2,
		"ready_started_at": SETTLEMENT_TIME - 120}
	travel_farm["mill"] = {"started_at": SETTLEMENT_TIME + 5, "done": 0}
	travel_farm["cow_shed"] = {"fed_at": 0, "ready": 1}
	travel_farm["beehive"] = {"fed_at": SETTLEMENT_TIME + 20, "ready": 0}
	travel_farm["dailies"] = {"date": "2026-10-10",
		"progress": {"water": 2, "harvest": 1},
		"claimed": ["garden_daily_2026-10-10_water"]}
	travel_farm["last_dew_date"] = "2026-10-10"
	travel_farm["fed_visitor_date"] = "2026-10-10"
	travel_farm["fish_caught_total"] = 5
	travel_farm["last_fish_at"] = SETTLEMENT_TIME + 30
	travel_farm["dog_fetches"] = 6
	travel_farm["dog_tricks"] = ["sit", "roll"]
	travel_farm["last_dog_dig_date"] = "2026-10-10"
	travel_farm["bear_return_visit_pending"] = true
	travel_farm["visit_log"] = [{"who": "bear", "kind": "guest",
		"shared": 1, "star": 1, "at": SETTLEMENT_TIME + 40}]
	travel_farm["master_farmer_achieved"] = true
	travel_farm["last_well_wish_date"] = "2026-10-10"
	var travel_npc: Dictionary = Farm.normalise_npc(travel_farm.get("npc"))
	travel_npc["bear"]["last_share_cycle"] = 5
	travel_npc["bear"]["help_completed_cycle"] = 4
	travel_npc["bear"]["help_owed"] = true
	travel_npc["bear"]["last_sneak_cycle"] = 3
	travel_npc["bear"]["sneak_completed_cycle"] = 3
	travel_npc["rabbit"]["last_share_cycle"] = 6
	travel_npc["rabbit"]["help_completed_cycle"] = 5
	travel_npc["rabbit"]["help_owed"] = true
	travel_farm["npc"] = travel_npc
	SaveManager.data["farm_visitors"] = {
		"bear": {"visits": 3, "claimed": ["visits_3"]},
	}
	SaveManager.data["farm_unlocks"] = {"garden": {"rabbit": true}}
	SaveManager.data["inventory"] = {"seed_rare": 2}
	SaveManager.save_game()
	var travelled := SaveManager.export_progress()

	# ...arriving on a blank tablet.
	SaveManager.data = SaveManager._default_data()
	SaveManager._settle_after_load()
	SaveManager.import_progress(travelled)
	_ok(str(SaveManager.data["profile"].get("name", "")) == "Ari"
			and str(SaveManager.data["profile"].get("character_id", "")) == "sprout"
			and int(SaveManager.data["profile"].get("created_at", 0))
			== 1_600_000_000,
		"a blank tablet receives the child's identity from the backup")
	var imported_checkpoint: Dictionary = SaveManager.data.get(
		"harvest_checkpoint", {})
	_ok(str(imported_checkpoint.get("level_id", "")) == "harvest_12"
			and int(imported_checkpoint.get("order_index", 0)) == 2
			and int(imported_checkpoint.get("delivered", {}).get("carrot", 0)) == 4,
		"an unfinished multi-order harvest challenge resumes after import")
	var imported_farm: Dictionary = SaveManager.data["farm"]
	_ok(int(imported_farm.get("coop", {}).get("eggs", 0)) == 2
			and int(imported_farm.get("mill", {}).get("started_at", 0))
			== SETTLEMENT_TIME + 5
			and int(imported_farm.get("cow_shed", {}).get("ready", 0)) == 1
			and int(imported_farm.get("beehive", {}).get("fed_at", 0))
			== SETTLEMENT_TIME + 20,
		"pen and mill outputs and active timers travel to a blank tablet")
	_ok(str(imported_farm.get("dailies", {}).get("date", "")) == "2026-10-10"
			and int(imported_farm.get("dailies", {}).get("progress", {})
			.get("water", 0)) == 2
			and "garden_daily_2026-10-10_water"
			in imported_farm.get("dailies", {}).get("claimed", []),
		"today's task progress and claimed reward travel together")
	_ok(str(imported_farm.get("last_dew_date", "")) == "2026-10-10"
			and str(imported_farm.get("fed_visitor_date", "")) == "2026-10-10"
			and str(imported_farm.get("last_dog_dig_date", "")) == "2026-10-10"
			and str(imported_farm.get("last_well_wish_date", "")) == "2026-10-10",
		"daily dew, feeding, digging, and wishing guards travel")
	_ok(int(imported_farm.get("fish_caught_total", 0)) == 5
			and int(imported_farm.get("last_fish_at", 0)) == SETTLEMENT_TIME + 30
			and int(imported_farm.get("dog_fetches", 0)) == 6
			and ["sit", "roll"] == imported_farm.get("dog_tricks", [])
			and bool(imported_farm.get("master_farmer_achieved", false)),
		"fish, dog growth, and the level-eight milestone travel")
	var imported_npc: Dictionary = Farm.normalise_npc(imported_farm.get("npc"))
	_ok(bool(imported_farm.get("bear_return_visit_pending", false))
			and bool(imported_npc["bear"].get("help_owed", false))
			and not bool(imported_npc["bear"].get("sneak_owed", true))
			and bool(imported_npc["rabbit"].get("help_owed", false)),
		"friend promises and the bear's return request survive import")
	_ok(int(SaveManager.data.get("farm_visitors", {}).get("bear", {})
			.get("visits", 0)) == 3
			and "visits_3" in SaveManager.data.get("farm_visitors", {})
			.get("bear", {}).get("claimed", [])
			and bool(SaveManager.data.get("farm_unlocks", {}).get("garden", {})
			.get("rabbit", false)),
		"nested visitor and unlock ledgers survive import")

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
	var imported_orders: Dictionary = SaveManager.data["farm_orders"]
	_ok(int(imported_orders.get("counts", {}).get(recurring_id, 0)) == 2,
		"a recurring order's delivery high-water mark travels to a new tablet")
	_ok("%s:1" % recurring_key in imported_orders.get("recurring_paid", [])
			and "%s:2" % recurring_key in imported_orders.get("recurring_paid", []),
		"the recurring once-key ledger travels with its delivery count")
	var recurring_wants: Dictionary = recurring_order.get("requirements", {})
	for item_id in recurring_wants.keys():
		Barn.put(str(item_id), int(recurring_wants[item_id]))
	var third_delivery := OrderDelivery.settle(recurring_order, imported_orders)
	_ok(bool(third_delivery.get("settled", false))
			and int(imported_orders.get("counts", {}).get(recurring_id, 0)) == 3,
		"the imported counter continues at delivery three")
	_ok("%s:3" % recurring_key in imported_orders.get("recurring_paid", []),
		"the continued delivery receives a distinct third receipt key")
	SaveManager.save_game()
	SaveManager.load_game()
	imported_orders = SaveManager.data["farm_orders"]
	_ok(int(imported_orders.get("counts", {}).get(recurring_id, 0)) == 3
			and "%s:3" % recurring_key in imported_orders.get("recurring_paid", []),
		"the continued recurring receipt survives a disk reload")
	_ok(int(SaveManager.data["inventory"].get("seed_rare", 0)) == 2,
		"...and the seeds")
	_ok(bool(SaveManager.data["shop"]["free_gift_taken"]),
		"and two devices do not add up to two free gifts")
	imported_farm = SaveManager.data["farm"]
	imported_npc = Farm.normalise_npc(imported_farm.get("npc"))
	_ok(int(imported_farm.get("coop", {}).get("eggs", 0)) == 2
			and int(imported_farm.get("mill", {}).get("started_at", 0))
			== SETTLEMENT_TIME + 5
			and int(imported_farm.get("dailies", {}).get("progress", {})
			.get("water", 0)) == 2
			and bool(imported_npc["rabbit"].get("help_owed", false))
			and int(SaveManager.data.get("farm_visitors", {}).get("bear", {})
			.get("visits", 0)) == 3,
		"imported farm state and nested ledgers survive disk reload")

	# The other half: a merge must not overwrite what THIS device has.
	SaveManager.data = SaveManager._default_data()
	SaveManager.data["profile"]["name"] = "Mina"
	SaveManager.data["profile"]["character_id"] = "zero"
	SaveManager.data["harvest_checkpoint"] = {
		"level_id": "harvest_12", "order_index": 3,
		"delivered": {"corn": 5},
	}
	SaveManager.data["rewards"]["creations"] = {"base": ["local_thing"]}
	SaveManager.data["shop"]["worn"] = {"tiga": {"head": "cap_cloud"}}
	SaveManager.data["farm"]["plots"][0]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"][0]["crop_id"] = "tomato"
	SaveManager.data["farm"]["coop"] = {"fed_at": SETTLEMENT_TIME + 100,
		"eggs": 1}
	SaveManager.data["farm"]["dailies"] = {"date": "2026-10-10",
		"progress": {"water": 3},
		"claimed": ["garden_daily_2026-10-10_deliver"]}
	SaveManager.data["farm_visitors"] = {"bear": {"visits": 4,
		"claimed": ["visits_4"]}}
	SaveManager.data["farm_unlocks"] = {
		"garden": {"rabbit": false, "puppy": true}}
	SaveManager.data["farm_orders"]["counts"][recurring_id] = 4
	SaveManager.data["farm_orders"]["recurring_paid"] = [
		"%s:3" % recurring_key, "%s:4" % recurring_key,
		"local_only_receipt",
	]
	SaveManager.import_progress(travelled)
	_ok(str(SaveManager.data["rewards"]["creations"]["base"][0]) == "local_thing",
		"an import never paints over something he made on THIS device")
	_ok(str(SaveManager.data["shop"]["worn"]["tiga"]["head"]) == "cap_cloud",
		"...nor over what a hero is wearing here")
	_ok(str(SaveManager.data["farm"]["plots"][0]["crop_id"]) == "tomato",
		"...nor over a garden with something growing in it")
	_ok(str(SaveManager.data["profile"].get("name", "")) == "Mina"
			and str(SaveManager.data["profile"].get("character_id", "")) == "zero",
		"an import preserves the name and hero already chosen on this tablet")
	var merged_checkpoint: Dictionary = SaveManager.data.get(
		"harvest_checkpoint", {})
	_ok(int(merged_checkpoint.get("order_index", 0)) == 3
			and int(merged_checkpoint.get("delivered", {}).get("corn", 0)) == 5,
		"the more advanced local harvest checkpoint remains resumable")
	var merged_farm_state: Dictionary = SaveManager.data["farm"]
	_ok(int(merged_farm_state.get("coop", {}).get("eggs", 0)) == 2
			and int(merged_farm_state.get("coop", {}).get("fed_at", 0))
			== 0
			and int(merged_farm_state.get("coop", {}).get("pending_fed_at", 0))
			== SETTLEMENT_TIME + 100,
		"a distinct later coop cycle waits behind imported ready output")
	var collected_merged_eggs: Dictionary = Pen.collect(
		merged_farm_state, Pen.COOP, SETTLEMENT_TIME + 101)
	_ok(int(collected_merged_eggs.get("amount", 0)) == 2
			and int(merged_farm_state.get("coop", {}).get("fed_at", 0))
			== SETTLEMENT_TIME + 100
			and int(merged_farm_state.get("coop", {}).get("pending_fed_at", 0)) == 0,
		"collecting imported eggs advances to the queued cycle exactly once")
	SaveManager._merge_progress({"farm": {"coop": {
		"fed_at": SETTLEMENT_TIME - 120, "eggs": 0}}})
	_ok(int(merged_farm_state.get("coop", {}).get("fed_at", 0))
			== SETTLEMENT_TIME + 100,
		"a stale timer cannot rearm a cycle that was already completed elsewhere")
	var merged_dailies: Dictionary = merged_farm_state.get("dailies", {})
	_ok(int(merged_dailies.get("progress", {}).get("water", 0)) == 3
			and int(merged_dailies.get("progress", {}).get("harvest", 0)) == 1
			and "garden_daily_2026-10-10_water" in merged_dailies.get("claimed", [])
			and "garden_daily_2026-10-10_deliver" in merged_dailies.get("claimed", []),
		"same-day task progress takes the higher tally and unions claims")
	var merged_visitors: Dictionary = SaveManager.data.get("farm_visitors", {})
	_ok(int(merged_visitors.get("bear", {}).get("visits", 0)) == 4
			and "visits_3" in merged_visitors.get("bear", {}).get("claimed", [])
			and "visits_4" in merged_visitors.get("bear", {}).get("claimed", [])
			and bool(SaveManager.data.get("farm_unlocks", {}).get("garden", {})
			.get("rabbit", false))
			and bool(SaveManager.data.get("farm_unlocks", {}).get("garden", {})
			.get("puppy", false)),
		"nested visitor and unlock ledgers merge without dropping either tablet")
	_ok(SaveManager.data["shop"]["owned"].size() == 2,
		"but the clothes still travel")
	var merged_orders: Dictionary = SaveManager.data["farm_orders"]
	var merged_paid: Array = merged_orders.get("recurring_paid", [])
	_ok(int(merged_orders.get("counts", {}).get(recurring_id, 0)) == 4,
		"merging a backup keeps the larger local recurring count")
	_ok("%s:1" % recurring_key in merged_paid
			and "%s:2" % recurring_key in merged_paid
			and "%s:3" % recurring_key in merged_paid
			and "%s:4" % recurring_key in merged_paid
			and "local_only_receipt" in merged_paid,
		"merging recurring receipts unions both devices without dropping local keys")
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
