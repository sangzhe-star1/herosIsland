extends RefCounted
## The gift shop's rules, with no screen attached.
##
##     const Shop := preload("res://scripts/shop/shop_manager.gd")
##
## Not a `class_name`, for the same reason as everything else shared here: the
## global class cache is only rebuilt by the editor, and a name it does not
## know is a parse error that greys the whole game.
##
## Everything a shop screen needs to ask is answerable here, without a screen:
## what is for sale, whether he can see it yet, what it costs, whether he owns
## it, what he is wearing, and what a bundle costs given what he already has.
## That is deliberate -- it means the rules can be tested by a headless probe
## before a single button exists, which is the order this project has learned
## to work in.
##
## Two things this file will never grow: a random reward, and a price that
## changes with time. tools_check fails the build if either concept appears in
## the data.

const Coins := preload("res://scripts/shop/currency_manager.gd")

## Where a child's shop life is kept. Note what is NOT in shop_items.json:
## `owned` and `equipped`. The catalogue is read-only game data; what he owns
## belongs to him. Mixing the two means editing a price can lose his hat.
const SAVE_KEY := "shop"

## One item per slot, and the slots a garment can occupy. `head` and `body`
## exist in HeroArt already (as "hat" and "suit"); `hands` and `feet` are new
## and are drawn as no-ops until the art lands, so buying them is safe now.
const WEAR_SLOTS := ["head", "body", "back", "hands", "feet"]
## The single-choice categories: one companion, one ride, one trail, one pose.
const PICK_SLOTS := ["pal", "ride", "fx", "action"]


# --- the catalogue ------------------------------------------------------

static func categories() -> Array:
	var list: Array = GameData.shop_categories.duplicate()
	list.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return list


static func items() -> Array:
	return GameData.shop_items


static func item(item_id: String) -> Dictionary:
	for entry in GameData.shop_items:
		if str(entry.get("id", "")) == item_id:
			return entry
	return {}


static func bundle(bundle_id: String) -> Dictionary:
	for entry in GameData.shop_bundles:
		if str(entry.get("id", "")) == bundle_id:
			return entry
	return {}


static func in_category(category: String) -> Array:
	var out: Array = []
	for entry in GameData.shop_items:
		if str(entry.get("category", "")) == category:
			out.append(entry)
	return out


# --- what he can see yet ------------------------------------------------

## Is this on the shelf?
##
## A locked item is still SHOWN -- as a real silhouette with its condition in
## pictures, never a question mark. The brief is right about this: a shelf that
## fills up as the island opens is the reason to keep playing, and a row of
## question marks is just a wall.
static func unlocked(entry: Dictionary) -> bool:
	var cond: Dictionary = entry.get("unlock_condition", {})
	match str(cond.get("type", "always")):
		"always", "free_gift":
			return true
		"levels_done":
			return _levels_done() >= int(cond.get("count", 0))
		"world_done":
			return _world_done(str(cond.get("world", "")))
		"world_stars":
			return _world_stars(str(cond.get("world", ""))) >= int(cond.get("count", 0))
		"three_stars":
			return _three_star_levels() >= int(cond.get("count", 0))
		"badges":
			return SaveManager.data["rewards"].get("badges", []).size() \
				>= int(cond.get("count", 0))
		"boss_beaten":
			return _any_boss_beaten()
	return true


static func _levels_done() -> int:
	var n := 0
	for lid in SaveManager.data["levels"]:
		if bool(SaveManager.data["levels"][lid].get("completed", false)):
			n += 1
	return n


static func _three_star_levels() -> int:
	var n := 0
	for lid in SaveManager.data["levels"]:
		if int(SaveManager.data["levels"][lid].get("stars", 0)) >= 3:
			n += 1
	return n


static func _world_done(world_id: String) -> bool:
	if world_id == "":
		return false
	for level in GameData.get_levels_for_world(world_id):
		var lid := str(level.get("id", ""))
		if lid == "hero_studio":
			continue
		if not bool(SaveManager.get_level_progress(lid).get("completed", false)):
			return false
	return true


