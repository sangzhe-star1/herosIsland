extends LevelManager
## Light Defence: the monsters keep coming, and the hero keeps getting
## stronger.
##
## The last monster used to walk off and then nothing happened at all -- no
## cheer, no confetti, no fanfare, just a cut to the results screen. The duel
## template has had a proper curtain call the whole time; see complete_level
## at the bottom of this file for the one this now shares with it.
##
## Replaces the whack-a-mole range, for two reasons the playtester's father
## gave in one breath: the shooting level should have a STREAM of monsters
## rather than heads popping politely out of holes, and the island's levels
## had become too alike -- eight worlds, but most of them one game repeated.
## This is the answer to both: nothing else in the game is a wave defence,
## and nothing else in the game grows a build.
##
## The loop, which is the modern roguelite loop shrunk to six-year-old size:
##
##   monsters walk in from the right, always
##       -> tap ANYWHERE to fire a blast at that spot
##       -> every few defeated, everything stops and you CHOOSE an upgrade
##       -> the upgrades stack, so the last wave is fought with a weapon
##          the child assembled themselves
##
## Seven upgrades, drafted three at a time:
##   rapid   fire faster            spread  one more bolt per tap
##   power   each bolt hits harder  wide    a bigger blast
##   slow    hit monsters trudge    split   the blast seeks another monster
##   guard   one more light heart, refilled
##
## House rules unchanged. Nothing is killed -- a defeated monster is dizzy,
## waves and wanders off. A monster that reaches the hero costs one light
## heart and leaves; when the light runs out the fight stops and the child
## chooses a Heart Potion or to finish there, exactly like the duels.
##
## Level config:
##   { "targets": 14, "spawn_interval": 2.1, "speed": 44, "hp_min": 1,
##     "hp_max": 2, "per_pick": 4, "monsters": [ ...Monster keys... ] }

const HERO_X := 190.0
const SPAWN_X := 1360.0
const REACH_X := 300.0            # where a monster counts as arriving
## Tuning. The first pass was too gentle to lose: monsters strolled in one
## at a time and a child could clear a level without ever using a pick.
## Faster spawns, tougher walkers, a shorter default reach -- and the
## upgrades stay generous, so the answer to "harder" is "build better".
const BASE_COOLDOWN := 0.62
const BASE_BLAST := 96.0
const BASE_LIGHT := 3
const MAX_LEVEL := 3              # per upgrade, so no single pick runs away

## id -> {icon, name_key, desc_key}. The pool the draft deals from.
const UPGRADES := {
	"rapid": {"icon": "lightning", "name_key": "up.rapid", "desc_key": "up.rapid_desc"},
	"spread": {"icon": "spread", "name_key": "up.spread", "desc_key": "up.spread_desc"},
	"power": {"icon": "power", "name_key": "up.power", "desc_key": "up.power_desc"},
	"wide": {"icon": "blast", "name_key": "up.wide", "desc_key": "up.wide_desc"},
	"slow": {"icon": "slow", "name_key": "up.slow", "desc_key": "up.slow_desc"},
	"split": {"icon": "split", "name_key": "up.split", "desc_key": "up.split_desc"},
	"guard": {"icon": "shield", "name_key": "up.guard", "desc_key": "up.guard_desc"},
}

var _targets := 14
var _spawn_interval := 2.1
var _speed := 44.0
var _hp_min := 1
var _hp_max := 2
var _per_pick := 4
var _specs: Array = []

