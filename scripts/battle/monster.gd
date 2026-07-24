extends Node2D
## A cartoon monster for the battle levels, drawn from primitives.
##
## Deliberately silly rather than scary: blob body, stubby limbs, huge eyes.
## The same genre-vocabulary trick as the drawn hero -- horns, spikes and a
## belly patch say "kaiju" without copying any particular one -- and the same
## art seam: drop a PNG at assets/characters/monsters/<id>.png (feet at the
## bottom edge) and it replaces the drawing, keeping every animation.
##
## The monster is never hurt, only startled. Hits make it flinch and blink;
## winning makes it happy and it hops away waving. The battle ends with a
## friend leaving, not a body -- at six, that is the difference between
## exciting and upsetting.
##
## Origin is at the feet, centre. Levels place it on the ground line and
## scale it; all drawing happens upward in negative y.

signal left()

var config: Dictionary = {}

var _rig: Node2D          # everything visual, so squash never fights placement
var _eye_pupils: Array = []
var _eye_whites: Array = []
var _mouth: Polygon2D
var _flinching := false


func build(monster_config: Dictionary) -> void:
	config = monster_config
	for child in get_children():
		child.queue_free()
	_eye_pupils.clear()
	_eye_whites.clear()

	_rig = Node2D.new()
	add_child(_rig)

	var art := "res://assets/characters/monsters/%s.png" % str(config.get("id", ""))
	if ResourceLoader.exists(art):
		_build_textured(art)
	else:
		_build_drawn()
	_sway()


func _build_textured(art: String) -> void:
	var sprite := Sprite2D.new()
	var tex: Texture2D = load(art)
	sprite.texture = tex
	var height := float(config.get("height", 300.0))
	var s: float = height / maxf(float(tex.get_height()), 1.0)
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, -height * 0.5)
	_rig.add_child(sprite)


func _build_drawn() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(config.get("id", "monster")))

	var h := float(config.get("height", 300.0))
	var w: float = h * float(config.get("width", 0.82))
	var body_color := Color.from_string(str(config.get("body_color", "#d98a4a")), Color(0.85, 0.54, 0.29))
	var belly_color := Color.from_string(str(config.get("belly_color", "#f2c489")), Color(0.95, 0.77, 0.54))
	var accent := Color.from_string(str(config.get("accent_color", "#a8632f")), body_color.darkened(0.25))

	# --- legs, under everything ---
	for side in [-1.0, 1.0]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(side * w * 0.30, -h * 0.16), Vector2(side * w * 0.12, -h * 0.16),
			Vector2(side * w * 0.10, -h * 0.02), Vector2(side * w * 0.34, 0),
		])
		leg.color = body_color.darkened(0.08)
		_rig.add_child(leg)
		# Three chubby toes.
		for t in range(3):
			var toe := Polygon2D.new()
			var tx: float = side * w * (0.14 + 0.09 * float(t))
			toe.polygon = _blob(Vector2(tx, -h * 0.005), w * 0.045, 8, rng, 0.15)
			toe.color = belly_color
			_rig.add_child(toe)

	# --- body: a rounded blob, wider at the bottom, organic bumps ---
	var body := Polygon2D.new()
	var points := PackedVector2Array()
	var steps := 26
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		var rx: float = w * 0.5 * (1.0 + 0.16 * sin(a * 1.0 + 2.2))
		var ry: float = h * 0.42
		var bump: float = 1.0 + rng.randf_range(-0.03, 0.05)
		# Pear shape: fatter below the middle.
		var squish: float = 1.0 + 0.22 * clampf(sin(a), 0.0, 1.0)
		points.append(Vector2(cos(a) * rx * bump * squish, -h * 0.52 + sin(a) * ry * bump))
	body.polygon = points
	body.color = body_color
	_rig.add_child(body)

	# --- back spikes, behind-ish (drawn over body but along the crown) ---
	var spikes := int(config.get("spikes", 0))
	for i in range(spikes):
		var t: float = float(i) / maxf(float(spikes - 1), 1.0)
		var a: float = lerpf(-2.55, -0.6, t)
		var base := Vector2(cos(a) * w * 0.46, -h * 0.52 + sin(a) * h * 0.40)
		var dir := (base - Vector2(0, -h * 0.52)).normalized()
		var spike := Polygon2D.new()
		var tip := base + dir * h * rng.randf_range(0.10, 0.16)
		var side := Vector2(-dir.y, dir.x) * w * 0.06
		spike.polygon = PackedVector2Array([base + side, tip, base - side])
		spike.color = accent
		_rig.add_child(spike)

	# --- belly patch ---
	var belly := Polygon2D.new()
	belly.polygon = _blob(Vector2(0, -h * 0.36), w * 0.30, 18, rng, 0.06, 1.25)
	belly.color = belly_color
	_rig.add_child(belly)

	# --- stubby arms ---
	for side in [-1.0, 1.0]:
		var arm := Polygon2D.new()
		arm.polygon = _blob(Vector2(side * w * 0.52, -h * 0.44), w * 0.11, 10, rng, 0.12, 1.7)
		arm.color = body_color.darkened(0.05)
		_rig.add_child(arm)

	# --- horns ---
	var horns := int(config.get("horns", 0))
	if horns == 1:
		_horn(Vector2(0, -h * 0.90), h, w, 0.0, accent)
	elif horns >= 2:
		_horn(Vector2(-w * 0.22, -h * 0.86), h, w, -0.35, accent)
		_horn(Vector2(w * 0.22, -h * 0.86), h, w, 0.35, accent)

	# --- eyes: enormous, close-set, instantly readable ---
	var eyes := int(config.get("eyes", 2))
	var eye_r: float = w * (0.14 if eyes <= 2 else 0.11)
	var eye_y: float = -h * 0.68
	for i in range(eyes):
		var ex: float
		if eyes == 1:
			ex = 0.0
		elif eyes == 2:
			ex = (-0.5 + float(i)) * w * 0.36
		else:
			ex = (float(i) - float(eyes - 1) / 2.0) * w * 0.26
		var ey: float = eye_y - (h * 0.05 if (eyes == 3 and i == 1) else 0.0)

		var white := Polygon2D.new()
		white.polygon = _blob(Vector2(0, 0), eye_r, 14, rng, 0.02, 1.15)
		white.position = Vector2(ex, ey)
		white.color = Color(0.99, 0.99, 0.97)
		_rig.add_child(white)
		_eye_whites.append(white)

		var pupil := Polygon2D.new()
		pupil.polygon = _blob(Vector2(0, 0), eye_r * 0.42, 10, rng, 0.02)
		pupil.position = Vector2(ex, ey + eye_r * 0.18)
		pupil.color = Color(0.13, 0.12, 0.16)
		_rig.add_child(pupil)
		_eye_pupils.append(pupil)

		var glint := Polygon2D.new()
		glint.polygon = _blob(Vector2(0, 0), eye_r * 0.13, 8, rng, 0.02)
		glint.position = Vector2(ex + eye_r * 0.18, ey - eye_r * 0.05)
		glint.color = Color(1, 1, 1, 0.9)
		_rig.add_child(glint)

	# --- mouth: a wide friendly wobble, with two blunt teeth ---
	_mouth = Polygon2D.new()
	_mouth.polygon = _mouth_shape(w, h, 0.10)
	_mouth.color = Color(0.30, 0.16, 0.20)
	_rig.add_child(_mouth)
	for side in [-1.0, 1.0]:
		var tooth := Polygon2D.new()
		tooth.polygon = PackedVector2Array([
			Vector2(side * w * 0.13 - w * 0.035, -h * 0.475),
			Vector2(side * w * 0.13 + w * 0.035, -h * 0.475),
			Vector2(side * w * 0.13, -h * 0.44),
		])
		tooth.color = Color(0.99, 0.99, 0.95)
		_rig.add_child(tooth)


