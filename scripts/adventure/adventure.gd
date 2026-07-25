extends LevelManager
## The adventure template: a side-scrolling level made of BEATS.
##
## This is the replacement for twelve separate minigames. A level is one
## long strip of ground plus a list of sections laid along it, and the child
## walks right through them:
##
##   collect     -- gather N energy orbs
##   switch      -- a floor plate that opens a gate
##   crate       -- push a box to reach a shelf
##   rescue      -- free someone; the interact key appears when close
##   chest       -- the reward, and the end of the level
##   (later phases) hazard, enemy, puzzle, boss
##
## The point of the beat list is that a child never does the same thing
## twice in one level. tools_check.py enforces at least three distinct kinds
## per level, so "a whole level of tapping the same thing" cannot ship.
##
## Terrain is generated from the level's seed, so a replay returns to the
## same valley; the sections are placed by `at` (an x hint) and snapped to
## the nearest flat ground, so a designer writes intent rather than pixels.
##
## Three stars, three independent conditions (LevelResult):
##   1  reached the chest        2  found the hidden gem
##   3  took at most one hit
##
## Nothing here can be failed. Running out of hearts returns the hero to the
## last checkpoint with everything already collected still collected.

## How far behind the hero the camera sits. Chosen so the hero stands clear of
## both thumb pads: the left pad ends at screen x=324, the right group begins
## at 948, and 480 puts the hero in the middle of what is left.
const CAMERA_LEAD := 480.0
## Where the hero starts. Far enough into the opening meadow that the camera
## has already scrolled past zero, so the hero is centred from frame one.
const SPAWN_X := 520.0
const SECTION_MIN_GAP := 420.0


## How high a single jump actually gets, in pixels, plus the ledge magnet.
## Every ledge this template generates is placed under this line, because a
## shelf you cannot reach is not a choice -- it is a thing a six-year-old
## throws themselves at twenty times and then stops trusting.
static func reach() -> float:
	return pow(HeroController.JUMP_VELOCITY, 2.0) / (2.0 * HeroController.GRAVITY) \
		+ HeroController.LEDGE_MAGNET

var _length := 2600.0
var _ground_y := 620.0
var _world: Node2D
var _stage: Stage
var _hud: Control
var _bar: SkillBar
var _hero: HeroController

var _platforms: Array = []
var _ropes: Array = []
var _sections: Array = []          # the level's beats, in order
var _orbs: Array = []              # [{node, at, taken}]
var _gems: Array = []
var _gates: Array = []             # [{node, left, right, open, at}]
var _switches: Array = []          # [{node, plate, at, pressed, gate}]
var _springs: Array = []           # [{node, at}]
var _crates: Array = []            # [{node, at, held}]
var _checkpoints: Array = []       # [{node, flag, at, claimed}]
var _chest: Dictionary = {}
var _interactables: Array = []     # [{at, icon, act}] rebuilt as things change

var _orbs_needed := 5
var _orbs_taken := 0
var _gem_found := false
var _hits_taken := 0
var _last_safe := Vector2.ZERO
var _deaths := 0
var _finished_level := false

var _hearts_row: HBoxContainer
var _heart_icons: Array = []
var _task_strip: Control
var _task_tiles: Array = []        # [{tile, count, key, done}]
var _instruction: Label
var _nearest: Dictionary = {}


## Collecting orbs is a beat, not the finish line. The chest ends the level.
func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_length = maxf(float(config.get("length", 2600.0)), 1600.0)
	_sections = (config.get("sections", []) as Array).duplicate(true)

	_stage = build_world(self)
	_ground_y = _stage.ground_y()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_build_terrain(config)
	_build_sections()
	_build_hero()
	_build_hud()
	_refresh_task()


# --- the ground -------------------------------------------------------------

