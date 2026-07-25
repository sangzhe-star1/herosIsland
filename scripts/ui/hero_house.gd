extends Control
## Hero House: where the child chooses who they play as.
##
## One card per character in data/characters.json, each showing the hero
## standing in it -- the real SkinnedCharacter node, so what the child picks is
## exactly what walks into the levels. Tapping a card selects it immediately;
## there is no confirm step, because trying every hero in turn IS the fun, and
## nothing here can be broken by tapping.

var _cards: Dictionary = {}   # character_id -> PanelContainer
var _badges: Dictionary = {}  # character_id -> the "this one is chosen" star


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

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(row)
	root.add_child(center)

	var characters: Dictionary = GameData.characters.get("characters", {})
	for character_id in characters.keys():
		var entry: Dictionary = characters[character_id]
		if not bool(entry.get("unlocked", false)):
			continue
		var card := _build_card(str(character_id), entry)
		card.pivot_offset = card.custom_minimum_size / 2.0
		_cards[str(character_id)] = card
		row.add_child(card)

	_refresh_selection()
	_build_sticker_wall()


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


func _build_card(character_id: String, entry: Dictionary) -> PanelContainer:
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(300, 400)

	# PanelContainer lays out its direct children itself and tramples anchors
	# and positions, so everything lives inside one plain Control -- the one
	# node type guaranteed to leave its children exactly where they are put.
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(300, 400)
	card.add_child(inner)

	# Every hero is presented the same way: the live drawn figure, standing on
	# a card, breathing. Two of the three used to be a photographic spotlight
	# card from an asset bundle and the third a drawn figure, which made the
	# choice screen look like a shop selling two different products.
	var preview := SkinnedCharacter.new()
	var preview_skin: CharacterSkin = GameData.skin_for(character_id)
	if preview_skin != null:
		preview.skin = preview_skin
	preview.position = Vector2(150, 300)
	inner.add_child(preview)
	preview.set_height(250.0)

	var name_label := UiKit.title(I18n.t(str(entry.get("name_key", ""))), 34)
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -64
	name_label.offset_bottom = -14
	inner.add_child(name_label)

	# "This is who you are right now": a gold star pinned to the chosen card.
	# A badge rather than a border, because at six a THING on the card reads
	# better than a property of the card.
	var badge: Control = UiKit.star(true, 72)
	badge.position = Vector2(224, 4)
	_badges[character_id] = badge
	inner.add_child(badge)

	# The whole card is the touch target; a six-year-old taps the hero, not a
	# button under it.
	card.gui_input.connect(func(event: InputEvent):
		var pressed: bool = (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed:
			_select(character_id)
	)
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
