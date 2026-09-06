class_name AdventureProps
extends RefCounted
## Everything an adventure level puts in the world that is not ground.
##
## Drawing only. Each function builds a Node2D at the origin and hands it
## back; the level owns where it sits and what it means. Kept apart from the
## template for the same reason `Shapes` is kept apart from everything: a
## chest drawn six months from now cannot come out in a different style
## because there is no other place to draw one.
##
## All of it goes through `Shapes`, so the ink, the light direction and the
## contact shadows match the ground it stands on and the hero standing next
## to it.
##
## ONE RULE, learned the hard way: anything that animates its own position
## animates a CHILD node, never the root. `Juice.idle_bob` captures the node's
## position when it is called, and a prop is drawn before the level knows
## where to put it -- so bobbing the root made every orb in the level tween
## itself back to world (0, 0) and vanish. Use `_bobber()`.

const GOLD := Color(1.0, 0.84, 0.34)
const WOOD := Color(0.62, 0.44, 0.28)
const STONE := Color(0.56, 0.58, 0.68)


## An inner node that is safe to animate: its origin really is zero, and it
## stays zero however the level moves the prop it hangs from.
static func _bobber(parent: Node2D, height: float, period: float) -> Node2D:
	var inner := Node2D.new()
	parent.add_child(inner)
	Juice.idle_bob(inner, height, period)
	return inner


## An energy orb: the thing the child is usually collecting. Bobs gently so
## it reads as "alive and waiting", not as scenery.
static func orb(parent: Node, tint: Color = Color(0.42, 0.86, 1.0)) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	var art := _bobber(node, 9.0, 1.5)
	Shapes.glow(art, Vector2.ZERO, 74.0, tint, 4, 0.42)
	Shapes.lit(art, Shapes.circle_points(Vector2.ZERO, 26.0, 20), tint, 0.9)
	Shapes.fill(art, Shapes.oval_points(Vector2(-8.0, -9.0), Vector2(8.0, 6.0), 12),
		Color(1, 1, 1, 0.65), 0.0)
	return node


## The hidden gem: one per level, worth the second star. Drawn as treasure
## rather than as a question mark, because a reward a child cannot picture
## is a reward they will not go looking for.
static func gem(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	var art := _bobber(node, 11.0, 1.9)
	Shapes.glow(art, Vector2.ZERO, 92.0, Color(0.98, 0.52, 0.86), 5, 0.40)
	Shapes.lit(art, PackedVector2Array([
		Vector2(0, -34.0), Vector2(24.0, -8.0), Vector2(14.0, 30.0),
		Vector2(-14.0, 30.0), Vector2(-24.0, -8.0),
	]), Color(0.96, 0.44, 0.78), 1.0)
	Shapes.fill(art, PackedVector2Array([
		Vector2(0, -34.0), Vector2(24.0, -8.0), Vector2(0, -2.0),
	]), Color(1, 1, 1, 0.35), 0.0)
	return node


## A floor switch. Unpressed it stands proud with a warm light; pressed it
## sinks and turns green. Both states are obvious from across the screen.
static func floor_switch(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 120.0, 0.20)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-52.0, -22.0), Vector2(104.0, 22.0), 8.0),
		STONE.darkened(0.18), 1.0)
	var plate := Node2D.new()
	plate.position = Vector2(0, -22.0)
	node.add_child(plate)
	Shapes.lit(plate, Shapes.rounded_rect(Vector2(-42.0, -20.0), Vector2(84.0, 22.0), 9.0),
		Color(0.94, 0.72, 0.30), 1.0)
	Shapes.glow(plate, Vector2(0, -10.0), 64.0, Color(1.0, 0.88, 0.44), 3, 0.34)
	return {"node": node, "plate": plate}


