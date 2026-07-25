extends Control
## The Star Shop: stars become things.
##
## The child asked (through his father) for exactly this: "the stars I earn
## should buy something". The catalogue is small and every item is a BATTLE
## item for the Monster Expedition, so the loop reads: play well -> stars ->
## potions -> braver expeditions -> more stars.
##
## The economy rule that keeps this safe: spending never touches the lifetime
## star count that unlocks worlds (see SaveManager.star_balance). A child can
## empty their purse and lose nothing they were proud of.
##
## Everything on a card is a picture first: the item icon, a star-price row,
## an owned-count chip. The words are captions.

var _balance_label: Label
var _cards: Dictionary = {}   # item_id -> {count: Label, price: int}


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.world_background(self, "piglet_town", "shop", 0.62)

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 18)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func():
		SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn")))
	var title := UiKit.title(I18n.t("shop.title"), 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# The purse: how many stars are free to spend, right where the prices are.
	var purse := UiKit.card(Color(1.0, 0.99, 0.96, 0.94))
	var purse_row := HBoxContainer.new()
	purse_row.add_theme_constant_override("separation", 8)
	purse_row.add_child(UiKit.star(true, 40))
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 36)
	_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purse_row.add_child(_balance_label)
	purse.add_child(purse_row)
	header.add_child(purse)
	root.add_child(header)

	var hint := UiKit.title(I18n.t("shop.hint"), 26, Palette.INK_SOFT)
	root.add_child(hint)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	center.add_child(row)

	for item in GameData.rewards.get("items", []):
		row.add_child(_build_card(item))
	_refresh()


func _build_card(item: Dictionary) -> PanelContainer:
	var item_id: String = str(item.get("id", ""))
	var price: int = int(item.get("cost_stars", 5))

	var card := UiKit.card()
	card.custom_minimum_size = Vector2(300, 380)

	var inner := Control.new()
	inner.custom_minimum_size = Vector2(260, 340)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	var art: Control = UiKit.picture(str(item.get("icon", "star")), 148)
	if art != null:
		art.position = Vector2(56, 8)
		inner.add_child(art)

	var name_label := UiKit.title(I18n.t(str(item.get("name_key", ""))), 32)
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 160
	name_label.offset_bottom = 200
	inner.add_child(name_label)

	var desc := UiKit.title(I18n.t(str(item.get("desc_key", ""))), 21, Palette.INK_SOFT)
	desc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	desc.offset_top = 200
	desc.offset_bottom = 252
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	# Price and pocket, side by side: "costs this" / "you have that many".
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 6)
	price_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	price_row.offset_top = 258
	price_row.offset_bottom = 300
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(UiKit.star(true, 36))
	var price_label := Label.new()
	price_label.text = str(price)
	price_label.add_theme_font_size_override("font_size", 32)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_row.add_child(price_label)
	inner.add_child(price_row)

	var count := Label.new()
	count.add_theme_font_size_override("font_size", 26)
	count.add_theme_color_override("font_color", Palette.INK_SOFT)
	count.set_anchors_preset(Control.PRESET_TOP_WIDE)
	count.offset_top = 302
	count.offset_bottom = 336
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(count)

	# The whole card buys, on press, exactly like the Hero House cards.
	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hit.button_down.connect(_buy.bind(item_id, price, card))
	inner.add_child(hit)

	card.pivot_offset = Vector2(150, 190)
	_cards[item_id] = {"count": count, "price": price}
	return card


func _buy(item_id: String, price: int, card: PanelContainer) -> void:
	if not SaveManager.spend_stars(price):
		# Not enough stars: the card shakes its head, the purse points at
		# itself. No grey-out -- a child should always be able to TRY.
		Juice.nudge(card)
		if _balance_label != null:
			Juice.pop(_balance_label, 0.3)
		return
	SaveManager.add_item(item_id)
	Juice.pop(card, 0.10)
	Juice.burst(self, card.get_global_rect().get_center(), 18)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	_refresh()


func _refresh() -> void:
	if _balance_label != null:
		_balance_label.text = str(SaveManager.star_balance())
	for item_id in _cards:
		var parts: Dictionary = _cards[item_id]
		(parts["count"] as Label).text = I18n.t("shop.owned") % SaveManager.item_count(item_id)
