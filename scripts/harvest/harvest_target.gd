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

	var sway := float(look.get("sway", 0.0))
	if sway > 0.0 and Juice.motion_enabled():
		var t := create_tween().set_loops()
		t.tween_property(self, "rotation_degrees", sway, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(self, "rotation_degrees", -sway, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	if _halo != null:
		_halo.queue_free()
	var t := create_tween()
	t.tween_property(self, "global_position", where, 0.34)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.34)
	t.tween_callback(queue_free)
