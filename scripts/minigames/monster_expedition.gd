extends LevelManager
## Expedition template: two or three monsters at once, each with its own
## health shown as a row of hearts over its head. Tap a monster to fire at
## it; monsters lob goo back; the star-shop items are usable mid-fight.
##
## This is the "equipment" game the playtester's father asked for, folded
## into the house rules:
##   * Different monsters, different health -- the hearts over each head make
##     "this one is tougher" readable with zero words and zero numbers.
##   * Items, not weapons. A potion that refills your light, a charm that
##     blocks for a while, a star that hits everyone once. Bought with stars
##     in the star shop, spent here one at a time.
##   * Still no fail state. Being hit dims a light pip and costs accuracy;
##     an empty light bar refills itself after a breath. Defeated monsters
##     are TIRED, not dead -- they wave and wander off, like the duels.
##
## A level's config is data all the way down:
##   { "monsters": [ {"id","hp","scale", ...Monster keys...}, ... ],
##     "goo_interval": 3.0 }
## Challenge ranks add a heart to every monster, never speed.

const HERO_POS := Vector2(240, 588)
const ATTACK_COOLDOWN := 0.75
const LIGHT_PIPS := 3
const ITEM_IDS := ["heart_potion", "shield_charm", "star_bomb"]

var _play_area: Control
var _hero: SkinnedCharacter
var _mons: Array = []      # [{node, hp, hp_max, hearts, zone, home, alive}]
var _clock := 0.0
var _attack_ready := 0.0
var _next_goo := 3.0
var _goo_interval := 3.0
var _shield_until := 0.0
var _shield_ring: Node2D
var _light_left := LIGHT_PIPS
var _light_row: Array = []          # heart Controls, dim as light is lost
var _instruction: Label
var _progress: Label
var _item_buttons: Dictionary = {}  # id -> {button, count_label}
var _taught_swat := false           # the "tap the goo" line, shown once


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_goo_interval = maxf(float(config.get("goo_interval", 3.0)), 1.6)
	var specs: Array = (config.get("monsters", []) as Array).duplicate()

	# Challenge scaling: every monster grows one more heart per rank (capped),
	# and the target grows to match. Never faster goo.
	var rank := challenge_rank()
	var extra: int = mini(rank, 3)
	if extra > 0:
		bump_target("correct", extra * specs.size())

	_build_scene(config, specs, extra)
	_next_goo = _goo_interval * 1.2


func _build_scene(config: Dictionary, specs: Array, extra_hp: int) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	build_world(_play_area)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "expedition.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(240, 34)
	_instruction.size = Vector2(800, 52)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	# The wordless version: tap the monster, AND tap the goo. Two ticks,
	# because both taps are things to do -- one attacks, one defends.
	var picto: Control = UiKit.pictogram([
		{"icon": "monster", "ok": true}, {"icon": "goo", "ok": true},
	], 70)
	picto.position = Vector2(240, 84)
	picto.size = Vector2(800, 74)
	_play_area.add_child(picto)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 32)
	_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_progress)
	_progress.position = Vector2(1050, 40)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_progress)

	# The hero's own light, three pips under the back button, clear of the
	# title. Same rule as the duel: a hit dims one; empty refills after a
	# breath; the LEVEL is never lost.
	var pips := HBoxContainer.new()
	pips.position = Vector2(30, 122)
	pips.add_theme_constant_override("separation", 8)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(pips)
	for i in range(LIGHT_PIPS):
		var heart: Control = UiKit.picture("heart", 40)
		if heart != null:
			pips.add_child(heart)
			_light_row.append(heart)

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = HERO_POS
	_play_area.add_child(_hero)
	_hero.set_height(300.0)
	_hero.entrance(340, 0.15)

	# The expedition party of the other side: right of centre, biggest at the
	# back, every one tappable through an invisible full-body button.
	var slots: Array = [Vector2(720, 616), Vector2(950, 604), Vector2(1150, 620)]
	if specs.size() == 2:
		slots = [Vector2(800, 612), Vector2(1080, 618)]
	for i in range(mini(specs.size(), 3)):
		var spec: Dictionary = (specs[i] as Dictionary).duplicate()
		var hp: int = maxi(int(spec.get("hp", 3)) + extra_hp, 1)
		var scale_f: float = float(spec.get("scale", 1.0))
		var mon := preload("res://scripts/battle/monster.gd").new()
		mon.position = slots[i]
		mon.scale = Vector2.ONE * scale_f
		_play_area.add_child(mon)
		mon.build(spec)

		var height: float = float(spec.get("height", 300.0)) * scale_f
		var width: float = height * float(spec.get("width", 0.82))

		var zone := Button.new()
		zone.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled"]:
			zone.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		zone.position = mon.position - Vector2(width * 0.5, height + 46.0)
		zone.size = Vector2(width, height + 46.0)
		zone.pressed.connect(_attack.bind(i))
		_play_area.add_child(zone)

		var entry := {
			"node": mon, "hp": hp, "hp_max": hp, "zone": zone,
			"home": mon.position, "alive": true, "hearts": null,
			"chest": mon.position - Vector2(0, height * 0.55),
			"crown": mon.position.y - height,
		}
		_mons.append(entry)
		_build_hearts(entry)
	_update_progress()
	_build_item_strip()


