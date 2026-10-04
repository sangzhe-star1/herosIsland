extends "res://scripts/battle/attack.gd"
## 泥球：抛物线飞过来，能拍掉。
##
## 屏幕上唯一会动的目标，也是最好发现的防守 —— 一个东西朝你飞，伸手拍它，
## 不需要任何人教。护罩是技能、有冷却；拍是本能。

const VOLLEY_GAP := 0.22


## 一关什么都没配的时候，它就是怪兽会的那一招 —— 最好发现、最好躲、最好拍。
func is_basic() -> bool:
	return true


func answered_by() -> Array:
	return ["block", "dodge", "interrupt", "swat"]


func fire(arena) -> void:
	# 一次几颗，随机而不是固定 —— 固定的数量两场之后就背下来了。
	var many: int = 1
	var volley: int = arena.arena_volley()
	if volley > 1:
		many = randi_range(1, volley)
	for i in range(many):
		var wait: float = VOLLEY_GAP * float(i)
		if wait <= 0.0:
			_lob(arena)
			continue
		arena.arena_after(wait).timeout.connect(func():
			if arena.arena_alive():
				_lob(arena))


func _lob(arena) -> void:
	var monster: Node2D = arena.arena_monster()
	if monster == null or not is_instance_valid(monster):
		return
	monster.call("puff_up")
	arena.arena_teach_once("swat", "duel.swat")

	var size := Vector2(96, 96)
	var goo := Button.new()
	goo.custom_minimum_size = size
	goo.size = size
	goo.pivot_offset = size / 2.0
	goo.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.78, 0.42, 0.95)
	style.set_corner_radius_all(int(size.x / 2.0))
	style.border_width_bottom = 5
	style.border_color = Color(0.40, 0.62, 0.30)
	for state in ["normal", "hover", "pressed", "disabled"]:
		goo.add_theme_stylebox_override(state, style)
	# 按下即中，不是抬手。Button 默认抬手触发，于是手指按下去、球从指尖飞走、
	# 抬手时判定已经脱靶 —— 屏幕上唯一会动的目标，用了最不适合动目标的模式。
	goo.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	goo.pressed.connect(func(): arena.arena_swat(goo))
	# 而且要看得出能拍。文字教学只有一次、三秒，不识字的孩子从来没收到过；
	# 一个会呼吸的东西自己会说"我能被碰"。
	UiKit.breathe(goo, 0.05, 0.7)

	var from: Vector2 = monster.position + Vector2(-40, -240 * monster.scale.x)
	goo.position = from - size / 2.0
	arena.arena_play_area().add_child(goo)
	arena.arena_add_threat(goo)

	var to: Vector2 = arena.arena_hero_at() + Vector2(0, -50)
	# Bound to the goo: when it is swatted (freed) mid-flight the tween dies
	# with it. Unbound, the arena's tween kept calling _step with a freed
	# argument every frame and the arrival lambda with a dead capture --
	# two ERROR lines per swat since July, which the old smoke only grepped
	# for SCRIPT ERROR and the isolated runner now rightly refuses.
	var t: Tween = arena.arena_tween().bind_node(goo)
	t.tween_method(_step.bind(goo, from, to), 0.0, 1.0, 2.4)
	t.tween_callback(func(): arena.arena_arrives(goo))


func _step(k: float, goo: Control, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(goo):
		return
	var x: float = lerpf(from.x, to.x, k)
	var y: float = lerpf(from.y, to.y, k) - sin(k * PI) * 170.0
	goo.position = Vector2(x, y) - goo.size / 2.0
