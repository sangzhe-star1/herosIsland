extends LevelManager
## Duel template: a proper one-on-one, hero versus monster, with a skill
## wheel in the thumb corner the way the big arena games do it -- and every
## one of their sharp edges filed off for a six-year-old.
##
## Three skills, all pictures:
##   BEAM   the basic attack. Tap, beam fires, monster flinches, meter +1.
##          A short cooldown sweeps the button -- pacing, not pressure: the
##          game never moves on without you.
##   SHIELD a light bubble for a few seconds. An attack that hits the bubble
##          bounces straight back at the monster (meter +1) -- blocking is
##          an ATTACK here, which is what makes the duel feel clever.
##   ULT    the special move, chosen before the battle when the level offers
##          a choice. It charges from landed beams (the classic ult economy);
##          when the ring is full the button glows. Barrage rains six beams;
##          Burst sweeps the arena clear and stuns.
##
## The monster fights back -- lobbing goo, and in later duels roaring rings
## across the arena -- but the house rules hold absolutely: an unblocked hit
## wobbles the hero and briefly delays the beam button. Nothing is ever
## lost, there is no hero health bar, misses are not mistakes, and the duel
## ends the way every battle here ends: the monster tired, happy, waving.

const GROUND_Y := 620.0
const HERO_POS := Vector2(240, 565)
const MONSTER_POS := Vector2(860, GROUND_Y)   # clear of the skill wheel

const BEAM_ART := "res://assets/effects/energy_beam.png"
const HIT_ART := "res://assets/effects/hit_burst.png"
const SMOKE_ART := "res://assets/effects/smoke.png"
const RING_ART := "res://assets/effects/power_up.png"
const DISC_ART := "res://assets/ui/disc.png"

var _beam_cooldown := 1.2
var _shield_cooldown := 6.0
var _shield_duration := 2.8
var _ult_needed := 6
var _goo_interval := 0.0
var _roar_interval := 0.0
var _ult_type := "barrage"

var _started := false
var _won := false
var _beam_ready_at := 0.0
var _shield_ready_at := 0.0
var _shield_until := 0.0
var _ult_charge := 0
var _clock := 0.0
var _goo_timer := 0.0
var _roar_timer := 0.0

