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

# --- the type scale and the radius family -------------------------------
#
# Four sizes, each at least 1.3x the next, and every word in the shell
# screens wears one of them. A fifth size is not a style decision, it is a
# typo with confidence -- before this table the shells had nineteen.
const TYPE_DISPLAY := 52   # one per screen: the greeting, the moment
const TYPE_TITLE := 36     # section heads and button words
const TYPE_BODY := 26      # sentences, prices, counts
const TYPE_CAPTION := 20   # the small print, usually for the adult

# One radius family. RADIUS for buttons and big panels, _CARD for cards and
# tiles, _CHIP for small chips and progress tracks, _INNER for the fill that
# sits 4px inside a track (nested corner = outer minus inset).
const RADIUS_CARD := 22
const RADIUS_CHIP := 16
const RADIUS_INNER := 12

const TOUCH_MIN := Vector2(220, 120)
const RADIUS := 30
const EDGE := 8          # thickness of a button's raised bottom edge

## Latin display font. Rounded and heavy reads as "toy", not "document".
const FONT_DISPLAY := "res://assets/fonts/Baloo2-SemiBold.ttf"
## CJK fallback. Godot falls through to this for any glyph the display font
## lacks, so mixed English/Chinese strings render in one pass.
const FONT_CJK := "res://assets/fonts/NotoSansSC.otf"

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


## A progress track: a sunk well with the fill sitting inside it. Drawn rather
## than nine-patched from imported art, so a bar in the Reward Centre and a
## button on Home are made of the same material.
static func track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.24, 0.30)
	style.set_corner_radius_all(RADIUS_CHIP)
	style.set_content_margin_all(5)
	return style


static func fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(RADIUS_INNER)
	return style


## Flat colour behind a screen. Used only where a screen deliberately has no
## world behind it -- the Parent Center, which is for an adult and should look
## like a settings page, not like the game.
static func background(parent: Control, color: Color) -> Control:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	parent.move_child(rect, 0)
	return rect


## The world behind a screen.
##
## This is the only way scenery reaches a shell screen, exactly as
## LevelManager.build_world() is the only way it reaches a level. Before the
## architecture pass each screen named its own PNG, which is how the home
## screen, the map and the result screen all ended up showing the same
## photograph of a night skyline while the sorting levels showed a pastel
## village.
static func world_background(parent: Control, world_id: String,
		seed_key: String = "", calm: float = 0.0) -> Stage:
	var style: WorldStyle = WorldStyle.for_world(world_id)
	style.calm = calm
	return Stage.build(parent, style, seed_key if seed_key != "" else world_id)


## A full-screen Control for a level to hold its play area in.
##
## Use this and never `Control.new()` + PRESET_FULL_RECT inside a level.
##
## Anchors do not work there, and they fail silently. A Control resolves its
## anchors against its parent CanvasItem's "anchorable rect", and a Node2D --
## which every level template is -- reports that as (0, 0, 0, 0). So the
## anchors are honoured perfectly against nothing and the Control ends up
## zero-sized. Meanwhile everything DRAWN inside it still appears, because
## Node2D children do not care what size their parent claims to be.
##
## The result is a level that looks completely finished and cannot be touched:
## the tap area is a zero-size rectangle in the top-left corner, so no press
## ever lands in it and no handler ever runs. Twelve levels shipped like that,
## including the first one in the game, and every screenshot of them looked
## right. (A Control under a CanvasLayer is fine -- a CanvasLayer is not a
## CanvasItem, so the lookup falls through to the viewport. That is why the
## HUDs all worked and the play areas all did not.)
static func play_area(parent: Node, catches_input: bool = false) -> Control:
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_STOP if catches_input \
		else Control.MOUSE_FILTER_IGNORE
	parent.add_child(area)
	# Sized by hand, because nothing will do it for us. No anchors at all --
	# an anchor that is quietly ignored is worse than no anchor.
	area.position = Vector2.ZERO
	area.size = area.get_viewport_rect().size
	var vp := area.get_viewport()
	if vp != null:
		var resize_area := func() -> void:
			if is_instance_valid(area):
				area.size = area.get_viewport_rect().size
		vp.size_changed.connect(resize_area)
		# The viewport outlives every level. Disconnect before this area is freed,
		# otherwise the global resize signal retains a lambda whose `area` capture
		# has already gone away when the next level changes window size.
		area.tree_exiting.connect(func() -> void:
			if is_instance_valid(vp) and vp.size_changed.is_connected(resize_area):
				vp.size_changed.disconnect(resize_area), CONNECT_ONE_SHOT)
	return area


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
	b.add_theme_font_size_override("font_size", TYPE_TITLE)
	b.add_theme_color_override("font_color", Palette.ON_COLOR)
	b.add_theme_color_override("font_hover_color", Palette.ON_COLOR)
	b.add_theme_color_override("font_pressed_color", Palette.ON_COLOR)
	b.add_theme_color_override("font_disabled_color", Palette.INK)

	b.add_theme_stylebox_override("normal", _raised(color, EDGE))
	b.add_theme_stylebox_override("hover", _raised(Palette.lift(color), EDGE))
	b.add_theme_stylebox_override("pressed", _raised(color.darkened(0.06), 2))
	b.add_theme_stylebox_override("disabled", _raised(Palette.MUTED, 3))

	# Every press earns a little bounce and a little sound, on top of the
	# squash the styleboxes already do. Feedback at the finger, always -- and
	# because the sfx player is a single voice, a button whose handler plays
	# its own louder sound simply replaces this one mid-pop.
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.pressed.connect(func():
		Juice.pop(b, 0.06)
		AudioManager.play_sfx("res://assets/audio/pop.ogg"))
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

	# A bare name is DRAWN. It used to check assets/icons/<name>.png first and
	# use that if present, which quietly meant the whole game rendered a set of
	# imported navy badge discs instead of its own icons -- five different
	# visual languages on one screen. Artwork now has to be asked for by path.
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
	b.add_theme_font_size_override("font_size", TYPE_BODY)

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


