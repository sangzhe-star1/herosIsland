extends "res://scripts/battle/attack.gd"
## 吐息：从嘴里喷一道持续的光。
##
## 颜色和吼声的环同一家紫 —— 怪兽的攻击共用一种颜色，孩子扫一眼就知道
## "这是它的，不是我的"。这招只能挡或躲，拍不掉。

func answered_by() -> Array:
	return ["block", "dodge", "interrupt"]


func fire(arena) -> void:
	var monster: Node2D = arena.arena_monster()
	if monster == null or not is_instance_valid(monster):
		return
	if monster.has_method("fire_breath"):
		monster.call("fire_breath", 0.55)
	var from: Vector2 = monster.position \
		+ Vector2(-70, -180.0 * monster.scale.x)
	var to: Vector2 = arena.arena_hero_at() + Vector2(40, -110)
	AudioManager.play_sfx("res://assets/audio/monster_roar.ogg")
	var breath := Node2D.new()
	arena.arena_play_area().add_child(breath)
	Shapes.fill(breath, Shapes.taper(from, to, 9.0, 30.0),
		Color(0.8, 0.55, 0.95, 0.8), 0.0)
	var t: Tween = arena.arena_tween()
	t.tween_interval(0.3)
	t.tween_callback(func(): arena.arena_contact_hero())
	t.tween_property(breath, "modulate:a", 0.0, 0.35)
	t.tween_callback(breath.queue_free)
