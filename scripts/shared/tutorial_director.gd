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
## A page can compact the existing lesson grammar when its real targets are
## smaller than the global button vocabulary. It scales the hand, ring and
## route together; callers never get a second tutorial overlay or a guessed
## finger offset.
var _visual_scale := 1.0
var _hand: Node2D
var _spot: Node2D
## A non-moving route for reduced-motion play. It belongs to the existing
## tutorial, so a child sees the same instruction grammar without a second
## overlay or a different set of gesture rules.
var _trace: Line2D
var _running := false
var _route_visible_in_motion := false
var _look_target_id := 0
var _look_target_offset := Vector2.ZERO
var _following_look := false
var _look_step_index := -1
var _look_radius := 0.0


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


## Call before play(). The default preserves the established tutorial look on
## every existing page; compact callers keep their cue legible without letting
## a large glove cover the object they are teaching.
func set_visual_scale(value: float) -> TutorialDirector:
	_visual_scale = clampf(value, 0.60, 1.20)
	return self


## A carry reminder can show its route during LOOK, before the glove travels.
## Other pages retain their existing moving lesson without a fixed route.
func set_route_visible_in_motion(value: bool) -> TutorialDirector:
	_route_visible_in_motion = value
	return self


## A compact carry cue uses the visible crop size supplied by its target.
func set_look_radius(value: float) -> TutorialDirector:
	_look_radius = maxf(value, 12.0)
	return self


## Keep LOOK on an object that is still settling into its held pose. Store
## only its identity; an interrupted lesson never retains a freed target.
func follow_look_target(target: Node2D,
		local_offset: Vector2 = Vector2.ZERO) -> TutorialDirector:
	_look_target_id = target.get_instance_id() if is_instance_valid(target) else 0
	_look_target_offset = local_offset if _look_target_id != 0 else Vector2.ZERO
	return self


func _process(_delta: float) -> void:
	if _running and _following_look:
		_refresh_look_anchor()


func _refresh_look_anchor() -> void:
	if not is_instance_id_valid(_look_target_id):
		_following_look = false
		_look_target_offset = Vector2.ZERO
		return
	var target := instance_from_id(_look_target_id) as Node2D
	if target == null:
		_following_look = false
		return
	var at := get_global_transform().affine_inverse() \
		* target.to_global(_look_target_offset)
	_spot.position = at
	if _look_step_index >= 0:
		var step: Dictionary = _steps[_look_step_index]
		step["look"] = at
	var points := _trace.points
	if not points.is_empty():
		points[0] = at
		_trace.points = points


func _show_look(look: Vector2, act: Vector2, path: PackedVector2Array,
		step_index: int) -> void:
	_spot.position = look
	_spot.scale = Vector2.ONE if _route_visible_in_motion else Vector2(1.5, 1.5)
	_look_step_index = step_index
	_following_look = _look_target_id != 0
	_trace.points = still_route(look, act, path) if _route_visible_in_motion \
		else PackedVector2Array()
	_trace.visible = not _trace.points.is_empty()
	if _following_look:
		_refresh_look_anchor()


func _begin_act(starts_at: Vector2) -> void:
	if _following_look:
		_refresh_look_anchor()
		_hand.position = _spot.position
	else:
		_hand.position = starts_at
	_following_look = false


func _hide_route() -> void:
	_trace.visible = false


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
	_trace.width = 10.0 * _visual_scale
	_trace.default_color = Color(1.0, 0.92, 0.55, 0.92)
	_trace.antialiased = true
	_trace.visible = false
	add_child(_trace)

	# The spotlight: a soft ring that lands on whatever is being pointed out.
	_spot = Node2D.new()
	add_child(_spot)
	var ring_radius := _look_radius if _look_radius > 0.0 else 88.0 * _visual_scale
	var glow_radius := ring_radius * 1.55 if _look_radius > 0.0 \
		else 190.0 * _visual_scale
	Shapes.glow(_spot, Vector2.ZERO, glow_radius,
		Color(1.0, 0.94, 0.60), 5, 0.42)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, ring_radius, 34)
	ring.closed = true
	ring.width = 7.0 * _visual_scale
	ring.default_color = Color(1.0, 0.92, 0.55, 0.9)
	ring.antialiased = true
	_spot.add_child(ring)
	_spot.modulate.a = 0.0

	_hand = Node2D.new()
	add_child(_hand)
	# One shared hero glove replaces the former bar-plus-circle hand. Its tip is
	# anchored at the exact taught point, so low-motion routes, moving gestures
	# and later screens all retain the same visual grammar without hand offsets.
	var hand_art := UiKit.guide_hand(HAND_SIZE * _visual_scale)
	if hand_art != null:
		_hand.add_child(hand_art)
	_hand.modulate.a = 0.0


func _run() -> void:
	if not Juice.motion_enabled():
		_run_still()
		return
	var t := create_tween()
	for step_index in range(_steps.size()):
		var step: Dictionary = _steps[step_index]
		var look: Vector2 = step["look"]
		var act: Vector2 = step["then"]
		var hold: float = float(step["hold"])
		var path: PackedVector2Array = step.get("path", PackedVector2Array())
		var starts_at: Vector2 = path[0] if not path.is_empty() else look
		var follows_path := path.size() > 1 and _path_distance(path) > 30.0

		# 1. LOOK: the spotlight lands on the goal and breathes once.
		t.tween_callback(_show_look.bind(look, act, path, step_index))
		t.tween_property(_spot, "modulate:a", 1.0, 0.22)
		t.parallel().tween_property(_spot, "scale", Vector2.ONE, 0.35)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(hold * 0.5)

		# 2. ACT: the finger arrives and taps, or travels if it is a drag.
		t.tween_callback(_begin_act.bind(starts_at))
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
		t.tween_callback(_hide_route)

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
	_following_look = false
	finished.emit()
	queue_free()


func running() -> bool:
	return _running
