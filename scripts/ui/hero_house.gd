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
	UiKit.background(self, Palette.SKY, "res://assets/backgrounds/home.png")

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


func _build_card(character_id: String, entry: Dictionary) -> PanelContainer:
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(300, 400)

	# A character with painted card art (the spotlight cards from the asset
	# bundle) gets it as the whole card face. Characters without one -- the
	# drawn Light Hero -- get the live SkinnedCharacter standing on a plain
	# card, so every hero is presented, art or no art.
	var card_art := "res://assets/ui/character_card_%s.png" % character_id
	if ResourceLoader.exists(card_art):
		card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var face := TextureRect.new()
		face.texture = load(card_art)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)

		# Name over the card art's bottom bar.
		var name_label := UiKit.title(I18n.t(str(entry.get("name_key", ""))), 36)
		name_label.add_theme_color_override("font_color", Palette.ON_COLOR)
		name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.75))
		name_label.add_theme_constant_override("outline_size", 8)
		name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.offset_top = -66
		name_label.offset_bottom = -18
		card.add_child(name_label)
	else:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)

		var holder := Control.new()
		holder.custom_minimum_size = Vector2(240, 260)
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(holder)

		var preview := SkinnedCharacter.new()
		var skin_path: String = str(entry.get("skin", ""))
		if skin_path != "" and ResourceLoader.exists(skin_path):
			preview.skin = load(skin_path)
		preview.position = Vector2(120, 130)
		preview.scale = Vector2(1.7, 1.7)
		holder.add_child(preview)
		Juice.idle_bob(preview, 5.0)

		var name_label := UiKit.title(I18n.t(str(entry.get("name_key", ""))), 34)
		box.add_child(name_label)

	# "This is who you are right now": a gold star pinned to the chosen card.
	# A badge rather than a border, because at six a THING on the card reads
	# better than a property of the card.
	var badge: Control = UiKit.star(true, 72)
	badge.position = Vector2(228, 2)
	_badges[character_id] = badge
	card.add_child(badge)

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
