extends LevelManager
## "Do it back." The listening game.
##
## Three ways to ask the same question, sharing one screen and one set of pads
## so a child who learned the lights can do the sounds without being retaught:
##
##   lights   the pads flash a phrase; tap it back
##   sounds   the pads sing a phrase with their eyes shut; tap it back
##   copy     a little figure does two or three actions; tap them in order
##
## The rules that make it playable at six, all of them from the brief:
##
##   * start at TWO. Only grow to three, four, five if the last round was right
##   * no rhythm accuracy at all -- order is the whole test, and there is no
##     clock between taps
##   * a mistake replays the phrase and costs the round, never the level
##   * every pad shows a SHAPE as well as a colour, so this works for a child
##     who cannot tell red from green
##
## `light_echo` proved this loop works and `memory_match` proved the pairs; this
## is the two of them in one template with the sharp edges taken off.

const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")

## The pads. Four is right: five is where a six-year-old starts guessing.
const PAD_COLOURS := [
	Color(0.92, 0.34, 0.32), Color(0.34, 0.60, 0.95),
	Color(1.00, 0.80, 0.24), Color(0.36, 0.78, 0.46),
]
const PAD_SHAPES := ["star", "moon", "heart", "leaf"]
const LEAD_IN := 1.2              # quiet before the phrase, so it is not missed
const GAP := 0.72                 # between notes: unhurried on purpose

var _hud: Control
var _field: Control
var _hints: Hints
var _picker: Picker
var _mode := "lights"
var _pads: Array = []             # [{node, at, colour, index, lamp}]
var _phrase: Array = []
var _typed := 0
var _round := 0
var _rounds := 4
var _listening := false
var _slips := 0
var _helped := false
var _perfect := true
var _encore := false               # the bonus round, worth star two
var _lamps: HBoxContainer
var _finished_level := false


func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_mode = str(config.get("mode", "lights"))
	_rounds = clampi(Hints.extra_things(harder_i(int(config.get("rounds", 4)), 1)), 3, 5)

	build_world(self, 0.55)      # a listening game should not be busy
	_field = UiKit.play_area(self, true)
	_field.gui_input.connect(_on_tap)

	_build_pads()
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_replay, _flash_next, _tap_it_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_play_tutorial()


# --- the pads ------------------------------------------------------------------

func _build_pads() -> void:
	var span := 840.0
	for i in range(4):
		var at := Vector2(640.0 + (float(i) - 1.5) * (span / 4.0), 430.0)
		var node := Node2D.new()
		node.position = at
		_field.add_child(node)
		Shapes.ground_shadow(node, Vector2(0, 96.0), 190.0, 0.20)
		Shapes.lit(node, Shapes.rounded_rect(Vector2(-88, -88), Vector2(176, 176), 34.0),
			PAD_COLOURS[i].darkened(0.34), 1.0)
		# The lamp is a separate node so lighting up is a modulate, not a redraw.
		var lamp := Node2D.new()
		node.add_child(lamp)
		Shapes.fill(lamp, Shapes.rounded_rect(Vector2(-74, -74), Vector2(148, 148), 28.0),
			PAD_COLOURS[i], 0.0)
		lamp.modulate.a = 0.30
		# A shape as well as a colour. Every pad is told apart two ways, so a
		# child who cannot separate red from green is not locked out.
		var mark: Control = UiKit.picture(PAD_SHAPES[i], 66)
		if mark != null:
			mark.position = Vector2(-33, -33)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(mark)
		_pads.append({"node": node, "at": at, "index": i, "lamp": lamp})


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

	# One lamp per round, so "how much is left" is a picture. They fill from
	# the left as rounds are won and never empty again.
	_lamps = HBoxContainer.new()
	_lamps.add_theme_constant_override("separation", 16)
	_lamps.position = Vector2(640.0 - float(_rounds) * 32.0, 30)
	_lamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_lamps)
	for i in range(_rounds):
		var pip := Control.new()
		pip.custom_minimum_size = Vector2(48, 48)
		pip.pivot_offset = Vector2(24, 24)
		var art := Node2D.new()
		pip.add_child(art)
		Shapes.fill(art, Shapes.circle_points(Vector2(24, 24), 20.0, 20),
			Color(0.05, 0.09, 0.20, 0.5), 0.0)
		pip.modulate = Color(1, 1, 1, 0.35)
		_lamps.add_child(pip)


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(_pads[0]["at"], _pads[0]["at"], 0.9)
	demo.add_step(_pads[2]["at"], _pads[2]["at"], 0.9)
	demo.finished.connect(_start_round)
	demo.play()


# --- a round -------------------------------------------------------------------

func _start_round() -> void:
	if _finished_level:
		return
	if _round >= _rounds:
		# Everything done. A perfect run earns one more phrase, just for fun.
		if _perfect and not _encore:
			_encore = true
			_round = _rounds        # keeps the lamps full
			_build_phrase(_rounds + 2)
			_play_phrase()
			return
		_finish()
		return
	# Two to start, then one more per round -- and only because the last one
	# was right, since a wrong round replays at the same length.
	_build_phrase(2 + _round)
	_play_phrase()


