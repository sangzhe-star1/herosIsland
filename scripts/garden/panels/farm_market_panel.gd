extends "res://scripts/garden/panels/farm_panel_base.gd"
## Market sheet: selling crops at the market stall.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Market := preload("res://scripts/garden/farm_market_manager.gd")
const MarketDay := preload("res://scripts/garden/farm_market_day_manager.gd")
const DragField := preload("res://scripts/shared/drag_field.gd")
const Shapes := preload("res://scripts/world/shapes.gd")


func build(view: Vector2) -> void:
	var wide := 780.0
	var tall := 460.0
	var origin: Vector2 = panel_sheet(view, "garden.market_title", wide, tall,
		Callable(screen, "_close_panels"))

	var market_rows: Dictionary = screen.get("_market_rows")
	market_rows.clear()
	screen.set("_market_total", null)
	screen.set("_market_rows_scroll", null)
	screen.set("_market_rows_list", null)
	screen.set("_market_drop_hint", null)

	var shelf := Panel.new()
	shelf.name = "MarketBarnShelf"
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.position = origin + Vector2(18.0, 72.0)
	shelf.size = Vector2(414.0, 372.0)
	shelf.add_theme_stylebox_override("panel", quiet_surface_style(
		Color(0.93, 0.91, 0.81, 0.64), 22, Color(0.57, 0.53, 0.40, 0.28), 1, 10))
	play.add_child(shelf)

	var receipt := Panel.new()
	receipt.name = "MarketReceipt"
	receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt.position = origin + Vector2(440.0, 72.0)
	receipt.size = Vector2(322.0, 372.0)
	receipt.add_theme_stylebox_override("panel", quiet_surface_style(
		Color(0.99, 0.96, 0.86, 0.76), 22, Color(0.77, 0.62, 0.34, 0.38), 1, 10))
	play.add_child(receipt)

	var shelf_title := UiKit.title(I18n.t("garden.market.shelf"), 21)
	shelf_title.position = origin + Vector2(34.0, 75.0)
	shelf_title.size = Vector2(210.0, 30.0)
	shelf_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.add_child(shelf_title)

	if MarketDay.is_market_day():
		var dear_id := MarketDay.current_dear_produce()
		var dear_name := MarketDay.crop_display_name(dear_id)
		var banner := UiKit.title(I18n.t("market.day_active_short") % dear_name, 15, Color(0.85, 0.46, 0.10))
		banner.name = "MarketDayShelfBanner"
		banner.position = origin + Vector2(200.0, 78.0)
		banner.size = Vector2(220.0, 26.0)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		play.add_child(banner)

	var box_title := UiKit.title(I18n.t("garden.market.box"), 21)
	box_title.position = origin + Vector2(458.0, 75.0)
	box_title.size = Vector2(260.0, 30.0)
	box_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.add_child(box_title)

	var market_field := DragField.new()
	play.add_child(market_field)
	market_field.dropped.connect(Callable(self, "on_market_drop"))
	screen.set("_market_field", market_field)

	var box_at := origin + Vector2(600.0, 166.0)
	var crate := Node2D.new()
	crate.position = box_at
	play.add_child(crate)
	Shapes.fill(crate, Shapes.oval_points(Vector2(0.0, 42.0),
		Vector2(80.0, 13.0), 24), Color(0.34, 0.25, 0.16, 0.15), 0.0)
	Shapes.lit(crate, Shapes.rounded_rect(Vector2(-72.0, -5.0),
		Vector2(144.0, 78.0), 16.0), Color(0.72, 0.52, 0.30), 0.8)
	Shapes.fill(crate, Shapes.oval_points(Vector2(0.0, -9.0),
		Vector2(68.0, 20.0), 24), Color(0.38, 0.25, 0.15), 0.65)
	Shapes.lit(crate, Shapes.rounded_rect(Vector2(-72.0, 18.0),
		Vector2(144.0, 15.0), 7.0), Color(0.83, 0.63, 0.37), 0.5)

	var box_slot_node := Node2D.new()
	play.add_child(box_slot_node)
	var box_slot: Dictionary = market_field.add_slot(box_slot_node, box_at, "", 99)

	var contents := Barn.contents()
	var market_sell: Dictionary = screen.get("_market_sell")
	for i in range(contents.size()):
		var pair: Array = contents[i]
		var crop_id := str(pair[0])
		var boxed := int(market_sell.get(crop_id, 0))
		var remaining := Barn.count(crop_id) - boxed
		var chip := Node2D.new()
		var col := i % 4
		var row_index := int(i / 4)
		chip.position = origin + Vector2(75.0 + 100.0 * col, 154.0 + 82.0 * row_index)
		play.add_child(chip)
		var spent := remaining <= 0
		Shapes.fill(chip, Shapes.rounded_rect(Vector2(-48.0, -32.0),
			Vector2(96.0, 72.0), 15.0), Color(0.49, 0.38, 0.22, 0.12), 0.0)
		Shapes.lit(chip, Shapes.rounded_rect(Vector2(-48.0, -36.0),
			Vector2(96.0, 72.0), 15.0),
			Color(0.91, 0.89, 0.82) if spent else Color(0.99, 0.97, 0.90), 0.72)
		var art := UiKit.picture(str(GameData.get_crop(crop_id).get("icon", "seed")), 40.0)
		if art != null:
			art.position = Vector2(-20.0, -32.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(art)
		var many := UiKit.title("x%d" % remaining, 17)
		many.name = "PileCount_%s" % crop_id
		many.position = Vector2(-44.0, 8.0)
		many.size = Vector2(42.0, 22.0)
		many.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		many.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(many)
		var coin_glyph := UiKit.picture("star_coin", 14.0)
		if coin_glyph != null:
			coin_glyph.position = Vector2(0.0, 12.0)
			coin_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(coin_glyph)
		var is_dear := MarketDay.is_doubled(crop_id)
		var unit := UiKit.title(str(GameData.market_price(crop_id)), 17,
			Color(0.85, 0.45, 0.10) if is_dear else Color(0.25, 0.22, 0.18))
		unit.name = "UnitPrice_%s" % crop_id
		unit.position = Vector2(18.0, 8.0)
		unit.size = Vector2(28.0, 22.0)
		unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(unit)
		if is_dear:
			var tag_x2 := UiKit.title("x%d" % MarketDay.multiplier(), 12, Color(0.85, 0.45, 0.10))
			tag_x2.name = "DoubleTag_%s" % crop_id
			tag_x2.position = Vector2(20.0, -28.0)
			tag_x2.size = Vector2(24.0, 16.0)
			tag_x2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(tag_x2)
		var market_item := market_field.add_item(chip, chip.position, crop_id)
		if boxed > 0:
			market_item["placed"] = true
			market_item["slot"] = box_slot
			box_slot["held"] = int(box_slot["held"]) + 1
			chip.position = box_at

	var market_rows_scroll := ScrollContainer.new()
	market_rows_scroll.name = "MarketReceiptRows"
	market_rows_scroll.position = origin + Vector2(456.0, 244.0)
	market_rows_scroll.custom_minimum_size = Vector2(290.0, 124.0)
	market_rows_scroll.size = Vector2(290.0, 124.0)
	market_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	market_rows_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	play.add_child(market_rows_scroll)
	screen.set("_market_rows_scroll", market_rows_scroll)

	var market_rows_list := VBoxContainer.new()
	market_rows_list.name = "MarketReceiptList"
	market_rows_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_rows_list.add_theme_constant_override("separation", 5)
	market_rows_scroll.add_child(market_rows_list)
	screen.set("_market_rows_list", market_rows_list)

	for crop_id in market_sell.keys():
		ensure_market_row(str(crop_id))

	market_rows_scroll.set_deferred("scroll_vertical", int(screen.get("_market_scroll_offset")))
	var market_drop_hint := UiKit.title(I18n.t("garden.market.drop_hint"), 17, Color(0.53, 0.48, 0.38))
	market_drop_hint.name = "MarketDropHint"
	market_drop_hint.position = origin + Vector2(466.0, 277.0)
	market_drop_hint.size = Vector2(270.0, 46.0)
	market_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(market_drop_hint)
	screen.set("_market_drop_hint", market_drop_hint)
	sync_rows_visibility()

	var coin := UiKit.picture("star_coin", 20.0)
	if coin != null:
		coin.position = origin + Vector2(526.0, 395.0)
		play.add_child(coin)
	var total_caption := UiKit.title(I18n.t("garden.market.total"), 14, Color(0.48, 0.42, 0.31))
	total_caption.position = origin + Vector2(458.0, 396.0)
	total_caption.size = Vector2(66.0, 24.0)
	total_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	total_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(total_caption)
	var market_total := UiKit.title(str(Market.quote(market_sell)), 26)
	market_total.position = origin + Vector2(546.0, 391.0)
	market_total.size = Vector2(46.0, 32.0)
	market_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	market_total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(market_total)
	screen.set("_market_total", market_total)

	var sell := chip_button(I18n.t("garden.sell"), Color(0.99, 0.83, 0.52), Vector2(152.0, 56.0))
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := sell.get_theme_stylebox(look) as StyleBoxFlat
		if style != null:
			style.content_margin_top = 6.0
			style.content_margin_bottom = 6.0
	sell.position = origin + Vector2(594.0, 382.0)
	sell.pressed.connect(Callable(self, "_sell_pressed"))
	play.add_child(sell)
	sell.size = Vector2(152.0, 56.0)
	var panel_buttons: Dictionary = screen.get("_panel_buttons")
	panel_buttons["sell"] = sell


## The drop is already in its slot when DragField emits. Keep the current
## basket in the screen so a clock-driven furniture rebuild can restore it.
func on_market_drop(item: Dictionary, slot: Variant, correct: bool) -> void:
	if not bool(screen.get("_market_open")) or not correct or slot == null:
		return
	var crop_id := str(item.get("key", ""))
	var market_sell: Dictionary = screen.get("_market_sell")
	market_sell[crop_id] = Barn.count(crop_id)
	if not (screen.get("_market_rows") as Dictionary).has(crop_id):
		ensure_market_row(crop_id)
	refresh_row(crop_id)
	sync_rows_visibility()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")


## Receipt rows and their thumb-sized steppers belong to this panel. The
## screen retains the basket data; a new panel instance redraws it after ticks.
func ensure_market_row(crop_id: String) -> void:
	var rows: Dictionary = screen.get("_market_rows")
	var rows_list := screen.get("_market_rows_list") as VBoxContainer
	if rows.has(crop_id) or not is_instance_valid(rows_list):
		return
	var row := PanelContainer.new()
	row.name = "MarketBoxRow_%s" % crop_id
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.custom_minimum_size = Vector2(274.0, 50.0)
	row.add_theme_stylebox_override("panel", quiet_surface_style(
		Color(1.0, 0.99, 0.93), 13, Color(0.67, 0.58, 0.39, 0.24), 1, 4))
	rows_list.add_child(row)
	var line := HBoxContainer.new()
	line.name = "MarketReceiptLine"
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_theme_constant_override("separation", 4)
	row.add_child(line)
	var art := UiKit.picture(
		str(GameData.get_crop(crop_id).get("icon", "seed")), 32.0)
	if art != null:
		art.custom_minimum_size = Vector2(36.0, 40.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(art)
	var market_sell: Dictionary = screen.get("_market_sell")
	var count := UiKit.title("x%d" % int(market_sell.get(crop_id, 0)), 19)
	count.name = "BoxCount_%s" % crop_id
	count.custom_minimum_size = Vector2(54.0, 34.0)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(count)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	var minus := chip_button("−", Color(0.99, 0.86, 0.74), Vector2(44.0, 44.0))
	minus.name = "BoxMinus_%s" % crop_id
	minus.pressed.connect(func(): step_crop(crop_id, -1))
	line.add_child(minus)
	var plus := chip_button("+", Color(0.88, 0.95, 0.84), Vector2(44.0, 44.0))
	plus.name = "BoxPlus_%s" % crop_id
	plus.pressed.connect(func(): step_crop(crop_id, +1))
	line.add_child(plus)
	rows[crop_id] = {"row": row, "count": count}


func sync_rows_visibility() -> void:
	var has_boxed := not (screen.get("_market_sell") as Dictionary).is_empty()
	var rows_scroll := screen.get("_market_rows_scroll") as ScrollContainer
	var drop_hint := screen.get("_market_drop_hint") as Label
	if is_instance_valid(rows_scroll):
		rows_scroll.visible = has_boxed
	if is_instance_valid(drop_hint):
		drop_hint.visible = not has_boxed


## The receipt total and shelf count answer one question together: how many
## are selected, and how many remain available to keep.
func refresh_row(crop_id: String) -> void:
	var rows: Dictionary = screen.get("_market_rows")
	var entry: Variant = rows.get(crop_id, null)
	if entry is Dictionary and (entry as Dictionary).get("count") is Label:
		var label: Label = (entry as Dictionary)["count"]
		if is_instance_valid(label):
			label.text = "x%d" % int((screen.get("_market_sell") as Dictionary).get(crop_id, 0))
	refresh_shelf(crop_id)
	var total := screen.get("_market_total") as Label
	if is_instance_valid(total):
		total.text = str(Market.quote(screen.get("_market_sell")))
		Juice.pop(total, 0.12)


func refresh_shelf(crop_id: String) -> void:
	var chip_count := play.find_child("PileCount_%s" % crop_id, true, false)
	if chip_count is Label and is_instance_valid(chip_count):
		(chip_count as Label).text = "x%d" % (
			Barn.count(crop_id) - int((screen.get("_market_sell") as Dictionary).get(crop_id, 0)))


## Emptying a row returns its placed crop card to the original shelf position.
func return_to_shelf(crop_id: String) -> void:
	var market_field: Variant = screen.get("_market_field")
	if not is_instance_valid(market_field):
		return
	for item in market_field.items():
		if str(item.get("key", "")) != crop_id \
				or not bool(item.get("placed", false)):
			continue
		var slot: Variant = item.get("slot", {})
		if slot is Dictionary and not slot.is_empty():
			slot["held"] = maxi(0, int(slot.get("held", 0)) - 1)
		item["placed"] = false
		item["slot"] = {}
		var node_value: Variant = item.get("node")
		if not is_instance_valid(node_value) or not (node_value is Node2D):
			return
		var card := node_value as Node2D
		var home: Vector2 = item.get("home", item.get("at", Vector2.ZERO))
		market_field.cancel_item_motion(item)
		card.position = home
		card.scale = Vector2.ONE
		card.z_index = 0
		return


## One crop per press, bounded by the live barn count. A zero row hands its
## card back to the shelf and disappears from the receipt.
func step_crop(crop_id: String, delta: int) -> void:
	var market_sell: Dictionary = screen.get("_market_sell")
	var boxed := clampi(int(market_sell.get(crop_id, 0)) + delta,
		0, Barn.count(crop_id))
	if boxed == 0:
		market_sell.erase(crop_id)
	else:
		market_sell[crop_id] = boxed
	var rows: Dictionary = screen.get("_market_rows")
	if boxed == 0:
		if rows.has(crop_id):
			var entry: Variant = rows[crop_id]
			if entry is Dictionary and (entry as Dictionary).get("row") is Node:
				var row: Node = (entry as Dictionary)["row"]
				if is_instance_valid(row):
					row.queue_free()
			rows.erase(crop_id)
		return_to_shelf(crop_id)
	refresh_row(crop_id)
	sync_rows_visibility()
	AudioManager.play_sfx("res://assets/audio/%s"
		% ("drag_snap.ogg" if delta > 0 else "drag_back.ogg"))


## Keep a refused sale in place. Only a committed Market receipt clears the
## basket, pays the coins, and plays the existing collection feedback.
func _sell_pressed() -> void:
	var market_sell: Dictionary = screen.get("_market_sell")
	var paid := Market.sell(market_sell)
	if paid <= 0:
		var buttons: Dictionary = screen.get("_panel_buttons")
		var button := buttons.get("sell") as Button
		if is_instance_valid(button):
			Juice.nudge(button, 8.0)
		return
	screen.set("_market_sell", {})
	screen.set("_market_rows", {})
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	AudioManager.say("farm_market_sold")
	if Juice.motion_enabled() and is_instance_valid(play):
		var view: Vector2 = (screen as CanvasItem).get_viewport_rect().size
		for i in range(5):
			var fly := UiKit.picture("star_coin", 30.0)
			if fly == null:
				continue
			fly.position = Vector2(view.x * 0.5, view.y * 0.45) \
				+ Vector2(float(i - 2) * 22.0, 0)
			play.add_child(fly)
			var tween := fly.create_tween()
			tween.tween_interval(0.05 * float(i))
			tween.tween_property(fly, "position",
				Vector2(view.x - 160.0, 40.0), 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(fly.queue_free)
	screen.call("_queue_rebuild")
