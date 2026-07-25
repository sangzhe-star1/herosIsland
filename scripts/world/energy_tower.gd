class_name EnergyTower
extends Node2D
## The landmark at the heart of Hero City, drawn.
##
## It replaces a photographic cut-out of a real broadcast tower sitting on a
## black rectangle, plus a coloured `Panel` floated over the top of it to fake
## the lamp. That arrangement could not be repaired, could not be lit, and had
## a visible black box around it on any background that was not the photograph
## it was cut from.
##
## The tower matters because "Repair the Energy Tower" is a level about a
## landmark changing state: it starts cracked and dark, its lamp is the
## instruction the child matches, and when they finish it lights up and the
## crack closes. That is the story of the level, told without a word -- and it
## needs an object that can change, not a picture.
##
## Origin is at the base, centre; the tower is drawn upward in negative y.

const LAMP_Y := -430.0

var _lamp: Polygon2D
var _lamp_glow: Node2D
var _crack: Node2D
var _lattice: Node2D
var _repaired := false

var _height := 470.0
var _base_half := 62.0


## `broken` opens the level on a damaged tower, so finishing it has something
## visible to fix.
func build(height: float = 470.0, broken: bool = true) -> void:
	for c in get_children():
		c.queue_free()
	_height = height
	_base_half = height * 0.132
	_repaired = not broken

	var steel := Color(0.26, 0.29, 0.44)
	var steel_lit := Color(0.36, 0.40, 0.56)

	_lattice = Node2D.new()
	add_child(_lattice)

	# Four legs in perspective: two outer, two inner and slightly darker. A
	# tower drawn as a flat triangle reads as a road sign; the inner pair is
	# what makes it a structure you could walk around.
	for pair in [{"half": _base_half, "top": 0.20, "color": steel},
			{"half": _base_half * 0.55, "top": 0.13, "color": steel.darkened(0.22)}]:
		var half: float = pair["half"]
		var top_half: float = half * float(pair["top"]) / 0.20 * 0.26
		for side in [-1.0, 1.0]:
			Shapes.fill(_lattice, PackedVector2Array([
				Vector2(side * half, 0.0),
				Vector2(side * (half - 13.0), 0.0),
				Vector2(side * (top_half - 7.0), -_height * 0.74),
				Vector2(side * top_half, -_height * 0.74),
			]), pair["color"], 0.9)

	# Cross-bracing. Spacing tightens towards the top, which is how a real
	# lattice is built and, more usefully here, what stops the pattern from
	# reading as a ladder.
	var rows := 8
	for i in range(rows):
		var t0: float = pow(float(i) / float(rows), 1.18)
		var t1: float = pow(float(i + 1) / float(rows), 1.18)
		var y0: float = -_height * 0.74 * t0
		var y1: float = -_height * 0.74 * t1
		var h0: float = lerpf(_base_half, _base_half * 0.26, t0)
		var h1: float = lerpf(_base_half, _base_half * 0.26, t1)
		Shapes.fill(_lattice, Shapes.taper(Vector2(-h0, y0), Vector2(h1, y1), 7.0, 7.0),
			steel_lit, 0.0)
		Shapes.fill(_lattice, Shapes.taper(Vector2(h0, y0), Vector2(-h1, y1), 7.0, 7.0),
			steel_lit, 0.0)
		Shapes.fill(_lattice, Shapes.rounded_rect(Vector2(-h1, y1 - 4.0),
			Vector2(h1 * 2.0, 8.0), 3.0), steel, 0.0)

	# Observation deck, then the mast the lamp sits on.
	var deck_y: float = -_height * 0.74
	Shapes.lit(_lattice, PackedVector2Array([
		Vector2(-_base_half * 0.62, deck_y + 6.0),
		Vector2(-_base_half * 0.40, deck_y - 30.0),
		Vector2(_base_half * 0.40, deck_y - 30.0),
		Vector2(_base_half * 0.62, deck_y + 6.0),
	]), steel_lit, 1.0)
	Shapes.fill(_lattice, Shapes.taper(Vector2(0, deck_y - 26.0),
		Vector2(0, -_height * 0.94), 20.0, 12.0), steel, 0.9)

	_build_lamp()
	if broken:
		_build_damage()


