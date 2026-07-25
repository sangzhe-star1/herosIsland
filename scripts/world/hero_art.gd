class_name HeroArt
extends Node2D
## The hero, drawn. Third design pass: the chibi build.
##
## The second pass fixed the marionette problems (visible joints, slab torso,
## tired eyes) but kept heroic four-and-a-half-head proportions -- and it
## still read as an adult in armour. The research on what actually makes a
## character likeable to small children is unambiguous and boring: the baby
## schema. Big head relative to the body, large LOW-SET eyes, round cheeks,
## small mouth, short thick limbs. Chibi practice lands the same place from
## the other direction: two to three heads tall, half of it head, details
## simplified, hands as mittens.
##
## So this build is ~2.2 heads: the head is nearly half the figure, the eyes
## are enormous and sit BELOW the head's midline, the cheeks blush, the limbs
## are stubs and the boots are huge. The hero identity survives entirely in
## the crest, the chest core, the colours and the poses -- which is the point
## of the skin system.
##
## Still a rig: poses are joint angles, so the chibi crouches, leaps, tucks
## and rolls. One geometric consequence of the huge head: raised arms must
## angle OUTWARD (CHEER, JUMP), because straight up puts the fists on the
## face.

enum Pose { IDLE, CHEER, BEAM, WALK, HURT, JUMP, TUCK }

## Nominal height from boot sole to helmet crown, in local units. Every level
## scales the hero by asking for a height in pixels rather than guessing a
## scale factor.
const NOMINAL_HEIGHT := 232.0

var design: CharacterSkin

## self -> _spin -> _root -> parts.
## _spin's origin sits at the body's centre so a roll rotates the hero around
## their middle; _root's origin is back at the feet so everything else (poses,
## breathing, placement) keeps thinking in feet-at-zero coordinates.
const SPIN_CENTRE_Y := -100.0

var _spin: Node2D
var _root: Node2D
var _head: Node2D
var _torso: Node2D
var _arm_back: Node2D
var _arm_front: Node2D
var _leg_back: Node2D
var _leg_front: Node2D
var _core: Polygon2D
var _core_halo: Node2D
var _eyes: Array[Polygon2D] = []

var _pose: Pose = Pose.IDLE
var _breath: Tween
var _walk_phase := 0.0
var _walking := false

# The skeleton, in local units, feet at y = 0 and the body going up.
# Chibi: the head owns everything above -118; the body is a bean below it.
const HIP_Y := -46.0
const SHOULDER_Y := -108.0
const NECK_Y := -122.0


func _init(skin: CharacterSkin = null) -> void:
	design = skin if skin != null else CharacterSkin.new()


func _ready() -> void:
	rebuild()
	set_pose(Pose.IDLE, false)
	_start_breathing()
	set_process(true)


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_eyes.clear()

	_spin = Node2D.new()
	_spin.position = Vector2(0, SPIN_CENTRE_Y)
	add_child(_spin)
	_root = Node2D.new()
	_root.position = Vector2(0, -SPIN_CENTRE_Y)
	_spin.add_child(_root)

	# Back to front. Back limbs are the same suit turned away from the light,
	# not a different colour.
	_leg_back = _limb_root(Vector2(_u(-13.0), HIP_Y + 2.0))
	_build_leg(_leg_back, true)
	_arm_back = _limb_root(Vector2(_u(-28.0), SHOULDER_Y + 2.0))
	_build_arm(_arm_back, true)

	_torso = Node2D.new()
	_root.add_child(_torso)
	_build_torso(_torso)

	_leg_front = _limb_root(Vector2(_u(13.0), HIP_Y + 2.0))
	_build_leg(_leg_front, false)

	_head = Node2D.new()
	_head.position = Vector2(0, NECK_Y)
	_root.add_child(_head)
	_build_head(_head)

	_arm_front = _limb_root(Vector2(_u(28.0), SHOULDER_Y + 2.0))
	_build_arm(_arm_front, false)

	# Shoulder domes last, over the arm joints: a pad the arm can slide out
	# from under is armour; one the arm detaches from is a sticker.
	var caps := Node2D.new()
	_root.add_child(caps)
	_build_shoulder_caps(caps)


