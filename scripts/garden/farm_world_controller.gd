extends Node2D
## 星光农场 as a place: ground you can drag, buildings you can walk the camera
## to, and beds standing on the earth rather than sitting in cards.
##
## WHAT THIS OWNS AND WHAT IT DOES NOT
##
## It owns everything that MOVES WITH THE FARM -- the ground, the buildings, the
## beds. It owns none of the screen furniture: the back button, the purse and
## the seed rack are the screen's, they stay still, and they are drawn by
## garden_screen.gd as this node's siblings.
##
## It decides nothing about the game. A press on a bed is reported upwards and
## garden_screen answers it, which is what keeps "one tap does the one thing
## this bed wants" in the one place it has always been.
##
##
## THE ONE RULE THAT MAKES A MOVING WORLD SAFE FOR A SIX-YEAR-OLD
##
## He must never be able to lose his farm. Three things enforce that and all
## three are cheap:
##
##   1. the opening view is the closest zoom at which EVERY bed is visible,
##      computed rather than chosen (Layout.default_zoom)
##   2. the camera cannot be dragged past the edge of the world at any zoom
##      (Layout.clamp_centre)
##   3. two taps on bare grass put it back exactly where it started
##
## Without those, "drag the ground" is a way to end up looking at an empty
## corner with no idea which way home is, and a child who gets there once does
## not come back to the farm.

signal plot_pressed(index: int)
signal facility_pressed(id: String)
## A press on land that is still under stones: the expansion slot for bed
## `index`. The screen answers it -- with a confirm card, a star badge, or a
## purse wobble -- the world only reports that the stones were pressed.
signal expansion_pressed(index: int)
signal camera_moved()
## A brush stroke: swept fires for the bed the stroke starts on and for every
## bed it passes over after that -- including the same bed again, deliberately.
## Whether a bed is worked on TWICE is the stroke bookkeeping's decision
## (continuous_action_controller), not the gesture's: the gesture reports what
## the finger did, and the finger really did cross that bed again.
signal stroke_swept(index: int)
signal stroke_ended()
## A tap nothing above claimed -- not a bed, not a building, not the stones.
## Glass coordinates. The screen uses it to let the FURNITURE answer last:
## decorations may only ever receive the taps nobody else was asked for,
## which is what keeps "furniture never swallows a tap meant for a plot"
## literally true.
signal grass_pressed(at: Vector2)
## The rain cloud was let go over this thirsty bed.
signal cloud_rained(index: int)
## A drag that began on a bed the screen says wants a pull: the finger is
## trying that crop's move. `offset` is how far it has travelled from the
## press, in glass pixels -- the bed leans with it while the drag lasts.
signal gesture_moved(index: int, offset: Vector2)
## That drag ended. `track` is every glass point from press to release,
## `centre` is the bed's centre on the glass, `net` is last-minus-first. The
## SCREEN judges the move against the crop's recogniser and owns both outcomes
## -- pick it, or rule "that was a pan after all" -- because which crops ask
## for which move is catalogue knowledge, not world knowledge.
signal gesture_finished(index: int, track: PackedVector2Array, centre: Vector2,
	net: Vector2)

