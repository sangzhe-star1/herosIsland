extends Control
## 英雄小屋 -- the dressing-up room.
##
## The old page was a configuration form: title, hint, a row of slot tabs, a
## row of 94 px tiles, a row of character cards, a sticker wall. The character
## was fifth down the page and a quarter of the height of the thing that
## dressed him.
##
## This one is a room. The hero stands in the middle at three quarters of the
## stage, the drawers of the wardrobe are down the left, and what is in the
## open drawer is a shelf of big cards along the bottom. Everything a finger
## touches does something within a tenth of a second, and nothing costs a star
## until he has seen the thing on and said yes.
##
## Laid out from the VIEWPORT, never from 1280x720. `stretch/aspect` is
## "expand", so a 4:3 tablet gets 1280x960 and anything measured off a
## hard-coded 720 ends up floating a quarter of the way up the screen. That
## exact bug shipped twice in this project already.

const Shapes := preload("res://scripts/world/shapes.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Presets := preload("res://scripts/shop/preset_manager.gd")
const History := preload("res://scripts/shop/outfit_history.gd")
## Named Podium, not Stage: `Stage` is already the world-scenery class, and
## shadowing it made `_stage.build()` resolve to Stage.build(parent, ...) --
## a parse error that took the whole screen out.
const Podium := preload("res://scripts/shop/character_preview.gd")
const Card := preload("res://scripts/shop/item_card.gd")
const Buying := preload("res://scripts/shop/purchase_manager.gd")

## 形象 first: who he is comes before what that person is wearing.
const CATEGORIES := ["who", "head", "body", "back", "hands", "feet", "colour",
	"pal", "set"]

var _stage: Control
var _shelf: HBoxContainer
var _scroll: ScrollContainer
var _tabs: Dictionary = {}
var _cards: Dictionary = {}
var _coin_label: Label
var _back: Button             # named, so the probe can ask what it overlaps
var _tray: Control            # the "do you like it?" strip
var _category := "head"
var _trying := ""             # the item being tried on, "" when nothing is
var _history := History.new()
var _buying: Buying
var _hero_row: HBoxContainer
var _face_scroll: ScrollContainer
var _preset_row: VBoxContainer
var _head_h := 96.0
var _shelf_h := 176.0
var _faces_h := 70.0
var _stage_top := 96.0
var _stage_h := 380.0


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.world_background(self, "piglet_town", "hero_house", 0.55)
	_buying = Buying.new()
	add_child(_buying)
	_buying.changed.connect(_after_change)
	_buying.bought.connect(_after_bought)
	_buying.go_play.connect(func(): SceneManager.goto_scene(
		"res://scenes/map/WorldMap.tscn"))

	var view: Vector2 = get_viewport_rect().size
	# The whole page in one place, measured off the real viewport. On a 4:3
	# tablet (1280x960) every band below simply gets taller; nothing is
	# written against 720.
	_head_h = 88.0
	_shelf_h = 196.0
	_faces_h = 84.0
	_stage_top = _head_h
	# The band between the title and the shelf. The face row takes the bottom
	# _faces_h of it and the hero stands in what is left -- they used to share,
	# which put a white strip of faces straight over his platform.
	_stage_h = view.y - _head_h - _shelf_h
	_build_header(view)
	_build_tabs(view)
	_build_stage(view)
	_build_tools(view)
	_build_shelf(view)
	_open(_category)
	_first_visit_gift()


# --- the room -------------------------------------------------------------

func _build_header(view: Vector2) -> void:
	_back = UiKit.back_button(func(): SceneManager.goto_home())
	_back.position = Vector2(24, 18)
	add_child(_back)

	var title := UiKit.title_on_art(I18n.t("house.title"), UiKit.TYPE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.position = Vector2(168, 12)
	title.size = Vector2(560, 52)
	add_child(title)

	var sub := Label.new()
	sub.text = I18n.t("house.sub")
	sub.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiKit.on_art(sub, 6)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	sub.position = Vector2(172, 56)
	sub.size = Vector2(660, 32)
	add_child(sub)

	# The purse. Tapping it plays a sound and leads nowhere: there is no
	# top-up in this game and there never will be, so the one place a child
	# would look for one has to be a dead end that still feels friendly.
	var purse := Button.new()
	purse.flat = true
	purse.focus_mode = Control.FOCUS_NONE
	purse.position = Vector2(view.x - 244.0, 20)
	purse.size = Vector2(220, 84)
	purse.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		Juice.pop(_coin_label, 0.28))
	add_child(purse)
	var pad := Node2D.new()
	purse.add_child(pad)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, Vector2(220, 84), 26.0),
		Color(1, 1, 1, 0.90), 0.0)
	Shapes.lit(pad, Shapes.star_points(Vector2(44, 42), 24.0, 0.44, 5),
		Color(1.0, 0.83, 0.30), 0.95)
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
	_coin_label.add_theme_color_override("font_color", Color(0.22, 0.32, 0.48))
	_coin_label.position = Vector2(78, 20)
	_coin_label.size = Vector2(126, 46)
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(_coin_label)
	_show_coins()


