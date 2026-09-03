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
const CARE_WEEDS := "weeds"
## A caterpillar on the leaf. Nothing PRODUCES this yet -- the farm's third job
## arrives with the tool bar it is shooed away with -- but the bed knows how to
## draw it and a tap knows how to clear it, and the probe drives both. A state
## the screen cannot show is a state that ships broken the day something starts
## setting it, which is how this project has shipped several.
const CARE_BUG := "bug"

## Where the weeds stage comes from when a crop's data does not say.
##
## Deliberately a fixed stage rather than a chance. Random weeds would mean two
## children with the same garden see different work, and "why does mine have
## weeds and his does not" is not a question this game wants to raise -- it is
## also the first step onto the ladder the shop is forbidden to climb. A crop
## grows weeds once, he pulls them once, and he learns that plants need looking
## after because it happens to him every single time.
const WEEDS_AT_STAGE := 2


## WHICH CROP ASKS FOR WHAT
##
## `care_event_types` in crops.json. Each crop raises exactly ONE kind of job
## per planting, which is the brief's rule and is also as much as a six-year-old
## should have to hold at once:
##
##   ["water"]   the plant gets thirsty; thirst_seconds says when
##   ["weeds"]   weeds come up at care_event_stage, and thirst_seconds is 0, so
##               the plant never ALSO gets thirsty -- two jobs on one plot is
##               two things to work out and one of them gets missed
##
## A crop with no list at all keeps the old behaviour, thirst and weeds both,
## because a data file that forgot a field should not quietly turn a job off.
static func wants(crop: Dictionary, kind: String) -> bool:
	var types: Array = crop.get("care_event_types", [])
	if types.is_empty():
		return true
	return kind in types


## The stage weeds come up at for this crop.
static func weeds_stage(crop: Dictionary) -> int:
	return int(crop.get("care_event_stage", WEEDS_AT_STAGE))


## Which job comes up out of the GROUND for this crop -- weeds or a bug -- or
## "" for a crop whose only job is thirst.
##
## One word for both, because they are the same mechanism wearing different
## pictures: something appears at care_event_stage, growth stops there until a
## hand clears it, and it never comes back this planting. Thirst is the one
## that is different (it has a clock, not a stage), which is why it is not in
## here. First match wins; a crop listing two ground jobs is a data mistake,
## and tools_check refuses it before it can ship.
static func field_job(crop: Dictionary) -> String:
	var types: Array = crop.get("care_event_types", [])
	if CARE_WEEDS in types:
		return CARE_WEEDS
	if CARE_BUG in types:
		return CARE_BUG
	return ""


## The crop as THIS plot experiences it.
##
## One planting in the whole game runs on its own clock: the carrot a child
## puts in during the first lesson, which has to go from seed to ripe while he
## is still crouched over the bed. Every other plot uses the crop's real times.
##
## The whole crop is SCALED rather than its total swapped, and that matters.
## thirst_seconds sits two thirds of the way through every crop by design, so
## that each one needs watering exactly once; a six-second carrot has to get
## thirsty at four seconds or the lesson arrives at "give it a drink" with
## nothing to drink. Scaling keeps that relationship instead of restating it
## here, where it would quietly drift away from crops.json.
##
## Returns the crop untouched when there is no override, so every lookup can be
## wrapped in it without asking first.
static func crop_for(plot: Dictionary, crop: Dictionary) -> Dictionary:
	var override := int(plot.get("growth_override_seconds", 0))
	if override <= 0 or crop.is_empty():
		return crop
	var stages: Array = crop.get("stage_seconds", [])
	var total := 0.0
	for seconds in stages:
		total += float(seconds)
	if total <= 0.0:
		return crop
	var scale := float(override) / total
	var out: Dictionary = crop.duplicate(true)
	var scaled: Array = []
	for seconds in stages:
		# Never below one second. advance() skips a zero-length stage instantly,
		# which would drop a growth stage out of the lesson altogether and take
		# the picture of it with it -- the sprout he is supposed to watch.
		scaled.append(maxi(1, int(round(float(seconds) * scale))))
	out["stage_seconds"] = scaled
	var thirst := float(crop.get("thirst_seconds", 0))
	out["thirst_seconds"] = maxi(1, int(round(thirst * scale))) if thirst > 0.0 else 0
	return out


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
	if Farm.is_ready(out):
		return out                      # ripe is the ceiling

	var stages: Array = crop.get("stage_seconds", [])
	if stages.is_empty():
		# A crop_id nothing in the catalogue answers to. Sit still rather than
		# finish instantly: a retired crop should look like a plant that has
		# stopped, not like a harvest waiting to be collected.
		return out

	# Already stopped and waiting for a hand. Nothing advances -- not the growth,
	# not the water -- until the job is done.
	#
	# This is what NEEDS_CARE MEANS, and it did not use to. Weeds were once
	# cosmetic: they asked to be pulled and growth carried straight on past
	# them, so a plot could sit at "needs care" for a fortnight and ripen
	# anyway, and the badge was decoration. A job that can be ignored is not a
	# job a six-year-old will learn from.
	if str(out.get("care_event", CARE_NONE)) != CARE_NONE:
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

	var job_at := weeds_stage(crop)
	var job := field_job(crop)
	# The empty-list fallback: a data file that forgot the field keeps the old
	# behaviour, weeds and thirst both, because forgetting a field should not
	# quietly turn a job off.
	if job == "" and wants(crop, CARE_WEEDS):
		job = CARE_WEEDS
	var job_possible: bool = job != "" \
		and not bool(out.get("care_completed", false))

	var stage := int(out.get("growth_stage", 0))
	var progress := float(out.get("growth_progress", 0.0))
	var left := watered_seconds
	var stopped_by_job := false
	while left > 0 and stage < stages.size():
		# The ground job -- weeds or the caterpillar -- comes up the moment the
		# plant reaches its stage, and the walk STOPS there. Time after that
		# point is not banked: a fortnight away leaves the plot exactly where
		# the job found it, which is the "waiting for help" ceiling the brief
		# asks for and the reason a year of absence cannot ripen anything.
		if job_possible and stage >= job_at:
			stopped_by_job = true
			break
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
		out["state"] = Farm.READY
		out["care_event"] = CARE_NONE
	elif water <= DRY and wants(crop, CARE_THIRSTY):
		# Thirsty, and saying so. Water beats weeds when both are true: a plant
		# that is not growing at all is the more urgent of the two.
		out["care_event"] = CARE_THIRSTY
		out["care_completed"] = false
		out["state"] = Farm.NEEDS_CARE
	elif stopped_by_job:
		out["care_event"] = job
		out["state"] = Farm.NEEDS_CARE
	else:
		if str(out.get("care_event", "")) == CARE_THIRSTY:
			out["care_event"] = CARE_NONE
		# Something is showing above the soil now, so it has stopped being a
		# seed in the ground and started being a plant.
		out["state"] = Farm.GROWING

	return out


