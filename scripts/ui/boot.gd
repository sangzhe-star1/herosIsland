extends Control
## Splash. Waits for a deliberate tap rather than auto-advancing, so the game
## never starts moving before the child is looking at it.

var _prompt: Label


func _ready() -> void:
	# Breadcrumbs: the Output panel shows how far boot gets. If the window is
	# blank, the last line printed is the step that failed.
	print("[boot] 1 entering _ready")

	# Background first, and with no dependencies, so that even a total failure
	# further down leaves a recognisable navy screen rather than engine grey.
	var bg := ColorRect.new()
	bg.color = Palette.DUSK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	print("[boot] 2 background ok")

	theme = UiKit.theme()
	print("[boot] 3 theme ok")

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
	print("[boot] 4 hero ok")

	var t := UiKit.title_on_art(I18n.t("app.title"), 72)
	box.add_child(t)

	_prompt = UiKit.title(I18n.t("boot.tap_to_start"), 40, Color(0.78, 0.88, 1.0))
	box.add_child(_prompt)

	# Slow breathing pulse, not a flash.
	var tw := create_tween().set_loops()
	tw.tween_property(_prompt, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	print("[boot] 5 done")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_start()
	elif event is InputEventMouseButton and event.pressed:
		_start()


func _start() -> void:
	SceneManager.goto_home()
