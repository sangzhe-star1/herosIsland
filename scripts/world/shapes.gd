class_name Shapes
extends RefCounted
## The drawing language. Every drawn thing in the game is built from these.
##
## Why this file exists: cohesion in a game world does not come from the
## individual pictures being good. It comes from every picture being made the
## same way -- the same corner softness, the same outline weight, the same
## place the light comes from, the same way a shadow lands. When each screen
## drew its own rectangles with its own conventions, the result read as a
## collage even where every single piece was competently drawn.
##
## So there is exactly one way to make a rounded shape, one outline colour, one
## shadow, one glow, and one light direction, and they live here. A new prop
## drawn six months from now will still belong to the world, because it cannot
## be drawn any other way.

## Where the light comes from, everywhere, always. Highlights go on the side a
## shape faces this direction; shading goes opposite. Getting this wrong is the
## single most obvious tell that a picture was pasted in from elsewhere.
const LIGHT_DIR := Vector2(-0.45, -0.89)

## The one outline colour. Never black -- a soft dark ink keeps drawings warm
## and stops small shapes from turning into holes at tablet size.
const INK := Color(0.12, 0.15, 0.22, 0.62)

## Outline weight as a fraction of a shape's size, so a 24px berry and a 400px
## building are drawn with visually equivalent lines.
const INK_RATIO := 0.028
const INK_MIN := 1.5
const INK_MAX := 5.0

## How far a highlight lightens and a shade darkens. Small, consistent numbers
## read as one material under one sun.
const HILIGHT := 0.16
const SHADE := 0.14


# --- geometry -----------------------------------------------------------

## A circle as a polygon. `segments` scales with radius so small shapes stay
## cheap and large ones stay smooth.
static func circle_points(centre: Vector2, radius: float, segments: int = 0) -> PackedVector2Array:
	return oval_points(centre, Vector2(radius, radius), segments)


static func oval_points(centre: Vector2, radii: Vector2, segments: int = 0) -> PackedVector2Array:
	var n: int = segments if segments > 0 else clampi(int(maxf(radii.x, radii.y) * 0.55), 10, 40)
	var pts := PackedVector2Array()
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