func _build_phrase(length: int) -> void:
	_phrase.clear()
	_typed = 0
	var last := -1
	for i in range(clampi(length, 2, 5)):
		# Never the same pad twice running: "red red" is unreadable at six --
		# a child cannot tell one long flash from two short ones.
		var pick: int = _picker.whole(0, 3)
		while pick == last:
			pick = _picker.whole(0, 3)
		last = pick
		_phrase.append(pick)


func _play_phrase() -> void:
	_listening = false
	_hints.pause_watching(true)
	var t := create_tween()
	t.tween_interval(LEAD_IN)
	for i in range(_phrase.size()):
		var index: int = _phrase[i]
		t.tween_callback(func(): _sing(index))
		t.tween_interval(GAP)
	t.tween_callback(func():
		_listening = true
		_hints.pause_watching(false))


## One pad's turn to speak. In sound mode the pad does not light -- the note
## is the only clue, which is a genuinely different puzzle from the same pads.
func _sing(index: int) -> void:
	var pad: Dictionary = _pads[index]
	AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (index + 1))
	if _mode == "sounds":
		return
	var lamp: Node2D = pad["lamp"]
	if not is_instance_valid(lamp):
		return
	lamp.modulate.a = 1.0
	Juice.pop(pad["node"], 0.16)
	get_tree().create_timer(GAP * 0.62).timeout.connect(func():
		if is_instance_valid(lamp):
			lamp.modulate.a = 0.30)


# --- tapping it back ------------------------------------------------------------

func _on_tap(event: InputEvent) -> void:
	if _finished_level or not _listening or not UiKit.is_press(event):
		return
	var at: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	for pad in _pads:
		if (pad["at"] as Vector2).distance_to(at) > 100.0:
			continue
		_press(pad)
		return


func _press(pad: Dictionary) -> void:
	var index: int = pad["index"]
	# Always answer the touch, right or wrong: a tap that does nothing is the
	# bug that made the old dance level unplayable.
	var lamp: Node2D = pad["lamp"]
	if is_instance_valid(lamp):
		lamp.modulate.a = 1.0
		get_tree().create_timer(0.24).timeout.connect(func():
			if is_instance_valid(lamp):
				lamp.modulate.a = 0.30)
	Juice.pop(pad["node"], 0.18)
	AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (index + 1))

	if index != int(_phrase[_typed]):
		_wrong(pad)
		return
	_typed += 1
	Juice.burst(_field, pad["at"], 8)
	if _typed < _phrase.size():
		return
	_round_won()


func _wrong(pad: Dictionary) -> void:
	_slips += 1
	_perfect = false
	_listening = false
	score_mistake()
	_hints.missed()
	Juice.nudge(pad["node"])
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
	# The phrase comes round again, same length. Nothing is lost but the try.
	_typed = 0
	get_tree().create_timer(0.7).timeout.connect(func():
		if not _finished_level:
			_play_phrase())


func _round_won() -> void:
	score_correct()
	_hints.progress()
	AudioManager.play_sfx("res://assets/audio/found.ogg")
	if _encore:
		_finish()
		return
	if _round < _lamps.get_child_count():
		var pip: Control = _lamps.get_child(_round)
		pip.modulate = Color(1, 1, 1, 1.0)
		Juice.pop(pip, 0.34)
	_round += 1
	for pad in _pads:
		Juice.pop(pad["node"], 0.2)
	get_tree().create_timer(1.0).timeout.connect(_start_round)


# --- the three levels of help ---------------------------------------------------

## One: play it again. Most of the time this is all a child needed -- they
## were still looking at the ceiling when it started.
func _replay() -> void:
	if _finished_level or not _listening:
		return
	_typed = 0
	_play_phrase()


## Two: play it again, and flash the NEXT pad a little harder each time.
func _flash_next() -> void:
	if _finished_level:
		return
	var index: int = int(_phrase[mini(_typed, _phrase.size() - 1)])
	var pad: Dictionary = _pads[index]
	Juice.pop(pad["node"], 0.34)
	Shapes.glow(pad["node"], Vector2.ZERO, 210.0, PAD_COLOURS[index], 4, 0.5)


## Three: tap all of it except the last one, and leave that for the child.
func _tap_it_for_them() -> void:
	if _finished_level or _phrase.is_empty():
		return
	while _typed < _phrase.size() - 1:
		var index: int = int(_phrase[_typed])
		_typed += 1
		var pad: Dictionary = _pads[index]
		Juice.pop(pad["node"], 0.2)
	_flash_next()


func _finish() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	result.reached_goal = true
	result.found_hidden = _encore
	result.clean_run = _slips == 0 and not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	for i in range(_pads.size()):
		var pad: Dictionary = _pads[i]
		get_tree().create_timer(0.12 * float(i)).timeout.connect(func():
			var lamp: Node2D = pad["lamp"]
			if is_instance_valid(lamp):
				lamp.modulate.a = 1.0
			Juice.pop(pad["node"], 0.3)
			AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (i + 1)))
	Juice.burst(_field, Vector2(640, 430), 40)
	await get_tree().create_timer(1.5).timeout
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	complete_level()
