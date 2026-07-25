extends LevelManager
## The adventure template: a side-scrolling level made of BEATS.
##
## This is the replacement for twelve separate minigames. A level is one
## long strip of ground plus a list of sections laid along it, and the child
## walks right through them:
##
##   collect     -- gather N energy orbs
##   switch      -- a floor plate that opens a gate
##   spring      -- a bounce pad up to the high places
##   gem         -- the one hidden treasure (star two)
##   crate_shelf -- push a solid box to reach a too-high shelf
##   rocks/fire  -- hazards that ALWAYS warn before they hurt
##   seq_plates  -- step the dot-plates in order; wrong = relight, never lose
##   puzzle      -- a picture-question card, asked without leaving the level
##   checkpoint / chest
##   (later phases) enemy, rescue, boss
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
# --- the adventure's own classes, by PATH rather than by name --------------
#
# These five are `class_name` scripts, and referring to them by that name is
# the obvious thing to do. It is also a trap this project has now fallen into
# twice. Godot keeps global class names in `.godot/global_script_class_cache.
# cfg`, which is only rebuilt when the EDITOR rescans -- so a new class_name is
# invisible to any run that has not had the editor opened since. The whole of
# `adventure.gd` then fails to PARSE, every level in the game errors the moment
# it is picked, and the cause is a cache file nobody thinks to look at.
#
# `preload` resolves by file path at compile time and never consults that
# cache. The class_name declarations stay where they are, because the editor
# likes them; nothing in the shipping game relies on them any more.
const HeroCtl := preload("res://scripts/adventure/hero_controller.gd")
const Pad := preload("res://scripts/ui/skill_bar.gd")
const Props := preload("res://scripts/adventure/props.gd")
const Foes := preload("res://scripts/adventure/enemies.gd")
const Card := preload("res://scripts/adventure/puzzle_card.gd")

const CAMERA_LEAD := 480.0
## Where the hero starts. Far enough into the opening meadow that the camera
## has already scrolled past zero, so the hero is centred from frame one.
const SPAWN_X := 520.0
const SECTION_MIN_GAP := 420.0
## Plain running between one beat and the next: room for a pit, a ledge, and
## a couple of seconds of nothing being asked of you. Without it every beat
## butts against the next and the level reads as a corridor of chores.
const BEAT_BREATHER := 300.0


## How high a single jump actually gets, in pixels, plus the ledge magnet.
## Every ledge this template generates is placed under this line, because a
## shelf you cannot reach is not a choice -- it is a thing a six-year-old
## throws themselves at twenty times and then stops trusting.
static func reach() -> float:
	return pow(HeroCtl.JUMP_VELOCITY, 2.0) / (2.0 * HeroCtl.GRAVITY) \
		+ HeroCtl.LEDGE_MAGNET

var _length := 2600.0
var _ground_y := 620.0
var _world: Node2D
var _stage: Stage
var _hud: Control
var _bar: Pad
var _hero: HeroCtl

var _platforms: Array = []
var _ropes: Array = []
var _sections: Array = []          # the level's beats, in order
var _orbs: Array = []              # [{node, at, taken}]
var _gems: Array = []
var _gates: Array = []             # [{node, left, right, open, at}]
var _switches: Array = []          # [{node, plate, at, pressed, gate}]
var _springs: Array = []           # [{node, at}]
var _crates: Array = []            # [{node, at, platform}]
var _checkpoints: Array = []       # [{node, flag, at, claimed}]
var _chest: Dictionary = {}
var _interactables: Array = []     # [{at, icon, act}] rebuilt as things change

# --- Phase B: things that warn, things that think --------------------------
var _rocks: Array = []             # [{x, state, t, warn, cool, shadow, node, rng, left, right}]
var _vents: Array = []             # [{node, glow, flame, at, t, warn, blaze, idle}]
var _seq_groups: Array = []        # [{plates: [...], next, gate, done}]
var _puzzles: Array = []           # [{node, at, kind, gate, solved}]
var _card: Card = null
var _warned := {}                  # one first-time callout per hazard family

# --- Phase C: things that fight back ----------------------------------------
var _foes: Array = []              # [{node, body, kind, at, hearts, state, t, ...}]
var _goo: Array = []               # [{node, at, vel}]
var _cages: Array = []             # [{node, bars, pet, at, freed}]
var _pets: Array = []              # rescued friends, following along
var _boss: Dictionary = {}
var _boss_bar: Control
var _boss_fill: Node2D
var _shield_until := 0.0
var _clock := 0.0
var _tries := 0                    # deaths this run; two means the game helps

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

	# Beats are planned BEFORE the ground exists, and the ground is then grown
	# to fit them. The other way round -- generate terrain, then hunt for a
	# segment wide enough -- looks reasonable and quietly ruins the level: the
	# only stretch long enough for a three-plate puzzle is the opening meadow,
	# so the puzzle, the crate and their gates all slid back to the start and
	# the last two thirds of the level were an empty walk.
	var plan := _plan_beats()
	_build_terrain(config, plan)
	_build_sections(plan)
	_build_hero()
	_build_hud()
	_refresh_task()


# --- planning ----------------------------------------------------------------

## How much unbroken flat ground a beat needs to work. Point beats want a
## little; a three-plate sequence wants a lot. Ground is generated to these
## numbers, so a beat is never squeezed and never relocated.
func _zone_width(section: Dictionary) -> float:
	match str(section.get("kind", "")):
		"seq_plates":
			return PLATE_SPACING * float(clampi(int(section.get("count", 3)), 2, 4)) + 200.0
		"crate_shelf":
			return 700.0
		"rocks":
			return 620.0
		"fire":
			return 200.0 * float(clampi(int(section.get("count", 3)), 1, 4)) + 120.0
		"collect":
			return 420.0
		"foes":
			return 300.0 * float(clampi(int(section.get("count", 2)), 1, 4)) + 160.0
		"boss":
			# A boss arena: room to back off, room to run under a swing, and
			# no pit anywhere in it. A fight fought on the lip of a hole is a
			# fight lost to the hole.
			return 1100.0
		_:
			return 260.0


## The beats, in order, spread evenly along the walkable middle of the level.
##
## A level author writes the ORDER and nothing else. Hand-written x positions
## were tried first and quietly did not work: the terrain generator overshoots
## its configured length to finish a segment, so every hand-picked number
## drifted, and several beats ended up inside one 190 px stretch.
func _plan_beats() -> Array:
	var plan: Array = []
	var cursor := 980.0
	for section in _sections:
		var kind := str(section.get("kind", ""))
		if kind == "chest" or section.has("above"):
			plan.append({"section": section, "x": 0.0, "want": 0.0, "placed": false})
			continue
		var want: float = _zone_width(section)
		var x: float = cursor + want * 0.5
		plan.append({"section": section, "x": x, "want": want, "placed": true})
		# Each beat gets the room it needs and then a breather -- somewhere
		# for a pit, a ledge, a few seconds of just running. Spacing beats
		# evenly instead made their zones overlap, which merged the whole
		# level into one flat slab with no gaps and no rhythm at all.
		cursor = x + want * 0.5 + BEAT_BREATHER
	# The level is exactly as long as its beats need, never shorter. Squeezing
	# eight beats into a length written for four is how a three-plate puzzle
	# came out with two plates.
	_length = maxf(_length, cursor + 1150.0)
	return plan


# --- the ground -------------------------------------------------------------

