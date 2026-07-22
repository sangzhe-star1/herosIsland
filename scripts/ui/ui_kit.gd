class_name UiKit
extends RefCounted
## Shared UI construction for a six-year-old.
##
## Design rules encoded here, applied everywhere:
##  - touch targets are at least 120x120 px, because small fingers miss
##  - labels are large and always paired with colour or shape, never text alone
##  - nothing depends on the child being able to read
##  - no flashing, no timers that create panic

const TOUCH_MIN := Vector2(220, 120)
const FONT_PATH := "res://assets/fonts/NotoSansSC-Regular.ttf"

## Godot's default label colour is near-white, which vanishes on the light
## backgrounds most of these screens use. Text defaults to dark here; the few
## screens on dark backgrounds override to white explicitly.
const TEXT_DARK := Color(0.12, 0.16, 0.24)
const TEXT_LIGHT := Color(0.97, 0.98, 1.0)

static var _theme: Theme = null


## A theme carrying a CJK-capable font if one has been added to assets/fonts/.
## Without it English still renders fine; Chinese would show empty boxes, so the
## font is only required before switching locale.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var font := load(FONT_PATH)
		if font is Font:
			_theme.default_font = font
	_theme.default_font_size = 32

	for type in ["Label", "RichTextLabel"]:
		_theme.set_color("font_color", type, TEXT_DARK)
	# LineEdit / SpinBox / OptionButton keep Godot's own styling: they draw a
	# dark field with light text, which already reads fine.
	return _theme


## Full-screen vertical layout with breathing room at the edges, so nothing sits
## flush against the bezel on a tablet.
static func screen_root(parent: Control, margin: int = 36) -> VBoxContainer:
	var box := MarginContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		box.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	box.add_child(column)
	return column


static func big_button(text: String, color: Color = Color(0.24, 0.5, 0.85)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = TOUCH_MIN
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.92))

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(28)
	normal.content_margin_left = 32
	normal.content_margin_right = 32
	normal.content_margin_top = 20
	normal.content_margin_bottom = 20
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.08)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	b.add_theme_stylebox_override("pressed", pressed)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.65, 0.65, 0.68)
	b.add_theme_stylebox_override("disabled", disabled)

	return b


static func title(text: String, size: int = 64) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func back_button(target: Callable) -> Button:
	var b := big_button("<", Color(0.45, 0.45, 0.5))
	b.custom_minimum_size = Vector2(120, 120)
	b.pressed.connect(target)
	return b


## Row of up to three stars. Empty stars stay visible so the child can see
## what is still there to earn, but they are never shown as red or crossed out.
static func star_row(filled: int, total: int = 3, size: int = 72) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for i in range(total):
		var s := Label.new()
		s.text = "*"
		s.add_theme_font_size_override("font_size", size)
		s.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.2) if i < filled else Color(0.75, 0.75, 0.78)
		)
		row.add_child(s)
	return row


static func background(parent: Control, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg
