extends RefCounted
## Decide what the first-planting lesson should say and which bed it means.
##
## GardenScreen owns the voice, finger, clock, and completion save. These
## queries use the same live plot state the child is looking at, so the lesson
## follows a seed planted in another bed and stays quiet while it grows.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")


static func step(plots: Array, named_index: int,
		fillable_order_id: String) -> String:
	# The basket somebody is waiting for beats the earth; giving it over ends the
	# lesson, and the child is already holding the carrots.
	if fillable_order_id != "":
		return "order"
	var index := target_plot(plots, named_index)
	if index < 0 or index >= plots.size():
		return ""
	var plot: Dictionary = plots[index]
	match str(plot.get("state", "")):
		Farm.EMPTY:
			return "till"
		Farm.TILLED:
			return "plant"
		Farm.READY:
			return "harvest"
		Farm.NEEDS_CARE:
			# Only thirst has a recorded tutorial line. Unknown care stays quiet
			# rather than telling the child to do something different.
			if str(plot.get("care_event", "")) == Growth.CARE_THIRSTY:
				return "water"
	return ""


## Prefer the named bed while it holds a plant; otherwise follow the first
## planted bed, then fall back to the configured bed if it still exists.
static func target_plot(plots: Array, named_index: int) -> int:
	if named_index >= 0 and named_index < plots.size() \
			and Farm.is_planted(plots[named_index]):
		return named_index
	for i in range(plots.size()):
		if Farm.is_planted(plots[i]):
			return i
	return named_index if named_index >= 0 and named_index < plots.size() else -1


## Preview a planting as present without changing the save. The real plot
## transition happens after this query decides whether the lesson's crop gets
## its one-time fast-growth override.
static func target_after_planting(plots: Array, named_index: int,
		planting_index: int) -> int:
	if named_index >= 0 and named_index < plots.size() \
			and (named_index == planting_index \
			or Farm.is_planted(plots[named_index])):
		return named_index
	for i in range(plots.size()):
		if i == planting_index or Farm.is_planted(plots[i]):
			return i
	return named_index if named_index >= 0 and named_index < plots.size() else -1
