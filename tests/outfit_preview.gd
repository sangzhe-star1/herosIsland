extends Node
## Renders one hero wearing a given outfit combo, large. Development harness:
##   SHOT_SKIN=tiga SHOT_OUTFIT=crown,sunglasses,cape_red SHOT_PATH=/tmp/o.png \
##     xvfb-run -a godot --path . res://tests/OutfitPreview.tscn
## Draws three figures (idle, cheer, jump) so a hat that only fits standing
## still gets caught here, not by a six-year-old mid-leap.
func _ready() -> void:
	var out := OS.get_environment("SHOT_PATH")
	var which := OS.get_environment("SHOT_SKIN")
	if which == "":
		which = "tiga"
	var combo := OS.get_environment("SHOT_OUTFIT")
	var outfit := {"hat": "", "face": "", "back": ""}
	for piece in combo.split(",", false):
		for entry in GameData.rewards.get("outfits", []):
			if str(entry.get("id", "")) == piece:
				outfit[str(entry.get("slot", "hat"))] = piece
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	Stage.build(root, WorldStyle.for_world("bluey_park"), "wardrobe")
	var poses := [HeroArt.Pose.IDLE, HeroArt.Pose.CHEER, HeroArt.Pose.JUMP]
	for pi in range(poses.size()):
		var art := HeroArt.new(load("res://resources/skins/%s.tres" % which))
		art.outfit = outfit
		root.add_child(art)
		art.position = Vector2(260.0 + float(pi) * 380.0, 660.0)
		art.set_height(500.0)
		art.set_pose(poses[pi], false)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("outfit_preview -> ", error_string(image.save_png(out)))
	get_tree().quit(0)
