extends RefCounted
## Resolve one press on a timed farm facility.
##
## The garden page owns sound, animation, and saving. This controller owns the
## shared decision: take a finished batch, show progress, start production, or
## report the missing input. Keeping that branch here makes the coop, mill,
## cow shed, and beehive follow the same rules.

const Maker := preload("res://scripts/garden/farm_maker_manager.gd")
const Pen := preload("res://scripts/garden/farm_pen_manager.gd")

const COLLECTED := "collected"
const WAITING := "waiting"
const STARTED := "started"
const MISSING := "missing"


static func press_pen(farm: Dictionary, spec: Dictionary, now: int) -> Dictionary:
	match Pen.state(farm, spec, now):
		Pen.READY:
			return {"action": COLLECTED, "receipt": Pen.collect(farm, spec)}
		Pen.PRODUCING:
			return {"action": WAITING, "progress": Pen.progress(farm, spec, now)}
		_:
			if Pen.feed(farm, spec, now):
				return {"action": STARTED}
			return {"action": MISSING,
				"input_crop": str(spec.get("feed_crop", ""))}


static func press_maker(farm: Dictionary, spec: Dictionary, now: int) -> Dictionary:
	match Maker.state(farm, spec, now):
		Maker.READY:
			return {"action": COLLECTED, "receipt": Maker.collect(farm, spec)}
		Maker.WORKING:
			return {"action": WAITING, "progress": Maker.progress(farm, spec, now)}
		_:
			if Maker.start(farm, spec, now):
				return {"action": STARTED}
			return {"action": MISSING,
				"input_crop": str(spec.get("input", ""))}
