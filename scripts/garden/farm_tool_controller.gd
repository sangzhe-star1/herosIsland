extends RefCounted
## Which tool is in the child's hand, and what each tool is FOR.
##
##     const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
##
## THE HAND COMES FIRST, AND THE HAND IS THE OLD GAME
##
## The four-bed garden's whole interaction was "a bed has one thing it wants,
## and tapping it does that" -- no tool to pick, so no way to pick wrong, which
## matters because "watering with the trowel, nothing happening, no idea why"
## is exactly the failure a six-year-old cannot debug. That rule was decided
## once and it stays: the first tool is the hand, it is selected by default,
## it can NEVER grey out, and while it is held every tap does what it always
## did. The six tools after it are additions for a child who has more beds
## than taps -- brushes that do one job to every bed they are swept across.
##
##
## WHY A TOOL WITH NO WORK IS GREY
##
## A tool that can be picked up and then does nothing teaches him that tools
## sometimes do nothing. Grey says "no thirsty beds today" before he commits,
## the same way the order cards grey out when the barn cannot fill them. And
## the moment a tool FINISHES its last job it goes grey in his hand -- so the
## hand comes back on its own (see garden_screen._auto_return) rather than
## leaving him holding a dead watering can.
##
## This file holds no nodes and draws nothing: it is the table of tools, who
## needs them, and which one is in hand. The screen draws it; the world sweeps
## it; both ask here.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")

const HAND := "hand"

## The rack, in the order it is drawn. `icon` must be something IconLibrary can
## draw -- tools_check refuses the table otherwise, because a button that
## renders as nothing is a button a child cannot find. `voice` is the line said
## when the tool is picked up; the words live in docs/VOICE_SCRIPT.md and the
## recording arrives whenever it arrives (a missing file is silent by design).
const TOOLS := [
	{"id": "hand", "icon": "tap", "voice": ""},
	{"id": "shovel", "icon": "shovel", "voice": "farm_tool_shovel"},
	{"id": "seed", "icon": "seed", "voice": "farm_tool_seed"},
	{"id": "water", "icon": "watering_can", "voice": "farm_tool_water"},
	{"id": "weed", "icon": "weed", "voice": "farm_tool_weed"},
	{"id": "bug", "icon": "fan", "voice": "farm_tool_bug"},
	{"id": "basket", "icon": "basket", "voice": "farm_tool_basket"},
]

var selected := HAND

## Which crop the seed brush plants. Chosen by tapping a tile on the rack --
## the same rack the classic drag plants from, so there is one place seeds
## live, not two. "" means "the first crop he owns".
var seed_crop := ""


func is_brush() -> bool:
	return selected != HAND


func tool_data(tool_id: String) -> Dictionary:
	for tool in TOOLS:
		if str(tool.get("id", "")) == tool_id:
			return tool
	return {}


## Does this ONE bed, right now, need this tool?
##
## This is gate two of the brush (gate one -- "not twice in one stroke" --
## lives in continuous_action_controller). It is also the greying rule and the
## auto-return rule, which is the point of it being one function: the button
## greys for exactly the beds the brush would skip, and no third copy of "what
## counts as thirsty" can drift.
func needs(tool_id: String, plot: Dictionary) -> bool:
	var state := str(plot.get("state", Farm.EMPTY))
	var care := str(plot.get("care_event", ""))
	match tool_id:
		"shovel":
			return state == Farm.EMPTY
		"seed":
			return state == Farm.TILLED
		"water":
			return care == Growth.CARE_THIRSTY
		"weed":
			return care == Growth.CARE_WEEDS
		"bug":
			return care == Growth.CARE_BUG
		"basket":
			return state == Farm.READY
	return false          # the hand is not a brush; it never "needs"


func work_exists(tool_id: String, plots: Array) -> bool:
	for plot in plots:
		if needs(tool_id, plot):
			return true
	return false


## The crop the seed brush would plant right now: the chosen one if he chose
## and still owns it, otherwise the first one he owns. Never "" while anything
## is unlocked -- a seed brush that plants nothing is a broken brush.
func crop_to_plant(unlocked: Array) -> String:
	if seed_crop != "" and seed_crop in unlocked:
		return seed_crop
	return str(unlocked[0]) if not unlocked.is_empty() else ""
