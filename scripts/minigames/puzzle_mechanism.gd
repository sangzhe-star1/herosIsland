extends LevelManager
## "Make the machine work." The thinking game.
##
## Four kinds of small mechanism, all of them three to five moves long, all of
## them solved by tapping or dragging one thing at a time:
##
##   pipes    turn each pipe until the light can run from the tank to the tower
##   wires    join the cut ends by dragging one end onto its matching colour
##   mirrors  turn each mirror so the beam reaches the crystal
##   order    press the buttons from smallest to biggest
##
## They share a shape on purpose: a row of things, each with a state, and a
## goal that lights up the moment all the states agree. A child who solved the
## pipes knows how to approach the mirrors without being told.
##
## Nothing can be got wrong permanently -- every piece can be turned again,
## every wire can be pulled out. The only thing that accumulates is how much
## help was needed, which is the third star.

const Hints := preload("res://scripts/shared/hint_director.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")

const ROW_Y := 400.0

var _field: Control
var _hud: Control
var _hints: Hints
var _picker: Picker
var _kind := "pipes"
var _pieces: Array = []           # [{node, at, state, want, kind}]
var _goal: Node2D                 # the thing that lights up when it is solved
var _steps := 4
var _slips := 0
var _helped := false
var _quick := false               # solved without a single wrong turn
var _tally: Label
var _finished_level := false


func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_kind = str(config.get("puzzle", "pipes"))
	# Three to five steps, never more. The brief says so and it is right:
	# a fourth turn is a puzzle, a seventh is homework.
	_steps = clampi(harder_i(int(config.get("steps", 4)), 1), 3, 5)

	build_world(self, 0.42)
	_field = UiKit.play_area(self, true)
	_field.gui_input.connect(_on_tap)

	_build_goal()
	_build_pieces()
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_glow_next, _show_the_turn, _do_one_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_play_tutorial()
	_refresh()


# --- the machine ------------------------------------------------------------------

## The thing being powered, on the right, dark until the puzzle is solved.
func _build_goal() -> void:
	_goal = Node2D.new()
	_goal.position = Fit.at(_field, Vector2(1108, ROW_Y - 40.0))
	_field.add_child(_goal)
	Shapes.ground_shadow(_goal, Vector2(0, 130.0), 150.0, 0.20)
	Shapes.lit(_goal, Shapes.taper(Vector2(0, 130.0), Vector2(0, -60.0), 46.0, 30.0),
		Color(0.58, 0.62, 0.74), 1.0)
	var lamp := Node2D.new()
	lamp.position = Vector2(0, -86.0)
	_goal.add_child(lamp)
	Shapes.lit(lamp, Shapes.circle_points(Vector2.ZERO, 34.0, 22),
		Color(0.42, 0.45, 0.54), 0.9)
	_goal.set_meta("lamp", lamp)

	# The source, on the left: where the light comes FROM, so the row of
	# pieces reads as a path between two things rather than as a row of toys.
	var source := Node2D.new()
	source.position = Fit.at(_field, Vector2(150, ROW_Y - 40.0))
	_field.add_child(source)
	Shapes.glow(source, Vector2.ZERO, 130.0, Color(0.55, 0.88, 1.0), 4, 0.45)
	Shapes.lit(source, Shapes.circle_points(Vector2.ZERO, 42.0, 24),
		Color(0.45, 0.86, 1.0), 0.9)


func _build_pieces() -> void:
	var span := 760.0
	for i in range(_steps):
		var t: float = 0.5 if _steps == 1 else float(i) / float(_steps - 1)
		var at := Fit.at(_field, Vector2(lerpf(300.0, 300.0 + span, t), ROW_Y))
		var node := Node2D.new()
		node.position = at
		_field.add_child(node)
		var piece := {"node": node, "at": at, "kind": _kind, "index": i}
		match _kind:
			"order":
				# Buttons wearing one to five dots, shuffled: press them in
				# dot order. The "state" is whether it has been pressed.
				piece["want"] = i + 1
				piece["state"] = 0
			"wires":
				# Each wire has a colour and starts unplugged.
				piece["colour"] = i
				piece["state"] = 0
				piece["want"] = 1
			_:
				# Pipes and mirrors: four rotations, one of them right.
				piece["want"] = 0
				piece["state"] = _picker.whole(1, 3)   # never start solved
		_pieces.append(piece)
		_paint(piece)

	if _kind == "order":
		# The dots are shuffled across the row, so "press them left to right"
		# is the wrong answer and looking at the dots is the right one.
		var dots: Array = []
		for i in range(_steps):
			dots.append(i + 1)
		_picker.shuffle(dots)
		for i in range(_steps):
			_pieces[i]["want"] = int(dots[i])
			_paint(_pieces[i])