## The slow breathing pulse for a screen's ONE primary action ("this is the
## thing to press"). Waits for first layout so the pivot lands in the centre.
static func breathe(control: Control, amount: float = 0.03, period: float = 0.9) -> void:
	if not Juice.motion_enabled():
		return
	var start := func():
		if not is_instance_valid(control):
			return
		control.pivot_offset = control.size / 2.0
		var t := control.create_tween().set_loops()
		t.tween_property(control, "scale", Vector2.ONE * (1.0 + amount), period)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(control, "scale", Vector2.ONE, period)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if control.is_inside_tree() and control.size.length() > 0.0:
		start.call()
	else:
		control.resized.connect(start, CONNECT_ONE_SHOT)


static func back_button(target: Callable) -> Button:
	var b := big_button("<", Palette.SLATE)
	b.custom_minimum_size = Vector2(112, 96)
	b.add_theme_font_size_override("font_size", TYPE_TITLE)
	b.pressed.connect(target)
	return b


# --- text ---------------------------------------------------------------

static func title(text: String, size: int = TYPE_DISPLAY, color: Color = Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Title over artwork or a dark background, where a plain label would be lost.
static func title_on_art(text: String, size: int = TYPE_DISPLAY) -> Label:
	var l := title(text, size, Palette.ON_COLOR)
	return on_art(l, 10)


## Makes any label survive whatever is behind it.
##
## Every screen now has a drawn world underneath, and a world has bright bits
## and dark bits and things that drift across. A white instruction that is
## legible over a dusk skyline is invisible over a midday cloud. An outline in
## the ink colour costs one theme override and is the difference between an
## instruction a six-year-old can read and one they cannot -- which, in a game
## where the instruction is the whole level, is not a cosmetic detail.
static func on_art(label: Label, size: int = 8) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.80))
	label.add_theme_constant_override("outline_size", size)
	return label


## The smallest gap a stacked column is allowed to close to before it starts
## shrinking things instead. Below this the screen stops reading as a list of
## separate happy facts and starts reading as a paragraph.
const MIN_STACK_GAP := 8


## Make a column fit the room it has, whatever ends up in it.
##
## A celebration screen is built out of ifs -- a badge line IF a badge was
## won, a level-up line IF the bar filled, a lesson button IF that was the
## last level of a world. Every one of those is a good thing, and on the run
## where a child earns all of them at once the column grows past the bottom of
## the screen and the buttons go with it. That is the BEST run they will ever
## have and it was the one run where they could not see what to press.
##
## Two steps, cheapest first: close the gaps, and only then shrink. Call it
## once, after the column is filled.
static func fit_column(box: BoxContainer) -> void:
	if box == null or not box.is_inside_tree():
		return
	await box.get_tree().process_frame
	if not is_instance_valid(box):
		return
	# The room is what the ANCHORS ask for, not box.size.
	#
	# A Container never reports a size smaller than its contents -- Godot
	# clamps it up to the combined minimum. So a column that has overflowed
	# reports a size that fits its overflow perfectly, and asking `box.size`
	# how much room it has is asking the overflow to measure itself. The first
	# cut of this did exactly that and cheerfully decided a 813 px column fit
	# in 813 px of a 720 px screen.
	var slot: Vector2 = _anchored_size(box)
	var room: float = slot.y
	var wide: float = slot.x
	var need: Vector2 = box.get_combined_minimum_size()
	if need.y <= room and need.x <= wide:
		return

	# 1. Close the gaps. Free, and invisible until it is a lot of them.
	if need.y > room:
		var gaps: int = maxi(box.get_child_count() - 1, 1)
		var over: float = need.y - room
		var gap: int = int(box.get_theme_constant("separation"))
		box.add_theme_constant_override("separation",
			maxi(gap - int(ceil(over / float(gaps))), MIN_STACK_GAP))
		await box.get_tree().process_frame
		if not is_instance_valid(box):
			return
		need = box.get_combined_minimum_size()
	if need.y <= room and need.x <= wide:
		return

	# 2. Still over: shrink the whole column, keeping its proportions. From the
	# top-centre, because a column that has overflowed is one Godot has already
	# started laying out at the top -- scaling about the middle would push the
	# bottom of it further off the screen, not less.
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	var k: float = minf(room / maxf(need.y, 1.0), wide / maxf(need.x, 1.0))
	k = clampf(k, 0.55, 1.0)
	box.pivot_offset = Vector2(box.size.x * 0.5, 0.0)
	box.scale = Vector2(k, k)


