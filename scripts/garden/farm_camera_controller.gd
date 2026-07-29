extends RefCounted
## Where the farm is being looked at from.
##
##     const FarmCamera := preload("res://scripts/garden/farm_camera_controller.gd")
##
## WHY THIS IS NOT A Camera2D
##
## There is not one anywhere in this game. Every screen is Controls positioned
## against get_viewport_rect().size, and a Camera2D moves the whole canvas --
## including the Controls, including the back button, including the seed rack.
## Keeping those still would mean a CanvasLayer, and CanvasLayer coordinates are
## a third coordinate space for two probes and DragField to get wrong.
##
## So the farm is one Node2D that this object positions and scales, the screen
## furniture is its sibling, and the conversion between the two is a function
## anybody can call with a number and check the answer of.
##
##
## WHY THE MATH IS HERE AND NOT IN THE SCREEN
##
## "The drag missed" and "the drag is broken" look identical, and this project
## has already lost an afternoon to that once (see garden_touch_probe's
## _glass()). Panning adds a second way for a coordinate to be wrong and no new
## way to see it. Every line below is arithmetic on two vectors and a float --
## no nodes, no viewport, no save -- so the probe can ask "after dragging 400px
## left at 0.8, where is bed 3" and be told a number.

const Layout := preload("res://scripts/garden/farm_layout.gd")

## How far a finger may travel and still count as a tap rather than a drag.
##
## A six-year-old's tap moves. Too small and every press on a bed scrolls the
## farm a little instead of doing the job; too large and a short deliberate
## drag does the job instead of scrolling. Half a thumb.
const TAP_SLOP := 22.0

## Where in the world the middle of the window is pointed.
var centre := Vector2.ZERO
var zoom := 1.0
## The rectangle on the glass the farm is drawn into, top bar and shelf removed.
var window := Rect2(0, 0, 1280, 456)

var _home_centre := Vector2.ZERO
var _home_zoom := 1.0
## The extra step BELOW the data's steps: far enough out that the whole world
## is on the glass at once. Computed from this window, not written in data --
## a taller window earns a closer overview. It is deliberately NOT in
## zoom_steps(): the seed-drag spacing rules key off the smallest PLANTING
## zoom (Layout.min_zoom()), and the overview is not a planting zoom -- a
## seed picked up out here steps the camera in first (see the world's
## ensure_planting_zoom), so no drag is ever measured at this distance.
var overview := 0.0


## Point it at the beds, as close in as it can get with all of them visible.
func look_at_the_beds(view: Vector2, top_bar: float, shelf: float,
		count: int) -> void:
	window = Layout.window_rect(view, top_bar, shelf)
	var world := Layout.world_size()
	overview = minf(window.size.x / maxf(world.x, 1.0),
		window.size.y / maxf(world.y, 1.0))
	_home_zoom = Layout.default_zoom(window.size, count)
	_home_centre = Layout.clamp_centre(Layout.default_centre(count),
		window.size, _home_zoom)
	go_home()


## Every zoom the buttons can reach: the whole-farm overview first (when the
## window earns one below the data's own floor), then the data's steps.
func all_steps() -> Array:
	var steps := Layout.zoom_steps()
	if overview > 0.0 and overview < float(steps[0]) - 0.005:
		return [overview] + steps
	return steps


## Back to the opening view. The way out of being lost, and the reason a double
## tap on bare grass is worth a gesture of its own.
func go_home() -> void:
	zoom = _home_zoom
	centre = _home_centre


func is_home() -> bool:
	return is_equal_approx(zoom, _home_zoom) and centre.is_equal_approx(_home_centre)


func world_to_screen(at: Vector2) -> Vector2:
	return (at - centre) * zoom + window.get_center()


func screen_to_world(at: Vector2) -> Vector2:
	return (at - window.get_center()) / maxf(zoom, 0.05) + centre


## Is this point on the glass inside the part of it the farm is drawn in?
## Everything outside belongs to the top bar or the shelf, which do not move.
func inside(at: Vector2) -> bool:
	return window.has_point(at)


## Drag the ground. `by` is how far the finger moved on the glass, so the world
## goes the other way -- the child is moving the ground under the window, which
## is what "drag the picture" means to everyone who has ever used a map.
func pan(by: Vector2) -> void:
	centre = Layout.clamp_centre(centre - by / maxf(zoom, 0.05),
		window.size, zoom)


## Step in or out one notch, keeping `anchor` (a point on the glass) over the
## same patch of ground. Returns whether anything moved.
##
## Anchoring matters: zooming around the middle of the window pulls whatever
## the child was looking at off to one side, and he has to find it again. The
## + and - buttons pass the middle of the window and get the plain behaviour.
func step_zoom(direction: int, anchor: Vector2) -> bool:
	var steps := all_steps()
	var here := 0
	for i in range(steps.size()):
		if is_equal_approx(float(steps[i]), zoom):
			here = i
	var want: int = clampi(here + signi(direction), 0, steps.size() - 1)
	if want == here:
		return false
	var ground := screen_to_world(anchor)
	zoom = float(steps[want])
	# Put that same patch of ground back under the finger, then obey the edges.
	centre = Layout.clamp_centre(
		ground - (anchor - window.get_center()) / zoom, window.size, zoom)
	return true


func can_zoom(direction: int) -> bool:
	var steps := all_steps()
	if direction < 0:
		return zoom > float(steps[0]) + 0.001
	return zoom < float(steps[steps.size() - 1]) - 0.001


## Slide the view until `at` (a point in the world) is in the middle of it --
## what tapping a building does. Nothing is opened by moving; the child sees
## where he is going.
func look_at(at: Vector2) -> void:
	centre = Layout.clamp_centre(at, window.size, zoom)


## Put the transform on the node that holds the farm.
func apply(world: Node2D) -> void:
	if not is_instance_valid(world):
		return
	world.scale = Vector2(zoom, zoom)
	world.position = window.get_center() - centre * zoom
