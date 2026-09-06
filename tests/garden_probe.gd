extends Node
## 星光菜园, stage one: the save. No growing yet, no screen yet -- just the
## question every other stage rests on, which is whether a garden can appear in
## a save that already has months of a child's history in it without disturbing
## any of it.
##
## The three checks here are the ones written down as stage one's acceptance:
##
##   1. an old save gains a garden and loses nothing
##   2. a new save arrives with four patches of earth and seeds to put in them
##   3. running the migration twice does not double anything
##
## The rest of the garden's acceptance list arrives with the stages that
## implement it -- growth in stage two, the screen in stage three.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const HarvestCrops := preload("res://scripts/harvest/harvest_crops.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const GardenScreen := preload("res://scripts/garden/garden_screen.gd")

## The fewest questions this probe is allowed to have asked by the time it
## prints its verdict.
##
## WHY A COUNT, WHEN THERE IS ALREADY A LIST OF FAILURES
##
## An empty failure list means "nothing I asked came back wrong". That is NOT
## the same as "I asked". Half of this file reads "find a plot in this state,
## then question it" -- change a layout, retire a crop, and the find comes back
## empty, the questions are never asked, and the probe prints PASSED having
## tested nothing. It is the exact accident this project keeps having;
## harvest_touch_probe.gd already carries this guard and the two garden probes
## did not.
##
## A floor, set a little under what the probe actually asks, so that adding a
## check never means editing this number. It only moves when a section is added.
const CHECKS_EXPECTED := 554

var _failures: Array[String] = []
## How many questions actually got asked. See CHECKS_EXPECTED.
var _asked := 0


func _ok(condition: bool, description: String) -> void:
	_asked += 1
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== garden probe ===")
	await get_tree().process_frame
	var real_save: Dictionary = SaveManager.data.duplicate(true)

	_a_new_child_finds_four_empty_plots()
	_an_old_save_grows_a_garden()
	_opening_the_garden_twice_changes_nothing()
	_a_damaged_garden_is_repaired_not_believed()
	_a_plot_says_what_it_is_doing_in_one_word()
	_a_save_from_before_the_state_machine_still_knows_what_it_was_doing()
	_a_planting_cycle_never_repeats()
	_an_old_save_keeps_the_beds_it_already_had()
	# --- stage two: growing ---
	_a_carrot_goes_through_five_stages()
	_it_grows_while_he_is_playing_a_level()
	_a_clock_dragged_backwards_does_not_break_it()
	_a_clock_dragged_forwards_ripens_once()
	_a_crop_never_dies()
	_a_ripe_plot_is_frozen()
	_the_four_plots_do_not_share_a_clock()
	_a_late_seed_never_inherits_farm_elapsed_time()
	_care_restarts_growth_from_the_action()
	_settling_twice_at_the_same_moment_never_compounds()
	_recurring_orders_hold_up_the_endgame()
	_the_days_little_jobs_hold_water()
	# --- stage four: the barn, the orders, and the money ---
	_the_barn_never_goes_negative()
	_a_full_barn_never_loses_anything()
	_the_overflow_basket_has_a_stable_shelf_anchor()
	_an_order_is_all_or_nothing()
	_an_order_pays_once()
	_the_garden_cannot_touch_his_score()
	_weeds_come_once_and_never_hurt_anything()
	_the_caterpillar_is_weeds_wearing_a_different_face()
	# --- stage 3 (阶段 3 of the farm): the shop, the market, the roof ---
	_the_shop_sells_a_crop_exactly_once()
	_the_shop_grows_with_the_farm()
	_the_market_pays_once_and_only_for_what_is_there()
	# --- 阶段 4: the bear, the shared strawberry, and the visitor board ---
	_the_bears_farm_is_arithmetic_and_kindness()
	_the_bear_drops_by_but_never_in_front_of_him()
	_the_quiet_strawberry_is_answered_with_grace()
	_the_regular_gets_his_milestones_once()
	_the_kitchen_cooks_knowledge_and_feeds_a_friend()
	_two_tablets_agree_about_the_bear()
	# --- 阶段 5: the ladder and the land ---
	_the_farm_grows_up_by_arithmetic()
	_the_seventh_bed_is_bought_once()
	# --- 阶段 6: the crop's own move ---
	_the_moves_a_crop_asks_for_are_moves_the_finger_can_make()

	# Put the save back the way it was found, and say so out loud: a probe that
	# leaves the disk holding its own fixtures is how the shop probe once failed
	# in a suite it passed alone.
	SaveManager.data = real_save
	SaveManager.save_game()

	# Did it actually ask anything? A silent skip is the one failure a list of
	# failures cannot report.
	if _asked < CHECKS_EXPECTED:
		_failures.append(
			"this probe only asked %d questions and expected at least %d -- "
			% [_asked, CHECKS_EXPECTED]
			+ "something it looks for is no longer there, so a whole section "
			+ "was skipped in silence")

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("asked %d questions" % _asked)
	print("GARDEN PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _a_new_child_finds_four_empty_plots() -> void:
	# Through the REAL first-launch path, not by calling the settlement by hand.
	# Calling it by hand is what the first version of this check did, and it
	# would have passed happily while the fresh-save branch skipped settling
	# altogether -- which is the actual bug being guarded here.
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	var farm: Dictionary = SaveManager.data.get("farm", {})
	var plots: Array = farm.get("plots", [])

	# Farm.PLOT_COUNT and not a literal: this number went from four to six the
	# day the garden became a farm, and a probe that carries its own copy of it
	# is a probe that has to be edited every time -- which is a probe that gets
	# edited to agree rather than to check.
	_ok(plots.size() == Farm.PLOT_COUNT,
		"a new save has %d patches of earth" % Farm.PLOT_COUNT)
	_ok(int(farm.get("plot_count", 0)) == Farm.PLOT_COUNT,
		"...and says so in plot_count")
	_ok(int(farm.get("warehouse_cap", 0)) == Farm.WAREHOUSE_START,
		"...and a barn that holds %d things" % Farm.WAREHOUSE_START)
	_ok((farm.get("harvest_basket", null) as Dictionary).is_empty(),
		"...and an empty basket by its door")

	var ids: Dictionary = {}
	for plot in plots:
		ids[str(plot.get("plot_id", ""))] = true
		_ok(str(plot.get("crop_id", "")) == "", "every new plot is empty")
		_ok(str(plot.get("state", "")) == Farm.EMPTY, "every new plot is untouched grass")
		_ok(int(plot.get("planted_at", -1)) == 0, "nothing has been planted yet")
		_ok(not Farm.is_ready(plot),
			"nothing is ready on the first morning")
	_ok(ids.size() == Farm.PLOT_COUNT,
		"the %d plots have %d different ids, not one repeated"
		% [Farm.PLOT_COUNT, Farm.PLOT_COUNT])

	# Seeds on the first launch, not the second. The settlements used to be
	# skipped entirely for a brand-new save, which would have opened the garden
	# with an empty seed rack until the child closed the game and came back.
	#
	# STARTERS, not the whole catalogue: the shop's crops arrive by being
	# bought, and a first launch that handed them out would quietly empty the
	# shop's shelf for every new child.
	_ok(farm.get("unlocked_crops", []).size() == _starter_count(),
		"a new child can plant every STARTER crop on the first launch")
	for crop in GameData.crops:
		var crop_id := str(crop.get("id", ""))
		var starter := str(crop.get("unlock_condition", "")) == ""
		_ok((crop_id in farm.get("unlocked_crops", [])) == starter,
			"'%s' is %s from the first morning" % [crop_id,
				"free" if starter else "the shop's to sell"])
	_ok(int(SaveManager.data.get("save_version", 0))
			== SaveManager.FARM_SAVE_VERSION,
		"a save made today is already at today's version")


## The one that matters: a save with real history in it, made before the garden
## existed. Nothing it already holds may move.
func _an_old_save_grows_a_garden() -> void:
	var old := SaveManager._default_data()
	# Months of a real child's game.
	old["profile"]["xp"] = 359
	old["profile"]["character_id"] = "zero"
	old["rewards"]["coins"] = 214
	old["rewards"]["badges"] = ["park_explorer", "night_walker"]
	old["rewards"]["album"] = ["stone_cub", "twin_horn", "drill_armor"]
	old["shop"]["owned"] = ["hat_crown", "cape_star", "boots_sky"]
	old["shop"]["worn"] = {"zero": {"head": "hat_crown", "back": "cape_star"}}
	old["levels"]["sunny_park_01"] = {"stars": 3, "best_accuracy": 1.0,
		"attempts": 4, "completed": true, "found_hidden": true}
	old["levels"]["sunny_park_02"] = {"stars": 2, "best_accuracy": 0.7,
		"attempts": 2, "completed": true, "found_hidden": false}
	# ...and no garden at all, because there was none when it was written.
	old.erase("farm")
	old.erase("inventory")
	old.erase("farm_orders")
	old.erase("save_version")

	var stars_before: int = 5
	# Through a real JSON round trip, so the ints come back as floats exactly
	# the way they do off a tablet.
	SaveManager.data = SaveManager._migrate(JSON.parse_string(JSON.stringify(old)))
	SaveManager._settle_after_load()

	# Nothing he had has moved.
	_ok(SaveManager.total_stars() == stars_before, "an old save keeps its stars")
	_ok(int(SaveManager.data["profile"]["xp"]) == 359, "...and its experience")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 214, "...and its 星星币")
	_ok(bool(SaveManager.get_level_progress("sunny_park_01").get("found_hidden", false)),
		"...and its hidden gem")
	_ok(SaveManager.data["rewards"]["badges"].size() == 2, "...and its badges")
	_ok(SaveManager.data["rewards"]["album"].size() == 3, "...and its 怪兽图鉴")
	_ok(SaveManager.data["shop"]["owned"].size() == 3, "...and every bought outfit")
	_ok(str(SaveManager.data["shop"]["worn"].get("zero", {}).get("head", ""))
			== "hat_crown", "...and what that hero was wearing")
	_ok(str(SaveManager.data["profile"]["character_id"]) == "zero",
		"...and which hero he was playing")

	# And a garden has appeared.
	var farm: Dictionary = SaveManager.data.get("farm", {})
	_ok(farm.get("plots", []).size() == Farm.PLOT_COUNT,
		"an old save gains %d patches of earth" % Farm.PLOT_COUNT)
	_ok(bool(farm.get("opened", false)), "the garden is marked open")
	_ok(farm.get("unlocked_crops", []).size() == _starter_count(),
		"and the starter seeds arrive with it -- the starters, not the shop's")
	_ok(SaveManager.data.has("inventory"), "the inventory key is there")
	_ok(SaveManager.data.get("farm_orders", {}).has("delivered"),
		"and so is the delivered-orders list that stops an order paying twice")
	_ok(int(SaveManager.data.get("save_version", 0))
			== SaveManager.FARM_SAVE_VERSION,
		"the save has been carried to the version with a garden in it")