func _build_terrain(config: Dictionary) -> void:
	var rng := Shapes.rng_for(str(level_data.get("id", "adventure")))
	var gap_max: float = clampf(harder(float(config.get("gap_max", 110.0)), 1.16),
		60.0, 210.0)
	var seg_min: float = maxf(harder(float(config.get("seg_min", 300.0)), 0.90), 220.0)

	# The opening meadow is long and always flat. The hero starts in the
	# MIDDLE of it rather than at its left edge, because the camera cannot
	# scroll past zero and a hero standing at screen x=180 stands underneath
	# the left thumb pad -- which is exactly where a child's hand is.
	var x := -520.0
	_add_ground(x, 1420.0, rng)
	x += 1420.0
	var high: float = reach() - 14.0
	while x < _length - 520.0:
		var gap: float = rng.randf_range(70.0, gap_max)
		var width: float = rng.randf_range(seg_min, seg_min + 260.0)
		if gap > 95.0:
			# Every real gap gets a ledge over it, so it is always crossable
			# the easy way as well as the brave way.
			_add_ledge(x + gap * 0.5 - 105.0, _ground_y - rng.randf_range(96.0, high * 0.8),
				210.0, rng)
		_add_pit(x, x + gap)
		x += gap
		_add_ground(x, width, rng)
		if rng.randf() < 0.5:
			_add_ledge(x + width * rng.randf_range(0.15, 0.5),
				_ground_y - rng.randf_range(high * 0.62, high),
				rng.randf_range(160.0, 220.0), rng)
		x += width
	_add_ground(x, 620.0, rng)
	_length = x + 620.0


func _add_ground(x: float, width: float, rng: RandomNumberGenerator) -> void:
	var holder := Node2D.new()
	_world.add_child(holder)
	var body: Color = _stage.style.ground_bottom.darkened(0.22)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, _ground_y),
		Vector2(width, 210.0), 10.0), body, 0.0)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, _ground_y - 4.0),
		Vector2(width, 22.0), 8.0), _stage.style.ground_top, 0.0)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, _ground_y - 4.0),
		Vector2(width, 7.0), 3.0), _stage.style.ground_top.lightened(0.20), 0.0)
	for i in range(int(width / 88.0)):
		var tx: float = x + rng.randf_range(14.0, width - 14.0)
		Shapes.fill(holder, PackedVector2Array([
			Vector2(tx - 7.0, _ground_y - 2.0),
			Vector2(tx + rng.randf_range(-4.0, 4.0), _ground_y - 17.0),
			Vector2(tx + 7.0, _ground_y - 2.0),
		]), _stage.style.ground_top.lightened(0.10), 0.0)
	_platforms.append({"rect": Rect2(x, _ground_y, width, 210.0), "node": null,
		"flat": true})


## A hole has to LOOK like a hole.
##
## Stage paints ground across the full width of the screen below the horizon,
## so a gap in the platform strip still has green underneath it and reads as
## "slightly different grass". A child running right cannot see the difference
## and simply falls. This fills the gap with a dark shaft, lit at the lip and
## black at the bottom, which is the one shape everybody reads as "down".
func _add_pit(left: float, right: float) -> void:
	var holder := Node2D.new()
	holder.z_index = -1                 # under the platforms, over the scenery
	_world.add_child(holder)
	var width: float = right - left
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(left - 6.0, _ground_y - 6.0),
		Vector2(width + 12.0, 260.0), 6.0), Color(0.10, 0.13, 0.20, 0.92), 0.0)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(left - 6.0, _ground_y - 6.0),
		Vector2(width + 12.0, 16.0), 5.0), Color(0.06, 0.08, 0.13, 0.95), 0.0)


func _add_ledge(x: float, y: float, width: float, rng: RandomNumberGenerator) -> void:
	var holder := Node2D.new()
	_world.add_child(holder)
	var body: Color = _stage.style.ground_bottom.darkened(0.22)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, y), Vector2(width, 30.0), 12.0),
		body, 0.9)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, y - 3.0),
		Vector2(width, 15.0), 7.0), _stage.style.ground_top.lightened(0.06), 0.0)
	for k in range(maxi(int(width / 110.0), 1)):
		var vx: float = x + rng.randf_range(18.0, width - 18.0)
		Shapes.fill(holder, Shapes.taper(Vector2(vx, y + 26.0),
			Vector2(vx + rng.randf_range(-5.0, 5.0), y + 26.0 + rng.randf_range(12.0, 26.0)),
			5.0, 1.8), body.lightened(0.08), 0.0)
	_platforms.append({"rect": Rect2(x, y, width, 30.0), "node": null, "flat": false})


## Where a section should actually stand: the flat ground nearest its hint.
## Designers write "around x=1600" and never a pixel.
func _ground_near(x: float) -> float:
	var best := x
	var best_d := INF
	for entry in _platforms:
		if not bool(entry.get("flat", false)):
			continue
		var rect: Rect2 = entry["rect"]
		var centre: float = rect.position.x + rect.size.x * 0.5
		var d: float = absf(centre - x)
		if d < best_d and rect.size.x > 220.0:
			best_d = d
			best = clampf(x, rect.position.x + 90.0,
				rect.position.x + rect.size.x - 90.0)
	return best


