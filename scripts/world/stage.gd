class_name Stage
extends Node2D
## The world, drawn.
##
## Every screen in the game -- shell screens and gameplay alike -- puts one of
## these behind itself, and that is the only way scenery gets on screen. There
## is no second path, no per-template skyline, and no `background_art` key.
## This is the architectural point: one renderer means one world.
##
## What it builds, back to front:
##
##   sky gradient -> sun or moon -> stars -> high clouds -> three parallax
##   horizon bands -> horizon haze -> ground plane -> ground detail ->
##   props standing on the ground line -> low clouds -> airborne motes ->
##   optional calm veil -> foreground fringe
##
## Everything is a polygon. Nothing is a PNG. That is what lets the world be
## generated per level, lit per world, animated, and recoloured at runtime --
## none of which a painted background can do.
##
## Usage:
##     var stage := Stage.build(play_area, WorldStyle.for_world("hero_city"), level_id)
##     hero.position.y = stage.ground_y()
##
## Determinism: the same seed key always produces the same city. A child who
## replays a level sees the same place, and a screenshot stays comparable.

## The size the world was drawn against. Every number below is a fraction of,
## or an offset from, these two -- which is what makes the next four lines
## possible at all.
const DESIGN_W := 1280.0
const DESIGN_H := 720.0
## Drawn wider than the viewport so the world still reaches the edges when the
## window is a different aspect ratio (the project stretches with "expand").
const BLEED := 220.0

## The size of the screen the child is ACTUALLY holding, filled in before a
## single shape is drawn.
##
## These were `const W := 1280.0` and `const H := 720.0` for the whole life of
## the project, and that is where the island's oldest layout bug lived. The
## game stretches with aspect="expand", so a 4:3 tablet hands it a 1280x960
## viewport -- 240 real pixels of extra height. With a fixed 720 the horizon
## stayed put at y=559 and the ground plane simply ran off the bottom, so the
## whole world was drawn into the top three quarters of an iPad and the last
## quarter was a flat green band with nothing in it. Every actor in the game
## stands on ground_y(), so every actor stood up there too.
##
## Measuring instead of assuming costs two lines and fixes it everywhere at
## once: on a 1280x720 screen these are 1280 and 720 and NOTHING changes, which
## is the only reason a change this wide is safe to make.
var view_w := DESIGN_W
var view_h := DESIGN_H

var style: WorldStyle
var _rng: RandomNumberGenerator

var _sky: Node2D
var _far: Node2D
var _mid: Node2D
var _near: Node2D
var _ground: Node2D
var _props: Node2D
var _air: Node2D
var _fringe: Node2D

var _clouds: Array[Dictionary] = []      # [{node, speed, span}]
var _swayers: Array[Dictionary] = []     # [{node, amount, rate, phase}]
## Scenery a child may poke: [{node, kind, radius}]. See poke_at().
var _pokeable: Array[Dictionary] = []
var _time := 0.0

## The y of the ground line on the design-size screen, for the three callers
## that need a number before there is a stage to ask. Anything holding a stage
## should call ground_y() on it instead -- that one knows how tall the screen
## really is.
static func ground_line() -> float:
	return DESIGN_H * WorldStyle.HORIZON


func ground_y() -> float:
	return view_h * (style.horizon if style != null else WorldStyle.HORIZON)


## Convenience: build a stage and put it behind everything already in `parent`.
static func build(parent: Node, world_style: WorldStyle, seed_key: String = "") -> Stage:
	var stage := Stage.new()
	stage.style = world_style
	stage.name = "Stage"
	# Everything in the world sits below every control. Node2D children keep
	# their own z ordering relative to this, so a near tree still draws in
	# front of a far one -- but no piece of scenery can ever end up in front of
	# a button, which is what happened the first time props were given depth.
	stage.z_index = -50
	stage._rng = Shapes.rng_for(seed_key if seed_key != "" else world_style.id)
	parent.add_child(stage)
	parent.move_child(stage, 0)
	return stage


func _ready() -> void:
	if style == null:
		style = WorldStyle.for_world("island")
	if _rng == null:
		_rng = Shapes.rng_for(style.id)
	_measure()
	_construct()
	set_process(true)


## Ask the screen how big it is, once, before anything is drawn.
##
## Clamped up to the design size and never down: a viewport smaller than
## 1280x720 cannot happen with aspect="expand" (it only ever adds pixels), and
## if one ever did, a world drawn SMALLER than the screen would leave a hole,
## which is worse than a world drawn slightly too big.
func _measure() -> void:
	var view := get_viewport_rect().size
	view_w = maxf(DESIGN_W, view.x)
	view_h = maxf(DESIGN_H, view.y)


# --- construction -------------------------------------------------------

func _construct() -> void:
	_sky = _layer("Sky")
	_build_sky()
	_build_celestial()
	_build_stars()

	# Three bands, tallest and palest at the back. The heights are per-world
	# because a skyline needs room to tower and a hedgerow does not.
	var scale: float = style.band_scale
	_far = _layer("Far")
	_build_band(_far, 0, 0.30, 118.0 * scale)
	_mid = _layer("Mid")
	_build_band(_mid, 1, 0.55, 76.0 * scale)
	_near = _layer("Near")
	_build_band(_near, 2, 0.80, 38.0 * scale)

	_build_haze()

	_ground = _layer("Ground")
	_build_ground()

	_props = _layer("Props")
	_build_props()

	_air = _layer("Air")
	_build_clouds()
	_build_motes()

	if style.calm > 0.0:
		_build_calm_veil()

	_fringe = _layer("Fringe")
	_build_fringe()


