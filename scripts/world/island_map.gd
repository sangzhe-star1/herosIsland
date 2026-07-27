class_name IslandMap
extends Node2D
## Growth Island, drawn as an island.
##
## What this replaces: a vertical list of navy cards stacked over a photograph
## of a city skyline, with a decorative dot-to-dot line baked INTO the
## photograph that had no relationship to any level. It was a menu wearing a
## map's name.
##
## A map is worth building properly because it is the only screen that shows a
## child the shape of the whole game: where they have been, where they are, and
## that there is more. That needs one continuous place with a path running
## through it, not five panels.
##
## The island is generated from the level data, so adding a level in
## data/levels.json extends the path and the coastline grows to fit. Nothing
## here is hand-placed and nothing needs redrawing when content changes.

## How much coast each level gets, and the least a world may have. Regions are
## sized from their level count rather than fixed, because a world with seven
## levels crammed into the same width as one with three puts markers on top of
## each other -- which is exactly what the first version of this map did.
const PER_LEVEL := 250.0
const REGION_MIN := 620.0
## The height the island was drawn against, and the height it is actually drawn
## on. Same story as stage.gd: aspect="expand" hands a 4:3 tablet a 1280x960
## viewport, and an island laid out against a fixed 720 leaves the nearest
## quarter of the sea empty with every level marker bunched up above it. On a
## 1280x720 screen the two are equal and nothing moves.
const DESIGN_H := 720.0
var view_h := DESIGN_H

const SHORE_Y := 250.0        # where the land begins
const PATH_W := 46.0

var _positions: Dictionary = {}     # "world_id:index" -> Vector2
var _region_centres: Dictionary = {}
var _region_x: Dictionary = {}
var _region_w: Dictionary = {}
var _width := 1280.0
var _rng: RandomNumberGenerator
## Compact mode: ONE world drawn as ONE island that fits a single 1280x720
## page, markers on a serpentine path. The paged map uses this; the original
## long-strip mode remains for anything that wants the whole archipelago.
var _compact := false


func canvas_size() -> Vector2:
	return Vector2(_width, view_h)


## Where a level's marker sits. World map asks for this and places its button
## there, so the buttons are ON the island rather than floating over it.
func node_position(world_id: String, index: int) -> Vector2:
	return _positions.get("%s:%d" % [world_id, index], Vector2(100, 400))


func region_centre(world_id: String) -> Vector2:
	return _region_centres.get(world_id, Vector2(100, SHORE_Y))


## `worlds` in display order; `levels_by_world` maps world id -> Array of level
## dictionaries.
func build(worlds: Array, levels_by_world: Dictionary, compact: bool = false) -> void:
	for c in get_children():
		c.queue_free()
	_positions.clear()
	_region_centres.clear()
	_region_x.clear()
	_region_w.clear()
	_compact = compact
	# How tall the screen really is, asked once, before a single shape is laid
	# out. Needs this node in the tree, which is why the map adds it to the page
	# before calling build() rather than after.
	if is_inside_tree():
		view_h = maxf(DESIGN_H, get_viewport_rect().size.y)
	# Seed per island in compact mode, so every world's coastline is its own.
	var seed_key := "growth-island"
	if compact and worlds.size() > 0:
		seed_key = "island-" + str(worlds[0].get("id", ""))
	_rng = Shapes.rng_for(seed_key)
	_measure(worlds, levels_by_world)
	_lay_out_nodes(worlds, levels_by_world)
	_draw_sea()
	_draw_land(worlds)
	_draw_regions(worlds)
	_draw_path(worlds, levels_by_world)
	_draw_clouds()


# --- where things go ----------------------------------------------------

## Each world gets as much coast as it needs.
func _measure(worlds: Array, levels_by_world: Dictionary) -> void:
	if _compact:
		# One island, one page: fixed geometry, however many levels it holds
		# (the serpentine below absorbs the count).
		for world in worlds:
			var world_id2: String = str(world.get("id", ""))
			_region_x[world_id2] = 120.0
			_region_w[world_id2] = 1040.0
		_width = 1280.0
		return
	var x: float = 120.0
	for world in worlds:
		var world_id: String = str(world.get("id", ""))
		var count: int = maxi((levels_by_world.get(world_id, []) as Array).size(), 1)
		var width: float = maxf(float(count) * PER_LEVEL, REGION_MIN)
		_region_x[world_id] = x
		_region_w[world_id] = width
		x += width
	_width = maxf(x + 160.0, 1280.0)


