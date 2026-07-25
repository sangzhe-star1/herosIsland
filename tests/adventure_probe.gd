extends Node
## Can a child actually FINISH an adventure level? All of them?
##
## Written before anyone plays one, because the whole 54-level rebuild rests
## on this template and "it boots and looks nice" has already been shown,
## twice on this project, to be a different claim from "it can be completed".
##
## The probe plays each level the way a person would: press right, jump when
## something is worth jumping for, hop over plates it should not step on yet,
## push the box with its body, tap the card's tiles with pretend fingers. It
## never reaches inside to set a flag that gameplay is supposed to set. When
## a beat is unreachable, it gets stuck on it and says which one.
##
## Before the walkthrough, the mechanical laws are tested head-on, because a
## walkthrough only proves the route it happened to take:
##   * a shut gate is a wall, and pushing on it opens nothing
##   * every placed thing sits inside the hero's real jump
##   * hazards warn for long enough to be dodged AT EVERY DIFFICULTY
##   * the crate moves when pushed and carries the hero to the shelf
##   * a wrong plate resets the sequence without costing anything
##   * a wrong card answer dims a tile and nothing else

const LEVELS := ["sunny_park_01", "sunny_park_02"]

var _out: Array[String] = []
var _lvl: Node

## The thing the pretend child has decided to go and do, or empty.
##
## Sticky on purpose. The first version recomputed "where would a child go"
## every frame from raw distances, and at the edge of the gate's stop zone
## the answer flipped every step -- the hero stood at the door vibrating
## between two answers for fifty seconds. A real child who turns around to
## look for the switch keeps looking until they have stood on it.
var _quest := {}     # {"x": float, "done": Callable}
var _card_tested := false


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	await get_tree().process_frame

	for level_id in LEVELS:
		await _run_level(level_id)

	for f in _out:
		print("FAIL  %s" % f)
	print("ADVENTURE PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


func _run_level(level_id: String) -> void:
	print("\n=== adventure probe: %s ===" % level_id)
	_quest = {}
	_card_tested = false
	GameManager.current_level_id = level_id
	_lvl = load("res://scenes/adventure/Adventure.tscn").instantiate()
	add_child(_lvl)
	for i in range(4):
		await get_tree().process_frame

	_report_terrain()
	_check_reachable()
	_check_hazard_warnings()
	await _check_warning_really_precedes_harm()
	await _check_gate_is_a_wall()
	await _check_wrong_plate_costs_nothing()
	await _check_crate_carries()
	await _walk_the_level(level_id)
	_report_result()

	_lvl.queue_free()
	_lvl = null
	for i in range(4):
		await get_tree().process_frame


# --- the mechanical laws -----------------------------------------------------

func _report_terrain() -> void:
	var flats: Array = []
	for entry in _lvl._platforms:
		if bool(entry.get("flat", false)):
			flats.append(entry["rect"])
	flats.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)

	var air: float = 2.0 * absf(HeroController.JUMP_VELOCITY) / HeroController.GRAVITY
	var reach: float = air * HeroController.MOVE_SPEED
	var widest := 0.0
	for i in range(1, flats.size()):
		var gap: float = flats[i].position.x - (flats[i - 1].position.x + flats[i - 1].size.x)
		widest = maxf(widest, gap)
	# Asked here, at the level's very first breath, before this probe has
	# teleported the hero anywhere: "does the hero start standing on the
	# ground" is a question about the LEVEL, not about the test harness.
	_ok(absf(_lvl._hero.position.y - _lvl._ground_y) < 2.0,
		"the hero starts %0.1f px off the ground" % absf(
			_lvl._hero.position.y - _lvl._ground_y))
	print("  ground: %d segments over %.0f px; widest gap %.0f px vs %.0f px jump" % [
		flats.size(), _lvl._length, widest, reach])
	var edges: Array = []
	for r in flats:
		edges.append("%.0f-%.0f" % [r.position.x, r.position.x + r.size.x])
	print("  flat: %s" % ", ".join(edges))
	_ok(widest < reach * 0.65,
		"a %.0f px gap is too wide for a %.0f px jump" % [widest, reach])
	_ok(flats.size() >= 4, "only %d ground segments -- the level is one slab" % flats.size())

	print("  beats: orbs=%d gems=%d springs=%d switches=%d gates=%d rocks=%d vents=%d seq=%d cards=%d crates=%d flags=%d chest=%s" % [
		_lvl._orbs.size(), _lvl._gems.size(), _lvl._springs.size(),
		_lvl._switches.size(), _lvl._gates.size(), _lvl._rocks.size(),
		_lvl._vents.size(), _lvl._seq_groups.size(), _lvl._puzzles.size(),
		_lvl._crates.size(), _lvl._checkpoints.size(),
		"yes" if not _lvl._chest.is_empty() else "NO"])
	var kinds := 0
	for present in [_lvl._orbs.size() > 0, _lvl._gems.size() > 0,
			_lvl._springs.size() > 0, _lvl._switches.size() > 0,
			_lvl._rocks.size() > 0, _lvl._vents.size() > 0,
			_lvl._seq_groups.size() > 0, _lvl._puzzles.size() > 0,
			_lvl._crates.size() > 0, not _lvl._chest.is_empty()]:
		if present:
			kinds += 1
	_ok(kinds >= 3, "a level needs at least three kinds of thing to do, found %d" % kinds)

	# Sequence plates must be further apart than the hero's step radius, or
	# standing on one stands on all of them and the puzzle solves itself in a
	# single step -- which is exactly how it shipped the first time, and it
	# looked completely fine in a screenshot.
	for group in _lvl._seq_groups:
		var xs: Array = []
		for p in group["plates"]:
			xs.append(float(p["at"]))
		xs.sort()
		for i in range(1, xs.size()):
			var apart: float = float(xs[i]) - float(xs[i - 1])
			_ok(apart >= 120.0,
				"two sequence plates are only %.0f px apart -- one step hits both" % apart)
		if xs.size() >= 2:
			print("  %d sequence plates, %.0f px apart" % [xs.size(),
				float(xs[1]) - float(xs[0])])


