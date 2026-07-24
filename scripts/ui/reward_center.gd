extends Control
## What the child has earned. Coins, badges, and the five growth attributes
## shown as bars that only ever grow.
##
## Laid out like a BabyBus catalogue page: a soft light background with white
## rounded cards, one card per idea -- treasure, badges, growing up. The
## child's stuff looks collected and cared for, not listed.

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Palette.CREAM)

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 16)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title(I18n.t("rewards.title"), 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# The treasure chest, sitting on the shelf where the treasure is counted.
	var chest: Control = UiKit.picture("res://assets/ui/reward_chest.png", 84)
	if chest != null:
		header.add_child(chest)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 20)
	scroll.add_child(list)

	# --- treasure card ---------------------------------------------------
	var treasure_card := UiKit.card()
	treasure_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var treasure_row := HBoxContainer.new()
	treasure_row.add_theme_constant_override("separation", 14)
	var coin_icon: Control = UiKit.picture("coin", 52)
	if coin_icon != null:
		treasure_row.add_child(coin_icon)
	var coins: int = int(SaveManager.data["rewards"]["coins"])
	treasure_row.add_child(UiKit.title("%s: %d" % [I18n.t("rewards.coins"), coins], 40))
	var star_icon: Control = UiKit.picture("star", 52)
	if star_icon != null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(28, 0)
		treasure_row.add_child(spacer)
		treasure_row.add_child(star_icon)
		treasure_row.add_child(UiKit.title("%d" % SaveManager.total_stars(), 40))
	treasure_card.add_child(treasure_row)
	list.add_child(treasure_card)

	# --- badges card -------------------------------------------------------
	var badge_card := UiKit.card()
	badge_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge_box := VBoxContainer.new()
	badge_box.add_theme_constant_override("separation", 12)
	badge_card.add_child(badge_box)

	var badge_title := UiKit.title(I18n.t("rewards.badges"), 40)
	badge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge_box.add_child(badge_title)

	var badge_row := HFlowContainer.new()
	badge_row.add_theme_constant_override("h_separation", 16)
	badge_row.add_theme_constant_override("v_separation", 16)
	badge_box.add_child(badge_row)

	var owned: Array = SaveManager.data["rewards"]["badges"]
	var all_badges: Dictionary = GameData.rewards.get("badges", {})
	for badge_id in all_badges.keys():
		var earned: bool = badge_id in owned
		var chip := UiKit.big_button(
			RewardManager.badge_name(badge_id) if earned else "?",
			Palette.ORANGE if earned else Palette.MUTED
		)
		chip.custom_minimum_size = Vector2(260, 110)
		chip.add_theme_font_size_override("font_size", 26)
		chip.disabled = true
		badge_row.add_child(chip)
	list.add_child(badge_card)

	# --- sticker book card ---------------------------------------------------
	# Coins finally have somewhere to GO. Each sticker is one of the game's
	# own badge pictures with a coin price; owned stickers glow at full
	# colour, unowned ones sit dim behind their price. Tap to buy -- if the
	# coins are there, it pops and it is yours forever. No reading needed:
	# picture, price, tap.
	var sticker_card := UiKit.card()
	sticker_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sticker_box := VBoxContainer.new()
	sticker_box.add_theme_constant_override("separation", 12)
	sticker_card.add_child(sticker_box)

	var sticker_title := UiKit.title(I18n.t("rewards.stickers"), 40)
	sticker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sticker_box.add_child(sticker_title)

	var sticker_row := HFlowContainer.new()
	sticker_row.add_theme_constant_override("h_separation", 14)
	sticker_row.add_theme_constant_override("v_separation", 14)
	sticker_box.add_child(sticker_row)

	for sticker in GameData.rewards.get("stickers", []):
		sticker_row.add_child(_build_sticker(sticker))
	list.add_child(sticker_card)

	# --- growth card ---------------------------------------------------------
	var growth_card := UiKit.card()
	growth_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var growth_box := VBoxContainer.new()
	growth_box.add_theme_constant_override("separation", 12)
	growth_card.add_child(growth_box)

	var growth_title := UiKit.title(I18n.t("rewards.growth"), 40)
	growth_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	growth_box.add_child(growth_title)

	for attribute in GameData.rewards.get("growth_attributes", []):
		var id: String = attribute.get("id", "")
		var value: int = int(SaveManager.data["growth"].get(id, 0))
		var line := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = I18n.t(attribute.get("name_key", ""))
		name_label.custom_minimum_size = Vector2(280, 0)
		name_label.add_theme_font_size_override("font_size", 32)
		line.add_child(name_label)

		var bar := ProgressBar.new()
		bar.max_value = 30.0
		bar.value = mini(value, 30)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(500, 34)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var frame: StyleBox = UiKit.texture_style("res://assets/ui/progress_frame.png", 24.0, 7.0)
		var fill: StyleBox = UiKit.texture_style("res://assets/ui/progress_fill.png", 18.0, 0.0)
		if frame != null and fill != null:
			bar.add_theme_stylebox_override("background", frame)
			bar.add_theme_stylebox_override("fill", fill)
		line.add_child(bar)
		growth_box.add_child(line)
	list.add_child(growth_card)


func _build_sticker(sticker: Dictionary) -> Control:
	var sticker_id := str(sticker.get("id", ""))
	var cost := int(sticker.get("cost", 10))
	var owned := SaveManager.has_sticker(sticker_id)

	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(150, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0) if owned else Color(0.55, 0.58, 0.66, 0.18)
	style.set_corner_radius_all(22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		tile.add_theme_stylebox_override(state, style)

	var icon: Control = UiKit.picture(sticker_id, 96)
	if icon != null:
		icon.position = Vector2(27, 8)
		icon.modulate = Color(1, 1, 1, 1.0) if owned else Color(0.6, 0.62, 0.7, 0.8)
		tile.add_child(icon)

	if not owned:
		var price := HBoxContainer.new()
		price.add_theme_constant_override("separation", 4)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var coin: Control = UiKit.picture("coin", 30)
		if coin != null:
			price.add_child(coin)
		var amount := Label.new()
		amount.text = str(cost)
		amount.add_theme_font_size_override("font_size", 24)
		amount.add_theme_color_override("font_color", Palette.INK)
		price.add_child(amount)
		price.position = Vector2(48, 112)
		tile.add_child(price)
		tile.pressed.connect(func(): _try_buy(sticker_id, cost, tile, icon, price))
	return tile


func _try_buy(sticker_id: String, cost: int, tile: Button, icon: Control, price: Control) -> void:
	if SaveManager.has_sticker(sticker_id):
		return
	if not SaveManager.spend_coins(cost):
		# Not enough yet: the price tag wiggles, nothing is lost, and the next
		# level is the way to fix it. No error sound, no popup.
		Juice.nudge(price)
		return
	SaveManager.add_sticker(sticker_id)
	if icon != null:
		icon.modulate = Color.WHITE
	price.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	style.set_corner_radius_all(22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		tile.add_theme_stylebox_override(state, style)
	Juice.pop(tile, 0.25)
	Juice.burst(self, tile.get_global_rect().get_center(), 18)
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	# The header chip and coins card are stale now; rebuild the screen state
	# cheaply by refreshing the scene.
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn")
