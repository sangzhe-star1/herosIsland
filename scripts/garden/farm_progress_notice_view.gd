extends "res://scripts/garden/panels/farm_panel_base.gd"
## Non-modal notices for recipe knowledge, farm milestones, and small discoveries.


## A level award is an event the screen has already decided to show. Keep its
## sound, voice, burst, and level-eight card together with the other notices.
func level_up(layer: CanvasLayer, view: Vector2,
		crossed_master_farmer: bool) -> void:
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	AudioManager.say("farm_level_up")
	if Juice.motion_enabled() and play != null and is_instance_valid(play):
		Juice.burst(play, Vector2(190.0, TOP_BAR * 0.55), 16)
	if crossed_master_farmer:
		master_farmer(layer, view)



## Beds that ripened while he watched: one pop for the beat, one soft ring per
## bed. The tick controller has already decided which beds crossed the line.
func ripened(centres: Array) -> void:
	if centres.is_empty() or play == null or not is_instance_valid(play):
		return
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	for centre in centres:
		Juice.shockwave(play, centre, 140.0, Color(1.0, 0.94, 0.62, 0.5))

## Daily completion receipts are already gated by the progress controller; this
## view owns the matching chimes and the last-star praise line.
func daily_progress(receipt: Dictionary) -> void:
	if bool(receipt.get("task_completed", false)):
		AudioManager.play_sfx("res://assets/audio/found.ogg")
	if bool(receipt.get("all_completed", false)):
		AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
		AudioManager.say("praise_3")


## A friend's thanks is feedback, never a dialog to dismiss. Keep it on the
## collection layer so the paid order's board redraw cannot remove it.
func order_thanks(order: Dictionary, layer: CanvasLayer, view: Vector2) -> void:
	var key := str(order.get("thanks_key", ""))
	if key.is_empty() or layer == null or not is_instance_valid(layer):
		return
	var old := layer.get_node_or_null("OrderThanks")
	if old != null:
		old.name = "ExpiredOrderThanks"
		old.queue_free()
	var card := Panel.new()
	card.name = "OrderThanks"
	card.set_meta("order_id", str(order.get("id", "")))
	card.add_theme_stylebox_override("panel", UiKit.panel_style(
		Color(1.0, 0.98, 0.89, 0.98), 20))
	card.position = Vector2((view.x - 450.0) * 0.5, TOP_BAR + 14.0)
	card.size = Vector2(450.0, 64.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var face := screen.call("_order_customer_art", order, 44.0) as Control
	if face != null:
		face.position = Vector2(12.0, 10.0)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
	var words := UiKit.title(I18n.t(key), 18, Color(0.34, 0.31, 0.23))
	words.name = "OrderThanksText"
	words.position = Vector2(68.0, 10.0)
	words.size = Vector2(370.0, 44.0)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(words)
	Juice.pop(card, 0.05)
	var lifetime := card.create_tween()
	lifetime.tween_interval(3.0)
	lifetime.tween_property(card, "modulate:a", 0.0, 0.25)
	lifetime.tween_callback(card.queue_free)


func recipe_learned(recipe: Dictionary, layer: CanvasLayer,
		view: Vector2) -> void:
	var wide := 520.0
	var card := Panel.new()
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.95, 0.98), 22))
	card.position = Vector2((view.x - wide) * 0.5, 96.0)
	card.custom_minimum_size = Vector2(wide, 116.0)
	card.size = Vector2(wide, 116.0)
	card.z_index = 30
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Collection feedback survives the bed/barn redraw that earned it.
	layer.add_child(card)
	var face := UiKit.picture("teddy", 72.0)
	if face != null:
		face.position = Vector2(20.0, 22.0)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
	var said := UiKit.title(I18n.t("garden.recipe_learned"), UiKit.TYPE_CAPTION,
		Color(0.52, 0.48, 0.40))
	said.position = Vector2(108.0, 18.0)
	said.size = Vector2(wide - 130.0, 26.0)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(said)
	var dish := UiKit.title(I18n.t(str(recipe.get("name_key", ""))), UiKit.TYPE_BODY)
	dish.position = Vector2(108.0, 46.0)
	dish.size = Vector2(wide - 130.0, 34.0)
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(dish)
	var x := 108.0
	for need in recipe.get("needs", []):
		var art := UiKit.picture(
			str(GameData.get_crop(str(need.get("crop_id", ""))).get("icon", "seed")), 26.0)
		if art != null:
			art.position = Vector2(x, 82.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art)
		x += 34.0
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	Juice.pop(card, 0.14)
	var lifetime := card.create_tween()
	lifetime.tween_interval(2.6)
	lifetime.tween_property(card, "modulate:a", 0.0, 0.4)
	lifetime.tween_callback(card.queue_free)


