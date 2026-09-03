extends Node2D
## One patch of earth, standing on the ground of the farm.
##
## WHY THIS IS A NODE AND NOT A REDRAW
##
## The four-bed garden threw the whole screen away after every action, and that
## was right for four rectangles and a seed rack. It is wrong for a farm: a
## rebuild also throws away where the camera is pointed, which dog is running
## where, and the brush the child has half-finished dragging. So each bed is a
## node that stays, and refresh() changes only what the plot says has changed.
##
##
## WHY THE STATE IS SHOWN BY THE GROUND AND THE PLANT, NOT BY A BADGE
##
## He cannot read, and a badge is a symbol he has to have been taught. Dry earth
## is a lighter brown than wet earth. Weeds are weeds, growing next to the
## carrot, not a picture of weeds in a circle. A caterpillar walks along the
## leaf. Those are things a six-year-old already knows, and the badge on top is
## the reminder of what to do about it rather than the only way to find out.
##
## The ring is deliberately NOT permanent. "How far along is it" is a question
## he asks occasionally; "is anything ready" is one he asks every time. So the
## ring appears for RING_SHOWN seconds when he presses the bed, and ripeness
## has a look of its own that never goes away.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")

## How long the progress ring stays up after a press.
const RING_SHOWN := 3.0

## Wet earth and dry earth. Far enough apart in LIGHTNESS, not just in hue,
## that they still read as different to eyes that do not separate red from
## green -- 0.30 against 0.45 in value.
const EARTH_WET := Color(0.42, 0.29, 0.20)
const EARTH_DRY := Color(0.62, 0.49, 0.36)
const GRASS := Color(0.44, 0.66, 0.36)

var index := 0

var _box := Vector2(220, 150)
var _ground: Node2D
var _planting: Node2D
var _overlay: Node2D
var _badge: Node2D
var _ring: Node2D
var _ring_left := 0.0
## Crawling things and swaying things need a clock. Kept as one float on the
## node rather than as tweens, so that a bed which is rebuilt mid-animation
## cannot leave a tween running against a freed node.
var _t := 0.0
var _bugs: Array = []
var _sway: Array = []
var _looked_like := ""
## Where the plant is leaning while a finger pulls on it. Direct manipulation,
## not decoration: it is how a ripe carrot says "coming loose -- pull harder".
## Two numbers, not tweens, for the same reason _t is one float -- a bed that
## refreshes mid-pull must not leave a tween against a freed node.
var _lean_rot := 0.0        # radians, current
var _lean_lift := 0.0       # pixels, current (0..-22, up is negative)
var _lean_rot_to := 0.0
var _lean_lift_to := 0.0


func setup(plot_index: int) -> void:
	index = plot_index
	_box = Layout.plot_box()
	position = Layout.plot_at(index)
	_ground = Node2D.new()
	add_child(_ground)
	_planting = Node2D.new()
	add_child(_planting)
	_overlay = Node2D.new()
	add_child(_overlay)


## How big a press on this bed's middle may miss by and still be this bed.
## Half the box, so the whole rectangle is live -- there is nothing between
## beds to hit by accident.
func reach() -> Vector2:
	return _box * 0.5


## The finger is pulling on this bed. `offset` is how far it has travelled from
## where it pressed, in screen pixels -- sideways lean tilts the plant, an
## upward pull lifts it out of the hollow a little. Raw follow, no spring in
## the input path; the spring below only smooths the RENDERING.
func lean(offset: Vector2) -> void:
	_lean_rot_to = clampf(offset.x * 0.0012, -0.20, 0.20)
	_lean_lift_to = -clampf(-offset.y, 0.0, 120.0) * 0.18


## The finger left: the plant settles back, whether or not the pull succeeded.
func relax() -> void:
	_lean_rot_to = 0.0
	_lean_lift_to = 0.0


## Redraw only if something a child could see has changed.
##
## The fingerprint is every field the drawing below reads, and nothing else.
## last_seen_at moving is not something happening; a stage changing is.
func refresh(plot: Dictionary, force: bool = false) -> void:
	var now := _fingerprint(plot)
	if now == _looked_like and not force:
		return
	_looked_like = now
	_draw_ground(plot)
	_draw_planting(plot)
	_draw_badge(plot)