## Node positions next, because the coastline is grown around them rather than
## the other way round -- that is what keeps every marker on dry land however
## many levels a world gains.
func _lay_out_nodes(worlds: Array, levels_by_world: Dictionary) -> void:
	for wi in range(worlds.size()):
		var world_id: String = str(worlds[wi].get("id", ""))
		var levels: Array = levels_by_world.get(world_id, [])
		var x0: float = _region_x.get(world_id, 120.0)
		var width: float = _region_w.get(world_id, REGION_MIN)
		_region_centres[world_id] = Vector2(x0 + width * 0.5, SHORE_Y + 30.0)
		var count: int = maxi(levels.size(), 1)
		if _compact:
			# A serpentine: up to four markers a row, the next row walking back
			# the other way. The path drawn through them becomes the S-curve a
			# one-page island needs -- eight levels with no scrolling at all.
			var per_row: int = 4 if count <= 8 else 5
			for i in range(count):
				var row: int = i / per_row
				var in_row: int = mini(per_row, count - row * per_row)
				var tt: float = 0.5 if in_row == 1 else float(i % per_row) / float(in_row - 1)
				if row % 2 == 1:
					tt = 1.0 - tt
				# Two rows with real air between them: a marker column (stone
				# + name + stars) is ~215px tall, so the rows sit 226 apart
				# and the first cut's cosy 144 -- which stacked row one's
				# stars into row two's stones -- stays a lesson.
				var sx: float = 240.0 + tt * 800.0
				# Rows measured from the BOTTOM of the screen, not from
				# taste: a marker column is a stone plus a name plus a star
				# row, about 215 px, hung from `sy - MARKER * 0.54`. At 584
				# the second row's stars fell off the bottom edge of a 720 px
				# screen -- invisible in a single-world map and obvious the
				# moment a world had six levels instead of eight.
				var sy: float = (332.0 if row == 0 else 550.0) * view_h / DESIGN_H \
					+ sin(float(i) * 1.9) * 8.0
				_positions["%s:%d" % [world_id, i]] = Vector2(sx, sy)
			continue
		for i in range(count):
			var t: float = (float(i) + 0.5) / float(count)
			# A meander rather than a row: the path has to look walked, not
			# laid out, or the island turns straight back into a list. The
			# vertical swing also buys horizontal room -- two markers a step
			# apart are further apart than their x values alone suggest.
			var x: float = x0 + 40.0 + t * (width - 80.0)
			var y: float = coast_y(x) + 205.0 + sin(float(i) * 1.15 + float(wi) * 1.7) * 105.0
			_positions["%s:%d" % [world_id, i]] = Vector2(x, clampf(y, SHORE_Y + 150.0, view_h - 205.0))


# --- the island ---------------------------------------------------------

## The coastline as a function, so props, path and land all agree on where the
## water stops. Reading it off the drawn polygon was the alternative; a
## function is cheaper and cannot drift out of sync with the shape.
func coast_y(x: float) -> float:
	var t: float = clampf((x + 80.0) / (_width + 160.0), 0.0, 1.0)
	var y: float = SHORE_Y + sin(t * 9.0) * 34.0 + sin(t * 21.0 + 1.3) * 15.0 + cos(t * 4.0) * 26.0
	var taper: float = smoothstep(0.0, 0.07, t) * smoothstep(1.0, 0.93, t)
	return lerpf(view_h + 200.0, y, taper)


