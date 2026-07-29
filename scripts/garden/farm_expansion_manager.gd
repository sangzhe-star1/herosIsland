extends RefCounted
## The land beyond the fence: two beds under stones, each bought exactly once.
##
##     const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")
##
## WHY BEDS ARE BOUGHT IN ORDER
##
## `plot_count` IS the ownership record: bed 6 exists exactly when plot_count
## is at least 7. One rising number cannot hold a hole -- there is no way to
## own the eighth bed and not the seventh -- so "in order" is not a rule that
## needs enforcing anywhere else, it is the shape of the record. It is also
## the idempotence: buying a bed you own answers "owned" because index <
## plot_count, and no press, replay, or double-dispatch can make the count
## rise past the one slot the press was about.
##
## THE REASON-WORD SHAPE, SAME AS THE SEED SHOP'S
##
## "" for done; "owned" / "level" / "poor" / "unknown" for why not. The screen
## turns each into the right gentleness -- a level word becomes a star badge,
## never a red lock.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")


static func slot(index: int) -> Dictionary:
	return GameData.farm_expansion_slot(index)


static func cost_of(index: int) -> int:
	return maxi(0, int(slot(index).get("coins", 0)))


static func level_needed(index: int) -> int:
	return maxi(1, int(slot(index).get("level", 1)))


## What the farm would say about bed `index` right now:
## "owned" | "ready" | "level" | "poor" | "unknown".
static func state_of(index: int) -> String:
	if slot(index).is_empty():
		return "unknown"
	var count := int(SaveManager.data.get("farm", {})
		.get("plot_count", Farm.PLOT_COUNT))
	if index < count:
		return "owned"
	if index > count:
		# Not this one's turn yet: the bed before it is still under stones.
		# Told apart from "unknown" nowhere on screen -- the slot after the
		# next simply shows its level badge like any other locked thing.
		return "level"
	if Level.level() < level_needed(index):
		return "level"
	return "ready" if Coins.can_afford(cost_of(index)) else "poor"


## Buy bed `index`. "" means the stones are his to watch slide away; anything
## else is the reason nothing happened, and nothing DID happen -- money and
## land move together or not at all.
static func buy(index: int) -> String:
	var state := state_of(index)
	if state != "ready":
		return state if state != "" else "unknown"
	if not Coins.spend(cost_of(index)):
		return "poor"
	var farm: Dictionary = SaveManager.data["farm"]
	farm["plot_count"] = index + 1
	var plots: Array = farm.get("plots", [])
	while plots.size() < index + 1:
		plots.append(Farm.fresh_plot(plots.size()))
	farm["plots"] = plots
	SaveManager.save_game()
	return ""


## The regret window. Whole price back, stones back on the bed -- but ONLY
## while the bed is still untouched grass and still the newest one: earth he
## has already turned or planted is HIS earth, and the game does not reach
## into the farm and take a bed with something in it. After the window the
## question never comes up again.
static func undo(index: int) -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	if int(farm.get("plot_count", 0)) != index + 1:
		return
	var plots: Array = farm.get("plots", [])
	if plots.size() != index + 1:
		return
	if str((plots[index] as Dictionary).get("state", "")) != Farm.EMPTY:
		return
	plots.pop_back()
	farm["plots"] = plots
	farm["plot_count"] = index
	Coins.refund(cost_of(index))
	SaveManager.save_game()
