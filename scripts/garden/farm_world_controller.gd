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
const Farm := preload("res://scripts/garden/farm_save.gd")
const Dog := preload("res://scripts/garden/farm_dog_controller.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")

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

	_ground = Node2D.new()
	add_child(_ground)
	_buildings = Node2D.new()
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

	camera.look_at_the_beds(view, top_bar, shelf, plots.size())
	camera.apply(self)
	refresh(plots)


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
		Color(0.71, 0.84, 0.58), 1.0)

	# A path from the gate up between the beds, so the farm reads as a place
	# somebody walks around rather than as a green rectangle with things on it.
	var gate := Layout.facility_at(Layout.facility("gate"))
	var well := Layout.facility_at(Layout.facility("well"))
	if gate != Vector2.ZERO and well != Vector2.ZERO:
		Shapes.fill(_ground, Shapes.ribbon(PackedVector2Array(
			[gate, gate.lerp(well, 0.5) + Vector2(-90, 0), well]), 54.0),
			Color(0.83, 0.76, 0.60), 1.0)

	# A fence around the outside. The edge of the world, said in a way a child
	# reads as "this is my farm" rather than as "the picture stopped".
	var inset := 26.0
	for i in range(int(world.x / 150.0)):
		var x := inset + 150.0 * float(i) + 40.0
		_fence_post(Vector2(x, inset))
		_fence_post(Vector2(x, world.y - inset))
	for i in range(int(world.y / 150.0)):
		var y := inset + 150.0 * float(i) + 40.0
		_fence_post(Vector2(inset, y))
		_fence_post(Vector2(world.x - inset, y))

	# Flowers, in a fixed pattern rather than scattered. Nothing in this garden
	# is random -- see offline_growth.gd on why weeds are not either.
	for i in range(24):
		var at := Vector2(
			140.0 + fmod(float(i) * 337.0, world.x - 280.0),
			120.0 + fmod(float(i) * 611.0, world.y - 240.0))
		if Layout.bed_block(Layout.places_for_plots()).grow(70.0).has_point(at):
			continue
		var tint: Color = [Color(0.96, 0.72, 0.78), Color(0.98, 0.86, 0.52),
			Color(0.80, 0.78, 0.96)][i % 3]
		Shapes.fill(_ground, Shapes.circle_points(at, 9.0), tint, 1.0)
		Shapes.fill(_ground, Shapes.circle_points(at, 4.0),
			Color(1.0, 0.94, 0.62), 1.0)


func _fence_post(at: Vector2) -> void:
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
		var hut := Node2D.new()
		hut.position = at
		_buildings.add_child(hut)

		Shapes.ground_shadow(hut, Vector2(0, box.y * 0.44), box.x * 0.8, 0.22)
		if locked_here:
			# Not yet: drawn as ground that has been marked out, not as a
			# building with a padlock. A lock is a thing he is being refused;
			# a marked-out patch is a thing that is coming.
			Shapes.fill(hut, Shapes.rounded_rect(-box * 0.5, box, 24.0),
				Color(0.64, 0.76, 0.53), 1.0)
			Shapes.fill(hut, Shapes.rounded_rect(-box * 0.5 + Vector2(8, 8),
				box - Vector2(16, 16), 20.0), Color(0.71, 0.84, 0.58), 1.0)
		else:
			Shapes.lit(hut, Shapes.rounded_rect(-box * 0.5, box, 24.0),
				Color(1.0, 0.99, 0.94), 0.12)
			# A roof, so that from across the farm the buildings are buildings.
			Shapes.fill(hut, PackedVector2Array([
				Vector2(-box.x * 0.56, -box.y * 0.46),
				Vector2(0, -box.y * 0.86),
				Vector2(box.x * 0.56, -box.y * 0.46)]),
				Color(0.86, 0.52, 0.42), 1.0)

		var art := UiKit.picture(str(f.get("icon", "star")), box.y * 0.5)
		if art != null:
			art.position = Vector2(-box.y * 0.25, -box.y * 0.22)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.modulate.a = 0.45 if locked_here else 1.0
			hut.add_child(art)


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


## Everything the town's drawing depends on, as one comparable word.
func _town_key(bed_count: int) -> String:
	return "%s|%d|%d" % [str(_bear_door_open()), Level.level(), bed_count]


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

		Shapes.ground_shadow(patch, Vector2(0, box.y * 0.42), box.x * 0.7, 0.16)
		Shapes.fill(patch, Shapes.rounded_rect(-box * 0.5, box, 26.0),
			Color(0.63, 0.74, 0.52), 1.0)
		Shapes.fill(patch, Shapes.rounded_rect(-box * 0.5 + Vector2(9, 9),
			box - Vector2(18, 18), 22.0), Color(0.70, 0.81, 0.57), 0.0)
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
			Shapes.lit(stone, Shapes.circle_points(Vector2.ZERO,
				box.y * (0.16 + 0.04 * float(n % 2))),
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
	elif event is InputEventMouseMotion and _finger == -2:
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


func add_blocker(node: Control) -> void:
	blockers.append(node)


func _blocked(at: Vector2) -> bool:
	for node in blockers:
		if node is Control and is_instance_valid(node) \
				and (node as Control).visible \
				and Rect2((node as Control).global_position,
					(node as Control).size).has_point(at):
			return true
	return false


func _moved(at: Vector2) -> void:
	if _finger == -1:
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
