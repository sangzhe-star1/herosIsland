extends RefCounted
## The day's three little jobs, and the arithmetic of them.
##
##     const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
##     farm["dailies"] = Dailies.roll(farm, GameClock.now_date())
##
## WHAT THE DAILIES ARE FOR
##
## 王者农场's engagement spine is the daily loop: a short list of the same
## three verbs the farm already teaches, refreshed while the child sleeps, so
## every visit opens with something to do even when every bed is still
## growing. The transplant keeps the spine and drops the fangs: nothing here
## expires PUNITIVELY (an unfinished list resets silently at the date line --
## nothing is lost, nothing turns grey, nothing nags), the tasks are the
## three verbs a four-year-old already knows (water, pick, deliver), and the
## reward is star coins through the same once-only gate as every other coin
## on the island.
##
## WHY THE DATE IS PASSED IN, NOT READ
##
## Every function here is pure: hand it the farm and today's date, it hands
## back the farm's dailies. The clock lives at the call sites (the screen's
## entry settle, the harvest, the delivery), which is what lets a probe run a
## whole week of dailies in a millisecond by typing different date strings.
##
## THE SHAPE ON DISK
##
##   farm.dailies = {
##     "date": "2026-09-02",      # the day this list belongs to
##     "progress": {"water": 2},  # verbs done so far today
##     "claimed": ["water"],      # verbs already paid for today
##   }
##
## Absent, malformed, or yesterday's -- roll() answers a fresh list for all
## three, so no migration is needed and no save can hold a stale job.


## The list for `today`. Same date and well-formed: keep it, progress and
## all. Anything else -- yesterday's, tomorrow's, missing, half-written --
## comes back as a clean slate for the new day.
static func roll(farm: Dictionary, today: String) -> Dictionary:
	var dailies: Dictionary = farm.get("dailies", {})
	if str(dailies.get("date", "")) == today \
			and dailies.get("progress", {}) is Dictionary \
			and dailies.get("claimed", []) is Array:
		return dailies
	return {"date": today, "progress": {}, "claimed": []}


## Count one more of a verb. Clamped at the task's own target: the tally on
## the board is a promise being kept, not a number that runs away.
static func add(farm: Dictionary, today: String, verb: String, by: int = 1) -> Dictionary:
	var dailies := roll(farm, today)
	if by <= 0:
		return dailies
	var progress: Dictionary = dailies.get("progress", {})
	progress[verb] = clampi(int(progress.get(verb, 0)) + by, 0, target(verb))
	dailies["progress"] = progress
	return dailies


## How many of this verb the day asks for. An unknown verb asks for one --
## the smallest honest target -- and a data file that forgot a row degrades
## to a task that is done in a single act rather than one never done.
static func target(verb: String) -> int:
	for task in GameData.garden_dailies:
		if str(task.get("id", "")) == verb:
			return maxi(int(task.get("target", 1)), 1)
	return 1


static func task_by_id(verb: String) -> Dictionary:
	for task in GameData.garden_dailies:
		if str(task.get("id", "")) == verb:
			return task
	return {}


## Is this task's tally at its target?
static func done(dailies: Dictionary, task: Dictionary) -> bool:
	return int(dailies.get("progress", {}).get(str(task.get("id", "")), 0)) \
		>= maxi(int(task.get("target", 1)), 1)


## How many of today's familiar verbs have reached their own finish line.
## Claims deliberately do not matter here: caring for the whole farm is what
## lights the golden chance, whether the child opens the board for the coin
## straight away or later.  Both the garden ribbon and the planting rule ask
## this one question, so their little three-star picture cannot disagree with
## the actual chance.
static func done_count(dailies: Dictionary) -> int:
	var count := 0
	for task in GameData.garden_dailies:
		if done(dailies, task):
			count += 1
	return count


## The day's care is complete only when every configured daily verb is done.
## An empty or temporarily missing data list is not a free golden bonus.
static func all_done(dailies: Dictionary) -> bool:
	var total := GameData.garden_dailies.size()
	return total > 0 and done_count(dailies) >= total


## Display-only facts for a page that wants to celebrate today's care.  The
## manager still owns the meanings of "done" and "all done"; callers only
## choose where the already-derived answer is drawn.
static func summary(dailies: Dictionary) -> Dictionary:
	return {
		"done": done_count(dailies),
		"total": GameData.garden_dailies.size(),
		"all_done": all_done(dailies),
	}


## Has this task's reward been collected today? The ledger stores CLAIM KEYS
## -- the same date-stamped strings the once-gate is asked with -- so a task
## is "claimed" exactly when its key for THIS day is on the list.
static func claimed(dailies: Dictionary, task: Dictionary) -> bool:
	return claim_key(dailies, task) in (dailies.get("claimed", []) as Array)


## The once-key a claim is recorded under. The DATE is inside the key, which
## is the whole reason the reward cannot be farmed by winding the tablet to
## yesterday: a new day mints a key nobody has ever paid against.
static func claim_key(dailies: Dictionary, task: Dictionary) -> String:
	return "garden_daily_%s_%s" % [str(dailies.get("date", "")),
		str(task.get("id", ""))]
