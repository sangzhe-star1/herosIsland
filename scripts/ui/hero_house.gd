extends Control
## Hero House: where the child chooses who they play as.
##
## One card per character in data/characters.json, each showing the hero
## standing in it -- the real SkinnedCharacter node, so what the child picks is
## exactly what walks into the levels. Tapping a card selects it immediately;
## there is no confirm step, because trying every hero in turn IS the fun, and
## nothing here can be broken by tapping.

var _cards: Dictionary = {}      # character_id -> PanelContainer
var _badges: Dictionary = {}     # character_id -> the "this one is chosen" star
var _previews: Dictionary = {}   # character_id -> SkinnedCharacter, for re-dressing
var _outfit_tiles: Dictionary = {}  # outfit_id -> its rack Button
var _slot_tabs: Dictionary = {}     # slot -> its tab Button
var _rack: HBoxContainer            # the tiles for the open slot
var _set_banner: Label              # "Full set: Cowboy!" when one is complete
var _slot := "hat"                  # which drawer of the wardrobe is open
var _coin_label: Label


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.world_background(self, "rescue_forest", "hero_house", 0.30)

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 16)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title_on_art(I18n.t("home.house"), 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	root.add_child(header)

	var hint := UiKit.title_on_art(I18n.t("house.choose"), 32)
	root.add_child(hint)

	# The wardrobe sits between the question and the heroes, so "who am I
	# today" and "what am I wearing" read as one decision.
	_build_wardrobe(root)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(row)
	root.add_child(center)

	# Card size adapts to the roster: three heroes got 300px cards, five get
	# ~220px ones, and every card stays at or above the house's 220x120 touch
	# minimum. UiKit.card() pads 20px on every side, so the OUTER size is what
	# has to fit the row and the drawing space inside is 40 less each way --
	# the first cut of this maths sized the INSIDE and five cards marched off
	# the right edge of the screen.
	var characters: Dictionary = GameData.characters.get("characters", {})
	var ids: Array = []
	for character_id in characters.keys():
		if bool(characters[character_id].get("unlocked", false)):
			ids.append(str(character_id))
	# One row, always: six heroes means six slimmer cards, not a second
	# storey. (The first two-row attempt sized its cards off the wrong clamp
	# and pushed row two clean off the bottom of the screen -- and a shelf
	# you can sweep with one finger beats a grid at six anyway.) Every card
	# stays a huge touch target; the 220px "minimum" is an area rule and a
	# 183x285 card clears it three times over.
	var n: int = maxi(ids.size(), 1)
	var sep: float = 20.0 if n >= 6 else (24.0 if n >= 5 else 32.0)
	row.add_theme_constant_override("separation", int(sep))
	var outer_w: float = clampf(
		(1200.0 - sep * float(n - 1)) / float(n), 176.0, 340.0)
	var inner_w: float = outer_w - 40.0
	var inner_box := Vector2(inner_w, inner_w * 4.0 / 3.0)

	for i in range(ids.size()):
		var character_id: String = ids[i]
		var card := _build_card(character_id, characters[character_id], inner_box)
		card.pivot_offset = (inner_box + Vector2(40, 40)) / 2.0
		_cards[character_id] = card
		row.add_child(card)

	_refresh_selection()
	_build_sticker_wall()


## The wardrobe rack: every outfit piece in the game on one shelf, worn with
## one tap. Not owned yet? The tile wears its coin price; tapping it BUYS it
## (and puts it straight on, because that is why anyone buys a hat). Coins
## finally have a job beyond stickers. One piece per slot: the crown knocks
## the party hat back onto its hook, and tapping what you wear takes it off.
func _build_wardrobe(root: Control) -> void:
	# Drawer tabs, then the drawer. Six pieces fitted on one shelf; twelve do
	# not, and a wardrobe that scrolls sideways forever is how a child stops
	# finding the hat they wanted. Tabs also name the SLOTS, which teaches
	# the rule -- one hat, one face, one back, one colour -- without a word
	# about rules.
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	root.add_child(tabs)

	for spec in [
		{"slot": "hat", "key": "house.slot_hat", "icon": "crown"},
		{"slot": "face", "key": "house.slot_face", "icon": "sunglasses"},
		{"slot": "suit", "key": "house.slot_suit", "icon": "dress"},
		{"slot": "back", "key": "house.slot_back", "icon": "cape_red"},
		{"slot": "colour", "key": "house.slot_colour", "icon": "star"},
	]:
		tabs.add_child(_build_slot_tab(str(spec["slot"]), str(spec["key"]),
			str(spec["icon"])))

	# The purse rides with the tabs: "can I afford the wings yet?" answers
	# itself without leaving the shelf.
	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.96, 0.92), 18))
	var purse_row := HBoxContainer.new()
	purse_row.add_theme_constant_override("separation", 6)
	var coin: Control = UiKit.picture("coin", 32)
	if coin != null:
		purse_row.add_child(coin)
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purse_row.add_child(_coin_label)
	purse.add_child(purse_row)
	tabs.add_child(purse)

	_rack = HBoxContainer.new()
	_rack.alignment = BoxContainer.ALIGNMENT_CENTER
	_rack.add_theme_constant_override("separation", 12)
	root.add_child(_rack)

	# Complete sets: a named look assembled from pieces bought separately.
	# The reason every dress-up game has them is that a child who has three
	# unrelated pieces has an outfit, and a child who has a SET has a
	# costume -- and a costume has a name they can say out loud.
	_set_banner = UiKit.title_on_art("", 28)
	_set_banner.visible = false
	root.add_child(_set_banner)

	_open_slot(_slot)


