extends LevelManager
## Battle template: the hero faces a monster across the city, and every tap on
## a light spark fires the hero's beam at it. Enough hits and the monster gives
## up, waves, and hops off home.
##
## Powers the Monster Arena levels via each level's "config" block:
##   monster_arena_01  big slow sparks, nothing else       (learn the loop)
##   monster_arena_02  dud sparks appear, goo gets thrown  (aim carefully)
##   monster_arena_03  the big one: faster, more of both   (feel like a hero)
##
## Combat, tuned for six: the child can never be hurt, never lose progress,
## and never run out of time. Sparks that fade cost nothing; goo that lands
## splats harmlessly. The only mistake is tapping a grey dud spark -- and that
## earns the same gentle nudge as every other template. Difficulty is MORE TO
## DO, never LESS TIME TO DO IT.
##
## Responsiveness rules (docs/DESIGN_NOTES.md): the beam fires on the same
## frame as the tap, from the hero's chest light to the exact point tapped,
## and something always happens where the finger is. No cooldowns, no rate
## limits -- every tap is answered.

const SPARK_SIZE := Vector2(116, 116)
const GROUND_Y := 620.0

const BEAM_ART := "res://assets/effects/energy_beam.png"
const HIT_ART := "res://assets/effects/hit_burst.png"
const SPARK_ART := "res://assets/effects/sparkle.png"
const SMOKE_ART := "res://assets/effects/smoke.png"

var _spark_interval := 1.4
var _spark_life := 6.0
var _dud_ratio := 0.0
var _goo_interval := 0.0
var _beam_color := Color(1.0, 0.85, 0.35)

var _spark_timer := 1.0
var _goo_timer := 0.0
var _won := false

var _play_area: Control
var _instruction: Label
var _meter: HBoxContainer
var _meter_cells: Array = []
var _hero: SkinnedCharacter
var _monster: Node2D


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_spark_interval = float(config.get("spark_interval", 1.4))
	_spark_life = float(config.get("spark_life", 6.0))
	_dud_ratio = clampf(float(config.get("dud_ratio", 0.0)), 0.0, 0.6)
	_goo_interval = float(config.get("goo_interval", 0.0))
	_beam_color = Color.from_string(str(config.get("beam_color", "#ffd95a")), _beam_color)
	_goo_timer = _goo_interval * 1.5

	# Challenge scaling: more sparks to land, more duds to tell apart, a
	# slightly busier monster. Spark lifetime never shrinks -- aim, not speed.
	var rank := challenge_rank()
	if rank > 0:
		_spark_interval = maxf(_spark_interval * pow(0.95, rank), 0.55)
		_dud_ratio = clampf(_dud_ratio + 0.02 * rank, 0.0, 0.45)
		if _goo_interval > 0.0:
			_goo_interval = maxf(_goo_interval - 0.2 * rank, 3.0)
		bump_target("correct", mini(rank, 12))

	_build_scene(config)


# --- construction -------------------------------------------------------

func _build_scene(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	build_world(_play_area)

	# The monster, on the city side it is bothering.
	_monster = preload("res://scripts/battle/monster.gd").new()
	_monster.position = Vector2(950, GROUND_Y)
	_monster.scale = Vector2.ONE * float(config.get("monster", {}).get("scale", 1.0))
	_play_area.add_child(_monster)
	_monster.build(config.get("monster", {}))

	# The hero, facing it. Same skin the child chose in the Hero House.
	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(250, GROUND_Y)
	_play_area.add_child(_hero)
	_hero.set_height(320.0)
	_hero.entrance(340.0, 0.15)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "battle.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.75))
	_instruction.add_theme_constant_override("outline_size", 8)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 30)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_build_meter()


## Progress as a row of sparks that light up -- countable on fingers, no
## numbers needed. This meter only ever fills; there is no bar that empties.
func _build_meter() -> void:
	_meter = HBoxContainer.new()
	_meter.add_theme_constant_override("separation", 6)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_meter)

	var total := target_value("correct", 8)
	for i in range(total):
		var cell: Control = UiKit.picture("spark", 40.0)
		if cell == null:
			cell = UiKit.star(true, 40)
		cell.modulate = Color(1, 1, 1, 0.28)
		_meter.add_child(cell)
		_meter_cells.append(cell)
	# Centred under the instruction, wherever the row's width lands.
	_meter.position = Vector2(640.0 - float(total) * 23.0, 92)


