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

const COLLECT_FLASH_ART := "res://assets/effects/collect_flash.png"
const POWER_UP_ART := "res://assets/effects/power_up.png"

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
var _picto: Control
var _hero: SkinnedCharacter
var _tower: EnergyTower


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_spawn_interval = float(config.get("spawn_interval", 1.0))
	_fall_speed = float(config.get("fall_speed", 130.0))
	_orb_colors = (config.get("orb_colors", ["#ffd23c"]) as Array).duplicate()
	_hazard_ratio = clampf(float(config.get("hazard_ratio", 0.0)), 0.0, 0.8)
	_color_target = bool(config.get("color_target", false))

	# Challenge scaling: denser sky and a higher goal each rank. Fall speed
	# barely moves (missing costs nothing here), and the pace has a floor.
	var rank := challenge_rank()
	if rank > 0:
		_spawn_interval = maxf(_spawn_interval * pow(0.94, rank), 0.45)
		_fall_speed = minf(_fall_speed + 4.0 * rank, 240.0)
		_hazard_ratio = clampf(_hazard_ratio + 0.02 * rank, 0.0, 0.6)
		bump_target("correct", mini(rank, 15))

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

	var stage: Stage = build_world(_play_area)

	# The tower is a landmark this level owns, so it goes in with the world's
	# props -- lit and shadowed like everything else standing on that ground,
	# rather than floating in front of the picture.
	if _color_target:
		_tower = EnergyTower.new()
		_tower.build(470.0, true)
		stage.add_landmark(_tower, 168.0, 0.0)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "collect.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 36)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	# The instruction, wordless: icon tiles with tick/slash rings right under
	# the text. The text stays for the parent; the strip is what a pre-reader
	# actually plays from.
	var picto_items: Array = []
	if _color_target:
		picto_items = [{"icon": "orb", "ok": true, "tint": _color_at(0)}]
	elif _hazard_ratio > 0.0:
		picto_items = [{"icon": "orb", "ok": true, "tint": _color_at(0)},
			{"icon": "rock", "ok": false}]
	else:
		picto_items = [{"icon": "orb", "ok": true, "tint": _color_at(0)}]
	_picto = UiKit.pictogram(picto_items)
	_picto.position = Vector2(340, 96)
	_picto.size = Vector2(600, 84)
	_play_area.add_child(_picto)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_progress)
	_progress.position = Vector2(1020, 40)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)
	_update_progress()

	# The hero stands at the bottom and, in colour-matching levels, wears the
	# answer on their chest -- the core light IS the instruction for a child
	# who cannot read the label above it.
	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	# Standing on the ground line at y=620, clear of the tower at x=140.
	_hero.position = Vector2(360, Stage.ground_line())
	# Inside the play area, NOT the scene root: the play area lives on a
	# CanvasLayer, which draws over the root canvas -- a root-level hero is
	# painted behind the background and never seen.
	_play_area.add_child(_hero)
	_hero.set_height(200.0)



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

	# Drawn, not blitted -- and drawn from the SAME IconLibrary entries the
	# instruction strip shows, so "collect these, not those" is taught by
	# matching pictures rather than by reading. The orb is tinted per colour;
	# the rock differs from orbs in shape as well as colour, so a colour-blind
	# child can still tell them apart.
	node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var art: Control = UiKit.picture("rock" if hazard else "orb", ORB_SIZE.x)
	if art != null:
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not hazard:
			art.modulate = _color_at(color_index)
		node.add_child(art)

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
	var pressed: bool = UiKit.is_press(event)
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

	Juice.burst(_play_area, node.position + ORB_SIZE / 2.0, 16)
	_collect_flash(node.position + ORB_SIZE / 2.0)
	_hero.celebrate()
	score_correct()
	_update_progress()

	if _color_target and result.correct % COLOR_SWITCH_EVERY == 0:
		_pick_required_color()


## A white starburst at the point of collection -- the tap is answered exactly
## where the finger is, which is where a six-year-old is looking.
func _collect_flash(at: Vector2) -> void:
	if not ResourceLoader.exists(COLLECT_FLASH_ART) or not Juice.motion_enabled():
		return
	var flash := TextureRect.new()
	flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # before size, or 512px art wins
	flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flash.texture = load(COLLECT_FLASH_ART)
	flash.size = Vector2(150, 150)
	flash.position = at - flash.size / 2.0
	flash.pivot_offset = flash.size / 2.0
	flash.scale = Vector2(0.4, 0.4)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(flash)
	var t := create_tween().set_parallel(true)
	t.tween_property(flash, "scale", Vector2(1.15, 1.15), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(flash.queue_free)


## The glow ring that pulses out of the tower lamp when the target colour
## changes. Its job is to pull the child's eye up to the new instruction.
func _power_up_ring() -> void:
	if _tower == null or not Juice.motion_enabled():
		return
	var at: Vector2 = _tower.position + _tower.lamp_position()
	var ring := Node2D.new()
	ring.position = at
	_play_area.add_child(ring)
	Shapes.fill(ring, Shapes.circle_points(Vector2.ZERO, 100.0, 30),
		Color(_color_at(_required_color_index), 0.0), 0.0)
	var line := Line2D.new()
	line.points = Shapes.circle_points(Vector2.ZERO, 100.0, 30)
	line.closed = true
	line.width = 10.0
	line.default_color = _color_at(_required_color_index)
	line.antialiased = true
	ring.add_child(line)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(ring.queue_free)


## The repair, delivered: the broken tower becomes the shining repaired one at
## the moment the level is won, while the base class holds the scene for a
## second before the result screen. Colour-matching was the work; this is what
## the work was FOR.
func complete_level() -> void:
	if not _finished and _color_target and _tower != null:
		_tower.repair(_color_at(_required_color_index))
		Juice.burst(_play_area, _tower.position + _tower.lamp_position(), 30)
		AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	await super.complete_level()


func _wrong(node: Control, message_key: String) -> void:
	_instruction.text = I18n.t(message_key)
	Juice.nudge(node)
	# The wordless half of the message: a red no-ring flashed over the exact
	# thing the finger touched, and a pulse on the rule tile it broke. This is
	# the entire correction for a child who cannot read the label above.
	Juice.no_sign(_play_area, node.position + ORB_SIZE / 2.0)
	_pulse_rule_tile(1 if message_key == "collect.not_that" else 0)
	score_mistake()


func _pulse_rule_tile(index: int) -> void:
	if _picto == null or not is_instance_valid(_picto):
		return
	var tiles: Array = _picto.get_meta("tiles", [])
	if index < tiles.size() and is_instance_valid(tiles[index]):
		Juice.pop(tiles[index], 0.30)


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
	# The hero's light flares when the target colour changes, so the child's eye
	# is drawn to the thing that just became the instruction.
	_hero.power_up()
	_power_up_ring()

	if _tower != null:
		_tower.set_light_color(color)

	# The rule tile follows the target colour, and pulses to say "look here".
	if _picto != null and is_instance_valid(_picto):
		var tiles: Array = _picto.get_meta("tiles", [])
		if tiles.size() > 0 and is_instance_valid(tiles[0]):
			var art: Control = tiles[0].get_node_or_null("Art")
			if art != null:
				art.modulate = color
			Juice.pop(tiles[0], 0.30)

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