## Four beds become six, and the four that were already there do not move.
##
## THE ONE THING THIS WHOLE STAGE IS FOR
##
## Raising Farm.PLOT_COUNT grows the plot list on the way past. The question
## that matters is not whether two new beds appear -- it is whether the four on
## disk survive the trip with everything that was growing in them: which crop,
## how far along, how thirsty, and above all which planting cycle, because a
## cycle that resets lets the next harvest reuse a transaction id that has
## already been paid and pay the child nothing at all for it.
##
## So this compares them FIELD BY FIELD against what went in, rather than
## counting them. A count would have passed even if every bed came back as
## fresh grass.
func _an_old_save_keeps_the_beds_it_already_had() -> void:
	var old := SaveManager._default_data()
	# A garden the way it looked before this stage: four beds, in four different
	# states, with real numbers in them.
	var four: Array = []
	for i in range(4):
		four.append(Farm.fresh_plot(i))
	four[0]["state"] = Farm.GROWING
	four[0]["crop_id"] = "carrot"
	four[0]["plant_cycle_id"] = 9
	four[0]["planted_at"] = 1_700_000_000
	four[0]["last_updated_at"] = 1_700_000_000
	four[0]["growth_stage"] = 2
	four[0]["growth_progress"] = 0.4
	four[0]["water_level"] = 0.75
	four[1]["state"] = Farm.NEEDS_CARE
	four[1]["crop_id"] = "corn"
	four[1]["plant_cycle_id"] = 3
	four[1]["planted_at"] = 1_700_000_000
	four[1]["last_updated_at"] = 1_700_000_000
	four[1]["growth_stage"] = 2
	four[1]["care_event"] = Growth.CARE_WEEDS
	four[2]["state"] = Farm.READY
	four[2]["crop_id"] = "strawberry"
	four[2]["plant_cycle_id"] = 41
	four[2]["planted_at"] = 1_700_000_000
	four[2]["last_updated_at"] = 1_700_000_000
	four[2]["growth_stage"] = 4
	four[3]["state"] = Farm.TILLED
	old["farm"]["plots"] = four
	old["farm"]["plot_count"] = 4
	old["farm"]["opened"] = true
	old["farm"]["warehouse"] = {"carrot": 6}
	old["farm"]["last_seen_at"] = 1_700_000_000
	old["save_version"] = 3
	old["farm"].erase("warehouse_cap")       # keys that did not exist yet
	old["farm"].erase("harvest_basket")

	var wanted: Array = JSON.parse_string(JSON.stringify(four))

	# The clock stays where the save was written, so that settling cannot move
	# anything and every difference below is the migration's doing.
	GameClock.set_test_now(1_700_000_000, 0)
	SaveManager.data = SaveManager._migrate(
		JSON.parse_string(JSON.stringify(old)))
	SaveManager._settle_after_load()
	GameClock.clear_test_now()

	var plots: Array = SaveManager.data["farm"]["plots"]
	_ok(plots.size() == Farm.PLOT_COUNT,
		"a four-bed save comes back with %d beds" % Farm.PLOT_COUNT)
	_ok(int(SaveManager.data["farm"]["plot_count"]) == Farm.PLOT_COUNT,
		"...and plot_count says so too")

	# The four that were there, field by field.
	for i in range(4):
		var was: Dictionary = wanted[i]
		var now: Dictionary = plots[i]
		# Words compared as words, numbers as numbers. JSON has one number
		# type, so an int written to disk comes back a float, and comparing the
		# two as strings makes "9" and "9.0" a difference -- which would report
		# a migration failure that never happened. Every reader in the game
		# already goes through int()/float(); so does this.
		for key in ["plot_id", "state", "crop_id", "care_event"]:
			_ok(str(now.get(key, "")) == str(was.get(key, "")),
				"bed %d kept its %s across the migration (%s -> %s)"
				% [i + 1, key, str(was.get(key, "")), str(now.get(key, ""))])
		for key in ["plant_cycle_id", "planted_at", "growth_stage"]:
			_ok(int(now.get(key, -1)) == int(was.get(key, -2)),
				"bed %d kept its %s across the migration (%d -> %d)"
				% [i + 1, key, int(was.get(key, -2)), int(now.get(key, -1))])
		_ok(abs(float(now.get("growth_progress", -1.0))
				- float(was.get("growth_progress", 0.0))) < 0.001,
			"bed %d kept how far along it was" % (i + 1))
		_ok(abs(float(now.get("water_level", -1.0))
				- float(was.get("water_level", 0.0))) < 0.001,
			"bed %d kept how thirsty it was" % (i + 1))

	# The new ones are new. Not a copy of anything, not carrying a cycle id that
	# some other bed has already been paid against.
	for i in range(4, Farm.PLOT_COUNT):
		var fresh: Dictionary = plots[i]
		_ok(str(fresh.get("state", "")) == Farm.EMPTY,
			"bed %d is untouched grass" % (i + 1))
		_ok(str(fresh.get("crop_id", "")) == "",
			"bed %d has nothing planted in it" % (i + 1))
		_ok(int(fresh.get("plant_cycle_id", -1)) == 0,
			"bed %d starts its own planting count at zero" % (i + 1))
		_ok(str(fresh.get("plot_id", "")) == "plot_%d" % (i + 1),
			"bed %d has its own id" % (i + 1))

	_ok(int(SaveManager.data["farm"].get("warehouse_cap", 0))
			== Farm.WAREHOUSE_START,
		"a save from before the barn had a ceiling is given one")
	_ok(int(SaveManager.data["farm"]["warehouse"].get("carrot", 0)) == 6,
		"and what was already in the barn is still in it")
	_ok(int(SaveManager.data.get("save_version", 0))
			== SaveManager.FARM_SAVE_VERSION,
		"the save is stamped with the version that has six beds in it")


## Migrations are re-run every launch. One that is not idempotent pays out
## again every morning -- which is not a hypothetical here: the star refund did
## exactly that in its first cut.
func _opening_the_garden_twice_changes_nothing() -> void:
	SaveManager.data = SaveManager._default_data()
	SaveManager._settle_after_load()
	# The child plays: turns a patch over, puts a carrot in it.
	SaveManager.data["farm"]["plots"][0]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"][0]["crop_id"] = "carrot"
	SaveManager.data["farm"]["plots"][0]["planted_at"] = 1_700_000_000
	SaveManager.data["farm"]["warehouse"] = {"carrot": 6}
	SaveManager.data["inventory"] = {"seed_carrot": 2}
	var before := JSON.stringify(SaveManager.data["farm"])

	# Two more launches.
	SaveManager._settle_after_load()
	SaveManager._settle_after_load()

	_ok(JSON.stringify(SaveManager.data["farm"]) == before,
		"settling twice more leaves the garden exactly as it was")
	_ok(SaveManager.data["farm"]["plots"].size() == Farm.PLOT_COUNT,
		"the plots are not appended to on every launch")
	_ok(int(SaveManager.data["farm"]["warehouse"].get("carrot", 0)) == 6,
		"the barn does not double")
	_ok(str(SaveManager.data["farm"]["plots"][0]["crop_id"]) == "carrot",
		"and the carrot he planted is still planted")


## _migrate reaches two levels down and no further, and a plot's fields are
## three down inside an array. normalise_plot is what covers that gap, so this
## hands it the kinds of damage a real file arrives with.
func _a_damaged_garden_is_repaired_not_believed() -> void:
	SaveManager.data = SaveManager._default_data()

	var wrecked := {
		"plot_count": 4,
		"plots": [
			{"plot_id": "plot_1", "crop_id": "carrot"},         # missing most fields
			{"plot_id": "plot_2", "water_level": "very wet"},   # wrong type
			"not even a dictionary",                            # not a plot at all
			# and a fourth that is simply absent
		],
		"warehouse": {"carrot": 3},
	}
	var farm: Dictionary = Farm.normalise_farm(wrecked)

	_ok(farm["plots"].size() == Farm.PLOT_COUNT,
		"a short plot list is grown back to %d" % Farm.PLOT_COUNT)
	_ok(str(farm["plots"][0]["crop_id"]) == "carrot",
		"a plot missing fields keeps the one thing it did say")
	_ok(farm["plots"][0].has("water_level"),
		"...and gains the fields it was missing")
	_ok(typeof(farm["plots"][1]["water_level"]) == TYPE_FLOAT,
		"a field of the wrong type is replaced, not carried")
	_ok(str(farm["plots"][2]["plot_id"]) == "plot_3",
		"something that is not a plot at all becomes an empty one")
	_ok(str(farm["plots"][3]["plot_id"]) == "plot_4", "and the missing fourth appears")
	_ok(int(farm["warehouse"].get("carrot", 0)) == 3, "the barn survives the repair")

	# The int/float tolerance has to reach in here too: planted_at is written as
	# an int and comes back from JSON as a float, and calling that damage would
	# un-plant every crop on every load.
	var planted := {"plots": [{"plot_id": "plot_1", "crop_id": "corn",
		"planted_at": 1_700_000_000, "growth_stage": 2}]}
	var round_trip: Dictionary = Farm.normalise_farm(
		JSON.parse_string(JSON.stringify(planted)))
	_ok(int(round_trip["plots"][0]["planted_at"]) == 1_700_000_000,
		"a plot that has been to disk and back is still planted")
	_ok(int(round_trip["plots"][0]["growth_stage"]) == 2,
		"...and still at the stage it had reached")


# =====================================================================
# Stage two: what happened while nobody was watching.
#
# Every check below moves the clock instead of waiting for it. That is the
# whole reason GameClock exists and the whole reason the growth arithmetic is a
# pure function -- a night, a date dragged backwards and a year skipped forward
# are all just numbers here.
# =====================================================================

## Plant a carrot in plot 0 of a fresh garden, with the clock at `at`.
func _plant(crop_id: String, at: int) -> void:
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	GameClock.set_test_now(at, 0)
	SaveManager.load_game()
	var plot: Dictionary = SaveManager.data["farm"]["plots"][0]
	plot["state"] = Farm.SEEDED
	plot["crop_id"] = crop_id
	plot["plant_cycle_id"] = int(plot.get("plant_cycle_id", 0)) + 1
	plot["planted_at"] = at
	plot["last_updated_at"] = at
	SaveManager.data["farm"]["last_seen_at"] = at
	SaveManager.data["farm"]["clock_high_water"] = at


func _plot0() -> Dictionary:
	return SaveManager.data["farm"]["plots"][0]


## What a child does when the plot says it is thirsty. Growth deliberately
## needs one watering per crop -- a plant that finishes whether or not anyone
## looks after it makes the watering can a decoration.
func _water_if_thirsty() -> void:
	var plot: Dictionary = _plot0()
	if float(plot.get("water_level", 1.0)) <= 0.0 \
			or str(plot.get("care_event", "")) == "thirsty":
		SaveManager.data["farm"]["plots"][0] = Growth.water(plot)


const NOON := 1_699_948_800 + 4 * 60 * 60      # a Tuesday, well clear of midnight


## Five stages, in order, on the clock -- and not a stage early. The boundary
## matters more than the middle: a stage that turns over a second before it
## should is the kind of thing that looks fine and quietly makes the whole
## garden faster than it was designed to be.
func _a_carrot_goes_through_five_stages() -> void:
	var crop: Dictionary = GameData.get_crop("carrot")
	var seconds: Array = crop.get("stage_seconds", [])
	_ok(seconds.size() == 4, "a carrot has four changes between five stages")

	_plant("carrot", NOON)
	_ok(int(_plot0().get("growth_stage", -1)) == 0, "a fresh seed is at stage 0")

	var elapsed := 0
	for i in range(seconds.size()):
		# One second short of the change: still on the old stage.
		GameClock.set_test_now(NOON + elapsed + int(seconds[i]) - 1, 0)
		_water_if_thirsty()
		SaveManager.settle_farm()
		_ok(int(_plot0().get("growth_stage", -1)) == i,
			"one second before the change, stage %d is still stage %d" % [i, i])

		# ...and one second later it has turned over.
		GameClock.set_test_now(NOON + elapsed + int(seconds[i]), 0)
		SaveManager.settle_farm()
		elapsed += int(seconds[i])
		_ok(int(_plot0().get("growth_stage", -1)) == i + 1,
			"after stage %d's time is up it is at stage %d" % [i, i + 1])

	_ok(Farm.is_ready(_plot0()),
		"when the last stage is done the carrot is ready to pick")
	GameClock.clear_test_now()


## Acceptance #7. The garden is never in the scene tree during a level, and it
## does not need to be: growth is worked out from the timestamps on the way in.
func _it_grows_while_he_is_playing_a_level() -> void:
	_plant("carrot", NOON)
	var before := int(_plot0().get("growth_stage", 0))

	# He backs out of the garden and plays two levels. Nothing garden-shaped is
	# loaded, nothing is ticking, and twelve minutes pass.
	GameClock.set_test_now(NOON + 12 * 60, 0)
	SaveManager.settle_farm()

	_ok(int(_plot0().get("growth_stage", 0)) > before,
		"a carrot planted before a level is further along after it")
	_ok(int(_plot0().get("last_updated_at", 0)) == NOON + 12 * 60,
		"and the plot knows when it was last brought up to date")
	GameClock.clear_test_now()


