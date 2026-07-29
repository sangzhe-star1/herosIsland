extends RefCounted
## The bear's farm, computed rather than stored, and the four promises around
## the one strawberry he shares.
##
##     const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
##
## WHY THE BEAR'S FARM IS ARITHMETIC
##
## The bear has no save file. What his beds look like is a function of the
## clock: each one cycles through its crop's real growth on a fixed offset, so
## the farm is alive -- come back after lunch and things have moved -- while
## nothing about it can be lost, corrupted, or need migrating. The three facts
## that ARE stored (in farm.npc.bear) are the three that concern the CHILD:
## which share-cycle he picked in, whether he still owes the watering, and
## when the bear last dropped by.
##
## THE SHARE CYCLE IS A GROWTH CLOCK, NOT A CALENDAR
##
## "One per day, resets at midnight" is a login bonus wearing a bow, and login
## bonuses are on this game's forbidden list. Instead the shared strawberry
## regrows on the strawberry's own real growth time, the same arithmetic as
## the child's own beds: cycle = now / growth_seconds. Miss a week and exactly
## one is waiting -- ripe things freeze here, nothing accumulates, nothing is
## forfeited, and there is no midnight to race.
##
## THE BEAR LOSES NOTHING, EVER
##
## There is no ledger of the bear's produce because there is no produce: the
## shared strawberry is EXTRA, conjured by the share star, and the rest of his
## beds are pictures of a farm being looked after. Nothing the child does here
## can cost the bear anything -- which is the whole lesson.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")

## How long after a visit the bear next drops by the child's farm. His own
## pace: the share crop's growth time, so the two rhythms feel like one
## friendship rather than two counters.
static func visit_period() -> int:
	return share_period()


static func share_period() -> int:
	var farm_def: Dictionary = GameData.get_npc_farm("bear")
	var crop_id := str(farm_def.get("share_crop", "strawberry"))
	return maxi(600, int(GameData.crop_total_seconds(crop_id)))


static func current_cycle(now: int) -> int:
	return maxi(0, now) / share_period()


static func bear_state() -> Dictionary:
	return Farm.normalise_npc(
		SaveManager.data.get("farm", {}).get("npc")).get("bear", {})


## May the shared strawberry be picked right now?
##
## Two conditions, and the second is the gentle enforcement of the promise:
## a NEW cycle must have grown it back, and the last visit's watering must be
## done. A child who picked and ran keeps the strawberry -- nothing is ever
## taken back -- but the next one waits until the kindness is returned. That
## is the whole of "must help": a door that waits, never a hand that takes.
static func can_pick(now: int) -> bool:
	var bear := bear_state()
	if bool(bear.get("help_owed", false)):
		return false
	return current_cycle(now) > int(bear.get("last_share_cycle", -1))


static func record_pick(now: int) -> void:
	var farm: Dictionary = SaveManager.data["farm"]
	var npc: Dictionary = Farm.normalise_npc(farm.get("npc"))
	npc["bear"]["last_share_cycle"] = current_cycle(now)
	npc["bear"]["help_owed"] = true
	farm["npc"] = npc


## The watering is done: the promise clears and the friendship grows by one.
## The flag itself is the idempotence -- a second call finds nothing owed and
## changes nothing, however it arrives.
static func record_help() -> bool:
	var farm: Dictionary = SaveManager.data["farm"]
	var npc: Dictionary = Farm.normalise_npc(farm.get("npc"))
	if not bool(npc["bear"]["help_owed"]):
		return false
	npc["bear"]["help_owed"] = false
	farm["npc"] = npc
	var friends: Dictionary = farm.get("npc_friendship", {})
	friends["bear"] = int(friends.get("bear", 0)) + 1
	farm["npc_friendship"] = friends
	return true


static func friendship() -> int:
	return int(SaveManager.data.get("farm", {})
		.get("npc_friendship", {}).get("bear", 0))


