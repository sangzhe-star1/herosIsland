extends RefCounted
## The one state transition for watering, weeding, and shooing a farm plot.
##
## A tap on a bed and a brush swept across it must produce the same plot.
## This controller owns that mutation and its timestamp; GardenScreen owns the
## sound, daily tally, and visible response after it has happened.

const Growth := preload("res://scripts/garden/offline_growth.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")

const WATER := "water"
const WEED := "weed"
const SHOO := "shoo"
const REPAIR := "repair"


static func apply(plot: Dictionary, now: int) -> Dictionary:
	match str(plot.get("care_event", "")):
		Growth.CARE_THIRSTY:
			return {"plot": Growth.reanchor(Growth.water(plot), now), "action": WATER}
		Growth.CARE_WEEDS:
			return {"plot": Growth.reanchor(Growth.weed(plot), now), "action": WEED}
		Growth.CARE_BUG:
			return {"plot": Growth.reanchor(Growth.shoo(plot), now), "action": SHOO}
		_:
			# A waiting plot with an unknown job must not become permanently
			# untouchable. Repair its state while preserving the unfamiliar marker
			# for save inspection; the screen gives this quiet repair no reward.
			var repaired := plot.duplicate(true)
			repaired["state"] = Farm.GROWING
			return {"plot": Growth.reanchor(repaired, now), "action": REPAIR}
