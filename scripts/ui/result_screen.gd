extends Control
## Celebration screen. Always positive: even a one-star run is framed as
## finishing, never as failing.

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Color(0.16, 0.22, 0.36))

	var result: LevelResult = GameManager.get_last_result()
	var stars: int = result.stars() if result != null else 0

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var heading := UiKit.title(I18n.t("result.title"), 64)
	heading.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(heading)

	var row := UiKit.star_row(stars, 3, 96)
	box.add_child(row)
	_animate_stars(row, stars)

	var praise_key := "result.finished"
	if stars >= 3:
		praise_key = "result.great"
	elif stars == 2:
		praise_key = "result.good"
	var praise := UiKit.title(I18n.t(praise_key), 44)
	praise.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	box.add_child(praise)

	if RewardManager.last_coins_earned > 0:
		var coins := UiKit.title(
			I18n.t("result.coins") % RewardManager.last_coins_earned, 34
		)
		coins.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		box.add_child(coins)

	if RewardManager.last_new_badge != "":
		var badge := UiKit.title(
			I18n.t("result.new_badge") + "  " + RewardManager.badge_name(RewardManager.last_new_badge),
			38
		)
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		box.add_child(badge)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 32)
	box.add_child(buttons)

	var again := UiKit.big_button(I18n.t("common.again"), Color(0.20, 0.62, 0.35))
	again.pressed.connect(func(): GameManager.start_level(GameManager.current_level_id))
	buttons.add_child(again)

	var to_map := UiKit.big_button(I18n.t("result.back_to_map"), Color(0.24, 0.5, 0.85))
	to_map.pressed.connect(func(): SceneManager.goto_world_map())
	buttons.add_child(to_map)

	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")


## Stars pop in one at a time. The pause between them is the reward.
func _animate_stars(row: HBoxContainer, stars: int) -> void:
	var children := row.get_children()
	for i in range(children.size()):
		var star: Control = children[i]
		if i >= stars:
			continue
		star.scale = Vector2.ZERO
		star.pivot_offset = star.size / 2.0
		await get_tree().create_timer(0.35).timeout
		var t := create_tween()
		t.tween_property(star, "scale", Vector2(1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK)
		t.tween_property(star, "scale", Vector2.ONE, 0.12)
		AudioManager.play_sfx("res://assets/audio/star.ogg")
