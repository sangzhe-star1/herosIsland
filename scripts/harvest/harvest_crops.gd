extends RefCounted
## The harvest catalogue, looked up by id.
##
##     const Crops := preload("res://scripts/harvest/harvest_crops.gd")
##     Crops.get_crop("carrot")
##
## A thin reader over GameData.harvest_crops, so nothing has to loop over the
## list at every call site and every caller gets the same answer for a crop id
## nothing knows about: an empty dictionary, never null.
const Maturity := preload("res://scripts/harvest/maturity.gd")


static func get_crop(crop_id: String) -> Dictionary:
	if crop_id == "":
		return {}
	for crop in GameData.harvest_crops:
		if str(crop.get("id", "")) == crop_id:
			return crop
	return {}


static func exists(crop_id: String) -> bool:
	return not get_crop(crop_id).is_empty()


## The move this crop asks for, as the recogniser that can judge it.
##
##     Crops.gesture_for("carrot")  # {"recogniser": "drag", "gesture_params": {...}}
##
## The farm's beds read this so that pulling a carrot up in the GARDEN is the
## same move pulling one up in 丰收行动 -- one catalogue, one grammar. Returns
## {} for a crop the catalogue does not know, and the caller treats that as
## "tap only": an unreadable gesture must never become an unreadable bed.
static func gesture_for(crop_id: String) -> Dictionary:
	var crop := get_crop(crop_id)
	if crop.is_empty() or str(crop.get("recogniser", "")) == "":
		return {}
	return {
		"harvest_gesture": str(crop.get("harvest_gesture", "")),
		"recogniser": str(crop.get("recogniser", "")),
		"gesture_params": crop.get("gesture_params", {}),
	}
