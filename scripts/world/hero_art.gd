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

## What the hero is wearing, by slot: {"hat": id, "face": id, "back": id},
## empty strings for bare. Set by SkinnedCharacter from the save before the
## figure is built; HeroArt itself never reads the save (it draws designs,
## it does not know whose game this is).
var outfit: Dictionary = {}

## Colour schemes for the wardrobe's "colour" slot: three values that repaint
## the whole suit at once. They live here, with the drawing, because that is
## where the knowledge of which colour goes on what already is -- the shop
## just sells the ids.
const PALETTES := {
	"sky":    {"body": Color(0.74, 0.87, 0.98), "accent": Color(0.24, 0.52, 0.88),
		"trim": Color(1.0, 0.90, 0.48)},
	"mint":   {"body": Color(0.86, 0.96, 0.90), "accent": Color(0.22, 0.70, 0.52),
		"trim": Color(1.0, 0.92, 0.58)},
	"rose":   {"body": Color(0.99, 0.91, 0.94), "accent": Color(0.88, 0.34, 0.52),
		"trim": Color(1.0, 0.86, 0.42)},
	"sun":    {"body": Color(1.0, 0.95, 0.82), "accent": Color(0.96, 0.60, 0.18),
		"trim": Color(0.99, 0.99, 0.99)},
	"violet": {"body": Color(0.91, 0.87, 0.99), "accent": Color(0.54, 0.34, 0.86),
		"trim": Color(1.0, 0.88, 0.45)},
	"shadow": {"body": Color(0.34, 0.38, 0.50), "accent": Color(0.18, 0.86, 0.90),
		"trim": Color(0.95, 0.96, 1.0)},
}

## The skin as the level handed it over. `design` is what actually gets
## drawn, and a chosen palette makes it a repainted copy -- so every line of
## drawing code below keeps reading `design` and knows nothing about
## wardrobes.
var _base_design: CharacterSkin

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
	if _base_design == null:
		_base_design = design
	design = _repainted(_base_design)

	_spin = Node2D.new()
	_spin.position = Vector2(0, SPIN_CENTRE_Y)
	add_child(_spin)
	_root = Node2D.new()
	_root.position = Vector2(0, -SPIN_CENTRE_Y)
	_spin.add_child(_root)

	# The back of the wardrobe first: a cape or wings live BEHIND the body.
	_build_back_piece(_root)

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

	# What is WORN on the body: a skirt hangs over the legs, a vest sits on
	# the chest. Drawn after the legs and before the head so it layers the
	# way clothes do.
	_build_suit(_root)

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


