extends Node2D
## 换你来数: the other half of 一二三木头人. After he has crept up on the
## friend's quiet bed, the friend gets a turn. He holds the eye button -- eyes
## shut, counting -- and the friend tiptoes toward him; he lets go and turns
## round, and the friend freezes mid-step in a silly pose. When the friend has
## crept all the way up, it tags him and gives him one of its crops.
##
## The same red lines as the first half: no luck (it walks only while he
## holds), no way to lose (letting go only pauses it), and nothing taken from
## anybody. Once per share cycle, recorded by the screen that owns this node.

const HOLD_SECONDS := 2.4

var progress := 0.0
var holding := false
var done := false
var model: Node3D
var start_at := Vector3.ZERO
var end_at := Vector3.ZERO
var on_done: Callable

var _button: Button
var _veil: ColorRect
var _counting: Label
var _freeze: Label
var _was_holding := false


func setup(friend_model: Node3D, from: Vector3, to: Vector3, button_at: Vector2,
		view: Vector2, done_callback: Callable) -> void:
	model = friend_model
	start_at = from
	end_at = to
	on_done = done_callback
	if model != null and is_instance_valid(model):
		model.position = start_at
		model.rotation_degrees = Vector3.ZERO

	# Eyes shut: the world dims a little, so letting go is a real "turn round".
	_veil = ColorRect.new()
	_veil.name = "FriendTagVeil"
	_veil.color = Color(0.05, 0.08, 0.18, 0.0)
	_veil.size = view
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_counting = UiKit.title_on_art(I18n.t("garden.friend_tag_counting"), 34)
	_counting.name = "FriendTagCounting"
	_counting.position = Vector2(view.x * 0.5 - 220.0, view.y * 0.5 - 30.0)
	_counting.size = Vector2(440.0, 60.0)
	_counting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counting.visible = false
	add_child(_counting)

	_button = Button.new()
	_button.name = "FriendTagButton"
	_button.focus_mode = Control.FOCUS_NONE
	_button.size = Vector2(124.0, 124.0)
	_button.position = button_at
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.88, 0.95)
	style.border_color = Color(0.98, 0.78, 0.30)
	style.set_border_width_all(6)
	style.set_corner_radius_all(62)
	for state in ["normal", "hover", "pressed", "disabled"]:
		_button.add_theme_stylebox_override(state, style)
	_button.button_down.connect(func(): holding = true)
	_button.button_up.connect(func(): holding = false)
	add_child(_button)
	# "1 2 3" is the game's own name and readable before words are: the
	# rendered eye icon read as a grey disc at this size.
	var digits := UiKit.title("1 2 3", 34, Color(0.62, 0.40, 0.08))
	digits.name = "FriendTagDigits"
	digits.position = Vector2(0.0, 26.0)
	digits.size = Vector2(124.0, 44.0)
	digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	digits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(digits)
	var caption := UiKit.title(I18n.t("garden.friend_tag_button"), 18, Color(0.42, 0.32, 0.18))
	caption.position = Vector2(0.0, 72.0)
	caption.size = Vector2(124.0, 28.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(caption)
	UiKit.breathe(_button, 0.05, 0.5)


## Separate from _process so a probe can step without waiting real seconds.
func advance(delta: float) -> void:
	if done:
		return
	# A swallowed release must not leave the friend walking on its own.
	if holding and _button != null and not _button.is_pressed():
		holding = false
	if holding:
		progress = minf(1.0, progress + maxf(delta, 0.0) / HOLD_SECONDS)
	_show_state(delta)
	if progress >= 1.0:
		_finish()


func _process(delta: float) -> void:
	advance(delta)


func _show_state(delta: float) -> void:
	if _veil != null:
		_veil.color.a = 0.32 if holding else 0.0
	if _counting != null:
		_counting.visible = holding
	if model != null and is_instance_valid(model):
		model.position = start_at.lerp(end_at, progress)
		if holding:
			# Tiptoeing: a little bob, facing him.
			model.rotation_degrees = Vector3(0.0, 0.0,
				sin(progress * 40.0) * 4.0 if Juice.motion_enabled() else 0.0)
		elif _was_holding:
			# Caught mid-step: freeze in a silly lean.
			model.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	if _was_holding and not holding and progress < 1.0:
		_say_freeze()
	_was_holding = holding


func _say_freeze() -> void:
	if _freeze != null and is_instance_valid(_freeze):
		return
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	_freeze = UiKit.title_on_art(I18n.t("garden.friend_tag_freeze"), 30)
	_freeze.name = "FriendTagFreeze"
	_freeze.position = Vector2(_button.position.x - 80.0, _button.position.y - 56.0)
	_freeze.size = Vector2(284.0, 44.0)
	_freeze.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_freeze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_freeze)
	# Owned by the label, so leaving the farm cannot strand a callback.
	var linger := _freeze.create_tween()
	linger.tween_interval(1.0)
	linger.tween_callback(_freeze.queue_free)


func _finish() -> void:
	done = true
	holding = false
	if _veil != null:
		_veil.color.a = 0.0
	if _counting != null:
		_counting.visible = false
	if _button != null and is_instance_valid(_button):
		_button.queue_free()
		_button = null
	if model != null and is_instance_valid(model):
		model.rotation_degrees = Vector3.ZERO
		if Juice.motion_enabled():
			var hop := model.create_tween()
			hop.tween_property(model, "position:y", 0.4, 0.14)
			hop.tween_property(model, "position:y", 0.0, 0.24) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on_done.is_valid():
		on_done.call()
