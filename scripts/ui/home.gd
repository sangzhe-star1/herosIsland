extends Control
## Child home screen. Four destinations, all large, all reachable in one tap
## except the parent door, which is deliberately hard for a child to open.

const PARENT_HOLD_SECONDS := 3.0

var _hold_time := 0.0
var _holding := false
var _parent_button: Button
var _hold_bar: ProgressBar


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Palette.SKY, "res://assets/backgrounds/home.png")

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	var greeting := UiKit.title_on_art(I18n.t("home.greeting"), 58)
	root.add_child(greeting)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 24)
	var center := CenterContainer.new()
	center.add_child(grid)
	root.add_child(center)

	var play := UiKit.icon_button(I18n.t("home.play"), "flag", Palette.GREEN)
	play.pressed.connect(_on_play)
	grid.add_child(play)
	UiKit.breathe(play)

	var rewards := UiKit.icon_button(I18n.t("home.rewards"), "star", Palette.ORANGE)
	rewards.pressed.connect(func(): SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn"))
	grid.add_child(rewards)

	var house := UiKit.icon_button(I18n.t("home.house"), "house", Palette.PURPLE)
	house.pressed.connect(func(): SceneManager.goto_scene("res://scenes/house/HeroHouse.tscn"))
	grid.add_child(house)

	# Press-and-hold, then an arithmetic gate on the next screen.
	# The button itself counts down, so an adult can see the hold is working
	# while a child who taps once still gets nowhere.
	_parent_button = UiKit.icon_button(I18n.t("home.parent"), "gear", Palette.SLATE)
	_parent_button.button_down.connect(_begin_hold)
	_parent_button.button_up.connect(_cancel_hold)
	grid.add_child(_parent_button)

	_hold_bar = ProgressBar.new()
	_hold_bar.max_value = PARENT_HOLD_SECONDS
	_hold_bar.show_percentage = false
	_hold_bar.custom_minimum_size = Vector2(280, 16)
	_hold_bar.modulate.a = 0.0
	var hint := Label.new()
	hint.text = I18n.t("parent.hold_hint")
	hint.add_theme_font_size_override("font_size", 22)
	# Over painted night art, soft ink vanishes; this is aimed at the adult
	# but still has to be findable.
	hint.add_theme_color_override("font_color", Color(0.84, 0.89, 1.0, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 6)
	bar_box.add_child(hint)
	bar_box.add_child(_hold_bar)
	var bar_center := CenterContainer.new()
	bar_center.add_child(bar_box)
	root.add_child(bar_center)

	_build_hero()
	_build_treasure_chip()


## Stars and coins, worn like a badge in the corner. BabyBus keeps the
## child's collectibles visible on every hub screen; this is that, and
## tapping it opens My Rewards -- the number IS the button.
func _build_treasure_chip() -> void:
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.26, 0.78)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	chip.add_theme_stylebox_override("normal", style)
	chip.add_theme_stylebox_override("hover", style)
	chip.add_theme_stylebox_override("pressed", style)
	chip.pressed.connect(func(): SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hero rank first: the number that only ever grows.
	var rank_icon: Control = UiKit.picture("shield", 40)
	if rank_icon != null:
		row.add_child(rank_icon)
		var rank_label := UiKit.title("%d" % SaveManager.hero_level(), 30, Palette.ON_COLOR)
		row.add_child(rank_label)

	var star_icon: Control = UiKit.picture("star", 40)
	if star_icon != null:
		row.add_child(star_icon)
	var star_count := UiKit.title("%d" % SaveManager.total_stars(), 30, Palette.ON_COLOR)
	row.add_child(star_count)

	var coin_icon: Control = UiKit.picture("coin", 40)
	if coin_icon != null:
		row.add_child(coin_icon)
	var coin_count := UiKit.title("%d" % int(SaveManager.data["rewards"]["coins"]), 30, Palette.ON_COLOR)
	row.add_child(coin_count)

	chip.add_child(row)
	add_child(chip)
	# Sized after layout, then pinned to the top-right corner.
	await get_tree().process_frame
	if is_instance_valid(chip) and is_instance_valid(row):
		chip.size = row.size + Vector2(32, 20)
		row.position = Vector2(16, 10)
		chip.position = Vector2(1280.0 - chip.size.x - 28.0, 24)


## The chosen hero, standing at home. Tapping them earns a little celebration
## -- it does nothing, costs nothing, and cannot be wrong, which is exactly the
## kind of button a six-year-old presses forty times with total satisfaction.
## It is also how the Hero House choice stays visible: whoever was picked is
## whoever is standing here.
func _build_hero() -> void:
	var holder := Control.new()
	holder.position = Vector2(50, 310)
	holder.size = Vector2(240, 350)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)

	# A soft spotlight pool behind the hero -- the BabyBus/Toca trick of making
	# the character the warmest, brightest thing on the screen so the eye (and
	# the finger) goes there first. A radial gradient, not a polygon: the glow
	# must FADE, or it reads as a grey egg instead of light.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.96, 0.8, 0.30))
	gradient.set_color(1, Color(1.0, 0.96, 0.8, 0.0))
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(0.5, 0.0)
	glow_texture.width = 256
	glow_texture.height = 256
	var glow := Sprite2D.new()
	glow.texture = glow_texture
	glow.position = Vector2(120, 170)
	glow.scale = Vector2(1.35, 1.6)
	holder.add_child(glow)

	var hero := SkinnedCharacter.new()
	hero.skin = GameData.current_skin()
	hero.position = Vector2(120, 245)
	hero.scale = Vector2(2.0, 2.0)
	holder.add_child(hero)
	Juice.idle_bob(hero)

	# Every so often the hero cheers on their own -- the screen invites play
	# instead of waiting for it. Skipped entirely under reduce-motion: that
	# setting means "calm screen", including from the hero.
	var wave_timer := Timer.new()
	wave_timer.wait_time = 9.0
	wave_timer.autostart = true
	holder.add_child(wave_timer)
	wave_timer.timeout.connect(func():
		if Juice.motion_enabled() and is_instance_valid(hero):
			hero.celebrate()
	)

	holder.gui_input.connect(func(event: InputEvent):
		var pressed: bool = (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed:
			hero.celebrate()
			Juice.burst(holder, Vector2(120, 150), 14)
			AudioManager.play_sfx("res://assets/audio/star.ogg")
	)




func _begin_hold() -> void:
	_holding = true
	_hold_time = 0.0
	_hold_bar.value = 0.0
	_hold_bar.modulate.a = 1.0


func _process(delta: float) -> void:
	if not _holding:
		return
	_hold_time += delta
	_hold_bar.modulate.a = 1.0
	_hold_bar.value = _hold_time

	var remaining := int(ceil(PARENT_HOLD_SECONDS - _hold_time))
	_parent_button.text = "%s %d" % [I18n.t("home.parent"), maxi(remaining, 1)]

	if _hold_time >= PARENT_HOLD_SECONDS:
		_reset_hold()
		SceneManager.goto_scene("res://scenes/parent/ParentCenter.tscn")


func _cancel_hold() -> void:
	_reset_hold()


func _reset_hold() -> void:
	_holding = false
	_hold_time = 0.0
	_hold_bar.value = 0.0
	_hold_bar.modulate.a = 0.0
	if _parent_button != null:
		_parent_button.text = I18n.t("home.parent")


func _on_play() -> void:
	if GameManager.daily_limit_reached():
		_show_break_message()
		return
	SceneManager.goto_world_map()


## Advisory only. There is no lock and no countdown -- it is a suggestion the
## child can dismiss, and the real limit is the parent in the room.
func _show_break_message() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = I18n.t("limit.title")
	dialog.dialog_text = I18n.t("limit.body")
	dialog.ok_button_text = I18n.t("common.continue")
	add_child(dialog)
	dialog.confirmed.connect(func(): SceneManager.goto_world_map())
	dialog.popup_centered()
