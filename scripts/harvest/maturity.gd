extends RefCounted
## How ripe a thing is, said five different ways at once.
##
##     const Maturity := preload("res://scripts/harvest/maturity.gd")
##
##
## WHY FIVE CHANNELS AND NOT A COLOUR
##
## "Pick the red ones" is a colour test, and roughly one boy in twelve cannot
## take it. Colour is one of the five ways a target says how ripe it is, and it
## is never the only one:
##
##   size     an unripe thing is visibly smaller
##   colour   greener when unripe, its own colour when ready
##   halo     ready wears a soft ring; golden wears a star
##   motion   ready sways; unripe sits still
##   voice    the helper says which one to look for
##
## A child who cannot see the colour difference can still see that one is
## bigger, moving, and ringed. That is the point of doing it five times.
##
##
## WHY THE FOUR STEPS ARE DERIVED AND NOT DRAWN
##
## The art pack has one picture per crop, not four. Four hand-drawn ripeness
## steps for fifteen crops is sixty drawings, and the moment a sixteenth crop
## arrives it is sixty-four. So a step is the one picture with a scale, a tint
## and a halo applied -- which costs nothing per crop and cannot fall out of
## step with the art.
##
## The honest cost: "unripe" reads as a small green version of the finished
## thing rather than as a real young fruit. For a six-year-old being asked
## "which ones are ready", that is the question being asked anyway. If it ever
## needs to be real art, a crop can override `maturity_visuals` in
## harvest_crops.json and nothing else changes.

const UNRIPE := "unripe"
const ALMOST := "almost_ready"
const READY := "ready"
const GOLDEN := "golden"
const ALL := [UNRIPE, ALMOST, READY, GOLDEN]

## The two that an order will accept by default. Everything else is scenery
## that has to be left alone.
const PICKABLE := [READY, GOLDEN]

## scale, tint, halo -- per step, shared by every crop unless it says otherwise.
const LOOK := {
	# The tints are PALE, not dark, and that is the whole of what was wrong with
	# the first cut. `modulate` multiplies, so tinting a red strawberry with a
	# strong green gives a dark brown-red -- and dark red says OVERripe to a
	# child, which is the opposite of what an unripe berry has to say. Washed
	# out and small reads as "not yet" on every base colour in the pack; deep
	# and saturated reads as "extra ready" on the red ones.
	# `wash` is a second copy of the same picture laid over the first, so it
	# paints only where the crop is and turns a red strawberry GREEN.
	#
	# `tint` alone cannot do that. modulate multiplies, so a green tint on a red
	# berry gives dark brown-red -- and dark red says OVERripe to a child, which
	# is the exact opposite of what an unripe one has to say. The first cut did
	# that and the unripe berries looked like extra-ripe small ones.
	UNRIPE: {"scale": 0.60, "tint": Color(0.86, 1.0, 0.86), "halo": "none",
		"sway": 0.0, "wash": Color(0.32, 0.72, 0.28, 0.80)},
	ALMOST: {"scale": 0.80, "tint": Color(0.94, 1.0, 0.90), "halo": "none",
		"sway": 0.0, "wash": Color(0.55, 0.78, 0.30, 0.42)},
	READY: {"scale": 1.0, "tint": Color(1, 1, 1), "halo": "soft",
		"sway": 3.5, "wash": Color(0, 0, 0, 0)},
	GOLDEN: {"scale": 1.06, "tint": Color(1.0, 0.92, 0.55), "halo": "star",
		"sway": 5.0, "wash": Color(0, 0, 0, 0)},
}


## Is this one allowed to be picked for this order?
static func pickable(step: String, allowed: Array = []) -> bool:
	if allowed.is_empty():
		return step in PICKABLE
	return step in allowed


static func look(step: String, crop: Dictionary = {}) -> Dictionary:
	var base: Dictionary = LOOK.get(step, LOOK[READY]).duplicate()
	var override: Dictionary = crop.get("maturity_visuals", {})
	if override.has(step) and override[step] is Dictionary:
		for key in (override[step] as Dictionary).keys():
			base[key] = override[step][key]
	return base


## A step nothing answers to is treated as unripe, not as ready.
##
## The safe direction. A damaged save or a typo in a level makes something
## un-pickable and visibly small, which is noticed in one play; the other way
## round it makes something free to take, which is not noticed at all.
static func normalise(step: String) -> String:
	return step if step in ALL else UNRIPE
