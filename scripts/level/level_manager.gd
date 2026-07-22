class_name LevelManager
extends Node2D
## Base class every minigame extends. Handles the shared shape of a level:
## read config, speak the instruction, tally correct answers and mistakes,
## and report a LevelResult when the goal is met.
##
## A subclass only implements the actual gameplay. This is what lets one
## template ("traffic_crossing") serve four different levels via JSON.

signal correct_scored(total: int)
signal mistake_made(total: int)
signal level_completed(result: LevelResult)

var level_data: Dictionary = {}
var result: LevelResult

var _elapsed := 0.0
var _finished := false


func _ready() -> void:
	level_data = GameManager.current_level_data()
	if level_data.is_empty():
		push_warning("LevelManager: no level data; running in standalone test mode")
		level_data = _debug_level_data()
	result = LevelResult.new(level_data.get("id", ""))
	setup_level()
	_speak_instruction()


## Override in subclasses. Read level_data for difficulty knobs.
func setup_level() -> void:
	pass


## Override to react when the child gets something right or wrong.
func on_correct() -> void:
	pass


func on_mistake() -> void:
	pass


func _process(delta: float) -> void:
	if not _finished:
		_elapsed += delta


func _speak_instruction() -> void:
	var voice: String = level_data.get("voice_intro", "")
	if voice != "":
		AudioManager.play_voice(voice)


func target_value(key: String, fallback: int) -> int:
	return int(level_data.get("target", {}).get(key, fallback))


## Call when the child does the right thing.
func score_correct() -> void:
	if _finished:
		return
	result.correct += 1
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	on_correct()
	correct_scored.emit(result.correct)
	if result.met_target():
		complete_level()


## Call when the child gets it wrong. No penalty, no scary sound, no lost
## progress -- just a gentle nudge and another try.
func score_mistake() -> void:
	if _finished:
		return
	result.mistakes += 1
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	on_mistake()
	mistake_made.emit(result.mistakes)


func complete_level() -> void:
	if _finished:
		return
	_finished = true
	result.duration_seconds = _elapsed
	level_completed.emit(result)
	await get_tree().create_timer(1.2).timeout
	GameManager.finish_level(result)


## Leaving early is allowed and costs nothing.
func quit_level() -> void:
	if _finished:
		return
	_finished = true
	result.quit_early = true
	result.duration_seconds = _elapsed
	SceneManager.goto_world_map()


func _debug_level_data() -> Dictionary:
	return {
		"id": "debug",
		"world": "safety",
		"game_type": "traffic_crossing",
		"difficulty": 1,
		"target": {"correct_crossings": 3},
		"reward": {"stars": 3, "coins": 20, "badge": ""},
	}
