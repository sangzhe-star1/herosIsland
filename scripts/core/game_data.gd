extends Node
## Loads all static configuration from res://data/*.json.
## Nothing in the game hardcodes level content -- add levels by editing JSON.

var worlds: Array = []
var levels: Array = []
var rewards: Dictionary = {}
var characters: Dictionary = {}

var _levels_by_id: Dictionary = {}
var _worlds_by_id: Dictionary = {}


func _ready() -> void:
	print("[autoload] GameData starting")
	worlds = _load_json("res://data/worlds.json", [])
	levels = _load_json("res://data/levels.json", [])
	rewards = _load_json("res://data/rewards.json", {})
	characters = _load_json("res://data/characters.json", {})

	for w in worlds:
		_worlds_by_id[w.get("id", "")] = w
	for l in levels:
		_levels_by_id[l.get("id", "")] = l
	print("[autoload] GameData ok: %d worlds, %d levels" % [worlds.size(), levels.size()])


func _load_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing data file %s" % path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: could not parse %s" % path)
		return fallback
	return parsed


## The skin of the character the child currently plays as, or null when its
## resource is missing (SkinnedCharacter then falls back to the drawn hero).
## The single place this lookup happens; levels and screens all come here.
func current_skin() -> CharacterSkin:
	var character_id: String = SaveManager.get_profile().get(
		"character_id", str(characters.get("default", "light_hero"))
	)
	var entry: Dictionary = characters.get("characters", {}).get(character_id, {})
	var path: String = str(entry.get("skin", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as CharacterSkin
	return null


func get_level(level_id: String) -> Dictionary:
	return _levels_by_id.get(level_id, {})


func get_world(world_id: String) -> Dictionary:
	return _worlds_by_id.get(world_id, {})


## Levels belonging to a world, in listed order.
func get_levels_for_world(world_id: String) -> Array:
	var out: Array = []
	for l in levels:
		if l.get("world", "") == world_id:
			out.append(l)
	return out


## The scene that implements a level's game_type. One template serves many levels.
func get_minigame_scene(game_type: String) -> String:
	var map := {
		"traffic_crossing": "res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn",
		"collect_energy": "res://scenes/minigames/collect_energy/CollectEnergy.tscn",
		"item_sorting": "res://scenes/minigames/item_sorting/ItemSorting.tscn",
		"animal_rescue": "res://scenes/minigames/animal_rescue/AnimalRescue.tscn",
		"monster_battle": "res://scenes/minigames/monster_battle/MonsterBattle.tscn",
		"memory_match": "res://scenes/minigames/memory_match/MemoryMatch.tscn",
		"light_echo": "res://scenes/minigames/light_echo/LightEcho.tscn",
		"monster_duel": "res://scenes/minigames/monster_duel/MonsterDuel.tscn",
	}
	return map.get(game_type, "")
