extends LevelManager
## "Put each thing where it belongs." The dragging game.
##
## The old sorting levels asked a child to TAP a bin. This one asks them to
## carry the thing there, which is both what the brief asked for and a
## genuinely different act: tapping is choosing, dragging is doing. A
## six-year-old who drags a banana into the fruit basket has moved a banana.
##
## All the feel lives in `DragField` -- lift, glow, snap, float home -- so a
## drag here behaves exactly like a drag in the repair levels. This file only
## decides what the bins are, what the things are, and which goes where.
##
## Nothing can be failed. A wrong drop floats back and the bin shakes its
## head; the item is still there, the child is still there, and the only
## record kept is whether they needed help, which is the third star.

const Field := preload("res://scripts/shared/drag_field.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")

## Where the thing waiting to be sorted sits, and where the bins go. One item
## at a time in the middle, bins along the bottom: the shortest possible drag
## for the shortest possible arm.
## Where the thing to sort appears, against the design size. Everything reads
## it through _stage_at, which is the same point on the real screen.
const STAGE := Vector2(640, 300)

var _stage_at := STAGE
## Where the bins stand, against the 1280x720 the art was drawn at. Put on the
## real screen through Fit.at() -- the world's ground plane moves down on a
## tablet and bins left at a hard 560 hang in the air above it.
const BIN_Y := 560.0

var _field: Field
var _hud: Control
var _hints: Hints
var _picker: Picker
var _queue: Array = []            # the things still to come
var _current: Dictionary = {}
var _bins: Array = []
var _done := 0
var _wanted := 8
var _slips := 0
var _helped := false
var _gift_at := -1                # which item in the run is the shiny one
var _gift_found := false
var _pips: HBoxContainer          # one per thing to sort, lit as they go
var _note: Label                  # the odd sentence, on its own line
var _bin_glow: Node2D             # the level-one hint, so it can be put out
var _finished_level := false


func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_wanted = clampi(Hints.extra_things(harder_i(int(config.get("count", 8)), 2)), 4, 12)

	build_world(self, 0.45)      # a sorting task should not fight the scenery
	_field = Field.new()
	add_child(_field)
	_field.dropped.connect(_on_dropped)
	_stage_at = Fit.at(_field, STAGE)

	_build_bins(config)
	_build_queue(config)
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_glow_right_bin, _show_the_drag, _do_it_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)

	# The shiny one: somewhere in the middle of the run, so it is a surprise
	# rather than a first impression or a leftover.
	_gift_at = _picker.whole(2, maxi(_wanted - 2, 3))
	_play_tutorial()
	_next_item()


# --- the bins ------------------------------------------------------------------

func _build_bins(config: Dictionary) -> void:
	var kinds: Array = config.get("bins", [])
	if kinds.is_empty():
		kinds = [{"key": "toy", "icon": "teddy", "colour": "#5fb0e8"},
			{"key": "danger", "icon": "warning", "colour": "#e2703c"},
			{"key": "plant", "icon": "leaf", "colour": "#4fa86b"}]
	# Left to right in a shuffled order, so a child who memorised "the toy box
	# is the left one" has to look at the picture on their second play.
	var order: Array = kinds.duplicate()
	_picker.shuffle(order)
	var span: float = 1120.0
	for i in range(order.size()):
		var kind: Dictionary = order[i]
		var x: float = 640.0 + (float(i) - float(order.size() - 1) * 0.5) \
			* (span / float(maxi(order.size(), 1)))
		var node := _draw_bin(kind)
		_field.add_child(node)
		var slot := _field.add_slot(node, Fit.at(_field, Vector2(x, BIN_Y)),
			str(kind.get("key", "")))
		slot["offset_y"] = -40.0
		_bins.append({"slot": slot, "kind": kind, "node": node})


func _draw_bin(kind: Dictionary) -> Node2D:
	var node := Node2D.new()
	var tint := Color.from_string(str(kind.get("colour", "#5fb0e8")), Color.SKY_BLUE)
	Shapes.ground_shadow(node, Vector2.ZERO, 210.0, 0.22)
	# An open crate, tipped toward the child so the inside is visible: a box
	# with a lid is a box you cannot see the point of.
	Shapes.lit(node, PackedVector2Array([
		Vector2(-96.0, -110.0), Vector2(96.0, -110.0),
		Vector2(78.0, 0.0), Vector2(-78.0, 0.0),
	]), tint, 1.0)
	Shapes.fill(node, PackedVector2Array([
		Vector2(-96.0, -110.0), Vector2(96.0, -110.0),
		Vector2(80.0, -86.0), Vector2(-80.0, -86.0),
	]), tint.darkened(0.30), 0.0)
	# The label: the picture of what goes in, big, on the front.
	var art: Control = UiKit.picture(str(kind.get("icon", "")), 62)
	if art != null:
		art.position = Vector2(-31, -80)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)
	return node


# --- the things ----------------------------------------------------------------

func _build_queue(config: Dictionary) -> void:
	var pool: Array = config.get("items", [])
	if pool.is_empty():
		pool = [{"icon": "teddy", "key": "toy"}, {"icon": "ball", "key": "toy"},
			{"icon": "blocks", "key": "toy"}, {"icon": "knife", "key": "danger"},
			{"icon": "matches", "key": "danger"}, {"icon": "scissors", "key": "danger"},
			{"icon": "leaf", "key": "plant"}, {"icon": "carrot", "key": "plant"},
			{"icon": "berries", "key": "plant"}, {"icon": "crayon", "key": "toy"}]
	# Only bins we actually built can be answered, or the level is unfinishable.
	var keys: Array = []
	for bin in _bins:
		keys.append(str(bin["kind"].get("key", "")))
	var usable: Array = []
	for item in pool:
		if keys.has(str(item.get("key", ""))):
			usable.append(item)
	_queue = _picker.some(usable, _wanted)
	# Short pools repeat rather than shorten the level.
	while _queue.size() < _wanted and not usable.is_empty():
		_queue.append(_picker.one(usable))


