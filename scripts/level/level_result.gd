class_name LevelResult
extends RefCounted
## What a minigame reports back when it ends.
##
## Deliberately has no "failed" state. A level either ends because the child
## finished it or because they left. Mistakes reduce stars from three to one --
## never to zero, and never below what they already earned.

var level_id: String = ""
var correct: int = 0
var mistakes: int = 0
var duration_seconds: float = 0.0
var quit_early: bool = false

## --- the three objectives -------------------------------------------------
##
## Adventure levels do not score stars by counting slips. They ask three
## separate questions, and a child can answer them in any order across any
## number of tries:
##
##   1  did you finish?          (reach the chest)
##   2  did you find the secret? (the one hidden gem)
##   3  did you keep your hearts? (at most one hit)
##
## Why this and not "mistakes": a mistakes counter tells a six-year-old they
## were bad at the level. Three little pictures tell them exactly which door
## is still shut and invite them back for that one thing. It is the difference
## between a grade and a treasure map.
##
## Set `objective_scoring` and the three flags below become the star count.
## Everything that does not set it keeps the old behaviour untouched, which is
## how the twelve older templates survive the rebuild without edits.
var objective_scoring: bool = false
var reached_goal: bool = false
var found_hidden: bool = false
var clean_run: bool = false

## Live targets for this run. Challenge levels scale their goals per rank on
## a COPY of the level data; without this override met_target() would read
## the untouched original in GameData and finish the level at the base goal
## while the on-screen counter promised the scaled one.
var target_override: Dictionary = {}


func _init(p_level_id: String = "") -> void:
	level_id = p_level_id


func accuracy() -> float:
	var total := correct + mistakes
	if total <= 0:
		return 1.0
	return float(correct) / float(total)


## 3 stars = clean run, 2 = a couple of slips, 1 = finished at all.
## Finishing always earns at least one star. That is the point.
func stars() -> int:
	if quit_early:
		return 0
	if objective_scoring:
		# Still never zero for a level that was actually finished: reaching the
		# chest IS the first star, so the floor holds without a special case.
		var earned := 0
		if reached_goal:
			earned += 1
		if found_hidden:
			earned += 1
		if clean_run:
			earned += 1
		return earned
	if mistakes == 0:
		return 3
	elif mistakes <= 2:
		return 2
	return 1


## Which of the three doors are still shut, for the result screen to draw.
## Order matches the star row left to right.
func objectives() -> Array:
	return [
		{"icon": "chest", "done": reached_goal},
		{"icon": "gem", "done": found_hidden},
		{"icon": "heart", "done": clean_run},
	]


func met_target() -> bool:
	var target: Dictionary = target_override
	if target.is_empty():
		target = GameData.get_level(level_id).get("target", {})
	for key in target.keys():
		if key == "correct_crossings" or key == "correct":
			if correct < int(target[key]):
				return false
	return true
