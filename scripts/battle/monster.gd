class_name Monster
extends Node2D
## A monster for the arena levels, drawn.
##
## Deliberately appealing rather than scary, and *specifically* appealing
## rather than merely inoffensive: the first version was a purple ball with
## triangle spikes and two white circles, which is a monster shape without
## being a character. What makes a creature likeable at six is the same short
## list every time, and all of it is here now:
##
##   * a big head low on the body, and a body wider at the bottom than the top
##   * eyes with lids and highlights, not discs -- lids are what carry mood
##   * eyebrows, which do more for expression than anything else on the face
##   * cheeks, a soft belly, rounded paws: nothing pointed except the horns
##   * every edge outlined and every mass lit from the same sun as the scenery
##
## The monster is never hurt, only startled. Hits make it flinch and blink;
## winning makes it happy and it hops away waving. The battle ends with a
## friend leaving, not a body -- at six, that is the difference between
## exciting and upsetting.
##
## Origin is at the feet, centre; everything is drawn upward in negative y.

signal left()

var config: Dictionary = {}

## The one place a monster's picture is loaded, shared with the adventure's
## small foes and with the album card -- so all three are the same drawing.
const MonsterArt := preload("res://scripts/reward/monster_art.gd")

var _rig: Node2D          # everything visual, so squash never fights placement
var _eye_whites: Array[Node2D] = []
var _eye_pupils: Array[Node2D] = []
var _lids: Array[Polygon2D] = []
## How far each lid has to travel to cover its eye, in local units.
var _lid_drops: Array[float] = []
var _brows: Array[Node2D] = []
var _ears: Array[Node2D] = []
var _mouth: Polygon2D
var _tongue: Polygon2D
var _flinching := false

var _h := 300.0
var _w := 246.0
var _body: Color
var _belly: Color
var _accent: Color
var _rng: RandomNumberGenerator


func build(monster_config: Dictionary) -> void:
	config = monster_config
	for child in get_children():
		child.queue_free()
	_eye_whites.clear()
	_eye_pupils.clear()
	_lids.clear()
	_lid_drops.clear()
	_brows.clear()
	_ears.clear()

	_rig = Node2D.new()
	add_child(_rig)

	# Height is settled BEFORE the branch, so `_h` means "how tall this monster
	# is drawn" whichever way it was drawn. It used to be set only inside
	# _build_drawn(), which left every painted monster reporting the default
	# 300 -- and the check that measures whether a boss fits on the screen was
	# measuring 300 for all six of them.
	_h = float(config.get("height", 300.0))
	_w = _h * float(config.get("width", 0.82))

	# Every monster stands on a pool of shadow, drawn first so it sits under
	# the body. It earns its keep twice: it plants the creature ON the ground
	# instead of floating in front of it, and for the painted monsters --
	# illustrated in a different style than the drawn world -- it is the one
	# shared prop that makes the two styles read as standing in the same
	# place. The hero has one; the monster not having one was half of why the
	# duel looked like two games pasted together.
	var shadow := Polygon2D.new()
	shadow.name = "GroundShadow"
	var oval := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		oval.append(Vector2(cos(a) * _w * 0.46, 6.0 + sin(a) * _w * 0.10))
	shadow.polygon = oval
	# Ink-blue like every other shadow in this world, not "darker grass" --
	# the first cut used a green-black at 18% and vanished into the lawn.
	shadow.color = Color(0.09, 0.13, 0.24, 0.26)
	_rig.add_child(shadow)

	# A painted monster lives at assets/characters/monsters/<id>.png, feet at
	# the bottom edge. It keeps every animation below except the ones that move
	# a face -- a picture has no eyelids.
	var tex: Texture2D = MonsterArt.texture(str(config.get("id", "")))
	if tex != null:
		_build_textured(tex)
	else:
		_build_drawn()
	_sway()


