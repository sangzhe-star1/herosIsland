extends Control
const Rest := preload("res://scripts/shared/rest_director.gd")

## Celebration screen. Always positive: even a one-star run is framed as
## finishing, never as failing.

## The strip along the bottom that belongs to the buttons, and a little air at
## the top so the "闯关成功！" heading never touches the bezel.
const BUTTON_STRIP := 150.0
const TOP_MARGIN := 14.0


func _ready() -> void:
	theme = UiKit.theme()
	# The world they were just standing in, not a fixed one. The celebration
	# reads as happening WHERE the level happened -- finish the castle and the
	# cheering happens under the castle's moon. It was pinned to hero_city,
	# which since the rebuild is not a world the child ever visits.
	UiKit.world_background(self, str(GameManager.current_world_id), "result")

	var result: LevelResult = GameManager.get_last_result()
	var stars: int = result.stars() if result != null else 0

	# The buttons get a strip at the bottom of their own, and everything the
	# child READS stacks in the room above it.
	#
	# It was all one centred column, which was right until a run earned a
	# badge AND a level-up AND finished a world -- and then the column grew
	# past the bottom of the screen, taking all four buttons with it. Roughly
	# 170 px of them, gone. The best run a child can have was the one run
	# where they could not see what to press.
	#
	# The buttons are pinned rather than fitted because they are a six-year-
	# old's touch targets: a column can close its gaps and shrink its text,
	# but a button that gets smaller when the news is good is backwards.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = TOP_MARGIN
	box.offset_bottom = -BUTTON_STRIP
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var heading := UiKit.title_on_art(I18n.t("result.title"), 64)
	box.add_child(heading)

	var row := UiKit.star_row(stars, 3, 96)
	box.add_child(row)
	_animate_stars(row, stars)

	# Adventure levels earn their three stars from three SEPARATE questions,
	# so the screen says which one is still out there. "You got two stars"
	# tells a six-year-old they fell short; a dim gem next to a bright chest
	# tells them exactly where to go looking, which is an invitation rather
	# than a grade.
	if result != null and result.objective_scoring:
		box.add_child(_objective_row(result))

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
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	buttons.offset_top = -BUTTON_STRIP
	buttons.offset_bottom = -22.0
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	add_child(buttons)

	# "Next" first and breathing: it is the one button a child should be able
	# to find without reading, and going forward is what they actually want
	# after a win. Replaying and the map stay available beside it.
	# Finishing a world earns the little lesson: the thing cartoons for this
	# age do at the end of an episode. It replaces the "next" button rather
	# than adding a third one, because a child who has just finished a world
	# should get the moment, not a menu.
	var next_id: String = GameManager.next_level_id()
	if result != null and not result.quit_early and _world_just_finished():
		var lesson := UiKit.big_button(I18n.t("lesson.watch"), Palette.ORANGE)
		lesson.custom_minimum_size = Vector2(300, 120)
		lesson.pressed.connect(func():
			SceneManager.goto_scene("res://scenes/ui/MiniLesson.tscn"))
		buttons.add_child(lesson)
		UiKit.breathe(lesson, 0.04, 0.85)
	if next_id != "":
		var next_button := UiKit.big_button(I18n.t("result.next"), Palette.GREEN)
		next_button.custom_minimum_size = Vector2(260, 120)
		next_button.pressed.connect(func(): GameManager.start_level(next_id))
		buttons.add_child(next_button)
		UiKit.breathe(next_button, 0.035, 0.9)

	var again := UiKit.big_button(I18n.t("common.again"),
		Palette.SLATE if next_id != "" else Palette.GREEN)
	again.pressed.connect(func(): GameManager.start_level(GameManager.current_level_id))
	buttons.add_child(again)

	var to_map := UiKit.big_button(I18n.t("result.back_to_map"), Palette.BLUE)
	to_map.pressed.connect(func(): SceneManager.goto_world_map())
	buttons.add_child(to_map)

	if next_id == "":
		var all_done := UiKit.title_on_art(I18n.t("result.all_done"), 30)
		box.add_child(all_done)

	# Every few levels, the game suggests a break -- and does nothing else
	# about it. See `rest_director.gd` for why this is the game's job rather
	# than the parent's.
	if result != null and not result.quit_early and Rest.should_offer():
		box.add_child(_rest_note())

	# Everything is in; make it fit. Closes the gaps first and only shrinks if
	# that was not enough, so an ordinary two-star run looks exactly as it did.
	UiKit.fit_column(box)

	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")

	# The hero celebrates WITH the child. Same skin they just played as; the
	# cheer pose (arms up) if that skin has one.
	var hero := SkinnedCharacter.new()
	hero.skin = GameData.current_skin()
	hero.position = Vector2(150, Stage.ground_line())
	add_child(hero)
	hero.set_height(330.0)
	hero.victory()

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
## The three doors: finished / found the secret / kept your hearts. Done ones
## are bright and wear a tick; the rest are dim -- never crossed out, never
## red. Nothing on this screen is allowed to read as a telling-off.
func _objective_row(result: LevelResult) -> Control:
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 30)
	var delay := 0.0
	for item in result.objectives():
		var tile := Control.new()
		tile.custom_minimum_size = Vector2(104, 104)
		tile.pivot_offset = Vector2(52, 52)
		var pad := Node2D.new()
		tile.add_child(pad)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2), Vector2(100, 100), 26.0),
			Color(0.05, 0.09, 0.20, 0.55), 0.0)
		var art: Control = UiKit.picture(str(item.get("icon", "")), 62)
		if art != null:
			art.position = Vector2(21, 21)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(art)
		var done: bool = bool(item.get("done", false))
		if done:
			tile.add_child(UiKit.rule_ring(true, 104.0))
		else:
			tile.modulate = Color(1, 1, 1, 0.42)
		strip.add_child(tile)
		if done and Juice.motion_enabled():
			delay += 0.28
			var wait := tile.create_tween()
			wait.tween_interval(0.5 + delay)
			wait.tween_callback(func(): Juice.pop(tile, 0.34))
	return strip


## A soft line above the buttons, in the same warm voice as everything else,
## with nothing to press. The "next level" button is still right there and
## still the biggest thing on screen: this is a suggestion from somebody who
## has enjoyed the last twenty minutes, not a gate.
## Was that the last level of its world, and is every level in it done?
func _world_just_finished() -> bool:
	var world_id := str(GameManager.current_world_id)
	var levels: Array = GameData.get_levels_for_world(world_id)
	if levels.size() < 2:
		return false
	for entry in levels:
		var lid := str(entry.get("id", ""))
		if lid == "hero_studio":
			continue          # the free-play room is never "finished"
		if not bool(SaveManager.get_level_progress(lid).get("completed", false)):
			return false
	return true


func _rest_note() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var art: Control = UiKit.picture("moon", 46)
	if art != null:
		row.add_child(art)
	# The spoken line and the written line must be the SAME line -- a child
	# hearing one sentence and seeing another is more confused, not less.
	var key := Rest.line()
	var spoken := ["rest.done_today", "rest.stretch", "rest.come_back",
		"rest.well_played"].find(key)
	if spoken >= 0:
		AudioManager.say("rest_%d" % (spoken + 1))
	var words := UiKit.title(I18n.t(key), 30)
	words.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0))
	row.add_child(words)
	if Juice.motion_enabled():
		row.modulate.a = 0.0
		var t := row.create_tween()
		t.tween_interval(1.6)          # after the stars have had their moment
		t.tween_property(row, "modulate:a", 1.0, 0.6)
	return row


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