## The skin, in the chosen colours. No colour chosen, no copy made.
func _repainted(base: CharacterSkin) -> CharacterSkin:
	var scheme_id := str(outfit.get("colour", ""))
	if scheme_id == "" or not PALETTES.has(scheme_id) or base == null:
		return base
	var scheme: Dictionary = PALETTES[scheme_id]
	var painted: CharacterSkin = base.duplicate()
	painted.body_color = scheme["body"]
	painted.accent_color = scheme["accent"]
	painted.trim_color = scheme["trim"]
	return painted


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
		# The three below sit as a BADGE on the left chest. The first two cuts
		# put them in the middle -- once big and centred on the core, once in a
		# band above it -- and both came out invisible: the chin covers the
		# chest above -108, the core plate and its halo own the middle, and the
		# arms cover past x 20. What is actually seen from the front is the
		# flank, which is where blade and chevron have always lived.
		"star":
			# Big, and deliberately BEHIND the chest light: the core becomes the
			# star's middle and the points radiate into the parts of the torso
			# that are actually visible. A badge-sized star on the flank was
			# tried first and disappeared under the shoulder cap.
			Shapes.lit(parent, Shapes.star_points(
				Vector2(0.0, _u(-88.0)), _u(27.0), 0.44, 5),
				design.accent_color, 0.8)
		"heart":
			# Same trick: the heart frames the core rather than hiding behind
			# it.
			for side in [-1.0, 1.0]:
				Shapes.fill(parent, Shapes.oval_points(
					Vector2(side * _u(12.0), _u(-94.0)),
					Vector2(_u(14.0), _u(12.0)), 20), design.accent_color, 0.7)
			Shapes.fill(parent, PackedVector2Array([
				Vector2(_u(-25.0), _u(-93.0)),
				Vector2(_u(25.0), _u(-93.0)),
				Vector2(0.0, _u(-61.0)),
			]), design.accent_color, 0.7)
		"ring":
			# Beads arching over the core: a full ring would have its bottom
			# half behind the core plate and never be seen.
			for i2 in range(7):
				var ra: float = lerpf(PI * 1.10, PI * 1.90, float(i2) / 6.0)
				Shapes.fill(parent, Shapes.circle_points(
					Vector2(cos(ra) * _u(25.0), _u(-92.0) + sin(ra) * _u(21.0)),
					_u(5.0), 12), design.accent_color, 0.7)
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
		# Lashes: three little strokes fanning off the outer-top rim. The one
		# detail that reads "she" at this scale without narrowing the eye,
		# which stays as big and bright as everyone else's.
		if design.lashes:
			for li in range(3):
				var la: float = -0.95 + 0.38 * float(li)
				var lash_dir := Vector2(cos(la) * side, sin(la))
				var lash_base := eye_centre + Vector2(lash_dir.x * rx * 0.315,
					lash_dir.y * ry * 0.275).rotated(tilt)
				var lash_tip := lash_base + Vector2(lash_dir.x * rx * 0.16,
					lash_dir.y * ry * 0.17 - ry * 0.03).rotated(tilt)
				Shapes.fill(parent, Shapes.taper(lash_base, lash_tip, rx * 0.045, rx * 0.012),
					design.body_color.darkened(0.30), 0.0)

	# Cheek blush: two soft warm patches under the eyes. Kept faint -- it
	# reads as roundness, not make-up.
	for side in [-1.0, 1.0]:
		Shapes.fill(parent, Shapes.oval_points(
			centre + Vector2(side * rx * 0.58, ry * 0.44),
			Vector2(rx * 0.15, ry * 0.08), 12),
			Color(1.0, 0.60, 0.62, 0.34 if design.lashes else 0.26), 0.0)

	# A tiny mouth, low. Small mouth is part of the schema; the second pass's
	# wide guard read as a grille.
	Shapes.fill(parent, Shapes.rounded_rect(
		centre + Vector2(-rx * 0.10, ry * 0.60), Vector2(rx * 0.20, ry * 0.075),
		ry * 0.037),
		Color(0.82, 0.42, 0.48, 0.9) if design.lashes else design.body_color.darkened(0.18), 0.0)

	# The crest -- the silhouette. Scaled to the big head, swept back.
	#
	# An OLD code-drawn hat still replaces it: those four were designed to sit
	# flat on the skull, and a crown balanced on a dorsal fin read as an
	# accident. A PAINTED hat does not replace it, and must not. 迪迦's fin and
	# 赛罗's horns are the first thing a six-year-old uses to tell one hero
	# from another, and the brief says plainly that a costume may not hide the
	# main head silhouette. Side by side they look deliberate -- the fin comes
	# up through the crown of the rescue helmet as though it were made to.
	if str(outfit.get("hat", "")) != "":
		_build_hat(parent, centre, rx, ry)
		_build_face_piece(parent, centre, rx, ry)
		return
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
		"tiara":
			# The princess band: a gold arc riding the crown, three points
			# (tall centre, two shy sides) and an accent gem. Yullian wears
			# exactly this in the source material; at chibi scale the arc IS
			# the silhouette.
			var band := PackedVector2Array()
			for i3 in range(13):
				var ba: float = lerpf(PI * 1.14, PI * 1.86, float(i3) / 12.0)
				band.append(centre + Vector2(cos(ba) * rx * 1.03, sin(ba) * ry * 1.05))
			for i3 in range(13):
				var ba2: float = lerpf(PI * 1.86, PI * 1.14, float(i3) / 12.0)
				band.append(centre + Vector2(cos(ba2) * rx * 0.88, sin(ba2) * ry * 0.90))
			Shapes.fill(parent, band, design.trim_color, 0.8)
			for spec in [[-0.30, 1.26], [0.0, 1.52], [0.30, 1.26]]:
				var px: float = spec[0]
				var ph: float = spec[1]
				Shapes.lit(parent, PackedVector2Array([
					centre + Vector2(rx * (px - 0.10), -ry * 0.96),
					centre + Vector2(rx * px, -ry * ph),
					centre + Vector2(rx * (px + 0.10), -ry * 0.96),
				]), design.trim_color, 0.9)
			Shapes.fill(parent, Shapes.oval_points(centre + Vector2(0, -ry * 1.06),
				Vector2(rx * 0.10, ry * 0.12), 12), design.accent_color, 0.7)
			Shapes.fill(parent, Shapes.oval_points(centre + Vector2(-rx * 0.03, -ry * 1.10),
				Vector2(rx * 0.035, ry * 0.04), 8), Color(1, 1, 1, 0.85), 0.0)
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
		"ears":
			# Cat ears: a triangle each side with a softer inner triangle. The
			# ears sit ON the skull rather than above it, so the head stays the
			# same height and no hat has to be re-fitted.
			for side in [-1.0, 1.0]:
				Shapes.lit(parent, PackedVector2Array([
					centre + Vector2(side * rx * 0.26, -ry * 0.84),
					centre + Vector2(side * rx * 0.54, -ry * 1.52),
					centre + Vector2(side * rx * 0.94, -ry * 0.72),
				]), design.accent_color, 1.0)
				Shapes.fill(parent, PackedVector2Array([
					centre + Vector2(side * rx * 0.44, -ry * 0.88),
					centre + Vector2(side * rx * 0.55, -ry * 1.22),
					centre + Vector2(side * rx * 0.72, -ry * 0.84),
				]), design.trim_color, 0.5)
		"star_crest":
			# One five-pointed star standing on the crown, on a short stalk so
			# it reads as worn rather than pasted on the forehead.
			Shapes.fill(parent, Shapes.rounded_rect(
				Vector2(centre.x - rx * 0.06, centre.y - ry * 1.26),
				Vector2(rx * 0.12, ry * 0.34), rx * 0.06),
				design.trim_color, 0.0)
			Shapes.lit(parent, Shapes.star_points(
				centre + Vector2(0.0, -ry * 1.46), rx * 0.44, 0.44, 5),
				design.accent_color, 1.0)
		"antenna":
			# Two bobbing antennae with a lit bead on each -- the friendly
			# robot read, and the only crest that uses the core colour.
			for side in [-1.0, 1.0]:
				Shapes.fill(parent, Shapes.ribbon(PackedVector2Array([
					centre + Vector2(side * rx * 0.22, -ry * 0.90),
					centre + Vector2(side * rx * 0.40, -ry * 1.20),
					centre + Vector2(side * rx * 0.34, -ry * 1.48),
				]), rx * 0.09), design.trim_color, 0.0)
				Shapes.lit(parent, Shapes.circle_points(
					centre + Vector2(side * rx * 0.34, -ry * 1.56), rx * 0.19, 16),
					design.core_color, 1.0)
		"ponytail":
			# Hair, not armour: a fringe across the brow and a tail swinging
			# off the side. The tail hangs BESIDE the head so a hat can still
			# sit flat on top.
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(-rx * 1.02, -ry * 0.30),
				centre + Vector2(-rx * 0.96, -ry * 0.92),
				centre + Vector2(-rx * 0.44, -ry * 1.16),
				centre + Vector2(rx * 0.44, -ry * 1.16),
				centre + Vector2(rx * 0.96, -ry * 0.92),
				centre + Vector2(rx * 1.02, -ry * 0.30),
				centre + Vector2(rx * 0.72, -ry * 0.52),
				centre + Vector2(rx * 0.30, -ry * 0.40),
				centre + Vector2(-rx * 0.30, -ry * 0.46),
				centre + Vector2(-rx * 0.72, -ry * 0.52),
			]), design.accent_color, 1.0)
			Shapes.lit(parent, Shapes.oval_points(
				centre + Vector2(rx * 1.16, -ry * 0.46),
				Vector2(rx * 0.30, ry * 0.62), 22), design.accent_color, 0.9)
			Shapes.fill(parent, Shapes.rounded_rect(
				Vector2(centre.x + rx * 0.86, centre.y - ry * 0.98),
				Vector2(rx * 0.26, ry * 0.20), rx * 0.08),
				design.trim_color, 0.0)
		"bun":
			# A round bun on top with a bright tie. Softest silhouette of the
			# set, and the one six-year-olds read as "the little one".
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(-rx * 1.00, -ry * 0.34),
				centre + Vector2(-rx * 0.92, -ry * 0.96),
				centre + Vector2(0.0, -ry * 1.20),
				centre + Vector2(rx * 0.92, -ry * 0.96),
				centre + Vector2(rx * 1.00, -ry * 0.34),
				centre + Vector2(rx * 0.62, -ry * 0.50),
				centre + Vector2(-rx * 0.62, -ry * 0.50),
			]), design.accent_color, 1.0)
			Shapes.lit(parent, Shapes.circle_points(
				centre + Vector2(0.0, -ry * 1.34), rx * 0.34, 20),
				design.accent_color, 1.0)
			Shapes.fill(parent, Shapes.rounded_rect(
				Vector2(centre.x - rx * 0.30, centre.y - ry * 1.16),
				Vector2(rx * 0.60, ry * 0.14), rx * 0.06),
				design.trim_color, 0.0)
		"unicorn":
			# One spiral horn. Deliberately the tallest crest in the set: it is
			# the silhouette a child picks out of a row of thumbnails.
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(-rx * 0.22, -ry * 0.92),
				centre + Vector2(0.0, -ry * 1.82),
				centre + Vector2(rx * 0.22, -ry * 0.92),
			]), design.trim_color, 1.0)
			for i4 in range(3):
				var ty: float = -ry * (1.02 + 0.22 * float(i4))
				var tw: float = rx * (0.18 - 0.042 * float(i4))
				Shapes.fill(parent, Shapes.rounded_rect(
					Vector2(centre.x - tw, centre.y + ty),
					Vector2(tw * 2.0, ry * 0.07), tw * 0.5),
					design.accent_color, 0.0)
	_build_face_piece(parent, centre, rx, ry)