func _build_terrain(config: Dictionary, plan: Array = []) -> void:
	var rng := Shapes.rng_for(str(level_data.get("id", "adventure")))
	var gap_max: float = clampf(harder(float(config.get("gap_max", 110.0)), 1.16),
		60.0, 210.0)
	var seg_min: float = maxf(harder(float(config.get("seg_min", 300.0)), 0.90), 220.0)

	# The opening meadow is long and always flat. The hero starts in the
	# MIDDLE of it rather than at its left edge, because the camera cannot
	# scroll past zero and a hero standing at screen x=180 stands underneath
	# the left thumb pad -- which is exactly where a child's hand is.
	# The stretches that must stay whole, because a beat is going to live
	# there. Gaps are not cut inside them and segments are grown to cover
	# them, so a rockfall is never dodged into a pit and a plate row is never
	# split across one.
	var zones: Array = []
	for entry in plan:
		if not bool(entry.get("placed", false)):
			continue
		var want: float = float(entry["want"]) + 150.0
		zones.append({"left": float(entry["x"]) - want * 0.5,
			"right": float(entry["x"]) + want * 0.5})

	var x := -520.0
	_add_ground(x, 1420.0, rng)
	x += 1420.0
	var high: float = reach() - 14.0
	while x < _length - 520.0:
		var gap: float = rng.randf_range(70.0, gap_max)
		var width: float = rng.randf_range(seg_min, seg_min + 260.0)
		var blocked: Dictionary = _zone_covering(zones, x, x + gap)
		if blocked.is_empty():
			if gap > 95.0:
				# Every real gap gets a ledge over it, so it is always
				# crossable the easy way as well as the brave way.
				_add_ledge(x + gap * 0.5 - 105.0,
					_ground_y - rng.randf_range(96.0, high * 0.8), 210.0, rng)
			_add_pit(x, x + gap)
			x += gap
		# Grow this segment until it clears EVERY zone it lands in. Growing to
		# clear only the first one found leaves the later beats sitting on
		# whatever narrow scrap the generator happened to produce.
		var edge: float = x + width
		var guard := 0
		var changed := true
		while changed and guard < 12:
			changed = false
			guard += 1
			for zone in zones:
				if edge > float(zone["left"]) and x < float(zone["right"]) \
						and float(zone["right"]) + 90.0 > edge:
					edge = float(zone["right"]) + 90.0
					changed = true
		width = edge - x
		_add_ground(x, width, rng)
		# A ledge only if it does not hang over a beat: a shelf above a plate
		# row is somewhere to stand that skips the puzzle.
		if rng.randf() < 0.5:
			var ledge_x: float = x + width * rng.randf_range(0.15, 0.5)
			var ledge_w: float = rng.randf_range(160.0, 220.0)
			if _zone_covering(zones, ledge_x, ledge_x + ledge_w).is_empty():
				_add_ledge(ledge_x, _ground_y - rng.randf_range(high * 0.62, high),
					ledge_w, rng)
		x += width
	_add_ground(x, 620.0, rng)
	_length = x + 620.0


## The first protected zone that overlaps [left, right], if any.
func _zone_covering(zones: Array, left: float, right: float) -> Dictionary:
	for zone in zones:
		if right > float(zone["left"]) and left < float(zone["right"]):
			return zone
	return {}


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


## The stretch of unbroken flat ground nearest a hint -- for beats that are a
## ZONE rather than a point: a rockfall, a row of vents, a row of plates.
## Handing back one segment guarantees the zone contains no pit, so a child
## dodging a rock is never dodging into a hole. Hazards may be scary; the
## ground under a hazard is always honest.
func _flat_zone_near(x: float, want: float) -> Dictionary:
	# Plain nearest-segment, because `_build_terrain` has already grown the
	# ground around this exact spot. An earlier version preferred whichever
	# segment could FIT the zone, which sounds safer and was much worse: the
	# opening meadow was the only stretch long enough, so every zone beat in
	# the level slid back to the first screen.
	var best: Rect2
	var best_d := INF
	for entry in _platforms:
		if not bool(entry.get("flat", false)):
			continue
		var rect: Rect2 = entry["rect"]
		if rect.size.x < 260.0:
			continue
		var d: float = absf(rect.position.x + rect.size.x * 0.5 - x)
		if d < best_d:
			best_d = d
			best = rect
	if best_d == INF:
		return {"left": x - want * 0.5, "right": x + want * 0.5}
	var width: float = minf(want, best.size.x - 120.0)
	var left: float = clampf(x - width * 0.5, best.position.x + 60.0,
		maxf(best.position.x + best.size.x - 60.0 - width, best.position.x + 60.0))
	return {"left": left, "right": left + width}


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
func _build_sections(plan: Array) -> void:
	var anchors := {}
	for entry in plan:
		var section: Dictionary = entry["section"]
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
			# The ground was grown around this exact spot, so the snap has
			# almost nothing left to do -- it only nudges off a segment lip.
			at = _ground_near(float(entry["x"]))
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
			"crate_shelf":
				_build_crate_shelf(section, at)
			"rocks":
				_build_rocks(section, at)
			"fire":
				_build_fire(section, at)
			"seq_plates":
				_build_seq_plates(section, at)
			"puzzle":
				_build_puzzle(section, at)
			"foes":
				_build_foes(section, at)
			"rescue":
				_build_rescue(at)
			"boss":
				_build_boss(section, at)
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
		var node := Props.orb(_world)
		node.position = Vector2(ox, oy)
		_orbs.append({"node": node, "at": Vector2(ox, oy), "taken": false})
	_orbs_needed = _orbs.size()


func _build_gem(at: float, height: float) -> void:
	var node := Props.gem(_world)
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
	var parts := Props.floor_switch(_world)
	(parts["node"] as Node2D).position = Vector2(at, plate_y)

	# The gate hangs off the plate rather than off an absolute x, so the pair
	# stays a pair however the terrain came out. Far enough to be a separate
	# thing, close enough to be on screen together when it opens -- which is
	# the whole lesson: I stood there, and THAT happened.
	var gate_at: float = _ground_near(at + maxf(float(section.get("gate_gap", 250.0)), 150.0))
	gate_at = maxf(gate_at, at + 150.0)
	var gate_parts := Props.gate(_world)
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
	var parts := Props.spring(_world)
	var node: Node2D = parts["node"]
	node.position = Vector2(at, _ground_y)
	_platforms.append({
		"rect": Rect2(at - 58.0, _ground_y - 92.0, 116.0, 24.0),
		"node": null, "flat": false, "spring": true, "cap": parts["cap"],
	})
	_springs.append({"node": node, "at": at})


## A crate with a REASON: a shelf too high for any jump, treasure on the
## shelf, and a box that can be walked to the foot of it. The child invents
## the rest, which is the entire pleasure of a pushable box.
func _build_crate_shelf(section: Dictionary, at: float) -> void:
	var zone := _flat_zone_near(at, 700.0)
	var left: float = float(zone["left"])
	var right: float = float(zone["right"])
	# The shelf sits one jump ABOVE the crate's roof and out of reach from
	# the floor: that gap is the puzzle, and both halves of it are arithmetic
	# rather than taste, so it cannot drift as the hero's jump is retuned.
	var crate_top := 92.0
	var shelf_h: float = crate_top + reach() - 40.0
	var shelf_w := 240.0
	var shelf_x: float = right - shelf_w
	_add_ledge(shelf_x, _ground_y - shelf_h, shelf_w, Shapes.rng_for("shelf%d" % int(at)))
	var gem := Props.gem(_world)
	# Low over the shelf: standing on the shelf is the achievement, not a
	# second precision jump on top of it.
	gem.position = Vector2(shelf_x + shelf_w * 0.5, _ground_y - shelf_h - 60.0)
	_gems.append({"node": gem, "at": gem.position, "taken": false})
	# The crate starts at the far LEFT of the zone and is pushed right, so
	# the child walks into it the way they are already walking.
	_build_crate(left + 90.0, left + 40.0, shelf_x - 30.0)


## The crate is SOLID: pushed by walking into it, ridden by jumping on it.
## No interact key -- a box you push with a button is furniture, a box you
## push with your body is a toy.
func _build_crate(at: float, bound_left: float = -INF, bound_right: float = INF) -> void:
	var node := Props.crate(_world)
	node.position = Vector2(at, _ground_y)
	var platform := {"rect": Rect2(-46.0, -92.0, 92.0, 92.0), "node": node,
		"base_y": -92.0, "flat": false}
	_platforms.append(platform)
	_crates.append({"node": node, "left": bound_left, "right": bound_right})


## Falling rocks over one honest stretch of ground. Each rock loops:
## rest -> a shadow grows on the ground for the whole warning -> the boulder
## drops exactly onto its shadow -> dust -> rest. The shadow IS the warning
## and its size IS the countdown; there is nothing to read and nothing that
## arrives unannounced.
func _build_rocks(section: Dictionary, at: float) -> void:
	var zone := _flat_zone_near(at, 620.0)
	var count: int = clampi(harder_i(int(section.get("count", 3)), 1), 1, 5)
	var rng := Shapes.rng_for("%s-rocks" % str(level_data.get("id", "")))
	for i in range(count):
		var shadow := Props.rock_shadow(_world)
		shadow.visible = false
		_rocks.append({
			"left": float(zone["left"]), "right": float(zone["right"]),
			"state": "rest",
			# Staggered starts, so the zone breathes instead of volleying.
			"t": 1.2 + float(i) * 1.1,
			"warn": harder(1.05, 0.80),      # GENTLE 1.3s, NORMAL 1.05, BRAVE 0.85
			"cool": harder(2.6, 0.85),
			"x": at, "shadow": shadow, "node": null, "rng": rng,
		})


