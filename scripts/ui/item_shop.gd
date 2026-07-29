extends Control
## Battle items, bought with 星星币.
##
## The catalogue is small and every item is a BATTLE item for the duels, so
## the loop reads: play well -> 星星币 -> potions -> braver fights.
##
## It used to spend STARS, against `total_stars() - spent_stars`. That never
## re-locked a world -- but a child still watched his star count fall after
## buying a potion and had no way to know the number the map cares about had
## not moved. Stars are a score again, and only a score; everything spendable
## is 星星币 now. See scripts/shop/currency_manager.gd.
##
## Everything on a card is a picture first: the item icon, a price row, an
## owned-count chip. The words are captions.

const Coins := preload("res://scripts/shop/currency_manager.gd")
const Buying := preload("res://scripts/shop/purchase_manager.gd")

var _balance_label: Label
var _cards: Dictionary = {}   # item_id -> {count: Label, price: int, hit: Button}
var _buying: Buying


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.world_background(self, "piglet_town", "shop", 0.62)

	# The same confirm-and-put-back contract the Hero House uses, because this
	# screen once spent a coin on ONE press of the card. That was the exact
	# shape the red line forbids ("一次点击直接扣费") -- it shipped anyway,
	# because the wardrobe got the careful flow and this little shop was built
	# earlier and never revisited. One contract, one file, both shops.
	_buying = Buying.new()
	add_child(_buying)
	_buying.changed.connect(_refresh)
	_buying.go_play.connect(func(): SceneManager.goto_world_map())

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
	purse_row.add_child(UiKit.picture("star_coin", 40))
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
	var price: int = int(item.get("cost_coins", 20))

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
	price_row.add_child(UiKit.picture("star_coin", 36))
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

	# The whole card is the door to the confirm sheet -- pressing it opens the
	# three numbers, never a purchase. `pressed`, not `button_down`: a press
	# that can cost money is completed deliberately, not started accidentally.
	var hit := Button.new()
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hit.pressed.connect(_ask.bind(item, card))
	inner.add_child(hit)

	card.pivot_offset = Vector2(150, 190)
	_cards[item_id] = {"count": count, "price": price, "hit": hit}
	return card


func _ask(item: Dictionary, card: PanelContainer) -> void:
	var item_id := str(item.get("id", ""))
	var price := int(item.get("cost_coins", 20))
	Juice.pop(card, 0.06)
	# Money moves only inside the sheet. This screen's whole part in the deal
	# is saying how the potion is handed over -- and how it goes back on the
	# shelf inside the five 放回去 seconds.
	_buying.offer({
		"name_key": str(item.get("name_key", "")),
		"icon": str(item.get("icon", "star")),
		"price": price,
		"give": func(): SaveManager.add_item(item_id),
		"take_back": func(): SaveManager.use_item(item_id),
	})


func _refresh() -> void:
	if _balance_label != null:
		_balance_label.text = str(Coins.balance())
	for item_id in _cards:
		var parts: Dictionary = _cards[item_id]
		(parts["count"] as Label).text = I18n.t("shop.owned") % SaveManager.item_count(item_id)