func _limb_root(at: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = at
	_root.add_child(node)
	return node


# --- parts --------------------------------------------------------------
#
# Everything below is written in local units at build_width 76; _u() scales,
# so a heavier hero is one number in the skin rather than a second drawing.

func _u(v: float) -> float:
	return v * design.build_width / 76.0


func _suit(back: bool) -> Color:
	return design.body_color.darkened(0.16) if back else design.body_color


func _accent(back: bool) -> Color:
	return design.accent_color.darkened(0.16) if back else design.accent_color


func _build_torso(parent: Node2D) -> void:
	var suit: Color = design.body_color

	# A bean, not a bodice: widest at the bottom, tucked under the chin at
	# the top. The chin overlaps the collar, because a chibi has no neck.
	Shapes.lit(parent, PackedVector2Array([
		Vector2(_u(-26.0), _u(-124.0)),
		Vector2(_u(26.0), _u(-124.0)),
		Vector2(_u(31.0), _u(-112.0)),
		Vector2(_u(33.0), _u(-90.0)),
		Vector2(_u(34.0), _u(-64.0)),
		Vector2(_u(27.0), _u(-46.0)),
		Vector2(_u(-27.0), _u(-46.0)),
		Vector2(_u(-34.0), _u(-64.0)),
		Vector2(_u(-33.0), _u(-90.0)),
		Vector2(_u(-31.0), _u(-112.0)),
	]), suit, 1.0)

	# The accent, one idea per suit.
	match design.chest_pattern:
		"chevron":
			for side in [-1.0, 1.0]:
				Shapes.fill(parent, PackedVector2Array([
					Vector2(side * _u(31.0), _u(-112.0)),
					Vector2(side * _u(18.0), _u(-118.0)),
					Vector2(0.0, _u(-96.0)),
					Vector2(0.0, _u(-82.0)),
				]), design.accent_color, 0.7)
		"bands":
			for i2 in range(2):
				var y: float = _u(-104.0 + float(i2) * 18.0)
				var half: float = _u(lerpf(31.0, 28.0, float(i2)))
				Shapes.fill(parent, Shapes.rounded_rect(
					Vector2(-half, y), Vector2(half * 2.0, _u(9.0)), 4.5),
					design.accent_color, 0.7)
		"blade", _:
			for side in [-1.0, 1.0]:
				Shapes.fill(parent, PackedVector2Array([
					Vector2(side * _u(30.0), _u(-113.0)),
					Vector2(side * _u(16.0), _u(-118.0)),
					Vector2(side * _u(12.0), _u(-88.0)),
					Vector2(side * _u(15.0), _u(-58.0)),
					Vector2(side * _u(25.0), _u(-62.0)),
					Vector2(side * _u(24.0), _u(-90.0)),
				]), design.accent_color, 0.7)

	# Belt, low on the bean.
	Shapes.fill(parent, Shapes.rounded_rect(
		Vector2(_u(-28.0), _u(-60.0)), Vector2(_u(56.0), _u(11.0)), 5.5),
		design.trim_color, 0.8)
	Shapes.fill(parent, Shapes.rounded_rect(
		Vector2(_u(-5.5), _u(-59.0)), Vector2(_u(11.0), _u(9.0)), 3.0),
		design.trim_color.darkened(0.25), 0.6)

	# The chest core. Levels recolour it -- in the colour-matching levels it
	# IS the instruction, the whole reason the hero is drawn, not blitted.
	var core_at := Vector2(0, _u(-86.0))
	_core_halo = Shapes.glow(parent, core_at, _u(54.0), design.core_color, 5, 0.45)
	Shapes.lit(parent, Shapes.circle_points(core_at, _u(13.5), 22),
		design.trim_color, 0.9)
	_core = Shapes.fill(parent, Shapes.oval_points(core_at,
		Vector2(_u(9.5), _u(10.5)), 20), design.core_color, 0.0)
	Shapes.fill(parent, Shapes.oval_points(core_at + Vector2(_u(-3.2), _u(-3.6)),
		Vector2(_u(3.6), _u(2.4)), 10), Color(1, 1, 1, 0.75), 0.0)


func _build_shoulder_caps(parent: Node2D) -> void:
	for side in [-1.0, 1.0]:
		var centre := Vector2(side * _u(28.5), _u(-104.0))
		var pts := PackedVector2Array()
		for i2 in range(11):
			var a: float = PI + PI * float(i2) / 10.0
			pts.append(centre + Vector2(cos(a) * _u(10.5), sin(a) * _u(8.5)))
		pts.append(centre + Vector2(_u(8.0), _u(4.0)))
		pts.append(centre + Vector2(_u(-8.0), _u(4.0)))
		Shapes.lit(parent, pts, design.accent_color, 1.0)


func _build_head(parent: Node2D) -> void:
	# Nearly half the figure. rx/ry are the head's radii; everything on the
	# face is a fraction of them.
	var rx: float = _u(50.0)
	var ry: float = _u(54.0)
	var centre := Vector2(0, -ry * 0.96)

	# The helmet: a soft egg, fuller at the cheeks (baby schema: round cheeks
	# beat a strong jaw).
	var helmet := PackedVector2Array()
	for i2 in range(30):
		var a: float = TAU * float(i2) / 30.0
		var x: float = cos(a) * rx
		var y: float = sin(a) * ry
		if y > 0.0:
			x *= lerpf(1.0, 0.90, y / ry)     # gentle taper, chin stays round
			y *= 1.02
		helmet.append(centre + Vector2(x, y))
	Shapes.lit(parent, helmet, design.body_color, 1.0)

	# Ear pods.
	for side in [-1.0, 1.0]:
		Shapes.fill(parent, Shapes.oval_points(
			centre + Vector2(side * rx * 0.96, ry * 0.10),
			Vector2(rx * 0.10, ry * 0.14), 12), design.body_color.darkened(0.14), 0.8)

	# Eyes: enormous, and LOW-SET -- below the head's midline. High-set eyes
	# age a face; low-set eyes are most of what "cute" means, and this is the
	# single biggest lever on the whole character.
	for side in [-1.0, 1.0]:
		var eye_centre := centre + Vector2(side * rx * 0.42, ry * 0.14)
		var tilt: float = -side * 0.14
		var eye_pts := PackedVector2Array()
		for i2 in range(20):
			var a: float = TAU * float(i2) / 20.0
			var p := Vector2(cos(a) * rx * 0.30, sin(a) * ry * 0.26)
			eye_pts.append(eye_centre + p.rotated(tilt))
		Shapes.glow(parent, eye_centre, rx * 0.85, design.eye_color, 4, 0.40)
		var rim := PackedVector2Array()
		for p2 in eye_pts:
			rim.append(eye_centre + (p2 - eye_centre) * 1.12)
		Shapes.fill(parent, rim, design.body_color.darkened(0.30), 0.0)
		_eyes.append(Shapes.fill(parent, eye_pts, design.eye_color, 0.0))
		# Two catchlights: one big high-outer, one small low-inner. Same trick
		# as the monsters' eyes; it is what makes an eye look AT you.
		Shapes.fill(parent, Shapes.oval_points(
			eye_centre + Vector2(side * rx * 0.09, -ry * 0.09).rotated(tilt),
			Vector2(rx * 0.09, ry * 0.06), 10), Color(1, 1, 1, 0.9), 0.0)
		Shapes.fill(parent, Shapes.oval_points(
			eye_centre + Vector2(-side * rx * 0.07, ry * 0.08).rotated(tilt),
			Vector2(rx * 0.045, ry * 0.03), 8), Color(1, 1, 1, 0.5), 0.0)

	# Cheek blush: two soft warm patches under the eyes. Kept faint -- it
	# reads as roundness, not make-up.
	for side in [-1.0, 1.0]:
		Shapes.fill(parent, Shapes.oval_points(
			centre + Vector2(side * rx * 0.58, ry * 0.44),
			Vector2(rx * 0.15, ry * 0.08), 12), Color(1.0, 0.60, 0.62, 0.26), 0.0)

	# A tiny mouth, low. Small mouth is part of the schema; the second pass's
	# wide guard read as a grille.
	Shapes.fill(parent, Shapes.rounded_rect(
		centre + Vector2(-rx * 0.10, ry * 0.60), Vector2(rx * 0.20, ry * 0.075),
		ry * 0.037), design.body_color.darkened(0.18), 0.0)

	# The crest -- the silhouette. Scaled to the big head, swept back.
	match design.crest_kind:
		"fin":
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(-rx * 0.05, -ry * 0.92),
				centre + Vector2(-rx * 0.13, -ry * 1.22),
				centre + Vector2(0.0, -ry * 1.68),
				centre + Vector2(rx * 0.26, -ry * 1.12),
				centre + Vector2(rx * 0.15, -ry * 0.84),
			]), design.accent_color, 1.0)
			Shapes.fill(parent, PackedVector2Array([
				centre + Vector2(-rx * 0.01, -ry * 0.98),
				centre + Vector2(-rx * 0.03, -ry * 1.42),
				centre + Vector2(rx * 0.10, -ry * 1.04),
			]), design.trim_color, 0.0)
		"twin":
			for side in [-1.0, 1.0]:
				Shapes.lit(parent, PackedVector2Array([
					centre + Vector2(side * rx * 0.10, -ry * 0.88),
					centre + Vector2(side * rx * 0.38, -ry * 1.58),
					centre + Vector2(side * rx * 0.64, -ry * 0.98),
					centre + Vector2(side * rx * 0.42, -ry * 0.70),
				]), design.accent_color, 1.0)
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(0.0, -ry * 1.26),
				centre + Vector2(rx * 0.12, -ry * 0.88),
				centre + Vector2(-rx * 0.12, -ry * 0.88),
			]), design.trim_color, 1.0)
		"horns":
			for side in [-1.0, 1.0]:
				Shapes.lit(parent, PackedVector2Array([
					centre + Vector2(side * rx * 0.22, -ry * 0.88),
					centre + Vector2(side * rx * 1.02, -ry * 1.44),
					centre + Vector2(side * rx * 0.92, -ry * 1.10),
					centre + Vector2(side * rx * 0.36, -ry * 0.60),
				]), design.trim_color, 1.0)
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(0.0, -ry * 1.40),
				centre + Vector2(rx * 0.16, -ry * 0.84),
				centre + Vector2(-rx * 0.16, -ry * 0.84),
			]), design.accent_color, 1.0)