# --- the beats ---------------------------------------------------------------

## Where each beat actually stands.
##
## A level author writes the ORDER of the beats and nothing else. The template
## spreads them evenly along however much ground the generator produced, then
## snaps each one to solid footing.
##
## It used to honour a hand-written `at` per section, and that quietly did not
## work: the terrain generator overshoots the configured length to finish its
## last segment, so every hand-picked x drifted, and `_ground_near` then
## clamped several beats into the same platform. Level one came out with its
## checkpoint, its plate and its gate inside one 190 px stretch -- three
## different ideas stacked in a space the camera shows all at once, which for
## a six-year-old is one confusing pile rather than three things that happened.
## Even spacing cannot do that, at any level length, on any seed.
##
## Two escapes from the even spacing, both needed:
##   * `chest` always goes at the end of the world, wherever that turns out
##     to be, because it is the finish line.
##   * a section may carry `"id"`, and a later one `"above": "<id>"` with an
##     `"offset"`, taking the first one's FINAL position. That is how the gem
##     ends up over the spring rather than over where the spring was asked to
##     go.
func _build_sections() -> void:
	var anchors := {}
	var walkers := 0
	for section in _sections:
		if str(section.get("kind", "")) != "chest" and not section.has("above"):
			walkers += 1

	# The walkable beats stop well short of the chest, so the last thing that
	# happens before the reward is a moment of plain walking toward it -- and
	# so a gate never opens straight INTO the chest, which collapses "I solved
	# the door" and "I won" into one unreadable second.
	var first := 980.0
	var last: float = _length - 1150.0
	var step: float = (last - first) / float(maxi(walkers, 1))
	var index := 0
	var previous := -INF

	for section in _sections:
		var kind := str(section.get("kind", ""))
		var at: float
		var anchor := str(section.get("above", ""))
		if anchor != "" and anchors.has(anchor):
			at = float(anchors[anchor]) + float(section.get("offset", 0.0))
		elif kind == "chest":
			# Where the chest goes is set by the CAMERA, not by taste. The
			# camera stops scrolling at (_length - 1280), so whatever stands
			# at (_length - 640) is dead centre of the final screen. At the
			# first try, (_length - 300), the chest sat exactly underneath the
			# jump button -- a thumb hiding the one thing the level walks to.
			at = _length - 640.0
		else:
			at = _ground_near(first + step * (float(index) + 0.5))
			# Snapping can shove two beats together even when the plan spread
			# them; keep the guarantee that they stay apart.
			if at < previous + SECTION_MIN_GAP:
				at = _ground_near(previous + SECTION_MIN_GAP)
			previous = at
			index += 1
		if section.has("id"):
			anchors[str(section["id"])] = at
		match kind:
			"collect":
				_build_collect(section, at)
			"gem":
				_build_gem(at, float(section.get("height", 210.0)))
			"switch":
				_build_switch(section, at)
			"spring":
				_build_spring(at)
			"crate":
				_build_crate(at)
			"checkpoint":
				_build_checkpoint(at)
			"chest":
				_build_chest(at)


func _build_collect(section: Dictionary, at: float) -> void:
	var count: int = maxi(int(section.get("count", 3)), 1)
	# Kept inside this beat's own stretch of ground, so one collect run does
	# not scatter orbs through the middle of the next beat.
	var spread: float = minf(float(section.get("spread", 520.0)), SECTION_MIN_GAP * 0.9)
	for i in range(count):
		var t: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var ox: float = at + lerpf(-spread * 0.5, spread * 0.5, t)
		# Every third orb sits high enough to need a jump, so collecting is
		# never just walking with your finger down. The height comes from what
		# a jump actually clears rather than from a number that looked right:
		# an orb at 196 px was above the arc, and a child who jumps for it and
		# misses every time concludes the game is broken, not the jump.
		var high: bool = i % 3 == 2
		var oy: float = _ground_y - (reach() * 0.66 if high else 86.0)
		var node := AdventureProps.orb(_world)
		node.position = Vector2(ox, oy)
		_orbs.append({"node": node, "at": Vector2(ox, oy), "taken": false})
	_orbs_needed = _orbs.size()


