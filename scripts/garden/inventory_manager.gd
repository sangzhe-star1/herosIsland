extends RefCounted
## The barn, and everything else the garden keeps a count of.
##
##     const Barn := preload("res://scripts/garden/inventory_manager.gd")
##
## Two stores, on purpose:
##
##   farm.warehouse   what came out of the ground. Carrots, corn, strawberries.
##   inventory        everything else the garden holds -- seeds, tools, parts.
##
## They are separate because an order asks for three carrots and should not be
## able to be paid in seeds, and because the barn is the thing the child SEES
## fill up. Neither is rewards.items: that one is battle potions, read directly
## by three minigames, and joining them would mean a bug in the garden could
## empty his healing potions.
##
##
## WHY EVERY CHANGE GOES THROUGH HERE
##
## take() is the only way anything leaves, and it returns false and changes
## NOTHING when there is not enough. A caller that forgets to check cannot
## overdraw -- which is the same shape as Coins.spend(), and for the same
## reason: the alternative is a barn that can go negative, and a negative
## carrot is not something a six-year-old can be told about.

const Farm := preload("res://scripts/garden/farm_save.gd")

const WAREHOUSE := "warehouse"
## The basket by the barn door: whatever did not fit. Uncapped, never spent
## from, and emptied back into the barn the moment there is room.
const BASKET := "harvest_basket"

## What "no ceiling" is written as. Seeds and tools are deliberately uncapped:
## a child who cannot buy a seed because his pouch is full has hit a wall he
## cannot see and cannot clear, and there is nothing on the screen to tell him
## which of the things he owns to throw away.
const NO_CAP := -1


## Which dictionary this name refers to, reaching into the save rather than
## copying it.
##
## `data["farm"]` and not `data.get("farm", {})`: get() with a default hands back
## a fresh literal when the key is missing, and every change written into it is
## then thrown away at the end of the statement. The key always exists today, so
## this was invisible -- which is exactly the kind of bug that survives.
static func _store(which: String) -> Dictionary:
	if which == WAREHOUSE or which == BASKET:
		if not SaveManager.data.has("farm"):
			SaveManager.data["farm"] = Farm.default_farm()
		var farm: Dictionary = SaveManager.data["farm"]
		if not farm.has(which):
			farm[which] = {}
		return farm[which]
	if not SaveManager.data.has("inventory"):
		SaveManager.data["inventory"] = {}
	return SaveManager.data["inventory"]


## How many things this store holds before it stops accepting.
static func cap(which: String = WAREHOUSE) -> int:
	if which != WAREHOUSE:
		return NO_CAP
	if not SaveManager.data.has("farm"):
		return Farm.WAREHOUSE_START
	return maxi(0, int(SaveManager.data["farm"].get(
		"warehouse_cap", Farm.WAREHOUSE_START)))


## Room for how many more. Always the whole number of things that will fit,
## never negative -- a barn edited to hold less than it already contains says
## zero, not minus six.
static func room_left(which: String = WAREHOUSE) -> int:
	var ceiling := cap(which)
	if ceiling == NO_CAP:
		return 1 << 30
	return maxi(0, ceiling - total(which))


static func is_full(which: String = WAREHOUSE) -> bool:
	return room_left(which) <= 0


static func count(item_id: String, which: String = WAREHOUSE) -> int:
	return int(_store(which).get(item_id, 0))


static func has(item_id: String, amount: int, which: String = WAREHOUSE) -> bool:
	return amount >= 0 and count(item_id, which) >= amount


## What is in the barn, as [id, count]: crops first, then made produce, each
## in catalogue order. Both kinds occupy space and can wait in the overflow
## basket. Unknown saved items remain visible after the known catalogue.
static func contents(which: String = WAREHOUSE) -> Array:
	var store := _store(which)
	var out: Array = []
	var seen: Dictionary = {}
	for catalogue in [GameData.crops, GameData.farm_produce.get("produce", [])]:
		for item in catalogue:
			var item_id := str(item.get("id", ""))
			if seen.has(item_id):
				continue
			seen[item_id] = true
			if int(store.get(item_id, 0)) > 0:
				out.append([item_id, int(store[item_id])])
	# Anything not in the catalogue still shows, at the end. A barn that
	# silently hides something it is holding is worse than an odd sort order.
	for key in store.keys():
		var item_id := str(key)
		if int(store[key]) > 0 and not seen.has(item_id):
			out.append([item_id, int(store[key])])
			seen[item_id] = true
	return out


