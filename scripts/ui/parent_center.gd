extends Control
## Behind a press-and-hold plus an arithmetic gate. Shows what the child has
## actually been doing, with no judgement attached and nothing sent anywhere.

var _gate: VBoxContainer
var _content: Control
var _answer: Label
var _typed := ""
var _feedback: Label
var _a := 0
var _b := 0
var _backup_status: Label


func _ready() -> void:
	theme = UiKit.theme()
	# The one screen with no world behind it. That is deliberate: this side of
	# the parent gate belongs to an adult, and it should look like a settings
	# page rather than like the game -- a child who gets this far should be in
	# no doubt they have left the island. It is still built from the same
	# palette and the same buttons, so it is recognisably the same product.
	UiKit.background(self, Palette.SURFACE_SUNK)
	_build_gate()


func _build_gate() -> void:
	_a = randi_range(12, 29)
	_b = randi_range(13, 28)

	_gate = VBoxContainer.new()
	_gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gate.alignment = BoxContainer.ALIGNMENT_CENTER
	_gate.add_theme_constant_override("separation", 20)
	add_child(_gate)

	# The gate sits on a card rather than floating on a flat grey field, which
	# is what it did before -- the only screen in the game that looked like an
	# unstyled engine default.
	var card := UiKit.card()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 12)
	card_box.custom_minimum_size = Vector2(560, 0)
	card.add_child(card_box)
	var card_holder := CenterContainer.new()
	card_holder.add_child(card)
	_gate.add_child(card_holder)

	var lock: Control = UiKit.picture("lock", 60)
	if lock != null:
		var lock_row := CenterContainer.new()
		lock_row.add_child(lock)
		card_box.add_child(lock_row)

	card_box.add_child(UiKit.title(I18n.t("parent.question") % [_a, _b], UiKit.TYPE_TITLE))

	# The answer, shown, and a numpad the game draws itself. A LineEdit here
	# summoned the OS keyboard -- half the tablet screen of system UI sliding
	# over a children's game, and the one screen transition in the product
	# that Godot did not draw. Ten digits is not a keyboard's job.
	_answer = Label.new()
	_answer.custom_minimum_size = Vector2(280, 52)
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_answer.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
	_answer.add_theme_color_override("font_color", Palette.INK)
	var well := PanelContainer.new()
	var field := StyleBoxFlat.new()
	field.bg_color = Palette.SURFACE_SUNK
	field.set_corner_radius_all(UiKit.RADIUS_CHIP)
	field.set_content_margin_all(8)
	well.add_theme_stylebox_override("panel", field)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.add_child(_answer)
	card_box.add_child(well)

	_feedback = UiKit.title("", UiKit.TYPE_BODY)
	_feedback.add_theme_color_override("font_color", Palette.RED)
	card_box.add_child(_feedback)

	var pad_holder := CenterContainer.new()
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 10)
	pad.add_theme_constant_override("v_separation", 10)
	pad_holder.add_child(pad)
	card_box.add_child(pad_holder)
	for n in range(1, 10):
		pad.add_child(_key(str(n)))
	pad.add_child(_key("del"))
	pad.add_child(_key("0"))
	pad.add_child(_key("ok"))

	var back := UiKit.big_button(I18n.t("common.back"), Palette.SLATE)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(200, 64)
	back.pressed.connect(func(): SceneManager.goto_home())
	card_box.add_child(back)


