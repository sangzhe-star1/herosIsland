extends Node2D
## One thing that can be picked, and the whole of what "picked once" means.
##
## Not a Button. A Button answers a press; these answer a *gesture*, and which
## gesture depends on what is growing. The area a finger has to land in is a
## circle around the middle -- bigger than the picture, and bigger still on the
## gentle setting -- because a six-year-old aims at the thing, not at its edge.

const Gesture := preload("res://scripts/harvest/gesture.gd")
const Maturity := preload("res://scripts/harvest/maturity.gd")
const VisualArt := preload("res://scripts/harvest/harvest_visual_art.gd")

## Loaded by path rather than preloaded: a missing art pass must cost the
## palette adaptation, not the whole screen.
const HARVEST_TONE_SHADER := "res://resources/shaders/harvest_crop_tone.gdshader"
const HELD_SCALE := 1.12

signal picked(target: Node2D)
signal refused(target: Node2D, why: String)

var crop: Dictionary = {}
var step := Maturity.READY
var radius := 78.0

## Once true, this one is out of the game. It stops answering, stops being
## found by the nearest-target search, and cannot be picked a second time --
## which is the same rule the garden's harvest keeps, for the same reason.
var taken := false

## Rejection feedback moves this local display group, preserving the
## target origin used by input, planting and lift/basket travel.
var _visual: Node2D
var _art: Control
var _halo: Node2D
## What the gesture acts on -- the stem, the branch, the arrow.
var _affordance: Node2D
## The soil over a buried crop, cleared as it is swept.
var _cover: Node2D
var _sway_tween: Tween
var _move_tween: Tween
var _held_bob: Tween
var _refuse_tween: Tween


