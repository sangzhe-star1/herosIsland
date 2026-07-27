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
	_session_start_ms = GameClock.ticks_ms()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		flush_playtime()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# The clock this counts with does NOT stop while iOS holds the app
		# suspended, and nothing here used to notice coming back -- so twenty
		# minutes of play plus three hours in a bag was banked as three hours
		# and twenty minutes of play, and a child who had played once that
		# morning was told he was finished for the day.
		#
		# Start a fresh session instead of flushing: the time spent in the bag
		# belongs to nobody.
		_session_start_ms = GameClock.ticks_ms()


## Bank the elapsed time so the Parent Center is accurate even if the app is
## closed abruptly, which with a six-year-old is the normal case.
func flush_playtime() -> void:
	var now := GameClock.ticks_ms()
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


## The level to offer after this one, or "" when there is nothing further.
##
## Walks data/levels.json in order from the level just finished and returns the
## first one that is unlocked and actually implemented. Same world first, so a
## child works through Hero City before being sent to Piglet Town, and the
## whole list afterwards so finishing a world does not dead-end.
##
## Why this exists: the result screen offered "Play Again" and "Back to Map"
## and nothing else, so the only way to reach the next level was to go back to
## the map and find it. For a six-year-old that is the difference between a
## game that carries them forward and one that stops after every level.
func next_level_id() -> String:
	var levels: Array = GameData.levels
	var index := -1
	for i in range(levels.size()):
		if str(levels[i].get("id", "")) == current_level_id:
			index = i
			break
	if index < 0:
		return ""
	var world: String = str(levels[index].get("world", ""))

	var same_world := _first_playable_after(levels, index, world)
	if same_world != "":
		return same_world
	return _first_playable_after(levels, index, "")


func _first_playable_after(levels: Array, index: int, world: String) -> String:
	for i in range(index + 1, levels.size()):
		var level: Dictionary = levels[i]
		if world != "" and str(level.get("world", "")) != world:
			continue
		var id: String = str(level.get("id", ""))
		if id == "" or id == current_level_id:
			continue
		if not SaveManager.is_level_unlocked(id):
			continue
		var scene: String = GameData.get_minigame_scene(str(level.get("game_type", "")))
		if scene == "" or not ResourceLoader.exists(scene):
			continue
		return id
	return ""


func daily_limit_reached() -> bool:
	var limit_minutes: float = float(SaveManager.get_setting("daily_limit_minutes", 30))
	if limit_minutes <= 0.0:
		return false
	return SaveManager.playtime_today() >= limit_minutes * 60.0