func _build_textured(tex: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var height := float(config.get("height", 300.0))
	var s: float = height / maxf(float(tex.get_height()), 1.0)
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, -height * 0.5)
	if bool(config.get("silhouette", false)):
		sprite.material = _silhouette_material()
	else:
		# A whisper of the scene's cool daylight over the illustration.
		# The painted monsters arrive saturated to the teeth from a renderer
		# that never saw this island's sky; multiplying a few percent of
		# blue-grey in is not a disguise, but it takes the "sticker pasted
		# on a photo" edge off. The drawn monsters skip it -- they were
		# born under this light.
		sprite.modulate = Color(0.95, 0.96, 1.0)
	_rig.add_child(sprite)


## The album's not-yet-met card: every opaque pixel one flat grey, alpha kept.
##
## modulate() cannot do this -- it MULTIPLIES, so a dark monster stays dark and
## a bright one stays bright, and the fifteen "silhouettes" come out as fifteen
## dimmed portraits with their colours still legible. That is not a silhouette,
## it is a spoiler. Two lines of shader gets the real thing.
static var _silhouette: ShaderMaterial


static func _silhouette_material() -> ShaderMaterial:
	if _silhouette != null:
		return _silhouette
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" \
		+ "uniform vec4 tint : source_color = vec4(0.62, 0.66, 0.74, 1.0);\n" \
		+ "void fragment() {\n" \
		+ "\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);\n" \
		+ "}\n"
	_silhouette = ShaderMaterial.new()
	_silhouette.shader = shader
	return _silhouette


# --- the drawing ---------------------------------------------------------

func _build_drawn() -> void:
	_rng = Shapes.rng_for(str(config.get("id", "monster")))
	_h = float(config.get("height", 300.0))
	_w = _h * float(config.get("width", 0.82))
	_body = Color.from_string(str(config.get("body_color", "#8a5fc9")), Color(0.54, 0.37, 0.79))
	_belly = Color.from_string(str(config.get("belly_color", "#c9aef2")), Color(0.79, 0.68, 0.95))
	_accent = Color.from_string(str(config.get("accent_color", "#5e3f96")), _body.darkened(0.25))

	# Back to front, so every join is covered by the piece in front of it.
	# The tail and arms go in FRONT of the body: behind it they were almost
	# entirely hidden, and the only part that showed was the tail tip, which
	# read as a rock floating in mid-air.
	_draw_ears()
	_draw_horns()
	_draw_spikes()
	_draw_legs()
	_draw_body()
	_draw_tail()
	_draw_arms()
	# A silhouette is the body and nothing else: no eyes, no smile, no cheeks.
	# The album draws the not-yet-met monsters this way. Greying the face out
	# instead of leaving it off looks like a monster he HAS met and the game
	# has faded, which is the opposite of the promise a silhouette makes.
	if not bool(config.get("silhouette", false)):
		_draw_face()


func _draw_tail() -> void:
	# Out of the lower right of the body and curling up, so the whole curve is
	# visible against the background rather than buried behind the belly.
	var root := Vector2(_w * 0.34, -_h * 0.24)
	var tip := Vector2(_w * 0.62, -_h * 0.54)
	var curve := PackedVector2Array([
		root,
		root + Vector2(_w * 0.16, -_h * 0.02),
		root + Vector2(_w * 0.28, -_h * 0.16),
		tip,
	])
	Shapes.fill(_rig, Shapes.ribbon(curve, _w * 0.11, 8), _body.darkened(0.08), 1.0)
	Shapes.lit(_rig, Shapes.blob(tip, Vector2(_w * 0.11, _w * 0.11), _rng, 0.14, 3, 16),
		_belly, 1.0)