## A gate that the switch opens. Two stone leaves and a gold keyhole ring;
## opening slides them apart rather than fading them out, because a door
## that dissolves does not read as a door that opened.
static func gate(parent: Node, height: float = 210.0) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	var left := Node2D.new()
	var right := Node2D.new()
	node.add_child(left)
	node.add_child(right)
	for side_node in [left, right]:
		var side: float = -1.0 if side_node == left else 1.0
		Shapes.lit(side_node, Shapes.rounded_rect(
			Vector2(side * 4.0 - (34.0 if side < 0.0 else 0.0), -height),
			Vector2(34.0, height), 6.0), STONE, 1.0)
		for band in range(3):
			Shapes.fill(side_node, Shapes.rounded_rect(
				Vector2(side * 4.0 - (30.0 if side < 0.0 else -4.0),
					-height + 24.0 + float(band) * height * 0.3),
				Vector2(26.0, 10.0), 3.0), STONE.darkened(0.22), 0.0)
	Shapes.lit(node, Shapes.circle_points(Vector2(0, -height * 0.52), 20.0, 16), GOLD, 0.9)
	Shapes.fill(node, Shapes.circle_points(Vector2(0, -height * 0.52), 8.0, 12),
		Color(0.30, 0.24, 0.18), 0.0)
	return {"node": node, "left": left, "right": right}


## The reward chest. Closed it is a promise; open it is a party.
static func chest(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 150.0, 0.22)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-56.0, -58.0), Vector2(112.0, 58.0), 8.0),
		WOOD, 1.0)
	Shapes.fill(node, Shapes.rounded_rect(Vector2(-56.0, -34.0), Vector2(112.0, 12.0), 4.0),
		GOLD, 0.0)
	var lid := Node2D.new()
	lid.position = Vector2(0, -58.0)
	node.add_child(lid)
	var dome := PackedVector2Array()
	for i in range(13):
		var a: float = PI + PI * float(i) / 12.0
		dome.append(Vector2(cos(a) * 56.0, sin(a) * 34.0))
	dome.append(Vector2(56.0, 2.0))
	dome.append(Vector2(-56.0, 2.0))
	Shapes.lit(lid, dome, WOOD.lightened(0.10), 1.0)
	Shapes.fill(lid, Shapes.rounded_rect(Vector2(-12.0, -14.0), Vector2(24.0, 22.0), 5.0),
		GOLD, 0.0)
	return {"node": node, "lid": lid}


## A checkpoint flag. Plants itself, waves, and glows once it is yours.
static func checkpoint(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 96.0, 0.18)
	Shapes.fill(node, Shapes.taper(Vector2.ZERO, Vector2(0, -150.0), 8.0, 5.0),
		WOOD.darkened(0.10), 0.9)
	var flag := Node2D.new()
	flag.position = Vector2(2.0, -146.0)
	node.add_child(flag)
	Shapes.lit(flag, PackedVector2Array([
		Vector2(0, 0), Vector2(64.0, 12.0), Vector2(48.0, 24.0),
		Vector2(64.0, 36.0), Vector2(0, 46.0),
	]), Color(0.60, 0.64, 0.74), 1.0)
	return {"node": node, "flag": flag}


## A bounce pad. Stepping on it throws you higher than any jump can reach,
## which is how the high shelves and the hidden gem stay reachable without
## asking a six-year-old for a precise double jump.
##
## Returned as a dictionary because the cap squashes on contact -- the hero
## controller holds onto it and animates it, so the bounce has a cause the
## child can see rather than being a surprise the floor does to them.
static func spring(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 130.0, 0.20)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-56.0, -18.0), Vector2(112.0, 18.0), 7.0),
		STONE.darkened(0.14), 1.0)
	# The coil, drawn as three stacked bands so the squash reads as a spring
	# compressing rather than a box shrinking.
	for i in range(3):
		Shapes.fill(node, Shapes.rounded_rect(
			Vector2(-38.0, -34.0 - float(i) * 13.0), Vector2(76.0, 10.0), 5.0),
			Color(0.86, 0.86, 0.92).darkened(0.06 * float(i)), 0.0)
	var cap := Node2D.new()
	cap.position = Vector2(0, -72.0)
	node.add_child(cap)
	Shapes.lit(cap, Shapes.rounded_rect(Vector2(-58.0, -20.0), Vector2(116.0, 24.0), 11.0),
		Color(0.98, 0.56, 0.44), 1.0)
	Shapes.fill(cap, PackedVector2Array([
		Vector2(-16.0, -4.0), Vector2(0, -16.0), Vector2(16.0, -4.0),
	]), Color(1.0, 0.92, 0.72), 0.0)
	return {"node": node, "cap": cap}


