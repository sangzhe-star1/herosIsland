class_name AdventureEnemies
extends RefCounted
## Everything on the island that can hurt you and be hurt back.
##
## Drawing and state shape only -- the level owns the clock, the same way it
## does for the props. Kept here so a monster drawn for world five cannot
## come out in a different style from the one in world one.
##
## THE LAW, and it has no exceptions: an enemy telegraphs before it attacks.
## It flashes, it winds up, it goes still, and only then does it do the thing.
## The window is tuned so a six-year-old who is LOOKING can always get out of
## the way, and shortened -- never removed -- by difficulty. A monster that
## can hurt you without warning teaches a child that watching does not pay,
## and after that they stop watching.
##
## The second law: nothing here dies. A beaten monster sits down, rubs its
## head and waves. The child won; nobody was killed.

const ROCK := Color(0.58, 0.56, 0.64)
const GOO := Color(0.55, 0.82, 0.42)
const EYE := Color(0.10, 0.13, 0.22)


## The plain patrol monster: a rounded pebble-body with two feet and a big
## friendly-but-grumpy face. One heart. Walks between two posts and turns
## round when it gets there.
static func walker(parent: Node, tint: Color = ROCK) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 118.0, 0.20)

	# A body node the level can squash without disturbing the shadow.
	var body := Node2D.new()
	node.add_child(body)
	Shapes.lit(body, PackedVector2Array([
		Vector2(-46.0, 0.0), Vector2(-40.0, -46.0), Vector2(-14.0, -70.0),
		Vector2(20.0, -68.0), Vector2(44.0, -40.0), Vector2(46.0, 0.0),
	]), tint, 1.0)
	for foot in [-24.0, 24.0]:
		Shapes.fill(body, Shapes.rounded_rect(Vector2(foot - 15.0, -10.0),
			Vector2(30.0, 12.0), 5.0), tint.darkened(0.24), 0.0)
	# Eyes: big, low, and close together. A monster a six-year-old should
	# want to bop rather than run from.
	for eye in [-15.0, 15.0]:
		Shapes.fill(body, Shapes.circle_points(Vector2(eye, -42.0), 11.0, 14),
			Color(0.96, 0.97, 1.0), 0.0)
		Shapes.fill(body, Shapes.circle_points(Vector2(eye + 2.0, -41.0), 6.0, 12), EYE, 0.0)
	Shapes.fill(body, Shapes.rounded_rect(Vector2(-13.0, -26.0), Vector2(26.0, 6.0), 3.0),
		EYE, 0.0)
	return {"node": node, "body": body}


## The spitter: same family, but it lobs goo. Drawn with a puffed cheek and a
## spout, so "this one does something at range" is legible standing still.
static func spitter(parent: Node) -> Dictionary:
	var parts := walker(parent, GOO)
	var body: Node2D = parts["body"]
	Shapes.lit(body, Shapes.circle_points(Vector2(34.0, -34.0), 16.0, 14),
		GOO.lightened(0.16), 0.9)
	Shapes.fill(body, Shapes.taper(Vector2(44.0, -34.0), Vector2(60.0, -30.0), 9.0, 6.0),
		GOO.darkened(0.20), 0.0)
	return parts


## The armoured one: a stone shell everywhere except a glowing spot on top,
## so the answer is "get above it" rather than "hit it more". The weak point
## is returned separately because it pulses, and its pulse is the invitation.
static func armoured(parent: Node) -> Dictionary:
	var parts := walker(parent, ROCK.darkened(0.18))
	var body: Node2D = parts["body"]
	for plate in [-30.0, 0.0, 30.0]:
		Shapes.fill(body, Shapes.rounded_rect(Vector2(plate - 13.0, -66.0),
			Vector2(26.0, 16.0), 5.0), ROCK.darkened(0.34), 0.0)
	var spot := Node2D.new()
	spot.position = Vector2(0, -80.0)
	body.add_child(spot)
	Shapes.glow(spot, Vector2.ZERO, 74.0, Color(1.0, 0.86, 0.38), 4, 0.5)
	Shapes.lit(spot, Shapes.star_points(Vector2.ZERO, 20.0, 0.44, 5),
		Color(1.0, 0.88, 0.42), 0.9)
	if Juice.motion_enabled():
		var t := spot.create_tween().set_loops()
		t.tween_property(spot, "scale", Vector2(1.22, 1.22), 0.55)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(spot, "scale", Vector2.ONE, 0.55)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	parts["weak"] = spot
	return parts


## The wind-up warning worn by anything about to attack: a ring that closes
## in on the attacker over the telegraph window. It shrinks rather than
## flashes, because a shrinking ring says "soon" and a flash only says "look".
static func telegraph(parent: Node2D, tint: Color = Color(1.0, 0.55, 0.30)) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, 100.0, 26)
	ring.closed = true
	ring.width = 7.0
	ring.default_color = tint
	ring.antialiased = true
	node.add_child(ring)
	Shapes.glow(node, Vector2.ZERO, 96.0, tint, 3, 0.34)
	return node


## A goo ball in flight. Slow and arcing on purpose: the whole point is that
## it can be watched, walked away from, or blocked.
static func goo_ball(parent: Node) -> Node2D:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.glow(node, Vector2.ZERO, 52.0, GOO, 3, 0.42)
	Shapes.lit(node, Shapes.circle_points(Vector2.ZERO, 20.0, 16), GOO, 0.9)
	Shapes.fill(node, Shapes.oval_points(Vector2(-6.0, -7.0), Vector2(6.0, 4.0), 10),
		Color(1, 1, 1, 0.6), 0.0)
	return node


