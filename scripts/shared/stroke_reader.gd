extends RefCounted
## 搓招：一笔画下去，认出是哪一招。
##
##     const Stroke := preload("res://scripts/shared/stroke_reader.gd")
##     var reader := Stroke.new(MOVES)
##     reader.feed(event, play_area_position)   # 每个输入事件喂一次
##     var move := reader.take()                # 抬手那一帧返回招名，否则 ""
##
##
## 为什么不是拳皇的搓招
##
## 拳皇是 ↓↘→ + 拳：一串**方向**输入，在几帧的窗口里按顺序完成，为摇杆和六个
## 按键设计。平板上没有方向键，六岁的手也没有帧窗口的概念。照搬会得到一个他
## 永远搓不出来的按钮，而那比现在的三个按钮更糟 —— 因为它看起来能用。
##
## 他要的那个感觉是对的：这一招是我用手划出来的，不是按了一个键。正确的翻译
## 不是方向序列，是**在屏幕上画一个形状**。
##
##
## 识别器不在这里，也不该在这里
##
## `scripts/harvest/gesture.gd` 已经是一套纯函数识别器 —— 五个原语
## （tap / drag / twist / line / sweep），不碰节点、不碰屏幕、不碰输入事件，
## 每个容差都是一个可以断言的数字。菜园里他每天拔萝卜、摇苹果树用的就是它。
##
## 复用它而不是重写一份，理由和那个文件自己写的一样：同一个手势在下一块屏幕上
## 行为不一样，是六岁孩子最先察觉的事。战斗里的手感必须和菜园是同一套。
##
## 所以这个文件只补真正缺的那一块：**把手指的轨迹收下来**，问识别器它是哪一招。
## 识别本身一行都没有重写。
const Gesture := preload("res://scripts/harvest/gesture.gd")

## 这里**没有**最短长度的门槛，是故意的。
##
## 第一版有一个 MIN_TRAVEL := 70，蓄意破坏时把它降到 5 也没有任何检查变红 ——
## 因为每一招自己的 `distance` 都要求 ≥ 90，那道门槛从来没有生效过。它不只是
## 没用，它是个陷阱：将来谁加一招只要划 40 像素，会被这个看不见的第二道门槛
## 悄悄挡掉，而招式表上写的明明是 40。
##
## 所以长度只有一个出处 —— 每一招自己的 `distance`。battle_feel_probe 里有一条
## 断言盯着招式表，不许任何一招的 distance 低到会和按钮的点击撞车。

## 太久的一笔不是一笔。手指按住不动是蓄力（阶段 2 的机制），不是搓招；没有
## 这条，蓄满松手会被认成一次乱划。
const MAX_SECONDS := 1.1

## 招式表：[{name, kind, params}]，按顺序问，第一个答应的赢。
## 顺序有意义 —— 上划和前划的容差扇面如果重叠，先写的那个优先。
var _moves: Array = []
var _track := PackedVector2Array()
var _drawing := false
var _began := 0.0
var _found := ""


func _init(moves: Array) -> void:
	_moves = moves


## 喂一个输入事件。`at` 是这个事件在战斗坐标系里的位置 —— 由调用方换算，
## 因为只有它知道自己挂在哪一层。
func feed(event: InputEvent, at: Vector2) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_track = PackedVector2Array([at])
			_drawing = true
			_began = float(GameClock.ticks_ms()) / 1000.0
		elif _drawing:
			_track.append(at)
			_drawing = false
			_found = _read()
	elif event is InputEventScreenDrag and _drawing:
		_track.append(at)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_track = PackedVector2Array([at])
			_drawing = true
			_began = float(GameClock.ticks_ms()) / 1000.0
		elif _drawing:
			_track.append(at)
			_drawing = false
			_found = _read()
	elif event is InputEventMouseMotion and _drawing:
		_track.append(at)


## 抬手那一帧认出来的招，取走之后清空。没有就是空字符串。
##
## 取走式而不是信号式：调用方要在同一次输入处理里决定"这是搓招还是普通点击"，
## 一个下一帧才到的信号会让那两条路各走各的。
func take() -> String:
	var out := _found
	_found = ""
	return out


## 正在画的那一笔，给调用方画出来看。空的表示手指没在屏幕上。
func trail() -> PackedVector2Array:
	return _track if _drawing else PackedVector2Array()


func drawing() -> bool:
	return _drawing


func _read() -> String:
	if _track.size() < 2:
		return ""
	if float(GameClock.ticks_ms()) / 1000.0 - _began > MAX_SECONDS:
		return ""
	# 中心点取起笔处：战斗里没有"目标物"，转和线这两个原语要有个参照，
	# 而手自己起笔的地方是唯一一个孩子知道的参照。
	var centre: Vector2 = _track[0]
	for move in _moves:
		if Gesture.satisfied(str(move.get("kind", "")),
				move.get("params", {}), _track, centre):
			return str(move.get("name", ""))
	return ""