func _build_gem(at: float, height: float) -> void:
	var node := AdventureProps.gem(_world)
	node.position = Vector2(at, _ground_y - height)
	_gems.append({"node": node, "at": node.position, "taken": false})


## Switch and gate, built as one beat because they only mean anything together.
##
## `height` lifts the plate onto its own ledge, and that single number is what
## turns this from scenery into a puzzle. A plate lying in the walkway gets
## stepped on by a child who is simply walking right, the gate is already open
## by the time they see it, and they learn that the machinery does not matter.
## Up on a ledge they meet the shut gate first, look around, and find it.
func _build_switch(section: Dictionary, at: float) -> void:
	var height: float = minf(float(section.get("height", 0.0)), reach() - 20.0)
	var plate_y: float = _ground_y - height
	if height > 0.0:
		_add_ledge(at - 118.0, plate_y, 236.0, Shapes.rng_for("plate%d" % int(at)))
	var parts := AdventureProps.floor_switch(_world)
	(parts["node"] as Node2D).position = Vector2(at, plate_y)

	# The gate hangs off the plate rather than off an absolute x, so the pair
	# stays a pair however the terrain came out. Far enough to be a separate
	# thing, close enough to be on screen together when it opens -- which is
	# the whole lesson: I stood there, and THAT happened.
	var gate_at: float = _ground_near(at + maxf(float(section.get("gate_gap", 250.0)), 150.0))
	gate_at = maxf(gate_at, at + 150.0)
	var gate_parts := AdventureProps.gate(_world)
	(gate_parts["node"] as Node2D).position = Vector2(gate_at, _ground_y)
	var gate := {"node": gate_parts["node"], "left": gate_parts["left"],
		"right": gate_parts["right"], "open": false, "at": gate_at}
	_gates.append(gate)
	_switches.append({"node": parts["node"], "plate": parts["plate"],
		"at": at, "y": plate_y, "pressed": false, "gate": gate})


## A bounce pad is a platform with `spring` set: the hero controller already
## knows what to do with one, so the level only has to draw it and hand the
## rectangle over. The pad sits ON the ground, so a child who simply walks
## right will find it whether or not they understood it was there.
func _build_spring(at: float) -> void:
	var parts := AdventureProps.spring(_world)
	var node: Node2D = parts["node"]
	node.position = Vector2(at, _ground_y)
	_platforms.append({
		"rect": Rect2(at - 58.0, _ground_y - 92.0, 116.0, 24.0),
		"node": null, "flat": false, "spring": true, "cap": parts["cap"],
	})
	_springs.append({"node": node, "at": at})


func _build_crate(at: float) -> void:
	var node := AdventureProps.crate(_world)
	node.position = Vector2(at, _ground_y)
	_crates.append({"node": node, "at": at})


func _build_checkpoint(at: float) -> void:
	var parts := AdventureProps.checkpoint(_world)
	(parts["node"] as Node2D).position = Vector2(at, _ground_y)
	(parts["node"] as Node2D).modulate = Color(0.72, 0.74, 0.80)
	_checkpoints.append({"node": parts["node"], "flag": parts["flag"],
		"at": at, "claimed": false})


func _build_chest(at: float) -> void:
	var parts := AdventureProps.chest(_world)
	(parts["node"] as Node2D).position = Vector2(at, _ground_y)
	Shapes.glow(parts["node"], Vector2(0, -40.0), 150.0, Color(1.0, 0.88, 0.44), 5, 0.22)
	_chest = {"node": parts["node"], "lid": parts["lid"], "at": at, "open": false}


# --- the hero and the hands --------------------------------------------------

