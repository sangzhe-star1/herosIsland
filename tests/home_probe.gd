extends Node
## Does the home screen fit on the screen, and is any of it still reachable?
##
##
## WHY THIS EXISTS
##
## The home screen shipped broken and nothing said so. Adding the garden as a
## fifth big button turned a 2x2 grid into 2x3 and the grid grew past both
## edges: at 1280x720 the greeting was clipped at the top, the parent button
## was sliced in half at the bottom, and the hold hint and its progress bar --
## the only way an adult gets into the parent centre -- were off the bottom of
## the screen entirely.
##
## Three layers of checking were blind to it at once:
##
##   * the smoke test BOOTS this scene and asserts it does not fault. It did
##     not fault. A screen whose furniture is off the edge runs perfectly.
##   * tablet_probe.gd measures exactly this, and its SCREENS list has never
##     contained a shell screen -- only levels.
##   * tests/farm_shot.gd has had a `home` mode since 阶段4, and nobody had run
##     it since the fifth button landed.
##
## So this file is the layer that was missing, and it asks the questions the
## other three could not:
##
##   1  everything is ON the screen           the bug itself, on both shapes
##   2  nothing sits on top of anything else  the version before this one had
##                                            the parent door under the hero's
##                                            boots on one shape only
##   3  a six-year-old can hit it             every target at least 60x60
##   4  the layout has ONE rhythm             equal gaps, equal margins, and
##                                            the greeting and the treasure
##                                            chip aligned to the card block
##   5  the hero stands on the ground         he floated 11px above his own
##                                            grass for one round, which looks
##                                            like nothing and reads as wrong
##   6  the dead band does not grow           tablet_probe's rule 2, which is
##                                            the one a layout cannot pass by
##                                            being uniformly broken
##   7  the world is still pokeable           the scenery answers taps, and a
##                                            card block that covered every
##                                            reachable prop would leave that
##                                            feature silently dead
##   8  one press is one press                touch emulation delivers a click
##                                            twice; UiKit.is_press is what
##                                            keeps it at one
##   9  the parent door is not a one-tap door a child who taps it gets nowhere
##  10  reduce-motion means calm              the pokeable world holds still

const Farm := preload("res://scripts/garden/farm_save.gd")

const SHAPES := [Vector2i(1280, 720), Vector2i(1024, 768)]

## A child's finger, not an adult's mouse pointer. The game's own rule.
const TOUCH_MIN := 60.0

var _failures: Array[String] = []
var _shape := ""
var _presses := 0


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append("[%s] %s" % [_shape, description])


## Press or release at a point in VIEWPORT coordinates.
##
## Input.parse_input_event takes window coordinates, and on the tablet shape
## those are not the same thing: a 1024x768 window carries a 1280x960 viewport,
## so the engine scales everything this probe sends by 1.25 on the way in.
## Every press here was landing a quarter of the screen down and to the right
## of where it was aimed. It went unnoticed because the primary card is big
## enough that a miss of that size still hits it -- and it was only when the
## parent door moved into a corner, where a 64px target has no slack at all,
## that the check finally said "pressing the parent door did nothing".
func _touch(at: Vector2, pressed: bool) -> void:
	var window: Vector2 = Vector2(get_window().size)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var on_glass: Vector2 = at
	if view.x > 1.0 and view.y > 1.0:
		on_glass = Vector2(at.x * window.x / view.x, at.y * window.y / view.y)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = on_glass
	event.global_position = on_glass
	Input.parse_input_event(event)