func _draw_sea() -> void:
	var sea := Node2D.new()
	add_child(sea)
	Shapes.gradient_quad(sea, Vector2(-120, -120), Vector2(_width + 240, view_h + 240),
		Color(0.30, 0.62, 0.82), Color(0.15, 0.40, 0.64))
	# Slow bands of shimmer instead of drawn waves: waves at this scale read as
	# clutter, and a still sea reads as a floor.
	for i in range(int(_width / 90.0)):
		var w: float = _rng.randf_range(70.0, 230.0)
		var at := Vector2(_rng.randf_range(-100.0, _width), _rng.randf_range(-60.0, view_h + 60.0))
		var band: Polygon2D = Shapes.fill(sea,
			Shapes.rounded_rect(at, Vector2(w, 6.0), 3.0, 2), Color(1, 1, 1, 0.13), 0.0)
		if not Juice.motion_enabled():
			continue
		var t := band.create_tween().set_loops()
		var period: float = _rng.randf_range(2.4, 5.0)
		t.tween_property(band, "self_modulate:a", 0.3, period).set_trans(Tween.TRANS_SINE)
		t.tween_property(band, "self_modulate:a", 1.0, period).set_trans(Tween.TRANS_SINE)


## One landmass for the whole game. The coastline wobbles around the node
## positions, so every world is part of the same island rather than five
## separate ones -- which is the point the old five-panel map could not make.
func _draw_land(worlds: Array) -> void:
	var land := Node2D.new()
	add_child(land)

	var coast := PackedVector2Array()
	var steps := int(_width / 40.0)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = -80.0 + t * (_width + 160.0)
		coast.append(Vector2(x, coast_y(x)))
	var bottom := PackedVector2Array(coast)
	bottom.append(Vector2(_width + 120.0, view_h + 220.0))
	bottom.append(Vector2(-120.0, view_h + 220.0))

	# Shallows, then foam, then sand, then grass. Four flat bands, each
	# slightly inset from the last -- the cheapest possible coastline, and it
	# reads better than any single outline.
	for layer in [
		{"inset": -46.0, "color": Color(0.52, 0.82, 0.90, 0.55)},
		{"inset": -22.0, "color": Color(0.92, 0.98, 1.00, 0.75)},
		{"inset": 0.0, "color": Color(0.94, 0.87, 0.68)},
		{"inset": 26.0, "color": Color(0.53, 0.76, 0.44)},
	]:
		var shifted := PackedVector2Array()
		for p in bottom:
			shifted.append(p + Vector2(0, float(layer["inset"])))
		Shapes.fill(land, shifted, layer["color"], 0.0)

	# The lit lip along the grass edge, same rule as every ground plane in the
	# game so the island belongs to the same world as the levels.
	var lip := PackedVector2Array()
	for p in coast:
		lip.append(p + Vector2(0, 26.0))
	for i in range(coast.size() - 1, -1, -1):
		lip.append(coast[i] + Vector2(0, 36.0))
	Shapes.fill(land, lip, Color(0.63, 0.84, 0.52), 0.0)


## Each world's stretch of coast gets its own terrain, drawn from the same
## prop vocabulary the levels use. Standing on the map looking at Hero City,
## a child should recognise the place they play in.
func _draw_regions(worlds: Array) -> void:
	var props := Node2D.new()
	add_child(props)
	for wi in range(worlds.size()):
		var world_id: String = str(worlds[wi].get("id", ""))
		var x0: float = _region_x.get(world_id, 120.0)
		var width: float = _region_w.get(world_id, REGION_MIN)
		var tint := Color.from_string(str(worlds[wi].get("color", "#888888")), Color.GRAY)

		# A soft wash of the world's colour, so the five regions are tellable
		# apart at a glance without a single word.
		Shapes.fill(props, Shapes.blob(Vector2(x0 + width * 0.5, SHORE_Y + 280.0),
			Vector2(width * 0.52, 260.0), _rng, 0.14, 3, 26),
			Color(tint.r, tint.g, tint.b, 0.14), 0.0)

		for i in range(int(width / 150.0) + 3):
			# Placed relative to the coastline at that x, so nothing ends up
			# standing on the sea when the shore happens to dip.
			# Two bands only: hugging the shore behind the path, or right at
			# the bottom in front of it. Anything in between lands on top of a
			# marker, and a level a child cannot see is worse than a bare field.
			var px: float = x0 + _rng.randf_range(0.0, width)
			var at := Vector2(px, coast_y(px) + _rng.randf_range(46.0, 96.0)) if i % 2 == 0 \
				else Vector2(px, view_h - _rng.randf_range(4.0, 44.0))
			var holder := Node2D.new()
			holder.position = at
			var s: float = _rng.randf_range(0.34, 0.58)
			holder.scale = Vector2(s, s)
			props.add_child(holder)
			Shapes.ground_shadow(holder, Vector2.ZERO, 120.0, 0.16)
			_region_prop(holder, world_id)


func _region_prop(parent: Node2D, world_id: String) -> void:
	match world_id:
		"hero_city":
			var h: float = _rng.randf_range(150.0, 260.0)
			var w: float = _rng.randf_range(70.0, 110.0)
			Shapes.lit(parent, Shapes.rounded_rect(Vector2(-w * 0.5, -h), Vector2(w, h), 6.0),
				Color(0.56, 0.60, 0.74), 1.0)
			for cy in range(int(h / 40.0)):
				for cx in range(int(w / 30.0)):
					Shapes.fill(parent, Shapes.rounded_rect(
						Vector2(-w * 0.5 + 12.0 + float(cx) * 30.0, -h + 16.0 + float(cy) * 40.0),
						Vector2(14, 18), 3.0), Color(0.94, 0.86, 0.58), 0.0)
		"piglet_town":
			var w2: float = _rng.randf_range(110.0, 150.0)
			var h2: float = w2 * 0.66
			Shapes.lit(parent, Shapes.rounded_rect(Vector2(-w2 * 0.5, -h2), Vector2(w2, h2), 8.0),
				Color(0.98, 0.94, 0.86), 1.0)
			Shapes.lit(parent, PackedVector2Array([
				Vector2(-w2 * 0.62, -h2), Vector2(0, -h2 - w2 * 0.38), Vector2(w2 * 0.62, -h2),
			]), Color(0.86, 0.44, 0.38), 1.0)
		"safety":
			Shapes.fill(parent, Shapes.taper(Vector2.ZERO, Vector2(0, -150.0), 12.0, 8.0),
				Color(0.34, 0.36, 0.44), 1.0)
			Shapes.lit(parent, Shapes.rounded_rect(Vector2(-24, -196), Vector2(48, 56), 12.0),
				Color(0.26, 0.27, 0.34), 1.0)
			for i in range(3):
				Shapes.fill(parent, Shapes.circle_points(Vector2(0, -182 + float(i) * 18.0), 7.0, 12),
					[Color(0.90, 0.32, 0.28), Color(0.98, 0.80, 0.28),
						Color(0.36, 0.76, 0.44)][i], 0.0)
		"rescue_forest":
			var th: float = _rng.randf_range(150.0, 220.0)
			Shapes.fill(parent, Shapes.taper(Vector2.ZERO, Vector2(0, -th * 0.45), 22.0, 16.0),
				Color(0.44, 0.31, 0.22), 1.0)
			for i in range(3):
				var t: float = float(i) / 2.0
				var w3: float = th * lerpf(0.42, 0.18, t)
				Shapes.lit(parent, PackedVector2Array([
					Vector2(-w3, -th * (0.36 + t * 0.24)),
					Vector2(0, -th * (0.70 + t * 0.24)),
					Vector2(w3, -th * (0.36 + t * 0.24)),
				]), Color(0.22, 0.48, 0.34).lightened(t * 0.10), 1.0)
		"adventure_valley":
			# A peak with a snowcap and a summit flag: the region is ABOUT
			# getting to the top of things.
			var pk: float = _rng.randf_range(120.0, 190.0)
			Shapes.lit(parent, PackedVector2Array([
				Vector2(-pk * 0.62, 0), Vector2(-pk * 0.1, -pk),
				Vector2(pk * 0.16, -pk * 0.66), Vector2(pk * 0.34, -pk * 0.82),
				Vector2(pk * 0.66, 0),
			]), Color(0.60, 0.70, 0.82), 1.0)
			Shapes.fill(parent, PackedVector2Array([
				Vector2(-pk * 0.26, -pk * 0.66), Vector2(-pk * 0.1, -pk),
				Vector2(pk * 0.08, -pk * 0.72), Vector2(0, -pk * 0.6),
			]), Color(0.97, 0.98, 1.0), 0.0)
			Shapes.fill(parent, Shapes.taper(Vector2(-pk * 0.1, -pk),
				Vector2(-pk * 0.1, -pk * 1.22), 3.0, 2.0), Color(0.5, 0.42, 0.3), 0.0)
			Shapes.fill(parent, PackedVector2Array([
				Vector2(-pk * 0.1, -pk * 1.22), Vector2(pk * 0.12, -pk * 1.14),
				Vector2(-pk * 0.1, -pk * 1.06),
			]), Color(0.90, 0.36, 0.34), 0.0)
		"bluey_park":
			# A kennel with a red roof and a bone over the door: the island a
			# puppy lives on, readable from across the map.
			var kw: float = _rng.randf_range(100.0, 140.0)
			var kh: float = kw * 0.62
			Shapes.lit(parent, Shapes.rounded_rect(Vector2(-kw * 0.5, -kh), Vector2(kw, kh), 8.0),
				Color(0.62, 0.80, 0.94), 1.0)
			Shapes.lit(parent, PackedVector2Array([
				Vector2(-kw * 0.62, -kh), Vector2(0, -kh - kw * 0.42), Vector2(kw * 0.62, -kh),
			]), Color(0.88, 0.40, 0.36), 1.0)
			var arch := PackedVector2Array()
			for i in range(11):
				var aa: float = PI + PI * float(i) / 10.0
				arch.append(Vector2(cos(aa) * kw * 0.20, -kh * 0.42 + sin(aa) * kw * 0.20))
			arch.append(Vector2(kw * 0.20, 0))
			arch.append(Vector2(-kw * 0.20, 0))
			Shapes.fill(parent, arch, Color(0.16, 0.22, 0.34), 0.0)
			for side2 in [-1.0, 1.0]:
				Shapes.fill(parent, Shapes.oval_points(
					Vector2(side2 * kw * 0.10, -kh - kw * 0.18), Vector2(kw * 0.085, kw * 0.055), 10),
					Color(0.97, 0.94, 0.86), 0.8)
		"monster_arena":
			var r: float = _rng.randf_range(70.0, 130.0)
			Shapes.lit(parent, Shapes.blob(Vector2(0, -r * 0.55), Vector2(r, r * 0.72),
				_rng, 0.24, 4, 16), Color(0.52, 0.44, 0.66), 1.0)

		# --- the five worlds the map actually has ----------------------------
		#
		# Same gap as in WorldStyle: the rebuild renamed the worlds and nobody
		# moved the map's drawings across, so all five regions fell to the
		# green blob at the bottom and the island read as one long park. A
		# child should be able to point at the map and say which bit is the
		# city, from across the room.

		"sunny_park":
			# A round tree and a bench: the picture of "park" a six-year-old
			# would draw.
			var tt: float = _rng.randf_range(120.0, 175.0)
			Shapes.fill(parent, Shapes.taper(Vector2.ZERO, Vector2(0, -tt * 0.5), 18.0, 13.0),
				Color(0.46, 0.33, 0.24), 1.0)
			Shapes.lit(parent, Shapes.blob(Vector2(0, -tt * 0.72), Vector2(tt * 0.46, tt * 0.38),
				_rng, 0.18, 4, 18), Color(0.34, 0.62, 0.38), 1.0)
			Shapes.lit(parent, Shapes.rounded_rect(
				Vector2(tt * 0.30, -tt * 0.20), Vector2(tt * 0.42, tt * 0.09), 4.0),
				Color(0.80, 0.62, 0.42), 1.0)

		"night_city":
			# A lit tower block. The windows are the point -- a dark tower is
			# a rock, a tower with windows on is a city at night.
			var ch: float = _rng.randf_range(170.0, 270.0)
			var cw: float = _rng.randf_range(72.0, 108.0)
			Shapes.lit(parent, Shapes.rounded_rect(Vector2(-cw * 0.5, -ch), Vector2(cw, ch), 6.0),
				Color(0.40, 0.42, 0.62), 1.0)
			for wy in range(int(ch / 40.0)):
				for wx in range(int(cw / 30.0)):
					# Not every window: a fully lit block looks like graph paper.
					if _rng.randf() < 0.72:
						Shapes.fill(parent, Shapes.rounded_rect(
							Vector2(-cw * 0.5 + 12.0 + float(wx) * 30.0,
								-ch + 16.0 + float(wy) * 40.0),
							Vector2(14, 18), 3.0), Color(0.98, 0.90, 0.60), 0.0)
			Shapes.glow(parent, Vector2(0, -ch - 6.0), 54.0, Color(0.72, 0.88, 1.0), 5, 0.26)

		"monster_valley":
			# A friendly lump with two ears and two eyes, asleep on the hill.
			var mr: float = _rng.randf_range(72.0, 128.0)
			Shapes.lit(parent, Shapes.blob(Vector2(0, -mr * 0.56), Vector2(mr, mr * 0.70),
				_rng, 0.22, 4, 16), Color(0.40, 0.58, 0.40), 1.0)
			for ear in [-1.0, 1.0]:
				Shapes.lit(parent, PackedVector2Array([
					Vector2(ear * mr * 0.52, -mr * 0.92),
					Vector2(ear * mr * 0.30, -mr * 1.30),
					Vector2(ear * mr * 0.16, -mr * 0.86),
				]), Color(0.36, 0.53, 0.38), 1.0)
			for eye in [-1.0, 1.0]:
				Shapes.fill(parent, Shapes.circle_points(
					Vector2(eye * mr * 0.26, -mr * 0.74), mr * 0.09, 12),
					Color(1.0, 0.96, 0.82), 0.0)

		"sky_base":
			# A platform on a column, standing in its own cloud. Reads as
			# "up there" without needing anything behind it.
			var sw: float = _rng.randf_range(120.0, 168.0)
			Shapes.fill(parent, Shapes.oval_points(Vector2(0, -12.0),
				Vector2(sw * 0.72, sw * 0.20), 18), Color(0.94, 0.97, 1.0, 0.85), 0.0)
			Shapes.fill(parent, Shapes.taper(Vector2(0, -sw * 0.10),
				Vector2(0, -sw * 0.66), 20.0, 26.0), Color(0.58, 0.68, 0.82), 1.0)
			Shapes.lit(parent, Shapes.rounded_rect(
				Vector2(-sw * 0.5, -sw * 0.86), Vector2(sw, sw * 0.24), 10.0),
				Color(0.76, 0.86, 0.94), 1.0)
			Shapes.fill(parent, Shapes.taper(Vector2(sw * 0.28, -sw * 0.86),
				Vector2(sw * 0.28, -sw * 1.16), 4.0, 3.0), Color(0.52, 0.60, 0.74), 0.0)
			Shapes.glow(parent, Vector2(sw * 0.28, -sw * 1.18), 40.0,
				Color(0.60, 0.94, 1.0), 5, 0.34)

		"dark_castle":
			# Two towers, battlements, one warm lit window. The light is what
			# keeps it from being a scary building: somebody is home.
			var kw2: float = _rng.randf_range(120.0, 170.0)
			var kh2: float = kw2 * 0.86
			Shapes.lit(parent, Shapes.rounded_rect(
				Vector2(-kw2 * 0.34, -kh2), Vector2(kw2 * 0.68, kh2), 4.0),
				Color(0.40, 0.34, 0.54), 1.0)
			for tower in [-1.0, 1.0]:
				Shapes.lit(parent, Shapes.rounded_rect(
					Vector2(tower * kw2 * 0.50 - kw2 * 0.12, -kh2 * 1.24),
					Vector2(kw2 * 0.24, kh2 * 1.24), 4.0), Color(0.34, 0.29, 0.48), 1.0)
				Shapes.lit(parent, PackedVector2Array([
					Vector2(tower * kw2 * 0.50 - kw2 * 0.17, -kh2 * 1.24),
					Vector2(tower * kw2 * 0.50, -kh2 * 1.52),
					Vector2(tower * kw2 * 0.50 + kw2 * 0.17, -kh2 * 1.24),
				]), Color(0.56, 0.34, 0.44), 1.0)
			for merlon in range(3):
				Shapes.fill(parent, Shapes.rounded_rect(
					Vector2(-kw2 * 0.30 + float(merlon) * kw2 * 0.22, -kh2 - kh2 * 0.12),
					Vector2(kw2 * 0.13, kh2 * 0.12), 2.0), Color(0.40, 0.34, 0.54), 0.0)
			Shapes.fill(parent, Shapes.rounded_rect(
				Vector2(-kw2 * 0.07, -kh2 * 0.62), Vector2(kw2 * 0.14, kh2 * 0.22), 5.0),
				Color(1.0, 0.86, 0.56), 0.0)
			Shapes.glow(parent, Vector2(0, -kh2 * 0.51), 58.0, Color(1.0, 0.84, 0.52), 5, 0.30)

		_:
			Shapes.lit(parent, Shapes.blob(Vector2(0, -40.0), Vector2(56.0, 40.0), _rng, 0.2, 3, 16),
				Color(0.42, 0.68, 0.42), 1.0)


