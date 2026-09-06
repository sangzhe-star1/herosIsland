extends RefCounted
## 农场世界的静态美术层。
##
## 这里不决定任何玩法、点击区域或设施位置；它只把 FarmWorld 已有的
## 地面和建筑画得更像一个可以走进去的小基地。把这些笔触留在一处，
## 而不是让控制器、地块和各个入口各画一份小树/小屋，才能一直沿用
## Shapes 的柔和描边、光向和阴影语言。

const MEADOW_LIGHT := Color(0.75, 0.87, 0.62)
const MEADOW_SHADE := Color(0.61, 0.78, 0.47)
const BUSH_DARK := Color(0.29, 0.52, 0.31)
const BUSH_MID := Color(0.38, 0.64, 0.35)
const BUSH_LIGHT := Color(0.55, 0.75, 0.42)
const WOOD_DARK := Color(0.48, 0.31, 0.20)
const WOOD_LIGHT := Color(0.78, 0.58, 0.35)
const STONE := Color(0.57, 0.62, 0.62)


## Draw a fixed, passive layer behind beds and facilities. The controller gives
## us the rectangles a child can act on; no tuft, stone or tree is allowed to
## make those targets look covered. This is a Node2D rather than a Control, so
## it cannot ever become a second input surface by accident.
static func add_ground_dressing(parent: Node2D, protected: Array[Rect2]) -> Node2D:
	var layer := Node2D.new()
	layer.name = "LandmarkScenery"
	layer.set_meta("input_passthrough", true)
	parent.add_child(layer)

	# The island first reads in three broad, low-contrast territories: supplies
	# on the left, the working garden in the middle, and a frontier on the
	# right. These deliberately sit *under* actionable places. They have no
	# outline, controls or hit logic, so they describe the map without asking a
	# child to choose a different kind of ground before touching a bed.
	_draw_base_zones(layer)

	# Broad low-contrast patches stop the farm reading as one flat green sheet.
	# They sit around the working garden, not under it, so ripe crops stay the
	# strongest colour in the opening view.
	for patch in [
		{"at": Vector2(135.0, 132.0), "radii": Vector2(148.0, 82.0), "seed": 11},
		{"at": Vector2(610.0, 142.0), "radii": Vector2(132.0, 70.0), "seed": 23},
		{"at": Vector2(1490.0, 158.0), "radii": Vector2(150.0, 86.0), "seed": 37},
		{"at": Vector2(1748.0, 654.0), "radii": Vector2(138.0, 102.0), "seed": 41},
		{"at": Vector2(250.0, 964.0), "radii": Vector2(158.0, 76.0), "seed": 53},
	]:
		var at: Vector2 = patch["at"]
		var radii: Vector2 = patch["radii"]
		if _clear_of_targets(at, radii.length() * 0.55, protected):
			_draw_meadow_patch(layer, at, radii, int(patch["seed"]))

	# The short branch paths make the visible base facilities feel connected to
	# the existing gate-to-well path without ever crossing a plantable bed.
	draw_path(layer, PackedVector2Array([
		Vector2(205.0, 346.0), Vector2(298.0, 357.0), Vector2(362.0, 382.0),
	]), 32.0)
	draw_path(layer, PackedVector2Array([
		Vector2(208.0, 614.0), Vector2(286.0, 600.0), Vector2(356.0, 574.0),
	]), 32.0)

	# Three edge clusters are enough to establish foreground/middle/background.
	# They are deliberately fixed: a familiar farm should not rearrange itself
	# after a child waters one carrot.
	for tree in [
		{"at": Vector2(128.0, 340.0), "scale": 0.76, "seed": 61},
		{"at": Vector2(1460.0, 202.0), "scale": 0.88, "seed": 67},
		{"at": Vector2(1765.0, 768.0), "scale": 0.82, "seed": 71},
		# Small canopy islands in the gaps make the opening view feel like a
		# base with routes through it, while their measured footprints leave the
		# full child-sized hit areas around every bed untouched.
		{"at": Vector2(650.0, 610.0), "scale": 0.48, "seed": 79},
	]:
		var at: Vector2 = tree["at"]
		var scale: float = float(tree["scale"])
		if _clear_of_targets(at, 78.0 * scale, protected):
			_draw_tree_cluster(layer, at, scale, int(tree["seed"]))

	# The matching gap gets a lower hedge instead of a second twin tree. That
	# difference is small, but prevents the farm from reading as a grid of
	# repeated stickers while still giving the route a little depth.
	for hedge in [
		{"at": Vector2(1010.0, 614.0), "scale": 0.92, "seed": 83},
		{"at": Vector2(1368.0, 602.0), "scale": 0.76, "seed": 89},
	]:
		var at: Vector2 = hedge["at"]
		var scale: float = float(hedge["scale"])
		if _clear_of_targets(at, 36.0 * scale, protected):
			_draw_hedge_cluster(layer, at, scale, int(hedge["seed"]))

	for stones in [
		{"at": Vector2(308.0, 182.0), "scale": 0.90},
		{"at": Vector2(1386.0, 280.0), "scale": 0.78},
		{"at": Vector2(1670.0, 420.0), "scale": 0.92},
		{"at": Vector2(1330.0, 982.0), "scale": 0.88},
	]:
		var at: Vector2 = stones["at"]
		var scale: float = float(stones["scale"])
		if _clear_of_targets(at, 46.0 * scale, protected):
			_draw_stone_cluster(layer, at, scale)

	# Quiet middle-ground detail belongs in the corridors BETWEEN plots. It is
	# purposefully smaller and lower-contrast than a crop: from a child’s first
	# view it reads as “a cared-for place”, never as a second thing to tap.
	for sprig in [
		{"at": Vector2(648.0, 288.0), "scale": 0.88, "bloom": Color(0.99, 0.82, 0.42)},
		{"at": Vector2(505.0, 604.0), "scale": 0.80, "bloom": Color(0.98, 0.68, 0.62)},
		{"at": Vector2(1356.0, 306.0), "scale": 0.80, "bloom": Color(0.99, 0.82, 0.42)},
		{"at": Vector2(1368.0, 602.0), "scale": 0.94, "bloom": Color(0.73, 0.73, 0.94)},
	]:
		var at: Vector2 = sprig["at"]
		var scale: float = float(sprig["scale"])
		if _clear_of_targets(at, 28.0 * scale, protected):
			_draw_fern_patch(layer, at, scale, sprig["bloom"])

	return layer


