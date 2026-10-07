extends LevelManager
## "Find the things." The looking game.
##
## A scene full of stuff, some of it the thing you want, and a child who has
## to LOOK rather than react. It is the quietest template on the island and
## the one a tired six-year-old will pick, because nothing is chasing them and
## nothing is ticking.
##
## The whole design is in what happens when they cannot find it:
##
##   after 8 seconds   the missing one twinkles, once
##   after 16 seconds  it leans out of its hiding place and goes back in
##   after 24 seconds  a finger points straight at it
##
## and at no point does anything say they were slow. There is no timer, no
## score, and no failure -- the level ends when the last one is found, and the
## only question is how much help it took, which is the third star.
##
## Where things hide comes from a hand-written list per level, shuffled by
## `VariantPicker`. A second play hides them somewhere else; it never hides
## them somewhere impossible.

const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")
## By path, not by class name. A newer class_name is invisible to any run
## whose editor has not rescanned, and an unknown identifier is a PARSE error
## in GDScript -- the whole level would fail to open rather than degrade.
const Props := preload("res://scripts/adventure/props.gd")

## Hiding places, in screen space, written so a child's eye can travel between
## them: never two in the same corner, never one under the HUD.
const SPOTS := [
	Vector2(180, 470), Vector2(330, 330), Vector2(520, 500), Vector2(690, 360),
	Vector2(860, 480), Vector2(1030, 340), Vector2(1140, 520), Vector2(260, 600),
	Vector2(620, 620), Vector2(920, 610), Vector2(430, 420), Vector2(760, 470),
]

var _field: Control
var _hud: Control
var _hints: Hints
var _picker: Picker
var _targets: Array = []          # [{node, at, found}]
var _decoys: Array = []
var _bonus: Dictionary = {}       # the extra thing worth star two
var _found := 0
var _wanted := 5
var _tally: Control
var _tally_pips: Array = []
var _helped := false
var _icon := "orb"
var _finished_level := false


func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_icon = str(config.get("icon", "orb"))
	_wanted = clampi(Hints.extra_things(harder_i(int(config.get("count", 5)), 1)), 3, 8)

	var stage: Stage = build_world(self, 0.30)      # the scene is the puzzle: quiet it a little
	if ResourceLoader.exists("res://assets/scenes_3d/park_observatory.glb"):
		if stage != null:
			stage.visible = false
		_setup_3d_stage()
	_field = UiKit.play_area(self, true)
	_field.gui_input.connect(_on_tap)

	_scatter(config)
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_twinkle, _peek, _point_at_it)
	_hints.escalated.connect(func(level: int):
		if level >= 1:
			_helped = true)

	_play_tutorial()


# --- the scene ---------------------------------------------------------------

func _scatter(config: Dictionary) -> void:
	# The hiding places, put on the screen the child is actually holding. On a
	# 4:3 tablet that is 1280x960 and the world's ground plane has moved down
	# with it, so raw design spots would crowd every hidden thing into the top
	# three quarters and leave the nearest quarter of the field empty.
	#
	# Fitted BEFORE the picker sees them, not after, so which spots get chosen
	# is still decided by the level's seed alone: same level, same hiding
	# places, whatever the child is holding.
	var fitted: Array = []
	for spot in SPOTS:
		fitted.append(Fit.at(_field, spot))
	var places: Array = _picker.spots(fitted, _wanted + 4, 150.0)
	# The things to find first, so they get the best-spread positions.
	for i in range(_wanted):
		var at: Vector2 = places[i]
		var node := _draw_thing(_icon, at, true)
		_targets.append({"node": node, "at": at, "found": false})

	# Decoys: same family, wrong thing. Without them the level is "tap the
	# only five objects on screen", which is not looking, it is counting.
	var decoy_icons: Array = config.get("decoys", ["rock", "leaf", "spark"])
	for i in range(_wanted, mini(places.size(), _wanted + 4)):
		var name := str(_picker.one(decoy_icons))
		_decoys.append(_draw_thing(name, places[i], false))

	# The bonus: one small friend somewhere, worth the second star. Drawn
	# smaller and never in the same place twice.
	var bonus_at: Vector2 = _picker.one(fitted)
	var bonus := _draw_thing(str(config.get("bonus", "paw")),
		bonus_at + Vector2(0, -40.0), false)
	bonus.scale = Vector2(0.7, 0.7)
	_bonus = {"node": bonus, "at": bonus_at + Vector2(0, -40.0), "found": false}


