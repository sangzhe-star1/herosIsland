extends LevelManager
## Echo template: the light pads sing a little song, the child sings it back
## by tapping. A brand-new kind of interaction for the game -- listen, hold
## it in your head, reproduce it -- and the gentlest one: the game waits
## forever for the answer, and a wrong note just means hearing the song
## again.
##
## The pads play the island theme's own pentatonic notes (C D E G A), so the
## game and its music teach each other. The hero's chest light sings along,
## turning the colour of every note -- the same light that answers colours
## in Repair the Energy Tower.
##
## Powers the Light Song levels via "config": pad count, starting length,
## maximum length, colours. Challenge-ready: rank stretches the song.
##
## The hard part for a six-year-old is not remembering the notes, it is
## understanding that ORDER is the whole point. A real playtester watched
## yellow-then-green light up and tapped GREEN -- the last thing he saw --
## and got told he was wrong by a sentence he cannot read. So the lamps
## above the pads now carry the phrase's COLOURS in order while the island
## sings, the first phrase of every level keeps them showing while he
## answers (a copy-the-recipe round that teaches the rule), and any wrong
## tap reveals them again instead of hiding the answer behind a retry.

const PAD_SIZE := Vector2(150, 150)
## The demo's pace. Slower than the first cut: a phrase that has come and
## gone before the child has finished looking up is not a demo, it is a
## rumour. The lead-in matters as much -- the round used to begin singing
## 0.8 s after the level appeared, while the child was still arriving.
const NOTE_GAP := 0.78
const LEAD_IN := 1.4
## While the child is singing back, a nudge if nothing is tapped for this
## long: the next pad breathes. No-fail games still need a way out of stuck.
const HINT_AFTER := 5.0
const DEFAULT_COLORS := ["#ff5d5d", "#ffd23c", "#7ee06a", "#4fb8ff", "#c493f2"]

var _pad_count := 4
var _sequence_start := 2
var _sequence_max := 4

var _pads: Array = []           # [{node, color, note_index}]
var _sequence: Array = []       # pad indices
var _position := 0              # where the child is in repeating it
var _listening := false         # true while the child may tap

var _play_area: Control
var _instruction: Label
var _progress: Label
var _hero: SkinnedCharacter
const DOT := 56.0

var _dots: Array = []          # one lamp per note in the current phrase
var _dot_row: HBoxContainer
var _revealed := false         # are the lamps showing the phrase's colours?
var _idle := 0.0               # seconds since the child last tapped
var _ear_badge: Control        # "the island is singing -- listen"
var _tap_badge: Control        # "your turn -- tap"
var _replay: Button            # hear the song again, free, any time


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_pad_count = clampi(int(config.get("pads", 4)), 3, 5)
	_sequence_start = clampi(int(config.get("sequence_start", 2)), 1, 6)
	_sequence_max = clampi(int(config.get("sequence_max", 4)), _sequence_start, 8)

	# Difficulty: longer phrases, and Brave starts past the training round.
	_sequence_start = clampi(harder_i(_sequence_start, 1), 1, 6)
	_sequence_max = clampi(harder_i(_sequence_max, 1), _sequence_start, 8)

	# Challenge scaling: the song grows longer, never faster.
	var rank := challenge_rank()
	if rank > 0:
		_sequence_max = clampi(_sequence_max + (rank + 1) / 2, _sequence_max, 8)
		bump_target("correct", mini(rank, 6))

	_build_scene(config)
	_start_round()


# --- construction -------------------------------------------------------