## Draw a piece in its current state. Called again after every change, so
## there is exactly one place that knows what a piece looks like.
func _paint(piece: Dictionary) -> void:
	var node: Node2D = piece["node"]
	if not is_instance_valid(node):
		return
	for child in node.get_children():
		child.queue_free()
	var solved: bool = _piece_ok(piece)
	var tint: Color = Color(0.45, 0.86, 1.0) if solved else Color(0.60, 0.64, 0.74)

	match str(piece["kind"]):
		"order":
			Shapes.ground_shadow(node, Vector2(0, 46.0), 120.0, 0.18)
			Shapes.lit(node, Shapes.circle_points(Vector2.ZERO, 54.0, 26),
				Color(0.52, 0.56, 0.68) if int(piece["state"]) == 0
				else Color(0.45, 0.86, 0.60), 1.0)
			# Dots, never digits: a six-year-old counts long before they read.
			var many: int = int(piece["want"])
			for d in range(many):
				var a: float = -PI * 0.5 + TAU * float(d) / float(maxi(many, 1))
				var spot: Vector2 = Vector2.ZERO if many == 1 \
					else Vector2(cos(a), sin(a)) * 26.0
				Shapes.fill(node, Shapes.circle_points(spot, 8.0, 12),
					Color(0.06, 0.10, 0.22), 0.0)
		"wires":
			var colours := [Color(0.92, 0.32, 0.30), Color(0.32, 0.58, 0.95),
				Color(1.0, 0.80, 0.22), Color(0.38, 0.80, 0.46),
				Color(0.72, 0.45, 0.92)]
			var wire: Color = colours[int(piece["colour"]) % colours.size()]
			# Two cut ends and, once joined, the cable between them.
			for side in [-1.0, 1.0]:
				Shapes.fill(node, Shapes.rounded_rect(
					Vector2(side * 54.0 - 16.0, -14.0), Vector2(32.0, 28.0), 8.0),
					wire.darkened(0.25), 0.0)
			if int(piece["state"]) == 1:
				Shapes.fill(node, Shapes.rounded_rect(Vector2(-46.0, -9.0),
					Vector2(92.0, 18.0), 8.0), wire, 0.0)
				Shapes.glow(node, Vector2.ZERO, 110.0, wire, 3, 0.4)
		"mirrors":
			Shapes.ground_shadow(node, Vector2(0, 60.0), 120.0, 0.18)
			Shapes.fill(node, Shapes.taper(Vector2(0, 60.0), Vector2(0, 10.0),
				12.0, 8.0), Color(0.46, 0.50, 0.60), 0.0)
			var turn: float = float(int(piece["state"])) * 45.0
			var glass := Node2D.new()
			glass.rotation_degrees = turn
			node.add_child(glass)
			Shapes.lit(glass, Shapes.rounded_rect(Vector2(-8.0, -56.0),
				Vector2(16.0, 112.0), 7.0), tint, 1.0)
			Shapes.fill(glass, Shapes.rounded_rect(Vector2(-3.0, -48.0),
				Vector2(6.0, 96.0), 3.0), Color(1, 1, 1, 0.55), 0.0)
		_:
			# Pipes: an elbow that only carries light when it points along the row.
			Shapes.ground_shadow(node, Vector2(0, 56.0), 120.0, 0.18)
			var barrel := Node2D.new()
			barrel.rotation_degrees = float(int(piece["state"])) * 90.0
			node.add_child(barrel)
			Shapes.lit(barrel, Shapes.rounded_rect(Vector2(-58.0, -20.0),
				Vector2(116.0, 40.0), 12.0), tint, 1.0)
			Shapes.fill(barrel, Shapes.rounded_rect(Vector2(-44.0, -8.0),
				Vector2(88.0, 16.0), 7.0),
				Color(0.85, 0.97, 1.0) if solved else Color(0.34, 0.38, 0.48), 0.0)
			if solved:
				Shapes.glow(barrel, Vector2.ZERO, 130.0, Color(0.55, 0.88, 1.0), 3, 0.4)


func _piece_ok(piece: Dictionary) -> bool:
	if str(piece["kind"]) == "order":
		return int(piece["state"]) == 1
	if str(piece["kind"]) == "wires":
		return int(piece["state"]) == 1
	return int(piece["state"]) == int(piece["want"])


func _solved() -> bool:
	for piece in _pieces:
		if not _piece_ok(piece):
			return false
	return true


# --- turning things ------------------------------------------------------------

func _on_tap(event: InputEvent) -> void:
	if _finished_level or not UiKit.is_press(event):
		return
	var at: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	for piece in _pieces:
		if (piece["at"] as Vector2).distance_to(at) > 92.0:
			continue
		_use(piece)
		return


