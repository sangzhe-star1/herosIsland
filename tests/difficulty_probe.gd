extends Node
## Does the Parent Center's difficulty dial actually reach the games?
##
## Boots one level per template at Gentle and again at Brave and compares
## the knob that template is supposed to bend. A dial that changes a saved
## number and nothing else is the easiest bug in the world to ship, and the
## hardest to notice: everything still runs, it is just all the same.

const NORMAL_SETTING := 1
## 2026-07-30 实测：十一个模板里有七个一关都没有。见 _ready() 结尾。
const HOMELESS_TODAY := 7

var _failures: Array[String] = []

# 模板、要读的那个旋钮、Brave 该往哪边走。
#
# 这里**不写关卡 id**，写模板名。原来十一个 case 各写一个 id，而那十一个 id
# 一个都不存在了 —— GameManager 找不到关卡就交出空 config，于是每个 case 都在
# 拿默认值和默认值比。它证明的是 harder() 这个函数会算术，不是任何一关真的
# 会随难度档变。整套检查亮了很久的绿灯，量的却是空气。
#
# 改成运行时按 game_type 去 GameData 里找一关真的在用这个模板的。关卡改名、
# 重排、增删都不会再让这个探针变瞎；而一个模板如果一关都没有，下面会**大声
# 说出来**，不会假装测过。
const CASES := [
	{"type": "collect_energy",
		"scene": "res://scenes/minigames/collect_energy/CollectEnergy.tscn",
		"field": "_spawn_interval", "brave": "lower"},
	{"type": "platformer",
		"scene": "res://scenes/minigames/platformer/Platformer.tscn",
		"field": "_rock_count", "brave": "higher"},
	{"type": "light_defense",
		"scene": "res://scenes/minigames/light_defense/LightDefense.tscn",
		"field": "_speed", "brave": "higher"},
	{"type": "traffic_crossing",
		"scene": "res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn",
		"field": "_green_seconds", "brave": "lower"},
	{"type": "light_echo",
		"scene": "res://scenes/minigames/light_echo/LightEcho.tscn",
		"field": "_sequence_max", "brave": "higher"},
	{"type": "monster_duel",
		"scene": "res://scenes/minigames/monster_duel/MonsterDuel.tscn",
		"field": "_goo_interval", "brave": "lower"},
	{"type": "monster_battle",
		"scene": "res://scenes/minigames/monster_battle/MonsterBattle.tscn",
		"field": "_spark_life", "brave": "lower"},
	{"type": "keepy_uppy",
		"scene": "res://scenes/minigames/keepy_uppy/KeepyUppy.tscn",
		"field": "_drift", "brave": "higher"},
	{"type": "animal_rescue",
		"scene": "res://scenes/minigames/animal_rescue/AnimalRescue.tscn",
		"field": "_trail_length", "brave": "higher"},
	# Pairs, not columns: a 3-pair and a 5-pair board can share a column
	# count, and the pairs are what a child actually has to hold in mind.
	{"type": "memory_match",
		"scene": "res://scenes/minigames/memory_match/MemoryMatch.tscn",
		"field": "_icons", "brave": "higher"},
	{"type": "monster_expedition",
		"scene": "res://scenes/minigames/monster_expedition/MonsterExpedition.tscn",
		"field": "_goo_interval", "brave": "lower"},
]


## 一关真的在用这个模板的，挑 config 最丰富的那一关 —— 一个 config 空空的
## 关卡等于还是在量默认值。一关都没有就返回空字符串。
static func a_level_using(game_type: String) -> String:
	var best := ""
	var richest := -1
	for entry in GameData.levels:
		if str(entry.get("game_type", "")) != game_type:
			continue
		var size: int = (entry.get("config", {}) as Dictionary).size()
		if size > richest:
			richest = size
			best = str(entry.get("id", ""))
	return best


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _read(case: Dictionary, level_id: String, level_setting: int) -> float:
	SaveManager.set_setting("difficulty", level_setting)
	GameManager.current_level_id = level_id
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

	# 一关都没有的模板。它们不是"测过了"，是"没得测" —— 印出来，而且下面有
	# 一条断言盯着这个数字别再长。一个没有任何关卡的模板要么是待接的内容，
	# 要么是该删的死代码，两者都不该藏在一片绿灯里。
	var homeless: Array[String] = []

	for case in CASES:
		var level_id := a_level_using(str(case["type"]))
		if level_id == "":
			homeless.append(str(case["type"]))
			continue
		var gentle: float = await _read(case, level_id, 0)
		var brave: float = await _read(case, level_id, 2)
		var name: String = level_id + "." + str(case["field"])
		print("  %-38s gentle=%.2f  brave=%.2f" % [name, gentle, brave])
		match str(case["brave"]):
			"lower":
				_ok(brave < gentle, "%s should be LOWER at Brave" % name)
			"higher":
				_ok(brave > gentle, "%s should be HIGHER at Brave" % name)
			_:
				_ok(brave != gentle, "%s should differ at Brave" % name)

	if not homeless.is_empty():
		print("  没有任何关卡在用的模板（难度档对它们无从谈起）：%s"
			% ", ".join(homeless))
	# 上限就是今天实测的数字。多一个就红 —— 那意味着又有一个模板悄悄失去了
	# 全部关卡，而这正是这些 case 当初集体变瞎的过程。
	_ok(homeless.size() <= HOMELESS_TODAY,
		"有 %d 个模板一关都没有（今天是 %d 个）：%s —— 要么把内容接回来，"
		% [homeless.size(), HOMELESS_TODAY, ", ".join(homeless)]
		+ "要么把模板删掉，别留在检查里假装测过")

	# Put the dial back and PERSIST it: this probe writes the setting, other
	# probes read it, and a Brave setting left on disk quietly retunes every
	# level the rest of the suite boots.
	SaveManager.set_setting("difficulty", NORMAL_SETTING)
	for f in _failures:
		print("FAIL  %s" % f)
	print("DIFFICULTY PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)