func _build_scene(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	build_world(_play_area, 0.0)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t("echo.listen")
	_instruction.add_theme_font_size_override("font_size", 38)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.75))
	_instruction.add_theme_constant_override("outline_size", 8)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 40)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_progress)
	_progress.position = Vector2(1020, 44)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()

	# The state, without the reading: an EAR medallion while the island
	# sings, a TAPPING-FINGER medallion while it is the child's turn. The
	# playtest that demanded this: the song played its two notes, the screen
	# sat politely waiting, and a six-year-old concluded the game was broken
	# -- "Listen..." and "Your turn!" were just letters to him.
	_ear_badge = _state_badge("ear", Color(1.0, 0.78, 0.30))
	_tap_badge = _state_badge("tap", Color(0.36, 0.78, 0.44))
	_play_area.add_child(_ear_badge)
	_play_area.add_child(_tap_badge)

	# Hear it again, whenever, free. A wrong note already replays the song;
	# this replays it BEFORE being wrong, which is what a child who looked
	# away for two seconds actually needs.
	_replay = Button.new()
	_replay.custom_minimum_size = Vector2(104, 104)
	_replay.position = Vector2(1120, 112)
	_replay.focus_mode = Control.FOCUS_NONE
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.09, 0.15, 0.30, 0.92)
	rp_style.set_corner_radius_all(52)
	rp_style.border_width_bottom = 7
	rp_style.border_width_top = 5
	rp_style.border_width_left = 5
	rp_style.border_width_right = 5
	rp_style.border_color = Color(1.0, 0.78, 0.30)
	for st in ["normal", "hover", "pressed", "disabled"]:
		_replay.add_theme_stylebox_override(st, rp_style)
	var rp_icon: Control = UiKit.picture("sound_on", 62)
	if rp_icon != null:
		rp_icon.position = Vector2(21, 21)
		rp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay.add_child(rp_icon)
	_replay.pivot_offset = Vector2(52, 52)
	_replay.pressed.connect(_on_replay_pressed)
	_play_area.add_child(_replay)

	# The hero conducts from the side; the chest light sings every note.
	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(170, 560)
	_hero.scale = Vector2(1.4, 1.4)
	_play_area.add_child(_hero)

	# The note lamps: one per note in the phrase, above the pads. They fill
	# as the island sings, empty at the handover, and fill again as the child
	# sings back. THIS is the fix for "tapping does nothing": a correct tap
	# used to change nothing a child could see, so two taps into a two-note
	# phrase he had no idea he was winning -- and one wrong guess later the
	# song restarted and he concluded the buttons were dead.
	_dot_row = HBoxContainer.new()
	_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", 18)
	_dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_dot_row)

	# Pads in a gentle arc, big and forgiving.
	var colors: Array = config.get("colors", DEFAULT_COLORS)
	var spacing := 40.0
	var total: float = _pad_count * PAD_SIZE.x + (_pad_count - 1) * spacing
	var start_x: float = (1280.0 - total) / 2.0 + 60.0
	# The lamps hang centred over the pad row, whatever the pad count -- the
	# same numbers, not a guessed constant that drifts when a level asks for
	# three pads or five.
	_dot_row.position = Vector2(start_x, 330.0)
	_dot_row.size = Vector2(total, 54.0)
	for i in range(_pad_count):
		var pad := Panel.new()
		pad.size = PAD_SIZE
		var lift: float = absf(float(i) - float(_pad_count - 1) / 2.0) * 18.0
		pad.position = Vector2(start_x + i * (PAD_SIZE.x + spacing), 400.0 + lift)
		pad.pivot_offset = PAD_SIZE / 2.0
		pad.mouse_filter = Control.MOUSE_FILTER_STOP

		var color := Color.from_string(str(colors[i % colors.size()]), Color.WHITE)
		pad.add_theme_stylebox_override("panel", _pad_style(color, false))
		pad.gui_input.connect(_on_pad_input.bind(i))
		_play_area.add_child(pad)
		_pads.append({"node": pad, "color": color, "note_index": i})


## A big round state medallion: dark coaster, drawn icon, coloured ring.
func _state_badge(icon_name: String, ring_color: Color) -> Control:
	var box := Control.new()
	var size := 104.0
	box.custom_minimum_size = Vector2(size, size)
	box.size = Vector2(size, size)
	box.position = Vector2(640.0 - size * 0.5, 96.0)
	box.pivot_offset = Vector2(size, size) / 2.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Node2D.new()
	box.add_child(pad)
	Shapes.fill(pad, Shapes.circle_points(Vector2(size, size) / 2.0, size * 0.48, 28),
		Color(0.05, 0.09, 0.20, 0.60), 0.0)
	var art: Control = UiKit.picture(icon_name, size * 0.60)
	if art != null:
		art.position = Vector2(size, size) / 2.0 - Vector2(size * 0.30, size * 0.30)
		box.add_child(art)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2(size, size) / 2.0, size * 0.48, 28)
	ring.closed = true
	ring.width = 7.0
	ring.default_color = ring_color
	ring.antialiased = true
	box.add_child(ring)
	return box