## Ears are the biggest shape on the head, and for a long time every monster
## on the island had the same two big round ones. Ten different colours with
## one identical outline reads as ONE creature recoloured -- which is exactly
## what a child says when he looks at the album: "they're all the same".
##
## So the ears come from the data now, one of:
##
##   round    the friendly default -- soft, wide, mouse-like
##   pointed  triangles, up and alert
##   small    barely there, tucked against the head
##   long     tall and drooping, rabbit-ish
##   fin      swept back along the head instead of up
##   none     no ears at all (the ones whose horns ARE their ears)
##
## Two variants also mean two SILHOUETTES, which is what still works when the
## album card is 126 px wide and the colour is turned off.
func _draw_ears() -> void:
	var kind := str(config.get("ears", "round"))
	if kind == "none":
		return
	for side in [-1.0, 1.0]:
		var ear := Node2D.new()
		_rig.add_child(ear)
		var inner: Color = _belly
		match kind:
			"pointed":
				ear.position = Vector2(side * _w * 0.36, -_h * 0.80)
				var tip := Vector2(side * _w * 0.22, -_h * 0.20)
				Shapes.lit(ear, PackedVector2Array([
					Vector2(side * _w * -0.04, _w * 0.10),
					tip, Vector2(side * _w * 0.22, _w * 0.06),
				]), _body.darkened(0.06), 1.0)
				Shapes.fill(ear, PackedVector2Array([
					Vector2(side * _w * 0.02, _w * 0.06),
					tip * 0.66, Vector2(side * _w * 0.16, _w * 0.03),
				]), inner, 0.8)
			"small":
				ear.position = Vector2(side * _w * 0.40, -_h * 0.72)
				Shapes.lit(ear, Shapes.oval_points(Vector2(side * _w * 0.05, 0),
					Vector2(_w * 0.085, _w * 0.075), 14), _body.darkened(0.06), 1.0)
			"long":
				ear.position = Vector2(side * _w * 0.30, -_h * 0.80)
				Shapes.lit(ear, Shapes.oval_points(Vector2(side * _w * 0.14, -_h * 0.09),
					Vector2(_w * 0.09, _h * 0.15), 20), _body.darkened(0.06), 1.0)
				Shapes.fill(ear, Shapes.oval_points(Vector2(side * _w * 0.14, -_h * 0.09),
					Vector2(_w * 0.045, _h * 0.10), 16), inner, 0.8)
			"fin":
				# Swept BACK, not up: the shape stays inside the head's height,
				# which is what makes a swimmer look like a swimmer.
				ear.position = Vector2(side * _w * 0.38, -_h * 0.70)
				Shapes.lit(ear, PackedVector2Array([
					Vector2(0, -_w * 0.10), Vector2(side * _w * 0.30, -_w * 0.02),
					Vector2(side * _w * 0.26, _w * 0.12), Vector2(0, _w * 0.10),
				]), _body.darkened(0.06), 1.0)
			_:
				ear.position = Vector2(side * _w * 0.40, -_h * 0.78)
				Shapes.lit(ear, Shapes.oval_points(Vector2(side * _w * 0.10, 0),
					Vector2(_w * 0.15, _w * 0.19), 18), _body.darkened(0.06), 1.0)
				Shapes.fill(ear, Shapes.oval_points(Vector2(side * _w * 0.10, _w * 0.01),
					Vector2(_w * 0.08, _w * 0.11), 14), inner, 0.8)
		_ears.append(ear)


func _draw_horns() -> void:
	var horns := int(config.get("horns", 0))
	if horns <= 0:
		return
	if horns == 1:
		# One horn on a round head reads as a pin stuck in it. An antenna with
		# a little lamp on the end reads as part of the creature, and it gives
		# the monster something that glows when it is about to throw.
		var stalk := Vector2(0, -_h * 0.94)
		Shapes.fill(_rig, Shapes.taper(stalk + Vector2(0, _h * 0.05),
			stalk + Vector2(_w * 0.06, -_h * 0.19), _w * 0.055, _w * 0.034),
			_accent, 1.0)
		Shapes.glow(_rig, stalk + Vector2(_w * 0.06, -_h * 0.20), _w * 0.44,
			Color(1.0, 0.86, 0.52), 5, 0.38)
		Shapes.lit(_rig, Shapes.circle_points(stalk + Vector2(_w * 0.06, -_h * 0.20),
			_w * 0.105, 16), Color(1.0, 0.88, 0.54), 1.0)
		return

	var places: Array = [-0.16, 0.16]
	if horns >= 3:
		places = [-0.24, 0.0, 0.24]
	for place in places:
		var base := Vector2(float(place) * _w, -_h * 0.93)
		var lean: float = signf(float(place)) if place != 0.0 else 0.0
		# A curved horn rather than a triangle: three segments narrowing to a
		# rounded tip, which reads as grown rather than glued on.
		var curve := PackedVector2Array([
			base,
			base + Vector2(lean * _w * 0.10, -_h * 0.13),
			base + Vector2(lean * _w * 0.24, -_h * 0.22),
			base + Vector2(lean * _w * 0.40, -_h * 0.28),
		])
		var horn := PackedVector2Array()
		var left := PackedVector2Array()
		for i in range(curve.size()):
			var t: float = float(i) / float(curve.size() - 1)
			var width: float = _w * lerpf(0.14, 0.025, t)
			var dir: Vector2 = (curve[mini(i + 1, curve.size() - 1)]
				- curve[maxi(i - 1, 0)]).normalized()
			if dir.length() < 0.01:
				dir = Vector2.UP
			var side_v := Vector2(-dir.y, dir.x) * width
			horn.append(curve[i] + side_v)
			left.append(curve[i] - side_v)
		for i in range(left.size() - 1, -1, -1):
			horn.append(left[i])
		Shapes.lit(_rig, horn, Color(0.96, 0.93, 0.86), 1.0)