func _build_arm(parent: Node2D, back: bool) -> void:
	# Stubs with mittens. No elbow detail: at this scale a bend line is
	# noise, and the mitten is the friendliest hand there is.
	var upper: float = _u(18.0)
	var lower: float = _u(15.0)
	Shapes.fill(parent, Shapes.circle_points(Vector2.ZERO, _u(7.5), 12),
		_suit(back), 0.0)
	Shapes.fill(parent, Shapes.taper(Vector2(0, _u(-4.0)), Vector2(0, upper),
		_u(14.5), _u(12.0)), _suit(back), 1.0)

	var fore := Node2D.new()
	fore.name = "Fore"
	fore.position = Vector2(0, upper)
	parent.add_child(fore)
	Shapes.fill(fore, Shapes.circle_points(Vector2.ZERO, _u(6.0), 10),
		_suit(back), 0.0)
	Shapes.fill(fore, Shapes.taper(Vector2(0, _u(-3.0)), Vector2(0, lower),
		_u(12.0), _u(10.0)), _suit(back), 1.0)
	# Cuff band, then the mitten.
	Shapes.fill(fore, Shapes.rounded_rect(Vector2(_u(-8.0), lower * 0.42),
		Vector2(_u(16.0), _u(6.5)), 3.0), _accent(back), 0.8)
	Shapes.lit(fore, Shapes.circle_points(Vector2(0, lower + _u(7.5)), _u(10.0), 16),
		_suit(back), 1.0)