func _build_tabs(view: Vector2) -> void:
	# Nine drawers down the left, in TWO columns of five and four.
	#
	# One column was the obvious layout and it failed twice at once, and both
	# failures were invisible in a screenshot glance. Nine drawers stacked in
	# the band between title and shelf left each one 138x40 -- and 40 is
	# smaller than the finger pressing it; this project's own floor for a
	# child's target is 60. And the column started at the same height as the
	# back button, which sits in the same corner: the top drawer (形象, the
	# most important one) was UNDER the back button by sixteen pixels,
	# pressable only in its lower half. Two columns halve the row count, which
	# is what buys every drawer its sixty pixels; starting below the back
	# button gives the corner exactly one owner.
	var top: float = maxf(_stage_top + 2.0, _back.position.y + _back.size.y + 12.0)
	var rows: int = int(ceil(float(CATEGORIES.size()) / 2.0))
	var room: float = view.y - _shelf_h - 6.0 - top
	var step: float = room / float(rows)
	var chip_w := 82.0
	for i in range(CATEGORIES.size()):
		var slot: String = CATEGORIES[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(14.0 + float(i % 2) * (chip_w + 7.0),
			top + float(i / 2) * step)
		b.size = Vector2(chip_w, minf(step - 7.0, 108.0))
		b.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			_open(slot))
		add_child(b)
		_tabs[slot] = b
		_paint_tab(slot, slot == _category)


func _paint_tab(slot: String, chosen: bool) -> void:
	var b: Button = _tabs[slot]
	for child in b.get_children():
		child.queue_free()
	var pad := Node2D.new()
	b.add_child(pad)
	var box: Vector2 = b.size
	# The unchosen ones stay clearly legible. Greying out seven of eight
	# drawers to show which is open makes the wardrobe look mostly broken.
	Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, box, 20.0),
		Color(1, 1, 1, 0.96) if chosen else Color(1, 1, 1, 0.74), 0.0)
	if chosen:
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(-4, -4), box + Vector2(8, 8), 22.0),
			Color(1.0, 0.80, 0.32, 0.55), 0.0)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, box, 20.0),
			Color(1, 1, 1, 0.98), 0.0)
	# The picture on top and big; the word underneath, small, for the day he
	# starts reading. They must not overlap: an icon with 帽子 printed across
	# it is neither a picture nor a word. Stacked rather than side by side,
	# because the drawers are square-ish now -- a word beside a picture in an
	# 82px-wide chip would squeeze both.
	var art: float = minf(box.y * 0.52, 44.0)
	var icon: Control = UiKit.picture(_tab_icon(slot), art)
	if icon != null:
		icon.position = Vector2((box.x - art) * 0.5, box.y * 0.5 - art + 4.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
	var label := Label.new()
	label.text = I18n.t(_cat_key(slot))
	label.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	label.add_theme_color_override("font_color",
		Color(0.16, 0.24, 0.38) if chosen else Color(0.44, 0.52, 0.64))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, box.y * 0.5 + 8.0)
	label.size = Vector2(box.x, 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	if chosen and Juice.motion_enabled():
		Juice.pop(b, 0.16)


## Built rather than spelled out, because the eight are data. The static
## check reads bare "namespace.key" literals to find unused strings, so the
## keys themselves are listed in _CAT_KEYS where it can see them.
const _CAT_KEYS := {
	"who": "cat.who",
	"head": "cat.head", "body": "cat.body", "back": "cat.back",
	"hands": "cat.hands", "feet": "cat.feet", "colour": "cat.colour",
	"pal": "cat.pal", "set": "cat.set",
}
const _SET_KEYS := {
	"park": "set.park", "rescue": "set.rescue", "monster": "set.monster",
	"sky": "set.sky", "castle": "set.castle", "party": "set.party",
	"rainbow": "set.rainbow", "space": "set.space", "dino": "set.dino",
	"wizard": "set.wizard", "pirate": "set.pirate", "fairy": "set.fairy",
}


func _cat_key(slot: String) -> String:
	return str(_CAT_KEYS.get(slot, ""))


func _set_key(set_id: String) -> String:
	return str(_SET_KEYS.get(set_id, ""))


func _tab_icon(slot: String) -> String:
	match slot:
		"who": return "hero_face"
		"head": return "cap"
		"body": return "tshirt"
		"back": return "cape_star"
		"hands": return "gloves"
		"feet": return "boots"
		"colour": return "palette"
		"pal": return "paw"
		"set": return "outfit_set"
		_: return "sparkle"


func _build_stage(view: Vector2) -> void:
	_stage = Podium.new()
	# 200, because the drawer rail to its left is two columns wide now
	# (14 + 82 + 7 + 82 = 185) -- at the old 160 the rail's second column sat
	# on the podium's edge.
	_stage.position = Vector2(200, _stage_top)
	# The stage is the STANDING area only. The face row underneath used to be
	# drawn inside it, over the platform, so the hero looked like he was
	# floating above a white strip.
	_stage.size = Vector2(view.x - 200.0 - 226.0, _stage_h - _faces_h)
	add_child(_stage)
	_stage.call("build", _who())
	(_stage as Object).connect("slot_tapped", Callable(self, "_open"))

	# The heroes he already has, as big round faces under the stage. Ten of
	# them at 78 px do not fit across a 894 px stage, so the row scrolls --
	# same gesture as the shelf below it, which he is already using.
	_face_scroll = ScrollContainer.new()
	_face_scroll.position = Vector2(_stage.position.x,
		_stage.position.y + _stage.size.y + 2.0)
	_face_scroll.size = Vector2(_stage.size.x, _faces_h)
	_face_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_face_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_face_scroll)
	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 14)
	_hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_face_scroll.add_child(_hero_row)
	_build_heroes()


