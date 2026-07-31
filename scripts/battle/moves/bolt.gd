extends "res://scripts/battle/move.gd"
## 雷击：⚡ 画折线。闪电就长这样。
##
## 来回折几次才出得来，是四招里最难画的一个，所以它给的也最多：打断，而且把
## 破绽窗口再撑开一截 —— 最难的答法给最大的奖励，和护甲那边"越难的答法窗口
## 越大"是同一条规矩。

const EXTRA_OPENING := 0.9


func gesture() -> Dictionary:
	# 来回三次。菜园里摇苹果树用的就是这个原语，他的手已经会了。
	return {"kind": "sweep", "params": {"turns": 3, "leg": 55.0}}


func card_stroke() -> Array:
	return [Vector2(-0.85, -0.6), Vector2(0.1, -0.1),
		Vector2(-0.4, 0.1), Vector2(0.85, 0.6)]


func card_icon() -> String:
	return "lightning"


func perform(arena) -> void:
	var target: Vector2 = arena.arena_aim()
	AudioManager.play_sfx("res://assets/audio/ultimate.ogg")
	arena.arena_beam(target, 1.3)
	arena.arena_impact(target)
	Juice.burst(arena.arena_play_area(), target, 18)
	arena.arena_interrupt()
	arena.arena_stretch_opening(EXTRA_OPENING)
	arena.arena_land(1, true)
