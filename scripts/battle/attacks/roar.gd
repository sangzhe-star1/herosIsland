extends "res://scripts/battle/attack.gd"
## 吼声：一圈震波横着推过来。
##
## 和泥球的区别是它**拍不掉**（mouse_filter IGNORE）—— 这一招只有挡和躲两个
## 答案，所以它排在后半程，等护罩已经用熟了才出现。

const RING_ART := "res://assets/effects/power_up.png"
const SMOKE_ART := "res://assets/effects/smoke.png"


## 慢招：走第二个更慢的计时器。它拍不掉，只有挡和躲两个答案，来得太勤会让
## 孩子有一半时间手上没有可用的手段。
func is_heavy() -> bool:
	return true


func answered_by() -> Array:
	return ["block", "dodge", "interrupt"]


func fire(arena) -> void:
	var monster: Node2D = arena.arena_monster()
	if monster == null or not is_instance_valid(monster):
		return
	monster.call("puff_up")
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	var ring := TextureRect.new()
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		ring.texture = load(RING_ART)
	elif ResourceLoader.exists(SMOKE_ART):
		ring.texture = load(SMOKE_ART)
	ring.size = Vector2(170, 170)
	ring.position = monster.position + Vector2(-140, -260)
	ring.modulate = Color(0.8, 0.55, 0.95, 0.8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.arena_play_area().add_child(ring)
	arena.arena_add_threat(ring)
	var t: Tween = arena.arena_tween().bind_node(ring)  # dies with the ring; see goo.gd
	t.tween_property(ring, "position:x", arena.arena_hero_at().x - 85.0, 2.6)
	t.tween_callback(func(): arena.arena_arrives(ring))