func _build_heroes() -> void:
	for child in _hero_row.get_children():
		child.queue_free()
	var chosen := _who()
	for character_id in GameData.characters.get("characters", {}):
		# Owned, not merely listed: the four bought faces appear here the
		# moment they are paid for and vanish again if the purchase is undone.
		if not Shop.have_character(character_id):
			continue
		var here: bool = character_id == chosen
		var box: float = _faces_h - 6.0
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(box, box)
		b.clip_contents = true
		b.pressed.connect(func(): _pick_hero(character_id))
		_hero_row.add_child(b)
		var pad := Node2D.new()
		b.add_child(pad)
		Shapes.fill(pad, Shapes.circle_points(Vector2(box * 0.5, box * 0.5),
			box * 0.46, 26), Color(0.97, 0.99, 1.0), 0.0)
		var face := SkinnedCharacter.new()
		face.show_pal = false
		var skin: CharacterSkin = GameData.skin_for(character_id)
		if skin != null:
			face.skin = skin
		# Standing far below the crop so only the head shows in the window.
		# The head sits at about 0.78 of the figure's height above the feet,
		# so this puts it in the middle of the circle rather than above it.
		face.position = Vector2(box * 0.5, box * 1.72)
		b.add_child(face)
		face.set_height(box * 1.62)
		# clip_contents crops to a SQUARE, so a ring on top turns it round --
		# the same trick the duel health bar uses for its monster portrait.
		var ring := Node2D.new()
		b.add_child(ring)
		var band := PackedVector2Array()
		var outer := Shapes.circle_points(Vector2(box * 0.5, box * 0.5), box * 0.80, 26)
		var inner := Shapes.circle_points(Vector2(box * 0.5, box * 0.5), box * 0.44, 26)
		band.append_array(outer)
		band.append(outer[0])
		for k in range(inner.size() - 1, -1, -1):
			band.append(inner[k])
		band.append(inner[inner.size() - 1])
		Shapes.fill(ring, band, Color(1, 1, 1, 0.95), 0.0)
		if here:
			# The gold goes round the WINDOW, not round the tile. A gold tile
			# on a white tile is two white squares from a metre away.
			var gold := PackedVector2Array()
			var g_out := Shapes.circle_points(Vector2(box * 0.5, box * 0.5),
				box * 0.50, 26)
			gold.append_array(g_out)
			gold.append(g_out[0])
			for k in range(inner.size() - 1, -1, -1):
				gold.append(inner[k])
			gold.append(inner[inner.size() - 1])
			Shapes.fill(ring, gold, Color(1.0, 0.80, 0.28), 0.0)