## Fire vents in a row, blowing in order like a song: ground blushes red,
## THEN the flame. The rhythm is the puzzle; running the row is the answer.
func _build_fire(section: Dictionary, at: float) -> void:
	var count: int = clampi(int(section.get("count", 3)), 1, 4)
	var zone := _flat_zone_near(at, 200.0 * float(count))
	var warn: float = harder(1.05, 0.82)
	var blaze := 0.9
	var idle: float = harder(1.7, 0.80)
	var cycle: float = warn + blaze + idle
	for i in range(count):
		var parts := Props.fire_vent(_world)
		var vent_x: float = lerpf(float(zone["left"]) + 80.0, float(zone["right"]) - 80.0,
			0.5 if count == 1 else float(i) / float(count - 1))
		(parts["node"] as Node2D).position = Vector2(vent_x, _ground_y)
		_vents.append({"node": parts["node"], "glow": parts["glow"],
			"flame": parts["flame"], "at": vent_x,
			"t": cycle - float(i) * (cycle / float(count)),   # in order, left first
			"warn": warn, "blaze": blaze, "idle": idle})


## Three plates wearing one, two, three dots. Step them in dot order and the
## gate opens; step wrong and they all just light up again -- a shrug, not a
## slap. The plates sit in a row, so hopping OVER the ones not yet due is the
## actual game.
## The plates must stand further apart than the hero is wide, or standing on
## one stands on its neighbours too and the "sequence" solves itself in a
## single step. 200 px is comfortably more than the 52 px step radius on
## either side, and leaves room to hop a plate that is not yet due -- which
## is the actual skill the puzzle asks for.
const PLATE_SPACING := 200.0


func _build_seq_plates(section: Dictionary, at: float) -> void:
	var count: int = clampi(int(section.get("count", 3)), 2, 4)
	var zone := _flat_zone_near(at, PLATE_SPACING * float(count))
	# However wide the ground actually turned out, honour the spacing and
	# drop a plate instead: two plates a child can tell apart beat four in a
	# heap. A puzzle that shrinks is fine; one that overlaps is broken.
	var span: float = float(zone["right"]) - float(zone["left"]) - 140.0
	count = clampi(int(span / PLATE_SPACING) + 1, 2, count)
	var rng := Shapes.rng_for("%s-seq" % str(level_data.get("id", "")))
	var dot_order: Array = []
	for i in range(count):
		dot_order.append(i + 1)
	for i in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap = dot_order[i]
		dot_order[i] = dot_order[j]
		dot_order[j] = swap

	# Centred on the zone at the fixed spacing, rather than stretched to fill
	# it: the gap between plates is a rule, not a leftover.
	var row: float = PLATE_SPACING * float(count - 1)
	var start: float = (float(zone["left"]) + float(zone["right"]) - row) * 0.5
	var plates: Array = []
	for i in range(count):
		var px: float = start + PLATE_SPACING * float(i)
		var parts := Props.seq_plate(_world, int(dot_order[i]))
		(parts["node"] as Node2D).position = Vector2(px, _ground_y)
		plates.append({"node": parts["node"], "lamp": parts["lamp"],
			"at": px, "dots": int(dot_order[i]), "lit": false, "on": false})

	var last_plate: float = start + row
	var gate_at: float = _ground_near(last_plate
		+ maxf(float(section.get("gate_gap", 240.0)), 150.0))
	gate_at = maxf(gate_at, last_plate + 150.0)
	var gate_parts := Props.gate(_world)
	(gate_parts["node"] as Node2D).position = Vector2(gate_at, _ground_y)
	var gate := {"node": gate_parts["node"], "left": gate_parts["left"],
		"right": gate_parts["right"], "open": false, "at": gate_at}
	_gates.append(gate)
	_seq_groups.append({"plates": plates, "next": 1, "gate": gate, "done": false})


## A question post and the gate it unlocks. Walking up shows the interact
## key; pressing it asks one picture-question right there in the level.
func _build_puzzle(section: Dictionary, at: float) -> void:
	var node := Props.puzzle_sign(_world)
	node.position = Vector2(at, _ground_y)
	var gate_at: float = _ground_near(at + maxf(float(section.get("gate_gap", 240.0)), 150.0))
	gate_at = maxf(gate_at, at + 150.0)
	var gate_parts := Props.gate(_world)
	(gate_parts["node"] as Node2D).position = Vector2(gate_at, _ground_y)
	var gate := {"node": gate_parts["node"], "left": gate_parts["left"],
		"right": gate_parts["right"], "open": false, "at": gate_at}
	_gates.append(gate)
	_puzzles.append({"node": node, "at": at,
		"kind": str(section.get("puzzle", "color_match")), "gate": gate,
		"solved": false})


## A patrol of monsters. Kinds are mixed on purpose from level three onward:
## a walker teaches the attack button, a spitter teaches the shield, and an
## armoured one teaches that "hit it harder" is sometimes the wrong idea.
func _build_foes(section: Dictionary, at: float) -> void:
	var count: int = clampi(harder_i(int(section.get("count", 2)), 1), 1, 4)
	var kinds: Array = section.get("kinds", ["walker"])
	var zone := _flat_zone_near(at, _zone_width(section))
	for i in range(count):
		var kind := str(kinds[i % kinds.size()])
		var parts: Dictionary
		match kind:
			"spitter":
				parts = Foes.spitter(_world)
			"armoured":
				parts = Foes.armoured(_world)
			_:
				parts = Foes.walker(_world)
		var fx: float = lerpf(float(zone["left"]) + 120.0, float(zone["right"]) - 120.0,
			0.5 if count == 1 else float(i) / float(count - 1))
		(parts["node"] as Node2D).position = Vector2(fx, _ground_y)
		_foes.append({
			"node": parts["node"], "body": parts["body"], "weak": parts.get("weak"),
			"kind": kind, "hearts": 2 if kind == "armoured" else 1,
			"home": fx, "range": 130.0, "dir": 1.0,
			# Slow. A monster a child cannot walk away from is a monster that
			# turns exploring into a chase, and this is not a chase game.
			"speed": harder(46.0, 1.18),
			"state": "walk", "t": 0.0,
			"warn": harder(1.10, 0.82),      # never below the half-second floor
			"cool": harder(2.4, 0.85),
			"telegraph": null, "down": false,
		})


## Someone to let out. The interact key opens the cage; the friend then
## trots along behind, which is the whole reward -- company.
func _build_rescue(at: float) -> void:
	var parts := Foes.cage(_world)
	(parts["node"] as Node2D).position = Vector2(at, _ground_y)
	_cages.append({"node": parts["node"], "bars": parts["bars"], "pet": parts["pet"],
		"at": at, "freed": false})


## The rock giant, and the arena it stands in.
func _build_boss(section: Dictionary, at: float) -> void:
	var zone := _flat_zone_near(at, _zone_width(section))
	var arena_left: float = float(zone["left"]) + 80.0
	var arena_right: float = float(zone["right"]) - 80.0
	var parts := Foes.rock_boss(_world)
	(parts["node"] as Node2D).position = Vector2(arena_right - 200.0, _ground_y)
	_boss = {
		"node": parts["node"], "body": parts["body"], "arms": parts["arms"],
		"weak": parts["weak"], "shell": parts["shell"],
		"at": arena_right - 200.0, "left": arena_left, "right": arena_right,
		# Three phases, three hits each: short enough to hold a six-year-old,
		# long enough that beating it is a story they tell afterwards.
		"phase": 1, "hearts": 3, "max_hearts": 3, "total": 9, "hit": 0,
		"state": "rest", "t": 1.6, "shots": 0,
		"warn": harder(1.25, 0.84), "rest": harder(1.9, 0.86),
		"open": harder(3.0, 0.88),        # how long the weak point stays out
		"telegraph": null, "beaten": false, "gate": {},
	}


