class_name TutorialDirector
extends Control
## The five to eight seconds at the start of every level.
##
## The brief asks for the same three beats every time, and the order is the
## point: **show the goal, show the action once, then hand over control.** A
## child who is given the controls first starts pressing, and never sees the
## demonstration at all.
##
## It is wordless. A finger, a glowing target, and an arrow between them --
## which is how you explain anything to somebody who cannot read, and how the
## instructions on a Lego box work.
##
## While it runs, the child's input is ignored, and the ignoring is visible:
## the pad dims. Nothing is worse than a game that looks playable and is not.

signal finished()

const HAND_SIZE := 104.0

var _steps: Array = []            # [{look, then, hold, path?: PackedVector2Array}]
var _hand: Node2D
var _spot: Node2D
## A non-moving route for reduced-motion play. It belongs to the existing
## tutorial, so a child sees the same instruction grammar without a second
## overlay or a different set of gesture rules.
var _trace: Line2D
var _running := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40


## `look_at` is the thing to notice; `act_at` is where the finger goes.
## Pass the same point twice for "look here, then tap here".
func add_step(look_at: Vector2, act_at: Vector2, hold: float = 1.1) -> void:
	_steps.append({"look": look_at, "then": act_at, "hold": hold})


## Show one continuous gesture. `then` remains the final point so callers
## that only need a pointing finger (for example the basket hints) stay on the
## small `add_step()` API and existing readers of `_steps` keep working.
func add_path(look_at: Vector2, path: PackedVector2Array,
		hold: float = 1.1) -> void:
	if path.is_empty():
		add_step(look_at, look_at, hold)
		return
	_steps.append({"look": look_at, "then": path[path.size() - 1],
		"path": path, "hold": hold})


## Run it. Returns immediately; listen for `finished`.
func play() -> void:
	if _running or _steps.is_empty():
		finished.emit()
		return
	_running = true
	_build()
	_run()


func _build() -> void:
	_trace = Line2D.new()
	_trace.name = "MotionTrace"
	_trace.width = 10.0
	_trace.default_color = Color(1.0, 0.92, 0.55, 0.92)
	_trace.antialiased = true
	_trace.visible = false
	add_child(_trace)

	# The spotlight: a soft ring that lands on whatever is being pointed out.
	_spot = Node2D.new()
	add_child(_spot)
	Shapes.glow(_spot, Vector2.ZERO, 190.0, Color(1.0, 0.94, 0.60), 5, 0.42)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, 88.0, 34)
	ring.closed = true
	ring.width = 7.0
	ring.default_color = Color(1.0, 0.92, 0.55, 0.9)
	ring.antialiased = true
	_spot.add_child(ring)
	_spot.modulate.a = 0.0

	_hand = Node2D.new()
	add_child(_hand)
	# One shared hero glove replaces the former bar-plus-circle hand. Its tip is
	# anchored at the exact taught point, so low-motion routes, moving gestures
	# and later screens all retain the same visual grammar without hand offsets.
	var hand_art := UiKit.guide_hand(HAND_SIZE)
	if hand_art != null:
		_hand.add_child(hand_art)
	_hand.modulate.a = 0.0


func _run() -> void:
	if not Juice.motion_enabled():
		_run_still()
		return
	var t := create_tween()
	for step in _steps:
		var look: Vector2 = step["look"]
		var act: Vector2 = step["then"]
		var hold: float = float(step["hold"])
		var path: PackedVector2Array = step.get("path", PackedVector2Array())
		var starts_at: Vector2 = path[0] if not path.is_empty() else look
		var follows_path := path.size() > 1 and _path_distance(path) > 30.0

		# 1. LOOK: the spotlight lands on the goal and breathes once.
		t.tween_callback(func():
			_spot.position = look
			_spot.scale = Vector2(1.5, 1.5))
		t.tween_property(_spot, "modulate:a", 1.0, 0.22)
		t.parallel().tween_property(_spot, "scale", Vector2.ONE, 0.35)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(hold * 0.5)

		# 2. ACT: the finger arrives and taps, or travels if it is a drag.
		t.tween_callback(func():
			_hand.position = starts_at)
		t.tween_property(_hand, "modulate:a", 1.0, 0.18)
		if follows_path:
			var distance := _path_distance(path)
			for i in range(1, path.size()):
				# Tiny path fragments receive a visible beat, but a long sweep
				# cannot turn a one-step lesson into an impatient wait.
				var seconds := clampf(0.90 * path[i].distance_to(path[i - 1])
					/ maxf(distance, 1.0), 0.05, 0.22)
				t.tween_property(_hand, "position", path[i], seconds) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				t.parallel().tween_property(_spot, "position", path[i], seconds) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif act.distance_to(look) > 30.0:
			t.tween_property(_hand, "position", act, 0.7)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(_spot, "position", act, 0.7)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			t.tween_property(_hand, "scale", Vector2(0.82, 0.82), 0.16)
			t.tween_property(_hand, "scale", Vector2.ONE, 0.2)
		t.tween_interval(hold * 0.45)
		t.tween_property(_hand, "modulate:a", 0.0, 0.2)
		t.parallel().tween_property(_spot, "modulate:a", 0.0, 0.2)

	# 3. HAND OVER.
	t.tween_callback(func():
		_running = false
		finished.emit()
		queue_free())


## Reduced motion trades travel for a clear, held picture: the thing to look
## at stays lit, a line shows the route when there is one, and the finger
## rests at its destination. There is still time to see it, but no bouncing,
## dragging or fading between positions.
func _run_still() -> void:
	var t := create_tween()
	for step in _steps:
		var look: Vector2 = step["look"]
		var act: Vector2 = step["then"]
		var hold: float = float(step["hold"])
		var path: PackedVector2Array = step.get("path", PackedVector2Array())
		var route := still_route(look, act, path)
		var end: Vector2 = route[route.size() - 1] if not route.is_empty() else look
		t.tween_callback(func():
			_spot.position = look
			_spot.scale = Vector2.ONE
			_spot.modulate.a = 1.0
			_hand.position = end
			_hand.scale = Vector2.ONE
			_hand.modulate.a = 1.0
			_trace.points = route
			_trace.visible = not route.is_empty())
		t.tween_interval(maxf(hold, 0.85))
		t.tween_callback(func():
			_hand.modulate.a = 0.0
			_spot.modulate.a = 0.0
			_trace.visible = false)

	t.tween_callback(func():
		_running = false
		finished.emit()
		queue_free())


## A path from add_path is already the exact gesture. A small add_step route
## (for example crop -> basket) is equally useful when frozen as a line.
static func still_route(look: Vector2, act: Vector2,
		path: PackedVector2Array) -> PackedVector2Array:
	if path.size() > 1 and _path_distance(path) > 30.0:
		return path
	if act.distance_to(look) > 30.0:
		return PackedVector2Array([look, act])
	return PackedVector2Array()


static func _path_distance(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total


## Skip it -- a child tapping through, or a replay of a level they know.
func skip() -> void:
	if not _running:
		return
	_running = false
	finished.emit()
	queue_free()


func running() -> bool:
	return _running
