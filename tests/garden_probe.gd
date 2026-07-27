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

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
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
	# --- stage two: growing ---
	_a_carrot_goes_through_five_stages()
	_it_grows_while_he_is_playing_a_level()
	_a_clock_dragged_backwards_does_not_break_it()
	_a_clock_dragged_forwards_ripens_once()
	_a_crop_never_dies()
	_a_ripe_plot_is_frozen()
	_the_four_plots_do_not_share_a_clock()
	# --- stage four: the barn, the orders, and the money ---
	_the_barn_never_goes_negative()
	_an_order_is_all_or_nothing()
	_an_order_pays_once()
	_the_garden_cannot_touch_his_score()
	_weeds_come_once_and_never_hurt_anything()

	# Put the save back the way it was found, and say so out loud: a probe that
	# leaves the disk holding its own fixtures is how the shop probe once failed
	# in a suite it passed alone.
	SaveManager.data = real_save
	SaveManager.save_game()

	for failure in _failures:
		print("FAIL  %s" % failure)
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

	_ok(plots.size() == 4, "a new save has four patches of earth")
	_ok(int(farm.get("plot_count", 0)) == 4, "...and says so in plot_count")

	var ids: Dictionary = {}
	for plot in plots:
		ids[str(plot.get("plot_id", ""))] = true
		_ok(str(plot.get("crop_id", "")) == "", "every new plot is empty")
		_ok(not bool(plot.get("tilled", true)), "every new plot is unturned")
		_ok(int(plot.get("planted_at", -1)) == 0, "nothing has been planted yet")
		_ok(not bool(plot.get("ready_to_harvest", true)),
			"nothing is ready on the first morning")
	_ok(ids.size() == 4, "the four plots have four different ids, not one repeated")

	# Seeds on the first launch, not the second. The settlements used to be
	# skipped entirely for a brand-new save, which would have opened the garden
	# with an empty seed rack until the child closed the game and came back.
	_ok(farm.get("unlocked_crops", []).size() == GameData.crops.size(),
		"a new child can plant every starter crop on the first launch")
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
	_ok(farm.get("plots", []).size() == 4, "an old save gains four patches of earth")
	_ok(bool(farm.get("opened", false)), "the garden is marked open")
	_ok(farm.get("unlocked_crops", []).size() == GameData.crops.size(),
		"and the starter seeds arrive with it")
	_ok(SaveManager.data.has("inventory"), "the inventory key is there")
	_ok(SaveManager.data.get("farm_orders", {}).has("delivered"),
		"and so is the delivered-orders list that stops an order paying twice")
	_ok(int(SaveManager.data.get("save_version", 0))
			== SaveManager.FARM_SAVE_VERSION,
		"the save has been carried to the version with a garden in it")