func _build_leg(parent: Node2D, back: bool) -> void:
	# Short and thick, ending in a boot that is almost as big as the leg --
	# stubby limbs and planted feet are the rest of the schema.
	var thigh: float = _u(18.0)
	var shin: float = _u(13.0)
	Shapes.fill(parent, Shapes.circle_points(Vector2.ZERO, _u(9.0), 12),
		_suit(back), 0.0)
	Shapes.fill(parent, Shapes.taper(Vector2(0, _u(-5.0)), Vector2(0, thigh),
		_u(17.0), _u(14.0)), _suit(back), 1.0)

	var lower := Node2D.new()
	lower.name = "Shin"
	lower.position = Vector2(0, thigh)
	parent.add_child(lower)
	Shapes.fill(lower, Shapes.circle_points(Vector2.ZERO, _u(7.0), 10),
		_suit(back), 0.0)
	Shapes.fill(lower, Shapes.taper(Vector2(0, _u(-3.0)), Vector2(0, shin * 0.6),
		_u(13.5), _u(12.0)), _suit(back), 1.0)

	Shapes.lit(lower, PackedVector2Array([
		Vector2(_u(-11.0), shin * 0.30),
		Vector2(_u(11.0), shin * 0.30),
		Vector2(_u(12.0), shin + _u(4.0)),
		Vector2(_u(17.0), shin + _u(9.0)),
		Vector2(_u(17.0), shin + _u(13.0)),
		Vector2(_u(-14.0), shin + _u(13.0)),
		Vector2(_u(-12.0), shin + _u(4.0)),
	]), _accent(back), 1.0)
	Shapes.fill(lower, Shapes.rounded_rect(Vector2(_u(-11.0), shin * 0.28),
		Vector2(_u(22.0), _u(4.5)), 2.0), design.trim_color, 0.0)
	Shapes.fill(lower, Shapes.rounded_rect(Vector2(_u(-14.0), shin + _u(11.0)),
		Vector2(_u(31.0), _u(4.0)), 2.0),
		(_accent(back) as Color).darkened(0.30), 0.0)


