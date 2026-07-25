extends LevelManager
## The blaster range: monsters pop up from behind the rocks, tap to zap.
##
## This is the requested "shooting game where you win things", folded into
## the house rules. The gun is the hero's own light bolt (established since
## the first duel); the targets are the island's cheeky monsters, who get
## BONKED -- dizzy stars, a rub of the head, back down behind the rock --
## never hurt. And the range PAYS: bonked monsters drop coins and, now and
## then, a real star-shop item in a bubble. Play the range, stock the bag,
## spend it on expeditions. Coins bank at the finish like the trail's do.
##
## The one thing that costs accuracy: the puppy pops up too, waving. She is
## a FRIEND. Zapping a friend is the range's only mistake -- the red no-sign
## says so on the spot, wordlessly. (Friends never hurt either; she ducks,
## droops, forgives.)
##
## Config: { "targets": 10, "max_up": 2, "pop_min": 1.9, "pop_max": 2.6,
##           "friend_ratio": 0.18, "item_chance": 0.16, "monsters": [...] }
## Challenge ranks add targets, never speed.

const FIRE_COOLDOWN := 0.45
const HIT_RADIUS := 100.0
const SPOT_XS := [260.0, 490.0, 720.0, 950.0, 1160.0]

var _targets := 10
var _max_up := 2
var _pop_min := 1.9
var _pop_max := 2.6
var _friend_ratio := 0.18
var _item_chance := 0.16
var _specs: Array = []

var _play_area: Control
var _actors: Node2D              # occupants live here, BEHIND the rocks
var _hero: SkinnedCharacter
var _spots: Array = []           # [{x, taken, node, friend, chest, until, leaving}]
var _clock := 0.0
var _fire_ready := 0.0
var _next_pop := 1.0
var _coins_got := 0
var _items_dropped := 0
var _instruction: Label
var _picto: Control
var _progress: Label
var _coin_label: Label
var _ground := 620.0


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_targets = target_value("correct", int(config.get("targets", 10)))
	_max_up = clampi(int(config.get("max_up", 2)), 1, 3)
	_pop_min = float(config.get("pop_min", 1.9))
	_pop_max = float(config.get("pop_max", 2.6))
	_friend_ratio = clampf(float(config.get("friend_ratio", 0.18)), 0.0, 0.5)
	_item_chance = clampf(float(config.get("item_chance", 0.16)), 0.0, 1.0)
	_specs = (config.get("monsters", []) as Array).duplicate()
	if _specs.is_empty():
		_specs = [{"id": "peek", "body_color": "#7fb069", "belly_color": "#cde6b2",
			"accent_color": "#4f7d43", "height": 210}]

	# Challenge scaling: more bonks to win, a third head allowed up. The pop
	# rhythm never quickens -- patience out-shoots reflexes here too.
	var rank := challenge_rank()
	if rank > 0:
		bump_target("correct", mini(rank * 2, 8))
		if rank >= 2:
			_max_up = 3

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
	_ground = stage.ground_y() if stage != null else Stage.ground_line()

	# The tap catcher: one full-screen surface that turns any touch into a
	# shot. Added FIRST so every button built later sits on top of it.
	var range_surface := Control.new()
	range_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	range_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	range_surface.gui_input.connect(_on_range_input)
	_play_area.add_child(range_surface)

	# Occupants first, rocks second: the rocks draw OVER the risers, which
	# is the whole puppet-theatre trick.
	_actors = Node2D.new()
	_play_area.add_child(_actors)
	var rocks := Node2D.new()
	_play_area.add_child(rocks)
	var rng := Shapes.rng_for(str(level_data.get("id", "range")) + ":rocks")
	for x in SPOT_XS:
		var rock := Node2D.new()
		rock.position = Vector2(x, _ground + 26.0)
		rocks.add_child(rock)
		Shapes.ground_shadow(rock, Vector2.ZERO, 150.0, 0.20)
		var stone: Color = Color(0.42, 0.34, 0.44)
		Shapes.lit(rock, Shapes.blob(Vector2(0, -34.0), Vector2(96.0, 44.0), rng, 0.12, 3, 16),
			stone, 1.0)
		Shapes.lit(rock, Shapes.blob(Vector2(-52.0, -18.0), Vector2(40.0, 24.0), rng, 0.16, 3, 12),
			stone.lightened(0.08), 0.9)
		_spots.append({"x": x, "taken": false, "node": null, "friend": false,
			"chest": Vector2.ZERO, "until": 0.0, "leaving": false})

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "blaster.instruction")))
	_instruction.add_theme_font_size_override("font_size", 34)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(190, 32)
	_instruction.size = Vector2(900, 50)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	# Wordless: zap the monster, spare the puppy.
	_picto = UiKit.pictogram([
		{"icon": "monster", "ok": true}, {"icon": "paw", "ok": false},
	], 68)
	_picto.position = Vector2(240, 82)
	_picto.size = Vector2(800, 72)
	_play_area.add_child(_picto)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_progress)
	_progress.position = Vector2(1070, 34)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)

	var pouch := HBoxContainer.new()
	pouch.position = Vector2(1080, 84)
	pouch.add_theme_constant_override("separation", 6)
	pouch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin_icon: Control = UiKit.picture("coin", 30)
	if coin_icon != null:
		pouch.add_child(coin_icon)
	_coin_label = Label.new()
	_coin_label.text = "0"
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_coin_label, 6)
	pouch.add_child(_coin_label)
	_play_area.add_child(pouch)
	_update_progress()

	# The marksman, down in the corner, out of the firing line.
	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(110, _ground + 58.0)
	_play_area.add_child(_hero)
	_hero.set_height(190.0)


