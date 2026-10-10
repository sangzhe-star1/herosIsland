extends RefCounted
## Settle the barn roof purchase as one inventory and currency transaction.
##
## The screen owns the confirm card and feedback. This controller owns the
## once-only cap check, all-or-nothing plank and coin costs, overflow recovery,
## persistence, and the regret receipt for a successful upgrade.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Undo := preload("res://scripts/garden/farm_undo_controller.gd")


static func settle(farm: Dictionary, now_ms: int) -> Dictionary:
	if maxi(0, int(farm.get("warehouse_cap", Farm.WAREHOUSE_START))) \
			>= Farm.WAREHOUSE_UPGRADED:
		return {"upgraded": false, "reason": "already_upgraded"}
	if not Barn.has("plank", Undo.UPGRADE_PLANKS, "inventory"):
		return {"upgraded": false, "reason": "missing_planks"}
	if not Coins.spend(Undo.UPGRADE_COINS):
		return {"upgraded": false, "reason": "missing_coins"}
	if not Barn.take("plank", Undo.UPGRADE_PLANKS, "inventory"):
		# Keep the transaction all-or-nothing if the stock changed unexpectedly.
		Coins.refund(Undo.UPGRADE_COINS)
		return {"upgraded": false, "reason": "missing_planks"}

	farm["warehouse_cap"] = Farm.WAREHOUSE_UPGRADED
	var tipped := Barn.tip_basket_in()
	SaveManager.save_game()
	return {
		"upgraded": true,
		"tipped": tipped,
		"undo": Undo.offer("cap", "", now_ms),
	}