## Large zones are compositional background, unlike a tree or stone that can
## visually cover an individual target. Therefore they may sit beneath beds
## and facilities, while every smaller prop still goes through `_clear_of_targets`.
## Fixed seeds make the opening base familiar after every refresh.
static func _draw_base_zones(parent: Node2D) -> void:
	var zones := [
		{"at": Vector2(215.0, 600.0), "radii": Vector2(315.0, 470.0),
			"tint": Color(0.80, 0.89, 0.65, 0.31), "seed": 1_147},
		{"at": Vector2(980.0, 585.0), "radii": Vector2(650.0, 470.0),
			"tint": Color(0.84, 0.91, 0.69, 0.25), "seed": 2_233},
		{"at": Vector2(1840.0, 595.0), "radii": Vector2(330.0, 470.0),
			"tint": Color(0.74, 0.84, 0.58, 0.24), "seed": 3_419},
	]
	for zone in zones:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(zone["seed"])
		Shapes.fill(parent, Shapes.blob(zone["at"], zone["radii"], rng,
			0.045, 5, 34), zone["tint"], 0.0)


## A facility's visual shell. The controller remains the single owner of its
## layout and hit test; all this function receives is the already-authoritative
## id and box. The returned drawing has no controls or collision objects.
static func draw_facility(parent: Node2D, id: String, box: Vector2,
		locked: bool) -> void:
	if locked:
		_draw_future_pad(parent, box)
		return

	match id:
		"seed_shop":
			_draw_seed_shop(parent, box)
		"warehouse":
			_draw_warehouse(parent, box)
		"kennel":
			_draw_kennel(parent, box)
		"well":
			_draw_well(parent, box)
		"orders":
			_draw_notice_board(parent, box, true)
		"visit_board":
			_draw_notice_board(parent, box, false)
		"gate":
			_draw_gate(parent, box)
		"bear_door":
			_draw_bear_door(parent, box)
		"market":
			_draw_market_stall(parent, box)
		"orchard":
			_draw_orchard_shed(parent, box)
		"workshop":
			_draw_workshop(parent, box)
		"decor":
			_draw_decor_pavilion(parent, box)
		_:
			_draw_hut(parent, box, _facility_style(id))


