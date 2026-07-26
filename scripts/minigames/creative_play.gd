extends LevelManager
## "Make something." The game with no rules.
##
## No timer, no hearts, no score, nothing to get wrong, and no way to lose.
## The child drags stickers and decorations onto their base and it stays
## exactly how they left it, in the save file, for as long as they want it.
##
## This exists because the other eight templates all, however gently, ASK for
## something. A six-year-old who has been asked for things all day needs one
## room where nothing is expected of them, and the brief is right to make it a
## permanent fixture rather than a level you finish and pass.
##
## It is also the only screen in the game whose output belongs to the child
## rather than to the design. Whatever they build is shown on the base and in
## the reward wall, and nobody -- including this file -- ever grades it.

const Picker := preload("res://scripts/shared/variant_picker.gd")

## What can be placed. Deliberately a mixed bag: some of it heroic, some of it
## silly, none of it "correct".
const STICKERS := [
	"star", "heart", "moon", "spark", "leaf", "flag", "medal", "crown",
	"balloon", "music", "paw", "orb", "gem", "party_hat", "wings", "shield",
]
const LIGHT_COLOURS := [
	Color(0.98, 0.82, 0.36), Color(0.52, 0.84, 1.0), Color(0.96, 0.52, 0.62),
	Color(0.56, 0.90, 0.60), Color(0.78, 0.60, 0.98),
]

var _hud: Control
var _canvas: Control
var _tray: Control
var _placed: Array = []           # [{icon, at, size, tint}]
var _dragging: Node2D
var _drag_spec := {}
var _touch := -1
var _light := 0
var _base: Node2D
var _saved_note: Label


## Nothing here completes, so nothing here reports a target.
func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	# Three stars the moment they arrive. There is no version of this room in
	# which a child has done it wrong, and the result screen should not
	# pretend otherwise.
	result.objective_scoring = true
	result.reached_goal = true
	result.found_hidden = true
	result.clean_run = true

	build_world(self, 0.30)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_canvas)

	_build_base()
	_restore()
	_build_hud()
	_build_tray()


# --- the base -----------------------------------------------------------------

func _build_base() -> void:
	_base = Node2D.new()
	_base.position = Vector2(640, 470)
	_canvas.add_child(_base)
	_paint_base()


## The hero's base: a dome on legs with a big window. Redrawn when the child
## changes its light colour, which is the one "setting" this room has.
func _paint_base() -> void:
	for child in _base.get_children():
		child.queue_free()
	var tint: Color = LIGHT_COLOURS[_light % LIGHT_COLOURS.size()]
	Shapes.ground_shadow(_base, Vector2(0, 130.0), 520.0, 0.22)
	Shapes.lit(_base, Shapes.rounded_rect(Vector2(-230, -40), Vector2(460, 170), 26.0),
		Color(0.72, 0.76, 0.86), 1.0)
	var dome := PackedVector2Array()
	for i in range(19):
		var a: float = PI + PI * float(i) / 18.0
		dome.append(Vector2(cos(a) * 236.0, sin(a) * 150.0 - 40.0))
	Shapes.lit(_base, dome, Color(0.80, 0.84, 0.92), 1.0)
	# The window, which is where the light colour actually shows.
	Shapes.glow(_base, Vector2(0, -96.0), 230.0, tint, 5, 0.42)
	Shapes.lit(_base, Shapes.oval_points(Vector2(0, -96.0), Vector2(120.0, 74.0), 26),
		tint, 0.9)
	Shapes.fill(_base, Shapes.oval_points(Vector2(-36.0, -118.0),
		Vector2(38.0, 22.0), 14), Color(1, 1, 1, 0.45), 0.0)
	for leg in [-160.0, 160.0]:
		Shapes.fill(_base, Shapes.taper(Vector2(leg, 128.0), Vector2(leg * 0.8, 20.0),
			26.0, 18.0), Color(0.58, 0.62, 0.72), 0.0)
	# A little aerial, because every base needs one.
	Shapes.fill(_base, Shapes.taper(Vector2(0, -186.0), Vector2(0, -252.0), 7.0, 4.0),
		Color(0.62, 0.66, 0.76), 0.0)
	Shapes.glow(_base, Vector2(0, -258.0), 60.0, tint, 3, 0.5)


# --- what the child put there --------------------------------------------------

func _restore() -> void:
	var saved: Array = SaveManager.get_creation("base")
	for entry in saved:
		var spec := {
			"icon": str(entry.get("icon", "star")),
			"at": Vector2(float(entry.get("x", 640.0)), float(entry.get("y", 300.0))),
			"size": float(entry.get("size", 84.0)),
		}
		_placed.append(spec)
		_draw_sticker(spec)
	_light = int(SaveManager.get_setting("base_light", 0))
	_paint_base()


func _draw_sticker(spec: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.position = spec["at"]
	_canvas.add_child(node)
	var size: float = float(spec["size"])
	var art: Control = UiKit.picture(str(spec["icon"]), size)
	if art != null:
		art.position = Vector2(-size, -size) * 0.5
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)
	spec["node"] = node
	return node


