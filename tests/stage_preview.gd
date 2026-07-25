extends Node
## Renders one WorldStyle full-screen. Development harness for the world layer:
## it lets a world be judged on its own, without a level's UI on top of it.
##
##   SHOT_WORLD=hero_city SHOT_PATH=/tmp/x.png \
##     xvfb-run -a godot --path . res://tests/StagePreview.tscn
func _ready() -> void:
	var world := OS.get_environment("SHOT_WORLD")
	var out := OS.get_environment("SHOT_PATH")
	var cfg := OS.get_environment("SHOT_CFG")
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 1.4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var style: WorldStyle = WorldStyle.for_world(world)
	if cfg != "":
		var parsed: Variant = JSON.parse_string(cfg)
		if parsed is Dictionary:
			style.apply_config(parsed)
	Stage.build(root, style, world)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("stage_preview: ", world, " -> ", error_string(image.save_png(out)))
	get_tree().quit(0)
