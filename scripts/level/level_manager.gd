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
	# A deep copy: challenge scaling mutates targets and knobs per run, and
	# the original dictionaries in GameData must never drift.
	level_data = GameManager.current_level_data().duplicate(true)
	if level_data.is_empty():
		push_warning("LevelManager: no level data; running in standalone test mode")
		level_data = _debug_level_data()
	result = LevelResult.new(level_data.get("id", ""))
	# Same dictionary object the templates mutate in setup_level(), so any
	# challenge scaling applied there is what completion is measured against.
	result.target_override = level_data.get("target", {})
	setup_level()
	_speak_instruction()


## How many times this challenge has been beaten before -- 0 for ordinary
## levels. Templates read this in setup_level() and grow themselves: more to
## do, a little denser, never faster than the no-speed rule allows. This is
## the level system that expands forever without new content.
# --- difficulty ------------------------------------------------------------
#
# One dial, set once by a parent, felt in every game. The island shipped at
# a single pitch and a six-year-old outgrew it in a fortnight -- but the
# NEXT child to pick up the tablet may be four. So each template scales two
# or three of its own knobs off this, rather than the game shipping three
# copies of every level.
#
# Gentle is genuinely gentler, not slower: fewer things at once, longer
# gaps, more forgiveness. Brave is genuinely braver. The house rules never
# move -- no failure, one star minimum, nothing flashes -- at any setting.

const GENTLE := 0
const NORMAL := 1
const BRAVE := 2


func difficulty() -> int:
	return clampi(int(SaveManager.get_setting("difficulty", NORMAL)), GENTLE, BRAVE)


## Scale a number one notch per difficulty step. `per_step` above 1.0 means
## the number grows with difficulty (speed, count); below 1.0 means it
## shrinks (intervals, forgiveness windows).
func harder(value: float, per_step: float) -> float:
	return value * pow(per_step, float(difficulty() - NORMAL))


## The same, in whole numbers: how many more (or fewer) of a thing.
func harder_i(value: int, per_step: int) -> int:
	return maxi(value + per_step * (difficulty() - NORMAL), 1)


func challenge_rank() -> int:
	if not bool(level_data.get("challenge", false)):
		return 0
	return SaveManager.get_challenge_rank(str(level_data.get("id", "")))


## Raise a target counter for challenge runs, e.g. bump_target("correct", 3).
func bump_target(key: String, extra: int) -> void:
	var target: Dictionary = level_data.get("target", {})
	target[key] = int(target.get(key, 0)) + extra
	level_data["target"] = target


## The world this level takes place in, drawn.
##
## Every template calls this and nothing else to get its scenery. Before the
## architecture pass each template drew its own sky, or loaded whatever PNG its
## `background_art` key named, which is why the game contained a photographic
## night city, a flat pastel village and a grey rectangle at the same time.
##
## `calm` quiets the scenery for templates whose gameplay is a reading task --
## a sorting grid over a busy meadow is harder to look at than it is pretty.
func build_world(parent: Node, calm: float = 0.0) -> Stage:
	var world_id: String = str(level_data.get("world", "island"))
	var config: Dictionary = level_data.get("config", {})
	var style: WorldStyle = WorldStyle.for_world(world_id)
	style.calm = calm
	style.apply_config(config)
	# Seeded on the level id, so a child who replays a level comes back to the
	# same place rather than a freshly shuffled one.
	return Stage.build(parent, style, str(level_data.get("id", world_id)))


## Override in subclasses. Read level_data for difficulty knobs.
func setup_level() -> void:
	pass


## Does hitting the target end the level by itself?
##
## True for the older templates, where "get ten right" IS the level. False for
## adventure levels, where collecting is one beat among several and the level
## ends at the chest -- without this they would finish on the first orb,
## because an empty target satisfies met_target() immediately.
func auto_complete_on_target() -> bool:
	return true


## Override to react when the child gets something right or wrong.
func on_correct() -> void:
	pass


func on_mistake() -> void:
	pass


func _process(delta: float) -> void:
	if not _finished:
		_elapsed += delta