## A future bed should look like a patch of rocky grass waiting to be cleared,
## not like an inactive UI tile. Individual movable stones are still created by
## FarmWorld after this call, because those exact nodes are what scatter when a
## child expands the farm.
static func draw_future_plot(parent: Node2D, box: Vector2, index: int) -> void:
	Shapes.ground_shadow(parent, Vector2(0.0, box.y * 0.42), box.x * 0.70, 0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90_011 + index * 1_097
	Shapes.fill(parent, Shapes.blob(Vector2.ZERO,
		Vector2(box.x * 0.55, box.y * 0.59), rng, 0.08, 5, 26),
		Color(0.60, 0.72, 0.46), 0.0)
	rng.seed = 93_119 + index * 1_097
	Shapes.lit(parent, Shapes.blob(Vector2(0.0, 4.0),
		Vector2(box.x * 0.46, box.y * 0.48), rng, 0.07, 4, 24),
		Color(0.67, 0.73, 0.55), 0.34)
	for x in [-box.x * 0.35, box.x * 0.35]:
		_draw_tuft(parent, Vector2(x, box.y * 0.19), 0.75)


## The shared backer for the familiar world-space icon. Keep the meaningful
## icon in FarmWorld/UiKit; this quiet disc simply prevents it from floating in
## an empty white rectangle.
static func facility_icon_anchor(box: Vector2, id: String) -> Vector2:
	match id:
		"seed_shop", "warehouse", "market":
			return Vector2(0.0, -box.y * 0.10)
		"kennel":
			# 把爪印挂在屋檐下，入口仍保持清晰，孩子能一眼看出这里是小狗的家。
			return Vector2(0.0, -box.y * 0.24)
		"orchard", "workshop", "decor":
			return Vector2(0.0, -box.y * 0.12)
		"well":
			return Vector2(0.0, -box.y * 0.12)
		"orders", "visit_board":
			return Vector2(0.0, -box.y * 0.05)
		"gate":
			return Vector2(0.0, -box.y * 0.10)
		"bear_door":
			return Vector2(0.0, 0.0)
		_:
			return Vector2(0.0, -box.y * 0.10)


static func _clear_of_targets(at: Vector2, radius: float,
		protected: Array[Rect2]) -> bool:
	var footprint := Rect2(at - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	for target in protected:
		if footprint.intersects(target.grow(22.0)):
			return false
	return true


static func _draw_meadow_patch(parent: Node2D, at: Vector2, radii: Vector2,
		seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Shapes.fill(parent, Shapes.blob(at, radii, rng, 0.07, 4, 24),
		MEADOW_LIGHT, 0.0)
	rng.seed = seed + 1_003
	Shapes.fill(parent, Shapes.blob(at + Vector2(-8.0, -10.0), radii * 0.72,
		rng, 0.06, 4, 22), MEADOW_LIGHT.lightened(0.04), 0.0)
	for i in range(5):
		var x := at.x - radii.x * 0.46 + float(i) * radii.x * 0.22
		var y := at.y + radii.y * (0.18 + 0.12 * float(i % 2))
		_draw_tuft(parent, Vector2(x, y), 0.72 + 0.08 * float(i % 2))


## All farm paths share this deliberately soft two-tone treatment.  A route
## should gather the world into a place someone walks through, not fence the
## grass into dark, competing sections.  It is visual-only: callers retain the
## same layout, camera and target boxes beneath the drawing.
static func draw_path(parent: Node2D, points: PackedVector2Array,
		width: float) -> void:
	var outer_width := maxf(width, 1.0)
	Shapes.fill(parent, Shapes.ribbon(points, outer_width),
		Color(0.82, 0.76, 0.60), 0.0)
	Shapes.fill(parent, Shapes.ribbon(points, maxf(12.0, outer_width * 0.50)),
		Color(0.89, 0.83, 0.68), 0.0)


static func _draw_tree_cluster(parent: Node2D, at: Vector2, scale: float,
		seed: int) -> void:
	Shapes.ground_shadow(parent, at + Vector2(4.0, 46.0) * scale,
		88.0 * scale, 0.17)
	Shapes.fill(parent, Shapes.taper(at + Vector2(-7.0, 44.0) * scale,
		at + Vector2(-3.0, -10.0) * scale, 22.0 * scale, 13.0 * scale),
		WOOD_DARK, 0.74)
	Shapes.fill(parent, Shapes.taper(at + Vector2(5.0, 44.0) * scale,
		at + Vector2(18.0, -1.0) * scale, 15.0 * scale, 8.0 * scale),
		WOOD_LIGHT, 0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Shapes.lit(parent, Shapes.blob(at + Vector2(-18.0, -30.0) * scale,
		Vector2(47.0, 43.0) * scale, rng, 0.10, 4, 22), BUSH_DARK, 0.48)
	rng.seed = seed + 19
	Shapes.lit(parent, Shapes.blob(at + Vector2(22.0, -36.0) * scale,
		Vector2(50.0, 46.0) * scale, rng, 0.10, 5, 24), BUSH_MID, 0.52)
	rng.seed = seed + 37
	Shapes.lit(parent, Shapes.blob(at + Vector2(0.0, -64.0) * scale,
		Vector2(40.0, 35.0) * scale, rng, 0.09, 4, 20), BUSH_LIGHT, 0.48)


static func _draw_hedge_cluster(parent: Node2D, at: Vector2, scale: float,
		seed: int) -> void:
	Shapes.ground_shadow(parent, at + Vector2(0.0, 13.0) * scale,
		72.0 * scale, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	Shapes.lit(parent, Shapes.blob(at + Vector2(-20.0, 2.0) * scale,
		Vector2(31.0, 23.0) * scale, rng, 0.10, 4, 20), BUSH_DARK, 0.38)
	rng.seed = seed + 17
	Shapes.lit(parent, Shapes.blob(at + Vector2(5.0, -5.0) * scale,
		Vector2(37.0, 27.0) * scale, rng, 0.10, 5, 22), BUSH_MID, 0.42)
	rng.seed = seed + 29
	Shapes.fill(parent, Shapes.blob(at + Vector2(18.0, -14.0) * scale,
		Vector2(23.0, 17.0) * scale, rng, 0.08, 4, 18), BUSH_LIGHT, 0.0)


static func _draw_stone_cluster(parent: Node2D, at: Vector2, scale: float) -> void:
	Shapes.ground_shadow(parent, at + Vector2(2.0, 14.0) * scale,
		74.0 * scale, 0.14)
	for stone in [
		{"offset": Vector2(-23.0, 3.0), "radii": Vector2(19.0, 14.0)},
		{"offset": Vector2(6.0, -5.0), "radii": Vector2(24.0, 18.0)},
		{"offset": Vector2(30.0, 9.0), "radii": Vector2(15.0, 11.0)},
	]:
		var offset: Vector2 = stone["offset"] * scale
		var radii: Vector2 = stone["radii"] * scale
		Shapes.lit(parent, Shapes.oval_points(at + offset, radii), STONE, 0.45)


static func _draw_tuft(parent: Node2D, at: Vector2, scale: float) -> void:
	var tint := MEADOW_SHADE
	for x in [-7.0, 0.0, 7.0]:
		Shapes.fill(parent, PackedVector2Array([
			at + Vector2(x - 2.0, 6.0) * scale,
			at + Vector2(x, -9.0) * scale,
			at + Vector2(x + 2.5, 6.0) * scale,
		]), tint, 0.0)


static func _draw_fern_patch(parent: Node2D, at: Vector2, scale: float,
		bloom: Color) -> void:
	Shapes.ground_shadow(parent, at + Vector2(0.0, 12.0) * scale,
		44.0 * scale, 0.10)
	for offset in [Vector2(-13.0, 5.0), Vector2(0.0, -2.0), Vector2(13.0, 5.0)]:
		_draw_tuft(parent, at + offset * scale, scale)
	for offset in [Vector2(-9.0, 1.0), Vector2(10.0, 4.0)]:
		Shapes.fill(parent, Shapes.circle_points(at + offset * scale, 4.2 * scale),
			bloom, 0.0)
		Shapes.fill(parent, Shapes.circle_points(at + offset * scale, 1.6 * scale),
			Color(1.0, 0.94, 0.62), 0.0)


static func _draw_future_pad(parent: Node2D, box: Vector2) -> void:
	Shapes.fill(parent, Shapes.rounded_rect(-box * 0.5, box, 24.0),
		Color(0.63, 0.74, 0.52), 0.78)
	Shapes.fill(parent, Shapes.rounded_rect(-box * 0.5 + Vector2(9.0, 9.0),
		box - Vector2(18.0, 18.0), 20.0), Color(0.71, 0.84, 0.58), 0.0)
	# A pair of small posts says “a place is coming” more warmly than a second
	# opaque card or a lock. The controller adds the familiar faint icon above.
	for x in [-box.x * 0.30, box.x * 0.30]:
		Shapes.fill(parent, Shapes.rounded_rect(Vector2(x - 5.0, box.y * 0.10),
			Vector2(10.0, box.y * 0.24), 4.0), WOOD_LIGHT, 0.55)


static func _draw_hut(parent: Node2D, box: Vector2, style: Dictionary) -> void:
	var wall: Color = style["wall"]
	var roof: Color = style["roof"]
	var trim: Color = style["trim"]
	# Warm back wall and a darker foundation make this read as a building, not
	# a panel. The roof has a fuller overhang to be recognisable at overview.
	_draw_home_wall(parent, box, wall, trim)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.42, box.y * 0.18),
		Vector2(box.x * 0.84, box.y * 0.22), 10.0), trim.darkened(0.10), 0.70)
	_draw_home_roof(parent, box, roof)
	# A sign face makes the existing icon feel like a destination label instead
	# of a sticker placed on a blank wall.
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.10),
		Vector2(minf(46.0, box.x * 0.19), minf(38.0, box.y * 0.22)))
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.12, box.y * 0.14),
		Vector2(box.x * 0.24, box.y * 0.25), 9.0), WOOD_DARK, 0.62)
	Shapes.fill(parent, Shapes.circle_points(Vector2(box.x * 0.055, box.y * 0.26),
		3.8), Color(1.0, 0.86, 0.42), 0.0)