func _horn(at: Vector2, h: float, w: float, lean: float, color: Color) -> void:
	var horn := Polygon2D.new()
	horn.polygon = PackedVector2Array([
		at + Vector2(-w * 0.07, 0),
		at + Vector2(lean * w * 0.3, -h * 0.14),
		at + Vector2(w * 0.07, 0),
	])
	horn.color = color
	_rig.add_child(horn)


static func _blob(centre: Vector2, radius: float, steps: int,
		rng: RandomNumberGenerator, wobble: float, squash_y: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		var r: float = radius * (1.0 + rng.randf_range(-wobble, wobble))
		points.append(centre + Vector2(cos(a) * r, sin(a) * r * squash_y))
	return points


func _mouth_shape(w: float, h: float, open_amount: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var y := -h * 0.50
	for i in range(9):
		var t: float = float(i) / 8.0
		points.append(Vector2(lerpf(-w * 0.20, w * 0.20, t), y + sin(t * PI) * h * 0.02))
	for i in range(9):
		var t: float = 1.0 - float(i) / 8.0
		points.append(Vector2(lerpf(-w * 0.20, w * 0.20, t), y + sin(t * PI) * h * (0.02 + open_amount)))
	return points


# --- states ---------------------------------------------------------------

## Gentle side-to-side sway so the monster is alive while waiting.
func _sway() -> void:
	if not Juice.motion_enabled():
		return
	var t := create_tween().set_loops()
	t.tween_property(_rig, "rotation_degrees", 2.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_rig, "rotation_degrees", -2.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Startled, not hurt: a squash, a blink, a step back. Reads as "gotcha!"
func flinch() -> void:
	_blink(0.35)
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


func _blink(duration: float) -> void:
	for eye in _eye_whites:
		if is_instance_valid(eye):
			eye.scale = Vector2(1.0, 0.15)
	for pupil in _eye_pupils:
		if is_instance_valid(pupil):
			pupil.visible = false
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		for eye in _eye_whites:
			if is_instance_valid(eye):
				eye.scale = Vector2.ONE
		for pupil in _eye_pupils:
			if is_instance_valid(pupil):
				pupil.visible = true
	)


## Winding up to throw -- a puff, so the child sees it coming.
func puff_up() -> void:
	if not Juice.motion_enabled():
		return
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.10, 1.10), 0.30).set_trans(Tween.TRANS_SINE)
	t.tween_property(_rig, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


## The end of every battle: tired, happy, and off home. Two little jumps, a
## wave (the whole body rocks), then it hops away and the `left` signal fires.
func leave_happy() -> void:
	for pupil in _eye_pupils:
		if is_instance_valid(pupil):
			pupil.position.y -= 6.0   # eyes smile upward
	if _mouth != null and is_instance_valid(_mouth):
		_mouth.polygon = _mouth_shape(
			float(config.get("height", 300.0)) * float(config.get("width", 0.82)),
			float(config.get("height", 300.0)), 0.22)

	if not Juice.motion_enabled():
		left.emit()
		return

	var t := create_tween()
	for i in range(2):
		t.tween_property(_rig, "position:y", -46.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_rig, "position:y", 0.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_rig, "rotation_degrees", -8.0, 0.18)
	t.tween_property(_rig, "rotation_degrees", 8.0, 0.18)
	t.tween_property(_rig, "rotation_degrees", 0.0, 0.14)
	t.tween_property(self, "position:x", position.x + 420.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.9)
	t.tween_callback(func(): left.emit())
