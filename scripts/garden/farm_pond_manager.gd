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
const POND_RADIUS := 54.0
const RING_DURATION := 1.8
const RING_TOLERANCE := 0.45


## The water art owns its position in farm_world_dressing.json. The hit test,
## ring, and collection flight all read this same anchor so moving the pond in
## the world layout cannot leave fishing behind at an empty patch of grass.
static func pond_center() -> Vector2:
	var center: Variant = _pond_dressing_center()
	if center is Vector2:
		return center
	return Vector2.ZERO


static func _pond_dressing_center() -> Variant:
	for entry in GameData.farm_dressing.get("props", []):
		if not entry is Dictionary or str(entry.get("id", "")) != "pond":
			continue
		var at: Variant = entry.get("at", [])
		if at is Array and at.size() >= 2:
			return Vector2(float(at[0]), float(at[1]))
	return null


static func fish_caught_total(farm: Dictionary) -> int:
	return int(farm.get("fish_caught_total", 0))


static func has_ducklings(farm: Dictionary) -> bool:
	return fish_caught_total(farm) >= DUCKLING_THRESHOLD


static func is_near_pond(world_pos: Vector2) -> bool:
	var center: Variant = _pond_dressing_center()
	if not center is Vector2:
		return false
	var point: Vector2 = center
	return world_pos.distance_to(point) <= (POND_RADIUS + 25.0)


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