func _check_reachable() -> void:
	var ceiling: float = _lvl.reach()
	var stranded: Array = []
	for orb in _lvl._orbs:
		if not _standable_under(orb["at"], ceiling):
			stranded.append("orb at (%.0f, %.0f)" % [(orb["at"] as Vector2).x,
				(orb["at"] as Vector2).y])
	for gem in _lvl._gems:
		# A gem may need the spring or the crate-shelf; both end on a
		# standable platform, so the platform test still holds.
		var spring_reach: float = 1000.0 * 1000.0 / (2.0 * HeroController.GRAVITY)
		if not _standable_under(gem["at"], maxf(ceiling, spring_reach)):
			stranded.append("gem at (%.0f, %.0f)" % [(gem["at"] as Vector2).x,
				(gem["at"] as Vector2).y])
	for sw in _lvl._switches:
		if not _standable_under(Vector2(float(sw["at"]), float(sw["y"]) - 10.0), ceiling):
			stranded.append("plate at x=%.0f" % float(sw["at"]))
	for s in stranded:
		_out.append("out of reach: %s" % s)
	print("  reach = %.0f px up; %d placed things out of reach" % [ceiling, stranded.size()])


func _standable_under(at: Vector2, ceiling: float) -> bool:
	for entry in _lvl._platforms:
		var r: Rect2 = entry["rect"]
		var off := 0.0
		var node: Variant = entry.get("node")
		if node != null and is_instance_valid(node):
			off = (node as Node2D).position.x
		if at.x < r.position.x + off - 150.0 or at.x > r.position.x + off + r.size.x + 150.0:
			continue
		var top: float = r.position.y
		if node != null and is_instance_valid(node):
			top = float(entry.get("base_y", r.position.y)) + (node as Node2D).position.y
		var rise: float = top - at.y
		if rise >= -20.0 and rise <= ceiling + 95.0:
			return true
	return false


## A hazard's warning must be long enough to act on, at EVERY difficulty.
## BRAVE may shorten the fuse; it may not remove it. Half a second is about
## the floor of a six-year-old's see-then-move loop.
func _check_hazard_warnings() -> void:
	if _lvl._rocks.is_empty() and _lvl._vents.is_empty():
		return
	for rock in _lvl._rocks:
		_ok(float(rock["warn"]) >= 0.55,
			"a rock's warning is %.2f s -- too short to dodge" % float(rock["warn"]))
	for vent in _lvl._vents:
		_ok(float(vent["warn"]) >= 0.55,
			"a vent's warning is %.2f s -- too short to step back" % float(vent["warn"]))
	# And the BRAVE end of the dial, computed the way the level computes it:
	# one more 0.8x step down from whatever this run's difficulty produced.
	if not _lvl._rocks.is_empty():
		var brave_warn: float = float(_lvl._rocks[0]["warn"]) * pow(0.80,
			float(LevelManager.BRAVE - _lvl.difficulty()))
		_ok(brave_warn >= 0.5,
			"at BRAVE a rock would warn only %.2f s" % brave_warn)
		print("  rock warn %.2f s (%.2f s at BRAVE); vents warn %s" % [
			float(_lvl._rocks[0]["warn"]), brave_warn,
			"%.2f s" % float(_lvl._vents[0]["warn"]) if not _lvl._vents.is_empty() else "n/a"])


