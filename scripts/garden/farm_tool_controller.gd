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
const PlotCare := preload("res://scripts/garden/farm_plot_care_controller.gd")
const PlotPlanting := preload("res://scripts/garden/farm_plot_planting_controller.gd")
const PlotTilling := preload("res://scripts/garden/farm_plot_tilling_controller.gd")

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

## Kept beside the tool truth, but separate from TOOLS because tools_check.py
## deliberately parses the latter as a strict compatibility table.
const LABEL_KEYS := {
	HAND: "garden.tool.hand",
	"shovel": "garden.tool.shovel",
	"seed": "garden.tool.seed",
	"water": "garden.tool.water",
	"weed": "garden.tool.weed",
	"bug": "garden.tool.bug",
	"basket": "garden.tool.basket",
}

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


func label_key(tool_id: String) -> String:
	return str(LABEL_KEYS.get(tool_id, "garden.tool.hand"))


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


## Apply one tool's plot-state transition and return its presentation event.
##
## The screen still decides when time or the lesson's rare-gold rule applies,
## then owns the save and the sound or animation. This controller joins that
## context with the existing till, plant, and care transitions so a tap, a
## brush stroke, and the first-lesson hint cannot grow separate rule tables.
## The basket deliberately stays with the harvest transaction controller:
## picking also claims a receipt and settles storage, so it is not a plot-only
## action.
func apply_to_plot(tool_id: String, plot: Dictionary, now: int = 0,
		crop_id: String = "", growth_override_seconds: int = 0,
		golden: bool = false) -> Dictionary:
	if tool_id == HAND:
		# A damaged save can contain an unknown care marker. Preserve the old
		# quiet repair path when the hand taps that bed; recognized jobs always
		# resolve to their own tool via tool_for().
		if str(plot.get("state", Farm.EMPTY)) == Farm.NEEDS_CARE:
			var repaired: Dictionary = PlotCare.apply(plot, now)
			if str(repaired.get("action", "")) == PlotCare.REPAIR:
				return repaired
		return {}
	if not needs(tool_id, plot):
		return {}
	match tool_id:
		"shovel":
			var tilled := PlotTilling.till(plot)
			return {"plot": tilled, "action": "till"} if not tilled.is_empty() else {}
		"seed":
			var planted := PlotPlanting.plant(plot, crop_id, now,
				growth_override_seconds, golden)
			return {"plot": planted, "action": "plant"} if not planted.is_empty() else {}
		"water", "weed", "bug":
			return PlotCare.apply(plot, now)
		_:
			return {}


func work_exists(tool_id: String, plots: Array) -> bool:
	for plot in plots:
		if needs(tool_id, plot):
			return true
	return false


## Which brush answers this plot right now. The task ribbon and tool rack must
## never each carry a private state-to-tool table: a new care event belongs in
## needs() once and then reaches both of them.
func tool_for(plot: Dictionary) -> String:
	for tool in TOOLS:
		var tool_id := str(tool.get("id", ""))
		if needs(tool_id, plot):
			return tool_id
	return HAND


## The one plot that is worth drawing a child's eye to. This is intentionally
## a static, side-effect-free ordering for the garden's ribbon and hint flow.
## A turned bed comes before untouched grass: after he has dug, planting the
## seed is the natural next beat, not a request to dig a different hole.
static func next_action_index(plots: Array) -> int:
	for want in [Farm.READY, Farm.NEEDS_CARE, Farm.TILLED, Farm.EMPTY]:
		for i in range(plots.size()):
			if str(plots[i].get("state", "")) == want:
				return i
	return -1


## The crop the seed brush would plant right now: the chosen one if he chose
## and still owns it, otherwise the first one he owns. Never "" while anything
## is unlocked -- a seed brush that plants nothing is a broken brush.
func crop_to_plant(unlocked: Array) -> String:
	if seed_crop != "" and seed_crop in unlocked:
		return seed_crop
	return str(unlocked[0]) if not unlocked.is_empty() else ""