## Which medallion is up. Swapping pops the incoming one so the change is an
## event, not a detail.
func _show_state(listening: bool) -> void:
	if _ear_badge != null and is_instance_valid(_ear_badge):
		_ear_badge.visible = not listening
	if _tap_badge != null and is_instance_valid(_tap_badge):
		_tap_badge.visible = listening
		if listening:
			Juice.pop(_tap_badge, 0.30)


func _on_replay_pressed() -> void:
	if not _listening:
		# Already singing: point at the ear. The button never punishes.
		if _ear_badge != null:
			Juice.pop(_ear_badge, 0.25)
		return
	Juice.pop(_replay, 0.15)
	_idle = 0.0
	_play_sequence()


## Rebuild the lamp row for a phrase of `count` notes.
func _build_dots(count: int) -> void:
	if _dot_row == null or not is_instance_valid(_dot_row):
		return
	for child in _dot_row.get_children():
		child.queue_free()
	_dots.clear()
	var centre := Vector2(DOT, DOT) * 0.5
	for i in range(count):
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(DOT, DOT)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.pivot_offset = centre
		var art := Node2D.new()
		art.name = "Art"     # _reveal() looks the swatch up by path
		dot.add_child(art)
		Shapes.fill(art, Shapes.circle_points(centre, DOT * 0.40, 20),
			Color(0.06, 0.10, 0.22, 0.55), 0.0)
		# The colour swatch: invisible until the phrase is revealed, and then
		# it IS the answer for that position -- "yellow, then green".
		var swatch: Polygon2D = Shapes.fill(art,
			Shapes.circle_points(centre, DOT * 0.31, 20), Color(1, 1, 1, 0.0), 0.0)
		swatch.name = "Swatch"
		var ring := Line2D.new()
		ring.name = "Ring"
		ring.points = Shapes.circle_points(centre, DOT * 0.40, 20)
		ring.closed = true
		ring.width = 4.5
		ring.default_color = Color(1.0, 0.94, 0.72, 0.8)
		ring.antialiased = true
		dot.add_child(ring)
		# The done-tick, same green tick badge the pictogram strips use, so a
		# child who has met one has met both.
		var tick := Node2D.new()
		tick.name = "Tick"
		tick.position = centre + Vector2(DOT * 0.26, DOT * 0.26)
		tick.visible = false
		dot.add_child(tick)
		Shapes.fill(tick, Shapes.circle_points(Vector2.ZERO, DOT * 0.17, 14),
			Color(0.36, 0.78, 0.44), 0.0)
		var check := Line2D.new()
		check.points = PackedVector2Array([
			Vector2(-DOT * 0.085, 0.0), Vector2(-DOT * 0.02, DOT * 0.062),
			Vector2(DOT * 0.09, -DOT * 0.07),
		])
		check.width = DOT * 0.055
		check.default_color = Color(1, 1, 1, 0.95)
		check.antialiased = true
		tick.add_child(check)
		_dot_row.add_child(dot)
		_dots.append(dot)


## How many notes of the phrase are done. Ticking one is an event: it pops.
func _set_dots(filled: int) -> void:
	for i in range(_dots.size()):
		var dot: Control = _dots[i]
		if not is_instance_valid(dot):
			continue
		var tick: Node2D = dot.get_node_or_null("Tick")
		if tick == null:
			continue
		var want: bool = i < filled
		if want and not tick.visible:
			Juice.pop(dot, 0.28)
		tick.visible = want
		var ring: Line2D = dot.get_node_or_null("Ring")
		if ring != null:
			ring.default_color = Color(0.36, 0.78, 0.44) if want \
				else Color(1.0, 0.94, 0.72, 0.8)


