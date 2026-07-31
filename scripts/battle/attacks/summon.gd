extends "res://scripts/battle/attack.gd"
## 召小怪：两只小的落在半路上，各自蹲一拍，然后扑过来。
##
## 拍的是**源头**，和拍泥球同一个动作，问的却是另一个问题：两只，先拍哪一只。
## 它们蹲的时间错开，所以那个选择是真实存在的而不是装饰。

const HOW_MANY := 2
const CROUCH := 1.6
const STAGGER := 0.5


func answered_by() -> Array:
	return ["swat", "block", "dodge", "interrupt"]


## 两只一起来，起手窗口给宽一点：要看清有几只、在哪儿。
func telegraph_scale() -> float:
	return 1.3


func fire(arena) -> void:
	arena.arena_teach_once("minions", "duel.minions")
	for i in range(HOW_MANY):
		_one(arena, i)


func _one(arena, index: int) -> void:
	var size := Vector2(72, 72)
	var minion := Button.new()
	minion.custom_minimum_size = size
	minion.size = size
	minion.pivot_offset = size / 2.0
	minion.focus_mode = Control.FOCUS_NONE
	# 按下即中，和泥球同一个理由：它会动，抬手判定对动目标必脱靶。
	minion.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.62, 0.45, 0.85, 0.95)
	style.set_corner_radius_all(int(size.x / 2.0))
	style.border_width_bottom = 5
	style.border_color = Color(0.45, 0.32, 0.65)
	for state in ["normal", "hover", "pressed", "disabled"]:
		minion.add_theme_stylebox_override(state, style)
	var face: Control = UiKit.picture("monster", 46.0)
	if face != null:
		face.position = Vector2(13, 10)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minion.add_child(face)

	var hero: Vector2 = arena.arena_hero_at()
	var lair: Vector2 = arena.arena_monster_at()
	var ground_x: float = lerpf(hero.x, lair.x, 0.42 + 0.2 * float(index))
	minion.position = Vector2(ground_x - size.x / 2.0, lair.y - size.y + 6.0)
	minion.pressed.connect(func(): arena.arena_swat(minion))
	UiKit.breathe(minion, 0.06, 0.6)
	arena.arena_play_area().add_child(minion)
	arena.arena_add_threat(minion)
	AudioManager.play_sfx("res://assets/audio/pop.ogg")

	# 蹲一拍再扑：拍的窗口错开，先近后远，选择真实存在。
	var pounce: SceneTreeTimer = arena.arena_after(CROUCH + STAGGER * float(index))
	pounce.timeout.connect(func():
		if not is_instance_valid(minion) or not arena.arena_alive():
			return
		var t: Tween = arena.arena_tween()
		t.tween_property(minion, "position",
			hero + Vector2(-20, -140) - size / 2.0, 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func(): arena.arena_arrives(minion)))
