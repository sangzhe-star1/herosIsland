extends RefCounted
## Own the lifetime of the first-planting lesson: its greeting beat, live
## growth refresh, and the single event that records the lesson as complete.
## GardenScreen remains the source of lesson steps and target presentation.

const FarmTick := preload("res://scripts/garden/farm_tick_controller.gd")

const WELCOME_BEAT := 2.0
const LESSON_TICK := 0.5

var running := false
var said := ""
var tutorial_growth := 0


func teach(screen: Node) -> void:
	var plan: Dictionary = GameData.garden_tutorial
	var crop_id := str(plan.get("crop_id", "carrot"))
	tutorial_growth = int(GameData.get_crop(crop_id).get(
		"tutorial_growth_override", 0))
	running = true

	# The greeting is the one line that is not about a job, so it is the one
	# line the garden cannot ask for. Everything after it is.
	said = "welcome"
	screen.call("_say_the_step", "welcome")
	tick(screen)
	var tree: SceneTree = screen.get_tree()
	await tree.create_timer(WELCOME_BEAT).timeout
	if running and screen.is_inside_tree():
		advance(screen)


## Called from redraws, which happen after actions and meaningful clock beats.
## Repeated questions are quiet; only a new step gets a line and a finger.
func advance(screen: Node) -> void:
	if not running:
		return
	var step := str(screen.call("_lesson_step"))
	if step == "" or step == said:
		return
	said = step
	screen.call("_say_the_step", step)


## The tutorial crop settles in memory on a faster beat while the child watches.
## Growth still derives from the planted timestamp and is never saved here.
func tick(screen: Node) -> void:
	while running and screen.is_inside_tree():
		await screen.get_tree().create_timer(LESSON_TICK).timeout
		if not running or not screen.is_inside_tree():
			return
		SaveManager.settle_farm(false)
		var plots: Array = screen.call("_plots")
		if FarmTick.visual_signature(plots) != str(screen.get("_beds_looked_like")):
			screen.call("_queue_rebuild")


## The first delivery sets this before the order transaction's one save.
func finish(screen: Node) -> void:
	if not running:
		return
	running = false
	var farm: Dictionary = screen.call("_farm")
	farm["tutorial_completed"] = true