## The hearts over a monster's head ARE its health bar: filled hearts left to
## live, hollow hearts already won. Counting hearts is something a
## six-year-old does natively; a number or a shrinking rectangle is not.
func _build_hearts(entry: Dictionary) -> void:
	var old: Variant = entry.get("hearts")
	if old is Node and is_instance_valid(old):
		(old as Node).queue_free()
	var mon: Node2D = entry["node"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size := 30.0
	var total: float = float(entry["hp_max"]) * (size + 2.0)
	# Above the whole monster, not on its brows: crown minus a clear margin.
	row.position = Vector2(mon.position.x - total * 0.5,
		float(entry.get("crown", (entry["chest"] as Vector2).y - 200.0)) - 52.0)
	for i in range(int(entry["hp_max"])):
		var heart: Control = UiKit.picture("heart", size)
		if heart != null:
			heart.modulate = Color(1, 1, 1, 1.0) if i < int(entry["hp"]) \
				else Color(0.35, 0.38, 0.48, 0.75)
			row.add_child(heart)
	_play_area.add_child(row)
	entry["hearts"] = row


## The item strip, bottom left: one round button per shop item, with how many
## the child owns riding it as a little count chip. Owning none leaves the
## button visible but asleep -- it doubles as the ad for the star shop.
func _build_item_strip() -> void:
	for i in range(ITEM_IDS.size()):
		var item_id: String = ITEM_IDS[i]
		var b := Button.new()
		var size := 118.0
		b.custom_minimum_size = Vector2(size, size)
		b.position = Vector2(30.0 + float(i) * (size + 22.0), 720.0 - size - 26.0)
		b.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		# Opaque on purpose: a translucent face let the arena's boulders show
		# through the buttons like stains (and translucency is what wakes the
		# rounded-corner seam artifact).
		style.bg_color = Color(0.10, 0.16, 0.32)
		style.set_corner_radius_all(int(size / 2.0))
		style.border_width_bottom = 6
		style.border_width_top = 5
		style.border_width_left = 5
		style.border_width_right = 5
		style.border_color = Color(0.55, 0.95, 0.75)
		var sleepy: StyleBoxFlat = style.duplicate()
		sleepy.border_color = Color(0.35, 0.40, 0.52)
		sleepy.bg_color = Color(0.11, 0.15, 0.26)
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		b.add_theme_stylebox_override("pressed", style)
		b.add_theme_stylebox_override("disabled", sleepy)
		var art: Control = UiKit.picture(_item_icon(item_id), size * 0.60)
		if art != null:
			art.position = Vector2(size * 0.20, size * 0.17)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(art)
		var chip := Label.new()
		chip.add_theme_font_size_override("font_size", 26)
		chip.add_theme_color_override("font_color", Palette.ON_COLOR)
		UiKit.on_art(chip, 6)
		chip.position = Vector2(size - 40.0, size - 44.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chip)
		b.pivot_offset = Vector2(size, size) / 2.0
		b.pressed.connect(_use_item.bind(item_id))
		_play_area.add_child(b)
		_item_buttons[item_id] = {"button": b, "count": chip}
	_refresh_items()


func _item_icon(item_id: String) -> String:
	match item_id:
		"heart_potion": return "potion"
		"shield_charm": return "shield"
		_: return "star_bomb"


func _refresh_items() -> void:
	for item_id in _item_buttons:
		var owned: int = SaveManager.item_count(item_id)
		var parts: Dictionary = _item_buttons[item_id]
		(parts["button"] as Button).disabled = owned <= 0
		(parts["count"] as Label).text = "x%d" % owned


# --- the fight -------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if _finished:
		return
	_clock += delta

	# The counter-attack drumbeat: one goo at a time, from whoever is awake.
	_next_goo -= delta
	if _next_goo <= 0.0:
		_next_goo = _goo_interval * randf_range(0.85, 1.25)
		_lob_goo()

	if _shield_ring != null and is_instance_valid(_shield_ring):
		if _clock >= _shield_until:
			_shield_ring.queue_free()
			_shield_ring = null
		else:
			_shield_ring.position = _hero.position


func _attack(index: int) -> void:
	if _finished or index >= _mons.size():
		return
	var entry: Dictionary = _mons[index]
	if not bool(entry["alive"]):
		return
	if _clock < _attack_ready:
		# Not silence -- the core brightens: "almost, one breath". Silence
		# after a tap is how a child decides a button is broken.
		_hero.pulse_core(1)
		return
	_attack_ready = _clock + ATTACK_COOLDOWN
	_hero.set_pose(HeroArt.Pose.BEAM)
	_bolt(_hero.core_position(), entry["chest"], Color(1.0, 0.86, 0.40))
	_hit(index, 1)
	var back_timer := get_tree().create_timer(0.4)
	back_timer.timeout.connect(func():
		if not _finished and _hero != null and is_instance_valid(_hero):
			_hero.set_pose(HeroArt.Pose.IDLE)
	)


## One point of damage to one monster, with everything a hit owes the eye:
## bolt already flying, flinch, a heart hollowing, the meter climbing.
func _hit(index: int, amount: int) -> void:
	var entry: Dictionary = _mons[index]
	if not bool(entry["alive"]):
		return
	entry["hp"] = maxi(int(entry["hp"]) - amount, 0)
	var mon: Node2D = entry["node"]
	if mon.has_method("flinch"):
		mon.flinch()
	Juice.burst(_play_area, entry["chest"], 10)
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	_build_hearts(entry)
	score_correct()
	_update_progress()
	if int(entry["hp"]) <= 0:
		_retire(entry)


## A beaten monster is tired, not dead: brows up, a happy bounce, a wave,
## and off it wanders. Same ending as every battle in this game.
func _retire(entry: Dictionary) -> void:
	entry["alive"] = false
	var zone: Button = entry["zone"]
	if is_instance_valid(zone):
		zone.disabled = true
	var hearts: Variant = entry.get("hearts")
	if hearts is Node and is_instance_valid(hearts):
		(hearts as Node).queue_free()
		entry["hearts"] = null
	var mon: Node2D = entry["node"]
	if mon.has_method("leave_happy"):
		mon.leave_happy()
	if Juice.motion_enabled():
		var t := mon.create_tween()
		t.tween_interval(0.9)
		t.set_parallel(true)
		t.tween_property(mon, "position:x", mon.position.x + 260.0, 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(mon, "modulate:a", 0.0, 1.1)
	else:
		mon.modulate.a = 0.35


func _bolt(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 11.0
	line.default_color = color
	line.antialiased = true
	_play_area.add_child(line)
	Shapes.glow(line, to, 60.0, color, 3, 0.5)
	if Juice.motion_enabled():
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.22)
		t.tween_callback(line.queue_free)
	else:
		get_tree().create_timer(0.25).timeout.connect(func():
			if is_instance_valid(line):
				line.queue_free()
		)


# --- being fought back at ---------------------------------------------------

func _lob_goo() -> void:
	var awake: Array = _mons.filter(func(m): return bool(m["alive"]))
	if awake.is_empty():
		return
	var entry: Dictionary = awake[randi() % awake.size()]
	var mon: Node2D = entry["node"]
	if mon.has_method("puff_up"):
		mon.puff_up()
	# Say it once, the first time something is thrown: the strip shows the
	# goo with a tick, and the line names the verb for the parent reading
	# over his shoulder.
	if not _taught_swat:
		_taught_swat = true
		_say(I18n.t("expedition.swat"))

	# A BUTTON, so it can be swatted out of the air. The expedition had no
	# defence at all except a bought charm -- fine while the light bar was
	# decorative, unplayable the moment running out actually ends the level.
	# Tapping the thing flying at you is a defence a six-year-old invents on
	# his own.
	var goo := Button.new()
	var goo_size := Vector2(104, 104)
	goo.custom_minimum_size = goo_size
	goo.size = goo_size
	goo.pivot_offset = goo_size / 2.0
	goo.focus_mode = Control.FOCUS_NONE
	goo.position = (entry["chest"] as Vector2) - goo_size / 2.0
	for state in ["normal", "hover", "pressed", "disabled"]:
		goo.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var art := Node2D.new()
	art.position = goo_size / 2.0
	goo.add_child(art)
	var rng := Shapes.rng_for("goo%f" % _clock)
	Shapes.lit(art, Shapes.blob(Vector2.ZERO, Vector2(30.0, 25.0), rng, 0.22, 3, 12),
		Color(0.56, 0.78, 0.35), 0.9)
	Shapes.fill(art, Shapes.oval_points(Vector2(-9.0, -9.0), Vector2(8.0, 5.0), 10),
		Color(1, 1, 1, 0.45), 0.0)
	goo.pressed.connect(_swat_goo.bind(goo))
	_play_area.add_child(goo)

	var flight := 1.15
	var lands: Vector2 = _hero.position + Vector2(0, -110.0) - goo_size / 2.0
	if Juice.motion_enabled():
		var t := goo.create_tween()
		t.tween_property(goo, "position", lands, flight)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(_goo_arrives.bind(goo))
	else:
		goo.position = lands
		get_tree().create_timer(flight).timeout.connect(_goo_arrives.bind(goo))


## Swatted out of the air: it bursts and nothing is lost. No score --
## defending is its own reward, and scoring it would inflate the target.
func _swat_goo(goo: Control) -> void:
	if not is_instance_valid(goo) or _finished:
		return
	Juice.burst(_play_area, goo.position + goo.size / 2.0, 12)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	goo.queue_free()


func _goo_arrives(goo: Control) -> void:
	if _finished:
		if is_instance_valid(goo):
			goo.queue_free()
		return
	var at: Vector2 = _hero.position + Vector2(0, -110.0)
	if is_instance_valid(goo):
		at = goo.position + goo.size / 2.0
		goo.queue_free()

	if _clock < _shield_until:
		# Blocked: the charm turns the hit into sparkles, and that is all --
		# the shield protects, it does not counter, so the charm never
		# becomes the only way anyone would ever fight.
		Juice.burst(_play_area, at, 14)
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		return
	_lose_light()


func _lose_light() -> void:
	_light_left = maxi(_light_left - 1, 0)
	_refresh_light()
	score_mistake()
	_hero.stumble()
	if _light_left == 0:
		_out_of_light()


## Empty bar, so the expedition STOPS -- it used to top itself up after a
## breath, which is why a parent watched his son take hit after hit with an
## empty bar and nothing happening at all. Spend a Heart Potion and carry
## on, or finish here with the reward already earned. Finishing is a real
## ending: the result reports normally and still earns its star.
func _out_of_light() -> void:
	if _finished:
		return
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	get_tree().paused = true
	UiKit.light_out_card(_play_area, SaveManager.item_count("heart_potion"),
		func():
			get_tree().paused = false
			if not SaveManager.use_item("heart_potion"):
				return
			_light_left = LIGHT_PIPS
			_refresh_light()
			_hero.power_up()
			Juice.burst(_play_area, _hero.position + Vector2(0, -140.0), 18)
			AudioManager.play_sfx("res://assets/audio/power_up.ogg")
			_refresh_items(),
		func():
			get_tree().paused = false
			complete_level())


func _refresh_light() -> void:
	for i in range(_light_row.size()):
		var heart: Control = _light_row[i]
		if is_instance_valid(heart):
			heart.modulate = Color(1, 1, 1, 1.0) if i < _light_left \
				else Color(0.35, 0.38, 0.48, 0.75)


# --- the items ---------------------------------------------------------------

func _use_item(item_id: String) -> void:
	if _finished:
		return
	match item_id:
		"heart_potion":
			# Only useful when light is missing; a full bar politely refuses
			# rather than silently eating the potion.
			if _light_left >= LIGHT_PIPS:
				_refuse(item_id)
				return
			if not SaveManager.use_item(item_id):
				return
			_light_left = LIGHT_PIPS
			_refresh_light()
			_hero.power_up()
			Juice.burst(_play_area, _hero.position + Vector2(0, -140.0), 16)
			AudioManager.play_sfx("res://assets/audio/power_up.ogg")
		"shield_charm":
			if _clock < _shield_until:
				_refuse(item_id)
				return
			if not SaveManager.use_item(item_id):
				return
			_shield_until = _clock + 6.0
			_shield_ring = Node2D.new()
			_shield_ring.position = _hero.position
			_play_area.add_child(_shield_ring)
			var ring := Line2D.new()
			ring.points = Shapes.circle_points(Vector2(0, -110.0), 150.0, 30)
			ring.closed = true
			ring.width = 8.0
			ring.default_color = Color(0.55, 0.85, 1.0, 0.9)
			ring.antialiased = true
			_shield_ring.add_child(ring)
			Shapes.glow(_shield_ring, Vector2(0, -110.0), 170.0, Color(0.55, 0.85, 1.0), 4, 0.25)
			AudioManager.play_sfx("res://assets/audio/power_up.ogg")
		"star_bomb":
			var awake: Array = _mons.filter(func(m): return bool(m["alive"]))
			if awake.is_empty():
				_refuse(item_id)
				return
			if not SaveManager.use_item(item_id):
				return
			AudioManager.play_sfx("res://assets/audio/star.ogg")
			for i in range(_mons.size()):
				if bool(_mons[i]["alive"]):
					_bolt(_hero.core_position(), _mons[i]["chest"], Color(1.0, 0.70, 0.30))
					_hit(i, 1)
	_refresh_items()


## "Not now", said kindly: the button wobbles, nothing is spent.
func _refuse(item_id: String) -> void:
	var parts: Dictionary = _item_buttons.get(item_id, {})
	if parts.has("button"):
		Juice.nudge(parts["button"])


## Swap the instruction line for a moment, then put the standing one back.
func _say(text: String) -> void:
	if _instruction == null or not is_instance_valid(_instruction):
		return
	_instruction.text = text
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(_instruction) and not _finished:
			_instruction.text = I18n.t("expedition.instruction")
	)


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = "%d / %d" % [result.correct, target_value("correct", 5)]