func _layer(layer_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = layer_name
	add_child(node)
	return node


func _build_sky() -> void:
	Shapes.gradient_quad(_sky, Vector2(-BLEED, -80.0), Vector2(view_w + BLEED * 2.0, view_h + 160.0),
		style.sky_top, style.sky_bottom)


## The sun or the moon. It is placed, not centred: a light source in a fixed
## corner is what makes every shadow in the scene agree with every other one.
func _build_celestial() -> void:
	if style.light_radius <= 0.0:
		return
	var at := Vector2(style.light_at.x * view_w, style.light_at.y * view_h)
	Shapes.glow(_sky, at, style.light_radius * 5.0, style.light_color, 6, style.light_glow)
	var disc := Shapes.fill(_sky, Shapes.circle_points(at, style.light_radius, 34),
		style.light_color, 0.0)
	disc.self_modulate = Color(1, 1, 1, 0.96)

	# A moon gets craters, which is the cheapest possible way to say "night"
	# without darkening anything a child has to look at. Kept faint and off to
	# one side: three dark dots in the middle read as a face, and a face in the
	# sky is not what this screen is for.
	if style.star_density > 0.6:
		for i in range(4):
			var a: float = TAU * _rng.randf()
			var d: float = sqrt(_rng.randf()) * 0.62
			Shapes.fill(_sky,
				Shapes.circle_points(at + Vector2(cos(a), sin(a)) * d * style.light_radius,
					style.light_radius * _rng.randf_range(0.08, 0.15), 14),
				style.light_color.darkened(0.055), 0.0)


func _build_stars() -> void:
	if style.star_density <= 0.0:
		return
	var count := int(120.0 * style.star_density)
	var horizon: float = ground_y()
	for i in range(count):
		var y: float = _rng.randf_range(-40.0, horizon - 120.0)
		# Thin out towards the horizon, where the haze would wash them out.
		if _rng.randf() > 1.0 - (y / horizon) * 0.75:
			continue
		var at := Vector2(_rng.randf_range(-BLEED, view_w + BLEED), y)
		var r: float = _rng.randf_range(1.4, 3.4)
		var dot := Shapes.fill(_sky, Shapes.circle_points(at, r, 8),
			Color(1.0, 0.98, 0.90, _rng.randf_range(0.4, 0.95)), 0.0)
		# A slow, low-contrast twinkle. Never a blink: rapid flicker is both
		# unpleasant for a small child and a seizure risk.
		if _rng.randf() < 0.4:
			var t := dot.create_tween().set_loops()
			var period: float = _rng.randf_range(1.6, 3.4)
			t.tween_property(dot, "self_modulate:a", 0.30, period)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(dot, "self_modulate:a", 1.0, period)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# A handful of the brightest ones get points, so the sky has a few
		# things in it that read as stars rather than as dust.
		if r > 3.0:
			Shapes.fill(_sky, Shapes.star_points(at, r * 3.4, 0.22, 4),
				Color(1.0, 0.99, 0.92, 0.5), 0.0)


## One silhouette band. `depth` drives both how far it parallaxes and how much
## it is washed toward the sky, which is the only distance cue a flat drawn
## world has -- and the one the pasted-together version never had.
func _build_band(parent: Node2D, index: int, solidity: float, height: float) -> void:
	var color: Color = style.band_color(index).lerp(style.sky_bottom, (1.0 - solidity) * 0.55)
	var base: float = ground_y() + 6.0
	var points := PackedVector2Array()
	match style.horizon_kind:
		"skyline", "rooftops":
			points = _skyline(base, height, index)
		"forest":
			points = _treeline(base, height, index)
		"crags":
			points = _crags(base, height, index)
		"sea":
			points = _sea_band(base, height, index)
		"hills", _:
			points = _hills(base, height, index)
	if points.is_empty():
		return
	Shapes.fill(parent, points, color, 0.0)

	# Windows only on the nearest city band -- lit windows at distance turn a
	# skyline into confetti.
	if style.horizon_kind == "skyline" and index >= 2:
		_light_windows(parent, points, base)


func _hills(base: float, height: float, index: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var phase: float = _rng.randf() * TAU
	var freq: float = 0.0022 + 0.0011 * float(index)
	var x: float = -BLEED
	while x <= view_w + BLEED:
		var y: float = base - height \
			- sin(x * freq + phase) * height * 0.55 \
			- sin(x * freq * 2.3 + phase * 1.7) * height * 0.22
		pts.append(Vector2(x, y))
		x += 26.0
	pts.append(Vector2(view_w + BLEED, base + view_h))
	pts.append(Vector2(-BLEED, base + view_h))
	return pts


func _skyline(base: float, height: float, index: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-BLEED, base + view_h), Vector2(-BLEED, base - height)])
	var x: float = -BLEED
	var block: float = 70.0 + 28.0 * float(index)
	while x <= view_w + BLEED:
		var w: float = block * _rng.randf_range(0.62, 1.5)
		var h: float = height * _rng.randf_range(0.45, 1.7)
		# Rooftop worlds are low and domestic; city worlds tower.
		if style.horizon_kind == "rooftops":
			h = height * _rng.randf_range(0.30, 0.75)
		var top: float = base - h
		pts.append(Vector2(x, top))
		# A few get a stepped crown or a mast, which is what stops a skyline
		# from reading as a bar chart.
		var roll: float = _rng.randf()
		if roll < 0.18:
			var inset: float = w * 0.28
			pts.append(Vector2(x + inset, top))
			pts.append(Vector2(x + inset, top - h * 0.22))
			pts.append(Vector2(x + w - inset, top - h * 0.22))
			pts.append(Vector2(x + w - inset, top))
		elif roll < 0.30 and style.horizon_kind == "rooftops":
			pts.append(Vector2(x + w * 0.5, top - h * 0.30))
		elif roll < 0.36:
			var mast: float = x + w * 0.5
			pts.append(Vector2(mast - 3.0, top))
			pts.append(Vector2(mast - 3.0, top - h * 0.34))
			pts.append(Vector2(mast + 3.0, top - h * 0.34))
			pts.append(Vector2(mast + 3.0, top))
		pts.append(Vector2(x + w, top))
		x += w + _rng.randf_range(0.0, 14.0)
	pts.append(Vector2(view_w + BLEED, base + view_h))
	return pts


func _treeline(base: float, height: float, index: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-BLEED, base + view_h)])
	var x: float = -BLEED
	var span: float = 44.0 + 16.0 * float(index)
	while x <= view_w + BLEED:
		var h: float = height * _rng.randf_range(0.55, 1.5)
		var w: float = span * _rng.randf_range(0.7, 1.3)
		# A conifer is three chevrons; drawn as a spike with two shoulders it
		# reads as a tree at a distance and costs four points.
		pts.append(Vector2(x, base - h * 0.20))
		pts.append(Vector2(x + w * 0.28, base - h * 0.62))
		pts.append(Vector2(x + w * 0.18, base - h * 0.60))
		pts.append(Vector2(x + w * 0.5, base - h))
		pts.append(Vector2(x + w * 0.82, base - h * 0.60))
		pts.append(Vector2(x + w * 0.72, base - h * 0.62))
		pts.append(Vector2(x + w, base - h * 0.20))
		x += w * _rng.randf_range(0.62, 0.92)
	pts.append(Vector2(view_w + BLEED, base + view_h))
	return pts