func _build_hero() -> void:
	_hero = HeroController.new()
	_world.add_child(_hero)
	_hero.setup(GameData.current_skin(), _ground_y, 168.0)
	_hero.use_terrain(_platforms, _ropes)
	_hero.use_enemies(func(): return [])      # enemies arrive in a later phase
	_hero.place_at(Vector2(SPAWN_X, _ground_y))
	_last_safe = _hero.position
	_hero.hurt_taken.connect(_on_hurt)
	_hero.died.connect(_on_died)
	_hero.landed.connect(func(at: Vector2, hard: bool):
		Juice.dust(_world, at, 5 if hard else 3, 0.8 if hard else 0.6))


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

	# Hearts, top left under the back button.
	_hearts_row = HBoxContainer.new()
	_hearts_row.position = Vector2(30, 118)
	_hearts_row.add_theme_constant_override("separation", 8)
	_hearts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hearts_row)
	for i in range(_hero.max_hearts):
		var heart: Control = UiKit.picture("heart", 42)
		if heart != null:
			_hearts_row.add_child(heart)
			_heart_icons.append(heart)

	_build_task_strip()

	_instruction = Label.new()
	_instruction.text = I18n.t(str(level_data.get("config", {})
		.get("instruction_key", "adventure.instruction")))
	_instruction.add_theme_font_size_override("font_size", 30)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(240, 120)
	_instruction.size = Vector2(800, 46)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_instruction)

	_bar = SkillBar.new()
	_hud.add_child(_bar)
	_bar.move_pressed.connect(func(dir: float, down: bool):
		if dir < 0.0:
			_hero.press_left(down)
		else:
			_hero.press_right(down))
	_bar.jump_pressed.connect(func(): _hero.press_jump())
	_bar.jump_released.connect(func(): _hero.release_jump())
	_bar.attack_pressed.connect(_on_attack)
	_bar.interact_pressed.connect(_on_interact)
	# Two skills from the start, so the layout a child learns on level one is
	# the layout they keep. What they DO grows with the world.
	_bar.add_skill("shield", Color(0.55, 0.85, 1.0), 6.0)
	_bar.add_skill("lightning", Color(1.0, 0.86, 0.40), 4.0)
	_bar.skill_pressed.connect(_on_skill)


# --- the loop ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _finished or _finished_level or _hero == null or not is_instance_valid(_hero):
		return
	_hero.tick(delta)
	# The edges of the world. The right-hand wall sits just past the chest,
	# still inside what the fully-scrolled camera shows -- past THAT is space
	# the child can stand in but never see themselves standing in.
	_hero.position.x = clampf(_hero.position.x, -400.0, _length - 460.0)
	_collect_orbs()
	_collect_gems()
	_press_switches()
	_block_at_gates()
	_claim_checkpoints()
	_check_fall()
	_offer_interaction()
	_scroll_camera()


## Where the hero's chest is IN THE WORLD'S COORDINATES.
##
## `HeroController.chest()` answers in global pixels, because that is what a
## beam muzzle needs. Everything a level places -- orbs, gems, gates -- is
## positioned inside `_world`, which slides left as the camera scrolls. Compare
## the two directly and the pickup radius drifts by exactly the scroll
## distance: fine on the first screen, hundreds of pixels wrong by the third.
## That is the bug that made a walk-right level collect nothing.
func _hero_core() -> Vector2:
	return _world.to_local(_hero.chest())


func _collect_orbs() -> void:
	var core := _hero_core()
	for orb in _orbs:
		if bool(orb["taken"]):
			continue
		# Generous on purpose. A pickup radius tuned to look right on paper is
		# a pickup radius a six-year-old sails past at the top of a jump.
		if core.distance_to(orb["at"]) > 116.0:
			continue
		orb["taken"] = true
		_orbs_taken += 1
		var node: Node2D = orb["node"]
		if is_instance_valid(node):
			Juice.burst(_world, node.position, 14)
			node.queue_free()
		AudioManager.play_sfx("res://assets/audio/orb_collect.ogg")
		score_correct()
		_refresh_task()


func _collect_gems() -> void:
	var core := _hero_core()
	for gem in _gems:
		if bool(gem["taken"]):
			continue
		if core.distance_to(gem["at"]) > 110.0:
			continue
		gem["taken"] = true
		_gem_found = true
		var node: Node2D = gem["node"]
		if is_instance_valid(node):
			Juice.burst(_world, node.position, 26)
			node.queue_free()
		Juice.shockwave(_world, _hero.position, 150.0, Color(0.98, 0.52, 0.86))
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		_say(I18n.t("adventure.gem"))
		_refresh_task()


## Standing on a plate presses it, and the gate it belongs to slides open.
## No button: a switch you step on is a switch a child understands before
## anybody explains it.
func _press_switches() -> void:
	for sw in _switches:
		if bool(sw["pressed"]):
			continue
		if absf(_hero.position.x - float(sw["at"])) > 74.0:
			continue
		# Standing ON it, not flying past it. A loose window here is worse than
		# no puzzle at all: the apex of an ordinary jump passes right through
		# the height of a shelf-mounted plate, so the gate opened itself while
		# the child was jumping at something else entirely.
		if not _hero.grounded or absf(_hero.position.y - float(sw["y"])) > 14.0:
			continue
		sw["pressed"] = true
		var plate: Node2D = sw["plate"]
		if is_instance_valid(plate) and Juice.motion_enabled():
			var t := plate.create_tween()
			t.tween_property(plate, "position:y", -8.0, 0.16)
			t.tween_property(plate, "modulate", Color(0.55, 1.0, 0.70), 0.2)
		AudioManager.play_sfx("res://assets/audio/power_up.ogg")
		_open_gate(sw["gate"])


