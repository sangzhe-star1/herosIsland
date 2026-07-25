extends Node
## Renders the drawn Bluey large, across her pose vocabulary. Harness:
##   SHOT_PATH=/tmp/pup.png xvfb-run -a godot --path . res://tests/PuppyPreview.tscn
func _ready() -> void:
	var out := OS.get_environment("SHOT_PATH")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Stage.build(root, WorldStyle.for_world("bluey_park"), "pup")
	var poses := [HeroArt.Pose.IDLE, HeroArt.Pose.CHEER, HeroArt.Pose.WALK,
		HeroArt.Pose.HURT, HeroArt.Pose.JUMP]
	for pi in range(poses.size()):
		var pup: Node2D = preload("res://scripts/world/puppy_art.gd").new()
		root.add_child(pup)
		pup.position = Vector2(140.0 + float(pi) * 250.0, 650.0)
		pup.set_height(430.0)
		pup.set_pose(poses[pi], false)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("puppy_preview -> ", error_string(image.save_png(out)))
	get_tree().quit(0)