func build(crop_data: Dictionary, ripeness: String, tolerance: float,
		art_scale: float = 1.0) -> void:
	crop = crop_data
	step = Maturity.normalise(ripeness)
	radius = tolerance
	var look := Maturity.look(step, crop)

	_visual = Node2D.new()
	_visual.name = "HarvestTargetVisual"
	_visual.position = Vector2.ZERO
	add_child(_visual)

	_halo = Node2D.new()
	_visual.add_child(_halo)
	_draw_halo(str(look.get("halo", "none")))

	# Catalogue art stays the recognised crop language, but at world scale it
	# needs room to grow out of the soil rather than reading as a giant HUD icon.
	var size: float = 90.0 * float(look.get("scale", 1.0)) \
		* clampf(art_scale, 0.6, 1.0)
	var art_ref := str(crop.get("asset", crop.get("id", "")))
	var crop_texture := VisualArt.crop_texture(str(crop.get("id", art_ref)))
	var plant := VisualArt.plant_layout(str(crop.get("id", "")), art_scale)
	if not plant.is_empty():
		crop_texture = plant["fruit"]
		size = float(plant["fruit_size"]) * float(look.get("scale", 1.0))
	var has_3d_art := crop_texture != null
	if not plant.is_empty():
		_art = VisualArt.anchored_sprite(crop_texture, size,
			plant["fruit_center_pixel"], Vector2.ZERO, "HarvestPlantFruit3DArt")
	elif has_3d_art:
		_art = VisualArt.grounded_sprite(crop_texture, size, Vector2(0.0, 42.0),
			"HarvestCrop3DArt")
	else:
		_art = UiKit.picture(art_ref, size)
	if _art != null:
		if not has_3d_art:
			_art.position = Vector2(-size * 0.5, -size * 0.5)
		_art.modulate = look.get("tint", Color.WHITE)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual.add_child(_art)

		# Keep harvest crop artwork in one palette pass: the source catalogue
		# stays recognizable, while dark ink and saturation are softened to sit
		# closer to the watercolor field. The same pass carries unripe wash.
		var wash: Color = look.get("wash", Color(0, 0, 0, 0))
		if _art is TextureRect:
			var mat := ShaderMaterial.new()
			mat.shader = load(HARVEST_TONE_SHADER)
			mat.set_shader_parameter("maturity_tint", look.get("tint", Color.WHITE))
			mat.set_shader_parameter("wash", Color(wash.r, wash.g, wash.b, 1.0))
			mat.set_shader_parameter("wash_amount", wash.a)
			mat.set_shader_parameter("palette_adaptation", not has_3d_art)
			_art.material = mat
			_art.modulate = Color.WHITE

	# What this gesture needs to SEE to be doable.
	#
	# A recogniser with nothing drawn for it is a rule nobody can follow: a
	# child asked to cut a stem with no stem on screen, or to dig with no soil
	# over the crop, is being asked to guess. Each of these is drawn from the
	# crop's own recogniser, so adding a crop cannot forget it.
	_draw_affordance(size)

	var sway := float(look.get("sway", 0.0))
	if sway > 0.0 and Juice.motion_enabled():
		_sway_tween = create_tween().set_loops()
		var t := _sway_tween
		t.tween_property(self, "rotation_degrees", sway, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(self, "rotation_degrees", -sway, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The thing the gesture acts ON, drawn under the crop.
##
##   line    a glowing stem across the middle -- the line to cut through
##   sweep   a mound of soil over it, or a branch it hangs from
##   drag    an arrow the way it has to go, for the long ones
##
## Tap needs nothing: the crop itself is the target and "touch the thing" is
## the one instruction that needs no diagram.
func _draw_affordance(crop_size: float) -> void:
	var art := Node2D.new()
	art.z_index = -2
	_visual.add_child(art)
	_affordance = art
	var params: Dictionary = crop.get("gesture_params", {})

	match str(crop.get("recogniser", "")):
		Gesture.LINE:
			# Keep the actual recogniser width in data, but show a compact stem
			# instead of a full-screen neon bar behind the crop. TutorialDirector
			# still demonstrates the cutting motion when it is needed.
			var half: float = minf(float(params.get("line_half_width", 74.0)), 46.0)
			Shapes.fill(art, Shapes.rounded_rect(Vector2(-half, -5.0),
				Vector2(half * 2.0, 10.0), 5.0),
				Color(0.20, 0.45, 0.22, 0.82), 0.0)
			Shapes.fill(art, Shapes.rounded_rect(Vector2(-half + 8.0, -1.5),
				Vector2(maxf(half * 2.0 - 16.0, 1.0), 3.0), 1.5),
				Color(0.78, 0.88, 0.54, 0.62), 0.0)
		Gesture.SWEEP:
			var over := str(crop.get("sweep_cover", "soil"))
			if over == "branch":
				_draw_hanging_branch(art, crop_size)
			else:
				# Buried: a mound of earth sitting over it, which is why the
				# crop underneath cannot simply be tapped.
				_cover = Node2D.new()
				_cover.name = "HarvestSoilCover"
				_visual.add_child(_cover)
				_cover.z_index = 2
				var earth := VisualArt.soil_cover_layout(crop_size)
				if not earth.is_empty():
					var sprite := VisualArt.grounded_sprite(earth["texture"],
						earth["size"], earth["ground_at"], "HarvestSoilCover3DArt")
					_cover.add_child(sprite)
				else:
					Shapes.fill(_cover, Shapes.rounded_rect(Vector2(-78, -52),
						Vector2(156, 104), 44.0), Color(0.42, 0.29, 0.19), 1.0)
					Shapes.fill(_cover, Shapes.rounded_rect(Vector2(-52, -34),
						Vector2(104, 26), 13.0), Color(0.52, 0.37, 0.25, 0.8), 0.0)
		Gesture.DRAG:
			var way := Vector2(float(params.get("direction_x", 0.0)),
				float(params.get("direction_y", -1.0))).normalized()
			var distance := float(params.get("distance", 90.0))
			# A short upward pull follows the shape of a rooted crop. A short
			# downward swipe does not, so keep a compact arrow for that move too.
			# Long pushes still get the same cue as before.
			var short_down_cue := distance < 140.0 and way.y > 0.5
			if distance < 140.0 and not short_down_cue:
				return
			var shaft_start := 38.0 if short_down_cue else 46.0
			var head_depth := 15.0 if short_down_cue else 22.0
			var head_half_width := 11.0 if short_down_cue else 15.0
			var tip_distance := clampf(distance * 0.72, 58.0, 84.0) \
				if short_down_cue else 96.0
			var tip: Vector2 = way * tip_distance
			var arrow := Line2D.new()
			arrow.name = "HarvestDirectionCue"
			arrow.points = PackedVector2Array([way * shaft_start, tip])
			arrow.width = 8.0 if short_down_cue else 11.0
			arrow.default_color = Color(1.0, 0.94, 0.55, 0.75)
			arrow.antialiased = true
			art.add_child(arrow)
			var head := Shapes.fill(art, PackedVector2Array([
				tip + way * head_depth,
				tip + way.orthogonal() * head_half_width,
				tip - way.orthogonal() * head_half_width]),
				Color(1.0, 0.94, 0.55, 0.75), 0.0)
			head.name = "HarvestDirectionArrowhead"
		Gesture.TWIST:
			_draw_twist_affordance(art, crop_size)


## A short arc around the visible fruit says "turn it"; opposing tangent
## arrowheads make clear that either direction works. Keep it on the source
## silhouette, inside the existing touch radius, and below the crop.
func _draw_twist_affordance(art: Node2D, crop_size: float) -> void:
	var fruit := Rect2(Vector2(-crop_size * 0.5, -crop_size * 0.5),
		Vector2.ONE * crop_size)
	if _art is TextureRect:
		fruit = VisualArt.texture_used_bounds(_art.texture, _art.size.x * 0.5,
			Vector2.ZERO, _art.position)
	var centre := fruit.get_center()
	var radius := clampf(maxf(fruit.size.x, fruit.size.y) * 0.5 + 9.0,
		34.0, 58.0)
	var start_angle := deg_to_rad(210.0)
	var end_angle := deg_to_rad(330.0)
	var arc_points := PackedVector2Array()
	for point_index in range(13):
		var fraction := float(point_index) / 12.0
		var angle := lerpf(start_angle, end_angle, fraction)
		arc_points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	var arc := Line2D.new()
	arc.name = "HarvestTwistArc"
	arc.points = arc_points
	arc.width = 5.0
	arc.default_color = Color(1.0, 0.88, 0.50, 0.84)
	arc.antialiased = true
	art.add_child(arc)
	var start_tangent := Vector2(-sin(start_angle), cos(start_angle))
	var end_tangent := Vector2(-sin(end_angle), cos(end_angle))
	_draw_twist_arrowhead(art, arc_points[0], -start_tangent,
		arc.default_color, "HarvestTwistArrowheadStart")
	_draw_twist_arrowhead(art, arc_points[-1], end_tangent,
		arc.default_color, "HarvestTwistArrowheadEnd")


func _draw_twist_arrowhead(art: Node2D, tip: Vector2, direction: Vector2,
		color: Color, node_name: String) -> Polygon2D:
	var base := tip - direction * 12.0
	var wing := direction.orthogonal() * 7.0
	var arrowhead := Shapes.fill(art, PackedVector2Array([
		tip, base + wing, base - wing]), color, 0.0)
	arrowhead.name = node_name
	return arrowhead


## A short hanging twig explains shaking without crossing the next fruit.
## Fit it to the actual alpha silhouette, including smaller unripe artwork.
## It stays inside the passive display group; the crop owns the gesture.
func _draw_hanging_branch(art: Node2D, crop_size: float) -> void:
	art.name = "HarvestBranchCue"
	var fruit := Rect2(Vector2(-crop_size * 0.5, -crop_size * 0.5),
		Vector2.ONE * crop_size)
	if _art is TextureRect:
		fruit = VisualArt.texture_used_bounds(_art.texture, _art.size.x * 0.5,
			Vector2.ZERO, _art.position)
	var middle := fruit.get_center().x
	var top := fruit.position.y
	var half := clampf(crop_size * 0.68, 46.0, 68.0) * 0.5
	var branch_y := top - 12.0
	var points := PackedVector2Array([
		Vector2(middle - half, branch_y + 2.0),
		Vector2(middle - half * 0.48, branch_y + 7.0),
		Vector2(middle + half * 0.04, branch_y + 10.0),
		Vector2(middle + half * 0.52, branch_y + 7.0),
		Vector2(middle + half, branch_y + 2.0),
	])
	var twig := Shapes.fill(art, Shapes.ribbon(points, 5.2),
		Color(0.53, 0.37, 0.22), 0.0)
	twig.name = "HarvestBranchTwig"
	Shapes.fill(art, Shapes.ribbon(PackedVector2Array([
		points[0] + Vector2(2.0, -1.0),
		points[2] + Vector2(0.0, -1.0),
		points[4] + Vector2(-3.0, -1.0),
	]), 1.4), Color(0.70, 0.52, 0.32), 0.0)
	# A short tapered stem joins the fruit's crown to the bough. Its overlap
	# with the actual alpha edge avoids the detached-cap look at small sizes.
	Shapes.fill(art, Shapes.taper(points[2], Vector2(middle, top + 4.0),
		3.4, 2.0), Color(0.47, 0.38, 0.23), 0.0)
	# A single upward spur makes the support read as a living branch while
	# staying within the same narrow width used to protect nearby touch targets.
	var spur_root := Vector2(middle + half * 0.40, branch_y + 7.0)
	var spur_tip := spur_root + Vector2(half * 0.12, -9.0)
	Shapes.fill(art, Shapes.taper(spur_root, spur_tip, 2.7, 1.5),
		Color(0.48, 0.34, 0.20), 0.0)
	var leaf_center := spur_tip + Vector2(3.0, -1.0)
	var leaf_points := PackedVector2Array([
		leaf_center + Vector2(-7.0, 1.0),
		leaf_center + Vector2(-1.0, -4.0),
		leaf_center + Vector2(7.0, -2.0),
		leaf_center + Vector2(2.0, 3.0),
	])
	Shapes.fill(art, leaf_points, Color(0.42, 0.57, 0.30), 0.0)


## Soil coming off as the finger sweeps, so digging looks like digging.
func uncover(fraction: float) -> void:
	if _cover == null or not is_instance_valid(_cover):
		return
	_cover.modulate.a = clampf(1.0 - fraction, 0.0, 1.0)
	_cover.scale = Vector2.ONE * (1.0 - 0.2 * clampf(fraction, 0.0, 1.0))


## A ring for ready, a star for golden, nothing for the two that are not yet.
## Drawn rather than tinted, so it survives a child who cannot see the tint.
func _draw_halo(kind: String) -> void:
	match kind:
		"soft":
			Shapes.glow(_halo, Vector2.ZERO, 96.0, Color(1.0, 0.96, 0.62), 4, 0.30)
		"star":
			Shapes.glow(_halo, Vector2.ZERO, 116.0, Color(1.0, 0.88, 0.36), 5, 0.44)
			var star: Control = UiKit.picture("star", 44.0)
			if star != null:
				star.position = Vector2(28, -74)
				star.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_halo.add_child(star)


func in_reach(at: Vector2) -> bool:
	return not taken and global_position.distance_to(at) <= radius


## Ask this target whether that was its gesture. Only ever called with a track
## that started inside in_reach().
func try_gesture(track: PackedVector2Array, allowed: Array) -> bool:
	if taken:
		return false
	if not Maturity.pickable(step, allowed):
		refuse("unripe")
		return false
	var ok: bool = Gesture.satisfied(str(crop.get("recogniser", "")),
		crop.get("gesture_params", {}), track, global_position)
	if not ok:
		refuse("gesture")
		return false
	taken = true
	picked.emit(self)
	return true


## "Not that one" -- said with a shake of the head and a sound, never with a
## penalty. Nothing is lost here: no time, no star, no coin, nothing taken back.
## The only thing a refusal feeds is the hint director, which is a counter for
## HELP and not for punishment.
func refuse(why: String) -> void:
	refused.emit(self, why)
	if _refuse_tween != null and _refuse_tween.is_valid():
		_refuse_tween.kill()
	_refuse_tween = null
	if _visual == null or not is_instance_valid(_visual):
		return
	# Every rejection starts from the fixed local origin, including rapid
	# retries and a setting switch to reduced motion during a shake.
	_visual.position = Vector2.ZERO
	if not Juice.motion_enabled():
		return
	_refuse_tween = create_tween()
	var t := _refuse_tween
	t.tween_property(_visual, "position", Vector2(9, 0), 0.06)
	t.tween_property(_visual, "position", Vector2(-9, 0), 0.06)
	t.tween_property(_visual, "position", Vector2(5, 0), 0.05)
	t.tween_property(_visual, "position", Vector2.ZERO, 0.05)


## Off the plant and into his hand -- still here, still his, not yet put away.
##
## Two differences from fly_to. It stays, because a crop waiting to be sorted
## has to remain on screen and remain the thing the next touch is about. And it
## rises where it grew rather than travelling anywhere: the first cut parked it
## on a free patch of ground beside the baskets, and on screen that was a
## strawberry sitting on the soil looking exactly like the strawberries still
## growing on the soil. Held and growing have to be told apart at a glance, and
## "it lifted up off the plant and it is glowing" does that where "it moved
## eighty pixels sideways" does not.
## Passive plant artwork may need extra clearance; ordinary crops keep the
## established lift. The page measures that clearance from source alpha.
func held_lift_height(base_height: float = 46.0) -> float:
	return maxf(base_height, float(get_meta("visual_lift_clearance", base_height)))


## The carry reminder surrounds the visible crop rather than its transparent
## source canvas or generous input radius. This changes artwork only.
func held_art_radius() -> float:
	if _art == null or not is_instance_valid(_art):
		return radius * 0.62
	var visible_size := _art.size
	if _art is TextureRect:
		var texture := (_art as TextureRect).texture
		var source := texture.get_image() if texture != null else null
		if source != null:
			var factor := minf(_art.size.x / source.get_width(),
				_art.size.y / source.get_height())
			visible_size = Vector2(source.get_used_rect().size) * factor
	return maxf(16.0, maxf(visible_size.x, visible_size.y) * HELD_SCALE * 0.5)


func held_lift_displacement(base_height: float = 46.0) -> Vector2:
	return Vector2(0.0, -held_lift_height(base_height)) \
		+ Vector2(get_meta("visual_held_shift", Vector2.ZERO))


func lift(height: float = 46.0) -> void:
	var displacement := held_lift_displacement(height)
	_stop_motion_tweens()
	rotation_degrees = 0.0
	for extra in [_halo, _affordance, _cover]:
		if extra != null and is_instance_valid(extra):
			extra.queue_free()

	# A thin landing oval and light behind it.  The old opaque cream saucer was
	# readable, but looked like a second giant UI badge under the crop.  This
	# keeps the held state unmistakable while making the crop feel lifted from
	# the soil rather than pasted onto a white disc.
	var lamp := Node2D.new()
	lamp.name = "HeldCue"
	lamp.z_index = -1
	_visual.add_child(lamp)
	Shapes.glow(lamp, Vector2(0.0, -radius * 0.05), radius * 0.50,
		Color(1.0, 0.86, 0.30), 4, 0.22)
	Shapes.fill(lamp, Shapes.oval_points(Vector2(0.0, radius * 0.54),
		Vector2(radius * 0.54, radius * 0.14), 28),
		Color(0.16, 0.18, 0.18, 0.18), 0.0)
	Shapes.fill(lamp, Shapes.oval_points(Vector2(0.0, radius * 0.49),
		Vector2(radius * 0.38, radius * 0.085), 28),
		Color(1.0, 0.86, 0.30, 0.54), 0.0)
	_halo = lamp

	# He still needs to see that this crop is now in his hand. In reduced
	# motion, land directly in the clear held pose and keep its saucer/glow;
	# the optional spring and idle bob are decoration, not the state itself.
	# It must also sit over neighbouring crops, rather than quietly disappear
	# behind the very field it was picked from.
	z_index = maxi(z_index, 2)
	if not Juice.motion_enabled():
		global_position += displacement
		scale = Vector2.ONE * HELD_SCALE
		return

	_move_tween = create_tween()
	var t := _move_tween
	t.tween_property(self, "global_position",
		global_position + displacement, 0.24)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE * HELD_SCALE, 0.24)
	t.tween_callback(_finish_lift)


func _finish_lift() -> void:
	_held_bob = Juice.idle_bob(self, 7.0, 1.5)


## Into the basket, and out of the game.
func fly_to(where: Vector2) -> void:
	# A fast second touch may deliver before the lifting spring has finished.
	# Stop its pending bob callback and any current bob before the flight owns
	# the transform, so the crop takes one continuous route into the basket.
	_stop_motion_tweens()
	for extra in [_halo, _affordance, _cover]:
		if extra != null and is_instance_valid(extra):
			extra.queue_free()
	# HarvestBasket.accept() supplies the fixed check at the destination in
	# reduced motion. Do not make a crop fly across the field just to explain a
	# state the basket can say still and clearly.
	if not Juice.motion_enabled():
		queue_free()
		return
	_move_tween = create_tween()
	var t := _move_tween
	t.tween_property(self, "global_position", where, 0.34)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.34)
	t.tween_callback(queue_free)


func _stop_motion_tweens() -> void:
	for tween in [_sway_tween, _move_tween, _held_bob, _refuse_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_sway_tween = null
	_move_tween = null
	_held_bob = null
	_refuse_tween = null
	if _visual != null and is_instance_valid(_visual):
		_visual.position = Vector2.ZERO