## A few shared building strokes keep the special destinations related to the
## ordinary huts: all roofs point up, all doors sit low, and every large icon
## gets the same warm sign backer. The difference is therefore a silhouette,
## not a random new UI language for each place.
static func _draw_home_wall(parent: Node2D, box: Vector2, wall: Color,
		trim: Color, inset: Vector2 = Vector2(7.0, 8.0)) -> void:
	var base := -box * 0.5
	Shapes.lit(parent, Shapes.rounded_rect(base + inset,
		box - Vector2(inset.x * 2.0, inset.y + 10.0), 24.0), wall, 0.84)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.42, box.y * 0.30),
		Vector2(box.x * 0.84, box.y * 0.11), 8.0), trim.darkened(0.12), 0.60)


static func _draw_home_roof(parent: Node2D, box: Vector2, roof: Color,
		peak: float = 0.86, overhang: float = 0.57) -> void:
	Shapes.fill(parent, PackedVector2Array([
		Vector2(-box.x * overhang, -box.y * 0.39),
		Vector2(0.0, -box.y * peak),
		Vector2(box.x * overhang, -box.y * 0.39),
	]), roof, 0.92)
	Shapes.fill(parent, PackedVector2Array([
		Vector2(-box.x * overhang * 0.70, -box.y * 0.43),
		Vector2(0.0, -box.y * (peak - 0.13)),
		Vector2(box.x * overhang * 0.70, -box.y * 0.43),
	]), roof.lightened(0.12), 0.0)


