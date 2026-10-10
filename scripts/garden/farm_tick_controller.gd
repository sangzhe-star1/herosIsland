extends RefCounted
## Compare a farm clock beat with the state that was on screen before it.
## The screen owns the timer and its effects; this controller decides whether
## the garden furniture has a new fact to show and which beds just ripened.

const Farm := preload("res://scripts/garden/farm_save.gd")


static func capture(plots: Array) -> Dictionary:
	var ripe_ids: Array[String] = []
	for plot_value in plots:
		var plot: Dictionary = plot_value
		if Farm.is_ready(plot):
			ripe_ids.append(str(plot.get("plot_id", "")))
	return {
		"meaning": meaning_signature(plots),
		"visual": visual_signature(plots),
		"ripe_ids": ripe_ids,
	}


static func resolve(before: Dictionary, plots: Array, tipped: int = 0) -> Dictionary:
	var before_ripe: Dictionary = {}
	for plot_id in before.get("ripe_ids", []):
		before_ripe[str(plot_id)] = true
	var ripened_indices: Array[int] = []
	for i in range(plots.size()):
		var plot: Dictionary = plots[i]
		var plot_id := str(plot.get("plot_id", ""))
		if Farm.is_ready(plot) and not before_ripe.has(plot_id):
			ripened_indices.append(i)
	var meaning := meaning_signature(plots)
	return {
		"meaning": meaning,
		"visual": visual_signature(plots),
		"meaning_changed": meaning != str(before.get("meaning", "")),
		"ripened_indices": ripened_indices,
		"needs_rebuild": meaning != str(before.get("meaning", "")) \
			or tipped > 0,
	}


## Sub-stage progress changes bed art, but not the ribbon, dog, or hints.
static func visual_signature(plots: Array) -> String:
	var out := ""
	for plot in plots:
		out += "%s/%d/%.3f/%s;" % [
			str(plot.get("state", "")),
			int(plot.get("growth_stage", 0)),
			float(plot.get("growth_progress", 0.0)),
			str(plot.get("care_event", "")),
		]
	return out


## Furniture reacts only when a bed's state, stage, or care request changes.
static func meaning_signature(plots: Array) -> String:
	var out := ""
	for plot in plots:
		out += "%s/%d/%s;" % [
			str(plot.get("state", "")),
			int(plot.get("growth_stage", 0)),
			str(plot.get("care_event", "")),
		]
	return out