func _open_gate(gate: Dictionary) -> void:
	if bool(gate["open"]):
		return
	gate["open"] = true
	var left: Node2D = gate["left"]
	var right: Node2D = gate["right"]
	Juice.burst(_world, Vector2(float(gate["at"]), _ground_y - 110.0), 20)
	if Juice.motion_enabled():
		for pair in [[left, -120.0], [right, 120.0]]:
			var node: Node2D = pair[0]
			if not is_instance_valid(node):
				continue
			var t := node.create_tween()
			t.tween_property(node, "position:x", float(pair[1]), 0.6)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if is_instance_valid(left):
			left.position.x = -120.0
		if is_instance_valid(right):
			right.position.x = 120.0
	_say(I18n.t("adventure.gate_open"))


## A shut gate is a wall. Without this the child can walk straight past it to
## the chest and the switch behind them was decoration -- which is worse than
## having no puzzle, because it teaches that the puzzles do not matter.
##
## Implemented as a soft stop rather than a bounce: the hero simply cannot get
## further right, keeps walking on the spot, and the gate wobbles to say why.
## Nothing hurts, nothing throws them backwards.
func _block_at_gates() -> void:
	for gate in _gates:
		if bool(gate["open"]):
			continue
		var wall: float = float(gate["at"]) - 58.0
		if _hero.position.x <= wall:
			continue
		_hero.position.x = wall
		_hero.velocity.x = 0.0
		var node: Node2D = gate["node"]
		if is_instance_valid(node) and not bool(gate.get("nudging", false)):
			gate["nudging"] = true
			Juice.nudge(node)
			_say(I18n.t("adventure.gate_shut"))
			get_tree().create_timer(1.6).timeout.connect(func(): gate["nudging"] = false)
		# Pushing at a shut door for two seconds is a child who has not found
		# the plate. Point at it. The house rule is that the game shows you
		# rather than telling you, and never makes you feel slow for asking.
		gate["pressing"] = float(gate.get("pressing", 0.0)) + get_physics_process_delta_time()
		if float(gate["pressing"]) > 2.0 and not bool(gate.get("pointed", false)):
			gate["pointed"] = true
			_point_at_plate(gate)


func _point_at_plate(gate: Dictionary) -> void:
	for sw in _switches:
		if sw["gate"] != gate or bool(sw["pressed"]):
			continue
		var hand := AdventureProps.hint_hand(_world)
		hand.position = Vector2(float(sw["at"]), float(sw["y"]) - 34.0)
		var plate: Node2D = sw["plate"]
		if is_instance_valid(plate):
			Juice.pop(plate, 0.34)
		get_tree().create_timer(4.5).timeout.connect(func():
			if is_instance_valid(hand):
				hand.queue_free())
		return


func _claim_checkpoints() -> void:
	for point in _checkpoints:
		if bool(point["claimed"]):
			continue
		if absf(_hero.position.x - float(point["at"])) > 70.0:
			continue
		point["claimed"] = true
		_last_safe = Vector2(float(point["at"]), _ground_y)
		var node: Node2D = point["node"]
		if is_instance_valid(node):
			node.modulate = Color(1, 1, 1)
			Juice.pop(node, 0.3)
		Juice.burst(_world, Vector2(float(point["at"]), _ground_y - 120.0), 16)
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		_say(I18n.t("adventure.checkpoint"))


## Falling costs nothing but a moment: back to the last flag with everything
## already collected still collected.
func _check_fall() -> void:
	if _hero.position.y < _ground_y + 300.0:
		return
	_hero.place_at(_last_safe)
	Juice.dust(_world, _last_safe, 6)
	_say(I18n.t("adventure.oops"))


# --- interaction -------------------------------------------------------------