static func _draw_icon_backer(parent: Node2D, at: Vector2, radii: Vector2,
		fill: Color = Color(1.0, 0.96, 0.80)) -> void:
	Shapes.lit(parent, Shapes.oval_points(at, radii), fill, 0.62)


static func _draw_window(parent: Node2D, at: Vector2, box: Vector2,
		frame: Color = WOOD_DARK, glass: Color = Color(0.58, 0.79, 0.86)) -> void:
	Shapes.lit(parent, Shapes.rounded_rect(at, box, 8.0), frame, 0.55)
	Shapes.fill(parent, Shapes.rounded_rect(at + Vector2(5.0, 5.0),
		box - Vector2(10.0, 10.0), 5.0), glass, 0.0)


static func _draw_crate(parent: Node2D, at: Vector2, size: float,
		tint: Color = WOOD_LIGHT) -> void:
	var box := Vector2(size, size * 0.76)
	Shapes.lit(parent, Shapes.rounded_rect(at - box * 0.5, box, 5.0), tint, 0.52)
	Shapes.fill(parent, Shapes.taper(at + Vector2(-box.x * 0.34, -box.y * 0.29),
		at + Vector2(box.x * 0.34, box.y * 0.29), 4.0, 4.0),
		WOOD_DARK.lightened(0.08), 0.0)
	Shapes.fill(parent, Shapes.taper(at + Vector2(box.x * 0.34, -box.y * 0.29),
		at + Vector2(-box.x * 0.34, box.y * 0.29), 4.0, 4.0),
		WOOD_DARK.lightened(0.08), 0.0)


## 种子店不用再只是“另一间颜色不同的小屋”：门口的条纹遮阳棚、
## 两盒种子和圆招牌共同形成“可以买、能种”的轮廓。真正可点击的盒子
## 仍由 FarmWorld 的既有 layout 决定，下面全部只是被动的画笔。
static func _draw_seed_shop(parent: Node2D, box: Vector2) -> void:
	var wall := Color(0.98, 0.89, 0.61)
	var roof := Color(0.86, 0.48, 0.29)
	var trim := Color(0.72, 0.51, 0.27)
	_draw_home_wall(parent, box, wall, trim, Vector2(9.0, 16.0))
	_draw_home_roof(parent, box, roof, 0.88, 0.60)
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.10),
		Vector2(minf(47.0, box.x * 0.20), minf(37.0, box.y * 0.22)))
	# A low canopy reads at overview before its fine seed-packet detail does.
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.47, box.y * 0.03),
		Vector2(box.x * 0.94, box.y * 0.18), 8.0), Color(0.98, 0.76, 0.45), 0.70)
	for i in range(5):
		var stripe_x := -box.x * 0.42 + float(i) * box.x * 0.19
		if i % 2 == 0:
			Shapes.fill(parent, Shapes.rounded_rect(Vector2(stripe_x, box.y * 0.045),
				Vector2(box.x * 0.15, box.y * 0.15), 5.0), roof, 0.0)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.13, box.y * 0.19),
		Vector2(box.x * 0.26, box.y * 0.22), 8.0), WOOD_DARK, 0.62)
	Shapes.fill(parent, Shapes.circle_points(Vector2(box.x * 0.055, box.y * 0.29),
		3.8), Color(1.0, 0.86, 0.42), 0.0)
	_draw_crate(parent, Vector2(-box.x * 0.34, box.y * 0.30), 30.0,
		Color(0.88, 0.67, 0.35))
	_draw_crate(parent, Vector2(box.x * 0.34, box.y * 0.30), 26.0,
		Color(0.81, 0.58, 0.31))
	for x in [-box.x * 0.34, box.x * 0.34]:
		Shapes.fill(parent, Shapes.oval_points(Vector2(x, box.y * 0.24),
			Vector2(7.0, 4.5)), Color(0.44, 0.69, 0.32), 0.0)


## 仓库刻意采用更宽、更低的谷仓轮廓。双门和外放木箱能够让还不会读
## “仓库”二字的孩子，也把篮子和“收好的东西在这里”对应起来。
static func _draw_warehouse(parent: Node2D, box: Vector2) -> void:
	var wall := Color(0.95, 0.79, 0.56)
	var roof := Color(0.62, 0.36, 0.24)
	var trim := Color(0.58, 0.37, 0.22)
	_draw_home_wall(parent, box, wall, trim, Vector2(8.0, 13.0))
	_draw_home_roof(parent, box, roof, 0.82, 0.61)
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.10),
		Vector2(minf(48.0, box.x * 0.20), minf(36.0, box.y * 0.22)),
		Color(1.0, 0.91, 0.66))
	# Split doors create the barn silhouette even after the basket icon covers
	# the sign; their diagonal braces survive at small zoom.
	for side in [-1.0, 1.0]:
		var door_box := Vector2(box.x * 0.19, box.y * 0.28)
		var door_at := Vector2(side * box.x * 0.015 - door_box.x * 0.5,
			box.y * 0.12)
		if side < 0.0:
			door_at.x -= door_box.x * 0.50
		else:
			door_at.x += door_box.x * 0.50
		Shapes.lit(parent, Shapes.rounded_rect(door_at, door_box, 7.0), trim, 0.62)
		Shapes.fill(parent, Shapes.taper(door_at + Vector2(7.0, 7.0),
			door_at + door_box - Vector2(7.0, 7.0), 4.0, 4.0),
			WOOD_LIGHT, 0.0)
	_draw_crate(parent, Vector2(-box.x * 0.36, box.y * 0.31), 32.0,
		Color(0.76, 0.52, 0.29))
	_draw_crate(parent, Vector2(box.x * 0.37, box.y * 0.32), 27.0,
		Color(0.84, 0.61, 0.33))