func _fingerprint(plot: Dictionary) -> String:
	return "%s/%s/%d/%.3f/%s/%s" % [
		str(plot.get("state", "")),
		str(plot.get("crop_id", "")),
		int(plot.get("growth_stage", 0)),
		float(plot.get("growth_progress", 0.0)),
		str(plot.get("care_event", "")),
		"dry" if float(plot.get("water_level", 1.0)) <= 0.35 else "wet",
	]


# --- what it looks like ---------------------------------------------------

func _draw_ground(plot: Dictionary) -> void:
	for child in _ground.get_children():
		child.queue_free()
	var tilled := Farm.is_tilled(plot)
	var thirsty := float(plot.get("water_level", 1.0)) <= 0.35 \
		or str(plot.get("care_event", "")) == Growth.CARE_THIRSTY
	var earth: Color = GRASS if not tilled \
		else (EARTH_DRY if thirsty else EARTH_WET)

	Shapes.ground_shadow(_ground, Vector2(0, _box.y * 0.42), _box.x * 0.86, 0.20)
	# One ink line, and only around the outside. Everything inside a bed is
	# drawn WITHOUT an outline, and that single argument is the difference
	# between soil and a wooden crate: Shapes.fill() inks whatever it is given,
	# so three inked ovals across a brown rectangle are three slats, and the
	# first cut of this screen came out as six vegetable boxes.
	Shapes.lit(_ground, Shapes.rounded_rect(-_box * 0.5, _box, 26.0), earth, 0.5)

	if not tilled:
		# Untouched grass, with the tufts that say it has never been turned.
		for i in range(5):
			var x := -_box.x * 0.34 + _box.x * 0.17 * float(i)
			Shapes.fill(_ground, PackedVector2Array([
				Vector2(x - 5, _box.y * 0.16), Vector2(x, -_box.y * 0.10),
				Vector2(x + 5, _box.y * 0.16)]),
				Color(0.34, 0.56, 0.28), 0.0)
		return

	# Turned earth: ridges and crumbs.
	#
	# THE FIRST CUT OF THIS DREW A CRATE. Three hard dark bars right across the
	# rectangle, evenly spaced, full width -- which is exactly what slats look
	# like, and every bed on the farm read as a wooden box with a vegetable
	# sitting in it. Soil is not regular: the ridges are soft, they are lit
	# along their top edge and shaded underneath, they do not reach the sides,
	# and there are crumbs between them. None of that is decoration; "is this
	# earth I can dig, or a box" is the first question a bed has to answer.
	var shade := earth.darkened(0.08)
	var lit := earth.lightened(0.10)
	for i in range(3):
		var y := -_box.y * 0.24 + _box.y * 0.24 * float(i)
		var wide: float = _box.x * (0.72 if i == 1 else 0.60)
		Shapes.fill(_ground, Shapes.oval_points(Vector2(0, y + 3.0),
			Vector2(wide * 0.5, 6.0)), shade, 0.0)
		Shapes.fill(_ground, Shapes.oval_points(Vector2(0, y),
			Vector2(wide * 0.5, 4.0)), lit, 0.0)

	# Crumbs. Fixed positions, not scattered -- nothing in this garden is
	# random, for the same reason the weeds are not (offline_growth.gd).
	for i in range(9):
		var at := Vector2(
			-_box.x * 0.36 + fmod(float(i) * 47.0, _box.x * 0.72),
			-_box.y * 0.30 + fmod(float(i) * 61.0, _box.y * 0.60))
		Shapes.fill(_ground, Shapes.circle_points(at, 3.0 + float(i % 2)),
			shade, 0.0)


