extends Node2D
## Bluey, drawn from the reference this time.
##
## The first pass guessed and produced "a blue puppy-ish pet on four legs".
## The playtester's father sent us back to look properly, so this build
## follows the published character description: a Blue Heeler who STANDS UP
## and plays like a kid, with the canonical colour map --
##   mid blue      head, torso, arms, legs, tail stem
##   light blue    outer muzzle, chest, eyebrows, paws
##   dark blue     outer ears, head-side spots, torso spots, tail tip
##   tan yellow    inner ears, inner muzzle
##   black         the nose
## (Blueypedia, "Bluey Heeler", appearance section.)
##
## Still a housemate of the art system, not a licence: same Shapes ink, feet
## at the origin, poses as joint angles. If the family drops real show art
## into assets/characters/bluey/, the textured skin takes over automatically
## (GameData.DROPIN_CHARACTERS) and this drawing bows out.
##
## Speaks just enough of HeroArt's language -- set_height, set_pose,
## set_core_color (a polite no-op), core_position -- for SkinnedCharacter to
## carry her through every level like any other hero.

const NOMINAL_HEIGHT := 232.0

const BLUE := Color(0.47, 0.65, 0.85)        # head, torso, limbs, tail stem
const LIGHT := Color(0.85, 0.91, 0.96)       # muzzle, chest, brows, paws
const DARK := Color(0.30, 0.42, 0.68)        # ears, head/torso spots, tail tip
const TAN := Color(0.94, 0.81, 0.48)         # inner ears, inner muzzle
const INK_NOSE := Color(0.13, 0.13, 0.16)

var _rig: Node2D
var _head: Node2D
var _ear_l: Node2D
var _ear_r: Node2D
var _arm_l: Node2D
var _arm_r: Node2D
var _leg_l: Node2D
var _leg_r: Node2D
var _tail: Node2D
var _breath: Tween
var _walk_phase := 0.0
var _walking := false
var _hopping := false


func _ready() -> void:
	_rig = Node2D.new()
	add_child(_rig)
	_build()
	_start_breathing()
	_start_wag()
	set_process(true)


# --- the figure -----------------------------------------------------------