## Rebuild the "what is near me" answer every frame and let the bar show it.
## The key exists only while something is in reach, so the child never has a
## button that does nothing.
func _offer_interaction() -> void:
	_nearest = {}
	var best := 150.0
	if not _chest.is_empty() and not bool(_chest["open"]):
		var d: float = absf(_hero.position.x - float(_chest["at"]))
		# A chest is a big thing and it is the goal: reachable from further
		# away than a crate, and from the wall at the end of the world.
		best = maxf(best, 190.0)
		if d < best:
			best = d
			_nearest = {"kind": "chest", "at": Vector2(float(_chest["at"]),
				_ground_y - 130.0), "icon": "chest"}
			if not bool(_chest.get("told", false)):
				_chest["told"] = true
				_say(I18n.t("adventure.chest"))
	for crate in _crates:
		var d2: float = absf(_hero.position.x - float(crate["at"]))
		if d2 < best:
			best = d2
			_nearest = {"kind": "crate", "at": Vector2(float(crate["at"]),
				_ground_y - 150.0), "icon": "tap", "crate": crate}
	if _bar == null or not is_instance_valid(_bar):
		return
	if _nearest.is_empty():
		_bar.show_interact(Vector2.ZERO, "")
		return
	var screen: Vector2 = (_nearest["at"] as Vector2) + _world.position
	_bar.show_interact(screen, str(_nearest["icon"]))


func _on_interact() -> void:
	if _nearest.is_empty():
		return
	match str(_nearest["kind"]):
		"chest":
			_open_chest()
		"crate":
			_push_crate(_nearest["crate"])


func _push_crate(crate: Dictionary) -> void:
	var node: Node2D = crate["node"]
	if not is_instance_valid(node):
		return
	var dir: float = signf(_hero.position.x - float(crate["at"])) * -1.0
	if dir == 0.0:
		dir = 1.0
	crate["at"] = float(crate["at"]) + dir * 120.0
	if Juice.motion_enabled():
		var t := node.create_tween()
		t.tween_property(node, "position:x", float(crate["at"]), 0.32)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		node.position.x = float(crate["at"])
	Juice.dust(_world, node.position, 4, 0.7)
	AudioManager.play_sfx("res://assets/audio/coin.ogg")