## The warning is not a config value -- it is a promise, and this measures
## whether the running game keeps it.
##
## Watches a real rockfall with a stopwatch: from the frame the shadow first
## appears to the frame the boulder lands. Configuration can say 1.05 s and
## the code can still drop the rock early; only the clock knows.
func _check_warning_really_precedes_harm() -> void:
	if _lvl._rocks.is_empty():
		return
	var rock: Dictionary = _lvl._rocks[0]
	# Stand well clear -- this measures the hazard, not the hero.
	_lvl._hero.place_at(Vector2(float(rock["left"]) - 500.0, _lvl._ground_y))

	var shadow_seen := -1
	var landed := -1
	for frame in range(600):
		await get_tree().physics_frame
		var shadow: Node2D = rock["shadow"]
		if shadow_seen < 0 and is_instance_valid(shadow) and shadow.visible:
			shadow_seen = frame
		if shadow_seen >= 0 and str(rock["state"]) == "shatter":
			landed = frame
			break
	if shadow_seen < 0 or landed < 0:
		_out.append("a rock never completed a warn-then-fall cycle")
		return
	var lead: float = float(landed - shadow_seen) / 60.0
	print("  measured a real rockfall: shadow up %.2f s before impact" % lead)
	_ok(lead >= 0.55,
		"the shadow appeared only %.2f s before the rock landed" % lead)

	# And the shadow must be UNDER the rock: a warning in the wrong place is
	# worse than none, because the child dodges into it.
	_ok(absf((rock["shadow"] as Node2D).position.x - float(rock["x"])) < 2.0,
		"the shadow was not where the rock fell")
	_lvl._hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
	await get_tree().physics_frame


## Stepping the plates out of order must cost NOTHING -- not a heart, not a
## collected orb, not the gate. Tested head-on rather than opportunistically:
## whether the walkthrough happens to wander onto a wrong plate depends on the
## terrain seed, and a safety promise cannot be tested only on lucky seeds.
func _check_wrong_plate_costs_nothing() -> void:
	if _lvl._seq_groups.is_empty():
		return
	var group: Dictionary = _lvl._seq_groups[0]
	var hero: HeroController = _lvl._hero

	# Step the first plate correctly, so there is progress available to lose.
	var first := _next_plate(group)
	if not first.is_empty():
		hero.place_at(Vector2(float(first["at"]), _lvl._ground_y))
		for i in range(6):
			await get_tree().physics_frame
		_ok(bool(first["lit"]), "stepping the due plate must light it")

	# The plate must be wrong AND not already green: re-crossing a plate you
	# have finished with is deliberately free, so stepping one of those proves
	# nothing. (It also silently passed the first version of this test, which
	# is worse than failing it.)
	var wrong := {}
	for p in group["plates"]:
		if int(p["dots"]) != int(group["next"]) and not bool(p["lit"]):
			wrong = p
	if wrong.is_empty():
		hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
		return
	var hearts_before: int = hero.hearts
	var orbs_before: int = _lvl._orbs_taken
	var due: int = int(group["next"])
	hero.place_at(Vector2(float(wrong["at"]), _lvl._ground_y))
	for i in range(6):
		await get_tree().physics_frame

	var lit_count := 0
	for p in group["plates"]:
		if bool(p["lit"]):
			lit_count += 1
	print("  stepped plate %d while %d was due -> next=%d, lit=%d, hearts %d->%d" % [
		int(wrong["dots"]), due, int(group["next"]), lit_count,
		hearts_before, hero.hearts])
	_ok(int(group["next"]) == 1, "a wrong plate must reset the sequence to the start")
	_ok(lit_count == 0, "a wrong plate must relight the whole row")
	_ok(hero.hearts == hearts_before, "a wrong plate must never cost a heart")
	_ok(_lvl._orbs_taken == orbs_before, "a wrong plate must never take back progress")
	_ok(not bool(group["gate"]["open"]), "a wrong plate must not open the gate")

	# Leave the row exactly as the level built it.
	for p in group["plates"]:
		p["lit"] = false
		p["on"] = false
	group["next"] = 1
	hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
	await get_tree().physics_frame


