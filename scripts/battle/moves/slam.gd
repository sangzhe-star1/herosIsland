extends "res://scripts/battle/move.gd"
## 地面重砸：↓ 下划。从天而降的重击。
##
## 英雄向下俯冲突击，激荡地面冲击波。
## 能够击碎沿途地面威胁并震荡打断怪兽。

func gesture() -> Dictionary:
	return {"kind": "drag", "params": {
		"direction_x": 0.0, "direction_y": 1.0,
		"distance": 90.0, "angle": 35.0}}


func card_stroke() -> Array:
	return [Vector2(0, -0.85), Vector2(0, 0.85)]


func card_icon() -> String:
	return "blast"


func perform(arena) -> void:
	var target: Vector2 = arena.arena_aim()
	var hero_pos: Vector2 = arena.arena_hero_at()
	arena.arena_hero().slam(110.0, 0.38)
	Juice.dust(arena.arena_play_area(), hero_pos, 10, 1.2)
	Juice.shockwave(arena.arena_play_area(), hero_pos, 200.0, Color(1.0, 0.88, 0.42))
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	arena.arena_beam(target, 2.0)
	arena.arena_impact(target)
	arena.arena_interrupt()
	arena.arena_sweep_threats()
	arena.arena_land(2, true)