func _open_chest() -> void:
	if _chest.is_empty() or bool(_chest["open"]):
		return
	_chest["open"] = true
	var lid: Node2D = _chest["lid"]
	if is_instance_valid(lid) and Juice.motion_enabled():
		var t := lid.create_tween()
		t.tween_property(lid, "rotation_degrees", -104.0, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.burst(_world, Vector2(float(_chest["at"]), _ground_y - 120.0), 34)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	_hero.freeze(true)
	_hero.figure().victory()
	_refresh_task()
	_finish()


func _on_attack() -> void:
	if _hero.attack():
		var area: Dictionary = _hero.attack_area()
		# The swing, drawn: an arc of light where the reach actually is.
		var arc := Node2D.new()
		arc.position = area["at"]
		_world.add_child(arc)
		Shapes.glow(arc, Vector2.ZERO, float(area["radius"]) * 0.8,
			Color(1.0, 0.86, 0.40), 4, 0.5)
		if Juice.motion_enabled():
			var t := arc.create_tween().set_parallel(true)
			t.tween_property(arc, "scale", Vector2(1.35, 1.35), 0.2)
			t.tween_property(arc, "modulate:a", 0.0, 0.2)
			t.chain().tween_callback(arc.queue_free)
		else:
			get_tree().create_timer(0.25).timeout.connect(func():
				if is_instance_valid(arc):
					arc.queue_free())
		AudioManager.play_sfx("res://assets/audio/beam.ogg")


func _on_skill(slot: int) -> void:
	if not _bar.use_skill(slot):
		return
	match slot:
		0:
			# Shield: a bubble that blocks the next hit. Nothing to block yet
			# on level one, so it is a light show and a rehearsal.
			var ring := Node2D.new()
			ring.position = _hero.position
			_world.add_child(ring)
			Shapes.glow(ring, Vector2(0, -100.0), 170.0, Color(0.55, 0.85, 1.0), 4, 0.3)
			if Juice.motion_enabled():
				var t := ring.create_tween().set_parallel(true)
				t.tween_property(ring, "scale", Vector2(1.2, 1.2), 1.4)
				t.tween_property(ring, "modulate:a", 0.0, 1.4)
				t.chain().tween_callback(ring.queue_free)
			else:
				get_tree().create_timer(1.4).timeout.connect(func():
					if is_instance_valid(ring):
						ring.queue_free())
		1:
			_hero.figure().power_up()
			Juice.shockwave(_world, _hero.position, 190.0, Color(1.0, 0.86, 0.40))
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")


# --- being hurt, and the end -------------------------------------------------

func _on_hurt(remaining: int) -> void:
	_hits_taken += 1
	score_mistake()
	_refresh_hearts(remaining)


func _on_died() -> void:
	_deaths += 1
	_hero.heal_full()
	_refresh_hearts(_hero.hearts)
	_hero.place_at(_last_safe)
	Juice.dust(_world, _last_safe, 8)
	_say(I18n.t("adventure.again"))


func _refresh_hearts(remaining: int) -> void:
	for i in range(_heart_icons.size()):
		var heart: Control = _heart_icons[i]
		if is_instance_valid(heart):
			heart.modulate = Color(1, 1, 1) if i < remaining \
				else Color(0.35, 0.38, 0.48, 0.7)


## The three things this level wants, in pictures, top centre, always on
## screen: the orbs (with a count, the one number a six-year-old reads fine),
## the hidden gem, the chest.
##
## Undone tiles are DIM, not crossed out. A red ring means "you got that
## wrong"; a dim tile means "that one is still out there". At six the
## difference between those two messages is the difference between going
## looking and giving up.
func _build_task_strip() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.position = Vector2(478, 16)
	row.size = Vector2(324, 92)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(row)
	_task_strip = row

	for spec in [{"key": "orb", "icon": "orb"}, {"key": "gem", "icon": "gem"},
			{"key": "chest", "icon": "chest"}]:
		var tile := Control.new()
		tile.custom_minimum_size = Vector2(92, 92)
		tile.size = Vector2(92, 92)
		tile.pivot_offset = Vector2(46, 46)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := Node2D.new()
		tile.add_child(pad)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2), Vector2(88, 88), 22.0),
			Color(0.05, 0.09, 0.20, 0.55), 0.0)
		var art: Control = UiKit.picture(str(spec["icon"]), 48)
		if art != null:
			art.position = Vector2(22, 6)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(art)
		var count := Label.new()
		count.add_theme_font_size_override("font_size", 26)
		count.add_theme_color_override("font_color", Palette.ON_COLOR)
		UiKit.on_art(count)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.position = Vector2(0, 58)
		count.size = Vector2(92, 30)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(count)
		tile.modulate = Color(1, 1, 1, 0.45)
		row.add_child(tile)
		_task_tiles.append({"tile": tile, "count": count, "key": str(spec["key"]),
			"done": false})


func _refresh_task() -> void:
	for entry in _task_tiles:
		var tile: Control = entry["tile"]
		if not is_instance_valid(tile):
			continue
		var done := false
		match str(entry["key"]):
			"orb":
				done = _orbs_taken >= maxi(_orbs_needed, 1)
				(entry["count"] as Label).text = "%d/%d" % [_orbs_taken,
					maxi(_orbs_needed, 1)]
			"gem":
				done = _gem_found
			"chest":
				done = not _chest.is_empty() and bool(_chest["open"])
		if done == bool(entry["done"]):
			continue
		entry["done"] = done
		tile.modulate = Color(1, 1, 1, 1.0 if done else 0.45)
		if done:
			tile.add_child(UiKit.rule_ring(true, 92.0))
			Juice.pop(tile, 0.28)


func _say(text: String) -> void:
	if _instruction == null or not is_instance_valid(_instruction):
		return
	_instruction.text = text
	var timer := get_tree().create_timer(2.6)
	timer.timeout.connect(func():
		if is_instance_valid(_instruction) and not _finished:
			_instruction.text = I18n.t(str(level_data.get("config", {})
				.get("instruction_key", "adventure.instruction")))
	)


## Three stars, three independent questions -- so a child who finished but
## missed the gem can go back for exactly that one thing.
func _finish() -> void:
	if _finished_level:
		return
	_finished_level = true
	result.reached_goal = true
	result.found_hidden = _gem_found
	result.clean_run = _hits_taken <= 1
	await get_tree().create_timer(1.4).timeout
	complete_level()


func _scroll_camera() -> void:
	var scroll: float = clampf(_hero.position.x - CAMERA_LEAD, 0.0, _length - 1280.0)
	_world.position.x = -scroll
	if _stage != null and is_instance_valid(_stage):
		_stage.parallax(scroll)
