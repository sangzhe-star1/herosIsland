extends RefCounted
## What happened to a plot while nobody was watching.
##
##     const Growth := preload("res://scripts/garden/offline_growth.gd")
##
## Stateless by design. advance() -- where all the arithmetic lives -- takes a
## plot, a crop and a number of seconds and hands back a new plot, touching no
## save, no clock and no scene. That is not tidiness for its own sake: four of
## the garden's acceptance checks are about time nobody can sit through (a
## night, a date dragged backwards, a year skipped forward), and the only way
## to check those is to be able to hand the arithmetic any number of seconds
## and read the answer.
##
## settle() is the one function that reaches outside, for the clock and the
## crop catalogue. It is kept thin on purpose, so that what it does can be read
## in one screen and everything hard sits in advance() where it can be tested
## with numbers instead of with a Tuesday.
##
##
## WHY GROWTH IS COMPUTED AND NOT COUNTED
##
## Nothing here runs on a timer. A plot stores when it was planted and how far
## it has been settled, and growth is the difference worked out on the way in.
## That is what makes "the carrot keeps growing while he plays a level" true
## without a single frame of the garden being loaded -- there is nothing to
## keep running, because nothing was ever running.
##
##
## THE TWO RULES THAT ARE NOT NEGOTIABLE
##
## A crop never dies. Water runs out and growth WAITS; it does not rot, wilt
## past saving, or need to be dug up and started again. The worst state a plot
## can be found in after a fortnight away is "thirsty, still exactly where you
## left it" -- because the child who comes back after a fortnight is six, and
## did not choose to be away.
##
## Ripe is the ceiling. Once a crop is ready to harvest it stops, whatever the
## clock says afterwards. Skipping the tablet's date forward cannot turn one
## planting into two harvests, because there is no second harvest to reach --
## the only way to get another is to plant again.

const Farm := preload("res://scripts/garden/farm_save.gd")

## Water falls from 1.0 to 0.0 over the crop's thirst_seconds. At 0 growth
## waits. It is a pause, not a penalty: nothing is lost, and one watering
## anywhere in the next fortnight picks up exactly where it stopped.
const DRY := 0.0
const FULL := 1.0

## What a plot is waiting for, when it is waiting.
const CARE_NONE := ""
const CARE_THIRSTY := "thirsty"


## Move one plot forward by `seconds`, and hand back what it became.
##
## `seconds` is expected to have already been through GameClock.elapsed_since(),
## which is where "never negative" and "never more than one night" are enforced.
## This function trusts it and clamps anyway, because a growth function that
## can run backwards given a bad number is a growth function that will.
static func advance(plot: Dictionary, crop: Dictionary, seconds: int) -> Dictionary:
	var out: Dictionary = plot.duplicate(true)
	if seconds <= 0:
		return out
	if str(out.get("crop_id", "")) == "":
		return out                      # bare earth has nowhere to get to
	if bool(out.get("ready_to_harvest", false)):
		return out                      # ripe is the ceiling

	var stages: Array = crop.get("stage_seconds", [])
	if stages.is_empty():
		# A crop_id nothing in the catalogue answers to. Sit still rather than
		# finish instantly: a retired crop should look like a plant that has
		# stopped, not like a harvest waiting to be collected.
		return out

	var thirst := float(crop.get("thirst_seconds", 0))
	var water := float(out.get("water_level", FULL))
	var remaining := seconds

	# Walk the absence in two pieces: the part with water in it, which grows,
	# and the part after the water ran out, which waits.
	var watered_seconds := remaining
	if thirst > 0.0:
		var seconds_of_water := int(round(water * thirst))
		watered_seconds = mini(remaining, seconds_of_water)
		water = maxf(DRY, water - float(remaining) / thirst)
	out["water_level"] = water

	var stage := int(out.get("growth_stage", 0))
	var progress := float(out.get("growth_progress", 0.0))
	var left := watered_seconds
	while left > 0 and stage < stages.size():
		var this_stage := int(stages[stage])
		if this_stage <= 0:
			stage += 1
			progress = 0.0
			continue
		var needed := int(round(float(this_stage) * (1.0 - progress)))
		if left < needed:
			progress += float(left) / float(this_stage)
			left = 0
		else:
			left -= needed
			stage += 1
			progress = 0.0
	out["growth_stage"] = mini(stage, stages.size())
	out["growth_progress"] = clampf(progress, 0.0, 1.0)

	if out["growth_stage"] >= stages.size():
		out["growth_stage"] = stages.size()
		out["growth_progress"] = 0.0
		out["ready_to_harvest"] = true
		out["care_event"] = CARE_NONE
	elif water <= DRY:
		# Thirsty, and saying so. This is the worst a plot can be.
		out["care_event"] = CARE_THIRSTY
		out["care_completed"] = false
	elif str(out.get("care_event", "")) == CARE_THIRSTY:
		out["care_event"] = CARE_NONE

	return out


