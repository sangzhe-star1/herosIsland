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
		var coins := UiKit.title(I18n.t("result.coins") % RewardManager.last_coins_earned, 34)
		coins.add_theme_color_override("font_color", Palette.STAR_ON)
		coin_row.add_child(coins)
		box.add_child(coin_row)
		_fly_coins_to_chip(coin_row, RewardManager.last_coins_earned)

	if RewardManager.last_new_badge != "":
		var badge := UiKit.title(
			I18n.t("result.new_badge") + "  " + RewardManager.badge_name(RewardManager.last_new_badge),
			38
		)
		badge.add_theme_color_override("font_color", Palette.STAR_ON)
		box.add_child(badge)

	# Experience: a quiet spark line every time, a loud party on rank-up.
	if RewardManager.last_xp_earned > 0:
		var xp_row := HBoxContainer.new()
		xp_row.alignment = BoxContainer.ALIGNMENT_CENTER
		xp_row.add_theme_constant_override("separation", 8)
		var spark: Control = UiKit.picture("spark", 34)
		if spark != null:
			xp_row.add_child(spark)
		var xp_label := UiKit.title("+%d" % RewardManager.last_xp_earned, 28, Color(0.75, 0.88, 1.0))
		xp_row.add_child(xp_label)
		box.add_child(xp_row)

	if RewardManager.last_levels_gained > 0:
		var level_up := UiKit.title_on_art(
			I18n.t("result.level_up") % SaveManager.hero_level(), 46)
		level_up.add_theme_color_override("font_color", Palette.STAR_ON)
		box.add_child(level_up)
		UiKit.breathe(level_up, 0.05, 0.8)
		AudioManager.play_sfx("res://assets/audio/star.ogg")

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


## The earned coins fly one by one into the treasure chip, whose total climbs
## as each lands -- the child watches today's pay join the pile they own, the
## same chip they see on the home screen. Watching wealth accumulate is a
## reward in itself at this age.
func _fly_coins_to_chip(from_node: Control, earned: int) -> void:
	var new_total: int = int(SaveManager.data["rewards"]["coins"])
	var old_total: int = maxi(new_total - earned, 0)

	# The chip, top-right, showing where the coins are going.
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.26, 0.85)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	chip.add_theme_stylebox_override("panel", style)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	var chip_icon: Control = UiKit.picture("coin", 40)
	if chip_icon != null:
		chip_row.add_child(chip_icon)
	var chip_label := UiKit.title("%d" % old_total, 30, Palette.ON_COLOR)
	chip_row.add_child(chip_label)
	chip.add_child(chip_row)
	add_child(chip)
	await get_tree().process_frame
	if not is_instance_valid(chip):
		return
	chip.position = Vector2(1280.0 - chip.size.x - 28.0, 24)
	chip.pivot_offset = chip.size / 2.0

	if not Juice.motion_enabled():
		chip_label.text = "%d" % new_total
		return

	# A handful of flying coins carry the whole amount between them.
	var flights: int = clampi(earned, 3, 8)
	var from: Vector2 = from_node.get_global_rect().get_center()
	for i in range(flights):
		await get_tree().create_timer(0.14).timeout
		if not is_instance_valid(chip):
			return
		var coin: Control = UiKit.picture("coin", 44)
		if coin == null:
			break
		coin.position = from - Vector2(22, 22)
		add_child(coin)
		var to: Vector2 = chip.position + Vector2(24, chip.size.y / 2.0 - 22)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(coin, "position:x", to.x, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(coin, "position:y", to.y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		var landed := i + 1
		t.chain().tween_callback(func():
			if is_instance_valid(coin):
				coin.queue_free()
			if is_instance_valid(chip_label):
				var shown: int = old_total + int(round(float(earned) * float(landed) / float(flights)))
				chip_label.text = "%d" % (new_total if landed == flights else shown)
				Juice.pop(chip, 0.12)
				AudioManager.play_sfx("res://assets/audio/coin.ogg")
		)


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