var _play_area: Control
var _hero: SkinnedCharacter
var _walkers: Array = []          # [{node, hp, hp_max, hearts, slow_until, alive}]
var _levels: Dictionary = {}      # upgrade id -> how many times taken
var _clock := 0.0
var _fire_ready := 0.0
var _spawn_at := 1.2
var _start_interval := 2.1
var _end_interval := 1.3
var _defeated := 0
var _charge := 0
var _light_left := BASE_LIGHT
var _light_row: Array = []
var _light_box: HBoxContainer
var _badges: HBoxContainer
var _ground := 620.0
var _instruction: Label
var _progress: Label            # only when there are too many for pips
var _pip_row: HBoxContainer
var _pips: Array[Control] = []
var _drafting := false


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_targets = target_value("correct", int(config.get("targets", 14)))
	_spawn_interval = maxf(float(config.get("spawn_interval", 2.1)), 0.9)
	_speed = clampf(float(config.get("speed", 44.0)), 20.0, 90.0)
	_hp_min = maxi(int(config.get("hp_min", 1)), 1)
	_hp_max = maxi(int(config.get("hp_max", 2)), _hp_min)
	_per_pick = maxi(int(config.get("per_pick", 4)), 2)
	_specs = (config.get("monsters", []) as Array).duplicate()
	if _specs.is_empty():
		_specs = [{"id": "creep", "body_color": "#7fb069", "belly_color": "#cde6b2",
			"accent_color": "#4f7d43", "height": 190, "scale": 0.6}]

	# Challenge scaling: more monsters and a touch more health. The walk
	# never speeds up -- a longer siege, not a twitchier one.
	var rank := challenge_rank()
	if rank > 0:
		bump_target("correct", mini(rank * 3, 12))
		_targets = target_value("correct", _targets)
		_hp_max += mini(rank, 2)
		_spawn_interval = maxf(_spawn_interval * pow(0.92, rank), 0.85)
		_speed = minf(_speed + 3.0 * float(rank), 80.0)

	# The siege tightens as it goes: by the last third the monsters arrive
	# roughly half again as often as at the start. A wave defence whose
	# pressure never rises is a queue, not a siege.
	_start_interval = _spawn_interval
	_end_interval = maxf(_spawn_interval * 0.62, 0.75)

	# Difficulty: they arrive sooner, walk faster, carry more health, and
	# a pick costs one more of them.
	_spawn_interval = harder(_spawn_interval, 0.82)
	_speed = clampf(harder(_speed, 1.16), 20.0, 92.0)
	_hp_max = maxi(harder_i(_hp_max, 1), _hp_min)
	_per_pick = maxi(harder_i(_per_pick, 1), 2)
	_start_interval = _spawn_interval
	_end_interval = maxf(_spawn_interval * 0.62, 0.70)

	_light_left = BASE_LIGHT
	_build_scene(config)


# --- construction -----------------------------------------------------------

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

	# One surface that turns any touch into a shot, added before everything
	# else so every button built later sits on top of it.
	var field := Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.gui_input.connect(_on_field_input)
	_play_area.add_child(field)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "defense.instruction")))
	_instruction.add_theme_font_size_override("font_size", 34)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(240, 28)
	_instruction.size = Vector2(800, 48)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	# 还剩几只，用图说.
	#
	# This was "3 / 8" at 30 px, which is a sentence in a language the player
	# does not read yet. A row of little monsters says the same thing without
	# any: the ones he has seen off are bright, the ones still coming are dim.
	# Same trick as the light hearts on the other side of the screen, so the
	# two halves of the HUD are read the same way.
	_pip_row = HBoxContainer.new()
	_pip_row.add_theme_constant_override("separation", 6)
	_pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_pip_row)
	_build_pips()

	# The hero's light, top left under the back button.
	_light_box = HBoxContainer.new()
	# 132, not 118: the back button ends at y=120 and the hearts sat on its
	# bottom edge by two pixels.
	_light_box.position = Vector2(30, 132)
	_light_box.add_theme_constant_override("separation", 8)
	_light_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_light_box)
	_rebuild_light()

	# The build, as a row of badges: what the child has collected so far,
	# always visible, because a build you cannot see is not a build.
	_badges = HBoxContainer.new()
	_badges.position = Vector2(30, 190)
	_badges.add_theme_constant_override("separation", 8)
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_badges)

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(HERO_X, _ground + 40.0)
	_play_area.add_child(_hero)
	_hero.set_height(250.0)
	_update_progress()


# --- the siege ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if _finished or _drafting:
		return
	_clock += delta

	_spawn_at -= delta
	if _spawn_at <= 0.0:
		# Interval slides from the opening pace to the closing one as the
		# level is cleared, so the last monsters come in a crowd.
		var through: float = clampf(float(_defeated) / float(maxi(_targets, 1)), 0.0, 1.0)
		_spawn_interval = lerpf(_start_interval, _end_interval, through)
		_spawn_at = _spawn_interval * randf_range(0.78, 1.18)
		_spawn_walker()

	for walker in _walkers.duplicate():
		if not bool(walker["alive"]):
			continue
		var node: Node2D = walker["node"]
		if not is_instance_valid(node):
			_walkers.erase(walker)
			continue
		var pace: float = _speed * float(walker.get("pace", 1.0))
		if _clock < float(walker["slow_until"]):
			pace *= 0.42
		node.position.x -= pace * delta
		if node.position.x <= REACH_X:
			_arrives(walker)


