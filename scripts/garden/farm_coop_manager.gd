extends RefCounted
## The hens. One rule a six-year-old can hold: give them corn, wait, pick
## up the eggs. Nothing else -- no hunger that punishes, no hens that leave,
## no eggs that rot. A coop that is not fed is a coop that is waiting.
##
## State lives in the farm save under "coop": when they were fed and how
## many eggs are waiting. Time is GameClock.now_unix(), the same clock the
## beds grow by, so an egg laid while the game was closed is there when it
## opens, exactly like a carrot that ripened overnight.

const Barn := preload("res://scripts/garden/inventory_manager.gd")

## What the hens eat, how long they take, and what a feed gives.
const FEED_CROP := "corn"
const LAY_SECONDS := 120
const EGGS_PER_FEED := 2

const HUNGRY := "hungry"      # press feeds them, if there is corn
const LAYING := "laying"      # press shows how long is left
const READY := "ready"        # press collects


static func coop(farm: Dictionary) -> Dictionary:
	if not (farm.get("coop") is Dictionary):
		farm["coop"] = {"fed_at": 0, "eggs": 0}
	return farm["coop"]


static func state(farm: Dictionary, now: int) -> String:
	var c := coop(farm)
	if int(c.get("eggs", 0)) > 0:
		return READY
	var fed_at := int(c.get("fed_at", 0))
	if fed_at <= 0:
		return HUNGRY
	if now - fed_at >= LAY_SECONDS:
		# Laid while nobody was looking: the eggs appear on this very look.
		c["eggs"] = EGGS_PER_FEED
		c["fed_at"] = 0
		return READY
	return LAYING


## 0..1 of the wait, for the ring.
static func progress(farm: Dictionary, now: int) -> float:
	var c := coop(farm)
	var fed_at := int(c.get("fed_at", 0))
	if fed_at <= 0:
		return 0.0
	return clampf(float(now - fed_at) / float(LAY_SECONDS), 0.0, 1.0)


static func can_feed() -> bool:
	return Barn.has(FEED_CROP, 1)


## Takes one corn from the barn and starts the clock. False when there is
## no corn: the caller shows the corn, it does not scold.
static func feed(farm: Dictionary, now: int) -> bool:
	if not Barn.take(FEED_CROP, 1):
		return false
	var c := coop(farm)
	c["fed_at"] = now
	c["eggs"] = 0
	return true


## The eggs go to the barn by the same door every harvest uses, so a full
## barn spills them into the basket rather than losing them.
static func collect(farm: Dictionary) -> Dictionary:
	var c := coop(farm)
	var eggs := int(c.get("eggs", 0))
	if eggs <= 0:
		return {}
	c["eggs"] = 0
	c["fed_at"] = 0
	var receipt := Barn.store_harvest("egg", eggs)
	receipt["crop_id"] = "egg"
	receipt["amount"] = eggs
	return receipt
