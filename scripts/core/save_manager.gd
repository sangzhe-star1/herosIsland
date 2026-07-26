extends Node
## All progress lives on this device in user://save_game.json.
## No account, no server, no analytics, no network calls anywhere in this game.

signal progress_changed()

const SAVE_PATH := "user://save_game.json"
## The previous good save. Every successful write rotates the current file
## here first, so there is always ONE known-good generation behind us.
const SAVE_BACKUP := "user://save_game.bak"
## Writes land here first, then rename into place. A rename is atomic on
## every platform this game ships to; writing straight over the real file
## was not, and one interrupted write (a child swiping the app away
## mid-save) truncated the file -- which the old loader then "recovered"
## from by overwriting months of stars with a fresh save. That was the
## whole mystery of the vanishing history.
const SAVE_TMP := "user://save_game.tmp"
const SAVE_VERSION := 1

## The autoload order puts SaveManager BEFORE I18n, so the I18n singleton
## does not exist yet while a fresh save is being built. Reading the
## constant off the script itself works whatever the order, and keeps one
## definition of "which language does this island speak".
const I18nScript = preload("res://scripts/core/i18n.gd")

var data: Dictionary = {}


func _ready() -> void:
	print("[autoload] SaveManager starting")
	load_game()
	print("[autoload] SaveManager ok")


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {
			"name": "",
			"character_id": str(GameData.characters.get("default", "light_hero")),
			"created_at": Time.get_unix_time_from_system(),
			# Hero experience: only ever rises, one shared number for the one
			# child. Levels come out of it via hero_level().
			"xp": 0,
			# What the child is wearing, by slot. The outfit rides the CHILD,
			# not the hero: swap heroes and the crown comes along.
			"outfit": {"hat": "", "face": "", "back": ""},
		},
		# Challenge ranks: level_id -> how many times its challenge has been
		# beaten. Each rank makes that challenge a little bigger -- the level
		# system that keeps growing after the hand-made levels run out.
		"challenges": {},
		"settings": {
			"locale": I18nScript.DEFAULT_LOCALE,
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"voice_volume": 1.0,
			"daily_limit_minutes": 30,
			# 0 gentle / 1 normal / 2 brave. Set in the Parent Center; every
			# template scales its own knobs off it (LevelManager.harder).
			"difficulty": 1,
			# Some children find particles and bouncing genuinely unpleasant.
			"reduce_motion": false,
		},
		# level_id -> {stars, best_accuracy, attempts, completed}
		"levels": {},
		"rewards": {
			"coins": 0,
			"badges": [],
			"stickers": [],
			# The star shop: lifetime stars stay untouched (they unlock worlds);
			# spending only raises spent_stars. Items are consumables, id -> count.
			"spent_stars": 0,
			"items": {},
			# Outfit pieces owned (ids). Bought once with coins, kept forever.
			"outfits": [],
			# Every monster the child has met, by id. A collection that grows
			# by PLAYING rather than by buying, which is the only kind this
			# game has -- there is no shop for these and no way to miss one.
			"album": [],
			# What the child MADE. Not a reward and not a score -- the only
			# thing in this file that belongs to them rather than to the
			# game, which is why it is stored whole and never inspected.
			"creations": {},
			# Abilities the hero keeps forever once a chest gives them.
			# Separate from outfits because these change what the child can
			# DO, not what they look like -- and because a skill that is not
			# written down is a skill that vanishes when the tablet sleeps.
			"skills": [],
		},
		# Growth attributes. Displayed as growing plants/flags, never as combat stats.
		"growth": {
			"courage": 0,
			"wisdom": 0,
			"kindness": 0,
			"focus": 0,
			"safety": 0,
		},
		# date string -> seconds played, used by the Parent Center.
		"playtime": {},
	}


func load_game() -> void:
	# Main file first; if it is missing or torn, fall back to the previous
	# good generation. Only when BOTH are gone does the island start over --
	# a torn main file used to start over immediately, taking the child's
	# whole history with it.
	var parsed: Variant = _read_save(SAVE_PATH)
	if parsed == null and FileAccess.file_exists(SAVE_BACKUP):
		parsed = _read_save(SAVE_BACKUP)
		if parsed != null:
			push_warning("SaveManager: main save was torn; recovered from backup")
	if parsed is Dictionary:
		data = _migrate(parsed)
		_settle_after_load()
		return
	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BACKUP):
		push_warning("SaveManager: no readable save found, starting fresh")
	data = _default_data()
	save_game()


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else null