func _crags(base: float, height: float, index: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-BLEED, base + view_h)])
	var x: float = -BLEED
	while x <= view_w + BLEED:
		var w: float = _rng.randf_range(90.0, 230.0)
		var h: float = height * _rng.randf_range(0.5, 1.8)
		pts.append(Vector2(x, base))
		pts.append(Vector2(x + w * _rng.randf_range(0.35, 0.65), base - h))
		x += w
	pts.append(Vector2(view_w + BLEED, base))
	pts.append(Vector2(view_w + BLEED, base + view_h))
	return pts


## The map's horizon: open sea, so the island below has somewhere to sit.
func _sea_band(base: float, height: float, index: int) -> PackedVector2Array:
	var y: float = base - height * 1.4
	return PackedVector2Array([
		Vector2(-BLEED, y), Vector2(view_w + BLEED, y),
		Vector2(view_w + BLEED, base + view_h), Vector2(-BLEED, base + view_h),
	])


## Warm windows along the nearest rooftops. Sparse and irregular on purpose --
## a perfect grid of windows is the fastest way to make a drawn city look like
## a spreadsheet.
func _light_windows(parent: Node2D, silhouette: PackedVector2Array, base: float) -> void:
	var lit := Color(1.0, 0.86, 0.50, 0.85)
	var i := 1
	while i < silhouette.size() - 2:
		var a: Vector2 = silhouette[i]
		var b: Vector2 = silhouette[i + 1]
		i += 1
		if absf(b.x - a.x) < 30.0 or absf(a.y - b.y) > 2.0:
			continue
		var top: float = a.y
		var w: float = b.x - a.x
		var cols := int(w / 24.0)
		var rows := int((base - top) / 30.0)
		for cx in range(cols):
			for cy in range(rows):
				if _rng.randf() > 0.34:
					continue
				var at := Vector2(a.x + 10.0 + float(cx) * 24.0, top + 16.0 + float(cy) * 30.0)
				Shapes.fill(parent, Shapes.rounded_rect(at, Vector2(9, 12), 2.0, 2),
					Color(lit.r, lit.g, lit.b, _rng.randf_range(0.35, 0.9)), 0.0)


## The warm band where the sky meets the land. This one gradient does more for
## "this is a place at a particular time of day" than any other single thing in
## the file, which is why every world has one.
func _build_haze() -> void:
	var base: float = ground_y()
	var haze := Shapes.gradient_quad(self, Vector2(-BLEED, base - 200.0),
		Vector2(view_w + BLEED * 2.0, 206.0),
		Color(style.haze.r, style.haze.g, style.haze.b, 0.0), style.haze)
	haze.name = "Haze"


func _build_ground() -> void:
	var base: float = ground_y()
	Shapes.gradient_quad(_ground, Vector2(-BLEED, base),
		Vector2(view_w + BLEED * 2.0, view_h - base + 120.0), style.ground_top, style.ground_bottom)

	# The lip where ground meets sky, lit from above. Without it the ground is
	# a coloured rectangle; with it, it is a surface.
	Shapes.fill(_ground, PackedVector2Array([
		Vector2(-BLEED, base), Vector2(view_w + BLEED, base),
		Vector2(view_w + BLEED, base + 7.0), Vector2(-BLEED, base + 7.0),
	]), style.ground_top.lightened(0.22), 0.0)

	match style.ground_kind:
		"road":
			_build_road(base)
		"plaza":
			_build_plaza(base)
		"arena":
			_build_arena(base)
		"sand":
			_build_shore(base)
		"grass", _:
			_build_grass(base)


func _build_grass(base: float) -> void:
	# Tufts, thinning with distance from the camera. Placed with the seeded rng
	# so the meadow is the same meadow every time.
	for i in range(int(round(120.0 * style.grass_tuft_density))):
		var y: float = base + pow(_rng.randf(), 0.7) * (view_h - base + 60.0)
		var depth: float = (y - base) / maxf(view_h - base, 1.0)
		var x: float = _rng.randf_range(-BLEED, view_w + BLEED)
		var h: float = 6.0 + depth * 22.0
		var blade := Shapes.fill(_ground, PackedVector2Array([
			Vector2(x - h * 0.28, y), Vector2(x + _rng.randf_range(-h * 0.4, h * 0.4), y - h),
			Vector2(x + h * 0.28, y),
		]), style.ground_bottom.lerp(style.ground_top, 0.35 + depth * 0.4), 0.0)
		blade.z_index = -1
	for i in range(int(round(22.0 * style.flower_density))):
		var y: float = base + pow(_rng.randf(), 0.6) * (view_h - base + 40.0)
		var x: float = _rng.randf_range(-BLEED, view_w + BLEED)
		var petal: Color = [Color(1.0, 0.86, 0.34), Color(0.98, 0.62, 0.72),
			Color(0.86, 0.90, 1.0)][_rng.randi() % 3]
		var r: float = 3.0 + (y - base) / (view_h - base) * 5.0
		for k in range(5):
			var a: float = TAU * float(k) / 5.0
			Shapes.fill(_ground, Shapes.circle_points(
				Vector2(x, y) + Vector2(cos(a), sin(a)) * r * 0.9, r * 0.6, 8), petal, 0.0)
		Shapes.fill(_ground, Shapes.circle_points(Vector2(x, y), r * 0.5, 8),
			Color(1.0, 0.94, 0.62), 0.0)


func _build_road(base: float) -> void:
	# A road in perspective: narrower at the horizon, wide at the child's feet.
	# The traffic level used to be flat grey bands with no ground at all.
	var road_top: float = base + 8.0
	var top_half: float = view_w * 0.30
	var bottom_half: float = view_w * 0.86
	var mid: float = view_w * 0.5
	var tarmac := Shapes.fill(_ground, PackedVector2Array([
		Vector2(mid - top_half, road_top), Vector2(mid + top_half, road_top),
		Vector2(mid + bottom_half, view_h + 60.0), Vector2(mid - bottom_half, view_h + 60.0),
	]), Color(0.34, 0.35, 0.40), 0.0)
	tarmac.name = "Road"
	# Kerbs, lit on top.
	for side in [-1.0, 1.0]:
		Shapes.fill(_ground, PackedVector2Array([
			Vector2(mid + side * top_half, road_top),
			Vector2(mid + side * (top_half + 10.0), road_top),
			Vector2(mid + side * (bottom_half + 26.0), view_h + 60.0),
			Vector2(mid + side * bottom_half, view_h + 60.0),
		]), Color(0.80, 0.79, 0.76), 0.0)
	# Centre dashes, foreshortened.
	var t := 0.06
	while t < 1.0:
		var y0: float = lerpf(road_top, view_h + 40.0, t * t)
		var y1: float = lerpf(road_top, view_h + 40.0, minf((t + 0.06), 1.0) * (t + 0.06))
		var w0: float = lerpf(3.0, 16.0, t)
		Shapes.fill(_ground, PackedVector2Array([
			Vector2(mid - w0, y0), Vector2(mid + w0, y0),
			Vector2(mid + w0 * 1.4, y1), Vector2(mid - w0 * 1.4, y1),
		]), Color(1.0, 0.94, 0.62, 0.85), 0.0)
		t += 0.14