func _spawn_walker() -> void:
	var spec: Dictionary = (_specs[randi() % _specs.size()] as Dictionary).duplicate()
	# A spec may fix its own health and its own rarity. That is what makes a
	# BOSS possible: one huge slow creature with six hearts among the
	# one-heart runners, without a second template or a second level type.
	if spec.has("rarity") and randf() > float(spec["rarity"]):
		spec = (_specs[0] as Dictionary).duplicate()
	var hp: int = int(spec["hp"]) if spec.has("hp") else randi_range(_hp_min, _hp_max)
	var scale_f: float = float(spec.get("scale", 0.6))
	var mon := preload("res://scripts/battle/monster.gd").new()
	mon.scale = Vector2.ONE * scale_f
	# Spread the lane a little so a queue of monsters is a crowd, not a line.
	mon.position = Vector2(SPAWN_X, _ground + randf_range(6.0, 62.0))
	_play_area.add_child(mon)
	mon.build(spec)

	var height: float = float(spec.get("height", 190.0)) * scale_f
	var walker := {
		"node": mon, "hp": hp, "hp_max": hp, "hearts": null,
		"slow_until": 0.0, "alive": true, "height": height,
		"pace": float(spec.get("pace", 1.0)),
	}
	_walkers.append(walker)
	_rebuild_hearts(walker)


## A monster's health, as hearts riding above its head. They are children of
## the monster itself, so they walk along without a line of update code.
func _rebuild_hearts(walker: Dictionary) -> void:
	var old: Variant = walker.get("hearts")
	if old is Node and is_instance_valid(old):
		(old as Node).queue_free()
	var mon: Node2D = walker["node"]
	if not is_instance_valid(mon):
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size := 34.0
	var total: float = float(walker["hp_max"]) * (size + 2.0)
	# In the monster's own (scaled) space, so the row sits over its head.
	row.position = Vector2(-total * 0.5, -float(walker["height"]) / mon.scale.y - 46.0)
	for i in range(int(walker["hp_max"])):
		var heart: Control = UiKit.picture("heart", size)
		if heart != null:
			heart.modulate = Color(1, 1, 1, 1.0) if i < int(walker["hp"]) \
				else Color(0.35, 0.38, 0.48, 0.7)
			row.add_child(heart)
	mon.add_child(row)
	walker["hearts"] = row


## A monster that walks all the way in bumps the hero and wanders off with
## its prize: one light heart. It is never a death and never a game over.
func _arrives(walker: Dictionary) -> void:
	walker["alive"] = false
	_walkers.erase(walker)
	var node: Node2D = walker["node"]
	if is_instance_valid(node):
		Juice.burst(_play_area, node.position + Vector2(0, -70.0), 12)
		node.queue_free()
	_hero.stumble()
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	score_mistake()
	_light_left = maxi(_light_left - 1, 0)
	_refresh_light()
	if _light_left == 0:
		_out_of_light()


# --- shooting ----------------------------------------------------------------

func _on_field_input(event: InputEvent) -> void:
	if not UiKit.is_press(event) or _finished or _drafting:
		return
	if _clock < _fire_ready:
		_hero.pulse_core(1)      # "almost" -- never silence
		return
	_fire_ready = _clock + _cooldown()
	_hero.set_pose(HeroArt.Pose.BEAM)
	var settle := get_tree().create_timer(0.3)
	settle.timeout.connect(func():
		if not _finished and is_instance_valid(_hero):
			_hero.set_pose(HeroArt.Pose.IDLE)
	)

	var aim: Vector2 = _event_position(event)
	var shots: int = 1 + _level("spread")
	var from: Vector2 = _hero.core_position()
	for i in range(shots):
		# The fan opens around the aimed point, so the first bolt always
		# goes exactly where the finger went.
		var offset := Vector2.ZERO
		if shots > 1:
			var k: float = float(i) - float(shots - 1) * 0.5
			offset = (aim - from).normalized().orthogonal() * k * 92.0
		_bolt(from, aim + offset, i == 0)