## One path from the first level to the last, through every marker in order.
## It is the thing that makes the island a journey: a child can see that the
## road keeps going past the level they are on.
func _draw_path(worlds: Array, levels_by_world: Dictionary) -> void:
	var route := PackedVector2Array()
	for world in worlds:
		var world_id: String = str(world.get("id", ""))
		var levels: Array = levels_by_world.get(world_id, [])
		for i in range(maxi(levels.size(), 1)):
			route.append(node_position(world_id, i))
	if route.size() < 2:
		return

	var path := Node2D.new()
	add_child(path)
	# A worn sandy track with a soft edge, drawn under everything the child
	# taps so the markers sit ON it.
	Shapes.fill(path, Shapes.ribbon(route, PATH_W + 12.0, 10),
		Color(0.86, 0.76, 0.55, 0.55), 0.0)
	Shapes.fill(path, Shapes.ribbon(route, PATH_W, 10), Color(0.95, 0.89, 0.72), 0.0)
	# Stepping stones along it, which is what stops a long sand ribbon from
	# reading as a road marking.
	var smooth := Shapes.smooth(route, 10)
	for i in range(0, smooth.size(), 4):
		Shapes.fill(path, Shapes.oval_points(smooth[i],
			Vector2(11.0, 8.0), 12), Color(0.86, 0.79, 0.62, 0.8), 0.0)


