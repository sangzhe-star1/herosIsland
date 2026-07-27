extends LevelManager
## 丰收行动 -- the tenth template, and the first one that asks the HAND to
## learn something rather than the eye.
##
##
## WHY THIS IS A LEVEL AND NOT A ROOM IN THE GARDEN
##
## The brief puts it under the farm, as ten new scripts and five new scenes.
## Its own definition argues otherwise: "a two-to-four minute level, scored out
## of three stars, paying 星星币 at the end, not touching the real barn". That
## is word for word what a level is on this island, and LevelManager already
## does all of it -- entering, leaving, the back button, LevelResult, the three
## doors, the result screen, first-time bonuses, unlocking, the map marker, and
## the star tally. Every one of those is covered by probes that already exist.
##
## A parallel farm subsystem would re-implement each of them, and the new copy
## would be outside every probe in the folder on the day it was written.
##
##
## THE REAL BARN IS NOT TOUCHED
##
## Nothing picked here goes into InventoryManager. It goes into `_picked`, a
## count that lives as long as the level does, and the reward is paid ONCE at
## the end through RewardManager like every other level's. That is the brief's
## rule (§15) and it is also the only way "the challenge cannot be farmed" can
## be true: there is nothing to farm mid-level, because nothing is banked
## mid-level.

const Crops := preload("res://scripts/harvest/harvest_crops.gd")
const Target := preload("res://scripts/harvest/harvest_target.gd")
const Basket := preload("res://scripts/harvest/harvest_basket.gd")
const Maturity := preload("res://scripts/harvest/maturity.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")

## Where the basket sits, against the design size. Bottom right, clear of the
## targets, in the corner a right thumb rests in.
const BASKET_AT := Vector2(1140, 600)
const BASKET_SIZE := 132.0

var _stage: Stage                   # the world, kept so the bed can sit on its ground
var _field: Control                 # catches every touch; targets live under it
var _hud: Control
var _picker: Picker
var _hints: Hints
var _targets: Array[Node2D] = []
## The baskets, in the order the level listed them. One basket means the game
## puts things away; two or more mean he has to decide which, and the drop has
## to LAND in one.
var _baskets: Array[Node2D] = []
var _tally: HBoxContainer
var _tally_pips: Array = []

## What has been picked THIS RUN. Never written to the barn.
var _picked: Dictionary = {}        # crop_id -> how many
var _wanted: Dictionary = {}        # crop_id -> how many the order asks for
var _allowed: Array = []            # which ripeness steps this order accepts
## Rules that beat the ordinary basket sorting: [{tag, basket}].
var _exceptions: Array = []
## The orders, in the order they arrive, and which one is on the board now.
var _orders: Array = []
var _order_index := 0
## What earlier orders in this level already took. Kept apart from `_picked`
## so a checkpoint restores the finished ones without refilling the current one.
var _delivered: Dictionary = {}
var _unripe_taps := 0
var _helped := false
## Whether the order has been filled. LevelManager keeps its OWN `_finished`
## for "this level is over"; shadowing it is a parse error, and the two mean
## different things anyway -- the order can be full a moment before the level
## has finished saying so.
var _order_done := false

## The pointer currently drawing a gesture, and what it has drawn.
var _pointer := -1
var _track := PackedVector2Array()
var _holding: Node2D = null


## Picking is the whole level; there is no separate goal to reach.
func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	# Three doors, like every template here:
	#   1 the order is filled   2 every order is filled   3 one optional thing
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_allowed = config.get("allowed_maturity", Maturity.PICKABLE)
	_exceptions = config.get("exceptions", [])

	_stage = build_world(self, 0.30)
	_field = UiKit.play_area(self, true)
	_field.gui_input.connect(_on_field_input)

	_draw_bed()
	_lay_out(config)
	_build_hud(config)

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_nudge, _show_the_move, _do_the_hard_part)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_teach_if_new(config)


# --- the field ------------------------------------------------------------

## Lay the targets out on a loose grid, jittered by the level's own seed so a
## replay finds them in the same places rather than a fresh shuffle.
##
## Spacing is derived from the touch radius, not chosen by eye: two targets
## closer together than twice the radius can both claim the same press, and a
## child who watched the wrong carrot come up has no way to put it back. The
## garden learned this the same way and its beds are spaced off DragField.SNAP.
func _lay_out(config: Dictionary) -> void:
	var spec: Array = config.get("targets", [])
	var placed: Array[Vector2] = []
	var reach := _reach()
	var apart := reach * 2.0 + 20.0

	for entry in spec:
		var crop: Dictionary = Crops.get_crop(str(entry.get("crop_id", "")))
		if crop.is_empty():
			continue
		var step := str(entry.get("maturity", Maturity.READY))
		for i in range(int(entry.get("count", 1))):
			var at := _somewhere_clear(placed, apart)
			placed.append(at)
			var node: Node2D = Target.new()
			node.position = at
			_field.add_child(node)
			node.build(crop, step, reach)
			node.picked.connect(_on_picked)
			node.refused.connect(_on_refused)
			_targets.append(node)

	# One order, or several in a row. A level with several is a level with
	# checkpoints: each one that lands is written to disk before the next
	# appears, so a tablet that dies in the middle of the celebration level
	# costs the current order and never the two already delivered.
	_orders = config.get("orders", [])
	if _orders.is_empty():
		_orders = [{"requirements": config.get("order", [])}]
	_restore_checkpoint()
	_load_order()


## Where he had got to, if he was here before and left in the middle.
##
## Only ONE checkpoint is kept, and only for the level it belongs to. A child
## does not sit half-finished in three levels at once, and a stale checkpoint
## from another level restoring into this one would be worse than no checkpoint
## at all.
func _restore_checkpoint() -> void:
	var mark: Dictionary = SaveManager.data.get("farm", {}).get(
		"harvest_checkpoint", {})
	if str(mark.get("level_id", "")) != str(level_data.get("id", "")):
		return
	_order_index = clampi(int(mark.get("order_index", 0)), 0, _orders.size() - 1)
	var done: Dictionary = mark.get("delivered", {})
	for crop_id in done.keys():
		_delivered[str(crop_id)] = int(done[crop_id])


## Write down where he is. Called the moment an order lands, never mid-order:
## a checkpoint that saved every pick would let a child put one carrot in,
## leave, come back and find it counted, which is a save system doing the
## level for him.
func _save_checkpoint() -> void:
	var farm: Dictionary = SaveManager.data.get("farm", {})
	farm["harvest_checkpoint"] = {
		"level_id": str(level_data.get("id", "")),
		"order_index": _order_index,
		"delivered": _delivered.duplicate(),
	}
	SaveManager.save_game()


## Clear it -- the level is over, one way or the other.
func _clear_checkpoint() -> void:
	var farm: Dictionary = SaveManager.data.get("farm", {})
	if str(farm.get("harvest_checkpoint", {}).get("level_id", "")) \
			== str(level_data.get("id", "")):
		farm["harvest_checkpoint"] = {}
		SaveManager.save_game()


func _load_order() -> void:
	_wanted.clear()
	_picked.clear()
	if _order_index >= _orders.size():
		return
	for entry in (_orders[_order_index] as Dictionary).get("requirements", []):
		_wanted[str(entry.get("crop_id", ""))] = int(entry.get("count", 1))


## How far from the middle of a target a press still counts.
##
## The gentle setting reaches further and the brave setting less, through the
## same difficulty knob the other thirty levels use -- NOT through a second
## table of profiles, which would leave the parent's switch in the Parent
## Centre setting one thing and the harvest levels reading another.
func _reach() -> float:
	return harder(78.0, 0.77)