# --- the wardrobe ---------------------------------------------------------
#
# Every piece is drawn in head-space fractions like the face itself, so it
# fits every build width and rides every pose for free.

func _build_hat(parent: Node2D, centre: Vector2, rx: float, ry: float) -> void:
	match str(outfit.get("hat", "")):
		"crown":
			var gold := Color(1.0, 0.82, 0.30)
			var band_y: float = -ry * 0.78
			Shapes.fill(parent, Shapes.rounded_rect(
				centre + Vector2(-rx * 0.52, band_y - ry * 0.10),
				Vector2(rx * 1.04, ry * 0.16), 5.0), gold, 0.8)
			for k in range(3):
				var px3: float = (-0.34 + 0.34 * float(k)) * rx
				var tall: float = ry * (0.42 if k == 1 else 0.30)
				Shapes.lit(parent, PackedVector2Array([
					centre + Vector2(px3 - rx * 0.14, band_y - ry * 0.08),
					centre + Vector2(px3, band_y - ry * 0.08 - tall),
					centre + Vector2(px3 + rx * 0.14, band_y - ry * 0.08),
				]), gold, 0.8)
			for k in range(3):
				Shapes.fill(parent, Shapes.circle_points(
					centre + Vector2((-0.34 + 0.34 * float(k)) * rx, band_y - ry * 0.02),
					rx * 0.05, 10),
					[Color(0.90, 0.32, 0.36), Color(0.36, 0.70, 0.92),
						Color(0.42, 0.80, 0.52)][k], 0.6)
		"party_hat":
			var lean := rx * 0.06
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(-rx * 0.34, -ry * 0.74),
				centre + Vector2(rx * 0.34, -ry * 0.82),
				centre + Vector2(lean, -ry * 1.52),
			]), Color(0.95, 0.58, 0.76), 0.9)
			Shapes.fill(parent, Shapes.rounded_rect(
				centre + Vector2(-rx * 0.22, -ry * 1.06),
				Vector2(rx * 0.40, ry * 0.09), 4.0), Color(1.0, 0.86, 0.42), 0.0)
			Shapes.fill(parent, Shapes.circle_points(
				centre + Vector2(lean, -ry * 1.56), rx * 0.10, 12), Color(1.0, 0.86, 0.42), 0.7)
		"cowboy_hat":
			# Wide brim, tall crown, a band -- read from across the room,
			# which is the whole job of a hat in this game.
			var leather := Color(0.72, 0.52, 0.30)
			Shapes.lit(parent, Shapes.oval_points(centre + Vector2(0, -ry * 0.74),
				Vector2(rx * 1.22, ry * 0.20), 22), leather, 1.0)
			var crown := PackedVector2Array()
			for k in range(13):
				var a17: float = PI + PI * float(k) / 12.0
				crown.append(centre + Vector2(cos(a17) * rx * 0.60,
					-ry * 0.78 + sin(a17) * ry * 0.52))
			crown.append(centre + Vector2(rx * 0.60, -ry * 0.72))
			crown.append(centre + Vector2(-rx * 0.60, -ry * 0.72))
			Shapes.lit(parent, crown, leather.lightened(0.06), 1.0)
			Shapes.fill(parent, Shapes.rounded_rect(
				centre + Vector2(-rx * 0.62, -ry * 0.90), Vector2(rx * 1.24, ry * 0.14),
				4.0), Color(0.42, 0.30, 0.22), 0.0)
			Shapes.fill(parent, Shapes.star_points(centre + Vector2(0, -ry * 0.84),
				rx * 0.11, 0.45, 5), Color(1.0, 0.86, 0.36), 0.0)
		"cap":
			var blue3 := Color(0.34, 0.58, 0.86)
			var dome := PackedVector2Array()
			for k in range(15):
				var a11: float = PI + PI * float(k) / 14.0
				dome.append(centre + Vector2(cos(a11) * rx * 0.72, -ry * 0.70 + sin(a11) * ry * 0.42))
			dome.append(centre + Vector2(rx * 0.72, -ry * 0.62))
			dome.append(centre + Vector2(-rx * 0.72, -ry * 0.62))
			Shapes.lit(parent, dome, blue3, 1.0)
			Shapes.fill(parent, Shapes.oval_points(
				centre + Vector2(0, -ry * 0.60), Vector2(rx * 0.80, ry * 0.11), 18),
				blue3.darkened(0.12), 0.8)
			Shapes.fill(parent, Shapes.circle_points(
				centre + Vector2(0, -ry * 1.10), rx * 0.07, 10), blue3.darkened(0.20), 0.0)


