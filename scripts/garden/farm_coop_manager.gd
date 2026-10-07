extends RefCounted
## The hens. Delegated to FarmPenManager as a pen specification while
## preserving the existing static API for probes and callers.

const Pen := preload("res://scripts/garden/farm_pen_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")

const FEED_CROP := "corn"
const LAY_SECONDS := 120
const EGGS_PER_FEED := 2

const HUNGRY := "hungry"
const LAYING := "producing"
const READY := "ready"


static func coop(farm: Dictionary) -> Dictionary:
	return Pen.pen(farm, Pen.COOP)


static func state(farm: Dictionary, now: int) -> String:
	return Pen.state(farm, Pen.COOP, now)


static func progress(farm: Dictionary, now: int) -> float:
	return Pen.progress(farm, Pen.COOP, now)


static func can_feed() -> bool:
	return Pen.can_feed(Pen.COOP)


static func feed(farm: Dictionary, now: int) -> bool:
	return Pen.feed(farm, Pen.COOP, now)


static func collect(farm: Dictionary) -> Dictionary:
	return Pen.collect(farm, Pen.COOP)
