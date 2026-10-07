extends "res://scripts/battle/attack.gd"
## 震地践踏：怪兽高高跃起跺地，产生地面土石冲击波。
##
## 只有跳起躲避(dodge)或使用护盾格挡(block)两个答案。
## 重击类型，走重攻击计时器。

const RING_ART := "res://assets/effects/power_up.png"
const SMOKE_ART := "res://assets/effects/smoke.png"


func is_heavy() -> bool:
	return true


func answered_by() -> Array:
	return ["dodge", "block", "interrupt"]


func fire(arena) -> void:
	var monster: Node2D = arena.arena_monster()
	if monster == null or not is_instance_valid(monster):
		return
	if monster.has_method("ground_stomp"):
		monster.call("ground_stomp", 0.55)
	else:
		monster.call("puff_up")
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	var wave := TextureRect.new()
	wave.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wave.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		wave.texture = load(RING_ART)
	elif ResourceLoader.exists(SMOKE_ART):
		wave.texture = load(SMOKE_ART)
	wave.size = Vector2(190, 110)
	wave.position = monster.position + Vector2(-120, -110)
	wave.modulate = Color(1.0, 0.75, 0.35, 0.85)
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.arena_play_area().add_child(wave)
	arena.arena_add_threat(wave)
	var t: Tween = arena.arena_tween().bind_node(wave)
	t.tween_property(wave, "position:x", arena.arena_hero_at().x - 70.0, 2.4)
	t.tween_callback(func(): arena.arena_arrives(wave))
