extends RefCounted
## Where everything in 星光农场 stands, and the arithmetic that says whether it
## can stand there.
##
##     const Layout := preload("res://scripts/garden/farm_layout.gd")
##
## Deliberately NOT a class_name, for the same reason as every other shared
## helper here: Godot only rebuilds the global class cache in the editor, so a
## new class name is a parse error on any machine that has not rescanned, and a
## parse error takes the whole game grey.
##
##
## WHY THE NUMBERS ARE IN A JSON FILE AND THE RULES ARE IN THIS ONE
##
## The positions are content -- they will be nudged a hundred times while the
## farm is being drawn, and nudging them should not mean touching code. The
## RULES about those positions are not content: "two beds may not be closer
## together than a dropped seed can reach" is a fact about a six-year-old's
## thumb, and it has to be computed rather than eyeballed.
##
## So data/farm_world_layout.json holds where things are, this file holds what
## makes a position legal, and tools_check.py runs the same arithmetic against
## the same file before anything is ever launched.
##
##
## EVERY FUNCTION HERE IS PURE
##
## Nothing below touches a node, a viewport or the save. That is what lets the
## probe ask "at the smallest zoom, how far apart are beds 3 and 4 on the
## glass" and get a number instead of a screenshot -- which is the only way
## this project has ever caught a spacing bug before a child did.

## How far apart two beds have to be ON THE GLASS, in the same terms the four-bed
## garden used: DragField clicks a released seed into any slot within SNAP, so
## two beds closer than twice that can both claim the same drop, and a child who
## watched his carrot land in the wrong bed has no way to move it. The margin on
## top is for the thumb -- releasing 40px off centre is normal.
const SCREEN_GAP_NEEDED := DragField.SNAP * 2.0 + 26.0

## How far apart two things a thumb can press have to be on the glass, when
## missing costs nothing worse than pressing the neighbour. Two aiming errors
## wide. Taken from 丰收行动, which arrived at it the hard way.
const THUMB_APART := 92.0

## How much bare glass has to be left between the outermost bed and the edge of
## the screen. A thumb reaching the very edge of a tablet is a thumb that hits
## the case, and the bezel eats the last few millimetres on top of that. The
## touch probe has insisted on this number since the four-bed garden.
const EDGE := 60.0

## Fallbacks, used only when the layout file is missing entirely. They are not
## a second copy of the design -- GameData shouts about an empty layout at boot
## -- they exist so that a missing file draws a small wrong farm instead of
## dividing by zero on the way to the first frame.
const FALLBACK := {
	"world": {"width": 2200, "height": 1150},
	"zoom_steps": [0.8, 1.0, 1.25],
	"plots": {"box": [220, 150], "across": 3, "gap": [360, 360],
		"first": [470, 420]},
	"expansion": {"first": [1550, 420], "gap": [0, 360], "count": 2},
	"facilities": [],
}


static func data() -> Dictionary:
	var raw: Dictionary = GameData.farm_layout
	return raw if raw.has("plots") else FALLBACK


static func _pair(from: Variant, fallback: Vector2) -> Vector2:
	if from is Array and (from as Array).size() >= 2:
		return Vector2(float(from[0]), float(from[1]))
	return fallback


static func world_size() -> Vector2:
	var w: Dictionary = data().get("world", {})
	return Vector2(float(w.get("width", 2200)), float(w.get("height", 1150)))


static func zoom_steps() -> Array:
	var steps: Array = data().get("zoom_steps", [])
	if steps.is_empty():
		return [1.0]
	var out: Array = []
	for step in steps:
		out.append(maxf(0.05, float(step)))
	out.sort()
	return out


static func min_zoom() -> float:
	return float(zoom_steps()[0])


static func plot_box() -> Vector2:
	return _pair(data().get("plots", {}).get("box", null), Vector2(220, 150))


static func plots_across() -> int:
	return maxi(1, int(data().get("plots", {}).get("across", 3)))


