class_name PuzzleCard
extends Control
## A knowledge question, asked WITHOUT leaving the level.
##
## This is how the twelve old minigames survive inside the adventure: their
## ideas come back as cards that pop up mid-level, get answered in fifteen
## seconds, and put the child straight back on the path. No scene switch, no
## loading, no losing the place -- the world dims behind the card and is
## still there when it flips away.
##
## One shell, many kinds. The shell owns the dimmer, the frame, the option
## tiles, the wrong-answer manners (dim the tile, wobble it, never a fail
## state) and the celebration. Each kind only decides what the question looks
## like and which tile is right. Phase B ships `color_match`; the other kinds
## arrive as the worlds that need them are rebuilt.
##
## House manners, same as everywhere on the island:
##   * pictures carry the meaning; there is not a word on the card
##   * a wrong tap dims that tile and nudges it -- the question never resets
##   * nothing here can be failed, so nothing here can be feared

signal answered(correct: bool)
signal solved()

const CARD_SIZE := Vector2(880, 520)

var _kind := "color_match"
var _correct := 0
var _tiles: Array = []
var _done := false

## The palette of askable colours: far apart in hue, each nameable by a
## six-year-old, none relying on red-green telling-apart alone.
const ASK_COLORS := [
	Color(0.92, 0.30, 0.28),     # red
	Color(0.30, 0.55, 0.95),     # blue
	Color(1.00, 0.80, 0.20),     # yellow
	Color(0.35, 0.78, 0.42),     # green
]


func _ready() -> void:
	# Anchors AND offsets. `set_anchors_preset` alone keeps the current rect
	# and merely re-expresses it, so a Control born at zero size stays at zero
	# size -- and its full-screen dimmer, anchored to a zero-size parent, comes
	# out invisible. The card looked right; the world behind it never dimmed.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # the world is busy; eat the taps
	z_index = 60


## Build and show. `rng` comes seeded from the level so a replayed level asks
## the same question -- a child who walks away thinking about the answer
## comes back to the question they solved in their head.
func open(kind: String, rng: RandomNumberGenerator, gentle: bool) -> void:
	_kind = kind
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.12, 0.55)
	# Anchors alone leave the rect at its birth size until a layout pass that
	# may never come; offsets make it cover the screen this frame, which is
	# the frame the child is looking at.
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var card := Control.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.position = (Vector2(1280, 720) - CARD_SIZE) / 2.0
	card.pivot_offset = CARD_SIZE / 2.0
	add_child(card)

	var face := Node2D.new()
	card.add_child(face)
	Shapes.fill(face, Shapes.rounded_rect(Vector2(6, 10), CARD_SIZE, 34.0),
		Color(0.04, 0.07, 0.16, 0.45), 0.0)
	Shapes.lit(face, Shapes.rounded_rect(Vector2.ZERO, CARD_SIZE, 34.0),
		Color(0.97, 0.94, 0.86), 1.0)
	Shapes.fill(face, Shapes.rounded_rect(Vector2(0, 0), Vector2(CARD_SIZE.x, 14.0), 7.0),
		Color(1.0, 0.84, 0.34), 0.0)

	match _kind:
		"color_match":
			_build_color_match(card, rng, gentle)
		_:
			_build_color_match(card, rng, gentle)

	Juice.pop(card, 0.26)


# --- the one kind Phase B ships ----------------------------------------------

