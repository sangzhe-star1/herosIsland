extends Control
## Celebration screen. Always positive: even a one-star run is framed as
## finishing, never as failing.

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Palette.DUSK, "res://assets/backgrounds/victory.png")

	var result: LevelResult = GameManager.get_last_result()
	var stars: int = result.stars() if result != null else 0

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var heading := UiKit.title_on_art(I18n.t("result.title"), 64)
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
	praise.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	box.add_child(praise)

	if RewardManager.last_coins_earned > 0:
		var coin_row := HBoxContainer.new()
		coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
		coin_row.add_theme_constant_override("separation", 10)
		var coin_icon: Control = UiKit.picture("coin", 42)
		if coin_icon != null:
			coin_row.add_child(coin_icon)
		var coins := UiKit.title(I18n.t("result.coins") % 0, 34)
		coins.add_theme_color_override("font_color", Palette.STAR_ON)
		coin_row.add_child(coins)
		box.add_child(coin_row)
		_count_up(coins, RewardManager.last_coins_earned)

	if RewardManager.last_new_badge != "":
		var badge := UiKit.title(
			I18n.t("result.new_badge") + "  " + RewardManager.badge_name(RewardManager.last_new_badge),
			38
		)
		badge.add_theme_color_override("font_color", Palette.STAR_ON)
		box.add_child(badge)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 32)
	box.add_child(buttons)

	var again := UiKit.big_button(I18n.t("common.again"), Palette.GREEN)
	again.pressed.connect(func(): GameManager.start_level(GameManager.current_level_id))
	buttons.add_child(again)

	var to_map := UiKit.big_button(I18n.t("result.back_to_map"), Palette.BLUE)
	to_map.pressed.connect(func(): SceneManager.goto_world_map())
	buttons.add_child(to_map)

	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")

	# The hero celebrates WITH the child. Same skin they just played as; the
	# cheer pose (arms up) if that skin has one.
	var hero := SkinnedCharacter.new()
	hero.skin = GameData.current_skin()
	hero.position = Vector2(212, 520)
	hero.scale = Vector2(2.4, 2.4)
	add_child(hero)
	Juice.idle_bob(hero)
	hero.celebrate()

	# A full three stars earns a proper celebration; one or two do not. The
	# child should be able to feel the difference without counting.
	if stars >= 3:
		await get_tree().create_timer(1.4).timeout
		if is_instance_valid(self):
			hero.celebrate()
			Juice.burst(self, Vector2(420, 320), 30)
			Juice.burst(self, Vector2(860, 320), 30)


## Coins tick up rather than appearing. Watching a number climb is a reward in
## itself at this age, and it stretches the payoff over a couple of seconds
## instead of spending it in one frame.
func _count_up(label: Label, total: int) -> void:
	if not Juice.motion_enabled():
		label.text = I18n.t("result.coins") % total
		return
	var shown := 0
	var step: float = maxf(0.04, 0.9 / float(maxi(total, 1)))
	while shown < total:
		await get_tree().create_timer(step).timeout
		if not is_instance_valid(label):
			return
		shown += 1
		label.text = I18n.t("result.coins") % shown
		AudioManager.play_sfx("res://assets/audio/coin.ogg")


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