## What the bear's beds look like at `now`: a list of plot-shaped dictionaries
## PlotView can draw, plus two flags of our own (share / help_target).
##
## Deterministic to the second. Two children with the same clock see the same
## farm; the same child sees it move between visits. Nothing here touches the
## save.
static func bear_beds(now: int) -> Array:
	var farm_def: Dictionary = GameData.get_npc_farm("bear")
	var out: Array = []
	var beds: Array = farm_def.get("beds", [])
	for i in range(beds.size()):
		var def: Dictionary = beds[i]
		var crop_id := str(def.get("crop", "carrot"))
		var total := maxi(1, int(GameData.crop_total_seconds(crop_id)))
		var plot: Dictionary = Farm.fresh_plot(i)
		plot["crop_id"] = crop_id
		plot["share"] = bool(def.get("share", false))
		plot["help_target"] = bool(def.get("thirsty", false))

		if plot["share"]:
			if can_pick(now):
				plot["state"] = Farm.READY
				plot["growth_stage"] = Farm.STAGES - 1
			else:
				# Growing back: however far the current cycle has run.
				_grow_to(plot, crop_id,
					float(now % share_period()) / float(share_period()))
		elif plot["help_target"]:
			plot["state"] = Farm.NEEDS_CARE
			plot["care_event"] = Growth.CARE_THIRSTY
			plot["water_level"] = 0.0
			plot["growth_stage"] = 2
		else:
			# An ordinary bed, part-way through its crop on a fixed offset, so
			# the farm reads as looked-after rather than staged.
			var phase := clampf(float(def.get("phase", 0.5)), 0.02, 0.95)
			_grow_to(plot, crop_id,
				fmod(phase + float(now) / float(total * 4), 0.96))
		out.append(plot)
	return out


static func _grow_to(plot: Dictionary, crop_id: String, fraction: float) -> void:
	var crop: Dictionary = GameData.get_crop(crop_id)
	var total := maxi(1, int(GameData.crop_total_seconds(crop_id)))
	plot["state"] = Farm.GROWING
	var grown: Dictionary = Growth.advance(plot, crop,
		int(clampf(fraction, 0.0, 0.95) * float(total)))
	for key in grown.keys():
		plot[key] = grown[key]
	# The bear's beds never nag: whatever jobs the arithmetic raised on the
	# way, the bear has already seen to them.
	plot["care_event"] = ""
	if str(plot.get("state", "")) == Farm.NEEDS_CARE:
		plot["state"] = Farm.GROWING


## The bear drops by, if enough of his own rhythm has passed. Returns the log
## entry he left, or {} for "not today".
##
## Runs when the CHILD walks into his farm -- a visit nobody is there to find
## is not a visit. Waters every thirsty bed for real (watering is a gift;
## gifts are real), leaves one friendship star, writes one entry. The stamp
## `last_visit_at` is the idempotence: however many times this is asked in a
## row, the period has passed once.
static func maybe_visit(now: int) -> Dictionary:
	if friendship() < 1:
		return {}
	var farm: Dictionary = SaveManager.data["farm"]
	var npc: Dictionary = Farm.normalise_npc(farm.get("npc"))
	var last := int(npc["bear"]["last_visit_at"])
	if last > 0 and now - last < visit_period():
		return {}
	if last == 0:
		# The first visit comes one period after the friendship begins, not
		# the instant it does -- he walks home first.
		npc["bear"]["last_visit_at"] = now
		farm["npc"] = npc
		return {}

	var watered := 0
	var plots: Array = farm.get("plots", [])
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		if str(plot.get("care_event", "")) == Growth.CARE_THIRSTY:
			plots[i] = Growth.water(plot)
			watered += 1
	farm["plots"] = plots

	var friends: Dictionary = farm.get("npc_friendship", {})
	friends["bear"] = int(friends.get("bear", 0)) + 1
	farm["npc_friendship"] = friends

	npc["bear"]["last_visit_at"] = now
	farm["npc"] = npc

	var entry := {"who": "bear", "watered": watered, "star": 1, "at": now}
	Farm.remember_visit(farm, entry)
	return entry