func _draw_planting(plot: Dictionary) -> void:
	for child in _planting.get_children():
		child.queue_free()
	_sway.clear()
	_bugs.clear()
	if not Farm.is_planted(plot):
		return

	var crop: Dictionary = Growth.crop_for(plot,
		GameData.get_crop(str(plot.get("crop_id", ""))))
	if crop.is_empty():
		return
	var done := Growth.fraction_done(plot, crop)
	var ripe := Farm.is_ready(plot)
	var stage := int(plot.get("growth_stage", 0))

	if stage <= 0 and done <= 0.0:
		# A seed in the ground: a little mound, and nothing above it. The bed
		# has to look DIFFERENT from turned-and-empty or he will plant again.
		Shapes.fill(_planting, Shapes.oval_points(Vector2(0, 6),
			Vector2(26, 13)), EARTH_WET.lightened(0.14), 0.0)
		return

	# A dark hollow under the plant, so it is growing OUT of the bed rather than
	# resting on top of it. Cheap, and it is most of what makes the crop look
	# planted at the smallest zoom.
	Shapes.fill(_planting, Shapes.oval_points(Vector2(0, 12),
		Vector2(30, 11)), EARTH_WET.darkened(0.18), 0.0)

	var art_size := 46.0 + 58.0 * done
	var plant := UiKit.picture(str(crop.get("icon", "sprout")), art_size)
	if plant != null:
		plant.position = Vector2(-art_size * 0.5, -art_size * 0.5 - 6.0)
		plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_planting.add_child(plant)
		if ripe:
			# Ripe things move. This is the whole of "he can see it is ready"
			# from across the farm, and it costs one entry in a list.
			_sway.append(plant)

	if ripe and bool(plot.get("golden", false)):
		# Bright enough to see from the far side of the farm at the smallest
		# zoom -- the first version was a 0.30-alpha halo and was, in the
		# screenshot, completely invisible. Four little stars on top, because a
		# glow alone reads as "lit" and stars read as "special".
		Shapes.glow(_planting, Vector2(0, -10), 86.0,
			Color(1.0, 0.86, 0.34), 5, 0.62)
		for i in range(4):
			var a := TAU * float(i) / 4.0 - PI * 0.25
			Shapes.fill(_planting, Shapes.star_points(
				Vector2(cos(a), sin(a)) * 50.0 + Vector2(0, -10), 12.0),
				Color(1.0, 0.95, 0.62), 0.0)

	match str(plot.get("care_event", "")):
		Growth.CARE_WEEDS:
			_draw_weeds()
		Growth.CARE_BUG:
			_draw_bugs()


## Weeds, growing beside the plant rather than drawn on top of it. Two clumps,
## always the same two: weeds in this garden are deterministic, and a child who
## sees them in a different place every visit learns that the game is guessing.
func _draw_weeds() -> void:
	for side in [-1.0, 1.0]:
		var root := Vector2(side * _box.x * 0.28, 10.0)
		for blade in range(3):
			var lean := (float(blade) - 1.0) * 13.0
			Shapes.fill(_planting, Shapes.taper(root,
				root + Vector2(lean, -40.0 - abs(lean) * 0.4), 8.0, 1.0),
				Color(0.36, 0.60, 0.24), 1.0)


## A caterpillar on the leaf. It walks, because a bug that does not move is a
## green blob, and the point is that he SEES something is wrong.
func _draw_bugs() -> void:
	var bug := Node2D.new()
	_planting.add_child(bug)
	Shapes.fill(bug, Shapes.oval_points(Vector2.ZERO, Vector2(15, 10)),
		Color(0.52, 0.72, 0.26), 1.0)
	Shapes.fill(bug, Shapes.circle_points(Vector2(12, -3), 8.0),
		Color(0.42, 0.62, 0.20), 1.0)
	Shapes.fill(bug, Shapes.circle_points(Vector2(15, -6), 2.4),
		Color(0.12, 0.14, 0.10), 1.0)
	_bugs.append(bug)


