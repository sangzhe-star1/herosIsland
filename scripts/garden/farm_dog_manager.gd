extends RefCounted
## Manages dog fetch growth, trick unlocks, and daily marked dig spot mechanics.
##
## Deliberately NOT a class_name, loaded through:
##     const DogManager := preload("res://scripts/garden/farm_dog_manager.gd")
##
## Child-first design principles:
## - Fetch count unlocks tricks (sit, roll, carry the basket).
## - Once per day, he digs at one marked spot on the grass and finds a seed.
## - Never coins, never a surprise box, never a fail state. The seed is one
##   of the four starter crops every farm already has, chosen by the weekday,
##   so it is a ritual with the dog and never a shop unlock for free.
## - On the save: the fetch tally, the trick list and the day of the last dig.
##   Nothing about where he stands or what he is doing.

## Open grass in the south-east, below the expansion beds and left of the
## decor stand: the point farthest from every bed, facility and dressing prop
## (the rules probe checks the beds and facilities). The first spot sat inside
## the visit board's box, and the board took every tap meant for the mound.
const DIG_SPOT_POSITION := Vector2(1750.0, 890.0)
const DIG_SPOT_RADIUS := 44.0


static func fetch_count(farm: Dictionary) -> int:
	return int(farm.get("dog_fetches", 0))


static func tricks_unlocked(farm: Dictionary) -> Array:
	return farm.get("dog_tricks", [])


static func has_trick(farm: Dictionary, trick_id: String) -> bool:
	return trick_id in tricks_unlocked(farm)


## Records a fetch completion and unlocks any newly earned tricks.
static func record_fetch(farm: Dictionary) -> Dictionary:
	var total := fetch_count(farm) + 1
	farm["dog_fetches"] = total
	var current_tricks: Array = farm.get("dog_tricks", []).duplicate()
	var new_tricks: Array = []
	var config: Dictionary = GameData.farm_dog
	for entry in config.get("fetch_tricks", []):
		if not (entry is Dictionary):
			continue
		var tid := str(entry.get("id", ""))
		var threshold := int(entry.get("fetches", 3))
		if total >= threshold and not (tid in current_tricks):
			current_tricks.append(tid)
			new_tricks.append(tid)
	farm["dog_tricks"] = current_tricks
	return {
		"total": total,
		"new_tricks": new_tricks,
		"latest_trick": new_tricks[0] if not new_tricks.is_empty() else ""
	}


static func can_dig_today(farm: Dictionary) -> bool:
	return str(farm.get("last_dog_dig_date", "")) != GameClock.now_date()


static func is_near_dig_spot(world_pos: Vector2) -> bool:
	return world_pos.distance_to(DIG_SPOT_POSITION) <= (DIG_SPOT_RADIUS + 25.0)


## The seed the dog finds today: a starter crop the child already grows,
## picked by the weekday so Monday's find is Monday's find. Only crops on the
## child's own rack qualify -- the shop ladder stays the one way to a new crop.
static func todays_seed(farm: Dictionary) -> String:
	var config: Dictionary = GameData.farm_dog
	var seeds: Array = config.get("daily_dig_seeds", ["carrot", "corn", "strawberry", "tomato"])
	var owned: Array = farm.get("unlocked_crops", [])
	var allowed: Array = []
	for id in seeds:
		if str(id) in owned:
			allowed.append(str(id))
	if allowed.is_empty():
		return "carrot"
	var weekday := int(GameClock.now_datetime().get("weekday", 0))
	return str(allowed[weekday % allowed.size()])


## Digs at the marked spot once a day: names the seed, stamps the day. It
## changes nothing else on the save -- no coins, no unlock, no inventory row
## nothing reads -- the find is the little flight to the barn and a word.
static func perform_dig(farm: Dictionary) -> Dictionary:
	if not can_dig_today(farm):
		return {"success": false, "reason": "already_dug"}
	var date_str := GameClock.now_date()
	var crop_id := todays_seed(farm)
	farm["last_dog_dig_date"] = date_str
	return {"success": true, "crop_id": crop_id, "date": date_str}