func _build_tools(view: Vector2) -> void:
	_preset_row = VBoxContainer.new()
	_preset_row.add_theme_constant_override("separation", 10)
	_preset_row.position = Vector2(view.x - 212.0, _stage_top + 6.0)
	_preset_row.size = Vector2(196, _stage_h - 16.0)
	add_child(_preset_row)
	_build_preset_row()


func _build_preset_row() -> void:
	for child in _preset_row.get_children():
		child.queue_free()
	var head := Label.new()
	head.text = I18n.t("house.presets")
	head.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	UiKit.on_art(head, 5)
	head.add_theme_color_override("font_color", Color.WHITE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.custom_minimum_size = Vector2(196, 28)
	_preset_row.add_child(head)

	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	_preset_row.add_child(slots)
	for i in range(Presets.SAVED):
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(60, 60)
		var index := i
		b.pressed.connect(func(): _preset_tapped(index))
		slots.add_child(b)
		var pad := Node2D.new()
		b.add_child(pad)
		var full: bool = Presets.has_look(i)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, Vector2(60, 60), 16.0),
			Color(1, 1, 1, 0.94) if full else Color(1, 1, 1, 0.66), 0.0)
		var mark := Label.new()
		mark.text = str(i + 1) if full else "+"
		mark.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
		mark.add_theme_color_override("font_color",
			Color(0.22, 0.34, 0.52) if full else Color(0.56, 0.64, 0.76))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.position = Vector2(0, 12)
		mark.size = Vector2(60, 38)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)

	# One protagonist on this side of the room. Purple, blue and green in a
	# stack was three buttons shouting over each other -- and two of them are
	# housekeeping. 魔法搭配 keeps its colour; undo and restore go quiet.
	for spec in [
			["house.magic", Palette.PURPLE, Callable(self, "_magic"), "spark", true],
			["house.undo", Palette.SLATE, Callable(self, "_undo"), "retry", false],
			["house.restore", Palette.SLATE, Callable(self, "_restore"), "home", false]]:
		var b := _side_button(I18n.t(str(spec[0])), spec[1], str(spec[3]),
			bool(spec[4]))
		b.pressed.connect(spec[2])
		_preset_row.add_child(b)