# --- posing -------------------------------------------------------------

## Every pose is a set of joint angles; changing pose is a tween, not a
## texture swap, so the hero moves between them instead of cutting.
func set_pose(pose: Pose, animate: bool = true) -> void:
	_pose = pose
	_walking = pose == Pose.WALK
	_apply_angles(_angles_for(pose), 0.22 if animate and Juice.motion_enabled() else 0.0)


## The crouch that loads a jump. Not a public pose -- it exists for the beat
## between standing and leaping, which is what sells the leap.
func crouch(animate: bool = true) -> void:
	_apply_angles({
		"arm_back": deg_to_rad(-30.0), "fore_back": deg_to_rad(-18.0),
		"arm_front": deg_to_rad(30.0), "fore_front": deg_to_rad(18.0),
		"leg_back": deg_to_rad(-16.0), "shin_back": deg_to_rad(24.0),
		"leg_front": deg_to_rad(16.0), "shin_front": deg_to_rad(-24.0),
		"head": deg_to_rad(4.0), "torso": deg_to_rad(3.0), "lift": 12.0,
	}, 0.09 if animate and Juice.motion_enabled() else 0.0)


func _apply_angles(angles: Dictionary, duration: float) -> void:
	_apply(_arm_back, angles["arm_back"], angles["fore_back"], duration)
	_apply(_arm_front, angles["arm_front"], angles["fore_front"], duration)
	_apply(_leg_back, angles["leg_back"], angles["shin_back"], duration)
	_apply(_leg_front, angles["leg_front"], angles["shin_front"], duration)
	_tween_to(_head, "rotation", angles["head"], duration)
	_tween_to(_torso, "rotation", angles["torso"], duration)
	_tween_to(_root, "position:y", -SPIN_CENTRE_Y + float(angles["lift"]), duration)