## Show (or hide) the phrase's colours in the lamps -- the recipe, in order.
## Revealing is how this level teaches and how it rescues; hiding is how it
## becomes a memory game again on the next phrase.
func _reveal(show_colours: bool) -> void:
	_revealed = show_colours
	for i in range(_dots.size()):
		var dot: Control = _dots[i]
		if not is_instance_valid(dot) or i >= _sequence.size():
			continue
		var swatch: Polygon2D = dot.get_node_or_null("Art/Swatch")
		if swatch == null:
			continue
		var colour: Color = _pads[int(_sequence[i])]["color"]
		swatch.color = colour if show_colours else Color(colour.r, colour.g, colour.b, 0.0)


func _pad_style(color: Color, lit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.lightened(0.25) if lit else color.darkened(0.18)
	style.bg_color.a = 1.0 if lit else 0.9
	style.set_corner_radius_all(int(PAD_SIZE.x / 2.0))
	style.border_width_bottom = 8
	style.border_color = color.darkened(0.4)
	if lit:
		style.shadow_color = Color(color.r, color.g, color.b, 0.65)
		style.shadow_size = 26
	return style


# --- the song -----------------------------------------------------------

## A phrase of `length` notes. Pure -- no nodes, no timers -- so the probe
## can generate a hundred of them and check every one.
##
## NEVER the same pad twice running. The old rule allowed it half the time,
## and a phrase like [blue, blue] is unreadable at six: one pad blinking
## twice looks exactly like one pad blinking once. The very first phrase a
## real child met was [blue, blue], which is how this level earned the
## verdict "tapping does nothing".
func make_phrase(length: int) -> Array:
	var out: Array = []
	var previous := -1
	for i in range(length):
		var pick := randi() % _pad_count
		while pick == previous and _pad_count > 1:
			pick = (pick + 1) % _pad_count
		out.append(pick)
		previous = pick
	return out


func _start_round() -> void:
	_sequence = make_phrase(mini(_sequence_start + result.correct, _sequence_max))
	_build_dots(_sequence.size())
	_play_sequence()


func _play_sequence() -> void:
	_listening = false
	_position = 0
	_instruction.text = I18n.t("echo.listen")
	_show_state(false)
	_set_dots(0)
	_reveal(false)
	await get_tree().create_timer(LEAD_IN).timeout
	for i in range(_sequence.size()):
		if not is_inside_tree():
			return
		_sing_pad(int(_sequence[i]))
		# Each lamp takes the colour of the note being sung, left to right.
		# By the end of the demo the strip literally reads the phrase --
		# "yellow, then green" -- which is the ONE thing a child has to
		# understand here and the one thing nothing used to say.
		_paint_lamp(i)
		await get_tree().create_timer(NOTE_GAP).timeout
	_listening = true
	_idle = 0.0
	_set_dots(0)
	# Training wheels: the first phrase of a level is a copy-the-recipe
	# round, colours still showing. From the second phrase on they fade and
	# it becomes the memory game it is named for -- and a wrong tap brings
	# them straight back, so nobody is ever left guessing in the dark.
	if not _teaching():
		_reveal(false)
	_instruction.text = I18n.t("echo.your_turn")
	_show_state(true)
	# The pads bow, one after another: "now these are yours to press".
	if Juice.motion_enabled():
		for i in range(_pads.size()):
			var node: Panel = _pads[i]["node"]
			if not is_instance_valid(node):
				continue
			var t := node.create_tween()
			t.tween_interval(0.07 * float(i))
			t.tween_property(node, "scale", Vector2(1.07, 1.07), 0.11)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(node, "scale", Vector2.ONE, 0.16)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## True while the child has not yet completed a phrase in this level.
func _teaching() -> bool:
	return result.correct == 0


## Colour lamp `i` from the note it belongs to, with a little pop.
func _paint_lamp(i: int) -> void:
	if i >= _dots.size() or i >= _sequence.size():
		return
	var dot: Control = _dots[i]
	if not is_instance_valid(dot):
		return
	var swatch: Polygon2D = dot.get_node_or_null("Art/Swatch")
	if swatch != null:
		swatch.color = _pads[int(_sequence[i])]["color"]
	Juice.pop(dot, 0.30)


## One pad lights, plays its note, and the hero's chest light turns its
## colour. The light IS the note made visible.
func _sing_pad(index: int) -> void:
	var pad: Dictionary = _pads[index]
	var node: Panel = pad["node"]
	var color: Color = pad["color"]

	node.add_theme_stylebox_override("panel", _pad_style(color, true))
	_hero.set_core_color(color)
	AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (int(pad["note_index"]) + 1))
	if Juice.motion_enabled():
		var t := node.create_tween()
		t.tween_property(node, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)

	var timer := get_tree().create_timer(NOTE_GAP * 0.62)
	timer.timeout.connect(func():
		if is_instance_valid(node):
			node.add_theme_stylebox_override("panel", _pad_style(color, false))
	)

	# A note floats off the pad -- the song made visible, so "the island is
	# singing" does not depend on the speaker being loud enough.
	if Juice.motion_enabled():
		var glyph: Control = UiKit.picture("music", 44)
		if glyph != null:
			glyph.position = node.position + Vector2(PAD_SIZE.x * 0.5 - 22.0, -30.0)
			glyph.modulate = color.lightened(0.25)
			_play_area.add_child(glyph)
			var g := glyph.create_tween().set_parallel(true)
			g.tween_property(glyph, "position:y", glyph.position.y - 66.0, 0.65)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			g.tween_property(glyph, "modulate:a", 0.0, 0.65)
			g.chain().tween_callback(glyph.queue_free)


