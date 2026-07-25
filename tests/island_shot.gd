extends Node
## Renders ONE world's compact map island to a PNG. Development harness:
##   SHOT_WORLD=bluey_park SHOT_PATH=/tmp/island.png \
##     xvfb-run -a godot --path . res://tests/IslandShot.tscn
func _ready() -> void:
	var out := OS.get_environment("SHOT_PATH")
	var world_id := OS.get_environment("SHOT_WORLD")
	if world_id == "":
		world_id = "bluey_park"
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	UiKit.world_background(root, "island", "probe")
	var island := IslandMap.new()
	island.build([GameData.get_world(world_id)],
		{world_id: GameData.get_levels_for_world(world_id)}, true)
	root.add_child(island)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("island_shot -> ", error_string(image.save_png(out)))
	get_tree().quit(0)
