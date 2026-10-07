extends RefCounted
## Data-driven pen manager for farm animals and facilities.
##
## Generalizes the chicken coop into a reusable pen rule: give them the crop
## they eat, wait for production, and collect the farm produce. Zero punishment,
## zero decay, positive child UX only.
##
## Built-in specs:
## - coop: corn (1) -> 120s -> egg (2)
## - cow_shed: wheat (2) -> 150s -> milk (1)
## - beehive: strawberry (2) -> 90s -> honey (1)

const Barn := preload("res://scripts/garden/inventory_manager.gd")

const COOP := {
	"key": "coop",
	"feed_crop": "corn",
	"feed_count": 1,
	"seconds": 120,
	"output": "egg",
	"output_count": 2,
	"ready_key": "eggs",
	"voice_feed": "farm_coop_feed",
	"voice_collect": "farm_coop_eggs"
}

const COW_SHED := {
	"key": "cow_shed",
	"feed_crop": "wheat",
	"feed_count": 2,
	"seconds": 150,
	"output": "milk",
	"output_count": 1,
	"ready_key": "ready",
	"voice_feed": "farm_coop_feed",
	"voice_collect": "farm_coop_eggs"
}

const BEEHIVE := {
	"key": "beehive",
	"feed_crop": "strawberry",
	"feed_count": 2,
	"seconds": 90,
	"output": "honey",
	"output_count": 1,
	"ready_key": "ready",
	"voice_feed": "farm_coop_feed",
	"voice_collect": "farm_coop_eggs"
}

const ALL_SPECS := [COOP, COW_SHED, BEEHIVE]

const HUNGRY := "hungry"
const PRODUCING := "producing"
const READY := "ready"


static func spec_for(key: String) -> Dictionary:
	for s in ALL_SPECS:
		if str(s["key"]) == key:
			return s
	return {}


static func pen(farm: Dictionary, spec: Dictionary) -> Dictionary:
	var key := str(spec["key"])
	var rkey := str(spec.get("ready_key", "ready"))
	if not (farm.get(key) is Dictionary):
		farm[key] = {"fed_at": 0, rkey: 0}
	return farm[key]


static func state(farm: Dictionary, spec: Dictionary, now: int) -> String:
	var p := pen(farm, spec)
	var rkey := str(spec.get("ready_key", "ready"))
	if int(p.get(rkey, 0)) > 0:
		return READY
	var fed_at := int(p.get("fed_at", 0))
	if fed_at <= 0:
		return HUNGRY
	var duration := int(spec.get("seconds", 120))
	if now - fed_at >= duration:
		p[rkey] = int(spec.get("output_count", 1))
		p["fed_at"] = 0
		return READY
	return PRODUCING


static func progress(farm: Dictionary, spec: Dictionary, now: int) -> float:
	var p := pen(farm, spec)
	var fed_at := int(p.get("fed_at", 0))
	if fed_at <= 0:
		return 0.0
	var duration := float(spec.get("seconds", 120))
	return clampf(float(now - fed_at) / maxf(duration, 1.0), 0.0, 1.0)


static func can_feed(spec: Dictionary) -> bool:
	return Barn.has(str(spec.get("feed_crop", "")), int(spec.get("feed_count", 1)))


static func feed(farm: Dictionary, spec: Dictionary, now: int) -> bool:
	var crop := str(spec.get("feed_crop", ""))
	var count := int(spec.get("feed_count", 1))
	if not Barn.take(crop, count):
		return false
	var p := pen(farm, spec)
	var rkey := str(spec.get("ready_key", "ready"))
	p["fed_at"] = now
	p[rkey] = 0
	return true


static func collect(farm: Dictionary, spec: Dictionary) -> Dictionary:
	var p := pen(farm, spec)
	var rkey := str(spec.get("ready_key", "ready"))
	var amount := int(p.get(rkey, 0))
	if amount <= 0:
		return {}
	p[rkey] = 0
	p["fed_at"] = 0
	var out_crop := str(spec.get("output", ""))
	var receipt := Barn.store_harvest(out_crop, amount)
	receipt["crop_id"] = out_crop
	receipt["amount"] = amount
	return receipt
