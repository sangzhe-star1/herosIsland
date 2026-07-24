extends LevelManager
## Memory template: cards face down, find the pairs.
##
## Powers the memory levels from each level's "config" block: which icons to
## pair, how many columns, which scene art sits behind. One more classic that
## needs no reading -- the pictures ARE the game.
##
## Memory-specific mercy rules, on top of the house rules:
##  - A miss is not a mistake. Forgetting where a card was IS the game at
##    six; only the stars-from-mistakes rule would turn memory into anxiety.
##    Misses flip quietly back and cost nothing.
##  - Cards never shuffle mid-round and never disappear: found pairs stay
##    face up and green, so the board only ever gets easier.

const CARD_SIZE := Vector2(170, 170)
const FLIP_TIME := 0.11

var _icons: Array = []
var _columns := 4
var _cards: Array = []            # [{node, icon, found, showing, face, back}]
var _first_pick := -1
var _busy := false

var _play_area: Control
var _instruction: Label
var _progress: Label


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_icons = (config.get("icons", ["teddy", "ball", "blocks", "crayon"]) as Array).duplicate()
	_columns = int(config.get("columns", 4))
	_build_ui(config)
	_deal()


# --- construction -------------------------------------------------------

func _build_ui(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	var bg := ColorRect.new()
	bg.color = Color.from_string(str(config.get("background", "#efe7d8")), Color(0.93, 0.9, 0.84))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(bg)
	UiKit.scene_art(_play_area, config)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "memory.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.INK)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 34)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.INK)
	_progress.position = Vector2(1020, 38)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()


func _deal() -> void:
	var deck: Array = []
	for icon_name in _icons:
		deck.append(str(icon_name))
		deck.append(str(icon_name))
	deck.shuffle()

	var rows: int = ceili(float(deck.size()) / float(_columns))
	var spacing := 26.0
	var grid_w: float = _columns * CARD_SIZE.x + (_columns - 1) * spacing
	var grid_h: float = rows * CARD_SIZE.y + (rows - 1) * spacing
	var origin := Vector2((1280.0 - grid_w) / 2.0, 120.0 + (560.0 - grid_h) / 2.0)

	for i in range(deck.size()):
		var column: int = i % _columns
		var row: int = i / _columns
		var at := origin + Vector2(column * (CARD_SIZE.x + spacing), row * (CARD_SIZE.y + spacing))
		_cards.append(_build_card(i, str(deck[i]), at))

	# Cards deal in one after another -- watching the board get made is part
	# of the little ritual of a memory game.
	if Juice.motion_enabled():
		for i in range(_cards.size()):
			var node: Control = _cards[i]["node"]
			node.scale = Vector2.ZERO
			var t := node.create_tween()
			t.tween_interval(0.05 * float(i))
			t.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _build_card(index: int, icon_name: String, at: Vector2) -> Dictionary:
	var node := Panel.new()
	node.size = CARD_SIZE
	node.position = at
	node.pivot_offset = CARD_SIZE / 2.0
	node.mouse_filter = Control.MOUSE_FILTER_STOP

	var back_style: StyleBox = UiKit.texture_style("res://assets/ui/level_card.png", 36.0, 12.0)
	if back_style == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.13, 0.22, 0.42)
		flat.set_corner_radius_all(22)
		flat.border_width_bottom = 6
		flat.border_color = Color(0.08, 0.14, 0.30)
		back_style = flat
	node.add_theme_stylebox_override("panel", back_style)

	# Back face: a question spark, "something is hiding here".
	var back_icon: Control = UiKit.picture("spark", CARD_SIZE.x * 0.40)
	if back_icon != null:
		back_icon.position = CARD_SIZE * 0.30
		back_icon.modulate = Color(1, 1, 1, 0.5)
		node.add_child(back_icon)

	# Front face: white card with the item picture; hidden until flipped.
	var face := Panel.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.add_theme_stylebox_override("panel", UiKit.panel_style(Palette.SURFACE, 22))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.visible = false
	var face_icon: Control = UiKit.picture(icon_name, CARD_SIZE.x * 0.62)
	if face_icon != null:
		face_icon.position = CARD_SIZE * 0.19
		face.add_child(face_icon)
	node.add_child(face)

	node.gui_input.connect(_on_card_input.bind(index))
	_play_area.add_child(node)
	return {"node": node, "icon": icon_name, "found": false, "showing": false, "face": face}


# --- play -----------------------------------------------------------------

func _on_card_input(event: InputEvent, index: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or _busy:
		return
	var card: Dictionary = _cards[index]
	if card["found"] or card["showing"]:
		return

	await _flip(index, true)

	if _first_pick == -1:
		_first_pick = index
		return

	var first: Dictionary = _cards[_first_pick]
	var second: Dictionary = _cards[index]
	var first_index := _first_pick
	_first_pick = -1

	if first["icon"] == second["icon"]:
		_match_found(first_index, index)
	else:
		# Not a mistake -- just not this time. Both flip quietly back after a
		# beat long enough to LOOK, because looking is how the child wins.
		_busy = true
		_instruction.text = I18n.t("memory.look_again")
		await get_tree().create_timer(1.0).timeout
		await _flip(first_index, false)
		await _flip(index, false)
		_busy = false


func _match_found(a: int, b: int) -> void:
	for index in [a, b]:
		var card: Dictionary = _cards[index]
		card["found"] = true
		var node: Control = card["node"]
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.modulate = Color(0.78, 1.0, 0.82)
		Juice.pop(node, 0.22)
		Juice.burst(_play_area, node.position + CARD_SIZE / 2.0, 12)
	_instruction.text = I18n.t("memory.instruction")
	score_correct()
	_update_progress()


## Scale-x flip: squeeze shut, swap faces, spring open. Instant under
## reduce-motion -- the card just changes.
func _flip(index: int, face_up: bool) -> void:
	var card: Dictionary = _cards[index]
	var node: Control = card["node"]
	var face: Control = card["face"]
	card["showing"] = face_up

	if not Juice.motion_enabled():
		face.visible = face_up
		return

	_busy = true
	var t := node.create_tween()
	t.tween_property(node, "scale:x", 0.06, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	if not is_instance_valid(node):
		_busy = false
		return
	face.visible = face_up
	var t2 := node.create_tween()
	t2.tween_property(node, "scale:x", 1.0, FLIP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t2.finished
	_busy = false


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", _icons.size())]