## A shut gate is a wall, and only its opener opens it.
func _check_gate_is_a_wall() -> void:
	if _lvl._gates.is_empty():
		_out.append("the level has no gate to test")
		return
	var gate: Dictionary = _lvl._gates[0]
	_ok(not bool(gate["open"]), "the gate must start shut")

	var hero: HeroController = _lvl._hero
	var wall: float = float(gate["at"]) - 58.0
	hero.place_at(Vector2(wall - 30.0, _lvl._ground_y))
	hero.press_right(true)
	for i in range(45):
		await get_tree().physics_frame
	hero.press_right(false)
	print("  pushed at the shut gate for 0.75 s: stopped at x=%.0f (wall %.0f)" % [
		hero.position.x, wall])
	_ok(hero.position.x <= wall + 2.0,
		"a shut gate let the hero through to x=%.0f" % hero.position.x)
	_ok(not bool(gate["open"]), "pushing at a gate must not open it")

	# If this gate belongs to a pressure plate, the plate must be the key.
	for sw in _lvl._switches:
		if sw["gate"] != gate:
			continue
		hero.place_at(Vector2(float(sw["at"]), float(sw["y"])))
		for i in range(4):
			await get_tree().physics_frame
		_ok(bool(sw["pressed"]), "standing on the plate must press it")
		_ok(bool(gate["open"]), "pressing the plate must open its gate")
		gate["open"] = false
		gate["pressing"] = 0.0
		sw["pressed"] = false

	hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
	await get_tree().physics_frame


## The crate: pushed with the body, ridden to the shelf, gem on top. Driven
## entirely with the buttons plus two honest teleports (standing the tester
## next to the box, not solving anything for it).
func _check_crate_carries() -> void:
	if _lvl._crates.is_empty():
		return
	var crate: Dictionary = _lvl._crates[0]
	var node: Node2D = crate["node"]
	var hero: HeroController = _lvl._hero
	var start_x: float = node.position.x

	hero.place_at(Vector2(start_x - 90.0, _lvl._ground_y))
	hero.press_right(true)
	for i in range(240):                     # four seconds of shoving
		await get_tree().physics_frame
		if node.position.x >= float(crate["right"]) - 60.0:
			break
	hero.press_right(false)
	var moved: float = node.position.x - start_x
	print("  pushed the crate %.0f px (bound %.0f)" % [moved, float(crate["right"])])
	_ok(moved > 150.0, "walking into the crate moved it only %.0f px" % moved)

	# Climb it and jump for the shelf. From the crate's top the shelf is one
	# ordinary jump; that arithmetic is the whole reason the crate exists.
	hero.place_at(Vector2(node.position.x, _lvl._ground_y - 92.0))
	hero.press_right(true)
	for i in range(90):
		await get_tree().physics_frame
		if i % 20 == 0:
			hero.press_jump()
		if hero.grounded and hero.position.y < _lvl._ground_y - 180.0:
			break
	hero.press_right(false)
	var on_shelf: bool = hero.grounded and hero.position.y < _lvl._ground_y - 180.0
	_ok(on_shelf, "could not reach the shelf from the crate top (y=%.0f)" % hero.position.y)

	# The gem hangs over the shelf; walking its length while hopping gets it.
	if on_shelf:
		hero.press_right(true)
		for i in range(70):
			await get_tree().physics_frame
			if i % 24 == 0:
				hero.press_jump()
			if _lvl._gem_found:
				break
		hero.press_right(false)
		print("  rode the crate to the shelf; gem found: %s" % _lvl._gem_found)
		_ok(_lvl._gem_found, "stood on the shelf but the gem was out of reach")

	hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
	await get_tree().physics_frame


# --- the walkthrough ----------------------------------------------------------