func _build() -> void:
	var rng := Shapes.rng_for("bluey")
	Shapes.ground_shadow(_rig, Vector2.ZERO, 120.0, 0.18)

	# Tail first: at RUMP height, poking out low behind her, dark tip. The
	# first cut hung it at chest height and it read as an antenna beside the
	# muzzle -- a tail is a tail because of where it starts.
	_tail = Node2D.new()
	_tail.position = Vector2(-26.0, -44.0)
	_rig.add_child(_tail)
	# Angled DOWN and back, the heeler default. The up-curl version sat its
	# dark tip right under the arm's paw and the two merged into one long
	# noodle limb; pointed down, tail and arm finally read as two things.
	Shapes.fill(_tail, Shapes.taper(Vector2.ZERO, Vector2(-30.0, 28.0), 12.0, 6.5), BLUE, 0.9)
	Shapes.fill(_tail, Shapes.circle_points(Vector2(-32.0, 30.0), 8.5, 12), DARK, 0.7)

	# Legs: short, blue, ending in light paws -- she stands up like a kid.
	_leg_l = _limb(Vector2(-16.0, -58.0))
	_leg_r = _limb(Vector2(16.0, -58.0))
	for leg in [_leg_l, _leg_r]:
		Shapes.fill(leg, Shapes.taper(Vector2.ZERO, Vector2(0, 44.0), 15.0, 11.0), BLUE, 0.9)
		Shapes.lit(leg, Shapes.oval_points(Vector2(3.0, 52.0), Vector2(16.0, 9.0), 12), LIGHT, 0.8)

	# Torso: an upright bean, light chest front, dark heeler spots on the sides.
	Shapes.lit(_rig, Shapes.blob(Vector2(0, -92.0), Vector2(40.0, 44.0), rng, 0.08, 3, 18), BLUE, 1.0)
	Shapes.fill(_rig, Shapes.oval_points(Vector2(0, -84.0), Vector2(26.0, 32.0), 16), LIGHT, 0.0)
	Shapes.fill(_rig, Shapes.oval_points(Vector2(-33.0, -104.0), Vector2(9.0, 12.0), 10), DARK, 0.0)
	Shapes.fill(_rig, Shapes.oval_points(Vector2(34.0, -84.0), Vector2(8.0, 10.0), 10), DARK, 0.0)

	# Arms: blue, out at the sides, light paw mitts. A round joint inside
	# each shoulder and a cap drawn OVER it on the torso, so a swung arm
	# stays attached -- the slab-with-a-gap version read as a maraca.
	_arm_l = _limb(Vector2(-28.0, -108.0))
	_arm_r = _limb(Vector2(28.0, -108.0))
	for i in range(2):
		var arm: Node2D = [_arm_l, _arm_r][i]
		var side: float = -1.0 if i == 0 else 1.0
		Shapes.fill(arm, Shapes.circle_points(Vector2.ZERO, 7.5, 12), BLUE, 0.0)
		Shapes.fill(arm, Shapes.taper(Vector2(0, -3.0), Vector2(side * 9.0, 34.0), 11.5, 8.0),
			BLUE, 0.9)
		Shapes.lit(arm, Shapes.circle_points(Vector2(side * 10.0, 40.0), 9.5, 12), LIGHT, 0.8)


	# The head: nearly half of her, a wide rounded square. Ears live on it.
	_head = Node2D.new()
	_head.position = Vector2(0, -132.0)
	_rig.add_child(_head)

	_ear_l = _ear(-1.0)
	_ear_r = _ear(1.0)

	Shapes.lit(_head, Shapes.rounded_rect(Vector2(-52.0, -74.0), Vector2(104.0, 82.0), 30.0),
		BLUE, 1.0)
	# Dark spots hugging the head's sides -- the heeler mask.
	Shapes.fill(_head, Shapes.oval_points(Vector2(-45.0, -34.0), Vector2(12.0, 19.0), 12), DARK, 0.0)
	Shapes.fill(_head, Shapes.oval_points(Vector2(45.0, -30.0), Vector2(11.0, 17.0), 12), DARK, 0.0)

	# Muzzle: light outer, tan inner, big black nose, small smile.
	Shapes.fill(_head, Shapes.oval_points(Vector2(0, 0.0), Vector2(30.0, 21.0), 16), LIGHT, 0.0)
	Shapes.fill(_head, Shapes.oval_points(Vector2(0, 6.0), Vector2(22.0, 12.0), 14), TAN, 0.0)
	Shapes.lit(_head, Shapes.oval_points(Vector2(0, -10.0), Vector2(11.0, 8.0), 12), INK_NOSE, 0.0)
	Shapes.fill(_head, Shapes.rounded_rect(Vector2(-8.0, 6.0), Vector2(16.0, 4.0), 2.0),
		Color(0.35, 0.24, 0.18, 0.55), 0.0)

	# Eyes: big white ovals, black pupils, a catchlight each, and the light
	# little brow dashes above them.
	for side in [-1.0, 1.0]:
		var eye := Vector2(side * 21.0, -32.0)
		Shapes.fill(_head, Shapes.oval_points(eye, Vector2(12.5, 14.5), 14), Color.WHITE, 0.5)
		Shapes.fill(_head, Shapes.circle_points(eye + Vector2(0, 1.0), 5.6, 12), INK_NOSE, 0.0)
		Shapes.fill(_head, Shapes.circle_points(eye + Vector2(-2.0, -2.5), 2.0, 8),
			Color(1, 1, 1, 0.95), 0.0)
		Shapes.fill(_head, Shapes.rounded_rect(eye + Vector2(-8.0, -24.0), Vector2(16.0, 5.0), 2.5),
			LIGHT, 0.0)


