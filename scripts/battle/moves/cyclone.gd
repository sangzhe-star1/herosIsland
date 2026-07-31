extends "res://scripts/battle/move.gd"
## 光之旋风：○ 画圈。把自己围起来。
##
## 圈 = 围住自己，所以它做的是防守：清掉所有飞行物，再给一小段护罩。它是唯一
## 一个不打伤害的搓招 —— 手忙脚乱的时候有一个"全部收拾干净"的动作，比再多一
## 份输出有用得多。三连泥球那几关就是给它准备的。
##
## 护罩比技能键给的短，而且不吃护罩自己的冷却：它是应急，不是替代。

const SHELTER := 1.4


func gesture() -> Dictionary:
	# 转过大半圈就算，不要求闭合 —— 六岁的手画不出圆，而"画不完整就不算"
	# 是这个游戏最不该有的那种严格。
	return {"kind": "twist", "params": {"turn": 240.0}}


func card_stroke() -> Array:
	var out: Array = []
	for i in range(13):
		var a: float = TAU * float(i) / 12.0
		out.append(Vector2(cos(a), sin(a)) * 0.8)
	return out


func card_icon() -> String:
	return "shield"


func perform(arena) -> void:
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	var at: Vector2 = arena.arena_hero_at() + Vector2(0, -110)
	Juice.shockwave(arena.arena_play_area(), at, 210.0,
		Color(0.72, 0.94, 1.0))
	Juice.dust(arena.arena_play_area(), arena.arena_hero_at(), 10)
	arena.arena_hero().spin(1.0, 0.5)
	arena.arena_sweep_threats()
	arena.arena_shelter(SHELTER)
