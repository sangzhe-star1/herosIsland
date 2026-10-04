extends RefCounted
## A maker: something on the farm that takes one thing in, works for a
## while, and gives another thing back. The windmill is the first (wheat
## to flour); the hens have their own older manager that says the same
## thing in the same shape. One spec dictionary per maker, state in the
## farm save under spec.key, time on GameClock so work done while the
## game was shut is done when it opens.

const Barn := preload("res://scripts/garden/inventory_manager.gd")

const MILL := {"key": "mill", "input": "wheat", "input_count": 2,
	"seconds": 90, "output": "flour", "output_count": 1}

const IDLE := "idle"          # press puts the input in, if there is enough
const WORKING := "working"    # press shows how long is left
const READY := "ready"        # press collects


static func store(farm: Dictionary, spec: Dictionary) -> Dictionary:
	var key := str(spec["key"])
	if not (farm.get(key) is Dictionary):
		farm[key] = {"started_at": 0, "done": 0}
	return farm[key]


static func state(farm: Dictionary, spec: Dictionary, now: int) -> String:
	var c := store(farm, spec)
	if int(c.get("done", 0)) > 0:
		return READY
	var started := int(c.get("started_at", 0))
	if started <= 0:
		return IDLE
	if now - started >= int(spec["seconds"]):
		c["done"] = int(spec["output_count"])
		c["started_at"] = 0
		return READY
	return WORKING


static func progress(farm: Dictionary, spec: Dictionary, now: int) -> float:
	var started := int(store(farm, spec).get("started_at", 0))
	if started <= 0:
		return 0.0
	return clampf(float(now - started) / float(spec["seconds"]), 0.0, 1.0)


static func can_start(spec: Dictionary) -> bool:
	return Barn.has(str(spec["input"]), int(spec["input_count"]))


static func start(farm: Dictionary, spec: Dictionary, now: int) -> bool:
	if not Barn.take(str(spec["input"]), int(spec["input_count"])):
		return false
	var c := store(farm, spec)
	c["started_at"] = now
	c["done"] = 0
	return true


## Out through the harvest's own door, so a full barn spills, never loses.
static func collect(farm: Dictionary, spec: Dictionary) -> Dictionary:
	var c := store(farm, spec)
	var done := int(c.get("done", 0))
	if done <= 0:
		return {}
	c["done"] = 0
	c["started_at"] = 0
	var receipt := Barn.store_harvest(str(spec["output"]), done)
	receipt["crop_id"] = str(spec["output"])
	receipt["amount"] = done
	return receipt
