extends LevelManager
## Keepy Uppy: don't let the balloon touch the ground.
##
## The signature game of the Bluey Park world, and the simplest physics toy
## in the whole box: one balloon, gravity set to "gentle", every tap punches
## it back up with a squash and a giggle of confetti. The drawn heeler puppy
## bounces along at the fence; the child's own hero cheers from the other
## side. Family game, family audience.
##
## House rules, as always:
##   * The balloon PLOPS, it never pops. A plop costs one accuracy star,
##     the puppy slumps for half a second, and a fresh balloon floats in.
##     Nothing is lost, nobody is out.
##   * Waiting costs nothing -- gravity here is slower than a six-year-old.
##
## Config: { "bounces": 8, "drift": 90 }. Challenge ranks add bounces and a
## little more sideways mischief, never more gravity.

const GRAVITY := 300.0
const MAX_FALL := 270.0
const BOUNCE_VY := -430.0
const BALLOON_R := 74.0

var _target_bounces := 8
var _drift := 90.0

var _play_area: Control
var _balloon: Node2D
var _hit: Button
var _velocity := Vector2.ZERO
var _wobble := 0.0
var _resting := false          # true between a plop and the next balloon
var _ground_y := 620.0
var _instruction: Label
var _progress: Label
var _hero: SkinnedCharacter
var _puppy: Node2D


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_target_bounces = int(config.get("bounces", 8))
	_drift = float(config.get("drift", 90.0))

	# Difficulty: the balloon wanders more and the goal is longer. Gravity
	# is left alone -- a faster fall is not harder, it is just crueller.
	_drift = harder(_drift, 1.30)
	_target_bounces = maxi(harder_i(_target_bounces, 3), 4)
	bump_target("correct", 3 * (difficulty() - NORMAL))

	# Challenge scaling: more bounces, a touch more sideways drift. The fall
	# speed never changes -- patience stays a winning strategy.
	var rank := challenge_rank()
	if rank > 0:
		bump_target("correct", mini(rank * 2, 10))
		_drift = minf(_drift + 10.0 * float(rank), 150.0)

	_build_scene(config)


func _build_scene(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	var stage: Stage = build_world(_play_area)
	_ground_y = stage.ground_y() if stage != null else Stage.ground_line()

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "keepy.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(240, 34)
	_instruction.size = Vector2(800, 52)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	# Wordless: the balloon, ringed green. Tap THAT.
	var picto: Control = UiKit.pictogram([{"icon": "balloon", "ok": true}], 72)
	picto.position = Vector2(240, 86)
	picto.size = Vector2(800, 76)
	_play_area.add_child(picto)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_progress)
	_progress.position = Vector2(1050, 40)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()

	# The family: hero on the left, puppy on the right, balloon between them.
	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(200, _ground_y)
	_play_area.add_child(_hero)
	_hero.set_height(240.0)

	_puppy = preload("res://scripts/world/puppy_art.gd").new()
	_puppy.position = Vector2(1070, _ground_y)
	_play_area.add_child(_puppy)
	_puppy.set_height(235.0)

	_spawn_balloon(true)