# --- the echo -----------------------------------------------------------

func _on_pad_input(event: InputEvent, index: int) -> void:
	var pressed: bool = UiKit.is_press(event)
	if not pressed:
		return
	if not _listening:
		# Tapped while the island is still singing. Not wrong, just early --
		# the ear medallion pulses to say "listening time", and nothing else
		# happens. A silently ignored tap reads as a broken game.
		if _ear_badge != null and is_instance_valid(_ear_badge):
			Juice.pop(_ear_badge, 0.25)
		return

	_sing_pad(index)

	if index != _sequence[_position]:
		# Not that note -- and specifically, not that note YET, which is the
		# distinction a six-year-old misses. So: the red no-sign over the pad
		# he touched (the same "not this one" he already knows from the other
		# levels), then the recipe revealed, then the song again. Hearing it
		# twice is help, not punishment; SEEING it is help he can act on.
		_listening = false
		_set_dots(0)
		var wrong_pad: Panel = _pads[index]["node"]
		if is_instance_valid(wrong_pad):
			Juice.no_sign(_play_area, wrong_pad.position + PAD_SIZE / 2.0, 130.0)
		_reveal(true)
		_instruction.text = I18n.t("echo.again")
		score_mistake()
		await get_tree().create_timer(1.4).timeout
		if is_inside_tree():
			# Replay with the colours still up: this attempt is a guided one.
			_play_sequence()
			await get_tree().create_timer(0.05).timeout
			_reveal(true)
		return

	_position += 1
	_idle = 0.0
	_set_dots(_position)
	if _position < _sequence.size():
		return

	# The whole song, echoed back.
	_listening = false
	_reveal(false)
	_hero.celebrate()
	Juice.burst(_play_area, _pads[index]["node"].position + PAD_SIZE / 2.0, 20)
	score_correct()
	_update_progress()
	if not result.met_target():
		await get_tree().create_timer(1.1).timeout
		if is_inside_tree():
			_start_round()


## Stuck for a few seconds with the island waiting? The pad he needs next
## breathes, once, quietly. It is a hint rather than an answer only in the
## sense that he still has to tap it -- and a six-year-old who cannot find
## the way in has already lost the level in every way that matters.
func _process(delta: float) -> void:
	super._process(delta)
	if _finished or not _listening or _sequence.is_empty():
		return
	_idle += delta
	if _idle < HINT_AFTER:
		return
	_idle = 0.0
	if _position >= _sequence.size():
		return
	# Stuck with the recipe hidden? Show it -- that is the kinder hint, and
	# it explains the rule rather than just pointing.
	if not _revealed:
		_reveal(true)
	var node: Panel = _pads[int(_sequence[_position])]["node"]
	if not is_instance_valid(node) or not Juice.motion_enabled():
		return
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2(1.14, 1.14), 0.30)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.30)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2(1.14, 1.14), 0.30)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.30)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", 5)]
