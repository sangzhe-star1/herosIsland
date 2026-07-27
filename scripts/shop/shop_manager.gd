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
	# A drop-in face has no row in the data file; see _cast_rows().
	if item_id.begins_with(WHO_CATEGORY + "_"):
		for entry in _cast_rows():
			if str(entry.get("id", "")) == item_id:
				return entry
	return {}


static func bundle(bundle_id: String) -> Dictionary:
	for entry in GameData.shop_bundles:
		if str(entry.get("id", "")) == bundle_id:
			return entry
	return {}


static func in_category(category: String) -> Array:
	if category == WHO_CATEGORY:
		return _cast_rows()
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
		if bool(level.get("room", false)):
			continue          # a room is never "finished"
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
	# Taking it off first -- off EVERY hero, not just the one on screen.
	# Leaving him wearing something he no longer owns is the kind of state that
	# turns into a blank hat three screens later.
	var everyones: Dictionary = shop.get("worn", {})
	for character_id in everyones:
		var mine: Dictionary = everyones[character_id]
		for slot in mine:
			if str(mine[slot]) == item_id:
				mine[slot] = ""
	shop["worn"] = everyones
	SaveManager.data[SAVE_KEY] = shop
	Coins.refund(int(entry.get("price", 0)))
	SaveManager.save_game()
	SaveManager.progress_changed.emit()
	return true


# --- wearing ------------------------------------------------------------
#
# Everything here is per CHARACTER. It used to be one global `equipped`, which
# meant dressing 迪迦 also dressed 赛罗 -- six heroes reading as one hero in
# six colours. Owning is still shared, because the clothes belong to the child.

static func who() -> String:
	return str(SaveManager.get_profile().get("character_id", "tiga"))


static func worn(character_id: String = "") -> Dictionary:
	return SaveManager.worn_by(character_id if character_id != "" else who())


static func equipped_in(slot: String, character_id: String = "") -> String:
	return str(worn(character_id).get(slot, ""))


static func is_equipped(item_id: String, character_id: String = "") -> bool:
	if item_id == "":
		return false
	for slot in worn(character_id):
		if str(worn(character_id)[slot]) == item_id:
			return true
	return false


## Wear it, or take it off by passing "". One thing per slot: the crown goes
## back on its hook when the party hat goes on.
static func equip(item_id: String, character_id: String = "") -> bool:
	if item_id == "":
		return false
	var entry := item(item_id)
	if entry.is_empty() or not owns(item_id):
		return false
	var slot := _slot_of(entry)
	if slot == "":
		return false
	var target := character_id if character_id != "" else who()
	if not fits(entry, target):
		return false
	SaveManager.wear_item(target, slot, item_id)
	return true


static func unequip(slot: String, character_id: String = "") -> void:
	SaveManager.wear_item(character_id if character_id != "" else who(), slot, "")


## Six states, and a card is in exactly one of them. Nothing is cached: the
## answer is recomputed every time it is asked, because a stale lookup table
## is how this project has lost a rename four times this month.
enum State { LOCKED, INCOMPATIBLE, BUYABLE, OWNED, WEARING }


static func state_of(entry: Dictionary, character_id: String = "") -> State:
	var target := character_id if character_id != "" else who()
	var item_id := str(entry.get("id", ""))
	# A face is not worn in a slot -- "wearing" one means BEING him -- so the
	# cast answers before the wardrobe rules get a chance to.
	if is_who(entry):
		var cid := who_id(entry)
		if cid == target:
			return State.WEARING
		if have_character(cid):
			return State.OWNED
		if not unlocked(entry):
			return State.LOCKED
		return State.BUYABLE
	if not fits(entry, target):
		return State.INCOMPATIBLE
	if is_equipped(item_id, target):
		return State.WEARING
	if owns(item_id):
		return State.OWNED
	if not unlocked(entry):
		return State.LOCKED
	return State.BUYABLE


# --- the cast -------------------------------------------------------------
#
# Fourteen faces, ten of them free from the first minute and four bought with
# stars like anything else. They are shop items so that ONE purchase flow
# covers them -- try on, see the three numbers, decide, and 放回去 for five
# seconds afterwards. What makes them different is only what "wearing" means:
# the profile changes rather than a wardrobe slot, which is why every function
# below exists instead of reusing equip().

const WHO_CATEGORY := "who"


static func is_who(entry: Dictionary) -> bool:
	return str(entry.get("category", "")) == WHO_CATEGORY


static func who_id(entry: Dictionary) -> String:
	return str(entry.get("character_id", ""))


## Free from the start, or bought. Both count, and neither is stored twice:
## characters.json says who is free and the owned list says who was paid for.
static func have_character(character_id: String) -> bool:
	var cast: Dictionary = GameData.characters.get("characters", {})
	if not cast.has(character_id):
		return false
	if bool(cast[character_id].get("unlocked", false)):
		return true
	return owns(WHO_CATEGORY + "_" + character_id)


## Become him. Refuses a character he has not got, so a stale save or a bad
## card cannot strand the game on a face that does not exist.
static func become(character_id: String) -> bool:
	if not have_character(character_id):
		return false
	if who() == character_id:
		return true
	SaveManager.set_character(character_id)
	return true


## Everyone he could be, whether or not he can be them yet.
static func cast() -> Array:
	return _cast_rows()


## The cards for the 形象 drawer: the fourteen in the data file, plus any face
## the game picked up at boot that the data file has never heard of.
##
## That last part is not hypothetical. GameData scans assets/characters for a
## drop-in -- a scan of a drawing -- and adds it to the cast at runtime. Before
## this, such a face appeared in the row of heads under the stage but had no
## card in the drawer, which is exactly the kind of half-present thing this
## project keeps finding months later.
static func _cast_rows() -> Array:
	var rows: Array = []
	var carded: Dictionary = {}
	for entry in GameData.shop_items:
		if str(entry.get("category", "")) == WHO_CATEGORY:
			rows.append(entry)
			carded[who_id(entry)] = true
	for cid in GameData.characters.get("characters", {}):
		if carded.has(cid):
			continue
		var meta: Dictionary = GameData.characters["characters"][cid]
		rows.append({
			"id": WHO_CATEGORY + "_" + str(cid),
			"name_key": str(meta.get("name_key", "")),
			"category": WHO_CATEGORY,
			"slot": "",
			"price": 0,
			"art": "",
			"icon": "",
			"character_id": str(cid),
			"character_compatibility": [],
			"unlock_condition": {"type": "always"},
			"set_id": "",
			"world_theme": "",
			"bundle_id": "",
		})
	return rows


## The "new!" mark: owned, and he has not looked at it yet. One small star in
## the corner, gone after the first look -- never a red dot that keeps pulsing.
static func is_new(item_id: String) -> bool:
	return owns(item_id) and not (item_id in _shop().get("seen_new", []))


static func mark_seen(item_id: String) -> void:
	var shop := _shop()
	var seen: Array = shop.get("seen_new", [])
	if item_id in seen:
		return
	seen.append(item_id)
	shop["seen_new"] = seen
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()


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
