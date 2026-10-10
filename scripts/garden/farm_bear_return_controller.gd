extends RefCounted
## Commit the returning bear's water, visit record, and pending flag together.
## The screen owns the later sound and visual response; the world only decides
## when the bear reaches the bed.

const Farm := preload("res://scripts/garden/farm_save.gd")
const PlotCare := preload("res://scripts/garden/farm_plot_care_controller.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")


static func settle_water(farm: Dictionary, index: int, now: int) -> Dictionary:
	if not bool(farm.get("bear_return_visit_pending", false)):
		return {"settled": false, "reason": "not_pending"}
	var raw_plots: Variant = farm.get("plots", [])
	if not raw_plots is Array or index < 0 or index >= raw_plots.size():
		return {"settled": false, "reason": "missing_plot"}
	var plots: Array = raw_plots
	if not plots[index] is Dictionary:
		return {"settled": false, "reason": "invalid_plot"}
	var plot: Dictionary = plots[index]
	if str(plot.get("care_event", "")) != Growth.CARE_THIRSTY:
		return {"settled": false, "reason": "plot_not_thirsty"}
	var care: Dictionary = PlotCare.apply(plot, now)
	if str(care.get("action", "")) != PlotCare.WATER:
		return {"settled": false, "reason": "water_refused"}

	# No disk write happens until the screen has also recorded daily progress.
	# Keeping all durable fields together means an interrupted visit is either
	# still pending on next launch or fully visible on the board, never half done.
	plots[index] = care.get("plot", plot)
	farm["plots"] = plots
	farm["bear_return_visit_pending"] = false
	Farm.remember_visit(farm, {
		"who": "bear",
		"watered": 1,
		"star": 1,
		"at": now,
	})
	farm["visit_log_unread"] = true
	return {"settled": true, "action": PlotCare.WATER, "plot": plots[index]}