## A wide button with the picture on the left and the word beside it.
##
## Three coloured rectangles of Chinese is a menu a six-year-old navigates by
## memorising positions. A sparkle, a turn-back arrow and a little house are
## three things he can tell apart the first time he sees them, and the words
## stay for the day he starts reading them.
func _side_button(text: String, colour: Color, icon_name: String,
		loud: bool = true) -> Button:
	var box := Vector2(196, 68)
	var b := UiKit.big_button(text, colour)
	b.custom_minimum_size = box
	b.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	if not loud:
		# The quiet version: a warm white chip with ink words, same raised
		# physics, no colour. Housekeeping should be findable, not loud.
		for state in ["normal", "hover", "pressed"]:
			var quiet: StyleBox = b.get_theme_stylebox(state)
			if quiet is StyleBoxFlat:
				(quiet as StyleBoxFlat).bg_color = Color(1.0, 0.99, 0.96, 0.92)
				(quiet as StyleBoxFlat).border_color = Color(0.72, 0.74, 0.78)
		b.add_theme_color_override("font_color", Palette.INK)
		b.add_theme_color_override("font_hover_color", Palette.INK)
		b.add_theme_color_override("font_pressed_color", Palette.INK)
	var icon: Control = UiKit.picture(icon_name, 40.0)
	if icon == null:
		return b
	icon.position = Vector2(12, (box.y - 40.0) * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	# Push the label clear of the picture rather than centring it under one.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = b.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).content_margin_left = 62.0
	return b


func _build_shelf(view: Vector2) -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(160, view.y - _shelf_h + 4.0)
	_scroll.size = Vector2(view.x - 184.0, _shelf_h - 10.0)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_shelf = HBoxContainer.new()
	_shelf.add_theme_constant_override("separation", 16)
	_scroll.add_child(_shelf)

	_tray = Control.new()
	_tray.position = Vector2(160, view.y - _shelf_h + 4.0)
	_tray.size = Vector2(view.x - 184.0, _shelf_h - 10.0)
	_tray.visible = false
	add_child(_tray)


# --- the open drawer ------------------------------------------------------

func _open(category: String) -> void:
	if not _tabs.has(category):
		return
	_stop_trying()
	for slot in _tabs:
		_paint_tab(slot, slot == category)
	_category = category
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	_fill_shelf()


func _fill_shelf() -> void:
	for child in _shelf.get_children():
		child.queue_free()
	_cards.clear()
	var who := _who()
	# 形象 has to stay reachable while playing as the puppy, or picking Bluey
	# would be a one-way door.
	if _wears_nothing(who) and _category != "pal" and _category != "who":
		_fill_puppy_note()
		return
	if _category == "set":
		_fill_sets()
		return
	# Owned first, then buyable, then locked -- so what he can actually use is
	# the first thing under his thumb and the shelf is not a wall of padlocks.
	var rows: Array = Shop.in_category(_category)
	rows.sort_custom(func(a, b):
		return _rank(a, who) < _rank(b, who))
	for entry in rows:
		var card := Card.new()
		_shelf.add_child(card)
		card.build(entry, who)
		card.tapped.connect(_card_tapped)
		card.held.connect(_card_held)
		card.dragged.connect(_card_dragged)
		_cards[str(entry.get("id", ""))] = card


## Bluey and the photo skins are drawn by a different renderer and are never
## dressed -- a hat bought while playing as the puppy would simply not appear.
## Saying so, once, with somewhere to go next, is kinder than a shelf of grey
## cards he can buy and then not see.
func _wears_nothing(character_id: String) -> bool:
	var skin: CharacterSkin = GameData.skin_for(character_id)
	return skin != null and (skin.renderer == "puppy" or not skin.is_drawn())


func _fill_puppy_note() -> void:
	var note := Button.new()
	note.flat = true
	note.focus_mode = Control.FOCUS_NONE
	note.custom_minimum_size = Vector2(620, _shelf_h - 14.0)
	note.pressed.connect(func(): _open("pal"))
	_shelf.add_child(note)
	var pad := Node2D.new()
	note.add_child(pad)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2),
		Vector2(616, _shelf_h - 22.0), 26.0), Color(1, 1, 1, 0.97), 0.0)
	var line := UiKit.title(I18n.t("house.dog_no_clothes"), UiKit.TYPE_TITLE)
	line.add_theme_color_override("font_color", Color(0.18, 0.26, 0.40))
	line.position = Vector2(0, 22)
	line.size = Vector2(616, 44)
	note.add_child(line)
	var more := UiKit.title(I18n.t("house.dog_pals"), UiKit.TYPE_BODY)
	more.add_theme_color_override("font_color", Color(0.36, 0.52, 0.74))
	more.position = Vector2(0, 70)
	more.size = Vector2(616, 36)
	note.add_child(more)
	var go := UiKit.big_button(I18n.t("cat.pal"), Palette.PURPLE)
	go.custom_minimum_size = Vector2(200, 50)
	go.position = Vector2(208, 108)
	go.pressed.connect(func(): _open("pal"))
	note.add_child(go)


func _rank(entry: Dictionary, who: String) -> int:
	match Shop.state_of(entry, who):
		Shop.State.WEARING: return 0
		Shop.State.OWNED: return 1
		Shop.State.BUYABLE: return 2
		Shop.State.LOCKED: return 3
		_: return 4


