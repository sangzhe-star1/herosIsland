extends Node
## The result screen, loaded up with everything it can possibly show at once,
## and checked for anything hanging off the edge of the screen.
##
##   xvfb-run -a godot --path . res://tests/ResultProbe.tscn
##
## Why this exists: the screen stacks its rewards in one centred column, so it
## looked right in every ordinary run and then quietly clipped the title AND
## the buttons on the one run where a child earned everything at once -- a
## three-star finish, a new badge, a level-up and the end of a world, all on
## the same screen. That is the BEST run they will ever have, and it was the
## one run where they could not see the buttons.
##
## So the probe builds exactly that run and asserts every child of the screen
## sits inside 1280x720. Failing loudly on the happiest case is the point.

const W := 1280.0
const H := 720.0


func _ready() -> void:
	var window := get_window()
	if window != null:
		window.size = Vector2i(int(W), int(H))
		window.content_scale_size = Vector2i(int(W), int(H))

	print("=== result probe ===")
	var failures: Array[String] = []

	# Case 1: the fullest screen the game can produce.
	failures.append_array(await _check("everything at once", true))
	# Case 2: an ordinary two-star run with no extras, to prove the fix did not
	# squash the common case.
	failures.append_array(await _check("an ordinary run", false))
	failures.append_array(await _the_lesson_waits_for_the_whole_world())

	if failures.is_empty():
		print("RESULT PROBE PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			print("  FAIL: ", f)
		print("RESULT PROBE FAILED")
		get_tree().quit(1)


func _check(label: String, loaded: bool) -> Array[String]:
	print("-- ", label)
	_prime(loaded)
	var screen: Control = load("res://scenes/ui/ResultScreen.tscn").instantiate()
	add_child(screen)
	# Long enough for the star tween chain and the coin flight to settle, so
	# the measurement is of the screen at rest rather than mid-animation.
	await get_tree().create_timer(2.6).timeout

	var out: Array[String] = []
	# The measuring works headless -- Control layout is arithmetic, not
	# rendering -- so this runs in the smoke suite. The picture only comes out
	# when there is something to draw into. Waiting on frame_post_draw has to
	# stay inside this branch too: headless never draws a frame, so awaiting it
	# there waits forever.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := "/tmp/result_%s.png" % ("full" if loaded else "plain")
		get_viewport().get_texture().get_image().save_png(shot)
		print("   shot -> ", shot)

	for node in _visible_controls(screen):
		var r: Rect2 = node.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		# Coins in flight legitimately leave the column, and the celebrating
		# hero stands at the edge on purpose. Everything a child has to READ
		# or PRESS has to be inside the screen.
		if not (node is Label or node is Button):
			continue
		if r.position.y < -1.0:
			out.append("%s '%s' starts %.0f px above the top"
				% [label, _name_of(node), -r.position.y])
		if r.end.y > H + 1.0:
			out.append("%s '%s' runs %.0f px below the bottom"
				% [label, _name_of(node), r.end.y - H])
		if r.position.x < -1.0 or r.end.x > W + 1.0:
			out.append("%s '%s' runs off the side" % [label, _name_of(node)])

	screen.queue_free()
	await get_tree().process_frame
	return out


func _name_of(node: Control) -> String:
	if node is Label:
		return (node as Label).text.substr(0, 18)
	if node is Button:
		return (node as Button).text.substr(0, 18)
	return node.name


func _visible_controls(root: Node, out: Array[Control] = []) -> Array[Control]:
	for child in root.get_children():
		if child is Control and (child as Control).visible:
			out.append(child as Control)
		_visible_controls(child, out)
	return out


## The best run a child can have: finished the last level of a world with
## every star, a new badge, enough experience to rank up, and a rest due.
func _prime(loaded: bool) -> void:
	var result := LevelResult.new("night_city_06")
	result.objective_scoring = true
	result.reached_goal = true
	result.found_hidden = loaded
	result.clean_run = false
	result.correct = 8
	GameManager.current_level_id = "night_city_06"
	GameManager.current_world_id = "night_city"
	# Set directly rather than through finish_level(), which would grant the
	# rewards a second time and change scene out from under the probe.
	GameManager.set("_last_result", result)

	RewardManager.last_coins_earned = 28 if loaded else 0
	RewardManager.last_new_badge = "tidy_helper" if loaded else ""
	RewardManager.last_xp_earned = 35 if loaded else 0
	RewardManager.last_levels_gained = 1 if loaded else 0

	if loaded:
		# Every level of the world done, so the screen also offers the lesson
		# button -- a fourth button on the row.
		for entry in GameData.get_levels_for_world("night_city"):
			var lid := str(entry.get("id", ""))
			var progress: Dictionary = SaveManager.get_level_progress(lid)
			progress["completed"] = true
			SaveManager.data["levels"][lid] = progress
		# should_offer() adds one and tests for a multiple of three.
		SaveManager.set_setting("levels_this_session", RestDirector.EVERY - 1)
	else:
		SaveManager.set_setting("levels_this_session", 0)


## The end-of-episode lesson appears when a WORLD is finished, and not before.
##
## This is the only video-shaped thing in the game -- the three-panel animation
## a cartoon plays before the credits -- and it is gated on every level of a
## world being done. Worth checking both ways round: a lesson that never
## appears is content nobody sees, and one that appears a level early spends
## the moment it was saving up for.
func _the_lesson_waits_for_the_whole_world() -> Array[String]:
	var out: Array[String] = []
	for world_id in ["sunny_park", "night_city", "dark_castle"]:
		var levels: Array = []
		for entry in GameData.get_levels_for_world(world_id):
			if str(entry.get("id", "")) != "hero_studio":
				levels.append(str(entry.get("id", "")))
		if levels.size() < 2:
			continue

		# One level short of the whole world.
		SaveManager.data["levels"] = {}
		for i in range(levels.size() - 1):
			SaveManager.record_level_result(levels[i], 2, 1.0)
		var early := await _lesson_offered(world_id, levels[levels.size() - 1])
		# ...and now the last one.
		SaveManager.record_level_result(levels[levels.size() - 1], 2, 1.0)
		var done := await _lesson_offered(world_id, levels[levels.size() - 1])

		print("  %-15s %d levels: one short -> %s, all done -> %s"
			% [world_id, levels.size(),
				"offered" if early else "not offered",
				"offered" if done else "NOT OFFERED"])
		if early:
			out.append("%s offers the lesson with a level still unfinished"
				% world_id)
		if not done:
			out.append("%s finished every level and the lesson never appeared"
				% world_id)
	return out


func _lesson_offered(world_id: String, last_level: String) -> bool:
	GameManager.current_world_id = world_id
	GameManager.current_level_id = last_level
	var result := LevelResult.new(last_level)
	result.objective_scoring = true
	result.reached_goal = true
	GameManager.set("_last_result", result)
	RewardManager.last_coins_earned = 0
	RewardManager.last_new_badge = ""
	RewardManager.last_xp_earned = 0
	RewardManager.last_levels_gained = 0
	SaveManager.set_setting("levels_this_session", 0)

	var screen: Control = load("res://scenes/ui/ResultScreen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var found := false
	for node in _visible_controls(screen):
		if node is Button and str((node as Button).text) == I18n.t("lesson.watch"):
			found = true
	screen.queue_free()
	await get_tree().process_frame
	return found