## Fill in any keys added by a later build so old saves never crash the game.
func _migrate(loaded: Dictionary) -> Dictionary:
	var base := _default_data()
	for key in base.keys():
		if not loaded.has(key):
			loaded[key] = base[key]
		elif base[key] is Dictionary and loaded[key] is Dictionary:
			for sub in base[key].keys():
				if not loaded[key].has(sub):
					loaded[key][sub] = base[key][sub]
	loaded["version"] = SAVE_VERSION
	return loaded


## Everything that has to happen once, after a save is loaded and merged.
##
## "Once" is the load-bearing word, and it costs a write: a settlement that
## only happens in memory is re-applied on the next launch, and the launch
## after that. The first cut of the refund below did exactly that -- the
## balance looked right every time and the file never changed, so it would have
## paid out again every morning forever.
func _settle_after_load() -> void:
	if _refund_spent_stars():
		save_game()


func save_game() -> void:
	# Write-to-temp, rotate, rename: at every instant of this sequence there
	# is a complete save on disk somewhere. Interrupt it wherever you like --
	# the worst case is losing the one change being written.
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save file")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BACKUP):
			DirAccess.remove_absolute(SAVE_BACKUP)
		DirAccess.rename_absolute(SAVE_PATH, SAVE_BACKUP)
	DirAccess.rename_absolute(SAVE_TMP, SAVE_PATH)


# --- settings ---

func get_setting(key: String, fallback: Variant = null) -> Variant:
	return data.get("settings", {}).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_game()


# --- profile ---

func get_profile() -> Dictionary:
	return data.get("profile", {})


func set_profile_name(child_name: String) -> void:
	data["profile"]["name"] = child_name
	save_game()


## Which hero the child plays as. Only ids present in data/characters.json are
## accepted, so a corrupt save cannot point the game at a skin that is not there.
func set_character(character_id: String) -> void:
	if not GameData.characters.get("characters", {}).has(character_id):
		return
	data["profile"]["character_id"] = character_id
	save_game()
	progress_changed.emit()


# --- level progress ---

func get_level_progress(level_id: String) -> Dictionary:
	return data["levels"].get(level_id, {
		"stars": 0, "best_accuracy": 0.0, "attempts": 0, "completed": false,
		"found_hidden": false,
	})


## Stars only ever go up. A worse run never erases what the child already earned.
##
## `found_hidden` is remembered for the same reason and works the same way: it
## latches true and stays there, so the 星星币 bonus for finding the hidden gem
## is paid exactly once however many times he replays the level.
func record_level_result(level_id: String, stars: int, accuracy: float,
		found_hidden: bool = false) -> void:
	var prev := get_level_progress(level_id)
	data["levels"][level_id] = {
		"stars": maxi(prev.get("stars", 0), stars),
		"best_accuracy": maxf(prev.get("best_accuracy", 0.0), accuracy),
		"attempts": int(prev.get("attempts", 0)) + 1,
		"completed": true,
		"found_hidden": bool(prev.get("found_hidden", false)) or found_hidden,
	}
	save_game()
	progress_changed.emit()


func total_stars() -> int:
	var sum := 0
	for level_id in data["levels"].keys():
		sum += int(data["levels"][level_id].get("stars", 0))
	return sum


## The one switch that opens the whole island, for testing.
##
## Deliberately a VIEW of the save and never a write to it. Nothing about his
## stars, his completions or his album changes when this goes on or off -- it
## is reversible precisely because it never edited anything. Turn it off and
## the locks are exactly where he left them, to the star.
##
## It lives here rather than in the map because four different places ask
## whether a level is open -- the map, the "next level" button, the island's
## completion ring, the probes -- and a test switch that only some of them
## honour is worse than no switch at all.
const TEST_UNLOCK := "test_unlock_all"


func test_unlock_all() -> bool:
	return bool(get_setting(TEST_UNLOCK, false))


func is_level_unlocked(level_id: String) -> bool:
	var level := GameData.get_level(level_id)
	if level.is_empty():
		return false
	if test_unlock_all():
		return true
	var requires: String = level.get("requires", "")
	if requires == "":
		return true
	return get_level_progress(requires).get("completed", false)


# --- rewards ---

func add_coins(amount: int) -> void:
	data["rewards"]["coins"] = int(data["rewards"]["coins"]) + amount
	save_game()


# --- hero level and challenges ---

const XP_PER_LEVEL := 120


func hero_level() -> int:
	return 1 + int(data["profile"].get("xp", 0)) / XP_PER_LEVEL


