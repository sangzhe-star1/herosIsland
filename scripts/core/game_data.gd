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
	worlds = _load_json("res://data/worlds.json", [])
	levels = _load_json("res://data/levels.json", [])
	rewards = _load_json("res://data/rewards.json", {})
	characters = _load_json("res://data/characters.json", {})

	for w in worlds:
		_worlds_by_id[w.get("id", "")] = w
	for l in levels:
		_levels_by_id[l.get("id", "")] = l


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
	}
	return map.get(game_type, "")