func _build_plaza(base: float) -> void:
	# Wet city stone at dusk: slabs in perspective plus reflected window light.
	var mid: float = view_w * 0.5
	var rows := 7
	for i in range(rows):
		var t0: float = pow(float(i) / float(rows), 1.8)
		var t1: float = pow(float(i + 1) / float(rows), 1.8)
		var y0: float = lerpf(base, view_h + 60.0, t0)
		var y1: float = lerpf(base, view_h + 60.0, t1)
		var shade: Color = style.ground_top.lerp(style.ground_bottom, t0)
		Shapes.fill(_ground, PackedVector2Array([
			Vector2(-BLEED, y0), Vector2(view_w + BLEED, y0),
			Vector2(view_w + BLEED, y1), Vector2(-BLEED, y1),
		]), shade.lightened(0.02 if i % 2 == 0 else 0.0), 0.0)
	for i in range(26):
		var x: float = _rng.randf_range(-BLEED, view_w + BLEED)
		var y: float = base + pow(_rng.randf(), 1.6) * (view_h - base)
		var length: float = _rng.randf_range(20.0, 70.0)
		Shapes.fill(_ground, PackedVector2Array([
			Vector2(x - 3.0, y), Vector2(x + 3.0, y),
			Vector2(x + 5.0, y + length), Vector2(x - 5.0, y + length),
		]), Color(1.0, 0.80, 0.50, _rng.randf_range(0.05, 0.16)), 0.0)


func _build_arena(base: float) -> void:
	# A ring of packed sand with a lit rim, so a duel visibly happens SOMEWHERE
	# rather than in front of a wall. The ring reaches above the horizon line,
	# which is what makes the ground read as a floor receding away from the
	# child rather than a stripe along the bottom of the screen.
	var centre := Vector2(view_w * 0.5, base + (view_h - base) * 0.30)
	var radii := Vector2(view_w * 0.60, (view_h - base) * 1.5)
	Shapes.glow(_ground, centre, radii.x * 1.1, Color(0.94, 0.72, 1.0), 5, 0.16)
	Shapes.fill(_ground, Shapes.oval_points(centre, radii, 44),
		Color(0.52, 0.42, 0.62), 0.0)
	Shapes.fill(_ground, Shapes.oval_points(centre, radii * 0.93, 44),
		Color(0.40, 0.33, 0.52), 0.0)
	Shapes.fill(_ground, Shapes.oval_points(centre, radii * 0.86, 44),
		Color(0.46, 0.37, 0.56), 0.0)
	# Torch marks around the rim -- the fairground-after-closing light this
	# world is supposed to have.
	for i in range(9):
		var a: float = PI * (0.06 + 0.88 * float(i) / 8.0)
		var at: Vector2 = centre + Vector2(cos(a) * radii.x * 0.96, sin(a) * radii.y * 0.96)
		if at.y < base - 6.0:
			continue
		Shapes.glow(_ground, at, 60.0, Color(1.0, 0.74, 0.42), 4, 0.34)
		Shapes.fill(_ground, Shapes.circle_points(at, 6.0, 10), Color(1.0, 0.86, 0.56), 0.0)


func _build_shore(base: float) -> void:
	# Open water for the map: slow bands of shimmer rather than drawn waves.
	for i in range(16):
		var y: float = base + _rng.randf_range(0.0, view_h - base + 60.0)
		var w: float = _rng.randf_range(80.0, 300.0)
		var x: float = _rng.randf_range(-BLEED, view_w + BLEED - w)
		var band := Shapes.fill(_ground, Shapes.rounded_rect(Vector2(x, y), Vector2(w, 5.0), 2.5, 2),
			Color(1, 1, 1, 0.16), 0.0)
		var t := band.create_tween().set_loops()
		var period: float = _rng.randf_range(2.2, 4.4)
		t.tween_property(band, "self_modulate:a", 0.25, period).set_trans(Tween.TRANS_SINE)
		t.tween_property(band, "self_modulate:a", 1.0, period).set_trans(Tween.TRANS_SINE)


# --- props --------------------------------------------------------------

## Things standing on the ground line. Placed away from the middle third,
## because that is where the game happens -- scenery that has to be looked
## past is worse than no scenery.
func _build_props() -> void:
	if style.props.is_empty():
		return
	var base: float = ground_y()
	var count := int(9.0 * style.prop_density)
	# Placed in slots rather than at random, so props never pile up on one
	# spot and the middle third -- where the game happens -- stays clear.
	var slots: Array[float] = []
	for i in range(count):
		var t: float = float(i) / maxf(float(count - 1), 1.0)
		var left: bool = i % 2 == 0
		var lane: float = t if left else 1.0 - t
		slots.append(lerpf(-70.0, view_w * 0.30, lane) if left
			else lerpf(view_w * 0.70, view_w + 70.0, lane))
	for i in range(count):
		var kind: String = style.props[_rng.randi() % style.props.size()]
		var x: float = slots[i] + _rng.randf_range(-46.0, 46.0)
		var depth: float = _rng.randf_range(0.0, 1.0)
		var y: float = base + depth * (view_h - base) * style.prop_band
		var scale: float = lerpf(0.55, 1.25, depth)
		var holder := Node2D.new()
		holder.position = Vector2(x, y)
		holder.scale = Vector2(scale, scale)
		holder.z_index = int(depth * 10.0)
		_props.add_child(holder)
		Shapes.ground_shadow(holder, Vector2.ZERO, 90.0, 0.18)
		_draw_prop(holder, kind, depth)
		# Props are drawn upward from their feet, so the poke circle is lifted
		# off the ground line to sit on the thing itself rather than on the
		# grass under it.
		_pokeable.append({
			"node": holder, "kind": kind, "radius": 66.0 * scale,
			"lift": Vector2(0, -52.0 * scale),
		})