## The rectangle a Control's anchors and offsets ask for, ignoring the clamp
## that Containers apply to their own size. This is Godot's own formula, and
## the only honest answer to "how much room is there".
static func _anchored_size(node: Control) -> Vector2:
	var parent: Vector2 = node.get_parent_area_size()
	return Vector2(
		parent.x * (node.anchor_right - node.anchor_left)
			+ node.offset_right - node.offset_left,
		parent.y * (node.anchor_bottom - node.anchor_top)
			+ node.offset_bottom - node.offset_top)


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

	var centre := Vector2(size, size) / 2.0
	var points := Shapes.star_points(centre, size * 0.46, 0.44, 5)
	if filled:
		Shapes.glow(holder, centre, size * 0.9, Palette.STAR_ON, 4, 0.34)
		Shapes.lit(holder, points, Palette.STAR_ON, 1.0)
	else:
		# An empty star stays clearly visible: seeing what is still there to
		# earn is the entire reason for drawing it at all.
		Shapes.fill(holder, points, Color(1, 1, 1, 0.34), 1.0)
	return holder


# --- wordless instructions ------------------------------------------------

## A "do / don't" ring. The two road signs every pre-reader already owns:
## green ring with a tick means "this one, yes"; red ring with a diagonal
## slash means "not this one". Drawn, so it can be dropped over any icon at
## any size -- in the instruction strip, or flashed over the exact rock a
## child just tapped.
static func rule_ring(ok: bool, size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.pivot_offset = Vector2(size, size) / 2.0

	var centre := Vector2(size, size) / 2.0
	var colour := Color(0.36, 0.78, 0.44) if ok else Color(0.90, 0.28, 0.28)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(centre, size * 0.44, 30)
	ring.closed = true
	ring.width = maxf(size * 0.085, 4.0)
	ring.default_color = colour
	ring.antialiased = true
	holder.add_child(ring)

	if ok:
		# A tick riding the ring's lower-right, like a stamp of approval --
		# NOT crossing the icon, which stays fully visible.
		var badge := Node2D.new()
		badge.position = centre + Vector2(size * 0.30, size * 0.30)
		holder.add_child(badge)
		Shapes.fill(badge, Shapes.circle_points(Vector2.ZERO, size * 0.17, 16), colour, 0.0)
		var tick := Line2D.new()
		tick.points = PackedVector2Array([
			Vector2(-size * 0.085, 0.0),
			Vector2(-size * 0.02, size * 0.062),
			Vector2(size * 0.09, -size * 0.07),
		])
		tick.width = maxf(size * 0.05, 3.0)
		tick.default_color = Color(1, 1, 1, 0.95)
		tick.antialiased = true
		badge.add_child(tick)
	else:
		# The slash DOES cross the icon: "no" has to be unmissable.
		var slash := Line2D.new()
		var arm := Vector2(size * 0.30, -size * 0.30)
		slash.points = PackedVector2Array([centre - arm, centre + arm])
		slash.width = maxf(size * 0.085, 4.0)
		slash.default_color = colour
		slash.antialiased = true
		holder.add_child(slash)
	return holder


## The instruction, without the reading: a row of icon tiles, each wearing a
## green-tick or red-slash ring. Callers pass [{icon, ok, tint?}, ...] and put
## the strip right under the text label -- the text stays for the parent and
## for the child to grow into, the strip is what actually instructs.
##
## Returns the strip; each tile is retrievable via get_meta("tiles") (an Array
## of Controls in item order) so a level can pulse the matching tile when its
## rule is broken, or retint an icon when the target changes.
static func pictogram(items: Array, tile: float = 78.0) -> Control:
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", int(tile * 0.22))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tiles: Array = []

	for item in items:
		var box := Control.new()
		box.custom_minimum_size = Vector2(tile, tile)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.pivot_offset = Vector2(tile, tile) / 2.0

		# A soft dark coaster so the strip reads over any world, day or night.
		var pad := Node2D.new()
		box.add_child(pad)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2),
			Vector2(tile - 4.0, tile - 4.0), tile * 0.24),
			Color(0.05, 0.09, 0.20, 0.55), 0.0)

		var art: Control = picture(str(item.get("icon", "")), tile * 0.58)
		if art != null:
			art.name = "Art"     # so a level can retint it when the target changes
			art.position = Vector2(tile, tile) / 2.0 - Vector2(tile * 0.29, tile * 0.29)
			if item.has("tint"):
				art.modulate = item["tint"]
			box.add_child(art)

		box.add_child(rule_ring(bool(item.get("ok", true)), tile))
		strip.add_child(box)
		tiles.append(box)

	strip.set_meta("tiles", tiles)
	return strip