func _build_checkpoint(at: float) -> void:
	var parts := Props.checkpoint(_world)
	(parts["node"] as Node2D).position = Vector2(at, _ground_y)
	(parts["node"] as Node2D).modulate = Color(0.72, 0.74, 0.80)
	_checkpoints.append({"node": parts["node"], "flag": parts["flag"],
		"at": at, "claimed": false})


func _build_chest(at: float) -> void:
	var parts := Props.chest(_world)
	(parts["node"] as Node2D).position = Vector2(at, _ground_y)
	Shapes.glow(parts["node"], Vector2(0, -40.0), 150.0, Color(1.0, 0.88, 0.44), 5, 0.22)
	_chest = {"node": parts["node"], "lid": parts["lid"], "at": at, "open": false}


# --- the hero and the hands --------------------------------------------------

func _build_hero() -> void:
	_hero = HeroCtl.new()
	_world.add_child(_hero)
	_hero.setup(GameData.current_skin(), _ground_y, 168.0)
	_hero.use_terrain(_platforms, _ropes)
	# What auto-aim turns toward: the monsters still standing, plus the boss.
	_hero.use_enemies(func():
		var targets: Array = []
		for foe in _foes:
			if not bool(foe["down"]) and is_instance_valid(foe["node"]):
				targets.append(foe["node"])
		if not _boss.is_empty() and not bool(_boss["beaten"]) \
				and is_instance_valid(_boss["node"]):
			targets.append(_boss["node"])
		return targets)
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
	_build_boss_bar()

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

	_bar = Pad.new()
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
	# A giant standing in the path IS the door. Walking round it would make
	# the whole fight optional, and a boss you can stroll past is not a boss.
	if not _boss.is_empty() and not bool(_boss["beaten"]):
		_hero.position.x = minf(_hero.position.x, float(_boss["right"]))
	_clock += delta
	_push_crates(delta)
	_tick_rocks(delta)
	_tick_vents(delta)
	_tick_foes(delta)
	_tick_goo(delta)
	_tick_boss(delta)
	_tick_pets(delta)
	_watch_seq_plates()
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
			var cool := node.create_tween()
			cool.tween_interval(1.6)
			cool.tween_callback(func(): gate["nudging"] = false)
		# Pushing at a shut door for two seconds is a child who has not found
		# the plate. Point at it. The house rule is that the game shows you
		# rather than telling you, and never makes you feel slow for asking.
		gate["pressing"] = float(gate.get("pressing", 0.0)) + get_physics_process_delta_time()
		if float(gate["pressing"]) > 2.0 and not bool(gate.get("pointed", false)):
			gate["pointed"] = true
			_point_at_plate(gate)


## Point at whatever OPENS this gate: a pressure plate, the next plate in a
## sequence, or the question post. The hand always knows, because a child
## pushing at a locked door for two seconds is a child about to give up.
func _point_at_plate(gate: Dictionary) -> void:
	var spot := Vector2.ZERO
	var wobble: Variant = null
	for sw in _switches:
		if sw["gate"] == gate and not bool(sw["pressed"]):
			spot = Vector2(float(sw["at"]), float(sw["y"]) - 34.0)
			wobble = sw["plate"]
	for group in _seq_groups:
		if group["gate"] == gate and not bool(group["done"]):
			for p in group["plates"]:
				if int(p["dots"]) == int(group["next"]):
					spot = Vector2(float(p["at"]), _ground_y - 34.0)
					wobble = p["node"]
	for puzzle in _puzzles:
		if puzzle["gate"] == gate and not bool(puzzle["solved"]):
			spot = Vector2(float(puzzle["at"]), _ground_y - 230.0)
			wobble = puzzle["node"]
	if spot == Vector2.ZERO:
		return
	var hand := Props.hint_hand(_world)
	hand.position = spot
	if wobble is Node2D and is_instance_valid(wobble):
		Juice.pop(wobble, 0.34)
	# The hand cleans itself up with a tween it OWNS, so leaving the level
	# takes the timer with it. A SceneTreeTimer outlives the node it was
	# meant to tidy, and complains about it in the log on the way out.
	var fade := hand.create_tween()
	fade.tween_interval(4.0)
	fade.tween_property(hand, "modulate:a", 0.0, 0.5)
	fade.tween_callback(hand.queue_free)


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


# --- the moving parts --------------------------------------------------------

## A crate is pushed by WALKING INTO IT. Beside it at ground level, the hero
## leans on it and it slides at walking pace; from above it is a platform the
## ordinary landing code already understands. It never leaves its zone, so it
## can neither fall into a pit nor be shoved past the shelf it exists for.
func _push_crates(delta: float) -> void:
	for crate in _crates:
		var node: Node2D = crate["node"]
		if not is_instance_valid(node):
			continue
		# On top? The platform system is already carrying us; nothing to do.
		if _hero.position.y < _ground_y - 60.0:
			continue
		var dx: float = _hero.position.x - node.position.x
		if absf(dx) > 68.0:
			continue
		# Pushing means walking INTO it: moving, and toward the box. Read off
		# the buttons rather than off velocity, because the contact clamp on
		# the line below zeroes the velocity the moment they touch -- which is
		# how the first version of this shoved the crate exactly 0 px.
		var want: float = _hero.wish_dir()
		if want != 0.0 and signf(-dx) == want:
			var to: float = clampf(node.position.x + want * HeroCtl.MOVE_SPEED
				* delta * 0.80, float(crate["left"]) + 56.0, float(crate["right"]) - 56.0)
			if absf(to - node.position.x) > 0.1 and fmod(_elapsed, 0.3) < delta * 1.5:
				Juice.dust(_world, Vector2(node.position.x - want * 50.0, _ground_y), 2, 0.5)
			node.position.x = to
		# Solid either way: stand the hero against the face of the box.
		_hero.position.x = node.position.x + (68.0 if dx > 0.0 else -68.0)


## The rockfall loop. Every rock is its own little clock; the shadow's size
## is the countdown, and the boulder lands exactly where the shadow said.
func _tick_rocks(delta: float) -> void:
	for rock in _rocks:
		rock["t"] = float(rock["t"]) - delta
		match str(rock["state"]):
			"rest":
				if float(rock["t"]) <= 0.0:
					rock["state"] = "warn"
					rock["t"] = float(rock["warn"])
					var rng: RandomNumberGenerator = rock["rng"]
					rock["x"] = rng.randf_range(float(rock["left"]) + 70.0,
						float(rock["right"]) - 70.0)
					var shadow: Node2D = rock["shadow"]
					if is_instance_valid(shadow):
						shadow.position = Vector2(float(rock["x"]), _ground_y - 4.0)
						shadow.scale = Vector2(0.25, 0.25)
						shadow.visible = true
					if _hero_can_see(float(rock["x"])):
						_warn_once("rocks", I18n.t("adventure.rocks"))
			"warn":
				var shadow2: Node2D = rock["shadow"]
				if is_instance_valid(shadow2):
					var grown: float = 1.0 - float(rock["t"]) / float(rock["warn"])
					shadow2.scale = Vector2(0.25, 0.25).lerp(Vector2.ONE, grown)
				if float(rock["t"]) <= 0.0:
					rock["state"] = "fall"
					var node := Props.boulder(_world)
					node.position = Vector2(float(rock["x"]), _ground_y - 840.0)
					rock["node"] = node
			"fall":
				var node2: Node2D = rock["node"]
				if not is_instance_valid(node2):
					rock["state"] = "rest"
					rock["t"] = float(rock["cool"])
					continue
				node2.position.y += 1250.0 * delta
				node2.rotation += delta * 1.6
				# The hurtbox is honest: the boulder's own width, nothing more.
				if absf(_hero.position.x - float(rock["x"])) < 56.0 \
						and node2.position.y > _hero.position.y - 175.0 \
						and node2.position.y < _hero.position.y + 8.0:
					_hero.take_hit(node2.position)
				if node2.position.y >= _ground_y - 20.0:
					node2.position.y = _ground_y - 20.0
					rock["state"] = "shatter"
					rock["t"] = 0.4
					Juice.dust(_world, Vector2(float(rock["x"]), _ground_y), 7, 1.1)
					var shadow3: Node2D = rock["shadow"]
					if is_instance_valid(shadow3):
						shadow3.visible = false
			"shatter":
				var node3: Node2D = rock["node"]
				if is_instance_valid(node3):
					node3.modulate.a = maxf(float(rock["t"]) / 0.4, 0.0)
				if float(rock["t"]) <= 0.0:
					if is_instance_valid(node3):
						node3.queue_free()
					rock["node"] = null
					rock["state"] = "rest"
					var rng2: RandomNumberGenerator = rock["rng"]
					rock["t"] = float(rock["cool"]) * rng2.randf_range(0.8, 1.35)


