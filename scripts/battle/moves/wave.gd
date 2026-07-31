extends "res://scripts/battle/move.gd"
## 光波：→ 前划。推出去。
##
## 路上的泥球一起带走 —— 一个动作替掉"一颗一颗拍"。

func gesture() -> Dictionary:
	return {"kind": "drag", "params": {
		"direction_x": 1.0, "direction_y": 0.0,
		"distance": 90.0, "angle": 32.0}}


func card_stroke() -> Array:
	return [Vector2(-0.85, 0), Vector2(0.85, 0)]


func card_icon() -> String:
	return "spark"


func perform(arena) -> void:
	var target: Vector2 = arena.arena_aim()
	arena.arena_beam(target, 2.2)
	arena.arena_impact(target)
	Juice.shockwave(arena.arena_play_area(), target, 170.0,
		Color(1.0, 0.94, 0.72))
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	arena.arena_sweep_threats()
	arena.arena_land(1, true)