# --- the puppet theatre -----------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if _finished:
		return
	_clock += delta

	var up := 0
	for spot in _spots:
		if spot["taken"]:
			up += 1
	_next_pop -= delta
	if up < _max_up and _next_pop <= 0.0:
		_next_pop = randf_range(0.5, 1.0)
		_pop_one()

	for spot in _spots:
		if spot["taken"] and not spot["leaving"] and _clock >= float(spot["until"]):
			_duck(spot, false)


func _pop_one() -> void:
	var free: Array = _spots.filter(func(s): return not s["taken"])
	if free.is_empty():
		return
	var spot: Dictionary = free[randi() % free.size()]
	var friend: bool = randf() < _friend_ratio

	var riser: Node2D
	var head_h := 150.0
	if friend:
		riser = preload("res://scripts/world/puppy_art.gd").new()
		riser.scale = Vector2(0.62, 0.62)
		head_h = 145.0
	else:
		var spec: Dictionary = (_specs[randi() % _specs.size()] as Dictionary).duplicate()
		riser = preload("res://scripts/battle/monster.gd").new()
		var mon_scale: float = float(spec.get("scale", 0.62))
		riser.scale = Vector2.ONE * mon_scale
		head_h = float(spec.get("height", 210.0)) * mon_scale
		riser.set_meta("spec", spec)
	riser.position = Vector2(float(spot["x"]), _ground + 40.0 + head_h)
	_actors.add_child(riser)
	if not friend:
		riser.build(riser.get_meta("spec"))
	if friend and riser.has_method("wave"):
		riser.wave()    # "it's me, don't shoot!" -- one paw up, waving

	spot["taken"] = true
	spot["node"] = riser
	spot["friend"] = friend
	spot["chest"] = Vector2(float(spot["x"]), _ground - head_h * 0.42)
	spot["until"] = _clock + randf_range(_pop_min, _pop_max)
	spot["leaving"] = false

	var rise_to: float = _ground + 40.0
	if Juice.motion_enabled():
		var t := riser.create_tween()
		t.tween_property(riser, "position:y", rise_to, 0.28)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		riser.position.y = rise_to


func _duck(spot: Dictionary, bonked: bool) -> void:
	spot["leaving"] = true
	var riser: Node2D = spot["node"]
	if riser == null or not is_instance_valid(riser):
		_clear_spot(spot)
		return
	var drop_y: float = riser.position.y + 320.0
	if Juice.motion_enabled():
		var t := riser.create_tween()
		t.tween_interval(0.35 if bonked else 0.0)
		t.tween_property(riser, "position:y", drop_y, 0.30)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(riser.queue_free)
		t.tween_callback(_clear_spot.bind(spot))
	else:
		riser.queue_free()
		_clear_spot(spot)


