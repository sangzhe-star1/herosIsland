extends Node
## The money, checked from every angle that matters to a six-year-old.
##
##   godot --headless --path . res://tests/ShopProbe.tscn
##
## Written before the shop screen exists, on purpose. Everything here is
## answerable without a single button: whether a purchase deducts the right
## amount, whether it can overdraw, whether an undo returns every coin, and --
## the one that matters most -- whether buying anything can cost him a star.
##
## That last one is the whole reason the currencies were collapsed. The brief
## opens with it: 关卡星章是永久成绩，不能被消费. A test is the only way that
## sentence stays true after the twentieth change to the shop.

const Coins := preload("res://scripts/shop/currency_manager.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")
const Wishes := preload("res://scripts/shop/wishlist_manager.gd")

var _out: Array[String] = []


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== shop probe ===")

	_a_score_is_not_a_purse()
	_spending()
	_cannot_overdraw()
	_undo_returns_everything()
	_earning_says_why()
	await _save_round_trip()
	_stars_are_retired()
	_old_saves_get_paid_back()
	_bonuses_pay_once()

	print("  --- the shop itself ---")
	_the_catalogue_is_whole()
	_unlocking()
	_buying_and_wearing()
	_undo_is_whole()
	_bundles_discount_what_he_owns()
	_the_wish_box()
	_the_free_gift()
	await _shop_survives_a_restart()
	_clothes_know_who_can_wear_them()

	for f in _out:
		print("FAIL  %s" % f)
	print("SHOP PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## THE RULE. Buying must never move 关卡星章, by any route, ever.
func _a_score_is_not_a_purse() -> void:
	# A child three worlds in: real stars on real levels.
	for lid in ["sunny_park_01", "sunny_park_02", "night_city_01"]:
		SaveManager.record_level_result(lid, 3, 1.0)
	var stars_before := SaveManager.total_stars()
	var island_before := SaveManager.island_completion()

	SaveManager.data["rewards"]["coins"] = 500
	for i in range(7):
		Coins.spend(50)

	var stars_after := SaveManager.total_stars()
	print("  stars %d -> %d after spending 350 星星币" % [stars_before, stars_after])
	_ok(stars_before == stars_after,
		"spending changed 关卡星章: %d -> %d" % [stars_before, stars_after])
	_ok(stars_before > 0, "the probe bought nothing meaningful -- no stars to protect")
	_ok(is_equal_approx(island_before, SaveManager.island_completion()),
		"spending changed how much of the island is finished")


func _spending() -> void:
	SaveManager.data["rewards"]["coins"] = 100
	_ok(Coins.balance() == 100, "balance() disagrees with the save")
	_ok(Coins.can_afford(100), "cannot afford exactly what it has")
	_ok(not Coins.can_afford(101), "claims to afford one more than it has")
	_ok(Coins.spend(30), "a purchase it could afford was refused")
	_ok(Coins.balance() == 70, "70 expected after spending 30, got %d" % Coins.balance())
	print("  100 - 30 = %d" % Coins.balance())


## Not enough money must change NOTHING. A caller that forgets to check first
## still cannot leave the child with a negative purse or a free item.
func _cannot_overdraw() -> void:
	SaveManager.data["rewards"]["coins"] = 20
	_ok(not Coins.spend(21), "overdrew: spent 21 out of 20")
	_ok(Coins.balance() == 20,
		"a refused purchase still moved the balance: %d" % Coins.balance())
	_ok(not Coins.spend(-5), "a negative price was accepted")
	_ok(Coins.balance() == 20, "a negative price moved the balance")
	_ok(Coins.short_by(35) == 15,
		"short_by() said %d, expected 15" % Coins.short_by(35))
	_ok(Coins.short_by(5) == 0, "short_by() went negative")
	print("  20 星星币: refuses 21, refuses -5, short of 35 by %d" % Coins.short_by(35))


func _undo_returns_everything() -> void:
	SaveManager.data["rewards"]["coins"] = 90
	var before := Coins.balance()
	_ok(Coins.spend(35), "could not buy the thing being undone")
	Coins.refund(35)
	_ok(Coins.balance() == before,
		"undo returned %d, not the %d he paid" % [Coins.balance() - (before - 35), 35])
	print("  bought at 35 and put it back: %d -> %d" % [before, Coins.balance()])


func _earning_says_why() -> void:
	SaveManager.data["rewards"]["coins"] = 0
	_ok(Coins.earn(12, "level:test") == 12, "earning did not report what it paid")
	_ok(Coins.earn(0, "nothing") == 0, "earning zero claimed to pay something")
	_ok(Coins.earn(-4, "bug") == 0, "a negative reward was paid")
	_ok(Coins.balance() == 12, "balance after earning is %d, expected 12" % Coins.balance())
	print("  earn 12, then 0, then -4  ->  %d" % Coins.balance())


## The purse has to survive the app closing. This writes, re-reads from disk,
## and checks the number came back.
func _save_round_trip() -> void:
	SaveManager.data["rewards"]["coins"] = 137
	SaveManager.save_game()
	await get_tree().process_frame
	SaveManager.load_game()
	print("  wrote 137, reloaded from disk -> %d" % Coins.balance())
	_ok(Coins.balance() == 137,
		"the purse did not survive a save/load: %d" % Coins.balance())


## The old star-purse must be gone, not merely unused. A call site that quietly
## went back to spending stars is the exact regression this exists to catch.
func _stars_are_retired() -> void:
	var stars := SaveManager.total_stars()
	# spend_stars() now pushes an error and refuses; the point is that it
	# CANNOT take a star even when called.
	SaveManager.spend_stars(1)
	_ok(SaveManager.total_stars() == stars,
		"the retired spend_stars() still moved 关卡星章")
	print("  retired spend_stars(1): stars still %d" % SaveManager.total_stars())


## A returning child must be no poorer for the change.
##
## His old save has `spent_stars` in it -- stars he already paid for potions.
## Those stars are coming back as 星星币, so the collapse can only ever make
## him richer. A migration that quietly costs a child something he earned is
## not a migration worth shipping.
func _old_saves_get_paid_back() -> void:
	SaveManager.data["rewards"]["coins"] = 40
	SaveManager.data["rewards"]["spent_stars"] = 17
	SaveManager.save_game()
	SaveManager.load_game()
	print("  old save with 17 spent stars: 40 星星币 -> %d" % Coins.balance())
	_ok(Coins.balance() == 57,
		"a returning child ended up with %d, not 57" % Coins.balance())
	_ok(int(SaveManager.data["rewards"].get("spent_stars", -1)) == 0,
		"spent_stars was not cleared, so the refund will repeat every launch")
	# ...and the refund has to be WRITTEN DOWN, not just applied in memory.
	#
	# Reading the balance back cannot tell you this: any later save flushes the
	# cleared flag as a side effect, and saves happen constantly. So this reads
	# the file itself. The window it protects is small -- open the app, change
	# nothing, close it -- but in that window an in-memory-only refund pays out
	# again every single launch.
	var on_disk: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var still_owed: int = 0
	if on_disk is Dictionary:
		still_owed = int((on_disk as Dictionary)["rewards"].get("spent_stars", 0))
	print("  spent_stars left in the file on disk: %d" % still_owed)
	_ok(still_owed == 0,
		"the refund was applied in memory but not written -- it will pay "
		+ "again on the next launch (%d still owed on disk)" % still_owed)


## The five new earning sources pay the first time and never again.
func _bonuses_pay_once() -> void:
	var lid := "sunny_park_05"        # an adventure level: has a hidden gem
	SaveManager.data["levels"].erase(lid)
	SaveManager.data["rewards"]["coins"] = 0

	var first := LevelResult.new(lid)
	first.objective_scoring = true
	first.reached_goal = true
	first.found_hidden = true
	first.clean_run = true
	RewardManager.grant_for_level(first)
	var paid_first := RewardManager.last_coins_earned
	print("  %s first perfect run: %d 星星币" % [lid, paid_first])

	var again := LevelResult.new(lid)
	again.objective_scoring = true
	again.reached_goal = true
	again.found_hidden = true
	again.clean_run = true
	RewardManager.grant_for_level(again)
	var paid_again := RewardManager.last_coins_earned
	print("  the very same run again:    %d 星星币" % paid_again)

	_ok(paid_first >= 18,
		"a first perfect run paid only %d -- the bonuses are not firing" % paid_first)
	_ok(paid_again == 0,
		"replaying the same level paid %d again -- it is a coin farm" % paid_again)


# --- stage 1: the catalogue, owning, wearing, bundles, wishes -------------

func _fresh_shop() -> void:
	SaveManager.data["shop"] = SaveManager.default_shop()
	SaveManager.data["rewards"]["coins"] = 0
	SaveManager.data["levels"] = {}


func _the_catalogue_is_whole() -> void:
	var items: Array = Shop.items()
	var cats: Array = Shop.categories()
	print("  catalogue: %d items in %d categories" % [items.size(), cats.size()])
	_ok(cats.size() == 7, "expected 7 categories, found %d" % cats.size())
	_ok(items.size() >= 21, "expected at least 21 items, found %d" % items.size())

	# Every category has something in it. An empty tab is a dead end a child
	# taps once and never again.
	for cat in cats:
		var cid := str(cat.get("id", ""))
		_ok(Shop.in_category(cid).size() > 0, "category '%s' is empty" % cid)

	# Ids are unique, prices are real, and nothing is free by accident.
	var seen := {}
	for entry in items:
		var iid := str(entry.get("id", ""))
		_ok(not seen.has(iid), "duplicate item id '%s'" % iid)
		seen[iid] = true
		_ok(int(entry.get("price", 0)) > 0, "'%s' costs nothing" % iid)


## Locked things stay locked, and open on exactly the condition they name.
func _unlocking() -> void:
	_fresh_shop()
	var cloud := Shop.item("cap_cloud")          # world_done: sunny_park
	_ok(not Shop.unlocked(cloud), "cap_cloud is open before the park is done")
	for level in GameData.get_levels_for_world("sunny_park"):
		var lid := str(level.get("id", ""))
		if lid != "hero_studio":
			SaveManager.record_level_result(lid, 2, 1.0)
	_ok(Shop.unlocked(cloud), "cap_cloud stayed shut after the park was finished")
	print("  cap_cloud: shut before 阳光公园, open after")

	_fresh_shop()
	var boots := Shop.item("boots_bolt")         # three_stars: 3
	_ok(not Shop.unlocked(boots), "boots_bolt is open with no three-star runs")
	for lid in ["sunny_park_01", "sunny_park_02", "sunny_park_03"]:
		SaveManager.record_level_result(lid, 3, 1.0)
	_ok(Shop.unlocked(boots), "boots_bolt stayed shut after three perfect levels")
	print("  boots_bolt: shut at 0 three-stars, open at 3")


func _buying_and_wearing() -> void:
	_fresh_shop()
	SaveManager.data["rewards"]["coins"] = 100

	_ok(Shop.buy("act_wave") == "", "could not buy the cheapest thing in the shop")
	_ok(Shop.owns("act_wave"), "bought it and does not own it")
	_ok(Coins.balance() == 92, "8 should have left 92, balance is %d" % Coins.balance())
	_ok(Shop.buy("act_wave") == "owned", "bought the same thing twice")
	_ok(Coins.balance() == 92, "the second purchase still took money")

	# Locked and unaffordable both refuse, and both leave the purse alone.
	_ok(Shop.buy("ride_cloud") == "locked", "bought a locked item")
	SaveManager.data["rewards"]["coins"] = 5
	_ok(Shop.buy("fx_starstep") in ["poor", "locked"], "bought with 5 星星币")
	_ok(Coins.balance() == 5, "a refused purchase moved the purse")
	print("  buy / own / no-double-buy / locked / too-poor all behave")

	# Wearing: one per slot.
	SaveManager.data["rewards"]["coins"] = 200
	Shop.grant_free("cap_cloud")
	Shop.grant_free("crown_brave")
	_ok(Shop.equip("cap_cloud"), "could not wear a hat he owns")
	_ok(Shop.equipped_in("head") == "cap_cloud", "the hat did not go on his head")
	_ok(Shop.equip("crown_brave"), "could not swap hats")
	_ok(Shop.equipped_in("head") == "crown_brave", "the second hat did not replace the first")
	_ok(not Shop.is_equipped("cap_cloud"), "he is somehow wearing two hats")
	Shop.unequip("head")
	_ok(Shop.equipped_in("head") == "", "taking the hat off did not work")
	print("  one hat per head, swapping replaces, taking off works")

	# Wearing something he does not own must be impossible.
	_ok(not Shop.equip("vest_rescue"), "wore something he never bought")


## Undo returns the money AND takes the thing back off.
func _undo_is_whole() -> void:
	_fresh_shop()
	SaveManager.data["rewards"]["coins"] = 100
	Shop.buy("act_wave")
	Shop.equip("act_wave")
	_ok(Shop.undo("act_wave"), "could not put it back")
	_ok(not Shop.owns("act_wave"), "put it back and still owns it")
	_ok(Coins.balance() == 100, "undo left him with %d, not 100" % Coins.balance())
	_ok(Shop.equipped_in("action") == "",
		"he is still using something he put back")
	print("  put back: money returned, item gone, no longer equipped")


## A bundle must never charge twice for a piece he already has.
func _bundles_discount_what_he_owns() -> void:
	_fresh_shop()
	# The box opens when 阳光公园 is finished, so finish it -- otherwise this
	# tests nothing but the lock, which _unlocking() already covers.
	for level in GameData.get_levels_for_world("sunny_park"):
		var lid := str(level.get("id", ""))
		if lid != "hero_studio":
			SaveManager.record_level_result(lid, 2, 1.0)
	_ok(Shop.unlocked(Shop.bundle("bundle_park")),
		"the park box is still shut after finishing the park")
	var full := Shop.bundle_price("bundle_park")
	print("  公园野餐礼盒 full price: %d" % full)
	_ok(full == 68, "bundle should cost 68, says %d" % full)

	Shop.grant_free("deco_sofa")          # the 45-coin piece, already his
	var after := Shop.bundle_price("bundle_park")
	print("  after already owning 云朵沙发 (45 of 95): %d" % after)
	_ok(after < full, "owning a piece did not reduce the box at all")
	_ok(after == 36, "expected 36 after the discount, got %d" % after)

	SaveManager.data["rewards"]["coins"] = 100
	_ok(Shop.buy_bundle("bundle_park") == "", "could not buy the box")
	_ok(Coins.balance() == 100 - after,
		"the box charged %d, not the discounted %d" % [100 - Coins.balance(), after])
	for member in ["cap_cloud", "act_spin", "deco_sofa", "set_park_stickers"]:
		_ok(Shop.owns(member), "the box did not deliver %s" % member)
	print("  box delivered all four, charged the discounted price")


func _the_wish_box() -> void:
	_fresh_shop()
	for iid in ["cape_star", "cap_cloud", "vest_rescue", "boots_bolt",
			"gloves_rainbow"]:
		_ok(Wishes.add(iid), "could not wish for %s" % iid)
	_ok(Wishes.full(), "five wishes and the box is not full")
	_ok(not Wishes.add("crown_brave"), "a sixth wish went in")
	_ok(Wishes.all().size() == Wishes.MAX,
		"the box holds %d, not %d" % [Wishes.all().size(), Wishes.MAX])
	print("  wish box holds %d and refuses the sixth" % Wishes.MAX)

	# The one it points at is the one he is closest to affording.
	SaveManager.data["rewards"]["coins"] = 20
	var near := Wishes.closest()
	print("  closest wish at 20 星星币: %s, short by %d"
		% [str(near.get("id", "-")), Wishes.gap_to(near)])
	_ok(str(near.get("id", "")) == "cap_cloud",
		"pointed at %s, but 云朵帽 (18) is nearest" % str(near.get("id", "-")))

	# Buying it takes it off the list.
	SaveManager.data["rewards"]["coins"] = 100
	for level in GameData.get_levels_for_world("sunny_park"):
		var lid := str(level.get("id", ""))
		if lid != "hero_studio":
			SaveManager.record_level_result(lid, 2, 1.0)
	Shop.buy("cap_cloud")
	_ok(not Wishes.has("cap_cloud"), "he bought it and it is still on the list")
	print("  bought a wish: it left the box on its own")


## The first visit gives something, once.
func _the_free_gift() -> void:
	_fresh_shop()
	_ok(Shop.free_gift_pending(), "a brand new child is offered nothing")
	var gift := Shop.take_free_gift()
	print("  first visit gift: %s (free)" % gift)
	_ok(gift != "", "the free gift is not configured")
	_ok(Shop.owns(gift), "gave the gift and he does not have it")
	_ok(Coins.balance() == 0, "the FREE gift charged him %d" % (0 - Coins.balance()))
	_ok(not Shop.free_gift_pending(), "still offering a gift he already took")
	_ok(Shop.take_free_gift() == "", "handed out a second free gift")


## Everything he bought has to be there tomorrow.
func _shop_survives_a_restart() -> void:
	_fresh_shop()
	SaveManager.data["rewards"]["coins"] = 200
	Shop.buy("act_wave")
	Shop.equip("act_wave")
	Wishes.add("crown_brave")
	SaveManager.save_game()
	SaveManager.load_game()
	print("  after a restart: owns %d, wearing '%s', %d wishes, %d 星星币"
		% [Shop.owned_count(), Shop.equipped_in("action"),
			Wishes.all().size(), Coins.balance()])
	_ok(Shop.owns("act_wave"), "what he bought did not survive the restart")
	_ok(Shop.equipped_in("action") == "act_wave",
		"what he was wearing did not survive the restart")
	_ok(Wishes.has("crown_brave"), "his wish list did not survive the restart")


## Bluey cannot be dressed -- SkinnedCharacter never dresses a textured skin.
## Selling him a hat that will not appear is worse than not offering it.
func _clothes_know_who_can_wear_them() -> void:
	var hat := Shop.item("cap_cloud")
	_ok(Shop.fits(hat, "tiga"), "迪迦 cannot wear a hat")
	_ok(not Shop.fits(hat, "bluey"),
		"a hat claims to fit bluey, who is never dressed by the renderer")
	# Non-garments fit everybody.
	_ok(Shop.fits(Shop.item("pal_orb"), "bluey"), "a companion refused bluey")
	print("  garments fit the drawn heroes and not bluey; pals fit everyone")
