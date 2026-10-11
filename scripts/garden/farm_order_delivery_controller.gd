extends RefCounted
## Settle the inventory and reward side of one order delivery.
##
## The screen still owns the lesson, XP, daily progress, animation, and sound.
## This boundary owns the part a double press must never repeat: pay the whole
## basket once, grant the matching reward, and record its once-only key in
## memory. The screen commits this together with XP, daily progress, and the
## lesson state in one save before presentation can yield.

const Barn := preload("res://scripts/garden/inventory_manager.gd")


static func settle(order: Dictionary, orders: Dictionary) -> Dictionary:
	var order_id := str(order.get("id", ""))
	var delivered: Array = orders.get("delivered", [])
	var recurring := bool(order.get("recurring", false))
	var counts: Dictionary = {}
	var delivery_number := 0
	var recurring_key := ""
	var recurring_paid: Array = []

	# Ask before emptying the barn. Story orders use their delivered list as the
	# once gate; recurring orders remain available and use a numbered ledger.
	if not recurring and order_id in delivered:
		return {"settled": false, "reason": "already_delivered"}
	if recurring:
		var counts_value: Variant = orders.get("counts", {})
		counts = counts_value if counts_value is Dictionary else {}
		var paid_value: Variant = orders.get("recurring_paid", [])
		recurring_paid = paid_value if paid_value is Array else []
		delivery_number = maxi(0, int(counts.get(order_id, 0))) + 1
		recurring_key = "%s:%d" % [
			str(order.get("completion_transaction_key", order_id)),
			delivery_number,
		]
		# A restored or merged counter can be behind its receipt ledger. Refuse
		# before removing goods; the caller can keep the basket and repair the
		# counter instead of losing a delivery with no reward.
		if recurring_key in recurring_paid:
			return {"settled": false, "reason": "already_paid",
				"once_key": recurring_key}
	var wants: Dictionary = order.get("requirements", {})
	if not Barn.pay(wants):
		return {"settled": false, "reason": "missing_items"}

	var paid := 0
	if recurring:
		counts[order_id] = delivery_number
		orders["counts"] = counts
		paid = RewardManager.grant("garden:order:%s" % order_id,
			int(order.get("rewards", {}).get("coins", 0)), recurring_key,
			recurring_paid, false)
		orders["recurring_paid"] = recurring_paid
	else:
		paid = RewardManager.grant("garden:order:%s" % order_id,
			int(order.get("rewards", {}).get("coins", 0)), order_id,
			delivered, false)

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
