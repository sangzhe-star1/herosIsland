extends "res://scripts/battle/move.gd"
## 飞踢反击：← 左划（后撤回旋踢）。
##
## 英雄后撤借力凌空反击，附带疾速光影。
## 命中后产生快速连击，并解除地面近身威胁。

func gesture() -> Dictionary:
	return {"kind": "drag", "params": {
		"direction_x": -1.0, "direction_y": 0.0,
		"distance": 90.0, "angle": 32.0}}


func card_stroke() -> Array:
	return [Vector2(0.85, 0), Vector2(-0.85, 0)]


func card_icon() -> String:
	return "spread"


func perform(arena) -> void:
	var target: Vector2 = arena.arena_aim()
	arena.arena_hero().kick(0.35)
	Juice.speed_lines(arena.arena_play_area(), arena.arena_hero_at(),
		Vector2(1.0, -0.4).normalized(), Color(0.4, 0.85, 1.0, 0.8), 5)
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	arena.arena_beam(target, 1.5)
	arena.arena_impact(target)
	arena.arena_interrupt()
	arena.arena_land(1, true)
