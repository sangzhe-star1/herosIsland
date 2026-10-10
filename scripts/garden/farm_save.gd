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

## How many patches of earth a garden has to start with.
##
## Four became six when the garden turned into a farm, and this ONE number is
## the whole of that migration. That is not luck: normalise_farm() below grows
## the plot list to maxi(plot_count, PLOT_COUNT), so a save written when it was
## four comes back with its four beds byte for byte and two fresh ones after
## them. Later expansions raise the SAVE's own plot_count instead, and the same
## maxi() is why that number can never shrink and take a planted bed with it.
const PLOT_COUNT := 6

## How many crops the barn holds before the rest goes into the basket by the
## door. A number, not a feeling: the six starting beds yield at most 4 each,
## so a barn that is emptied once per full sweep never fills, and a child who
## never delivers anything meets the basket after about two sweeps. Raised to
## a bigger number by the first upgrade, which is earned and is never bought
## with anything but coins he grew himself. The upgrade itself arrives with the
## market and the seed shop (docs/FARM_WORLD_PLAN.md, 阶段 3); this is only the
## ceiling it starts at, and the field on the farm that remembers it.
const WAREHOUSE_START := 40
## What the one upgrade raises it to. Bought once with coins and the three
## planks the three friends left; farm_undo_controller owns the purchase and
## refund, this owns the roof.
const WAREHOUSE_UPGRADED := 60

## Five stages, from seed to ripe. The child watches a shape change four times;
## fewer and nothing seems to happen, more and the middle ones look identical.
const STAGES := 5


## WHAT A PATCH OF EARTH IS DOING, AS ONE WORD
##
## This used to be three booleans -- tilled, care_event, ready_to_harvest --
## and "which of the eight combinations are legal" lived in the head of
## whoever was reading. Six of the eight were nonsense (ripe but not tilled,
## carrying weeds with nothing planted), nothing rejected them, and a save
## with one in it would have drawn a plot that could not be tapped.
##
## So there is one word now, and the booleans are gone rather than
## duplicated. A seventh field that can disagree with the other six is not a
## state machine, it is a seventh way to be wrong.
const EMPTY := "EMPTY"          # grass. Wants turning over.
const TILLED := "TILLED"        # turned earth. Wants a seed.
const SEEDED := "SEEDED"        # a seed is in, nothing showing yet
const GROWING := "GROWING"      # something is coming up
const NEEDS_CARE := "NEEDS_CARE"  # stopped, waiting for water or weeding
const READY := "READY"          # ripe. Wants picking.

## Every state that can be written down. HARVESTING is deliberately NOT here:
## it lasts as long as an animation, and a state that only exists while the
## screen is open has no business on disk -- a tablet closed mid-animation
## would come back holding a plot stuck in it forever. The screen keeps that
## one in memory, which is where the "cannot tap during the harvest" rule
## lives; see garden_screen.gd.
const STATES := [EMPTY, TILLED, SEEDED, GROWING, NEEDS_CARE, READY]

## The states that mean something is planted. Used by the load-time check
## that throws out a plot claiming to be ripe with bare earth under it.
const PLANTED_STATES := [SEEDED, GROWING, NEEDS_CARE, READY]

## One patch of earth. Every field here has to survive a JSON round trip, so
## there are no nested dictionaries and no nulls.
const PLOT := {
	"plot_id": "",
	"state": EMPTY,
	"crop_id": "",              # "" means nothing planted
	# Which planting this is. Rises by one every time a seed goes in and NEVER
	# resets, including across a harvest -- it is half of the transaction id
	# that stops one crop being paid for twice (see garden_screen._harvest).
	"plant_cycle_id": 0,
	"planted_at": 0,            # unix seconds, from GameClock
	"last_updated_at": 0,       # how far growth has been settled
	"growth_stage": 0,          # 0 .. STAGES - 1
	"growth_progress": 0.0,     # 0.0 .. 1.0 within the current stage
	"water_level": 1.0,         # 0.0 .. 1.0; at 0 growth waits, it never dies
	"care_event": "",           # "" | "thirsty" | "weeds"
	"care_completed": false,
	# Seconds this ONE planting takes from seed to ripe, instead of the crop's
	# own growth_seconds. 0 means "use the crop's time", which is every plot in
	# the game except one: the carrot planted during the first lesson, which
	# has to finish while the child is still standing in front of it.
	#
	# It lives on the plot and not in crops.json deliberately. Speeding the
	# crop up would leave every later carrot fast too, for ever -- a lesson is
	# not allowed to change the game it is teaching. The harvest clears it,
	# because a picked bed is reset from fresh_plot().
	"growth_override_seconds": 0,
	# A better-than-usual crop, shown with a soft glow and worth more. Nothing
	# SETS it yet -- what earns it is being decided with the market -- but a
	# field on a plot costs nothing to add later and costs a whole state to add
	# wrongly, and normalise_plot() below hands it to every old save for free.
	"golden": false,
}


