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
static func pop(node: Node, strength: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_method("create_tween"):
		return
	if not motion_enabled():
		return

	var base: Vector2 = node.get("scale")
	var t: Tween = node.create_tween()
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

	var origin: Vector2 = node.get("position")
	if not motion_enabled():
		return
	var t: Tween = node.create_tween()
	t.tween_property(node, "position", origin + Vector2(distance, 0), 0.06)
	t.tween_property(node, "position", origin - Vector2(distance, 0), 0.06)
	t.tween_property(node, "position", origin, 0.06)


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
