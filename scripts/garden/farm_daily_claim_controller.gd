extends RefCounted
## Settle one completed daily job through the island's reward once gate.
##
## The screen still owns the date, save, and happy feedback. This controller
## owns the claim boundary: a job must be complete, its date-stamped key can
## pay once, and the claim is written back into the farm only when the reward
## was actually granted.

const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")


static func claim(farm: Dictionary, task: Dictionary, today: String) -> Dictionary:
	var dailies: Dictionary = Dailies.roll(farm, today)
	if Dailies.claimed(dailies, task) or not Dailies.done(dailies, task):
		return {"paid": 0, "claimed": false}

	var claimed_list: Array = dailies.get("claimed", [])
	var paid := RewardManager.grant("garden:daily",
		int(task.get("coins", 0)), Dailies.claim_key(dailies, task), claimed_list)
	if paid <= 0:
		return {"paid": 0, "claimed": false}

	dailies["claimed"] = claimed_list
	farm["dailies"] = dailies
	return {"paid": paid, "claimed": true, "dailies": dailies}