## The fire vents. One shared rhythm, staggered starts: red glow first,
## always; then the column; then quiet. Standing in a warning costs nothing
## -- only the flame itself has teeth.
func _tick_vents(delta: float) -> void:
	for vent in _vents:
		var cycle: float = float(vent["warn"]) + float(vent["blaze"]) + float(vent["idle"])
		vent["t"] = fmod(float(vent["t"]) + delta, cycle)
		var t: float = float(vent["t"])
		var glow: Node2D = vent["glow"]
		var flame: Node2D = vent["flame"]
		if t < float(vent["warn"]):
			if is_instance_valid(glow):
				glow.modulate.a = 0.35 + 0.45 * absf(sin(t * 9.0))
			if is_instance_valid(flame):
				flame.visible = false
			if t < delta * 2.0 and _hero_can_see(float(vent["at"])):
				_warn_once("fire", I18n.t("adventure.fire"))
		elif t < float(vent["warn"]) + float(vent["blaze"]):
			if is_instance_valid(glow):
				glow.modulate.a = 1.0
			if is_instance_valid(flame):
				if not flame.visible:
					flame.visible = true
					AudioManager.play_sfx("res://assets/audio/beam.ogg")
				flame.scale.y = 0.92 + 0.10 * absf(sin(t * 26.0))
			if absf(_hero.position.x - float(vent["at"])) < 52.0 \
					and _hero.position.y > _ground_y - 165.0:
				_hero.take_hit(Vector2(float(vent["at"]), _ground_y))
		else:
			if is_instance_valid(glow):
				glow.modulate.a = 0.0
			if is_instance_valid(flame):
				flame.visible = false


## The step-in-order plates. Edge-triggered -- STANDING on a plate is one
## step, not sixty a second -- and walking back over an already-green plate
## is free, so pacing about while thinking costs nothing.
func _watch_seq_plates() -> void:
	for group in _seq_groups:
		if bool(group["done"]):
			continue
		for plate in group["plates"]:
			var on: bool = _hero.grounded \
				and absf(_hero.position.x - float(plate["at"])) < 52.0 \
				and absf(_hero.position.y - _ground_y) < 8.0
			if on and not bool(plate["on"]):
				plate["on"] = true
				_step_seq_plate(group, plate)
			elif not on:
				plate["on"] = false


func _step_seq_plate(group: Dictionary, plate: Dictionary) -> void:
	if bool(plate["lit"]):
		return                          # re-crossing a done plate is free
	if int(plate["dots"]) == int(group["next"]):
		plate["lit"] = true
		group["next"] = int(group["next"]) + 1
		var lamp: Node2D = plate["lamp"]
		if is_instance_valid(lamp):
			lamp.modulate = Color(0.55, 1.0, 0.62)
			Juice.pop(plate["node"], 0.22)
		AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg"
			% clampi(int(plate["dots"]), 1, 5))
		var all_done := true
		for p in group["plates"]:
			if not bool(p["lit"]):
				all_done = false
		if all_done:
			group["done"] = true
			Juice.burst(_world, Vector2(float(plate["at"]), _ground_y - 90.0), 22)
			_open_gate(group["gate"])
	else:
		# Wrong order: everything just lights up again. A shrug. The child's
		# hearts, progress and dignity are all exactly where they left them.
		group["next"] = 1
		for p in group["plates"]:
			p["lit"] = false
			var lamp2: Node2D = p["lamp"]
			if is_instance_valid(lamp2):
				lamp2.modulate = Color.WHITE
		Juice.nudge(plate["node"])
		AudioManager.play_sfx("res://assets/audio/try_again.ogg")
		_say(I18n.t("adventure.seq_again"))


# --- monsters -----------------------------------------------------------------

## Every monster's turn, every frame.
##
## They walk their beat, and when the hero comes close they WIND UP -- a ring
## closing in for the whole telegraph window -- before doing anything at all.
## A walker lunges; a spitter throws. Nothing here ever touches the hero
## during the wind-up, so a child who backs off on seeing the ring is always
## right to have done it.
func _tick_foes(delta: float) -> void:
	for foe in _foes:
		# Check the flag BEFORE typing the node. A beaten monster's node is
		# freed a second later by its own farewell tween, and assigning a
		# freed instance to a typed variable is an error in itself -- the
		# is_instance_valid() guard never gets a chance to run.
		if bool(foe["down"]) or not is_instance_valid(foe["node"]):
			continue
		var node: Node2D = foe["node"]
		foe["t"] = float(foe["t"]) - delta
		var to_hero: float = _hero.position.x - node.position.x
		match str(foe["state"]):
			"walk":
				node.position.x += float(foe["dir"]) * float(foe["speed"]) * delta
				if absf(node.position.x - float(foe["home"])) > float(foe["range"]):
					foe["dir"] = -float(foe["dir"])
					node.position.x = clampf(node.position.x,
						float(foe["home"]) - float(foe["range"]),
						float(foe["home"]) + float(foe["range"]))
				_face_foe(foe, signf(to_hero) if absf(to_hero) < 460.0 else float(foe["dir"]))
				var trigger: float = 380.0 if str(foe["kind"]) == "spitter" else 190.0
				if absf(to_hero) < trigger and float(foe["t"]) <= 0.0 \
						and absf(_hero.position.y - _ground_y) < 200.0:
					foe["state"] = "warn"
					foe["t"] = float(foe["warn"])
					foe["telegraph"] = Foes.telegraph(node,
						Color(1.0, 0.55, 0.30))
					(foe["telegraph"] as Node2D).position = Vector2(0, -80.0)
					if str(foe["kind"]) == "spitter":
						_warn_once("spitter", I18n.t("adventure.shield_hint"))
			"warn":
				_shrink_telegraph(foe, float(foe["warn"]))
				if float(foe["t"]) <= 0.0:
					_drop_telegraph(foe)
					foe["state"] = "strike"
					foe["t"] = 0.45
					if str(foe["kind"]) == "spitter":
						_spit(node)
					else:
						Juice.pop(foe["body"], 0.22)
			"strike":
				if str(foe["kind"]) != "spitter":
					# The lunge: a short hop toward the hero, and only NOW
					# does touching it cost anything.
					node.position.x += signf(to_hero) * 190.0 * delta
					_touch_test(foe, node)
				if float(foe["t"]) <= 0.0:
					foe["state"] = "walk"
					foe["t"] = float(foe["cool"])
		if str(foe["state"]) != "strike":
			_touch_test(foe, node)


## Walking into a monster costs a heart -- but the monster is never the one
## that closed the distance except during its own telegraphed lunge.
func _touch_test(foe: Dictionary, node: Node2D) -> void:
	if bool(foe["down"]) or _hero.invulnerable():
		return
	if absf(_hero.position.x - node.position.x) > 62.0:
		return
	if _hero.position.y < _ground_y - 110.0:
		return                       # sailing over its head is free
	if _blocking():
		_block_flash(node.position)
		return
	_hero.take_hit(node.position)


func _face_foe(foe: Dictionary, dir: float) -> void:
	var body: Node2D = foe["body"]
	if is_instance_valid(body) and dir != 0.0:
		body.scale.x = absf(body.scale.x) * signf(dir)


func _shrink_telegraph(holder: Dictionary, window: float) -> void:
	var ring: Node2D = holder["telegraph"]
	if not is_instance_valid(ring):
		return
	var left: float = clampf(float(holder["t"]) / maxf(window, 0.01), 0.0, 1.0)
	ring.scale = Vector2.ONE * lerpf(0.34, 1.25, left)
	ring.modulate.a = lerpf(1.0, 0.55, left)


func _drop_telegraph(holder: Dictionary) -> void:
	var ring: Variant = holder.get("telegraph")
	if ring is Node2D and is_instance_valid(ring):
		(ring as Node2D).queue_free()
	holder["telegraph"] = null


