extends RefCounted
## Settle everything that becomes true when the child walks into the farm.
##
## Offline growth, morning dew, today's jobs, and any scheduled bear visit all
## belong to this arrival. Persist once after all of them so the backup always
## represents the complete state from before the visit.

const DayCycle := preload("res://scripts/garden/farm_day_cycle.gd")
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")


static func settle() -> Dictionary:
	# Growth can move produce from the basket into the barn. Keep it in memory
	# until the rest of the arrival transaction has finished too.
	SaveManager.settle_farm(false)
	var farm: Dictionary = SaveManager.data.get("farm", {})
	var dew: Dictionary = DayCycle.check_morning_dew(farm)
	farm["dailies"] = Dailies.roll(farm, GameClock.now_date())
	SaveManager.data["farm"] = farm

	# A visit happens on arrival, never while the child is away. Its gifts and
	# friendship changes share the same save as growth and the daily rollover.
	var visit: Dictionary = NpcFarm.maybe_visit(GameClock.now_unix())
	farm["last_farm_visit_at"] = GameClock.now_unix()
	SaveManager.data["farm"] = farm
	SaveManager.save_game()
	return {"dew": dew, "visit": visit}
