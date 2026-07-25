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


## Every icon is drawn through Shapes, which is what makes a 96px teddy on a
## sorting bin and a 400px tree in the background look like they were drawn by
## the same hand: same outline colour, same weight for their size, same light
## direction, same rounding.

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
	return icon_name in NAMES


const NAMES := [
	# sorting items
	"teddy", "ball", "blocks", "picture_book", "comic", "socks", "tshirt",
	"hat", "knife", "matches", "scissors", "medicine", "socket", "crayon",
	"pillow", "bandage", "plaster", "berries", "fish", "carrot", "blanket",
	"scarf",
	# abstract, used on bins rather than items
	"check", "warning",
	# navigation and status, so every screen can be read without words
	"flag", "house", "home", "gear", "star", "star_empty", "car", "spark",
	"sort", "paw", "monster", "lock", "coin", "heart", "shield", "lightning",
	"orb", "rock", "sound_on", "sound_off", "retry", "pause", "chest", "moon",
	# badge pictures: every award a child can earn has a face of its own
	"eye", "umbrella", "magnifier", "compass", "leaf", "music", "medal",
	"traffic_light",
	# wordless-instruction states and the star shop's goods
	"ear", "tap", "tower", "potion", "star_bomb", "balloon",
	# the wardrobe: outfit pieces for the Hero House rack
	"crown", "party_hat", "cap", "sunglasses", "cape_red", "wings",
	# the blaster range's map stone, and the goo you swat out of the air
	"target", "goo",
]


# --- primitive helpers --------------------------------------------------

static func _circle(parent: Control, centre: Vector2, radius: float, color: Color) -> void:
	Shapes.fill(parent, Shapes.circle_points(centre, radius), color, 1.0)


static func _lit_circle(parent: Control, centre: Vector2, radius: float, color: Color) -> void:
	Shapes.lit(parent, Shapes.circle_points(centre, radius), color, 1.0)


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


## Rounded box. Preferred over _rect for anything a child looks at directly --
## nothing in this game has a sharp corner unless it means to.
static func _round_rect(parent: Control, at: Vector2, box: Vector2, color: Color,
		radius: float = -1.0) -> void:
	Shapes.fill(parent, Shapes.rounded_rect(at - box / 2.0, box, radius), color, 1.0)


static func _poly(parent: Control, points: PackedVector2Array, color: Color) -> void:
	Shapes.fill(parent, points, color, 1.0)