func _draw_clouds() -> void:
	var air := Node2D.new()
	air.z_index = 6
	add_child(air)
	for i in range(int(_width / 380.0) + 2):
		var cloud := Node2D.new()
		cloud.position = Vector2(_rng.randf_range(-80.0, _width), _rng.randf_range(20.0, 150.0))
		var s: float = _rng.randf_range(0.5, 0.9)
		cloud.scale = Vector2(s, s)
		cloud.modulate = Color(1, 1, 1, 0.55)
		air.add_child(cloud)
		var span: float = 170.0
		Shapes.fill(cloud, Shapes.blob(Vector2(0, 8), Vector2(span, span * 0.20), _rng, 0.12, 3, 22),
			Color(0.86, 0.93, 1.0), 0.0)
		for k in range(3):
			Shapes.fill(cloud, Shapes.blob(
				Vector2(_rng.randf_range(-span * 0.4, span * 0.4), _rng.randf_range(-12.0, 2.0)),
				Vector2(span * 0.44, span * 0.26), _rng, 0.16, 3, 22), Color.WHITE, 0.0)
		# The shadow the cloud throws on the sea. Two nodes, and the island
		# stops looking like a sticker on blue paper.
		Shapes.fill(air, Shapes.blob(cloud.position + Vector2(60, 210),
			Vector2(span * s * 0.9, span * s * 0.22), _rng, 0.14, 3, 20),
			Color(0.10, 0.24, 0.40, 0.10), 0.0)