func _build_slot_tab(slot: String, name_key: String, icon_name: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(126, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(63, 29)
	var row := HBoxContainer.new()
	row.position = Vector2(11, 11)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = UiKit.picture(icon_name, 32)
	if icon != null:
		row.add_child(icon)
	var label := Label.new()
	label.text = I18n.t(name_key)
	label.add_theme_font_size_override("font_size", 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	b.add_child(row)
	b.pressed.connect(func(): _open_slot(slot))
	_slot_tabs[slot] = b
	return b


## Open a drawer: rebuild the tile row for that slot, and light its tab.
func _open_slot(slot: String) -> void:
	_slot = slot
	for tab_slot in _slot_tabs:
		var tab: Button = _slot_tabs[tab_slot]
		var chosen: bool = tab_slot == slot
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.99, 0.96, 0.96) if chosen \
			else Color(0.80, 0.84, 0.90, 0.80)
		style.set_corner_radius_all(20)
		style.border_width_bottom = 6 if chosen else 3
		style.border_color = Palette.BLUE if chosen else Color(0.62, 0.66, 0.76, 0.7)
		for state in ["normal", "hover", "pressed", "disabled"]:
			tab.add_theme_stylebox_override(state, style)
	if _rack == null or not is_instance_valid(_rack):
		return
	for child in _rack.get_children():
		child.queue_free()
	_outfit_tiles.clear()
	for outfit in GameData.rewards.get("outfits", []):
		if str(outfit.get("slot", "")) != slot:
			continue
		_rack.add_child(_build_outfit_tile(outfit))
	_refresh_wardrobe()


func _build_outfit_tile(outfit: Dictionary) -> Button:
	var outfit_id: String = str(outfit.get("id", ""))
	var b := Button.new()
	b.custom_minimum_size = Vector2(94, 94)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(47, 47)
	var icon: Control = UiKit.picture(str(outfit.get("icon", outfit_id)), 62)
	if icon != null:
		icon.position = Vector2(16, 8)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
	var price := Label.new()
	price.name = "Price"
	price.add_theme_font_size_override("font_size", 19)
	price.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(price, 5)
	price.position = Vector2(6, 68)
	price.size = Vector2(82, 22)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(price)
	b.pressed.connect(_on_outfit_tap.bind(outfit))
	_outfit_tiles[outfit_id] = b
	return b


func _on_outfit_tap(outfit: Dictionary) -> void:
	var outfit_id: String = str(outfit.get("id", ""))
	var slot: String = str(outfit.get("slot", "hat"))
	var tile: Button = _outfit_tiles.get(outfit_id)

	if not SaveManager.has_outfit(outfit_id):
		# Buying: coins in, piece owned, and straight onto the hero -- a
		# bought hat that stays on the shelf is a scolding, not a toy.
		if not SaveManager.spend_coins(int(outfit.get("cost_coins", 0))):
			if tile != null:
				Juice.nudge(tile)
			if _coin_label != null:
				Juice.pop(_coin_label, 0.3)
			return
		SaveManager.add_outfit(outfit_id)
		SaveManager.wear_outfit(slot, outfit_id)
		if tile != null:
			Juice.pop(tile, 0.14)
			Juice.burst(self, tile.get_global_rect().get_center(), 14)
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
	else:
		var wearing: bool = str(SaveManager.get_outfit().get(slot, "")) == outfit_id
		SaveManager.wear_outfit(slot, "" if wearing else outfit_id)
		if tile != null:
			Juice.pop(tile, 0.10)
		AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (randi() % 5 + 1))
	_refresh_wardrobe()


## Tiles show their state, the purse shows the coins, and every hero on the
## shelf changes clothes at once -- the point of the whole rack.
func _refresh_wardrobe() -> void:
	if _coin_label != null:
		# int() first: JSON numbers arrive as floats and "45.0 coins" is not
		# a number any six-year-old has ever been paid.
		_coin_label.text = str(int(SaveManager.data["rewards"]["coins"]))
	var worn: Dictionary = SaveManager.get_outfit()
	for outfit in GameData.rewards.get("outfits", []):
		var outfit_id: String = str(outfit.get("id", ""))
		if not _outfit_tiles.has(outfit_id):
			continue                       # a piece in a drawer that is shut
		var tile: Button = _outfit_tiles[outfit_id]
		var owned: bool = SaveManager.has_outfit(outfit_id)
		var wearing: bool = str(worn.get(str(outfit.get("slot", "")), "")) == outfit_id
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.99, 0.96, 0.94) if owned else Color(0.85, 0.87, 0.92, 0.85)
		style.set_corner_radius_all(22)
		style.border_width_bottom = 6
		style.border_width_top = 4
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_color = Color(0.36, 0.78, 0.44) if wearing else Color(0.62, 0.66, 0.76, 0.6)
		for state in ["normal", "hover", "pressed", "disabled"]:
			tile.add_theme_stylebox_override(state, style)
		if str(outfit.get("slot", "")) == "colour" \
				and HeroArt.PALETTES.has(outfit_id):
			# Paint the tile in the scheme it sells. A colour you cannot see
			# before buying is a colour nobody buys.
			var scheme: Dictionary = HeroArt.PALETTES[outfit_id]
			style.bg_color = scheme["body"] if owned else (scheme["body"] as Color)\
				.lerp(Color(0.80, 0.82, 0.88), 0.55)
			if not wearing:
				style.border_color = scheme["accent"]
		var price: Label = tile.get_node_or_null("Price")
		if price != null:
			price.text = "" if owned else ("%d" % int(outfit.get("cost_coins", 0)))
	for preview in _previews.values():
		if is_instance_valid(preview):
			preview.refresh_outfit()
	_refresh_set_banner()


