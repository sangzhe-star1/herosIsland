extends RefCounted
## The wish box: things he likes and cannot buy yet.
##
##     const Wishes := preload("res://scripts/shop/wishlist_manager.gd")
##
## This is the shop's answer to "还差一点点星星". A six-year-old who wants the
## rainbow cape and has 22 星星币 needs somewhere for that wanting to go, or the
## only thing the moment teaches him is that he does not have enough.
##
## Deliberately small and deliberately quiet:
##
##   * five things, maximum. A wish list of twenty is a chore, not a wish.
##   * it never nags. The result screen may mention ONE wish, and only
##     occasionally -- see should_mention(). A game that reminds a child what he
##     cannot afford every time he finishes a level has learned the wrong trade.
##   * it connects to nothing that costs money. There is no money here to
##     connect to.

const Coins := preload("res://scripts/shop/currency_manager.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")

const MAX := 5
## Levels between wish reminders. Three is about the same cadence as the rest
## suggestion, and for the same reason: often enough to be a goal, rare enough
## not to be a voice on his shoulder.
const REMIND_EVERY := 3


static func _shop() -> Dictionary:
	if not SaveManager.data.has(Shop.SAVE_KEY):
		SaveManager.data[Shop.SAVE_KEY] = SaveManager.default_shop()
	return SaveManager.data[Shop.SAVE_KEY]


static func all() -> Array:
	return _shop().get("wishlist", [])


static func has(item_id: String) -> bool:
	return item_id in all()


static func full() -> bool:
	return all().size() >= MAX


## Returns false when it is full or already there -- both of which a screen
## should answer with a shrug, not an error.
static func add(item_id: String) -> bool:
	if item_id == "" or has(item_id) or full():
		return false
	if Shop.item(item_id).is_empty() or Shop.owns(item_id):
		return false
	var shop := _shop()
	var list: Array = shop.get("wishlist", [])
	list.append(item_id)
	shop["wishlist"] = list
	SaveManager.data[Shop.SAVE_KEY] = shop
	SaveManager.save_game()
	SaveManager.progress_changed.emit()
	return true


static func remove(item_id: String) -> void:
	var shop := _shop()
	var list: Array = shop.get("wishlist", [])
	list.erase(item_id)
	shop["wishlist"] = list
	SaveManager.data[Shop.SAVE_KEY] = shop
	SaveManager.save_game()
	SaveManager.progress_changed.emit()


## The one he is closest to affording. That is the one worth mentioning: it is
## the one where "one more level" is actually true.
static func closest() -> Dictionary:
	var best: Dictionary = {}
	var best_gap := 1 << 30
	for item_id in all():
		var entry := Shop.item(str(item_id))
		if entry.is_empty():
			continue
		var gap := Coins.short_by(int(entry.get("price", 0)))
		if gap < best_gap:
			best_gap = gap
			best = entry
	return best


static func gap_to(entry: Dictionary) -> int:
	return Coins.short_by(int(entry.get("price", 0)))


## Should the result screen say anything about the wish box right now?
##
## Only every third level, only if he actually wants something, and never once
## he can already afford it -- at that point the shop itself is the message.
static func should_mention() -> bool:
	if all().is_empty():
		return false
	var wish := closest()
	if wish.is_empty() or gap_to(wish) <= 0:
		return false
	var seen: int = int(SaveManager.get_setting("wish_mentions", 0)) + 1
	SaveManager.set_setting("wish_mentions", seen)
	return seen % REMIND_EVERY == 0
