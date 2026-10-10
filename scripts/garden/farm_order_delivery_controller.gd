extends RefCounted
## Settle the inventory and reward side of one order delivery.
##
## The screen still owns the lesson, XP, daily progress, animation, and sound.
## This boundary owns the part a double press must never repeat: pay the whole
## basket once, grant the matching reward, and persist its once-only key.

const Barn := preload("res://scripts/garden/inventory_manager.gd")


static func settle(order: Dictionary, orders: Dictionary) -> Dictionary:
	var order_id := str(order.get("id", ""))
	var delivered: Array = orders.get("delivered", [])
	var recurring := bool(order.get("recurring", false))

	# Ask before emptying the barn. Story orders use their delivered list as the
	# once gate; recurring orders remain available and use a numbered ledger.
	if not recurring and order_id in delivered:
		return {"settled": false, "reason": "already_delivered"}
	var wants: Dictionary = order.get("requirements", {})
	if not Barn.pay(wants):
		return {"settled": false, "reason": "missing_items"}

	var paid := 0
	if recurring:
		var counts: Dictionary = orders.get("counts", {})
		var delivery_number := int(counts.get(order_id, 0)) + 1
		counts[order_id] = delivery_number
		orders["counts"] = counts
		var once_key := "%s:%d" % [
			str(order.get("completion_transaction_key", order_id)),
			delivery_number,
		]
		var ledger: Array = orders.get("recurring_paid", [])
		paid = RewardManager.grant("garden:order:%s" % order_id,
			int(order.get("rewards", {}).get("coins", 0)), once_key, ledger)
		orders["recurring_paid"] = ledger
	else:
		paid = RewardManager.grant("garden:order:%s" % order_id,
			int(order.get("rewards", {}).get("coins", 0)), order_id, delivered)

	if paid > 0:
		var gifts: Dictionary = order.get("rewards", {}).get("items", {})
		for item_id in gifts.keys():
			Barn.put(str(item_id), int(gifts[item_id]), "inventory")
	orders["delivered"] = delivered
	return {
		"settled": true,
		"order_id": order_id,
		"paid": paid,
		"recurring": recurring,
	}