func master_farmer(layer: CanvasLayer, view: Vector2) -> void:
	var old := layer.get_node_or_null("MasterCelebration")
	if old != null:
		old.name = "ExpiredMasterCelebration"
		old.queue_free()
	var card := Panel.new()
	card.name = "MasterCelebration"
	card.add_theme_stylebox_override("panel", UiKit.panel_style(
		Color(1.0, 0.97, 0.82, 0.98), 20))
	var wide := 480.0
	var tall := 90.0
	card.position = Vector2((view.x - wide) * 0.5, 96.0)
	card.custom_minimum_size = Vector2(wide, tall)
	card.size = Vector2(wide, tall)
	card.z_index = 32
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var crown := UiKit.picture("crown", 48.0)
	if crown != null:
		crown.position = Vector2(16.0, 21.0)
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(crown)
	var title := UiKit.title(I18n.t("farm.level_8_title"), 22,
		Color(0.68, 0.42, 0.10))
	title.position = Vector2(78.0, 12.0)
	title.size = Vector2(wide - 92.0, 24.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(title)
	var desc := UiKit.title(I18n.t("farm.level_8_desc"), 16,
		Color(0.42, 0.36, 0.25))
	desc.position = Vector2(78.0, 38.0)
	desc.size = Vector2(wide - 92.0, 20.0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(desc)
	var reward_lbl := UiKit.title(I18n.t("farm.level_8_reward"), 14,
		Color(0.56, 0.46, 0.22))
	reward_lbl.position = Vector2(78.0, 60.0)
	reward_lbl.size = Vector2(wide - 92.0, 18.0)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(reward_lbl)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	Juice.pop(card, 0.14)
	if Juice.motion_enabled():
		Juice.burst(layer, Vector2(view.x * 0.5, 140.0), 16)
	var lifetime := card.create_tween()
	lifetime.tween_interval(3.6)
	lifetime.tween_property(card, "modulate:a", 0.0, 0.45)
	lifetime.tween_callback(card.queue_free)


func toast(layer: CanvasLayer, view: Vector2, top_bar: float,
		message: String, icon_name: String = "") -> void:
	var old := layer.get_node_or_null("ToastBanner")
	if old != null:
		old.name = "ExpiredToastBanner"
		old.queue_free()
	var card := Panel.new()
	card.name = "ToastBanner"
	card.add_theme_stylebox_override("panel", UiKit.panel_style(
		Color(1.0, 0.98, 0.89, 0.98), 20))
	var wide := 500.0
	card.position = Vector2((view.x - wide) * 0.5, top_bar + 14.0)
	card.size = Vector2(wide, 64.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var x_offset := 16.0
	if icon_name != "":
		var art := UiKit.picture(icon_name, 40.0)
		if art != null:
			art.position = Vector2(14.0, 12.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art)
			x_offset = 64.0
	var words := UiKit.title(message, 17, Color(0.34, 0.31, 0.23))
	words.position = Vector2(x_offset, 10.0)
	words.size = Vector2(wide - x_offset - 16.0, 44.0)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(words)
	Juice.pop(card, 0.05)
	var lifetime := card.create_tween()
	lifetime.tween_interval(2.8)
	lifetime.tween_property(card, "modulate:a", 0.0, 0.35)
	lifetime.tween_callback(card.queue_free)
