extends Node
## Captures the hero's motion verbs as a filmstrip: entrance mid-fall,
## the landing dust, a roll mid-tumble, and the settle. Motion cannot be
## judged from a single still, so this saves four.
##   SHOT_DIR=/tmp/motion ... res://tests/MotionPreview.tscn
var _dir: String
var _root: Control


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var stage: Stage = Stage.build(_root, WorldStyle.for_world("monster_arena"), "motion")

	var hero := SkinnedCharacter.new()
	hero.skin = load("res://resources/skins/tiga.tres")
	hero.position = Vector2(380, stage.ground_y())
	_root.add_child(hero)
	hero.set_height(300.0)
	hero.entrance(360.0, 0.1)

	var hero2 := SkinnedCharacter.new()
	hero2.skin = load("res://resources/skins/zero.tres")
	hero2.position = Vector2(760, stage.ground_y())
	_root.add_child(hero2)
	hero2.set_height(300.0)

	await _snap(0.38, "1_falling")     # mid-drop, JUMP pose
	await _snap(0.30, "2_landed")      # dust and shockwave
	hero2.roll(220.0, 0.6)
	await _snap(0.30, "3_rolling")     # tucked, spinning, speed lines
	hero.jump(90.0)
	await _snap(0.34, "4_leaping")     # crouch->launch caught mid-air
	await _snap(0.60, "5_settled")
	get_tree().quit(0)


func _snap(delay: float, tag: String) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("motion_preview %s -> %s" % [tag, error_string(
		image.save_png(_dir.path_join(tag + ".png")))])