## Migrations are re-run every launch. One that is not idempotent pays out
## again every morning -- which is not a hypothetical here: the star refund did
## exactly that in its first cut.
func _opening_the_garden_twice_changes_nothing() -> void:
	SaveManager.data = SaveManager._default_data()
	SaveManager._settle_after_load()
	# The child plays: turns a patch over, puts a carrot in it.
	SaveManager.data["farm"]["plots"][0]["tilled"] = true
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
	_ok(SaveManager.data["farm"]["plots"].size() == 4,
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

	_ok(farm["plots"].size() == 4, "a short plot list is grown back to four")
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
	plot["tilled"] = true
	plot["crop_id"] = crop_id
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

	_ok(bool(_plot0().get("ready_to_harvest", false)),
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
	_ok(not bool(_plot0().get("ready_to_harvest", false)),
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
	_ok(bool(_plot0().get("ready_to_harvest", false)),
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
	_ok(bool(plot.get("ready_to_harvest", false)), "measured watering ripens it")
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
	_ok(not bool(plot.get("ready_to_harvest", false)),
		"it did not finish itself while he was away")
	# One watering, and the fortnight has cost him nothing.
	SaveManager.data["farm"]["plots"][0] = Growth.water(plot)
	GameClock.set_test_now(NOON + 15 * 24 * 60 * 60, 0)
	SaveManager.settle_farm()
	_ok(bool(_plot0().get("ready_to_harvest", false)),
		"and one watering after a fortnight away still gets him his carrot")

	# And a crop that ran out of water mid-way waits rather than dying.
	_plant("tomato", NOON)
	var thirsty: Dictionary = _plot0()
	thirsty["water_level"] = 0.05
	var tomato: Dictionary = GameData.get_crop("tomato")
	var parched: Dictionary = Growth.advance(thirsty, tomato, 14 * 24 * 60 * 60)
	_ok(float(parched.get("water_level", 1.0)) == 0.0, "the water runs out")
	_ok(str(parched.get("care_event", "")) == "thirsty",
		"and the plot says it is thirsty")
	_ok(not bool(parched.get("ready_to_harvest", false)),
		"a thirsty plant waits instead of finishing")
	var revived: Dictionary = Growth.water(parched)
	_ok(float(revived.get("water_level", 0.0)) == 1.0, "one watering fills it")
	var moved_on: Dictionary = Growth.advance(revived, tomato, 8 * 60 * 60)
	_ok(Growth.fraction_done(moved_on, tomato)
			> Growth.fraction_done(parched, tomato),
		"and it picks up exactly where it stopped, having lost nothing")
	GameClock.clear_test_now()


## Acceptance #3, the growing half: four plots, four independent clocks.
func _the_four_plots_do_not_share_a_clock() -> void:
	_plant("carrot", NOON)
	# Three more, planted at different times with different crops.
	var farm: Dictionary = SaveManager.data["farm"]
	var later := [0, 600, 1800, 3600]
	var crops := ["carrot", "corn", "strawberry", "tomato"]
	for i in range(1, 4):
		farm["plots"][i]["tilled"] = true
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
	_ok(readings[0] >= readings[1], "the carrot is further along than the corn")
	_ok(readings[1] > readings[2], "the corn is further along than the strawberry")
	_ok(readings[2] > readings[3], "the strawberry is further along than the tomato")
	_ok(readings[3] > 0.0, "and even the tomato has started")

	# Harvesting one must not touch the others, so prove they are separate
	# objects and not four references to the same dictionary.
	SaveManager.data["farm"]["plots"][0]["crop_id"] = ""
	_ok(str(SaveManager.data["farm"]["plots"][1]["crop_id"]) == "corn",
		"clearing one plot leaves the others alone")
	GameClock.clear_test_now()


# =====================================================================
# Stage four: the barn, the orders, and the one number a child can spend.
# =====================================================================

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
	var price := int(order.get("reward_coins", 0))
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
	plots[0]["tilled"] = true
	plots[0]["crop_id"] = "carrot"
	plots[0]["planted_at"] = NOON
	GameClock.set_test_now(NOON + 8 * 60 * 60, 0)
	SaveManager.settle_farm()
	Barn.put("carrot", 3)
	var order: Dictionary = GameData.garden_orders[0]
	Barn.pay(order.get("wants", {}))
	RewardManager.grant("garden:order", int(order.get("reward_coins", 0)),
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
	var crop: Dictionary = GameData.get_crop("carrot")
	var plot: Dictionary = Farm.fresh_plot(0)
	plot["tilled"] = true
	plot["crop_id"] = "carrot"

	# Far enough in to reach the stage weeds arrive at.
	var grown: Dictionary = Growth.advance(plot, crop, 800)
	_ok(int(grown.get("growth_stage", 0)) >= Growth.WEEDS_AT_STAGE,
		"the carrot reaches the stage weeds come at")
	_ok(str(grown.get("care_event", "")) == Growth.CARE_WEEDS,
		"and weeds arrive -- every time, for every child, not by chance")

	# Weeds do not stop it growing. They are something to do, not a tax.
	var kept_going: Dictionary = Growth.advance(grown, crop, 300)
	_ok(Growth.fraction_done(kept_going, crop)
			> Growth.fraction_done(grown, crop),
		"a weedy plot keeps growing while it waits to be tidied")

	var tidy: Dictionary = Growth.weed(grown)
	_ok(str(tidy.get("care_event", "")) == "", "pulling them clears the plot")
	var later: Dictionary = Growth.advance(tidy, crop, 400)
	_ok(str(later.get("care_event", "")) != Growth.CARE_WEEDS,
		"and they do not come back on the next visit")