## The body slot: dresses, vests, robes -- the pieces that change the
## SILHOUETTE below the neck, which is what "a whole outfit" means to a
## child who has just discovered dressing up.
func _build_suit(parent: Node2D) -> void:
	match str(outfit.get("suit", "")):
		"dress":
			# A flared skirt from the belt down, with a bright hem and two
			# soft folds. Falls over the legs, so the legs keep moving under
			# it in every pose without a line of extra code.
			var cloth := Color(0.98, 0.72, 0.84)
			Shapes.lit(parent, PackedVector2Array([
				Vector2(_u(-29.0), _u(-58.0)), Vector2(_u(29.0), _u(-58.0)),
				Vector2(_u(46.0), _u(-6.0)), Vector2(_u(24.0), _u(-2.0)),
				Vector2(0.0, _u(-8.0)), Vector2(_u(-24.0), _u(-2.0)),
				Vector2(_u(-46.0), _u(-6.0)),
			]), cloth, 1.0)
			for fold in [-14.0, 14.0]:
				Shapes.fill(parent, Shapes.taper(Vector2(_u(fold * 0.6), _u(-54.0)),
					Vector2(_u(fold), _u(-10.0)), _u(3.0), _u(1.6)),
					cloth.darkened(0.12), 0.0)
			Shapes.fill(parent, Shapes.rounded_rect(Vector2(_u(-30.0), _u(-62.0)),
				Vector2(_u(60.0), _u(7.0)), 3.0), Color(1.0, 0.92, 0.55), 0.7)
		"vest":
			# Two denim panels open down the middle, a collar, and stitching.
			var denim := Color(0.36, 0.50, 0.72)
			for side in [-1.0, 1.0]:
				Shapes.lit(parent, PackedVector2Array([
					Vector2(side * _u(31.0), _u(-114.0)),
					Vector2(side * _u(10.0), _u(-108.0)),
					Vector2(side * _u(9.0), _u(-62.0)),
					Vector2(side * _u(30.0), _u(-58.0)),
				]), denim, 1.0)
				Shapes.fill(parent, Shapes.taper(
					Vector2(side * _u(26.0), _u(-108.0)),
					Vector2(side * _u(25.0), _u(-64.0)), _u(1.8), _u(1.8)),
					Color(0.94, 0.82, 0.42), 0.0)
				Shapes.fill(parent, Shapes.circle_points(
					Vector2(side * _u(15.0), _u(-92.0)), _u(3.2), 8),
					Color(0.90, 0.86, 0.72), 0.0)
			Shapes.lit(parent, PackedVector2Array([
				Vector2(_u(-30.0), _u(-118.0)), Vector2(_u(30.0), _u(-118.0)),
				Vector2(_u(20.0), _u(-104.0)), Vector2(_u(-20.0), _u(-104.0)),
			]), denim.lightened(0.10), 0.9)
		"star_robe":
			# A long night-blue robe with stars on it -- the wizard silhouette
			# every child recognises, in this island's colours.
			var night := Color(0.26, 0.30, 0.56)
			Shapes.lit(parent, PackedVector2Array([
				Vector2(_u(-30.0), _u(-112.0)), Vector2(_u(30.0), _u(-112.0)),
				Vector2(_u(40.0), _u(-40.0)), Vector2(_u(48.0), _u(-2.0)),
				Vector2(0.0, _u(-10.0)), Vector2(_u(-48.0), _u(-2.0)),
				Vector2(_u(-40.0), _u(-40.0)),
			]), night, 1.0)
			var rng := Shapes.rng_for("robe")
			for k in range(6):
				var sx: float = rng.randf_range(-34.0, 34.0)
				var sy: float = rng.randf_range(-96.0, -20.0)
				Shapes.fill(parent, Shapes.star_points(Vector2(_u(sx), _u(sy)),
					_u(rng.randf_range(3.4, 5.4)), 0.44, 5),
					Color(1.0, 0.92, 0.60, 0.95), 0.0)
			Shapes.fill(parent, Shapes.rounded_rect(Vector2(_u(-31.0), _u(-116.0)),
				Vector2(_u(62.0), _u(8.0)), 3.5), Color(1.0, 0.86, 0.42), 0.7)


