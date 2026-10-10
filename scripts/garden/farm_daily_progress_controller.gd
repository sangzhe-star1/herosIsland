extends RefCounted
## Record one daily-care action and report the milestones it crossed.
##
## Rolling yesterday's completed list before comparing today is important:
## otherwise yesterday's full tally can suppress today's first completion
## chime. The screen receives the two events and owns their sounds.

const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")


static func record(farm: Dictionary, today: String, verb: String,
		by: int = 1) -> Dictionary:
	# roll() reuses today's nested dictionary, and add() mutates its progress;
	# snapshot before changing it so completion remains a real edge transition.
	var before: Dictionary = Dailies.roll(farm, today).duplicate(true)
	var after: Dictionary = Dailies.add(farm, today, verb, by)
	var task_completed := false
	for task in GameData.garden_dailies:
		if str(task.get("id", "")) != verb:
			continue
		task_completed = Dailies.done(after, task) \
			and not Dailies.done(before, task)
		break
	var all_completed := Dailies.all_done(after) \
		and not Dailies.all_done(before)
	farm["dailies"] = after
	return {
		"dailies": after,
		"task_completed": task_completed,
		"all_completed": all_completed,
	}
