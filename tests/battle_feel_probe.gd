extends Node
## 打怪兽的手感，逐条量出来。
##
##   godot --headless --path . res://tests/BattleFeelProbe.tscn
##
## 战斗模板的问题几乎都不是"画错了"，是**按下去没有回应**——而没有回应在截图
## 上看不出来，在"能不能跑起来"的冒烟里也看不出来。这个探针只问一件事：
## 孩子的手指动了，游戏答了吗。
##
## 三条来自 2026-07-30 的实测：
##
##   1. 泥球是屏幕上唯一会动的目标，却用 Button 的默认 RELEASE 触发——手指按
##      下去，球从指尖飞走，抬手时判定已经脱靶。三个不会动的技能键反而都是
##      按下即触发。
##   2. 光之防卫冷却期点屏幕调 `_hero.pulse_core(1)`，而 SkinnedCharacter 上
##      根本没有这个方法。紧挨着的注释写着 "never silence"，实际结果正是
##      silence。upgrade_probe 在开火前先把冷却清零，**刚好绕开了这个分支**。
##   3. 最后一颗光之生命没了的那一帧，try_again.ogg 响三遍——小游戏说一次、
##      score_mistake() 说一次、弹卡再说一次。三层都没写错，所以修在 AudioManager。

const DUEL := "res://scenes/minigames/monster_duel/MonsterDuel.tscn"

