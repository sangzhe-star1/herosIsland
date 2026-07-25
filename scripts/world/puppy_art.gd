extends Node2D
## A chibi blue-heeler puppy, drawn in the island's own hand.
##
## She is the host of the Bluey Park world: she bounces beside the balloon
## games, wags through the wins, and slumps (briefly!) with the plops. Drawn
## rather than imported because this sandbox cannot download show art -- the
## REAL Bluey pictures still have a door: drop hero_idle.png/hero_cheer.png
## into assets/characters/bluey/ and she becomes a playable hero (see
## GameData.DROPIN_CHARACTERS). This drawing is the housemate, not the
## license: same Shapes ink as every hero and monster, feet at the origin.

const BODY := Color(0.42, 0.60, 0.82)      # heeler blue-grey
const DARK := Color(0.28, 0.42, 0.66)      # ear tips, back patch, tail
const CREAM := Color(0.96, 0.91, 0.80)     # belly, muzzle, paws
const TAN := Color(0.93, 0.76, 0.52)       # brow and cheek patches

var _rig: Node2D
var _tail: Node2D
var _hopping := false


func _ready() -> void:
	_rig = Node2D.new()
	add_child(_rig)
	_build()
	_sway()


func _build() -> void:
	var rng := Shapes.rng_for("puppy")
	Shapes.ground_shadow(_rig, Vector2.ZERO, 110.0, 0.18)

	# Tail first (behind), a happy curl that wags.
	_tail = Node2D.new()
	_tail.position = Vector2(-40.0, -58.0)
	_rig.add_child(_tail)
	# Curls UP behind the back -- pointing down it read as a third leg.
	Shapes.fill(_tail, Shapes.taper(Vector2.ZERO, Vector2(-12.0, -40.0), 11.0, 6.0), DARK, 0.9)
	Shapes.fill(_tail, Shapes.circle_points(Vector2(-13.0, -43.0), 7.0, 10), CREAM, 0.7)

	# Body: a bean sitting back on its haunches, cream belly, blue back.
	Shapes.lit(_rig, Shapes.blob(Vector2(0, -46.0), Vector2(46.0, 42.0), rng, 0.10, 3, 18), BODY, 1.0)
	Shapes.fill(_rig, Shapes.oval_points(Vector2(4.0, -36.0), Vector2(28.0, 30.0), 16), CREAM, 0.0)
	# Haunch and front paws planted.
	Shapes.lit(_rig, Shapes.oval_points(Vector2(-26.0, -22.0), Vector2(20.0, 22.0), 14), BODY, 0.9)
	for px in [10.0, 34.0]:
		Shapes.fill(_rig, Shapes.oval_points(Vector2(px, -6.0), Vector2(11.0, 8.0), 10), CREAM, 0.8)

	# Head: big and round, high on the body -- same baby schema as everyone.
	var head := Node2D.new()
	head.position = Vector2(14.0, -108.0)
	_rig.add_child(head)
	# Ears up and alert, dark tips, cream inners.
	for side in [-1.0, 1.0]:
		var ear_x: float = side * 28.0
		Shapes.lit(head, PackedVector2Array([
			Vector2(ear_x - 13.0, -20.0), Vector2(ear_x - 2.0, -48.0), Vector2(ear_x + 13.0, -22.0),
		]), DARK if side < 0.0 else BODY, 0.9)
		Shapes.fill(head, PackedVector2Array([
			Vector2(ear_x - 5.0, -25.0), Vector2(ear_x - 1.0, -38.0), Vector2(ear_x + 5.0, -26.0),
		]), Color(0.98, 0.85, 0.78, 0.85), 0.0)
	Shapes.lit(head, Shapes.blob(Vector2.ZERO, Vector2(40.0, 34.0), rng, 0.08, 3, 18), BODY, 1.0)
	# Tan brow patch ABOVE one eye -- the heeler mask, one idea only. Kept
	# clear of the eye itself: touching it, it read as a black eye.
	Shapes.fill(head, Shapes.oval_points(Vector2(-16.0, -22.0), Vector2(11.0, 7.5), 12), TAN, 0.0)
	# Muzzle, nose, mouth.
	Shapes.fill(head, Shapes.oval_points(Vector2(4.0, 12.0), Vector2(20.0, 14.0), 14), CREAM, 0.0)
	Shapes.fill(head, Shapes.oval_points(Vector2(4.0, 4.0), Vector2(8.0, 6.0), 10),
		Color(0.16, 0.14, 0.18), 0.0)
	Shapes.fill(head, Shapes.rounded_rect(Vector2(-4.0, 16.0), Vector2(16.0, 4.5), 2.2),
		Color(0.16, 0.14, 0.18, 0.6), 0.0)
	# Eyes: the same big low-set lamps as the heroes, catchlights and all.
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * 16.0, -6.0)
		Shapes.fill(head, Shapes.oval_points(eye, Vector2(9.0, 10.0), 12), Color.WHITE, 0.6)
		# Big centred pupils: small off-centre ones made her look worried.
		Shapes.fill(head, Shapes.circle_points(eye + Vector2(0.0, 0.5), 6.2, 12),
			Color(0.16, 0.14, 0.18), 0.0)
		Shapes.fill(head, Shapes.circle_points(eye + Vector2(-2.0, -2.0), 2.2, 8),
			Color(1, 1, 1, 0.95), 0.0)
	# Blush -- she is one of ours.
	for side in [-1.0, 1.0]:
		Shapes.fill(head, Shapes.oval_points(Vector2(side * 26.0, 8.0), Vector2(7.0, 4.5), 10),
			Color(1.0, 0.60, 0.62, 0.30), 0.0)


## The tail never stops; the wag rate is the puppy's heartbeat.
func _sway() -> void:
	if not Juice.motion_enabled() or _tail == null:
		return
	var t := _tail.create_tween().set_loops()
	t.tween_property(_tail, "rotation_degrees", 26.0, 0.24)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_tail, "rotation_degrees", -10.0, 0.24)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## One excited bounce -- fired every time the balloon is kept up.
func hop() -> void:
	if _hopping or not Juice.motion_enabled() or _rig == null:
		return
	_hopping = true
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.06, 0.90), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "position:y", -54.0, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rig, "scale", Vector2(0.96, 1.06), 0.16)
	t.tween_property(_rig, "position:y", 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_rig, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _hopping = false)


## A short, theatrical slump when the balloon plops. Two beats, then back to
## wagging -- disappointment in this game lasts exactly as long as a giggle.
func droop() -> void:
	if not Juice.motion_enabled() or _rig == null:
		return
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.04, 0.92), 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.5)
	t.tween_property(_rig, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