func _cooldown() -> float:
	return BASE_COOLDOWN * pow(0.74, float(_level("rapid")))


func _blast_radius() -> float:
	return BASE_BLAST * (1.0 + 0.30 * float(_level("wide")))


func _damage() -> int:
	return 1 + _level("power")


func _level(id: String) -> int:
	return int(_levels.get(id, 0))


## The colour of the gun. Frost turns it blue, power turns it molten -- the
## bolt has to ANNOUNCE the build, because a draft you cannot see the effect
## of is a draft that feels like it did nothing. (Which is exactly what got
## reported: "the different guns aren't reflected in the skills".)
func _bolt_color() -> Color:
	if _level("slow") > 0:
		return Color(0.60, 0.88, 1.0)
	if _level("power") >= 2:
		return Color(1.0, 0.62, 0.26)
	if _level("power") == 1:
		return Color(1.0, 0.76, 0.32)
	return Color(1.0, 0.86, 0.40)


func _bolt(from: Vector2, to: Vector2, allow_split: bool) -> void:
	var tint := _bolt_color()
	# Thicker with every point of power: the beam visibly fattens as the
	# build grows, which is the cheapest possible "you got stronger".
	var thickness: float = 9.0 + 4.0 * float(_level("power"))
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = thickness
	line.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	line.antialiased = true
	_play_area.add_child(line)
	# A white-hot core inside the beam once it is strong: two lines read as
	# one heavy beam, which one line never does however wide you make it.
	if _level("power") > 0:
		var core := Line2D.new()
		core.points = line.points
		core.width = thickness * 0.42
		core.default_color = Color(1, 1, 1, 0.9)
		core.antialiased = true
		line.add_child(core)
	# The muzzle flash grows with the gun too.
	Shapes.glow(line, from, 40.0 + 16.0 * float(_level("power")), tint, 3, 0.55)

	if Juice.motion_enabled():
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.16 + 0.03 * float(_level("power")))
		t.tween_callback(line.queue_free)
	else:
		get_tree().create_timer(0.2).timeout.connect(func():
			if is_instance_valid(line):
				line.queue_free()
		)
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	_blast(to, allow_split)


## The bang: everything inside the radius takes the hit. A blast rather than
## a bullet is what makes a fan of shots feel generous instead of fiddly,
## and it forgives a six-year-old's aim by design.
func _blast(at: Vector2, allow_split: bool) -> void:
	var tint := _bolt_color()
	var radius: float = _blast_radius()
	var ring := Node2D.new()
	ring.position = at
	_play_area.add_child(ring)
	Shapes.glow(ring, Vector2.ZERO, radius * 0.9, tint, 4, 0.45)
	# An actual outline at the actual radius. Glow alone gave no edge, so
	# "Big Blast" changed a number nobody could see; a ring you can watch
	# swallow three monsters is the upgrade, made visible.
	var edge := Line2D.new()
	edge.points = Shapes.circle_points(Vector2.ZERO, radius, 30)
	edge.closed = true
	edge.width = 6.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	edge.antialiased = true
	ring.add_child(edge)
	# Frost leaves a rime of shards behind; the slow is a look, not a stat.
	if _level("slow") > 0:
		for k in range(6):
			var a16: float = TAU * float(k) / 6.0 + 0.3
			Shapes.fill(ring, Shapes.star_points(
				Vector2(cos(a16), sin(a16)) * radius * 0.66, radius * 0.09, 0.4, 6),
				Color(0.82, 0.95, 1.0, 0.9), 0.0)
	if Juice.motion_enabled():
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.26)
		t.tween_property(ring, "modulate:a", 0.0, 0.26)
		t.chain().tween_callback(ring.queue_free)
	else:
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(ring):
				ring.queue_free()
		)

	var hit: Array = []
	for walker in _walkers.duplicate():
		if not bool(walker["alive"]):
			continue
		var node: Node2D = walker["node"]
		if not is_instance_valid(node):
			continue
		if node.position.distance_to(at) > _blast_radius() + 40.0:
			continue
		hit.append(walker)
		_wound(walker, _damage())

	# Split: the blast goes looking for the nearest monster it did NOT hit.
	if allow_split and _level("split") > 0:
		var seeking: int = _level("split")
		for walker in _nearest_unhit(at, hit, seeking):
			_bolt(at, (walker["node"] as Node2D).position + Vector2(0, -60.0), false)


