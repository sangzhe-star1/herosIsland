extends Node
## Renders one scene to a PNG and quits. Development tool for eyeballing
## screens without a person at the keyboard:
##
##   SHOT_SCENE=res://scenes/home/Home.tscn SHOT_PATH=/tmp/home.png \
##     xvfb-run -a godot --path . res://tests/Screenshot.tscn
##
## SHOT_LEVEL primes GameManager first, so minigame templates render as a
## real level. SHOT_WAIT (seconds, default 1.6) lets tweens and art settle.

func _ready() -> void:
	var scene_path := OS.get_environment("SHOT_SCENE")
	var out_path := OS.get_environment("SHOT_PATH")
	var level_id := OS.get_environment("SHOT_LEVEL")
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 1.6

	if scene_path == "" or out_path == "":
		push_error("screenshot_tool: set SHOT_SCENE and SHOT_PATH")
		get_tree().quit(2)
		return

	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)

	if level_id != "":
		GameManager.current_level_id = level_id

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("screenshot_tool: cannot load %s" % scene_path)
		get_tree().quit(2)
		return
	add_child(packed.instantiate())

	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(out_path)
	print("screenshot_tool: %s -> %s (%s)" % [scene_path, out_path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
