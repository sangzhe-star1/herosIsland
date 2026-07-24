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
