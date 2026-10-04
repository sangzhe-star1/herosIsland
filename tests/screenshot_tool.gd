extends Node

const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")
## Renders one scene to a PNG and quits. Development tool for eyeballing
## screens without a person at the keyboard:
##
##   SHOT_SCENE=res://scenes/home/Home.tscn SHOT_PATH=/tmp/home.png \
##     xvfb-run -a godot --path . res://tests/Screenshot.tscn
##
## SHOT_LEVEL primes GameManager first, so minigame templates render as a
## real level. SHOT_WAIT (seconds, default 1.6) lets tweens and art settle.
##
## SHOT_WINDOW="1024x768" renders the iPad shape. The project stretches with
## aspect=expand, so a 4:3 window gives the game a 1280x960 viewport -- 240
## more pixels of height than anything designed against 720 expects. That is
## where this project's two worst shipped layout bugs lived, and until now the
## screenshot tool could not show it: it set content_scale_size as well as
## size, which switches expand off and hands back a tidy 1024x768 that is not
## what any tablet ever sees.

func _ready() -> void:
	var scene_path := OS.get_environment("SHOT_SCENE")
	var out_path := OS.get_environment("SHOT_PATH")
	var level_id := OS.get_environment("SHOT_LEVEL")
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 1.6

	if scene_path == "" or out_path == "":
		push_error("screenshot_tool: set SHOT_SCENE and SHOT_PATH")
		await ProbeLifecycle.finish(self, 2)
		return

	var want := Vector2i(1280, 720)
	var asked := OS.get_environment("SHOT_WINDOW")
	if asked != "" and asked.contains("x"):
		var parts := asked.split("x")
		want = Vector2i(int(parts[0]), int(parts[1]))

	var window := get_window()
	if window != null:
		# ONLY the window size. Touching content_scale_size here is what made
		# the 4:3 path untestable, so it is deliberately not touched.
		window.size = want
	await get_tree().process_frame
	# Print what the game actually got, not what was asked for. On a 4:3 window
	# these two lines disagree, and that disagreement is the whole point.
	print("screenshot_tool: window %s -> viewport %s"
		% [str(want), str(get_viewport().get_visible_rect().size)])

	if level_id != "":
		GameManager.current_level_id = level_id
		SaveManager.clear_harvest_checkpoint(level_id)
		var asked_order := OS.get_environment("SHOT_ORDER_INDEX")
		if asked_order != "":
			SaveManager.set_harvest_checkpoint({"level_id": level_id,
				"order_index": int(asked_order), "delivered": {}})
	if OS.get_environment("SHOT_SKIP_TUTORIAL") == "1":
		_mark_all_harvest_lessons_taught()
	if OS.get_environment("SHOT_DIFFICULTY") != "":
		SaveManager.set_setting("difficulty", int(OS.get_environment("SHOT_DIFFICULTY")))
	SaveManager.set_setting("reduce_motion", OS.get_environment("SHOT_REDUCE_MOTION") == "1")

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("screenshot_tool: cannot load %s" % scene_path)
		await ProbeLifecycle.finish(self, 2)
		return
	add_child(packed.instantiate())

	await get_tree().create_timer(wait).timeout
	RenderingServer.force_draw(false)

	var image := get_viewport().get_texture().get_image()
	var has_content := ProbeLifecycle.image_has_content(image)
	var err := image.save_png(out_path)
	if has_content:
		print("screenshot_tool: CONTENT PASSED")
	else:
		print("screenshot_tool: CONTENT FAILED (blank or transparent capture)")
	print("screenshot_tool: %s -> %s (%s)" % [scene_path, out_path, error_string(err)])
	await ProbeLifecycle.finish(self, 0 if err == OK and has_content else 1)


## A screenshot called "skip tutorial" must not leave the gesture lesson for
## whichever level was selected. Key lessons from the same level data as the
## game, so new harvest gestures are skipped here without another fixture list.
func _mark_all_harvest_lessons_taught() -> void:
	var learned: Array = []
	for level in GameData.levels:
		if str(level.get("game_type", "")) != "harvest_action":
			continue
		var config: Dictionary = level.get("config", {})
		var lesson := str(config.get("teaches", ""))
		if lesson != "" and not learned.has(lesson):
			learned.append(lesson)
	SaveManager.set_setting("harvest_taught", learned)
