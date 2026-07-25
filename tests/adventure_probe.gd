extends Node
## Can a child actually FINISH an adventure level?
##
## Written before anyone plays one, because the whole 54-level rebuild rests
## on this template and "it boots and looks nice" has already been shown, twice
## on this project, to be a different claim from "it can be completed".
##
## The probe walks the level the way a person would: press right, jump when
## something is above you, stand on the plate, press the interact key at the
## chest. It never reaches inside to set a flag that gameplay is supposed to
## set. If a beat is unreachable, this hangs on it and says which one.
##
## Then it checks the things a screenshot cannot:
##   * the terrain has no hole wider than a jump
##   * a shut gate is really a wall
##   * the three stars are three independent questions

var _out: Array[String] = []
var _lvl: Node
## The plate the pretend child has decided to go and stand on, or -1.
##
## Sticky on purpose. The first version recomputed "where would a child go"
## every frame from raw distances, and at the edge of the gate's stop zone the
## answer flipped every step: one pixel left of the line means "go find the
## plate", one pixel right means "the door is fine, walk on". The hero stood
## at the door vibrating between the two answers for fifty seconds. A real
## child does not do that: having turned around to look for the switch, they
## keep looking until they have stood on it.
var _quest_x := -1.0


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


## One physics step with the right-hand button held.
func _step(frames: int = 1, jump: bool = false) -> void:
	for i in range(frames):
		if jump:
			_lvl._hero.press_jump()
		await get_tree().physics_frame