static func _tri(parent: Control, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	Shapes.fill(parent, PackedVector2Array([a, b, c]), color, 1.0)


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
		"flag":
			_rect(p, c + Vector2(-s * 0.22, s * 0.02), Vector2(s * 0.06, s * 0.60), Color(0.52, 0.40, 0.28))
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.19, -s * 0.28), c + Vector2(s * 0.30, -s * 0.16),
				c + Vector2(-s * 0.19, -s * 0.04),
			]), Color(0.88, 0.34, 0.32))
		"house", "home":
			_tri(p, c + Vector2(0, -s * 0.34), c + Vector2(s * 0.38, -s * 0.02),
				c + Vector2(-s * 0.38, -s * 0.02), Color(0.84, 0.38, 0.32))
			_rect(p, c + Vector2(0, s * 0.16), Vector2(s * 0.56, s * 0.36), Color(0.96, 0.90, 0.78))
			_rect(p, c + Vector2(0, s * 0.22), Vector2(s * 0.16, s * 0.24), Color(0.52, 0.40, 0.28))
		"gear":
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				_rect(p, c + Vector2(cos(a), sin(a)) * s * 0.30,
					Vector2(s * 0.14, s * 0.14), Color(0.56, 0.60, 0.66), a)
			_circle(p, c, s * 0.24, Color(0.64, 0.68, 0.74))
			_circle(p, c, s * 0.10, Color(0.34, 0.38, 0.44))
		"star":
			Shapes.lit(p, Shapes.star_points(c, s * 0.40, 0.44, 5),
				Color(1.0, 0.80, 0.18), 1.0)
		"car":
			_rect(p, c + Vector2(0, s * 0.02), Vector2(s * 0.66, s * 0.22), Color(0.32, 0.58, 0.86))
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.22, -s * 0.09), c + Vector2(-s * 0.12, -s * 0.28),
				c + Vector2(s * 0.14, -s * 0.28), c + Vector2(s * 0.24, -s * 0.09),
			]), Color(0.44, 0.70, 0.94))
			_circle(p, c + Vector2(-s * 0.20, s * 0.18), s * 0.10, Color(0.20, 0.22, 0.26))
			_circle(p, c + Vector2(s * 0.20, s * 0.18), s * 0.10, Color(0.20, 0.22, 0.26))
		"spark":
			_circle(p, c, s * 0.20, Color(1.0, 0.86, 0.34))
			for i in range(6):
				var ang2: float = TAU * float(i) / 6.0
				_rect(p, c + Vector2(cos(ang2), sin(ang2)) * s * 0.32,
					Vector2(s * 0.08, s * 0.20), Color(1.0, 0.78, 0.24), ang2 + PI / 2.0)
		"sort":
			_rect(p, c + Vector2(-s * 0.18, -s * 0.16), Vector2(s * 0.26, s * 0.26), Color(0.34, 0.62, 0.88))
			_circle(p, c + Vector2(s * 0.18, s * 0.18), s * 0.15, Color(0.92, 0.60, 0.26))
			_tri(p, c + Vector2(s * 0.18, -s * 0.30), c + Vector2(s * 0.33, -s * 0.02),
				c + Vector2(s * 0.03, -s * 0.02), Color(0.44, 0.74, 0.48))
		"paw":
			_circle(p, c + Vector2(0, s * 0.14), s * 0.22, Color(0.62, 0.46, 0.34))
			for dx in [-0.22, -0.07, 0.07, 0.22]:
				_circle(p, c + Vector2(s * dx, -s * (0.16 if absf(dx) < 0.15 else 0.06)),
					s * 0.09, Color(0.62, 0.46, 0.34))
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
		"monster":
			var purple := Color(0.56, 0.40, 0.78)
			_circle(p, c + Vector2(0, s * 0.04), s * 0.32, purple)
			_tri(p, c + Vector2(-s * 0.20, -s * 0.20), c + Vector2(-s * 0.30, -s * 0.42),
				c + Vector2(-s * 0.08, -s * 0.26), purple.darkened(0.2))
			_tri(p, c + Vector2(s * 0.20, -s * 0.20), c + Vector2(s * 0.30, -s * 0.42),
				c + Vector2(s * 0.08, -s * 0.26), purple.darkened(0.2))
			for dx in [-1.0, 1.0]:
				_circle(p, c + Vector2(dx * s * 0.12, -s * 0.02), s * 0.10, Color(0.99, 0.99, 0.97))
				_circle(p, c + Vector2(dx * s * 0.12, 0), s * 0.045, Color(0.13, 0.12, 0.16))
			_rect(p, c + Vector2(0, s * 0.20), Vector2(s * 0.28, s * 0.05), Color(0.30, 0.16, 0.20))
			for dx in [-1.0, 1.0]:
				_tri(p, c + Vector2(dx * s * 0.10 - s * 0.03, s * 0.18),
					c + Vector2(dx * s * 0.10 + s * 0.03, s * 0.18),
					c + Vector2(dx * s * 0.10, s * 0.24), Color(0.99, 0.99, 0.95))
		"lock":
			_round_rect(p, c + Vector2(0, s * 0.14), Vector2(s * 0.56, s * 0.42),
				Color(0.98, 0.82, 0.32), s * 0.10)
			# The shackle, drawn as a ring with the bottom hidden behind the body.
			var shackle := PackedVector2Array()
			for i in range(13):
				var a: float = PI + PI * float(i) / 12.0
				shackle.append(c + Vector2(cos(a), sin(a)) * s * 0.19 + Vector2(0, -s * 0.08))
			for i in range(12, -1, -1):
				var a2: float = PI + PI * float(i) / 12.0
				shackle.append(c + Vector2(cos(a2), sin(a2)) * s * 0.11 + Vector2(0, -s * 0.08))
			_poly(p, shackle, Color(0.72, 0.75, 0.80))
			_circle(p, c + Vector2(0, s * 0.12), s * 0.06, Color(0.42, 0.34, 0.16))
		"coin":
			_lit_circle(p, c, s * 0.34, Color(1.0, 0.80, 0.24))
			_circle(p, c, s * 0.24, Color(1.0, 0.88, 0.42))
			_poly(p, Shapes.star_points(c, s * 0.16, 0.45, 5), Color(0.94, 0.68, 0.16))
		"heart":
			_poly(p, PackedVector2Array([
				c + Vector2(0, s * 0.34), c + Vector2(-s * 0.36, -s * 0.04),
				c + Vector2(-s * 0.30, -s * 0.24), c + Vector2(-s * 0.14, -s * 0.28),
				c + Vector2(0, -s * 0.14), c + Vector2(s * 0.14, -s * 0.28),
				c + Vector2(s * 0.30, -s * 0.24), c + Vector2(s * 0.36, -s * 0.04),
			]), Color(0.90, 0.34, 0.40))
		"shield":
			Shapes.lit(p, PackedVector2Array([
				c + Vector2(0, -s * 0.36), c + Vector2(s * 0.30, -s * 0.22),
				c + Vector2(s * 0.26, s * 0.12), c + Vector2(0, s * 0.38),
				c + Vector2(-s * 0.26, s * 0.12), c + Vector2(-s * 0.30, -s * 0.22),
			]), Color(0.34, 0.58, 0.86), 1.0)
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.16, -s * 0.02), c + Vector2(-s * 0.05, s * 0.10),
				c + Vector2(s * 0.17, -s * 0.16), c + Vector2(s * 0.21, -s * 0.05),
				c + Vector2(-s * 0.04, s * 0.22), c + Vector2(-s * 0.21, s * 0.03),
			]), Color(0.98, 0.99, 0.98))
		"lightning":
			_poly(p, PackedVector2Array([
				c + Vector2(s * 0.06, -s * 0.38), c + Vector2(-s * 0.22, s * 0.06),
				c + Vector2(-s * 0.02, s * 0.04), c + Vector2(-s * 0.08, s * 0.38),
				c + Vector2(s * 0.22, -s * 0.06), c + Vector2(s * 0.02, -s * 0.04),
			]), Color(1.0, 0.82, 0.24))
		"orb":
			Shapes.glow(p, c, s * 0.52, Color(0.55, 0.88, 1.0), 5, 0.5)
			_lit_circle(p, c, s * 0.28, Color(0.55, 0.86, 1.0))
			Shapes.fill(p, Shapes.oval_points(c + Vector2(-s * 0.09, -s * 0.10),
				Vector2(s * 0.08, s * 0.05), 12), Color(1, 1, 1, 0.8), 0.0)
		"rock":
			Shapes.lit(p, PackedVector2Array([
				c + Vector2(-s * 0.34, s * 0.16), c + Vector2(-s * 0.22, -s * 0.20),
				c + Vector2(s * 0.06, -s * 0.32), c + Vector2(s * 0.30, -s * 0.10),
				c + Vector2(s * 0.32, s * 0.16), c + Vector2(0, s * 0.28),
			]), Color(0.58, 0.58, 0.64), 1.0)
		"sound_on", "sound_off":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.30, -s * 0.10), c + Vector2(-s * 0.14, -s * 0.10),
				c + Vector2(s * 0.02, -s * 0.30), c + Vector2(s * 0.02, s * 0.30),
				c + Vector2(-s * 0.14, s * 0.10), c + Vector2(-s * 0.30, s * 0.10),
			]), Color(0.42, 0.46, 0.56))
			if icon_name == "sound_on":
				for i in range(2):
					var ring := PackedVector2Array()
					var rr: float = s * (0.16 + 0.11 * float(i))
					for k in range(9):
						var aa: float = -PI * 0.34 + PI * 0.68 * float(k) / 8.0
						ring.append(c + Vector2(s * 0.06, 0) + Vector2(cos(aa), sin(aa)) * rr)
					var line := Line2D.new()
					line.points = ring
					line.width = maxf(2.0, s * 0.045)
					line.default_color = Color(0.42, 0.46, 0.56)
					line.antialiased = true
					p.add_child(line)
			else:
				for sign in [-1.0, 1.0]:
					_rect(p, c + Vector2(s * 0.22, 0), Vector2(s * 0.26, s * 0.07),
						Color(0.86, 0.34, 0.32), sign * 0.78)
		"retry":
			var arc := PackedVector2Array()
			for i in range(17):
				var a3: float = -PI * 0.35 + TAU * 0.82 * float(i) / 16.0
				arc.append(c + Vector2(cos(a3), sin(a3)) * s * 0.28)
			var stroke := Line2D.new()
			stroke.points = arc
			stroke.width = maxf(3.0, s * 0.10)
			stroke.default_color = Color(0.34, 0.60, 0.86)
			stroke.joint_mode = Line2D.LINE_JOINT_ROUND
			stroke.antialiased = true
			p.add_child(stroke)
			_tri(p, c + Vector2(s * 0.34, -s * 0.28), c + Vector2(s * 0.10, -s * 0.24),
				c + Vector2(s * 0.28, -s * 0.02), Color(0.34, 0.60, 0.86))
		"pause":
			for dx in [-0.13, 0.13]:
				_round_rect(p, c + Vector2(s * dx, 0), Vector2(s * 0.13, s * 0.46),
					Color(0.42, 0.46, 0.56), s * 0.05)
		"chest":
			_round_rect(p, c + Vector2(0, s * 0.16), Vector2(s * 0.66, s * 0.32),
				Color(0.64, 0.44, 0.26), s * 0.06)
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.33, -s * 0.01), c + Vector2(-s * 0.26, -s * 0.24),
				c + Vector2(s * 0.26, -s * 0.24), c + Vector2(s * 0.33, -s * 0.01),
			]), Color(0.76, 0.52, 0.30))
			_round_rect(p, c + Vector2(0, s * 0.02), Vector2(s * 0.14, s * 0.18),
				Color(1.0, 0.82, 0.30), s * 0.04)
		"traffic_light":
			# Safety, as the one object every one of those levels is about. A
			# bare tick was used here before and it is drawn near-white, so on
			# a cream card it vanished -- the exact failure this screen was
			# being fixed for.
			_rect(p, c + Vector2(0, s * 0.34), Vector2(s * 0.07, s * 0.24),
				Color(0.42, 0.44, 0.52))
			_round_rect(p, c + Vector2(0, -s * 0.06), Vector2(s * 0.40, s * 0.62),
				Color(0.30, 0.32, 0.40), s * 0.10)
			for i in range(3):
				var lamp: Color = [Color(0.92, 0.32, 0.30), Color(1.0, 0.82, 0.28),
					Color(0.34, 0.76, 0.44)][i]
				Shapes.fill(p, Shapes.circle_points(
					c + Vector2(0, -s * 0.24 + float(i) * s * 0.18), s * 0.075, 12), lamp, 0.0)
		"eye":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.40, 0),
				c + Vector2(-s * 0.18, -s * 0.22), c + Vector2(0, -s * 0.26),
				c + Vector2(s * 0.18, -s * 0.22), c + Vector2(s * 0.40, 0),
				c + Vector2(s * 0.18, s * 0.22), c + Vector2(0, s * 0.26),
				c + Vector2(-s * 0.18, s * 0.22),
			]), Color(0.98, 0.98, 0.96))
			_circle(p, c, s * 0.17, Color(0.32, 0.60, 0.86))
			_circle(p, c, s * 0.08, Color(0.13, 0.13, 0.18))
			Shapes.fill(p, Shapes.circle_points(c + Vector2(-s * 0.06, -s * 0.06),
				s * 0.05, 10), Color(1, 1, 1, 0.9), 0.0)
		"umbrella":
			var dome := PackedVector2Array()
			for i in range(13):
				var au: float = PI + PI * float(i) / 12.0
				dome.append(c + Vector2(cos(au), sin(au)) * s * 0.40 + Vector2(0, s * 0.04))
			# A scalloped hem, which is what stops a half-circle reading as a hill.
			for i in range(4):
				var t: float = 1.0 - float(i) / 3.0
				dome.append(c + Vector2(lerpf(-s * 0.40, s * 0.40, t), s * 0.04)
					+ Vector2(0, sin(t * PI * 3.0) * s * 0.05))
			_poly(p, dome, Color(0.88, 0.36, 0.38))
			_rect(p, c + Vector2(0, s * 0.22), Vector2(s * 0.05, s * 0.38),
				Color(0.60, 0.46, 0.32))
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.14, s * 0.40), c + Vector2(-s * 0.12, s * 0.32),
				c + Vector2(-s * 0.02, s * 0.34), c + Vector2(-s * 0.02, s * 0.42),
			]), Color(0.60, 0.46, 0.32))
		"magnifier":
			_circle(p, c + Vector2(-s * 0.06, -s * 0.08), s * 0.24, Color(0.72, 0.90, 0.98))
			var rim := Line2D.new()
			rim.points = Shapes.circle_points(c + Vector2(-s * 0.06, -s * 0.08), s * 0.24, 22)
			rim.closed = true
			rim.width = maxf(3.0, s * 0.075)
			rim.default_color = Color(0.36, 0.40, 0.50)
			rim.antialiased = true
			p.add_child(rim)
			_rect(p, c + Vector2(s * 0.20, s * 0.20), Vector2(s * 0.10, s * 0.30),
				Color(0.52, 0.40, 0.28), -0.78)
			Shapes.fill(p, Shapes.oval_points(c + Vector2(-s * 0.14, -s * 0.16),
				Vector2(s * 0.08, s * 0.05), 12), Color(1, 1, 1, 0.85), 0.0)
		"compass":
			_lit_circle(p, c, s * 0.36, Color(0.94, 0.93, 0.90))
			_circle(p, c, s * 0.28, Color(0.34, 0.58, 0.82))
			_poly(p, PackedVector2Array([
				c + Vector2(0, -s * 0.24), c + Vector2(s * 0.10, 0), c + Vector2(0, s * 0.24),
				c + Vector2(-s * 0.10, 0),
			]), Color(0.98, 0.98, 0.96))
			_tri(p, c + Vector2(0, -s * 0.24), c + Vector2(s * 0.10, 0),
				c + Vector2(-s * 0.10, 0), Color(0.90, 0.32, 0.30))
			_circle(p, c, s * 0.05, Color(0.30, 0.30, 0.36))
		"leaf":
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.30, s * 0.30), c + Vector2(-s * 0.24, -s * 0.10),
				c + Vector2(0, -s * 0.34), c + Vector2(s * 0.28, -s * 0.20),
				c + Vector2(s * 0.20, s * 0.12), c + Vector2(-s * 0.06, s * 0.30),
			]), Color(0.36, 0.68, 0.38))
			var vein := Line2D.new()
			vein.points = PackedVector2Array([
				c + Vector2(-s * 0.26, s * 0.28), c + Vector2(-s * 0.04, s * 0.02),
				c + Vector2(s * 0.18, -s * 0.20),
			])
			vein.width = maxf(2.0, s * 0.05)
			vein.default_color = Color(0.24, 0.50, 0.28)
			vein.antialiased = true
			p.add_child(vein)
		"music":
			_circle(p, c + Vector2(-s * 0.16, s * 0.22), s * 0.13, Color(0.52, 0.42, 0.78))
			_circle(p, c + Vector2(s * 0.22, s * 0.12), s * 0.13, Color(0.52, 0.42, 0.78))
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.05, s * 0.24), c + Vector2(-s * 0.05, -s * 0.28),
				c + Vector2(s * 0.33, -s * 0.36), c + Vector2(s * 0.33, s * 0.14),
				c + Vector2(s * 0.24, s * 0.14), c + Vector2(s * 0.24, -s * 0.24),
				c + Vector2(s * 0.04, -s * 0.20), c + Vector2(s * 0.04, s * 0.24),
			]), Color(0.40, 0.32, 0.64))
		"medal":
			for side in [-1.0, 1.0]:
				_poly(p, PackedVector2Array([
					c + Vector2(side * s * 0.06, -s * 0.34),
					c + Vector2(side * s * 0.26, -s * 0.34),
					c + Vector2(side * s * 0.20, s * 0.02),
					c + Vector2(side * s * 0.02, s * 0.02),
				]), Color(0.86, 0.32, 0.32) if side < 0.0 else Color(0.34, 0.54, 0.84))
			_lit_circle(p, c + Vector2(0, s * 0.14), s * 0.26, Color(1.0, 0.80, 0.24))
			_poly(p, Shapes.star_points(c + Vector2(0, s * 0.14), s * 0.15, 0.44, 5),
				Color(1.0, 0.94, 0.62))
		"moon":
			# A crescent: the full disc with a second disc bitten out of it.
			# Drawn as one polygon so it outlines like everything else, rather
			# than as a light circle with a background-coloured circle on top,
			# which only works over one background.
			var crescent := PackedVector2Array()
			for i in range(20):
				var a4: float = -PI * 0.5 + PI * float(i) / 19.0
				crescent.append(c + Vector2(cos(a4), sin(a4)) * s * 0.36)
			for i in range(19, -1, -1):
				var a5: float = -PI * 0.5 + PI * float(i) / 19.0
				crescent.append(c + Vector2(-s * 0.14, 0)
					+ Vector2(cos(a5), sin(a5)) * s * 0.34)
			Shapes.lit(p, crescent, Color(0.99, 0.94, 0.68), 1.0)
			for star_at in [Vector2(0.24, -0.26), Vector2(0.32, 0.06), Vector2(0.14, 0.30)]:
				_poly(p, Shapes.star_points(c + (star_at as Vector2) * s, s * 0.07, 0.4, 4),
					Color(1.0, 0.88, 0.42))
		"star_empty":
			_poly(p, Shapes.star_points(c, s * 0.38, 0.44, 5), Color(0.86, 0.87, 0.90))
		"ear":
			# "Listen": an ear, warm and simple -- outer shell, inner curl, lobe.
			var shell := Color(0.98, 0.80, 0.62)
			_poly(p, Shapes.oval_points(c + Vector2(0, -s * 0.04), Vector2(s * 0.26, s * 0.34), 22), shell)
			_poly(p, Shapes.oval_points(c + Vector2(s * 0.02, -s * 0.10), Vector2(s * 0.15, s * 0.20), 18),
				shell.darkened(0.16))
			_poly(p, Shapes.oval_points(c + Vector2(s * 0.03, -s * 0.06), Vector2(s * 0.08, s * 0.12), 14), shell)
			_circle(p, c + Vector2(-s * 0.04, s * 0.26), s * 0.11, shell)
			# Three sound arcs arriving from the left.
			for k in range(3):
				var arc_r: float = s * (0.34 + 0.10 * float(k))
				var arc := PackedVector2Array()
				for j in range(7):
					var a6: float = PI * 0.72 + PI * 0.56 * float(j) / 6.0
					arc.append(c + Vector2(-s * 0.18, 0) + Vector2(cos(a6), sin(a6)) * arc_r)
				for j in range(6, -1, -1):
					var a7: float = PI * 0.72 + PI * 0.56 * float(j) / 6.0
					arc.append(c + Vector2(-s * 0.18, 0) + Vector2(cos(a7), sin(a7)) * (arc_r - s * 0.035))
				_poly(p, arc, Color(0.44, 0.72, 0.95, 0.9 - 0.18 * float(k)))
		"tap":
			# "Your turn": a finger mid-tap, ripples where it lands.
			var skin := Color(0.98, 0.80, 0.62)
			for k in range(2):
				var ring_r: float = s * (0.16 + 0.11 * float(k))
				var ring := PackedVector2Array()
				for j in range(14):
					var a8: float = TAU * float(j) / 14.0
					ring.append(c + Vector2(0, s * 0.30) + Vector2(cos(a8) * ring_r, sin(a8) * ring_r * 0.38))
				for j in range(13, -1, -1):
					var a9: float = TAU * float(j) / 14.0
					ring.append(c + Vector2(0, s * 0.30)
						+ Vector2(cos(a9) * (ring_r - s * 0.03), sin(a9) * (ring_r - s * 0.03) * 0.38))
				_poly(p, ring, Color(0.44, 0.72, 0.95, 0.8 - 0.3 * float(k)))
			_round_rect(p, c + Vector2(-s * 0.05, -s * 0.34), Vector2(s * 0.13, s * 0.42), skin, s * 0.06)
			_poly(p, Shapes.blob(c + Vector2(s * 0.10, s * 0.10), Vector2(s * 0.17, s * 0.14),
				Shapes.rng_for("tapfist"), 0.10, 2, 12), skin.darkened(0.06))
			_circle(p, c + Vector2(0.0, -s * 0.34), s * 0.065, skin)
		"tower":
			# The energy tower, small enough for a map stone: body, lamp, glow.
			var steel := Color(0.56, 0.60, 0.74)
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.13, s * 0.40), c + Vector2(-s * 0.07, -s * 0.16),
				c + Vector2(s * 0.07, -s * 0.16), c + Vector2(s * 0.13, s * 0.40),
			]), steel)
			_round_rect(p, c + Vector2(-s * 0.17, s * 0.34), Vector2(s * 0.34, s * 0.08), steel.darkened(0.15), s * 0.03)
			_circle(p, c + Vector2(0, -s * 0.26), s * 0.13, Color(1.0, 0.86, 0.42))
			_poly(p, Shapes.star_points(c + Vector2(0, -s * 0.26), s * 0.07, 0.45, 4), Color(1, 1, 1, 0.9))
			for wy2 in range(2):
				_round_rect(p, c + Vector2(-s * 0.045, -s * 0.04 + float(wy2) * s * 0.16),
					Vector2(s * 0.09, s * 0.10), Color(0.94, 0.86, 0.58), s * 0.02)
		"potion":
			# The heart potion: a round flask with a heart glowing in it.
			var glass := Color(0.72, 0.86, 0.96)
			_circle(p, c + Vector2(0, s * 0.10), s * 0.28, glass)
			_round_rect(p, c + Vector2(-s * 0.08, -s * 0.34), Vector2(s * 0.16, s * 0.20), glass, s * 0.04)
			_round_rect(p, c + Vector2(-s * 0.11, -s * 0.40), Vector2(s * 0.22, s * 0.09),
				Color(0.72, 0.52, 0.36), s * 0.03)
			var heart := PackedVector2Array()
			var hc := c + Vector2(0, s * 0.12)
			for j in range(24):
				var t2: float = TAU * float(j) / 24.0
				heart.append(hc + Vector2(
					s * 0.0100 * 16.0 * pow(sin(t2), 3.0),
					-s * 0.0100 * (13.0 * cos(t2) - 5.0 * cos(2.0 * t2) - 2.0 * cos(3.0 * t2) - cos(4.0 * t2))))
			_poly(p, heart, Color(0.94, 0.35, 0.44))
			_circle(p, hc + Vector2(-s * 0.06, -s * 0.02), s * 0.035, Color(1, 1, 1, 0.75))
		"star_bomb":
			# The star burst: a gold star leaving a trail of sparks -- thrown, not lit.
			for k in range(3):
				_poly(p, Shapes.star_points(c + Vector2(-s * (0.20 + 0.10 * float(k)), s * (0.16 + 0.08 * float(k))),
					s * (0.08 - 0.02 * float(k)), 0.42, 4), Color(1.0, 0.84, 0.36, 0.7 - 0.2 * float(k)))
			_lit_circle(p, c + Vector2(s * 0.08, -s * 0.06), s * 0.235, Color(1.0, 0.62, 0.30))
			_poly(p, Shapes.star_points(c + Vector2(s * 0.08, -s * 0.06), s * 0.30, 0.45, 5),
				Color(1.0, 0.84, 0.30))
			_poly(p, Shapes.star_points(c + Vector2(s * 0.08, -s * 0.06), s * 0.13, 0.45, 5),
				Color(1.0, 0.96, 0.72))
		"balloon":
			# The red balloon, mid-bounce: Keepy Uppy's whole idea in one shape.
			var red2 := Color(0.92, 0.34, 0.36)
			var string_line := Line2D.new()
			string_line.points = PackedVector2Array([
				c + Vector2(0, s * 0.24), c + Vector2(-s * 0.04, s * 0.42),
			])
			string_line.width = maxf(s * 0.03, 2.0)
			string_line.default_color = Color(0.40, 0.30, 0.24, 0.9)
			string_line.antialiased = true
			p.add_child(string_line)
			_lit_circle(p, c + Vector2(0, -s * 0.04), s * 0.28, red2)
			_poly(p, Shapes.oval_points(c + Vector2(0, -s * 0.04), Vector2(s * 0.26, s * 0.30), 20), red2)
			_poly(p, Shapes.oval_points(c + Vector2(-s * 0.09, -s * 0.14), Vector2(s * 0.07, s * 0.09), 10),
				Color(1, 1, 1, 0.5))
			_tri(p, c + Vector2(-s * 0.05, s * 0.26), c + Vector2(s * 0.05, s * 0.26),
				c + Vector2(0, s * 0.19), red2.darkened(0.15))
		"goo":
			var slime := Color(0.55, 0.78, 0.42)
			_lit_circle(p, c + Vector2(0, s * 0.04), s * 0.30, slime)
			# Two drips so it reads as thrown goo rather than a green ball.
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.30, s * 0.10), c + Vector2(-s * 0.36, s * 0.30),
				c + Vector2(-s * 0.18, s * 0.22),
			]), slime.darkened(0.10))
			_circle(p, c + Vector2(s * 0.30, s * 0.26), s * 0.07, slime.darkened(0.06))
			_poly(p, Shapes.oval_points(c + Vector2(-s * 0.09, -s * 0.12),
				Vector2(s * 0.09, s * 0.06), 10), Color(1, 1, 1, 0.5))
		"target":
			for k in range(3):
				_circle(p, c, s * (0.34 - 0.11 * float(k)),
					[Color(0.90, 0.32, 0.30), Color(0.97, 0.94, 0.88),
						Color(0.90, 0.32, 0.30)][k])
			_circle(p, c, s * 0.05, Color(0.97, 0.94, 0.88))
		"crown":
			var gold := Color(1.0, 0.82, 0.30)
			_round_rect(p, c + Vector2(-s * 0.30, s * 0.06), Vector2(s * 0.60, s * 0.16), gold, s * 0.04)
			for k in range(3):
				var px2: float = -s * 0.22 + s * 0.22 * float(k)
				_tri(p, c + Vector2(px2 - s * 0.09, s * 0.08), c + Vector2(px2 + s * 0.09, s * 0.08),
					c + Vector2(px2, -s * (0.30 if k == 1 else 0.20)), gold)
			for k in range(3):
				_circle(p, c + Vector2(-s * 0.22 + s * 0.22 * float(k), s * 0.13), s * 0.035,
					[Color(0.90, 0.32, 0.36), Color(0.36, 0.70, 0.92), Color(0.42, 0.80, 0.52)][k])
		"party_hat":
			var cone := PackedVector2Array([
				c + Vector2(-s * 0.22, s * 0.30), c + Vector2(s * 0.22, s * 0.30), c + Vector2(0, -s * 0.28),
			])
			_poly(p, cone, Color(0.95, 0.58, 0.76))
			_round_rect(p, c + Vector2(-s * 0.17, s * 0.02), Vector2(s * 0.30, s * 0.075),
				Color(1.0, 0.86, 0.42), s * 0.03)
			_circle(p, c + Vector2(0, -s * 0.30), s * 0.07, Color(1.0, 0.86, 0.42))
		"cap":
			var blue2 := Color(0.34, 0.58, 0.86)
			var dome := PackedVector2Array()
			for k in range(13):
				var a10: float = PI + PI * float(k) / 12.0
				dome.append(c + Vector2(cos(a10) * s * 0.28, s * 0.06 + sin(a10) * s * 0.28))
			_poly(p, dome, blue2)
			_circle(p, c + Vector2(0, -s * 0.20), s * 0.045, blue2.darkened(0.2))
			_poly(p, Shapes.oval_points(c + Vector2(s * 0.14, s * 0.09), Vector2(s * 0.26, s * 0.075), 14),
				blue2.darkened(0.12))
		"sunglasses":
			var dark := Color(0.16, 0.18, 0.24)
			for side3 in [-1.0, 1.0]:
				_round_rect(p, c + Vector2(side3 * s * 0.26 - s * 0.15, -s * 0.10),
					Vector2(s * 0.30, s * 0.22), dark, s * 0.07)
				_circle(p, c + Vector2(side3 * s * 0.20, -s * 0.04), s * 0.035, Color(1, 1, 1, 0.35))
			_round_rect(p, c + Vector2(-s * 0.08, -s * 0.06), Vector2(s * 0.16, s * 0.05), dark, s * 0.02)
		"cape_red":
			var red3 := Color(0.88, 0.30, 0.32)
			_poly(p, PackedVector2Array([
				c + Vector2(-s * 0.16, -s * 0.30), c + Vector2(s * 0.16, -s * 0.30),
				c + Vector2(s * 0.30, s * 0.26), c + Vector2(s * 0.10, s * 0.18),
				c + Vector2(-s * 0.06, s * 0.30), c + Vector2(-s * 0.28, s * 0.20),
			]), red3)
			_round_rect(p, c + Vector2(-s * 0.20, -s * 0.34), Vector2(s * 0.40, s * 0.075),
				Color(1.0, 0.86, 0.42), s * 0.03)
		"wings":
			for side4 in [-1.0, 1.0]:
				var wing := PackedVector2Array([
					c + Vector2(side4 * s * 0.04, s * 0.10),
					c + Vector2(side4 * s * 0.38, -s * 0.26),
					c + Vector2(side4 * s * 0.30, s * 0.02),
					c + Vector2(side4 * s * 0.20, s * 0.16),
				])
				_poly(p, wing, Color(0.97, 0.97, 1.0))
				_circle(p, c + Vector2(side4 * s * 0.24, -s * 0.10), s * 0.05, Color(1.0, 0.90, 0.55))
		_:
			return false
	return true