func _update_meter() -> void:
	for i in range(_meter_cells.size()):
		var cell: Control = _meter_cells[i]
		if not is_instance_valid(cell):
			continue
		var lit: bool = i < result.correct
		cell.modulate = Color(1, 1, 1, 1.0) if lit else Color(1, 1, 1, 0.28)
		if lit and i == result.correct - 1:
			Juice.pop(cell, 0.35)


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if _won:
		return
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = _spark_interval * randf_range(0.8, 1.25)
		_spawn_spark()
	if _goo_interval > 0.0:
		_goo_timer -= delta
		if _goo_timer <= 0.0:
			_goo_timer = _goo_interval * randf_range(0.85, 1.3)
			_throw_goo()


## A spark somewhere on the monster. Generous size, generous lifetime, and a
## slow pulse that says "I am the thing to tap". Duds are grey, square-ish and
## dull -- different in shape AND brightness, so a colour-blind child can tell.
func _spawn_spark() -> void:
	var dud := randf() < _dud_ratio
	var monster_scale: float = _monster.scale.x
	var at := _monster.position + Vector2(
		randf_range(-130.0, 110.0) * monster_scale,
		-randf_range(70.0, 280.0) * monster_scale
	)
	at.x = clampf(at.x, 700.0, 1180.0)
	at.y = clampf(at.y, 150.0, 560.0)

	var node := Panel.new()
	node.size = SPARK_SIZE
	node.position = at - SPARK_SIZE / 2.0
	node.pivot_offset = SPARK_SIZE / 2.0
	# A soft glowing disc behind the sparkle art: the sparkle alone is wispy
	# against the monster, and the disc is what makes the tap target read as
	# "a thing", the full 116px of it.
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(1.0, 0.85, 0.42, 0.30) if not dud else Color(0.45, 0.47, 0.53, 0.30)
	glow.set_corner_radius_all(int(SPARK_SIZE.x / 2.0) if not dud else 14)
	if not dud:
		glow.shadow_color = Color(1.0, 0.82, 0.35, 0.35)
		glow.shadow_size = 18
	node.add_theme_stylebox_override("panel", glow)
	node.mouse_filter = Control.MOUSE_FILTER_STOP

	var face: Control = null
	if ResourceLoader.exists(SPARK_ART if not dud else SMOKE_ART):
		var tex := TextureRect.new()
		tex.texture = load(SPARK_ART if not dud else SMOKE_ART)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.modulate = Color(1.0, 0.86, 0.42) if not dud else Color(0.62, 0.63, 0.68)
		node.add_child(tex)
		face = tex
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.86, 0.42) if not dud else Color(0.45, 0.46, 0.5)
		if dud:
			style.set_corner_radius_all(8)
		else:
			style.set_corner_radius_all(int(SPARK_SIZE.x / 2.0))
			style.shadow_color = Color(1.0, 0.86, 0.42, 0.5)
			style.shadow_size = 16
		node.add_theme_stylebox_override("panel", style)

	node.gui_input.connect(_on_spark_input.bind(node, dud))
	_play_area.add_child(node)

	if Juice.motion_enabled():
		var pulse := node.create_tween().set_loops()
		pulse.tween_property(node, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(node, "scale", Vector2(0.92, 0.92), 0.55).set_trans(Tween.TRANS_SINE)

	# Fading away costs nothing. Another spark is always coming.
	var expire := node.create_tween()
	expire.tween_interval(_spark_life)
	expire.tween_property(node, "modulate:a", 0.0, 0.6)
	expire.tween_callback(node.queue_free)


func _on_spark_input(event: InputEvent, node: Panel, dud: bool) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or _won or not is_instance_valid(node):
		return
	if dud:
		_instruction.text = I18n.t("battle.not_that")
		Juice.nudge(node)
		score_mistake()
		return
	_zap(node)


## The whole point of the level, so everything lands on the same frame as the
## tap: beam out, spark pops, monster flinches, meter fills.
func _zap(node: Panel) -> void:
	var target: Vector2 = node.position + SPARK_SIZE / 2.0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_fire_beam(_hero.core_position(), target)
	_hit_burst(target)
	_monster.flinch()
	Juice.burst(_play_area, target, 14)
	_hero_recoil()

	var t := create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector2(1.7, 1.7), 0.18).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(node.queue_free)

	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	score_correct()
	_update_meter()


