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

	var greeting := UiKit.title_on_art(I18n.t("home.greeting"), 52)
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

	var rewards := UiKit.icon_button(I18n.t("home.rewards"), "star", Palette.ORANGE)
	rewards.pressed.connect(func(): SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn"))
	grid.add_child(rewards)

	var house := UiKit.icon_button(I18n.t("home.house"), "house", Palette.PURPLE)
	house.disabled = true
	house.tooltip_text = I18n.t("common.coming_soon")
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
	hint.add_theme_color_override("font_color", Palette.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 6)
	bar_box.add_child(hint)
	bar_box.add_child(_hold_bar)
	var bar_center := CenterContainer.new()
	bar_center.add_child(bar_box)
	root.add_child(bar_center)


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