static func plot_gap() -> Vector2:
	return _pair(data().get("plots", {}).get("gap", null), Vector2(360, 360))


## The middle of bed `index`, in world coordinates.
##
## Beds past the ones the layout lays out in a grid -- the expansion plots --
## continue down their own column, because that is where the stones and the
## broken fence are drawn and a bed has to appear where the stone was moved
## from. Anything past those wraps on down the expansion column rather than
## being clamped, so a farm that somehow grows to twenty beds draws twenty beds
## somewhere rather than twenty beds on top of each other.
static func plot_at(index: int) -> Vector2:
	var grid := plots_across() * 2
	if index < grid:
		var first := _pair(data().get("plots", {}).get("first", null),
			Vector2(470, 420))
		var gap := plot_gap()
		return first + Vector2(
			float(index % plots_across()) * gap.x,
			float(index / plots_across()) * gap.y)
	var ex: Dictionary = data().get("expansion", {})
	var ex_first := _pair(ex.get("first", null), Vector2(1550, 420))
	var ex_gap := _pair(ex.get("gap", null), Vector2(0, 360))
	return ex_first + ex_gap * float(index - grid)


## How many beds this layout has drawn a place for. Beds beyond it still get a
## position from plot_at(); this is what the farm and tools_check compare
## against so that "the save has more beds than the ground has room for" is a
## question somebody can ask.
static func places_for_plots() -> int:
	return plots_across() * 2 + maxi(0,
		int(data().get("expansion", {}).get("count", 0)))


static func facilities() -> Array:
	return data().get("facilities", [])


static func facility(id: String) -> Dictionary:
	for f in facilities():
		if str(f.get("id", "")) == id:
			return f
	return {}


static func facility_at(f: Dictionary) -> Vector2:
	return _pair(f.get("at", null), Vector2.ZERO)


static func facility_size(f: Dictionary) -> Vector2:
	return _pair(f.get("size", null), Vector2(220, 150))


## The rectangle the child's own beds occupy, edges included.
##
## THE ONE RECTANGLE THAT DECIDES THE DEFAULT VIEW. A child who opens the farm
## and cannot see his beds has to go looking for them, and a six-year-old who
## drags the ground the wrong way twice concludes the game is broken. So the
## opening view is whatever zoom fits this box, and never anything closer.
static func bed_block(count: int) -> Rect2:
	var half := plot_box() * 0.5
	var box := Rect2(plot_at(0) - half, plot_box())
	for i in range(1, maxi(count, 1)):
		box = box.merge(Rect2(plot_at(i) - half, plot_box()))
	return box


## The window the world is drawn into, given the whole screen. The top bar and
## the shelf are screen furniture and do not move with the farm.
static func window_rect(view: Vector2, top_bar: float, shelf: float) -> Rect2:
	return Rect2(Vector2(0, top_bar),
		Vector2(view.x, maxf(120.0, view.y - top_bar - shelf)))


## The closest zoom at which every bed is still on the glass at once.
##
## Walks the steps from closest to furthest and takes the first that fits, so a
## roomier screen gets a bigger farm rather than the same small one. Falls back
## to the smallest step when nothing fits -- showing most of the farm beats
## showing a corner of it.
static func default_zoom(window: Vector2, count: int) -> float:
	var block := bed_block(count).size
	# Room for the beds AND for the margin either side. Leaving EDGE out of this
	# is not a rounding error: at 4:3 the window is 240px taller, the next zoom
	# step up fits by arithmetic, and the outermost bed's edge lands 25px from
	# the bezel -- reachable only by a thumb that is half off the tablet. The
	# touch probe caught it on the iPad shape and not on the 16:9 one, which is
	# exactly the pair of screens this project keeps getting wrong.
	var room := window - Vector2(EDGE, EDGE) * 2.0
	var steps := zoom_steps()
	for i in range(steps.size() - 1, -1, -1):
		var z := float(steps[i])
		if block.x * z <= room.x and block.y * z <= room.y:
			return z
	return float(steps[0])