func _draw_spikes() -> void:
	var spikes := int(config.get("spikes", 0))
	for i in range(spikes):
		var t: float = (float(i) + 0.5) / float(maxi(spikes, 1))
		var a: float = lerpf(-2.5, -0.7, t)
		var base := Vector2(cos(a) * _w * 0.52, -_h * 0.52 + sin(a) * _h * 0.44)
		var dir: Vector2 = (base - Vector2(0, -_h * 0.52)).normalized()
		var tip: Vector2 = base + dir * _h * 0.19
		var side_v := Vector2(-dir.y, dir.x) * _w * 0.085
		# Rounded shoulders on the spike so it reads soft, not sharp. This is
		# a friendly monster; nothing on it should look like it would hurt.
		Shapes.lit(_rig, PackedVector2Array([
			base + side_v, base + side_v * 0.7 + dir * _h * 0.05,
			tip, base - side_v * 0.7 + dir * _h * 0.05, base - side_v,
		]), _accent, 1.0)


func _draw_legs() -> void:
	for side in [-1.0, 1.0]:
		var hip := Vector2(side * _w * 0.24, -_h * 0.22)
		Shapes.lit(_rig, Shapes.rounded_rect(hip - Vector2(_w * 0.15, 0),
			Vector2(_w * 0.30, _h * 0.22), _w * 0.13), _body.darkened(0.08), 1.0)
		# A rounded foot, wider than the leg: what makes a creature look
		# planted instead of balanced on posts.
		var foot := Vector2(side * _w * 0.26, -_h * 0.05)
		Shapes.lit(_rig, Shapes.oval_points(foot, Vector2(_w * 0.21, _w * 0.10), 20),
			_belly.darkened(0.04), 1.0)
		for t in range(3):
			var tx: float = foot.x + (float(t) - 1.0) * _w * 0.11
			Shapes.fill(_rig, Shapes.oval_points(Vector2(tx, foot.y + _w * 0.03),
				Vector2(_w * 0.045, _w * 0.035), 12), _belly.lightened(0.16), 0.7)


## The body and the head are one mass. A separate head on a neck reads as a
## person in a costume; one pear-shaped lump reads as a creature.
func _draw_body() -> void:
	var centre := Vector2(0, -_h * 0.52)
	var points := PackedVector2Array()
	var steps := 34
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		# Wider below the middle, slightly narrower at the crown.
		var squish: float = 1.0 + 0.20 * clampf(sin(a), 0.0, 1.0) - 0.10 * clampf(-sin(a), 0.0, 1.0)
		var wobble: float = 1.0 + 0.022 * sin(a * 3.0 + 1.4)
		points.append(centre + Vector2(
			cos(a) * _w * 0.50 * squish * wobble,
			sin(a) * _h * 0.44 * wobble))
	Shapes.lit(_rig, points, _body, 1.0)

	# Belly patch: a soft lighter shape low and centred. It gives the eye
	# somewhere to rest and stops a big single-colour mass reading as flat.
	Shapes.fill(_rig, Shapes.blob(Vector2(0, -_h * 0.33),
		Vector2(_w * 0.30, _h * 0.20), _rng, 0.06, 3, 24), _belly, 0.8)