## The one thing this bed is asking for, as a picture. Icons, not words.
func _draw_badge(plot: Dictionary) -> void:
	for child in _overlay.get_children():
		child.queue_free()
	_badge = null
	var icon := ""
	match str(plot.get("state", Farm.EMPTY)):
		Farm.EMPTY:
			icon = "soil"
		Farm.READY:
			icon = "basket"
		Farm.NEEDS_CARE:
			match str(plot.get("care_event", "")):
				Growth.CARE_THIRSTY: icon = "watering_can"
				Growth.CARE_WEEDS: icon = "weed"
				# The real caterpillar, not a symbol for one. There is a
				# painting of it already (丰收行动 uses it), and a badge that
				# shows the THING is one fewer symbol he has to be taught.
				Growth.CARE_BUG: icon = "res://assets/crops/bug.png"
	if icon == "":
		return
	var badge := Node2D.new()
	badge.position = Vector2(_box.x * 0.5 - 24.0, -_box.y * 0.5 + 4.0)
	_overlay.add_child(badge)
	Shapes.lit(badge, Shapes.circle_points(Vector2.ZERO, 29.0),
		Color(1.0, 0.99, 0.94), 0.12)
	var art := UiKit.picture(icon, 40.0)
	if art != null:
		art.position = Vector2(-20, -20)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(art)
	_badge = badge


## The progress ring, for as long as he is looking at it.
func show_ring(plot: Dictionary) -> void:
	var crop: Dictionary = Growth.crop_for(plot,
		GameData.get_crop(str(plot.get("crop_id", ""))))
	if crop.is_empty() or not Farm.is_planted(plot):
		return
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = Node2D.new()
	_overlay.add_child(_ring)
	var done := Growth.fraction_done(plot, crop)
	Shapes.fill(_ring, _annulus(58.0, 7.0, 1.0), Color(1, 1, 1, 0.42), 1.0)
	if done > 0.01:
		Shapes.fill(_ring, _annulus(58.0, 7.0, done),
			Color(1.0, 0.80, 0.18), 1.0)
	_ring_left = RING_SHOWN


func _annulus(radius: float, width: float, fraction: float) -> PackedVector2Array:
	var steps := maxi(3, int(round(48.0 * clampf(fraction, 0.0, 1.0))))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(steps + 1):
		var a: float = -PI * 0.5 + TAU * clampf(fraction, 0.0, 1.0) \
			* (float(i) / float(steps))
		var dir := Vector2(cos(a), sin(a))
		outer.append(dir * radius)
		inner.append(dir * (radius - width))
	inner.reverse()
	var ring := PackedVector2Array(outer)
	ring.append_array(inner)
	return ring


func _process(delta: float) -> void:
	_t += delta
	if _ring_left > 0.0:
		_ring_left -= delta
		if _ring_left <= 0.0 and _ring != null and is_instance_valid(_ring):
			_ring.queue_free()
			_ring = null
	if not Juice.motion_enabled():
		return
	# The lean chases the finger. A lerp rather than a hard set, so a waggle
	# reads as the plant swinging on its roots instead of vibrating.
	_lean_rot = lerpf(_lean_rot, _lean_rot_to, minf(1.0, delta * 14.0))
	_lean_lift = lerpf(_lean_lift, _lean_lift_to, minf(1.0, delta * 14.0))
	# Settled: only snap to exactly zero once the FINGER has let go and the
	# spring has carried the plant home -- snapping while a pull is building
	# would pin the plant upright under the finger.
	if is_equal_approx(_lean_rot_to, 0.0) and is_equal_approx(_lean_lift_to, 0.0) \
			and absf(_lean_rot) < 0.002 and absf(_lean_lift) < 0.3:
		_lean_rot = 0.0
		_lean_lift = 0.0
	if _planting != null and is_instance_valid(_planting):
		_planting.rotation = _lean_rot
		_planting.position = Vector2(0.0, _lean_lift)
	for plant in _sway:
		if is_instance_valid(plant):
			(plant as Control).rotation = sin(_t * 2.1) * 0.055
	for bug in _bugs:
		if is_instance_valid(bug):
			(bug as Node2D).position = Vector2(
				sin(_t * 0.9) * _box.x * 0.22, -14.0 + cos(_t * 1.7) * 4.0)
			(bug as Node2D).scale.x = 1.0 if cos(_t * 0.9) >= 0.0 else -1.0
