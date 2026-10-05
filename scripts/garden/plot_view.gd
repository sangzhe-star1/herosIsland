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
const Art := preload("res://scripts/harvest/harvest_visual_art.gd")

## Where the plant comes out of the earth: the centre of the dark hollow
## drawn in _draw_planting. The rendered crop's ground pivot is pinned here,
## so a carrot stands IN the bed the way it stands in the harvest page.
const PLANT_ROOT := Vector2(0.0, 12.0)
## How much bigger than the old flat icon the rendered crop is drawn, and the
## most it may stand above its bed, both as multiples of the growth size.
const CROP_PRESENCE := 1.3
const CROP_TALLEST := 1.55
## Half-canvas of the rendered soil patch: its loam oval is about 1.46 of
## this wide, so 158 fills the 220 px bed box with a little grass to spare.
const BED_PATCH_SIZE := 158.0

## How long the progress ring stays up after a press.
const RING_SHOWN := 3.0

## Wet earth and dry earth. Far enough apart in LIGHTNESS, not just in hue,
## that they still read as different to eyes that do not separate red from
## green -- 0.30 against 0.45 in value.
const EARTH_WET := Color(0.57, 0.40, 0.25)
const EARTH_DRY := Color(0.68, 0.52, 0.36)
const GRASS := Color(0.44, 0.66, 0.36)

var index := 0

var _box := Vector2(220, 150)
var _ground: Node2D
## A selected brush's possible landing places. This is a sibling of the
## redrawable soil/plant layers: refresh() may repaint a thirsty bed while a
## stroke is still held, but it must not erase the little answer to "where can
## this tool go?".
var _tool_target_halo: Node2D
var _tool_target_active := false
var _planting: Node2D
var _overlay: Node2D
## A short action answer must outlive the state redraw that follows it.  It is
## still owned by this PlotView (not a second feedback system), but sits beside
## `_overlay` because `_draw_badge()` intentionally clears that snapshot layer.
var _action_feedback: Node2D
## The current farm task lives beside the transient care badge, not inside its
## subtree. `_draw_badge()` deliberately clears `_overlay` on every state
## change; a world-level pointer must survive that inexpensive redraw.
var _task_beacon: Node2D
## A task flag already says the one action this bed wants.  Keep the normal
## state badge in the tree for stable refresh/test geometry, but let it yield
## visually while that stronger, page-derived instruction is present.  This is
## only a presentation priority; FarmWorld still owns the one task route and
## this PlotView still owns no input or state rules.
var _task_beacon_active := false
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
## Seconds of perk-up left after water landed. The water's WORK is in the
## timestamps; this is only the part that tells him it happened.
var _drink := 0.0


func setup(plot_index: int) -> void:
	index = plot_index
	_box = Layout.plot_box()
	position = Layout.plot_at(index)
	_ground = Node2D.new()
	add_child(_ground)
	# Between soil and plant: the ring kisses the earth edge, while the crop,
	# care badge and task flag retain their familiar visual priority above it.
	_tool_target_halo = Node2D.new()
	_tool_target_halo.name = "ToolTargetHalo"
	add_child(_tool_target_halo)
	_planting = Node2D.new()
	add_child(_planting)
	_overlay = Node2D.new()
	add_child(_overlay)
	_action_feedback = Node2D.new()
	_action_feedback.name = "PlotActionFeedback"
	_action_feedback.z_index = 1
	add_child(_action_feedback)
	# This is a sibling of `_overlay`, on purpose. The task marker is supplied
	# by FarmWorld from the screen's already-derived next task, while the badge
	# is rebuilt from the plot snapshot. Neither gets to erase the other.
	_task_beacon = Node2D.new()
	_task_beacon.name = "TaskBeacon"
	_task_beacon.z_index = 2
	add_child(_task_beacon)


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


