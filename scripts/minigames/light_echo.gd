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

const PAD_SIZE := Vector2(150, 150)
const NOTE_GAP := 0.62
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
var _ear_badge: Control        # "the island is singing -- listen"
var _tap_badge: Control        # "your turn -- tap"
var _replay: Button            # hear the song again, free, any time


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_pad_count = clampi(int(config.get("pads", 4)), 3, 5)
	_sequence_start = clampi(int(config.get("sequence_start", 2)), 1, 6)
	_sequence_max = clampi(int(config.get("sequence_max", 4)), _sequence_start, 8)

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

	# Pads in a gentle arc, big and forgiving.
	var colors: Array = config.get("colors", DEFAULT_COLORS)
	var spacing := 40.0
	var total: float = _pad_count * PAD_SIZE.x + (_pad_count - 1) * spacing
	var start_x: float = (1280.0 - total) / 2.0 + 60.0
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
	_play_sequence()


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

func _start_round() -> void:
	var length: int = mini(_sequence_start + result.correct, _sequence_max)
	_sequence.clear()
	var previous := -1
	for i in range(length):
		var pick := randi() % _pad_count
		# No triple repeats: they are hard to count by ear at six.
		if pick == previous and randi() % 2 == 0:
			pick = (pick + 1) % _pad_count
		_sequence.append(pick)
		previous = pick
	_play_sequence()


func _play_sequence() -> void:
	_listening = false
	_position = 0
	_instruction.text = I18n.t("echo.listen")
	_show_state(false)
	await get_tree().create_timer(0.8).timeout
	for index in _sequence:
		if not is_inside_tree():
			return
		_sing_pad(index)
		await get_tree().create_timer(NOTE_GAP).timeout
	_listening = true
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
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
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
		# Not that note. The song simply plays again -- hearing it twice is
		# help, not punishment.
		_listening = false
		_instruction.text = I18n.t("echo.again")
		score_mistake()
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			_play_sequence()
		return

	_position += 1
	if _position < _sequence.size():
		return

	# The whole song, echoed back.
	_listening = false
	_hero.celebrate()
	Juice.burst(_play_area, _pads[index]["node"].position + PAD_SIZE / 2.0, 20)
	score_correct()
	_update_progress()
	if not result.met_target():
		await get_tree().create_timer(1.1).timeout
		if is_inside_tree():
			_start_round()


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", 5)]