## A pushable crate: the simplest physical puzzle there is, and the one a
## six-year-old invents uses for on their own.
static func crate(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 118.0, 0.20)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-46.0, -92.0), Vector2(92.0, 92.0), 8.0),
		WOOD, 1.0)
	for line in [Vector2(-46.0, -50.0), Vector2(-46.0, -6.0)]:
		Shapes.fill(node, Shapes.rounded_rect(line, Vector2(92.0, 8.0), 3.0),
			WOOD.darkened(0.18), 0.0)
	Shapes.fill(node, Shapes.taper(Vector2(-40.0, -86.0), Vector2(40.0, -6.0), 7.0, 7.0),
		WOOD.lightened(0.08), 0.0)
	return node


# --- hazards ---------------------------------------------------------------
#
# The one law of every hazard on the island: IT WARNS FIRST, in the exact
# place it is about to hurt. Difficulty may shorten the warning; nothing may
# remove it. A danger that arrives unannounced teaches a six-year-old that
# the game is out to get them, and after that no amount of charm gets the
# trust back.

## The warning half of a falling rock: a ground shadow that grows from
## nothing to full size while the rock is still "far away". The level scales
## this node from 0 to 1 over the warning time, so the SIZE of the shadow is
## the countdown -- readable at any age, no numbers anywhere.
static func rock_shadow(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.fill(node, Shapes.oval_points(Vector2.ZERO, Vector2(64.0, 16.0), 22),
		Color(0.08, 0.10, 0.16, 0.42), 0.0)
	var ring := Line2D.new()
	ring.points = Shapes.oval_points(Vector2.ZERO, Vector2(64.0, 16.0), 26)
	ring.closed = true
	ring.width = 5.0
	ring.default_color = Color(0.95, 0.45, 0.35, 0.85)
	ring.antialiased = true
	node.add_child(ring)
	return node


## The rock itself. Round enough to read as "boulder", craggy enough not to
## read as "ball" -- a ball is something a child runs TOWARD.
static func boulder(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.lit(node, PackedVector2Array([
		Vector2(-40.0, 10.0), Vector2(-34.0, -22.0), Vector2(-10.0, -40.0),
		Vector2(22.0, -34.0), Vector2(40.0, -8.0), Vector2(30.0, 22.0),
		Vector2(-6.0, 30.0),
	]), Color(0.58, 0.56, 0.62), 1.0)
	Shapes.fill(node, PackedVector2Array([
		Vector2(-18.0, -10.0), Vector2(-4.0, -22.0), Vector2(6.0, -8.0),
	]), Color(0.70, 0.68, 0.74), 0.0)
	return node


## A fire vent: a stone grate that idles cold, blushes red as the warning,
## then throws a flame column. The level owns the timing; this hands back the
## three parts it animates.
static func fire_vent(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 110.0, 0.18)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-48.0, -16.0), Vector2(96.0, 16.0), 7.0),
		STONE.darkened(0.24), 1.0)
	for slot in range(3):
		Shapes.fill(node, Shapes.rounded_rect(
			Vector2(-32.0 + float(slot) * 24.0, -12.0), Vector2(14.0, 8.0), 3.0),
			Color(0.16, 0.14, 0.18), 0.0)

	# The warning: a red glow pooled ON THE GROUND, where the flame will be.
	var glow := Node2D.new()
	node.add_child(glow)
	Shapes.glow(glow, Vector2(0, -10.0), 96.0, Color(1.0, 0.42, 0.22), 4, 0.5)
	glow.modulate.a = 0.0

	# The flame column: three licks of fire, hidden until it blows.
	var flame := Node2D.new()
	flame.position = Vector2(0, -16.0)
	node.add_child(flame)
	Shapes.glow(flame, Vector2(0, -70.0), 120.0, Color(1.0, 0.60, 0.25), 4, 0.5)
	for lick in [[-20.0, 96.0, Color(1.0, 0.55, 0.20)], [0.0, 140.0, Color(1.0, 0.72, 0.28)],
			[20.0, 88.0, Color(1.0, 0.55, 0.20)]]:
		Shapes.fill(flame, PackedVector2Array([
			Vector2(float(lick[0]) - 16.0, 0.0),
			Vector2(float(lick[0]) + rng_wobble(lick[0]), -float(lick[1])),
			Vector2(float(lick[0]) + 16.0, 0.0),
		]), lick[2], 0.0)
	Shapes.fill(flame, PackedVector2Array([
		Vector2(-8.0, 0.0), Vector2(0.0, -64.0), Vector2(8.0, 0.0),
	]), Color(1.0, 0.92, 0.55), 0.0)
	flame.visible = false
	return {"node": node, "glow": glow, "flame": flame}