func _use(piece: Dictionary) -> void:
	if _piece_ok(piece) and str(piece["kind"]) != "pipes" \
			and str(piece["kind"]) != "mirrors":
		return                          # already done and not re-turnable
	match str(piece["kind"]):
		"order":
			# Pressing out of turn is not a failure: everything unlights and
			# the child starts the sequence again, with nothing lost.
			var next: int = _next_in_order()
			if int(piece["want"]) != next:
				for p in _pieces:
					p["state"] = 0
					_paint(p)
				_slips += 1
				_hints.missed()
				Juice.nudge(piece["node"])
				AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
				_refresh()
				return
			piece["state"] = 1
		"wires":
			piece["state"] = 1
		_:
			piece["state"] = (int(piece["state"]) + 1) % 4
	_paint(piece)
	Juice.pop(piece["node"], 0.2)
	if _piece_ok(piece):
		score_correct()
		_hints.progress()
		AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		Juice.burst(_field, piece["at"], 12)
	else:
		AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
	_refresh()
	if _solved():
		_power_up()


func _next_in_order() -> int:
	var done := 0
	for piece in _pieces:
		if int(piece["state"]) == 1:
			done += 1
	return done + 1


func _refresh() -> void:
	var done := 0
	for piece in _pieces:
		if _piece_ok(piece):
			done += 1
	if _tally != null and is_instance_valid(_tally):
		_tally.text = "%d / %d" % [done, _steps]
	# The lamp brightens as the path completes, so progress is visible on the
	# THING rather than only in a counter.
	var lamp: Node2D = _goal.get_meta("lamp")
	if is_instance_valid(lamp):
		var share: float = float(done) / float(maxi(_steps, 1))
		lamp.modulate = Color(0.42, 0.45, 0.54).lerp(Color(1.0, 0.94, 0.55), share)


## Solved: the light runs down the row and the tower comes on.
func _power_up() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	_quick = _slips == 0
	for i in range(_pieces.size()):
		var piece: Dictionary = _pieces[i]
		get_tree().create_timer(0.14 * float(i)).timeout.connect(func():
			if is_instance_valid(piece["node"]):
				Juice.pop(piece["node"], 0.26)
				Juice.burst(_field, piece["at"], 10)
				AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg"
					% clampi(i + 1, 1, 8)))
	var wait: float = 0.16 * float(_pieces.size()) + 0.3
	get_tree().create_timer(wait).timeout.connect(func():
		var lamp: Node2D = _goal.get_meta("lamp")
		if is_instance_valid(lamp):
			Shapes.glow(lamp, Vector2.ZERO, 260.0, Color(1.0, 0.94, 0.55), 5, 0.6)
			Juice.pop(lamp, 0.5)
		Juice.shockwave(_field, _goal.position + Vector2(0, -86.0), 380.0,
			Color(1.0, 0.94, 0.55))
		AudioManager.play_sfx("res://assets/audio/power_on.ogg"))
	await get_tree().create_timer(wait + 1.5).timeout
	_finish()


# --- the screen ---------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UiKit.theme()
	layer.add_child(_hud)
	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_hud.add_child(back)

	_tally = Label.new()
	_tally.add_theme_font_size_override("font_size", 40)
	_tally.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_tally)
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally.position = Vector2(440, 28)
	_tally.size = Vector2(400, 52)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tally)


## The brief asks for one complete run-through before the child touches it.
## For a mechanism that means: here is the machine, here is a piece being
## turned, now the light gets a bit further.
func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(_goal.position + Vector2(0, -86.0),
		_goal.position + Vector2(0, -86.0), 0.9)
	if not _pieces.is_empty():
		demo.add_step(_pieces[0]["at"], _pieces[0]["at"], 1.1)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo.finished.connect(func(): _field.mouse_filter = Control.MOUSE_FILTER_STOP)
	demo.play()


# --- the three levels of help ---------------------------------------------------

func _next_unsolved() -> Dictionary:
	if str(_kind) == "order":
		var next: int = _next_in_order()
		for piece in _pieces:
			if int(piece["want"]) == next:
				return piece
		return {}
	for piece in _pieces:
		if not _piece_ok(piece):
			return piece
	return {}


func _glow_next() -> void:
	var piece := _next_unsolved()
	if piece.is_empty():
		return
	Juice.pop(piece["node"], 0.3)
	Shapes.glow(piece["node"], Vector2.ZERO, 170.0, Color(1.0, 0.94, 0.55), 4, 0.45)


func _show_the_turn() -> void:
	var piece := _next_unsolved()
	if piece.is_empty():
		return
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(piece["at"], piece["at"], 1.0)
	demo.play()


## Turn one piece to where it should be -- one, not all of them. The child
## still finishes the machine.
func _do_one_for_them() -> void:
	var piece := _next_unsolved()
	if piece.is_empty():
		return
	match str(piece["kind"]):
		"order", "wires":
			piece["state"] = 1
		_:
			piece["state"] = int(piece["want"])
	_paint(piece)
	Juice.pop(piece["node"], 0.3)
	Juice.burst(_field, piece["at"], 12)
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	_refresh()
	if _solved():
		_power_up()


func _finish() -> void:
	result.reached_goal = true
	# Star two: solved without ever turning a piece past its answer -- the
	# child who looked before they touched.
	result.found_hidden = _quick
	result.clean_run = not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(0.9).timeout
	complete_level()