static func fresh_plot(index: int) -> Dictionary:
	var plot := PLOT.duplicate(true)
	plot["plot_id"] = "plot_%d" % (index + 1)
	return plot


## Is anything planted here?
static func is_planted(plot: Dictionary) -> bool:
	return str(plot.get("state", EMPTY)) in PLANTED_STATES


static func is_ready(plot: Dictionary) -> bool:
	return str(plot.get("state", EMPTY)) == READY


## Has this earth been turned? True for everything except bare grass -- a plot
## with a crop in it was necessarily tilled first.
static func is_tilled(plot: Dictionary) -> bool:
	return str(plot.get("state", EMPTY)) != EMPTY


## A garden nobody has planted in yet: four turned-nothing patches and an empty
## barn. Written into every new save, so a child who has never opened the
## garden still has one waiting rather than a null to be handled everywhere.
static func default_farm() -> Dictionary:
	var plots: Array = []
	for i in range(PLOT_COUNT):
		plots.append(fresh_plot(i))
	return {
		"farm_level": 1,
		# The farm's own experience, and the ONLY source of farm_level: the
		# level is computed from this number every time it is asked
		# (farm_level_manager.gd), and the field above is a copy kept for the
		# merge, which takes the higher of two tablets' worth of each. It has
		# nothing to do with the child's own profile xp, on purpose -- the
		# farm growing up and the child growing up are different stories.
		"farm_xp": 0,
		"plot_count": PLOT_COUNT,
		"plots": plots,
		"warehouse": {},              # crop_id -> how many are in the barn
		# How many the barn holds. On the farm and not in a constant because it
		# is upgraded, and an upgrade that is not on disk is an upgrade he loses
		# every time he closes the lid.
		"warehouse_cap": WAREHOUSE_START,
		# What did not fit, sitting in a basket by the barn door. crop_id -> how
		# many. NOT a second warehouse: nothing is spent from here and nothing is
		# delivered from here -- it empties itself back into the barn the moment
		# there is room (see InventoryManager.tip_basket_in).
		#
		# It exists so that "the barn is full" is never an answer to "what
		# happened to the carrots I just picked". A six-year-old who watches four
		# strawberries vanish has been robbed by the game, and he will not read
		# the message explaining it.
		"harvest_basket": {},
		"unlocked_crops": [],         # filled by the migration from crops.json
		"unlocked_recipes": [],
		"completed_missions": [],
		"npc_friendship": {},         # npc_id -> a small number that only rises
		# The two clock anchors. last_seen_at is where growth was settled to;
		# clock_high_water is the furthest the wall clock has ever been seen to
		# reach, which is how a date dragged backwards is noticed at all.
		"last_seen_at": 0,
		"clock_high_water": 0,
		"opened": false,              # the one-shot migration flag
		# The first-planting lesson, run once and never again.
		"tutorial_completed": false,
		# The one other thing that is ever taught: the market box, pointed at
		# once, the first time the barn gets close to full. Same shape as the
		# lesson flag -- "has this ever happened", never a schedule.
		"market_taught": false,
		# When he last stood in the garden. Distinct from last_seen_at, which is
		# where GROWTH has been settled to: growth is settled by anything that
		# loads the save, including a level, and "when did he last actually
		# visit" is a different question that the entrance badge asks.
		"last_farm_visit_at": 0,
		# Harvest transaction ids already paid for. Bounded on purpose -- see
		# remember_paid() for why a bound cannot let a harvest be paid twice.
		"paid_harvests": [],
		"coop": {"fed_at": 0, "eggs": 0},   # the hens: when last fed, eggs waiting
		"mill": {"started_at": 0, "done": 0},  # the windmill: grinding since, flour waiting
		"cow_shed": {"fed_at": 0, "ready": 0},  # the cow: when last fed, milk waiting
		"beehive": {"fed_at": 0, "ready": 0},  # the bees: when last fed, honey waiting
		# The market's receipts. The counter only rises, so every sale in the
		# history of a save has its own id -- the same shape as plant_cycle_id,
		# because it is solving the same problem: a second press of the same
		# button must present an id that has already been seen.
		"sale_receipt_id": 0,
		"paid_sales": [],
		# The neighbours, as the child's save knows them. Three facts per bear
		# and not one more: which share-cycle he picked in, whether he still
		# owes the watering he promised, and when the bear last dropped by his
		# farm. Everything else about the bear's farm is COMPUTED from the
		# clock -- storing a state that can be computed is storing a thing
		# that can disagree.
		"npc": default_npc(),
		# What the visitors did, newest first, at most VISIT_LOG_KEPT entries.
		# Every entry is something GIVEN -- nothing in this list can be a
		# loss, and farm_visit_texts.json is checked for loss-words before it
		# ever ships.
		"visit_log": [],
		"visit_log_unread": false,
		# Today's little jobs: the date, the tally, and the claims. Lived
		# here, inside the whitelist, or normalise_farm would wipe them on
		# every load -- the first cut stored them and watched a same-day
		# reopen hand out the day's coins a second time.
		"dailies": {"date": "", "progress": {}, "claimed": []},
		# Morning dew date stamp: waters every bed once each morning.
		"last_dew_date": "",
		"fed_visitor_date": "",  # the day the visitor at the board last got a dish
		# Pond fishing: total fish caught and last fish timestamp.
		"fish_caught_total": 0,
		"last_fish_at": 0,
		# Dog growth: fetch count, unlocked tricks list, and daily dig date.
		"dog_fetches": 0,
		"dog_tricks": [],
		"last_dog_dig_date": "",
		# Bear return visit: true when child helped bear, triggers reciprocal visit.
		"bear_return_visit_pending": false,
		# Level 8 Master Farmer milestone:
		"master_farmer_achieved": false,
		"last_well_wish_date": "",
	}