func _limb(at: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = at
	_rig.add_child(node)
	return node


func _ear(side: float) -> Node2D:
	var ear := Node2D.new()
	# Ears attach to the HEAD node so a head tilt carries them, and they are
	# built before the head shape so their bases hide behind it.
	_head.add_child(ear)
	ear.position = Vector2(side * 34.0, -62.0)
	Shapes.lit(ear, PackedVector2Array([
		Vector2(side * -16.0, 8.0), Vector2(side * 10.0, -52.0), Vector2(side * 20.0, 6.0),
	]), DARK, 0.9)
	Shapes.fill(ear, PackedVector2Array([
		Vector2(side * -7.0, 2.0), Vector2(side * 9.0, -36.0), Vector2(side * 13.0, 2.0),
	]), TAN, 0.0)
	return ear


# --- HeroArt's language, enough of it -------------------------------------

func set_height(pixels: float) -> void:
	var s: float = pixels / NOMINAL_HEIGHT
	scale = Vector2(s, s)


func set_core_color(_value: Color) -> void:
	pass    # no chest lamp on a heeler; levels may ask, she politely declines


func core_position() -> Vector2:
	return to_global(Vector2(0, -90.0))


func head_position() -> Vector2:
	return to_global(Vector2(0, -190.0))


## Poses map HeroArt's vocabulary onto dog joints, so SkinnedCharacter can
## treat her exactly like the drawn heroes. Values match HeroArt.Pose.
func set_pose(pose: int, animate: bool = true) -> void:
	_walking = pose == HeroArt.Pose.WALK
	var duration: float = 0.22 if animate and Juice.motion_enabled() else 0.0
	var angles: Dictionary
	match pose:
		HeroArt.Pose.CHEER:
			angles = {"arm_l": 2.4, "arm_r": -2.4, "leg_l": 0.1, "leg_r": -0.1,
				"head": -0.06, "ears": -0.12, "lift": -4.0}
		HeroArt.Pose.BEAM:
			angles = {"arm_l": -1.0, "arm_r": 1.0, "leg_l": 0.12, "leg_r": -0.1,
				"head": 0.0, "ears": 0.0, "lift": 0.0}
		HeroArt.Pose.HURT:
			angles = {"arm_l": 0.45, "arm_r": -0.25, "leg_l": 0.15, "leg_r": -0.08,
				"head": 0.14, "ears": 0.55, "lift": 5.0}
		HeroArt.Pose.JUMP:
			angles = {"arm_l": 2.7, "arm_r": -2.7, "leg_l": 0.5, "leg_r": -0.4,
				"head": -0.08, "ears": -0.20, "lift": 0.0}
		HeroArt.Pose.TUCK:
			angles = {"arm_l": -1.1, "arm_r": 1.1, "leg_l": 0.8, "leg_r": -0.8,
				"head": 0.22, "ears": 0.4, "lift": 12.0}
		_:
			angles = {"arm_l": 0.25, "arm_r": -0.25, "leg_l": 0.04, "leg_r": -0.04,
				"head": 0.0, "ears": 0.0, "lift": 0.0}
	_pose_tween(_arm_l, angles["arm_l"], duration)
	_pose_tween(_arm_r, angles["arm_r"], duration)
	_pose_tween(_leg_l, angles["leg_l"], duration)
	_pose_tween(_leg_r, angles["leg_r"], duration)
	_pose_tween(_head, angles["head"], duration)
	if _ear_l != null and is_instance_valid(_ear_l):
		_pose_tween(_ear_l, float(angles["ears"]) * -1.0, duration)
	if _ear_r != null and is_instance_valid(_ear_r):
		_pose_tween(_ear_r, angles["ears"], duration)
	if _rig != null and is_instance_valid(_rig):
		if duration <= 0.0:
			_rig.position.y = float(angles["lift"])
		else:
			var t := _rig.create_tween()
			t.tween_property(_rig, "position:y", float(angles["lift"]), duration)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pose_tween(node: Node2D, angle: float, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if duration <= 0.0:
		node.rotation = angle
		return
	var t := node.create_tween()
	t.tween_property(node, "rotation", angle, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func crouch(animate: bool = true) -> void:
	set_pose(HeroArt.Pose.TUCK, animate)


func spin(_turns: float = 1.0, _duration: float = 0.5) -> void:
	hop()    # a heeler's roll is a bounce; close enough, and always happy


func pulse_core(_times: int = 1) -> void:
	hop()


# --- her own verbs ----------------------------------------------------------

## One excited bounce -- balloons kept up, friends spotted, anything really.
func hop() -> void:
	if _hopping or not Juice.motion_enabled() or _rig == null:
		return
	_hopping = true
	var t := create_tween()
	t.tween_property(_rig, "scale", Vector2(1.06, 0.90), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_rig, "position:y", -50.0, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rig, "scale", Vector2(0.96, 1.06), 0.16)
	t.tween_property(_rig, "position:y", 0.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_rig, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _hopping = false)


## Ears down, a small slump, two beats, forgiven.
func droop() -> void:
	set_pose(HeroArt.Pose.HURT)
	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func():
		if is_inside_tree():
			set_pose(HeroArt.Pose.IDLE)
	)


## One arm up, waving hello -- the blaster range's "it's me, don't shoot!".
func wave() -> void:
	if _arm_r == null or not is_instance_valid(_arm_r) or not Juice.motion_enabled():
		return
	var t := _arm_r.create_tween()
	t.tween_property(_arm_r, "rotation", -2.6, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in range(2):
		t.tween_property(_arm_r, "rotation", -2.1, 0.14).set_trans(Tween.TRANS_SINE)
		t.tween_property(_arm_r, "rotation", -2.7, 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_property(_arm_r, "rotation", -0.25, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# --- life -------------------------------------------------------------------

func _start_breathing() -> void:
	if not Juice.motion_enabled() or _rig == null:
		return
	_breath = create_tween().set_loops()
	_breath.tween_property(_rig, "scale", Vector2(1.0, 1.014), 1.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(_rig, "scale", Vector2(1.0, 1.0), 1.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_wag() -> void:
	if not Juice.motion_enabled() or _tail == null:
		return
	var t := _tail.create_tween().set_loops()
	t.tween_property(_tail, "rotation_degrees", 24.0, 0.24)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_tail, "rotation_degrees", -8.0, 0.24)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if not _walking or not Juice.motion_enabled():
		return
	_walk_phase += delta * 7.0
	var swing: float = sin(_walk_phase) * 0.5
	if is_instance_valid(_leg_l):
		_leg_l.rotation = swing
	if is_instance_valid(_leg_r):
		_leg_r.rotation = -swing
	if is_instance_valid(_arm_l):
		_arm_l.rotation = 0.25 - swing * 0.4
	if is_instance_valid(_arm_r):
		_arm_r.rotation = -0.25 - swing * 0.4