## The balloon: drawn once, moved by _process, tapped through an invisible
## button that rides on it (a Node2D cannot hear fingers; a Control can).
func _spawn_balloon(first: bool) -> void:
	_balloon = Node2D.new()
	_balloon.position = Vector2(640, 210) if first \
		else Vector2(randf_range(420.0, 860.0), 190.0)
	_play_area.add_child(_balloon)
	var rng := Shapes.rng_for("keepy%d" % result.mistakes)
	var red := Color(0.92, 0.34, 0.36)
	var string := Line2D.new()
	string.points = PackedVector2Array([Vector2(0, 66.0), Vector2(rng.randf_range(-8.0, 8.0), 128.0)])
	string.width = 3.0
	string.default_color = Color(0.40, 0.30, 0.24, 0.8)
	string.antialiased = true
	_balloon.add_child(string)
	Shapes.lit(_balloon, Shapes.oval_points(Vector2.ZERO, Vector2(BALLOON_R * 0.88, BALLOON_R), 22), red, 1.0)
	Shapes.fill(_balloon, Shapes.oval_points(Vector2(-22.0, -28.0), Vector2(17.0, 22.0), 12),
		Color(1, 1, 1, 0.45), 0.0)
	Shapes.fill(_balloon, PackedVector2Array([
		Vector2(-10.0, 74.0), Vector2(10.0, 74.0), Vector2(0.0, 58.0),
	]), red.darkened(0.14), 0.0)

	_hit = Button.new()
	_hit.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		_hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# Generous: half again the balloon, because the balloon is MOVING and the
	# finger aiming at it is six years old.
	_hit.size = Vector2(BALLOON_R * 3.0, BALLOON_R * 3.2)
	_hit.pressed.connect(_bounce)
	_play_area.add_child(_hit)

	_velocity = Vector2(randf_range(-40.0, 40.0), first if false else -60.0)
	_velocity.y = -60.0
	_wobble = randf() * TAU
	_resting = false
	if Juice.motion_enabled() and not first:
		_balloon.scale = Vector2(0.3, 0.3)
		var t := _balloon.create_tween()
		t.tween_property(_balloon, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	super._process(delta)
	if _finished or _balloon == null or not is_instance_valid(_balloon) or _resting:
		return

	_wobble += delta * 1.7
	_velocity.y = minf(_velocity.y + GRAVITY * delta, MAX_FALL)
	_velocity.x += sin(_wobble) * _drift * delta * 0.35
	_velocity.x = clampf(_velocity.x, -170.0, 170.0)
	_balloon.position += _velocity * delta

	# The walls bat it back in -- the game never drifts off screen.
	if _balloon.position.x < 130.0 and _velocity.x < 0.0:
		_velocity.x = absf(_velocity.x) * 0.9
	elif _balloon.position.x > 1150.0 and _velocity.x > 0.0:
		_velocity.x = -absf(_velocity.x) * 0.9

	_hit.position = _balloon.position - _hit.size / 2.0

	if _balloon.position.y > _ground_y - BALLOON_R * 0.55:
		_plop()


## The tap: balloon squashes, leaps, sheds a little confetti; the puppy
## bounces with it; the counter climbs. The whole game is this one verb
## feeling good.
func _bounce() -> void:
	if _finished or _resting:
		return
	_velocity.y = BOUNCE_VY + randf_range(-40.0, 20.0)
	_velocity.x += randf_range(-90.0, 90.0)
	AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % (randi() % 5 + 1))
	Juice.burst(_play_area, _balloon.position, 8)
	if Juice.motion_enabled():
		var t := _balloon.create_tween()
		t.tween_property(_balloon, "scale", Vector2(1.18, 0.82), 0.09)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_balloon, "scale", Vector2.ONE, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _puppy != null and _puppy.has_method("hop"):
		_puppy.hop()
	_hero.celebrate()
	score_correct()
	_update_progress()


## The plop. Soft landing, sighing puppy, one star of accuracy, and a fresh
## balloon floats in a moment later. Never a pop: a pop is a small tragedy
## at six, and this is a game about keeping joy airborne.
func _plop() -> void:
	_resting = true
	score_mistake()
	_instruction.text = I18n.t("keepy.plop")
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	if _puppy != null and _puppy.has_method("droop"):
		_puppy.droop()
	var old_balloon := _balloon
	var old_hit := _hit
	if is_instance_valid(old_hit):
		old_hit.queue_free()
	if Juice.motion_enabled() and is_instance_valid(old_balloon):
		var t := old_balloon.create_tween()
		t.tween_property(old_balloon, "scale", Vector2(1.3, 0.5), 0.16)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(old_balloon, "modulate:a", 0.0, 0.5)
		t.tween_callback(old_balloon.queue_free)
	elif is_instance_valid(old_balloon):
		old_balloon.queue_free()

	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if _finished or not is_inside_tree():
			return
		_instruction.text = I18n.t("keepy.instruction")
		_spawn_balloon(false)
	)


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", _target_bounces)]