## The cage: an animal to let out. Bars, a worried little friend inside, and
## a gold lock that the interact key opens.
static func cage(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 140.0, 0.22)
	var pet := Node2D.new()
	pet.position = Vector2(0, -34.0)
	node.add_child(pet)
	Shapes.lit(pet, Shapes.oval_points(Vector2.ZERO, Vector2(30.0, 26.0), 20),
		Color(0.98, 0.84, 0.52), 1.0)
	for ear in [-16.0, 16.0]:
		Shapes.lit(pet, Shapes.oval_points(Vector2(ear, -24.0), Vector2(9.0, 15.0), 12),
			Color(0.98, 0.84, 0.52), 0.9)
	for eye in [-10.0, 10.0]:
		Shapes.fill(pet, Shapes.circle_points(Vector2(eye, -4.0), 5.0, 10), EYE, 0.0)
	Shapes.fill(pet, Shapes.circle_points(Vector2(0, 6.0), 4.0, 10),
		Color(0.92, 0.55, 0.55), 0.0)
	Juice.idle_bob(pet, 7.0, 1.1)

	var bars := Node2D.new()
	node.add_child(bars)
	Shapes.fill(bars, Shapes.rounded_rect(Vector2(-58.0, -8.0), Vector2(116.0, 10.0), 4.0),
		Color(0.52, 0.55, 0.64), 0.0)
	Shapes.fill(bars, Shapes.rounded_rect(Vector2(-58.0, -116.0), Vector2(116.0, 12.0), 5.0),
		Color(0.52, 0.55, 0.64), 0.0)
	for bar in [-46.0, -23.0, 0.0, 23.0, 46.0]:
		Shapes.fill(bars, Shapes.rounded_rect(Vector2(bar - 4.0, -112.0),
			Vector2(8.0, 106.0), 3.0), Color(0.62, 0.65, 0.74), 0.0)
	Shapes.lit(bars, Shapes.circle_points(Vector2(0, -56.0), 15.0, 14),
		Color(1.0, 0.84, 0.34), 0.9)
	Shapes.fill(bars, Shapes.circle_points(Vector2(0, -56.0), 6.0, 10),
		Color(0.34, 0.26, 0.16), 0.0)
	return {"node": node, "bars": bars, "pet": pet}


## The boss: the rock giant. Big, slow, and built out of the same shapes as
## its little cousins, so a child reads it as "the big one of those" rather
## than as a new and frightening thing.
##
## Every part the level animates comes back by name: the arms telegraph, the
## shell is the phase-three puzzle, the weak point is the answer.
static func rock_boss(parent: Node) -> Dictionary:
	var node := Node2D.new()
	parent.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 300.0, 0.26)

	var body := Node2D.new()
	node.add_child(body)
	Shapes.lit(body, PackedVector2Array([
		Vector2(-104.0, 0.0), Vector2(-96.0, -108.0), Vector2(-56.0, -178.0),
		Vector2(38.0, -186.0), Vector2(100.0, -128.0), Vector2(108.0, 0.0),
	]), ROCK, 1.0)
	for foot in [-56.0, 56.0]:
		Shapes.fill(body, Shapes.rounded_rect(Vector2(foot - 32.0, -22.0),
			Vector2(64.0, 24.0), 8.0), ROCK.darkened(0.26), 0.0)
	for eye in [-32.0, 30.0]:
		Shapes.fill(body, Shapes.circle_points(Vector2(eye, -128.0), 20.0, 16),
			Color(0.96, 0.97, 1.0), 0.0)
		Shapes.fill(body, Shapes.circle_points(Vector2(eye + 3.0, -126.0), 11.0, 12), EYE, 0.0)
	Shapes.fill(body, Shapes.rounded_rect(Vector2(-30.0, -96.0), Vector2(60.0, 11.0), 5.0),
		EYE, 0.0)

	# Arms, pivoted at the shoulder so raising one reads as a wind-up.
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var arm := Node2D.new()
		arm.position = Vector2(side * 96.0, -120.0)
		body.add_child(arm)
		Shapes.lit(arm, Shapes.rounded_rect(Vector2(-22.0, -14.0), Vector2(44.0, 96.0), 16.0),
			ROCK.darkened(0.10), 1.0)
		Shapes.lit(arm, Shapes.circle_points(Vector2(0, 88.0), 30.0, 18),
			ROCK.darkened(0.18), 0.9)
		arms.append(arm)

	# The weak point on its back: hidden until the boss is dizzy.
	var weak := Node2D.new()
	weak.position = Vector2(0, -150.0)
	body.add_child(weak)
	Shapes.glow(weak, Vector2.ZERO, 110.0, Color(1.0, 0.86, 0.38), 5, 0.5)
	Shapes.lit(weak, Shapes.star_points(Vector2.ZERO, 34.0, 0.44, 5),
		Color(1.0, 0.88, 0.42), 0.9)
	weak.visible = false

	# The phase-three shell: a bubble only the charged beam can break.
	var shell := Node2D.new()
	shell.position = Vector2(0, -96.0)
	body.add_child(shell)
	Shapes.glow(shell, Vector2.ZERO, 220.0, Color(0.55, 0.85, 1.0), 5, 0.34)
	var bubble := Line2D.new()
	bubble.points = Shapes.circle_points(Vector2.ZERO, 150.0, 34)
	bubble.closed = true
	bubble.width = 9.0
	bubble.default_color = Color(0.62, 0.90, 1.0, 0.9)
	bubble.antialiased = true
	shell.add_child(bubble)
	shell.visible = false

	return {"node": node, "body": body, "arms": arms, "weak": weak, "shell": shell}