func _draw_arms() -> void:
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(side * _w * 0.40, -_h * 0.56)
		var paw := Vector2(side * _w * 0.62, -_h * 0.30)
		Shapes.lit(_rig, Shapes.ribbon(PackedVector2Array([
			shoulder,
			shoulder.lerp(paw, 0.5) + Vector2(side * _w * 0.09, -_h * 0.02),
			paw,
		]), _w * 0.17, 8), _body.darkened(0.06), 1.0)
		Shapes.lit(_rig, Shapes.blob(paw, Vector2(_w * 0.13, _w * 0.12), _rng, 0.12, 3, 16),
			_belly.darkened(0.04), 1.0)
		# Three little claws on each paw, so the hands read as hands.
		for k in range(3):
			Shapes.fill(_rig, Shapes.oval_points(
				paw + Vector2(side * _w * 0.10, (float(k) - 1.0) * _w * 0.07),
				Vector2(_w * 0.035, _w * 0.028), 10), _belly.lightened(0.20), 0.6)


func _draw_face() -> void:
	var eyes := maxi(int(config.get("eyes", 2)), 1)
	var eye_r: float = _w * (0.155 if eyes <= 2 else 0.115)
	var eye_y: float = -_h * 0.66

	for i in range(eyes):
		var ex: float
		if eyes == 1:
			ex = 0.0
		elif eyes == 2:
			ex = (-0.5 + float(i)) * _w * 0.40
		else:
			ex = (float(i) - float(eyes - 1) / 2.0) * _w * 0.28
		var ey: float = eye_y - (_h * 0.04 if (eyes == 3 and i == 1) else 0.0)
		_draw_eye(Vector2(ex, ey), eye_r)

	_draw_mouth()

	# Cheeks: two soft warm patches under the eyes. One of the cheapest and
	# most reliable ways to make a drawn creature read as friendly.
	for side in [-1.0, 1.0]:
		Shapes.fill(_rig, Shapes.oval_points(
			Vector2(side * _w * 0.38, -_h * 0.55), Vector2(_w * 0.10, _w * 0.07), 16),
			Color(1.0, 0.58, 0.62, 0.32), 0.0)


func _draw_eye(at: Vector2, r: float) -> void:
	var eye := Node2D.new()
	eye.position = at
	_rig.add_child(eye)

	# A dark socket rim rather than a white disc floating on the body.
	Shapes.fill(eye, Shapes.oval_points(Vector2.ZERO, Vector2(r * 1.10, r * 1.24), 22),
		_body.darkened(0.22), 0.0)
	Shapes.fill(eye, Shapes.oval_points(Vector2.ZERO, Vector2(r, r * 1.14), 22),
		Color(0.99, 0.99, 0.97), 0.9)
	_eye_whites.append(eye)

	var pupil := Node2D.new()
	pupil.position = Vector2(0, r * 0.14)
	eye.add_child(pupil)
	Shapes.fill(pupil, Shapes.oval_points(Vector2.ZERO, Vector2(r * 0.46, r * 0.52), 18),
		Color(0.13, 0.12, 0.18), 0.0)
	# Two highlights, one big and one small: the standard trick that turns a
	# black dot into an eye that is looking at you.
	Shapes.fill(pupil, Shapes.circle_points(Vector2(r * 0.18, -r * 0.20), r * 0.16, 12),
		Color(1, 1, 1, 0.95), 0.0)
	Shapes.fill(pupil, Shapes.circle_points(Vector2(-r * 0.16, r * 0.18), r * 0.08, 10),
		Color(1, 1, 1, 0.55), 0.0)
	_eye_pupils.append(pupil)

	# The lid, parked above the eye. Blinking drops it; mood tilts it. A lid
	# does far more for expression than moving the pupil.
	var lid: Polygon2D = Shapes.fill(eye, Shapes.oval_points(
		Vector2(0, -r * 2.2), Vector2(r * 1.14, r * 1.22), 20), _body, 0.0)
	_lids.append(lid)
	_lid_drops.append(r * 2.2)

	# Eyebrow: a short thick arc above the eye, on its own node so it can be
	# angled. Nothing else on a face says "surprised" or "cross" this cheaply.
	var brow := Node2D.new()
	brow.position = Vector2(0, -r * 1.45)
	eye.add_child(brow)
	Shapes.fill(brow, Shapes.rounded_rect(Vector2(-r * 0.72, -r * 0.11),
		Vector2(r * 1.44, r * 0.26), r * 0.13), _accent.darkened(0.10), 0.0)
	_brows.append(brow)