func _build_lamp() -> void:
	var y: float = -_height * 0.94
	# A cage around the lamp, so the light reads as a fitting rather than a
	# floating ball.
	Shapes.fill(self, Shapes.rounded_rect(Vector2(-46.0, y - 6.0),
		Vector2(92.0, 16.0), 7.0), Color(0.30, 0.33, 0.48), 0.9)

	_lamp_glow = Shapes.glow(self, Vector2(0, y - 52.0), 250.0,
		Color(0.62, 0.86, 1.0), 6, 0.42)
	Shapes.fill(self, Shapes.circle_points(Vector2(0, y - 52.0), 50.0, 26),
		Color(1, 1, 1, 0.30), 0.0)
	_lamp = Shapes.fill(self, Shapes.circle_points(Vector2(0, y - 52.0), 38.0, 26),
		Color(0.62, 0.86, 1.0), 0.9)
	# A bright catchlight, offset the same way as every other lit shape in the
	# game, so the tower is under the same sun as the trees.
	Shapes.fill(self, Shapes.oval_points(Vector2(-13.0, y - 66.0),
		Vector2(11.0, 8.0), 12), Color(1, 1, 1, 0.7), 0.0)

	# Three rings around the mast head.
	for i in range(3):
		var ring_y: float = y - 8.0 - float(i) * 13.0
		var half: float = 30.0 - float(i) * 6.0
		Shapes.fill(self, Shapes.rounded_rect(Vector2(-half, ring_y),
			Vector2(half * 2.0, 6.0), 3.0), Color(0.34, 0.38, 0.54), 0.0)


## The damage. Kept to a crack, loose cables and a dark lamp -- there is no
## rubble and nothing is on fire, because the level is about mending something,
## not about a disaster.
func _build_damage() -> void:
	_crack = Node2D.new()
	add_child(_crack)
	var dark := Color(0.14, 0.15, 0.26)
	var y: float = -_height * 0.52
	Shapes.fill(_crack, PackedVector2Array([
		Vector2(-_base_half * 0.60, y),
		Vector2(-8.0, y - 34.0), Vector2(4.0, y - 6.0),
		Vector2(_base_half * 0.52, y - 40.0),
		Vector2(_base_half * 0.44, y - 12.0),
		Vector2(-2.0, y + 22.0), Vector2(-10.0, y + 4.0),
		Vector2(-_base_half * 0.66, y + 26.0),
	]), dark, 0.0)
	# Two cables hanging loose from the break.
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in range(7):
			var t: float = float(i) / 6.0
			pts.append(Vector2(side * (10.0 + t * 40.0),
				y + t * 96.0 + sin(t * 3.4) * 12.0))
		Shapes.fill(_crack, Shapes.ribbon(pts, 6.0, 4), dark, 0.0)
	set_light_color(Color(0.34, 0.36, 0.44))


## The lamp becomes whatever colour the level needs the child to match. This is
## the whole reason the tower is drawn: in "Repair the Energy Tower" the lamp
## IS the instruction, and a picture cannot be an instruction.
func set_light_color(color: Color) -> void:
	if _lamp != null and is_instance_valid(_lamp):
		_lamp.color = color
	if _lamp_glow != null and is_instance_valid(_lamp_glow):
		_lamp_glow.modulate = color


## Where the lamp is, for the ring that pulses out of it when the target
## colour changes.
func lamp_position() -> Vector2:
	return Vector2(0, -_height * 0.94 - 52.0)


## Finished. The crack closes and the lamp comes up to full -- slowly, because
## a sudden flash is unpleasant for a small child and a real seizure risk.
func repair(color: Color = Color(0.72, 0.92, 1.0)) -> void:
	if _repaired:
		return
	_repaired = true
	set_light_color(color)
	if _crack != null and is_instance_valid(_crack):
		if Juice.motion_enabled():
			var fade: Tween = create_tween()
			fade.tween_property(_crack, "modulate:a", 0.0, 0.8)
			fade.tween_callback(_crack.queue_free)
		else:
			_crack.queue_free()
	if _lamp_glow != null and is_instance_valid(_lamp_glow) and Juice.motion_enabled():
		var t: Tween = create_tween()
		t.tween_property(_lamp_glow, "scale", Vector2(1.5, 1.5), 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