func _build_face_piece(parent: Node2D, centre: Vector2, rx: float, ry: float) -> void:
	match str(outfit.get("face", "")):
		"bandana":
			# Tied over the muzzle, knot to one side: half of the cowboy set
			# and, at chibi scale, an instantly readable silhouette change.
			var cloth2 := Color(0.86, 0.32, 0.34)
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(-rx * 0.74, ry * 0.30),
				centre + Vector2(rx * 0.74, ry * 0.30),
				centre + Vector2(rx * 0.52, ry * 0.86),
				centre + Vector2(0.0, ry * 1.00),
				centre + Vector2(-rx * 0.52, ry * 0.86),
			]), cloth2, 1.0)
			for k in range(4):
				Shapes.fill(parent, Shapes.circle_points(
					centre + Vector2(-rx * 0.36 + rx * 0.24 * float(k), ry * 0.56),
					rx * 0.05, 8), Color(1, 1, 1, 0.75), 0.0)
			Shapes.lit(parent, PackedVector2Array([
				centre + Vector2(rx * 0.70, ry * 0.24),
				centre + Vector2(rx * 0.96, ry * 0.14),
				centre + Vector2(rx * 0.90, ry * 0.44),
			]), cloth2.darkened(0.10), 0.8)
		"sunglasses":
			var dark := Color(0.16, 0.18, 0.24, 0.94)
			for side in [-1.0, 1.0]:
				var lens_at := centre + Vector2(side * rx * 0.42, ry * 0.12)
				Shapes.fill(parent, Shapes.rounded_rect(
					lens_at - Vector2(rx * 0.30, ry * 0.22),
					Vector2(rx * 0.60, ry * 0.42), rx * 0.14), dark, 0.7)
				Shapes.fill(parent, Shapes.oval_points(
					lens_at + Vector2(-side * rx * 0.08, -ry * 0.08),
					Vector2(rx * 0.10, ry * 0.05), 10), Color(1, 1, 1, 0.30), 0.0)
			Shapes.fill(parent, Shapes.rounded_rect(
				centre + Vector2(-rx * 0.14, ry * 0.02), Vector2(rx * 0.28, ry * 0.08),
				rx * 0.03), dark, 0.0)


