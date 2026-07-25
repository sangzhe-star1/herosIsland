extends Node
## Does the Parent Center's difficulty dial actually reach the games?
##
## Boots one level per template at Gentle and again at Brave and compares
## the knob that template is supposed to bend. A dial that changes a saved
## number and nothing else is the easiest bug in the world to ship, and the
## hardest to notice: everything still runs, it is just all the same.

const NORMAL_SETTING := 1

var _failures: Array[String] = []

# scene, level, the field to read, and which way Brave should move it.
const CASES := [
	{"scene": "res://scenes/minigames/collect_energy/CollectEnergy.tscn",
		"level": "hero_city_01", "field": "_spawn_interval", "brave": "lower"},
	{"scene": "res://scenes/minigames/platformer/Platformer.tscn",
		"level": "adventure_valley_01", "field": "_rock_count", "brave": "higher"},
	{"scene": "res://scenes/minigames/light_defense/LightDefense.tscn",
		"level": "star_trials_04", "field": "_speed", "brave": "higher"},
	{"scene": "res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn",
		"level": "safety_traffic_01", "field": "_green_seconds", "brave": "lower"},
	{"scene": "res://scenes/minigames/light_echo/LightEcho.tscn",
		"level": "hero_city_06", "field": "_sequence_max", "brave": "higher"},
	{"scene": "res://scenes/minigames/monster_duel/MonsterDuel.tscn",
		"level": "monster_arena_04", "field": "_goo_interval", "brave": "lower"},
	{"scene": "res://scenes/minigames/monster_battle/MonsterBattle.tscn",
		"level": "monster_arena_01", "field": "_spark_life", "brave": "lower"},
	{"scene": "res://scenes/minigames/keepy_uppy/KeepyUppy.tscn",
		"level": "bluey_park_01", "field": "_drift", "brave": "higher"},
	{"scene": "res://scenes/minigames/animal_rescue/AnimalRescue.tscn",
		"level": "rescue_forest_01", "field": "_trail_length", "brave": "higher"},
	# Pairs, not columns: a 3-pair and a 5-pair board can share a column
	# count, and the pairs are what a child actually has to hold in mind.
	{"scene": "res://scenes/minigames/memory_match/MemoryMatch.tscn",
		"level": "piglet_town_05", "field": "_icons", "brave": "higher"},
	{"scene": "res://scenes/minigames/monster_expedition/MonsterExpedition.tscn",
		"level": "star_trials_01", "field": "_goo_interval", "brave": "lower"},
]


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _read(case: Dictionary, level_setting: int) -> float:
	SaveManager.set_setting("difficulty", level_setting)
	GameManager.current_level_id = str(case["level"])
	var node: Node = load(str(case["scene"])).instantiate()
	add_child(node)
	for i in range(4):
		await get_tree().process_frame
	# An Array field means "how many of them", which is the honest reading
	# for a deck of cards or a pool of monsters.
	var raw: Variant = node.get(str(case["field"]))
	var value: float = float((raw as Array).size()) if raw is Array else float(raw)
	node.queue_free()
	await get_tree().process_frame
	return value


func _ready() -> void:
	print("\n=== difficulty probe ===")
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
	await get_tree().process_frame

	for case in CASES:
		var gentle: float = await _read(case, 0)
		var brave: float = await _read(case, 2)
		var name: String = str(case["level"]) + "." + str(case["field"])
		print("  %-38s gentle=%.2f  brave=%.2f" % [name, gentle, brave])
		match str(case["brave"]):
			"lower":
				_ok(brave < gentle, "%s should be LOWER at Brave" % name)
			"higher":
				_ok(brave > gentle, "%s should be HIGHER at Brave" % name)
			_:
				_ok(brave != gentle, "%s should differ at Brave" % name)

	# Put the dial back and PERSIST it: this probe writes the setting, other
	# probes read it, and a Brave setting left on disk quietly retunes every
	# level the rest of the suite boots.
	SaveManager.set_setting("difficulty", NORMAL_SETTING)
	for f in _failures:
		print("FAIL  %s" % f)
	print("DIFFICULTY PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)
