extends RefCounted
## Resolve the farm's three hint levels against the live task and plot state.
## The screen still owns the callbacks' input lifecycle and the world itself.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
const LessonView := preload("res://scripts/garden/farm_lesson_view.gd")


static func next_plot(screen: Node) -> int:
	var plots: Array = screen.call("_plots")
	var harvesting: Dictionary = screen.get("_harvesting")
	return Tools.next_action_index(plots, harvesting)


## Level one: repeat the instruction for the most useful live task and glow it.
static func nudge(screen: Node) -> void:
	var task: Dictionary = screen.call("_next_task")
	var world: Variant = screen.get("_world")
	if str(task.get("kind", "")) == "deliver":
		AudioManager.say("garden_tut_order")
		if world != null and is_instance_valid(world):
			var board_at: Vector2 = world.call("facility_screen_position", "orders")
			LessonView.new(screen).highlight(board_at)
		return
	var index := next_plot(screen)
	var plots: Array = screen.call("_plots")
	if index < 0 or index >= plots.size():
		return
	var plot: Dictionary = plots[index]
	match str(plot.get("state", "")):
		Farm.READY:
			AudioManager.say("garden_tut_harvest")
		Farm.NEEDS_CARE:
			match str(plot.get("care_event", "")):
				Growth.CARE_WEEDS: AudioManager.say("harvest_pull_up")
				Growth.CARE_BUG: AudioManager.say("harvest_shoo_bug")
				_: AudioManager.say("garden_tut_water")
		Farm.EMPTY:
			AudioManager.say("garden_tut_till")
		_:
			AudioManager.say("garden_tut_plant")
	var bed_at: Vector2 = screen.call("_bed_centre", index)
	LessonView.new(screen).highlight(bed_at)


## Level two: show the existing gesture for this task, or point to the board.
static func show_move(screen: Node) -> void:
	var task: Dictionary = screen.call("_next_task")
	if str(task.get("kind", "")) == "deliver":
		screen.call("_point_at", "order")
		return
	var index := next_plot(screen)
	var plots: Array = screen.call("_plots")
	if index < 0 or index >= plots.size():
		return
	var bed_at: Vector2 = screen.call("_bed_centre", index)
	var seed_at: Vector2 = screen.call("_seed_rack_centre")
	var state := str(plots[index].get("state", ""))
	LessonView.new(screen).show_move(state, bed_at, seed_at)


## Level three: prepare only the hard part. Orders and one-step care stay the
## child's action; for bare earth, turning it over leaves the seed to him.
static func do_hard_part(screen: Node) -> void:
	var task: Dictionary = screen.call("_next_task")
	if str(task.get("kind", "")) == "deliver":
		show_move(screen)
		return
	var index := next_plot(screen)
	var plots: Array = screen.call("_plots")
	if index < 0 or index >= plots.size():
		return
	if str(plots[index].get("state", "")) != Farm.EMPTY:
		show_move(screen)
		return
	var tools: Variant = screen.get("_tools")
	var result: Dictionary = tools.apply_to_plot("shovel", plots[index])
	if result.is_empty():
		return
	plots[index] = result.get("plot", plots[index])
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	screen.call("_queue_rebuild")