const Layout := preload("res://scripts/garden/farm_layout.gd")
const FarmCamera := preload("res://scripts/garden/farm_camera_controller.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Coop := preload("res://scripts/garden/farm_coop_manager.gd")
const Maker := preload("res://scripts/garden/farm_maker_manager.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")
const Dog := preload("res://scripts/garden/farm_dog_controller.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const FarmWorldArt := preload("res://scripts/garden/farm_world_art.gd")

## How long between two presses on the grass still counts as a double tap.
## Generous: a six-year-old's second tap is not fast.
const DOUBLE_TAP := 0.55

var camera := FarmCamera.new()

## True while a seed is in the air. The farm does not move then -- a rebuild or
## a pan mid-drag takes the carrot out of his hand with nothing on screen to
## explain it, which is the same accident the four-bed garden already guards
## against in _queue_rebuild().
var locked := false

## Screen furniture standing OVER the farm's window: the zoom buttons, an open
## order board, the rest card. Their presses belong to the GUI -- but
## Node._input runs BEFORE the GUI, so without this list a press on the +
## button would ALSO be a tap on whatever ground happens to be drawn under it,
## and pressing it twice would be a double tap on grass, which is the go-home
## gesture. A camera that jumps because a child zoomed twice is a farm that
## teleports under his finger.
##
## Nodes rather than rectangles, deliberately: a rectangle would have to be
## told when its owner is freed, and a freed node answers for itself.
var blockers: Array = []

## True while a tool other than the hand is selected. Set by the screen. It
## changes what a press ON A BED means: with the hand it is the old game (tap
## acts, drag pans -- even from a bed); with a brush it is a stroke, and the
## camera holds still so the beds cannot slide out from under the sweep.
## Grass is grass either way: a drag that starts on it always pans, which is
## what keeps "I can always move the picture" true with any tool in hand.
var brush_armed := false

## The screen's answer to "does this bed want a pull?" -- ripe, a move the
## catalogue knows, not mid-harvest. A Callable, not a copied list, because
## ripeness changes under the screen's feet (taps, brushes, the clock) and a
## list would go stale between refreshes; asked fresh at the moment a finger
## lands. Never set, or set empty, and no bed ever claims a drag: the world is
## exactly the pre-gesture farm it always was.
var gesture_bed_check := Callable()

var _ground: Node2D
var _buildings: Node2D
## A quiet world-space landmark for the one task the page has already chosen.
## It is intentionally separate from both the buildings and beds: rebuilding a
## hut must not erase a delivery marker, and refreshing a bed must not disturb
## a marker on another plot.
var _task_beacon_layer: Node2D
var _task_beacon_task: Dictionary = {}
var _task_beacon_tint := Color(1.0, 0.94, 0.62)
var _task_beacon_plot_index := -1
var _beds: Array = []          # PlotView, one per bed in the save
## The guard dog. Lives in the world so he moves with the ground; takes no
## input, keeps his distance, stores nothing.
var _dog: Dog
## What the town looked like when it was last drawn: the bear door's
## presence, the farm level (which decides how the orchard corner is drawn),
## and how many beds stand. refresh() compares this against the save so a
## door opening, a level rising or a bed being cleared redraws the town the
## moment it happens -- and NOTHING redraws it on the refreshes in between.
var _town_drawn := ""
## The stones standing on land not yet cleared, one Node2D per waiting slot,
## keyed by bed index. Kept so a purchase can animate THESE stones sliding
## away rather than conjuring new ones to dismiss.
var _slots: Dictionary = {}

var _finger := -1
## A press that started on the dog: lifting without travel is a pat, a drag
## is a throw. Panning never starts on him.
var _fetch_live := false
## The rain cloud, while a thirsty bed wants it; and the finger on it.
var _cloud: Node2D = null
var _cloud_live := false
var _cloud_home := Vector2.ZERO
var _cloud_rest_until := 0
var _plots_seen: Array = []
const CLOUD_REST_SECONDS := 90
var _finger_from := Vector2.ZERO
var _finger_last := Vector2.ZERO
var _travelled := 0.0
## True from a brush press on a bed until that finger lifts.
var _stroke := false
## True from a bare-hand press on a pullable bed until that finger lifts. While
## it lasts the drag is the crop's move, not a pan: the camera holds still, the
## way it holds still for a stroke.
var _gesture := false
var _gesture_bed := -1
var _gesture_centre := Vector2.ZERO
var _track := PackedVector2Array()
var _last_grass_tap := -10.0
var _clock := 0.0


func build(view: Vector2, top_bar: float, shelf: float, plots: Array) -> void:
	for child in get_children():
		child.queue_free()
	_beds.clear()
	_task_beacon_plot_index = -1

	# Depth is the y of a thing's feet: beds, buildings, the dog, every tree
	# and fence post sort by where they stand, nested through the layers, so
	# near things cover far things the way they would on a table.
	y_sort_enabled = true
	_ground = Node2D.new()
	_ground.y_sort_enabled = true
	add_child(_ground)
	_buildings = Node2D.new()
	_buildings.y_sort_enabled = true
	add_child(_buildings)

	_draw_ground()
	_draw_buildings()
	_draw_expansion_slots(plots.size())

	for i in range(plots.size()):
		var bed := PlotView.new()
		add_child(bed)
		bed.setup(i)
		_beds.append(bed)

	_dog = Dog.new()
	add_child(_dog)

	# This layer has no Controls that can catch a press and no collision shapes.
	# It follows the farm like a building, but lies above it so a delivery flag
	# remains visible when a rooftop redraw happens underneath.
	_task_beacon_layer = Node2D.new()
	_task_beacon_layer.name = "TaskBeaconLayer"
	_task_beacon_layer.z_index = 3
	add_child(_task_beacon_layer)

	camera.look_at_the_beds(view, top_bar, shelf, plots.size())
	camera.apply(self)
	refresh(plots)
	_render_task_beacon()


## Redraw the beds that changed. Everything else stays exactly where it is --
## including the camera, which is the whole reason this is not a rebuild.
func refresh(plots: Array) -> void:
	# A bed that was cleared since the last refresh needs a view. Grown here
	# rather than in a rebuild so the camera never moves for it -- the child
	# is looking at the stones he just paid to move.
	while _beds.size() < plots.size():
		var bed := PlotView.new()
		add_child(bed)
		bed.setup(_beds.size())
		_beds.append(bed)
	# And the regret window can take the newest one back: without this the
	# undone bed's view lingers under the returned stones, still tappable --
	# a ghost bed the hit test can find and the child cannot see.
	while _beds.size() > plots.size():
		var ghost: Node2D = _beds.pop_back()
		if is_instance_valid(ghost):
			ghost.queue_free()
	for i in range(mini(_beds.size(), plots.size())):
		(_beds[i] as Node2D).call("refresh", plots[i])
	_plots_seen = plots
	_tend_cloud()
	if _dog != null and is_instance_valid(_dog):
		_dog.retarget(plots, bool(SaveManager.data.get("farm", {})
			.get("visit_log_unread", false)))
	# The town redraws when -- and only when -- something about it changed:
	# the bear's door appearing after the first paid harvest, the orchard
	# corner building up at a new farm level, stones leaving cleared land.
	# All three happen mid-visit, between two of these refreshes, and
	# comparing against what was last DRAWN keeps every other refresh free.
	if _town_key(plots.size()) != _town_drawn:
		refresh_buildings()
		_draw_expansion_slots(plots.size())


func dog_position() -> Vector2:
	if _dog == null or not is_instance_valid(_dog):
		return Vector2.ZERO
	return _dog.position


func bed_count() -> int:
	return _beds.size()


## Show exactly one child-facing landmark for an already-derived screen task.
## This does not inspect the farm, orders, tools or saves. `index` means a
## PlotView target; a delivery may provide `facility_id`, with the established
## physical orders board as the presentation fallback for today's task shape.
func set_task_beacon(task: Dictionary, tint: Color) -> void:
	_task_beacon_task = task.duplicate(true)
	_task_beacon_tint = tint
	_render_task_beacon()


## Lightly circle every bed that the selected brush can genuinely work on.
## The page hands us already-derived indices instead of another copy of the
## farm rules, so this remains a world-space presentation route like the task
## flag above. These are all PlotView Node2Ds, never Controls or blockers.
func set_tool_targets(indices: Array, tint: Color, primary_index: int = -1) -> void:
	var wanted := {}
	for value in indices:
		var index := int(value)
		if index >= 0 and index < _beds.size():
			wanted[index] = true
	for i in range(_beds.size()):
		(_beds[i] as PlotView).set_tool_target(wanted.has(i), tint,
			i == primary_index)


## Remove the old visual first, then route the one supplied target to either a
## bed or a facility. This is deliberately a rendering route rather than a
## second "what now?" rule: the page remains the only owner of task priority.
func _render_task_beacon() -> void:
	_clear_task_beacon_visuals()
	if _task_beacon_task.is_empty():
		return
	var icon := str(_task_beacon_task.get("icon", "star"))
	var index := int(_task_beacon_task.get("index", -1))
	if index >= 0 and index < _beds.size():
		_task_beacon_plot_index = index
		(_beds[index] as PlotView).set_task_beacon(icon, _task_beacon_tint)
		return
	var facility_id := str(_task_beacon_task.get("facility_id", ""))
	if facility_id == "" and str(_task_beacon_task.get("kind", "")) == "deliver":
		facility_id = "orders"
	if facility_id != "":
		_draw_facility_task_beacon(facility_id, icon, _task_beacon_tint)


## Both possible homes are cleared together, so two "next" markers can never
## coexist for one task snapshot. Detached children are queued for normal
## Godot cleanup but leave the visual tree immediately.
func _clear_task_beacon_visuals() -> void:
	if _task_beacon_plot_index >= 0 and _task_beacon_plot_index < _beds.size():
		(_beds[_task_beacon_plot_index] as PlotView).set_task_beacon("", Color.WHITE)
	_task_beacon_plot_index = -1
	if _task_beacon_layer == null or not is_instance_valid(_task_beacon_layer):
		return
	for child in _task_beacon_layer.get_children():
		_task_beacon_layer.remove_child(child)
		child.free()


## Delivery's marker is a world sibling of the buildings, never a child of
## `_buildings`: refresh_buildings() deliberately wipes that subtree. Reusing
## PlotView's small pennant keeps its icon/tint language identical on soil and
## on the physical orders board without copying task art a second time.
func _draw_facility_task_beacon(facility_id: String, icon: String,
	tint: Color) -> void:
	if _task_beacon_layer == null or not is_instance_valid(_task_beacon_layer):
		return
	var facility := Layout.facility(facility_id)
	if facility.is_empty():
		return
	var landmark := Node2D.new()
	landmark.name = "TaskFacilityBeacon"
	var box := Layout.facility_size(facility)
	# Set it on the left roof corner, where it reads as a destination flag
	# without covering the building's own big pictogram.
	landmark.position = Layout.facility_at(facility) + Vector2(
		-box.x * 0.33, -box.y * 0.22)
	_task_beacon_layer.add_child(landmark)
	PlotView.draw_task_beacon(landmark, icon, tint, 1.0)


## Where bed `index` is on the glass right now. The seam every screen-space
## thing needs: the seed rack's drop targets, the pointing finger, and both
## probes all ask this and none of them has to know the camera exists.
func bed_screen_position(index: int) -> Vector2:
	if index < 0 or index >= _beds.size():
		return Vector2.ZERO
	return camera.world_to_screen(Layout.plot_at(index))


func facility_screen_position(id: String) -> Vector2:
	return camera.world_to_screen(Layout.facility_at(Layout.facility(id)))


func show_ring(index: int, plot: Dictionary) -> void:
	if index >= 0 and index < _beds.size():
		(_beds[index] as Node2D).call("show_ring", plot)


func look_at_facility(id: String) -> void:
	var f := Layout.facility(id)
	if f.is_empty():
		return
	camera.look_at(Layout.facility_at(f))
	_settle()


## Walk the camera to a world point. The probe's way to the expansion
## column, and any future caller's -- the pair of calls it wraps is easy to
## half-do (look_at without settle moves the arithmetic and not the picture).
func look_at_world(at: Vector2) -> void:
	camera.look_at(at)
	_settle()


## In from the overview to the nearest zoom seeds may be planted at. Called
## the moment a seed leaves the rack: every spacing promise the drag relies
## on (Layout.world_gap_needed and friends) is written against min_zoom, so
## a drag is simply never measured further out than that. The child reads it
## as the farm leaning in to receive the seed.
func ensure_planting_zoom() -> void:
	if camera.zoom >= Layout.min_zoom() - 0.001:
		return
	camera.zoom = Layout.min_zoom()
	camera.centre = Layout.clamp_centre(camera.centre, camera.window.size,
		camera.zoom)
	_settle()


func go_home() -> void:
	camera.go_home()
	_settle()


func zoom_by(direction: int) -> void:
	if camera.step_zoom(direction, camera.window.get_center()):
		_settle()


func can_zoom(direction: int) -> bool:
	return camera.can_zoom(direction)


func _settle() -> void:
	camera.apply(self)
	camera_moved.emit()


# --- the ground and the buildings ----------------------------------------

func _draw_ground() -> void:
	var world := Layout.world_size()
	Shapes.fill(_ground, Shapes.rounded_rect(Vector2.ZERO, world, 40.0),
		Color(0.66, 0.81, 0.53), 1.0)
	# A quiet grass texture over the paint: low-contrast mottling and a few
	# blades, tiled. Not a baked picture of the farm -- a material for the
	# ground, so the rendered things stand on grass rather than on a colour.
	var grass := HarvestArt.prop_texture("grass_tile")
	if grass != null:
		var tile := TextureRect.new()
		tile.name = "GrassTile"
		tile.texture = grass
		tile.stretch_mode = TextureRect.STRETCH_TILE
		tile.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tile.position = Vector2.ZERO
		tile.size = world
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ground.add_child(tile)
	# The passive scenery is a child Node2D with no input of its own. It gets
	# every real bed and facility rectangle first, so a tree can make the world
	# feel lived in without ever making a child wonder whether a carrot is
	# behind a decoration.
	FarmWorldArt.add_ground_dressing(_ground, _art_safe_rects())

	# A path from the gate up between the beds, so the farm reads as a place
	# somebody walks around rather than as a green rectangle with things on it.
	var gate := Layout.facility_at(Layout.facility("gate"))
	var well := Layout.facility_at(Layout.facility("well"))
	if gate != Vector2.ZERO and well != Vector2.ZERO:
		# Use the same quiet path material as the supply branches.  The old
		# ink outline read as a crack through the farm and divided nearby beds
		# into islands even though their layout and touch areas were unchanged.
		FarmWorldArt.draw_path(_ground, PackedVector2Array(
			[gate, gate.lerp(well, 0.5) + Vector2(-90, 0), well]), 54.0)

	# A fence around the outside. The edge of the world, said in a way a child
	# reads as "this is my farm" rather than as "the picture stopped".
	var inset := 26.0
	for i in range(int(world.x / 150.0)):
		var x := inset + 150.0 * float(i) + 40.0
		_fence_post(Vector2(x, inset))
		_fence_post(Vector2(x, world.y - inset))
	for i in range(int(world.y / 150.0)):
		var y := inset + 150.0 * float(i) + 40.0
		_fence_post(Vector2(inset, y), true)
		_fence_post(Vector2(world.x - inset, y), true)

	# Flowers, in a fixed pattern rather than scattered. Nothing in this garden
	# is random -- see offline_growth.gd on why weeds are not either.
	var protected := _art_safe_rects()
	for i in range(24):
		var at := Vector2(
			140.0 + fmod(float(i) * 337.0, world.x - 280.0),
			120.0 + fmod(float(i) * 611.0, world.y - 240.0))
		var flower_footprint := Rect2(at - Vector2.ONE * 9.0,
			Vector2.ONE * 18.0)
		var touches_target := false
		for target in protected:
			if flower_footprint.intersects(target.grow(22.0)):
				touches_target = true
				break
		if touches_target:
			continue
		var sprig := HarvestArt.prop_texture(["sprig_pink", "sprig_yellow", "sprig_lilac"][i % 3])
		if sprig != null:
			var root := Node2D.new()
			root.name = "Sprig"
			root.position = at + Vector2(0.0, 6.0)
			_ground.add_child(root)
			var art := HarvestArt.grounded_sprite(sprig, 24.0, Vector2.ZERO, "SprigArt")
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(art)
			continue
		var tint: Color = [Color(0.96, 0.72, 0.78), Color(0.98, 0.86, 0.52),
			Color(0.80, 0.78, 0.96)][i % 3]
		Shapes.fill(_ground, Shapes.circle_points(at, 9.0), tint, 1.0)
		Shapes.fill(_ground, Shapes.circle_points(at, 4.0),
			Color(1.0, 0.94, 0.62), 1.0)


func _fence_post(at: Vector2, along_y: bool = false) -> void:
	# One rendered post with its rails, standing where the drawn one stood.
	# Posts are 150 apart and a rail is 1.3 of the 2.2 m render span, so a
	# half-canvas of 132 lets neighbouring rails meet. The side runs use the
	# render whose rails go into the screen.
	var rail := HarvestArt.prop_texture("fence_y" if along_y else "fence")
	if rail != null:
		var post := Node2D.new()
		post.name = "Fence"
		post.position = at + Vector2(0.0, 30.0)
		_ground.add_child(post)
		Shapes.ground_shadow(post, Vector2(0.0, -4.0), 60.0, 0.10)
		var art := HarvestArt.grounded_sprite(rail, 132.0, Vector2.ZERO, "FenceArt")
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		post.add_child(art)
		return
	Shapes.fill(_ground, Shapes.rounded_rect(at - Vector2(6, 30),
		Vector2(12, 60), 5.0), Color(0.78, 0.66, 0.48), 1.0)
	Shapes.fill(_ground, Shapes.rounded_rect(at - Vector2(58, 8),
		Vector2(116, 9), 4.0), Color(0.85, 0.74, 0.55), 1.0)


func _draw_buildings() -> void:
	for f in Layout.facilities():
		# The bear's door appears once the story has knocked: after the first
		# harvest has ever been paid, and forever after. Before that it is not
		# locked, not greyed -- it is simply not there yet, the same way the
		# bear has not visited yet.
		if str(f.get("id", "")) == "bear_door" and not _bear_door_open():
			continue
		var at := Layout.facility_at(f)
		var box := Layout.facility_size(f)
		# Marked-out ground until the farm has grown to its level: a thing
		# that is COMING, never a thing that is refused. No padlock exists
		# anywhere on this farm.
		var locked_here: bool = Level.level() < int(f.get("level", 0))
		var facility_id := str(f.get("id", ""))
		var hut := Node2D.new()
		hut.name = "Facility_%s" % facility_id
		hut.position = at
		_buildings.add_child(hut)

		Shapes.ground_shadow(hut, Vector2(0, box.y * 0.44), box.x * 0.8, 0.22)
		# FarmWorldArt owns the visual shell only. Layout still owns this box,
		# and facility_under() still uses that same box for its hit area, so a
		# richer landmark cannot create a second kind of door to maintain.
		FarmWorldArt.draw_facility(hut, facility_id, box, locked_here)

		var art_size := minf(box.y * 0.42, box.x * 0.36)
		# These three destinations use the building's own picture as its wordless
		# action cue: basket at the barn, a finished dish at the kitchen entrance,
		# and a heart above the order checklist. It stays within the existing
		# facility art and does not create another control or tap target.
		if facility_id == "coop" and not locked_here:
			_dress_coop(hut, box)
		if facility_id == "mill" and not locked_here:
			_dress_mill(hut, box)
		var art := UiKit.picture(str(f.get("icon", "star")), art_size)
		if art != null:
			art.position = FarmWorldArt.facility_icon_anchor(box,
				facility_id) - Vector2.ONE * art_size * 0.5
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.modulate.a = 0.45 if locked_here else 1.0
			hut.add_child(art)

## Every visible place a child can act on, in world coordinates. This feeds
## only the passive art layer; facility_under() and bed_under() keep their own
## existing authority. Keeping the safe rectangles here means a future plot or
## facility added to the JSON automatically stays clear of scenery too.
func _art_safe_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var bed_box := Layout.plot_box()
	for index in range(Layout.places_for_plots()):
		out.append(Rect2(Layout.plot_at(index) - bed_box * 0.5, bed_box))
	for facility in Layout.facilities():
		var box := Layout.facility_size(facility)
		out.append(Rect2(Layout.facility_at(facility) - box * 0.5, box))
	return out


func _bear_door_open() -> bool:
	var farm: Dictionary = SaveManager.data.get("farm", {})
	return not (farm.get("paid_harvests", []) as Array).is_empty() \
		or int(farm.get("npc_friendship", {}).get("bear", 0)) > 0


## Redraw the buildings alone -- what the bear's door needs when the first
## harvest opens it mid-visit, without a full rebuild throwing the camera.
func refresh_buildings() -> void:
	if _buildings == null or not is_instance_valid(_buildings):
		return
	for child in _buildings.get_children():
		child.queue_free()
	_draw_buildings()
	# The delivery pennant is not a building child, but reroute the current
	# presentation snapshot explicitly after a town redraw. That keeps the
	# landmark correct even if a future building visual changes its own layer.
	_render_task_beacon()


## Everything the town's drawing depends on, as one comparable word.
func _town_key(bed_count: int) -> String:
	var farm: Dictionary = SaveManager.data.get("farm", {})
	return "%s|%d|%d|%s|%s" % [str(_bear_door_open()), Level.level(), bed_count,
		Coop.state(farm, GameClock.now_unix()),
		Maker.state(farm, Maker.MILL, GameClock.now_unix())]


## The land still under stones: one patch per expansion slot the save has not
## bought yet. Three stones and a leaning fence post on marked-out ground --
## a thing that is coming, with a star saying which level brings it.
func _draw_expansion_slots(bed_count: int) -> void:
	_town_drawn = _town_key(bed_count)
	for key in _slots.keys():
		var gone: Node2D = _slots[key]
		if is_instance_valid(gone):
			gone.queue_free()
	_slots.clear()
	for index in range(bed_count, Layout.places_for_plots()):
		if GameData.farm_expansion_slot(index).is_empty():
			continue
		var patch := Node2D.new()
		patch.position = Layout.plot_at(index)
		add_child(patch)
		_slots[index] = patch
		var box := Layout.plot_box()

		# The locked plot keeps the exact same hit box and moving stone nodes,
		# but its idle drawing is now a rocky grass clearing rather than a
		# rounded inactive tile. FarmWorldArt draws only passive shapes here.
		FarmWorldArt.draw_future_plot(patch, box, index)
		# The stones, placed by arithmetic so they sit the same on every
		# tablet and the purchase can slide THESE exact stones away.
		var stones := maxi(1, int(GameData.farm_expansions
			.get("animation", {}).get("stones", 3)))
		for n in range(stones):
			var stone := Node2D.new()
			stone.position = Vector2(
				(float(n) - float(stones - 1) * 0.5) * box.x * 0.28,
				(-0.12 + 0.16 * float(n % 2)) * box.y)
			patch.add_child(stone)
			var radius := box.y * (0.16 + 0.04 * float(n % 2))
			# The same rendered field stone the harvest page's beds carry,
			# standing on this slot; the node it sits in is what the purchase
			# slides away, so the animation is untouched.
			var rock := HarvestArt.crop_texture("stone")
			if rock != null:
				var art := HarvestArt.grounded_sprite(rock, radius * 1.45,
					Vector2(0.0, radius * 0.55), "Stone3D")
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stone.add_child(art)
			else:
				var rng := RandomNumberGenerator.new()
				rng.seed = 47_129 + index * 997 + n * 131
				Shapes.lit(stone, Shapes.blob(Vector2.ZERO,
					Vector2(radius, radius * 0.82), rng, 0.10, 4, 20),
					Color(0.62, 0.64, 0.66), 0.6)
		# A fence post lying where the fence gave up, pointing at the work.
		Shapes.fill(patch, Shapes.rounded_rect(
			Vector2(-box.x * 0.46, box.y * 0.30), Vector2(box.x * 0.30, 10), 4.0),
			Color(0.72, 0.58, 0.40), 1.0)

		# The star and the level it asks for. A NUMBER, deliberately: digits
		# are the one bit of writing this game trusts a six-year-old with.
		var lift := Node2D.new()
		lift.position = Vector2(0, -box.y * 0.62)
		patch.add_child(lift)
		var badge := UiKit.picture("star", 40.0)
		if badge != null:
			badge.position = Vector2(-38, -22)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var wanted := int(GameData.farm_expansion_slot(index).get("level", 1))
			badge.modulate = Color(1, 1, 1, 1.0) 				if Level.level() >= wanted else Color(1, 1, 1, 0.85)
			lift.add_child(badge)
		var tag := UiKit.title(str(int(GameData.farm_expansion_slot(index)
			.get("level", 1))), 30)
		tag.position = Vector2(6, -18)
		tag.size = Vector2(40, 36)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lift.add_child(tag)


## Eggs waiting by the coop, one each, with a soft glow so they read from
## the far side of the farm: the picture of "come and collect".
func _dress_coop(hut: Node2D, box: Vector2) -> void:
	var farm: Dictionary = SaveManager.data.get("farm", {})
	if Coop.state(farm, GameClock.now_unix()) != Coop.READY:
		return
	var egg := HarvestArt.prop_texture("egg")
	if egg == null:
		return
	var count := int(Coop.coop(farm).get("eggs", 0))
	Shapes.glow(hut, Vector2(-box.x * 0.30, box.y * 0.36), 54.0,
		Color(1.0, 0.94, 0.62), 4, 0.5)
	for n in range(count):
		var at := Vector2(-box.x * 0.38 + 26.0 * float(n), box.y * 0.40 - 6.0 * float(n % 2))
		# Siblings cannot share a name; Godot would quietly rename the second.
		var art := HarvestArt.grounded_sprite(egg, 20.0, at, "CoopEgg_%d" % n)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hut.add_child(art)


## The sails on the tower, turning -- slowly when idle, briskly while wheat
## is in it -- and the sack of flour waiting at its door. The hub pixels
## were measured in Blender (pipeline recipes building_mill, windmill_blades).
func _dress_mill(hut: Node2D, box: Vector2) -> void:
	var tower := hut.get_node_or_null("Building_mill") as Control
	var blades := HarvestArt.prop_texture("windmill_blades")
	if tower == null or blades == null:
		return
	var scale := tower.size.x / HarvestArt.SOURCE_CANVAS_SIZE
	var hub := tower.position + Vector2(227.1, 249.1) * scale
	var sails := HarvestArt.grounded_sprite(blades, tower.size.x * 0.5 * 0.787,
		Vector2.ZERO, "MillSails")
	var own_hub := Vector2(256.0, 369.9) * (sails.size.x / HarvestArt.SOURCE_CANVAS_SIZE)
	sails.position = hub - own_hub
	sails.pivot_offset = own_hub
	sails.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hut.add_child(sails)
	var farm: Dictionary = SaveManager.data.get("farm", {})
	var state := Maker.state(farm, Maker.MILL, GameClock.now_unix())
	if Juice.motion_enabled():
		var turn := sails.create_tween().set_loops()
		turn.tween_property(sails, "rotation", TAU, 2.8 if state == Maker.WORKING else 9.0) \
			.from(0.0)
	if state != Maker.READY:
		return
	var sack := HarvestArt.prop_texture("flour")
	if sack == null:
		return
	Shapes.glow(hut, Vector2(-box.x * 0.22, box.y * 0.40), 50.0,
		Color(1.0, 0.94, 0.62), 4, 0.5)
	for n in range(int(Maker.store(farm, Maker.MILL).get("done", 0))):
		var art := HarvestArt.grounded_sprite(sack, 22.0,
			Vector2(-box.x * 0.26 + 26.0 * float(n), box.y * 0.44), "MillSack_%d" % n)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hut.add_child(art)


# --- the dog's stick ----------------------------------------------------------

## A drag that began on the dog: the stick flies to where the finger let go,
## and he goes after it. Pure play -- no save, no count, like the pat.
func _throw_stick(at: Vector2) -> void:
	if _dog == null or not is_instance_valid(_dog):
		return
	var world := Layout.world_size()
	var target := camera.screen_to_world(at)
	target = Vector2(clampf(target.x, 60.0, world.x - 60.0), clampf(target.y, 60.0, world.y - 60.0))
	var stick := Node2D.new()
	stick.name = "Stick"
	stick.position = (_dog as Node2D).position
	add_child(stick)
	var art := HarvestArt.prop_texture("stick")
	var picture: Control = HarvestArt.grounded_sprite(art, 30.0, Vector2.ZERO, "StickArt") \
		if art != null else null
	if picture != null:
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.pivot_offset = -picture.position
		stick.add_child(picture)
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	# He bolts the moment it leaves the hand, the way a dog does; the stick is
	# still in the air while he runs.
	_dog.call("fetch", target, stick)
	if not Juice.motion_enabled():
		stick.position = target
		return
	var flight := stick.create_tween()
	flight.tween_property(stick, "position", target, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if picture != null:
		var hop := picture.create_tween()
		hop.tween_property(picture, "position:y", picture.position.y - 70.0, 0.27) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(picture, "position:y", picture.position.y, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hop.parallel().tween_property(picture, "rotation", TAU * 1.5, 0.55).from(0.0)


# --- the rain cloud -------------------------------------------------------------

## While a bed is thirsty a small cloud hangs over the farm. Dragged onto
## that bed and let go, it rains; let go anywhere else, it drifts back. It
## is help, not a chore: the can still works, and a child who never touches
## the cloud loses nothing.
func _tend_cloud() -> void:
	var thirsty := _any_thirsty()
	if thirsty and _cloud == null and GameClock.now_unix() >= _cloud_rest_until:
		_spawn_cloud()
	elif not thirsty and _cloud != null and not _cloud_live:
		_dismiss_cloud()


func _any_thirsty() -> bool:
	for plot in _plots_seen:
		if str(plot.get("care_event", "")) == Growth.CARE_THIRSTY:
			return true
	return false


func _plot_thirsty(index: int) -> bool:
	return index >= 0 and index < _plots_seen.size() \
		and str(_plots_seen[index].get("care_event", "")) == Growth.CARE_THIRSTY


func _spawn_cloud() -> void:
	var texture := HarvestArt.prop_texture("cloud")
	if texture == null:
		return
	var world := Layout.world_size()
	_cloud = Node2D.new()
	_cloud.name = "RainCloud"
	_cloud.z_index = 20
	_cloud.position = Vector2(world.x * 0.46, 110.0)
	_cloud_home = _cloud.position
	add_child(_cloud)
	var art := HarvestArt.grounded_sprite(texture, 70.0, Vector2.ZERO, "CloudArt")
	art.position = -art.size * 0.5
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloud.add_child(art)
	_cloud.modulate.a = 0.0
	if Juice.motion_enabled():
		_cloud.create_tween().tween_property(_cloud, "modulate:a", 1.0, 0.6)
	else:
		_cloud.modulate.a = 1.0


func _dismiss_cloud() -> void:
	var gone := _cloud
	_cloud = null
	_cloud_live = false
	if gone == null or not is_instance_valid(gone):
		return
	if not Juice.motion_enabled():
		gone.queue_free()
		return
	var t := gone.create_tween()
	t.tween_property(gone, "modulate:a", 0.0, 0.5)
	t.tween_callback(gone.queue_free)


func _cloud_under(at: Vector2) -> bool:
	if _cloud == null or not is_instance_valid(_cloud) or _cloud.get_child_count() == 0:
		return false
	var art := _cloud.get_child(0) as Control
	return art != null and art.get_global_rect().grow(12.0).has_point(at)


func _cloud_back() -> void:
	if _cloud == null or not is_instance_valid(_cloud):
		return
	if Juice.motion_enabled():
		_cloud.create_tween().tween_property(_cloud, "position", _cloud_home, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_cloud.position = _cloud_home


func _rain_on(index: int) -> void:
	if _cloud == null or not is_instance_valid(_cloud):
		return
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	var bed := Layout.plot_at(index)
	if Juice.motion_enabled():
		for i in range(12):
			var drop := Node2D.new()
			drop.z_index = 19
			drop.position = _cloud.position + Vector2(-50.0 + 10.0 * float(i), 20.0)
			add_child(drop)
			Shapes.fill(drop, Shapes.oval_points(Vector2.ZERO, Vector2(3.0, 6.0)),
				Color(0.45, 0.68, 0.90, 0.9), 0.0)
			var t := drop.create_tween()
			t.tween_interval(0.04 * float(i % 4))
			t.tween_property(drop, "position", bed + Vector2(-50.0 + 10.0 * float(i), 0.0), 0.45) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(drop.queue_free)
	cloud_rained.emit(index)
	_cloud_rest_until = GameClock.now_unix() + CLOUD_REST_SECONDS
	_dismiss_cloud()


## A press on scenery that can answer: the duck hops, a hen flaps. Pure
## delight, no save, no signal -- like the dog. Returns what was poked.
func poke_scenery_at(at: Vector2) -> String:
	return FarmWorldArt.poke_scenery(_ground, at)


## All scenery of one kind reacts (feeding the hens makes both flap).
func poke_scenery_kind(kind: String) -> void:
	FarmWorldArt.poke_scenery_kind(_ground, kind)


## Which expansion slot is under this point on the glass, or -1. The whole
## patch is live, same forgiveness as a bed -- stones are pressed with the
## same thumb that presses carrots.
func expansion_under(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for index in _slots.keys():
		var patch: Node2D = _slots[index]
		if not is_instance_valid(patch):
			continue
		var centre := camera.world_to_screen(patch.position)
		var half: Vector2 = Layout.plot_box() * 0.5 * camera.zoom
		if absf(at.x - centre.x) > half.x or absf(at.y - centre.y) > half.y:
			continue
		var d := centre.distance_to(at)
		if d < best_d:
			best_d = d
			best = int(index)
	return best


## The stones slide away and the earth is his. Plays over the patch that is
## ALREADY on screen -- refresh() has not run yet, so the stones the child
## paid to move are the stones that move. Deterministic: same slide every
## time, no dice anywhere.
func celebrate_new_bed(index: int) -> void:
	var patch: Node2D = _slots.get(index)
	if patch == null or not is_instance_valid(patch):
		return
	_slots.erase(index)
	var seconds := maxf(0.3, float(GameData.farm_expansions
		.get("animation", {}).get("unfold_seconds", 0.9)))
	if not Juice.motion_enabled():
		patch.queue_free()
		return
	var n := 0
	for child in patch.get_children():
		# The stones (and the fallen post's siblings) scatter outward and
		# fade; the ground fills fade with the patch itself.
		if child is Node2D:
			var away := Vector2(-1.0 if n % 2 == 0 else 1.0,
				-0.4 + 0.3 * float(n % 3))
			var t := (child as Node2D).create_tween()
			t.tween_property(child, "position",
				(child as Node2D).position + away * 190.0, seconds * 0.8)				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			n += 1
	var fade := patch.create_tween()
	fade.tween_property(patch, "modulate:a", 0.0, seconds)
	fade.tween_callback(patch.queue_free)
	Juice.burst(self, Layout.plot_at(index), 18)


# --- thumbs ---------------------------------------------------------------

## Everything a finger can do to the farm, in one place.
##
## WHO OWNS A DRAG
##
## Down on a bed or a building, then released without travelling: that thing
## was pressed. Down anywhere, then travelled: the ground is being dragged --
## INCLUDING from a bed, which matters more than it sounds. If a press that
## started on a bed could not become a pan, then a child whose farm is mostly
## beds would find that most of the screen does not scroll, and he would decide
## the farm does not scroll.
func _input(event: InputEvent) -> void:
	if locked or not is_inside_tree():
		return
	# Own the physical source, not Godot's mirrored mouse/touch event. A mouse
	# moving while a finger is down must not turn that tap into a camera pan.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1:
			if _down(touch.position):
				_finger = touch.index
		elif not touch.pressed and touch.index == _finger:
			_up(touch.position)
			_finger = -1
	elif event is InputEventScreenDrag \
			and (event as InputEventScreenDrag).index == _finger:
		_moved((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _finger == -1:
			if _down(click.position):
				_finger = -2
		elif not click.pressed and _finger == -2:
			_up(click.position)
			_finger = -1
	elif event is InputEventMouseMotion and _finger == -2 \
			and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_moved((event as InputEventMouseMotion).position)


## Claim this finger, or refuse it. THE ANSWER MATTERS: the first cut set a
## flag inside and the caller assigned the finger anyway, which meant a press
## on the seed rack -- outside the window -- was owned by the farm, and letting
## go of it counted as a tap on whatever the shelf happened to cover. Tapping
## the barn label scrolled the farm to the gate.
func _down(at: Vector2) -> bool:
	if not camera.inside(at) or _blocked(at):
		return false
	_finger_from = at
	_finger_last = at
	_travelled = 0.0
	_stroke = false
	_gesture = false
	_track = PackedVector2Array()
	if _cloud_under(at):
		_cloud_live = true
		return true
	if _dog != null and is_instance_valid(_dog) and _dog.pet_at(at, camera) \
			and bool(_dog.call("can_fetch")):
		_fetch_live = true
		return true
	if brush_armed:
		var bed := bed_under(at)
		if bed >= 0:
			_stroke = true
			stroke_swept.emit(bed)
	elif gesture_bed_check.is_valid():
		var bed := bed_under(at)
		if bed >= 0 and bool(gesture_bed_check.call(bed)):
			_gesture = true
			_gesture_bed = bed
			_gesture_centre = bed_screen_position(bed)
			_track.append(at)
	return true


## Is a brush stroke in progress right now? The screen's _queue_rebuild waits
## on this the same way it waits on a held seed: a rebuild mid-stroke would
## throw away the toolbar under his finger and the combo he is counting.
func stroking() -> bool:
	return _stroke


## The screen looked at a finished pull and ruled "that was a pan after all".
## Catch the world up by the NET distance the finger travelled -- one jump, not
## a replay of the drag. A replay would wiggle the camera through every waggle
## of a failed shake, and a camera that dances reads as broken.
func pan_by(by: Vector2) -> void:
	if by == Vector2.ZERO:
		return
	camera.pan(by)
	_settle()


## The plant under a pulling finger leans with it. Pure forwarding: the world
## never decides what a lean means, only which bed it landed on.
func gesture_lean(index: int, offset: Vector2) -> void:
	if index < 0 or index >= _beds.size():
		return
	(_beds[index] as PlotView).lean(offset)


## Water landed on this bed: drops in, plant perks. Pure forwarding, like the
## lean above.
func drink_bed(index: int) -> void:
	if index < 0 or index >= _beds.size():
		return
	(_beds[index] as PlotView).drink()


func add_blocker(node: Control) -> void:
	blockers.append(node)


func _blocked(at: Vector2) -> bool:
	# Validity FIRST. A card that frees itself (the recipe card fades out
	# on its own) leaves a dead reference here, and `dead is Control` is a
	# script error -- which aborted the whole input handler, so every press
	# on the farm went nowhere until the next rebuild swept the list.
	var alive: Array = []
	var blocked := false
	for node in blockers:
		if not is_instance_valid(node) or not (node is Control):
			continue
		alive.append(node)
		if (node as Control).visible and Rect2((node as Control).global_position,
				(node as Control).size).has_point(at):
			blocked = true
	# Keep scanning after a hit: close/pager controls may be registered after
	# the sheet. Truncating here would let the next press reach the soil.
	blockers = alive
	return blocked


func _moved(at: Vector2) -> void:
	if _finger == -1:
		return
	if _cloud_live:
		if _cloud != null and is_instance_valid(_cloud):
			_cloud.position = camera.screen_to_world(at)
		_travelled += _finger_last.distance_to(at)
		_finger_last = at
		return
	if _fetch_live:
		_travelled += _finger_last.distance_to(at)
		_finger_last = at
		return
	if _gesture:
		# A pull never pans -- the ground must sit still while the crop comes
		# loose, exactly as it does under a stroke. Travel keeps counting so
		# _up can still tell a pull from a press that wobbled.
		_travelled += _finger_last.distance_to(at)
		_track.append(at)
		gesture_moved.emit(_gesture_bed, at - _finger_from)
		_finger_last = at
		return
	if _stroke:
		# A stroke never pans. One report per event is enough -- the events
		# arrive far closer together than beds do, so a sweep cannot jump
		# clean over one.
		var bed := bed_under(at)
		if bed >= 0:
			stroke_swept.emit(bed)
		_finger_last = at
		return
	_travelled += _finger_last.distance_to(at)
	if _travelled > FarmCamera.TAP_SLOP:
		camera.pan(at - _finger_last)
		_settle()
	_finger_last = at


func _up(at: Vector2) -> void:
	if _cloud_live:
		_cloud_live = false
		var bed := bed_under(at)
		if bed >= 0 and _plot_thirsty(bed):
			_rain_on(bed)
		else:
			_cloud_back()
		return
	if _fetch_live:
		_fetch_live = false
		if _travelled > FarmCamera.TAP_SLOP * 1.5:
			_throw_stick(at)
		elif _dog != null and is_instance_valid(_dog):
			_dog.pet()
		return
	if _gesture:
		_gesture = false
		# The finger left, whatever the verdict: settle the plant first, so the
		# tap-that-wobbled path -- which never reaches the screen's finish
		# handler -- cannot leave a bed leaning at nothing.
		gesture_moved.emit(_gesture_bed, Vector2.ZERO)
		if _travelled > FarmCamera.TAP_SLOP:
			# A real pull attempt, however clumsy: the screen judges it.
			var net := Vector2.ZERO
			if _track.size() >= 2:
				net = _track[_track.size() - 1] - _track[0]
			gesture_finished.emit(_gesture_bed, _track, _gesture_centre, net)
		else:
			press_at(at)          # a press on the bed that wobbled, not a pull
		_track = PackedVector2Array()
		return
	if _stroke:
		_stroke = false
		stroke_ended.emit()
		return
	if _travelled > FarmCamera.TAP_SLOP:
		return                            # that was a drag, not a press
	press_at(at)


## What is under this point on the glass, and tell somebody about it.
##
## Public because the touch probe drives it: a probe that reimplemented the hit
## test would be checking its own arithmetic rather than the farm's.
func press_at(at: Vector2) -> void:
	var index := bed_under(at)
	if index >= 0:
		plot_pressed.emit(index)
		return
	var id := facility_under(at)
	if id != "":
		look_at_facility(id)
		facility_pressed.emit(id)
		return
	var slot := expansion_under(at)
	if slot >= 0:
		camera.look_at(Layout.plot_at(slot))
		_settle()
		expansion_pressed.emit(slot)
		return
	# The dog, last of the claimable things and first of the nothing-happens
	# ones: a hand on his head is a greeting the world answers itself, with no
	# save and no signal, because there is no state anywhere to change.
	if _dog != null and is_instance_valid(_dog) and _dog.pet_at(at, camera):
		_dog.pet()
		return
	var poked := poke_scenery_at(at)
	if poked != "":
		AudioManager.play_sfx("res://assets/audio/water.ogg" if poked == "duck"
			else "res://assets/audio/rustle.ogg")
		return
	_grass_tap(at)


## Which bed is under this point on the glass, or -1.
##
## Nearest-centre among the beds whose box contains the point, and the box is
## the whole bed. Nearest and not first-found: the four-bed garden learned that
## one the hard way in 丰收行动's baskets, where "the first one in range" meant
## the second and third could never be chosen at all.
func bed_under(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	var forgiveness := _reach_factor()
	for i in range(_beds.size()):
		var bed: Node2D = _beds[i]
		var centre := bed_screen_position(i)
		var half: Vector2 = (bed.call("reach") as Vector2) * camera.zoom \
			* forgiveness
		if absf(at.x - centre.x) > half.x or absf(at.y - centre.y) > half.y:
			continue
		var d := centre.distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


## How far past a bed's edge a press still counts, by the parent dial.
##
## Gentle grows the target because a gentle hand misses more; brave shrinks it
## a little because a child who is doing well wants his aim to matter. Neither
## can make two beds fight over one press: the beds are 360 world units apart
## and even the gentle box (110 * 1.18 = 130 a side) leaves 100 clear between
## them, and bed_under takes the NEAREST of any that match anyway.
func _reach_factor() -> float:
	match clampi(int(SaveManager.get_setting("difficulty", 1)), 0, 2):
		0: return 1.18
		2: return 0.90
	return 1.0


func facility_under(at: Vector2) -> String:
	var best := ""
	var best_d := INF
	for f in Layout.facilities():
		if str(f.get("id", "")) == "bear_door" and not _bear_door_open():
			continue
		var centre := camera.world_to_screen(Layout.facility_at(f))
		var half: Vector2 = Layout.facility_size(f) * 0.5 * camera.zoom
		if absf(at.x - centre.x) > half.x or absf(at.y - centre.y) > half.y:
			continue
		var d := centre.distance_to(at)
		if d < best_d:
			best_d = d
			best = str(f.get("id", ""))
	return best


## Two presses on bare grass: back to the opening view.
##
## On the GRASS and not anywhere, because a double tap on a bed is a child
## tapping a bed twice -- which he does constantly -- and yanking the camera
## home in the middle of that would be the farm answering a question he did not
## ask.
func _grass_tap(at: Vector2) -> void:
	grass_pressed.emit(at)
	if _clock - _last_grass_tap <= DOUBLE_TAP:
		_last_grass_tap = -10.0
		go_home()
		return
	_last_grass_tap = _clock


func _process(delta: float) -> void:
	_clock += delta
	if _cloud != null and is_instance_valid(_cloud) and not _cloud_live \
			and Juice.motion_enabled():
		_cloud.position.x = _cloud_home.x + sin(_clock * 0.35) * 70.0
		_cloud.position.y = _cloud_home.y + sin(_clock * 0.9) * 4.0