## Adds experience and returns how many hero levels that gained (usually 0,
## sometimes 1 -- the result screen throws the party).
func add_xp(amount: int) -> int:
	var before := hero_level()
	data["profile"]["xp"] = int(data["profile"].get("xp", 0)) + maxi(amount, 0)
	save_game()
	return hero_level() - before


func get_challenge_rank(level_id: String) -> int:
	return int(data.get("challenges", {}).get(level_id, 0))


func bump_challenge_rank(level_id: String) -> void:
	data["challenges"][level_id] = get_challenge_rank(level_id) + 1
	save_game()
	progress_changed.emit()


# --- the star shop ------------------------------------------------------
#
# Stars are two things at once: the lifetime achievement count that unlocks
# worlds (total_stars(), which only ever rises) and, since the star shop, a
# spendable allowance. Spending NEVER touches the lifetime count -- it only
# raises rewards.spent_stars -- so buying a potion can never re-lock a world
# or shrink the tally a child is proud of.

## RETIRED. Stars are a score again, and only a score.
##
## These two used to make total_stars() double as a purse: the shop spent
## against `total_stars() - spent_stars`. It never re-locked a world, which was
## the danger its author guarded against -- but a child still saw his star
## count drop after buying a potion, with no way to tell that the number the
## map cares about had not moved.
##
## Everything spendable is 星星币 now (scripts/shop/currency_manager.gd).
## `spent_stars` is refunded coin-for-coin by _refund_spent_stars() on the
## first load after this change, so nobody is a single star worse off.
##
## Left here as a hard error rather than deleted, because a call site that
## quietly went back to spending stars is exactly the regression this whole
## change exists to prevent.
func spend_stars(_amount: int) -> bool:
	push_error("SaveManager.spend_stars() is retired -- 关卡星章 cannot be "
		+ "spent. Use scripts/shop/currency_manager.gd.")
	return false


## One-time: turn a returning child's already-spent stars into 星星币.
##
## He spent them; he should still have the value. Paying it back as coins
## means the change can only ever make him richer, which is the only kind of
## migration worth shipping to somebody's six-year-old.
## Returns whether anything changed, so the caller knows to write it down.
func _refund_spent_stars() -> bool:
	var spent: int = int(data["rewards"].get("spent_stars", 0))
	if spent <= 0:
		return false
	data["rewards"]["coins"] = int(data["rewards"].get("coins", 0)) + spent
	data["rewards"]["spent_stars"] = 0
	print("[save] refunded %d spent stars as 星星币" % spent)
	return true


