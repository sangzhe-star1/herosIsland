extends LevelManager
## Collection template: things drift down, tap the right ones.
##
## Powers three levels from one file via each level's "config" block:
##   hero_city_01  collect every orb                (no hazards)
##   hero_city_02  collect orbs, leave the rocks    (hazards)
##   hero_city_03  collect only the tower's colour  (colour matching)
##
## Missing an orb costs nothing. Only tapping the wrong thing is a mistake, so
## a slow child is never punished for being slow -- a fast one just finishes
## sooner. That distinction matters a lot at this age.

const SPAWN_MARGIN := 140.0
const ORB_SIZE := Vector2(110, 110)
const DESPAWN_Y := 760.0
const COLOR_SWITCH_EVERY := 3

var _spawn_interval := 1.0
var _fall_speed := 130.0
var _orb_colors: Array = []
var _hazard_ratio := 0.0
var _color_target := false

var _spawn_timer := 0.0
var _things: Array = []            # [{node, speed, hazard, color_index, drift}]
var _required_color_index := 0

var _play_area: Control
var _progress: Label
var _instruction: Label
var _hero: SkinnedCharacter
var _tower_light: Panel


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_spawn_interval = float(config.get("spawn_interval", 1.0))
	_fall_speed = float(config.get("fall_speed", 130.0))
	_orb_colors = (config.get("orb_colors", ["#ffd23c"]) as Array).duplicate()
	_hazard_ratio = clampf(float(config.get("hazard_ratio", 0.0)), 0.0, 0.8)
	_color_target = bool(config.get("color_target", false))

	_build_scene(config)
	_spawn_timer = 0.4
	if _color_target:
		_pick_required_color()


# --- construction -------------------------------------------------------

func _build_scene(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	var bg := ColorRect.new()
	bg.color = Color.from_string(str(config.get("background", "#101c33")), Color(0.06, 0.11, 0.2))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(bg)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "collect.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 36)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_progress.position = Vector2(1020, 40)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()

	# The hero stands at the bottom and, in colour-matching levels, wears the
	# answer on their chest -- the core light IS the instruction for a child
	# who cannot read the label above it.
	_hero = SkinnedCharacter.new()
	_hero.skin = _load_skin()
	_hero.position = Vector2(150, 620)
	_hero.scale = Vector2(1.3, 1.3)
	add_child(_hero)

	if _color_target:
		_tower_light = Panel.new()
		_tower_light.size = Vector2(120, 120)
		_tower_light.position = Vector2(80, 110)
		_tower_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_area.add_child(_tower_light)


func _load_skin() -> CharacterSkin:
	var character_id: String = SaveManager.get_profile().get("character_id", "light_hero")
	var entry: Dictionary = GameData.characters.get("characters", {}).get(character_id, {})
	var path: String = entry.get("skin", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_tick_spawn(delta)
	_tick_things(delta)


func _tick_spawn(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = _spawn_interval * randf_range(0.8, 1.25)
	_spawn_thing()


func _spawn_thing() -> void:
	var hazard := randf() < _hazard_ratio
	var color_index := randi() % maxi(_orb_colors.size(), 1)

	var node := Panel.new()
	node.size = ORB_SIZE
	node.custom_minimum_size = ORB_SIZE
	node.pivot_offset = ORB_SIZE / 2.0
	node.position = Vector2(
		randf_range(SPAWN_MARGIN, 1280.0 - SPAWN_MARGIN - ORB_SIZE.x), -ORB_SIZE.y
	)
	node.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	if hazard:
		# Hazards are a different colour AND a different shape, never colour
		# alone, so a colour-blind child can still tell them apart.
		style.bg_color = Color(0.29, 0.30, 0.34)
		style.set_corner_radius_all(6)
		style.border_width_top = 6
		style.border_color = Color(0.18, 0.19, 0.22)
	else:
		style.bg_color = _color_at(color_index)
		style.set_corner_radius_all(int(ORB_SIZE.x / 2.0))
		style.shadow_color = style.bg_color
		style.shadow_color.a = 0.45
		style.shadow_size = 14
	node.add_theme_stylebox_override("panel", style)

	var thing := {
		"node": node,
		"speed": _fall_speed * randf_range(0.85, 1.2),
		"hazard": hazard,
		"color_index": color_index,
		"drift": randf_range(-24.0, 24.0),
		"phase": randf() * TAU,
	}
	node.gui_input.connect(_on_thing_input.bind(thing))
	_play_area.add_child(node)
	_things.append(thing)


func _tick_things(delta: float) -> void:
	var survivors: Array = []
	for thing in _things:
		var node: Control = thing["node"]
		if not is_instance_valid(node):
			continue
		thing["phase"] = float(thing["phase"]) + delta * 2.0
		node.position.y += float(thing["speed"]) * delta
		node.position.x += sin(float(thing["phase"])) * float(thing["drift"]) * delta

		# Falling off the bottom is free. Nothing is lost by being slow.
		if node.position.y > DESPAWN_Y:
			node.queue_free()
		else:
			survivors.append(thing)
	_things = survivors


# --- tapping ------------------------------------------------------------

func _on_thing_input(event: InputEvent, thing: Dictionary) -> void:
	var pressed := (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var node: Control = thing["node"]
	if not is_instance_valid(node):
		return

	if bool(thing["hazard"]):
		_wrong(node, "collect.not_that")
		return

	if _color_target and int(thing["color_index"]) != _required_color_index:
		_wrong(node, "collect.wrong_color")
		return

	_collect(node)


func _collect(node: Control) -> void:
	_things = _things.filter(func(t): return t["node"] != node)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var t := create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector2(1.8, 1.8), 0.22).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(node.queue_free)

	_hero.celebrate()
	score_correct()
	_update_progress()

	if _color_target and result.correct % COLOR_SWITCH_EVERY == 0:
		_pick_required_color()


func _wrong(node: Control, message_key: String) -> void:
	_instruction.text = I18n.t(message_key)
	var origin := node.position
	var t := create_tween()
	t.tween_property(node, "position", origin + Vector2(14, 0), 0.06)
	t.tween_property(node, "position", origin - Vector2(14, 0), 0.06)
	t.tween_property(node, "position", origin, 0.06)
	score_mistake()


## In colour-matching levels the target colour changes every few collects, and
## the hero's chest core changes with it.
func _pick_required_color() -> void:
	if _orb_colors.size() <= 1:
		return
	var next := _required_color_index
	while next == _required_color_index:
		next = randi() % _orb_colors.size()
	_required_color_index = next

	var color := _color_at(_required_color_index)
	_hero.set_core_color(color)

	if _tower_light != null:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(60)
		style.shadow_color = Color(color.r, color.g, color.b, 0.5)
		style.shadow_size = 20
		_tower_light.add_theme_stylebox_override("panel", style)

	_instruction.text = I18n.t("collect.match_tower")


func _color_at(index: int) -> Color:
	if _orb_colors.is_empty():
		return Color(1.0, 0.82, 0.24)
	var raw := str(_orb_colors[index % _orb_colors.size()])
	return Color.from_string(raw, Color(1.0, 0.82, 0.24))


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", 8)]