static func default_centre(count: int) -> Vector2:
	return bed_block(count).get_center()


## Where the camera's centre is allowed to be, so that the edge of the world is
## never dragged into the middle of the screen. When the world is smaller than
## the window in one direction, that direction is pinned to the middle: there
## is nothing out there to look at, and letting it slide is letting a child
## lose his farm.
static func centre_limits(window: Vector2, zoom: float) -> Rect2:
	var world := world_size()
	var visible := window / maxf(zoom, 0.05)
	var half := visible * 0.5
	var lo := Vector2(minf(half.x, world.x * 0.5), minf(half.y, world.y * 0.5))
	var hi := Vector2(maxf(world.x - half.x, world.x * 0.5),
		maxf(world.y - half.y, world.y * 0.5))
	return Rect2(lo, hi - lo)


static func clamp_centre(centre: Vector2, window: Vector2, zoom: float) -> Vector2:
	var limits := centre_limits(window, zoom)
	return Vector2(
		clampf(centre.x, limits.position.x, limits.end.x),
		clampf(centre.y, limits.position.y, limits.end.y))


# --- the rules, asked as questions anything can ask ------------------------

## How far apart two beds have to be IN THE WORLD.
##
## This is the whole reason the spacing could quietly break. DragField.SNAP is
## measured on the GLASS, and the world can now be zoomed out -- so the same
## world distance buys fewer screen pixels at 0.8 than at 1.0, and a layout that
## was safe at full zoom starts letting seeds land in the wrong bed the moment
## a child pinches out. The gap therefore has to clear the screen rule at the
## SMALLEST zoom, which is what dividing by it does.
static func world_gap_needed() -> float:
	return SCREEN_GAP_NEEDED / min_zoom()


## Everything wrong with this layout, as sentences. Empty means it is legal.
##
## Returned rather than pushed as errors so that the probe, tools_check and the
## farm itself can all ask the same question and each do its own thing with the
## answer -- one rule, three readers, no second copy to drift.
static func problems(count: int) -> Array:
	var out: Array = []
	var gap := plot_gap()
	var needed := world_gap_needed()
	if gap.x < needed or gap.y < needed:
		out.append(("beds are %.0fx%.0f apart in the world and need %.0f: "
			+ "at the smallest zoom (%.2f) that is %.0fpx on the glass, and "
			+ "DragField snaps a dropped seed within %.0fpx")
			% [gap.x, gap.y, needed, min_zoom(),
				minf(gap.x, gap.y) * min_zoom(), DragField.SNAP])

	if count > places_for_plots():
		out.append("the save has %d beds and the layout has room for %d"
			% [count, places_for_plots()])

	# Every bed inside the world, so nothing can be dragged to and never found.
	var half := plot_box() * 0.5
	var world := world_size()
	for i in range(count):
		var at := plot_at(i)
		if at.x - half.x < 0.0 or at.y - half.y < 0.0 \
				or at.x + half.x > world.x or at.y + half.y > world.y:
			out.append("bed %d is at %s, partly outside the %s world"
				% [i + 1, str(at), str(world)])

	# Two things a thumb can press, too close together. Beds are already covered
	# by the seed rule above, so this is facilities against each other and
	# against beds -- and it is measured on the glass at the smallest zoom,
	# because that is where everything is nearest.
	var pressable: Array = []
	for i in range(count):
		pressable.append(["bed %d" % (i + 1), plot_at(i)])
	for f in facilities():
		pressable.append([str(f.get("id", "?")), facility_at(f)])
	for a in range(pressable.size()):
		for b in range(a + 1, pressable.size()):
			var apart: float = (pressable[a][1] as Vector2).distance_to(
				pressable[b][1]) * min_zoom()
			if apart < THUMB_APART:
				out.append(("%s and %s are %.0fpx apart on the glass at the "
					+ "smallest zoom; a thumb needs %.0f")
					% [pressable[a][0], pressable[b][0], apart, THUMB_APART])
	return out