## Battle items are consumable and counted: bought in the star shop, spent
## in a fight, one at a time.
func item_count(item_id: String) -> int:
	return int(data["rewards"].get("items", {}).get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> void:
	var items: Dictionary = data["rewards"].get("items", {})
	items[item_id] = int(items.get(item_id, 0)) + amount
	data["rewards"]["items"] = items
	save_game()
	progress_changed.emit()


## Items go out only through here, and only if one is really there.
func use_item(item_id: String) -> bool:
	if item_count(item_id) <= 0:
		return false
	data["rewards"]["items"][item_id] = item_count(item_id) - 1
	save_game()
	progress_changed.emit()
	return true


# --- the wardrobe ---------------------------------------------------------

func get_outfit() -> Dictionary:
	return data["profile"].get("outfit", {"hat": "", "face": "", "back": ""})


## --- the monster album ---------------------------------------------------

func has_met(monster_id: String) -> bool:
	return monster_id in data["rewards"].get("album", [])


## Meeting a monster writes it down. Returns true the first time, so a level
## can make a small fuss about it exactly once.
func record_meeting(monster_id: String) -> bool:
	if monster_id == "":
		return false
	if not data["rewards"].has("album"):
		data["rewards"]["album"] = []
	if has_met(monster_id):
		return false
	data["rewards"]["album"].append(monster_id)
	save_game()
	progress_changed.emit()
	return true


func album() -> Array:
	return data["rewards"].get("album", [])


## How much of the island is finished, 0 to 1: stars earned over stars there
## are. The map shows this, because "how far am I" is the one question a
## six-year-old asks about a game that has more than one screen.
func island_completion() -> float:
	var possible := 0
	for level in GameData.levels:
		if str(level.get("id", "")) == "hero_studio":
			continue        # the free-play room has nothing to complete
		possible += 3
	if possible == 0:
		return 0.0
	return clampf(float(total_stars()) / float(possible), 0.0, 1.0)


## --- things the child made -----------------------------------------------

func get_creation(name: String) -> Array:
	return (data["rewards"].get("creations", {}) as Dictionary).get(name, [])


func set_creation(name: String, layout: Array) -> void:
	if not data["rewards"].has("creations"):
		data["rewards"]["creations"] = {}
	data["rewards"]["creations"][name] = layout
	save_game()
	progress_changed.emit()


## --- skills the hero keeps ---------------------------------------------

func has_skill(skill_id: String) -> bool:
	return skill_id in data["rewards"].get("skills", [])


## Grant a skill. Returns true only the FIRST time, so the level can throw a
## party for it exactly once and stay quiet on every replay.
func unlock_skill(skill_id: String) -> bool:
	if skill_id == "":
		return false
	if not data["rewards"].has("skills"):
		data["rewards"]["skills"] = []
	if has_skill(skill_id):
		return false
	data["rewards"]["skills"].append(skill_id)
	save_game()
	progress_changed.emit()
	return true


func has_outfit(outfit_id: String) -> bool:
	return outfit_id in data["rewards"].get("outfits", [])


func add_outfit(outfit_id: String) -> void:
	if outfit_id == "" or has_outfit(outfit_id):
		return
	data["rewards"]["outfits"].append(outfit_id)
	save_game()
	progress_changed.emit()


## Wear a piece (or pass "" to take the slot's piece off). One piece per
## slot: putting on the crown hangs the party hat back on its hook.
func wear_outfit(slot: String, outfit_id: String) -> void:
	var outfit: Dictionary = get_outfit()
	outfit[slot] = outfit_id
	data["profile"]["outfit"] = outfit
	save_game()
	progress_changed.emit()


## Coins go out only through here, and only if they are really there.
func spend_coins(amount: int) -> bool:
	if amount <= 0 or int(data["rewards"]["coins"]) < amount:
		return false
	data["rewards"]["coins"] = int(data["rewards"]["coins"]) - amount
	save_game()
	progress_changed.emit()
	return true


func has_sticker(sticker_id: String) -> bool:
	return sticker_id in data["rewards"]["stickers"]


func add_sticker(sticker_id: String) -> void:
	if sticker_id == "" or has_sticker(sticker_id):
		return
	data["rewards"]["stickers"].append(sticker_id)
	save_game()
	progress_changed.emit()


func add_badge(badge_id: String) -> bool:
	if badge_id == "" or badge_id in data["rewards"]["badges"]:
		return false
	data["rewards"]["badges"].append(badge_id)
	save_game()
	return true


func add_growth(attribute: String, amount: int) -> void:
	if not data["growth"].has(attribute):
		return
	data["growth"][attribute] = int(data["growth"][attribute]) + amount
	save_game()


# --- progress backup: how two devices share one child's history ----------
#
# There is no cloud and no account, on purpose. Instead the Parent Center
# can EXPORT the save as a small file (AirDrop or WeChat it across) and
# IMPORT one found on this device. Import MERGES by best-of -- stars, coins,
# items, badges all take the higher value -- so importing an old file can
# never downgrade anyone, and importing twice never double-counts.

const BACKUP_PREFIX := "heroes_island_progress"


## Writes the backup file and returns its absolute path ("" only if even the
## app's own folder refuses, which means the disk is full or broken).
##
## Order matters, and the first version had it backwards. It wrote straight
## to Downloads and gave up if that failed -- and on macOS it always failed:
## Apple guards Downloads, Documents and Desktop behind TCC, so an app
## without the matching usage-description entitlement is denied silently,
## with no prompt and no explanation. Hence "could not write the backup
## file" on a Mac with plenty of disk.
##
## So: write to user:// first, which no OS permission can take away (macOS
## Application Support, the iPad's own Documents where the Files app can
## see it). THEN try to also drop a copy somewhere friendlier, and report
## that path if it lands. The backup always exists either way.
func export_progress() -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	var file_name := "%s_%04d-%02d-%02d_%02d%02d.json" % [BACKUP_PREFIX,
		stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute]
	var payload := JSON.stringify({
		"heroes_island_backup": true,
		"exported_at": Time.get_datetime_string_from_system(),
		"data": data,
	}, "\t")

	var f := FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write backup to user:// (error %d)"
			% FileAccess.get_open_error())
		return ""
	f.store_string(payload)
	f.close()
	var written := ProjectSettings.globalize_path("user://" + file_name)

	# The nicety, not the deliverable: a copy where a parent looks first.
	# Failure here is expected on locked-down systems and costs nothing.
	for kind in [OS.SYSTEM_DIR_DOWNLOADS, OS.SYSTEM_DIR_DOCUMENTS]:
		var dir: String = OS.get_system_dir(kind)
		if dir == "" or not DirAccess.dir_exists_absolute(dir):
			continue
		var candidate: String = dir.path_join(file_name)
		var out := FileAccess.open(candidate, FileAccess.WRITE)
		if out == null:
			continue
		out.store_string(payload)
		out.close()
		return candidate
	return written


