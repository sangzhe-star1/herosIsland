extends RefCounted
## Apply the durable farm progress that follows a successfully claimed harvest.
##
## The harvest receipt is the gate: a refused or duplicate claim must not pay
## XP, advance a daily task, teach a recipe, or consume the first-market hint.
## This controller mutates the live save in memory but never writes it; the
## tap/stroke transaction owns the one save after all effects have settled.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const DailyProgress := preload("res://scripts/garden/farm_daily_progress_controller.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const Recipes := preload("res://scripts/garden/recipe_manager.gd")


static func settle(receipt: Dictionary, today: String) -> Dictionary:
	if not bool(receipt.get("claimed", false)):
		return {}
	var amount := int(receipt.get("amount", 0))
	if amount <= 0:
		return {}

	var farm: Dictionary = SaveManager.data.get("farm", {})
	var levels: Array = Level.award("harvest")
	var daily: Dictionary = DailyProgress.record(farm, today, "harvest", amount)
	var learned: Array = Recipes.check_barn(false)
	var market_taught := false
	if not bool(farm.get("market_taught", false)) \
			and Barn.total() >= Barn.cap() - 6:
		farm["market_taught"] = true
		market_taught = true

	return {
		"levels": levels,
		"daily": daily,
		"learned_recipes": learned,
		"market_taught": market_taught,
	}