func _speak_instruction() -> void:
	# A recording named after the level wins; the old explicit `voice_intro`
	# field still works for anything that has one. Neither is required --
	# every level is playable in silence, and that is how it ships until
	# somebody sits down with a phone and the script.
	if AudioManager.play_level_voice(str(level_data.get("id", ""))):
		return
	var voice: String = level_data.get("voice_intro", "")
	if voice != "":
		AudioManager.play_voice(voice)


func target_value(key: String, fallback: int) -> int:
	return int(level_data.get("target", {}).get(key, fallback))


## How many right answers between spoken praise. Every one would be a running
## commentary; never would waste a recorded voice. Four is about one warm word
## a minute, which is how an adult sitting beside a child actually behaves.
const PRAISE_EVERY := 4

## Call when the child does the right thing.
func score_correct() -> void:
	if _finished:
		return
	result.correct += 1
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	if result.correct % PRAISE_EVERY == 0:
		# Rotated, not random: the same one twice running sounds like a
		# machine, and a child hears that immediately.
		AudioManager.say("praise_%d" % (1 + (result.correct / PRAISE_EVERY) % 3))
	on_correct()
	correct_scored.emit(result.correct)
	# `has_target()` first, and it is not belt-and-braces: a level with no
	# target has no finish line, and met_target() says yes to no finish line.
	# Templates that end themselves leave the target empty on purpose, and for
	# one of them -- the duel -- that meant the level ended on the first hit.
	if auto_complete_on_target() and result.has_target() and result.met_target():
		complete_level()


## Call when the child gets it wrong. No penalty, no scary sound, no lost
## progress -- just a gentle nudge and another try.
func score_mistake() -> void:
	if _finished:
		return
	result.mistakes += 1
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	# Spoken once per level, on the first slip. After that the child knows
	# what the sound means and being told again is nagging.
	if result.mistakes == 1:
		AudioManager.say("retry")
	on_mistake()
	mistake_made.emit(result.mistakes)


func complete_level() -> void:
	if _finished:
		return
	_finished = true
	result.duration_seconds = _elapsed
	AudioManager.say("finish")
	level_completed.emit(result)
	await get_tree().create_timer(1.2).timeout
	GameManager.finish_level(result)


## Leaving early is allowed and costs nothing.
##
## One rule, said once: **他从哪进来，就从哪出去**. Where that is lives in
## DATA, never in code -- the room-naming rule forbids naming a room here, and
## a missing or misspelt destination falls back to the world map, so a child is
## never locked in anywhere by a typo.
##
## Two fields, because there are two kinds of "where":
##
##   config.exit_room -- another LEVEL (装饰间回菜园, 丰收八关回菜园)
##   config.exit_to   -- a SCREEN that is not a level; "home" is the only one
##
## Everything with neither goes back to the world map, which is right for the
## 34 levels whose door is a pin on the island.
##
## 这条规则是两次实测撞出来的。菜园先是回英雄基地（验收 #16 原文，7-29），
## 迷路；改回世界地图（7-30），还是迷路——因为他根本不是从岛上进去的，他是
## 从首页那张卡片进去的。所以菜园现在**不在岛上**（mode: standalone），
## 出口是首页。同一天发现丰收八关也一样：门开在菜园里，出来却站在岛上。
func quit_level() -> void:
	if _finished:
		return
	_finished = true
	result.quit_early = true
	result.duration_seconds = _elapsed
	go_out_the_way_he_came_in(level_data)


## The one place that turns a level's data into a destination. Shared with the
## result screen so "退出" and "结算页上的返回" can never disagree -- they used
## to, and the disagreement is invisible until a child takes the other door.
static func go_out_the_way_he_came_in(data: Dictionary) -> void:
	var config: Dictionary = data.get("config", {})
	var exit_room := str(config.get("exit_room", ""))
	if exit_room != "" and not GameData.get_level(exit_room).is_empty():
		GameManager.start_level(exit_room)
		return
	if str(config.get("exit_to", "")) == "home":
		SceneManager.goto_home()
		return
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