## How many paid-harvest ids are kept.
##
## A bounded ledger sounds like a hole and is not one. A transaction id is
## "<plot_id>_<plant_cycle_id>", and plant_cycle_id rises by one on every
## planting and never resets -- so an id that falls off the end can never be
## presented again, because the plot it belongs to has moved on and will never
## return to that cycle. The ledger only has to cover the window between paying
## and the save landing, which is one frame, not one childhood.
const PAID_LEDGER_KEPT := 64


## Record a harvest transaction, trimming the oldest away.
static func remember_paid(farm: Dictionary, key: String) -> void:
	var paid: Array = farm.get("paid_harvests", [])
	if not paid is Array:
		paid = []
	if key in paid:
		return
	paid.append(key)
	while paid.size() > PAID_LEDGER_KEPT:
		paid.pop_front()
	farm["paid_harvests"] = paid


## Record a sale, trimming the oldest away. Bounded for the same reason
## paid_harvests is: the receipt counter never repeats, so an id that falls
## off the end can never be presented again, and the ledger only has to cover
## the window between paying and the save landing.
static func remember_paid_sale(farm: Dictionary, key: String) -> void:
	var paid: Array = farm.get("paid_sales", [])
	if not paid is Array:
		paid = []
	if key in paid:
		return
	paid.append(key)
	while paid.size() > PAID_LEDGER_KEPT:
		paid.pop_front()
	farm["paid_sales"] = paid


## How many visitor entries are kept. Ten is a story, forty is a chore.
const VISIT_LOG_KEPT := 10


static func default_npc() -> Dictionary:
	return {"bear": {"last_share_cycle": -1, "help_owed": false,
		"last_visit_at": 0,
		# 悄悄摘一颗：摘过哪个生长周期、小熊还欠着哪一次"什么都没说，
		# 多分你一颗"。normalise_npc 会给旧存档补上这两个默认值。
		"last_sneak_cycle": -1, "sneak_owed": false},
		"rabbit": {"last_share_cycle": -1, "help_owed": false},
		"puppy": {"last_share_cycle": -1, "help_owed": false}}


## The npc block sits three levels deep, which is one past what _migrate can
## reach -- the same hole normalise_plot() exists for, patched the same way:
## every read passes through here and missing keys get their defaults.
static func normalise_npc(raw: Variant) -> Dictionary:
	var out := default_npc()
	if not raw is Dictionary:
		return out
	for npc_id in out.keys():
		var given: Variant = raw.get(npc_id)
		if not given is Dictionary:
			continue
		for key in out[npc_id].keys():
			if given.has(key) and SaveManager.same_shape(given[key], out[npc_id][key]):
				out[npc_id][key] = given[key]
	return out


