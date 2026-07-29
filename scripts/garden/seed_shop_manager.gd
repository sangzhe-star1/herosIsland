extends RefCounted
## The seed shop's till: what a crop costs, whether he already owns it, and
## the one way money becomes seeds.
##
##     const SeedShop := preload("res://scripts/garden/seed_shop_manager.gd")
##
## A CROP IS BOUGHT ONCE AND KEPT FOREVER
##
## Not packets. A packet model means a child can run out of seeds AND out of
## coins on the same afternoon, and a farm where nothing can be planted is a
## game that has ended without saying so -- the exact deadlock the four free
## starter crops exist to make impossible. So the shop sells the CROP: buy the
## potato once and its tile joins the rack beside the carrot's, forever, with
## the same unlimited seeds. What keeps the economy alive is not re-buying
## potatoes, it is the ladder above them: the barn's bigger roof, and later
## the seventh bed and the orchard.
##
## THE SHAPE OF A PURCHASE, COPIED FROM THE HERO HOUSE
##
## buy() answers with a reason word, not a boolean -- "" for done, "owned",
## "poor", "unknown" -- so the screen can be gentle in the right way. "Owned"
## is itself the idempotence: a second press finds the crop already on the
## rack and pays nothing, which is why there is no ledger here. And undo()
## gives the whole price back within the regret window, exactly like the gift
## shop's, because a six-year-old's second thought deserves the same respect
## as his first.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")


static func price_of(crop_id: String) -> int:
	return maxi(0, int(GameData.seed_listing(crop_id).get("price", 0)))


static func owns(crop_id: String) -> bool:
	return crop_id in SaveManager.data.get("farm", {}).get("unlocked_crops", [])


## What the shop would say about this row: "owned" | "free" | "buyable" |
## "poor" | "unknown". Recomputed every time it is asked -- the hero house
## learned the hard way that a cached copy of this table goes stale.
static func state_of(crop_id: String) -> String:
	if GameData.get_crop(crop_id).is_empty() \
			or GameData.seed_listing(crop_id).is_empty():
		return "unknown"
	if owns(crop_id):
		return "owned"
	var price := price_of(crop_id)
	if price <= 0:
		# On the shelf, free, and somehow not owned -- a save from before this
		# crop existed. Buying it costs nothing and fixes it.
		return "free"
	return "buyable" if Coins.can_afford(price) else "poor"


## Buy the crop. "" means it is his now; anything else is the reason it is not,
## and the reason is a word so the screen never has to show a red error.
static func buy(crop_id: String) -> String:
	match state_of(crop_id):
		"unknown":
			return "unknown"
		"owned":
			return "owned"
		"poor":
			return "poor"
	# Money first, and Coins.spend refuses and changes NOTHING when it cannot
	# pay -- so a caller that forgot to check can still not overdraw.
	if not Coins.spend(price_of(crop_id)):
		return "poor"
	var farm: Dictionary = SaveManager.data["farm"]
	var unlocked: Array = farm.get("unlocked_crops", [])
	unlocked.append(crop_id)
	farm["unlocked_crops"] = unlocked
	SaveManager.save_game()
	return ""


## The regret window. Whole price back, crop off the rack. A potato already
## PLANTED in the ground stays planted and keeps growing -- taking a growing
## plant out of the earth because the receipt was returned would be the game
## reaching into the farm, and nothing is allowed to do that.
static func undo(crop_id: String) -> void:
	if not owns(crop_id):
		return
	var farm: Dictionary = SaveManager.data["farm"]
	var unlocked: Array = farm.get("unlocked_crops", [])
	unlocked.erase(crop_id)
	farm["unlocked_crops"] = unlocked
	Coins.refund(price_of(crop_id))
	SaveManager.save_game()
