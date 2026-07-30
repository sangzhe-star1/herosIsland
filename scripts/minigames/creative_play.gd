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

## Which shelf in the save this room's work goes on.
##
## It was the string "base", written directly into get_creation() and
## set_creation() -- fine while exactly one level used this template, and a
## data-loss trap the moment a second one did: two rooms sharing one key means
## decorating the garden SAVES OVER the hero base, and a child loses an
## afternoon's work by playing a different room. The key now comes from the
## level's own config (canvas_id, falling back to the level id, falling
## back to "base" so a malformed save of the original room never strands its
## stickers). 菜园二期的装饰系统就指着这一行活下来。
var _canvas_key := "base"


func _canvas_id() -> String:
	var config: Dictionary = level_data.get("config", {})
	var key := str(config.get("canvas_id", ""))
	if key == "":
		key = str(level_data.get("id", ""))
	return key if key != "" else "base"

## What can be placed. Deliberately a mixed bag: some of it heroic, some of it
## silly, none of it "correct".
const STICKERS := [
	"star", "heart", "moon", "spark", "leaf", "flag", "medal", "crown",
	"balloon", "music", "paw", "orb", "gem", "party_hat", "wings", "shield",
]


## The room's own shelf of stickers, if its data brings one; the classic
## mixed bag otherwise. 装饰菜园 brings garden things -- a room is what is on
## its shelf as much as what is on its wall.
func _sticker_set() -> Array:
	var names: Array = level_data.get("config", {}).get("stickers", [])
	return names if not names.is_empty() else STICKERS


## What this room looks out on: the hero base dome, or (装饰间) a meadow.
func _backdrop() -> String:
	return str(level_data.get("config", {}).get("backdrop", "base"))
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
	_canvas = UiKit.play_area(self, true)
	# Through the CONTROL, not through _unhandled_input.
	#
	# The play area is a full-screen Control that catches input, which means it
	# eats every press and drag before the node ever sees them. On a Mac that
	# was survivable by accident; with a real finger it meant the one gesture
	# this whole room is made of -- pick a sticker up and move it -- did
	# nothing at all. Reported from an iPad: "拖动没响应".
	#
	# The other four templates built on play_area() have always used
	# `gui_input`. This one was the odd one out.
	_canvas.gui_input.connect(_pointer)

	_build_base()
	_restore()
	_build_hud()
	_build_tray()


# --- the base -----------------------------------------------------------------

func _build_base() -> void:
	_base = Node2D.new()
	# Standing ON the floor of whatever screen this is, rather than at y=470 --
	# which on a taller iPad viewport left the base hanging in mid-air with a
	# strip of empty ground under it.
	_base.position = Vector2(640, shelf_y() - 148.0)
	_canvas.add_child(_base)
	_paint_base()


## The 装饰间 backdrop: a strip of meadow and a soil patch, echoing the farm
## it decorates. No dome, no window -- and therefore no light to change,
## which is why the lamp button stays home in this room.
func _paint_meadow() -> void:
	Shapes.fill(_base, Shapes.rounded_rect(Vector2(-560, 10), Vector2(1120, 150), 30.0),
		Color(0.55, 0.74, 0.42), 0.0)
	# fill, not lit: lit() lays a highlight copy over the soil and the two
	# browns read as stacked planks rather than a bed of earth.
	Shapes.fill(_base, Shapes.rounded_rect(Vector2(-460, -50), Vector2(920, 100), 26.0),
		Color(0.52, 0.38, 0.26), 0.0)
	for i in range(5):
		var x := -420.0 + float(i) * 210.0
		Shapes.fill(_base, Shapes.taper(Vector2(x, 16.0), Vector2(x, -34.0), 9.0, 7.0),
			Color(0.72, 0.58, 0.40), 0.0)


## The hero's base: a dome on legs with a big window. Redrawn when the child
## changes its light colour, which is the one "setting" this room has.
func _paint_base() -> void:
	for child in _base.get_children():
		child.queue_free()
	if _backdrop() == "meadow":
		_paint_meadow()
		return
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
	_canvas_key = _canvas_id()
	var saved: Array = SaveManager.get_creation(_canvas_key)
	for entry in saved:
		var spec := {
			"icon": str(entry.get("icon", "star")),
			"at": Vector2(float(entry.get("x", 640.0)), float(entry.get("y", 300.0))),
			"size": float(entry.get("size", 84.0)),
		}
		_placed.append(spec)
		_draw_sticker(spec)
	_light = int(SaveManager.get_setting(_canvas_key + "_light", 0))
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
	SaveManager.set_creation(_canvas_key, out)
	SaveManager.set_setting(_canvas_key + "_light", _light)
	if _saved_note != null and is_instance_valid(_saved_note):
		_saved_note.modulate.a = 1.0
		var t := _saved_note.create_tween()
		t.tween_interval(0.9)
		t.tween_property(_saved_note, "modulate:a", 0.0, 0.5)


# --- the tray, and dragging out of it ---------------------------------------------

## Where the shelf sits on THIS screen.
##
## `stretch/aspect` is "expand", so the viewport is 1280 wide on everything but
## only 720 tall on a 16:9 Mac -- a 4:3 iPad gets 1280x960. Every y in this
## file used to be written for 720, which put the shelf a third of the way up
## an iPad screen with a band of empty room underneath it, and left the
## "dropped on the shelf means put it away" line at y=600 cutting straight
## through the middle of the room a child draws in.
##
## One number, asked of the real viewport, and the three places that need it
## all agree.
const SHELF_H := 92.0
const SHELF_GAP := 10.0


func shelf_y() -> float:
	var tall: float = get_viewport_rect().size.y
	return maxf(tall - SHELF_H - SHELF_GAP, 200.0)


## Below this line, letting go means "put it back". It has to sit just above
## the shelf and nowhere near the middle of the screen.
func _shelf_line() -> float:
	return shelf_y() - 18.0


func _build_tray() -> void:
	_tray = Control.new()
	_tray.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tray)
	var shelf := Node2D.new()
	shelf.position = Vector2(0, shelf_y())
	_tray.add_child(shelf)
	Shapes.fill(shelf, Shapes.rounded_rect(Vector2(16, 0), Vector2(1248, SHELF_H), 26.0),
		Color(0.05, 0.10, 0.22, 0.62), 0.0)

	var owned: Array = []
	for name in _sticker_set():
		if SaveManager.has_sticker(name) or SaveManager.has_outfit(name) \
				or _sticker_set().find(name) < 8:
			owned.append(name)          # the first eight are always available
	for i in range(owned.size()):
		var node := Node2D.new()
		node.position = Vector2(88.0 + float(i) * 74.0, shelf_y() + SHELF_H * 0.5)
		node.set_meta("icon", str(owned[i]))
		_tray.add_child(node)
		var art: Control = UiKit.picture(str(owned[i]), 56)
		if art != null:
			art.position = Vector2(-28, -28)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(art)


## Kept as a safety net for any event that somehow arrives outside the play
## area. The real path is _canvas.gui_input, connected in setup_level().
func _unhandled_input(event: InputEvent) -> void:
	_pointer(event)


func _pointer(event: InputEvent) -> void:
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
	if at.y > _shelf_line():
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
	# six-year-old is one button that visibly changes something -- so it only
	# exists where there is a window to change. A meadow has no lamp, and a
	# button that presses without anything happening teaches "buttons lie".
	if _backdrop() == "base":
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
