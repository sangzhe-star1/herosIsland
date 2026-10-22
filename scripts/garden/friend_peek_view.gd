extends Node2D
## The on-screen half of 一二三木头人: turns the friend's 3D model, draws the
## hold ring over the quiet bed, says "freeze" when it looks, and calls back
## once when the ring fills. The rules live in friend_peek_controller.gd; the
## screen that owns this node decides what a finished pick stores.
##
## Shared by the bear's farm and the three friend farms, so the game feels the
## same at every door.

const Peek := preload("res://scripts/garden/friend_peek_controller.gd")
const RING_RADIUS := 62.0

var peek = Peek.new()
var holding := false
var model: Node3D
var centre := Vector2.ZERO
var on_done: Callable

var _ring: Line2D
var _ring_back: Line2D
var _freeze: Label


func setup(friend_model: Node3D, bed_centre: Vector2, done: Callable) -> void:
	model = friend_model
	centre = bed_centre + Vector2(0, -20)
	on_done = done
	_ring_back = Line2D.new()
	_ring_back.name = "SneakRingBack"
	_ring_back.width = 10.0
	_ring_back.default_color = Color(1.0, 1.0, 1.0, 0.45)
	_ring_back.points = _arc(1.0)
	add_child(_ring_back)
	_ring = Line2D.new()
	_ring.name = "SneakRing"
	_ring.width = 10.0
	_ring.default_color = Color(0.55, 0.86, 1.0, 0.95)
	add_child(_ring)


## One beat. Separate from _process so a probe can step without real seconds.
func advance(delta: float) -> void:
	if peek.done:
		return
	var result: String = peek.step(delta, holding)
	_face(delta)
	if _ring != null and is_instance_valid(_ring):
		_ring.points = _arc(peek.progress) if peek.progress > 0.0 else PackedVector2Array()
		# Dim while the friend looks: the ring is waiting, not lost.
		_ring.modulate.a = 0.45 if peek.phase() == Peek.LOOKING else 1.0
	if result == "frozen":
		_say_freeze()
	elif result == "done":
		holding = false
		if model != null and is_instance_valid(model):
			model.rotation_degrees.y = 0.0
		for ring in [_ring, _ring_back]:
			if ring != null and is_instance_valid(ring):
				ring.queue_free()
		_ring = null
		_ring_back = null
		if on_done.is_valid():
			on_done.call()


func _process(delta: float) -> void:
	advance(delta)


## The friend's back is the whole signal, so it is shown with or without
## motion: reduced motion snaps between the poses instead of turning.
func _face(delta: float) -> void:
	if model == null or not is_instance_valid(model):
		return
	var phase: String = peek.phase()
	var target := 0.0 if phase == Peek.LOOKING else 180.0
	if phase == Peek.TURNING:
		target = 180.0 + sin(peek.elapsed * 28.0) * 12.0
	if not Juice.motion_enabled():
		model.rotation_degrees.y = target
		return
	# Time-based easing, so a slow tablet turns as fast as a quick one.
	model.rotation_degrees.y = lerpf(model.rotation_degrees.y, target,
		1.0 - exp(-delta * 10.0))


func _arc(fraction: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(2, int(48.0 * fraction) + 1)
	for i in range(steps):
		var angle := -PI * 0.5 + TAU * fraction * float(i) / float(steps - 1)
		points.append(centre + Vector2(cos(angle), sin(angle)) * RING_RADIUS)
	return points


func _say_freeze() -> void:
	if _freeze != null and is_instance_valid(_freeze):
		return
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	_freeze = UiKit.title_on_art(I18n.t("garden.friend_peek_freeze"), 30)
	_freeze.name = "FriendPeekFreeze"
	_freeze.position = centre + Vector2(-140, -130)
	_freeze.size = Vector2(280, 40)
	_freeze.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_freeze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_freeze)
	# Owned by the label, so leaving the farm cannot strand a callback.
	var linger := _freeze.create_tween()
	linger.tween_interval(1.0)
	linger.tween_callback(_freeze.queue_free)
