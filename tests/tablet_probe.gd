extends Node
## Does the game use the whole iPad, or the top three quarters of it?
##
## The island is drawn against 1280x720 and stretches with aspect="expand",
## which does not scale the extra space away -- it HANDS IT OVER. A 4:3 tablet
## gives the game a 1280x960 viewport. Every number written against 720 then
## points 240 pixels too high, and the result is a game that runs, responds,
## passes every other probe in this folder, and looks on the child's actual
## device like it is stuck to the ceiling with a quarter of the screen empty
## underneath it.
##
## This project has shipped that bug twice. Nobody reported either one: a game
## that is merely UGLY on a tablet still works, so it never comes back as a bug
## report -- it comes back as a six-year-old reaching for a button that is not
## under his thumb any more.
##
##
## WHAT IS ASSERTED
##
## Each screen names the things that MUST follow the screen -- the ground the
## hero stands on, the bins he drops into, the pads he taps -- and each is
## checked twice, once on 1280x720 and once on the iPad's 1024x768 window.
##
##   1  the same fraction of the screen        an anchor two thirds of the way
##      down at 720 is two thirds of the way down at 960, not 46% of the way
##      down because the pixels stopped counting
##
##   2  the dead band does not grow            the gap between the lowest thing
##      on the screen and the bottom edge, as a fraction, is the bug itself:
##      at 720 the duel's was 3%, at 960 it was 27%
##
## Rule 2 is the one that matters. It is written so that a screen CANNOT pass
## it by being uniformly broken -- a layout that ignores the extra height
## always grows its own dead band, whatever else it does.
##
## Thumb chrome (the skill pad) is the deliberate exception: it keeps a fixed
## GAP to the corner rather than a fraction, because a thumb rests where the
## bezel is and the bezel does not move proportionally. Those are asserted in
## pixels, and asserted separately, so the exception has to be argued for by
## name rather than being a hole anything can fall through.

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]

## screen -> how much of the bottom may be empty, as a fraction of the height.
## Read off the 1280x720 rendering the father has actually looked at, plus a
## few points of room. These are a coarse net -- some templates legitimately
## keep their play field high and their grass in front of it. The assertion
## that does the real work is _compare(), which demands the SAME reading on
## both screens and cannot be satisfied by a layout that ignores the extra
## height.
##
## `holds` names the member that keeps the things the child touches, for the
## three templates whose targets are drawn shapes rather than buttons -- they
## are tapped by position inside one full-screen catcher, so there is nothing
## for a generic sweep to find. A missing member is a FAILURE, not a skip: a
## renamed variable must break this probe loudly rather than quietly turning
## its screen off.
##
## `tops` names things that must follow the screen but are NOT the lowest thing
## on it -- the machine a child builds sits above the tray he takes parts from,
## so pinning the machine back to design coordinates left the tray correct, the
## dead band correct, and only the DISTANCE between them wrong: a drag twice as
## long as it was drawn. Found by sabotage; the lowest-thing sweep is blind to
## it by construction.
##
## `stands` names characters who are on the ground rather than in the hand. The
## duel's hero is not a button and not a target, so the sweep above cannot see
## him: with the skill pad correctly in the corner, the whole screen passed
## while the hero floated a hundred and fifty pixels above the grass. That is
## precisely what this file exists to catch, and it took a deliberate sabotage
## round to find out it did not.
##
## `pads` names the array of thumb buttons on a screen that has no pad panel
## under them. They are chrome against the bottom edge, so they are checked in
## PIXELS: each one within a thumb's width of the bottom, inside the right
## edge, and the same gap on both shapes.
##
## `walks` marks the bridge: the friend's walk across it is asked for by name
## (`cross_path()`) and must land ON the planks. It did not, once: the slots
## followed the screen and the walk kept its design coordinates, so on a
## tablet he strolled 240 px above the bridge the child had just built. The
## lowest-thing sweep cannot see a walk that has not happened yet.
##
## `key` is a name for a screen that has no level id -- the platformer has no
## level in data/levels.json and runs on its own debug data.
const SCREENS := [
	{"id": "sunny_park_06", "scene": "res://scenes/minigames/monster_duel/MonsterDuel.tscn",
		"dead": 0.14, "stands": ["_hero", "_monster"],
		"pad": "_skill_pad", "on_pad": ["_ult_button", "_shield_button", "_beam_button"]},
	{"id": "sunny_park_03", "scene": "res://scenes/minigames/build_repair/BuildRepair.tscn",
		"dead": 0.20, "tops": ["_slot_nodes"], "walks": true},
	{"id": "night_city_03", "scene": "res://scenes/minigames/roleplay_rescue/RoleplayRescue.tscn",
		"dead": 0.26, "holds": "_tools", "stands": ["_patient"]},
	{"id": "", "key": "platformer", "scene": "res://scenes/minigames/platformer/Platformer.tscn",
		"dead": 0.05, "pads": "_pads"},
	{"id": "sunny_park_02", "scene": "res://scenes/minigames/matching_sorting/MatchingSorting.tscn",
		"dead": 0.28},
	{"id": "sunny_park_04", "scene": "res://scenes/minigames/memory_rhythm/MemoryRhythm.tscn",
		"dead": 0.44, "holds": "_pads"},
	{"id": "sunny_park_01", "scene": "res://scenes/minigames/observation_search/ObservationSearch.tscn",
		"dead": 0.20, "holds": "_targets"},
	{"id": "night_city_02", "scene": "res://scenes/minigames/puzzle_mechanism/PuzzleMechanism.tscn",
		"dead": 0.50, "holds": "_pieces"},
	{"id": "bonus_echo", "scene": "res://scenes/minigames/light_echo/LightEcho.tscn",
		"dead": 0.30, "stands": ["_hero"], "holds": "_pads"},
	{"id": "bonus_blaster", "scene": "res://scenes/minigames/light_defense/LightDefense.tscn",
		"dead": 0.0, "no_floor": true, "stands": ["_hero"]},
]

