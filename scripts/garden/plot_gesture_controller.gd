extends RefCounted
## The plot gesture grammar, separated from the screen's action side effects.
##
## A screen asks whether a bed should catch a gesture, then asks what that
## gesture means after the finger lifts. This controller owns both answers so
## a change to a care move or crop move cannot make the hit test and judge
## disagree. It knows nothing about saves, animation, sound, or camera motion.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const HarvestCrops := preload("res://scripts/harvest/harvest_crops.gd")

const CARE := "care"
const HARVEST := "harvest"
const PAN := "pan"
const NONE := "none"

## A tap remains available for every care action. These moves add expression;
## they never gate care behind a gesture the child must get right.
const CARE_MOVES := {
	"weeds": {"recogniser": "drag",
		"params": {"direction_x": 0.0, "direction_y": -1.0,
			"distance": 90.0, "angle": 40.0}},
	"bug": {"recogniser": "sweep",
		"params": {"turns": 2, "leg": 50.0}},
	"thirsty": {"recogniser": "drag",
		"params": {"direction_x": 0.0, "direction_y": 1.0,
			"distance": 90.0, "angle": 40.0}},
}


## Is this bed eligible for a gesture when the finger lands?
static func wants_gesture(plot: Dictionary, harvesting: bool) -> bool:
	if harvesting:
		return false
	match str(plot.get("state", "")):
		Farm.READY:
			return not HarvestCrops.gesture_for(
				str(plot.get("crop_id", ""))).is_empty()
		Farm.NEEDS_CARE:
			return CARE_MOVES.has(str(plot.get("care_event", "")))
	return false


## Judge the bed as it exists at release time. A failed recognised move is a
## camera pan; an ineligible or locked bed is left to the world controller.
static func judge(plot: Dictionary, harvesting: bool,
		track: PackedVector2Array, centre: Vector2) -> String:
	if not wants_gesture(plot, harvesting):
		return NONE
	if str(plot.get("state", "")) == Farm.NEEDS_CARE:
		var care: Dictionary = CARE_MOVES.get(
			str(plot.get("care_event", "")), {})
		if Gesture.satisfied(str(care["recogniser"]), care["params"],
				track, centre):
			return CARE
		return PAN
	var move := HarvestCrops.gesture_for(str(plot.get("crop_id", "")))
	if Gesture.satisfied(str(move["recogniser"]),
			move["gesture_params"], track, centre):
		return HARVEST
	return PAN