func _nearest_unhit(at: Vector2, already: Array, count: int) -> Array:
	var pool: Array = []
	for walker in _walkers:
		if not bool(walker["alive"]) or walker in already:
			continue
		if not is_instance_valid(walker["node"]):
			continue
		pool.append(walker)
	pool.sort_custom(func(a, b):
		return (a["node"] as Node2D).position.distance_to(at) \
			< (b["node"] as Node2D).position.distance_to(at))
	return pool.slice(0, count)


func _wound(walker: Dictionary, amount: int) -> void:
	walker["hp"] = maxi(int(walker["hp"]) - amount, 0)
	var node: Node2D = walker["node"]
	if is_instance_valid(node) and node.has_method("flinch"):
		node.flinch()
	if _level("slow") > 0:
		walker["slow_until"] = _clock + 2.4
		if is_instance_valid(node):
			node.modulate = Color(0.78, 0.90, 1.0)
	if int(walker["hp"]) > 0:
		_rebuild_hearts(walker)
		return
	_defeat(walker)


## Defeated: dizzy, a wave, and off it wanders. And the meter climbs.
func _defeat(walker: Dictionary) -> void:
	walker["alive"] = false
	_walkers.erase(walker)
	var node: Node2D = walker["node"]
	if is_instance_valid(node):
		var hearts: Variant = walker.get("hearts")
		if hearts is Node and is_instance_valid(hearts):
			(hearts as Node).queue_free()
		Juice.burst(_play_area, node.position + Vector2(0, -70.0), 12)
		if node.has_method("leave_happy"):
			node.leave_happy()
		if Juice.motion_enabled():
			var t := node.create_tween().set_parallel(true)
			t.tween_property(node, "position:y", node.position.y - 40.0, 0.6)
			t.tween_property(node, "modulate:a", 0.0, 0.6)
			t.chain().tween_callback(node.queue_free)
		else:
			node.queue_free()
	# monster_defeat, not coin. A coin is the sound of buying something, and
	# what just happened is a monster getting tired and waving goodbye -- the
	# two were never the same event, and score_correct() below already plays
	# correct.ogg on the same frame, so this was also two sounds at once.
	AudioManager.play_sfx("res://assets/audio/monster_defeat.ogg")
	_defeated += 1
	score_correct()
	_update_progress()

	if _defeated >= _targets:
		complete_level()
		return
	_charge += 1
	if _charge >= _per_pick:
		_charge = 0
		_offer_draft()


# --- the draft ---------------------------------------------------------------