var _failures: Array[String] = []
var _shape := ""
var _view := Vector2.ZERO


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


func _ready() -> void:
	print("\n=== tablet probe ===")
	# fraction-of-the-screen readings, per screen, per shape: id -> [f720, f960]
	var seen: Dictionary = {}

	for shape in SHAPES:
		_shape = "%dx%d" % [shape.x, shape.y]
		get_window().size = shape
		await get_tree().process_frame
		await get_tree().process_frame
		_view = get_viewport().get_visible_rect().size
		print("-- window %s -> viewport %s" % [str(shape), str(_view)])

		# The viewport must actually be the shape this probe thinks it is, or
		# every assertion below is being made twice about the same screen and
		# the whole file is decoration.
		if shape == Vector2i(1024, 768):
			_ok(is_equal_approx(_view.y, 960.0),
				"a 1024x768 window did not produce the 1280x960 viewport a "
				+ "tablet gets (got %s) -- nothing here tested anything" % str(_view))

		for screen in SCREENS:
			await _measure(screen, seen)
		await _the_thumb_controls_hug_the_corner(seen)
		await _the_world_reaches_the_bottom(seen)
		await _the_map_fills_the_screen(seen)
		await _the_lesson_keeps_its_footing(seen)

	_compare(seen)

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("TABLET PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


# --- the measurement ---------------------------------------------------------

## Open a level, find the lowest thing in it that the child interacts with, and
## record how far above the bottom of the screen that is.
func _measure(screen: Dictionary, seen: Dictionary) -> void:
	GameManager.current_level_id = str(screen["id"])
	var packed: PackedScene = load(str(screen["scene"]))
	if packed == null:
		_ok(false, "%s will not load" % screen["scene"])
		return
	var node: Node = packed.instantiate()
	add_child(node)
	# Long enough for the entrances to land. Six frames was not: the duel's hero
	# walks in over the first fraction of a second, so he was being measured in
	# mid-stride and read 47% of the way down the screen on one run and 52% on
	# the next. A flaky assertion is worse than none -- it teaches whoever sees
	# it next that a red probe means nothing.
	await get_tree().create_timer(1.2).timeout
	await get_tree().process_frame

	var low := _lowest(node)
	var key := str(screen.get("key", screen["id"]))

	# The three templates whose targets are drawn shapes: ask the level itself
	# where they are. If the member is gone, say so -- an assertion that has
	# quietly stopped looking at anything is worse than no assertion.
	if screen.has("holds"):
		var held = node.get(str(screen["holds"]))
		if held == null or not (held is Array) or (held as Array).is_empty():
			_ok(false, "%s: %s is empty or gone -- this probe has stopped "
				% [key, str(screen["holds"])] + "watching this screen")
		else:
			for entry in (held as Array):
				var art = entry.get("node") if entry is Dictionary else entry
				if art is Node2D and is_instance_valid(art):
					low = maxf(low, (art as Node2D).global_position.y)
	# Whoever is standing on the ground in this level, recorded by name. Checked
	# as a fraction of the screen in _compare(), which is the only reading that
	# notices a character left behind by a ground line that moved.
	for who in screen.get("stands", []):
		var actor = node.get(str(who))
		if actor == null or not (actor is Node2D) or not is_instance_valid(actor):
			_ok(false, "%s: %s is gone -- this probe has stopped watching who "
				% [key, str(who)] + "is standing on the ground")
		else:
			var at: float = (actor as Node2D).global_position.y
			print("   %-15s %s at %4d of %4d" % [key, str(who), int(at), int(_view.y)])
			_remember(seen, "%s:%s" % [key, str(who)], at / _view.y)

	# Things above the lowest one that still have to move with the screen.
	for member in screen.get("tops", []):
		var group = node.get(str(member))
		if group == null or not (group is Array) or (group as Array).is_empty():
			_ok(false, "%s: %s is empty or gone -- this probe has stopped "
				% [key, str(member)] + "watching the top of this screen")
			continue
		var top := INF
		for entry in (group as Array):
			var art = entry.get("node") if entry is Dictionary else entry
			if art is Node2D and is_instance_valid(art):
				top = minf(top, (art as Node2D).global_position.y)
		if top < INF:
			print("   %-15s %s top %4d of %4d" % [key, str(member), int(top), int(_view.y)])
			_remember(seen, "%s:%s top" % [key, str(member)], top / _view.y)

	if screen.has("pad"):
		_the_buttons_sit_on_their_pad(node, str(screen["pad"]),
			screen.get("on_pad", []), key)
	if screen.has("pads"):
		_the_pads_hug_the_bottom(node, str(screen["pads"]), key, seen)
	if bool(screen.get("walks", false)):
		_the_friend_walks_on_the_bridge(node, key)

	if low <= 0.0:
		_ok(false, "%s: found nothing placed on the screen at all -- either the "
			% key + "level is empty or this probe is measuring the wrong thing")
	elif bool(screen.get("no_floor", false)):
		# A screen whose TARGET is the screen. light_defense is aimed by
		# tapping anywhere at all, so the only placed controls on it are the
		# back button and the top-left HUD, and both of those are chrome that
		# correctly keeps its distance from the TOP. The lowest-thing rule
		# then measures a badge at y=120 and reports 83% of the screen empty
		# on every shape, which is true and means nothing.
		#
		# Named rather than given a loose threshold: "this rule does not
		# describe this screen" is a different statement from "this screen is
		# allowed to be 95% empty", and only one of them stays honest when
		# somebody later puts a real control down there.
		print("   %-15s lowest %4d of %4d -- floor rule not applied (no_floor)"
			% [key, int(low), int(_view.y)])
	else:
		var dead: float = (_view.y - low) / _view.y
		print("   %-15s lowest %4d of %4d, %4.1f%% of the screen below it"
			% [key, int(low), int(_view.y), dead * 100.0])
		_ok(dead <= float(screen["dead"]),
			"%s leaves %.0f%% of the bottom of the screen empty (allowed %.0f%%)"
			% [key, dead * 100.0, float(screen["dead"]) * 100.0])
		_remember(seen, key, low / _view.y)

	node.queue_free()
	await get_tree().process_frame


## The lowest y anything the child can touch sits at.
##
## Deliberately NOT "the lowest node": scenery, ground planes and full-screen
## backgrounds all reach the bottom by construction and would make every screen
## pass. Only three things count, and all three are things a hand goes to:
##
##   a drag field's items and slots      what he picks up and where it goes
##   a BaseButton                        what he presses
##   a Control that catches input        the skill pads, drawn as panels
##
## A screen with none of these returns 0 and is reported as unmeasurable rather
## than quietly passing.
func _lowest(root: Node) -> float:
	var low := 0.0
	for child in _every_node(root):
		if child is Control and child.has_method("items") and child.has_method("slots"):
			for entry in (child.items() + child.slots()):
				var at: Node2D = entry.get("node")
				if at != null and is_instance_valid(at):
					low = maxf(low, at.global_position.y)
			continue
		if child is BaseButton and (child as Control).visible:
			low = maxf(low, (child as Control).get_global_rect().end.y)
			continue
		if child is Control and (child as Control).visible \
				and (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			var rect: Rect2 = (child as Control).get_global_rect()
			# A full-screen catcher is the play area itself, not a target.
			if rect.size.x < _view.x * 0.9 or rect.size.y < _view.y * 0.9:
				low = maxf(low, rect.end.y)
			continue
		if child is Node2D and child.has_meta("touchable"):
			low = maxf(low, (child as Node2D).global_position.y)
	return low


## Chrome that keeps a fixed gap to a corner is measured in pixels, not
## fractions, so the whole-screen readings above cannot see one piece of it
## drifting away from the others: moving a single skill button back to design
## coordinates left the other two correct, the dead band unchanged, and the
## probe green -- with a button sitting off its own pad in the middle of the
## grass. So the pad and the buttons are checked against EACH OTHER. They move
## together or the assertion goes red.
func _the_buttons_sit_on_their_pad(node: Node, pad_name: String,
		button_names: Array, key: String) -> void:
	var pad = node.get(pad_name)
	if pad == null or not (pad is Control):
		_ok(false, "%s: %s is gone -- the thumb corner is no longer watched"
			% [key, pad_name])
		return
	var area: Rect2 = (pad as Control).get_global_rect().grow(28.0)
	for button_name in button_names:
		var button = node.get(str(button_name))
		if button == null or not (button is Control):
			_ok(false, "%s: %s is gone" % [key, str(button_name)])
			continue
		var centre: Vector2 = (button as Control).get_global_rect().get_center()
		_ok(area.has_point(centre),
			"%s: %s has come off the skill pad (button at %s, pad %s) -- one of "
			% [key, str(button_name), str(centre.round()), str(area)]
			+ "the two stopped following the corner of the screen")


## Thumb buttons with no pad under them, checked in pixels against the bottom
## and right edges. A pad written at y=584 is 12 px off the bottom of a 720
## screen and 252 px off the bottom of a 960 one; the gap is remembered and
## _compare() demands the same number on both shapes.
func _the_pads_hug_the_bottom(node: Node, member: String, key: String,
		seen: Dictionary) -> void:
	var pads = node.get(member)
	if pads == null or not (pads is Array) or (pads as Array).is_empty():
		_ok(false, "%s: %s is empty or gone -- the thumb pads are no longer watched"
			% [key, member])
		return
	var i := 0
	for pad in (pads as Array):
		if not (pad is Control) or not is_instance_valid(pad):
			continue
		var rect: Rect2 = (pad as Control).get_global_rect()
		var gap: float = _view.y - rect.end.y
		print("   %-15s pad %d ends %4d px above the bottom, right edge at %4d of %4d"
			% [key, i, int(gap), int(rect.end.x), int(_view.x)])
		_ok(gap >= 0.0 and gap <= 40.0,
			"%s: pad %d sits %d px above the bottom edge of a %d-tall screen -- "
			% [key, i, int(gap), int(_view.y)] + "it has floated away from the thumb")
		_ok(rect.end.x <= _view.x + 0.5,
			"%s: pad %d pokes %d px past the right edge of the screen"
			% [key, i, int(rect.end.x - _view.x)])
		_remember(seen, "%s pad %d gap" % [key, i], gap)
		i += 1


## The friend's walk across the finished bridge has to be ON the bridge: both
## ends inside the screen, and the far end standing just above the planks,
## not a quarter of a screen over their heads.
func _the_friend_walks_on_the_bridge(node: Node, key: String) -> void:
	if not node.has_method("cross_path"):
		_ok(false, "%s: cross_path() is gone -- the walk across the bridge is "
			% key + "no longer watched")
		return
	var path: PackedVector2Array = node.cross_path()
	var slots = node.get("_slot_nodes")
	var deck := 0.0
	if slots is Array:
		for ghost in (slots as Array):
			if ghost is Node2D and is_instance_valid(ghost):
				deck = maxf(deck, (ghost as Node2D).global_position.y)
	if path.size() < 2 or deck <= 0.0:
		_ok(false, "%s: the bridge has no planks or the walk has no ends" % key)
		return
	var far_side: Vector2 = path[path.size() - 1]
	var above: float = deck - far_side.y
	print("   %-15s friend walks to y=%4d, the planks are at y=%4d (%d px above them)"
		% [key, int(far_side.y), int(deck), int(above)])
	var screen := Rect2(Vector2.ZERO, _view)
	for point in path:
		_ok(screen.has_point(point),
			"%s: the friend's walk goes through %s, which is off a %s screen"
			% [key, str(point.round()), str(_view)])
	_ok(above >= 0.0 and above <= 120.0,
		"%s: the friend ends his walk %d px above the planks (y=%d, planks y=%d) "
		% [key, int(above), int(far_side.y), int(deck)]
		+ "-- the walk did not follow the bridge down the screen")


## The adventure's hands, built on their own: the skill bar with its stick and
## its two skills, exactly as adventure.gd builds them. Everything on it is
## chrome against the bottom-right corner, so it is all measured in PIXELS:
##
##   the stick's zone ends AT the bottom edge -- a zone that stops at 720 on a
##   960-tall screen leaves a dead band a thumb lands in and nothing happens
##
##   jump and attack sit within a thumb's width of the bottom, every button
##   is inside the right edge, and every gap is the same on both shapes
func _the_thumb_controls_hug_the_corner(seen: Dictionary) -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	await get_tree().process_frame
	var bar: Control = load("res://scripts/ui/skill_bar.gd").new()
	host.add_child(bar)
	bar.add_skill("shield", Color(0.55, 0.85, 1.0), 6.0)
	bar.add_skill("lightning", Color(1.0, 0.86, 0.40), 4.0)
	await get_tree().process_frame

	var stick = bar.get("_stick")
	if stick == null or not stick.has_method("area"):
		_ok(false, "the skill bar has no stick with an area() -- the thumb zone "
			+ "is no longer watched")
	else:
		var zone: Rect2 = stick.area()
		print("   %-15s zone y %4d..%4d of %4d" % ["thumb stick", int(zone.position.y),
			int(zone.end.y), int(_view.y)])
		_ok(is_equal_approx(zone.end.y, _view.y),
			"the thumb stick's zone ends at y=%d on a %d-tall screen -- the bottom "
			% [int(zone.end.y), int(_view.y)]
			+ "%d px are dead under a thumb" % int(_view.y - zone.end.y))
		_ok(zone.position.x <= 0.0 and zone.size.y >= 300.0,
			"the thumb stick's zone %s is not a big bottom-left corner any more"
			% str(zone))
		_remember(seen, "thumb stick top gap", _view.y - zone.position.y)

	var named := {"jump": "_jump_button", "attack": "_attack_button"}
	for what in named.keys():
		var button = bar.get(str(named[what]))
		if button == null or not (button is Control):
			_ok(false, "the skill bar's %s button is gone" % what)
			continue
		var rect: Rect2 = (button as Control).get_global_rect()
		var gap: float = _view.y - rect.end.y
		print("   %-15s %s ends %4d px above the bottom, right edge %4d of %4d"
			% ["skill bar", what, int(gap), int(rect.end.x), int(_view.x)])
		# 42 px at design size: the pad sits a thumb's rest above the bezel.
		_ok(gap >= 0.0 and gap <= 48.0,
			"the %s button sits %d px above the bottom of a %d-tall screen -- it "
			% [what, int(gap), int(_view.y)] + "has floated off the thumb")
		_ok(rect.end.x <= _view.x + 0.5,
			"the %s button pokes %d px past the right edge" % [what, int(rect.end.x - _view.x)])
		_remember(seen, "skill bar %s gap" % what, gap)

	var skills = bar.get("_skill_buttons")
	if skills == null or not (skills is Array) or (skills as Array).size() < 2:
		_ok(false, "the skill bar did not build its two skill buttons")
	else:
		var slot := 0
		for entry in (skills as Array):
			var button: Control = entry["button"]
			var rect: Rect2 = button.get_global_rect()
			print("   %-15s skill %d ends %4d px above the bottom, right edge %4d of %4d"
				% ["skill bar", slot, int(_view.y - rect.end.y), int(rect.end.x), int(_view.x)])
			_ok(rect.end.x <= _view.x + 0.5 and rect.end.y <= _view.y + 0.5,
				"skill %d ends at %s, past the edge of a %s screen"
				% [slot, str(rect.end.round()), str(_view)])
			_remember(seen, "skill bar skill %d gap" % slot, _view.y - rect.end.y)
			slot += 1

	host.queue_free()
	await get_tree().process_frame


func _every_node(root: Node) -> Array:
	var out: Array = [root]
	var i := 0
	while i < out.size():
		for child in (out[i] as Node).get_children():
			out.append(child)
		i += 1
	return out


# --- the three that are checked by name --------------------------------------

## The ground the whole island stands on. Every actor in every template is
## placed on Stage.ground_y(), so if this one number stops following the screen
## then eleven levels' worth of characters float and no other assertion here
## would have to notice.
func _the_world_reaches_the_bottom(seen: Dictionary) -> void:
	var style := WorldStyle.for_world("sunny_park")
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	await get_tree().process_frame
	var stage := Stage.build(host, style, "tablet-probe")
	await get_tree().process_frame

	var ground: float = stage.ground_y()
	print("   %-15s ground %4d of %4d" % ["stage", int(ground), int(_view.y)])
	# Recorded as a fraction and compared across the two shapes. A bare
	# threshold is not enough and was proved not to be: with the stage pinned
	# back to a fixed 720 the ground came out at 619 on a 960-tall screen, which
	# is still past any sane floor, and the sabotage round passed.
	_remember(seen, "stage ground", ground / _view.y)
	_ok(ground > _view.y * 0.6,
		"the ground line is at %d on a %d-tall screen -- the world is drawn "
		% [int(ground), int(_view.y)]
		+ "into the top of the tablet and everything standing on it floats")
	host.queue_free()
	await get_tree().process_frame


## The island the child picks a level from. The markers are the level buttons,
## so a map that keeps them in the top three quarters is a map with a quarter
## of itself wasted -- and it is the first screen he sees.
func _the_map_fills_the_screen(seen: Dictionary) -> void:
	var map: Node = load("res://scenes/map/WorldMap.tscn").instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame

	var low := 0.0
	for child in _every_node(map):
		if child is BaseButton and (child as Control).visible:
			var rect: Rect2 = (child as Control).get_global_rect()
			# The page arrows are pinned to the middle by design; the level
			# markers are what has to spread out.
			if rect.size.x < 260.0 and rect.size.y < 260.0:
				low = maxf(low, rect.end.y)
	_ok(low > 0.0, "the map has no level markers at all")
	if low > 0.0:
		var dead: float = (_view.y - low) / _view.y
		print("   %-15s lowest marker %4d of %4d, %4.1f%% below"
			% ["world map", int(low), int(_view.y), dead * 100.0])
		_ok(dead <= 0.26,
			"the map leaves %.0f%% of the screen empty under the last level"
			% (dead * 100.0))
		_remember(seen, "world map", low / _view.y)

	map.queue_free()
	await get_tree().process_frame


## The lesson card. Its caption and its two buttons are chrome against the
## bottom edge, so this one is checked in PIXELS: the gap to the bottom must be
## the same on both screens, not the same fraction.
func _the_lesson_keeps_its_footing(seen: Dictionary) -> void:
	var lesson: Node = load("res://scenes/ui/MiniLesson.tscn").instantiate()
	add_child(lesson)
	for i in range(6):
		await get_tree().process_frame

	var caption: Node = lesson.get("_caption")
	if caption == null:
		_ok(false, "the lesson has no caption -- probe is out of date")
	else:
		var gap: float = _view.y - (caption as Control).position.y
		print("   %-15s caption %4d px above the bottom" % ["lesson", int(gap)])
		_remember(seen, "lesson caption gap", gap)

	lesson.queue_free()
	await get_tree().process_frame


# --- comparing the two shapes ------------------------------------------------

func _remember(seen: Dictionary, key: String, value: float) -> void:
	if not seen.has(key):
		seen[key] = []
	(seen[key] as Array).append(value)


## The heart of it: the same reading, taken on both screens, has to agree.
##
## Fractions for everything that lives in the world, so a hero two thirds of the
## way down stays two thirds of the way down. Pixels for the one reading that is
## chrome, so a caption sixty pixels off the bottom stays sixty pixels off the
## bottom. A screen that ignores the extra height fails whichever of the two it
## is measured by, which is the point.
func _compare(seen: Dictionary) -> void:
	_shape = "both"
	for key in seen.keys():
		var readings: Array = seen[key]
		if readings.size() < 2:
			_ok(false, "%s was only measured on one screen shape" % key)
			continue
		var a: float = readings[0]
		var b: float = readings[1]
		if key.ends_with("gap"):
			_ok(absf(a - b) <= 2.0,
				"%s is %d px on 720 and %d px on 960 -- chrome against an edge "
				% [key, int(a), int(b)] + "should keep its gap to that edge")
		else:
			_ok(absf(a - b) <= 0.03,
				"%s sits %.0f%% down the screen on 720 but %.0f%% down on 960"
				% [key, a * 100.0, b * 100.0])