## Is every piece of a set being worn right now? Say so, once, in its name.
func _refresh_set_banner() -> void:
	if _set_banner == null or not is_instance_valid(_set_banner):
		return
	var worn: Array = SaveManager.get_outfit().values()
	for set_spec in GameData.rewards.get("outfit_sets", []):
		var complete := true
		for piece in set_spec.get("pieces", []):
			if not str(piece) in worn:
				complete = false
				break
		if complete:
			var was_hidden: bool = not _set_banner.visible
			_set_banner.text = I18n.t("house.set_on") % I18n.t(str(set_spec["name_key"]))
			_set_banner.visible = true
			if was_hidden:
				Juice.pop(_set_banner, 0.35)
				Juice.burst(self, Vector2(640, 300), 22)
				AudioManager.play_sfx("res://assets/audio/star.ogg")
			return
	_set_banner.visible = false


## The stickers bought in My Rewards live here, stuck along the bottom of
## the Hero House like a six-year-old's bedroom door. Each one is a toy:
## tap it and it bounces, sparkles and sings one of the island's own notes.
## Purely for joy -- no score, no goal, no way to be wrong.
func _build_sticker_wall() -> void:
	var owned: Array = SaveManager.data["rewards"]["stickers"]
	if owned.is_empty():
		return

	var wall := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.26, 0.55)
	style.set_corner_radius_all(30)
	style.set_content_margin_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	wall.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	wall.add_child(row)

	for sticker_id in owned:
		var tile := Button.new()
		tile.focus_mode = Control.FOCUS_NONE
		tile.custom_minimum_size = Vector2(64, 64)
		tile.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		tile.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		tile.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var icon: Control = UiKit.picture(str(sticker_id), 56)
		if icon != null:
			icon.position = Vector2(4, 4)
			tile.add_child(icon)
		tile.pressed.connect(func():
			Juice.pop(tile, 0.35)
			Juice.burst(self, tile.get_global_rect().get_center(), 10)
			AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (randi() % 5 + 1))
		)
		tile.resized.connect(func(): tile.pivot_offset = tile.size / 2.0)
		row.add_child(tile)

	add_child(wall)
	await get_tree().process_frame
	if is_instance_valid(wall):
		wall.position = Vector2(640.0 - wall.size.x / 2.0, 720.0 - wall.size.y - 18.0)