func _draw_prop(parent: Node2D, kind: String, depth: float) -> void:
	# Distant props lose contrast toward the sky, exactly like the bands do.
	# Distant things lose contrast against the sky. Less so at night: a night
	# sky is already dark, so washing props toward it erases them instead of
	# pushing them back.
	var strength: float = 0.35 * (1.0 - style.star_density * 0.6)
	var wash: float = (1.0 - depth) * strength * (1.0 - style.calm * 0.3) + style.calm * 0.25
	match kind:
		"tree", "pine":
			_prop_tree(parent, kind == "pine", wash)
		"bush":
			_prop_bush(parent, wash)
		"flower":
			_prop_flower(parent, wash)
		"cottage", "shop":
			_prop_house(parent, kind == "shop", wash)
		"fence":
			_prop_fence(parent, wash)
		"lamp":
			_prop_lamp(parent, wash)
		"rock", "crag":
			_prop_rock(parent, wash)
		"log":
			_prop_log(parent, wash)
		"block":
			_prop_block(parent, wash)
		"antenna":
			_prop_antenna(parent, wash)
		"banner":
			_prop_banner(parent, wash)
		"brazier":
			_prop_brazier(parent, wash)


func _wash(c: Color, amount: float) -> Color:
	return c.lerp(style.sky_bottom, amount)


func _prop_tree(parent: Node2D, conifer: bool, wash: float) -> void:
	var h: float = _rng.randf_range(120.0, 190.0)
	var trunk := _wash(Color(0.44, 0.31, 0.22), wash)
	Shapes.fill(parent, Shapes.taper(Vector2(0, 0), Vector2(_rng.randf_range(-8, 8), -h * 0.55),
		h * 0.13, h * 0.08), trunk, 1.0)
	# The crown is a separate node so it can sway from the trunk top.
	var crown := Node2D.new()
	crown.position = Vector2(0, -h * 0.5)
	parent.add_child(crown)
	var leaf: Color = _wash(Color(0.28, 0.56, 0.32) if not conifer
		else Color(0.20, 0.44, 0.34), wash)
	if conifer:
		for i in range(3):
			var t: float = float(i) / 2.0
			var w: float = h * lerpf(0.46, 0.20, t)
			var y: float = -t * h * 0.34
			Shapes.lit(crown, PackedVector2Array([
				Vector2(-w, y), Vector2(0, y - h * 0.34), Vector2(w, y),
			]), leaf.lightened(t * 0.10), 1.0)
	else:
		for i in range(3):
			var at := Vector2(_rng.randf_range(-h * 0.18, h * 0.18), _rng.randf_range(-h * 0.24, 0.0))
			Shapes.lit(crown, Shapes.blob(at, Vector2(h * 0.34, h * 0.30), _rng, 0.14, 4, 22),
				leaf.lightened(_rng.randf_range(0.0, 0.10)), 1.0)
	_swayers.append({
		"node": crown, "amount": _rng.randf_range(0.012, 0.030),
		"rate": _rng.randf_range(0.5, 0.9), "phase": _rng.randf() * TAU,
	})


func _prop_bush(parent: Node2D, wash: float) -> void:
	var r: float = _rng.randf_range(30.0, 52.0)
	var leaf: Color = _wash(Color(0.32, 0.58, 0.34), wash)
	for i in range(3):
		var at := Vector2(_rng.randf_range(-r * 0.7, r * 0.7), _rng.randf_range(-r * 0.3, 0.0))
		Shapes.lit(parent, Shapes.blob(at, Vector2(r * 0.8, r * 0.62), _rng, 0.18, 3, 18),
			leaf.lightened(_rng.randf_range(0.0, 0.12)), 1.0)


func _prop_flower(parent: Node2D, wash: float) -> void:
	var h: float = _rng.randf_range(26.0, 44.0)
	Shapes.fill(parent, Shapes.taper(Vector2(0, 0), Vector2(_rng.randf_range(-5, 5), -h), 4.0, 3.0),
		_wash(Color(0.36, 0.58, 0.32), wash), 0.8)
	var petal: Color = _wash([Color(0.98, 0.56, 0.68), Color(1.0, 0.82, 0.34),
		Color(0.72, 0.62, 0.94)][_rng.randi() % 3], wash)
	for k in range(5):
		var a: float = TAU * float(k) / 5.0
		Shapes.fill(parent, Shapes.oval_points(Vector2(0, -h) + Vector2(cos(a), sin(a)) * h * 0.16,
			Vector2(h * 0.13, h * 0.13), 10), petal, 0.8)
	Shapes.fill(parent, Shapes.circle_points(Vector2(0, -h), h * 0.10, 10),
		_wash(Color(1.0, 0.92, 0.56), wash), 0.8)


func _prop_house(parent: Node2D, shop: bool, wash: float) -> void:
	var w: float = _rng.randf_range(110.0, 160.0)
	var h: float = w * _rng.randf_range(0.62, 0.85)
	var wall: Color = _wash([Color(0.98, 0.94, 0.86), Color(0.96, 0.88, 0.78),
		Color(0.92, 0.92, 0.86)][_rng.randi() % 3], wash)
	var roof: Color = _wash([Color(0.84, 0.42, 0.36), Color(0.46, 0.56, 0.72),
		Color(0.90, 0.62, 0.30)][_rng.randi() % 3], wash)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-w * 0.5, -h), Vector2(w, h), 8.0), wall, 1.0)
	Shapes.lit(parent, PackedVector2Array([
		Vector2(-w * 0.62, -h), Vector2(0, -h - w * 0.38), Vector2(w * 0.62, -h),
	]), roof, 1.0)
	# A lit window, warm in every world -- the one thing that says somebody
	# lives here.
	var lit_window: Color = Color(1.0, 0.86, 0.52) if style.star_density > 0.0 \
		else _wash(Color(0.62, 0.82, 0.92), wash)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-w * 0.28, -h * 0.78),
		Vector2(w * 0.24, h * 0.28), 5.0), lit_window, 1.0)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(w * 0.06, -h * 0.52),
		Vector2(w * 0.22, h * 0.52), 6.0), _wash(Color(0.52, 0.38, 0.28), wash), 1.0)
	if shop:
		# An awning, striped, which is enough to make a house read as a shop.
		for i in range(5):
			var sw: float = w * 0.16
			Shapes.fill(parent, PackedVector2Array([
				Vector2(-w * 0.42 + float(i) * sw, -h * 0.55),
				Vector2(-w * 0.42 + float(i + 1) * sw, -h * 0.55),
				Vector2(-w * 0.46 + float(i + 1) * sw, -h * 0.34),
				Vector2(-w * 0.46 + float(i) * sw, -h * 0.34),
			]), _wash(Color(0.92, 0.42, 0.38) if i % 2 == 0 else Color(0.98, 0.96, 0.92), wash), 0.6)