var _play_area: Control
var _instruction: Label
var _hero: SkinnedCharacter
var _monster: Node2D
var _shield_bubble: TextureRect
var _meter_cells: Array = []
var _beam_button: Control
var _beam_sweep: TextureProgressBar
var _shield_button: Control
var _shield_sweep: TextureProgressBar
var _ult_button: Control
var _ult_ring: TextureProgressBar
var _threats: Array = []          # goo and roar nodes in flight


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_beam_cooldown = float(config.get("beam_cooldown", 1.2))
	_shield_cooldown = float(config.get("shield_cooldown", 6.0))
	_ult_needed = int(config.get("ult_needed", 6))
	_goo_interval = float(config.get("goo_interval", 5.0))
	_roar_interval = float(config.get("roar_interval", 0.0))
	_ult_type = str(config.get("ult", "barrage"))

	# Challenge scaling: a busier opponent and a higher goal, never a faster
	# hand required of the child.
	var rank := challenge_rank()
	if rank > 0:
		if _goo_interval > 0.0:
			_goo_interval = maxf(_goo_interval - 0.25 * rank, 2.6)
		if _roar_interval > 0.0:
			_roar_interval = maxf(_roar_interval - 0.3 * rank, 5.0)
		bump_target("correct", mini(rank, 10))

	_goo_timer = _goo_interval
	_roar_timer = _roar_interval * 1.4
	_build_scene(config)

	var choices: Array = config.get("ult_choices", [])
	if choices.size() >= 2:
		_build_ult_picker(choices)
	else:
		_started = true


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
	UiKit.scene_art(_play_area, config)

	_monster = preload("res://scripts/battle/monster.gd").new()
	_monster.position = MONSTER_POS
	_monster.scale = Vector2.ONE * float(config.get("monster", {}).get("scale", 1.15))
	_play_area.add_child(_monster)
	_monster.build(config.get("monster", {}))

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = HERO_POS
	_hero.scale = Vector2(1.7, 1.7)
	_play_area.add_child(_hero)
	Juice.idle_bob(_hero)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "duel.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	_instruction.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.75))
	_instruction.add_theme_constant_override("outline_size", 8)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(340, 30)
	_instruction.size = Vector2(600, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_build_meter()
	_build_skill_wheel()


func _build_meter() -> void:
	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", 6)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(meter)
	var total := target_value("correct", 8)
	for i in range(total):
		var cell: Control = UiKit.picture("spark", 38.0)
		if cell == null:
			cell = UiKit.star(true, 38)
		cell.modulate = Color(1, 1, 1, 0.28)
		meter.add_child(cell)
		_meter_cells.append(cell)
	meter.position = Vector2(640.0 - float(total) * 22.0, 88)


func _update_meter() -> void:
	for i in range(_meter_cells.size()):
		var cell: Control = _meter_cells[i]
		if not is_instance_valid(cell):
			continue
		var lit: bool = i < result.correct
		cell.modulate = Color(1, 1, 1, 1.0) if lit else Color(1, 1, 1, 0.28)
		if lit and i == result.correct - 1:
			Juice.pop(cell, 0.3)


## The thumb corner: ult, shield, beam -- beam biggest and rightmost,
## exactly where a landscape tablet's right thumb already rests.
func _build_skill_wheel() -> void:
	_ult_button = _skill_button(Vector2(830, 545), 118, "star", Color(0.95, 0.75, 0.25))
	_ult_ring = _sweep_for(_ult_button, 118, Color(1.0, 0.83, 0.35, 0.55))
	_ult_ring.value = 0.0
	_ult_button.gui_input.connect(_on_ult_input)

	_shield_button = _skill_button(Vector2(975, 480), 108, "shield", Color(0.45, 0.7, 0.95))
	_shield_sweep = _sweep_for(_shield_button, 108, Color(0, 0, 0, 0.45))
	_shield_sweep.value = 0.0
	_shield_button.gui_input.connect(_on_shield_input)

	_beam_button = _skill_button(Vector2(1105, 555), 134, "spark", Color(1.0, 0.85, 0.4))
	_beam_sweep = _sweep_for(_beam_button, 134, Color(0, 0, 0, 0.45))
	_beam_sweep.value = 0.0
	_beam_button.gui_input.connect(_on_beam_input)


func _skill_button(at: Vector2, size: float, icon_name: String, ring: Color) -> Control:
	var button := Panel.new()
	button.size = Vector2(size, size)
	button.position = at
	button.pivot_offset = button.size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.26, 0.88)
	style.set_corner_radius_all(int(size / 2.0))
	style.border_width_bottom = 5
	style.border_width_top = 5
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_color = ring
	button.add_theme_stylebox_override("panel", style)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon: Control = UiKit.picture(icon_name, size * 0.62)
	if icon != null:
		icon.position = Vector2(size * 0.19, size * 0.19)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
	_play_area.add_child(button)
	return button


## The cooldown/charge sweep laid over a skill button, HoK-style.
func _sweep_for(button: Control, size: float, tint: Color) -> TextureProgressBar:
	var sweep := TextureProgressBar.new()
	sweep.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	if ResourceLoader.exists(DISC_ART):
		sweep.texture_progress = load(DISC_ART)
	sweep.tint_progress = tint
	sweep.min_value = 0.0
	sweep.max_value = 100.0
	sweep.size = Vector2(size, size)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(sweep)
	return sweep