static func total(which: String = WAREHOUSE) -> int:
	var sum := 0
	for pair in contents(which):
		sum += int(pair[1])
	return sum


## Put things away, and say how many actually went in.
##
## The RETURN VALUE is the whole of the capacity rule, and the signature did not
## have to change to get it: put() has always answered "how many went in", it
## simply always answered `amount`. Every caller that ignored the number was
## already ignoring the truth; now the truth can differ, and the one caller that
## matters -- the harvest -- compares it and puts the remainder in the basket.
static func put(item_id: String, amount: int, which: String = WAREHOUSE) -> int:
	if item_id == "" or amount <= 0:
		return 0
	var room := room_left(which)
	var going_in := mini(amount, room)
	if going_in <= 0:
		return 0
	var store := _store(which)
	store[item_id] = int(store.get(item_id, 0)) + going_in
	return going_in


## Pick a crop and put it away: as much as the barn holds, the rest into the
## basket by the door. Returns {"stored": n, "spilled": n}.
##
## NOTHING IS EVER DROPPED. stored + spilled == amount, always, and there is no
## branch here that can make that untrue -- the basket has no ceiling to hit.
## That is the whole reason this function exists rather than each caller
## remembering to check put()'s answer.
static func store_harvest(item_id: String, amount: int) -> Dictionary:
	if item_id == "" or amount <= 0:
		return {"stored": 0, "spilled": 0}
	var stored := put(item_id, amount, WAREHOUSE)
	var spilled := put(item_id, amount - stored, BASKET)
	return {"stored": stored, "spilled": spilled}


## Tip the basket back into the barn, as far as it goes. Returns how many moved.
##
## Called from wherever the barn gets emptier -- pay() below and
## SaveManager.settle_farm() -- rather than from a button, because "there is
## room now" is a fact about the barn and not an errand for the child. A basket
## that needs to be noticed and tapped is a basket he will not notice.
static func tip_basket_in() -> int:
	var moved := 0
	for pair in contents(BASKET):
		var item_id := str(pair[0])
		var waiting := int(pair[1])
		var went_in := put(item_id, waiting, WAREHOUSE)
		if went_in > 0:
			take(item_id, went_in, BASKET)
			moved += went_in
		if room_left(WAREHOUSE) <= 0:
			break
	return moved


## Take from the store, or take nothing at all. Never partial, never negative.
static func take(item_id: String, amount: int, which: String = WAREHOUSE) -> bool:
	if amount <= 0 or not has(item_id, amount, which):
		return false
	var store := _store(which)
	var left := int(store.get(item_id, 0)) - amount
	if left <= 0:
		store.erase(item_id)          # an empty shelf shows nothing, not a zero
	else:
		store[item_id] = left
	return true


## Can this whole basket be paid at once? Asked before taking anything, so an
## order that is one carrot short takes nothing rather than emptying the barn
## of everything it CAN cover.
static func can_pay(basket: Dictionary, which: String = WAREHOUSE) -> bool:
	for item_id in basket.keys():
		if not has(str(item_id), int(basket[item_id]), which):
			return false
	return true


## All of it, or none of it.
static func pay(basket: Dictionary, which: String = WAREHOUSE) -> bool:
	if not can_pay(basket, which):
		return false
	for item_id in basket.keys():
		take(str(item_id), int(basket[item_id]), which)
	# Room just appeared. Emptying the barn is the ONLY way that happens, so
	# this is the one place the basket has to be tipped back in -- putting it at
	# each caller instead is how the fifth caller forgets.
	if which == WAREHOUSE:
		tip_basket_in()
	return true
