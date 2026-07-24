extends Node
## Session state: which level is running, and how long the child has played.
## Also owns the daily-limit check, which is advisory only -- it tells the child
## it is time to stop, it never locks them out mid-level.

signal level_finished(result: LevelResult)

var current_level_id: String = ""
var current_world_id: String = "safety"

var _session_start_ms: int = 0
var _last_result: LevelResult = null


func _ready() -> void:
	_session_start_ms = Time.get_ticks_msec()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		flush_playtime()


## Bank the elapsed time so the Parent Center is accurate even if the app is
## closed abruptly, which with a six-year-old is the normal case.
func flush_playtime() -> void:
	var now := Time.get_ticks_msec()
	var elapsed := float(now - _session_start_ms) / 1000.0
	if elapsed > 0.0:
		SaveManager.add_playtime(elapsed)
	_session_start_ms = now


func start_level(level_id: String) -> void:
	var level := GameData.get_level(level_id)
	if level.is_empty():
		push_error("GameManager: unknown level %s" % level_id)
		return
	var scene_path := GameData.get_minigame_scene(level.get("game_type", ""))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_error("GameManager: no scene for game_type %s" % level.get("game_type", ""))
		return
	current_level_id = level_id
	current_world_id = level.get("world", current_world_id)
	SceneManager.goto_scene(scene_path)


## Called by every minigame when it ends. The minigame reports raw performance;
## scoring and reward rules live here so all levels stay consistent.
func finish_level(result: LevelResult) -> void:
	_last_result = result
	RewardManager.grant_for_level(result)
	# A beaten challenge grows: next time it is one rank bigger.
	var level := GameData.get_level(result.level_id)
	if bool(level.get("challenge", false)) and not result.quit_early:
		SaveManager.bump_challenge_rank(result.level_id)
	flush_playtime()
	level_finished.emit(result)
	SceneManager.goto_scene("res://scenes/ui/ResultScreen.tscn")


func get_last_result() -> LevelResult:
	return _last_result


func current_level_data() -> Dictionary:
	return GameData.get_level(current_level_id)


func daily_limit_reached() -> bool:
	var limit_minutes: float = float(SaveManager.get_setting("daily_limit_minutes", 30))
	if limit_minutes <= 0.0:
		return false
	return SaveManager.playtime_today() >= limit_minutes * 60.0
