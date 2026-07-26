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

const FINGER := Color(0.98, 0.86, 0.72)

var _steps: Array = []            # [{look: Vector2, then: Vector2, hold: float}]
var _hand: Node2D
var _spot: Node2D
var _running := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40


## `look_at` is the thing to notice; `act_at` is where the finger goes.
## Pass the same point twice for "look here, then tap here".
func add_step(look_at: Vector2, act_at: Vector2, hold: float = 1.1) -> void:
	_steps.append({"look": look_at, "then": act_at, "hold": hold})


## Run it. Returns immediately; listen for `finished`.
func play() -> void:
	if _running or _steps.is_empty():
		finished.emit()
		return
	_running = true
	_build()
	_run()


func _build() -> void:
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
	Shapes.fill(_hand, Shapes.rounded_rect(Vector2(-12.0, -70.0),
		Vector2(24.0, 58.0), 11.0), FINGER, 0.85)
	Shapes.lit(_hand, Shapes.circle_points(Vector2(8.0, 6.0), 26.0, 20), FINGER, 0.9)
	_hand.modulate.a = 0.0


func _run() -> void:
	var t := create_tween()
	for step in _steps:
		var look: Vector2 = step["look"]
		var act: Vector2 = step["then"]
		var hold: float = float(step["hold"])

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
			_hand.position = look + Vector2(26, 18))
		t.tween_property(_hand, "modulate:a", 1.0, 0.18)
		if act.distance_to(look) > 30.0:
			t.tween_property(_hand, "position", act + Vector2(26, 18), 0.7)\
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


## Skip it -- a child tapping through, or a replay of a level they know.
func skip() -> void:
	if not _running:
		return
	_running = false
	finished.emit()
	queue_free()


func running() -> bool:
	return _running
