extends Control
## Splash. Waits for a deliberate tap rather than auto-advancing, so the game
## never starts moving before the child is looking at it.

var _prompt: Label


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.background(self, Color(0.08, 0.12, 0.22))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	add_child(box)

	var hero := SkinnedCharacter.new()
	hero.scale = Vector2(2.0, 2.0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 240)
	holder.add_child(hero)
	hero.position = Vector2(640, 160)
	box.add_child(holder)

	var t := UiKit.title(I18n.t("app.title"), 72)
	t.add_theme_color_override("font_color", Color(1, 1, 1))
	box.add_child(t)

	_prompt = UiKit.title(I18n.t("boot.tap_to_start"), 40)
	_prompt.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	box.add_child(_prompt)

	# Slow breathing pulse, not a flash.
	var tw := create_tween().set_loops()
	tw.tween_property(_prompt, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_start()
	elif event is InputEventMouseButton and event.pressed:
		_start()


func _start() -> void:
	SceneManager.goto_home()
