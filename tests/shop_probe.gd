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
const Presets := preload("res://scripts/shop/preset_manager.gd")
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

	print("  --- one tap is never a purchase ---")
	await _one_tap_buys_nothing()

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


## The OTHER rule, checked through the real screen: one tap on a shop card
## must never move money. The 道具小店 shipped for weeks spending a coin on
## button_down -- everything else about it worked, so nothing complained --
## and the sticker book had the same shape. Both go through the confirm sheet
## now, and this walks the whole contract: tap opens the sheet and spends
## nothing; the sheet's own button spends exactly the price; 放回去 returns
## every coin and takes the goods back.
func _one_tap_buys_nothing() -> void:
	SaveManager.data["rewards"]["coins"] = 100
	SaveManager.data["rewards"]["items"] = {}
	var shop_screen: Control = load("res://scenes/shop/ItemShop.tscn").instantiate()
	add_child(shop_screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var cards: Dictionary = shop_screen.get("_cards")
	var buying: Node = shop_screen.get("_buying")
	_ok(not cards.is_empty(), "the item shop built no cards")
	_ok(buying != null, "the item shop has no confirm sheet at all")
	if cards.is_empty() or buying == null:
		shop_screen.queue_free()
		return
	var first_id := str(cards.keys()[0])
	var price := int(cards[first_id]["price"])
	var hit: Button = cards[first_id]["hit"]

	hit.pressed.emit()
	await get_tree().process_frame
	_ok(Coins.balance() == 100,
		"tapping a shop card moved money: 100 -> %d before any confirm"
		% Coins.balance())
	_ok(SaveManager.item_count(first_id) == 0,
		"tapping a shop card already handed the item over")
	_ok(bool(buying.call("is_open")), "the tap did not open the confirm sheet")

	var yes: Button = buying.get("sheet_yes")
	_ok(yes != null, "the confirm sheet has no yes button to press")
	if yes != null:
		yes.pressed.emit()
		await get_tree().process_frame
		_ok(Coins.balance() == 100 - price,
			"confirming spent %d, not the price %d"
			% [100 - Coins.balance(), price])
		_ok(SaveManager.item_count(first_id) == 1,
			"paid, but the item never arrived")

	var undo: Button = buying.get("sheet_undo")
	_ok(undo != null, "no 放回去 after the purchase")
	if undo != null:
		undo.pressed.emit()
		await get_tree().process_frame
		_ok(Coins.balance() == 100,
			"放回去 returned %d of %d coins" % [Coins.balance() - (100 - price), price])
		_ok(SaveManager.item_count(first_id) == 0,
			"the coins came back but he kept the potion too")

	print("  tap: no spend; confirm: -%d; 放回去: whole again at %d"
		% [price, Coins.balance()])
	shop_screen.queue_free()
	await get_tree().process_frame


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
	# WHICH HERO, explicitly.
	#
	# Wearing is per character now, and equip() refuses a hero who cannot wear
	# the thing. This probe passed on its own and failed inside the suite,
	# because an earlier probe had left "bluey" -- who wears nothing -- in the
	# save file on disk. A test that depends on state it did not set is a test
	# that will lie to you eventually.
	SaveManager.data["profile"]["character_id"] = "tiga"


func _the_catalogue_is_whole() -> void:
	var items: Array = Shop.items()
	var cats: Array = Shop.categories()
	print("  catalogue: %d items in %d categories" % [items.size(), cats.size()])
	_ok(cats.size() >= 7, "expected at least 7 categories, found %d" % cats.size())
	_ok(items.size() >= 80, "expected at least 80 items, found %d" % items.size())

	# Every category has something in it. An empty tab is a dead end a child
	# taps once and never again. `set` is the exception on purpose: the twelve
	# themed outfits are built from outfit_presets.json rather than being items
	# of their own, so its drawer is filled by preset_manager.
	for cat in cats:
		var cid := str(cat.get("id", ""))
		if cid == "set":
			continue
		_ok(Shop.in_category(cid).size() > 0, "category '%s' is empty" % cid)

	# Ids are unique, prices are real, and nothing is free by accident.
	var seen := {}
	for entry in items:
		var iid := str(entry.get("id", ""))
		_ok(not seen.has(iid), "duplicate item id '%s'" % iid)
		seen[iid] = true
		# A face is the one thing that may be priced 0: ten of the fourteen are
		# free from the first minute and are in the item list only so that one
		# drawer and one purchase flow cover the whole cast. A free face must
		# be marked free in characters.json, though -- a 0-star card that is
		# not unlocked would be a thing nobody could ever get.
		if Shop.is_who(entry):
			var cid := Shop.who_id(entry)
			var meta: Dictionary = GameData.characters.get("characters", {})\
				.get(cid, {})
			_ok(not meta.is_empty(), "'%s' is a card for nobody" % iid)
			if int(entry.get("price", 0)) == 0:
				_ok(bool(meta.get("unlocked", false)),
					"'%s' costs nothing and is not free either" % iid)
			else:
				_ok(not bool(meta.get("unlocked", false)),
					"'%s' is free from the start but still has a price" % iid)
		else:
			_ok(int(entry.get("price", 0)) > 0, "'%s' costs nothing" % iid)


## Locked things stay locked, and open on exactly the condition they name.
func _unlocking() -> void:
	_fresh_shop()
	var helmet := Shop.item("helmet_rescue")     # world_done: night_city
	_ok(not Shop.unlocked(helmet), "helmet_rescue is open before the city is done")
	for level in GameData.get_levels_for_world("night_city"):
		var lid := str(level.get("id", ""))
		if lid != "hero_studio":
			SaveManager.record_level_result(lid, 2, 1.0)
	_ok(Shop.unlocked(helmet), "helmet_rescue stayed shut after 夜光城市 was done")
	print("  helmet_rescue: shut before 夜光城市, open after")

	_fresh_shop()
	var hood := Shop.item("hood_dino_red")       # three_stars: 4
	_ok(not Shop.unlocked(hood), "hood_dino_red is open with no three-star runs")
	for lid in ["sunny_park_01", "sunny_park_02", "sunny_park_03", "sunny_park_04"]:
		SaveManager.record_level_result(lid, 3, 1.0)
	_ok(Shop.unlocked(hood), "hood_dino_red stayed shut after four perfect levels")
	print("  hood_dino_red: shut at 0 three-stars, open at 4")


func _buying_and_wearing() -> void:
	_fresh_shop()
	SaveManager.data["rewards"]["coins"] = 100

	var cheap := Shop.item("mittens_cloud")      # always unlocked, 15
	var price := int(cheap.get("price", 0))
	_ok(Shop.buy("mittens_cloud") == "", "could not buy the cheapest thing in the shop")
	_ok(Shop.owns("mittens_cloud"), "bought it and does not own it")
	_ok(Coins.balance() == 100 - price,
		"%d should have left %d, balance is %d" % [price, 100 - price, Coins.balance()])
	_ok(Shop.buy("mittens_cloud") == "owned", "bought the same thing twice")
	_ok(Coins.balance() == 100 - price, "the second purchase still took money")

	# Locked and unaffordable both refuse, and both leave the purse alone.
	_ok(Shop.buy("tiara_rainbow") == "locked", "bought a locked item")
	SaveManager.data["rewards"]["coins"] = 5
	_ok(Shop.buy("crown_party") in ["poor", "locked"], "bought with 5 星星币")
	_ok(Coins.balance() == 5, "a refused purchase moved the purse")
	print("  buy / own / no-double-buy / locked / too-poor all behave")

	# Wearing: one per slot.
	SaveManager.data["rewards"]["coins"] = 200
	Shop.grant_free("cap_cloud")
	Shop.grant_free("cap_sun")
	_ok(Shop.equip("cap_cloud"), "could not wear a hat he owns")
	_ok(Shop.equipped_in("head") == "cap_cloud", "the hat did not go on his head")
	_ok(Shop.equip("cap_sun"), "could not swap hats")
	_ok(Shop.equipped_in("head") == "cap_sun", "the second hat did not replace the first")
	_ok(not Shop.is_equipped("cap_cloud"), "he is somehow wearing two hats")
	Shop.unequip("head")
	_ok(Shop.equipped_in("head") == "", "taking the hat off did not work")
	print("  one hat per head, swapping replaces, taking off works")

	# Wearing something he does not own must be impossible.
	_ok(not Shop.equip("vest_park"), "wore something he never bought")


## Undo returns the money AND takes the thing back off.
func _undo_is_whole() -> void:
	_fresh_shop()
	SaveManager.data["rewards"]["coins"] = 100
	Shop.buy("mittens_cloud")
	Shop.equip("mittens_cloud")
	_ok(Shop.undo("mittens_cloud"), "could not put it back")
	_ok(not Shop.owns("mittens_cloud"), "put it back and still owns it")
	_ok(Coins.balance() == 100, "undo left him with %d, not 100" % Coins.balance())
	_ok(Shop.equipped_in("hands") == "",
		"he is still using something he put back")
	print("  put back: money returned, item gone, no longer equipped")


## Buying a whole themed outfit must never cost more than the pieces do.
##
## The old catalogue had one gift box with a price of its own and a pro-rata
## discount for pieces already owned. The wardrobe replaced it with twelve
## themed outfits assembled from ordinary items -- so there is no box price to
## get wrong, and the thing worth checking is that the twelve are real: every
## piece exists, covers a different slot, and can actually be collected.
func _bundles_discount_what_he_owns() -> void:
	_fresh_shop()
	var sets: Array = Presets.sets()
	print("  %d themed outfits" % sets.size())
	_ok(sets.size() >= 6, "only %d themed outfits" % sets.size())
	for spec in sets:
		var set_id := str(spec.get("id", ""))
		var slots := {}
		var total := 0
		for piece in spec.get("pieces", []):
			var entry: Dictionary = Shop.item(str(piece))
			_ok(not entry.is_empty(),
				"outfit '%s' wants '%s', which is not in the catalogue"
					% [set_id, piece])
			if entry.is_empty():
				continue
			var slot := str(entry.get("slot", ""))
			_ok(not slots.has(slot),
				"outfit '%s' puts two things in the '%s' slot" % [set_id, slot])
			slots[slot] = true
			total += int(entry.get("price", 0))
		_ok(slots.has("head") and slots.has("body") and slots.has("back")
			and slots.has("feet"),
			"outfit '%s' is not a whole outfit: %s" % [set_id, slots.keys()])
		_ok(total > 0, "outfit '%s' is free" % set_id)


func _the_wish_box() -> void:
	_fresh_shop()
	for iid in ["cape_star", "cap_cloud", "vest_park", "boots_bolt",
			"gloves_leaf"]:
		_ok(Wishes.add(iid), "could not wish for %s" % iid)
	_ok(Wishes.full(), "five wishes and the box is not full")
	_ok(not Wishes.add("crown_brave"), "a sixth wish went in")
	_ok(Wishes.all().size() == Wishes.MAX,
		"the box holds %d, not %d" % [Wishes.all().size(), Wishes.MAX])
	print("  wish box holds %d and refuses the sixth" % Wishes.MAX)

	# The one it points at is the one he is closest to affording. Worked out
	# from the catalogue rather than written down: hard-coding the answer meant
	# that changing one price turned this into a test of last month's shop.
	SaveManager.data["rewards"]["coins"] = 20
	var want := ""
	var best := 1 << 30
	for iid in Wishes.all():
		var gap: int = Wishes.gap_to(Shop.item(str(iid)))
		if gap < best:
			best = gap
			want = str(iid)
	var near := Wishes.closest()
	print("  closest wish at 20 星星币: %s (short by %d); cheapest gap is %s (%d)"
		% [str(near.get("id", "-")), Wishes.gap_to(near), want, best])
	_ok(str(near.get("id", "")) == want,
		"pointed at %s, but %s is nearest" % [str(near.get("id", "-")), want])

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
	Shop.buy("mittens_cloud")
	Shop.equip("mittens_cloud")
	Wishes.add("crown_brave")
	SaveManager.save_game()
	SaveManager.load_game()
	print("  after a restart: owns %d, wearing '%s', %d wishes, %d 星星币"
		% [Shop.owned_count(), Shop.equipped_in("hands"),
			Wishes.all().size(), Coins.balance()])
	_ok(Shop.owns("mittens_cloud"), "what he bought did not survive the restart")
	_ok(Shop.equipped_in("hands") == "mittens_cloud",
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
	_ok(Shop.fits(Shop.item("pal_light_orb"), "bluey"), "a companion refused bluey")
	print("  garments fit the drawn heroes and not bluey; pals fit everyone")