## Water just landed on this bed. Two things happen and neither is a number:
## a few drops fall in from above, and the plant perks up with a damped
## little wobble. Fixed drop positions, like everything else here -- nothing
## in this garden is random.
func drink() -> void:
	_drink = 0.55
	if not Juice.motion_enabled() or _action_feedback == null \
			or not is_instance_valid(_action_feedback):
		return
	var xs := [-30.0, -13.0, 4.0, 21.0, 36.0]
	for i in range(xs.size()):
		var drop := Node2D.new()
		drop.name = "WaterDrop_%d" % i
		var at_x: float = xs[i]
		Shapes.fill(drop, Shapes.circle_points(Vector2.ZERO, 5.0),
			Color(0.45, 0.66, 0.92), 0.0)
		drop.position = Vector2(at_x, -74.0)
		_action_feedback.add_child(drop)
		var t := drop.create_tween()
		t.tween_interval(0.05 * float(i))
		t.tween_property(drop, "position",
			Vector2(at_x + 4.0, 2.0), 0.34)			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(drop, "modulate:a", 0.0, 0.12)
		t.tween_callback(drop.queue_free)


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
	return "%s/%s/%d/%.3f/%s/%s/%s" % [
		str(plot.get("state", "")),
		str(plot.get("crop_id", "")),
		int(plot.get("growth_stage", 0)),
		float(plot.get("growth_progress", 0.0)),
		str(plot.get("care_event", "")),
		"dry" if float(plot.get("water_level", 1.0)) <= 0.35 else "wet",
		"golden" if bool(plot.get("golden", false)) else "ordinary",
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
	# A narrow rim is enough to say "grass meets soil". A wide saturated ring
	# made the two world layers compete with the crop for attention.
	var grass_island := _patch_blob(_box * 0.49)

	if not tilled:
		# Untouched grass: the studio's meadow patch, daisies and all, on the
		# same footprint the soil patch will take when he turns it.
		var meadow := Art.prop_texture("meadow_patch")
		if meadow != null:
			var lawn := Art.grounded_sprite(meadow, BED_PATCH_SIZE * 0.98,
				Vector2(0.0, _box.y * 0.40), "MeadowPatch")
			lawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ground.add_child(lawn)
			return
		Shapes.fill(_ground, grass_island, GRASS.lightened(0.05), 0.0)
		var tuft := Art.prop_texture("tuft")
		for i in range(5):
			var x := -_box.x * 0.34 + _box.x * 0.17 * float(i)
			if tuft != null:
				var blade := Art.grounded_sprite(tuft, 26.0,
					Vector2(x, _box.y * (0.10 if i % 2 == 0 else 0.18)), "Tuft")
				blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_ground.add_child(blade)
			else:
				Shapes.fill(_ground, PackedVector2Array([
					Vector2(x - 5, _box.y * 0.16), Vector2(x, -_box.y * 0.10),
					Vector2(x + 5, _box.y * 0.16)]),
					Color(0.34, 0.56, 0.28), 0.0)
		return

	# The Blender surface anchor sits on the soil's top, above the model's
	# ground origin. Pin that surface to the same root as the crop so a raised
	# bed cannot leave the plant floating over its front edge. Dry earth uses
	# the same geometry with the existing tint and cracks.
	var patch := Art.prop_texture("soil_grass_patch")
	if patch != null:
		var legacy_surface := Vector2(256.0, Art.GROUND_ORIGIN_PIXEL_Y + 8.0
			* Art.SOURCE_CANVAS_SIZE / (BED_PATCH_SIZE * Art.SPRITE_CANVAS_MULTIPLIER))
		var surface := Art.prop_anchor_pixel("soil_grass_patch", "planting_surface", legacy_surface)
		var bed := Art.anchored_sprite(patch, BED_PATCH_SIZE, surface, PLANT_ROOT, "BedPatch")
		bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if thirsty:
			bed.modulate = Color(1.0, 0.92, 0.78)
		_ground.add_child(bed)
		if thirsty:
			_draw_dry_cracks(earth)
		return

	# A small contact shadow is enough to seat a bed. A giant ellipse around
	# every plot made the opening view read as six separate UI cards.
	Shapes.ground_shadow(_ground, Vector2(0, _box.y * 0.40), _box.x * 0.64, 0.07)

	# The bed has a very small raised edge: a warm side wall, then its sunlit
	# top. This gives the crop somewhere to grow *from* without turning every
	# plot into a dark sticker or introducing a second 3D scene system.
	# Everything stays unoutlined; the crop and its care signal keep the only
	# strong contrast a young player needs to find the next action.
	# This rim is only the grass pressed down around the bed. It intentionally
	# stays close to the world meadow instead of becoming another green island.
	Shapes.fill(_ground, grass_island, Color(0.70, 0.83, 0.56), 0.0)
	var soil_side := _patch_blob(_box * 0.448, Vector2(1.5, 4.5))
	Shapes.fill(_ground, soil_side, earth.darkened(0.10), 0.0)
	var soil_island := _patch_blob(_box * 0.435, Vector2(-1.0, -2.0))
	Shapes.lit(_ground, soil_island, earth, 0.0)

	# Crumbs are enough surface detail at this scale. The old broad horizontal
	# mounds read as wooden slats, then fought the crop's silhouette. Fixed
	# positions keep this a familiar patch of earth rather than visual noise.
	var shade := earth.darkened(0.05)
	for i in range(9):
		var at := Vector2(
			-_box.x * 0.36 + fmod(float(i) * 47.0, _box.x * 0.72),
			-_box.y * 0.30 + fmod(float(i) * 61.0, _box.y * 0.60))
		Shapes.fill(_ground, Shapes.circle_points(at, 3.0 + float(i % 2)),
			shade, 0.0)
	if thirsty:
		_draw_dry_cracks(earth)


## Fixed organic outlines let soil be a little irregular without jumping when
## the farm refreshes. The plot index is stable across saves and camera moves,
## which makes the shape part of the place rather than an animation.
func _patch_blob(radii: Vector2, centre: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 32_557 + index * 7_919
	# Gentle, high-resolution contours read as turned earth. Large scallops made
	# the old beds look like six unrelated rock stickers from the overview.
	return Shapes.blob(centre, radii, rng, 0.035, 4, 42)


## Water is an action a child already understands from the earth itself.  These
## fixed, short cracks sit at the soil edge rather than under the crop, so the
## bed reads thirsty even when its little water-can reminder is momentarily
## out of view.  They are paint only; `water_level` remains the sole rule.
func _draw_dry_cracks(earth: Color) -> void:
	var crack := earth.darkened(0.34)
	for segment in [
		{"from": Vector2(-61.0, -22.0), "to": Vector2(-44.0, -13.0)},
		{"from": Vector2(-44.0, -13.0), "to": Vector2(-53.0, -1.0)},
		{"from": Vector2(55.0, 26.0), "to": Vector2(63.0, 15.0)},
		{"from": Vector2(63.0, 15.0), "to": Vector2(48.0, 7.0)},
		{"from": Vector2(21.0, -4.0), "to": Vector2(35.0, 4.0)},
	]:
		var from: Vector2 = segment["from"]
		var to: Vector2 = segment["to"]
		Shapes.fill(_ground, Shapes.taper(from, to, 2.6, 0.8), crack, 0.0)


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
	var golden := bool(plot.get("golden", false))

	if stage <= 0 and done <= 0.0:
		# A seed in the ground: a little mound, and nothing above it. The bed
		# has to look DIFFERENT from turned-and-empty or he will plant again.
		Shapes.fill(_planting, Shapes.oval_points(Vector2(0, 6),
			Vector2(26, 13)), EARTH_WET.lightened(0.14), 0.0)
		if golden:
			# Even the buried seed keeps its quiet golden promise. The brighter
			# halo and stars wait until the crop is ready to pick.
			Shapes.glow(_planting, Vector2(0, 6), 50.0,
				Color(1.0, 0.82, 0.20), 5, 0.42)
		return

	# The crop gets the same short, soft contact shadow as every other object in
	# the farm. The bitmap can keep its clear child-friendly outline without
	# reading as a sticker dropped on the soil.
	Shapes.ground_shadow(_planting, Vector2(2, 17), 62.0, 0.12)
	# A dark hollow under the plant, so it is growing OUT of the bed rather than
	# resting on top of it. Cheap, and it is most of what makes the crop look
	# planted at the smallest zoom.
	Shapes.fill(_planting, Shapes.oval_points(Vector2(0, 12),
		Vector2(30, 11)), EARTH_WET.darkened(0.18), 0.0)
	if golden and not ripe:
		# A gentle backlight carries the rare identity through the growing
		# stages without competing with the ripe state's four stars. It stays
		# broad and soft so it reads around the crop at overview zoom without
		# turning the whole berry or leaf into a yellow block.
		Shapes.glow(_planting, Vector2(0, -10), 96.0,
			Color(1.0, 0.78, 0.16), 5, 0.78)

	var art_size := 46.0 + 58.0 * done
	var plant := _crop_art(str(crop.get("id", plot.get("crop_id", ""))),
		str(crop.get("icon", "sprout")), golden, art_size)
	if plant != null:
		plant.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_planting.add_child(plant)
		if ripe:
			# Ripe things move. This is the whole of "he can see it is ready"
			# from across the farm, and it costs one entry in a list.
			_sway.append(plant)
			if not bool(plot.get("golden", false)):
				_draw_ready_glints()

	if ripe and golden:
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


## The crop itself: the same rendered sprite the harvest page uses, so a
## child walking from the garden to the harvest level sees one carrot, not a
## flat sticker in one room and a toy in the next. Its ground pivot sits on
## the hollow and it rotates about its root when it sways. A crop with no
## render yet (none today; the pipeline covers all seventeen) falls back to
## the drawn icon, floating as it used to.
func _crop_art(crop_id: String, icon: String, golden: bool, art_size: float) -> Control:
	var texture: Texture2D = Art.crop_texture("golden_" + crop_id) if golden else null
	if texture == null:
		texture = Art.crop_texture(crop_id)
	if texture != null:
		# The render fills about half its canvas, so it is drawn larger than
		# the flat icon was to hold the same presence from across the farm;
		# the tall ones (carrot, wheat) are then held to a height the bed can
		# carry, so a ripe carrot does not stand into the next row.
		var world := art_size * CROP_PRESENCE
		var seen := Art.texture_used_bounds(texture, world,
			Vector2(Art.SOURCE_CANVAS_SIZE * 0.5, Art.GROUND_ORIGIN_PIXEL_Y))
		var tallest := art_size * CROP_TALLEST
		if seen.size.y > tallest:
			world *= tallest / seen.size.y
		var sprite := Art.grounded_sprite(texture, world, PLANT_ROOT, "Crop3D")
		sprite.pivot_offset = PLANT_ROOT - sprite.position
		return sprite
	var picture := UiKit.picture(icon, art_size)
	if picture != null:
		picture.position = Vector2(-art_size * 0.5, -art_size * 0.5 - 6.0)
	return picture


## A normal ripe crop earns two pale, four-point glints rather than the rare
## crop's gold halo and four stars.  At overview distance that is enough to say
## "ready to pick" while leaving the special golden celebration unmistakable.
func _draw_ready_glints() -> void:
	var glint := Color(1.0, 0.95, 0.73, 0.86)
	for sparkle in [
		{"at": Vector2(-38.0, 24.0), "size": 5.5},
		{"at": Vector2(37.0, -15.0), "size": 4.0},
	]:
		var at: Vector2 = sparkle["at"]
		Shapes.fill(_planting, Shapes.star_points(at, float(sparkle["size"]),
			0.38, 4), glint, 0.0)


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
	# The icon tells a child what to do; this quiet, state-specific backing lets
	# him sort the four kinds of work before he has learned every tiny drawing.
	# They are deliberately pastel rather than reward-gold: a ripe ordinary crop
	# must not impersonate the rare golden-crop celebration.
	var fill := Color(0.95, 0.86, 0.66)
	var rim := Color(0.67, 0.50, 0.29)
	match str(plot.get("state", Farm.EMPTY)):
		Farm.EMPTY:
			icon = "soil"
		Farm.READY:
			icon = "basket"
			fill = Color(1.0, 0.93, 0.66)
			rim = Color(0.75, 0.57, 0.24)
		Farm.NEEDS_CARE:
			match str(plot.get("care_event", "")):
				Growth.CARE_THIRSTY:
					icon = "watering_can"
					fill = Color(0.73, 0.91, 1.0)
					rim = Color(0.28, 0.61, 0.83)
				Growth.CARE_WEEDS:
					icon = "weed"
					fill = Color(0.80, 0.94, 0.72)
					rim = Color(0.34, 0.64, 0.31)
				# The real caterpillar, not a symbol for one. There is a
				# painting of it already (丰收行动 uses it), and a badge that
				# shows the THING is one fewer symbol he has to be taught.
				Growth.CARE_BUG:
					icon = "res://assets/crops/bug.png"
					fill = Color(1.0, 0.80, 0.72)
					rim = Color(0.83, 0.39, 0.34)
	if icon == "":
		return
	var badge := Node2D.new()
	badge.name = "PlotStatusBadge"
	badge.position = Vector2(_box.x * 0.5 - 24.0, -_box.y * 0.5 + 4.0)
	_overlay.add_child(badge)
	# A coloured rim is softer than an ink circle but still keeps the picture
	# legible over grass, soil and a pale crop.  The small downward offset also
	# reads as contact shadow, not a second white map pin.
	var rim_shadow := rim.darkened(0.10)
	rim_shadow.a = 0.45
	Shapes.fill(badge, Shapes.circle_points(Vector2(0.0, 2.0), 30.5), rim_shadow, 0.0)
	var face := Shapes.lit(badge, Shapes.circle_points(Vector2.ZERO, 28.5), fill, 0.0)
	face.name = "PlotStatusBadgeSurface"
	var art := UiKit.picture(icon, 40.0)
	if art != null:
		art.position = Vector2(-20, -20)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(art)
	# The flag carries this same current action for the one primary task.  Hiding
	# the duplicate badge there removes a competing circle without removing any
	# hit target or the state picture from all the other beds.
	badge.visible = not _task_beacon_active
	_badge = badge


## Point to this bed's one current world task. This is presentation only: the
## screen decides which task exists, and FarmWorld chooses which PlotView gets
## it. A Node2D plus mouse-ignoring art has no hit shape and cannot change the
## forgiving bed hit test below it.
func set_task_beacon(icon: String, tint: Color) -> void:
	_task_beacon_active = icon != ""
	if _badge != null and is_instance_valid(_badge):
		_badge.visible = not _task_beacon_active
	if _task_beacon == null or not is_instance_valid(_task_beacon):
		return
	for child in _task_beacon.get_children():
		_task_beacon.remove_child(child)
		child.free()
	if icon == "":
		return
	# The pole lands in the left grass rim; its pennant stays out of the crop's
	# centre and the care badge's top-right corner.
	var flag := Node2D.new()
	flag.name = "TaskBeaconFlag"
	flag.position = Vector2(-_box.x * 0.36, -_box.y * 0.36)
	_task_beacon.add_child(flag)
	draw_task_beacon(flag, icon, tint, 0.82)


## A brush has already been chosen by the screen. This ring does not decide
## what that brush can do -- FarmToolController remains the single rule -- it
## only makes every currently compatible bed easy to spot before a small hand
## starts a sweep. `primary` is the bed already carrying the stronger next-task
## flag, so its ring intentionally steps back rather than competing with it.
func set_tool_target(active: bool, tint: Color, primary: bool = false) -> void:
	if _tool_target_halo == null or not is_instance_valid(_tool_target_halo):
		return
	for child in _tool_target_halo.get_children():
		_tool_target_halo.remove_child(child)
		child.free()
	_tool_target_active = active
	_tool_target_halo.modulate = Color.WHITE
	if not active:
		return
	var halo := Node2D.new()
	halo.name = "ToolTargetRing"
	_tool_target_halo.add_child(halo)
	var alpha := 0.10 if primary else 0.26
	var outer := tint
	outer.a = alpha
	# One fine ring rides the grass edge: it guides a sweep without turning a
	# living crop into a radar target.  51px stays inside the 75px half-height
	# of a bed and away from its flag and care badge on 4:3.
	Shapes.fill(halo, _annulus(51.0, 2.4, 1.0), outer, 0.0)


## Shared by a bed and the orders building so the small world flag uses the
## same icon and colour language as the shelf ribbon. It intentionally has no
## tween: the task ribbon already provides gentle motion when appropriate, and
## a quiet landmark lets the crop/care feedback keep the child's attention.
static func draw_task_beacon(parent: Node2D, icon: String, tint: Color,
	scale: float = 1.0) -> void:
	if icon == "":
		return
	var cloth := tint
	cloth.a = 1.0
	var wood := Color(0.45, 0.34, 0.22)
	var pole_top := Vector2(0.0, -52.0 * scale)
	var pole_bottom := Vector2(0.0, 44.0 * scale)
	Shapes.fill(parent, Shapes.taper(pole_bottom, pole_top,
		7.0 * scale, 4.4 * scale), wood, 0.65)
	Shapes.lit(parent, Shapes.circle_points(pole_top, 5.5 * scale),
		Color(1.0, 0.84, 0.34), 0.55)
	var pennant := Node2D.new()
	pennant.name = "TaskBeaconPennant"
	pennant.position = pole_top + Vector2(2.0 * scale, 0.0)
	parent.add_child(pennant)
	Shapes.lit(pennant, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(60.0 * scale, 9.0 * scale),
		Vector2(47.0 * scale, 23.0 * scale), Vector2(60.0 * scale, 37.0 * scale),
		Vector2(0.0, 47.0 * scale),
	]), cloth, 0.78)
	var badge_at := Vector2(29.0 * scale, 24.0 * scale)
	Shapes.lit(pennant, Shapes.circle_points(badge_at, 14.0 * scale),
		Color(1.0, 0.99, 0.92, 0.90), 0.35)
	var art := UiKit.picture(icon, 22.0 * scale)
	if art != null:
		art.name = "TaskBeaconIcon"
		art.position = badge_at - Vector2.ONE * 11.0 * scale
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pennant.add_child(art)


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
	if _tool_target_active and _tool_target_halo != null \
			and is_instance_valid(_tool_target_halo):
		var halo_tint := Color.WHITE
		halo_tint.a = 0.94 + 0.06 * sin(_t * 1.8 + float(index) * 0.6) \
			if Juice.motion_enabled() else 1.0
		_tool_target_halo.modulate = halo_tint
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
		# The perk after a drink: a damped wobble that settles as the timer
		# runs out, then snaps to exactly one so nothing drifts.
		if _drink > 0.0:
			_drink = maxf(0.0, _drink - delta)
			var wobble := 1.0 + 0.07 * sin((0.55 - _drink) * 16.0) \
				* (_drink / 0.55)
			_planting.scale = Vector2(wobble, wobble)
		elif not is_equal_approx(_planting.scale.x, 1.0):
			_planting.scale = Vector2.ONE
	for plant in _sway:
		if is_instance_valid(plant):
			(plant as Control).rotation = sin(_t * 2.1) * 0.055
	for bug in _bugs:
		if is_instance_valid(bug):
			(bug as Node2D).position = Vector2(
				sin(_t * 0.9) * _box.x * 0.22, -14.0 + cos(_t * 1.7) * 4.0)
			(bug as Node2D).scale.x = 1.0 if cos(_t * 0.9) >= 0.0 else -1.0