func _fill_sets() -> void:
	# Today's suggestion goes FIRST, with a small star on it.
	#
	# It is a suggestion and nothing more: no countdown, no "only today", and
	# ignoring it forever costs him nothing. Presets.today() picks the themed
	# outfit he is closest to finishing, rotated a little day by day so it is
	# not the same one for a month.
	var suggested := Presets.today(_day_number())
	var order: Array = []
	for spec in Presets.sets():
		if str(spec.get("id", "")) == suggested:
			order.push_front(spec)
		else:
			order.append(spec)
	for spec in order:
		var set_id := str(spec.get("id", ""))
		var progress := Presets.set_progress(set_id)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Card.BOX
		b.pressed.connect(func(): _wear_set(set_id))
		_shelf.add_child(b)
		var pad := Node2D.new()
		b.add_child(pad)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(4, 8), Card.BOX - Vector2(8, 8), 26.0),
			Color(0.20, 0.30, 0.45, 0.18), 0.0)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2), Card.BOX - Vector2(8, 10), 26.0),
			Color(1, 1, 1, 0.98), 0.0)
		# The four pieces, small, in a row: the card IS the outfit.
		var pieces: Array = spec.get("pieces", [])
		for i in range(mini(pieces.size(), 4)):
			var item: Dictionary = Shop.item(str(pieces[i]))
			var tex: Texture2D = preload("res://scripts/reward/monster_art.gd")\
				._load(str(item.get("art", "")))
			if tex == null:
				continue
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# The four pieces live in the top 100 px and NOTHING else does.
			# The first cut used 64 px rows starting at 12, so the bottom row
			# ran to 138 and painted boots straight over the set's name.
			pic.position = Vector2(6.0 + float(i % 2) * 86.0,
				26.0 + float(i / 2) * 36.0)
			pic.size = Vector2(82, 34)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not Shop.owns(str(pieces[i])):
				pic.material = Card._shadow_material()
			b.add_child(pic)
		var label := Label.new()
		label.text = I18n.t(_set_key(set_id))
		label.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
		label.add_theme_color_override("font_color", Color(0.15, 0.22, 0.34))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(4, Card.ART_H)
		label.size = Vector2(Card.BOX.x - 8, 28)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(label)
		if set_id == suggested:
			Shapes.lit(pad, Shapes.star_points(
				Vector2(Card.BOX.x - 24.0, 14.0), 12.0, 0.44, 5),
				Color(1.0, 0.86, 0.34), 0.9)
			var today := Label.new()
			today.text = I18n.t("house.today")
			today.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
			today.add_theme_color_override("font_color", Color(0.86, 0.60, 0.10))
			today.position = Vector2(9, 3)
			today.size = Vector2(120, 22)
			today.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(today)

		var count := Label.new()
		count.text = "%d / %d" % [progress[0], progress[1]]
		count.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
		count.add_theme_color_override("font_color",
			Color(0.24, 0.60, 0.36) if progress[0] == progress[1]
			else Color(0.46, 0.54, 0.68))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Two lines of 22 px text after the 100 px of pictures: 100 + 30 + 30 =
		# 160, inside the 168 px card. The first cut put this line at 144 with
		# a box of 32 -- so every "5 / 5" was printed on the grass below.
		count.position = Vector2(4, Card.ART_H + 32.0)
		count.size = Vector2(Card.BOX.x - 8, 30)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(count)


# --- trying things on -----------------------------------------------------

func _card_tapped(item_id: String) -> void:
	var entry := Shop.item(item_id)
	if entry.is_empty():
		return
	var who := _who()
	if Shop.is_who(entry):
		_who_tapped(entry)
		return
	match Shop.state_of(entry, who):
		Shop.State.INCOMPATIBLE:
			_nudge(item_id)
			return
		Shop.State.LOCKED:
			_nudge(item_id)
			return
		Shop.State.WEARING:
			# Tapping what he has on takes it off. The quickest way to find
			# out what a thing does is to be able to undo it in one tap.
			_history.remember(Shop.worn(who))
			Shop.unequip(str(entry.get("slot", "")), who)
			_after_change()
			AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
			return
		_:
			pass
	Shop.mark_seen(item_id)
	_try_on(item_id)


## A face, tapped.
##
## One he already has: he becomes him on the spot. Switching who you are is the
## cheapest, most-repeated thing in this drawer and it must not cost a
## confirmation -- it costs no stars and it is undone by tapping the one before.
##
## One he has not got: the character walks onto the stage as a full-size
## try-on, free, and the strip underneath offers the three numbers. Same flow
## as a hat, because it is the same rule -- nothing is bought by one tap.
func _who_tapped(entry: Dictionary) -> void:
	var cid := Shop.who_id(entry)
	var item_id := str(entry.get("id", ""))
	if cid == _who():
		_stage.call("play_random_action")
		return
	if Shop.have_character(cid):
		Shop.mark_seen(item_id)
		_pick_hero(cid)
		return
	Shop.mark_seen(item_id)
	_trying = item_id
	_stage.call("build", cid)
	if _stage.get("hero") != null and is_instance_valid(_stage.get("hero")):
		_stage.get("hero").entrance(300.0, 0.05)
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	_show_tray(item_id)


## Free. Always. Writes nothing.
func _try_on(item_id: String) -> void:
	var entry := Shop.item(item_id)
	_trying = item_id
	_stage.call("try_on", {str(entry.get("slot", "")): item_id})
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	_stage.call("show_off")
	_show_tray(item_id)


func _stop_trying() -> void:
	if _trying == "":
		return
	var was := _trying
	_trying = ""
	if _stage != null and is_instance_valid(_stage):
		# A face was tried on by REPLACING the figure, so putting it back means
		# rebuilding the real one -- clearing an outfit preview would leave the
		# stranger standing there.
		if Shop.is_who(Shop.item(was)):
			_stage.call("build", _who())
		else:
			_stage.call("stop_trying")
	if _tray != null and is_instance_valid(_tray):
		_tray.visible = false
		_scroll.visible = true