func _angles_for(pose: Pose) -> Dictionary:
	match pose:
		Pose.CHEER:
			# Up AND OUT: at chibi proportions a straight-up arm puts the fist
			# on the face, because the head is wider than the shoulders.
			return {
				"arm_back": deg_to_rad(120.0), "fore_back": deg_to_rad(10.0),
				"arm_front": deg_to_rad(-120.0), "fore_front": deg_to_rad(-10.0),
				"leg_back": deg_to_rad(-7.0), "shin_back": deg_to_rad(4.0),
				"leg_front": deg_to_rad(7.0), "shin_front": deg_to_rad(-4.0),
				"head": deg_to_rad(-3.0), "torso": 0.0, "lift": -6.0,
			}
		Pose.BEAM:
			# The crossed-forearm brace: both hands by the chest core, where
			# the light comes from in every beam level.
			return {
				"arm_back": deg_to_rad(96.0), "fore_back": deg_to_rad(-96.0),
				"arm_front": deg_to_rad(-96.0), "fore_front": deg_to_rad(96.0),
				"leg_back": deg_to_rad(-15.0), "shin_back": deg_to_rad(9.0),
				"leg_front": deg_to_rad(13.0), "shin_front": deg_to_rad(-7.0),
				"head": 0.0, "torso": deg_to_rad(-2.0), "lift": 0.0,
			}
		Pose.HURT:
			# A stumble, never a collapse.
			return {
				"arm_back": deg_to_rad(-32.0), "fore_back": deg_to_rad(-40.0),
				"arm_front": deg_to_rad(26.0), "fore_front": deg_to_rad(44.0),
				"leg_back": deg_to_rad(-18.0), "shin_back": deg_to_rad(14.0),
				"leg_front": deg_to_rad(10.0), "shin_front": deg_to_rad(-6.0),
				"head": deg_to_rad(9.0), "torso": deg_to_rad(7.0), "lift": 4.0,
			}
		Pose.JUMP:
			# Airborne: arms flung up and back, legs bent unevenly. The
			# asymmetry is what makes it read as a leap instead of a levitate.
			return {
				"arm_back": deg_to_rad(128.0), "fore_back": deg_to_rad(18.0),
				"arm_front": deg_to_rad(-128.0), "fore_front": deg_to_rad(-18.0),
				"leg_back": deg_to_rad(-30.0), "shin_back": deg_to_rad(44.0),
				"leg_front": deg_to_rad(22.0), "shin_front": deg_to_rad(-52.0),
				"head": deg_to_rad(-5.0), "torso": deg_to_rad(-4.0), "lift": 0.0,
			}
		Pose.TUCK:
			# Rolled into a ball, for the tumble: knees to chest, arms hugged
			# in, chin down.
			return {
				"arm_back": deg_to_rad(-46.0), "fore_back": deg_to_rad(-88.0),
				"arm_front": deg_to_rad(46.0), "fore_front": deg_to_rad(88.0),
				"leg_back": deg_to_rad(-44.0), "shin_back": deg_to_rad(62.0),
				"leg_front": deg_to_rad(40.0), "shin_front": deg_to_rad(-64.0),
				"head": deg_to_rad(12.0), "torso": deg_to_rad(6.0), "lift": 10.0,
			}
		Pose.WALK, Pose.IDLE, _:
			# At ease, not at attention: arms slightly out with a soft elbow,
			# one leg a touch forward. Clamped-to-the-sides arms were most of
			# why the first pass read as a toy soldier.
			return {
				"arm_back": deg_to_rad(16.0), "fore_back": deg_to_rad(8.0),
				"arm_front": deg_to_rad(-16.0), "fore_front": deg_to_rad(-8.0),
				"leg_back": deg_to_rad(-4.0), "shin_back": deg_to_rad(2.0),
				"leg_front": deg_to_rad(4.0), "shin_front": deg_to_rad(-2.0),
				"head": 0.0, "torso": 0.0, "lift": 0.0,
			}