func _spit(from: Node2D) -> void:
	var ball := Foes.goo_ball(_world)
	ball.position = from.position + Vector2(signf(_hero.position.x - from.position.x)
		* 56.0, -86.0)
	var away: float = _hero.position.x - ball.position.x
	_goo.append({"node": ball,
		# Deliberately slow and arcing: it must be watchable all the way in.
		"vel": Vector2(signf(away) * harder(250.0, 1.12), -180.0)})
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")


func _tick_goo(delta: float) -> void:
	for ball in _goo.duplicate():
		var node: Node2D = ball["node"]
		if not is_instance_valid(node):
			_goo.erase(ball)
			continue
		var vel: Vector2 = ball["vel"]
		vel.y += 520.0 * delta
		ball["vel"] = vel
		node.position += vel * delta
		node.rotation += delta * 3.0
		if node.position.distance_to(_hero_core()) < 78.0:
			if _blocking():
				_block_flash(node.position)
			else:
				_hero.take_hit(node.position)
			Juice.burst(_world, node.position, 10)
			node.queue_free()
			_goo.erase(ball)
			continue
		if node.position.y > _ground_y + 20.0:
			Juice.dust(_world, Vector2(node.position.x, _ground_y), 4, 0.7)
			node.queue_free()
			_goo.erase(ball)


## The shield: a real window, not a light show. Raised with skill 0, it eats
## exactly the hits that land while it is up.
func _blocking() -> bool:
	return _clock < _shield_until


func _block_flash(at: Vector2) -> void:
	Juice.shockwave(_world, _hero.position + Vector2(0, -90.0), 130.0,
		Color(0.55, 0.85, 1.0))
	Juice.burst(_world, at, 8)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")


## The swing lands. Auto-aim already turned the hero toward the nearest
## enemy; this decides what the swing actually reached.
func _swing_hits(area: Dictionary) -> void:
	var at: Vector2 = area["at"]
	var radius: float = float(area["radius"])
	for foe in _foes:
		if bool(foe["down"]) or not is_instance_valid(foe["node"]):
			continue
		var node: Node2D = foe["node"]
		# A CAPSULE, not a circle round the origin. A monster's origin is at
		# its feet and the swing lands 80 px above the hero's; measured
		# centre-to-centre with a circle, a hit from above came out 217 px
		# away and the armoured monster was literally unhittable. Generous on
		# purpose besides -- the design brief says big hitboxes, and a
		# six-year-old aims with their whole arm.
		if absf(node.position.x - at.x) > radius * 0.92:
			continue
		if absf((node.position.y - 46.0) - at.y) > 160.0:
			continue
		# The armoured one is the lesson that force is not always the answer:
		# only a hit coming DOWN onto its glowing spot counts.
		if str(foe["kind"]) == "armoured" and _hero.position.y > node.position.y - 70.0:
			Juice.nudge(foe["body"])
			var spot: Variant = foe.get("weak")
			if spot is Node2D and is_instance_valid(spot):
				Juice.pop(spot, 0.4)
			AudioManager.play_sfx("res://assets/audio/try_again.ogg")
			continue
		_hurt_foe(foe)
	_hit_boss(at, radius)


func _hurt_foe(foe: Dictionary) -> void:
	foe["hearts"] = int(foe["hearts"]) - 1
	var node: Node2D = foe["node"]
	Juice.burst(_world, node.position + Vector2(0, -70.0), 14)
	if int(foe["hearts"]) > 0:
		Juice.nudge(foe["body"])
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		return
	# Beaten, not killed: it sits down, waves, and pops away in sparkles.
	foe["down"] = true
	_drop_telegraph(foe)
	score_correct()
	AudioManager.play_sfx("res://assets/audio/star.ogg")
	Juice.burst(_world, node.position + Vector2(0, -60.0), 26)
	var body: Node2D = foe["body"]
	if is_instance_valid(body) and Juice.motion_enabled():
		var t := body.create_tween()
		t.tween_property(body, "scale", Vector2(1.15, 0.72), 0.16)
		t.tween_property(body, "rotation_degrees", -22.0, 0.3)
		t.tween_interval(0.5)
		t.parallel().tween_property(body, "modulate:a", 0.0, 0.5)
		t.tween_callback(node.queue_free)
	else:
		node.queue_free()


# --- the rock giant -----------------------------------------------------------

## Three phases, each with one telegraphed attack and one plain opening to
## hit back. The boss is slow everywhere: this is a puzzle about watching and
## waiting, not a test of thumbs.
func _tick_boss(delta: float) -> void:
	if _boss.is_empty() or bool(_boss["beaten"]):
		return
	var node: Node2D = _boss["node"]
	if not is_instance_valid(node):
		return
	# Asleep until the child walks into the arena: no six-year-old should be
	# shot at by something still off the side of the screen.
	if _hero.position.x < float(_boss["left"]) - 40.0:
		return
	_boss["t"] = float(_boss["t"]) - delta
	_refresh_boss_bar()

	match str(_boss["state"]):
		"rest":
			if float(_boss["t"]) <= 0.0:
				_boss["state"] = "warn"
				_boss["t"] = float(_boss["warn"])
				_boss["shots"] = 0
				var ring := Foes.telegraph(node, Color(1.0, 0.5, 0.28))
				ring.position = Vector2(0, -150.0)
				ring.scale = Vector2(1.6, 1.6)
				_boss["telegraph"] = ring
				_raise_arms(true)
				if int(_boss["phase"]) == 3:
					_say(I18n.t("adventure.boss_shell"))
		"warn":
			_shrink_telegraph(_boss, float(_boss["warn"]))
			if float(_boss["t"]) <= 0.0:
				_drop_telegraph(_boss)
				_raise_arms(false)
				match int(_boss["phase"]):
					1:
						_boss_slam()
					2:
						_boss_throw()
					_:
						_boss_shell()
				_boss["state"] = "open" if int(_boss["phase"]) != 3 else "shelled"
				_boss["t"] = float(_boss["open"])
				if int(_boss["phase"]) != 3:
					_show_weak(true)
					_say(I18n.t("adventure.boss_open"))
		"open":
			if float(_boss["t"]) <= 0.0:
				_show_weak(false)
				_boss["state"] = "rest"
				_boss["t"] = float(_boss["rest"])
		"shelled":
			# Phase three waits, shelled, until the charged beam breaks it.
			pass
	_boss_touch()


func _raise_arms(up: bool) -> void:
	for arm in _boss["arms"]:
		if not is_instance_valid(arm):
			continue
		if Juice.motion_enabled():
			var t := (arm as Node2D).create_tween()
			t.tween_property(arm, "rotation_degrees", -52.0 if up else 0.0, 0.35)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			(arm as Node2D).rotation_degrees = -52.0 if up else 0.0


func _show_weak(on: bool) -> void:
	var weak: Node2D = _boss["weak"]
	if not is_instance_valid(weak):
		return
	weak.visible = on
	if on:
		Juice.pop(weak, 0.4)


## Phase one: it slams the ground. A shadow marks the spot for the whole
## telegraph, exactly like a falling rock, because a child who learned the
## rock in level two already knows how to read this.
func _boss_slam() -> void:
	var node: Node2D = _boss["node"]
	var spot: float = clampf(_hero.position.x, float(_boss["left"]),
		float(_boss["right"]))
	Juice.shockwave(_world, Vector2(spot, _ground_y), 220.0, Color(0.95, 0.72, 0.42))
	Juice.dust(_world, Vector2(spot, _ground_y), 10, 1.4)
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	if absf(_hero.position.x - spot) < 130.0 and _hero.grounded:
		if _blocking():
			_block_flash(Vector2(spot, _ground_y))
		else:
			_hero.take_hit(node.position)


## Phase two: three stones, each announced by the same ring.
func _boss_throw() -> void:
	var node: Node2D = _boss["node"]
	for i in range(3):
		var when: float = 0.35 * float(i)
		var t := node.create_tween()
		t.tween_interval(when)
		t.tween_callback(func():
			if is_instance_valid(node) and not bool(_boss["beaten"]):
				_spit(node))


func _boss_shell() -> void:
	var shell: Node2D = _boss["shell"]
	if is_instance_valid(shell):
		shell.visible = true
		Juice.pop(shell, 0.3)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")


