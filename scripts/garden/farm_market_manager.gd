extends RefCounted
## The market box: crops go in, 星星币 come out, and no press of any button can
## make that happen one and a half times.
##
##     const Market := preload("res://scripts/garden/farm_market_manager.gd")
##
## WHY SELLING PAYS LESS THAN AN ORDER
##
## The market takes ANYTHING, NOW -- that convenience is what the lower price
## buys. An order pays clearly more for exactly the right basket, so "should I
## sell these or save them for the bear" is a real question a six-year-old can
## work out for himself, with numbers small enough to compare. tools_check
## does the comparing too: an order whose reward is not comfortably above the
## market value of what it asks for is refused before it ships.
##
## THE RECEIPT
##
## `farm_sale_<n>`, where n is a counter on the farm that only ever rises --
## the same shape as plant_cycle_id, solving the same problem: every sale in
## the history of a save gets an id nobody has seen before, so an id seen
## twice is always a repeat. The counter moves FIRST, the goods move second,
## the money moves last, and everything before the money is asked "all or
## nothing": a basket the barn cannot cover pays zero and takes zero.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")


## What this pile of crops is worth, before anything moves. The screen shows
## this number next to the box; sell() computes it again from the same table,
## so the number he saw and the number he gets cannot drift.
static func quote(basket: Dictionary) -> int:
	var total := 0
	for crop_id in basket.keys():
		var item_id := str(crop_id)
		var amount := int(basket[crop_id])
		var unit_price := GameData.market_price(item_id)
		# A mixed basket must not throw away an unpriced saved item while its
		# priced neighbours are sold. Reject the whole quote so the receipt can
		# be edited before any goods leave the barn.
		if amount <= 0 or unit_price <= 0:
			return 0
		total += unit_price * amount
	return total


## Sell the basket. Returns the coins paid: the quote for a sale that
## happened, 0 for one that could not -- an empty basket, crops the barn does
## not actually hold, or a pile of things the market has no price for.
static func sell(basket: Dictionary) -> int:
	var worth := quote(basket)
	# A stale market receipt may outlive a crop sold or delivered on another
	# device. Refuse it BEFORE creating a once-only sale key so the child can
	# keep editing the basket and retry when the stock is present.
	if worth <= 0 or not Barn.can_pay(basket):
		return 0
	var farm: Dictionary = SaveManager.data["farm"]

	# The receipt is written before anything moves, so even a sale interrupted
	# between the barn and the purse can never be presented again. Pass a copy:
	# RewardManager.record() appends to its argument, and giving it the save's
	# array directly makes remember_paid_sale() see a pre-appended id and skip
	# trimming the ledger to its 64-entry bound.
	var receipt := int(farm.get("sale_receipt_id", 0)) + 1
	var key := "farm_sale_%d" % receipt
	var saved_paid: Variant = farm.get("paid_sales", [])
	var paid: Array = saved_paid if saved_paid is Array else []
	var duplicate_check := paid.duplicate()
	if not RewardManager.record("garden:market", key, duplicate_check):
		return 0
	farm["sale_receipt_id"] = receipt
	Farm.remember_paid_sale(farm, key)

	# All of it or none of it. A basket one carrot short takes nothing --
	# Barn.pay() is the same call the orders trust, refusing the same way.
	if not Barn.pay(basket):
		return 0
	Coins.earn(worth, "farm:market")
	SaveManager.save_game()
	return worth
