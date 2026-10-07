extends RefCounted
## Manages dog fetch growth, trick unlocks, and daily marked dig spot mechanics.
##
## Deliberately NOT a class_name, loaded through:
##     const DogManager := preload("res://scripts/garden/farm_dog_manager.gd")
##
## Child-first design principles:
## - Fetch count unlocks tricks (sit, roll, carry the basket).
## - Once per day, he digs at one marked spot on the grass and finds a seed.
## - Never coins, never a surprise box, never a fail state.
## - Dog state stays off the save except the trick list and fetch tally.

const Barn := preload("res://scripts/garden/inventory_manager.gd")

const DIG_SPOT_POSITION := Vector2(510.0, 980.0)
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


## Digs at the marked spot: finds a seed for the day, unlocks crop if unowned,
## and records today's date.
static func perform_dig(farm: Dictionary) -> Dictionary:
	if not can_dig_today(farm):
		return {"success": false, "reason": "already_dug"}
	var config: Dictionary = GameData.farm_dog
	var seeds: Array = config.get("daily_dig_seeds", ["carrot", "corn", "strawberry", "tomato"])
	if seeds.is_empty():
		seeds = ["carrot"]
	var date_str := GameClock.now_date()
	var hash_val := 0
	for ch in date_str.to_utf8_buffer():
		hash_val = (hash_val * 31 + int(ch)) & 0x7FFFFFFF
	var crop_id := str(seeds[hash_val % seeds.size()])

	# Put seed into pouch/inventory
	Barn.put("seed_" + crop_id, 1, "inventory")

	# Also unlock on rack if unowned so the child can grow it!
	var unlocked_crops: Array = farm.get("unlocked_crops", [])
	var newly_unlocked := false
	if not (crop_id in unlocked_crops):
		unlocked_crops.append(crop_id)
		farm["unlocked_crops"] = unlocked_crops
		newly_unlocked = true

	farm["last_dog_dig_date"] = date_str
	return {
		"success": true,
		"crop_id": crop_id,
		"newly_unlocked_crop": newly_unlocked,
		"date": date_str
	}
