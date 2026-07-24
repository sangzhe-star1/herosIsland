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

## Real artwork, used the moment the files exist and drawn otherwise.
const CITY_ART := "res://assets/backgrounds/city.png"
const TOWER_ART := "res://assets/backgrounds/tower.png"
const TOWER_BROKEN_ART := "res://assets/backgrounds/tower_broken.png"
const TOWER_REPAIRED_ART := "res://assets/backgrounds/tower_repaired.png"
const ORB_ART := "res://assets/icons/orb.png"
const ROCK_ART := "res://assets/icons/rock.png"
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
var _hero: SkinnedCharacter
var _tower_light: Panel
var _tower_art: TextureRect


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

	_build_city()

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "collect.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 36)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
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
	_hero.position = Vector2(330, 560)
	_hero.scale = Vector2(1.3, 1.3)
	# Inside the play area, NOT the scene root: the play area lives on a
	# CanvasLayer, which draws over the root canvas -- a root-level hero is
	# painted behind the background and never seen.
	_play_area.add_child(_hero)
	Juice.idle_bob(_hero)

	if _color_target:
		_tower_light = Panel.new()
		if ResourceLoader.exists(TOWER_ART):
			# Sized and placed to sit exactly on the painted tower's lamp orb,
			# so the colour looks like the lamp lighting up rather than a
			# sticker over it.
			_tower_light.size = Vector2(96, 96)
			_tower_light.position = Vector2(92, 123)
		else:
			_tower_light.size = Vector2(120, 120)
			_tower_light.position = Vector2(80, 96)   # crowns the drawn mast, which tops out at y=190
		_tower_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_area.add_child(_tower_light)