## Pre-battle choice of special move -- two big picture cards, no timer.
func _build_ult_picker(choices: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.12, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.add_child(dim)

	var title := UiKit.title_on_art(I18n.t("duel.pick_ult"), 46)
	title.position = Vector2(340, 140)
	title.size = Vector2(600, 60)
	dim.add_child(title)

	var icons := {"barrage": "star", "burst": "lightning"}
	var offsets := [Vector2(400, 250), Vector2(710, 250)]
	for i in range(2):
		var kind := str(choices[i])
		var card := Panel.new()
		card.size = Vector2(190, 220)
		card.position = offsets[i]
		card.pivot_offset = card.size / 2.0
		var style: StyleBox = UiKit.texture_style("res://assets/ui/level_card.png", 36.0, 12.0,
			Color(1.35, 1.3, 1.2))
		if style == null:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(0.13, 0.22, 0.42)
			flat.set_corner_radius_all(22)
			style = flat
		card.add_theme_stylebox_override("panel", style)
		var icon: Control = UiKit.picture(str(icons.get(kind, "star")), 110)
		if icon != null:
			icon.position = Vector2(40, 26)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(icon)
		var name_label := UiKit.title(I18n.t("duel.ult_" + kind), 26, Palette.ON_COLOR)
		name_label.position = Vector2(0, 160)
		name_label.size = Vector2(190, 40)
		card.add_child(name_label)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent):
			var pressed: bool = (event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed)
			if pressed and not _started:
				_ult_type = kind
				_started = true
				Juice.pop(card, 0.2)
				AudioManager.play_sfx("res://assets/audio/correct.ogg")
				dim.queue_free()
		)
		dim.add_child(card)
		UiKit.breathe(card, 0.03, 1.0 + 0.15 * float(i))


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_clock += delta
	_beam_sweep.value = clampf((_beam_ready_at - _clock) / _beam_cooldown, 0.0, 1.0) * 100.0
	_shield_sweep.value = clampf((_shield_ready_at - _clock) / _shield_cooldown, 0.0, 1.0) * 100.0
	if _shield_bubble != null and is_instance_valid(_shield_bubble) and _clock > _shield_until:
		_shield_bubble.queue_free()
		_shield_bubble = null

	if not _started or _won:
		return
	if _goo_interval > 0.0:
		_goo_timer -= delta
		if _goo_timer <= 0.0:
			_goo_timer = _goo_interval * randf_range(0.85, 1.3)
			_monster_attack_goo()
	if _roar_interval > 0.0:
		_roar_timer -= delta
		if _roar_timer <= 0.0:
			_roar_timer = _roar_interval * randf_range(0.9, 1.3)
			_monster_attack_roar()


# --- skills -------------------------------------------------------------

func _tap(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed) or (event is InputEventScreenTouch and event.pressed)


func _on_beam_input(event: InputEvent) -> void:
	if _tap(event):
		fire_beam_skill()


func _on_shield_input(event: InputEvent) -> void:
	if _tap(event):
		activate_shield()


func _on_ult_input(event: InputEvent) -> void:
	if _tap(event):
		fire_ult()


func fire_beam_skill() -> bool:
	if not _started or _won or _clock < _beam_ready_at:
		return false
	_beam_ready_at = _clock + _beam_cooldown
	var target: Vector2 = _monster.position + Vector2(randf_range(-40, 40), -190.0 * _monster.scale.x + randf_range(-40, 40))
	_draw_beam(_hero.core_position(), target)
	_impact(target)
	_land_hit(1)
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	Juice.pop(_beam_button, 0.12)
	return true


