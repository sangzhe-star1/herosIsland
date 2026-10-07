extends RefCounted
## Manages pond fishing, timing ring mechanics, and the duck family reward.
##
## Deliberately NOT a class_name, loaded through:
##     const PondManager := preload("res://scripts/garden/farm_pond_manager.gd")
##
## Child-first design principles:
## - No luck involved: ripples expand smoothly, the timing ring always contracts deterministically.
## - No fail state: missing or tapping early gives a gentle water ripple and an instant retry.
## - After catching 5 fish, 3 cute yellow ducklings hatch and follow mama duck in a row!

const Barn := preload("res://scripts/garden/inventory_manager.gd")

const DUCKLING_THRESHOLD := 5
const POND_CENTER := Vector2(1362, 612)
const POND_RADIUS := 54.0
const RING_DURATION := 1.8
const RING_TOLERANCE := 0.45


static func fish_caught_total(farm: Dictionary) -> int:
	return int(farm.get("fish_caught_total", 0))


static func has_ducklings(farm: Dictionary) -> bool:
	return fish_caught_total(farm) >= DUCKLING_THRESHOLD


static func is_near_pond(world_pos: Vector2) -> bool:
	return world_pos.distance_to(POND_CENTER) <= (POND_RADIUS + 25.0)


## Record catching a fish: adds 1 fresh fish to inventory, updates count,
## and checks whether ducklings should follow the duck.
static func catch_fish(farm: Dictionary) -> Dictionary:
	var total := fish_caught_total(farm) + 1
	farm["fish_caught_total"] = total
	farm["last_fish_at"] = GameClock.now_unix()
	var stored_res := Barn.store_harvest("fish", 1)
	var unlocked_ducklings := (total == DUCKLING_THRESHOLD)
	return {
		"success": true,
		"total": total,
		"unlocked_ducklings": unlocked_ducklings,
		"crop_id": "fish",
		"amount": 1,
		"stored": int(stored_res.get("stored", 1)),
		"spilled": int(stored_res.get("spilled", 0))
	}
