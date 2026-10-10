extends RefCounted
## Owns the garden's short regret window and reverses its three paid actions.
##
## The screen offers the window after a successful purchase. It only draws the
## toast and plays the response; timing and refunds stay here so each route
## shares one boundary and can be exercised against the real save.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const SeedShop := preload("res://scripts/garden/seed_shop_manager.gd")
const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")

const WINDOW_MS := 5000
const UPGRADE_COINS := 60
const UPGRADE_PLANKS := 3


static func offer(kind: String, id: String, now_ms: int) -> Dictionary:
	return {"kind": kind, "id": id, "until": now_ms + WINDOW_MS}


## The end tick remains inside the window, matching the toast's old deadline
## comparison. Empty entries are never presented as an open regret window.
static func is_open(pending: Dictionary, now_ms: int) -> bool:
	return not pending.is_empty() and now_ms <= int(pending.get("until", 0))


## Reverse the purchase if the window is still open. `accepted` says the press
## landed in time; `changed` says its object could still be returned. A plot
## already worked is accepted as a press but remains the child's land.
static func settle(pending: Dictionary, now_ms: int) -> Dictionary:
	if pending.is_empty():
		return {"accepted": false, "expired": true, "changed": false}
	if not is_open(pending, now_ms):
		return {"accepted": false, "expired": true, "changed": false}

	var kind := str(pending.get("kind", ""))
	var id := str(pending.get("id", ""))
	var changed := false
	match kind:
		"seed":
			changed = SeedShop.owns(id)
			SeedShop.undo(id)
		"cap":
			var farm: Dictionary = SaveManager.data.get("farm", {})
			if int(farm.get("warehouse_cap", 0)) >= Farm.WAREHOUSE_UPGRADED:
				# Goods gathered while the larger barn was open stay his. The lower
				# roof only stops future storage; it never ejects existing produce.
				farm["warehouse_cap"] = Farm.WAREHOUSE_START
				Coins.refund(UPGRADE_COINS)
				Barn.put("plank", UPGRADE_PLANKS, "inventory")
				SaveManager.save_game()
				changed = true
		"plot":
			var farm_before: Dictionary = SaveManager.data.get("farm", {})
			var count_before := int(farm_before.get("plot_count", 0))
			Expand.undo(int(id))
			var farm_after: Dictionary = SaveManager.data.get("farm", {})
			changed = int(farm_after.get("plot_count", 0)) != count_before

	return {"accepted": true, "expired": false, "changed": changed,
		"kind": kind}
