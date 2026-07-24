extends Node
## All progress lives on this device in user://save_game.json.
## No account, no server, no analytics, no network calls anywhere in this game.

signal progress_changed()

const SAVE_PATH := "user://save_game.json"
const SAVE_VERSION := 1

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
		},
		"settings": {
			"locale": "en",
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"voice_volume": 1.0,
			"daily_limit_minutes": 30,
			# Some children find particles and bouncing genuinely unpleasant.
			"reduce_motion": false,
		},
		# level_id -> {stars, best_accuracy, attempts, completed}
		"levels": {},
		"rewards": {
			"coins": 0,
			"badges": [],
			"stickers": [],
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
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		save_game()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		data = _migrate(parsed)
	else:
		push_warning("SaveManager: save file unreadable, starting fresh")
		data = _default_data()
		save_game()


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


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save file")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


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
		"stars": 0, "best_accuracy": 0.0, "attempts": 0, "completed": false
	})


## Stars only ever go up. A worse run never erases what the child already earned.
func record_level_result(level_id: String, stars: int, accuracy: float) -> void:
	var prev := get_level_progress(level_id)
	data["levels"][level_id] = {
		"stars": maxi(prev.get("stars", 0), stars),
		"best_accuracy": maxf(prev.get("best_accuracy", 0.0), accuracy),
		"attempts": int(prev.get("attempts", 0)) + 1,
		"completed": true,
	}
	save_game()
	progress_changed.emit()


func total_stars() -> int:
	var sum := 0
	for level_id in data["levels"].keys():
		sum += int(data["levels"][level_id].get("stars", 0))
	return sum


func is_level_unlocked(level_id: String) -> bool:
	var level := GameData.get_level(level_id)
	if level.is_empty():
		return false
	var requires: String = level.get("requires", "")
	if requires == "":
		return true
	return get_level_progress(requires).get("completed", false)


# --- rewards ---

func add_coins(amount: int) -> void:
	data["rewards"]["coins"] = int(data["rewards"]["coins"]) + amount
	save_game()


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


# --- playtime, for the Parent Center ---

func add_playtime(seconds: float) -> void:
	var today := Time.get_date_string_from_system()
	data["playtime"][today] = float(data["playtime"].get(today, 0.0)) + seconds
	save_game()


func playtime_today() -> float:
	return float(data["playtime"].get(Time.get_date_string_from_system(), 0.0))
