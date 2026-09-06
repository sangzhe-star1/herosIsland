extends RefCounted
## Was that the right move? Five questions, asked of a list of points.
##
##     const Gesture := preload("res://scripts/harvest/gesture.gd")
##     Gesture.satisfied("drag", params, track, centre)
##
##
## WHY FIVE AND NOT NINETEEN
##
## The harvest catalogue names nineteen gestures across fifty-six crops:
## pull_up, dig_search, tap_collect, twist, cut_stem, cut_cluster, swipe_cut,
## shake_tree, open_pod, swipe_down, roll_to_basket, tap_pair, tap_cluster,
## tap_bundle, tap_seeds, memory_pick, match_color, charge_then_cut,
## pull_timing.
##
## Sorted by what the FINGER actually does, there are five:
##
##   tap     it went down and came up in the same place
##   drag    it went in a direction, far enough           pull_up, swipe_down,
##                                                        open_pod, roll_to_basket
##   twist   it went round the target far enough          twist
##   line    it crossed a line                            cut_stem, swipe_cut,
##                                                        cut_cluster
##   sweep   it changed direction N times                 dig_search, shake_tree
##
## Nineteen match arms would become nineteen separately-evolving bugs. The crop
## data still says `pull_up` -- that word is what a level designer thinks in --
## and one table maps it here.
##
##
## WHY THESE ARE PURE FUNCTIONS ON A LIST OF POINTS
##
## The same reason the garden's growth arithmetic is: a tolerance is a NUMBER,
## and a number can be tested. "Does a drag 34 degrees off vertical still count,
## and does one 36 degrees off not" is two lines here and an afternoon of
## poking at a tablet otherwise. Nothing below touches a node, a screen or an
## input event.

## What the recognisers are called, so a typo in a data file is catchable.
const TAP := "tap"
const DRAG := "drag"
const TWIST := "twist"
const LINE := "line"
const SWEEP := "sweep"
const ALL := [TAP, DRAG, TWIST, LINE, SWEEP]

## A press that moved less than this is a tap, not a very short drag. Roughly a
## six-year-old's finger wobble on a tablet held in one hand.
const TAP_SLOP := 26.0


## The one entry point. `track` is every point from press to release, in the
## play area's coordinates; `centre` is where the target sits.
##
## An unknown recogniser returns FALSE and never true: a gesture nothing
## understands must refuse, not succeed. A crop whose data says a recogniser
## that has not been written yet is then simply un-pickable, which is visible
## in one play -- where "quietly succeeds on any touch" would not be.
static func satisfied(recogniser: String, params: Dictionary,
		track: PackedVector2Array, centre: Vector2) -> bool:
	match recogniser:
		TAP:
			return tap_ok(track)
		DRAG:
			return drag_ok(track,
				Vector2(float(params.get("direction_x", 0.0)),
					float(params.get("direction_y", -1.0))),
				float(params.get("distance", 90.0)),
				float(params.get("angle", 35.0)))
		TWIST:
			return twist_ok(track, centre, float(params.get("turn", 90.0)))
		LINE:
			return line_ok(track, centre, float(params.get("line_half_width", 74.0)))
		SWEEP:
			return sweep_ok(track, int(params.get("turns", 3)),
				float(params.get("leg", 60.0)))
	return false


## A short, legible example of a gesture the recogniser will genuinely accept.
##
## This is deliberately beside `satisfied()` rather than in the tutorial or a
## probe. The catalogue already owns the recogniser and its tuned parameters;
## a child must never be shown a second, approximate version of that rule.
## `reach` only keeps circular demonstrations inside the target's generous
## touch area -- it is not a new gameplay tolerance.
static func demo_path(recogniser: String, params: Dictionary,
		centre: Vector2, reach: float = 78.0) -> PackedVector2Array:
	match recogniser:
		TAP:
			return PackedVector2Array([centre])
		DRAG:
			var direction := Vector2(float(params.get("direction_x", 0.0)),
				float(params.get("direction_y", -1.0)))
			if direction.length() < 0.001:
				direction = Vector2.UP
			else:
				direction = direction.normalized()
			return _line(centre, centre + direction
				* (float(params.get("distance", 90.0)) + 24.0), 7)
		LINE:
			# Crossing both sides of the horizontal stem is what line_ok asks;
			# a downward point from its centre only *looks* like cutting.
			var half := float(params.get("line_half_width", 74.0))
			var side := minf(30.0, half * 0.4)
			return _line(centre + Vector2(-side, -46.0),
				centre + Vector2(side, 46.0), 7)
		SWEEP:
			# `turns` means reversals, so it needs one more real leg than that
			# number. The small margin makes a video demonstration robust at the
			# same difficulty setting a child is currently playing.
			var leg := float(params.get("leg", 60.0)) + 26.0
			var turns := maxi(int(params.get("turns", 3)), 1)
			var sweep_path := PackedVector2Array([centre])
			var here := centre
			for i in range(turns + 1):
				var next := here + Vector2(leg if i % 2 == 0 else -leg, 0.0)
				for point in _line(here, next, 3):
					sweep_path.append(point)
				here = next
			return sweep_path
		TWIST:
			# A visible arc, not a diagonal arrow. The extra 60 degrees leaves
			# room for a finger that rounds the circle less precisely than ours.
			var turn := float(params.get("turn", 90.0))
			var arc := maxf(turn + 60.0, 120.0)
			var steps := maxi(int(ceil(arc / 20.0)) + 3, 6)
			var radius := clampf(reach * 0.75, 42.0, 62.0)
			var twist_path := PackedVector2Array()
			for i in range(steps + 1):
				var angle := TAU * arc / 360.0 * float(i) / float(steps)
				twist_path.append(centre + Vector2(cos(angle), sin(angle)) * radius)
			return twist_path
	return PackedVector2Array([centre])