static func _world_stars(world_id: String) -> int:
	var n := 0
	for level in GameData.get_levels_for_world(world_id):
		n += int(SaveManager.get_level_progress(str(level.get("id", ""))).get("stars", 0))
	return n


static func _any_boss_beaten() -> bool:
	for level in GameData.levels:
		if str(level.get("game_type", "")) != "monster_duel":
			continue
		if bool(SaveManager.get_level_progress(str(level.get("id", ""))).get("completed", false)):
			return true
	return false


# --- owning -------------------------------------------------------------

static func _shop() -> Dictionary:
	if not SaveManager.data.has(SAVE_KEY):
		SaveManager.data[SAVE_KEY] = SaveManager.default_shop()
	return SaveManager.data[SAVE_KEY]


static func owns(item_id: String) -> bool:
	return item_id in _shop().get("owned", [])


static func owned_count() -> int:
	return _shop().get("owned", []).size()


## Buy it. Returns "" on success, or a reason a screen can turn into a gentle
## line: "owned", "locked", "poor", "unknown".
##
## Nothing here shouts. Refusing a purchase is a normal thing that happens to a
## six-year-old with 12 星星币 and, per the brief, must never be a red error.
static func buy(item_id: String) -> String:
	var entry := item(item_id)
	if entry.is_empty():
		return "unknown"
	if owns(item_id):
		return "owned"
	if not unlocked(entry):
		return "locked"
	var price := int(entry.get("price", 0))
	if not Coins.can_afford(price):
		return "poor"
	if not Coins.spend(price):
		return "poor"
	_grant(item_id)
	return ""


## Put it in his box without charging. The free first gift, and nothing else.
static func grant_free(item_id: String) -> bool:
	if item(item_id).is_empty() or owns(item_id):
		return false
	_grant(item_id)
	return true


static func _grant(item_id: String) -> void:
	var shop := _shop()
	var owned: Array = shop.get("owned", [])
	if item_id not in owned:
		owned.append(item_id)
	shop["owned"] = owned
	# Buying it takes it off the wishlist -- he got it, so it is no longer a
	# thing he is waiting for.
	var wish: Array = shop.get("wishlist", [])
	wish.erase(item_id)
	shop["wishlist"] = wish
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()
	SaveManager.progress_changed.emit()


## Undo a purchase, whole. The brief asks for a short-lived 放回去 button after
## a mis-tap; a partial refund would teach a worse lesson than none.
static func undo(item_id: String) -> bool:
	var entry := item(item_id)
	if entry.is_empty() or not owns(item_id):
		return false
	var shop := _shop()
	var owned: Array = shop.get("owned", [])
	owned.erase(item_id)
	shop["owned"] = owned
	# Taking it off first: leaving him wearing something he no longer owns is
	# the kind of state that turns into a blank hat three screens later.
	for slot in shop.get("equipped", {}):
		if str(shop["equipped"][slot]) == item_id:
			shop["equipped"][slot] = ""
	SaveManager.data[SAVE_KEY] = shop
	Coins.refund(int(entry.get("price", 0)))
	SaveManager.save_game()
	SaveManager.progress_changed.emit()
	return true


# --- wearing ------------------------------------------------------------

static func equipped_in(slot: String) -> String:
	return str(_shop().get("equipped", {}).get(slot, ""))


static func is_equipped(item_id: String) -> bool:
	for slot in _shop().get("equipped", {}):
		if str(_shop()["equipped"][slot]) == item_id:
			return true
	return false