func _remember() -> void:
	var out: Array = []
	for spec in _placed:
		out.append({"icon": str(spec["icon"]), "x": (spec["at"] as Vector2).x,
			"y": (spec["at"] as Vector2).y, "size": float(spec["size"])})
	SaveManager.set_creation("base", out)
	SaveManager.set_setting("base_light", _light)
	if _saved_note != null and is_instance_valid(_saved_note):
		_saved_note.modulate.a = 1.0
		var t := _saved_note.create_tween()
		t.tween_interval(0.9)
		t.tween_property(_saved_note, "modulate:a", 0.0, 0.5)


# --- the tray, and dragging out of it ---------------------------------------------

func _build_tray() -> void:
	_tray = Control.new()
	_tray.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tray)
	var shelf := Node2D.new()
	shelf.position = Vector2(0, 618)
	_tray.add_child(shelf)
	Shapes.fill(shelf, Shapes.rounded_rect(Vector2(16, 0), Vector2(1248, 92), 26.0),
		Color(0.05, 0.10, 0.22, 0.62), 0.0)

	var owned: Array = []
	for name in STICKERS:
		if SaveManager.has_sticker(name) or SaveManager.has_outfit(name) \
				or STICKERS.find(name) < 8:
			owned.append(name)          # the first eight are always available
	for i in range(owned.size()):
		var node := Node2D.new()
		node.position = Vector2(88.0 + float(i) * 74.0, 664.0)
		node.set_meta("icon", str(owned[i]))
		_tray.add_child(node)
		var art: Control = UiKit.picture(str(owned[i]), 56)
		if art != null:
			art.position = Vector2(-28, -28)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(art)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch == -1:
			_press(touch.position, touch.index)
		elif touch.index == _touch:
			_let_go(touch.position)
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch:
		_move((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _touch == -1:
			_press(click.position, -2)
		elif _touch == -2:
			_let_go(click.position)
	elif event is InputEventMouseMotion and _touch == -2:
		_move((event as InputEventMouseMotion).position)


func _press(at: Vector2, index: int) -> void:
	# From the tray: start a new sticker.
	for node in _tray.get_children():
		if not (node is Node2D) or (node as Node2D).position.distance_to(at) > 46.0:
			continue
		_touch = index
		_drag_spec = {"icon": str((node as Node2D).get_meta("icon")),
			"at": at, "size": 96.0, "fresh": true}
		_dragging = _draw_sticker(_drag_spec)
		_dragging.z_index = 40
		AudioManager.play_sfx("res://assets/audio/drag_pick.ogg")
		return
	# From the wall: pick an existing one back up and move it.
	for spec in _placed:
		if (spec["at"] as Vector2).distance_to(at) > float(spec["size"]) * 0.6:
			continue
		_touch = index
		_drag_spec = spec
		_dragging = spec["node"]
		if is_instance_valid(_dragging):
			_dragging.z_index = 40
		AudioManager.play_sfx("res://assets/audio/drag_pick.ogg")
		return


func _move(at: Vector2) -> void:
	if _dragging == null or not is_instance_valid(_dragging):
		return
	_dragging.position = at
	_drag_spec["at"] = at


func _let_go(at: Vector2) -> void:
	_touch = -1
	if _dragging == null or not is_instance_valid(_dragging):
		_drag_spec = {}
		return
	_dragging.z_index = 0
	# Dropped back on the shelf: put it away. That is the only "delete" in
	# here, and it is the one gesture a child works out by themselves.
	if at.y > 600.0:
		_placed.erase(_drag_spec)
		_dragging.queue_free()
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
	else:
		if bool(_drag_spec.get("fresh", false)):
			_drag_spec.erase("fresh")
			_placed.append(_drag_spec)
		Juice.pop(_dragging, 0.2)
		AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	_dragging = null
	_drag_spec = {}
	_remember()


# --- the screen -------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UiKit.theme()
	layer.add_child(_hud)

	# "Done" rather than "Back": leaving is finishing, because there is
	# nothing here to abandon.
	var done := UiKit.big_button(I18n.t("creative.done"), Palette.GREEN)
	done.custom_minimum_size = Vector2(220, 104)
	done.position = Vector2(1030, 24)
	done.pressed.connect(func():
		_remember()
		result.duration_seconds = 0.0
		complete_level())
	_hud.add_child(done)

	# One button that cycles the base's light colour. A settings screen for a
	# six-year-old is one button that visibly changes something.
	var lamp := UiKit.big_button(I18n.t("creative.light"), Palette.BLUE)
	lamp.custom_minimum_size = Vector2(200, 104)
	lamp.position = Vector2(24, 24)
	lamp.pressed.connect(func():
		_light = (_light + 1) % LIGHT_COLOURS.size()
		_paint_base()
		Juice.pop(_base, 0.24)
		AudioManager.play_sfx("res://assets/audio/power_on.ogg")
		_remember())
	_hud.add_child(lamp)

	_saved_note = Label.new()
	_saved_note.text = I18n.t("creative.saved")
	_saved_note.add_theme_font_size_override("font_size", 30)
	_saved_note.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_saved_note)
	_saved_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saved_note.position = Vector2(440, 110)
	_saved_note.size = Vector2(400, 44)
	_saved_note.modulate.a = 0.0
	_saved_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_saved_note)