func _walk_the_level(level_id: String) -> void:
	var hero: HeroController = _lvl._hero
	# Put everything back where the level left it and let it settle, so the
	# walkthrough starts from a standing hero rather than mid-teleport -- and
	# with full hearts, because the hits taken while measuring a rockfall on
	# purpose belong to the test, not to the child's run.
	hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
	hero.heal_full()
	_lvl._hits_taken = 0
	_lvl._refresh_hearts(hero.hearts)
	for i in range(6):
		await get_tree().physics_frame

	var met_gate := false
	var stuck_at := -1.0
	var stuck_for := 0

	for frame in range(6600):                       # 110 seconds of game time
		if _lvl._finished_level:
			break
		await get_tree().physics_frame
		if frame % 600 == 0:
			print("   t=%5.1fs  x=%6.1f  hearts=%d  orbs=%d/%d  gem=%s" % [
				float(frame) / 60.0, hero.position.x, hero.hearts,
				_lvl._orbs_taken, _lvl._orbs_needed, _lvl._gem_found])

		# The card is modal: while it is up, the only game is answering it.
		if _lvl._card != null and is_instance_valid(_lvl._card):
			await _answer_card()
			continue

		if not met_gate:
			for gate in _lvl._gates:
				if not bool(gate["open"]) and hero.position.x >= float(gate["at"]) - 60.0:
					met_gate = true

		var goal: float = _goal_x(hero.position)
		hero.press_right(goal > hero.position.x + 20.0)
		hero.press_left(goal < hero.position.x - 20.0)

		if hero.grounded:
			if _something_above(hero.position) or _gap_ahead(hero.position) \
					or _plate_to_hop(hero.position, goal) \
					or _crate_to_climb(hero.position, goal):
				hero.press_jump()
			else:
				hero.release_jump()

		if absf(hero.position.x - stuck_at) < 4.0:
			stuck_for += 1
			if stuck_for == 40:
				_lvl._on_interact()
			if stuck_for > 300:
				_out.append("stuck at x=%.0f for five seconds" % hero.position.x)
				break
		else:
			stuck_at = hero.position.x
			stuck_for = 0

	hero.press_right(false)
	hero.press_left(false)
	print("  met a shut gate on the way: %s" % met_gate)
	_ok(_lvl._finished_level, "never reached the chest (got to x=%.0f of %.0f)" % [
		hero.position.x, _lvl._length])
	print("  finished: orbs=%d/%d, gem=%s, hits=%d, hearts=%d" % [
		_lvl._orbs_taken, _lvl._orbs_needed,
		"yes" if _lvl._gem_found else "no", _lvl._hits_taken, hero.hearts])


## Tap one WRONG tile first -- the manners matter as much as the mechanics --
## then the right one.
func _answer_card() -> void:
	var card: PuzzleCard = _lvl._card
	var tiles: Array = card.tiles()
	var correct: int = card.correct_index()
	if not _card_tested and tiles.size() > 1:
		_card_tested = true
		var wrong: int = (correct + 1) % tiles.size()
		_tap(tiles[wrong])
		for i in range(20):
			await get_tree().physics_frame
		_ok(_lvl._card != null and is_instance_valid(_lvl._card),
			"a wrong answer must not close the card")
		_ok(_lvl._hero.hearts == _lvl._hero.max_hearts
			or _lvl._hits_taken > 0,     # hearts lost to hazards are fine
			"a wrong answer must never cost a heart")
	_tap(tiles[correct])
	for i in range(70):
		await get_tree().physics_frame
		if _lvl._card == null or not is_instance_valid(_lvl._card):
			break
	_ok(_lvl._card == null or not is_instance_valid(_lvl._card),
		"the right answer must close the card")


## A pretend finger: the same event a touchscreen sends, delivered to the
## same signal the tile listens on.
func _tap(tile: Button) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = tile.global_position + tile.pivot_offset
	tile.gui_input.emit(ev)


# --- where would a child go? ---------------------------------------------------

func _goal_x(at: Vector2) -> float:
	if not _quest.is_empty():
		if not (_quest["done"] as Callable).call():
			return float(_quest["x"])
		_quest = {}
	for gate in _lvl._gates:
		if bool(gate["open"]):
			continue
		# Not "near the gate" -- AGAINST it. A child holding the right-hand
		# button does not go looking for the key until the door has refused.
		if at.x < float(gate["at"]) - 62.0:
			continue
		for sw in _lvl._switches:
			if sw["gate"] == gate and not bool(sw["pressed"]):
				var sw_ref: Dictionary = sw
				_quest = {"x": float(sw["at"]),
					"done": func(): return bool(sw_ref["pressed"])}
				return float(_quest["x"])
		for group in _lvl._seq_groups:
			if group["gate"] == gate and not bool(group["done"]):
				var plate := _next_plate(group)
				if not plate.is_empty():
					var plate_ref: Dictionary = plate
					_quest = {"x": float(plate["at"]),
						"done": func(): return bool(plate_ref["lit"])}
					return float(_quest["x"])
		for puzzle in _lvl._puzzles:
			if puzzle["gate"] == gate and not bool(puzzle["solved"]):
				var puzzle_ref: Dictionary = puzzle
				_quest = {"x": float(puzzle["at"]),
					"done": func(): return bool(puzzle_ref["solved"])}
				return float(_quest["x"])
	return _lvl._length


