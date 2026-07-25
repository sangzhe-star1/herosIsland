class_name Juice
extends RefCounted
## Celebration feedback: the small motions that make a correct answer feel
## like something happened.
##
## Two rules govern everything here:
##
##  1. Reward motion is generous; correction motion is not. Getting something
##     right earns confetti and a bounce. Getting it wrong gets a small nudge
##     and nothing else -- never a buzz, a shake of the whole screen, or a red
##     flash. The asymmetry is the point.
##
##  2. All of it can be switched off. Some children find particles and bouncing
##     genuinely unpleasant, and a child who is overstimulated cannot learn.
##     Parent Center has a reduce-motion toggle; every function below checks it
##     and degrades to a still, instant version rather than disappearing.

const CONFETTI_COLORS: Array[Color] = [
	Color(1.00, 0.80, 0.24),
	Color(0.36, 0.74, 0.44),
	Color(0.34, 0.62, 0.90),
	Color(0.90, 0.44, 0.52),
	Color(0.66, 0.50, 0.86),
]


static func motion_enabled() -> bool:
	return not bool(SaveManager.get_setting("reduce_motion", false))


## Confetti at a point, in the coordinate space of `parent`.
## Frees itself; callers never need to track it.
static func burst(parent: Node, at: Vector2, amount: int = 22) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not motion_enabled():
		return

	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = amount
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 14.0
	particles.direction = Vector2(0, -1)
	particles.spread = 55.0
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 330.0
	particles.gravity = Vector2(0, 620.0)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.angular_velocity_min = -220.0
	particles.angular_velocity_max = 220.0
	particles.color = CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()]

	# Painted sparkle when the art exists; bare squares until then. The art is
	# 256px, so the scale drops to keep particles the same size either way.
	var sparkle_art := "res://assets/effects/sparkle.png"
	if ResourceLoader.exists(sparkle_art):
		particles.texture = load(sparkle_art)
		particles.scale_amount_min = 0.06
		particles.scale_amount_max = 0.14
	parent.add_child(particles)
	particles.emitting = true

	# Outlive the longest particle, then clean up.
	var timer := parent.get_tree().create_timer(particles.lifetime + 0.4)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Squash-and-stretch bounce. Works on any CanvasItem with a `scale`.