## Everything in the scene is drawn the same way, target or decoy, or the
## child could tell them apart without looking at what they are.
func _draw_thing(icon_name: String, at: Vector2, target: bool) -> Node2D:
	var node := Node2D.new()
	node.position = at
	_field.add_child(node)

	# 3D Perspective scaling: objects far back on the hill/gazebo are naturally smaller
	var depth_factor: float = clampf((at.y - 300.0) / 340.0, 0.0, 1.0)
	var p_scale: float = lerpf(0.72, 1.08, depth_factor)

	# 3D Ground contact shadow on grass/boardwalk
	Shapes.ground_shadow(node, Vector2(0, 20.0 * p_scale), 68.0 * p_scale, 0.32)

	var art: Control = UiKit.picture(icon_name, int(76.0 * p_scale))
	if art != null:
		var half_size: float = 38.0 * p_scale
		art.position = Vector2(-half_size, -half_size)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(art)

	# Everything breathes a little. A scene where only the answers move is a
	# scene with the answers written on it.
	if Juice.motion_enabled():
		var t := node.create_tween().set_loops()
		var period: float = _picker.number(1.6, 2.6)
		t.tween_property(node, "scale", Vector2(1.05, 1.05), period * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(node, "scale", Vector2.ONE, period * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return node


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UiKit.theme()
	layer.add_child(_hud)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_hud.add_child(back)

	var card_w := float(_wanted) * 68.0 + 32.0
	var tally_card := Panel.new()
	tally_card.position = Vector2(640 - card_w * 0.5, 20)
	tally_card.size = Vector2(card_w, 64)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.14, 0.24, 0.72)
	card_style.set_corner_radius_all(24)
	card_style.border_width_top = 1
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.42, 0.58, 0.82, 0.45)
	card_style.shadow_color = Color(0, 0, 0, 0.35)
	card_style.shadow_size = 8
	tally_card.add_theme_stylebox_override("panel", card_style)
	tally_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(tally_card)

	# The task, as a row of empty rings that fill in. No numbers: a child can
	# see "three left" faster than they can read it.
	_tally = HBoxContainer.new()
	_tally.add_theme_constant_override("separation", 14)
	_tally.position = Vector2(16, 5)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally_card.add_child(_tally)
	for i in range(_wanted):
		var pip := Control.new()
		pip.custom_minimum_size = Vector2(54, 54)
		pip.pivot_offset = Vector2(27, 27)
		var pad := Node2D.new()
		pip.add_child(pad)
		Shapes.fill(pad, Shapes.circle_points(Vector2(27, 27), 25.0, 22),
			Color(0.05, 0.09, 0.20, 0.5), 0.0)
		var art: Control = UiKit.picture(_icon, 34)
		if art != null:
			art.position = Vector2(10, 10)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.add_child(art)
		pip.modulate = Color(1, 1, 1, 0.35)
		_tally.add_child(pip)
		_tally_pips.append(pip)


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	var first: Vector2 = (_targets[0]["at"] as Vector2) if not _targets.is_empty() \
		else Vector2(640, 400)
	demo.add_step(first, first, 1.2)
	demo.add_step(Vector2(640, 52), Vector2(640, 52), 0.9)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo.finished.connect(func():
		_field.mouse_filter = Control.MOUSE_FILTER_STOP)
	demo.play()


# --- looking ------------------------------------------------------------------

func _on_tap(event: InputEvent) -> void:
	if _finished_level or not UiKit.is_press(event):
		return
	var at: Vector2 = _press_position(event)
	# Generous: a 96 px radius round a 76 px picture, because a thumb covers
	# what it is pointing at.
	for target in _targets:
		if bool(target["found"]) or (target["at"] as Vector2).distance_to(at) > 96.0:
			continue
		_take(target)
		return
	if not _bonus.is_empty() and not bool(_bonus["found"]) \
			and (_bonus["at"] as Vector2).distance_to(at) < 88.0:
		_take_bonus()
		return
	for decoy in _decoys:
		if not is_instance_valid(decoy) or decoy.position.distance_to(at) > 90.0:
			continue
		# Tapping the wrong thing is a shrug: it wobbles and says no. It is
		# not a mistake, because looking IS the game and looking costs nothing.
		Juice.nudge(decoy)
		AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
		_hints.missed()
		return


func _press_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2.ZERO


