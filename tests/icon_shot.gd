extends Node
## Renders the app icon source: the hero, big and friendly, on the island's
## own morning sky. tools/build_mac.command turns it into the .icns.
##   SHOT_PATH=/tmp/icon.png ... res://tests/IconShot.tscn
func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Stage.build(root, WorldStyle.for_world("piglet_town"), "app-icon")
	var hero := SkinnedCharacter.new()
	hero.skin = load("res://resources/skins/tiga.tres")
	hero.position = Vector2(640, Stage.ground_line() + 40.0)
	root.add_child(hero)
	hero.set_height(560.0)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("icon_shot -> ", error_string(image.save_png(OS.get_environment("SHOT_PATH"))))
	get_tree().quit(0)