## A rectangle with rounded corners. The default radius is generous on purpose:
## nothing in a game for a six-year-old should have a sharp corner.
static func rounded_rect(at: Vector2, box: Vector2, radius: float = -1.0,
		steps: int = 5) -> PackedVector2Array:
	var r: float = radius if radius >= 0.0 else minf(box.x, box.y) * 0.22
	r = minf(r, minf(box.x, box.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		{"c": at + Vector2(box.x - r, box.y - r), "a": 0.0},
		{"c": at + Vector2(r, box.y - r), "a": PI * 0.5},
		{"c": at + Vector2(r, r), "a": PI},
		{"c": at + Vector2(box.x - r, r), "a": PI * 1.5},
	]
	for corner in corners:
		var centre: Vector2 = corner["c"]
		var start: float = corner["a"]
		for i in range(steps + 1):
			var a: float = start + PI * 0.5 * float(i) / float(steps)
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


## A soft organic lump -- the base shape for clouds, bushes, rocks, animals.
## `wobble` is how far the radius wanders; `lobes` how many bumps it grows.
## Given the same rng it produces the same blob, which is what makes a
## procedurally generated world stay put between one run and the next.
static func blob(centre: Vector2, radii: Vector2, rng: RandomNumberGenerator,
		wobble: float = 0.16, lobes: int = 3, segments: int = 26) -> PackedVector2Array:
	var phase: float = rng.randf() * TAU
	var phase2: float = rng.randf() * TAU
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		var w: float = 1.0 \
			+ sin(a * float(lobes) + phase) * wobble \
			+ sin(a * float(lobes * 2 + 1) + phase2) * wobble * 0.4
		pts.append(centre + Vector2(cos(a) * radii.x * w, sin(a) * radii.y * w))
	return pts


## A tapered stroke: a line with width, used for branches, limbs, trails and
## cables. Returns a closed polygon so it fills and outlines like everything
## else rather than being a special case.
static func taper(from: Vector2, to: Vector2, width_from: float,
		width_to: float) -> PackedVector2Array:
	var dir: Vector2 = (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	return PackedVector2Array([
		from + side * width_from * 0.5,
		to + side * width_to * 0.5,
		to - side * width_to * 0.5,
		from - side * width_from * 0.5,
	])


## A smooth curve through control points, as a filled ribbon of given width.
## Used for paths on the island map and for trails between rescue steps.
static func ribbon(points: PackedVector2Array, width: float,
		smoothing: int = 8) -> PackedVector2Array:
	var curve := smooth(points, smoothing)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(curve.size()):
		var prev: Vector2 = curve[maxi(i - 1, 0)]
		var next: Vector2 = curve[mini(i + 1, curve.size() - 1)]
		var dir: Vector2 = (next - prev)
		if dir.length() < 0.001:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		left.append(curve[i] + side)
		right.append(curve[i] - side)
	var out := PackedVector2Array(left)
	for i in range(right.size() - 1, -1, -1):
		out.append(right[i])
	return out


## Catmull-Rom through the given points. Hand-placed nodes become a flowing
## line rather than a dot-to-dot, which is most of the difference between a
## drawn map and a diagram.
static func smooth(points: PackedVector2Array, steps: int = 8) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var out := PackedVector2Array()
	for i in range(points.size() - 1):
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for s in range(steps):
			var t: float = float(s) / float(steps)
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(points[points.size() - 1])
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
	)


# --- nodes --------------------------------------------------------------

## The workhorse. A filled shape with the house outline, added to `parent`.
## Returns the Polygon2D so callers can animate its colour.
##
## `outline` of 0 means none (used for anything soft-edged: clouds, glows,
## distant silhouettes -- an outline at distance is what makes a background
## look like a sticker).
static func fill(parent: Node, points: PackedVector2Array, color: Color,
		outline: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.antialiased = true
	parent.add_child(poly)
	if outline > 0.0:
		var size: float = _extent(points)
		var line := Line2D.new()
		line.points = points
		line.closed = true
		line.width = clampf(size * 0.018, 1.2, 2.4) * outline
		line.default_color = color.darkened(0.14)
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		parent.add_child(line)
	return poly


## Volumetric fill: base colour plus a warm sunlit crest and a soft underside
## shade. This stops shapes from reading as flat paper cutouts or stickers,
## giving them subtle 3D toy / clay volume under the island's sunlight.
static func lit(parent: Node, points: PackedVector2Array, color: Color,
		outline: float = 1.0) -> Polygon2D:
	var base: Polygon2D = fill(parent, points, color, outline)
	var centre: Vector2 = _centroid(points)
	var size: float = _extent(points)

	# 1. Underside form shade (ambient occlusion away from the sun)
	var shade_shift: Vector2 = -LIGHT_DIR * size * 0.06
	var shade_pts := PackedVector2Array()
	for p in points:
		shade_pts.append(centre + (p - centre) * 0.82 + shade_shift)
	var shade := Polygon2D.new()
	shade.polygon = shade_pts
	shade.color = color.darkened(SHADE * 0.85)
	shade.antialiased = true
	parent.add_child(shade)

	# 2. Sunlit top-facing highlight (diffuse light facing the sun)
	var shift: Vector2 = LIGHT_DIR * size * 0.08
	var highlight := PackedVector2Array()
	for p in points:
		highlight.append(centre + (p - centre) * 0.72 + shift)
	var glare := Polygon2D.new()
	glare.polygon = highlight
	glare.color = color.lightened(HILIGHT * 1.25)
	glare.antialiased = true
	parent.add_child(glare)

	# Order layers: base -> shade -> glare -> outline
	if outline > 0.0 and parent.get_child_count() >= 4:
		parent.move_child(shade, parent.get_child_count() - 3)
		parent.move_child(glare, parent.get_child_count() - 2)
	return base


## A vertical gradient quad. The sky, water, and every ground plane are this.
## Godot interpolates vertex colours across the triangles for free, so a whole
## sky is one draw call and one node.
static func gradient_quad(parent: Node, at: Vector2, box: Vector2,
		top: Color, bottom: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		at, at + Vector2(box.x, 0), at + box, at + Vector2(0, box.y),
	])
	poly.vertex_colors = PackedColorArray([top, top, bottom, bottom])
	parent.add_child(poly)
	return poly


## Soft light without a shader, and without banding.
##
## An earlier version stacked translucent circles, which is the obvious way to
## do it and looks like tree rings on any screen with real gamma. A radial
## gradient texture is one node, one draw call, and genuinely smooth -- and the
## falloff curve is squared so the light has a bright core and a long tail,
## the way light actually behaves, instead of a linear ramp that reads as a
## flat disc with a fuzzy edge.
static func glow(parent: Node, centre: Vector2, radius: float, color: Color,
		_rings: int = 5, strength: float = 0.30) -> Node2D:
	var grad := Gradient.new()
	var stops := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(7):
		var t: float = float(i) / 6.0
		stops.append(t)
		var falloff: float = pow(1.0 - t, 2.4)
		cols.append(Color(color.r, color.g, color.b, strength * falloff))
	grad.offsets = stops
	grad.colors = cols

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 192
	tex.height = 192

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = centre
	sprite.scale = Vector2.ONE * (radius * 2.0 / 192.0)
	var holder := Node2D.new()
	parent.add_child(holder)
	holder.add_child(sprite)
	return holder


## The shadow an actor casts on the ground. Always an ellipse, always the same
## softness, always offset against the light -- which is what makes characters
## look like they are standing IN the scene rather than in front of it. The
## missing contact shadow is the number-one reason a cutout looks pasted on.
static func ground_shadow(parent: Node, at: Vector2, width: float,
		strength: float = 0.22) -> Node2D:
	var holder := Node2D.new()
	parent.add_child(holder)
	var offset: Vector2 = Vector2(-LIGHT_DIR.x, 0.0) * width * 0.10
	for i in range(3):
		var t: float = 1.0 - float(i) * 0.28
		var shadow := Polygon2D.new()
		shadow.polygon = oval_points(at + offset, Vector2(width * 0.5 * t, width * 0.15 * t), 22)
		shadow.color = Color(0.08, 0.10, 0.18, strength / 3.0)
		shadow.antialiased = true
		holder.add_child(shadow)
	return holder


## A star, used for rewards and for the sky. One definition, so the star on the
## result screen and the star in the map header are the same star.
static func star_points(centre: Vector2, outer: float, inner_ratio: float = 0.44,
		arms: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(arms * 2):
		var a: float = -PI * 0.5 + TAU * float(i) / float(arms * 2)
		var r: float = outer if i % 2 == 0 else outer * inner_ratio
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


# --- helpers ------------------------------------------------------------

static func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


static func _extent(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.0
	var lo: Vector2 = points[0]
	var hi: Vector2 = points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	return maxf(hi.x - lo.x, hi.y - lo.y)


## Deterministic rng from any string. Two runs of the same level draw the same
## world: a child who plays "Collect Energy Orbs" twice should recognise it,
## and a screenshot taken today should still match the game tomorrow.
static func rng_for(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng
