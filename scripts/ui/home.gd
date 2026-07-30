extends Control
## Child home screen. Four doors a six-year-old may open in one tap, and a
## fifth -- the parent door -- that he cannot.
##
##
## WHY THIS WAS REBUILT
##
## Every rectangle used to be placed by hand against a 1280x720 mock-up. That
## survives exactly until the layout changes: adding the garden as a fifth big
## button turned the 2x2 grid into 2x3, and the grid grew past both edges of
## the screen. At 1280x720 the greeting was sliced off at the top, the parent
## button was cut in half at the bottom, and the hold hint and its progress bar
## were off the bottom of the screen ENTIRELY -- the one control an adult needs
## to find had no pixels at all.
##
## Nothing caught it. The smoke test boots this scene and checks it does not
## fault, which it did not. The tablet probe measures whether a screen follows
## a 4:3 viewport, and the shell screens were never in its list. The shot
## harness has had a `home` mode since 阶段4 and nobody had run it since the
## fifth button landed. Three layers of checking, all blind to the same wall.
##
## So: nothing below is a number read off a picture. Every rectangle is derived
## from GAP and the REAL viewport -- which is 1280x960 on the 4:3 tablet this
## game is actually played on, not 1280x720 -- and `tests/home_probe.gd` now
## measures the result on both shapes.
##
##
## WHY IT LOOKS LIKE THIS
##
## One rhythm (GAP) for every gap on the screen, one corner radius family, one
## accent colour. The four destination cards share a single shape and a single
## internal layout -- picture on top, word underneath -- so they read as four
## of the same thing rather than five unrelated coloured slabs. Colour is
## identity, not emphasis: it lives in the round chip behind each picture.
## The one saturated surface on the screen is 去冒险, because that is the thing
## to press.
##
##
## WHY IT MOVES
##
## A screen that only reacts where it is touched teaches a child that most of
## it is a photograph. So: the pictures drift on their own, the cards squash
## and tilt toward the finger, the hero answers whichever card was pressed, and
## the world behind all of it can be poked (see Stage.poke_at). None of it
## navigates anywhere and none of it can be got wrong. All of it is skipped
## under reduce-motion, which means "calm screen" and is honoured by every
## loop here.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")

# --- the one rhythm -----------------------------------------------------
# Every gap on this screen is GAP or a multiple of it. Three neighbouring
# elements with three different spacings is three accidents, so there is
# exactly one number and everything else is derived from it.
const GAP := 24
const MARGIN := GAP            # safe edge, all four sides
const GROUP := GAP * 2         # between groups: hero column | card block
const RADIUS := 28             # one corner family, all four cards
const HEADER_H := 72
const PARENT_H := 64           # the parent capsule; also its corner radius x2

const PARENT_HOLD_SECONDS := 3.0

# Type scale: four sizes, each at least 1.3x the next. Anything outside this
# list is a fifth size nobody asked for.
const TYPE_GREETING := UiKit.TYPE_DISPLAY
const TYPE_TREASURE := UiKit.TYPE_BODY
const TYPE_HINT := UiKit.TYPE_CAPTION

var _hold_time := 0.0
var _holding := false
## Rises once per too-short tap; the flash timer only clears the hint it
## itself put up. See _cancel_hold.
var _hint_flash := 0

var _stage: Stage
var _greeting: Label
var _treasure: Button
var _hero_holder: Control
var _hero: SkinnedCharacter
var _parent_pill: Button
var _parent_fill: Panel
var _parent_hint: Label
var _cards: Array[Button] = []

## Rebuilt from the viewport on every resize, and read by the probe.
var _card_boxes: Array[Rect2] = []


func _ready() -> void:
	theme = UiKit.theme()
	_stage = UiKit.world_background(self, "piglet_town", "home", 0.18)

	_build_greeting()
	_build_cards()
	_build_hero()
	_build_parent_door()
	_build_treasure_chip()

	_layout()
	# A tablet rotating, or the father dragging the debug window, must not
	# leave half the screen behind. Layout is a function of the viewport, so
	# it is simply run again.
	get_viewport().size_changed.connect(_layout)


# --- layout -------------------------------------------------------------

## Everything on the screen, placed from the real viewport size.
##
## Asks the screen how big it is exactly once, here, and hands out rectangles.
## No other function in this file may contain a coordinate.
func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return

	# Left column holds the hero and the parent door; the cards take the rest.
	var left_w: float = _snap(clampf(view.x * 0.25, 250.0, 330.0))
	# The cards stop at the horizon, and the ground below them belongs to the
	# world: the hero stands in it and the child can poke everything in it.
	#
	# Running them to the bottom margin instead is what the first version did,
	# and it parked the card block on top of every prop on the right-hand half
	# of the island -- the pokeable world was still there, still working, and
	# had two reachable things in it on a tablet. Nobody would ever have
	# reported that; poking a home screen and getting nothing looks exactly
	# like a home screen.
	var body_top: float = MARGIN + HEADER_H + GAP
	var body_bottom: float = minf(view.y - MARGIN, _stage.ground_y() - GAP)
	var body_h: float = body_bottom - body_top
	var cards_x: float = MARGIN + left_w + GROUP
	var cards_w: float = view.x - MARGIN - cards_x

	# One wide card over three short ones. The primary is bigger, not just a
	# different colour: size is the half of "press this one" that survives
	# being colour-blind, six years old, or in a bright room. It is a banner
	# rather than a slab -- at 0.535 of the block it was tall enough that the
	# picture and the word floated in the middle of a field of green.
	var rows_h: float = body_h - GAP
	var h1: float = _snap(rows_h * 0.46)
	var h2: float = rows_h - h1
	# Counted, not written down. The literal 3 here is exactly the mistake this
	# file's header is about: the grid was hand-fitted to the card count, and
	# the fifth card walked off the edge of the screen. Adding 光之战士 made it
	# four. Whatever the array holds, the row divides by it.
	var secondary: int = maxi(_cards.size() - 1, 1)
	var sec_w: float = (cards_w - GAP * float(secondary - 1)) / float(secondary)

	# The greeting starts where the cards start. Aligning it to the screen edge
	# instead put it above the hero, which reads as a label for the hero.
	_greeting.position = Vector2(cards_x, MARGIN)
	_greeting.size = Vector2(cards_w * 0.7, HEADER_H)

	_card_boxes = [Rect2(Vector2(cards_x, body_top), Vector2(cards_w, h1))]
	for i in range(secondary):
		_card_boxes.append(Rect2(
			Vector2(cards_x + (sec_w + GAP) * float(i), body_top + h1 + GAP),
			Vector2(sec_w, h2)))
	for i in range(_cards.size()):
		_place_card(_cards[i], _card_boxes[i], i == 0)

	# The parent door owns the bottom-right corner, and it is the only thing
	# there. Not the bottom-LEFT, which is where the hero stands: he had to be
	# lifted off the ground to clear it, and a hero hovering twenty pixels above
	# his own grass looks merely "a bit off" forever.
	#
	# It keeps its DISTANCE to the two edges rather than a fraction of them --
	# a thumb rests where the bezel is, and the bezel does not move
	# proportionally. Same exception the skill pad gets, argued for by name in
	# tablet_probe.gd.
	_parent_pill.position = Vector2(view.x - MARGIN - PARENT_H, view.y - MARGIN - PARENT_H)
	_parent_pill.size = Vector2(PARENT_H, PARENT_H)
	_parent_fill.size.y = PARENT_H
	# Its words sit to the LEFT of it, right-aligned against it, so they grow
	# inward instead of off the edge of the screen.
	var hint_w: float = 200.0
	_parent_hint.position = Vector2(
		_parent_pill.position.x - GAP * 0.5 - hint_w,
		_parent_pill.position.y + (PARENT_H - TYPE_HINT * 2.6) * 0.5)
	_parent_hint.size = Vector2(hint_w, TYPE_HINT * 2.6)

	# The hero stands ON the ground, so he follows the ground down a taller
	# screen. His size follows the screen too -- a hero drawn for 720 is a doll
	# on a 960-tall tablet.
	var feet: float = _stage.ground_y()
	var hero_h: float = clampf(view.y * 0.45, 240.0, 400.0)
	_hero_holder.size = Vector2(left_w, hero_h)
	_hero_holder.position = Vector2(MARGIN, feet - hero_h)
	_hero.position = Vector2(left_w * 0.5, hero_h)
	_hero.set_height(hero_h * 0.86)
	# The contact shadow is placed here rather than remembered from build time:
	# the hero moves on every resize, and a shadow left behind where he used to
	# stand is worse than no shadow at all. It is also what plants him -- the
	# first version had a soft warm spotlight instead, which was invisible
	# against a pale green hill in daylight and left him floating.
	var shade: Node2D = _hero_holder.get_node("Shade")
	shade.position = Vector2(left_w * 0.5, hero_h)
	shade.scale = Vector2.ONE * (hero_h / 300.0)

	# The world does not get to put a cottage where the hero is standing.
	# Without this he reads as balanced on someone's roof -- which is what the
	# first rendering of this layout actually looked like, because props are
	# placed in slots that only avoid the middle third and the hero is in the
	# left one.
	# Only as wide as he is. A generous lane is tempting and wrong: every prop
	# it clears is a thing the child can no longer poke, and the left column is
	# where most of the reachable world lives.
	_stage.clear_lane(MARGIN + left_w * 0.5 - hero_h * 0.24,
		MARGIN + left_w * 0.5 + hero_h * 0.24)

	_place_treasure(view)


## The rhythm survives division: snap back onto a multiple of 4 so a card that
## came out of a divide by three does not land on a half pixel and blur its
## own edge.
func _snap(value: float) -> float:
	return roundf(value / 4.0) * 4.0


# --- the greeting -------------------------------------------------------

func _build_greeting() -> void:
	_greeting = UiKit.title_on_art(I18n.t("home.greeting"), TYPE_GREETING)
	_greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_greeting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_greeting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_greeting)


# --- the four doors -----------------------------------------------------

func _build_cards() -> void:
	# Order is reading order, and reading order is importance order.
	var doors: Array[Dictionary] = [
		{"key": "home.play", "icon": "flag", "color": Palette.GREEN,
			"motion": "sway", "go": func(): _on_play()},
		{"key": "home.rewards", "icon": "star", "color": Palette.ORANGE,
			"motion": "turn", "go": func(): _goto("res://scenes/reward/RewardCenter.tscn")},
		{"key": "home.house", "icon": "house", "color": Palette.PURPLE,
			"motion": "bob", "go": func(): _goto("res://scenes/shop/HeroHouseScreen.tscn")},
		# The farm's front door, and since 2026-07-30 its ONLY door.
		#
		# The garden used to ALSO be a room on the island, which made "退出" a
		# question with no right answer: back to a map he may never have seen,
		# or back to here? It answered "the map", and the child who came in
		# through this card landed somewhere he had not been. The garden is off
		# the island now (mode: standalone in levels.json) and its way out is
		# this screen -- 从哪进就从哪出，全游戏一条规则。
		{"key": "home.garden", "icon": "carrot", "color": Palette.RED,
			"motion": "sprout", "go": func(): _on_garden()},
		# 光之战士. The monster fighting used to be six boss levels scattered one
		# per island world -- a child who wants to fight a monster had to walk
		# the island and finish five other things first. It is its own door now,
		# off the map like the garden, and the icon is the monster itself
		# because that is the word he owns.
		{"key": "home.battle", "icon": "monster", "color": Palette.PURPLE,
			"motion": "bob", "go": func(): _on_battle()},
	]

	# What is waiting behind each door, said with a picture in the corner.
	#
	# Positive marks only, and only for things that are TRUE right now: a ripe
	# carrot because there is a ripe carrot, a star because he owns something
	# he has not looked at yet. Never a red dot, never a count that goes up
	# while he is away, never anything that expires -- a home screen that nags
	# a six-year-old into a shop is the thing this game exists not to be.
	# The star is the same mark item_card.gd already draws in the Hero House,
	# so it means the same thing in both places.
	#
	# The garden's mark is a BASKET, not a carrot. A carrot was the obvious
	# choice and it is the weaker one twice over: the card already has a carrot
	# on it, so a second smaller carrot in the corner repeats what the card
	# says instead of adding "and it is ready" -- and a drawn carrot is a
	# narrow cone that fills about a third of a 44px badge, while a basket
	# fills it. The basket is also the picture he already picks things into in
	# 丰收行动, so it says "there is something to pick" in a word he owns.
	doors[1]["mark"] = ""
	doors[2]["mark"] = "star" if _house_has_something_new() else ""
	doors[3]["mark"] = "basket" if _garden_has_something_ripe() else ""

	for i in range(doors.size()):
		var door: Dictionary = doors[i]
		var primary: bool = i == 0
		var card := _card(str(door["key"]), str(door["icon"]),
			door["color"] as Color, primary)
		card.set_meta("motion", str(door["motion"]))
		card.set_meta("mark", str(door.get("mark", "")))
		var go: Callable = door["go"]
		card.pressed.connect(go)
		# The hero answers the press, not the arrival: the reaction has to
		# land while the finger is still down or it is a reaction to nothing.
		var which: int = i
		card.button_down.connect(func(): _hero_answers(which))
		add_child(card)
		_cards.append(card)

	# The breathing lives on the primary card's CHIP, not on the card.
	#
	# Breathing the card was the obvious thing and it silently cancelled the
	# press: both are tweens on the same `scale`, the looping one always wins,
	# and 去冒险 -- the one button on this screen that matters -- was the one
	# card that did not squash when pressed. The probe caught it reading a
	# scale of 1.011 in the middle of a press.
	#
	# So: one owner per property. The card's scale belongs to the finger, and
	# the slow "this is the one" pulse belongs to the disc inside it.
	UiKit.breathe(_cards[0].get_node("Body/Box/Chip"), 0.035, 1.1)