## Put a visitor's entry at the top and trim the tale to length.
static func remember_visit(farm: Dictionary, entry: Dictionary) -> void:
	var log: Array = farm.get("visit_log", [])
	if not log is Array:
		log = []
	log.push_front(entry)
	while log.size() > VISIT_LOG_KEPT:
		log.pop_back()
	farm["visit_log"] = log
	farm["visit_log_unread"] = true


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

	# A save written before `state` existed. Everything needed to work out what
	# this plot was doing is still on disk in the three booleans it used, so
	# read them once, here, and never again.
	if not given.has("state"):
		plot["state"] = _state_from_the_old_booleans(given, plot)

	return _repair(plot)


## The old shape, read once on the way past.
##
## Order matters and is the same order the screen used to ask in: ripe beats
## everything, then whatever the plot is waiting for, then "there is a crop",
## then "the earth is turned".
static func _state_from_the_old_booleans(given: Dictionary,
		plot: Dictionary) -> String:
	var has_crop: bool = str(plot.get("crop_id", "")) != ""
	if bool(given.get("ready_to_harvest", false)) and has_crop:
		return READY
	if has_crop and str(plot.get("care_event", "")) != "":
		return NEEDS_CARE
	if has_crop:
		# Stage 0 with nothing showing yet is still a seed in the ground.
		if int(plot.get("growth_stage", 0)) <= 0 \
				and float(plot.get("growth_progress", 0.0)) <= 0.0:
			return SEEDED
		return GROWING
	if bool(given.get("tilled", false)):
		return TILLED
	return EMPTY


## Everything the brief asks to be checked on the way in, in one place.
##
## Every branch REPAIRS rather than rejects. A hand-edited file, an interrupted
## write or a crop retired from the catalogue between two versions must never
## be the reason a child's whole save will not open -- the worst outcome
## allowed here is one patch of earth back to grass.
static func _repair(plot: Dictionary) -> Dictionary:
	var state := str(plot.get("state", EMPTY))
	if not state in STATES:
		state = EMPTY                       # a word nothing answers to

	var crop_id := str(plot.get("crop_id", ""))
	# A crop the catalogue has never heard of. Not an error -- a crop retired
	# between two versions looks exactly like this -- but nothing can be grown
	# or harvested from it, so the earth goes back to being earth.
	if crop_id != "" and GameData.get_crop(crop_id).is_empty():
		crop_id = ""

	# State and crop have to agree. Ripe with nothing planted, or bare earth
	# holding a carrot, are both nonsense however they got written.
	if crop_id == "" and state in PLANTED_STATES:
		state = TILLED                      # the earth is turned; the crop is not there
	elif crop_id != "" and not state in PLANTED_STATES:
		state = GROWING                     # something IS planted; let it grow

	plot["state"] = state
	plot["crop_id"] = crop_id

	# Numbers that are outside what they mean. growth_stage is allowed to reach
	# STAGES - 1 while growing; READY is carried by the state, not by an index
	# one past the end.
	plot["growth_stage"] = clampi(int(plot.get("growth_stage", 0)), 0, STAGES)
	plot["growth_progress"] = clampf(float(plot.get("growth_progress", 0.0)), 0.0, 1.0)
	plot["water_level"] = clampf(float(plot.get("water_level", 1.0)), 0.0, 1.0)
	plot["plant_cycle_id"] = maxi(int(plot.get("plant_cycle_id", 0)), 0)

	# A stamp from before the epoch, or from a clock that was wrong when it was
	# written. Zero means "never", which every reader already handles.
	plot["planted_at"] = maxi(int(plot.get("planted_at", 0)), 0)
	plot["last_updated_at"] = maxi(int(plot.get("last_updated_at", 0)), 0)

	# Nothing is waiting for care on bare earth, and bare earth is not golden.
	if not state in PLANTED_STATES:
		plot["care_event"] = ""
		plot["care_completed"] = false
		plot["golden"] = false
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

	farm["npc"] = normalise_npc(farm.get("npc"))
	var wanted: int = maxi(int(farm["plot_count"]), PLOT_COUNT)
	farm["plot_count"] = wanted
	var incoming: Array = given.get("plots", []) if given.get("plots") is Array else []
	var plots: Array = []
	for i in range(wanted):
		plots.append(normalise_plot(incoming[i] if i < incoming.size() else null, i))
	farm["plots"] = plots
	return farm
