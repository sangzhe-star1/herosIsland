extends RefCounted
## Starts one planting cycle on a turned plot.
##
## Time, lesson acceleration, and the rare-gold decision are inputs from the
## screen. This controller owns only the plot transition, so every planting
## path starts the same transaction cycle and leaves its source snapshot alone.

const Farm := preload("res://scripts/garden/farm_save.gd")


static func plant(plot: Dictionary, crop_id: String, planted_at: int,
		growth_override_seconds: int, golden: bool) -> Dictionary:
	if crop_id.is_empty() or str(plot.get("state", "")) != Farm.TILLED:
		return {}
	var planted := plot.duplicate(true)
	planted["crop_id"] = crop_id
	planted["state"] = Farm.SEEDED
	# A new planting, and therefore a new transaction id for whatever comes out
	# of it. Rising by one here is the whole reason a harvest cannot be paid
	# for twice; see the harvest controller.
	planted["plant_cycle_id"] = int(planted.get("plant_cycle_id", 0)) + 1
	planted["planted_at"] = planted_at
	planted["last_updated_at"] = planted_at
	planted["growth_stage"] = 0
	planted["growth_progress"] = 0.0
	planted["water_level"] = 1.0
	planted["care_event"] = ""
	planted["care_completed"] = false
	planted["growth_override_seconds"] = growth_override_seconds
	planted["golden"] = golden
	return planted
