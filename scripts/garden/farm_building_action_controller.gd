extends RefCounted
## Resolve what a press on a farm building means.
##
## This is the progression boundary between a world hit target and the screen
## action it opens. The screen still owns scene changes, panels, sounds, and
## saves; this controller owns panel routing, unlock gates, and visit-board
## read state.

const Layout := preload("res://scripts/garden/farm_layout.gd")

const PANEL := "panel"
const FACILITY := "facility"
const WISH := "wish"
const START_LEVEL := "start_level"
const LOCKED := "locked"

const PANELS := {
	"orders": "orders",
	"seed_shop": "shop",
	"market": "market",
	"warehouse": "barn",
	"bear_door": "gift",
	"visit_board": "visits",
}

const TIMED_FACILITIES := ["coop", "mill", "cow_shed", "beehive"]


## `deco_room_exists` is supplied by the screen because only it owns the
## active level's config and the loaded level catalogue.
static func press(building_id: String, farm: Dictionary, level: int,
		master_farmer: bool, deco_room: String = "",
		deco_room_exists: bool = false) -> Dictionary:
	if PANELS.has(building_id):
		var needs_save := false
		if building_id == "visit_board" \
				and bool(farm.get("visit_log_unread", false)):
			farm["visit_log_unread"] = false
			needs_save = true
		return {"kind": PANEL, "panel": str(PANELS[building_id]),
			"needs_save": needs_save}
	if building_id in TIMED_FACILITIES:
		return {"kind": FACILITY, "facility_id": building_id}
	if building_id == "well":
		return {"kind": WISH} if master_farmer else _locked("water")
	if building_id == "workshop":
		var required := int(Layout.facility("workshop").get("level", 5))
		return {"kind": PANEL, "panel": "kitchen", "needs_save": false} \
			if level >= required else _locked()
	if building_id == "decor":
		var required := int(Layout.facility("decor").get("level", 4))
		if level >= required and deco_room != "" and deco_room_exists:
			return {"kind": START_LEVEL, "level_id": deco_room}
		return _locked()
	return _locked()


static func _locked(cue: String = "pop") -> Dictionary:
	return {"kind": LOCKED, "cue": cue}