## Every backup file this device can see, newest first.
func list_backups() -> Array:
	var found: Array = []
	var dirs := [
		OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS),
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
		OS.get_user_data_dir(),
	]
	for dir in dirs:
		if dir == "" or not DirAccess.dir_exists_absolute(dir):
			continue
		for file_name in DirAccess.get_files_at(dir):
			if str(file_name).begins_with(BACKUP_PREFIX) and str(file_name).ends_with(".json"):
				var path: String = dir.path_join(str(file_name))
				found.append({
					"path": path,
					"modified": FileAccess.get_modified_time(path),
				})
	found.sort_custom(func(a, b): return int(a["modified"]) > int(b["modified"]))
	return found


## Merge a backup into this device's save. Returns
## {ok, error?, stars_before, stars_after, path}.
func import_progress(path: String) -> Dictionary:
	var before := total_stars()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not bool(parsed.get("heroes_island_backup", false)) \
			or not (parsed.get("data") is Dictionary):
		return {"ok": false, "error": "bad_file", "stars_before": before,
			"stars_after": before, "path": path}
	_merge_progress(_migrate(parsed["data"]))
	save_game()
	progress_changed.emit()
	return {"ok": true, "stars_before": before, "stars_after": total_stars(),
		"path": path}


## Best-of, field by field. Settings and playtime stay LOCAL -- each device
## keeps its own volume and daily limit; it is the child's achievements
## that travel.
func _merge_progress(theirs: Dictionary) -> void:
	for level_id in theirs.get("levels", {}).keys():
		var t: Dictionary = theirs["levels"][level_id]
		var m: Dictionary = get_level_progress(level_id)
		data["levels"][level_id] = {
			"stars": maxi(int(m.get("stars", 0)), int(t.get("stars", 0))),
			"best_accuracy": maxf(float(m.get("best_accuracy", 0.0)),
				float(t.get("best_accuracy", 0.0))),
			"attempts": maxi(int(m.get("attempts", 0)), int(t.get("attempts", 0))),
			"completed": bool(m.get("completed", false)) or bool(t.get("completed", false)),
		}
	for level_id in theirs.get("challenges", {}).keys():
		data["challenges"][level_id] = maxi(get_challenge_rank(str(level_id)),
			int(theirs["challenges"][level_id]))
	var tr: Dictionary = theirs.get("rewards", {})
	data["rewards"]["coins"] = maxi(int(data["rewards"].get("coins", 0)), int(tr.get("coins", 0)))
	data["rewards"]["spent_stars"] = maxi(int(data["rewards"].get("spent_stars", 0)),
		int(tr.get("spent_stars", 0)))
	for badge in tr.get("badges", []):
		if not badge in data["rewards"]["badges"]:
			data["rewards"]["badges"].append(badge)
	for sticker in tr.get("stickers", []):
		if not sticker in data["rewards"]["stickers"]:
			data["rewards"]["stickers"].append(sticker)
	for outfit in tr.get("outfits", []):
		if not outfit in data["rewards"]["outfits"]:
			data["rewards"]["outfits"].append(outfit)
	for item_id in tr.get("items", {}).keys():
		data["rewards"]["items"][item_id] = maxi(item_count(str(item_id)),
			int(tr["items"][item_id]))
	var tp: Dictionary = theirs.get("profile", {})
	data["profile"]["xp"] = maxi(int(data["profile"].get("xp", 0)), int(tp.get("xp", 0)))
	for attribute in theirs.get("growth", {}).keys():
		if data["growth"].has(attribute):
			data["growth"][attribute] = maxi(int(data["growth"][attribute]),
				int(theirs["growth"][attribute]))


# --- playtime, for the Parent Center ---

func add_playtime(seconds: float) -> void:
	var today := Time.get_date_string_from_system()
	data["playtime"][today] = float(data["playtime"].get(today, 0.0)) + seconds
	save_game()


func playtime_today() -> float:
	return float(data["playtime"].get(Time.get_date_string_from_system(), 0.0))
