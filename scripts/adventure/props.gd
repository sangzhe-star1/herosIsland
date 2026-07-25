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


## The teaching hand: a translucent finger that taps where the child should.
## Used for the opening beat of a level and for the demo after two failures.
static func hint_hand(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	node.modulate = Color(1, 1, 1, 0.85)
	var art := Node2D.new()
	node.add_child(art)
	Shapes.fill(art, Shapes.rounded_rect(Vector2(-9.0, -54.0), Vector2(18.0, 46.0), 8.0),
		Color(0.98, 0.82, 0.66), 0.7)
	Shapes.lit(art, Shapes.circle_points(Vector2(6.0, 4.0), 20.0, 16),
		Color(0.98, 0.82, 0.66), 0.9)
	if Juice.motion_enabled():
		var t := art.create_tween().set_loops()
		t.tween_property(art, "position:y", -18.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(art, "position:y", 0.0, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_interval(0.5)
	return node