func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	await get_tree().process_frame
	GameManager.current_level_id = "sunny_park_01"
	_lvl = load("res://scenes/adventure/Adventure.tscn").instantiate()
	add_child(_lvl)
	for i in range(4):
		await get_tree().process_frame

	print("\n=== adventure probe ===")
	_report_terrain()
	_check_reachable()
	await _check_gate_is_a_wall()
	await _walk_the_level()
	_report_result()

	for f in _out:
		print("FAIL  %s" % f)
	print("ADVENTURE PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## The ground, measured. A gap the hero physically cannot clear is a level
## that ends in a pit no matter how well the child plays, and it is invisible
## in a screenshot because the camera never gets that far.
func _report_terrain() -> void:
	var flats: Array = []
	for entry in _lvl._platforms:
		if bool(entry.get("flat", false)):
			flats.append(entry["rect"])
	flats.sort_custom(func(a: Rect2, b: Rect2): return a.position.x < b.position.x)
	print("  ground segments = %d over %.0f px" % [flats.size(), _lvl._length])

	# What a single jump actually covers: time in the air times walking speed.
	var air: float = 2.0 * absf(HeroController.JUMP_VELOCITY) / HeroController.GRAVITY
	var reach: float = air * HeroController.MOVE_SPEED
	var widest := 0.0
	for i in range(1, flats.size()):
		var gap: float = flats[i].position.x - (flats[i - 1].position.x + flats[i - 1].size.x)
		widest = maxf(widest, gap)
	print("  widest gap = %.0f px, a jump covers %.0f px" % [widest, reach])
	_ok(widest < reach * 0.65,
		"a %.0f px gap is too wide for a %.0f px jump" % [widest, reach])
	_ok(flats.size() >= 4, "only %d ground segments -- the level is one slab" % flats.size())

	var edges: Array = []
	for r in flats:
		edges.append("%.0f-%.0f" % [r.position.x, r.position.x + r.size.x])
	print("  flat ground: %s" % ", ".join(edges))
	print("  chest at x=%.0f, gate at x=%.0f, plate at x=%.0f" % [
		float(_lvl._chest.get("at", -1.0)),
		float(_lvl._gates[0]["at"]) if _lvl._gates.size() > 0 else -1.0,
		float(_lvl._switches[0]["at"]) if _lvl._switches.size() > 0 else -1.0])
	print("  beats: orbs=%d gems=%d springs=%d switches=%d gates=%d flags=%d chest=%s" % [
		_lvl._orbs.size(), _lvl._gems.size(), _lvl._springs.size(),
		_lvl._switches.size(), _lvl._gates.size(), _lvl._checkpoints.size(),
		"yes" if not _lvl._chest.is_empty() else "NO"])
	var kinds := 0
	for present in [_lvl._orbs.size() > 0, _lvl._gems.size() > 0,
			_lvl._springs.size() > 0, _lvl._switches.size() > 0,
			_lvl._checkpoints.size() > 0, not _lvl._chest.is_empty()]:
		if present:
			kinds += 1
	_ok(kinds >= 3, "a level needs at least three kinds of thing to do, found %d" % kinds)


## Can everything the level asks for actually be got to?
##
## Measured against the jump the hero really has, not against a number that
## looked about right. An orb hanging 30 px above the top of the arc is
## invisible as a bug and infuriating as a game: the child jumps at it over
## and over, and concludes they are bad at jumping.
func _check_reachable() -> void:
	var ceiling: float = _lvl.reach()
	var stranded: Array = []
	for orb in _lvl._orbs:
		var p: Vector2 = orb["at"]
		if not _standable_under(p, ceiling):
			stranded.append("orb at (%.0f, %.0f)" % [p.x, p.y])
	for gem in _lvl._gems:
		var g: Vector2 = gem["at"]
		# A gem is allowed to need the spring, which throws far higher.
		var spring_reach: float = 1000.0 * 1000.0 / (2.0 * HeroController.GRAVITY)
		if not _standable_under(g, maxf(ceiling, spring_reach)):
			stranded.append("gem at (%.0f, %.0f)" % [g.x, g.y])
	for sw in _lvl._switches:
		if not _standable_under(Vector2(float(sw["at"]), float(sw["y"]) - 10.0), ceiling):
			stranded.append("plate at x=%.0f" % float(sw["at"]))
	for s in stranded:
		_out.append("out of reach: %s" % s)
	print("  reach = %.0f px up; %d of %d placed things out of reach" % [
		ceiling, stranded.size(), _lvl._orbs.size() + _lvl._gems.size()
		+ _lvl._switches.size()])


## Is there somewhere to stand within jumping distance below this point?
func _standable_under(at: Vector2, ceiling: float) -> bool:
	for entry in _lvl._platforms:
		var r: Rect2 = entry["rect"]
		if at.x < r.position.x - 150.0 or at.x > r.position.x + r.size.x + 150.0:
			continue
		var rise: float = r.position.y - at.y
		if rise >= -20.0 and rise <= ceiling + 90.0:
			return true
	return false


## Is a shut gate a wall?
##
## Tested directly rather than by hoping the walkthrough happens to arrive at
## it while it is still closed. The route a player takes is a design question
## and it changes every time the terrain seed does; whether the door holds is
## a mechanical one, and it must never change.
func _check_gate_is_a_wall() -> void:
	if _lvl._gates.is_empty():
		_out.append("the level has no gate to test")
		return
	var gate: Dictionary = _lvl._gates[0]
	_ok(not bool(gate["open"]), "the gate must start shut")
	for sw in _lvl._switches:
		_ok(not bool(sw["pressed"]), "the plate must start unpressed")

	var hero: HeroController = _lvl._hero
	var wall: float = float(gate["at"]) - 58.0
	hero.place_at(Vector2(wall - 30.0, _lvl._ground_y))
	hero.press_right(true)
	for i in range(45):
		await get_tree().physics_frame
	hero.press_right(false)
	var got_to: float = hero.position.x
	print("  pushed at the shut gate for 0.75 s: stopped at x=%.0f (wall %.0f)" % [
		got_to, wall])
	_ok(got_to <= wall + 2.0, "a shut gate let the hero through to x=%.0f" % got_to)
	_ok(not bool(gate["open"]), "pushing at a gate must not open it")

	# And the plate must be what opens it.
	var sw0: Dictionary = _lvl._switches[0]
	hero.place_at(Vector2(float(sw0["at"]), float(sw0["y"])))
	for i in range(4):
		await get_tree().physics_frame
	_ok(bool(sw0["pressed"]), "standing on the plate must press it")
	_ok(bool(gate["open"]), "pressing the plate must open its gate")

	# Put everything back so the walkthrough starts from a clean level.
	gate["open"] = false
	gate["pressing"] = 0.0
	sw0["pressed"] = false
	hero.place_at(Vector2(_lvl.SPAWN_X, _lvl._ground_y))
	await get_tree().physics_frame


## Walk right until the chest opens, jumping whenever something worth having
## is overhead. Deliberately dumb: if a beat needs cleverness a six-year-old
## does not have, this never finishes and the timeout says so.
func _walk_the_level() -> void:
	var hero: HeroController = _lvl._hero
	_ok(absf(hero.position.y - _lvl._ground_y) < 2.0,
		"the hero starts %0.1f px off the ground" % absf(hero.position.y - _lvl._ground_y))

	var gate_tested := false
	var stuck_at := -1.0
	var stuck_for := 0

	for frame in range(3600):                       # a minute of game time
		if _lvl._finished_level:
			break
		await get_tree().physics_frame
		if frame % 300 == 0:
			print("   t=%4.1fs  x=%6.1f  y=%6.1f  ground=%s  orbs=%d  goal=%.0f gate=%s plate=%s" % [
				float(frame) / 60.0, hero.position.x, hero.position.y,
				hero.grounded, _lvl._orbs_taken, _goal_x(hero.position),
				"open" if _lvl._gates.is_empty() or bool(_lvl._gates[0]["open"]) else "shut",
				"on" if _lvl._switches.is_empty() or bool(_lvl._switches[0]["pressed"]) else "off"])

		# A shut gate must actually stop us. Note it the first time it does.
		if not gate_tested:
			for gate in _lvl._gates:
				if not bool(gate["open"]) and hero.position.x >= float(gate["at"]) - 60.0:
					gate_tested = true
					print("  a shut gate stopped the hero at x=%.0f" % hero.position.x)

		# Where a child would be heading. Normally right; but standing at a
		# shut gate, back up towards whatever plate belongs to it. Doing this
		# through the same two buttons the child has is the point -- a probe
		# that teleports proves nothing about whether the level is solvable.
		var goal: float = _goal_x(hero.position)
		hero.press_right(goal > hero.position.x + 20.0)
		hero.press_left(goal < hero.position.x - 20.0)

		# Jump for anything above head height, and for the far side of a gap.
		if hero.grounded:
			if _something_above(hero.position) or _gap_ahead(hero.position):
				hero.press_jump()
			else:
				hero.release_jump()

		# Standing still for a second means a beat is blocking the way. Try
		# the interact key -- that is what a child would do.
		if absf(hero.position.x - stuck_at) < 4.0:
			stuck_for += 1
			if stuck_for == 40:
				_lvl._on_interact()
			if stuck_for > 240:
				_out.append("stuck at x=%.0f for four seconds" % hero.position.x)
				break
		else:
			stuck_at = hero.position.x
			stuck_for = 0

	hero.press_right(false)
	hero.press_left(false)
	# Not a failure. Whether a child finds the plate before or after the door
	# depends on which way they wandered, and the terrain seed moves it about;
	# that the door actually HOLDS is checked properly, on its own, above.
	print("  met the gate while it was still shut: %s" % gate_tested)
	_ok(_lvl._finished_level, "never reached the chest (got to x=%.0f of %.0f)" % [
		hero.position.x, _lvl._length])
	print("  finished at x=%.0f, orbs=%d/%d, gem=%s, hits=%d" % [
		hero.position.x, _lvl._orbs_taken, _lvl._orbs_needed,
		"yes" if _lvl._gem_found else "no", _lvl._hits_taken])


## Where to walk next. Right, unless a shut gate is in the way and its plate
## is somewhere else -- then towards the plate, which is the whole point of
## the beat.
func _goal_x(at: Vector2) -> float:
	# Mid-quest: keep going to the plate until it has actually been pressed.
	if _quest_x >= 0.0:
		for sw in _lvl._switches:
			if not bool(sw["pressed"]) and absf(float(sw["at"]) - _quest_x) < 1.0:
				return _quest_x
		_quest_x = -1.0
	for gate in _lvl._gates:
		if bool(gate["open"]):
			continue
		# Not "near the gate" -- AGAINST it. A child holding the right-hand
		# button does not go looking for the plate until the door has actually
		# refused to let them through.
		if at.x < float(gate["at"]) - 62.0:
			continue
		for sw in _lvl._switches:
			if sw["gate"] == gate and not bool(sw["pressed"]):
				_quest_x = float(sw["at"])
				return _quest_x
	return _lvl._length


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
		if g.x > at.x - 40.0 and g.x < at.x + 260.0:
			return true
	# A plate up on a ledge: this is the "look around and find it" beat. Only
	# climb for it AFTER meeting the gate, because that is the order a child
	# holding the right-hand button experiences it in -- and if the probe
	# jumps early it opens the gate before ever being stopped by it, which is
	# how a broken puzzle passes its own test.
	for sw in _lvl._switches:
		if bool(sw["pressed"]):
			continue
		# On the way to THIS plate, always jump for it; otherwise only once
		# the gate has been met, which is the order a walking child meets them.
		var on_quest: bool = _quest_x >= 0.0 and absf(float(sw["at"]) - _quest_x) < 1.0
		var gate: Dictionary = sw["gate"]
		if not on_quest and (bool(gate["open"]) or at.x < float(gate["at"]) - 120.0):
			continue
		if float(sw["y"]) > at.y - 60.0:
			continue
		if absf(float(sw["at"]) - at.x) < 300.0:
			return true
	return false


## Is the ground about to run out? Looks one hero-width ahead, which is all
## the warning a running child gets too.
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


## The three stars have to be three separate questions, or the result screen
## is lying about what is left to find.
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
