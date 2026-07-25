extends Node
## Renders hero designs and poses, large enough to judge. Development harness.
##   SHOT_BIG=1 renders one hero at full height; otherwise a 3x4 sheet.
func _ready() -> void:
	var out := OS.get_environment("SHOT_PATH")
	var big := OS.get_environment("SHOT_BIG") != ""
	var which := OS.get_environment("SHOT_SKIN")
	if which == "":
		which = "tiga"
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Stage.build(root, WorldStyle.for_world("piglet_town"), "heroes")

	if big:
		var poses := [HeroArt.Pose.IDLE, HeroArt.Pose.CHEER, HeroArt.Pose.BEAM,
			HeroArt.Pose.HURT, HeroArt.Pose.JUMP, HeroArt.Pose.TUCK]
		for pi in range(poses.size()):
			var art := HeroArt.new(load("res://resources/skins/%s.tres" % which))
			root.add_child(art)
			art.position = Vector2(120.0 + float(pi) * 208.0, 640.0)
			art.set_height(470.0)
			art.set_pose(poses[pi], false)
	else:
		var skins := ["light_hero", "tiga", "zero"]
		var poses2 := [HeroArt.Pose.IDLE, HeroArt.Pose.CHEER, HeroArt.Pose.BEAM, HeroArt.Pose.HURT]
		for si in range(skins.size()):
			for pi in range(poses2.size()):
				var art2 := HeroArt.new(load("res://resources/skins/%s.tres" % skins[si]))
				root.add_child(art2)
				art2.position = Vector2(170.0 + float(pi) * 300.0, 230.0 + float(si) * 230.0)
				art2.set_height(210.0)
				art2.set_pose(poses2[pi], false)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("hero_preview -> ", error_string(image.save_png(out)))
	get_tree().quit(0)