func _draw_mouth() -> void:
	var y: float = -_h * 0.47
	_mouth = Shapes.fill(_rig, _mouth_shape(0.10), Color(0.28, 0.14, 0.20), 0.9)
	_tongue = Shapes.fill(_rig, Shapes.oval_points(Vector2(0, y + _h * 0.02),
		Vector2(_w * 0.11, _h * 0.02), 16), Color(0.92, 0.44, 0.50), 0.0)
	# Two blunt fangs at the corners of the smile, pointing DOWN from the top
	# lip -- small enough to be charming rather than threatening.
	for side in [-1.0, 1.0]:
		Shapes.fill(_rig, PackedVector2Array([
			Vector2(side * _w * 0.14 - _w * 0.032, y),
			Vector2(side * _w * 0.14 + _w * 0.032, y),
			Vector2(side * _w * 0.14, y + _h * 0.035),
		]), Color(0.99, 0.99, 0.95), 0.7)


## A smile: a shallow arc for the top lip and a deeper one for the bottom.
## `open_amount` is how far the jaw drops, which is the whole mood range from
## "content" to "delighted".
func _mouth_shape(open_amount: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var y: float = -_h * 0.47
	var half: float = _w * 0.20
	for i in range(11):
		var t: float = float(i) / 10.0
		points.append(Vector2(lerpf(-half, half, t), y + sin(t * PI) * _h * 0.012))
	for i in range(11):
		var t: float = 1.0 - float(i) / 10.0
		points.append(Vector2(lerpf(-half, half, t),
			y + sin(t * PI) * _h * (0.012 + open_amount)))
	return points


# --- states ---------------------------------------------------------------

## Gentle side-to-side sway, plus ears that lag behind it, so the monster is
## alive while the child is deciding what to do.
func _sway() -> void:
	if not Juice.motion_enabled():
		return
	var t := create_tween().set_loops()
	t.tween_property(_rig, "rotation_degrees", 2.0, 1.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_rig, "rotation_degrees", -2.0, 1.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(_ears.size()):
		var ear: Node2D = _ears[i]
		var swing: float = 5.0 if i % 2 == 0 else -5.0
		var e := ear.create_tween().set_loops()
		e.tween_property(ear, "rotation_degrees", swing, 1.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		e.tween_property(ear, "rotation_degrees", -swing, 1.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_loop()


func _blink_loop() -> void:
	if not is_inside_tree() or not Juice.motion_enabled():
		return
	var wait: float = randf_range(2.4, 5.0)
	var timer := get_tree().create_timer(wait)
	timer.timeout.connect(func():
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_blink(0.12)
		_blink_loop()
	)


## Startled, not hurt: a squash, a blink, brows up, a step back. Reads as
## "gotcha!" rather than "ouch".
func flinch() -> void:
	_blink(0.30)
	_set_brows(-16.0)
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(self):
			_set_brows(0.0)
	)
	if _flinching or not Juice.motion_enabled():
		return
	_flinching = true
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.14, 0.86), 0.09).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_rig, "position:x", 14.0, 0.09)
	t.tween_property(_rig, "scale", Vector2(0.94, 1.06), 0.12)
	t.tween_property(_rig, "scale", Vector2.ONE, 0.12)
	t.parallel().tween_property(_rig, "position:x", 0.0, 0.12)
	t.tween_callback(func(): _flinching = false)