## A tiny deterministic wiggle so three flame tips are not identical, without
## dragging a whole RNG through the drawing call.
static func rng_wobble(seed_val: float) -> float:
	return fmod(absf(seed_val) * 7.31, 9.0) - 4.5


## One plate of a step-in-order puzzle, wearing its position in the sequence
## as a pattern of DOTS -- one, two, three -- never a written digit. Lit cyan
## while waiting, green once stepped in the right turn.
static func seq_plate(parent: Node, dots: int) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 130.0, 0.20)
	# A chunky plinth, so the plate reads as a machine standing on the path
	# rather than a puddle painted on it. The first version was 18 px tall
	# with 5 px dots and vanished into the grass in a screenshot.
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-54.0, -30.0), Vector2(108.0, 30.0), 9.0),
		STONE.darkened(0.16), 1.0)
	var lamp := Node2D.new()
	lamp.position = Vector2(0, -30.0)
	node.add_child(lamp)
	Shapes.glow(lamp, Vector2(0, -14.0), 84.0, Color(0.45, 0.86, 1.0), 4, 0.42)
	Shapes.lit(lamp, Shapes.rounded_rect(Vector2(-46.0, -30.0), Vector2(92.0, 30.0), 10.0),
		Color(0.45, 0.86, 1.0), 0.9)
	# The count, as dots a child can read across the screen -- never a digit.
	var spots := [[Vector2.ZERO], [Vector2(-17.0, 0.0), Vector2(17.0, 0.0)],
		[Vector2(-26.0, 0.0), Vector2.ZERO, Vector2(26.0, 0.0)],
		[Vector2(-30.0, 0.0), Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Vector2(30.0, 0.0)]]
	for spot in spots[clampi(dots, 1, 4) - 1]:
		var centre: Vector2 = (spot as Vector2) + Vector2(0, -15.0)
		Shapes.fill(lamp, Shapes.circle_points(centre, 9.0, 14),
			Color(0.05, 0.10, 0.24), 0.0)
		Shapes.fill(lamp, Shapes.circle_points(centre + Vector2(-2.0, -2.5), 3.4, 10),
			Color(1, 1, 1, 0.55), 0.0)
	return {"node": node, "lamp": lamp}


## The question post: where a knowledge card lives in the world. A wooden
## sign with three little coloured tiles -- the picture of "a small quiz",
## with not a word on it.
static func puzzle_sign(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 100.0, 0.18)
	Shapes.fill(node, Shapes.taper(Vector2.ZERO, Vector2(0, -120.0), 9.0, 6.0),
		WOOD.darkened(0.08), 0.9)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-58.0, -196.0), Vector2(116.0, 84.0), 12.0),
		WOOD.lightened(0.10), 1.0)
	var tints := [Color(0.95, 0.45, 0.40), Color(1.0, 0.85, 0.35), Color(0.45, 0.75, 0.98)]
	for i in range(3):
		Shapes.fill(node, Shapes.rounded_rect(
			Vector2(-44.0 + float(i) * 32.0, -182.0), Vector2(24.0, 24.0), 7.0),
			tints[i], 0.0)
	Shapes.glow(node, Vector2(0, -240.0), 60.0, Color(1.0, 0.95, 0.70), 3, 0.4)
	return node


## The teaching hand: the same contact-anchored hero glove used by every
## tutorial. Used for the opening beat of a level and after two failures.
static func hint_hand(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	node.modulate = Color(1, 1, 1, 0.85)
	var art := UiKit.guide_hand(88.0)
	if art == null:
		return node
	node.add_child(art)
	if Juice.motion_enabled():
		var rest_y := art.position.y
		var t := art.create_tween().set_loops()
		t.tween_property(art, "position:y", rest_y - 18.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(art, "position:y", rest_y, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_interval(0.5)
	return node
