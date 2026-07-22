class_name IconLibrary
extends RefCounted
## Simple vector icons drawn from primitives.
##
## Why this exists: three sorting levels (Spot the Danger, Tidy Up the Room,
## Choose Rescue Tools) rendered their items as *words*. A six-year-old who
## cannot read cannot play them -- they were a reading test wearing a sorting
## costume. These icons make the picture carry the meaning, with the word kept
## underneath as a caption, which is how early-reading material is normally
## built: the child plays from the image and absorbs the word alongside it.
##
## Deliberately primitives rather than art files, so the levels become playable
## tonight with nothing to download. Swapping in real artwork later means
## pointing `icon` at a texture; nothing else changes.

const OUTLINE := Color(0.10, 0.14, 0.20, 0.55)


## Returns a Control drawing `name`, or null if there is no icon for it.
## Callers fall back to their text label when null comes back.
static func build(icon_name: String, size: float = 96.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var drawn: bool = _draw(icon_name, holder, size)
	if not drawn:
		holder.queue_free()
		return null
	return holder


static func has(icon_name: String) -> bool:
	return icon_name in [
		"teddy", "ball", "blocks", "picture_book", "comic", "socks", "tshirt",
		"hat", "knife", "matches", "scissors", "medicine", "socket", "crayon",
		"pillow", "bandage", "plaster", "berries", "fish", "carrot", "blanket",
		"scarf",
		# abstract, used on bins rather than items
		"check", "warning",
	]


# --- primitive helpers --------------------------------------------------

static func _circle(parent: Control, centre: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		points.append(centre + Vector2(cos(a), sin(a)) * radius)
	_poly(parent, points, color)


static func _rect(parent: Control, at: Vector2, box: Vector2, color: Color,
		rotation: float = 0.0) -> void:
	var half := box / 2.0
	var corners := [
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for corner in corners:
		points.append(at + (corner as Vector2).rotated(rotation))
	_poly(parent, points, color)


static func _poly(parent: Control, points: PackedVector2Array, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)

	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 2.5
	outline.default_color = OUTLINE
	parent.add_child(outline)


static func _tri(parent: Control, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_poly(parent, PackedVector2Array([a, b, c]), color)


# --- the icons ----------------------------------------------------------

static func _draw(icon_name: String, p: Control, s: float) -> bool:
	# All coordinates are fractions of `s`, so every icon scales cleanly.
	var c := Vector2(s, s) / 2.0

	match icon_name:
		"teddy":
			var brown := Color(0.62, 0.44, 0.28)
			_circle(p, c + Vector2(-s * 0.20, -s * 0.24), s * 0.10, brown)
			_circle(p, c + Vector2(s * 0.20, -s * 0.24), s * 0.10, brown)
			_circle(p, c + Vector2(0, -s * 0.12), s * 0.22, brown)
			_circle(p, c + Vector2(0, s * 0.22), s * 0.26, brown)
			_circle(p, c + Vector2(-s * 0.07, -s * 0.16), s * 0.03, Color(0.15, 0.1, 0.08))
			_circle(p, c + Vector2(s * 0.07, -s * 0.16), s * 0.03, Color(0.15, 0.1, 0.08))
		"ball":
			_circle(p, c, s * 0.34, Color(0.88, 0.32, 0.30))
			_rect(p, c, Vector2(s * 0.68, s * 0.12), Color(0.98, 0.96, 0.92))
		"blocks":
			_rect(p, c + Vector2(-s * 0.16, s * 0.14), Vector2(s * 0.28, s * 0.28), Color(0.24, 0.52, 0.80))
			_rect(p, c + Vector2(s * 0.16, s * 0.14), Vector2(s * 0.28, s * 0.28), Color(0.92, 0.72, 0.24))
			_rect(p, c + Vector2(0, -s * 0.16), Vector2(s * 0.28, s * 0.28), Color(0.84, 0.36, 0.34))
		"picture_book", "comic":
			var cover := Color(0.30, 0.58, 0.42) if icon_name == "picture_book" else Color(0.72, 0.40, 0.66)
			_rect(p, c, Vector2(s * 0.62, s * 0.48), cover)
			_rect(p, c, Vector2(s * 0.05, s * 0.48), Color(0.98, 0.97, 0.94))
			_rect(p, c + Vector2(-s * 0.17, s * 0.10), Vector2(s * 0.20, s * 0.04), Color(1, 1, 1, 0.8))
			_rect(p, c + Vector2(s * 0.17, s * 0.10), Vector2(s * 0.20, s * 0.04), Color(1, 1, 1, 0.8))
		"socks":
			for dx in [-s * 0.16, s * 0.16]:
				var top := c + Vector2(dx, -s * 0.10)
				_rect(p, top, Vector2(s * 0.16, s * 0.34), Color(0.94, 0.62, 0.32))
				_rect(p, top + Vector2(s * 0.06, s * 0.22), Vector2(s * 0.28, s * 0.14), Color(0.94, 0.62, 0.32))
		"tshirt":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.34, -s * 0.18), c + Vector2(-s * 0.16, -s * 0.28),
				c + Vector2(s * 0.16, -s * 0.28), c + Vector2(s * 0.34, -s * 0.18),
				c + Vector2(s * 0.22, -s * 0.02), c + Vector2(s * 0.22, s * 0.28),
				c + Vector2(-s * 0.22, s * 0.28), c + Vector2(-s * 0.22, -s * 0.02),
			]), Color(0.32, 0.60, 0.84))
		"hat":
			_rect(p, c + Vector2(0, s * 0.14), Vector2(s * 0.72, s * 0.10), Color(0.86, 0.42, 0.32))
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.24, s * 0.09), c + Vector2(-s * 0.16, -s * 0.24),
				c + Vector2(s * 0.16, -s * 0.24), c + Vector2(s * 0.24, s * 0.09),
			]), Color(0.92, 0.52, 0.38))
		"knife":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.30, -s * 0.06), c + Vector2(s * 0.06, -s * 0.26),
				c + Vector2(s * 0.10, -s * 0.02), c + Vector2(-s * 0.30, s * 0.02),
			]), Color(0.78, 0.80, 0.84))
			_rect(p, c + Vector2(s * 0.22, s * 0.02), Vector2(s * 0.30, s * 0.10), Color(0.36, 0.26, 0.20))
		"matches":
			_rect(p, c + Vector2(0, s * 0.10), Vector2(s * 0.08, s * 0.44), Color(0.84, 0.70, 0.48))
			_circle(p, c + Vector2(0, -s * 0.18), s * 0.09, Color(0.84, 0.28, 0.22))
			_tri(p, c + Vector2(0, -s * 0.40), c + Vector2(s * 0.10, -s * 0.20),
				c + Vector2(-s * 0.10, -s * 0.20), Color(0.96, 0.66, 0.20))
		"scissors":
			_circle(p, c + Vector2(-s * 0.16, s * 0.24), s * 0.10, Color(0.30, 0.50, 0.78))
			_circle(p, c + Vector2(s * 0.16, s * 0.24), s * 0.10, Color(0.30, 0.50, 0.78))
			_rect(p, c + Vector2(-s * 0.06, -s * 0.06), Vector2(s * 0.07, s * 0.46), Color(0.80, 0.82, 0.86), 0.35)
			_rect(p, c + Vector2(s * 0.06, -s * 0.06), Vector2(s * 0.07, s * 0.46), Color(0.80, 0.82, 0.86), -0.35)
		"medicine":
			_rect(p, c + Vector2(0, s * 0.08), Vector2(s * 0.40, s * 0.44), Color(0.86, 0.36, 0.34))
			_rect(p, c + Vector2(0, -s * 0.24), Vector2(s * 0.22, s * 0.12), Color(0.72, 0.74, 0.78))
			_rect(p, c + Vector2(0, s * 0.08), Vector2(s * 0.22, s * 0.07), Color(1, 1, 1, 0.95))
			_rect(p, c + Vector2(0, s * 0.08), Vector2(s * 0.07, s * 0.22), Color(1, 1, 1, 0.95))
		"socket":
			_rect(p, c, Vector2(s * 0.56, s * 0.56), Color(0.94, 0.93, 0.90))
			_circle(p, c + Vector2(-s * 0.11, -s * 0.04), s * 0.055, Color(0.20, 0.22, 0.26))
			_circle(p, c + Vector2(s * 0.11, -s * 0.04), s * 0.055, Color(0.20, 0.22, 0.26))
			_rect(p, c + Vector2(0, s * 0.16), Vector2(s * 0.20, s * 0.05), Color(0.20, 0.22, 0.26))
		"crayon":
			_rect(p, c + Vector2(0, s * 0.06), Vector2(s * 0.20, s * 0.44), Color(0.36, 0.62, 0.86))
			_tri(p, c + Vector2(0, -s * 0.34), c + Vector2(s * 0.10, -s * 0.16),
				c + Vector2(-s * 0.10, -s * 0.16), Color(0.22, 0.42, 0.66))
			_rect(p, c + Vector2(0, s * 0.10), Vector2(s * 0.22, s * 0.08), Color(1, 1, 1, 0.55))
		"pillow":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.36, -s * 0.20), c + Vector2(s * 0.36, -s * 0.22),
				c + Vector2(s * 0.34, s * 0.22), c + Vector2(-s * 0.34, s * 0.20),
			]), Color(0.96, 0.95, 0.92))
			_circle(p, c, s * 0.05, Color(0.88, 0.86, 0.82))
		"bandage", "plaster":
			var tone := Color(0.94, 0.80, 0.62) if icon_name == "plaster" else Color(0.98, 0.97, 0.94)
			_rect(p, c, Vector2(s * 0.66, s * 0.22), tone, -0.5)
			_rect(p, c, Vector2(s * 0.22, s * 0.22), tone.darkened(0.12), -0.5)
		"berries":
			_circle(p, c + Vector2(-s * 0.12, s * 0.08), s * 0.13, Color(0.62, 0.20, 0.42))
			_circle(p, c + Vector2(s * 0.12, s * 0.08), s * 0.13, Color(0.70, 0.24, 0.46))
			_circle(p, c + Vector2(0, -s * 0.10), s * 0.13, Color(0.56, 0.18, 0.38))
			_tri(p, c + Vector2(0, -s * 0.22), c + Vector2(s * 0.20, -s * 0.34),
				c + Vector2(s * 0.02, -s * 0.36), Color(0.34, 0.60, 0.34))
		"fish":
			_circle(p, c + Vector2(-s * 0.04, 0), s * 0.24, Color(0.34, 0.66, 0.86))
			_tri(p, c + Vector2(s * 0.16, 0), c + Vector2(s * 0.38, -s * 0.16),
				c + Vector2(s * 0.38, s * 0.16), Color(0.26, 0.54, 0.76))
			_circle(p, c + Vector2(-s * 0.14, -s * 0.05), s * 0.035, Color(0.10, 0.14, 0.20))
		"carrot":
			_tri(p, c + Vector2(0, s * 0.36), c + Vector2(s * 0.16, -s * 0.16),
				c + Vector2(-s * 0.16, -s * 0.16), Color(0.92, 0.54, 0.20))
			_tri(p, c + Vector2(0, -s * 0.34), c + Vector2(s * 0.14, -s * 0.12),
				c + Vector2(-s * 0.14, -s * 0.12), Color(0.34, 0.62, 0.34))
		"blanket":
			_rect(p, c, Vector2(s * 0.64, s * 0.44), Color(0.52, 0.42, 0.72))
			_rect(p, c + Vector2(0, -s * 0.12), Vector2(s * 0.64, s * 0.08), Color(0.66, 0.56, 0.84))
			_rect(p, c + Vector2(0, s * 0.06), Vector2(s * 0.64, s * 0.08), Color(0.66, 0.56, 0.84))
		"scarf":
			_rect(p, c + Vector2(0, -s * 0.10), Vector2(s * 0.58, s * 0.16), Color(0.84, 0.34, 0.40), 0.25)
			_rect(p, c + Vector2(s * 0.10, s * 0.18), Vector2(s * 0.16, s * 0.32), Color(0.84, 0.34, 0.40))
			for i in range(3):
				var x: float = s * (0.05 + 0.05 * float(i))
				_rect(p, c + Vector2(x, s * 0.34), Vector2(s * 0.03, s * 0.10), Color(0.72, 0.26, 0.32))
		"check":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.30, -s * 0.02), c + Vector2(-s * 0.14, -s * 0.18),
				c + Vector2(-s * 0.04, s * 0.04), c + Vector2(s * 0.26, -s * 0.28),
				c + Vector2(s * 0.36, -s * 0.12), c + Vector2(-s * 0.04, s * 0.30),
			]), Color(0.98, 0.99, 0.98))
		"warning":
			_tri(p, c + Vector2(0, -s * 0.32), c + Vector2(s * 0.36, s * 0.26),
				c + Vector2(-s * 0.36, s * 0.26), Color(0.99, 0.86, 0.30))
			_rect(p, c + Vector2(0, -s * 0.02), Vector2(s * 0.08, s * 0.24), Color(0.22, 0.18, 0.10))
			_circle(p, c + Vector2(0, s * 0.17), s * 0.05, Color(0.22, 0.18, 0.10))
		_:
			return false
	return true