func _next_item() -> void:
	if _done >= _wanted:
		_finish()
		return
	var spec: Dictionary = _queue[_done % _queue.size()]
	var node := Node2D.new()
	var shiny: bool = _done == _gift_at
	if shiny:
		Shapes.glow(node, Vector2.ZERO, 130.0, Color(1.0, 0.88, 0.42), 5, 0.45)
	var art: Control = UiKit.picture(str(spec.get("icon", "")), 108)
	if art != null:
		art.position = Vector2(-54, -54)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)
	_field.add_child(node)
	_current = _field.add_item(node, _stage_at, str(spec.get("key", "")))
	_current["shiny"] = shiny
	# It floats down into place, so the child's eye follows it to the middle.
	if Juice.motion_enabled():
		node.position = _stage_at + Vector2(0, -120.0)
		var t := node.create_tween()
		t.tween_property(node, "position", _stage_at, 0.34)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("res://assets/audio/pop.ogg")


func _on_dropped(item: Dictionary, slot: Dictionary, correct: bool) -> void:
	if _finished_level:
		return
	# Let go over empty ground: a fumble, not an answer. The field has already
	# floated the thing home, which is all the reply it needs. Counting it as a
	# mistake cost a star for a slipped thumb, and hints.missed() would have
	# escalated straight to a hint (misses_before_help is 1) and cost the
	# third star as well.
	if slot.is_empty():
		return
	if not correct:
		_slips += 1
		score_mistake()
		_hints.missed()
		_say("sorting.try_again")
		return
	_done += 1
	score_correct()
	_hints.progress()
	_unglow_bin()
	if bool(item.get("shiny", false)):
		_gift_found = true
		Juice.shockwave(_field, (item["node"] as Node2D).position, 200.0,
			Color(1.0, 0.88, 0.42))
		AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	_refresh_tally()
	# A beat before the next one, so the click-in gets to be the whole event.
	get_tree().create_timer(0.42).timeout.connect(func():
		if not _finished_level:
			_next_item())


# --- the screen ----------------------------------------------------------------

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

	# One star per thing to sort, lit as they go in. Centred on the REAL
	# screen width, clear of the back button on the left.
	var view: Vector2 = _hud.get_viewport_rect().size
	_pips = UiKit.pip_row("star", _wanted)
	_pips.position = Vector2(view.x * 0.5 - UiKit.pip_row_width(_wanted) * 0.5, 26)
	_hud.add_child(_pips)

	# The sentence ("not that box") lives under the counter, never on it: the
	# old label was both, and every wrong drop wiped the score for a second.
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 32)
	_note.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_note)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(view.x * 0.5 - 300.0, 88)
	_note.size = Vector2(600, 46)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_note)
	_refresh_tally()


func _refresh_tally() -> void:
	UiKit.pip_fill(_pips, _done)


func _say(key: String) -> void:
	if _note == null or not is_instance_valid(_note):
		return
	_note.text = I18n.t(key)
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(_note):
			_note.text = "")


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(_stage_at, _stage_at, 0.9)
	if not _bins.is_empty():
		demo.add_step(_stage_at, ((_bins[0]["slot"] as Dictionary)["node"] as Node2D).position,
			1.2)
	demo.play()


# --- the three levels of help ---------------------------------------------------

func _right_bin() -> Dictionary:
	if _current.is_empty():
		return {}
	for bin in _bins:
		if str(bin["kind"].get("key", "")) == str(_current["key"]):
			return bin
	return {}


func _glow_right_bin() -> void:
	var bin := _right_bin()
	if bin.is_empty():
		return
	var node: Node2D = bin["node"]
	if is_instance_valid(node):
		Juice.pop(node, 0.3)
		# One glow, on the bin the CURRENT thing wants. It used to be added and
		# never removed, so after the drop the old bin kept shining and the
		# next hint lit a second one: two answers to a one-answer question.
		_unglow_bin()
		_bin_glow = Shapes.glow(node, Vector2(0, -60.0), 190.0,
			Color(1.0, 0.94, 0.55), 4, 0.45)
		_bin_glow.set_meta("hint_glow", true)


func _unglow_bin() -> void:
	if _bin_glow != null and is_instance_valid(_bin_glow):
		_bin_glow.queue_free()
	_bin_glow = null


func _show_the_drag() -> void:
	var bin := _right_bin()
	if bin.is_empty() or _current.is_empty():
		return
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step((_current["node"] as Node2D).position,
		(bin["node"] as Node2D).position, 1.1)
	demo.play()


func _do_it_for_them() -> void:
	if _current.is_empty() or bool(_current["placed"]):
		return
	_field.place_for_them(_current)
	_done += 1
	_unglow_bin()
	_refresh_tally()
	get_tree().create_timer(0.5).timeout.connect(func():
		if not _finished_level:
			_next_item())


func _finish() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	result.reached_goal = true
	result.found_hidden = _gift_found
	result.clean_run = _slips == 0 and not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	# The bins do a little bow: the child put everything away and the room
	# says thank you.
	for bin in _bins:
		Juice.pop(bin["node"], 0.34)
	Juice.burst(_field, Fit.at(_field, Vector2(640, 420)), 40)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(1.3).timeout
	complete_level()
