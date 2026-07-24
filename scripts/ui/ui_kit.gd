class_name UiKit
extends RefCounted
## Shared UI construction for a six-year-old.
##
## Design rules encoded here, applied everywhere:
##  - touch targets are at least 220x120 px, because small fingers miss
##  - buttons look physically raised and visibly squash when pressed, so a
##    child can tell a tap registered without reading anything
##  - dark ink on light surfaces; nothing is conveyed by colour alone
##  - nothing depends on the child being able to read
##  - no flashing; all motion is slow and low-contrast

const TOUCH_MIN := Vector2(220, 120)
const RADIUS := 30
const EDGE := 8          # thickness of a button's raised bottom edge

## Latin display font. Rounded and heavy reads as "toy", not "document".
const FONT_DISPLAY := "res://assets/fonts/Baloo2-SemiBold.ttf"
## CJK fallback. Godot falls through to this for any glyph the display font
## lacks, so mixed English/Chinese strings render in one pass.
const FONT_CJK := "res://assets/fonts/NotoSansSC-Regular.ttf"

static var _theme: Theme = null


## Built once and shared. Fonts are optional: with none present the engine
## default is used, so the game always runs. Chinese needs FONT_CJK.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()

	var display: Font = _load_font(FONT_DISPLAY)
	var cjk: Font = _load_font(FONT_CJK)

	# Chain them so one font object covers both scripts.
	if display is FontFile and cjk != null:
		var chain: Array[Font] = display.fallbacks.duplicate()
		chain.append(cjk)
		display.fallbacks = chain

	var chosen: Font = display if display != null else cjk
	if chosen != null:
		_theme.default_font = chosen
	_theme.default_font_size = 32

	for type in ["Label", "RichTextLabel"]:
		_theme.set_color("font_color", type, Palette.INK)
	# LineEdit / SpinBox / OptionButton keep Godot's own styling: they draw a
	# dark field with light text, which already reads fine.
	return _theme


static func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Font


# --- surfaces -----------------------------------------------------------

## Warm white card. Used for anything holding content.
static func panel_style(fill: Color = Palette.SURFACE, radius: int = RADIUS) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0.0, 0.05, 0.15, 0.16)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style


static func card(fill: Color = Palette.SURFACE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(fill))
	return p


## Nine-patch stylebox from bundle UI art (panels, level cards, progress
## bars). Returns null when the art is missing so callers keep their drawn
## fallback -- same contract as every other slot in the pipeline.
static func texture_style(path: String, margin: float, content_margin: float = 16.0,
		tint: Color = Color.WHITE) -> StyleBoxTexture:
	if not ResourceLoader.exists(path):
		return null
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.set_texture_margin_all(margin)
	style.set_content_margin_all(content_margin)
	style.modulate_color = tint
	return style


## Full-screen background. Uses assets/backgrounds/<name>.png when that art
## exists, and a flat colour when it does not, so screens look finished now and
## better later without any code change.
static func background(parent: Control, color: Color, art: String = "") -> Control:
	var node: Control
	if art != "" and ResourceLoader.exists(art):
		var tex := TextureRect.new()
		tex.texture = load(art)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		node = tex
	else:
		var rect := ColorRect.new()
		rect.color = color
		node = rect
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	parent.move_child(node, 0)
	return node


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


# --- buttons ------------------------------------------------------------

## A chunky raised button. The bottom edge is the button's "thickness"; when
## pressed, the edge shrinks and the label moves down, so the whole thing
## visibly squashes. That physical feedback is what tells a pre-reader the tap
## worked -- far more legible to them than a colour change.
static func big_button(text: String, color: Color = Palette.BLUE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = TOUCH_MIN
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Palette.ON_COLOR)
	b.add_theme_color_override("font_hover_color", Palette.ON_COLOR)
	b.add_theme_color_override("font_pressed_color", Palette.ON_COLOR)
	b.add_theme_color_override("font_disabled_color", Palette.INK)

	b.add_theme_stylebox_override("normal", _raised(color, EDGE))
	b.add_theme_stylebox_override("hover", _raised(Palette.lift(color), EDGE))
	b.add_theme_stylebox_override("pressed", _raised(color.darkened(0.06), 2))
	b.add_theme_stylebox_override("disabled", _raised(Palette.MUTED, 3))
	return b


