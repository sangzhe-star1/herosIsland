extends RefCounted
## The one action a plot is offering right now.
##
## The task ribbon and a bare-hand tap used to keep parallel state matches:
## one said "plant" while the other answered with a seed hint, one showed a
## harvest while the other could route to care. This small rule table is the
## shared contract. Callers still own the sound, save, animation, and wording.

const Farm := preload("res://scripts/garden/farm_save.gd")

const TILL := "till"
const CARE := "care"
const HARVEST := "harvest"
const PLANT := "plant"
const WAIT := "wait"
const LOCKED := "locked"


static func for_plot(plot: Dictionary, harvesting: bool = false) -> String:
	if harvesting:
		return LOCKED
	match str(plot.get("state", Farm.EMPTY)):
		Farm.EMPTY:
			return TILL
		Farm.NEEDS_CARE:
			return CARE
		Farm.READY:
			return HARVEST
		Farm.TILLED:
			return PLANT
		_:
			return WAIT


## Choose the first usable bed in the same priority order used by the ribbon.
## Beds mid-harvest are omitted until their collection animation settles.
static func next_action_index(plots: Array,
		harvesting_ids: Dictionary = {}) -> int:
	for action in [HARVEST, CARE, PLANT, TILL]:
		for index in range(plots.size()):
			var plot: Dictionary = plots[index]
			var plot_id := str(plot.get("plot_id", ""))
			if for_plot(plot, harvesting_ids.has(plot_id)) == action:
				return index
	return -1