func _build_card(character_id: String, entry: Dictionary, box: Vector2) -> PanelContainer:
	var card := UiKit.card()
	card.custom_minimum_size = box

	# PanelContainer lays out its direct children itself and tramples anchors
	# and positions, so everything lives inside one plain Control -- the one
	# node type guaranteed to leave its children exactly where they are put.
	# MOUSE_FILTER_IGNORE, and the fix for "tapping a hero does nothing": a
	# plain Control defaults to STOP, so this inner sheet was silently eating
	# every tap on the middle of the card -- only the card's thin outer
	# margin ever heard one. That is exactly the "not responsive" a child
	# reports, because a child taps the hero, dead centre.
	var inner := Control.new()
	inner.custom_minimum_size = box
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	# Every hero is presented the same way: the live drawn figure, standing on
	# a card, breathing. Two of the three used to be a photographic spotlight
	# card from an asset bundle and the third a drawn figure, which made the
	# choice screen look like a shop selling two different products.
	var preview := SkinnedCharacter.new()
	var preview_skin: CharacterSkin = GameData.skin_for(character_id)
	if preview_skin != null:
		preview.skin = preview_skin
	preview.position = Vector2(box.x * 0.5, box.y * 0.75)
	inner.add_child(preview)
	preview.set_height(box.x * 0.83)
	_previews[character_id] = preview

	var name_label := UiKit.title(I18n.t(str(entry.get("name_key", ""))),
		34 if box.x >= 260.0 else (28 if box.x >= 175.0 else 24))
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -58
	name_label.offset_bottom = -12
	inner.add_child(name_label)

	# "This is who you are right now": a gold star pinned to the chosen card.
	# A badge rather than a border, because at six a THING on the card reads
	# better than a property of the card.
	var badge_size: int = 72 if box.x >= 260.0 else 56
	var badge: Control = UiKit.star(true, badge_size)
	badge.position = Vector2(box.x - float(badge_size) - 4.0, 4.0)
	_badges[character_id] = badge
	inner.add_child(badge)

	# The whole card is one big button, and it answers ON PRESS -- button_down,
	# not the release -- because at six, "the button is broken" usually means
	# "it answered a beat after my finger did". An invisible Button on top of
	# everything gets the platform's own touch handling (drag tolerance,
	# multi-touch) for free, which hand-rolled gui_input never quite matched.
	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "disabled"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit.button_down.connect(func(): _select(character_id))
	inner.add_child(hit)
	return card


func _select(character_id: String) -> void:
	SaveManager.set_character(character_id)
	_refresh_selection()
	var card: PanelContainer = _cards.get(character_id)
	if card != null:
		Juice.pop(card, 0.06)
		Juice.burst(self, card.get_global_rect().get_center(), 18)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")


## The chosen hero's card wears the gold star and full brightness; the others
## dim slightly but stay visible and tappable, so the child can flip between
## heroes freely and nothing ever disappears.
func _refresh_selection() -> void:
	var chosen: String = SaveManager.get_profile().get("character_id", "")
	for character_id in _cards.keys():
		var card: PanelContainer = _cards[character_id]
		var is_chosen: bool = character_id == chosen
		card.modulate = Color(1, 1, 1) if is_chosen else Color(0.78, 0.82, 0.9)
		var badge: Control = _badges.get(character_id)
		if badge != null:
			badge.visible = is_chosen
