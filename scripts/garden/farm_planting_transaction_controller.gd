extends RefCounted
## Resolve and commit one planting against the farm's saved plot array.
##
## The screen supplies the live lesson state, timestamp, and one rare-crop
## roll. This controller keeps context resolution, cycle creation, and the
## saved-array update in one transaction shared by seed drops and the brush.

const Planting := preload("res://scripts/garden/farm_plot_planting_controller.gd")
const PlantingContext := preload("res://scripts/garden/farm_planting_context_controller.gd")


static func settle(farm: Dictionary, index: int, crop_id: String,
		planted_at: int, lesson_running: bool, lesson_target_index: int,
		lesson_crop_id: String, lesson_growth_seconds: int,
		golden_roll: float) -> Dictionary:
	var plots: Array = farm.get("plots", [])
	if index < 0 or index >= plots.size() or crop_id.is_empty():
		return {}
	var source: Dictionary = plots[index]
	var context := PlantingContext.resolve(
		farm.get("dailies", {}), lesson_running, index, lesson_target_index,
		crop_id, lesson_crop_id, lesson_growth_seconds, golden_roll)
	var planted: Dictionary = Planting.plant(source, crop_id, planted_at,
		int(context.get("growth_override_seconds", 0)),
		bool(context.get("golden", false)))
	if planted.is_empty():
		return {}
	plots[index] = planted
	farm["plots"] = plots
	return {"planted": true, "index": index,
		"plot": planted.duplicate(true), "context": context.duplicate(true)}