func activate_shield() -> bool:
	if not _started or _won or _clock < _shield_ready_at:
		return false
	_shield_ready_at = _clock + _shield_cooldown
	_shield_until = _clock + _shield_duration
	Juice.pop(_shield_button, 0.12)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")

	_shield_bubble = TextureRect.new()
	_shield_bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shield_bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		_shield_bubble.texture = load(RING_ART)
	elif ResourceLoader.exists(DISC_ART):
		_shield_bubble.texture = load(DISC_ART)
	_shield_bubble.size = Vector2(300, 300)
	_shield_bubble.position = HERO_POS - Vector2(150, 150) - Vector2(0, 60)
	_shield_bubble.modulate = Color(0.55, 0.85, 1.0, 0.65)
	_shield_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_shield_bubble)
	if Juice.motion_enabled():
		var t := _shield_bubble.create_tween().set_loops()
		t.tween_property(_shield_bubble, "modulate:a", 0.4, 0.5)
		t.tween_property(_shield_bubble, "modulate:a", 0.65, 0.5)
	return true


func shield_active() -> bool:
	return _clock < _shield_until


func ult_ready() -> bool:
	return _ult_charge >= _ult_needed


func fire_ult() -> bool:
	if not _started or _won or not ult_ready():
		if not ult_ready():
			Juice.nudge(_ult_button, 8.0)
		return false
	_ult_charge = 0
	_ult_ring.value = 0.0
	_hero.celebrate()
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	if _ult_type == "burst":
		_ult_burst()
	else:
		_ult_barrage()
	return true


## Six quick beams raking the monster. Loud, bright, three meter cells.
func _ult_barrage() -> void:
	for i in range(6):
		var target: Vector2 = _monster.position + Vector2(randf_range(-90, 90), -randf_range(60, 320) * _monster.scale.x)
		var delay := 0.09 * float(i)
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_inside_tree() or _monster == null or not is_instance_valid(_monster):
				return
			_draw_beam(_hero.core_position(), target)
			_impact(target)
			AudioManager.play_sfx("res://assets/audio/beam.ogg")
		)
	_monster.call("flinch")
	get_tree().create_timer(0.65).timeout.connect(func():
		if is_inside_tree():
			_land_hit(3, false)
	)


## A great gold ring sweeping the arena: every threat pops, the monster is
## dazzled, three meter cells.
func _ult_burst() -> void:
	var ring := TextureRect.new()
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		ring.texture = load(RING_ART)
	ring.size = Vector2(220, 220)
	ring.position = HERO_POS - Vector2(110, 170)
	ring.pivot_offset = ring.size / 2.0
	ring.modulate = Color(1.0, 0.85, 0.4, 0.85)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(7.0, 7.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.55)
	t.chain().tween_callback(ring.queue_free)

	for threat in _threats.duplicate():
		if is_instance_valid(threat):
			Juice.burst(_play_area, threat.position + threat.size / 2.0, 10)
			threat.queue_free()
	_threats.clear()
	_land_hit(3, false)


## charges=false for the ult's own hits: a special move must not pay for
## the next special move, or the button never stops glowing.
func _land_hit(amount: int, charges: bool = true) -> void:
	_monster.call("flinch")
	if charges:
		_ult_charge = mini(_ult_charge + amount, _ult_needed)
		_ult_ring.value = float(_ult_charge) / float(_ult_needed) * 100.0
		if ult_ready():
			UiKit.breathe(_ult_button, 0.06, 0.6)
	for i in range(amount):
		score_correct()
	_update_meter()


# --- the monster fights back --------------------------------------------

func _monster_attack_goo() -> void:
	_monster.call("puff_up")
	var goo := Panel.new()
	var goo_size := Vector2(80, 80)
	goo.size = goo_size
	goo.pivot_offset = goo_size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.78, 0.42, 0.95)
	style.set_corner_radius_all(int(goo_size.x / 2.0))
	goo.add_theme_stylebox_override("panel", style)
	goo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var from: Vector2 = _monster.position + Vector2(-40, -240 * _monster.scale.x)
	goo.position = from - goo_size / 2.0
	_play_area.add_child(goo)
	_threats.append(goo)

	var to := HERO_POS + Vector2(0, -50)
	var t := create_tween()
	t.tween_method(_goo_step.bind(goo, from, to), 0.0, 1.0, 2.4)
	t.tween_callback(func(): _threat_arrives(goo))