## Down and up in the same place.
static func tap_ok(track: PackedVector2Array) -> bool:
	if track.size() == 0:
		return false
	return _travel(track) <= TAP_SLOP


## Went that way, and went far enough.
##
## Measured from the FIRST point to the LAST, not along the path: a child
## pulling a carrot up wanders sideways on the way, and the wander is not the
## gesture. `angle` is the half-angle either side of the wanted direction --
## 35 means anything inside a 70-degree fan counts.
static func drag_ok(track: PackedVector2Array, direction: Vector2,
		distance: float, angle: float) -> bool:
	if track.size() < 2:
		return false
	var moved: Vector2 = track[track.size() - 1] - track[0]
	if moved.length() < distance:
		return false
	if direction.length() < 0.001:
		return true                      # any direction will do
	return rad_to_deg(moved.angle_to(direction)) <= angle \
		and rad_to_deg(moved.angle_to(direction)) >= -angle


## Went round it far enough, either way.
##
## Total turn, summed as signed steps, then taken as an absolute -- so a child
## who wobbles back and forth does not accumulate a quarter turn out of noise,
## and one who turns anticlockwise is not told they turned the wrong way.
## Nobody is asked to draw a circle: any path around the target adds up.
static func twist_ok(track: PackedVector2Array, centre: Vector2,
		turn: float) -> bool:
	if track.size() < 3:
		return false
	var total := 0.0
	for i in range(1, track.size()):
		var a: Vector2 = track[i - 1] - centre
		var b: Vector2 = track[i] - centre
		# A point on top of the target has no angle. Skipping it is right:
		# the finger passing over the middle should not spin the reading.
		if a.length() < 4.0 or b.length() < 4.0:
			continue
		total += a.angle_to(b)
	return absf(rad_to_deg(total)) >= turn


## Crossed the cutting line.
##
## The line is horizontal through the target -- it is drawn on screen as a
## glowing stem, and the shears snap to it. What counts is going from one side
## to the other anywhere within `line_half_width` of the middle, at any angle.
## Following the line lengthwise does NOT count: that is a stroke along the
## stem, not through it.
static func line_ok(track: PackedVector2Array, centre: Vector2,
		half_width: float) -> bool:
	if track.size() < 2:
		return false
	var above := false
	var below := false
	for point in track:
		if absf(point.x - centre.x) > half_width:
			continue
		if point.y < centre.y:
			above = true
		elif point.y > centre.y:
			below = true
	return above and below


## Changed direction enough times, with real travel between each change.
##
## Digging and shaking are both "waggle it": what makes them feel like work is
## the number of REVERSALS, not the distance. `leg` is how far the finger has
## to travel between one reversal and the next -- without it, a fingertip
## trembling on the spot would dig up a whole field.
static func sweep_ok(track: PackedVector2Array, turns: int, leg: float) -> bool:
	if track.size() < 3 or turns <= 0:
		return false
	var reversals := 0
	var heading := 0.0                   # -1 left, +1 right, 0 not moving yet
	var run := 0.0
	for i in range(1, track.size()):
		var dx: float = track[i].x - track[i - 1].x
		if absf(dx) < 0.5:
			continue
		var way: float = signf(dx)
		if heading == 0.0:
			heading = way
			run = absf(dx)
			continue
		if way == heading:
			run += absf(dx)
			continue
		# A change of direction only counts if the leg before it was a real
		# stroke rather than a wobble.
		if run >= leg:
			reversals += 1
		heading = way
		run = absf(dx)
	return reversals >= turns


static func _travel(track: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, track.size()):
		total += track[i].distance_to(track[i - 1])
	return total


## One shared interpolation helper keeps the probe's thumb and the tutorial's
## painted finger on the same deliberate, easy-to-see path.
static func _line(from: Vector2, to: Vector2, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := maxi(steps, 1)
	for i in range(count + 1):
		out.append(from.lerp(to, float(i) / float(count)))
	return out
