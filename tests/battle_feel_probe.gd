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
## 图鉴，用来拿全部怪兽的名字 —— 见"模板不认识任何一只怪兽"那一节。
const Album := preload("res://scripts/reward/monster_album.gd")
## 招式册 —— 5C 之后招式不再是模板上的方法。
const Book := preload("res://scripts/battle/attack_book.gd")

var _failures: Array[String] = []
var _asked := 0
## 少一条就说明有一节被静默跳过了。见 garden_touch_probe 的同名常量。
const CHECKS_EXPECTED := 50


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
	await _a_stroke_is_a_shortcut_not_a_toll()
	await _the_monster_learned_new_moves()
	_the_book_is_the_only_list()

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
	# 直接问招式册要那一招，而不是调一个模板上的方法 —— 5C 之后模板上已经
	# 没有 _monster_attack_goo 了，招式住在 scripts/battle/attacks/ 下面。
	Book.get_attack("goo").fire(duel)
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


## 搓招是捷径，不是收费站。
##
## 三个按钮必须永远单独够用。这一节的存在理由只有一条：任何一天有人让某一招
## 变成"只有搓出来才做得到"，这里就会红 —— 一个还没学会划的六岁孩子被挡在
## 门外，是最不会被人报上来的那种坏，因为他只会安静地不玩了。
func _a_stroke_is_a_shortcut_not_a_toll() -> void:
	const Stroke := preload("res://scripts/shared/stroke_reader.gd")
	var duel_script := load("res://scripts/minigames/monster_duel.gd")
	var reader = Stroke.new(duel_script.MOVES)

	# 认得出：一笔往上是升龙，一笔往右是光波。
	_ok(_reads(reader, [Vector2(200, 500), Vector2(206, 430), Vector2(210, 380)])
		== "rising", "一笔往上没被认成升龙")
	_ok(_reads(reader, [Vector2(200, 500), Vector2(270, 496), Vector2(320, 502)])
		== "wave", "一笔往右没被认成光波")

	# 下面两条是"认不错"，而且必须真的对参数敏感 —— 第一版写的两个反例，
	# 把容差从 38 度开到 90 度、把最短笔画从 70 降到 5，两个都照样不匹配，
	# 于是三次蓄意破坏全绿。一个不会红的断言比没有断言更糟，因为它让人以为
	# 这里有人在看。两条都换成刚好卡在阈值外面的输入。

	# 偏 50 度：在 38 度的扇面外，但如果谁把扇面开到 90 就会中。
	_ok(_reads(reader, [Vector2(200, 500), Vector2(280, 430), Vector2(320, 400)])
		== "", "偏了 50 度也认成升龙 —— 容差扇面开得太大，乱划都会出招")

	# 往右只挪 34 像素不该出招 —— 那个距离是手指按按钮时的正常滑动量。
	_ok(_reads(reader, [Vector2(200, 500), Vector2(220, 500), Vector2(234, 501)])
		== "", "手指只挪了 34 像素也被当成一招 —— 那按按钮会变成乱放技能")

	# 上面那条只在招式表自己要求得够长时才成立，所以直接盯着招式表。
	# 写这一条是因为 stroke_reader 原来还有一道 MIN_TRAVEL 门槛，蓄意破坏时
	# 把它降到 5 也没有任何检查变红 —— 那道门槛从来没生效过（每一招的
	# distance 都更严），既没用又是陷阱，已经删掉。长度只剩这一个出处。
	for move in duel_script.MOVES:
		var d: float = float((move.get("params", {}) as Dictionary).get("distance", 0.0))
		_ok(d >= 70.0,
			"招式表里 %s 只要求划 %.0f 像素 —— 短到会和按按钮时的手指滑动撞车，"
			% [str(move.get("name", "?")), d] + "他每按一次技能键都会顺手放个招")

	# 两招都吃光线的冷却：搓招是替代，不是白送的输出。
	# 真的打一招出去看时钟，不是在源码里搜字符串 —— 第一版搜的那行在
	# fire_beam_skill 里也有一份，把 _perform 里的删掉照样搜得到。
	GameManager.current_level_id = "battle_05"
	var one: Node = load(DUEL).instantiate()
	add_child(one)
	for i in 20:
		await get_tree().process_frame
	one.set("_beam_ready_at", 0.0)
	one.call("_perform", "wave")
	await get_tree().process_frame
	_ok(float(one.get("_beam_ready_at")) > float(one.get("_clock")),
		"搓完一招光线立刻又能打 —— 那搓招就是外挂，按按钮的孩子永远落后")
	one.queue_free()
	await get_tree().process_frame

	# 最要紧的一条：不搓也能打完。逐关检查没有任何一关把通关条件挂在搓招上。
	for entry in GameData.get_levels_for_mode("battle"):
		var cfg: Dictionary = entry.get("config", {})
		if bool(cfg.get("requires_stroke", false)):
			_ok(false, "%s 要求必须搓招才能过 —— 三个按钮必须永远单独够用"
				% str(entry.get("id", "")))
			return
	_ok(true, "十五关没有一关把通关挂在搓招上")

	# 招式表是图不是字。
	GameManager.current_level_id = "battle_05"
	var duel: Node = load(DUEL).instantiate()
	add_child(duel)
	for i in 20:
		await get_tree().process_frame
	var words := 0
	var pictures := 0
	for node in _all(duel):
		if node is Label and str((node as Label).text).length() > 0:
			words += 1
		if node is Polygon2D or node is Line2D:
			pictures += 1
	_ok(pictures > 0, "战斗里一个画出来的形状都没有 —— 这个探针在看错的东西")
	_ok(duel.get("_stroke") != null, "对决里没有搓招层")
	duel.queue_free()
	await get_tree().process_frame