## A blink is the lid sliding down over the eye and back up. It parks above the
## eye the rest of the time, which is why it never needs hiding.
func _blink(duration: float) -> void:
	for i in range(_lids.size()):
		var lid: Polygon2D = _lids[i]
		if not is_instance_valid(lid):
			continue
		var drop: float = _lid_drops[i] if i < _lid_drops.size() else 40.0
		if not Juice.motion_enabled():
			continue
		var t := lid.create_tween()
		t.tween_property(lid, "position:y", drop, 0.06).set_trans(Tween.TRANS_SINE)
		t.tween_interval(duration)
		t.tween_property(lid, "position:y", 0.0, 0.09).set_trans(Tween.TRANS_SINE)


## Winding up to throw -- a puff and a scrunch, so the child sees it coming
## and has time to raise the shield. Telegraphing is what makes a defence
## button fair.
func puff_up() -> void:
	_set_brows(14.0)
	get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(self):
			_set_brows(0.0)
	)
	if not Juice.motion_enabled():
		return
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.12, 1.10), 0.30).set_trans(Tween.TRANS_SINE)
	t.tween_property(_rig, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


## Ferocious roar telegraph with body expansion and shockwave ring
func roar(duration: float = 0.65) -> void:
	_set_brows(22.0)
	if _mouth != null and is_instance_valid(_mouth):
		_mouth.polygon = _mouth_shape(0.36)
	if not Juice.motion_enabled() or _rig == null or not is_instance_valid(_rig):
		return
	var t := create_tween()
	# Inhale lean back
	t.tween_property(_rig, "scale", Vector2(0.92, 1.18), duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rig, "position:x", 18.0, duration * 0.35)
	# Roar forward blast
	t.tween_property(_rig, "scale", Vector2(1.22, 0.94), duration * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rig, "position:x", -24.0, duration * 0.35)
	t.tween_callback(func():
		Juice.shockwave(get_parent(), global_position + Vector2(-60.0, -_h * 0.45), 110.0, Color(1.0, 0.85, 0.35))
		Juice.screen_shake(get_parent() if get_parent() is Node2D else self, 10.0, 0.18)
	)
	# Settle back to rest
	t.tween_property(_rig, "scale", Vector2.ONE, duration * 0.30)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_rig, "position:x", 0.0, duration * 0.30)
	t.tween_callback(func():
		_set_brows(0.0)
		if _mouth != null and is_instance_valid(_mouth):
			_mouth.polygon = _mouth_shape(0.10)
	)


## Lunge forward claw swipe with claw streak FX
func claw_swipe(duration: float = 0.45) -> void:
	_set_brows(16.0)
	if not Juice.motion_enabled() or _rig == null or not is_instance_valid(_rig):
		return
	var t := create_tween()
	# Pull back
	t.tween_property(_rig, "position:x", 25.0, duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Strike forward
	t.tween_property(_rig, "position:x", -45.0, duration * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		Juice.speed_lines(get_parent(), global_position + Vector2(-40.0, -_h * 0.4), Vector2(-1, 0), Color(1.0, 0.45, 0.25, 0.9), 4)
		Juice.impact_sparks(get_parent(), global_position + Vector2(-50.0, -_h * 0.4), Color(1.0, 0.5, 0.2), 8)
	)
	# Recover
	t.tween_property(_rig, "position:x", 0.0, duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): _set_brows(0.0))


## Inhale and exhale fire breath burst
func fire_breath(duration: float = 0.55) -> void:
	_set_brows(18.0)
	if not Juice.motion_enabled() or _rig == null or not is_instance_valid(_rig):
		return
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(0.9, 1.15), duration * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "scale", Vector2(1.18, 0.92), duration * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		Juice.burst(get_parent(), global_position + Vector2(-80.0, -_h * 0.45), 16)
	)
	t.tween_property(_rig, "scale", Vector2.ONE, duration * 0.3)
	t.tween_callback(func(): _set_brows(0.0))