## Standing inside the giant is a bad idea, but a gently-signposted one: it
## nudges you back rather than mauling you.
func _boss_touch() -> void:
	var node: Node2D = _boss["node"]
	if _hero.invulnerable() or absf(_hero.position.x - node.position.x) > 110.0:
		return
	if _blocking():
		_block_flash(node.position)
		return
	_hero.take_hit(node.position)


func _hit_boss(at: Vector2, radius: float) -> void:
	if _boss.is_empty() or bool(_boss["beaten"]):
		return
	var node: Node2D = _boss["node"]
	if not is_instance_valid(node) or node.position.distance_to(at) > radius + 140.0:
		return
	var shell: Node2D = _boss["shell"]
	if is_instance_valid(shell) and shell.visible:
		# The shell shrugs off the ordinary swing. The lightning skill is the
		# answer, and the game says so rather than leaving it to be guessed.
		Juice.nudge(_boss["body"])
		_say(I18n.t("adventure.boss_shell"))
		AudioManager.play_sfx("res://assets/audio/try_again.ogg")
		return
	if str(_boss["state"]) != "open":
		Juice.nudge(_boss["body"])
		AudioManager.play_sfx("res://assets/audio/try_again.ogg")
		return
	_wound_boss()


func _wound_boss() -> void:
	_boss["hit"] = int(_boss["hit"]) + 1
	_boss["hearts"] = int(_boss["hearts"]) - 1
	score_correct()
	Juice.burst(_world, (_boss["node"] as Node2D).position + Vector2(0, -150.0), 22)
	Juice.nudge(_boss["body"])
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	_refresh_boss_bar()
	if int(_boss["hearts"]) > 0:
		return
	# End of a phase: it staggers, and the next phase begins.
	_show_weak(false)
	_boss["phase"] = int(_boss["phase"]) + 1
	_boss["hearts"] = int(_boss["max_hearts"])
	_boss["state"] = "rest"
	_boss["t"] = float(_boss["rest"]) + 0.8
	if int(_boss["phase"]) > 3:
		_finish_boss()
	else:
		_say(I18n.t("adventure.boss_phase"))
		Juice.shockwave(_world, (_boss["node"] as Node2D).position + Vector2(0, -140.0),
			260.0, Color(1.0, 0.86, 0.40))


## Beaten, not beaten UP: it sits down, rubs its head, and waves.
func _finish_boss() -> void:
	_boss["beaten"] = true
	_drop_telegraph(_boss)
	var shell: Node2D = _boss["shell"]
	if is_instance_valid(shell):
		shell.visible = false
	var body: Node2D = _boss["body"]
	if is_instance_valid(body) and Juice.motion_enabled():
		var t := body.create_tween()
		t.tween_property(body, "scale", Vector2(1.12, 0.80), 0.4)\
			.set_trans(Tween.TRANS_SINE)
		t.tween_property(body, "rotation_degrees", 6.0, 0.5)
		t.tween_property(body, "rotation_degrees", -6.0, 0.8)
		t.set_loops()
	Juice.burst(_world, (_boss["node"] as Node2D).position + Vector2(0, -160.0), 40)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	_say(I18n.t("adventure.boss_done"))
	if _boss_bar != null and is_instance_valid(_boss_bar):
		_boss_bar.visible = false
	if not _boss.get("gate", {}).is_empty():
		_open_gate(_boss["gate"])


func _refresh_boss_bar() -> void:
	if _boss_bar == null or not is_instance_valid(_boss_bar):
		return
	if not _boss_bar.visible:
		_boss_bar.visible = true
	if _boss_fill == null or not is_instance_valid(_boss_fill):
		return
	for child in _boss_fill.get_children():
		child.queue_free()
	# Three pips per phase, and the phase number as pips too -- no digits.
	var wide := 520.0
	var per: float = wide / float(_boss["total"])
	var left: int = int(_boss["total"]) - int(_boss["hit"])
	for i in range(left):
		Shapes.fill(_boss_fill, Shapes.rounded_rect(
			Vector2(float(i) * per + 3.0, 3.0), Vector2(per - 6.0, 26.0), 6.0),
			Color(0.96, 0.42, 0.38) if i < 3 else (
				Color(1.0, 0.70, 0.32) if i < 6 else Color(1.0, 0.88, 0.42)), 0.0)


# --- rescued friends ----------------------------------------------------------

## A freed friend trots after the hero at a polite distance. It cannot be
## hurt and cannot be lost; it is company, not an escort mission.
func _tick_pets(delta: float) -> void:
	for pet in _pets:
		var node: Node2D = pet["node"]
		if not is_instance_valid(node):
			continue
		var want: float = _hero.position.x - 96.0 * signf(_hero.facing)
		node.position.x = lerpf(node.position.x, want, clampf(delta * 2.4, 0.0, 1.0))
		node.position.y = _ground_y - 34.0 + sin(_clock * 6.0) * 5.0


## Callouts that should happen exactly once per level, the first time the
## thing is actually on screen -- a warning about rocks you cannot see yet is
## just noise.
func _hero_can_see(x: float) -> bool:
	return absf(x - _hero.position.x) < 900.0


func _warn_once(family: String, text: String) -> void:
	if _warned.has(family):
		return
	_warned[family] = true
	_say(text)


# --- interaction -------------------------------------------------------------

## Rebuild the "what is near me" answer every frame and let the bar show it.
##
## All prompts float at the same height, well clear of the hero's head. The
## first version put each one near its own object, which floated the cage's
## key exactly where the hero's face was -- a button covering the character
## you are trying to look at.
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
				_ground_y - 250.0), "icon": "chest"}
			if not bool(_chest.get("told", false)):
				_chest["told"] = true
				_say(I18n.t("adventure.chest"))
	for puzzle in _puzzles:
		if bool(puzzle["solved"]):
			continue
		var d2: float = absf(_hero.position.x - float(puzzle["at"]))
		if d2 < best:
			best = d2
			_nearest = {"kind": "puzzle", "at": Vector2(float(puzzle["at"]),
				_ground_y - 250.0), "icon": "magnifier", "puzzle": puzzle}
	for cage in _cages:
		if bool(cage["freed"]):
			continue
		var d3: float = absf(_hero.position.x - float(cage["at"]))
		if d3 < best:
			best = d3
			_nearest = {"kind": "cage", "at": Vector2(float(cage["at"]),
				_ground_y - 250.0), "icon": "lock", "cage": cage}
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
		"puzzle":
			_open_card(_nearest["puzzle"])
		"cage":
			_free_pet(_nearest["cage"])


## Let someone out. The bars fly apart, the friend bounces, and from then on
## it trots along behind you. There is nothing to protect and nothing to
## lose -- the reward for being kind is company, and that is enough.
func _free_pet(cage: Dictionary) -> void:
	if bool(cage["freed"]):
		return
	cage["freed"] = true
	score_correct()
	var bars: Node2D = cage["bars"]
	var pet: Node2D = cage["pet"]
	if is_instance_valid(bars):
		if Juice.motion_enabled():
			var t := bars.create_tween().set_parallel(true)
			t.tween_property(bars, "scale", Vector2(1.35, 1.25), 0.4)
			t.tween_property(bars, "modulate:a", 0.0, 0.4)
			t.chain().tween_callback(bars.queue_free)
		else:
			bars.queue_free()
	Juice.burst(_world, Vector2(float(cage["at"]), _ground_y - 80.0), 26)
	AudioManager.play_sfx("res://assets/audio/star.ogg")
	_say(I18n.t("adventure.rescued"))
	if is_instance_valid(pet):
		# Hand the friend to the world so it can follow us anywhere, rather
		# than staying a child of a cage that is busy disappearing.
		var keep := pet.global_position
		pet.get_parent().remove_child(pet)
		_world.add_child(pet)
		pet.global_position = keep
		Juice.pop(pet, 0.4)
		_pets.append({"node": pet})