## One key of the gate's numpad. Digits are quiet ink-on-white chips; the
## check key is the one green thing, because it is the one that means go.
func _key(what: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(104, 60)
	b.focus_mode = Control.FOCUS_NONE
	var face := Palette.GREEN if what == "ok" else Color(1.0, 0.99, 0.96)
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.set_corner_radius_all(UiKit.RADIUS_CHIP)
	style.border_width_bottom = 6
	style.border_color = Palette.edge(face) if what == "ok" \
		else Color(0.78, 0.80, 0.84)
	var down: StyleBoxFlat = style.duplicate()
	down.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", down)
	match what:
		"ok":
			var tick: Control = UiKit.picture("check", 36)
			if tick != null:
				tick.position = Vector2(34, 12)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(tick)
			b.pressed.connect(_check)
		"del":
			var word := Label.new()
			word.text = "\u232b"
			word.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
			word.add_theme_color_override("font_color", Palette.INK_SOFT)
			word.set_anchors_preset(Control.PRESET_FULL_RECT)
			word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			word.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(word)
			b.pressed.connect(func():
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				_typed = _typed.substr(0, maxi(_typed.length() - 1, 0))
				_answer.text = _typed)
		_:
			var digit := Label.new()
			digit.text = what
			digit.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
			digit.add_theme_color_override("font_color", Palette.INK)
			digit.set_anchors_preset(Control.PRESET_FULL_RECT)
			digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(digit)
			b.pressed.connect(func():
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				if _typed.length() < 3:
					_typed += what
					_answer.text = _typed)
	return b


func _check() -> void:
	if _typed.is_valid_int() and int(_typed) == _a + _b:
		AudioManager.play_sfx("res://assets/audio/door.ogg")
		_gate.queue_free()
		_build_content()
	else:
		# A sound aimed at the adult mid-typo, not at a child who guessed:
		# the gentle hint chime, never an error buzz.
		AudioManager.play_sfx("res://assets/audio/hint.ogg")
		_feedback.text = I18n.t("parent.wrong")
		_typed = ""
		_answer.text = ""


func _build_content() -> void:
	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 14)
	_content = root

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title(I18n.t("parent.title"), UiKit.TYPE_DISPLAY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var stats := _compute_stats()
	_add_row(list, I18n.t("parent.playtime_today"),
		I18n.t("parent.minutes") % int(SaveManager.playtime_today() / 60.0))
	_add_row(list, I18n.t("parent.levels_completed"), str(stats.completed))
	_add_row(list, I18n.t("parent.total_stars"), str(SaveManager.total_stars()))
	_add_row(list, I18n.t("parent.accuracy"), "%d%%" % int(stats.accuracy * 100.0))
	_add_row(list, I18n.t("parent.attempts"), str(stats.attempts))

	list.add_child(HSeparator.new())
	list.add_child(_build_difficulty_row())
	list.add_child(_build_language_row())
	list.add_child(_build_limit_row())
	list.add_child(_build_motion_row())
	list.add_child(HSeparator.new())
	list.add_child(_build_unlock_row())
	list.add_child(HSeparator.new())
	_build_backup_section(list)


func _compute_stats() -> Dictionary:
	var completed := 0
	var attempts := 0
	var accuracy_sum := 0.0
	var counted := 0
	for level_id in SaveManager.data["levels"].keys():
		var p: Dictionary = SaveManager.data["levels"][level_id]
		if p.get("completed", false):
			completed += 1
		attempts += int(p.get("attempts", 0))
		accuracy_sum += float(p.get("best_accuracy", 0.0))
		counted += 1
	return {
		"completed": completed,
		"attempts": attempts,
		"accuracy": accuracy_sum / float(counted) if counted > 0 else 0.0,
	}


func _add_row(parent: Control, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(v)
	parent.add_child(row)


## Progress backup: how the iPad's stars reach the Mac and back. No cloud,
## no account -- a small file, carried by AirDrop or WeChat, merged best-of
## on arrival so importing can never lose anything.
func _build_backup_section(list: Control) -> void:
	var title := Label.new()
	title.text = I18n.t("parent.backup_title")
	title.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	list.add_child(title)

	var hint := Label.new()
	hint.text = I18n.t("parent.backup_hint")
	hint.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	hint.add_theme_color_override("font_color", Palette.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var export_btn := UiKit.big_button(I18n.t("parent.export"))
	export_btn.pressed.connect(_on_export_pressed)
	row.add_child(export_btn)
	var import_btn := UiKit.big_button(I18n.t("parent.import"), Palette.GREEN)
	import_btn.pressed.connect(_on_import_pressed)
	row.add_child(import_btn)
	list.add_child(row)

	_backup_status = Label.new()
	_backup_status.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	_backup_status.add_theme_color_override("font_color", Palette.INK_SOFT)
	_backup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_backup_status)


func _on_export_pressed() -> void:
	var path := SaveManager.export_progress()
	if path == "":
		_backup_status.text = I18n.t("parent.export_fail")
		return
	_backup_status.text = I18n.t("parent.export_done") % path
	# On a desktop, open the folder with the file selected. The backup used
	# to land in a place a parent would never think to look (Application
	# Support, six folders deep); pointing at it is most of the feature.
	if OS.has_feature("pc") and OS.has_method("shell_show_in_file_manager"):
		OS.shell_show_in_file_manager(path, true)


func _on_import_pressed() -> void:
	var backups: Array = SaveManager.list_backups()
	if backups.is_empty():
		_backup_status.text = I18n.t("parent.import_none")
		return
	# Newest file wins; the merge underneath is best-of, so even importing
	# an old file by mistake can only add, never subtract.
	var result: Dictionary = SaveManager.import_progress(str(backups[0]["path"]))
	if not bool(result.get("ok", false)):
		_backup_status.text = I18n.t("parent.import_bad")
		return
	_backup_status.text = I18n.t("parent.import_done") % [
		str(result["path"]).get_file(),
		int(result["stars_before"]), int(result["stars_after"])]


## One dial for the whole island. Worth being on this side of the parent
## gate rather than in the child's hands: it is the parent who knows whether
## last week was too easy or last night ended in tears.
func _build_difficulty_row() -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = I18n.t("parent.difficulty")
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(l)

	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	var names := ["parent.diff_gentle", "parent.diff_normal", "parent.diff_brave"]
	for i in range(names.size()):
		picker.add_item(I18n.t(names[i]), i)
	picker.select(clampi(int(SaveManager.get_setting("difficulty", 1)), 0, 2))
	picker.item_selected.connect(func(index: int):
		SaveManager.set_setting("difficulty", index))
	row.add_child(picker)
	return row


func _build_language_row() -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = I18n.t("parent.language")
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(l)

	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	var locales: Array = I18n.available_locales()
	for i in range(locales.size()):
		picker.add_item(str(locales[i]).to_upper(), i)
		if locales[i] == I18n.locale:
			picker.select(i)
	picker.item_selected.connect(func(index: int):
		I18n.set_locale(str(locales[index]))
		SceneManager.goto_scene("res://scenes/parent/ParentCenter.tscn")
	)
	row.add_child(picker)
	return row


## Confetti and bouncing delight most children and overwhelm some. A child who
## is overstimulated cannot learn, so this is a real accessibility control, not
## a preference.
func _build_motion_row() -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = I18n.t("parent.reduce_motion")
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(l)

	var toggle := CheckButton.new()
	toggle.button_pressed = bool(SaveManager.get_setting("reduce_motion", false))
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on: bool): SaveManager.set_setting("reduce_motion", on))
	row.add_child(toggle)
	return row