## Dizzy stun with spinning stars and head sway
func dizzy_stun(duration: float = 1.5) -> void:
	_set_brows(-18.0)
	if _mouth != null and is_instance_valid(_mouth):
		_mouth.polygon = _mouth_shape(0.22)
	Juice.dizzy_stars(get_parent(), global_position + Vector2(0.0, -_h * 1.05), duration)
	if not Juice.motion_enabled() or _rig == null or not is_instance_valid(_rig):
		return
	var t := create_tween()
	var loops := int(duration / 0.24)
	for i in range(loops):
		var ang := 7.0 if i % 2 == 0 else -7.0
		t.tween_property(_rig, "rotation_degrees", ang, 0.12)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_rig, "rotation_degrees", 0.0, 0.16)
	t.tween_callback(func():
		_set_brows(0.0)
		if _mouth != null and is_instance_valid(_mouth):
			_mouth.polygon = _mouth_shape(0.10)
	)


## Monster lifts up and stomps the ground hard, sending out dust and shockwaves
func ground_stomp(duration: float = 0.55) -> void:
	_set_brows(24.0)
	if not Juice.motion_enabled() or _rig == null or not is_instance_valid(_rig):
		return
	var t := create_tween()
	# Rear up
	t.tween_property(_rig, "position:y", -35.0, duration * 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rig, "scale", Vector2(0.92, 1.15), duration * 0.35)
	# Slam down hard
	t.tween_property(_rig, "position:y", 0.0, duration * 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_rig, "scale", Vector2(1.22, 0.85), duration * 0.25)
	t.tween_callback(func():
		Juice.dust(get_parent(), global_position, 8, 1.1)
		Juice.shockwave(get_parent(), global_position + Vector2(0.0, -20.0), 120.0, Color(0.95, 0.75, 0.45))
		Juice.screen_shake(get_parent() if get_parent() is Node2D else self, 12.0, 0.20)
		AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	)
	# Recover to normal size
	t.tween_property(_rig, "scale", Vector2.ONE, duration * 0.40)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _set_brows(0.0))


## Defensive guard brace behind armor shell
func guard_brace(duration: float = 0.60) -> void:
	_set_brows(20.0)
	if not Juice.motion_enabled() or _rig == null or not is_instance_valid(_rig):
		return
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.15, 0.88), duration * 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(duration * 0.50)
	t.tween_property(_rig, "scale", Vector2.ONE, duration * 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): _set_brows(0.0))


## Angle both eyebrows. Positive leans them inward (cross, concentrating),
## negative outward (surprised, delighted).
func _set_brows(degrees: float) -> void:
	for i in range(_brows.size()):
		var brow: Node2D = _brows[i]
		if not is_instance_valid(brow):
			continue
		var target: float = degrees * (1.0 if i % 2 == 0 else -1.0)
		if not Juice.motion_enabled():
			brow.rotation_degrees = target
			continue
		var t := brow.create_tween()
		t.tween_property(brow, "rotation_degrees", target, 0.14)


## The end of every battle: tired, happy, and off home. A big grin, two little
## jumps, a wave, then it hops away and the `left` signal fires.
func leave_happy() -> void:
	_set_brows(-12.0)
	if _mouth != null and is_instance_valid(_mouth):
		_mouth.polygon = _mouth_shape(0.26)
	if _tongue != null and is_instance_valid(_tongue):
		_tongue.position.y = _h * 0.04
	for pupil in _eye_pupils:
		if is_instance_valid(pupil):
			pupil.position.y -= 4.0   # eyes smile upward

	if not Juice.motion_enabled():
		left.emit()
		return

	var t := create_tween()
	for i in range(2):
		t.tween_property(_rig, "position:y", -46.0, 0.22)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_rig, "position:y", 0.0, 0.20)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_rig, "rotation_degrees", -8.0, 0.18)
	t.tween_property(_rig, "rotation_degrees", 8.0, 0.18)
	t.tween_property(_rig, "rotation_degrees", 0.0, 0.14)
	t.tween_property(self, "position:x", position.x + 420.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.9)
	t.tween_callback(func(): left.emit())