## One card. All four are built by this function and differ only in scale and
## in whether they carry the accent -- which is what makes them read as four of
## the same thing instead of a pile of coloured rectangles.
func _card(text_key: String, icon_name: String, color: Color, primary: bool) -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = false

	# A soft shadow OR a border, never both. The chunky bottom edge that
	# UiKit.big_button draws is this game's press feedback everywhere else;
	# here the card itself squashes and tilts under the finger, which does the
	# same job better, so the edge would be a second border saying nothing.
	# Nearly opaque, not translucent. At 0.93 the cottage behind the fourth
	# card showed through it, and a roof inside a button reads as a rendering
	# fault rather than as depth.
	var face: Color = color if primary else Color(1.0, 0.99, 0.96, 0.97)
	card.add_theme_stylebox_override("normal", _card_style(face, 10))
	card.add_theme_stylebox_override("hover", _card_style(face.lightened(0.06), 10))
	# Pressed drops the shadow: the card sinks into the screen. This is the
	# whole press feedback under reduce-motion, where the tilt is skipped.
	card.add_theme_stylebox_override("pressed", _card_style(face.darkened(0.05), 2))
	card.add_theme_stylebox_override("disabled", _card_style(Palette.MUTED, 4))

	# Centred by a container rather than by arithmetic. The first version
	# placed the picture and the word at computed offsets, which is fine until
	# the word is one character longer or the screen is 240px taller -- and
	# then it is a stack that is centred on paper and 9px off on the tablet.
	var body := CenterContainer.new()
	body.name = "Body"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)

	# Picture beside the word on the big card, picture above it on the small
	# ones: a 3:1 rectangle with a centred stack in it is mostly empty green,
	# and empty is what the first rendering looked like.
	var box: BoxContainer = HBoxContainer.new() if primary else VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(box)

	var chip := Panel.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(chip)

	# Colour lives here, behind the picture, and nowhere else on a white card.
	# On the accent card the chip is a hole punched in the green rather than a
	# sixth colour, so the screen still has exactly one.
	var chip_fill: Color = Color(1.0, 1.0, 1.0, 0.26) if primary else color.lightened(0.70)
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = chip_fill
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.set_meta("style", chip_style)

	# The picture is centred inside the chip by a container too, so it stays
	# centred when the chip is re-sized on a different screen.
	var well := CenterContainer.new()
	well.name = "Well"
	well.set_anchors_preset(Control.PRESET_FULL_RECT)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(well)

	var label := Label.new()
	label.name = "Word"
	label.text = I18n.t(text_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_color_override("font_color",
		Palette.ON_COLOR if primary else Palette.INK)
	box.add_child(label)
	card.set_meta("icon_name", icon_name)
	card.set_meta("primary", primary)

	# Driven from the button's own press, NOT from gui_input.
	#
	# gui_input was the obvious way to get the finger's position, and it does
	# not work here: with emulate_touch_from_mouse on -- which is how the debug
	# build runs -- a Button consumes the mouse event itself, so the emulated
	# touch never reaches the signal, and UiKit.is_press correctly refuses the
	# mouse duplicate. The result was a card that tilted on a tablet and sat
	# there like a photograph on the machine this game is developed on. The
	# home probe now presses a card and asserts it actually moved.
	#
	# button_down/button_up have no such gap, and Godot's own de-duplication
	# means they fire once per finger. The position comes from the mouse, which
	# follows the finger on a touchscreen through the reverse emulation.
	card.button_down.connect(func():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_card_push(card, card.get_local_mouse_position().x))
	card.button_up.connect(func(): _card_settle(card))
	return card


func _card_style(fill: Color, shadow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(RADIUS)
	style.shadow_color = Color(0.05, 0.10, 0.20, 0.16)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, 4 if shadow > 4 else 1)
	return style


## Put a card in its rectangle and re-scale everything inside it.
##
## The picture and the word are sized FROM the card, not from a constant, so
## the same code fills a 296-tall card on a 16:9 screen and a 424-tall one on
## a tablet without either looking like a mistake.
func _place_card(card: Button, box: Rect2, primary: bool) -> void:
	card.position = box.position
	card.size = box.size
	card.pivot_offset = box.size * 0.5

	# Four type sizes on the screen and each at least 1.3x the next: 56 / 42 /
	# 30 / 20. Two sizes a hair apart read as a mistake rather than a level.
	#
	# The chip is bounded by the card's WIDTH as well as its height. On the 4:3
	# tablet the small cards are tall and narrow, and a chip sized off height
	# alone grew until its top corner reached the card's own corner -- straight
	# under the mark that lives there.
	var chip_d: float = _snap(minf(
		clampf(box.size.y * (0.60 if primary else 0.42), 88.0, 210.0),
		box.size.x * 0.50))
	var font_size: int = int(_snap(clampf(box.size.y * (0.20 if primary else 0.12),
		24.0, 56.0)))

	var group: BoxContainer = card.get_node("Body/Box")
	group.add_theme_constant_override("separation", int(GAP * (1.5 if primary else 1.0)))

	var chip: Panel = card.get_node("Body/Box/Chip")
	chip.custom_minimum_size = Vector2(chip_d, chip_d)
	var chip_style: StyleBoxFlat = chip.get_meta("style")
	chip_style.set_corner_radius_all(int(chip_d * 0.5))

	# The picture is rebuilt at the new size rather than scaled: a drawn icon
	# stretched by a transform gets fuzzy edges and a stretched line weight,
	# and this screen has four of them side by side where that shows.
	var well: CenterContainer = card.get_node("Body/Box/Chip/Well")
	for child in well.get_children():
		child.queue_free()
	var icon_size: float = _snap(chip_d * 0.62)
	var icon: Control = UiKit.picture(str(card.get_meta("icon_name")), icon_size)
	if icon != null:
		# A perch between the container and the picture. Two of the four idle
		# motions move the picture, and a container re-sorts its own children
		# on every resize -- so a picture parented straight to the well gets
		# snapped back to centre mid-bob the first time the window changes
		# shape, and the tween then animates away from a position that is no
		# longer where it started.
		var perch := Control.new()
		perch.custom_minimum_size = Vector2(icon_size, icon_size)
		perch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(perch)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		perch.add_child(icon)
		_animate_icon(icon, icon_size, str(card.get_meta("motion")))

	var label: Label = card.get_node("Body/Box/Word")
	label.add_theme_font_size_override("font_size", font_size)

	_place_mark(card, box, chip_d)


## The little picture in a card's top-right corner, if that card has something
## waiting behind it.
##
## Drawn bare, with no disc under it. A disc would need either a border or a
## shadow to lift it off a warm-white card, and a badge is already the smallest
## thing on the screen -- two layers of furniture around a 40px carrot is how a
## corner mark turns into clutter. The pictures carry their own dark outlines
## and sit on the one part of a card that is always empty.
func _place_mark(card: Button, box: Rect2, chip_d: float) -> void:
	var wanted: String = str(card.get_meta("mark", ""))
	var old: Node = card.get_node_or_null("Mark")
	if old != null:
		old.queue_free()
		# Renamed at once, because queue_free happens at the end of the frame
		# and a second layout in the same frame would find the corpse and hand
		# the new mark a duplicate name.
		old.name = "MarkGone"
	if wanted == "":
		return

	# Sized to fit the gap beside the picture, not just to look right on the
	# shape it was drawn for. On the 4:3 tablet the small cards are narrow
	# enough that a mark scaled off the chip alone clipped the chip's own
	# corner by two pixels -- invisible in a screenshot, and exactly the sort
	# of thing that becomes twenty pixels the next time a card changes size.
	var free: float = (box.size.x - chip_d) * 0.5 - GAP
	var size: float = _snap(clampf(minf(chip_d * 0.42, free), 28.0, 60.0))
	var perch := Control.new()
	perch.name = "Mark"
	perch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perch.position = Vector2(box.size.x - size - GAP * 0.5, GAP * 0.5)
	perch.size = Vector2(size, size)
	card.add_child(perch)
	var picture: Control = UiKit.picture(wanted, size)
	if picture != null:
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		perch.add_child(picture)


## Is anything in the garden ready to pick right NOW?
##
## Asked through the same settle the garden itself runs, on a copy -- settle()
## deep-copies before it touches anything, so this reads the future without
## writing it. Reading the raw save instead would mark the card only for a
## child who had already gone in and looked, which is the one child who does
## not need telling.
func _garden_has_something_ripe() -> bool:
	var raw: Variant = SaveManager.data.get("farm", null)
	if not (raw is Dictionary):
		return false
	var settled: Dictionary = Growth.settle(raw as Dictionary, GameClock.now_unix())
	var plots: Array = settled.get("plots", [])
	for i in range(plots.size()):
		if Farm.is_ready(Farm.normalise_plot(plots[i], i)):
			return true
	return false


## Does he own something he has not looked at yet?
##
## Routed through Shop.is_new so this mark and the one in the Hero House can
## never disagree about what "new" means -- and so that looking at the thing
## clears both, because there is only one ledger.
func _house_has_something_new() -> bool:
	var shop: Dictionary = SaveManager.data.get("shop", {})
	for owned in shop.get("owned", []):
		if Shop.is_new(str(owned)):
			return true
	return false


## The idle life of one picture.
##
## Four different motions with four different periods, because four identical
## bobs read as a machine rather than as a place. Each is small enough that a
## child notices it without being pulled by it, and every one of them is off
## under reduce-motion.
func _animate_icon(icon: Control, size: float, kind: String) -> void:
	if not Juice.motion_enabled():
		return
	var tween: Tween = icon.create_tween().set_loops()
	match kind:
		"sway":
			# A flag pivots at the bottom of its pole, not at its middle.
			icon.pivot_offset = Vector2(size * 0.5, size * 0.92)
			tween.tween_property(icon, "rotation", 0.075, 1.1)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(icon, "rotation", -0.075, 1.1)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"turn":
			icon.pivot_offset = Vector2(size, size) * 0.5
			tween.tween_property(icon, "rotation", 0.14, 1.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(icon, "rotation", -0.14, 1.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"bob":
			var rest: Vector2 = icon.position
			tween.tween_property(icon, "position", rest - Vector2(0, size * 0.06), 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(icon, "position", rest, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"sprout":
			# A carrot pushing out of the soil and settling back: up quickly,
			# down slowly, with a pause before it tries again.
			var home: Vector2 = icon.position
			tween.tween_property(icon, "position", home - Vector2(0, size * 0.10), 0.45)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "position", home, 0.9)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_interval(0.85)


# --- the feel of a card -------------------------------------------------

## Squash toward the finger and spring back.
##
## The tilt direction is read from WHERE the card was touched, so its left edge
## and its right edge do not feel like the same button. That is the whole
## difference between a picture that changes colour and a thing that moved
## because you moved it.
func _card_push(card: Button, local_x: float) -> void:
	if not Juice.motion_enabled():
		return
	var away: float = 0.0
	if local_x >= 0.0 and card.size.x > 1.0:
		away = clampf((local_x / card.size.x) - 0.5, -0.5, 0.5)
	var tween: Tween = card.create_tween().set_parallel()
	tween.tween_property(card, "scale", Vector2(0.965, 0.94), 0.09)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", away * 0.05, 0.09)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Back to rest, from wherever the card happens to be.
##
## button_up fires wherever the finger lets go, including off the card, so a
## card cannot be left squashed by a press that wandered away -- which is the
## kind of thing nobody reports and everybody sees.
func _card_settle(card: Button) -> void:
	if not is_instance_valid(card):
		return
	var tween: Tween = card.create_tween().set_parallel()
	tween.tween_property(card, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", 0.0, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- the hero -----------------------------------------------------------

## The chosen hero, standing at home. Tapping them earns a little celebration
## -- it does nothing, costs nothing, and cannot be wrong, which is exactly the
## kind of button a six-year-old presses forty times with total satisfaction.
## It is also how the Hero House choice stays visible: whoever was picked is
## whoever is standing here.
func _build_hero() -> void:
	_hero_holder = Control.new()
	_hero_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hero_holder)

	# The patch of shade under his boots. Drawn through Shapes, so the hero at
	# home and every actor the Stage places stand on the same kind of floor.
	var shade := Node2D.new()
	shade.name = "Shade"
	_hero_holder.add_child(shade)
	Shapes.ground_shadow(shade, Vector2.ZERO, 150.0, 0.20)

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero_holder.add_child(_hero)

	# Every so often the hero cheers on their own -- the screen invites play
	# instead of waiting for it. Skipped entirely under reduce-motion: that
	# setting means "calm screen", including from the hero.
	var wave_timer := Timer.new()
	wave_timer.wait_time = 9.0
	wave_timer.autostart = true
	_hero_holder.add_child(wave_timer)
	wave_timer.timeout.connect(func():
		if Juice.motion_enabled() and is_instance_valid(_hero):
			_hero.celebrate()
	)

	# Tapping the hero earns a trick, and the trick varies -- a hop, a cheer,
	# a tumble and back. Variety is what makes a child tap twice, and a child
	# who taps twice has learned the hero is THEIRS to poke.
	var trick := 0
	_hero_holder.gui_input.connect(func(event: InputEvent):
		if not UiKit.is_press(event):
			return
		match trick % 3:
			0:
				_hero.hop()
			1:
				_hero.celebrate()
			2:
				_hero.roll(90.0 if _hero.position.x < _hero_holder.size.x * 0.5 else -90.0, 0.5)
		trick += 1
		Juice.burst(_hero_holder, _hero.position - Vector2(0, _hero_holder.size.y * 0.45), 14)
		AudioManager.play_sfx("res://assets/audio/star.ogg")
	)


## The hero reacts to the card under the child's finger.
##
## A different answer per door, so pressing all four is worth doing once for
## its own sake. This is the only place on the screen where one control moves
## another, and it is deliberate: it is what makes the hero read as watching.
func _hero_answers(which: int) -> void:
	if not Juice.motion_enabled() or not is_instance_valid(_hero):
		return
	match which:
		0:
			_hero.celebrate()
		1:
			_hero.jump(70.0, 0.5)
		2:
			_hero.hop()
		_:
			_hero.hop()


# --- the parent door ----------------------------------------------------

## Press and hold, then an arithmetic gate on the next screen.
##
## The capsule fills as it is held, so an adult can SEE the hold working --
## the old version printed a countdown into the button's own label, which
## meant the button changed width three times on the way through and the whole
## row jittered. The fill says the same thing without moving anything.
##
## Deliberately the quietest thing on the screen: muted, low contrast, in the
## corner. A child who taps it once gets nowhere, which is the point.
func _build_parent_door() -> void:
	_parent_pill = Button.new()
	_parent_pill.focus_mode = Control.FOCUS_NONE
	_parent_pill.clip_contents = true
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.16, 0.21, 0.30, 0.55)
	pill_style.set_corner_radius_all(int(PARENT_H * 0.5))
	for state in ["normal", "hover", "pressed"]:
		_parent_pill.add_theme_stylebox_override(state, pill_style)
	_parent_pill.button_down.connect(_begin_hold)
	_parent_pill.button_up.connect(_cancel_hold)
	add_child(_parent_pill)

	_parent_fill = Panel.new()
	_parent_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.62, 0.70, 0.82, 0.55)
	fill_style.set_corner_radius_all(int(PARENT_H * 0.5))
	_parent_fill.add_theme_stylebox_override("panel", fill_style)
	_parent_fill.size = Vector2(0, PARENT_H)
	_parent_pill.add_child(_parent_fill)

	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parent_pill.add_child(box)
	var gear: Control = UiKit.picture("gear", 34)
	if gear != null:
		box.add_child(gear)

	# The word lives here rather than inside the button, because a 64px circle
	# with two Chinese characters in it is a circle with no room for the gear
	# -- and the gear is the half of this an adult recognises from across the
	# room. Aimed at the adult, but over painted daylight a soft ink vanishes,
	# so it is white with a shadow like every other word on the artwork.
	#
	# Only the NAME stands here all day. The "hold for three seconds" line is
	# an instruction, and an instruction on permanent display is furniture --
	# it appears at the two moments it answers a question: while the hold is
	# running (as the countdown) and for a breath after a tap too short to
	# open the door (the one moment an adult wonders why nothing happened).
	_parent_hint = UiKit.title_on_art(I18n.t("home.parent"), TYPE_HINT)
	_parent_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_parent_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_parent_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parent_hint)


func _begin_hold() -> void:
	_holding = true
	_hold_time = 0.0
	_parent_fill.size.x = 0.0


func _process(delta: float) -> void:
	if not _holding:
		return
	_hold_time += delta
	_parent_fill.size.x = _parent_pill.size.x * clampf(_hold_time / PARENT_HOLD_SECONDS, 0.0, 1.0)
	# The fill is the feedback; the number is for the adult who wants to know
	# it is not stuck. Only the second line changes, so nothing on the screen
	# moves while the hold runs.
	_parent_hint.text = "%s\n%d" % [I18n.t("home.parent"),
		maxi(int(ceil(PARENT_HOLD_SECONDS - _hold_time)), 1)]

	if _hold_time >= PARENT_HOLD_SECONDS:
		_reset_hold()
		SceneManager.goto_scene("res://scenes/parent/ParentCenter.tscn")


func _cancel_hold() -> void:
	# Let go too early? Say how the door opens, for a breath, then fall
	# quiet again. Guarded by a token so a second attempt's message is never
	# wiped by the first attempt's timer going off late.
	var early := _holding and _hold_time >= 0.15 \
		and _hold_time < PARENT_HOLD_SECONDS
	_reset_hold()
	if early and is_instance_valid(_parent_hint):
		_hint_flash += 1
		var token := _hint_flash
		_parent_hint.text = "%s\n%s" % [I18n.t("home.parent"),
			I18n.t("parent.hold_hint")]
		get_tree().create_timer(2.2).timeout.connect(func():
			if _hint_flash == token and not _holding \
					and is_instance_valid(_parent_hint):
				_parent_hint.text = I18n.t("home.parent"))


func _reset_hold() -> void:
	_holding = false
	_hold_time = 0.0
	if is_instance_valid(_parent_fill):
		_parent_fill.size.x = 0.0
	if is_instance_valid(_parent_hint):
		_parent_hint.text = I18n.t("home.parent")


# --- the treasure chip --------------------------------------------------

## Stars and coins, worn like a badge in the corner, and tapping it opens My
## Rewards -- the number IS the button.
func _build_treasure_chip() -> void:
	_treasure = Button.new()
	_treasure.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	# Opaque enough that a cloud drifting behind it does not show through as a
	# grey smear across the child's own numbers.
	style.bg_color = Color(0.07, 0.13, 0.26, 0.88)
	style.set_corner_radius_all(30)
	for state in ["normal", "hover", "pressed"]:
		_treasure.add_theme_stylebox_override(state, style)
	_treasure.pressed.connect(func():
		Juice.pop(_treasure, 0.06)
		_goto("res://scenes/reward/RewardCenter.tscn"))

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hero rank first: the number that only ever grows.
	var rank_icon: Control = UiKit.picture("shield", 40)
	if rank_icon != null:
		row.add_child(rank_icon)
		row.add_child(UiKit.title("%d" % SaveManager.hero_level(), TYPE_TREASURE,
			Palette.ON_COLOR))

	var star_icon: Control = UiKit.picture("star", 40)
	if star_icon != null:
		row.add_child(star_icon)
	row.add_child(UiKit.title("%d" % SaveManager.total_stars(), TYPE_TREASURE,
		Palette.ON_COLOR))

	var coin_icon: Control = UiKit.picture("coin", 40)
	if coin_icon != null:
		row.add_child(coin_icon)
	row.add_child(UiKit.title("%d" % int(SaveManager.data["rewards"]["coins"]),
		TYPE_TREASURE, Palette.ON_COLOR))

	_treasure.add_child(row)
	add_child(_treasure)


## Pinned to the top-right corner of the REAL screen.
##
## This used to read `1280.0 - chip.size.x - 28.0`. It is right on a 16:9
## screen and right by accident on a tablet, because the viewport happens to
## stay 1280 wide -- so the bug was invisible and would have appeared the day
## the design width changed. There is no reason to keep a hard-coded edge when
## the screen can be asked.
func _place_treasure(view: Vector2) -> void:
	var row: Control = _treasure.get_node("Row")
	var wanted: Vector2 = row.get_combined_minimum_size() + Vector2(GAP * 1.5, GAP * 0.8)
	_treasure.size = Vector2(maxf(wanted.x, 160.0), maxf(wanted.y, 60.0))
	row.position = (_treasure.size - row.get_combined_minimum_size()) * 0.5
	row.size = row.get_combined_minimum_size()
	_treasure.position = Vector2(view.x - MARGIN - _treasure.size.x, MARGIN)
	_treasure.pivot_offset = _treasure.size * 0.5


# --- the world is not a photograph --------------------------------------

## A tap that landed on none of the controls above.
##
## Handled input has already had its chance, so a card, the hero and the two
## chips all get first refusal and nothing here can steal a real press. What is
## left is the scenery, and the scenery answers: a poked cloud squashes, a
## poked cottage rocks on its feet. It goes nowhere and cannot be wrong.
func _unhandled_input(event: InputEvent) -> void:
	if not UiKit.is_press(event):
		return
	if _stage == null or not is_instance_valid(_stage):
		return
	var at: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	else:
		return
	if _stage.poke_at(at):
		AudioManager.play_sfx("res://assets/audio/pop.ogg")


# --- going somewhere ----------------------------------------------------

func _goto(path: String) -> void:
	SceneManager.goto_scene(path)


func _on_play() -> void:
	if GameManager.daily_limit_reached():
		_show_break_message()
		return
	SceneManager.goto_world_map()


## The garden room, found by what it IS rather than by its name: the one
## room whose game is the garden. Nobody here spells the id, so a renamed or
## second room keeps this button honest without anyone remembering it exists.
func _on_garden() -> void:
	for level in GameData.levels:
		if bool(level.get("room", false)) \
				and str(level.get("game_type", "")) == "garden":
			GameManager.start_level(str(level.get("id", "")))
			return


## 光之战士: the next monster he has not beaten.
##
## The same shape as the garden's 丰收 door, and for the same reason: a menu of
## fifteen is a menu, and a six-year-old who cannot read chooses by pressing
## the biggest thing. One door, one fight, always the next one.
##
## When all fifteen are done it offers the last one again -- replaying is fine,
## and a door that stops opening is a door that looks broken. Nobody spells a
## level id here; the path is whatever levels.json files under this mode.
func _on_battle() -> void:
	var levels: Array = GameData.get_levels_for_mode("battle")
	if levels.is_empty():
		return
	var next: Dictionary = levels[levels.size() - 1]
	for level in levels:
		if int(SaveManager.get_level_progress(str(level.get("id", ""))
				).get("stars", 0)) <= 0:
			next = level
			break
	GameManager.start_level(str(next.get("id", "")))


## Advisory only. There is no lock and no countdown -- it is a suggestion the
## child can dismiss, and the real limit is the parent in the room.
##
## Built from the game's own parts rather than an AcceptDialog. Godot's dialog
## is an OS window with the engine's default grey theme: it ignored the palette
## entirely, and the one moment the game asks a six-year-old to stop playing is
## the worst possible moment to suddenly look like a system error.
func _show_break_message() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.08, 0.16, 0.0)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	var fade := scrim.create_tween()
	fade.tween_property(scrim, "color:a", 0.55, 0.25)

	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(holder)

	var card := UiKit.card()
	card.custom_minimum_size = Vector2(760, 0)
	holder.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)

	# A moon, because "night, sleep, stop" is a picture a pre-reader already
	# owns and a paragraph of Chinese is not.
	var moon: Control = UiKit.picture("moon", 108)
	if moon != null:
		var moon_row := CenterContainer.new()
		moon_row.add_child(moon)
		column.add_child(moon_row)

	column.add_child(UiKit.title(I18n.t("limit.title"), UiKit.TYPE_TITLE))

	var body := UiKit.title(I18n.t("limit.body"), UiKit.TYPE_BODY, Palette.INK_SOFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(680, 0)
	column.add_child(body)

	var button_row := CenterContainer.new()
	var ok := UiKit.big_button(I18n.t("common.continue"), Palette.GREEN)
	ok.pressed.connect(func():
		scrim.queue_free()
		SceneManager.goto_world_map()
	)
	button_row.add_child(ok)
	column.add_child(button_row)
	UiKit.breathe(ok, 0.03, 1.0)