## Settle a whole garden up to `now`, and hand back the garden it became.
##
## This is the only place the garden clock anchors are read and written, which
## is also the only place a clock dragged backwards has to be noticed. The
## farm stamp says when the garden was last seen; every plot also keeps its own
## planting/update stamp, so a seed never inherits time from before it existed.
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
	var plots: Array = out.get("plots", [])
	for i in range(plots.size()):
		var plot: Dictionary = Farm.normalise_plot(plots[i], i)
		var crop: Dictionary = crop_for(plot,
			GameData.get_crop(str(plot.get("crop_id", ""))))
		# `last_seen_at` keeps a whole-farm visit from being counted twice. A
		# new seed or a just-completed care action is newer than that visit and
		# must become the local anchor instead.
		var plot_anchor := maxi(last, maxi(int(plot.get("planted_at", 0)),
			int(plot.get("last_updated_at", 0))))
		plot = advance(plot, crop, GameClock.elapsed_since(plot_anchor))
		plot["last_updated_at"] = now
		plots[i] = plot
	out["plots"] = plots
	out["last_seen_at"] = now
	out["clock_high_water"] = maxi(high, now)
	return out


## How far along a plot is overall, 0.0 to 1.0. For the ring drawn around it --
## a six-year-old reads a ring filling up, not "stage 3 of 5".
static func fraction_done(plot: Dictionary, crop: Dictionary) -> float:
	if Farm.is_ready(plot):
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
		# Back to growing -- unless weeds were the reason it stopped, in which
		# case there is still a job to do and the state stays where it is.
		if str(out.get("state", "")) == Farm.NEEDS_CARE:
			out["state"] = Farm.GROWING
	return out


## Start the next growth interval from a real child action. This stays pure so
## the screen, a visitor and a probe all share the same timestamp rule.
static func reanchor(plot: Dictionary, now: int) -> Dictionary:
	var out: Dictionary = plot.duplicate(true)
	out["last_updated_at"] = maxi(now, 0)
	return out


## Shoo the caterpillar off. Exactly weed()'s twin, and deliberately a separate
## function rather than a shared one with a parameter: the two jobs are told
## apart by the child from what he SEES, and the day one of them stops growth
## and the other does not, a shared function is where that difference would have
## to be smuggled in as a flag.
static func shoo(plot: Dictionary) -> Dictionary:
	var out: Dictionary = plot.duplicate(true)
	if str(out.get("care_event", "")) == CARE_BUG:
		out["care_event"] = CARE_NONE
		if str(out.get("state", "")) == Farm.NEEDS_CARE:
			out["state"] = Farm.GROWING
	out["care_completed"] = true
	return out


## Pull the weeds. Growth was never stopped by them -- weeds are a job, not a
## punishment -- so this changes nothing except that the plot stops asking.
##
## care_completed latches, so weeds come once per planting and not once per
## visit. A child who has already tidied this bed should not find it untidy
## again every time he walks past.
static func weed(plot: Dictionary) -> Dictionary:
	var out: Dictionary = plot.duplicate(true)
	if str(out.get("care_event", "")) == CARE_WEEDS:
		out["care_event"] = CARE_NONE
		if str(out.get("state", "")) == Farm.NEEDS_CARE:
			out["state"] = Farm.GROWING
	out["care_completed"] = true
	return out
