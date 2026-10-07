extends RefCounted
## Computes day/night phases, visual lighting tint, and morning dew for the farm.
##
## Deliberately NOT a class_name, loaded through:
##     const DayCycle := preload("res://scripts/garden/farm_day_cycle.gd")
##
## Child-first design principles:
## - Scenery only! Crops never grow slower, nothing withers or decays at night.
## - Night features a cozy twilight tint, glowing lanterns, and fireflies over the pond.
## - Morning dew gently waters every thirsty plot once per day, bringing quiet delight.

const Growth := preload("res://scripts/garden/offline_growth.gd")

const PHASE_MORNING := "morning"
const PHASE_DAY := "day"
const PHASE_EVENING := "evening"
const PHASE_NIGHT := "night"

const TINT_MORNING := Color(1.0, 0.96, 0.88, 0.06)
const TINT_DAY := Color(1.0, 1.0, 1.0, 0.0)
const TINT_EVENING := Color(0.98, 0.68, 0.25, 0.16)
const TINT_NIGHT := Color(0.12, 0.16, 0.38, 0.26)


static func phase_for_hour(hour: int) -> String:
	if hour >= 6 and hour < 9:
		return PHASE_MORNING
	elif hour >= 9 and hour < 17:
		return PHASE_DAY
	elif hour >= 17 and hour < 20:
		return PHASE_EVENING
	return PHASE_NIGHT


static func current_phase() -> String:
	var dt: Dictionary = GameClock.now_datetime()
	return phase_for_hour(int(dt.get("hour", 12)))


static func tint_color_for_hour(hour: int) -> Color:
	match phase_for_hour(hour):
		PHASE_MORNING:
			return TINT_MORNING
		PHASE_DAY:
			return TINT_DAY
		PHASE_EVENING:
			return TINT_EVENING
		PHASE_NIGHT:
			return TINT_NIGHT
	return TINT_DAY


static func current_tint_color() -> Color:
	var dt: Dictionary = GameClock.now_datetime()
	return tint_color_for_hour(int(dt.get("hour", 12)))


static func night_factor_for_hour(hour: int) -> float:
	match phase_for_hour(hour):
		PHASE_NIGHT:
			return 1.0
		PHASE_EVENING:
			return 0.75
		PHASE_MORNING:
			return 0.15
		PHASE_DAY:
			return 0.0
	return 0.0


static func current_night_factor() -> float:
	var dt: Dictionary = GameClock.now_datetime()
	return night_factor_for_hour(int(dt.get("hour", 12)))


## Morning dew brings a quiet sparkle to growing crops once per morning (6:00 - 10:59).
## It does NOT clear thirsty care events, keeping morning watering agency for the child.
## Recorded in farm["last_dew_date"] to ensure exactly one morning blessing.
static func check_morning_dew(farm: Dictionary) -> Dictionary:
	var today := GameClock.now_date()
	var dt: Dictionary = GameClock.now_datetime()
	var hour := int(dt.get("hour", 12))
	if hour < 6 or hour >= 11:
		return {"applied": false, "sparkle_count": 0, "watered_count": 0, "date": today}

	if str(farm.get("last_dew_date", "")) == today:
		return {"applied": false, "sparkle_count": 0, "watered_count": 0, "date": today}

	farm["last_dew_date"] = today
	var plots: Array = farm.get("plots", [])
	var sparkle_count := 0
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		var crop_id := str(plot.get("crop_id", ""))
		if crop_id.is_empty():
			continue
		sparkle_count += 1

	return {"applied": true, "sparkle_count": sparkle_count, "watered_count": 0, "date": today}