# --- one finger, one press ------------------------------------------------

## Did this input event begin a press?
##
## Read this before writing another `event is InputEventMouseButton ... or
## event is InputEventScreenTouch` by hand, because that idiom is wrong here
## and it cost this project a fortnight of "the buttons don't work".
##
## project.godot sets pointing/emulate_touch_from_mouse so the desktop build
## can be played like a tablet. The emulation does not REPLACE the mouse
## event, it ADDS a touch event -- so one click arrives at the same
## gui_input TWICE, once as each type. Anything that merely counts presses
## then counts double.
##
## In most levels that was invisible or merely generous. In the Light Song
## it was fatal: tap the right pad and the real event advanced the phrase
## while its ghost, judged a millisecond later against the NEXT note, came
## back wrong. Tap correctly, be told you are wrong, hear the song restart,
## forever. "Tapping does nothing" -- and he was right.
##
## So: the touch is the truth, and the mouse duplicate is ignored whenever
## the engine is emulating. With emulation off (a plain desktop build), the
## mouse is the truth and there is no duplicate to ignore.
static func is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
			and not Input.is_emulating_touch_from_mouse()
	return false


## The other half: did this event END a press? Same duplication, same rule.
static func is_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return not button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
			and not Input.is_emulating_touch_from_mouse()
	return false



# --- the out-of-light moment ----------------------------------------------

## The fight stops and the child chooses: spend a Heart Potion and carry on,
## or finish the level here with what they earned.
##
## This is the one place the island has a real stake, added because a parent
## watched his son take hit after hit with the light bar empty and nothing
## whatsoever happening. He was right: a health bar that cannot run out is
## not a health bar, it is decoration, and the Star Shop's potions were
## shopping for nothing.
##
## It is still not a fail screen. Ending here is FINISHING -- the level
## reports normally and earns its star, the coins are kept, and the child is
## offered a way to continue before any of that happens. What changed is
## that the way to continue costs something they chose to buy.
static func light_out_card(parent: Node, potions: int, on_potion: Callable,
		on_finish: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP    # nothing behind it is tappable
	holder.z_index = 90
	# The tree is paused while this is up, so the card has to be the one
	# thing still allowed to think.
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(holder)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.03, 0.06, 0.14, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(centre)

	var card := UiKit.card()
	centre.add_child(card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)

	# Three spent hearts: the reason we are here, in one picture.
	var hearts := HBoxContainer.new()
	hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	hearts.add_theme_constant_override("separation", 10)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var heart: Control = UiKit.picture("heart", 54)
		if heart != null:
			heart.modulate = Color(0.40, 0.44, 0.54, 0.55)
			hearts.add_child(heart)
	column.add_child(hearts)

	column.add_child(UiKit.title(I18n.t("battle.out_of_light"), TYPE_TITLE))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	column.add_child(row)

	# The potion is offered first and only when there is one to spend -- a
	# greyed-out button a child cannot use is a tease, not an option.
	if potions > 0:
		var potion := UiKit.icon_button("x%d" % potions, "potion",
			Palette.GREEN, Vector2(250, 210))
		potion.pressed.connect(func():
			holder.queue_free()
			on_potion.call()
		)
		row.add_child(potion)
	else:
		column.add_child(UiKit.title(I18n.t("battle.buy_potions"), TYPE_CAPTION, Palette.INK_SOFT))

	var finish := UiKit.icon_button(I18n.t("battle.finish_here"), "flag",
		Palette.ORANGE, Vector2(250, 210))
	finish.pressed.connect(func():
		holder.queue_free()
		on_finish.call()
	)
	row.add_child(finish)
	return holder
