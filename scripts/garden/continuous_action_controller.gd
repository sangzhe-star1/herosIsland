extends RefCounted
## One stroke of a farm tool: which beds it has already touched, and which it
## may touch next.
##
##     const Stroke := preload("res://scripts/garden/continuous_action_controller.gd")
##
## THE TWO GATES, AND WHY BOTH
##
## A brush stroke visits the same bed many times -- a finger wobbles, and a
## child scrubs back and forth on purpose because scrubbing is satisfying. So
## every bed the stroke passes over is asked two questions, in order:
##
##   1. has THIS stroke already worked on this bed?   (the done list)
##   2. does this bed actually need this tool?        (Tools.needs)
##
## Gate one is the money gate: without it, scrubbing across a ripe bed would
## harvest it, reset it, and then -- next pass -- find it tilled and do nothing
## ONLY BY LUCK of what harvesting resets to. The gate makes "once per stroke"
## a rule rather than a coincidence, and the probe proves it with the one
## number that cannot lie: how many strawberries ended up in the barn.
##
## Gate two is the kindness gate: sweeping the watering can across six beds
## waters the two thirsty ones and leaves the rest alone, so there is no wrong
## way to sweep. It is the same rule that greys the button, asked per bed.
##
## Nothing here saves, draws, or knows what the jobs DO -- garden_screen owns
## that. This is bookkeeping for one gesture, thrown away when the finger lifts.

const Tools := preload("res://scripts/garden/farm_tool_controller.gd")

var _done: Dictionary = {}
## How many beds this stroke actually worked on. The combo counter reads it,
## and "did anything happen at all" at stroke end reads it -- a stroke that
## did nothing has nothing to save.
var applied := 0


func begin() -> void:
	_done.clear()
	applied = 0


## Close one stroke and hand its single commit decision to the page.
##
## `did_work` is the only reason the save layer should write at finger-up;
## reset the gesture here so a later stroke can never inherit its old count or
## once-per-bed set. The page still owns persistence and feedback.
func finish() -> Dictionary:
	var result := {
		"applied": applied,
		"did_work": applied > 0,
	}
	begin()
	return result


## May the brush work on this bed? Marks the bed as done ONLY when the answer
## is yes -- a bed that did not need the job when the stroke first crossed it
## stays askable, which costs nothing because the answer will still be no.
func may_apply(tools: Tools, plots: Array, index: int) -> bool:
	if index < 0 or index >= plots.size():
		return false
	if _done.has(index):
		return false
	if not tools.needs(tools.selected, plots[index]):
		return false
	_done[index] = true
	applied += 1
	return true