func _clear_spot(spot: Dictionary) -> void:
	spot["taken"] = false
	spot["node"] = null
	spot["leaving"] = false


# --- shooting ----------------------------------------------------------------

func _on_range_input(event: InputEvent) -> void:
	var pressed: bool = UiKit.is_press(event)
	if not pressed or _finished:
		return
	if _clock < _fire_ready:
		_hero.pulse_core(1)
		return
	_fire_ready = _clock + FIRE_COOLDOWN

	var aim: Vector2 = event.position
	_hero.set_pose(HeroArt.Pose.BEAM)
	var recover := get_tree().create_timer(0.35)
	recover.timeout.connect(func():
		if not _finished and is_instance_valid(_hero):
			_hero.set_pose(HeroArt.Pose.IDLE)
	)
	_bolt(_hero.core_position(), aim)

	# Nearest standing occupant within reach of the shot.
	var best: Dictionary = {}
	var best_d := HIT_RADIUS
	for spot in _spots:
		if not spot["taken"] or spot["leaving"]:
			continue
		var d: float = (spot["chest"] as Vector2).distance_to(aim)
		if d < best_d:
			best_d = d
			best = spot
	if best.is_empty():
		return
	if bool(best["friend"]):
		_zap_friend(best)
	else:
		_bonk(best)


func _bolt(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 10.0
	line.default_color = Color(1.0, 0.86, 0.40)
	line.antialiased = true
	_play_area.add_child(line)
	Shapes.glow(line, to, 48.0, Color(1.0, 0.86, 0.40), 3, 0.5)
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	if Juice.motion_enabled():
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.20)
		t.tween_callback(line.queue_free)
	else:
		get_tree().create_timer(0.22).timeout.connect(func():
			if is_instance_valid(line):
				line.queue_free()
		)


## A bonk, never a wound: flinch, a ring of dizzy stars, down behind the
## rock -- and the till rings: a coin always, an item bubble sometimes, and
## ALWAYS at least one item per level (the pity roll below), because a range
## that pays nothing the whole round taught the wrong lesson about luck.
func _bonk(spot: Dictionary) -> void:
	var riser: Node2D = spot["node"]
	if riser != null and is_instance_valid(riser) and riser.has_method("flinch"):
		riser.flinch()
	var at: Vector2 = spot["chest"]
	Juice.burst(_play_area, at, 12)
	for k in range(3):
		var star: Control = UiKit.star(true, 26)
		star.position = at + Vector2(-40.0 + 32.0 * float(k), -66.0)
		_play_area.add_child(star)
		if Juice.motion_enabled():
			var t := star.create_tween().set_parallel(true)
			t.tween_property(star, "position:y", star.position.y - 34.0, 0.5)
			t.tween_property(star, "modulate:a", 0.0, 0.5)
			t.chain().tween_callback(star.queue_free)
		else:
			get_tree().create_timer(0.6).timeout.connect(func():
				if is_instance_valid(star):
					star.queue_free()
			)
	_duck(spot, true)
	score_correct()
	_update_progress()
	_drop_loot(at)


func _zap_friend(spot: Dictionary) -> void:
	var riser: Node2D = spot["node"]
	if riser != null and is_instance_valid(riser) and riser.has_method("droop"):
		riser.droop()
	Juice.no_sign(_play_area, spot["chest"], 130.0)
	_pulse_rule_tile(1)
	score_mistake()
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	_instruction.text = I18n.t("blaster.friend")
	var timer := get_tree().create_timer(2.2)
	timer.timeout.connect(func():
		if is_instance_valid(_instruction) and not _finished:
			_instruction.text = I18n.t("blaster.instruction")
	)
	_duck(spot, true)


func _pulse_rule_tile(index: int) -> void:
	if _picto == null or not is_instance_valid(_picto):
		return
	var tiles: Array = _picto.get_meta("tiles", [])
	if index < tiles.size() and is_instance_valid(tiles[index]):
		Juice.pop(tiles[index], 0.30)


# --- the till -----------------------------------------------------------------

func _drop_loot(at: Vector2) -> void:
	# The pity roll: if the round is nearly won and no item has dropped yet,
	# this bonk pays one, guaranteed.
	var force_item: bool = _items_dropped == 0 \
		and result.correct >= _targets - 1
	if force_item or randf() < _item_chance:
		_drop_item(at)
	else:
		_drop_coin(at)