func _take(target: Dictionary) -> void:
	target["found"] = true
	_found += 1
	score_correct()
	_hints.progress()
	var node: Node2D = target["node"]
	if is_instance_valid(node):
		Juice.burst(_field, node.position, 18)
		# It flies to its ring in the tally, so the child sees WHERE it went.
		var pip: Control = _tally_pips[_found - 1]
		var to: Vector2 = pip.global_position + Vector2(27, 27)
		if Juice.motion_enabled():
			var t := node.create_tween()
			t.tween_property(node, "position", to, 0.42)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(node, "scale", Vector2(0.4, 0.4), 0.42)
			t.tween_callback(node.queue_free)
		else:
			node.queue_free()
		pip.modulate = Color(1, 1, 1, 1.0)
		Juice.pop(pip, 0.3)
	AudioManager.play_sfx("res://assets/audio/found.ogg")
	if _found >= _wanted:
		_finish()


func _take_bonus() -> void:
	_bonus["found"] = true
	var node: Node2D = _bonus["node"]
	if is_instance_valid(node):
		Juice.burst(_field, node.position, 26)
		Juice.shockwave(_field, node.position, 160.0, Color(1.0, 0.86, 0.42))
		node.queue_free()
	AudioManager.play_sfx("res://assets/audio/sparkle.ogg")


# --- the three levels of help ---------------------------------------------------

func _next_missing() -> Dictionary:
	for target in _targets:
		if not bool(target["found"]):
			return target
	return {}


## Level one: a twinkle. Nothing is said and nothing moves -- if the child was
## already looking in the right place, this is all they needed.
func _twinkle() -> void:
	var target := _next_missing()
	if target.is_empty():
		return
	var node: Node2D = target["node"]
	if is_instance_valid(node):
		Juice.pop(node, 0.26)
		Juice.burst(_field, node.position, 6, )


## Level two: it leans out and goes back in. Now it has moved, which the eye
## catches even when it is looking somewhere else entirely.
func _peek() -> void:
	var target := _next_missing()
	if target.is_empty():
		return
	var node: Node2D = target["node"]
	if not is_instance_valid(node) or not Juice.motion_enabled():
		return
	var home: Vector2 = target["at"]
	var t := node.create_tween()
	t.tween_property(node, "position", home + Vector2(0, -34.0), 0.34)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", home, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	Juice.pop(node, 0.2)


## Level three: point at it. Not a hint any more -- an answer, given without
## comment, because a child who has looked for half a minute has earned it.
func _point_at_it() -> void:
	var target := _next_missing()
	if target.is_empty():
		return
	var hand := Props.hint_hand(_field)
	# Props.hint_hand is contact-anchored: its fingertip, not an arbitrary
	# corner of the picture, belongs on the answer.
	hand.position = target["at"] as Vector2
	var node: Node2D = target["node"]
	if is_instance_valid(node):
		Shapes.glow(node, Vector2.ZERO, 150.0, Color(1.0, 0.94, 0.55), 4, 0.5)
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(hand):
			hand.queue_free())


func _finish() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	result.reached_goal = true
	result.found_hidden = not _bonus.is_empty() and bool(_bonus["found"])
	result.clean_run = not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	Juice.burst(_field, Vector2(640, 360), 40)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(1.3).timeout
	complete_level()


func _setup_3d_stage() -> void:
	var glb_path := "res://assets/scenes_3d/park_observatory.glb"
	if not ResourceLoader.exists(glb_path):
		return
	var vp_container := SubViewportContainer.new()
	vp_container.name = "ParkObservatory3DContainer"
	vp_container.stretch = true
	vp_container.custom_minimum_size = Vector2(1280, 720)
	vp_container.size = Vector2(1280, 720)
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp_container.z_index = -50

	var vp := SubViewport.new()
	vp.name = "SubViewport"
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(1280, 720)
	vp_container.add_child(vp)

	var world_root := Node3D.new()
	world_root.name = "World3D"
	vp.add_child(world_root)

	var glb_scene: PackedScene = load(glb_path)
	if glb_scene != null:
		var glb_inst: Node = glb_scene.instantiate()
		world_root.add_child(glb_inst)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.78, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.78, 0.72)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.18

	var env_node := WorldEnvironment.new()
	env_node.environment = env
	world_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -25.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.shadow_bias = 0.03
	world_root.add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 6.2, 11.8)
	cam.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	cam.fov = 38.0
	cam.current = true
	world_root.add_child(cam)

	add_child(vp_container)
	move_child(vp_container, 0)