## 狗屋保持比仓库更矮、更圆，深色拱门和屋檐下的爪印是第一眼的
## 识别点；不会把它误读成又一间可以种菜的商店。
static func _draw_kennel(parent: Node2D, box: Vector2) -> void:
	var wall := Color(0.93, 0.76, 0.50)
	var roof := Color(0.72, 0.36, 0.27)
	var trim := Color(0.61, 0.40, 0.25)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.42, -box.y * 0.13),
		Vector2(box.x * 0.84, box.y * 0.55), 28.0), wall, 0.84)
	_draw_home_roof(parent, box, roof, 0.92, 0.50)
	# The little tag is intentionally above the entrance, leaving the doorway
	# readable when UiKit draws the existing paw icon over this backer.
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.24),
		Vector2(minf(38.0, box.x * 0.16), minf(28.0, box.y * 0.17)),
		Color(1.0, 0.92, 0.67))
	Shapes.fill(parent, Shapes.oval_points(Vector2(0.0, box.y * 0.20),
		Vector2(box.x * 0.18, box.y * 0.25)), Color(0.28, 0.23, 0.24), 0.64)
	Shapes.fill(parent, Shapes.oval_points(Vector2(0.0, box.y * 0.23),
		Vector2(box.x * 0.11, box.y * 0.17)), Color(0.39, 0.29, 0.25), 0.0)
	# A bright bowl is a simple, non-text clue that this is a friend’s space.
	Shapes.lit(parent, Shapes.oval_points(Vector2(-box.x * 0.30, box.y * 0.32),
		Vector2(18.0, 9.0)), Color(0.46, 0.70, 0.87), 0.42)
	Shapes.fill(parent, Shapes.oval_points(Vector2(-box.x * 0.30, box.y * 0.30),
		Vector2(12.0, 4.5)), Color(0.88, 0.95, 0.99), 0.0)


## 市集以横向的摊棚代替第四个尖顶小屋，条纹篷布和两只篮子把它和
## “买种子”的种子店区分开来。
static func _draw_market_stall(parent: Node2D, box: Vector2) -> void:
	var wall := Color(0.99, 0.83, 0.64)
	var roof := Color(0.78, 0.40, 0.34)
	var trim := Color(0.70, 0.43, 0.29)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.45, -box.y * 0.12),
		Vector2(box.x * 0.90, box.y * 0.53), 20.0), wall, 0.78)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.51, -box.y * 0.47),
		Vector2(box.x * 1.02, box.y * 0.26), 14.0), roof, 0.84)
	for i in range(6):
		if i % 2 == 0:
			Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.43
				+ float(i) * box.x * 0.145, -box.y * 0.43),
				Vector2(box.x * 0.105, box.y * 0.18), 5.0),
				Color(1.0, 0.90, 0.67), 0.0)
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.10),
		Vector2(minf(46.0, box.x * 0.19), minf(34.0, box.y * 0.20)),
		Color(1.0, 0.94, 0.75))
	for x in [-box.x * 0.30, box.x * 0.30]:
		Shapes.lit(parent, Shapes.oval_points(Vector2(x, box.y * 0.29),
			Vector2(19.0, 11.0)), trim, 0.44)
		Shapes.fill(parent, Shapes.oval_points(Vector2(x, box.y * 0.255),
			Vector2(13.0, 5.0)), Color(0.71, 0.84, 0.47), 0.0)


static func _draw_orchard_shed(parent: Node2D, box: Vector2) -> void:
	var wall := Color(0.87, 0.92, 0.64)
	var roof := Color(0.43, 0.64, 0.34)
	var trim := Color(0.45, 0.52, 0.26)
	_draw_home_wall(parent, box, wall, trim, Vector2(10.0, 14.0))
	_draw_home_roof(parent, box, roof, 0.81, 0.55)
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.12),
		Vector2(minf(42.0, box.x * 0.18), minf(32.0, box.y * 0.22)),
		Color(0.95, 0.98, 0.77))
	for x in [-box.x * 0.32, box.x * 0.32]:
		Shapes.lit(parent, Shapes.circle_points(Vector2(x, box.y * 0.18), 18.0),
			BUSH_MID, 0.46)
		Shapes.fill(parent, Shapes.circle_points(Vector2(x + 5.0, box.y * 0.18),
			4.5), Color(0.95, 0.47, 0.36), 0.0)


