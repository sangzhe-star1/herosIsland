extends "res://scripts/battle/move.gd"
## 升龙光拳：↑ 上划。顶上去。
##
## 算一次打断，所以有壳的怪兽会被它开出破绽 —— 这正是"搓招更快"的地方：
## 蓄满一次要一整个冷却，这一下是立刻的。

func gesture() -> Dictionary:
	return {"kind": "drag", "params": {
		"direction_x": 0.0, "direction_y": -1.0,
		"distance": 90.0, "angle": 38.0}}


func card_stroke() -> Array:
	return [Vector2(0, 0.85), Vector2(0, -0.85)]


func card_icon() -> String:
	return "power"


func perform(arena) -> void:
	var target: Vector2 = arena.arena_aim()
	arena.arena_hero().jump(90.0, 0.42)
	Juice.speed_lines(arena.arena_play_area(),
		arena.arena_hero_at() + Vector2(0, -120),
		Vector2.UP, Color(1, 0.95, 0.7, 0.7), 4)
	arena.arena_beam(target, 1.6)
	arena.arena_impact(target)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	arena.arena_interrupt()
	arena.arena_land(1, true)