func _drop_coin(at: Vector2) -> void:
	_coins_got += 1
	_coin_label.text = str(_coins_got)
	var coin: Control = UiKit.picture("coin", 44)
	if coin == null:
		return
	coin.position = at - Vector2(22, 22)
	_play_area.add_child(coin)
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	if Juice.motion_enabled():
		var t := coin.create_tween().set_parallel(true)
		t.tween_property(coin, "position", Vector2(1084, 84), 0.55)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(coin, "modulate:a", 0.4, 0.55)
		t.chain().tween_callback(coin.queue_free)
	else:
		coin.queue_free()


## An item bubble: the shop good itself, floating gently down, banked into
## the bag the moment it lands. The toast under the pouch says what arrived,
## in pictures.
func _drop_item(at: Vector2) -> void:
	_items_dropped += 1
	var catalog: Array = GameData.rewards.get("items", [])
	if catalog.is_empty():
		_drop_coin(at)
		return
	var item: Dictionary = catalog[randi() % catalog.size()]
	var item_id: String = str(item.get("id", ""))

	var bubble := Control.new()
	bubble.custom_minimum_size = Vector2(84, 84)
	bubble.size = Vector2(84, 84)
	bubble.position = at - Vector2(42, 42)
	bubble.pivot_offset = Vector2(42, 42)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Node2D.new()
	bubble.add_child(pad)
	Shapes.glow(pad, Vector2(42, 42), 52.0, Color(0.65, 0.92, 1.0), 4, 0.4)
	Shapes.fill(pad, Shapes.circle_points(Vector2(42, 42), 40.0, 24),
		Color(0.80, 0.94, 1.0, 0.45), 0.0)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2(42, 42), 40.0, 24)
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(0.65, 0.92, 1.0, 0.9)
	ring.antialiased = true
	bubble.add_child(ring)
	var art: Control = UiKit.picture(str(item.get("icon", "star")), 52)
	if art != null:
		art.position = Vector2(16, 16)
		bubble.add_child(art)
	_play_area.add_child(bubble)
	AudioManager.play_sfx("res://assets/audio/orb_collect.ogg")

	SaveManager.add_item(item_id)
	_toast_item(item)

	if Juice.motion_enabled():
		var t := bubble.create_tween()
		t.tween_property(bubble, "position:y", _ground - 120.0, 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.4)
		t.set_parallel(true)
		t.tween_property(bubble, "scale", Vector2(1.35, 1.35), 0.25)
		t.tween_property(bubble, "modulate:a", 0.0, 0.25)
		t.chain().tween_callback(bubble.queue_free)
	else:
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(bubble):
				bubble.queue_free()
		)


## "+1 [potion]" -- the receipt, readable with zero words.
func _toast_item(item: Dictionary) -> void:
	var toast := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.26, 0.90)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 16
	toast.add_theme_stylebox_override("panel", style)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var plus := Label.new()
	plus.text = "+1"
	plus.add_theme_font_size_override("font_size", 28)
	plus.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75))
	row.add_child(plus)
	var art: Control = UiKit.picture(str(item.get("icon", "star")), 40)
	if art != null:
		row.add_child(art)
	var name_label := Label.new()
	name_label.text = I18n.t(str(item.get("name_key", "")))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Palette.ON_COLOR)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	toast.add_child(row)
	toast.position = Vector2(980, 128)
	_play_area.add_child(toast)
	if Juice.motion_enabled():
		toast.position.x = 1300
		var t := toast.create_tween()
		t.tween_property(toast, "position:x", 980.0, 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(1.6)
		t.tween_property(toast, "modulate:a", 0.0, 0.4)
		t.tween_callback(toast.queue_free)
	else:
		get_tree().create_timer(2.2).timeout.connect(func():
			if is_instance_valid(toast):
				toast.queue_free()
		)


## Coins bank at the finish, same promise as the trail: nothing collected is
## ever taken back.
func complete_level() -> void:
	if not _finished and _coins_got > 0:
		SaveManager.add_coins(_coins_got)
	await super.complete_level()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", _targets)]