## "喜欢吗？" -- and the only ways forward are wear, buy, next, or put back.
func _show_tray(item_id: String) -> void:
	for child in _tray.get_children():
		child.queue_free()
	var entry := Shop.item(item_id)
	var owned := Shop.owns(item_id)
	_tray.visible = true
	_scroll.visible = false

	var pad := Node2D.new()
	_tray.add_child(pad)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, _tray.size, 26.0),
		Color(1, 1, 1, 0.94), 0.0)
	var ask := UiKit.title(I18n.t("house.like"), UiKit.TYPE_TITLE)
	ask.add_theme_color_override("font_color", Color(0.18, 0.26, 0.40))
	ask.position = Vector2(0, 16)
	ask.size = Vector2(_tray.size.x, 44)
	_tray.add_child(ask)

	var options: Array = []
	if owned:
		options.append([I18n.t("house.wear"), Palette.GREEN,
			func(): _wear_tried(item_id), "check"])
	else:
		options.append(["", Palette.GREEN, func(): _buying.confirm(item_id), ""])
	options.append([I18n.t("house.another"), Palette.BLUE,
		Callable(self, "_stop_trying"), "next"])
	options.append([I18n.t("house.revert"), Palette.ORANGE,
		Callable(self, "_stop_trying"), "retry"])

	var wide: float = 240.0
	var span: float = wide * float(options.size()) + 24.0 * float(options.size() - 1)
	for i in range(options.size()):
		var spec = options[i]
		var b: Button
		if str(spec[0]) == "":
			b = _buying._star_button(str(int(entry.get("price", 0))),
				spec[1], Vector2(wide, 92))
		else:
			b = _tray_button(str(spec[0]), spec[1], str(spec[3]), Vector2(wide, 92))
		b.position = Vector2(_tray.size.x * 0.5 - span * 0.5
			+ float(i) * (wide + 24.0), 76.0)
		b.pressed.connect(spec[2])
		_tray.add_child(b)


## The same picture-then-word shape as the buttons on the right, at try-on
## size. The star-price button next to it is already a picture and a number,
## which is the one "price" a child who cannot read can still compare.
func _tray_button(text: String, colour: Color, icon_name: String,
		box: Vector2) -> Button:
	var b := UiKit.big_button(text, colour)
	b.custom_minimum_size = box
	b.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
	var icon: Control = UiKit.picture(icon_name, 46.0)
	if icon == null:
		return b
	icon.position = Vector2(20, (box.y - 46.0) * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = b.get_theme_stylebox(state)
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).content_margin_left = 76.0
	return b


func _wear_tried(item_id: String) -> void:
	var who := _who()
	_history.remember(Shop.worn(who))
	Shop.equip(item_id, who)
	_stop_trying()
	_after_change()
	AudioManager.play_sfx("res://assets/audio/correct.ogg")


## Dragged up out of the shelf and onto the hero. Same result as a tap: it
## goes on, free, and the "do you like it?" strip appears. A drag that lands
## nowhere in particular still counts -- asking a six-year-old to hit a target
## with a garment is asking him to fail at the fun part.
func _card_dragged(item_id: String, _at: Vector2) -> void:
	_card_tapped(item_id)


func _card_held(item_id: String) -> void:
	# Press and hold to look closer. Nothing is bought, nothing is worn.
	var entry := Shop.item(item_id)
	if entry.is_empty():
		return
	_buying._panel(Vector2(520, 520))
	var card: Control = _buying._layer.get_child(1)
	_buying._thumb(card, Vector2(260, 60), 300.0, entry)
	var label := UiKit.title(I18n.t(str(entry.get("name_key", ""))), UiKit.TYPE_TITLE)
	label.add_theme_color_override("font_color", Color(0.15, 0.22, 0.34))
	label.position = Vector2(0, 388)
	label.size = Vector2(520, 52)
	card.add_child(label)
	var close := UiKit.big_button(I18n.t("common.back"), Palette.BLUE)
	close.custom_minimum_size = Vector2(200, 78)
	close.position = Vector2(160, 424)
	close.pressed.connect(_buying.close)
	card.add_child(close)


func _nudge(item_id: String) -> void:
	if _cards.has(item_id):
		Juice.nudge(_cards[item_id])
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")


# --- the toys -------------------------------------------------------------