## The knowledge card, asked in place. The hero freezes mid-level, the hands
## disappear (there is nothing for them to do), the world dims, the question
## comes up. Solving it opens the puzzle's gate and gives the hands back.
func _open_card(puzzle: Dictionary) -> void:
	if _card != null and is_instance_valid(_card):
		return
	_hero.freeze(true)
	if _bar != null and is_instance_valid(_bar):
		_bar.visible = false
	_card = Card.new()
	_hud.add_child(_card)
	_card.open(str(puzzle["kind"]),
		Shapes.rng_for("%s-card" % str(level_data.get("id", ""))),
		difficulty() == GENTLE)
	_card.answered.connect(func(correct: bool):
		if correct:
			score_correct()
		else:
			score_mistake())
	_card.solved.connect(func():
		puzzle["solved"] = true
		_card = null
		_hero.freeze(false)
		if _bar != null and is_instance_valid(_bar):
			_bar.visible = true
		var node: Node2D = puzzle["node"]
		if is_instance_valid(node):
			Juice.burst(_world, node.position + Vector2(0, -160.0), 20)
		_open_gate(puzzle["gate"]))


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
		_swing_hits(area)
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
			# Reduce-motion: the arc still has to go away, and the countdown
			# still belongs to the arc rather than to the scene tree.
			var gone := arc.create_tween()
			gone.tween_interval(0.25)
			gone.tween_callback(arc.queue_free)
		AudioManager.play_sfx("res://assets/audio/beam.ogg")


func _on_skill(slot: int) -> void:
	if not _bar.use_skill(slot):
		return
	match slot:
		0:
			_raise_shield()
		1:
			_fire_beam()
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")


## The shield: a REAL window, and a visible one. It follows the hero for its
## whole duration rather than being a ring left behind on the ground, because
## a child who presses shield and then steps sideways has every right to
## still be shielded.
const SHIELD_TIME := 2.2

func _raise_shield() -> void:
	_shield_until = _clock + SHIELD_TIME
	var ring := Node2D.new()
	_hero.add_child(ring)
	ring.position = Vector2(0, -90.0)
	Shapes.glow(ring, Vector2.ZERO, 170.0, Color(0.55, 0.85, 1.0), 4, 0.34)
	var bubble := Line2D.new()
	bubble.points = Shapes.circle_points(Vector2.ZERO, 96.0, 30)
	bubble.closed = true
	bubble.width = 7.0
	bubble.default_color = Color(0.66, 0.92, 1.0, 0.92)
	bubble.antialiased = true
	ring.add_child(bubble)
	var t := ring.create_tween()
	t.tween_interval(SHIELD_TIME - 0.4)
	t.tween_property(ring, "modulate:a", 0.0, 0.4)
	t.tween_callback(ring.queue_free)


## The charged beam: the answer to the boss's shell, and a satisfying thing
## to fire at anything else. Reaches across the screen, so a child never has
## to stand inside a monster to use it.
func _fire_beam() -> void:
	_hero.figure().power_up()
	var from: Vector2 = _hero_core()
	var to: Vector2 = from + Vector2(_hero.facing * 620.0, 0.0)
	var beam := Node2D.new()
	_world.add_child(beam)
	Shapes.fill(beam, Shapes.taper(from, to, 34.0, 14.0), Color(1.0, 0.92, 0.55), 0.0)
	Shapes.glow(beam, (from + to) * 0.5, 260.0, Color(1.0, 0.86, 0.40), 5, 0.42)
	var t := beam.create_tween()
	t.tween_interval(0.22)
	t.tween_property(beam, "modulate:a", 0.0, 0.22)
	t.tween_callback(beam.queue_free)
	Juice.shockwave(_world, from, 190.0, Color(1.0, 0.86, 0.40))
	AudioManager.play_sfx("res://assets/audio/beam.ogg")

	# The beam is what breaks the boss's shell -- the one thing an ordinary
	# swing cannot do.
	if not _boss.is_empty() and not bool(_boss["beaten"]):
		var shell: Node2D = _boss["shell"]
		var node: Node2D = _boss["node"]
		if is_instance_valid(shell) and shell.visible and is_instance_valid(node) \
				and absf(node.position.x - from.x) < 700.0:
			shell.visible = false
			_boss["state"] = "open"
			_boss["t"] = float(_boss["open"])
			_show_weak(true)
			Juice.burst(_world, node.position + Vector2(0, -140.0), 30)
			Juice.shockwave(_world, node.position + Vector2(0, -100.0), 300.0,
				Color(0.55, 0.85, 1.0))
			_say(I18n.t("adventure.boss_open"))
	# And it knocks over any ordinary monster in its path.
	for foe in _foes:
		if bool(foe["down"]) or not is_instance_valid(foe["node"]):
			continue
		var fx: float = (foe["node"] as Node2D).position.x
		if signf(fx - from.x) == signf(_hero.facing) and absf(fx - from.x) < 620.0:
			_hurt_foe(foe)


# --- being hurt, and the end -------------------------------------------------

func _on_hurt(remaining: int) -> void:
	_hits_taken += 1
	score_mistake()
	_refresh_hearts(remaining)


func _on_died() -> void:
	_deaths += 1
	_tries += 1
	_hero.heal_full()
	_refresh_hearts(_hero.hearts)
	_hero.place_at(_last_safe)
	Juice.dust(_world, _last_safe, 8)
	_say(I18n.t("adventure.again"))
	# Two falls in one run and the island quietly leans in. Not a menu, not a
	# question -- a six-year-old who has just lost twice does not want to be
	# ASKED whether they would like it easier.
	if _tries >= 2:
		_offer_help()


## Everything that can be made kinder without changing what the level is:
## longer warnings, slower monsters, a gentler giant, and a hand pointing at
## whatever is currently in the way.
func _offer_help() -> void:
	if bool(_warned.get("helped", false)):
		return
	_warned["helped"] = true
	for foe in _foes:
		foe["warn"] = float(foe["warn"]) * 1.45
		foe["cool"] = float(foe["cool"]) * 1.35
		foe["speed"] = float(foe["speed"]) * 0.7
	for rock in _rocks:
		rock["warn"] = float(rock["warn"]) * 1.45
		rock["cool"] = float(rock["cool"]) * 1.3
	for vent in _vents:
		vent["warn"] = float(vent["warn"]) * 1.45
		vent["idle"] = float(vent["idle"]) * 1.3
	if not _boss.is_empty():
		_boss["warn"] = float(_boss["warn"]) * 1.4
		_boss["rest"] = float(_boss["rest"]) * 1.3
		_boss["open"] = float(_boss["open"]) * 1.5
		# One phase shorter, so a stuck child still gets to the end of the
		# story rather than to the end of their patience.
		_boss["total"] = maxi(int(_boss["total"]) - int(_boss["max_hearts"]), 3)
		if int(_boss["phase"]) < 3:
			_boss["phase"] = 3
			_boss["hearts"] = int(_boss["max_hearts"])
		_refresh_boss_bar()
	_say(I18n.t("adventure.helping"))
	for gate in _gates:
		if not bool(gate["open"]):
			_point_at_plate(gate)
			break


func _refresh_hearts(remaining: int) -> void:
	for i in range(_heart_icons.size()):
		var heart: Control = _heart_icons[i]
		if is_instance_valid(heart):
			heart.modulate = Color(1, 1, 1) if i < remaining \
				else Color(0.35, 0.38, 0.48, 0.7)


## The giant's health, as a row of pips rather than a number or a smooth bar.
## Pips can be counted, and "three more to go" is a thought a six-year-old can
## actually have. Hidden until the giant wakes up.
func _build_boss_bar() -> void:
	var holder := Control.new()
	holder.position = Vector2(380, 168)
	holder.size = Vector2(520, 32)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	_hud.add_child(holder)
	_boss_bar = holder

	var back := Node2D.new()
	holder.add_child(back)
	Shapes.fill(back, Shapes.rounded_rect(Vector2.ZERO, Vector2(520, 32), 10.0),
		Color(0.06, 0.09, 0.18, 0.72), 0.0)
	_boss_fill = Node2D.new()
	holder.add_child(_boss_fill)

	var face: Control = UiKit.picture("monster", 54)
	if face != null:
		face.position = Vector2(-66, -12)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(face)


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
	# Timed off a tween the LABEL owns, not a SceneTreeTimer: a child who
	# leaves mid-sentence takes the label and its countdown with them. A
	# tree timer outlives the level and fires into a freed scene.
	var back := I18n.t(str(level_data.get("config", {})
		.get("instruction_key", "adventure.instruction")))
	var t := _instruction.create_tween()
	t.tween_interval(2.6)
	t.tween_callback(func():
		if is_instance_valid(_instruction) and not _finished:
			_instruction.text = back)


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
