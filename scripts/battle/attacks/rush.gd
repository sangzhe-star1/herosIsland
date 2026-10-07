extends "res://scripts/battle/attack.gd"
## 冲撞：整只怪兽冲过来，再退回去。
##
## 屏幕上最大的东西朝你来 —— 五招里读起来最不用教的一招，所以它排在大多数
## 招式表的最前面，是新玩法的入门题。

func answered_by() -> Array:
	return ["dodge", "block", "interrupt"]


func fire(arena) -> void:
	var monster: Node2D = arena.arena_monster()
	if monster == null or not is_instance_valid(monster):
		return
	var home: Vector2 = arena.arena_monster_at()
	var strike := Vector2(arena.arena_hero_at().x + 150.0, home.y)
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	Juice.dust(arena.arena_play_area(), home, 8)
	Juice.speed_lines(arena.arena_play_area(), home + Vector2(60, -130),
		Vector2.LEFT, Color(1, 1, 1, 0.5), 4)
	var t: Tween = arena.arena_tween()
	t.tween_property(monster, "position", strike, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		arena.arena_contact_hero()
		if monster.has_method("claw_swipe"):
			monster.call("claw_swipe", 0.35)
	)
	t.tween_interval(0.18)
	t.tween_property(monster, "position", home, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