func _prop_fence(parent: Node2D, wash: float) -> void:
	var wood: Color = _wash(Color(0.86, 0.78, 0.62), wash)
	var span: float = 150.0
	for i in range(5):
		var x: float = -span * 0.5 + span * float(i) / 4.0
		Shapes.fill(parent, Shapes.rounded_rect(Vector2(x - 5, -52), Vector2(10, 52), 4.0), wood, 1.0)
	for y in [-40.0, -20.0]:
		Shapes.fill(parent, Shapes.rounded_rect(Vector2(-span * 0.5, y), Vector2(span, 8), 3.0),
			wood.darkened(0.06), 1.0)


func _prop_lamp(parent: Node2D, wash: float) -> void:
	var h: float = _rng.randf_range(140.0, 190.0)
	var metal: Color = _wash(Color(0.30, 0.32, 0.40), wash)
	Shapes.fill(parent, Shapes.taper(Vector2(0, 0), Vector2(0, -h), 11.0, 7.0), metal, 1.0)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-14, -h - 26), Vector2(28, 30), 12.0), metal, 1.0)
	# Lit only when the world needs light. A streetlamp on at noon is the kind
	# of detail that quietly tells a child the picture is fake.
	if style.star_density > 0.0 or style.id == "hero_city":
		Shapes.glow(parent, Vector2(0, -h - 12), 96.0, Color(1.0, 0.86, 0.52), 5, 0.30)
		Shapes.fill(parent, Shapes.circle_points(Vector2(0, -h - 12), 11.0, 14),
			Color(1.0, 0.94, 0.72), 0.0)


func _prop_rock(parent: Node2D, wash: float) -> void:
	var r: float = _rng.randf_range(34.0, 78.0)
	var stone: Color = _wash(Color(0.56, 0.56, 0.62), wash)
	Shapes.lit(parent, Shapes.blob(Vector2(0, -r * 0.45), Vector2(r, r * 0.62), _rng, 0.22, 4, 14),
		stone, 1.0)


func _prop_log(parent: Node2D, wash: float) -> void:
	var w: float = _rng.randf_range(90.0, 140.0)
	var bark: Color = _wash(Color(0.48, 0.34, 0.24), wash)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-w * 0.5, -30), Vector2(w, 30), 14.0), bark, 1.0)
	Shapes.fill(parent, Shapes.oval_points(Vector2(-w * 0.5, -15), Vector2(9, 15), 14),
		_wash(Color(0.76, 0.60, 0.42), wash), 1.0)


func _prop_block(parent: Node2D, wash: float) -> void:
	# A near city block, close enough to have real windows in it. Deliberately
	# modest: buildings that fill the frame turn the play area into an alley,
	# and the hero has to be the biggest thing on the screen.
	var w: float = _rng.randf_range(90.0, 150.0)
	var h: float = _rng.randf_range(150.0, 260.0)
	var wall: Color = _wash(style.band_color(2).lightened(0.08), wash * 0.5)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-w * 0.5, -h), Vector2(w, h), 6.0), wall, 1.0)
	var cols := int(w / 28.0)
	var rows := int(h / 34.0)
	for cx in range(cols):
		for cy in range(rows):
			var on: bool = _rng.randf() < 0.42
			Shapes.fill(parent, Shapes.rounded_rect(
				Vector2(-w * 0.5 + 13.0 + float(cx) * 28.0, -h + 16.0 + float(cy) * 34.0),
				Vector2(13, 16), 3.0),
				Color(1.0, 0.86, 0.52, _rng.randf_range(0.5, 0.95)) if on
					else wall.darkened(0.22), 0.0)


func _prop_antenna(parent: Node2D, wash: float) -> void:
	var h: float = _rng.randf_range(180.0, 300.0)
	var metal: Color = _wash(Color(0.28, 0.30, 0.42), wash)
	Shapes.fill(parent, Shapes.taper(Vector2(0, 0), Vector2(0, -h), 26.0, 6.0), metal, 1.0)
	for i in range(4):
		var y: float = -h * (0.25 + 0.18 * float(i))
		var w: float = lerpf(22.0, 7.0, float(i) / 3.0)
		Shapes.fill(parent, Shapes.rounded_rect(Vector2(-w, y), Vector2(w * 2.0, 5.0), 2.0), metal, 0.6)
	var beacon := Shapes.fill(parent, Shapes.circle_points(Vector2(0, -h - 8), 7.0, 12),
		Color(1.0, 0.42, 0.38), 0.0)
	var t := beacon.create_tween().set_loops()
	t.tween_property(beacon, "self_modulate:a", 0.25, 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(beacon, "self_modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE)


func _prop_banner(parent: Node2D, wash: float) -> void:
	var h: float = _rng.randf_range(180.0, 260.0)
	Shapes.fill(parent, Shapes.taper(Vector2(0, 0), Vector2(0, -h), 12.0, 8.0),
		_wash(Color(0.38, 0.30, 0.44), wash), 1.0)
	var cloth := Node2D.new()
	cloth.position = Vector2(0, -h)
	parent.add_child(cloth)
	var hue: Color = _wash([Color(0.78, 0.36, 0.62), Color(0.42, 0.44, 0.82),
		Color(0.94, 0.62, 0.30)][_rng.randi() % 3], wash)
	Shapes.lit(cloth, PackedVector2Array([
		Vector2(0, 6), Vector2(74, 20), Vector2(60, 52), Vector2(74, 84), Vector2(0, 74),
	]), hue, 1.0)
	_swayers.append({
		"node": cloth, "amount": _rng.randf_range(0.03, 0.06),
		"rate": _rng.randf_range(0.9, 1.4), "phase": _rng.randf() * TAU,
	})


func _prop_brazier(parent: Node2D, wash: float) -> void:
	var metal: Color = _wash(Color(0.34, 0.30, 0.40), wash)
	Shapes.fill(parent, Shapes.taper(Vector2(0, 0), Vector2(0, -84.0), 20.0, 12.0), metal, 1.0)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-30, -116), Vector2(60, 34), 12.0), metal, 1.0)
	Shapes.glow(parent, Vector2(0, -112), 130.0, Color(1.0, 0.62, 0.30), 5, 0.34)
	var flame := Shapes.fill(parent, PackedVector2Array([
		Vector2(-18, -112), Vector2(-6, -152), Vector2(4, -128), Vector2(14, -164), Vector2(20, -112),
	]), Color(1.0, 0.76, 0.34), 0.0)
	var t := flame.create_tween().set_loops()
	t.tween_property(flame, "scale", Vector2(1.08, 0.90), 0.42).set_trans(Tween.TRANS_SINE)
	t.tween_property(flame, "scale", Vector2(0.94, 1.10), 0.38).set_trans(Tween.TRANS_SINE)