static func _raised(color: Color, edge_size: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(RADIUS)
	style.border_width_bottom = edge_size
	style.border_color = Palette.edge(color)
	style.content_margin_left = 30
	style.content_margin_right = 30
	# Total height stays constant while the edge shrinks, so the label slides
	# down by exactly the amount the button "compresses".
	style.content_margin_top = 18 + (EDGE - edge_size)
	style.content_margin_bottom = 18
	style.shadow_color = Color(0.0, 0.05, 0.15, 0.13)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style


## Resolves a picture reference to a node, whichever form it takes.
##
## Accepts either a drawn-icon name ("teddy") or a texture path
## ("res://assets/icons/teddy.png"). Real artwork wins when it is present; the
## drawn placeholder is used when it is not. This is the seam that lets every
## icon in the game be replaced by dropping files into a folder, with no code
## change and no data change beyond the filename.
static func picture(reference: String, size: float) -> Control:
	if reference == "":
		return null

	if reference.begins_with("res://"):
		if ResourceLoader.exists(reference):
			var tex := TextureRect.new()
			# expand_mode FIRST: until it is set, a TextureRect's minimum size
			# is the texture's own size, and assigning a smaller `size` gets
			# clamped up to it -- which is how every 128px badge in the game
			# once rendered at 128px regardless of what was asked for.
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture = load(reference)
			tex.custom_minimum_size = Vector2(size, size)
			tex.size = Vector2(size, size)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tex
		# Named art that has not been added yet: fall back to the drawn icon
		# with the same base name, so a half-finished art pass still runs.
		return IconLibrary.build(reference.get_file().get_basename(), size)

	# A bare name checks for real artwork first -- "star" uses
	# assets/icons/star.png the moment that file exists -- and draws its
	# IconLibrary version until then. This is what makes the art checklist's
	# "drop the file in and it appears" promise true for icons.
	var art := "res://assets/icons/%s.png" % reference
	if ResourceLoader.exists(art):
		return picture(art, size)

	return IconLibrary.build(reference, size)


## A button carrying a picture above its label.
##
## The picture is not decoration: a six-year-old cannot read "Adventure" or "My
## Rewards", so on a text-only menu they are reduced to memorising button
## positions. The icon is what makes the screen navigable, and the word is what
## they gradually learn from it.
static func icon_button(text: String, icon_name: String,
		color: Color = Palette.BLUE, box: Vector2 = Vector2(300, 210)) -> Button:
	var b := big_button(text, color)
	b.custom_minimum_size = box
	b.add_theme_font_size_override("font_size", 30)

	var icon: Control = picture(icon_name, box.x * 0.40)
	if icon == null:
		return b

	# Sits above the label, which is pushed to the lower part of the button.
	icon.position = Vector2(box.x * 0.30, box.y * 0.10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Push the label into the lower third so it clears the icon above it.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = b.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			var flat := style as StyleBoxFlat
			flat.content_margin_top = box.y * 0.56
	return b


static func back_button(target: Callable) -> Button:
	var b := big_button("<", Palette.SLATE)
	b.custom_minimum_size = Vector2(112, 96)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(target)
	return b


# --- text ---------------------------------------------------------------

static func title(text: String, size: int = 60, color: Color = Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Title over artwork or a dark background, where a plain label would be lost.
static func title_on_art(text: String, size: int = 60) -> Label:
	var l := title(text, size, Palette.ON_COLOR)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.75))
	l.add_theme_constant_override("outline_size", 10)
	return l


# --- stars --------------------------------------------------------------

## Row of up to three stars. Empty stars stay visible so the child can see what
## is still there to earn, but they are never shown as red or crossed out.
static func star_row(filled: int, total: int = 3, size: int = 72) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(size * 0.12))
	for i in range(total):
		row.add_child(star(i < filled, size))
	return row


## A real five-pointed star, not an asterisk. Uses the painted star badges when
## they exist (assets/icons/star.png and star_empty.png); drawn as a polygon so
## it needs no art and scales cleanly when they do not.
static func star(filled: bool, size: int = 72) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set here rather than by the caller: `size` is still zero before the first
	# layout pass, so a caller computing the pivot would scale from the corner.
	holder.pivot_offset = Vector2(size, size) / 2.0

	var art := "res://assets/icons/%s.png" % ("star" if filled else "star_empty")
	if ResourceLoader.exists(art):
		var tex := TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # before size; see picture()
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = load(art)
		tex.size = Vector2(size, size)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not filled:
			# The empty badge is navy-on-navy on the map panels; lift it so
			# "still to earn" stays visible, which is the whole point of
			# showing empty stars at all.
			tex.modulate = Color(1.7, 1.7, 1.85)
		holder.add_child(tex)
		return holder

	var points := PackedVector2Array()
	var centre := Vector2(size, size) / 2.0
	var outer: float = size * 0.48
	var inner: float = size * 0.21
	for i in range(10):
		var angle: float = -PI / 2.0 + TAU * float(i) / 10.0
		var radius: float = outer if i % 2 == 0 else inner
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Palette.STAR_ON if filled else Palette.STAR_OFF
	holder.add_child(poly)

	if filled:
		var outline := Line2D.new()
		outline.points = points
		outline.closed = true
		outline.width = maxf(2.0, size * 0.045)
		outline.default_color = Palette.STAR_ON.darkened(0.35)
		holder.add_child(outline)
	return holder