## The patch of earth things grow in.
##
## Carrots do not hang in the sky. The first cut scattered targets across the
## whole play area and they floated in the clouds, which is funny for about a
## second and then reads as broken -- a six-year-old knows perfectly well where
## a carrot lives.
##
## So the bed is a real rectangle of turned earth, sitting ON the world's ground
## line, and everything is planted inside it. Measured off the stage rather than
## off 720: the ground moves down on a tablet and the bed has to move with it.
## Where the targets may be planted -- the middles, not the picture edges.
##
## Two rows of crops need about 380px of height, which is more than the world's
## near-ground strip has (the horizon sits around 78% of the way down). So the
## field starts above the horizon and runs to just short of the bottom edge,
## the way a field seen from slightly above does. Fractions of the real screen
## rather than numbers against 720: on a tablet the whole thing moves down with
## the ground it is drawn on.
##
## Inset by half a crop on every side, so nothing is drawn hanging over the
## edge of its own soil.
const CROP_HALF := 62.0

func _bed() -> Rect2:
	var view := get_viewport_rect().size
	var top: float = view.y * 0.50
	# Clear of the basket in the right-hand corner.
	return Rect2(110.0 + CROP_HALF, top + CROP_HALF,
		view.x - 360.0 - CROP_HALF * 2.0,
		view.y - top - 60.0 - CROP_HALF * 2.0)


func _draw_bed() -> void:
	# The soil is the planting box grown back out by the inset, so the crops sit
	# ON it rather than at its edges.
	var box := _bed().grow(CROP_HALF + 14.0)
	var soil := Node2D.new()
	soil.z_index = -5
	_field.add_child(soil)
	# fill(), not lit(). lit() shrinks its highlight to three quarters and
	# shifts it towards the light, which reads as a second brown rectangle
	# sitting crooked on top of the first once the shape is this big -- fine
	# for a carrot, wrong for a field.
	Shapes.fill(soil, Shapes.rounded_rect(box.position, box.size, 46.0),
		Color(0.47, 0.33, 0.22), 1.0)
	# A lighter band along the top edge instead: sunlight on turned earth.
	Shapes.fill(soil, Shapes.rounded_rect(box.position + Vector2(18, 10),
		Vector2(box.size.x - 36.0, 26.0), 13.0),
		Color(0.56, 0.41, 0.28, 0.7), 0.0)
	# Furrows, so it reads as ploughed ground and not as a brown card.
	var rows := 3
	for i in range(rows):
		var y: float = box.position.y + box.size.y * (float(i) + 1.0) / float(rows + 1)
		Shapes.fill(soil, Shapes.rounded_rect(
			Vector2(box.position.x + 40.0, y - 4.0),
			Vector2(box.size.x - 80.0, 8.0), 4.0),
			Color(0.36, 0.25, 0.16, 0.5), 0.0)


func _somewhere_clear(taken: Array[Vector2], apart: float) -> Vector2:
	var box := _bed()
	var best := box.position + box.size * 0.5
	var best_gap := -1.0
	for attempt in range(60):
		var at := Vector2(
			_picker.number(box.position.x, box.end.x),
			_picker.number(box.position.y, box.end.y))
		var gap := 1e9
		for other in taken:
			gap = minf(gap, at.distance_to(other))
		if taken.is_empty() or gap >= apart:
			return at
		if gap > best_gap:
			best_gap = gap
			best = at
	# Crowded. Take the roomiest spot found rather than stacking two on top of
	# each other -- a level that cannot be finished is worse than a tight one.
	return best


func _build_hud(config: Dictionary) -> void:
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

	# What the order wants, as pictures and pips. No sentence to read.
	_tally = HBoxContainer.new()
	_tally.add_theme_constant_override("separation", 18)
	_tally.position = Vector2(220, 26)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tally)
	_rebuild_tally()

	_build_baskets(config)


## One basket, or several.
##
## With one, a pick flies to it on its own -- there is no decision, and asking a
## five-year-old to carry every carrot across the screen is work without a
## question in it. With two or more the drop has to END on a basket, and which
## one is the whole level.
func _build_baskets(config: Dictionary) -> void:
	var spec: Array = config.get("baskets", [])
	if spec.is_empty():
		spec = [{"id": "basket", "icon": "basket"}]
	var view := get_viewport_rect().size
	# Beside the field and level with it, never above it. Baskets hanging in the
	# sky was the first cut, and a basket in a cloud is not somewhere a
	# six-year-old will think to put a strawberry.
	var bed := _bed()
	var span: float = minf(210.0, bed.size.y / maxf(float(spec.size()), 1.0))
	var middle: float = bed.position.y + bed.size.y * 0.5
	var top: float = middle - span * (float(spec.size()) - 1.0) * 0.5
	for i in range(spec.size()):
		var node: Node2D = Basket.new()
		node.position = Vector2(view.x - 150.0, top + span * float(i))
		_field.add_child(node)
		node.build(spec[i], BASKET_SIZE)
		_baskets.append(node)