func _magic() -> void:
	var who := _who()
	_stop_trying()
	_history.remember(Shop.worn(who))
	var mix := Presets.magic_mix(who)
	SaveManager.wear_whole(who, mix)
	AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	_after_change()
	_stage.call("show_off")


func _undo() -> void:
	_stop_trying()
	var back := _history.back()
	if back.is_empty():
		Juice.nudge(_preset_row)
		return
	SaveManager.wear_whole(_who(), back)
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
	_after_change()


func _restore() -> void:
	var who := _who()
	_stop_trying()
	_history.remember(Shop.worn(who))
	SaveManager.wear_whole(who, SaveManager.empty_outfit())
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	_after_change()


func _preset_tapped(index: int) -> void:
	var who := _who()
	_stop_trying()
	if Presets.has_look(index):
		_history.remember(Shop.worn(who))
		SaveManager.wear_whole(who, Presets.load_look(index, who))
		AudioManager.play_sfx("res://assets/audio/power_on.ogg")
		_after_change()
		_stage.call("show_off")
	else:
		Presets.save_look(index, Shop.worn(who))
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		_build_preset_row()


func _wear_set(set_id: String) -> void:
	var who := _who()
	_stop_trying()
	var pieces := Presets.pieces_of(set_id)
	if pieces.is_empty():
		Juice.nudge(_shelf)
		AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
		return
	_history.remember(Shop.worn(who))
	var outfit := Shop.worn(who)
	for slot in pieces:
		outfit[slot] = pieces[slot]
	SaveManager.wear_whole(who, outfit)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	_after_change()
	_stage.call("show_off")


# --- heroes ---------------------------------------------------------------

## Which day it is, for rotating the suggestion. Days since the save was
## started rather than a wall clock: a child who plays every evening should see
## it move on, and a child whose tablet clock is wrong should not see it jump.
func _day_number() -> int:
	return int(SaveManager.get_setting("levels_total", 0)) / 3 \
		+ int(Shop.owned_count())


func _who() -> String:
	return str(SaveManager.get_profile().get("character_id", "tiga"))


func _pick_hero(character_id: String) -> void:
	if character_id == _who():
		return
	_stop_trying()
	_history.clear()
	# become() refuses a face he has not got, so a stale save or a card built
	# from old data cannot strand the game on somebody who is not there.
	if not Shop.become(character_id):
		return
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	_stage.call("build", character_id)
	if _stage.get("hero") != null and is_instance_valid(_stage.get("hero")):
		_stage.get("hero").entrance(300.0, 0.05)
	_build_heroes()
	_fill_shelf()


# --- housekeeping ---------------------------------------------------------

## Buying a face means becoming him -- he has just watched this character walk
## on and paid for it, and being handed back the old one would read as the
## purchase not having worked. Undo (放回去) puts the stars back AND puts the
## old character back, because Shop.undo removes the ownership that
## have_character() checks and _pick_hero re-reads it.
func _after_bought(item_id: String) -> void:
	var entry := Shop.item(item_id)
	if not Shop.is_who(entry):
		return
	_trying = ""
	_pick_hero(Shop.who_id(entry))


func _after_change() -> void:
	_show_coins()
	# A refund of a face leaves the game standing as somebody he no longer
	# owns. Put him back on a character he has.
	if not Shop.have_character(_who()):
		_pick_hero(str(GameData.characters.get("default", "tiga")))
		return
	if _stage != null and is_instance_valid(_stage):
		_stage.call("refresh")
	_fill_shelf()
	_build_preset_row()


func _show_coins() -> void:
	if _coin_label != null and is_instance_valid(_coin_label):
		_coin_label.text = str(Coins.balance())


## The first visit hands him a cape, free, and shows him what a tap does. Once.
func _first_visit_gift() -> void:
	if not Shop.free_gift_pending():
		return
	var item_id := Shop.free_gift_id()
	if item_id == "":
		return
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(self):
		return
	Shop.take_free_gift()
	Shop.equip(item_id, _who())
	_after_change()
	AudioManager.say("house_first_gift")
	AudioManager.play_sfx("res://assets/audio/chest_open.ogg")
	if _stage != null and is_instance_valid(_stage):
		_stage.call("show_off")
	var line := UiKit.title_on_art(I18n.t("house.gift"), UiKit.TYPE_TITLE)
	line.position = Vector2(get_viewport_rect().size.x * 0.5 - 300.0, 112)
	line.size = Vector2(600, 52)
	add_child(line)
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(line):
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.6)
		t.tween_callback(line.queue_free)
