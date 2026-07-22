extends Control
## What the child has earned. Coins, badges, and the five growth attributes
## shown as bars that only ever grow.

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Color(0.96, 0.90, 0.76))

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 16)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title(I18n.t("rewards.title"), 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 20)
	scroll.add_child(list)

	var coins: int = int(SaveManager.data["rewards"]["coins"])
	list.add_child(UiKit.title("%s: %d" % [I18n.t("rewards.coins"), coins], 40))

	list.add_child(UiKit.title(I18n.t("rewards.badges"), 40))
	var badge_row := HFlowContainer.new()
	badge_row.add_theme_constant_override("h_separation", 16)
	badge_row.add_theme_constant_override("v_separation", 16)
	list.add_child(badge_row)

	var owned: Array = SaveManager.data["rewards"]["badges"]
	var all_badges: Dictionary = GameData.rewards.get("badges", {})
	for badge_id in all_badges.keys():
		var earned: bool = badge_id in owned
		var chip := UiKit.big_button(
			RewardManager.badge_name(badge_id) if earned else "?",
			Color(0.90, 0.68, 0.20) if earned else Color(0.72, 0.70, 0.66)
		)
		chip.custom_minimum_size = Vector2(260, 110)
		chip.add_theme_font_size_override("font_size", 26)
		chip.disabled = true
		badge_row.add_child(chip)

	list.add_child(UiKit.title(I18n.t("rewards.growth"), 40))
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
		bar.custom_minimum_size = Vector2(500, 40)
		line.add_child(bar)
		list.add_child(line)
