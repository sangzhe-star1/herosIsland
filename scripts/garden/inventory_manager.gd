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

const WAREHOUSE := "warehouse"


static func _store(which: String) -> Dictionary:
	if which == WAREHOUSE:
		var farm: Dictionary = SaveManager.data.get("farm", {})
		if not farm.has("warehouse"):
			farm["warehouse"] = {}
		return farm["warehouse"]
	if not SaveManager.data.has("inventory"):
		SaveManager.data["inventory"] = {}
	return SaveManager.data["inventory"]


static func count(item_id: String, which: String = WAREHOUSE) -> int:
	return int(_store(which).get(item_id, 0))


static func has(item_id: String, amount: int, which: String = WAREHOUSE) -> bool:
	return amount >= 0 and count(item_id, which) >= amount


## What is in the barn, as a list of [id, count] sorted by the crop order in
## the catalogue -- so the barn always reads in the same order it was learned
## in, rather than in whatever order things happened to be picked.
static func contents(which: String = WAREHOUSE) -> Array:
	var store := _store(which)
	var out: Array = []
	for crop in GameData.crops:
		var crop_id := str(crop.get("id", ""))
		if int(store.get(crop_id, 0)) > 0:
			out.append([crop_id, int(store[crop_id])])
	# Anything not in the catalogue still shows, at the end. A barn that
	# silently hides something it is holding is worse than an odd sort order.
	for key in store.keys():
		if int(store[key]) > 0 and GameData.get_crop(str(key)).is_empty():
			out.append([str(key), int(store[key])])
	return out


static func total(which: String = WAREHOUSE) -> int:
	var sum := 0
	for pair in contents(which):
		sum += int(pair[1])
	return sum


static func put(item_id: String, amount: int, which: String = WAREHOUSE) -> int:
	if item_id == "" or amount <= 0:
		return 0
	var store := _store(which)
	store[item_id] = int(store.get(item_id, 0)) + amount
	return amount


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
	return true
