extends RefCounted
## Settle every durable change for one harvest before the page plays feedback.
##
## Existing controllers own the once-only gate, plot transition, and progress
## rules. This boundary orders those changes with Barn's stored-plus-spilled
## receipt so a caller cannot collect a crop without also resetting the bed and
## recording the follow-up progress. It mutates the live save but never writes
## it; the tap or stroke owns the single complete disk commit.

const Farm := preload("res://scripts/garden/farm_save.gd")
const PlotHarvest := preload("res://scripts/garden/farm_plot_harvest_controller.gd")
const HarvestLedger := preload("res://scripts/garden/farm_harvest_ledger_controller.gd")
const HarvestProgress := preload("res://scripts/garden/farm_harvest_progress_controller.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")


static func settle(plot: Dictionary, farm: Dictionary,
		today: String = "") -> Dictionary:
	var plot_id := str(plot.get("plot_id", ""))
	var cycle := int(plot.get("plant_cycle_id", 0))
	var crop_id := str(plot.get("crop_id", ""))
	var claim: Dictionary = HarvestLedger.claim(plot, farm, crop_id)
	if not bool(claim.get("claimed", false)):
		var freed := false
		if bool(claim.get("duplicate", false)) and Farm.is_ready(plot):
			var paid_value: Variant = farm.get("paid_harvests", [])
			var paid: Array = paid_value if paid_value is Array else []
			var recovered: Dictionary = PlotHarvest.recover_paid_duplicate(plot, paid)
			if not recovered.is_empty():
				_apply_plot_state(plot, recovered)
				freed = true
		return {
			"claimed": false,
			"duplicate_freed": freed,
			"plot_id": plot_id,
			"cycle": cycle,
		}

	var crop: Dictionary = GameData.get_crop(crop_id)
	var amount := maxi(int(crop.get("harvest_amount", 1)), 1)
	var golden := bool(plot.get("golden", false))
	var landed: Dictionary = Barn.store_harvest(crop_id, amount)
	var reset: Dictionary = PlotHarvest.after_harvest(plot)
	_apply_plot_state(plot, reset)
	var receipt := {
		"claimed": true,
		"transaction_id": str(claim.get("key", "")),
		"plot_id": plot_id,
		"crop_id": crop_id,
		"amount": amount,
		"stored": int(landed.get("stored", 0)),
		"spilled": int(landed.get("spilled", 0)),
		"golden": golden,
	}
	var progress_date := today if today != "" else GameClock.now_date()
	receipt.merge(HarvestProgress.settle(receipt, progress_date), true)
	return receipt


static func _apply_plot_state(plot: Dictionary, fresh: Dictionary) -> void:
	for key in fresh.keys():
		plot[key] = fresh[key]