func _apply(limb: Node2D, upper: float, lower: float, duration: float) -> void:
	if limb == null or not is_instance_valid(limb):
		return
	_tween_to(limb, "rotation", upper, duration)
	for child in limb.get_children():
		if child is Node2D and (child.name == "Fore" or child.name == "Shin"):
			_tween_to(child, "rotation", lower, duration)


func _tween_to(node: Node, property: String, value: Variant, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if duration <= 0.0:
		node.set_indexed(property, value)
		return
	var t: Tween = node.create_tween()
	t.tween_property(node, property, value, duration).set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## One full turn around the body's centre -- the roll. The spin node exists
## for exactly this: rotating _root would pivot the hero around their feet
## and the tumble would look like a cartwheel off a cliff edge.
func spin(turns: float = 1.0, duration: float = 0.5) -> void:
	if _spin == null or not is_instance_valid(_spin) or not Juice.motion_enabled():
		return
	var t := _spin.create_tween()
	t.tween_property(_spin, "rotation", TAU * turns, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		if is_instance_valid(_spin):
			_spin.rotation = 0.0
	)


# --- life ---------------------------------------------------------------

## Nothing on screen is completely still while the game waits for a child --
## a frozen character reads as "the game has stopped".
func _start_breathing() -> void:
	if not Juice.motion_enabled() or _root == null:
		return
	_breath = create_tween().set_loops()
	_breath.tween_property(_root, "scale", Vector2(1.0, 1.012), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_root, "scale", Vector2(1.0, 1.0), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if not _walking or not Juice.motion_enabled():
		return
	_walk_phase += delta * 6.4
	var swing: float = sin(_walk_phase) * 0.52
	if is_instance_valid(_leg_front):
		_leg_front.rotation = swing
	if is_instance_valid(_leg_back):
		_leg_back.rotation = -swing
	if is_instance_valid(_arm_front):
		_arm_front.rotation = -swing * 0.6
	if is_instance_valid(_arm_back):
		_arm_back.rotation = swing * 0.6
	if is_instance_valid(_root):
		_root.position.y = -SPIN_CENTRE_Y - absf(sin(_walk_phase)) * 3.0


# --- what levels ask of it ----------------------------------------------

func set_core_color(value: Color) -> void:
	if _core != null and is_instance_valid(_core):
		_core.color = value
	if _core_halo != null and is_instance_valid(_core_halo):
		_core_halo.modulate = Color(value.r, value.g, value.b, 1.0)


## Where the beam comes from, in global coordinates.
func core_position() -> Vector2:
	return to_global(Vector2(0, _u(-86.0)))


func head_position() -> Vector2:
	return to_global(Vector2(0, NECK_Y - _u(50.0)))


## A slow brightening of the chest light. Slow on purpose: rapid flicker is
## unpleasant for a small child and a genuine seizure risk.
func pulse_core(times: int = 1) -> void:
	if _core == null or not Juice.motion_enabled():
		return
	var base: Color = _core.color
	var t: Tween = create_tween().set_loops(times)
	t.tween_property(_core, "color", base.lightened(0.45), 0.30).set_trans(Tween.TRANS_SINE)
	t.tween_property(_core, "color", base, 0.42).set_trans(Tween.TRANS_SINE)


## Fits the hero to a height in pixels, so levels say how big rather than
## guessing a scale.
func set_height(pixels: float) -> void:
	var s: float = pixels / NOMINAL_HEIGHT
	scale = Vector2(s, s)