# --- air ----------------------------------------------------------------

func _build_clouds() -> void:
	if style.clouds <= 0.0:
		return
	var count := int(3.0 + style.clouds * 6.0)
	for i in range(count):
		var high: bool = i < count / 2
		var cloud := Node2D.new()
		var y: float = _rng.randf_range(20.0, maxf(ground_y(), 200.0) * (0.34 if high else 0.62))
		cloud.position = Vector2(_rng.randf_range(-BLEED, view_w + BLEED), y)
		var s: float = _rng.randf_range(0.55, 1.35) * (0.7 if high else 1.0)
		cloud.scale = Vector2(s, s)
		_air.add_child(cloud)
		# Clouds catch the sky's own light, so they belong to the hour rather
		# than being white blobs stuck on top of it.
		var body: Color = style.sky_bottom.lerp(Color.WHITE, 0.72)
		var under: Color = style.sky_bottom.lerp(style.haze, 0.5)
		var span: float = _rng.randf_range(110.0, 200.0)
		# Every lump is drawn fully opaque and the whole cloud is faded once,
		# on the parent. Stacking translucent lumps instead makes each overlap
		# a darker patch, and the cloud ends up looking faceted -- which is
		# exactly what it looked like before this comment existed.
		cloud.modulate = Color(1, 1, 1, _rng.randf_range(0.80, 0.94))
		Shapes.fill(cloud, Shapes.blob(Vector2(0, 9), Vector2(span, span * 0.22), _rng, 0.12, 3, 22),
			under, 0.0)
		for k in range(3):
			var at := Vector2(_rng.randf_range(-span * 0.42, span * 0.42), _rng.randf_range(-13.0, 2.0))
			Shapes.fill(cloud, Shapes.blob(at, Vector2(span * 0.46, span * 0.27), _rng, 0.16, 3, 22),
				body, 0.0)
		_clouds.append({
			"node": cloud, "speed": _rng.randf_range(3.0, 11.0) * (0.5 if high else 1.0),
			"span": span,
		})
		_pokeable.append({
			"node": cloud, "kind": "cloud", "radius": span * 0.62 * s,
			"lift": Vector2.ZERO,
		})


func _build_motes() -> void:
	if style.mote_kind == "none":
		return
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.position = Vector2(view_w * 0.5, ground_y() * 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(view_w * 0.62 + BLEED, maxf(ground_y(), 120.0) * 0.5)
	p.color = style.mote_color
	p.local_coords = false
	match style.mote_kind:
		"fireflies":
			p.amount = 26
			p.lifetime = 4.0
			p.gravity = Vector2(0, -6)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 16.0
			p.scale_amount_min = 2.5
			p.scale_amount_max = 5.0
			# Fading in and out is what makes them read as fireflies rather
			# than dust; the ramp does it without a shader.
			p.color_ramp = _fade_ramp(style.mote_color)
		"pollen":
			p.amount = 30
			p.lifetime = 7.0
			p.gravity = Vector2(9, 5)
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 12.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.4
			p.color_ramp = _fade_ramp(style.mote_color)
		"embers", "sparks":
			p.amount = 22
			p.lifetime = 3.4
			p.gravity = Vector2(6, -26)
			p.position = Vector2(view_w * 0.5, ground_y() * 0.86)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 30.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.5
			p.color_ramp = _fade_ramp(style.mote_color)
		"snow":
			p.amount = 60
			p.lifetime = 8.0
			p.gravity = Vector2(10, 34)
			p.scale_amount_min = 2.5
			p.scale_amount_max = 5.5
		"rain":
			p.amount = 130
			p.lifetime = 1.1
			p.gravity = Vector2(-60, 1500)
			p.initial_velocity_min = 260.0
			p.initial_velocity_max = 340.0
			p.direction = Vector2(-0.12, 1)
			p.spread = 2.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
	p.preprocess = p.lifetime
	_air.add_child(p)
	p.emitting = true


func _fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0), color,
		Color(color.r, color.g, color.b, 0.0),
	])
	return g


## The veil that lets a busy world sit behind a reading task. Warm rather than
## grey, so quieting the scenery does not turn the screen cold.
func _build_calm_veil() -> void:
	var veil := Shapes.gradient_quad(self, Vector2(-BLEED, -80.0),
		Vector2(view_w + BLEED * 2.0, view_h + 160.0),
		Color(1.0, 0.99, 0.96, style.calm * 0.46),
		Color(1.0, 0.98, 0.94, style.calm * 0.60))
	veil.name = "Calm"


## Out-of-focus shapes hugging the bottom corners. A cheap, very effective
## depth cue: something nearer to the camera than the hero is what turns a
## backdrop into a place the hero is standing inside.
func _build_fringe() -> void:
	if style.id == "island":
		return
	var tint: Color = style.ground_bottom.darkened(0.30)
	for side in [-1.0, 1.0]:
		var at := Vector2(view_w * 0.5 + side * view_w * 0.56, view_h + 40.0)
		var lump := Shapes.fill(_fringe,
			Shapes.blob(at, Vector2(_rng.randf_range(200.0, 300.0), 150.0), _rng, 0.20, 3, 20),
			Color(tint.r, tint.g, tint.b, 0.55), 0.0)
		lump.z_index = 2