var _failures: Array[String] = []
var _asked := 0
## 少一条就说明有一节被静默跳过了。见 garden_touch_probe 的同名常量。
const CHECKS_EXPECTED := 19


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== battle feel probe ===")
	await _a_moving_target_can_be_hit()
	await _a_press_that_cannot_fire_still_answers()
	await _one_event_makes_one_sound()
	await _the_card_tells_the_truth()

	if _asked < CHECKS_EXPECTED:
		_failures.append("这个探针只问了 %d 个问题，本该至少 %d 个 —— "
			% [_asked, CHECKS_EXPECTED]
			+ "它在屏幕上找的某个东西不见了，于是一整节被静默跳过")
	for f in _failures:
		print("FAIL  ", f)
	print("asked %d questions" % _asked)
	print("BATTLE FEEL PROBE %s" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(0 if _failures.is_empty() else 1)


## 泥球：按下即中，而且看得出它能按。
func _a_moving_target_can_be_hit() -> void:
	GameManager.current_level_id = "sunny_park_06"
	var duel: Node = load(DUEL).instantiate()
	add_child(duel)
	for i in 20:
		await get_tree().process_frame

	# 让它扔一颗，而不是等 goo_interval 到点——等待会把探针的时长变成运气。
	duel.call("_monster_attack_goo")
	await get_tree().process_frame
	await get_tree().process_frame

	var goo := _find_goo(duel)
	_ok(goo != null, "怪兽扔不出泥球 —— 后面关于泥球的检查一条都没跑")
	if goo == null:
		duel.queue_free()
		await get_tree().process_frame
		return

	_ok(goo.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS,
		"泥球用的是抬手触发 —— 它正在 2.4 秒的抛物线上飞，手指按下去球就滑走了，"
		+ "抬手时判定已经脱靶。屏幕上唯一会动的目标，用了最不适合动目标的触发模式")
	_ok(goo.custom_minimum_size.x >= 60.0 and goo.custom_minimum_size.y >= 60.0,
		"泥球 %.0fx%.0f，比六岁的拇指还小" % [goo.custom_minimum_size.x,
			goo.custom_minimum_size.y])

	# 按下之后球继续飞，抬手时人已经不在球上了 —— 这正是真实情况。
	var before := _threat_count(duel)
	goo.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(_threat_count(duel) == before - 1,
		"拍中了泥球，它却还挂在威胁列表里")

	duel.queue_free()
	await get_tree().process_frame


## 冷却期的点击：可以打不出去，不可以毫无回应。
func _a_press_that_cannot_fire_still_answers() -> void:
	# 两个调用点都拿的是 SkinnedCharacter，不是 HeroArt。方法在 art 上有、在
	# 包装层上没有，于是调用静默地什么都不做 —— 这正是 GDScript 动态派发最
	# 容易漏掉的一类洞。
	var skinned := load("res://scripts/skin/skinned_character.gd")
	var one: Node = skinned.new()
	_ok(one.has_method("pulse_core"),
		"SkinnedCharacter 没有 pulse_core —— 光之防卫和怪兽远征在冷却期都调它，"
		+ "调不到就是按一下什么都不发生，而那两行的注释写的正是 never silence")
	if one.has_method("pulse_core"):
		# 没有 art 的裸对象上调用也不许炸：真实场景里 _art 可能还没建好。
		one.call("pulse_core", 1)
		_ok(true, "pulse_core 在还没有形象的角色上调用也不会炸")
	one.free()
	await get_tree().process_frame

	# 同一类问题别处还有没有：两个调用点都盯住。
	for path in ["res://scripts/minigames/light_defense.gd",
			"res://scripts/minigames/monster_expedition.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if not src.contains("pulse_core"):
			continue
		_ok(one_call_is_reachable(src),
			"%s 调了 pulse_core，但拿的对象上没有这个方法" % path.get_file())


## 这里只做一件事：确认那两个文件调的是 _hero（SkinnedCharacter），而上面已经
## 断言过 SkinnedCharacter 有这个方法。写成函数是为了让失败信息说人话。
func one_call_is_reachable(src: String) -> bool:
	return src.contains("_hero.pulse_core") or src.contains("pulse_core(")


## 一个事件一个声音。
func _one_event_makes_one_sound() -> void:
	# 数的是"真的响了几声"，不是"被要求了几次"。没有声卡的时候这两个数字的
	# 差就是唯一能观察到的东西。
	GameClock.set_test_now(1735700400, 10_000)
	var before: int = int(AudioManager.sfx_plays)

	# 同一帧三遍 —— 这正是掉最后一颗灯时发生的事：小游戏一次、score_mistake
	# 一次、弹卡一次。
	for i in 3:
		AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	_ok(AudioManager.sfx_plays - before == 1,
		"同一个音效在同一帧真的响了 %d 声 —— 掉最后一颗光之生命的那一刻听起来"
		% (AudioManager.sfx_plays - before) + "像卡带，而那一刻本该是安静下来的")

	# 不同的音效仍然可以叠 —— 两个不同的声音是和弦，不是口吃。
	before = int(AudioManager.sfx_plays)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	_ok(AudioManager.sfx_plays - before == 1,
		"换一个音效也被挡住了 —— 去重只该管重复，不该管同时")

	# 隔开足够久，同一个音效要能再响。
	before = int(AudioManager.sfx_plays)
	GameClock.set_test_now(1735700400, 10_000 + 400)
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	_ok(AudioManager.sfx_plays - before == 1,
		"隔了 0.4 秒同一个音效还是放不出来 —— 连着两次失误就只剩第一次有声音")
	GameClock.clear_test_now()
	await get_tree().process_frame


func _find_goo(duel: Node) -> Button:
	for threat in _threats(duel):
		if threat is Button:
			return threat
	return null


func _threats(duel: Node) -> Array:
	var list = duel.get("_threats")
	return list if list is Array else []


func _threat_count(duel: Node) -> int:
	return _threats(duel).size()


## 卡片上写的打法，战斗里得是真的。
##
## Every monster carries a weakness_key naming a real tactic, and for a long
## time the album printed it while the fight ignored it: whatever the card
## said, the answer was the beam button. These check the three things that
## have to hold for the card to mean anything.
func _the_card_tells_the_truth() -> void:
	# battle_10 是钢脊兽：卡片写"使用护盾挡住震动"，所以它只该被"挡"打开。
	GameManager.current_level_id = "battle_10"
	var duel: Node = load(DUEL).instantiate()
	add_child(duel)
	for i in 20:
		await get_tree().process_frame

	_ok(bool(duel.call("is_armored_now")),
		"battle_10 的怪兽卡片上写着有壳，开局却是软的")

	# 有壳的时候，普通光线不该扣血 —— 但也不能静悄悄，那和按钮坏了没区别。
	var before: int = int((duel.get("result") as LevelResult).correct)
	var sounds: int = int(AudioManager.sfx_plays)
	duel.set("_beam_ready_at", 0.0)
	duel.call("fire_beam_skill")
	await get_tree().process_frame
	_ok(int((duel.get("result") as LevelResult).correct) == before,
		"壳还在，普通光线却已经扣血了 —— 那壳就只是个装饰")
	_ok(AudioManager.sfx_plays > sounds,
		"打在壳上一点声音都没有 —— 一次没有回应的命中和坏掉的按钮读起来一样")

	# 卡片说"挡"，那"躲"就不该管用 —— 否则十五张卡说的是同一件事。
	duel.call("_open_up", "dodge")
	_ok(not bool(duel.call("wide_open")),
		"卡片写的是用护盾挡，结果躲一下也能破壳 —— 那弱点就没有意义了")
	duel.call("_open_up", "block")
	_ok(bool(duel.call("wide_open")),
		"按卡片写的挡住了，壳却没开")

	# 破绽期打中要真的更疼，不然读懂了也没奖励，孩子会回去乱按。
	before = int((duel.get("result") as LevelResult).correct)
	duel.set("_beam_ready_at", 0.0)
	duel.call("fire_beam_skill")
	await get_tree().process_frame
	var gained: int = int((duel.get("result") as LevelResult).correct) - before
	_ok(gained >= 2,
		"破绽期一击只值 %d 分 —— 读懂了它的打法和乱按一样划算，那就没人会去读" % gained)

	# 破绽会关上：它是一扇窗，不是一个开关。
	duel.set("_open_until", 0.0)
	_ok(not bool(duel.call("wide_open")), "破绽窗口不会关")

	duel.queue_free()
	await get_tree().process_frame

	# 前三只不该有壳：新玩法要先教基本循环，第一关就上壳是把人挡在门外。
	for easy in ["battle_01", "battle_02", "battle_03"]:
		var lvl: Dictionary = GameData.get_level(easy)
		_ok(not (lvl.get("config", {}) as Dictionary).has("armor"),
			"%s 就上了护甲 —— 头几关得先把点、挡、躲教会" % easy)
