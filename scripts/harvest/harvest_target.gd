extends Node2D
## One thing that can be picked, and the whole of what "picked once" means.
##
## Not a Button. A Button answers a press; these answer a *gesture*, and which
## gesture depends on what is growing. The area a finger has to land in is a
## circle around the middle -- bigger than the picture, and bigger still on the
## gentle setting -- because a six-year-old aims at the thing, not at its edge.

const Gesture := preload("res://scripts/harvest/gesture.gd")
const Maturity := preload("res://scripts/harvest/maturity.gd")

## Loaded by path rather than preloaded: a missing shader must cost the green
## tint, not the whole screen.
const WASH_SHADER := "res://resources/shaders/unripe_wash.gdshader"

signal picked(target: Node2D)
signal refused(target: Node2D, why: String)

var crop: Dictionary = {}
var step := Maturity.READY
var radius := 78.0

## Once true, this one is out of the game. It stops answering, stops being
## found by the nearest-target search, and cannot be picked a second time --
## which is the same rule the garden's harvest keeps, for the same reason.
var taken := false

var _art: Control
var _halo: Node2D
## What the gesture acts on -- the stem, the branch, the arrow.
var _affordance: Node2D
## The soil over a buried crop, cleared as it is swept.
var _cover: Node2D


func build(crop_data: Dictionary, ripeness: String, tolerance: float) -> void:
	crop = crop_data
	step = Maturity.normalise(ripeness)
	radius = tolerance
	var look := Maturity.look(step, crop)

	_halo = Node2D.new()
	add_child(_halo)
	_draw_halo(str(look.get("halo", "none")))

	var size: float = 118.0 * float(look.get("scale", 1.0))
	var art_ref := str(crop.get("asset", crop.get("id", "")))
	_art = UiKit.picture(art_ref, size)
	if _art != null:
		_art.position = Vector2(-size * 0.5, -size * 0.5)
		_art.modulate = look.get("tint", Color.WHITE)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)

		# The green wash, for the two steps that are not ready yet.
		#
		# A shader and not a modulate, because modulate multiplies: a green
		# modulate on a red strawberry gives DARK red, and dark red reads as
		# overripe to a child. Two versions of this went out looking like small
		# extra-ripe berries before it was written. See unripe_wash.gdshader.
		var wash: Color = look.get("wash", Color(0, 0, 0, 0))
		if wash.a > 0.01 and _art is TextureRect:
			var mat := ShaderMaterial.new()
			mat.shader = load(WASH_SHADER)
			mat.set_shader_parameter("wash", Color(wash.r, wash.g, wash.b, 1.0))
			mat.set_shader_parameter("amount", wash.a)
			_art.material = mat
			# The shader owns the colour from here; leaving a tint on as well
			# would multiply the wash down again.
			_art.modulate = Color.WHITE

	# What this gesture needs to SEE to be doable.
	#
	# A recogniser with nothing drawn for it is a rule nobody can follow: a
	# child asked to cut a stem with no stem on screen, or to dig with no soil
	# over the crop, is being asked to guess. Each of these is drawn from the
	# crop's own recogniser, so adding a crop cannot forget it.
	_draw_affordance()

	var sway := float(look.get("sway", 0.0))
	if sway > 0.0 and Juice.motion_enabled():
		var t := create_tween().set_loops()
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
func _draw_affordance() -> void:
	var art := Node2D.new()
	art.z_index = -2
	add_child(art)
	_affordance = art
	var params: Dictionary = crop.get("gesture_params", {})

	match str(crop.get("recogniser", "")):
		Gesture.LINE:
			# The stem, and the width of it that counts. Drawn as a bright band
			# rather than a hairline: what has to be crossed should look like a
			# thing with a size, not like a mathematical line.
			var half: float = float(params.get("line_half_width", 74.0))
			Shapes.fill(art, Shapes.rounded_rect(Vector2(-half, -7.0),
				Vector2(half * 2.0, 14.0), 7.0),
				Color(0.42, 0.72, 0.35), 0.0)
			Shapes.fill(art, Shapes.rounded_rect(Vector2(-half, -4.0),
				Vector2(half * 2.0, 5.0), 2.5),
				Color(1.0, 0.98, 0.72, 0.85), 0.0)
		Gesture.SWEEP:
			var over := str(crop.get("sweep_cover", "soil"))
			if over == "branch":
				# Hanging from a branch: the thing that gets shaken.
				Shapes.fill(art, Shapes.rounded_rect(Vector2(-96, -104),
					Vector2(192, 18), 9.0), Color(0.40, 0.28, 0.18), 1.0)
				var stalk := Line2D.new()
				stalk.points = PackedVector2Array([Vector2(0, -96), Vector2(0, -46)])
				stalk.width = 6.0
				stalk.default_color = Color(0.36, 0.55, 0.28)
				art.add_child(stalk)
			else:
				# Buried: a mound of earth sitting over it, which is why the
				# crop underneath cannot simply be tapped.
				_cover = Node2D.new()
				add_child(_cover)
				_cover.z_index = 2
				Shapes.fill(_cover, Shapes.rounded_rect(Vector2(-78, -52),
					Vector2(156, 104), 44.0), Color(0.42, 0.29, 0.19), 1.0)
				Shapes.fill(_cover, Shapes.rounded_rect(Vector2(-52, -34),
					Vector2(104, 26), 13.0), Color(0.52, 0.37, 0.25, 0.8), 0.0)
		Gesture.DRAG:
			# Only for the long hauls. A 90px pull is obvious from the crop
			# itself; a 160px push of a pumpkin is not.
			if float(params.get("distance", 90.0)) < 140.0:
				return
			var way := Vector2(float(params.get("direction_x", 0.0)),
				float(params.get("direction_y", -1.0))).normalized()
			var tip: Vector2 = way * 96.0
			var arrow := Line2D.new()
			arrow.points = PackedVector2Array([way * 46.0, tip])
			arrow.width = 11.0
			arrow.default_color = Color(1.0, 0.94, 0.55, 0.75)
			arrow.antialiased = true
			art.add_child(arrow)
			Shapes.fill(art, PackedVector2Array([
				tip + way * 22.0,
				tip + way.orthogonal() * 15.0,
				tip - way.orthogonal() * 15.0]),
				Color(1.0, 0.94, 0.55, 0.75), 0.0)


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
	if not Juice.motion_enabled():
		return
	var t := create_tween()
	var home := position
	t.tween_property(self, "position", home + Vector2(9, 0), 0.06)
	t.tween_property(self, "position", home - Vector2(9, 0), 0.06)
	t.tween_property(self, "position", home + Vector2(5, 0), 0.05)
	t.tween_property(self, "position", home, 0.05)


## Into the basket, and out of the game.
func fly_to(where: Vector2) -> void:
	for extra in [_halo, _affordance, _cover]:
		if extra != null and is_instance_valid(extra):
			extra.queue_free()
	var t := create_tween()
	t.tween_property(self, "global_position", where, 0.34)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.34)
	t.tween_callback(queue_free)