## The city the hero is defending: a night skyline with lit windows, and the
## energy tower he is here to recharge.
##
## Everything sits behind the play area and ignores input. It is scenery, but
## scenery is what turns "tap the falling circles" into "a hero collecting light
## over a city" -- and at six, that framing is most of the motivation.
##
## Drawn rather than textured, so it works today. A background PNG dropped at
## assets/backgrounds/city.png can replace all of it later.
func _build_city() -> void:
	var horizon := 620.0

	# With the painted skyline present, the whole drawn city stands down.
	# A level can ask for a specific skyline ("background_art" in its config --
	# the storm level uses the damaged city); everything else gets city.png.
	var city_path: String = str(level_data.get("config", {}).get("background_art", ""))
	if city_path == "" or not ResourceLoader.exists(city_path):
		city_path = CITY_ART
	if ResourceLoader.exists(city_path):
		var art := TextureRect.new()
		art.texture = load(city_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_area.add_child(art)
		if _color_target:
			_build_tower(horizon)
		return

	# Stars, thinning out towards the horizon.
	for i in range(46):
		var star := ColorRect.new()
		var twinkle: float = randf_range(0.35, 0.9)
		star.color = Color(1.0, 0.98, 0.88, twinkle)
		var star_size: float = randf_range(2.0, 4.0)
		star.size = Vector2(star_size, star_size)
		star.position = Vector2(randf_range(0.0, 1280.0), randf_range(20.0, 420.0))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_area.add_child(star)

	# Two building layers. The far one is darker and shorter, which reads as
	# distance without needing perspective.
	var layers := [
		{"color": Color(0.10, 0.14, 0.26), "min_h": 90.0, "max_h": 190.0, "width": 96.0},
		{"color": Color(0.14, 0.19, 0.34), "min_h": 140.0, "max_h": 300.0, "width": 124.0},
	]
	for layer_def in layers:
		var block_width: float = float(layer_def["width"])
		var x := -40.0
		while x < 1300.0:
			var block_height: float = randf_range(
				float(layer_def["min_h"]), float(layer_def["max_h"])
			)
			var w: float = block_width * randf_range(0.7, 1.25)

			var building := ColorRect.new()
			building.color = layer_def["color"]
			building.size = Vector2(w, block_height)
			building.position = Vector2(x, horizon - block_height)
			building.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_play_area.add_child(building)

			# Lit windows. Warm, sparse, and never in a perfect grid.
			var columns := int(w / 26.0)
			var rows := int(block_height / 34.0)
			for cx in range(columns):
				for cy in range(rows):
					if randf() > 0.42:
						continue
					var window := ColorRect.new()
					window.color = Color(1.0, 0.86, 0.48, randf_range(0.45, 0.9))
					window.size = Vector2(10, 14)
					window.position = Vector2(
						x + 14.0 + float(cx) * 26.0,
						horizon - block_height + 18.0 + float(cy) * 34.0
					)
					window.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_play_area.add_child(window)

			x += w + randf_range(6.0, 26.0)

	# Ground.
	var ground := ColorRect.new()
	ground.color = Color(0.08, 0.11, 0.18)
	ground.position = Vector2(0, horizon)
	ground.size = Vector2(1280, 720 - horizon)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(ground)

	if _color_target:
		_build_tower(horizon)


## The energy tower, present only in the level about repairing it. Its lamp is
## _tower_light, which the level recolours -- so the thing the child must match
## is a landmark in the world rather than a swatch in the corner.
func _build_tower(horizon: float) -> void:
	var base_x := 140.0

	# Painted tower art: 400x700 with the lamp orb near the top. Sized so its
	# base sits on the horizon and its lamp area lands under _tower_light at
	# (80..200, 96..216), which the level draws in colour on top.
	#
	# The repair level opens on the BROKEN tower -- cracked lamp, loose cables
	# -- and swaps to the repaired one when the child finishes. That before and
	# after is the story of the level, told without a single word.
	var tower_path := TOWER_ART
	if ResourceLoader.exists(TOWER_BROKEN_ART):
		tower_path = TOWER_BROKEN_ART
	if ResourceLoader.exists(tower_path):
		_tower_art = TextureRect.new()
		var height := 533.0
		var width := height * (400.0 / 700.0)
		_tower_art.texture = load(tower_path)
		_tower_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tower_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_tower_art.position = Vector2(base_x - width * 0.5, horizon - height)
		_tower_art.size = Vector2(width, height)
		_tower_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_area.add_child(_tower_art)
		return

	var mast := Polygon2D.new()
	mast.polygon = PackedVector2Array([
		Vector2(base_x - 46.0, horizon),
		Vector2(base_x - 18.0, 190.0),
		Vector2(base_x + 18.0, 190.0),
		Vector2(base_x + 46.0, horizon),
	])
	mast.color = Color(0.20, 0.26, 0.40)
	_play_area.add_child(mast)

	# Cross-bracing, so it reads as a structure rather than a triangle.
	for i in range(5):
		var t: float = float(i) / 5.0
		var y: float = 190.0 + (horizon - 190.0) * t
		var half: float = lerpf(18.0, 46.0, t)
		var brace := ColorRect.new()
		brace.color = Color(0.26, 0.33, 0.48)
		brace.size = Vector2(half * 2.0, 6.0)
		brace.position = Vector2(base_x - half, y)
		brace.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play_area.add_child(brace)


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

	var art_path: String = ROCK_ART if hazard else ORB_ART
	if ResourceLoader.exists(art_path):
		# Real artwork. The orb is painted neutral and tinted here, which is
		# what lets one file serve all four colours in the matching level. The
		# rock stays untinted: it differs from orbs in shape as well as colour,
		# so a colour-blind child can still tell them apart.
		node.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not hazard:
			art.modulate = _color_at(color_index)
		node.add_child(art)
	else:
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
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
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
	if _tower_light == null or not ResourceLoader.exists(POWER_UP_ART) or not Juice.motion_enabled():
		return
	var ring := TextureRect.new()
	ring.texture = load(POWER_UP_ART)
	ring.size = Vector2(280, 280)
	ring.position = _tower_light.position + _tower_light.size / 2.0 - ring.size / 2.0
	ring.pivot_offset = ring.size / 2.0
	ring.scale = Vector2(0.5, 0.5)
	ring.modulate = _color_at(_required_color_index)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(1.3, 1.3), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.55)
	t.chain().tween_callback(ring.queue_free)


## The repair, delivered: the broken tower becomes the shining repaired one at
## the moment the level is won, while the base class holds the scene for a
## second before the result screen. Colour-matching was the work; this is what
## the work was FOR.
func complete_level() -> void:
	if not _finished and _color_target and _tower_art != null \
			and ResourceLoader.exists(TOWER_REPAIRED_ART):
		_tower_art.texture = load(TOWER_REPAIRED_ART)
		if _tower_light != null:
			_tower_light.visible = false   # the repaired lamp shines on its own
		Juice.burst(_play_area, Vector2(140, 170), 30)
		AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	await super.complete_level()


func _wrong(node: Control, message_key: String) -> void:
	_instruction.text = I18n.t(message_key)
	Juice.nudge(node)
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
	# The hero's light flares when the target colour changes, so the child's eye
	# is drawn to the thing that just became the instruction.
	_hero.power_up()
	_power_up_ring()

	if _tower_light != null:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(int(_tower_light.size.x / 2.0))
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
