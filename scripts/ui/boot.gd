extends Control
## Splash. Waits for a deliberate tap rather than auto-advancing, so the game
## never starts moving before the child is looking at it.

var _prompt: Label


func _ready() -> void:
	# Breadcrumbs: the Output panel shows how far boot gets. If the window is
	# blank, the last line printed is the step that failed.
	print("[boot] 1 entering _ready")

	# The world first, with no dependencies beyond the drawing layer, so even a
	# total failure further down leaves a recognisable sky rather than engine
	# grey. There used to be a flat navy ColorRect here as the failsafe; it sat
	# in front of the world (scenery draws at a negative z so it can never
	# cover a button) and turned the splash screen solid navy.
	UiKit.world_background(self, "hero_city", "boot")
	print("[boot] 2 background ok")

	theme = UiKit.theme()
	print("[boot] 3 theme ok")

	# A soft dark wash across the lower half. Without it the title sits on
	# whatever part of the skyline happens to be behind it, and a lit window
	# lands in the middle of a letter.
	var wash := Shapes.gradient_quad(self, Vector2(-200, 300), Vector2(1700, 460),
		Color(0.05, 0.07, 0.16, 0.0), Color(0.05, 0.07, 0.16, 0.62))
	wash.z_index = -20

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 34)
	add_child(box)

	var hero := SkinnedCharacter.new()
	hero.skin = GameData.current_skin()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 300)
	holder.add_child(hero)
	hero.position = Vector2(640, 290)
	box.add_child(holder)
	hero.set_height(280.0)
	# The hero of light arrives from the sky -- the game's first moving thing
	# is its main character landing in front of you.
	hero.entrance(420.0, 0.35)
	print("[boot] 4 hero ok")

	var t := UiKit.title_on_art(I18n.t("app.title"), 72)
	box.add_child(t)
	# The title pops in and the hero's light flares once: the game says hello.
	if Juice.motion_enabled():
		t.resized.connect(func():
			t.pivot_offset = t.size / 2.0
			t.scale = Vector2(0.7, 0.7)
			var pop := t.create_tween()
			pop.tween_property(t, "scale", Vector2.ONE, 0.35)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		, CONNECT_ONE_SHOT)


	_prompt = UiKit.on_art(UiKit.title(I18n.t("boot.tap_to_start"), 40, Color(0.86, 0.93, 1.0)))
	box.add_child(_prompt)

	# Slow breathing pulse, not a flash.
	var tw := create_tween().set_loops()
	tw.tween_property(_prompt, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	print("[boot] 5 done")


func _gui_input(event: InputEvent) -> void:
	if UiKit.is_press(event):
		_start()


func _start() -> void:
	SceneManager.goto_home()