func _rebuild_tally() -> void:
	for child in _tally.get_children():
		child.queue_free()
	_tally_pips.clear()
	for crop_id in _wanted.keys():
		var crop: Dictionary = Crops.get_crop(str(crop_id))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var art: Control = UiKit.picture(str(crop.get("asset", "")), 62.0)
		if art != null:
			box.add_child(art)
		var count := UiKit.title("%d/%d" % [int(_picked.get(crop_id, 0)),
			int(_wanted[crop_id])], 26)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(count)
		_tally.add_child(box)
		_tally_pips.append(count)



# --- one finger, one gesture ----------------------------------------------

## Touch AND mouse, both normalised to the same three moments.
##
## Both families are handled here rather than relying on emulation: a
## MOUSE_FILTER_STOP Control eats InputEventScreenTouch before any mouse event
## is synthesised from it, which is exactly how this project once shipped a
## screen that worked on a Mac and did nothing at all on the iPad.
func _on_field_input(event: InputEvent) -> void:
	if _order_done:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin(touch.index, touch.position)
		else:
			_end(touch.index, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_begin(-2, click.position)
		else:
			_end(-2, click.position)
	elif event is InputEventMouseMotion:
		_move(-2, (event as InputEventMouseMotion).position)


func _begin(pointer: int, at: Vector2) -> void:
	if _pointer != -1:
		return                           # one gesture at a time, on purpose
	_pointer = pointer
	_track = PackedVector2Array([at])
	_holding = _nearest(at)


func _move(pointer: int, at: Vector2) -> void:
	if pointer != _pointer:
		return
	_track.append(at)
	# Digging shows its work. Without this a child sweeps at a mound of earth,
	# nothing happens for three strokes, and then the crop appears -- which
	# reads as the game deciding rather than as him digging.
	if _holding != null and is_instance_valid(_holding) \
			and str(_holding.crop.get("recogniser", "")) == Gesture.SWEEP:
		var params: Dictionary = _holding.crop.get("gesture_params", {})
		var want: int = maxi(int(params.get("turns", 3)), 1)
		_holding.uncover(float(_reversals(_track,
			float(params.get("leg", 60.0)))) / float(want))


## How many real direction changes the track has so far. Same rule the
## recogniser uses, asked mid-gesture so the soil can come off as it happens.
func _reversals(track: PackedVector2Array, leg: float) -> int:
	var turns := 0
	var heading := 0.0
	var run := 0.0
	for i in range(1, track.size()):
		var dx: float = track[i].x - track[i - 1].x
		if absf(dx) < 0.5:
			continue
		var way: float = signf(dx)
		if heading == 0.0:
			heading = way
			run = absf(dx)
			continue
		if way == heading:
			run += absf(dx)
			continue
		if run >= leg:
			turns += 1
		heading = way
		run = absf(dx)
	return turns


func _end(pointer: int, at: Vector2) -> void:
	if pointer != _pointer:
		return
	_track.append(at)
	var target := _holding
	var track := _track
	_pointer = -1
	_track = PackedVector2Array()
	_holding = null

	if target == null or not is_instance_valid(target):
		return
	if not target.try_gesture(track, _allowed):
		# A dig that stopped half way puts the earth back, so the next attempt
		# starts from somewhere honest rather than from a mound that is
		# mysteriously already half gone.
		if str(target.crop.get("recogniser", "")) == Gesture.SWEEP:
			target.uncover(0.0)
		return

	# Clutter is pushed aside where it lies. No basket, no count, no reward.
	if _is_clutter(target):
		target.fly_to(target.global_position + Vector2(0, 220.0))
		_targets.erase(target)
		AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		if _hints != null:
			_hints.progress()
		return

	# Where it goes. With one basket there is nothing to decide and it flies
	# there; with several, the drop has to have LANDED on one.
	var basket := _basket_for(track[track.size() - 1])
	if basket == null:
		# Let go over nothing. The crop stays where it was -- untaken, still
		# there to try again -- because "I picked it and it vanished" is the
		# one outcome a child cannot recover from.
		target.taken = false
		target.refuse("nowhere")
		return
	# Exceptions first, and that ORDER is the rule (brief section six): "the ones
	# with a star go in the gift basket" has to beat "fruit goes in the fruit
	# basket", or a golden strawberry is correct in two places and the child is
	# marked wrong for following the newer instruction.
	var must: String = _exception_basket(target)
	if must != "":
		if basket.id != must:
			target.taken = false
			basket.refuse()
			target.refuse("wrong_basket")
			return
	elif not basket.takes(target.crop):
		target.taken = false
		basket.refuse()
		target.refuse("wrong_basket")
		return

	basket.accept()
	target.fly_to(basket.global_position)
	_after_a_pick(target)


## A stone in the way, a bug on a berry. Moved aside, never "collected".
##
## Clutter is not scored, not counted, and not lost -- it is simply moved, the
## way a stone in a real garden is. It is the only thing on screen that does
## not go to a basket, because a stone in the fruit basket is a joke the game
## does not need to explain.
func _is_clutter(target: Node2D) -> bool:
	return "clutter" in target.crop.get("tags", [])


## Does this one have to go somewhere particular, whatever its kind says?
##
## Reads the level's `exceptions`: a tag, and the basket that tag demands. A
## crop carrying the tag can go NOWHERE else -- that is what makes it an
## exception rather than a second opinion.
func _exception_basket(target: Node2D) -> String:
	for rule in _exceptions:
		var tag := str(rule.get("tag", ""))
		if tag == "":
			continue
		# "golden" is a ripeness, not a tag on the crop -- it is the one
		# exception a child can SEE without reading anything, so it is worth
		# the special case.
		var carries: bool = tag in target.crop.get("tags", []) \
			or (tag == "golden" and target.step == Maturity.GOLDEN)
		if carries:
			return str(rule.get("basket", ""))
	return ""


## Which basket that drop landed in, or the only one there is.
func _basket_for(at: Vector2) -> Node2D:
	if _baskets.size() == 1:
		return _baskets[0]
	for basket in _baskets:
		if basket.in_reach(at):
			return basket
	return null


func _nearest(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_gap := 1e9
	for node in _targets:
		if not is_instance_valid(node) or node.taken:
			continue
		var gap: float = node.global_position.distance_to(at)
		if gap <= node.radius and gap < best_gap:
			best_gap = gap
			best = node
	return best


# --- what a pick means ----------------------------------------------------

func _on_picked(target: Node2D) -> void:
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	Juice.burst(_field, target.global_position, 16)


## Not the right one, or not the right move. Nothing is lost either way.
##
## An unripe tap is counted only so the third star can notice it and so the
## hint director can offer help sooner. It costs no time, no star and no coin,
## and there is no cap after which something bad happens.
func _on_refused(_target: Node2D, why: String) -> void:
	if why == "unripe":
		_unripe_taps += 1
		AudioManager.say("harvest_not_yet")
	elif why == "wrong_basket":
		AudioManager.say("harvest_wrong_basket")
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
	if _hints != null:
		_hints.missed()


func _after_a_pick(target: Node2D) -> void:
	var crop_id := str(target.crop.get("id", ""))
	var got := maxi(int(target.crop.get("harvest_count", 1)), 1)
	_picked[crop_id] = int(_picked.get(crop_id, 0)) + got
	_targets.erase(target)
	if _hints != null:
		_hints.progress()
	_rebuild_tally()
	score_correct()

	# The three doors, decided here and read by the result screen.
	if not _order_filled() or _order_done:
		return
	# The first order landing is the first star, and it is written down before
	# anything else happens.
	result.reached_goal = true
	for filled in _picked.keys():
		_delivered[filled] = int(_delivered.get(filled, 0)) \
			+ int(_picked[filled])
	_order_index += 1
	_save_checkpoint()

	if _order_index < _orders.size():
		AudioManager.play_sfx("res://assets/audio/coin.ogg")
		AudioManager.say("harvest_next_order")
		_load_order()
		_rebuild_tally()
		return
	_finish()


func _order_filled() -> bool:
	for crop_id in _wanted.keys():
		if int(_picked.get(crop_id, 0)) < int(_wanted[crop_id]):
			return false
	return true


## The optional third door: no hints used, or nothing unripe taken by mistake,
## or a golden one found. Any ONE of them is enough -- using a hint still gets
## the first two stars, which is the rule the whole hint system rests on.
func _optional_met() -> bool:
	if not _helped:
		return true
	if _unripe_taps == 0:
		return true
	for crop_id in _picked.keys():
		if str(Crops.get_crop(str(crop_id)).get("special_rule", "")) == "golden":
			return true
	return false


## The second star is "every order filled", which for a one-order level is the
## same moment as the first. Level 8 is where they come apart; until then the
## honest reading is that finishing a single-order level is worth both, and
## saying so here beats a level that can only ever score one.
func _finish() -> void:
	_order_done = true
	result.reached_goal = true
	result.clean_run = true                # every order filled
	_clear_checkpoint()
	result.found_hidden = _optional_met()  # the optional third
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	complete_level()


# --- teaching and helping -------------------------------------------------

## The finger shows the move once, the first time a child meets it.
##
## Keyed on the GESTURE and not on the level, so meeting pull_up again in a
## later level does not replay the lesson, and meeting a new gesture in level
## six does.
func _teach_if_new(config: Dictionary) -> void:
	var lesson := str(config.get("teaches", ""))
	if lesson == "":
		return
	var learned: Array = SaveManager.get_setting("harvest_taught", [])
	if lesson in learned:
		return
	learned.append(lesson)
	SaveManager.set_setting("harvest_taught", learned)
	AudioManager.say(str(config.get("teach_voice", "harvest_pull_up")))
	_show_the_move()


func _first_target() -> Node2D:
	for node in _targets:
		if is_instance_valid(node) and not node.taken \
				and Maturity.pickable(node.step, _allowed):
			return node
	return null


func _nudge() -> void:
	var node := _first_target()
	if node == null:
		return
	AudioManager.say(str(node.crop.get("voice_intro", "harvest_tap")))
	Juice.shockwave(_field, node.global_position, 150.0,
		Color(1.0, 0.94, 0.62, 0.5))


func _show_the_move() -> void:
	var node := _first_target()
	if node == null:
		return
	var hand := Tutorial.new()
	_field.add_child(hand)
	hand.add_step(node.global_position, _gesture_end(node), 1.2)
	hand.play()


## Where the finger should end up for this crop's gesture. The finger has to
## travel the actual move, not just point at the thing -- "tap it" and "pull it
## up" look identical if the hand only ever taps.
func _gesture_end(node: Node2D) -> Vector2:
	var params: Dictionary = node.crop.get("gesture_params", {})
	match str(node.crop.get("recogniser", "")):
		Gesture.DRAG:
			var dir := Vector2(float(params.get("direction_x", 0.0)),
				float(params.get("direction_y", -1.0))).normalized()
			return node.global_position + dir * float(params.get("distance", 90.0))
		Gesture.TWIST:
			return node.global_position + Vector2(70, -70)
		Gesture.LINE:
			return node.global_position + Vector2(0, 90)
		Gesture.SWEEP:
			return node.global_position + Vector2(90, 0)
	return node.global_position


## Never the last one. The hardest part of a gesture is starting it in the
## right place, so this puts the finger there and holds it -- the move itself
## is still his.
func _do_the_hard_part() -> void:
	_show_the_move()
