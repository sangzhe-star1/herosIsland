class_name ThumbStick
extends Control
## The left thumb, as a stick rather than two buttons.
##
## Two arrow buttons ask a six-year-old to find a target and keep their thumb
## on it. A stick asks them to put their thumb down anywhere in a big corner
## of the screen and lean. The second one is what a small hand actually does,
## and it is why every console controller made in forty years has a stick.
##
## Everything here is tuned for a thumb that is short, imprecise, and often
## not looking at what it is doing:
##
##   * the touch area is a QUARTER OF THE SCREEN, not a drawn circle -- the
##     ring appears wherever the thumb lands
##   * a dead zone, so resting a thumb is not walking
##   * the knob follows the finger and stops at the rim, so the ring always
##     shows which way the hero is going
##   * released, it springs home and the hero stops. No drift, ever.
##
## It reports a direction from -1 to 1, and the level decides what that means.
## Nothing in here knows there is a hero.

signal moved(dir: float)          # -1 .. 1, 0 when let go

## Where a thumb can land. The whole bottom-left quarter, because a child
## putting their thumb down in a hurry misses a 130 px circle constantly.
const AREA := Rect2(0, 380, 470, 340)
const RING := 104.0               # how far the knob travels before it stops
const DEAD := 0.16                # fraction of RING that counts as "resting"
const HOME := 0.12                # seconds to spring back

var _touch := -1                  # which finger owns the stick, -1 for none
var _origin := Vector2.ZERO       # where that finger first landed
var _ring: Node2D
var _knob: Node2D
var _dir := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	# A faint resting ring, so the corner does not look dead before it is
	# touched. It brightens and moves to the thumb the moment one lands.
	_ring = Node2D.new()
	_ring.position = AREA.position + AREA.size * 0.5
	_ring.modulate.a = 0.34
	add_child(_ring)
	var outer := Line2D.new()
	outer.points = Shapes.circle_points(Vector2.ZERO, RING, 40)
	outer.closed = true
	outer.width = 8.0
	outer.default_color = Color(0.62, 0.82, 1.0, 0.85)
	outer.antialiased = true
	_ring.add_child(outer)
	Shapes.fill(_ring, Shapes.circle_points(Vector2.ZERO, RING - 6.0, 34),
		Color(0.06, 0.12, 0.26, 0.34), 0.0)
	# Two chevrons on the rim: a wordless "this thing goes left and right".
	for side in [-1.0, 1.0]:
		Shapes.fill(_ring, PackedVector2Array([
			Vector2(side * (RING - 30.0), -14.0),
			Vector2(side * (RING - 8.0), 0.0),
			Vector2(side * (RING - 30.0), 14.0),
		]), Color(0.80, 0.90, 1.0, 0.55), 0.0)

	_knob = Node2D.new()
	_ring.add_child(_knob)
	Shapes.glow(_knob, Vector2.ZERO, 76.0, Color(0.62, 0.86, 1.0), 3, 0.30)
	Shapes.lit(_knob, Shapes.circle_points(Vector2.ZERO, 46.0, 26),
		Color(0.24, 0.46, 0.82), 1.0)
	Shapes.fill(_knob, Shapes.oval_points(Vector2(-13.0, -16.0),
		Vector2(15.0, 9.0), 12), Color(1, 1, 1, 0.45), 0.0)


## Godot delivers touches to `_input` whether or not anything is focused,
## which is what lets the stick own a finger that landed on empty scenery.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_maybe_grab(touch.index, touch.position)
		elif touch.index == _touch:
			_let_go()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch:
			_follow(drag.position)
	# The desktop mouse is one more finger, so a Mac build plays the same.
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_maybe_grab(-2, click.position)
			elif _touch == -2:
				_let_go()
	elif event is InputEventMouseMotion and _touch == -2:
		_follow((event as InputEventMouseMotion).position)


func _maybe_grab(index: int, at: Vector2) -> void:
	if _touch != -1 or not AREA.has_point(at):
		return
	_touch = index
	# The ring goes to the thumb. Asking the thumb to go to the ring is the
	# whole problem with a drawn pad.
	_origin = at
	_ring.position = at
	_ring.modulate.a = 1.0
	Juice.pop(_ring, 0.16)
	_follow(at)


func _follow(at: Vector2) -> void:
	var away: Vector2 = at - _origin
	var pull: float = clampf(away.x / RING, -1.0, 1.0)
	_knob.position.x = pull * RING
	# Vertical lean is shown but not reported: this is a side-scrolling
	# island, and a child who leans up should see the stick move rather than
	# wonder why it is stuck.
	_knob.position.y = clampf(away.y, -RING * 0.5, RING * 0.5)
	var wanted: float = 0.0 if absf(pull) < DEAD else pull
	if not is_equal_approx(wanted, _dir):
		_dir = wanted
		moved.emit(_dir)


func _let_go() -> void:
	_touch = -1
	_dir = 0.0
	moved.emit(0.0)
	if not Juice.motion_enabled():
		_knob.position = Vector2.ZERO
		_ring.modulate.a = 0.34
		return
	var t := _knob.create_tween()
	t.tween_property(_knob, "position", Vector2.ZERO, HOME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := _ring.create_tween()
	fade.tween_property(_ring, "modulate:a", 0.34, 0.25)


## Where the stick is leaning right now, for a level that would rather ask
## than listen.
func direction() -> float:
	return _dir