static func _draw_workshop(parent: Node2D, box: Vector2) -> void:
	var wall := Color(0.78, 0.88, 0.91)
	var roof := Color(0.39, 0.60, 0.72)
	var trim := Color(0.34, 0.48, 0.58)
	_draw_home_wall(parent, box, wall, trim, Vector2(9.0, 12.0))
	_draw_home_roof(parent, box, roof, 0.78, 0.55)
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.12),
		Vector2(minf(42.0, box.x * 0.18), minf(32.0, box.y * 0.22)),
		Color(0.85, 0.95, 0.98))
	_draw_window(parent, Vector2(-box.x * 0.34, box.y * 0.05),
		Vector2(box.x * 0.19, box.y * 0.20), trim)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(box.x * 0.13, box.y * 0.09),
		Vector2(box.x * 0.20, box.y * 0.26), 7.0), trim.darkened(0.08), 0.62)
	Shapes.fill(parent, Shapes.taper(Vector2(box.x * 0.17, box.y * 0.13),
		Vector2(box.x * 0.29, box.y * 0.30), 4.0, 4.0), WOOD_LIGHT, 0.0)


static func _draw_decor_pavilion(parent: Node2D, box: Vector2) -> void:
	var roof := Color(0.66, 0.46, 0.72)
	var rail := Color(0.57, 0.37, 0.62)
	Shapes.ground_shadow(parent, Vector2(0.0, box.y * 0.35), box.x * 0.72, 0.14)
	for x in [-box.x * 0.30, box.x * 0.30]:
		Shapes.lit(parent, Shapes.rounded_rect(Vector2(x - 8.0, -box.y * 0.20),
			Vector2(16.0, box.y * 0.57), 6.0), Color(0.93, 0.80, 0.93), 0.62)
	_draw_home_roof(parent, box, roof, 0.92, 0.53)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.42, box.y * 0.21),
		Vector2(box.x * 0.84, box.y * 0.14), 8.0), rail, 0.62)
	_draw_icon_backer(parent, Vector2(0.0, -box.y * 0.12),
		Vector2(minf(39.0, box.x * 0.18), minf(28.0, box.y * 0.22)),
		Color(0.98, 0.89, 1.0))
	for x in [-box.x * 0.14, box.x * 0.14]:
		Shapes.fill(parent, Shapes.circle_points(Vector2(x, box.y * 0.12), 6.0),
			Color(1.0, 0.84, 0.50), 0.0)


static func _draw_well(parent: Node2D, box: Vector2) -> void:
	Shapes.ground_shadow(parent, Vector2(0.0, box.y * 0.34), box.x * 0.68, 0.20)
	Shapes.lit(parent, Shapes.oval_points(Vector2(0.0, box.y * 0.10),
		Vector2(box.x * 0.34, box.y * 0.22)), Color(0.67, 0.75, 0.75), 0.82)
	Shapes.fill(parent, Shapes.oval_points(Vector2(0.0, box.y * 0.04),
		Vector2(box.x * 0.25, box.y * 0.13)), Color(0.28, 0.52, 0.66), 0.66)
	for x in [-box.x * 0.27, box.x * 0.27]:
		Shapes.lit(parent, Shapes.rounded_rect(Vector2(x - 7.0, -box.y * 0.40),
			Vector2(14.0, box.y * 0.55), 5.0), WOOD_LIGHT, 0.62)
	Shapes.fill(parent, PackedVector2Array([
		Vector2(-box.x * 0.46, -box.y * 0.36),
		Vector2(0.0, -box.y * 0.70),
		Vector2(box.x * 0.46, -box.y * 0.36),
	]), Color(0.45, 0.68, 0.76), 0.84)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.18, -box.y * 0.51),
		Vector2(box.x * 0.36, 10.0), 5.0), Color(0.78, 0.92, 0.96), 0.0)


