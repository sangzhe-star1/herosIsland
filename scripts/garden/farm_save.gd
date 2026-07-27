extends RefCounted
## The shape of 星光菜园 on disk, and the one function that repairs it.
##
## Deliberately NOT a `class_name` -- Godot rebuilds the global class cache only
## in the editor, so a new class name is a parse error on any machine that has
## not rescanned, and a parse error takes the whole game grey. Reached the same
## way as every other shared helper:
##
##     const Farm := preload("res://scripts/garden/farm_save.gd")
##
##
## WHY normalise_plot() EXISTS
##
## SaveManager._migrate() fills in missing keys two levels deep: a new top-level
## key gets a default, and so does a new key inside one. It cannot go deeper,
## and it can never reach inside an ARRAY -- and `plots` is an array. So the
## moment a second field is added to a plot, every save already on a tablet has
## plots without it, and nothing in the migration will ever put it there.
##
## Rather than write a migration per field forever, every read of a plot goes
## through normalise_plot(). A plot that is missing something gets the default
## on the way past, and adding a field in the future costs one line here and
## no migration at all.

const PLOT_COUNT := 4

## Five stages, from seed to ripe. The child watches a shape change four times;
## fewer and nothing seems to happen, more and the middle ones look identical.
const STAGES := 5

## One patch of earth. Every field here has to survive a JSON round trip, so
## there are no nested dictionaries and no nulls.
const PLOT := {
	"plot_id": "",
	"crop_id": "",              # "" means empty ground
	"tilled": false,            # turned over, ready to take a seed
	"planted_at": 0,            # unix seconds, from GameClock
	"last_updated_at": 0,       # how far growth has been settled
	"growth_stage": 0,          # 0 .. STAGES - 1
	"growth_progress": 0.0,     # 0.0 .. 1.0 within the current stage
	"water_level": 1.0,         # 0.0 .. 1.0; at 0 growth waits, it never dies
	"care_event": "",           # "" | "thirsty" | "weeds" | "pests"
	"care_completed": false,
	"ready_to_harvest": false,
}


static func fresh_plot(index: int) -> Dictionary:
	var plot := PLOT.duplicate(true)
	plot["plot_id"] = "plot_%d" % (index + 1)
	return plot


## A garden nobody has planted in yet: four turned-nothing patches and an empty
## barn. Written into every new save, so a child who has never opened the
## garden still has one waiting rather than a null to be handled everywhere.
static func default_farm() -> Dictionary:
	var plots: Array = []
	for i in range(PLOT_COUNT):
		plots.append(fresh_plot(i))
	return {
		"farm_level": 1,
		"plot_count": PLOT_COUNT,
		"plots": plots,
		"warehouse": {},              # crop_id -> how many are in the barn
		"unlocked_crops": [],         # filled by the migration from crops.json
		"unlocked_recipes": [],
		"decorations": [],
		"completed_missions": [],
		"npc_friendship": {},         # npc_id -> a small number that only rises
		# The two clock anchors. last_seen_at is where growth was settled to;
		# clock_high_water is the furthest the wall clock has ever been seen to
		# reach, which is how a date dragged backwards is noticed at all.
		"last_seen_at": 0,
		"clock_high_water": 0,
		"opened": false,              # the one-shot migration flag
	}


static func default_orders() -> Dictionary:
	# `delivered` is the whole of the "an order pays once" rule: an id in this
	# list has been paid for and can never be paid for again, however many
	# times the button is pressed or the clock is moved.
	return {"active": [], "delivered": []}


## Put one plot back into a shape the rest of the code can rely on.
##
## Missing fields get their default. Fields of the wrong TYPE get their default
## too -- with one exception, which is the same exception SaveManager makes and
## for the same reason: JSON has a single number type, so an int written to
## disk comes back as a float, and treating that as damage would reset a
## planted_at to zero and un-plant the crop.
static func normalise_plot(raw: Variant, index: int = 0) -> Dictionary:
	var plot := fresh_plot(index)
	if not raw is Dictionary:
		return plot
	var given: Dictionary = raw
	for key in plot.keys():
		if not given.has(key):
			continue
		if SaveManager.same_shape(given[key], plot[key]):
			plot[key] = given[key]
	# A plot with no id is a plot nothing can refer to.
	if str(plot["plot_id"]) == "":
		plot["plot_id"] = "plot_%d" % (index + 1)
	return plot


## Put the whole garden back into shape: the top-level keys through the same
## two-level rules SaveManager uses, and every plot through normalise_plot.
##
## Also fixes the count: if plot_count says four and there are three plots on
## disk (an interrupted write, a hand-edited file), the fourth is grown back
## empty rather than leaving an index that crashes on read.
static func normalise_farm(raw: Variant) -> Dictionary:
	var farm := default_farm()
	if not raw is Dictionary:
		return farm
	var given: Dictionary = raw
	for key in farm.keys():
		if key == "plots":
			continue
		if given.has(key) and SaveManager.same_shape(given[key], farm[key]):
			farm[key] = given[key]

	var wanted: int = maxi(int(farm["plot_count"]), PLOT_COUNT)
	farm["plot_count"] = wanted
	var incoming: Array = given.get("plots", []) if given.get("plots") is Array else []
	var plots: Array = []
	for i in range(wanted):
		plots.append(normalise_plot(incoming[i] if i < incoming.size() else null, i))
	farm["plots"] = plots
	return farm
