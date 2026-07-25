extends Node
## Photographs one adventure level at each of its beats.
##
##   SHOT_LEVEL=sunny_park_01 SHOT_DIR=/tmp/adv \
##     xvfb-run -a godot --path . --rendering-driver opengl3 \
##     res://tests/AdventureShots.tscn
##
## A single screenshot of the first screen proves the level boots. It does not
## show whether a pit reads as a pit, whether the gate and its plate are on
## screen together, or whether the chest is visible from where the interact
## key appears. Those are the pictures that matter and they are all 2000 px
## into the level, where no ordinary screenshot ever goes.
##
## The hero is walked to each spot with the ordinary buttons and given a moment
## to settle, so what comes out is a frame from a real run.

func _ready() -> void:
	var out_dir := OS.get_environment("SHOT_DIR")
	var level_id := OS.get_environment("SHOT_LEVEL")
	if out_dir == "":
		out_dir = "/tmp/adventure-shots"
	if level_id == "":
		level_id = "sunny_park_01"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)

	GameManager.current_level_id = level_id
	var lvl: Node = load("res://scenes/adventure/Adventure.tscn").instantiate()
	add_child(lvl)
	for i in range(4):
		await get_tree().process_frame

	var stops: Array = [["1-start", lvl.SPAWN_X]]
	if lvl._orbs.size() > 0:
		stops.append(["2-orbs", float((lvl._orbs[1]["at"] as Vector2).x)])
	if lvl._springs.size() > 0:
		stops.append(["3-spring", float(lvl._springs[0]["at"])])
	if lvl._rocks.size() > 0:
		stops.append(["3-rocks", (float(lvl._rocks[0]["left"])
			+ float(lvl._rocks[0]["right"])) * 0.5])
	if lvl._crates.size() > 0:
		stops.append(["4-crate", (lvl._crates[0]["node"] as Node2D).position.x + 120.0])
	if lvl._seq_groups.size() > 0:
		stops.append(["5-plates", float(lvl._seq_groups[0]["plates"][1]["at"])])
	if lvl._vents.size() > 0:
		stops.append(["6-fire", float(lvl._vents[0]["at"]) + 120.0])
	if lvl._puzzles.size() > 0:
		stops.append(["7-sign", float(lvl._puzzles[0]["at"])])
		stops.append(["8-card", float(lvl._puzzles[0]["at"])])
	if lvl._gates.size() > 0:
		stops.append(["9-gate", float(lvl._gates[0]["at"]) - 140.0])
	if not lvl._chest.is_empty():
		stops.append(["9-chest", float(lvl._chest["at"]) - 120.0])

	for stop in stops:
		var name: String = stop[0]
		var at: float = stop[1]
		# Gates shut ahead of a stop would clamp the hero short of it, so
		# open them: this tool photographs places, it does not play the level.
		for gate in lvl._gates:
			if float(gate["at"]) < at + 200.0:
				gate["open"] = true
		lvl._hero.place_at(Vector2(at, lvl._ground_y))
		if name == "8-card" and lvl._puzzles.size() > 0:
			lvl._open_card(lvl._puzzles[0])
		# Let the camera catch up and the props finish bobbing into place.
		for i in range(30):
			await get_tree().physics_frame
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, name]
		var err := image.save_png(path)
		print("  %s -> %s (%s)" % [name, path, error_string(err)])

	print("adventure shots done")
	get_tree().quit(0)