func _next_plate(group: Dictionary) -> Dictionary:
	for p in group["plates"]:
		if int(p["dots"]) == int(group["next"]):
			return p
	return {}


# --- when would a child jump? ---------------------------------------------------

func _something_above(at: Vector2) -> bool:
	for orb in _lvl._orbs:
		if bool(orb["taken"]):
			continue
		var p: Vector2 = orb["at"]
		if p.x > at.x - 40.0 and p.x < at.x + 210.0 and p.y < at.y - 120.0:
			return true
	for gem in _lvl._gems:
		if bool(gem["taken"]):
			continue
		var g: Vector2 = gem["at"]
		# Only spring-gems are jumped for from the ground; a shelf-gem is the
		# crate's business and was proven reachable in its own test.
		if g.y > at.y - _lvl.reach() - 140.0 and g.x > at.x - 40.0 and g.x < at.x + 260.0:
			return true
	for sw in _lvl._switches:
		if bool(sw["pressed"]):
			continue
		var on_quest: bool = not _quest.is_empty() \
			and absf(float(sw["at"]) - float(_quest["x"])) < 1.0
		var gate: Dictionary = sw["gate"]
		if not on_quest and (bool(gate["open"]) or at.x < float(gate["at"]) - 120.0):
			continue
		if float(sw["y"]) > at.y - 60.0:
			continue
		if absf(float(sw["at"]) - at.x) < 300.0:
			return true
	return false


## Hop over a plate that is not yet due. This is the sequence puzzle's real
## skill, and the probe has to have it for the same reason the child does.
func _plate_to_hop(at: Vector2, goal: float) -> bool:
	var dir: float = signf(goal - at.x)
	if dir == 0.0:
		return false
	for group in _lvl._seq_groups:
		if bool(group["done"]):
			continue
		for p in group["plates"]:
			if bool(p["lit"]):
				continue
			if int(p["dots"]) == int(group["next"]):
				continue                    # the due plate is for stepping ON
			var ahead: float = (float(p["at"]) - at.x) * dir
			if ahead > 30.0 and ahead < 135.0:
				return true
	return false


## A crate shoved as far as it goes becomes a wall in the path. Climbing over
## it is the answer, and it is one ordinary jump -- but a child, and a probe,
## has to think of it. If this ever stops being one jump, the level is a dead
## end and the walkthrough will say so.
func _crate_to_climb(at: Vector2, goal: float) -> bool:
	var dir: float = signf(goal - at.x)
	if dir == 0.0:
		return false
	for crate in _lvl._crates:
		var node: Node2D = crate["node"]
		if not is_instance_valid(node):
			continue
		var ahead: float = (node.position.x - at.x) * dir
		if ahead > 20.0 and ahead < 110.0 and at.y > _lvl._ground_y - 60.0:
			return true
	return false


func _gap_ahead(at: Vector2) -> bool:
	var here := false
	var ahead := false
	for entry in _lvl._platforms:
		if not bool(entry.get("flat", false)):
			continue
		var r: Rect2 = entry["rect"]
		if at.x >= r.position.x and at.x <= r.position.x + r.size.x:
			here = true
		if at.x + 120.0 >= r.position.x and at.x + 120.0 <= r.position.x + r.size.x:
			ahead = true
	return here and not ahead


# --- the reckoning --------------------------------------------------------------

func _report_result() -> void:
	var r: LevelResult = _lvl.result
	print("  result: goal=%s hidden=%s clean=%s -> %d stars" % [
		r.reached_goal, r.found_hidden, r.clean_run, r.stars()])
	_ok(r.objective_scoring, "an adventure level must score by objectives")
	_ok(r.reached_goal, "opening the chest must set reached_goal")
	_ok(r.stars() >= 1, "finishing a level must always earn at least one star")

	var probe := LevelResult.new("x")
	probe.objective_scoring = true
	probe.reached_goal = true
	_ok(probe.stars() == 1, "finish only = 1 star, got %d" % probe.stars())
	probe.clean_run = true
	_ok(probe.stars() == 2, "finish + no damage = 2 stars, got %d" % probe.stars())
	probe.found_hidden = true
	_ok(probe.stars() == 3, "all three = 3 stars, got %d" % probe.stars())
	probe.quit_early = true
	_ok(probe.stars() == 0, "walking out earns nothing, got %d" % probe.stars())