static func _draw_notice_board(parent: Node2D, box: Vector2, warm: bool) -> void:
	Shapes.ground_shadow(parent, Vector2(0.0, box.y * 0.39), box.x * 0.74, 0.18)
	for x in [-box.x * 0.30, box.x * 0.30]:
		Shapes.fill(parent, Shapes.rounded_rect(Vector2(x - 8.0, -box.y * 0.12),
			Vector2(16.0, box.y * 0.58), 6.0), WOOD_DARK, 0.72)
	var board := Color(0.83, 0.57, 0.31) if warm else Color(0.65, 0.48, 0.30)
	Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.44, -box.y * 0.48),
		Vector2(box.x * 0.88, box.y * 0.62), 18.0), board, 0.88)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.32, -box.y * 0.36),
		Vector2(box.x * 0.64, box.y * 0.37), 12.0), Color(1.0, 0.95, 0.78), 0.54)
	if warm:
		# The orders board receives a little red delivery pennant and three
		# check rows. The central heart icon remains owned by UiKit, while the
		# edge rhythm still says “several small jobs are waiting here”.
		Shapes.lit(parent, Shapes.rounded_rect(Vector2(-box.x * 0.39, -box.y * 0.59),
			Vector2(box.x * 0.78, box.y * 0.13), 8.0), Color(0.88, 0.40, 0.31), 0.66)
		for i in range(3):
			var row_y := -box.y * 0.23 + float(i) * box.y * 0.105
			Shapes.fill(parent, Shapes.circle_points(Vector2(-box.x * 0.24, row_y),
				4.5), Color(0.52, 0.72, 0.38), 0.0)
			Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.17, row_y - 3.0),
				Vector2(box.x * 0.18, 6.0), 3.0), Color(0.77, 0.59, 0.36), 0.0)
		Shapes.fill(parent, PackedVector2Array([
			Vector2(box.x * 0.34, -box.y * 0.48),
			Vector2(box.x * 0.50, -box.y * 0.42),
			Vector2(box.x * 0.34, -box.y * 0.35),
		]), Color(0.96, 0.62, 0.42), 0.56)
	else:
		# The friend-visit board is calmer: blue pins and flower dots make it
		# feel like a message board, not a second order queue.
		for pin in [Vector2(-box.x * 0.23, -box.y * 0.29),
				Vector2(box.x * 0.23, -box.y * 0.29)]:
			Shapes.fill(parent, Shapes.circle_points(pin, 5.0),
				Color(0.55, 0.72, 0.92), 0.0)
		for x in [-box.x * 0.17, box.x * 0.17]:
			Shapes.fill(parent, Shapes.circle_points(Vector2(x, -box.y * 0.07),
				5.0), Color(0.94, 0.64, 0.75), 0.0)
			Shapes.fill(parent, Shapes.circle_points(Vector2(x, -box.y * 0.07),
				1.8), Color(1.0, 0.91, 0.54), 0.0)


static func _draw_gate(parent: Node2D, box: Vector2) -> void:
	Shapes.ground_shadow(parent, Vector2(0.0, box.y * 0.40), box.x * 0.92, 0.18)
	for x in [-box.x * 0.38, box.x * 0.38]:
		Shapes.lit(parent, Shapes.rounded_rect(Vector2(x - 12.0, -box.y * 0.45),
			Vector2(24.0, box.y * 0.82), 10.0), WOOD_LIGHT, 0.74)
		Shapes.fill(parent, Shapes.circle_points(Vector2(x, -box.y * 0.48), 17.0),
			Color(0.96, 0.78, 0.38), 0.62)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.39, -box.y * 0.16),
		Vector2(box.x * 0.78, 18.0), 8.0), WOOD_DARK, 0.78)
	Shapes.fill(parent, Shapes.rounded_rect(Vector2(-box.x * 0.23, box.y * 0.08),
		Vector2(box.x * 0.46, 14.0), 7.0), Color(0.56, 0.72, 0.43), 0.54)


static func _draw_bear_door(parent: Node2D, box: Vector2) -> void:
	Shapes.ground_shadow(parent, Vector2(0.0, box.y * 0.40), box.x * 0.82, 0.18)
	Shapes.lit(parent, Shapes.oval_points(Vector2(0.0, -box.y * 0.03),
		Vector2(box.x * 0.46, box.y * 0.58)), Color(0.52, 0.42, 0.36), 0.84)
	Shapes.fill(parent, Shapes.oval_points(Vector2(0.0, box.y * 0.04),
		Vector2(box.x * 0.26, box.y * 0.38)), Color(0.23, 0.26, 0.30), 0.58)
	Shapes.fill(parent, Shapes.circle_points(Vector2(-box.x * 0.31, -box.y * 0.40),
		box.y * 0.12), Color(0.63, 0.51, 0.40), 0.54)
	Shapes.fill(parent, Shapes.circle_points(Vector2(box.x * 0.31, -box.y * 0.40),
		box.y * 0.12), Color(0.63, 0.51, 0.40), 0.54)


static func _facility_style(id: String) -> Dictionary:
	match id:
		"seed_shop":
			return {"wall": Color(0.98, 0.89, 0.61), "roof": Color(0.86, 0.48, 0.29), "trim": Color(0.72, 0.51, 0.27)}
		"warehouse":
			return {"wall": Color(0.95, 0.79, 0.56), "roof": Color(0.62, 0.36, 0.24), "trim": Color(0.58, 0.37, 0.22)}
		"kennel":
			return {"wall": Color(0.93, 0.76, 0.50), "roof": Color(0.72, 0.36, 0.27), "trim": Color(0.61, 0.40, 0.25)}
		"market":
			return {"wall": Color(0.99, 0.83, 0.64), "roof": Color(0.78, 0.40, 0.34), "trim": Color(0.70, 0.43, 0.29)}
		"orchard":
			return {"wall": Color(0.87, 0.92, 0.64), "roof": Color(0.43, 0.64, 0.34), "trim": Color(0.45, 0.52, 0.26)}
		"workshop":
			return {"wall": Color(0.78, 0.88, 0.91), "roof": Color(0.39, 0.60, 0.72), "trim": Color(0.34, 0.48, 0.58)}
		"decor":
			return {"wall": Color(0.93, 0.80, 0.93), "roof": Color(0.66, 0.46, 0.72), "trim": Color(0.57, 0.37, 0.62)}
		_:
			return {"wall": Color(0.96, 0.87, 0.65), "roof": Color(0.80, 0.48, 0.34), "trim": Color(0.65, 0.43, 0.28)}
