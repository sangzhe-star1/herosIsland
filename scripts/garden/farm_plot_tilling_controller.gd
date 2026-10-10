extends RefCounted
## Turns untouched earth into a ready seed bed.
##
## Taps, the shovel brush, and the hint director all use the same transition.
## GardenScreen owns persistence, sound, guidance, and the world redraw.

const Farm := preload("res://scripts/garden/farm_save.gd")


static func till(plot: Dictionary) -> Dictionary:
	if str(plot.get("state", Farm.EMPTY)) != Farm.EMPTY:
		return {}
	var tilled := plot.duplicate(true)
	tilled["state"] = Farm.TILLED
	return tilled