func _ready() -> void:
	print("\n=== home probe ===")
	# shape -> how much of the bottom is empty, as a fraction of the height
	var dead: Dictionary = {}

	# Every geometry check below runs with BOTH corner marks showing, because a
	# mark that fits on an empty card and overflows a marked one is the only
	# interesting case and it is the one a default save never reaches.
	_a_save_with(true)

	for shape in SHAPES:
		_shape = "%dx%d" % [shape.x, shape.y]
		# Only window.size. Touching content_scale_size switches the expand
		# off, and then the 4:3 pass is measuring a 16:9 screen with a
		# different number written on it.
		get_window().size = shape
		await get_tree().process_frame
		await get_tree().process_frame
		var view: Vector2 = get_viewport().get_visible_rect().size
		print("-- window %s -> viewport %s" % [str(shape), str(view)])
		if shape == Vector2i(1024, 768):
			_ok(is_equal_approx(view.y, 960.0),
				"a 1024x768 window did not produce the 1280x960 viewport a "
				+ "tablet gets (got %s) -- nothing here tested anything" % str(view))

		var home: Control = load("res://scenes/home/Home.tscn").instantiate()
		add_child(home)
		for i in range(4):
			await get_tree().process_frame

		_everything_is_on_the_screen(home, view)
		_nothing_sits_on_anything(home)
		_marks_sit_in_their_corner(home)
		_a_child_can_hit_it(home)
		_one_rhythm(home, view)
		_the_hero_stands_on_the_ground(home)
		_the_world_is_still_pokeable(home, view)
		dead[_shape] = _dead_band(home, view)
		await _one_press_is_one_press(home)
		await _the_parent_door_is_not_a_one_tap_door(home)

		home.queue_free()
		await get_tree().process_frame

	_the_dead_band_does_not_grow(dead)
	await _a_mark_means_something_is_there()
	await _reduce_motion_means_calm()

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("HOME PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


# --- what is on this screen ---------------------------------------------

## Everything with a rectangle, by name, so a failure says WHICH thing left.
##
## A missing member is a failure, not a skip. Renaming `_cards` and quietly
## turning this whole file off is exactly the shape of the bug it is here for.
func _furniture(home: Control) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (home.get("_cards") is Array):
		_failures.append("[%s] home has no _cards -- this probe tested nothing" % _shape)
		return out
	var cards: Array = home.get("_cards")
	var names := ["去冒险", "我的奖励", "英雄小屋", "星光菜园"]
	for i in range(cards.size()):
		var card: Control = cards[i]
		out.append({"name": names[i] if i < names.size() else "card %d" % i,
			"rect": Rect2(card.position, card.size), "touch": true})
	for member in [["_hero_holder", "英雄", true], ["_treasure", "宝物章", true],
			["_parent_pill", "家长门", true], ["_greeting", "问候语", false],
			["_parent_hint", "长按提示", false]]:
		var node: Variant = home.get(str(member[0]))
		if not (node is Control):
			_failures.append("[%s] home has no %s -- this probe tested nothing"
				% [_shape, str(member[0])])
			continue
		var control: Control = node
		out.append({"name": str(member[1]),
			"rect": Rect2(control.position, control.size), "touch": bool(member[2])})
	return out


# --- 1. everything is on the screen -------------------------------------

func _everything_is_on_the_screen(home: Control, view: Vector2) -> void:
	var screen := Rect2(Vector2.ZERO, view)
	for piece in _furniture(home):
		var rect: Rect2 = piece["rect"]
		_ok(screen.encloses(rect),
			"%s is not entirely on the screen: it is at %s on a %s screen"
			% [str(piece["name"]), str(rect), str(view)])


# --- 2. nothing sits on anything else -----------------------------------

func _nothing_sits_on_anything(home: Control) -> void:
	var pieces := _furniture(home)
	for i in range(pieces.size()):
		for j in range(i + 1, pieces.size()):
			var a: Rect2 = pieces[i]["rect"]
			var b: Rect2 = pieces[j]["rect"]
			# grow(-1) so two rectangles that merely share an edge are not
			# reported as overlapping.
			if not a.grow(-1.0).intersects(b.grow(-1.0)):
				continue
			_ok(false, "%s and %s are on top of each other (%s vs %s) -- "
				% [str(pieces[i]["name"]), str(pieces[j]["name"]), str(a), str(b)]
				+ "whichever is underneath cannot be pressed")


# --- 3. a six-year-old can hit it ---------------------------------------

func _a_child_can_hit_it(home: Control) -> void:
	for piece in _furniture(home):
		if not bool(piece["touch"]):
			continue
		var rect: Rect2 = piece["rect"]
		_ok(rect.size.x >= TOUCH_MIN and rect.size.y >= TOUCH_MIN,
			"%s is %dx%d -- under %d in either direction is smaller than the "
			% [str(piece["name"]), int(rect.size.x), int(rect.size.y), int(TOUCH_MIN)]
			+ "finger pressing it")


# --- 4. one rhythm ------------------------------------------------------

## Equal gaps, equal margins, and the header aligned to the block it heads.
##
## Not "roughly equal": three neighbouring elements at three slightly different
## spacings is the single most common way a screen looks wrong without anyone
## being able to say why, and it is arithmetic, so it can simply be asserted.
func _one_rhythm(home: Control, view: Vector2) -> void:
	var boxes: Array = home.get("_card_boxes")
	if boxes == null or boxes.size() < 3:
		_ok(false, "home did not publish a banner and at least two card rectangles")
		return
	var primary: Rect2 = boxes[0]
	# However many small cards there are. Counting them rather than writing 3
	# here is the same lesson twice: the layout hard-coded the count and the
	# fifth card walked off the screen; this probe hard-coded it too and went on
	# measuring the third card while the fourth was the one hanging off the end.
	var last: Rect2 = boxes[boxes.size() - 1]
	var gaps: Array[float] = []
	for i in range(2, boxes.size()):
		gaps.append((boxes[i] as Rect2).position.x - (boxes[i - 1] as Rect2).end.x)
	var widest := 0.0
	for g in gaps:
		widest = maxf(widest, absf(g - gaps[0]))
	_ok(widest <= 1.0,
		"the %d small cards are not evenly spaced: %s" % [boxes.size() - 1, gaps])
	_ok(absf((boxes[1] as Rect2).position.x - primary.position.x) <= 1.0,
		"the card block does not start on one line: big card at x=%.1f, small at x=%.1f"
		% [primary.position.x, (boxes[1] as Rect2).position.x])
	_ok(absf(last.end.x - primary.end.x) <= 1.5,
		"the card block does not end on one line: big card ends at x=%.1f, small at x=%.1f"
		% [primary.end.x, last.end.x])
	# One safe edge, used by everything that touches an edge. The number is
	# read out of the screen's own source rather than written here, so this
	# tests that the rhythm is FOLLOWED, not that it is still 24.
	var rhythm: Dictionary = home.get_script().get_script_constant_map()
	var margin: float = float(rhythm.get("MARGIN", 24))
	_ok(absf((view.x - primary.end.x) - margin) <= 1.5,
		"the card block's right margin is %.1f, and the screen's is %d"
		% [view.x - primary.end.x, int(margin)])
	var door: Control = home.get("_parent_pill")
	if door != null:
		var right: float = view.x - (door.position.x + door.size.x)
		var below: float = view.y - (door.position.y + door.size.y)
		_ok(absf(right - margin) <= 1.0 and absf(below - margin) <= 1.0,
			"the parent door sits %.1f from the right edge and %.1f from the "
			% [right, below] + "bottom; the screen's margin is %d" % int(margin))

	var greeting: Control = home.get("_greeting")
	if greeting != null:
		_ok(absf(greeting.position.x - primary.position.x) <= 1.0,
			"the greeting starts at x=%.1f and the cards at x=%.1f -- a heading "
			% [greeting.position.x, primary.position.x]
			+ "that does not line up with what it heads reads as a caption for "
			+ "whatever is to its left")
	var treasure: Control = home.get("_treasure")
	if treasure != null:
		_ok(absf((treasure.position.x + treasure.size.x) - primary.end.x) <= 1.5,
			"the treasure chip ends at x=%.1f and the cards at x=%.1f"
			% [treasure.position.x + treasure.size.x, primary.end.x])


# --- 5. the hero stands on the ground -----------------------------------

func _the_hero_stands_on_the_ground(home: Control) -> void:
	var holder: Control = home.get("_hero_holder")
	var stage: Variant = home.get("_stage")
	if holder == null or not (stage is Stage):
		_ok(false, "home has no hero or no stage")
		return
	var feet: float = holder.position.y + holder.size.y
	var ground: float = (stage as Stage).ground_y()
	_ok(absf(feet - ground) <= 2.0,
		"the hero's feet are at y=%.1f and the ground is at y=%.1f -- he is "
		% [feet, ground] + ("floating" if feet < ground else "sunk into the hill"))


# --- 6. the dead band ---------------------------------------------------

func _dead_band(home: Control, view: Vector2) -> float:
	var lowest: float = 0.0
	for piece in _furniture(home):
		if not bool(piece["touch"]):
			continue
		lowest = maxf(lowest, (piece["rect"] as Rect2).end.y)
	return (view.y - lowest) / view.y


## The rule a broken layout cannot pass by being uniformly broken. A screen
## that ignores the extra height a 4:3 tablet hands it ALWAYS grows its own
## empty band at the bottom, whatever else it does right.
func _the_dead_band_does_not_grow(dead: Dictionary) -> void:
	_shape = "both"
	if dead.size() < 2:
		_ok(false, "the dead band was not measured on both shapes")
		return
	var wide: float = dead["1280x720"]
	var tall: float = dead["1024x768"]
	print("-- empty band below the lowest control: %.1f%% at 16:9, %.1f%% at 4:3"
		% [wide * 100.0, tall * 100.0])
	_ok(tall <= wide + 0.03,
		"the empty band under the screen grows from %.1f%% to %.1f%% on a "
		% [wide * 100.0, tall * 100.0]
		+ "tablet -- the layout is ignoring the height it was handed")


# --- 7. the world is still pokeable -------------------------------------

## The scenery answers taps. It can only answer the ones that reach it, and
## the card block covers most of the screen -- so a layout change that parked a
## card over every reachable prop would turn the whole feature off without
## breaking anything. Nobody would report that: a home screen where poking the
## sky does nothing looks exactly like a home screen.
func _the_world_is_still_pokeable(home: Control, view: Vector2) -> void:
	var stage: Variant = home.get("_stage")
	if not (stage is Stage):
		_ok(false, "home has no stage")
		return
	# Only the things that actually STOP a touch block the world. The greeting
	# and the hold hint are labels the press falls straight through, and
	# counting them as walls made this check read three targets short.
	var covered: Array[Rect2] = []
	for piece in _furniture(home):
		if bool(piece["touch"]):
			covered.append(piece["rect"])
	var screen := Rect2(Vector2.ZERO, view)
	var on_screen := 0
	var reachable := 0
	for target in (stage as Stage).poke_targets():
		var at: Vector2 = target["at"]
		if not screen.has_point(at):
			continue
		on_screen += 1
		var blocked := false
		for rect in covered:
			if rect.has_point(at):
				blocked = true
				break
		if not blocked:
			reachable += 1
	print("-- pokeable scenery: %d on screen, %d a finger can actually reach"
		% [on_screen, reachable])
	_ok(reachable >= 3,
		"only %d pieces of scenery are reachable -- the cards have covered the "
		% reachable + "world, and poking it does nothing anywhere a child can reach")


# --- the corner marks ---------------------------------------------------

## A save with -- or without -- something waiting behind two of the doors.
##
## Written from nothing every time, because the home screen reads the save and
## a probe that inherits whatever the last one left behind is testing the last
## one. The garden's clock is anchored to now so settle() advances by zero:
## what is asserted here is that a ripe plot MARKS the card, not how crops grow.
func _a_save_with(waiting: bool) -> void:
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
	var farm: Dictionary = SaveManager.data["farm"]
	farm["last_seen_at"] = GameClock.now_unix()
	var plots: Array = farm["plots"]
	var plot: Dictionary = Farm.normalise_plot(plots[0], 0)
	# The crop matters as much as the state. A plot that says READY with
	# nothing planted in it is nonsense, and farm_save._repair quietly turns it
	# back into turned earth -- so the first version of this fixture asserted
	# that a ripe carrot marks the card while planting no carrot at all.
	plot["crop_id"] = "carrot" if waiting else ""
	plot["state"] = Farm.READY if waiting else Farm.EMPTY
	plots[0] = Farm.normalise_plot(plot, 0)
	var shop: Dictionary = SaveManager.data["shop"]
	shop["owned"] = ["cape_star"] if waiting else []
	shop["seen_new"] = []
	SaveManager.save_game()


func _marks(home: Control) -> Dictionary:
	var out: Dictionary = {}
	var names := ["去冒险", "我的奖励", "英雄小屋", "星光菜园"]
	var cards: Array = home.get("_cards")
	for i in range(cards.size()):
		var mark: Node = (cards[i] as Control).get_node_or_null("Mark")
		if mark != null and mark is Control:
			out[names[i]] = mark
	return out


## A mark lives in the corner of its own card, and nowhere near the word.
##
## The corner is the one part of a card that is always empty. A mark that
## drifts inward covers the picture; one that drifts down lands on the label,
## and 星光菜园 with a carrot printed through the middle of it is a card a
## pre-reader can no longer identify at all.
func _marks_sit_in_their_corner(home: Control) -> void:
	var cards: Array = home.get("_cards")
	var names := ["去冒险", "我的奖励", "英雄小屋", "星光菜园"]
	for i in range(cards.size()):
		var card: Control = cards[i]
		var mark: Node = card.get_node_or_null("Mark")
		if mark == null:
			continue
		var spot: Rect2 = (mark as Control).get_global_rect()
		_ok(card.get_global_rect().encloses(spot),
			"%s's corner mark is hanging off its card" % names[i])
		var word: Control = card.get_node("Body/Box/Word")
		_ok(not spot.intersects(word.get_global_rect()),
			"%s's corner mark is printed over its own word" % names[i])
		var chip: Control = card.get_node("Body/Box/Chip")
		_ok(not spot.intersects(chip.get_global_rect()),
			"%s's corner mark is printed over its own picture" % names[i])


## A mark has to MEAN something is there.
##
## The failure this exists for is not a mark in the wrong place -- it is a mark
## that is always drawn, which a child learns to ignore in a week, and which is
## one small step from a red dot that nags him into a shop. So: build the
## screen with something waiting and with nothing waiting, and demand the marks
## appear and then go.
func _a_mark_means_something_is_there() -> void:
	_shape = "marks"
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	_a_save_with(true)
	var loud: Control = load("res://scenes/home/Home.tscn").instantiate()
	add_child(loud)
	for i in range(3):
		await get_tree().process_frame
	var shown: Dictionary = _marks(loud)
	print("-- marks with something waiting: %s" % str(shown.keys()))
	_ok(shown.has("星光菜园"),
		"a ripe crop is waiting and 星光菜园 says nothing about it")
	_ok(shown.has("英雄小屋"),
		"he owns something he has never looked at and 英雄小屋 says nothing "
		+ "about it")
	_ok(not shown.has("去冒险"),
		"去冒险 is marked, and it has no state to be marked about")
	loud.queue_free()
	await get_tree().process_frame

	_a_save_with(false)
	var quiet: Control = load("res://scenes/home/Home.tscn").instantiate()
	add_child(quiet)
	for i in range(3):
		await get_tree().process_frame
	var still: Dictionary = _marks(quiet)
	print("-- marks with nothing waiting: %s" % str(still.keys()))
	_ok(still.is_empty(),
		"the cards are marked with nothing behind them (%s) -- a mark that is "
		% str(still.keys()) + "always on is a decoration, and a decoration "
		+ "that looks like news is the first half of a red dot")
	quiet.queue_free()
	await get_tree().process_frame
	_a_save_with(true)


# --- 8. one press is one press ------------------------------------------

## project.godot turns on emulate_touch_from_mouse, so one click arrives twice
## -- once as a mouse button, once as an emulated touch. Every handler on this
## screen accepts both. UiKit.is_press is what keeps it at one, and a card that
## answers twice fires the hero's reaction twice and starts two tweens on the
## same node.
##
## The second half of this -- did the card MOVE -- is here because it caught a
## real one. The squash was driven from gui_input, and under touch emulation a
## Button eats the mouse event itself, so the emulated touch never reached the
## handler and UiKit.is_press correctly refused the mouse duplicate: a card
## that tilted on the tablet and sat perfectly still on the machine this game
## is written on. Every check in this file passed while it did.
func _one_press_is_one_press(home: Control, expect_tilt: bool = true) -> void:
	var cards: Array = home.get("_cards")
	if cards.is_empty():
		return

	# Before unwiring anything: every door must be wired to somewhere. A card
	# that is beautiful and connected to nothing is this project's oldest bug
	# shape -- five coin sources and a whole shop manager sat finished and
	# unreachable for weeks, and nothing complained.
	for i in range(cards.size()):
		_ok((cards[i] as Button).pressed.get_connections().size() >= 1,
			"card %d opens nothing -- its pressed signal goes to no one" % i)

	var card: Button = cards[0]
	# Now take the trip off it. Left connected, the emulated touch that
	# accompanies every mouse event completes the button and SceneManager
	# replaces the current scene -- which is this probe, mid-await.
	for connection in card.pressed.get_connections():
		card.pressed.disconnect(connection["callable"])

	_presses = 0
	var count := func(): _presses += 1
	card.button_down.connect(count)

	card.scale = Vector2.ONE
	card.rotation = 0.0

	_touch(card.position + card.size * 0.5, true)
	for i in range(4):
		await get_tree().process_frame
	var squashed: Vector2 = card.scale

	_touch(Vector2(-50, -50), false)
	await get_tree().process_frame
	card.button_down.disconnect(count)

	_ok(_presses == 1,
		"one press on 去冒险 became %d button_down(s), not one" % _presses)
	if expect_tilt:
		_ok(squashed.y < 0.999,
			"去冒险 did not move under the finger (scale stayed %s) -- the "
			% str(squashed) + "card looks pressable and answers like a "
			+ "photograph")
	else:
		_ok(is_equal_approx(squashed.y, 1.0),
			"去冒险 still squashed with reduce-motion on (scale %s)" % str(squashed))


# --- 9. the parent door is not a one-tap door ---------------------------

## A child who taps it must get nowhere. The hold is the first of two locks
## (the second is the arithmetic gate on the far side), and a tap that opened
## it would make the second lock the only one.
##
## The required hold is read and asserted BEFORE anything is pressed, and the
## press is then deliberately shorter than it. The first version of this check
## simply held the door for a third of a second and asserted the screen had not
## gone anywhere -- which, when the hold was sabotaged down to 0.2s to see the
## check go red, opened the parent centre, replaced the current scene, and took
## the running probe with it. It reported nothing at all: no failure, no pass,
## no output. A check that cannot survive the bug it is looking for is not a
## check.
func _the_parent_door_is_not_a_one_tap_door(home: Control) -> void:
	var pill: Variant = home.get("_parent_pill")
	if not (pill is Button):
		_ok(false, "home has no parent door")
		return
	var required: float = float(home.get_script().get_script_constant_map()
		.get("PARENT_HOLD_SECONDS", 0.0))
	_ok(required >= 2.0,
		"the parent door opens after %.2fs -- a thumb resting on the corner of "
		% required + "a tablet lasts longer than that")

	var button: Button = pill
	var press: float = minf(0.35, required * 0.4)
	var at: Vector2 = button.position + button.size * 0.5

	# Before any finger arrives, the corner says the door's NAME and nothing
	# else. "Hold for three seconds" standing there all day is an instruction
	# as furniture -- it earned its removal, and this line keeps it removed.
	var hint: Variant = home.get("_parent_hint")
	if hint is Label:
		_ok(str((hint as Label).text) == I18n.t("home.parent"),
			"at rest the corner should say only '%s', it says '%s'"
			% [I18n.t("home.parent"), str((hint as Label).text)])

	_touch(at, true)
	await get_tree().create_timer(press).timeout

	# While the hold runs, the second line is the countdown -- the adult can
	# see it is working without anything else on the screen moving.
	if hint is Label:
		var mid := str((hint as Label).text)
		_ok(mid.contains("\n") and mid.get_slice("\n", 1).is_valid_int(),
			"while holding, the corner should count down; it says '%s'" % mid)

	_ok(bool(home.get("_holding")), "pressing the parent door did not start the hold")
	var fill: Variant = home.get("_parent_fill")
	if fill is Control:
		var grown: float = (fill as Control).size.x
		_ok(grown > 0.0,
			"the parent door filled nothing while it was held -- an adult "
			+ "cannot tell it is working")
		_ok(grown < button.size.x * 0.75,
			"%.0f%% of the way open after %.2fs of holding -- the door is not "
			% [grown / maxf(button.size.x, 1.0) * 100.0, press]
			+ "asking for a deliberate hold, it is asking for a press")

	_touch(at, false)
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(not bool(home.get("_holding")),
		"letting go of the parent door did not cancel the hold")
	_ok(home.is_inside_tree(),
		"the parent door opened during a press shorter than its own hold")
	if fill is Control:
		_ok((fill as Control).size.x <= 0.5,
			"the parent door stayed part-filled after the finger left, so the "
			+ "next press starts from wherever the last one stopped")

	# A tap too short to open the door is the one moment an adult wonders why
	# nothing happened -- the answer flashes up right then, and only then.
	if hint is Label:
		_ok(str((hint as Label).text).contains(I18n.t("parent.hold_hint")),
			"after a too-short press the corner should explain the hold; "
			+ "it says '%s'" % str((hint as Label).text))
		await get_tree().create_timer(2.5).timeout
		_ok(str((hint as Label).text) == I18n.t("home.parent"),
			"the explanation should fall quiet again; it stuck at '%s'"
			% str((hint as Label).text))


# --- 10. reduce-motion means calm ---------------------------------------

## Reduce-motion means "calm screen", and a world that wobbles when poked is
## the first thing it is asking for less of. The doors still have to work: the
## setting removes sugar, never function.
func _reduce_motion_means_calm() -> void:
	_shape = "reduce-motion"
	var was: Variant = SaveManager.get_setting("reduce_motion", false)
	SaveManager.set_setting("reduce_motion", true)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var home: Control = load("res://scenes/home/Home.tscn").instantiate()
	add_child(home)
	for i in range(4):
		await get_tree().process_frame

	var stage: Variant = home.get("_stage")
	if stage is Stage:
		var targets: Array[Dictionary] = (stage as Stage).poke_targets()
		_ok(not targets.is_empty(), "the world has nothing to poke at all")
		for target in targets:
			_ok(not (stage as Stage).poke_at(target["at"] as Vector2),
				"the scenery still wobbles when poked with reduce-motion on")
			break

	# ...and the doors still open, they just do not perform on the way.
	await _one_press_is_one_press(home, false)

	home.queue_free()
	await get_tree().process_frame
	SaveManager.set_setting("reduce_motion", was)
	# Saves live across processes. The next probe in the suite gets a clean
	# one rather than this file's ripe carrot and its unlooked-at cape.
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	DirAccess.remove_absolute(SaveManager.SAVE_BACKUP)
	SaveManager.load_game()