## Acceptance #8. The tablet's date is two taps away in Settings.
func _a_clock_dragged_backwards_does_not_break_it() -> void:
	_plant("carrot", NOON)
	GameClock.set_test_now(NOON + 10 * 60, 0)
	SaveManager.settle_farm()
	var stage_before := int(_plot0().get("growth_stage", 0))
	var progress_before := float(_plot0().get("growth_progress", 0.0))
	_ok(stage_before > 0 or progress_before > 0.0, "ten minutes did something")

	# Back a week.
	GameClock.set_test_now(NOON - 7 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(int(_plot0().get("growth_stage", 0)) == stage_before,
		"a clock dragged backwards does not un-grow the carrot")
	_ok(float(_plot0().get("growth_progress", 0.0)) >= 0.0,
		"...and never leaves a negative anywhere")
	_ok(int(SaveManager.data["farm"]["clock_high_water"]) >= NOON + 10 * 60,
		"the garden remembers the furthest the clock ever got")

	# And it is not frozen: from the moment it was dragged to, it grows again.
	GameClock.set_test_now(NOON - 7 * 24 * 60 * 60 + 10 * 60, 0)
	SaveManager.settle_farm()
	var after := Growth.fraction_done(_plot0(), GameData.get_crop("carrot"))
	var at_rollback := float(stage_before) # any monotone reading will do
	_ok(after > 0.0, "and it keeps growing from wherever the clock now is")
	_ok(at_rollback >= 0.0, "(sanity)")
	GameClock.clear_test_now()


## Acceptance #9, and the one with money behind it. Ripe is a ceiling: skipping
## the date forward cannot turn one planting into two harvests, because there
## is no second harvest to reach.
func _a_clock_dragged_forwards_ripens_once() -> void:
	_plant("carrot", NOON)

	GameClock.set_test_now(NOON + 365 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	# A year away does NOT hand him a finished carrot. One tank of water is as
	# far as any absence gets, so what a year buys is exactly what a night
	# buys: a thirsty plant, waiting, having lost nothing.
	_ok(not Farm.is_ready(_plot0()),
		"a year away does not finish a plant nobody watered")
	_ok(str(_plot0().get("care_event", "")) == "thirsty",
		"it is waiting for help, which is the worst it can be")
	var parked := int(_plot0().get("growth_stage", 0))

	# Another year changes nothing at all: with no water there is nothing to do.
	GameClock.set_test_now(NOON + 730 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(int(_plot0().get("growth_stage", 0)) == parked,
		"a second year adds nothing to a plant that is out of water")

	# He waters it. Now it finishes -- once.
	SaveManager.data["farm"]["plots"][0] = Growth.water(_plot0())
	GameClock.set_test_now(NOON + 731 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(Farm.is_ready(_plot0()),
		"one watering finishes it")
	var stage := int(_plot0().get("growth_stage", 0))

	# And ripe is the ceiling: no amount of clock past this point moves it.
	GameClock.set_test_now(NOON + 2000 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(int(_plot0().get("growth_stage", 0)) == stage,
		"more years add nothing: ripe is the ceiling")
	_ok(str(_plot0().get("crop_id", "")) == "carrot",
		"and it is still the one carrot he planted, not a second one")

	# The cap is real: one absence is worth one night, not the whole year.
	_plant("tomato", NOON)
	GameClock.set_test_now(NOON + 365 * 24 * 60 * 60, 0)
	var elapsed: int = GameClock.elapsed_since(NOON)
	_ok(elapsed == GameClock.MAX_OFFLINE_SECONDS,
		"one absence is worth one night however long it really was")
	GameClock.clear_test_now()


## A plot he left ready is exactly what he comes back to.
##
## Deliberately ripened in measured steps so there is still water in the soil
## when it finishes -- ripening it by skipping a year drains the tank on the
## way, and then "the water did not move" is true whatever the code does. The
## first version of this check did exactly that and passed while the rule it
## was checking was deleted.
func _a_ripe_plot_is_frozen() -> void:
	var crop: Dictionary = GameData.get_crop("carrot")
	_plant("carrot", NOON)

	# 900 seconds of the 1800 it needs, on the first tank.
	GameClock.set_test_now(NOON + 900, 0)
	SaveManager.settle_farm()
	SaveManager.data["farm"]["plots"][0] = Growth.water(_plot0())
	# The other 900, which finishes it and leaves a quarter tank behind.
	GameClock.set_test_now(NOON + 1800, 0)
	SaveManager.settle_farm()

	var plot := _plot0()
	_ok(Farm.is_ready(plot), "measured watering ripens it")
	var water_left := float(plot.get("water_level", 0.0))
	_ok(water_left > 0.1, "and it finished with water still in the soil")

	# Now leave it for a month.
	GameClock.set_test_now(NOON + 30 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(absf(float(_plot0().get("water_level", 0.0)) - water_left) < 0.001,
		"a plot he left ready does not go thirsty waiting to be picked")
	_ok(str(_plot0().get("care_event", "")) == "",
		"and it is not asking him for anything")
	GameClock.clear_test_now()


## Acceptance #14, and the rule this garden is built around. A child who is
## away for a fortnight did not choose to be.
func _a_crop_never_dies() -> void:
	var crop: Dictionary = GameData.get_crop("carrot")
	_plant("carrot", NOON)

	# Away for a fortnight, settling once a day the way real launches would.
	for day in range(14):
		GameClock.set_test_now(NOON + (day + 1) * 24 * 60 * 60, 0)
		SaveManager.settle_farm()

	var plot := _plot0()
	_ok(str(plot.get("crop_id", "")) == "carrot",
		"a fortnight away and the carrot is still there")
	_ok(str(plot.get("care_event", "")) == "thirsty",
		"...thirsty, which is the worst a fortnight can do to it")
	_ok(str(plot.get("care_event", "")) != "dead",
		"there is no state called dead, and there never will be")
	_ok(not Farm.is_ready(plot),
		"it did not finish itself while he was away")
	# One watering, and the fortnight has cost him nothing.
	SaveManager.data["farm"]["plots"][0] = Growth.water(plot)
	GameClock.set_test_now(NOON + 15 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(Farm.is_ready(_plot0()),
		"and one watering after a fortnight away still gets him his carrot")

	# And a crop that ran out of water mid-way waits rather than dying.
	# A thirst crop, deliberately: since crops.json started saying which job
	# each one raises, corn and tomato never run dry at all -- one job per
	# planting -- so asking a tomato to get thirsty would be asking it for
	# something it can no longer do, and the assertion would have been quietly
	# testing nothing.
	_plant("strawberry", NOON)
	var thirsty: Dictionary = _plot0()
	thirsty["water_level"] = 0.05
	var berry: Dictionary = GameData.get_crop("strawberry")
	var parched: Dictionary = Growth.advance(thirsty, berry, 14 * 24 * 60 * 60)
	_ok(float(parched.get("water_level", 1.0)) == 0.0, "the water runs out")
	_ok(str(parched.get("care_event", "")) == "thirsty",
		"and the plot says it is thirsty")
	_ok(not Farm.is_ready(parched),
		"a thirsty plant waits instead of finishing")
	var revived: Dictionary = Growth.water(parched)
	_ok(float(revived.get("water_level", 0.0)) == 1.0, "one watering fills it")
	var moved_on: Dictionary = Growth.advance(revived, berry, 4 * 60 * 60)
	_ok(Growth.fraction_done(moved_on, berry)
			> Growth.fraction_done(parched, berry),
		"and it picks up exactly where it stopped, having lost nothing")

	# The weeds crops wait too, and just as harmlessly.
	var corn: Dictionary = GameData.get_crop("corn")
	var weedy: Dictionary = Farm.fresh_plot(0)
	weedy["state"] = Farm.SEEDED
	weedy["crop_id"] = "corn"
	weedy = Growth.advance(weedy, corn, 14 * 24 * 60 * 60)
	_ok(str(weedy.get("care_event", "")) == Growth.CARE_WEEDS,
		"a fortnight leaves the corn waiting to be weeded")
	_ok(not Farm.is_ready(weedy), "a fortnight cannot weed it for him")
	var tidied: Dictionary = Growth.advance(Growth.weed(weedy), corn, 2 * 60 * 60)
	_ok(Farm.is_ready(tidied),
		"and pulling them, whenever he gets round to it, still gets him his corn")
	GameClock.clear_test_now()


## Acceptance #3, the growing half: four plots, four independent clocks.
func _the_four_plots_do_not_share_a_clock() -> void:
	_plant("carrot", NOON)
	# Three more, planted at different times with different crops.
	var farm: Dictionary = SaveManager.data["farm"]
	var later := [0, 600, 1800, 3600]
	var crops := ["carrot", "corn", "strawberry", "tomato"]
	for i in range(1, 4):
		farm["plots"][i]["state"] = Farm.TILLED
		farm["plots"][i]["crop_id"] = crops[i]
		farm["plots"][i]["planted_at"] = NOON + later[i]
		farm["plots"][i]["last_updated_at"] = NOON

	GameClock.set_test_now(NOON + 2 * 60 * 60, 0)
	SaveManager.settle_farm()

	var readings: Array = []
	for i in range(4):
		var plot: Dictionary = SaveManager.data["farm"]["plots"][i]
		readings.append(Growth.fraction_done(
			plot, GameData.get_crop(str(plot.get("crop_id", "")))))
	# All four moved, each by its own crop's clock, from its own planting time.
	#
	# This used to rank the four against each other -- carrot ahead of corn
	# ahead of strawberry -- which was only ever a proxy for independence and
	# stopped being true the moment corn started stopping at its weeds. Ranking
	# crops that raise different jobs measures the jobs, not the clocks.
	for i in range(4):
		_ok(readings[i] > 0.0, "plot %d moved on its own" % (i + 1))
	# Same crop, planted at different times: the one planted first is ahead.
	# Same job, same timings -- so this compares clocks and nothing else.
	var same: Array = []
	for i in range(2):
		var plot: Dictionary = Farm.fresh_plot(i)
		plot["state"] = Farm.SEEDED
		plot["crop_id"] = "strawberry"
		same.append(Growth.advance(plot, GameData.get_crop("strawberry"),
			3600 if i == 0 else 1800))
	_ok(Growth.fraction_done(same[0], GameData.get_crop("strawberry"))
			> Growth.fraction_done(same[1], GameData.get_crop("strawberry")),
		"two beds of the same crop, planted an hour apart, are an hour apart")

	# Harvesting one must not touch the others, so prove they are separate
	# objects and not four references to the same dictionary.
	SaveManager.data["farm"]["plots"][0]["crop_id"] = ""
	_ok(str(SaveManager.data["farm"]["plots"][1]["crop_id"]) == "corn",
		"clearing one plot leaves the others alone")
	GameClock.clear_test_now()


## A farm may have been left all morning, then receive a seed just before the
## child closes the app. The seed gets its own minute, not the whole morning.
func _a_late_seed_never_inherits_farm_elapsed_time() -> void:
	_plant("carrot", NOON)
	var farm: Dictionary = SaveManager.data["farm"]
	var late: Dictionary = farm["plots"][1]
	late["state"] = Farm.SEEDED
	late["crop_id"] = "carrot"
	late["planted_at"] = NOON + 30 * 60
	late["last_updated_at"] = NOON + 30 * 60
	farm["plots"][1] = late
	farm["last_seen_at"] = NOON

	GameClock.set_test_now(NOON + 31 * 60, 0)
	var settled: Dictionary = Growth.settle(farm, GameClock.now_unix())
	var actual: Dictionary = settled["plots"][1]
	var expected: Dictionary = Growth.advance(late, GameData.get_crop("carrot"), 60)
	_ok(int(actual.get("growth_stage", -1)) == int(expected.get("growth_stage", -2)),
		"a late seed gets only the minute since it was planted")
	_ok(is_equal_approx(float(actual.get("growth_progress", -1.0)),
			float(expected.get("growth_progress", -2.0))),
		"...and its partial stage is only one minute old")
	_ok(int(actual.get("last_updated_at", 0)) == NOON + 31 * 60,
		"the late seed receives this settlement's own anchor")
	GameClock.clear_test_now()


## A plot stopped for a job cannot receive the time it spent waiting as a bonus
## the instant the child waters, weeds or shoos it.
func _care_restarts_growth_from_the_action() -> void:
	var crop: Dictionary = GameData.get_crop("corn")
	var waiting: Dictionary = Farm.fresh_plot(0)
	waiting["state"] = Farm.NEEDS_CARE
	waiting["crop_id"] = "corn"
	waiting["growth_stage"] = 1
	waiting["growth_progress"] = 0.25
	waiting["care_event"] = Growth.CARE_WEEDS
	waiting["planted_at"] = NOON
	waiting["last_updated_at"] = NOON
	var cared_at := NOON + 30 * 60
	var resumed := Growth.reanchor(Growth.weed(waiting), cared_at)
	var farm := {"last_seen_at": NOON, "clock_high_water": NOON,
		"plots": [resumed]}

	GameClock.set_test_now(cared_at + 60, 0)
	var settled: Dictionary = Growth.settle(farm, GameClock.now_unix())
	var actual: Dictionary = settled["plots"][0]
	var expected: Dictionary = Growth.advance(resumed, crop, 60)
	_ok(int(actual.get("growth_stage", -1)) == int(expected.get("growth_stage", -2)),
		"weeding resumes only from the moment the weeds were pulled")
	_ok(is_equal_approx(float(actual.get("growth_progress", -1.0)),
			float(expected.get("growth_progress", -2.0))),
		"...rather than crediting the half hour it was waiting")
	_ok(int(actual.get("last_updated_at", 0)) == cared_at + 60,
		"care's new local anchor is carried through the next settlement")
	GameClock.clear_test_now()


# =====================================================================
# Stage four: the barn, the orders, and the one number a child can spend.
# =====================================================================

func _starter_count() -> int:
	var starters := 0
	for crop in GameData.crops:
		if str(crop.get("unlock_condition", "")) == "":
			starters += 1
	return starters


func _fresh_save() -> void:
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()


## A negative carrot is not something a six-year-old can be told about.
func _the_barn_never_goes_negative() -> void:
	_fresh_save()
	Barn.put("carrot", 3)
	_ok(Barn.count("carrot") == 3, "three carrots go into the barn")

	_ok(not Barn.take("carrot", 4), "taking more than there is fails")
	_ok(Barn.count("carrot") == 3, "...and takes nothing on the way out")

	_ok(Barn.take("carrot", 3), "taking exactly what is there works")
	_ok(Barn.count("carrot") == 0, "and empties the shelf")
	_ok(Barn.contents().is_empty(),
		"an empty shelf shows nothing at all, not a zero")


## A full barn never eats a harvest.
##
## The barn has a ceiling now, and a ceiling is the first thing in this garden
## that can say no. What it must never say is "and the four strawberries you
## just picked are gone" -- a six-year-old watching that happen has been robbed
## by the game, and there is no message that fixes it because he cannot read.
##
## So everything over the line goes into a basket by the door, and the arithmetic
## that has to hold is the simplest one there is: nothing in plus nothing out
## equals nothing lost.
func _a_full_barn_never_loses_anything() -> void:
	_fresh_save()
	var ceiling := Barn.cap()
	_ok(ceiling == Farm.WAREHOUSE_START,
		"a new barn holds %d things" % Farm.WAREHOUSE_START)

	# Fill it to two short of the top.
	Barn.put("carrot", ceiling - 2)
	_ok(Barn.total() == ceiling - 2, "the barn fills up")
	_ok(Barn.room_left() == 2, "...and knows it has room for two more")

	# Pick five strawberries into a barn with room for two.
	var landed: Dictionary = Barn.store_harvest("strawberry", 5)
	_ok(int(landed["stored"]) == 2, "two of the five fit in the barn")
	_ok(int(landed["spilled"]) == 3, "and the other three go in the basket")
	_ok(int(landed["stored"]) + int(landed["spilled"]) == 5,
		"nothing at all is lost between the plant and the barn")
	_ok(Barn.count("strawberry", Barn.WAREHOUSE) == 2,
		"the barn holds the two it took")
	_ok(Barn.count("strawberry", Barn.BASKET) == 3,
		"the basket holds the three it could not")
	_ok(Barn.is_full(), "and the barn is now full")

	# Picking again with no room at all still loses nothing.
	var again: Dictionary = Barn.store_harvest("tomato", 3)
	_ok(int(again["stored"]) == 0, "a full barn takes none of the next harvest")
	_ok(int(again["spilled"]) == 3, "...and all three wait in the basket")
	_ok(Barn.count("tomato", Barn.BASKET) == 3, "the basket keeps them")

	# Room appears. The basket empties itself -- no button, no errand.
	_ok(Barn.pay({"carrot": 10}), "an order takes ten carrots out of the barn")
	_ok(Barn.count("strawberry", Barn.BASKET) == 0
			and Barn.count("tomato", Barn.BASKET) == 0,
		"and the basket tips itself back in the moment there is room")
	_ok(Barn.count("strawberry") == 5, "all five strawberries are in the barn")
	_ok(Barn.count("tomato") == 3, "and all three tomatoes")
	# What went in, minus what the order took: 38 carrots, less the 10 it paid,
	# plus every one of the 5 strawberries and 3 tomatoes that were picked.
	# Written as the sum rather than as a number, so that it is checking the
	# arithmetic and not agreeing with it.
	_ok(Barn.total() == (ceiling - 2) - 10 + 5 + 3,
		"with nothing invented and nothing lost")
	_ok(Barn.count("carrot") == ceiling - 12, "and the carrots it paid with gone")

	# The seed pouch has no ceiling at all: a child who cannot buy a seed
	# because his pouch is full has hit a wall with nothing on screen to clear.
	Barn.put("seed_carrot", 500, "inventory")
	_ok(Barn.count("seed_carrot", "inventory") == 500,
		"seeds and tools are not capped")


## The overflow basket is a shelf landmark, not a row that slides every time a
## new crop kind spills. A flight started during one brush stroke has one honest
## landing place even if later beds add more kinds before the shelf rebuilds.
func _the_overflow_basket_has_a_stable_shelf_anchor() -> void:
	var wide := GardenScreen.spilled_basket_anchor(Vector2(1280, 720))
	var tall := GardenScreen.spilled_basket_anchor(Vector2(1280, 960))
	_ok(wide.x > 0.0 and wide.x < 1280.0 and wide.y > 0.0 and wide.y < 720.0,
		"the overflow basket anchor sits on the visible wide shelf")
	_ok(is_equal_approx(wide.x, tall.x) and is_equal_approx(tall.y - wide.y, 240.0),
		"the overflow anchor keeps its x position and follows the taller shelf")


## An order one carrot short takes nothing. Emptying the barn of everything it
## CAN cover and then refusing is the worst of both.
func _an_order_is_all_or_nothing() -> void:
	_fresh_save()
	Barn.put("strawberry", 2)
	Barn.put("carrot", 0)
	var basket := {"strawberry": 2, "carrot": 1}
	_ok(not Barn.can_pay(basket), "an order he cannot fill says so")
	_ok(not Barn.pay(basket), "...and paying it fails")
	_ok(Barn.count("strawberry") == 2,
		"and the strawberries he DID have are still there")

	Barn.put("carrot", 1)
	_ok(Barn.pay(basket), "with the last carrot it goes through")
	_ok(Barn.count("strawberry") == 0 and Barn.count("carrot") == 0,
		"and the whole basket leaves the barn at once")


## Acceptance #11 and #12. The one with money behind it.
func _an_order_pays_once() -> void:
	_fresh_save()
	var order: Dictionary = GameData.garden_orders[0]
	var price := int(order.get("rewards", {}).get("coins", 0))
	var order_id := str(order.get("id", ""))
	var before := Coins.balance()
	var delivered: Array = SaveManager.data["farm_orders"]["delivered"]

	var paid := RewardManager.grant("garden:order:%s" % order_id, price,
		order_id, delivered)
	_ok(paid == price, "delivering an order pays exactly what it promised")
	_ok(Coins.balance() == before + price,
		"and the 星星币 go up by exactly that much")
	_ok(order_id in delivered, "and the delivery is written down")

	# Again. And again. However many times the button is pressed.
	for again in range(3):
		_ok(RewardManager.grant("garden:order:%s" % order_id, price,
			order_id, delivered) == 0,
			"pressing a delivered order again pays nothing")
	_ok(Coins.balance() == before + price,
		"...and the balance has not moved")
	_ok(delivered.count(order_id) == 1,
		"and it is written down once, not four times")

	# Surviving a restart is the point of writing it down at all.
	SaveManager.save_game()
	SaveManager.load_game()
	var after_restart: Array = SaveManager.data["farm_orders"]["delivered"]
	_ok(order_id in after_restart, "the delivery survives closing the game")
	_ok(RewardManager.grant("garden:order:%s" % order_id, price,
		order_id, after_restart) == 0,
		"and it still will not pay a second time tomorrow")


## Acceptance #13. Gardening is not an achievement, and must not look like one.
##
## The fingerprint is borrowed from unlock_probe: the four numbers that decide
## what is unlocked. A whole planting-to-payment cycle must not move any of the
## first three.
func _the_garden_cannot_touch_his_score() -> void:
	_fresh_save()
	SaveManager.record_level_result("sunny_park_01", 3, 1.0, true)
	SaveManager.record_level_result("sunny_park_02", 2, 0.8)
	var stars_before := SaveManager.total_stars()
	var completed_before: int = SaveManager.data["levels"].size()
	var badges_before: int = SaveManager.data["rewards"]["badges"].size()
	var coins_before := Coins.balance()

	# Plant, grow, pick, deliver -- the whole loop.
	GameClock.set_test_now(NOON, 0)
	SaveManager.data["farm"]["last_seen_at"] = NOON
	var plots: Array = SaveManager.data["farm"]["plots"]
	plots[0]["state"] = Farm.TILLED
	plots[0]["crop_id"] = "carrot"
	plots[0]["planted_at"] = NOON
	GameClock.set_test_now(NOON + 8 * 60 * 60, 0)
	SaveManager.settle_farm()
	Barn.put("carrot", 3)
	var order: Dictionary = GameData.garden_orders[0]
	Barn.pay(order.get("requirements", {}))
	RewardManager.grant("garden:order", int(order.get("rewards", {}).get("coins", 0)),
		str(order.get("id", "")), SaveManager.data["farm_orders"]["delivered"])

	_ok(SaveManager.total_stars() == stars_before,
		"a whole gardening loop does not change one 关卡星章")
	_ok(SaveManager.data["levels"].size() == completed_before,
		"...and does not invent a level")
	_ok(SaveManager.data["rewards"]["badges"].size() == badges_before,
		"...and does not hand out a badge")
	_ok(Coins.balance() > coins_before,
		"the only number it moves is the one he can spend")
	GameClock.clear_test_now()


## Weeds are a job, not a punishment -- and the same job only once.
func _weeds_come_once_and_never_hurt_anything() -> void:
	var crop: Dictionary = GameData.get_crop("corn")
	var plot: Dictionary = Farm.fresh_plot(0)
	plot["state"] = Farm.SEEDED
	plot["crop_id"] = "corn"

	# Far enough in to reach the stage weeds arrive at.
	var grown: Dictionary = Growth.advance(plot, crop, 3000)
	_ok(int(grown.get("growth_stage", 0)) >= Growth.weeds_stage(crop),
		"the corn reaches the stage weeds come at")
	_ok(str(grown.get("care_event", "")) == Growth.CARE_WEEDS,
		"and weeds arrive -- every time, for every child, not by chance")
	_ok(str(grown.get("state", "")) == Farm.NEEDS_CARE,
		"and the bed says so in one word")

	# Weeds STOP it. That is what NEEDS_CARE means, and it did not use to: a
	# weedy plot once ripened on its own while the badge asked to be tapped,
	# so the job was decoration. A job that can be ignored teaches nothing.
	var waited: Dictionary = Growth.advance(grown, crop, 7 * 24 * 60 * 60)
	_ok(is_equal_approx(Growth.fraction_done(waited, crop),
			Growth.fraction_done(grown, crop)),
		"a week of weeds moves it not one second further on")
	_ok(not Farm.is_ready(waited), "and a week cannot ripen it either")
	_ok(str(waited.get("crop_id", "")) == "corn", "the corn is still there")

	var tidy: Dictionary = Growth.weed(grown)
	_ok(str(tidy.get("care_event", "")) == "", "pulling them clears the plot")
	_ok(str(tidy.get("state", "")) == Farm.GROWING, "and it is growing again")
	var later: Dictionary = Growth.advance(tidy, crop, 4000)
	_ok(str(later.get("care_event", "")) != Growth.CARE_WEEDS,
		"and they do not come back on the next visit")
	_ok(Growth.fraction_done(later, crop) > Growth.fraction_done(grown, crop),
		"and it makes up the ground it was waiting on")

	# A bed waiting on a job the growth loop knows NOTHING about still stops.
	#
	# This is the general rule -- NEEDS_CARE means stopped, whatever it is
	# waiting for -- and it needs its own case, because the weeds branch inside
	# the loop happens to stop weeds on its own. Deliberately deleting the
	# general rule left every weeds assertion above green, which is exactly how
	# a rule that is doing nothing hides. tomato's data already lists a second
	# care type, "trellis", that nothing raises yet; the day something does,
	# this is what makes it behave like a job rather than a decoration.
	var future: Dictionary = Farm.fresh_plot(2)
	future["state"] = Farm.NEEDS_CARE
	future["crop_id"] = "tomato"
	future["growth_stage"] = 1
	future["care_event"] = "trellis"
	var ignored: Dictionary = Growth.advance(future, GameData.get_crop("tomato"),
		30 * 24 * 60 * 60)
	_ok(int(ignored.get("growth_stage", 9)) == 1,
		"a bed waiting on ANY job stops, not just on the one kind the loop knows")
	_ok(not Farm.is_ready(ignored), "and a month cannot ripen it either")

	# A crop whose data does not ask for weeds never grows any.
	var berry: Dictionary = GameData.get_crop("strawberry")
	var clean: Dictionary = Farm.fresh_plot(1)
	clean["state"] = Farm.SEEDED
	clean["crop_id"] = "strawberry"
	clean = Growth.advance(clean, berry, 6000)
	_ok(str(clean.get("care_event", "")) != Growth.CARE_WEEDS,
		"a crop that does not ask for weeding never grows weeds")

## The tomato grows a caterpillar where the corn grows weeds -- the same
## mechanism wearing a different picture, and this proves the mechanism rather
## than the picture: it arrives at its stage every time, it STOPS the plant,
## shooing clears it once and for good, and crops that did not ask for it
## never get it.
func _the_caterpillar_is_weeds_wearing_a_different_face() -> void:
	var crop: Dictionary = GameData.get_crop("tomato")
	_ok(Growth.field_job(crop) == Growth.CARE_BUG,
		"the tomato's ground job is the caterpillar")

	var plot: Dictionary = Farm.fresh_plot(0)
	plot["state"] = Farm.SEEDED
	plot["crop_id"] = "tomato"
	# Far enough in to reach the stage the bug arrives at (5400 + 6300 and on).
	var grown: Dictionary = Growth.advance(plot, crop, 13000)
	_ok(int(grown.get("growth_stage", 0)) >= Growth.weeds_stage(crop),
		"the tomato reaches the stage the caterpillar comes at")
	_ok(str(grown.get("care_event", "")) == Growth.CARE_BUG,
		"and the caterpillar arrives -- every time, not by chance")
	_ok(str(grown.get("state", "")) == Farm.NEEDS_CARE,
		"and the bed says so in one word")

	var waited: Dictionary = Growth.advance(grown, crop, 7 * 24 * 60 * 60)
	_ok(is_equal_approx(Growth.fraction_done(waited, crop),
			Growth.fraction_done(grown, crop)),
		"a week of caterpillar moves the tomato not one second on")
	_ok(not Farm.is_ready(waited), "and cannot ripen it")

	var shooed: Dictionary = Growth.shoo(grown)
	_ok(str(shooed.get("care_event", "")) == "", "one shoo clears it")
	_ok(str(shooed.get("state", "")) == Farm.GROWING, "and growth resumes")
	_ok(bool(shooed.get("care_completed", false)),
		"and the visit is written down")
	var later: Dictionary = Growth.advance(shooed, crop, 8000)
	_ok(str(later.get("care_event", "")) != Growth.CARE_BUG,
		"so it does not come back this planting")

	# Thirst crops never grow one, and the weeds crop grows WEEDS, not this.
	var berry: Dictionary = Farm.fresh_plot(1)
	berry["state"] = Farm.SEEDED
	berry["crop_id"] = "strawberry"
	berry = Growth.advance(berry, GameData.get_crop("strawberry"), 8000)
	_ok(str(berry.get("care_event", "")) != Growth.CARE_BUG,
		"a crop that did not ask for a caterpillar never grows one")
	var corn_plot: Dictionary = Farm.fresh_plot(2)
	corn_plot["state"] = Farm.SEEDED
	corn_plot["crop_id"] = "corn"
	corn_plot = Growth.advance(corn_plot, GameData.get_crop("corn"), 3000)
	_ok(str(corn_plot.get("care_event", "")) == Growth.CARE_WEEDS,
		"and the corn still grows weeds, not caterpillars")


const SeedShop := preload("res://scripts/garden/seed_shop_manager.gd")
const Market := preload("res://scripts/garden/farm_market_manager.gd")


## The shop's whole contract, without a screen in the way: a crop is bought
## once, kept forever, refused politely, and returnable whole.
func _the_shop_sells_a_crop_exactly_once() -> void:
	_fresh_save()
	SaveManager.data["rewards"]["coins"] = 100

	_ok(SeedShop.state_of("carrot") == "owned",
		"a starter crop is already his, so the shop says so")
	_ok(SeedShop.state_of("potato") == "buyable",
		"the potato is on the shelf and he can afford it")
	_ok(SeedShop.state_of("dragonfruit") == "unknown",
		"a crop from nowhere is 'unknown', not a crash")

	_ok(SeedShop.buy("potato") == "", "forty coins buy the potato")
	_ok(Coins.balance() == 60, "...exactly forty of them")
	_ok(SeedShop.owns("potato"), "and it is his now")

	# Every way of paying twice, refused by the same word.
	_ok(SeedShop.buy("potato") == "owned", "buying it again is 'owned'")
	_ok(Coins.balance() == 60, "...and costs nothing")
	SaveManager.load_game()
	_ok(SeedShop.buy("potato") == "owned",
		"...even after closing the game and coming back")
	_ok(Coins.balance() == 60, "...which still costs nothing")

	# The regret window gives everything back.
	SeedShop.undo("potato")
	_ok(not SeedShop.owns("potato"), "putting it back takes it off the rack")
	_ok(Coins.balance() == 100, "...and returns the whole price")
	SeedShop.undo("potato")
	_ok(Coins.balance() == 100,
		"a second undo returns nothing -- there is nothing to return")

	# Too poor is a state, not an error.
	SaveManager.data["rewards"]["coins"] = 3
	_ok(SeedShop.state_of("lettuce") == "poor", "three coins is 'poor'")
	_ok(SeedShop.buy("lettuce") == "poor", "and buying is refused the same way")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 3,
		"with not one coin taken")
	_ok(not SeedShop.owns("lettuce"), "and no lettuce handed over")


## 三期阶段 2：种子跟着农场长。3 级的豌豆、5 级的苹果，在还没长到的
## 农场里既不能买也不标价——那是圈好的地，不是没钱，更不是锁。等级
## 一到，同一排种子按普通规矩开卖。钱的手一次都不许伸出来。
func _the_shop_grows_with_the_farm() -> void:
	_fresh_save()
	SaveManager.data["rewards"]["coins"] = 500

	# 1 级农场：3 级的豌豆和 5 级的苹果都还没长到。
	_ok(SeedShop.state_of("peas") == "level",
		"at level 1 the peas are ground not grown to, whatever the purse holds")
	_ok(SeedShop.buy("peas") == "level",
		"and buying them is refused with the level word, not the money word")
	_ok(Coins.balance() == 500, "the refusal took nothing")
	_ok(not SeedShop.owns("peas"), "and handed nothing over")
	_ok(SeedShop.state_of("apple") == "level", "the apple waits for level 5")

	# 3 级农场：豌豆开卖，苹果还在长。
	SaveManager.data["farm"]["farm_xp"] = 60
	_ok(SeedShop.state_of("peas") == "buyable",
		"at level 3 the peas go on sale like any seed")
	_ok(SeedShop.buy("peas") == "", "and sixty coins buy them")
	_ok(Coins.balance() == 440, "...exactly sixty")
	_ok(SeedShop.state_of("apple") == "level",
		"the apple still waits -- one batch at a time")

	# 5 级农场：全架开卖。买回来的和送回去的都走老规矩。
	SaveManager.data["farm"]["farm_xp"] = 200
	_ok(SeedShop.state_of("apple") == "buyable", "level 5 opens the orchard")
	_ok(SeedShop.buy("apple") == "", "and the apple is his")
	SeedShop.undo("apple")
	_ok(not SeedShop.owns("apple") and Coins.balance() == 440,
		"the regret window returns the whole two hundred and forty")

	# 存档往返：等级门是算术，不是账本——xp 在，门就在对的位置。
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(SeedShop.owns("peas"), "the peas survive the round-trip")
	_ok(SeedShop.state_of("watermelon") == "buyable",
		"and the gate still stands where the xp says")


## The market's whole contract: the quote is the payment, the payment happens
## once, and a basket the barn cannot cover moves nothing at all.
func _the_market_pays_once_and_only_for_what_is_there() -> void:
	_fresh_save()
	SaveManager.data["rewards"]["coins"] = 0
	Barn.put("carrot", 5)
	Barn.put("tomato", 2)

	var expected := 5 * GameData.market_price("carrot") \
		+ 2 * GameData.market_price("tomato")
	_ok(Market.quote({"carrot": 5, "tomato": 2}) == expected,
		"the quote is the price list times the pile, nothing else")

	var paid := Market.sell({"carrot": 5, "tomato": 2})
	_ok(paid == expected, "selling pays exactly the quote")
	_ok(Coins.balance() == expected, "...into the purse")
	_ok(Barn.count("carrot") == 0 and Barn.count("tomato") == 0,
		"...and the crops leave the barn")
	_ok("farm_sale_1" in SaveManager.data["farm"]["paid_sales"],
		"and the receipt is on the ledger")

	# The same basket again: the crops are gone, so nothing moves.
	_ok(Market.sell({"carrot": 5, "tomato": 2}) == 0,
		"selling the same basket twice pays nothing the second time")
	_ok(Coins.balance() == expected, "...and the purse does not move")

	# A basket one carrot short takes NOTHING -- not even the carrots it has.
	Barn.put("carrot", 2)
	_ok(Market.sell({"carrot": 3}) == 0,
		"a basket the barn cannot cover pays nothing")
	_ok(Barn.count("carrot") == 2, "...and takes nothing either")

	# Junk sells for nothing and takes nothing.
	_ok(Market.sell({}) == 0, "an empty basket pays nothing")
	_ok(Market.sell({"dragonfruit": 9}) == 0,
		"a crop the till has no price for pays nothing")

	# And the receipts survived all of it exactly once each.
	SaveManager.load_game()
	_ok(int(SaveManager.data["rewards"]["coins"]) == expected,
		"what was written to disk is the one real sale")


# =====================================================================
# The state machine.
# =====================================================================

## Every combination that used to be possible and meaningless, offered to the
## loader one at a time.
##
## The old shape was three booleans, which is eight combinations, of which six
## were nonsense -- ripe with nothing planted, weeds on bare grass, a carrot
## growing in earth that was never turned. Nothing rejected any of them, and a
## save carrying one would have drawn a patch of earth that no tap could move.
##
## Every case here has to be REPAIRED and not rejected. A hand-edited file or a
## crop retired between two versions must cost one patch of earth, never the
## whole save.
func _a_plot_says_what_it_is_doing_in_one_word() -> void:
	SaveManager.data = SaveManager._default_data()

	var nonsense := {"plots": [
		# ripe, with nothing planted
		{"plot_id": "plot_1", "state": Farm.READY, "crop_id": ""},
		# a carrot growing in ground that says it is bare
		{"plot_id": "plot_2", "state": Farm.EMPTY, "crop_id": "carrot"},
		# a state no version of this game has ever written
		{"plot_id": "plot_3", "state": "SUPERGROWN", "crop_id": "corn"},
		# a crop the catalogue has never heard of
		{"plot_id": "plot_4", "state": Farm.GROWING, "crop_id": "dragonfruit"},
	]}
	var plots: Array = Farm.normalise_farm(nonsense)["plots"]

	_ok(str(plots[0]["state"]) == Farm.TILLED,
		"ripe with nothing planted becomes turned earth, not a free harvest")
	_ok(str(plots[1]["state"]) in Farm.PLANTED_STATES,
		"a crop in ground that claims to be bare keeps the crop")
	_ok(str(plots[2]["state"]) in Farm.STATES,
		"a state nothing answers to is replaced by one that means something")
	_ok(str(plots[3]["crop_id"]) == "" and str(plots[3]["state"]) == Farm.TILLED,
		"a retired crop leaves turned earth behind, not a plant that cannot grow")

	# Numbers outside what they mean.
	var silly := {"plots": [{"plot_id": "plot_1", "state": Farm.GROWING,
		"crop_id": "carrot", "growth_stage": 99, "growth_progress": 4.5,
		"water_level": -3.0, "planted_at": -500, "plant_cycle_id": -7}]}
	var fixed: Dictionary = Farm.normalise_farm(silly)["plots"][0]
	_ok(int(fixed["growth_stage"]) <= Farm.STAGES, "a stage past the end is clamped")
	_ok(float(fixed["growth_progress"]) <= 1.0, "progress past 1.0 is clamped")
	_ok(float(fixed["water_level"]) >= 0.0, "water below empty is clamped")
	_ok(int(fixed["planted_at"]) >= 0, "a stamp from before the epoch is cleared")
	_ok(int(fixed["plant_cycle_id"]) >= 0, "a negative planting cycle is cleared")

	# And the whole save still opens, which is the point of repairing rather
	# than rejecting.
	_ok(SaveManager.total_stars() >= 0, "the save survives a garden full of nonsense")


## A save written before `state` existed still knows what each plot was doing.
##
## This is the migration, and it is the one that matters: every tablet with the
## garden already on it holds plots described by `tilled` and
## `ready_to_harvest` and nothing else. If the derivation is wrong, a child
## comes back to four patches of grass and a barn full of crops he cannot
## explain.
func _a_save_from_before_the_state_machine_still_knows_what_it_was_doing() -> void:
	var old := {"plots": [
		{"plot_id": "plot_1", "tilled": false, "crop_id": ""},
		{"plot_id": "plot_2", "tilled": true, "crop_id": ""},
		{"plot_id": "plot_3", "tilled": true, "crop_id": "carrot",
			"growth_stage": 2, "growth_progress": 0.4},
		{"plot_id": "plot_4", "tilled": true, "crop_id": "corn",
			"growth_stage": 4, "ready_to_harvest": true},
	]}
	var plots: Array = Farm.normalise_farm(old)["plots"]
	_ok(str(plots[0]["state"]) == Farm.EMPTY, "untouched grass is still grass")
	_ok(str(plots[1]["state"]) == Farm.TILLED, "turned and empty is still turned")
	_ok(str(plots[2]["state"]) == Farm.GROWING, "a half-grown carrot is still growing")
	_ok(str(plots[3]["state"]) == Farm.READY, "a ripe cob is still ripe")

	# A plot that was carrying weeds when the tablet was last closed.
	var waiting := {"plots": [{"plot_id": "plot_1", "tilled": true,
		"crop_id": "carrot", "growth_stage": 2, "care_event": "weeds"}]}
	_ok(str(Farm.normalise_farm(waiting)["plots"][0]["state"]) == Farm.NEEDS_CARE,
		"a plot that was waiting for help is still waiting for help")

	# A seed that had not come up yet is a seed, not a plant.
	var seeded := {"plots": [{"plot_id": "plot_1", "tilled": true,
		"crop_id": "carrot", "growth_stage": 0, "growth_progress": 0.0}]}
	_ok(str(Farm.normalise_farm(seeded)["plots"][0]["state"]) == Farm.SEEDED,
		"a seed that has not come up yet is still a seed")


## The planting cycle only ever goes up.
##
## It is half of the transaction id a harvest is paid against, so a cycle that
## repeats is a harvest that can be paid for twice. The dangerous moment is the
## reset at the end of a harvest, which puts every other field back to its
## default -- this one has to survive it.
func _a_planting_cycle_never_repeats() -> void:
	_plant("carrot", NOON)
	_ok(int(_plot0()["plant_cycle_id"]) > 0, "planting gives the bed a cycle number")
	# Whether the number SURVIVES a harvest is asserted where a harvest actually
	# happens -- garden_touch_probe. It was asserted here first, against a plot
	# this function had built by hand, and deliberately breaking the line in
	# garden_screen that carries it across proved that assertion was checking
	# its own fixture and nothing else.

	# The ledger is bounded, and being bounded must not let an id come back.
	var farm: Dictionary = SaveManager.data["farm"]
	farm["paid_harvests"] = []
	for i in range(Farm.PAID_LEDGER_KEPT + 20):
		Farm.remember_paid(farm, "farm_harvest_plot_1_%d" % i)
	var paid: Array = farm["paid_harvests"]
	_ok(paid.size() == Farm.PAID_LEDGER_KEPT, "the ledger stays bounded")
	_ok(paid[paid.size() - 1] == "farm_harvest_plot_1_%d"
		% (Farm.PAID_LEDGER_KEPT + 19), "...keeping the most recent")
	_ok(not ("farm_harvest_plot_1_0" in paid),
		"...and dropping the oldest, which no rising cycle can ever present again")


# --- 阶段 4: the bear ------------------------------------------------------

## The bear's farm is a pure function of the clock, and the four promises
## around his shared strawberry all hold: one per cycle, help before the next,
## the friendship star exactly once, and nothing of his ever lost -- provable
## here because ASKING what his farm looks like writes nothing at all.
func _the_bears_farm_is_arithmetic_and_kindness() -> void:
	_fresh_save()
	var period := NpcFarm.share_period()
	_ok(period >= 600, "the share cycle is minutes at the least, never seconds")
	_ok(period == GameData.crop_total_seconds("strawberry"),
		"the shared strawberry regrows on the strawberry's own real time")

	var now := period * 5 + 123
	var before := JSON.stringify(SaveManager.data["farm"])
	var beds: Array = NpcFarm.bear_beds(now)
	_ok(JSON.stringify(NpcFarm.bear_beds(now)) == JSON.stringify(beds),
		"the same clock always shows the same farm")
	_ok(JSON.stringify(SaveManager.data["farm"]) == before,
		"looking at the bear's farm writes nothing to the save")
	_ok(beds.size() == 6, "the bear keeps six beds")

	var shares := 0
	var thirsty := 0
	for plot in beds:
		if bool(plot.get("share", false)):
			shares += 1
		elif bool(plot.get("help_target", false)):
			thirsty += 1
			_ok(str(plot.get("care_event", "")) == Growth.CARE_THIRSTY,
				"the bed he needs help with is really thirsty")
		else:
			_ok(str(plot.get("care_event", "")) == "",
				"the bear's own beds never nag the visitor")
	_ok(shares == 1, "exactly one bed is shared")
	_ok(thirsty == 1, "exactly one bed asks for the kindness back")

	# The pick, the promise, and the star.
	_ok(NpcFarm.can_pick(now), "a new friend may take the starred one")
	for plot in beds:
		if bool(plot.get("share", false)):
			_ok(Farm.is_ready(plot), "...and it is drawn ripe, wearing the star")
	NpcFarm.record_pick(now)
	_ok(not NpcFarm.can_pick(now), "one per visit: the star is down")
	_ok(not NpcFarm.can_pick(now + period),
		"...and the NEXT one waits until the watering promised for this one")
	_ok(NpcFarm.friendship() == 0, "picking alone earns no star")
	_ok(NpcFarm.record_help(), "the watering clears the promise")
	_ok(NpcFarm.friendship() == 1, "...and grows the friendship by one")
	_ok(not NpcFarm.record_help(), "a second watering finds nothing owed")
	_ok(NpcFarm.friendship() == 1, "...and pays no second star")
	_ok(not NpcFarm.can_pick(now), "this cycle stays picked forever")
	_ok(NpcFarm.can_pick(now + period), "the next cycle grows a new one")

	# After the pick the shared bed is growing again, not a hole: nothing on
	# the bear's farm is ever consumed, the strawberry he gave was EXTRA.
	var after: Array = NpcFarm.bear_beds(now)
	for i in range(after.size()):
		var plot: Dictionary = after[i]
		if bool(plot.get("share", false)):
			_ok(str(plot.get("state", "")) == Farm.GROWING,
				"the shared bed is growing the next one, not standing empty")
		elif not bool(plot.get("help_target", false)):
			_ok(JSON.stringify(plot) == JSON.stringify(beds[i]),
				"the bear's own bed %d is untouched by the pick" % i)


## The bear returns the visits -- by the same arithmetic, never in front of
## the child, never more than his own rhythm allows, and only ever bringing
## good news: watered beds, one star, one line for the board.
func _the_bear_drops_by_but_never_in_front_of_him() -> void:
	_fresh_save()
	var period := NpcFarm.visit_period()
	var now := period * 9
	_ok(NpcFarm.maybe_visit(now).is_empty(),
		"a bear he has not befriended does not let himself in")

	NpcFarm.record_pick(now)
	NpcFarm.record_help()
	_ok(NpcFarm.maybe_visit(now).is_empty(),
		"the first visit is not instant -- he walks home first")
	_ok(int(NpcFarm.bear_state().get("last_visit_at", 0)) == now,
		"...but his clock has started")
	_ok(NpcFarm.maybe_visit(now).is_empty(), "asking twice changes nothing")

	# Leave one bed thirsty for him to find.
	var farm: Dictionary = SaveManager.data["farm"]
	var plots: Array = farm["plots"]
	var bed: Dictionary = plots[0]
	bed["state"] = Farm.NEEDS_CARE
	bed["care_event"] = Growth.CARE_THIRSTY
	bed["crop_id"] = "carrot"
	plots[0] = bed
	farm["plots"] = plots

	var later := now + period
	var entry: Dictionary = NpcFarm.maybe_visit(later)
	_ok(not entry.is_empty(), "after one of his own rhythms, he comes")
	_ok(int(entry.get("watered", 0)) == 1, "he found the one thirsty bed")
	_ok(str((farm["plots"][0] as Dictionary).get("care_event", "")) == "",
		"...and the watering was real, not a story")
	_ok(NpcFarm.friendship() == 2, "he leaves exactly one friendship star")
	_ok((farm.get("visit_log", []) as Array).size() == 1,
		"one visit writes one line on the board")
	_ok(bool(farm.get("visit_log_unread", false)),
		"...and the board knows it is news")
	_ok(NpcFarm.maybe_visit(later).is_empty(),
		"the same rhythm cannot be collected twice")
	_ok(NpcFarm.friendship() == 2, "...and pays no second star")

	# The board remembers ten visits and no more, newest first.
	for i in range(Farm.VISIT_LOG_KEPT + 5):
		Farm.remember_visit(farm, {"who": "bear", "watered": 0, "star": 1,
			"at": later + 100 + i})
	var log: Array = farm["visit_log"]
	_ok(log.size() == Farm.VISIT_LOG_KEPT, "the board stays bounded")
	_ok(int((log[0] as Dictionary).get("at", 0))
		== later + 100 + Farm.VISIT_LOG_KEPT + 4,
		"...keeping the newest at the top")


## 三期阶段 3：悄悄摘一颗，答的是温柔。没有星的那颗一个周期只有一颗；
## 摘了不发星、不挨说；小熊下次来访什么都没说、悄悄多分一颗，眨这一次
## 眼就把账清了——settle 跑两遍也只眨一次。真正的里程碑句永远让在前面。
func _the_quiet_strawberry_is_answered_with_grace() -> void:
	_fresh_save()
	var period := NpcFarm.share_period()
	var now := period * 7 + 55

	# 一个周期一颗，和分享星同一套算术，但不看 help_owed 的脸色。
	_ok(NpcFarm.can_sneak(now), "a fresh save has the quiet one standing ripe")
	NpcFarm.record_pick(now)
	_ok(NpcFarm.can_sneak(now),
		"grace is unconditional -- owing the watering does not close the "
		+ "quiet bed")
	NpcFarm.record_sneak(now)
	_ok(bool(NpcFarm.bear_state().get("sneak_owed", false)),
		"the sneak writes the wink into the save")
	_ok(not NpcFarm.can_sneak(now), "one per cycle: this one is spent")
	_ok(NpcFarm.can_sneak(now + period), "the next cycle grows another")

	# 下次来访：多一颗草莓、一句琥珀色的话，眨一次眼就清账。
	NpcFarm.record_help()                         # friendship 1, door open
	NpcFarm.maybe_visit(now)                      # 起表，不算来访
	var berries := Barn.count("strawberry")
	var entry: Dictionary = NpcFarm.maybe_visit(now + period)
	_ok(not entry.is_empty(), "after his rhythm, the bear comes")
	_ok(int(entry.get("shared_back", 0)) == 1,
		"the visit carries the one extra strawberry")
	_ok(str(entry.get("milestone_key", "")) == "garden.visit_shared_back",
		"...and its one amber line says he said nothing and shared")
	_ok(Barn.count("strawberry") == berries + 1,
		"the extra strawberry really lands in the barn")
	_ok(not bool(NpcFarm.bear_state().get("sneak_owed", false)),
		"the wink is winked -- the flag clears with the berry")

	# 再来一次访问周期：没有新的悄悄摘，就没有第二颗。
	var entry2: Dictionary = NpcFarm.maybe_visit(now + period * 2)
	_ok(not entry2.is_empty() and not entry2.has("shared_back"),
		"a visit with nothing owed brings no extra berry and tells no tale")
	_ok(Barn.count("strawberry") == berries + 1,
		"...and the barn agrees")

	# 撞上真里程碑的那次：里程碑的句子赢，草莓照给。
	# （前面已经来了 2 次：把账本拨到差一次就到第 3 次的门口。）
	NpcFarm.record_sneak(now + period * 2 + 5)
	var before_milestone := Barn.count("strawberry")
	var entry3: Dictionary = NpcFarm.maybe_visit(now + period * 3)
	_ok(str(entry3.get("milestone_key", "")) == "garden.visit_friend_3",
		"a real milestone outranks the wink's line")
	_ok(int(entry3.get("shared_back", 0)) == 1
			and Barn.count("strawberry") == before_milestone + 1,
		"...but the extra strawberry still arrives, told by its icon")

	# 存档往返：欠着的眨眼过夜也还在。
	NpcFarm.record_sneak(now + period * 3 + 5)
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(bool(NpcFarm.bear_state().get("sneak_owed", false)),
		"an owed wink survives the game closing")
	_ok(not NpcFarm.can_sneak(now + period * 3 + 6),
		"...and so does the spent cycle")


## 常客里程碑：第三次来访带一句话和一块木板，只带一次，存档也记得。
func _the_regular_gets_his_milestones_once() -> void:
	_fresh_save()
	GameClock.set_test_now(1_700_000_000, 0)
	var now := GameClock.now_unix()
	NpcFarm.record_pick(now)
	NpcFarm.record_help()
	var period := NpcFarm.visit_period()
	NpcFarm.maybe_visit(now)          # 起表，不算来访

	var planks_before := Barn.count("plank", "inventory")
	var entries: Array = []
	for i in range(3):
		var entry: Dictionary = NpcFarm.maybe_visit(now + period * (i + 1))
		_ok(not entry.is_empty(), "visit %d should happen" % (i + 1))
		entries.append(entry)

	_ok(not (entries[0] as Dictionary).has("milestone_key")
			and not (entries[1] as Dictionary).has("milestone_key"),
		"a milestone arrived before the third VISIT -- the regulars' ledger "
		+ "counts visits, never friendship stars (picking and helping pay "
		+ "stars too, and mixing them made 'third visit' arrive on the first)")
	_ok(str((entries[2] as Dictionary).get("milestone_key", "")) \
			== "garden.visit_friend_3",
		"the third visit should carry the friendship line")
	_ok(Barn.count("plank", "inventory") == planks_before + 1,
		"the third meeting leaves exactly one plank (%d -> %d)"
		% [planks_before, Barn.count("plank", "inventory")])
	var regular: Dictionary = SaveManager.data.get("farm_visitors", {})\
		.get("bear", {})
	_ok(int(regular.get("visits", 0)) == 3,
		"the regulars' ledger counts %s visits, not 3" % regular.get("visits"))
	_ok("visits_3" in (regular.get("claimed", []) as Array),
		"the claim ledger did not record visits_3")

	# 再来两次也不再发第一块木板；存档往返后账本还在。
	var planks_after := Barn.count("plank", "inventory")
	NpcFarm.maybe_visit(now + period * 4)
	_ok(Barn.count("plank", "inventory") == planks_after,
		"a later visit paid the same milestone again")
	SaveManager.save_game()
	SaveManager.load_game()
	_ok("visits_3" in ((SaveManager.data.get("farm_visitors", {})
			.get("bear", {}) as Dictionary).get("claimed", []) as Array),
		"the milestone claim vanished across a save round-trip")


## Two tablets, one bear. The merge must never un-make a promise, un-pick a
## cycle, or lose a visit either tablet saw.
func _two_tablets_agree_about_the_bear() -> void:
	_fresh_save()
	var farm: Dictionary = SaveManager.data["farm"]
	var npc: Dictionary = Farm.normalise_npc(null)
	npc["bear"]["last_share_cycle"] = 3
	npc["bear"]["help_owed"] = true
	npc["bear"]["last_visit_at"] = 1000
	farm["npc"] = npc
	farm["npc_friendship"] = {"bear": 1}
	farm["visit_log"] = [{"who": "bear", "watered": 1, "star": 1, "at": 1000}]
	farm["visit_log_unread"] = false

	var theirs := {"farm": {
		"npc": {"bear": {"last_share_cycle": 5, "help_owed": false,
			"last_visit_at": 900}},
		"npc_friendship": {"bear": 4},
		"visit_log": [
			{"who": "bear", "watered": 1, "star": 1, "at": 1000},
			{"who": "bear", "watered": 0, "star": 1, "at": 2000},
		],
		"visit_log_unread": true,
	}}
	SaveManager._merge_farm(theirs)

	var merged: Dictionary = Farm.normalise_npc(
		SaveManager.data["farm"].get("npc")).get("bear", {})
	_ok(int(merged.get("last_share_cycle", -1)) == 5,
		"a cycle picked on either tablet stays picked -- high water")
	_ok(bool(merged.get("help_owed", false)),
		"a promise made on either tablet was made -- OR")
	_ok(int(merged.get("last_visit_at", 0)) == 1000,
		"the visit clock keeps the later stamp")
	_ok(int(SaveManager.data["farm"]["npc_friendship"].get("bear", 0)) == 4,
		"friendship takes the higher count, never the sum")
	var log: Array = SaveManager.data["farm"]["visit_log"]
	_ok(log.size() == 2, "the same visit on both tablets lands once")
	_ok(int((log[0] as Dictionary).get("at", 0)) == 2000,
		"...and the union reads newest first")
	_ok(bool(SaveManager.data["farm"]["visit_log_unread"]),
		"news on either tablet is still news")


# --- 阶段 5: the ladder and the land ---------------------------------------

## The farm's level is arithmetic on one rising number, and the number rises
## only through award() -- whose callers all stand inside once-only gates, so
## the ladder inherits every idempotence the money already has.
func _the_farm_grows_up_by_arithmetic() -> void:
	_fresh_save()
	_ok(Level.xp() == 0 and Level.level() == 1,
		"a new farm stands on the first rung with nothing climbed")
	_ok(Level.next_at() > 0, "...and can see the next rung from there")
	_ok(Level.level_of(Level.next_at()) == 2,
		"the next threshold is exactly where level 2 begins")
	_ok(Level.level_of(Level.next_at() - 1) == 1,
		"...and one xp short of it is still level 1")

	var top := 1
	var top_xp := 0
	for row in GameData.farm_level_table():
		top = maxi(top, int(row.get("level", 1)))
		top_xp = maxi(top_xp, int(row.get("xp", 0)))
	_ok(Level.level_of(top_xp) == top and Level.level_of(top_xp * 10) == top,
		"the ladder has a top and xp beyond it changes nothing")

	var pair: Array = Level.award("harvest")
	_ok(int(pair[0]) == 1 and Level.xp() == GameData.farm_xp_for("harvest"),
		"one harvest pays exactly its listed xp")
	_ok(int(SaveManager.data["farm"]["farm_level"]) == Level.level(),
		"the stored level is a copy of the computed one, never its own fact")
	_ok(Level.award("no_such_kind") == [Level.level(), Level.level()]
		and Level.xp() == GameData.farm_xp_for("harvest"),
		"an unknown kind pays nothing rather than something")

	# Climb to the top rung and make sure the save carries it whole.
	while Level.level() < top:
		Level.award("order")
	var climbed := Level.xp()
	_ok(int(SaveManager.data["farm"]["farm_level"]) == top,
		"the stored copy climbed with the truth, rung for rung")
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(Level.xp() == climbed and Level.level() == top,
		"a reopened save stands exactly where it climbed to")
	_ok(Level.progress() == 1.0,
		"the top of the ladder reads as a FULL bar, never an empty one")

	# Two tablets: the xp is a high-water mark, never a sum.
	_fresh_save()
	SaveManager.data["farm"]["farm_xp"] = 30
	SaveManager.data["farm"]["farm_level"] = Level.level_of(30)
	SaveManager._merge_farm({"farm": {"farm_xp": 50, "farm_level": 2}})
	_ok(Level.xp() == 50,
		"a merge takes the higher climb, and 30+50 never becomes 80")


## The land under stones (test #10 of the twenty-two): bought in order, all
## or nothing, exactly once, and still there after the lid closes.
func _the_seventh_bed_is_bought_once() -> void:
	_fresh_save()
	var farm: Dictionary = SaveManager.data["farm"]
	_ok(Expand.state_of(6) == "level",
		"the seventh bed waits for the farm to grow first")
	_ok(Expand.buy(6) == "level" and int(farm["plot_count"]) == Farm.PLOT_COUNT,
		"...and buying it early does nothing at all")

	farm["farm_xp"] = 999
	farm["farm_level"] = Level.level_of(999)
	SaveManager.data["rewards"]["coins"] = 10
	_ok(Expand.state_of(6) == "poor", "grown but broke: the stones say poor")
	var held := Coins.balance()
	_ok(Expand.buy(6) == "poor" and Coins.balance() == held
		and int(farm["plot_count"]) == Farm.PLOT_COUNT,
		"...and a poor buy takes no coins and no land moves")

	SaveManager.data["rewards"]["coins"] = 200
	_ok(Expand.state_of(7) == "level",
		"the EIGHTH bed is not for sale while the seventh stands in stones")
	_ok(Expand.buy(6) == "", "the seventh bed clears")
	_ok(int(farm["plot_count"]) == 7 and (farm["plots"] as Array).size() == 7,
		"...and the count and the ground agree")
	_ok(str((farm["plots"][6] as Dictionary).get("state", "")) == Farm.EMPTY,
		"...and the new earth arrives as untouched grass")
	_ok(Coins.balance() == 200 - Expand.cost_of(6), "...at exactly its price")
	_ok(Expand.buy(6) == "owned" and Coins.balance() == 200 - Expand.cost_of(6),
		"buying it again finds it owned and charges nothing")

	# The regret window's arithmetic: back off while untouched, refused after.
	Expand.undo(6)
	_ok(int(farm["plot_count"]) == 6 and Coins.balance() == 200,
		"within the window, whole price back and the stones return")
	_ok(Expand.buy(6) == "", "bought again for keeps")
	var plots: Array = farm["plots"]
	var bed: Dictionary = plots[6]
	bed["state"] = Farm.TILLED
	plots[6] = bed
	farm["plots"] = plots
	var before := Coins.balance()
	Expand.undo(6)
	_ok(int(farm["plot_count"]) == 7 and Coins.balance() == before,
		"turned earth is HIS earth: the undo quietly refuses to take it")

	# Reopened, the bed is still his (the whole of test #10).
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(int(SaveManager.data["farm"]["plot_count"]) == 7
		and (SaveManager.data["farm"]["plots"] as Array).size() == 7,
		"the lid closes and opens and the seventh bed is still there")
	_ok(Expand.state_of(7) == "poor" or Expand.state_of(7) == "ready",
		"...and the eighth is next in line now")


## 三期阶段 1：厨房只做会做的菜、食材整取整付、送出去换一颗友谊星。
func _the_kitchen_cooks_knowledge_and_feeds_a_friend() -> void:
	_fresh_save()
	var Recipes := preload("res://scripts/garden/recipe_manager.gd")

	# 没学会：有食材也不做
	Barn.put("strawberry", 3)
	SaveManager.data["farm"]["unlocked_recipes"] = []
	_ok(not Recipes.cook("strawberry_soup"),
		"the kitchen cooked a recipe the child has not learned")
	_ok(Barn.count("strawberry") == 3,
		"a refused cook still took ingredients")

	# 学会但食材不够：拒绝且分文不动
	SaveManager.data["farm"]["unlocked_recipes"] = ["strawberry_soup"]
	Barn.take("strawberry", 2)
	_ok(not Recipes.cook("strawberry_soup"),
		"one strawberry made a three-strawberry soup")
	_ok(Barn.count("strawberry") == 1, "the failed cook nibbled an ingredient")

	# 做一份：食材恰好离开，菜恰好出现
	Barn.put("strawberry", 2)
	_ok(Recipes.cook("strawberry_soup"), "a learned, stocked recipe refused to cook")
	_ok(Barn.count("strawberry") == 0, "cooking left ingredients behind")
	_ok(Recipes.dish_count("strawberry_soup") == 1, "the dish never arrived")

	# 送给小熊：菜离开、友谊 +1、谢饭条目在
	var stars_before := NpcFarm.friendship()
	var log_before: int = (SaveManager.data["farm"].get("visit_log", []) as Array).size()
	_ok(Recipes.give_to_bear("strawberry_soup"), "giving the dish failed")
	_ok(Recipes.dish_count("strawberry_soup") == 0, "the given dish stayed home")
	_ok(NpcFarm.friendship() == stars_before + 1,
		"a gift of food should grow the friendship by exactly one")
	var log: Array = SaveManager.data["farm"].get("visit_log", [])
	_ok(log.size() == log_before + 1 \
			and str((log[0] as Dictionary).get("kind", "")) == "thanks",
		"the thank-you never reached the visit board")

	# 空盘子送不出去；存档往返后一切还在
	_ok(not Recipes.give_to_bear("strawberry_soup"),
		"an empty plate was given anyway")
	SaveManager.save_game()
	SaveManager.load_game()
	_ok(str(((SaveManager.data["farm"].get("visit_log", []) as Array)[0]
		as Dictionary).get("kind", "")) == "thanks",
		"the thank-you vanished across a save round-trip")


## --- 阶段 6: the crop's own move -------------------------------------------
##
## Every crop in the garden names the move that picks it, and the catalogue
## turns that name into a recogniser Gesture can judge. Both halves of that
## sentence can rot independently -- a crop retired from one file but not the
## other, a recogniser renamed, the carrot's pull quietly becoming a push --
## and none of it crashes anywhere. It shows up as a bed that ignores a
## child's pull, which is the kind of bug no console will ever print.
func _the_moves_a_crop_asks_for_are_moves_the_finger_can_make() -> void:
	var words := {}
	for crop in GameData.crops:
		var crop_id := str(crop.get("id", ""))
		var move := HarvestCrops.gesture_for(crop_id)
		_ok(not move.is_empty(),
			"crop %s asks for a move the catalogue knows" % crop_id)
		if move.is_empty():
			continue
		_ok(str(move["recogniser"]) in Gesture.ALL,
			"crop %s's move is one Gesture can judge" % crop_id)
		_ok(move["gesture_params"] is Dictionary,
			"crop %s's move has parameters" % crop_id)
		# The garden's word for the move and the catalogue's must be the SAME
		# word. Two files free to disagree are two files that will.
		_ok(str(move["harvest_gesture"]) == str(crop.get("harvest_gesture", "")),
			"crop %s's move is called the same thing in both files" % crop_id)
		words[crop_id] = str(move["harvest_gesture"])

	# The carrot's pull is THE teaching move; it must stay a drag, and upward.
	var carrot := HarvestCrops.gesture_for("carrot")
	var carrot_params: Dictionary = carrot.get("gesture_params", {})
	_ok(str(carrot.get("recogniser", "")) == Gesture.DRAG,
		"the carrot's move is a drag")
	_ok(Vector2(float(carrot_params.get("direction_x", 1.0)),
			float(carrot_params.get("direction_y", 1.0))) == Vector2(0.0, -1.0),
		"and a drag UP, because a carrot comes out of the ground")

	# The moves exist so the farm is not fourteen identical taps: somewhere in
	# the list there must be more than one word, and more than one recogniser.
	var unique_words := {}
	for crop_id in words:
		unique_words[words[crop_id]] = true
	_ok(unique_words.size() >= 5,
		"the farm asks for at least five different moves")

	# A crop the catalogue never heard of answers with no move at all -- tap
	# only, never a crash.
	_ok(HarvestCrops.gesture_for("no_such_crop").is_empty(),
		"an unknown crop answers with no move, not an error")

	# The lean: a bed follows a pulling finger and clamps, and settles when the
	# finger leaves. The targets are set synchronously, so no ticking needed.
	var bed := PlotView.new()
	bed.setup(0)
	bed.lean(Vector2(0.0, -120.0))
	_ok(float(bed.get("_lean_lift_to")) < 0.0,
		"an upward pull lifts the plant out of its hollow")
	bed.lean(Vector2(90.0, 0.0))
	_ok(float(bed.get("_lean_rot_to")) > 0.0,
		"a sideways pull tilts the plant")
	bed.lean(Vector2(900.0, -2000.0))
	_ok(absf(float(bed.get("_lean_rot_to"))) <= 0.20
			and float(bed.get("_lean_lift_to")) >= -22.0,
		"the lean is clamped -- a wild drag cannot uproot the drawing")
	bed.relax()
	_ok(is_equal_approx(float(bed.get("_lean_rot_to")), 0.0)
			and is_equal_approx(float(bed.get("_lean_lift_to")), 0.0),
		"and the plant settles when the finger leaves")
	bed.free()


## The quiet clock settles the same farm every twenty seconds while he plays.
## The arithmetic must read "asked twice at the same minute" as "asked once",
## and a minute of clock must buy exactly a minute of carrot every time -- a
## settle that compounded, even slightly, would make the tick a growth
## multiplier and the farm a slot machine.
func _settling_twice_at_the_same_moment_never_compounds() -> void:
	_plant("carrot", NOON)
	GameClock.set_test_now(NOON + 60, 0)
	SaveManager.settle_farm()
	var once: float = float(_plot0().get("growth_progress", 0.0))
	_ok(once > 0.0, "a minute of clock grows the carrot")
	SaveManager.settle_farm()
	_ok(is_equal_approx(float(_plot0().get("growth_progress", 0.0)), once),
		"a second settle at the same minute moves nothing")
	GameClock.set_test_now(NOON + 120, 0)
	SaveManager.settle_farm()
	var twice: float = float(_plot0().get("growth_progress", 0.0))
	_ok(twice > once, "another minute moves it further")
	_ok(absf((twice - once) - once) < 0.0005,
		"and by exactly the same minute's worth again -- settling never compounds")
	GameClock.clear_test_now()


## --- 阶段 7: the board never runs dry ---------------------------------------
##
## After the friends' own eight orders are all thanked, the board fills with
## recurring ones -- that is the whole endgame loop, and the only reason the
## ribbon keeps having something to say. A recurring order that asks for a
## retired crop, pays nothing, or pays LESS than the market would for the same
## basket is not a broken card; it is a loop that teaches the wrong lesson.
func _recurring_orders_hold_up_the_endgame() -> void:
	var bands := {}
	var prices: Dictionary = GameData.farm_market_prices.get("prices", {})
	var recurring := 0
	for order in GameData.garden_orders:
		if not bool(order.get("recurring", false)):
			continue
		recurring += 1
		var oid := str(order.get("id", ""))
		var gate := str(order.get("unlock_condition", ""))
		var level := int(gate.substr(6)) if gate.begins_with("level:") else 1
		if not bands.has(level):
			bands[level] = 0
		bands[level] += 1
		var worth := 0
		var real_crops := true
		for crop_id in order.get("requirements", {}).keys():
			if GameData.get_crop(str(crop_id)).is_empty():
				real_crops = false
			worth += int(prices.get(str(crop_id), 0)) \
				* int(order["requirements"][crop_id])
		_ok(real_crops,
			"recurring order %s asks only for real crops" % oid)
		_ok(int(order.get("rewards", {}).get("coins", 0)) > 0,
			"recurring order %s pays for the trouble" % oid)
		_ok(int(order.get("rewards", {}).get("coins", 0)) > worth,
			"recurring order %s beats the market for the same basket (%d vs %d)"
				% [oid, int(order["rewards"]["coins"]), worth])
		_ok(str(order.get("completion_transaction_key", "")) != "",
			"recurring order %s names the key its deliveries are counted by"
				% oid)
		_ok(not order.get("rewards", {}).get("items", {}).has("plank"),
			"recurring order %s carries no planks -- the roof is the friends' story, told once" % oid)
	_ok(recurring >= 3,
		"the board has recurring work for the days after the friends' orders")
	for level in [1, 3, 5]:
		_ok(int(bands.get(level, 0)) >= 1,
			"level %d has recurring work -- no band's board ever runs dry" % level)


## --- 阶段 8: the day's little jobs ------------------------------------------
##
## The daily list is 王者农场's spine, transplanted without the fangs: the
## same three verbs the farm teaches, tallied for one day, paid once, reset
## silently at the date line. The arithmetic has to hold four promises -- the
## tally clamps, the same day keeps its state, a new day rolls clean, and
## tomorrow's claim key is one nobody has ever paid against.
func _the_days_little_jobs_hold_water() -> void:
	var ids := {}
	for task in GameData.garden_dailies:
		var tid := str(task.get("id", ""))
		_ok(tid != "", "a daily task has an id")
		_ok(not ids.has(tid),
			"daily id %s is the only one with that name" % tid)
		ids[tid] = true
		_ok(int(task.get("target", 0)) > 0,
			"daily %s has a target a child can reach" % tid)
		_ok(int(task.get("coins", 0)) > 0,
			"daily %s pays for the trouble" % tid)
	_ok(GameData.garden_dailies.size() == 3,
		"the day asks for exactly three little jobs")

	var yesterday := {"dailies": {"date": "2026-09-01",
		"progress": {"water": 3}, "claimed": ["water"]}}
	var same: Dictionary = Dailies.roll(yesterday, "2026-09-01")
	_ok(int(same.get("progress", {}).get("water", 0)) == 3,
		"the same day keeps its tally and its claims")
	var rolled: Dictionary = Dailies.roll(yesterday, "2026-09-02")
	_ok((rolled.get("progress", {}) as Dictionary).is_empty()
			and (rolled.get("claimed", []) as Array).is_empty(),
		"a new date rolls a clean list -- yesterday is never nagged about")

	# add() answers the DAILIES dict; the caller hangs it back on the farm --
	# the same write-back the screen does.
	var daily_farm: Dictionary = {"dailies": Dailies.add({}, "2026-09-02", "water", 2)}
	var water: Dictionary = Dailies.task_by_id("water")
	_ok(not Dailies.done(daily_farm.get("dailies", {}), water),
		"two of three is not done")
	daily_farm["dailies"] = Dailies.add(daily_farm, "2026-09-02", "water", 5)
	var dailies: Dictionary = daily_farm.get("dailies", {})
	_ok(int(dailies.get("progress", {}).get("water", 0)) == 3,
		"the tally clamps at the target -- it is a promise, not a score")
	_ok(Dailies.done(dailies, water), "and three of three is done")
	_ok(Dailies.done_count(dailies) == 1 and not Dailies.all_done(dailies),
		"one finished verb lights one daily star, never the whole luck bonus")
	var full_day: Dictionary = dailies.duplicate(true)
	var full_progress: Dictionary = full_day.get("progress", {})
	for task in GameData.garden_dailies:
		full_progress[str(task.get("id", ""))] = int(task.get("target", 1))
	full_day["progress"] = full_progress
	var summary: Dictionary = Dailies.summary(full_day)
	_ok(Dailies.done_count(full_day) == GameData.garden_dailies.size()
		and Dailies.all_done(full_day),
		"all three familiar verbs, and only all three, light the golden chance")
	_ok(int(summary.get("done", 0)) == GameData.garden_dailies.size()
		and int(summary.get("total", 0)) == GameData.garden_dailies.size()
		and bool(summary.get("all_done", false)),
		"the ribbon's display summary comes from the same all-done rule")
	full_day["claimed"] = ["garden_daily_2026-09-02_water"]
	_ok(Dailies.all_done(full_day),
		"collecting a coin later does not turn off care already completed")
	var tomorrow: Dictionary = Dailies.roll({"dailies": full_day}, "2026-09-03")
	_ok(not Dailies.all_done(tomorrow),
		"a fresh date starts with dark daily stars and ordinary luck")
	_ok(Dailies.claim_key(dailies, water)
		!= Dailies.claim_key(Dailies.roll(daily_farm, "2026-09-03"), water),
		"tomorrow's claim key is one nobody has ever paid against")

	# The tally and the claims live INSIDE the farm's own dict, and the farm's
	# normalisation is a whitelist -- a key it does not know is dropped on
	# every load. The first cut of the dailies stored them outside that
	# whitelist: a same-day reopen silently refunded every coin and asked the
	# child to earn the day a second time. These four questions are the
	# regression that makes sure the whitelist never forgets again.
	var saved_farm: Dictionary = SaveManager.data.get("farm", {})
	var saved_dailies: Dictionary = Dailies.roll(saved_farm, "2026-09-02")
	saved_dailies["progress"] = {"water": 2}
	saved_dailies["claimed"] = ["garden_daily_2026-09-02_water"]
	SaveManager.data["farm"]["dailies"] = saved_dailies
	var kept: Dictionary = Farm.normalise_farm(SaveManager.data["farm"])
	_ok(str(kept.get("dailies", {}).get("date", "")) == "2026-09-02",
		"normalising the farm keeps today's daily list")
	_ok(int(kept.get("dailies", {}).get("progress", {}).get("water", 0)) == 2,
		"and its tally survives the load")
	_ok((kept.get("dailies", {}).get("claimed", []) as Array).size() == 1,
		"and a claim once collected stays collected for the day")
	var fresh: Dictionary = Dailies.roll(kept, "2026-09-03")
	_ok((fresh.get("claimed", []) as Array).is_empty(),
		"while a new date still rolls a clean list")

	# A whitelist check is not enough: it is the real JSON reload that used to
	# erase the list. Claim one completed job through the island's usual reward
	# gate, save it, and come back on the same day. The second pass must see the
	# stored claim and refuse a second coin payment.
	SaveManager.data = SaveManager._default_data()
	var claim_farm: Dictionary = SaveManager.data.get("farm", {})
	var claim_day := "2026-09-02"
	var completed: Dictionary = Dailies.add(claim_farm, claim_day,
		str(water.get("id", "water")), Dailies.target(str(water.get("id", "water"))))
	claim_farm["dailies"] = completed
	SaveManager.data["farm"] = claim_farm
	var first_claims: Array = completed.get("claimed", [])
	var coin_reward := int(water.get("coins", 0))
	var coins_before := Coins.balance()
	var first_paid := RewardManager.grant("garden:daily", coin_reward,
		Dailies.claim_key(completed, water), first_claims)
	completed["claimed"] = first_claims
	SaveManager.data["farm"]["dailies"] = completed
	SaveManager.save_game()
	_ok(first_paid == coin_reward and Coins.balance() == coins_before + coin_reward,
		"a completed daily pays once before the restart")

	SaveManager.load_game()
	var reloaded_farm: Dictionary = SaveManager.data.get("farm", {})
	var reloaded_dailies: Dictionary = reloaded_farm.get("dailies", {})
	_ok(str(reloaded_dailies.get("date", "")) == claim_day,
		"a same-day restart keeps the daily's date")
	_ok(int(reloaded_dailies.get("progress", {}).get("water", 0))
		== Dailies.target("water"),
		"a same-day restart keeps the completed tally")
	_ok(Dailies.claimed(reloaded_dailies, water),
		"a same-day restart keeps the collected claim")
	var reloaded_claims: Array = reloaded_dailies.get("claimed", [])
	var coins_after_reload := Coins.balance()
	var paid_again := RewardManager.grant("garden:daily", coin_reward,
		Dailies.claim_key(reloaded_dailies, water), reloaded_claims)
	_ok(paid_again == 0 and Coins.balance() == coins_after_reload,
		"the reward gate refuses the same daily claim after a restart")