## Wear it, or take it off by passing "". One thing per slot: the crown goes
## back on its hook when the party hat goes on.
static func equip(item_id: String) -> bool:
	if item_id == "":
		return false
	var entry := item(item_id)
	if entry.is_empty() or not owns(item_id):
		return false
	var slot := _slot_of(entry)
	if slot == "":
		return false
	var shop := _shop()
	var worn: Dictionary = shop.get("equipped", {})
	worn[slot] = item_id
	shop["equipped"] = worn
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()
	SaveManager.progress_changed.emit()
	return true


static func unequip(slot: String) -> void:
	var shop := _shop()
	var worn: Dictionary = shop.get("equipped", {})
	worn[slot] = ""
	shop["equipped"] = worn
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()
	SaveManager.progress_changed.emit()


## Garments answer with their body slot; companions, rides, trails and poses
## answer with their category, because each of those is also a one-at-a-time
## choice.
static func _slot_of(entry: Dictionary) -> String:
	var slot := str(entry.get("slot", ""))
	if slot != "":
		return slot
	var category := str(entry.get("category", ""))
	return category if category in PICK_SLOTS else ""


## Can THIS character wear it? Textured skins -- Bluey, and any photo skin --
## are deliberately never dressed by SkinnedCharacter, so a hat bought while
## playing as him would simply not appear. Saying so is kinder than silently
## doing nothing.
static func fits(entry: Dictionary, character_id: String) -> bool:
	var who: Array = entry.get("character_compatibility", [])
	if who.is_empty():
		return true          # not a garment: pals, rides, decorations
	return character_id in who


# --- bundles ------------------------------------------------------------

## What a bundle costs him TODAY.
##
## The brief is firm and right: already owning a piece must come off the price.
## A child who bought the cloud hat last week and then finds it inside a box he
## is being asked to pay full price for has been cheated, and he will not have
## the words for it -- he will just stop trusting the shop.
static func bundle_price(bundle_id: String) -> int:
	var box := bundle(bundle_id)
	if box.is_empty():
		return 0
	var price := int(box.get("price", 0))
	var full := 0
	var already := 0
	for member_id in box.get("contains", []):
		var member := item(str(member_id))
		var member_price := int(member.get("price", 0))
		full += member_price
		if owns(str(member_id)):
			already += member_price
	if already <= 0:
		return price
	if full <= 0:
		return price
	# Take off the same SHARE of the bundle price that the owned pieces are of
	# the full price, so the discount he was offered survives.
	var left := int(round(float(price) * float(full - already) / float(full)))
	return maxi(left, 0)


static func bundle_owned(bundle_id: String) -> bool:
	var box := bundle(bundle_id)
	if box.is_empty():
		return false
	for member_id in box.get("contains", []):
		if not owns(str(member_id)):
			return false
	return true


static func buy_bundle(bundle_id: String) -> String:
	var box := bundle(bundle_id)
	if box.is_empty():
		return "unknown"
	if bundle_owned(bundle_id):
		return "owned"
	if not unlocked(box):
		return "locked"
	var price := bundle_price(bundle_id)
	if not Coins.spend(price):
		return "poor"
	for member_id in box.get("contains", []):
		if not owns(str(member_id)):
			_grant(str(member_id))
	var shop := _shop()
	var done: Array = shop.get("bundles_done", [])
	if bundle_id not in done:
		done.append(bundle_id)
	shop["bundles_done"] = done
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()
	return ""


# --- the first visit ----------------------------------------------------

## The teaching gift. Given once, free, so his first act in the shop is to try
## something on rather than to find out he cannot afford anything.
static func free_gift_id() -> String:
	for entry in GameData.shop_items:
		if str(entry.get("unlock_condition", {}).get("type", "")) == "free_gift":
			return str(entry.get("id", ""))
	return ""


static func free_gift_pending() -> bool:
	return not bool(_shop().get("free_gift_taken", false)) and free_gift_id() != ""


static func take_free_gift() -> String:
	if not free_gift_pending():
		return ""
	var gift := free_gift_id()
	grant_free(gift)
	var shop := _shop()
	shop["free_gift_taken"] = true
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()
	return gift
