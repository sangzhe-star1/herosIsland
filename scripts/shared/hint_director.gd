class_name HintDirector
extends Node
## Helping a stuck child, in three steps, without ever saying they got it wrong.
##
## The rule from the brief, and it is a good one:
##
##   one failure   -- say the instruction again, and make the target glow
##   two failures  -- show a finger doing the action
##   three failures -- DO the hardest part for them, and leave the last step
##                     so the child is the one who finishes it
##
## That last line is the whole design. A game that solves the puzzle for you
## has taken it away; a game that does the hard bit and hands you the final
## piece has given you a win. At six the difference is enormous, and it is the
## difference between putting the tablet down and asking for one more.
##
## Nine templates share this, because a child should not have to learn what
## "stuck" looks like separately in each one. A template hands over three
## callables and stops thinking about it.

signal escalated(level: int)      # 1, 2 or 3

## Seconds of no progress that count as being stuck, even without a mistake.
## A child who is not failing but not moving needs help just as much -- they
## are usually the one who has not understood what to do at all.
const IDLE := 11.0

var _misses := 0
var _level := 0
var _idle := 0.0
var _armed := true

var _on_nudge: Callable            # level 1: say it again, glow the target
var _on_show: Callable             # level 2: the finger
var _on_do_it: Callable            # level 3: do the hard part, leave the last


## Templates call this once in setup_level().
func watch(nudge: Callable, show: Callable, do_it: Callable) -> void:
	_on_nudge = nudge
	_on_show = show
	_on_do_it = do_it
	set_process(true)


func _process(delta: float) -> void:
	if not _armed:
		return
	_idle += delta
	if _idle >= idle_wait():
		_idle = 0.0
		_step()


## The child did something right. Everything resets -- being stuck once should
## not follow you around the level.
func progress() -> void:
	_misses = 0
	_level = 0
	_idle = 0.0


## How many wrong tries before help arrives. 1 is the old behaviour (help on
## the first miss) and stays the default for every level that never sets it.
## The harvest levels set it from the parent's difficulty switch: a braver
## child gets more room to be wrong before anyone leans in -- difficulty as
## patience, not punishment.
var misses_before_help := 1


## The child got something wrong. Not a punishment, a signal.
func missed() -> void:
	_misses += 1
	_idle = 0.0
	if _misses >= misses_before_help:
		_misses = 0
		_step()


func _step() -> void:
	_level = mini(_level + 1, 3)
	escalated.emit(_level)
	AudioManager.play_sfx("res://assets/audio/hint.ogg")
	# If a parent has recorded the hint lines, the game uses them; if not it
	# stays with the chime, which already says the same thing.
	AudioManager.say("hint_%d" % _level)
	match _level:
		1:
			if _on_nudge.is_valid():
				_on_nudge.call()
		2:
			if _on_show.is_valid():
				_on_show.call()
		_:
			if _on_do_it.is_valid():
				_on_do_it.call()
			# After doing it for them, start over: the next thing they get
			# stuck on deserves the gentle first step again, not the last one.
			_misses = 0
			_level = 0


## --- and the other direction ---------------------------------------------
##
## The brief asks for adaptation BOTH ways, and is careful about what "harder"
## is allowed to mean for a six-year-old: one more thing to find, positions
## moved about, an extra star to chase, hints that wait a little longer. It
## explicitly rules out the two things games normally reach for -- more speed
## and more enemies -- because neither of those is a new idea, they are just
## the same idea turned up until it stops being fun.
##
## So "doing well" here buys a child MORE GAME, never less mercy.

## Three levels in a row finished without needing a single hint. Deliberately
## slow to earn and instantly lost: one level that needed help puts it back.
const STREAK_FOR_MORE := 3


## Call once when a level ends. `used_help` is whether any hint fired.
static func record_run(used_help: bool) -> void:
	var streak: int = int(SaveManager.get_setting("clean_streak", 0))
	streak = 0 if used_help else streak + 1
	SaveManager.set_setting("clean_streak", streak)


## Is this child sailing through? Templates ask before they lay a level out.
static func doing_well() -> bool:
	return int(SaveManager.get_setting("clean_streak", 0)) >= STREAK_FOR_MORE


## One extra thing to find, for a child who does not need the help. The only
## kind of "harder" this game does: more to look at, not less time to look.
static func extra_things(base: int) -> int:
	return base + (1 if doing_well() else 0)


## Hints wait longer for someone who has not been needing them -- and the
## floor is generous, because a confident child still gets stuck sometimes.
static func idle_wait() -> float:
	return IDLE * (1.45 if doing_well() else 1.0)


## Stop watching -- during a cutscene, a card, or after the level is won.
func pause_watching(on: bool) -> void:
	_armed = not on
	if on:
		_idle = 0.0


func level() -> int:
	return _level