func _goo_step(k: float, goo: Panel, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(goo):
		return
	var x: float = lerpf(from.x, to.x, k)
	var y: float = lerpf(from.y, to.y, k) - sin(k * PI) * 170.0
	goo.position = Vector2(x, y) - goo.size / 2.0


func _monster_attack_roar() -> void:
	_monster.call("puff_up")
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	var ring := TextureRect.new()
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		ring.texture = load(RING_ART)
	elif ResourceLoader.exists(SMOKE_ART):
		ring.texture = load(SMOKE_ART)
	ring.size = Vector2(170, 170)
	ring.position = _monster.position + Vector2(-140, -260)
	ring.modulate = Color(0.8, 0.55, 0.95, 0.8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(ring)
	_threats.append(ring)
	var t := create_tween()
	t.tween_property(ring, "position:x", HERO_POS.x - 85.0, 2.6)
	t.tween_callback(func(): _threat_arrives(ring))


## A threat reaches the hero. Shield up: it bounces back and COUNTS (+1).
## Shield down: a soft poof, a wobble, and the beam button rests a moment
## longer. Nothing is lost either way -- the difference is only how clever
## the child got to feel.
func _threat_arrives(threat: Control) -> void:
	_threats.erase(threat)
	if not is_instance_valid(threat):
		return
	if shield_active():
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		var back_to: Vector2 = _monster.position + Vector2(0, -190 * _monster.scale.x)
		var t := create_tween()
		t.tween_property(threat, "position", back_to - threat.size / 2.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func():
			if is_instance_valid(threat):
				_impact(threat.position + threat.size / 2.0)
				threat.queue_free()
			_land_hit(1)
		)
		return

	_splat(threat.position + threat.size / 2.0)
	threat.queue_free()
	Juice.nudge(_hero, 10.0)
	_beam_ready_at = maxf(_beam_ready_at, _clock) + 0.7


# --- shared effects -----------------------------------------------------

func _draw_beam(from: Vector2, to: Vector2) -> void:
	var span := to - from
	if ResourceLoader.exists(BEAM_ART):
		var beam := Sprite2D.new()
		beam.texture = load(BEAM_ART)
		beam.position = from + span / 2.0
		beam.rotation = span.angle()
		beam.scale = Vector2(span.length() / 1024.0, 0.34)
		beam.modulate = Color(1.0, 0.88, 0.45)
		_play_area.add_child(beam)
		var t := create_tween()
		t.tween_property(beam, "modulate:a", 0.0, 0.22 if Juice.motion_enabled() else 0.05)
		t.tween_callback(beam.queue_free)


func _impact(at: Vector2) -> void:
	Juice.burst(_play_area, at, 12)
	if not ResourceLoader.exists(HIT_ART):
		return
	var burst := TextureRect.new()
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	burst.texture = load(HIT_ART)
	burst.size = Vector2(150, 150)
	burst.position = at - burst.size / 2.0
	burst.pivot_offset = burst.size / 2.0
	burst.scale = Vector2(0.5, 0.5)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(burst)
	var t := create_tween().set_parallel(true)
	t.tween_property(burst, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(burst, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(burst.queue_free)


func _splat(at: Vector2) -> void:
	if not ResourceLoader.exists(SMOKE_ART):
		return
	var poof := TextureRect.new()
	poof.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poof.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poof.texture = load(SMOKE_ART)
	poof.size = Vector2(120, 120)
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

func complete_level() -> void:
	if not _finished:
		_won = true
		_instruction.text = I18n.t("battle.bye")
		_hero.celebrate()
		Juice.burst(_play_area, _monster.position + Vector2(0, -160), 30)
		AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
		_monster.call("leave_happy")
		await get_tree().create_timer(1.0).timeout
	await super.complete_level()


func on_correct() -> void:
	_update_meter()