# --- life ---------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not Juice.motion_enabled():
		return
	for cloud in _clouds:
		var node: Node2D = cloud["node"]
		if not is_instance_valid(node):
			continue
		node.position.x += float(cloud["speed"]) * delta
		if node.position.x > view_w + BLEED + 260.0:
			node.position.x = -BLEED - 260.0
	for sway in _swayers:
		var node2: Node2D = sway["node"]
		if not is_instance_valid(node2):
			continue
		node2.rotation = sin(_time * float(sway["rate"]) + float(sway["phase"])) \
			* float(sway["amount"])


# --- the world answers back ---------------------------------------------
#
# A screen that only reacts where it is touched teaches a child that the rest
# of it is a photograph -- and at six, a tap that does NOTHING is the screen
# being broken. So the scenery answers: poke a cloud and it squashes, poke a
# cottage and it rocks on its feet. Nothing here navigates, nothing here can be
# got wrong, and nothing here is stored.
#
# The reactions are all the same mechanic -- squash, overshoot, settle -- on
# purpose. One gesture used consistently reads as a world with rules; four
# different bespoke animations read as four bugs.
#
# What may be animated is not free. `_process` above owns every cloud's
# position.x (drift) and every swayer's rotation (wind), and a tween fighting a
# per-frame write loses silently and looks like a stutter. Scale is the one
# channel nothing else writes, which is why every reaction below is a scale.

## Take the scenery out of a vertical strip, for a screen that stands somebody
## there.
##
## Props are placed in slots that avoid the middle third, because that is where
## the game happens -- but a shell screen's character stands in the LEFT third,
## and the world will happily put a cottage under his boots. It looks exactly
## like a hero balanced on a roof, and that is what the home screen looked like
## the first time it was laid out this way.
##
## Removed rather than hidden: a prop nobody can see is still a poke target,
## and poking an invisible cottage is worse than the roof.
func clear_lane(x_min: float, x_max: float) -> void:
	for entry in _pokeable.duplicate():
		var node: Node2D = entry["node"]
		if not is_instance_valid(node) or node.get_parent() != _props:
			continue
		if node.position.x >= x_min and node.position.x <= x_max:
			_pokeable.erase(entry)
			node.queue_free()


## Everything a child may poke, in global coordinates:
## [{"at": Vector2, "kind": String, "radius": float}].
##
## Exposed so a screen can check that its own furniture has not covered the
## whole world -- a home screen whose cards sit over every reachable prop has
## a pokeable world with nothing in it, which looks exactly like a working one.
func poke_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _pokeable:
		var node: Node2D = entry["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		out.append({
			"at": node.to_global(Vector2.ZERO) + (entry["lift"] as Vector2),
			"kind": str(entry["kind"]),
			"radius": float(entry["radius"]),
		})
	return out


## A tap landed somewhere in the world. Returns true if something answered, so
## the caller knows whether to make a noise about it.
##
## Under reduce-motion nothing answers and this returns false. That setting
## means "calm screen", and a world that wobbles when poked is the first thing
## it is asking for less of.
func poke_at(point: Vector2) -> bool:
	if not Juice.motion_enabled():
		return false
	var best: Dictionary = {}
	var best_distance: float = INF
	for entry in _pokeable:
		var node: Node2D = entry["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var centre: Vector2 = node.to_global(Vector2.ZERO) + (entry["lift"] as Vector2)
		var distance: float = centre.distance_to(point)
		# Nearest wins, not first: props overlap, and answering with whichever
		# one happened to be built first means poking a cottage sometimes
		# wobbles the fence behind it.
		if distance <= float(entry["radius"]) and distance < best_distance:
			best_distance = distance
			best = entry
	if best.is_empty():
		return false
	_poke(best)
	return true


func _poke(entry: Dictionary) -> void:
	var node: Node2D = entry["node"]
	# The rest scale is the one the prop was BUILT at -- distance sets it, and
	# it is different for every prop. Reading it live would let a second poke
	# during the first one's squash adopt a squashed scale as home, and the
	# prop would shrink a little every time a child hammered on it.
	var rest: Vector2 = node.scale
	if node.has_meta("_poke_rest"):
		rest = node.get_meta("_poke_rest")
	else:
		node.set_meta("_poke_rest", rest)
	if node.has_meta("_poke_tween"):
		var old: Variant = node.get_meta("_poke_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	node.scale = rest

	var tween: Tween = node.create_tween()
	node.set_meta("_poke_tween", tween)
	tween.tween_property(node, "scale", rest * Vector2(1.14, 0.82), 0.09)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", rest * Vector2(0.95, 1.08), 0.13)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", rest, 0.24)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var at: Vector2 = node.position + (entry["lift"] as Vector2)
	Juice.dust(self, at, 5, 0.8)


# --- what levels ask of it ----------------------------------------------

## Put an actor on the ground at `x`, with its contact shadow, at the size
## things are at that distance. Levels use this instead of choosing a y, which
## is how everything in the game ends up standing on the same floor.
func place(actor: Node2D, x: float, depth: float = 0.0, base_scale: float = 1.0) -> void:
	var y: float = ground_y() + depth * (view_h - ground_y()) * 0.6
	var s: float = base_scale * lerpf(0.9, 1.15, depth)
	actor.position = Vector2(x, y)
	actor.scale = Vector2(s, s)
	actor.z_index = 1 + int(depth * 8.0)
	Shapes.ground_shadow(self, Vector2(x, y), 130.0 * s, 0.24)


## Side-scrolling support: shift the horizon layers against the camera, far
## ones least. This is what turns a static backdrop into depth when the
## platformer's world slides past -- the mountains keep their distance the
## way real mountains do.
func parallax(scroll: float) -> void:
	if _far != null and is_instance_valid(_far):
		_far.position.x = -scroll * 0.05
	if _mid != null and is_instance_valid(_mid):
		_mid.position.x = -scroll * 0.10
	if _near != null and is_instance_valid(_near):
		_near.position.x = -scroll * 0.16
	if _props != null and is_instance_valid(_props):
		_props.position.x = -scroll * 0.30
	if _fringe != null and is_instance_valid(_fringe):
		_fringe.position.x = -scroll * 0.45


## A landmark a level owns -- the energy tower, the crossing's traffic light.
## It goes in with the props so it is lit and shadowed like everything else,
## rather than floating in front of the picture.
func add_landmark(node: Node2D, x: float, depth: float = 0.2) -> void:
	node.position = Vector2(x, ground_y() + depth * (view_h - ground_y()) * 0.4)
	node.z_index = int(depth * 8.0)
	_props.add_child(node)
	Shapes.ground_shadow(_props, node.position, 150.0, 0.20)
