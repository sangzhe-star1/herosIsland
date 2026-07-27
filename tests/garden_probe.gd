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
	_a_plot_says_what_it_is_doing_in_one_word()
	_a_save_from_before_the_state_machine_still_knows_what_it_was_doing()
	_a_planting_cycle_never_repeats()
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
		_ok(str(plot.get("state", "")) == Farm.EMPTY, "every new plot is untouched grass")
		_ok(int(plot.get("planted_at", -1)) == 0, "nothing has been planted yet")
		_ok(not Farm.is_ready(plot),
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