## Open the whole island, for testing it.
##
## Two things this row is careful about. It changes nothing in the save -- see
## SaveManager.is_level_unlocked() -- so turning it off puts every lock back
## exactly where it was. And it says so underneath, because the failure mode
## here is not a bug, it is a parent leaving it on: a six-year-old who finds
## the whole island already open has lost the only thing the map was for.
func _build_unlock_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = I18n.t("parent.test_unlock")
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(l)

	var toggle := CheckButton.new()
	toggle.button_pressed = SaveManager.test_unlock_all()
	toggle.focus_mode = Control.FOCUS_NONE
	row.add_child(toggle)
	box.add_child(row)

	var note := Label.new()
	note.text = I18n.t("parent.test_unlock_note")
	note.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	note.add_theme_color_override("font_color", Palette.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(700, 0)
	box.add_child(note)

	toggle.toggled.connect(func(on: bool):
		SaveManager.set_setting(SaveManager.TEST_UNLOCK, on)
		note.text = I18n.t("parent.test_unlock_on" if on
			else "parent.test_unlock_note")
		note.add_theme_color_override("font_color",
			Palette.STAR_ON if on else Palette.MUTED))
	if toggle.button_pressed:
		note.text = I18n.t("parent.test_unlock_on")
		note.add_theme_color_override("font_color", Palette.STAR_ON)
	return box


func _build_limit_row() -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = I18n.t("parent.daily_limit")
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	row.add_child(l)

	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 120
	spin.step = 5
	spin.value = float(SaveManager.get_setting("daily_limit_minutes", 30))
	spin.value_changed.connect(func(v: float): SaveManager.set_setting("daily_limit_minutes", int(v)))
	row.add_child(spin)
	return row
