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
	if mistakes == 0:
		return 3
	elif mistakes <= 2:
		return 2
	return 1


func met_target() -> bool:
	var target: Dictionary = target_override
	if target.is_empty():
		target = GameData.get_level(level_id).get("target", {})
	for key in target.keys():
		if key == "correct_crossings" or key == "correct":
			if correct < int(target[key]):
				return false
	return true