## "The tower wants THIS colour -- which of these is it?"
## The question is a big tinted star on a little tower; the answers are orbs.
## Straight from the old collect_energy colour levels, which is the point.
func _build_color_match(card: Control, rng: RandomNumberGenerator, gentle: bool) -> void:
	var option_count: int = 3 if gentle else 4
	# Shuffled with the LEVEL'S rng, not the global one, so a replayed level
	# asks the same question in the same clothes.
	var colors: Array = ASK_COLORS.duplicate()
	for i in range(colors.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Color = colors[i]
		colors[i] = colors[j]
		colors[j] = swap
	var ask_index: int = rng.randi_range(0, option_count - 1)

	# The question: a tower with a grey lamp, and the wanted colour above it.
	var quiz := Node2D.new()
	# Low enough that the wanted-colour star sits INSIDE the card. At 170 the
	# star's top poked out over the card's gold rail and read as a sticker
	# stuck on the frame rather than as the thing being asked about.
	quiz.position = Vector2(CARD_SIZE.x / 2.0, 215.0)
	card.add_child(quiz)
	Shapes.lit(quiz, Shapes.taper(Vector2(0, 60.0), Vector2(0, -30.0), 26.0, 16.0),
		Color(0.62, 0.66, 0.76), 1.0)
	Shapes.lit(quiz, Shapes.circle_points(Vector2(0, -48.0), 22.0, 18),
		Color(0.55, 0.58, 0.66), 0.9)
	var want: Color = colors[ask_index]
	Shapes.glow(quiz, Vector2(0, -110.0), 110.0, want, 5, 0.5)
	Shapes.fill(quiz, Shapes.star_points(Vector2(0, -110.0), 42.0, 0.45, 5), want, 0.9)
	if Juice.motion_enabled():
		var t := quiz.create_tween().set_loops()
		t.tween_property(quiz, "scale", Vector2(1.06, 1.06), 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(quiz, "scale", Vector2.ONE, 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# The answers: a row of orbs, one of them the wanted colour.
	_correct = ask_index
	var tile := 150.0
	var row_w: float = tile * float(option_count) + 40.0 * float(option_count - 1)
	for i in range(option_count):
		var b := Button.new()
		b.custom_minimum_size = Vector2(tile, tile)
		b.size = Vector2(tile, tile)
		b.position = Vector2((CARD_SIZE.x - row_w) / 2.0
			+ float(i) * (tile + 40.0), 330.0)
		b.focus_mode = Control.FOCUS_NONE
		b.pivot_offset = Vector2(tile, tile) / 2.0
		# A visible tile, not a bare orb: a six-year-old needs to see WHERE to
		# put their thumb, and a floating picture on cream card stock does not
		# say "press me" to anyone.
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.90, 0.95, 1.0)
		style.border_color = Color(0.62, 0.72, 0.88)
		style.set_border_width_all(4)
		style.border_width_bottom = 8
		style.set_corner_radius_all(30)
		var down: StyleBoxFlat = style.duplicate()
		down.bg_color = Color(0.80, 0.88, 0.98)
		down.border_width_bottom = 4
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		b.add_theme_stylebox_override("pressed", down)
		card.add_child(b)

		var art := Node2D.new()
		art.position = Vector2(tile, tile) / 2.0
		b.add_child(art)
		var tint: Color = colors[i]
		Shapes.glow(art, Vector2.ZERO, 66.0, tint, 3, 0.4)
		Shapes.lit(art, Shapes.circle_points(Vector2.ZERO, 44.0, 22), tint, 0.9)
		Shapes.fill(art, Shapes.oval_points(Vector2(-14.0, -16.0), Vector2(13.0, 9.0), 12),
			Color(1, 1, 1, 0.6), 0.0)

		var index := i
		b.gui_input.connect(func(event: InputEvent):
			if UiKit.is_press(event):
				_choose(index, b))
		_tiles.append(b)


# --- answering ----------------------------------------------------------------

func _choose(index: int, tile: Button) -> void:
	if _done:
		return
	# This Control fills the screen from (0,0), so a tile's global position
	# IS its position on this canvas -- the one coordinate frame with no maths.
	var centre: Vector2 = tile.global_position + tile.pivot_offset
	if index == _correct:
		_done = true
		answered.emit(true)
		Juice.pop(tile, 0.30)
		Juice.burst(self, centre, 24)
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		# A beat to enjoy being right, timed off a tween this card owns, so
		# leaving the level does not leave a timer firing into a freed card.
		var t := create_tween()
		t.tween_interval(0.85)
		t.tween_callback(func():
			solved.emit()
			queue_free())
	else:
		answered.emit(false)
		tile.modulate = Color(0.55, 0.58, 0.66, 0.8)
		Juice.nudge(tile)
		Juice.no_sign(self, centre, 130.0)
		AudioManager.play_sfx("res://assets/audio/try_again.ogg")


## For the probe: which tile is right. Tests tap the BUTTON like a finger
## would; they only read this to know which finger to use.
func correct_index() -> int:
	return _correct


func tiles() -> Array:
	return _tiles