## Everything stops and three upgrades are laid out. Choosing is the whole
## point: two children who play the same level come out with different
## weapons, which is the one thing this island did not have anywhere.
func _offer_draft() -> void:
	var pool: Array = []
	for id in UPGRADES.keys():
		if _level(str(id)) < MAX_LEVEL:
			pool.append(str(id))
	if pool.is_empty():
		return
	pool.shuffle()
	var offer: Array = pool.slice(0, mini(3, pool.size()))

	_drafting = true
	get_tree().paused = true
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.z_index = 90
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	_play_area.add_child(holder)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.03, 0.06, 0.14, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(centre)
	var card := UiKit.card()
	centre.add_child(card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(UiKit.title(I18n.t("defense.pick"), 40))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	for id in offer:
		row.add_child(_draft_card(str(id), holder))


func _draft_card(id: String, holder: Control) -> Control:
	var spec: Dictionary = UPGRADES[id]
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)

	var have: int = _level(id)
	var label := I18n.t(str(spec["name_key"]))
	if have > 0:
		label += "  +%d" % have
	var button := UiKit.icon_button(label, str(spec["icon"]),
		Palette.BLUE if have == 0 else Palette.GREEN, Vector2(250, 220))
	button.pressed.connect(func():
		holder.queue_free()
		_take(id))
	box.add_child(button)

	# What it DOES, in pictures.
	#
	# This was one line of 20 px grey text and nothing else -- the single most
	# text-only thing left in the game, on the one screen where a six-year-old
	# has to make a real choice. "爆炸会再找一只怪兽" is three cards of letters
	# to him, so he picks whichever is on the left.
	#
	# The row below says it as a before-and-after: what he has now, an arrow,
	# what he would have. Nothing to read, and it is TRUE rather than generic --
	# a card taken twice shows two becoming three, not one becoming two.
	var shows: Array = _picture_of(id, have)
	if not shows.is_empty():
		var strip := HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 6)
		for item in shows:
			var art: Control = UiKit.picture(str(item), 30.0)
			if art != null:
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				strip.add_child(art)
		box.add_child(strip)

	# The words stay, smaller and under the picture. They are for the adult in
	# the room, who is often the one being asked "which one should I take?".
	var desc := UiKit.title(I18n.t(str(spec["desc_key"])), 18, Palette.INK_SOFT)
	desc.custom_minimum_size = Vector2(250, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	return box


## The before-and-after strip for one upgrade: icons, "next", icons.
##
## Every name here is already in the icon library -- nothing new is drawn, and
## nothing is invented that the level does not actually do:
##
##   rapid   fewer waits         one lightning  -> two
##   spread  one more bolt       n sparks       -> n+1
##   power   a harder hit        one fist       -> two
##   wide    a bigger blast      small blast    -> big blast (two of them)
##   slow    they trudge         one snowflake  -> two
##   split   it finds another    one monster    -> two monsters
##   guard   one more heart      n hearts       -> n+1
func _picture_of(id: String, have: int) -> Array:
	var was: int = 1 + have
	var now: int = was + 1
	var icon := ""
	match id:
		"rapid": icon = "lightning"
		"spread": icon = "spark"
		"power": icon = "power"
		"wide": icon = "blast"
		"slow": icon = "slow"
		"split": icon = "monster"
		"guard":
			icon = "heart"
			was = BASE_LIGHT + have
			now = was + 1
		_: return []
	# Kept short: a strip of nine hearts is a counting exercise, not a picture.
	var out: Array = []
	for i in range(mini(was, 3)):
		out.append(icon)
	out.append("next")
	for i in range(mini(now, 4)):
		out.append(icon)
	return out


func _take(id: String) -> void:
	_levels[id] = _level(id) + 1
	if id == "guard":
		# A guard heart is worth having NOW, not next level.
		_light_left += 1
		_rebuild_light()
	_refresh_badges()
	get_tree().paused = false
	_drafting = false
	if is_instance_valid(_hero):
		_hero.power_up()
	Juice.burst(_play_area, _hero.position + Vector2(0, -150.0), 20)


## The build, on screen: one badge per upgrade held, with its level.
func _refresh_badges() -> void:
	if _badges == null or not is_instance_valid(_badges):
		return
	for child in _badges.get_children():
		child.queue_free()
	for id in UPGRADES.keys():
		var have: int = _level(str(id))
		if have <= 0:
			continue
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(52, 52)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := Node2D.new()
		chip.add_child(pad)
		Shapes.fill(pad, Shapes.circle_points(Vector2(26, 26), 24.0, 20),
			Color(0.05, 0.09, 0.20, 0.55), 0.0)
		var art: Control = UiKit.picture(str(UPGRADES[id]["icon"]), 34)
		if art != null:
			art.position = Vector2(9, 6)
			chip.add_child(art)
		var pip := Label.new()
		pip.text = "%d" % have
		pip.add_theme_font_size_override("font_size", 18)
		pip.add_theme_color_override("font_color", Palette.ON_COLOR)
		UiKit.on_art(pip, 5)
		pip.position = Vector2(33, 26)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(pip)
		_badges.add_child(chip)


# --- the light bar -----------------------------------------------------------

func _rebuild_light() -> void:
	if _light_box == null or not is_instance_valid(_light_box):
		return
	for child in _light_box.get_children():
		child.queue_free()
	_light_row.clear()
	var total: int = maxi(_light_left, BASE_LIGHT + _level("guard"))
	for i in range(total):
		var heart: Control = UiKit.picture("heart", 40)
		if heart != null:
			_light_box.add_child(heart)
			_light_row.append(heart)
	_refresh_light()


func _refresh_light() -> void:
	for i in range(_light_row.size()):
		var heart: Control = _light_row[i]
		if is_instance_valid(heart):
			heart.modulate = Color(1, 1, 1, 1.0) if i < _light_left \
				else Color(0.35, 0.38, 0.48, 0.7)


func _out_of_light() -> void:
	if _finished:
		return
	_drafting = true                 # gate the siege while the card is up
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	get_tree().paused = true
	UiKit.light_out_card(_play_area, SaveManager.item_count("heart_potion"),
		func():
			get_tree().paused = false
			_drafting = false
			if not SaveManager.use_item("heart_potion"):
				return
			_light_left = BASE_LIGHT + _level("guard")
			_refresh_light()
			_hero.power_up()
			Juice.burst(_play_area, _hero.position + Vector2(0, -150.0), 18)
			AudioManager.play_sfx("res://assets/audio/power_up.ogg"),
		func():
			get_tree().paused = false
			_drafting = false
			complete_level())


func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	return Vector2.ZERO


## One pip per monster, while that stays readable.
##
## Above PIP_MAX the row would be a smear of 8 px dots, so it falls back to the
## number -- with the picture beside it, which the old version did not have
## either. Every level these two templates actually ship with is 8, so the
## fallback is a guard rather than the normal case; it is written down instead
## of pretending the row scales for ever.
const PIP_MAX := 12
const PIP := 30.0

func _build_pips() -> void:
	if _pip_row == null or not is_instance_valid(_pip_row):
		return
	for c in _pip_row.get_children():
		c.queue_free()
	_pips.clear()
	if _targets <= PIP_MAX:
		for i in range(_targets):
			var pip: Control = UiKit.picture("monster", PIP)
			if pip == null:
				continue
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pip_row.add_child(pip)
			_pips.append(pip)
	else:
		var icon: Control = UiKit.picture("monster", PIP)
		if icon != null:
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pip_row.add_child(icon)
		_progress = Label.new()
		_progress.add_theme_font_size_override("font_size", 30)
		_progress.add_theme_color_override("font_color", Palette.ON_COLOR)
		UiKit.on_art(_progress)
		_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pip_row.add_child(_progress)
	_place_pips()
	_update_progress()


## Right-hand corner, on the same top margin as everything else up there.
func _place_pips() -> void:
	if _pip_row == null or not is_instance_valid(_pip_row):
		return
	var wide: float = float(_pips.size()) * PIP + float(maxi(_pips.size() - 1, 0)) * 6.0
	if _pips.is_empty():
		wide = PIP + 6.0 + 70.0
	_pip_row.position = Vector2(_play_area.size.x - 24.0 - wide, 24.0)
	# The instruction's box ends where the pips begin. It used to span
	# 240..1040 whatever stood on the right, and a centred sentence of any
	# length ran under the first monsters.
	if _instruction != null and is_instance_valid(_instruction):
		_instruction.size.x = maxf(_pip_row.position.x - 12.0 - _instruction.position.x, 200.0)


func _update_progress() -> void:
	# Dim, not gone: a monster that has not arrived yet is still a monster he
	# is going to meet, and a row that shortens as he wins reads as losing
	# ground. Opacity only -- never a second colour for the same thing.
	for i in range(_pips.size()):
		var pip: Control = _pips[i]
		if is_instance_valid(pip):
			pip.modulate = Color(1, 1, 1, 1) if i < _defeated \
				else Color(0.62, 0.66, 0.76, 0.45)
	if _progress != null and is_instance_valid(_progress):
		_progress.text = "%d / %d" % [_defeated, _targets]


## The curtain call.
##
## Every other template on the island ends with the hero cheering and confetti
## in the air; this one ended with the last monster walking off and the screen
## cutting to the results card. That silence reads as "the game stopped", not
## as "you won" -- and winning is the entire point of the ninety seconds
## before it. Same shape as the duel's, deliberately: two templates that end
## the same way teach one ending.
func complete_level() -> void:
	if not _finished:
		if is_instance_valid(_hero):
			_hero.celebrate()
		Juice.burst(_play_area, _hero.position + Vector2(0, -150.0), 30)
		AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
		await get_tree().create_timer(1.0).timeout
	await super.complete_level()