## The beam: the bundle's energy_beam art stretched from chest light to spark,
## or a plain bright line when the art is missing. Present for exactly long
## enough to be seen, then gone -- it is feedback, not decoration, so it also
## appears (without the fade) when reduce-motion is on.
func _fire_beam(from: Vector2, to: Vector2) -> void:
	var span := to - from
	var fade := 0.22 if Juice.motion_enabled() else 0.05

	if ResourceLoader.exists(BEAM_ART):
		var beam := Sprite2D.new()
		beam.texture = load(BEAM_ART)
		beam.position = from + span / 2.0
		beam.rotation = span.angle()
		beam.scale = Vector2(span.length() / 1024.0, 0.30)
		beam.modulate = _beam_color
		_play_area.add_child(beam)
		var t := create_tween()
		t.tween_property(beam, "modulate:a", 0.0, fade)
		t.tween_callback(beam.queue_free)
	else:
		var line := Line2D.new()
		line.points = PackedVector2Array([from, to])
		line.width = 12.0
		line.default_color = _beam_color
		_play_area.add_child(line)
		var t := create_tween()
		t.tween_property(line, "modulate:a", 0.0, fade)
		t.tween_callback(line.queue_free)


func _hit_burst(at: Vector2) -> void:
	if not ResourceLoader.exists(HIT_ART):
		return
	var burst := TextureRect.new()
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # before size, or 512px art wins
	burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	burst.texture = load(HIT_ART)
	burst.size = Vector2(170, 170)
	burst.position = at - burst.size / 2.0
	burst.pivot_offset = burst.size / 2.0
	burst.scale = Vector2(0.5, 0.5)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(burst)
	var t := create_tween().set_parallel(true)
	t.tween_property(burst, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(burst, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(burst.queue_free)


## A tiny lean into the shot. Blink and you miss it; feel and you don't.
func _hero_recoil() -> void:
	if not Juice.motion_enabled():
		return
	var t := create_tween()
	t.tween_property(_hero, "position:x", 258.0, 0.07)
	t.tween_property(_hero, "position:x", 250.0, 0.12)


# --- goo ----------------------------------------------------------------

## The monster fights back the only way this game allows: slowly, softly, and
## harmlessly. Goo can be popped mid-air for fun; goo that lands just splats.
## Nothing to dodge, nothing to lose -- drama without danger.
func _throw_goo() -> void:
	if _won:
		return
	_monster.puff_up()

	var goo := Panel.new()
	var goo_size := Vector2(84, 84)
	goo.size = goo_size
	goo.pivot_offset = goo_size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.78, 0.42, 0.95)
	style.set_corner_radius_all(int(goo_size.x / 2.0))
	goo.add_theme_stylebox_override("panel", style)
	goo.mouse_filter = Control.MOUSE_FILTER_STOP

	var from := _monster.position + Vector2(-40, -240 * _monster.scale.x)
	var to := Vector2(randf_range(380.0, 720.0), GROUND_Y - goo_size.y * 0.5)
	goo.position = from - goo_size / 2.0
	_play_area.add_child(goo)

	goo.gui_input.connect(func(event: InputEvent):
		var pressed: bool = (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
		if pressed and is_instance_valid(goo):
			Juice.burst(_play_area, goo.position + goo_size / 2.0, 12)
			goo.queue_free()
	)

	# A slow, readable arc: x walks across while y rises then falls.
	var flight := 2.2
	var t := create_tween()
	t.tween_method(_goo_step.bind(goo, from, to), 0.0, 1.0, flight)
	t.tween_callback(func():
		if is_instance_valid(goo):
			_splat(goo.position + goo_size / 2.0)
			goo.queue_free()
	)


func _goo_step(k: float, goo: Panel, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(goo):
		return
	var x: float = lerpf(from.x, to.x, k)
	var y: float = lerpf(from.y, to.y, k) - sin(k * PI) * 180.0
	goo.position = Vector2(x, y) - goo.size / 2.0


func _splat(at: Vector2) -> void:
	if not ResourceLoader.exists(SMOKE_ART):
		return
	var poof := TextureRect.new()
	poof.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poof.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poof.texture = load(SMOKE_ART)
	poof.size = Vector2(130, 130)
	poof.position = at - poof.size / 2.0
	poof.pivot_offset = poof.size / 2.0
	poof.modulate = Color(0.7, 0.85, 0.6, 0.8)
	poof.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(poof)
	var t := create_tween().set_parallel(true)
	t.tween_property(poof, "scale", Vector2(1.4, 1.4), 0.5)
	t.tween_property(poof, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(poof.queue_free)


# --- winning ------------------------------------------------------------

## The monster gives up, waves goodbye, and hops off home. Held slightly
## longer than other templates so the child gets to WATCH it leave -- that
## exit is the reward the whole level was building to.
func complete_level() -> void:
	if not _finished:
		_won = true
		_instruction.text = I18n.t("battle.bye")
		_hero.celebrate()
		Juice.burst(_play_area, _monster.position + Vector2(0, -160), 30)
		AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
		_monster.leave_happy()
		# An extra beat on top of the base delay, so the child watches the
		# whole exit rather than being yanked to the result screen mid-hop.
		await get_tree().create_timer(1.0).timeout
	await super.complete_level()
