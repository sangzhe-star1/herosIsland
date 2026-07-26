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
