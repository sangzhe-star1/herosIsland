extends RefCounted
## Claim a planting's once-only harvest reward and persist its bounded ledger id.
##
## RewardManager.record() appends to the array it receives. Give it a snapshot
## so its duplicate check cannot pre-append to the save's ledger and bypass
## Farm.remember_paid()'s retention limit.

const Farm := preload("res://scripts/garden/farm_save.gd")
const PlotHarvest := preload("res://scripts/garden/farm_plot_harvest_controller.gd")


static func claim(plot: Dictionary, farm: Dictionary, crop_id: String) -> Dictionary:
	if not Farm.is_ready(plot):
		return {}
	var key := PlotHarvest.transaction_id(plot)
	var saved_paid: Variant = farm.get("paid_harvests", [])
	var gate_paid: Array = []
	if saved_paid is Array:
		gate_paid = saved_paid.duplicate()
	if not RewardManager.record("garden:harvest:%s" % crop_id, key, gate_paid):
		return {"claimed": false, "duplicate": true, "key": key}
	Farm.remember_paid(farm, key)
	return {"claimed": true, "duplicate": false, "key": key}