##
## The base scale is remembered the FIRST time and every pop returns to it,
## and a new pop kills the one in flight. The old version read the CURRENT
## scale as its base, so a tap landing mid-pop adopted the inflated size as
## the new normal -- ten fast taps grew a button without limit, until the
## Tap-to-Cross button had swallowed a quarter of the screen and the hero
## behind it. Found by a parent, tapping the way a child taps.
static func pop(node: Node, strength: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_method("create_tween"):
		return
	if not motion_enabled():
		return

	var base: Vector2
	if node.has_meta("_pop_base"):
		base = node.get_meta("_pop_base")
	else:
		base = node.get("scale")
		node.set_meta("_pop_base", base)
	if node.has_meta("_pop_tween"):
		var old: Variant = node.get_meta("_pop_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var t: Tween = node.create_tween()
	node.set_meta("_pop_tween", t)
	t.tween_property(node, "scale", base * (1.0 + strength), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", base, 0.16)\
		.set_trans(Tween.TRANS_SINE)


## Gentle correction. Deliberately small, quiet and quick -- a nudge that says
## "not that one", not a punishment.
static func nudge(node: Node, distance: float = 14.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_method("create_tween"):
		return

	if not motion_enabled():
		return
	# Kill any nudge in flight and put the node back where it was first,
	# otherwise a mid-nudge position becomes the next nudge's "home" and
	# rapid wrong-taps walk the node sideways across the screen.
	if node.has_meta("_nudge_tween"):
		var old: Variant = node.get_meta("_nudge_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
			node.set("position", node.get_meta("_nudge_origin"))
	var origin: Vector2 = node.get("position")
	node.set_meta("_nudge_origin", origin)
	var t: Tween = node.create_tween()
	node.set_meta("_nudge_tween", t)
	t.tween_property(node, "position", origin + Vector2(distance, 0), 0.06)
	t.tween_property(node, "position", origin - Vector2(distance, 0), 0.06)
	t.tween_property(node, "position", origin, 0.06)


## Dust kicked up where something lands. Six or so soft puffs that drift
## outward and fade -- the single cheapest thing that makes a landing feel
## like it had weight. Drawn through Shapes so a dust cloud in the arena and
## a cloud in the sky are made of the same material.
static func dust(parent: Node, at: Vector2, amount: int = 7, spread: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if not motion_enabled():
		return
	for i in range(amount):
		var puff := Polygon2D.new()
		var r: float = randf_range(6.0, 13.0) * spread
		puff.polygon = Shapes.circle_points(Vector2.ZERO, r, 12)
		puff.color = Color(0.93, 0.90, 0.84, randf_range(0.35, 0.55))
		puff.position = at + Vector2(randf_range(-14.0, 14.0), randf_range(-4.0, 2.0))
		puff.antialiased = true
		parent.add_child(puff)
		var away := Vector2(randf_range(-46.0, 46.0) * spread, randf_range(-30.0, -6.0))
		var t := puff.create_tween().set_parallel(true)
		t.tween_property(puff, "position", puff.position + away, randf_range(0.35, 0.55))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(puff, "scale", Vector2(1.6, 1.6), 0.5)
		t.tween_property(puff, "modulate:a", 0.0, randf_range(0.35, 0.55))
		t.chain().tween_callback(puff.queue_free)


## An expanding, fading ring -- the shockwave of an arrival or a big landing.
static func shockwave(parent: Node, at: Vector2, radius: float = 90.0,
		color: Color = Color(1.0, 0.95, 0.8)) -> void:
	if parent == null or not is_instance_valid(parent) or not motion_enabled():
		return
	var holder := Node2D.new()
	holder.position = at
	holder.scale = Vector2(0.35, 0.35)
	parent.add_child(holder)
	var line := Line2D.new()
	line.points = Shapes.oval_points(Vector2.ZERO, Vector2(radius, radius * 0.42), 28)
	line.closed = true
	line.width = 9.0
	line.default_color = color
	line.antialiased = true
	holder.add_child(line)
	var t := holder.create_tween().set_parallel(true)
	t.tween_property(holder, "scale", Vector2(1.7, 1.7), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(holder.queue_free)


## Short tapered streaks trailing something fast -- the drawn version of
## motion blur, for rolls and dashes. `direction` is the way the mover is
## GOING; the streaks trail behind.
static func speed_lines(parent: Node, at: Vector2, direction: Vector2,
		color: Color = Color(1, 1, 1, 0.6), count: int = 3) -> void:
	if parent == null or not is_instance_valid(parent) or not motion_enabled():
		return
	var back: Vector2 = -direction.normalized()
	for i in range(count):
		var offset := Vector2(randf_range(-8.0, 8.0), randf_range(-34.0, 20.0))
		var length: float = randf_range(34.0, 66.0)
		var streak := Polygon2D.new()
		streak.polygon = Shapes.taper(Vector2.ZERO, back * length, 7.0, 1.5)
		streak.color = color
		streak.position = at + offset
		streak.antialiased = true
		parent.add_child(streak)
		var t := streak.create_tween().set_parallel(true)
		t.tween_property(streak, "position", streak.position + back * 30.0, 0.28)
		t.tween_property(streak, "modulate:a", 0.0, 0.28)
		t.chain().tween_callback(streak.queue_free)


## Slow breathing loop for an idle character, so the screen is never fully
## still while waiting for the child to act.
static func idle_bob(node: Node, height: float = 8.0, period: float = 1.8) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_method("create_tween"):
		return
	if not motion_enabled():
		return

	var origin: Vector2 = node.get("position")
	var t: Tween = node.create_tween().set_loops()
	t.tween_property(node, "position", origin - Vector2(0, height), period * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position", origin, period * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The red "not this one" ring: a circle with a diagonal slash, bloomed over
## the exact thing that was wrongly touched, gone half a second later. For a
## child who cannot read, THIS is the correction message -- it points at the
## thing, it says no, and it leaves without scolding. Follows rule 1: one
## small bloom, never a strobe, never a whole-screen flash; under
## reduce-motion it appears still and simply goes.
static func no_sign(parent: Node, at: Vector2, size: float = 150.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var holder := Node2D.new()
	holder.position = at
	holder.z_index = 40                     # over the play things, under nothing that matters
	parent.add_child(holder)

	var red := Color(0.90, 0.28, 0.28)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, size * 0.44, 30)
	ring.closed = true
	ring.width = maxf(size * 0.085, 4.0)
	ring.default_color = red
	ring.antialiased = true
	holder.add_child(ring)

	var slash := Line2D.new()
	var arm := Vector2(size * 0.30, -size * 0.30)
	slash.points = PackedVector2Array([-arm, arm])
	slash.width = maxf(size * 0.085, 4.0)
	slash.default_color = red
	slash.antialiased = true
	holder.add_child(slash)

	if motion_enabled():
		holder.scale = Vector2(0.5, 0.5)
		var t := holder.create_tween()
		t.tween_property(holder, "scale", Vector2.ONE, 0.18)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.5)
		t.tween_property(holder, "modulate:a", 0.0, 0.30)
		t.tween_callback(holder.queue_free)
	else:
		holder.get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(holder):
				holder.queue_free()
		)