## Settle a whole garden up to `now`, and hand back the garden it became.
##
## This is the only place the two clock anchors are read and written, which is
## also the only place a clock dragged backwards has to be noticed.
##
##   * forwards  -- each plot advances by the elapsed seconds, already capped
##                  at one night's worth by GameClock
##   * backwards -- nothing advances and nothing retreats. If the wall clock
##                  has gone back further than a correction can explain, the
##                  anchors are moved to now: growing resumes immediately from
##                  where it stopped rather than the garden sitting frozen
##                  until the calendar catches up again, and no progress is
##                  handed out for the trip.
static func settle(farm: Dictionary, now: int) -> Dictionary:
	var out: Dictionary = farm.duplicate(true)
	var last := int(out.get("last_seen_at", 0))
	var high := int(out.get("clock_high_water", 0))

	if last <= 0:
		# First time anyone has looked. Anchor and grow nothing: an unset
		# stamp is not fifty-six years of absence.
		out["last_seen_at"] = now
		out["clock_high_water"] = maxi(high, now)
		return out

	# A clock dragged backwards needs no special case here, and it used to have
	# one. GameClock.elapsed_since() already answers zero for it -- growth of
	# zero, never a negative -- and re-anchoring falls out of the two lines at
	# the end that set last_seen_at to now and keep clock_high_water at its
	# high mark. The special case was written first, and deleting it and
	# watching the garden probe still pass is how it was found to do nothing.
	# One rule, in one place, with clock_probe as its test.
	var elapsed: int = GameClock.elapsed_since(last)
	var plots: Array = out.get("plots", [])
	for i in range(plots.size()):
		var plot: Dictionary = Farm.normalise_plot(plots[i], i)
		var crop: Dictionary = GameData.get_crop(str(plot.get("crop_id", "")))
		plot = advance(plot, crop, elapsed)
		plot["last_updated_at"] = now
		plots[i] = plot
	out["plots"] = plots
	out["last_seen_at"] = now
	out["clock_high_water"] = maxi(high, now)
	return out


## How far along a plot is overall, 0.0 to 1.0. For the ring drawn around it --
## a six-year-old reads a ring filling up, not "stage 3 of 5".
static func fraction_done(plot: Dictionary, crop: Dictionary) -> float:
	if bool(plot.get("ready_to_harvest", false)):
		return 1.0
	var stages: Array = crop.get("stage_seconds", [])
	if stages.is_empty():
		return 0.0
	var total := 0.0
	var done := 0.0
	var stage := int(plot.get("growth_stage", 0))
	for i in range(stages.size()):
		var seconds := float(stages[i])
		total += seconds
		if i < stage:
			done += seconds
		elif i == stage:
			done += seconds * clampf(float(plot.get("growth_progress", 0.0)), 0.0, 1.0)
	if total <= 0.0:
		return 0.0
	return clampf(done / total, 0.0, 1.0)


## Water a plot: back to full, and growing again if it had stopped.
static func water(plot: Dictionary) -> Dictionary:
	var out: Dictionary = plot.duplicate(true)
	out["water_level"] = FULL
	if str(out.get("care_event", "")) == CARE_THIRSTY:
		out["care_event"] = CARE_NONE
		out["care_completed"] = true
	return out
