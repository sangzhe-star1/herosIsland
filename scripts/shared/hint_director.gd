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
	if _idle >= IDLE:
		_idle = 0.0
		_step()


## The child did something right. Everything resets -- being stuck once should
## not follow you around the level.
func progress() -> void:
	_misses = 0
	_level = 0
	_idle = 0.0


## The child got something wrong. Not a punishment, a signal.
func missed() -> void:
	_misses += 1
	_idle = 0.0
	if _misses >= 1:
		_step()


func _step() -> void:
	_level = mini(_level + 1, 3)
	escalated.emit(_level)
	AudioManager.play_sfx("res://assets/audio/hint.ogg")
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


## Stop watching -- during a cutscene, a card, or after the level is won.
func pause_watching(on: bool) -> void:
	_armed = not on
	if on:
		_idle = 0.0


func level() -> int:
	return _level
