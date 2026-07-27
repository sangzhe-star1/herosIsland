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