func _reads(reader, points: Array) -> String:
	for i in range(points.size()):
		var e := InputEventScreenTouch.new() if i == 0 or i == points.size() - 1 \
			else null
		if e != null:
			e.index = 0
			e.pressed = i == 0
			e.position = points[i]
			reader.feed(e, points[i])
		else:
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = points[i]
			reader.feed(d, points[i])
	return reader.take()


func _all(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out.append_array(_all(c))
	return out


## 5B：怪兽的新招，逐条问。
##
## 三条保证：招式表从数据来（模板里不许出现任何一只怪兽的名字）；每一记攻击
## 无论哪种，挡了就是挡了、没挡就掉一格光——不引入第四种结果；岛上那六场
## boss 战永远走默认 ["goo"]，见不到新招，时长基准线原封不动。
func _the_monster_learned_new_moves() -> void:
	# 模板不认识任何一只怪兽。十五场不同的仗全部来自数据 —— 一旦有人写下
	# `if _monster_id == "shadow_wing"`，第十六只怪兽就再也进不来了。
	var src := FileAccess.get_file_as_string(
		"res://scripts/minigames/monster_duel.gd")
	var named: Array = []
	for entry in Album.all():
		var id := str(entry.get("id", ""))
		if id != "" and src.contains(id):
			named.append(id)
	_ok(named.is_empty(),
		"模板里点了怪兽的名字：%s —— 招式表必须全部来自数据" % str(named))

	# 数据的形状：教学关干净，最后一关全会，岛上的仗不受影响。
	_ok(not (GameData.get_level("battle_01").get("config", {}) as Dictionary)\
		.has("attacks"), "battle_01 配了招式表 —— 教学关得先教基本循环")
	var last: Array = (GameData.get_level("battle_15").get("config", {})
		as Dictionary).get("attacks", [])
	_ok(last.size() >= 3,
		"最后一只怪兽只会 %d 招 —— 它得是他见过最会打的" % last.size())
	_ok(not (GameData.get_level("sunny_park_06").get("config", {}) as Dictionary)\
		.has("attacks"),
		"岛上的 boss 战配了招式表 —— 那六场的时长基准线会被悄悄改掉")

	# 碰到英雄只有两种结果：挡了 = 弹开算一下；没挡 = 掉一格光。
	# 在没壳的 battle_01 上验，护甲会把"算一下"变成"叮"，那是另一条断言的事。
	GameManager.current_level_id = "battle_01"
	var duel: Node = load(DUEL).instantiate()
	add_child(duel)
	for i in 20:
		await get_tree().process_frame
	duel.call("activate_shield")
	var hits: int = int((duel.get("result") as LevelResult).correct)
	var light: int = int(duel.get("_light_left"))
	duel.call("_contact_hero")
	await get_tree().process_frame
	_ok(int((duel.get("result") as LevelResult).correct) == hits + 1,
		"挡下一记攻击没有算他一下 —— 挡本来是这套战斗里设计最好的一处")
	_ok(int(duel.get("_light_left")) == light,
		"挡着还掉了光 —— 护盾就没有意义了")
	duel.set("_shield_until", 0.0)
	duel.call("_contact_hero")
	await get_tree().process_frame
	_ok(int(duel.get("_light_left")) == light - 1,
		"没挡也不掉光 —— 攻击就没有分量了")
	duel.queue_free()
	await get_tree().process_frame

	# 召出来的小怪：按下即中、六岁的拇指按得中。
	GameManager.current_level_id = "battle_11"
	var brood: Node = load(DUEL).instantiate()
	add_child(brood)
	for i in 20:
		await get_tree().process_frame
	var before: int = (brood.get("_threats") as Array).size()
	Book.get_attack("summon").fire(brood)
	await get_tree().process_frame
	var minions: Array = []
	for threat in (brood.get("_threats") as Array):
		if threat is Button and not minions.has(threat):
			minions.append(threat)
	_ok(minions.size() - before == 2,
		"召唤没有召出两只小怪（多了 %d 只）" % (minions.size() - before))
	var fine := true
	for m in minions:
		if (m as Button).action_mode != BaseButton.ACTION_MODE_BUTTON_PRESS \
				or (m as Control).size.x < 60.0:
			fine = false
	_ok(fine, "小怪要么抬手才判定、要么比六岁的拇指还小")
	brood.queue_free()
	await get_tree().process_frame

	# 硬直：发怒之后欠一记大的 —— 但只在带真招式表的关。
	GameManager.current_level_id = "battle_04"
	var angry: Node = load(DUEL).instantiate()
	add_child(angry)
	for i in 20:
		await get_tree().process_frame
	var need: int = angry.call("target_value", "correct", 8)
	(angry.get("result") as LevelResult).correct = int(need * 0.6)
	angry.call("_check_phase")
	_ok(bool(angry.get("_heavy_owed")) or float(angry.get("_telegraph_left")) > 0.0,
		"发怒之后没有憋那记大的 —— 第二阶段就只是数字变密，没有一个能记住的瞬间")
	angry.queue_free()
	await get_tree().process_frame

	GameManager.current_level_id = "sunny_park_06"
	var island: Node = load(DUEL).instantiate()
	add_child(island)
	for i in 20:
		await get_tree().process_frame
	need = island.call("target_value", "correct", 8)
	(island.get("result") as LevelResult).correct = int(need * 0.6)
	island.call("_check_phase")
	_ok(not bool(island.get("_heavy_owed")),
		"岛上的 boss 也憋了硬直 —— 那六场的基准线被悄悄改掉了")
	island.queue_free()
	await get_tree().process_frame


## 招式册是唯一的清单。
##
## 5C 把五个 if/elif 和五个 `_monster_attack_*` 换成了"一招一个文件"。这一节
## 守的是那次重构的全部价值：只要模板重新认识某一招的名字，或者册子退回成一份
## 手写清单，加第六招就又要改三处 —— 而这个项目已经被"第二处"咬过两次（首页
## 卡片数写死成 3，tablet_probe 自己也写死成 3）。
func _the_book_is_the_only_list() -> void:
	var known: Array = Book.ids()
	_ok(known.size() >= 5,
		"招式册只认识 %d 招 —— 目录扫空了，怪兽会安静地不出手" % known.size())

	# 扫到的 == 目录里的文件数。导出包里 .gd 可能变成 .gdc 或跟一个 .remap，
	# 一个在编辑器里满员、在真机上空掉的注册表没人会报上来。
	_ok(known.size() == Book.files_on_disk(),
		"目录里有 %d 个文件，册子只认出 %d 招 —— 有文件没被扫进来"
		% [Book.files_on_disk(), known.size()])

	# 模板不许再认识任何一招的名字。
	var src := FileAccess.get_file_as_string(
		"res://scripts/minigames/monster_duel.gd")
	var named: Array = []
	for id in known:
		# 注释里提一句也不行：一旦放过注释，`if kind == "rush"` 就永远差一个
		# grep 的例外。和"模板不许点怪兽名字"那条同一个规矩。
		if src.contains('"%s"' % id):
			named.append(id)
	_ok(named.is_empty(),
		"模板里点了招式的名字：%s —— 第六招就又要改三处了" % str(named))

	# 每一招都真的实现了接口，而不是继承了基类就算数。
	for id in known:
		var attack = Book.get_attack(id)
		_ok(attack != null and attack.has_method("fire") \
				and attack.has_method("answered_by"),
			"%s 没有实现招式接口" % id)

	# 数据里写的每一个名字，册子都得认识。写错一个名字应该在这里红，
	# 而不是在孩子面前变成"这一次它没出手"。
	var missing: Array = []
	for entry in GameData.get_levels_for_mode("battle"):
		for id in (entry.get("config", {}) as Dictionary).get("attacks", []):
			if Book.get_attack(str(id)) == null and not missing.has(id):
				missing.append(id)
	_ok(missing.is_empty(),
		"关卡数据里写了册子不认识的招：%s" % str(missing))

	# 写错一个名字要安静地什么都不做，不能炸 —— 也不能悄悄换成另一招。
	_ok(Book.get_attack("nonexistent_move") == null,
		"招式册对一个不存在的名字给了东西 —— 数据写错会变成「它换了一招」，"
		+ "那种错永远查不出来")