func _build_back_piece(parent: Node2D) -> void:
	# (bandana lives in the face slot; see _build_face_piece)
	match str(outfit.get("back", "")):
		"cape_red":
			var red4 := Color(0.86, 0.28, 0.30)
			# Collar at the shoulders, hem swinging past the hips -- one wavy
			# polygon, because a cape is a silhouette, not a garment pattern.
			Shapes.lit(parent, PackedVector2Array([
				Vector2(_u(-26.0), SHOULDER_Y + _u(2.0)),
				Vector2(_u(26.0), SHOULDER_Y + _u(2.0)),
				Vector2(_u(40.0), _u(-30.0)),
				Vector2(_u(24.0), _u(-36.0)),
				Vector2(_u(6.0), _u(-26.0)),
				Vector2(_u(-18.0), _u(-38.0)),
				Vector2(_u(-38.0), _u(-26.0)),
			]), red4, 1.0)
			Shapes.fill(parent, Shapes.rounded_rect(
				Vector2(_u(-27.0), SHOULDER_Y - _u(2.0)), Vector2(_u(54.0), _u(7.0)), 3.5),
				design.trim_color, 0.7)
		"wings":
			for side in [-1.0, 1.0]:
				var wing := Node2D.new()
				wing.position = Vector2(side * _u(16.0), SHOULDER_Y + _u(6.0))
				parent.add_child(wing)
				Shapes.lit(wing, PackedVector2Array([
					Vector2(0, 0),
					Vector2(side * _u(34.0), _u(-30.0)),
					Vector2(side * _u(28.0), _u(-6.0)),
					Vector2(side * _u(16.0), _u(6.0)),
				]), Color(0.97, 0.97, 1.0), 0.9)
				Shapes.fill(wing, Shapes.circle_points(
					Vector2(side * _u(22.0), _u(-12.0)), _u(4.5), 8), Color(1.0, 0.90, 0.55), 0.0)
				if Juice.motion_enabled():
					var t := wing.create_tween().set_loops()
					t.tween_property(wing, "rotation_degrees", side * 9.0, 0.7)\
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					t.tween_property(wing, "rotation_degrees", side * -4.0, 0.7)\
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
