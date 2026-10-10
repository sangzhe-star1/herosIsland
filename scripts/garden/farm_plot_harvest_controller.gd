extends RefCounted
## The save-state boundary for one crop harvest.
##
## GardenScreen still coordinates rewards, barn storage, progress and feedback.
## This controller owns the plot's pay-once identity and the two legal soil
## transitions after a paid harvest or a duplicate paid cycle.

const Farm := preload("res://scripts/garden/farm_save.gd")


static func transaction_id(plot: Dictionary) -> String:
	return _transaction_id(str(plot.get("plot_id", "")),
		int(plot.get("plant_cycle_id", 0)))


## A successful pick leaves turned soil ready for the next seed, while the
## planting cycle survives so the next transaction id cannot repeat.
static func after_harvest(plot: Dictionary) -> Dictionary:
	if not Farm.is_ready(plot):
		return {}
	return _tilled_plot(plot, int(plot.get("plant_cycle_id", 0)))


## Two devices can merge a paid ledger with a ripe plot from the other copy.
## Free that bed without yield, then skip any already-paid following cycles so
## the next planting can still be collected.
static func recover_paid_duplicate(plot: Dictionary, paid: Array) -> Dictionary:
	if not Farm.is_ready(plot):
		return {}
	var plot_id := str(plot.get("plot_id", ""))
	var next := int(plot.get("plant_cycle_id", 0)) + 1
	while _transaction_id(plot_id, next) in paid:
		next += 1
	return _tilled_plot(plot, next - 1)


static func _tilled_plot(source: Dictionary, cycle: int) -> Dictionary:
	var plot := Farm.fresh_plot(0)
	plot["plot_id"] = str(source.get("plot_id", ""))
	plot["state"] = Farm.TILLED
	plot["plant_cycle_id"] = cycle
	return plot


static func _transaction_id(plot_id: String, cycle: int) -> String:
	return "farm_harvest_%s_%d" % [plot_id, cycle]
