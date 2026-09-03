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
## (BASKET_AT is the old single-basket anchor; _build_baskets() now measures
## the whole column against the soil, so this stays as a documented fallback.)
const BASKET_AT := Vector2(1140, 600)
## The biggest a basket picture gets. The column divides the soil height by the
## basket count, so three baskets still end up smaller than one -- smaller is
## not the failure, indistinguishable is (see _build_baskets).
const BASKET_SIZE := 150.0

## What a crop's reach is when harvest_crops.json does not say. Every crop in
## the catalogue does say, so this is only ever the answer for a crop_id that
## is not in the catalogue at all.
const DEFAULT_REACH := 78.0

## The closest two things on the bed are ever allowed to be planted.
##
## Not a reach and not a picture size: it is roughly twice how far a
## six-year-old's thumb lands from where he was looking. Closer than this and
## "I meant that one" stops being bad luck and becomes the layout's fault. See
## _somewhere_clear, which relaxes the level's preferred spacing in steps but
## never goes under this while any spot on the bed still clears it.
const THUMB_APART := 92.0

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
## A small, wordless route through a multi-order level. It deliberately lives
## in the existing HUD rather than becoming a second order-board component.
var _order_strip: HBoxContainer

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
## Consecutive successful picks with no refuse in between. Feeds NOTHING but
## the cheer below: no star, no coin, no optional door. A miss only quiets the
## celebration back down -- the gentle refuse voice is already the whole of
## what a mistake says, and a number that punished would teach him to stop
## guessing. There is deliberately no streak meter on screen for the same
## reason: the escalating confetti IS the display.
var _streak := 0
## Whether the order has been filled. LevelManager keeps its OWN `_finished`
## for "this level is over"; shadowing it is a parse error, and the two mean
## different things anyway -- the order can be full a moment before the level
## has finished saying so.
var _order_done := false

## The pointer currently drawing a gesture, and what it has drawn.
var _pointer := -1
var _track := PackedVector2Array()
var _holding: Node2D = null
## The gesture-demo finger, if one is still playing. Kept so the moment a
## crop comes off the plant it can be skipped: a demo is only ever about the
## half of the move just finished, and two fingers about two halves of one
## move is how the held crop ended up wearing its own lesson.
var _demo: Tutorial = null

## What he has picked and not yet put away, in a level with more than one
## basket. One thing at a time, on purpose: two things in hand and a tap on a
## basket means "which one", and that is a question the screen cannot ask.
var _in_hand: Node2D = null
## Whether the first pick of this run already taught the sorting loop. The
## waiting ring on the right basket is the permanent answer; the voice plus
## the pointing finger happen exactly once per run, on the first hold, so the
## help teaches and then gets out of the way. Reset in setup_level, so every
## entry into the level teaches once no matter which order is current.
var _sort_hinted := false


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
	_sort_hinted = false

	_stage = build_world(self, 0.30)
	_field = UiKit.play_area(self, true)
	_field.gui_input.connect(_on_field_input)

	_lay_out(config)
	_build_hud(config)

	_hints = Hints.new()
	add_child(_hints)
	# Row three of the difficulty table: errors before help. 温和 1 / 普通 2 /
	# 勇敢 3 -- the same harder_i() the rest of the game trusts, never a second
	# difficulty system.
	_hints.misses_before_help = harder_i(2, 1)
	_hints.watch(_nudge, _show_the_move, _do_the_hard_part)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_teach_if_new(config)
	_build_brave_clock()


## The last row of the difficulty table: at 勇敢 a small clock runs, purely to
## watch -- no countdown, nothing lost when it grows. The brave child gets one
## more thing to think about ("how fast was I?"), the other two tiers never
## see a timer at all, and a number that only ever counts UP cannot make
## anyone lose.
var _clock: Label


func _build_brave_clock() -> void:
	if difficulty() != BRAVE:
		return
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	UiKit.on_art(_clock, 6)
	_clock.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_clock.position = Vector2(148, 44)
	_clock.size = Vector2(140, 34)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock)


func _process(delta: float) -> void:
	# The base class ticks _elapsed and the rest of the level's heartbeat in
	# ITS _process -- overriding without super here silently froze the level
	# timer, which is the exact kind of bug a clock exists to reveal.
	super._process(delta)
	if _clock != null and is_instance_valid(_clock):
		_clock.text = "%d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]


# --- the field ------------------------------------------------------------

## Lay the targets out on a loose grid, jittered by the level's own seed so a
## replay finds them in the same places rather than a fresh shuffle.
##
## Spacing is derived from the touch radius, not chosen by eye: two targets
## closer together than twice the radius can both claim the same press, and a
## child who watched the wrong carrot come up has no way to put it back. The
## garden learned this the same way and its beds are spaced off DragField.SNAP.
func _lay_out(config: Dictionary) -> void:
	# The plan is settled FIRST -- crop, ripeness and count per entry, with
	# the difficulty already folded in -- then planted. Planning and planting
	# used to be one loop, and the moment a count depended on difficulty the
	# grid would have been sized for the data's numbers while the field held
	# the scaled ones.
	var plan: Array = []
	var count := 0
	for entry in config.get("targets", []):
		var crop: Dictionary = Crops.get_crop(str(entry.get("crop_id", "")))
		if crop.is_empty():
			continue
		var step := str(entry.get("maturity", Maturity.READY))
		var n := int(entry.get("count", 1))
		# Row two of the difficulty table: the decoy share. Things that are
		# NOT pickable for this level -- unripe, almost-ready, whatever the
		# order refuses -- are the "which ones are actually ready" question,
		# and the braver tier asks it more often. Data holds the 普通 number;
		# 温和 sees fewer, 勇敢 more. Never below one: a decoy the data asked
		# for teaches something even at the gentlest setting.
		if not Maturity.pickable(step, _allowed):
			n = maxi(int(round(harder(float(n), 1.45))), 1)
		plan.append({"crop": crop, "step": step, "count": n})
		count += n

	# Spacing against the WIDEST crop on this field, reach against each crop's
	# own. A pumpkin and a strawberry spaced for the strawberry would have the
	# pumpkin swallowing presses aimed at the berry next to it.
	var spots := _plan_positions(count, _bed(), _spread(config) * 2.0 + 20.0)
	var next := 0

	# The earth is drawn from the same spots the crops are planted on, so
	# every mound below sits under exactly one crop.
	_draw_bed(spots)

	for entry in plan:
		var crop: Dictionary = _tuned(entry["crop"])
		var step: String = entry["step"]
		for i in range(int(entry["count"])):
			var at: Vector2 = spots[next] if next < spots.size() \
				else _bed().position + _bed().size * 0.5
			next += 1
			var node: Node2D = Target.new()
			node.position = at
			_field.add_child(node)
			node.build(crop, step, _reach(crop))
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


## Rows four, five and six of the difficulty table, folded into the crop's own
## gesture parameters before the target is built: the drag cone tightens
## (×0.8 per step), a twist wants more of the circle (×1.15), a dig or shake
## wants one more pass. The crop dict is deep-copied -- GameData hands out
## references, and tuning the shared copy would make the FIRST difficulty this
## session saw permanent for every level after it.
func _tuned(crop: Dictionary) -> Dictionary:
	var out: Dictionary = crop.duplicate(true)
	var params: Dictionary = out.get("gesture_params", {})
	if params.has("angle"):
		params["angle"] = harder(float(params["angle"]), 0.8)
	if params.has("turn"):
		params["turn"] = harder(float(params["turn"]), 1.15)
	if params.has("turns"):
		params["turns"] = harder_i(int(params["turns"]), 1)
	out["gesture_params"] = params
	return out


## Where he had got to, if he was here before and left in the middle.
##
## Only ONE checkpoint is kept, and only for the level it belongs to. A child
## does not sit half-finished in three levels at once, and a stale checkpoint
## from another level restoring into this one would be worse than no checkpoint
## at all.
func _restore_checkpoint() -> void:
	var mark := SaveManager.get_harvest_checkpoint()
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
	SaveManager.set_harvest_checkpoint({
		"level_id": str(level_data.get("id", "")),
		"order_index": _order_index,
		"delivered": _delivered.duplicate(),
	})


## Clear it -- the level is over, one way or the other.
func _clear_checkpoint() -> void:
	SaveManager.clear_harvest_checkpoint(str(level_data.get("id", "")))


func _load_order() -> void:
	_wanted.clear()
	_picked.clear()
	if _order_index >= _orders.size():
		return
	var order: Dictionary = _orders[_order_index]
	for entry in order.get("requirements", []):
		_wanted[str(entry.get("crop_id", ""))] = int(entry.get("count", 1))
	# Row seven of the difficulty table: at 勇敢, an order may carry one extra
	# line, written in the level's data as `brave_extra` -- typically the
	# golden one, which also has to go in the RIGHT basket. The other two
	# tiers never see the line at all. Data decides what the exception is;
	# difficulty only decides whether it is asked.
	if difficulty() == BRAVE:
		for entry in order.get("brave_extra", []):
			_wanted[str(entry.get("crop_id", ""))] = int(entry.get("count", 1))
	_refresh_order_targets()
	_rebuild_order_strip()


## Is this target allowed to answer a finger right now?
##
## The answer is shared by hit testing, the tutorial, and the field's visual
## state. Keeping it here prevents a future order from becoming a hidden second
## inventory: a crop must not disappear before the order that asks for it is on
## screen.
func _target_is_available_now(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or target.taken:
		return false
	if _is_clutter(target):
		return true
	if not Maturity.pickable(target.step, _allowed):
		return true                         # visible decoys stay teachable
	var crop_id := str(target.crop.get("id", ""))
	return _wanted.has(crop_id) and int(_picked.get(crop_id, 0)) \
		< int(_wanted[crop_id])


## Multi-order fields are planted once for a stable layout, but only the crops
## in the current order are on the glass. This removes the "pick it now, need it
## later" trap and lets the top HUD honestly describe what can be touched.
func _refresh_order_targets() -> void:
	for target in _targets:
		if not is_instance_valid(target) or target.taken:
			continue
		target.visible = _target_is_available_now(target)


## How far from the middle of a target a press still counts.
##
## The gentle setting reaches further and the brave setting less, through the
## same difficulty knob the other thirty levels use -- NOT through a second
## table of profiles, which would leave the parent's switch in the Parent
## Centre setting one thing and the harvest levels reading another.
##
## THE CROP GETS A SAY
##
## harvest_crops.json gives every crop a `touch_tolerance`, from 74 for a
## strawberry to 96 for a pumpkin, and for a long time nothing read it: one
## number, 78, for everything on the field. A pumpkin that fills half a bed was
## exactly as hard to hit as a berry the size of a thumbnail, and the data said
## otherwise in writing.
##
## `spread` is the value the field's spacing is measured against -- the biggest
## reach on the ground -- because two targets have to be far enough apart for
## the WIDEST of them, not the average.
func _reach(crop: Dictionary = {}) -> float:
	var base: float = float(crop.get("touch_tolerance", DEFAULT_REACH)) \
		if not crop.is_empty() else DEFAULT_REACH
	return harder(base, 0.77)


## The widest reach any crop on this level asks for. Spacing is measured
## against it: a pumpkin and a strawberry planted a strawberry's width apart
## would have the pumpkin claiming presses meant for the berry.
func _spread(config: Dictionary) -> float:
	var widest := DEFAULT_REACH
	for entry in config.get("targets", []):
		var crop: Dictionary = Crops.get_crop(str(entry.get("crop_id", "")))
		widest = maxf(widest, float(crop.get("touch_tolerance", DEFAULT_REACH)))
	return harder(widest, 0.77)


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

## How far down the screen the soil starts.
##
## Was 0.50, which leaves a 16:9 screen 176px of planting height -- two rows and
## no room between them. 丰收庆典 puts eighteen things on that strip and the
## grid could only get them 92px apart, exactly the floor, with the branches
## over the apple trees poking up out of the soil into the sky.
##
## Was 0.44 next: 60px more earth and the same complaint one level later -- the
## top half of the screen is sky the game never uses while the bottom strip
## holds every target, the tally and the baskets shoulder to shoulder. 0.36
## gives a 16:9 field ~277px of planting height: two roomy rows with air
## between them, and the soil still starts below the horizon so it reads as a
## field seen from slightly above. A tablet had the room already and keeps it.
const BED_TOP := 0.36


func _bed() -> Rect2:
	var view := get_viewport_rect().size
	var top: float = view.y * BED_TOP
	# Clear of the basket in the right-hand corner.
	return Rect2(110.0 + CROP_HALF, top + CROP_HALF,
		view.x - 360.0 - CROP_HALF * 2.0,
		view.y - top - 60.0 - CROP_HALF * 2.0)


func _draw_bed(mounds: Array) -> void:
	# The soil is the planting box grown back out by the inset, so the crops sit
	# ON it rather than at its edges.
	var box := _bed().grow(CROP_HALF + 14.0)
	var soil := Node2D.new()
	soil.z_index = -5
	_field.add_child(soil)
	# Body and ink edge first: everything below tints the inside and leaves
	# this rim alone, which is what seats the soil INTO the meadow instead of
	# sticking it on top like a card.
	Shapes.fill(soil, Shapes.rounded_rect(box.position, box.size, 46.0),
		Color(0.47, 0.33, 0.22), 1.0)
	# Light from above: a translucent vertical gradient over the body. Alpha,
	# not opaque, so the rim above keeps its ink.
	Shapes.gradient_quad(soil, box.position + Vector2(8, 8), box.size - Vector2(16, 16),
		Color(0.62, 0.47, 0.31, 0.5), Color(0.30, 0.20, 0.12, 0.5))
	# Furrows the garden way: soft lit ridges with shade beneath, never
	# reaching the sides. Three hard dark bars right across would be slats,
	# and slats would make this a vegetable crate -- see plot_view.gd.
	var shade := Color(0.36, 0.25, 0.16, 0.55)
	var lit := Color(0.60, 0.45, 0.30, 0.55)
	for i in range(3):
		var y: float = box.position.y + box.size.y * (float(i) + 1.0) / float(3 + 1)
		var wide: float = box.size.x * (0.72 if i == 1 else 0.60)
		Shapes.fill(soil, Shapes.oval_points(Vector2(
			box.position.x + box.size.x * 0.5, y + 4.0),
			Vector2(wide * 0.5, 7.0), 26), shade, 0.0)
		Shapes.fill(soil, Shapes.oval_points(Vector2(
			box.position.x + box.size.x * 0.5, y - 2.0),
			Vector2(wide * 0.5, 4.5), 26), lit, 0.0)
	# Crumbs. One fixed seed, so every entry into the level photographs the
	# same earth -- nothing in the planted rows is random, and the dirt they
	# sit in should not be either.
	var rng := Shapes.rng_for("harvest_soil")
	for i in range(14):
		var at := Vector2(
			box.position.x + 40.0 + fmod(float(i) * 173.0, box.size.x - 80.0),
			box.position.y + 30.0 + fmod(float(i) * 97.0, box.size.y - 60.0))
		Shapes.fill(soil, Shapes.blob(at,
			Vector2(4.0 + float(i % 3) * 1.6, 3.0 + float(i % 2) * 1.2),
			rng), shade, 0.0)
	# A mound and a contact shadow under every planting. The missing contact
	# shadow is the number-one reason a cutout looks pasted on -- this is the
	# line between "pictures of carrots" and "carrots in the ground".
	for at in mounds:
		var centre: Vector2 = at
		Shapes.ground_shadow(soil, centre + Vector2(0, 30), 92.0, 0.18)
		Shapes.fill(soil, Shapes.oval_points(centre + Vector2(0, 20),
			Vector2(48, 13), 26), Color(0.36, 0.25, 0.16, 0.9), 0.0)


## Where everything on this level goes: a jittered grid, worked out in one go.
##
## WHY A GRID AND NOT SIXTY RANDOM DARTS
##
## This used to throw a dart at the bed, check it was `apart` from everything
## already down, and after sixty misses take the roomiest miss -- however bad.
## On a crowded level that is most of them: 丰收庆典 puts eighteen things on a
## strip 796 by 176 and darts left two of them 57px apart, which is closer than
## a six-year-old can aim. The docstring above `_lay_out` has said "a loose
## grid" since the day it was written; the code underneath it never was one.
##
## A grid packs what a bed can actually hold. Eighteen at 92px apart needs nine
## columns by two rows, and 796 by 176 is exactly nine by two -- the same bed
## the darts could not manage.
##
## THE FLOOR, AND WHY IT IS NOT TWICE THE REACH
##
## `wanted` is what the level would like: twice the widest crop's reach. Unlike
## the garden's seed beds this does not have to be met -- _nearest() gives a
## press to the CLOSEST target rather than to any target in range, so reaches
## that overlap are still decided sensibly. What it does have to meet is
## THUMB_APART: two middles closer than a thumb wanders turn "I meant that one"
## from bad luck into arithmetic.
##
## So the spacing steps down from `wanted` until the grid fits, and stops at
## the floor. Jitter is whatever is left over above the floor, which is what
## keeps a field of carrots from looking like a spreadsheet.
func _plan_positions(count: int, box: Rect2, wanted: float) -> Array:
	var apart := wanted
	while apart > THUMB_APART and not _grid_holds(count, box, apart):
		apart -= 4.0
	apart = maxf(apart, THUMB_APART)

	var cols: int = maxi(1, int(floor(box.size.x / apart)) + 1)
	var rows: int = maxi(1, int(ceil(float(count) / float(cols))))
	var span := Vector2(float(cols - 1) * apart, float(rows - 1) * apart)
	var origin: Vector2 = box.position + (box.size - span) * 0.5

	# Shuffled, so that "the third one along is always the golden carrot" is
	# not a thing a child can learn instead of looking.
	var slots: Array = []
	for i in range(cols * rows):
		slots.append(origin + Vector2(float(i % cols) * apart,
			float(i / cols) * apart))
	_picker.shuffle(slots)

	# Half the slack, each way, so two neighbours can lose at most the whole
	# slack between them and still clear the floor.
	var jitter: float = maxf(0.0, (apart - THUMB_APART) * 0.5)
	var out: Array = []
	for i in range(mini(count, slots.size())):
		var at: Vector2 = slots[i]
		if jitter > 0.0:
			at += Vector2(_picker.number(-jitter, jitter),
				_picker.number(-jitter, jitter))
		# Kept inside the planting rectangle. The jitter is what stops the
		# field looking like a spreadsheet, and on a short bed it is also what
		# would tip the top row up onto the grass above the soil. Clamping only
		# ever moves a crop back towards the middle, so it cannot bring two of
		# them closer than the grid already allows.
		at.x = clampf(at.x, box.position.x, box.end.x)
		at.y = clampf(at.y, box.position.y, box.end.y)
		out.append(at)
	# More things than the bed can hold even at the floor. Stack the remainder
	# in the middle rather than dropping them -- a level missing a carrot the
	# order asks for cannot be finished at all -- and let the touch probe say
	# so, because at that point the LEVEL is too full and the data is what
	# needs changing.
	while out.size() < count:
		out.append(box.position + box.size * 0.5)
	return out


## Does a grid at this spacing have room for them all?
func _grid_holds(count: int, box: Rect2, apart: float) -> bool:
	var cols: int = maxi(1, int(floor(box.size.x / apart)) + 1)
	var rows: int = maxi(1, int(floor(box.size.y / apart)) + 1)
	return cols * rows >= count


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

	# What the order wants, as pictures and pips. No sentence to read. The route
	# lives in the same vertical group, so a taller tally on a narrow tablet can
	# never overlap the current-order marker. The whole group rides on one
	# parchment card, so the tally never has to argue with the sun behind it.
	var order_card := UiKit.card(Color(0.99, 0.97, 0.90))
	order_card.position = Vector2(204, 14)
	# A look, not a button: the tally was untouchable before and stays that
	# way, so every press still falls through to the field.
	order_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(order_card)
	var order_hud := VBoxContainer.new()
	order_hud.add_theme_constant_override("separation", 24)
	order_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_card.add_child(order_hud)

	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 16)
	order_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_hud.add_child(order_row)

	# Who the order is for, as a face. Optional per level: a level naming no
	# customer_icon simply has no face, and the tally sits where it always
	# did. IconLibrary names only (teddy/robot/paw) -- the same faces the
	# garden's order board uses, so a customer stays recognisable across
	# rooms without a word being read.
	var face: Control = UiKit.picture(str(config.get("customer_icon", "")), 72.0)
	if face != null:
		face.name = "OrderCustomer"
		order_row.add_child(face)

	_tally = HBoxContainer.new()
	_tally.add_theme_constant_override("separation", 24)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_row.add_child(_tally)

	_order_strip = HBoxContainer.new()
	_order_strip.add_theme_constant_override("separation", 14)
	_order_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_hud.add_child(_order_strip)
	_rebuild_tally()
	_rebuild_order_strip()

	_build_baskets(config)


## One basket, or several.
##
## With one, a pick flies to it on its own -- there is no decision, and asking a
## five-year-old to carry every carrot across the screen is work without a
## question in it. With two or more he chooses, and choosing is the level.
##
## THE SPACING IS ARITHMETIC, NOT A GUESS
##
## Two things a finger can hit, sitting closer together than twice their reach,
## can both claim the same press -- and the one that answers is whichever the
## loop happened to meet first. This is the third time the project has met that
## rule: the garden's beds are spaced off DragField.SNAP, the targets above are
## spaced off _reach(), and the baskets were spaced off nothing at all.
##
## What it cost: three baskets 59px apart, each with a reach of 119. The second
## and third could never be chosen -- every drop in that column answered as the
## first -- and on screen they overlapped so far they read as one striped box
## rather than as three places to put things. Sorting was impossible in every
## level that asked for it, and the screenshot agreed with the arithmetic.
##
## So the column is measured against the SOIL, which is what a child sees as
## the ground, rather than the narrow planting rectangle inside it -- nearly
## twice the room -- and the reach comes from the spacing instead of from the
## picture's size. One or two baskets stay big; three get smaller. Smaller is
## not the failure. Indistinguishable is.
func _build_baskets(config: Dictionary) -> void:
	var spec: Array = config.get("baskets", [])
	if spec.is_empty():
		spec = [{"id": "basket", "icon": "basket"}]
	var view := get_viewport_rect().size
	# Beside the field and level with it, never above it. Baskets hanging in the
	# sky was the first cut, and a basket in a cloud is not somewhere a
	# six-year-old will think to put a strawberry.
	var soil := _bed().grow(CROP_HALF + 14.0)
	var count: float = maxf(float(spec.size()), 1.0)
	var span: float = soil.size.y / count
	## Three baskets at 0.60 of their span rendered at 73px on a 16:9 screen:
	## tappable per the probe, but a picture of a basket smaller than the
	## strawberries it is asked to hold. 0.72 brings three up to ~88px and two
	## up to ~133px without moving the column: the reach below still comes from
	## the spacing, so distinguishability is unchanged.
	var size: float = minf(BASKET_SIZE, span * 0.72)
	# 0.45 and not 0.5: half the spacing would put two reaches exactly edge to
	# edge, and a press landing on that seam belongs to nobody in particular.
	var reach: float = minf(size * 0.9, span * 0.45)
	var middle: float = soil.position.y + soil.size.y * 0.5
	var top: float = middle - span * (count - 1.0) * 0.5
	for i in range(spec.size()):
		var node: Node2D = Basket.new()
		node.position = Vector2(view.x - 150.0, top + span * float(i))
		_field.add_child(node)
		node.build(spec[i], size, reach)
		_baskets.append(node)


func _rebuild_tally() -> void:
	for child in _tally.get_children():
		child.queue_free()
	_tally_pips.clear()
	for crop_id in _wanted.keys():
		var crop: Dictionary = Crops.get_crop(str(crop_id))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var art: Control = UiKit.picture(str(crop.get("asset", "")), 80.0)
		if art != null:
			box.add_child(art)
		var count := UiKit.title("%d/%d" % [int(_picked.get(crop_id, 0)),
			int(_wanted[crop_id])], 32)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(count)
		_tally.add_child(box)
		_tally_pips.append(count)


## The visual companion to `_target_is_available_now`: one chip per order is
## enough to say "done / now / later" without asking a child to read a sentence.
func _rebuild_order_strip() -> void:
	if _order_strip == null or not is_instance_valid(_order_strip):
		return
	for child in _order_strip.get_children():
		child.queue_free()
	_order_strip.visible = _orders.size() > 1
	if not _order_strip.visible:
		return
	for i in range(_orders.size()):
		var done := i < _order_index
		var current := i == _order_index
		var fill := Palette.YELLOW if current else \
			(Palette.SURFACE if done else Palette.SURFACE_SUNK)
		var chip := UiKit.card(fill)
		chip.custom_minimum_size = Vector2(64, 56)
		var marker: Control = UiKit.picture("check", 32.0) if done \
			else UiKit.title("%d" % [i + 1], 28, Palette.INK_SOFT)
		if marker is Label:
			(marker as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(marker)
		_order_strip.add_child(chip)
		if current:
			UiKit.breathe(chip, 0.025, 0.78)



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
	# With something already in his hand this touch is about a basket, so
	# nothing on the ground is being worked on -- otherwise a stroke that
	# happened to start over a potato would brush the soil off it for no
	# reason he could see.
	_holding = null if _in_hand != null and is_instance_valid(_in_hand) \
		else _nearest(at)


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

	# Something already in his hand: this touch is about where it goes, not
	# about picking anything else. See _take_in_hand for why the two are
	# separate touches.
	if _in_hand != null and is_instance_valid(_in_hand):
		_put_it_away(at)
		return

	if target == null or not is_instance_valid(target):
		return
	# A target from a later order is not an early bonus. It stays on the plant
	# until its own order is visible, so a curious tap cannot make the next order
	# impossible to finish.
	if not _target_is_available_now(target):
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

	# With one basket there is nothing to decide, so it flies there and the pick
	# is the whole move. With several, picking and putting away are two touches.
	if _baskets.size() == 1:
		_baskets[0].accept()
		target.fly_to(_baskets[0].global_position)
		_after_a_pick(target)
		return
	_take_in_hand(target)


## Picked, and now in his hand, waiting to be put somewhere.
##
## WHY PICKING AND SORTING ARE TWO TOUCHES
##
## They used to be one: the gesture picked it and wherever the finger let go
## chose the basket. Those two things cannot both be true of one stroke, and
## every level with more than one basket was unplayable because of it --
##
##   * every gesture finishes where it started or nearby (a tap does not move,
##     a pull goes up, a twist goes round, a cut goes across). None of them
##     ends over on the baskets, so letting go meant "over nothing" and the
##     crop was refused;
##   * carrying on to a basket afterwards broke the gesture instead. A tap that
##     travels is not a tap; a pull-up that turns right leaves the fan it has
##     to stay inside. So the fix for the first failure caused the second.
##
## Four of the eight levels could not be finished by any motion at all, and
## nothing said so: the logic probe checks that 34 degrees is inside the fan and
## that every order CAN be filled from what is on the ground, neither of which
## is a thumb. There was no touch probe. There is one now.
##
## Two touches also happens to be how the garden works -- one tap does one
## thing -- and how a child describes it: pick the strawberry, put it in the
## red basket. The sorting stays a real decision, which was the whole point of
## having more than one basket.
func _take_in_hand(target: Node2D) -> void:
	_in_hand = target
	_targets.erase(target)
	# One finger at a time. A gesture demo still playing is about the picking
	# half just finished, so it goes quiet and the waiting ring plus the
	# first-hold pointer below are the only answer left on screen.
	if _demo != null and is_instance_valid(_demo):
		_demo.skip()
	_demo = null
	# It rises where it grew. See HarvestTarget.lift for why it does not travel
	# somewhere tidier: a picked strawberry parked on the soil is indis-
	# tinguishable from a strawberry still growing on the soil.
	target.lift()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	# The one basket that can take this crop starts breathing. Highlighting every
	# basket would turn a sorting question into three equally loud guesses.
	for basket in _baskets:
		basket.waiting(_basket_accepts(target, basket))
	# The first pick of the run also says the loop out loud, once. The waiting
	# ring above is the permanent visual answer; this voice plus the pointing
	# finger teach "pick it, then put it in the lit basket" at the exact moment
	# he has something in his hand -- and never again this run, so the help
	# does not narrate every strawberry. Reuses the existing two-basket voice
	# and the existing Tutorial finger; no new hint system.
	if not _sort_hinted and _baskets.size() > 1:
		_sort_hinted = true
		AudioManager.say("harvest_two_baskets")
		_point_at_the_baskets()


## He tapped somewhere with a crop in his hand.
func _put_it_away(at: Vector2) -> void:
	var target := _in_hand
	var basket := _basket_for(at)
	if basket == null:
		# Not on a basket. Not a mistake either -- he may have been reaching for
		# another crop, or missed. Nothing is said and nothing is lost; the
		# finger points at where it goes instead, which is the answer to the
		# question he was actually asking.
		_point_at_the_baskets()
		return

	if not _basket_accepts(target, basket):
		basket.refuse()
		target.refuse("wrong_basket")
		return

	_in_hand = null
	for other in _baskets:
		other.waiting(false)
	basket.accept()
	target.fly_to(basket.global_position)
	_after_a_pick(target)


## Point at the baskets, without saying anything. Used when he has something in
## his hand and touched somewhere that is not a basket.
func _point_at_the_baskets() -> void:
	if _baskets.is_empty() or _in_hand == null or not is_instance_valid(_in_hand):
		return
	var destination := _destination_for(_in_hand)
	if destination == null:
		return
	var hand := Tutorial.new()
	_field.add_child(hand)
	hand.add_step(_in_hand.global_position, destination.global_position, 1.1)
	hand.play()


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


## The one source of truth for sorting. A pointer, a basket tap, and a future
## helper must never disagree about where the same crop belongs.
func _basket_accepts(target: Node2D, basket: Node2D) -> bool:
	if target == null or basket == null:
		return false
	var must := _exception_basket(target)
	return basket.id == must if must != "" else basket.takes(target.crop)


func _destination_for(target: Node2D) -> Node2D:
	for basket in _baskets:
		if _basket_accepts(target, basket):
			return basket
	return null


## Which basket that press landed on, or the only one there is.
##
## The NEAREST one in reach, not the first one in reach. With the column spaced
## properly the two answers are the same, and when they are not -- a level that
## packs four baskets in, a tablet shape nobody tried -- "nearest" degrades into
## picking the one he was aiming at, while "first" degrades into always
## answering with the top basket and never the others.
func _basket_for(at: Vector2) -> Node2D:
	if _baskets.size() == 1:
		return _baskets[0]
	var best: Node2D = null
	var best_gap := 1e9
	for basket in _baskets:
		var gap: float = basket.global_position.distance_to(at)
		if gap <= basket.radius and gap < best_gap:
			best_gap = gap
			best = basket
	return best


func _nearest(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_gap := 1e9
	for node in _targets:
		if not _target_is_available_now(node) or not node.visible:
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
	# Any refuse quiets the streak back to zero, silently. See _streak: the
	# cheer is decoration and its absence is not a punishment.
	_streak = 0
	if why == "unripe":
		_unripe_taps += 1
		AudioManager.say("harvest_not_yet")
	elif why == "wrong_basket":
		AudioManager.say("harvest_wrong_basket")
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
	if _hints != null:
		_hints.missed()


## How loud the cheer is for this streak: 0 none, 1 small, 2 big.
##
## Static and pure so the table is assertable without a screen: 3 in a row
## earns the small one, every 5th the big one, anything else nothing at all.
## Kept sparse on purpose -- a cheer on every pick is wallpaper within a
## minute, and the base class already says a warm word every 4th correct.
static func cheer_for(streak: int) -> int:
	if streak >= 5 and streak % 5 == 0:
		return 2
	if streak == 3:
		return 1
	return 0


## The streak made visible. Juice-owned visuals and one existing sfx only: no
## new voice (the base class rotates praise_1/2/3 already), no score, no coin.
func _cheer_for_streak(at: Vector2) -> void:
	match cheer_for(_streak):
		1:
			Juice.burst(_field, at, 28)
		2:
			Juice.burst(_field, at, 46)
			Juice.shockwave(_field, at, 170.0, Color(1.0, 0.94, 0.62, 0.5))
			AudioManager.play_sfx("res://assets/audio/star.ogg")


func _after_a_pick(target: Node2D) -> void:
	var crop_id := str(target.crop.get("id", ""))
	var got := maxi(int(target.crop.get("harvest_count", 1)), 1)
	_picked[crop_id] = int(_picked.get(crop_id, 0)) + got
	_targets.erase(target)
	if _hints != null:
		_hints.progress()
	_rebuild_tally()
	score_correct()
	_streak += 1
	_cheer_for_streak(target.global_position)

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
		_celebrate_order_done()
		_load_order()
		_rebuild_tally()
		return
	_finish()


## The landed order, said once in pictures: a big check that pops and fades,
## with the checkpoint write landing in the same beat ("记住啦"). Transient
## by design -- the fresh tally arriving underneath is the permanent record,
## and the last order of a level gets the result screen instead of this.
func _celebrate_order_done() -> void:
	var party := VBoxContainer.new()
	party.name = "OrderDone"
	party.alignment = BoxContainer.ALIGNMENT_CENTER
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := get_viewport_rect().size
	party.position = view * 0.5 + Vector2(-70, -160)
	party.custom_minimum_size = Vector2(140, 0)
	party.size = Vector2(140, 0)
	_hud.add_child(party)
	var tick: Control = UiKit.picture("check", 110.0)
	if tick != null:
		tick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		party.add_child(tick)
	var saved := UiKit.title(I18n.t("harvest.saved"), 30)
	saved.custom_minimum_size = Vector2(140, 0)
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party.add_child(saved)
	Juice.pop(party, 0.12)
	var t := party.create_tween()
	t.tween_interval(0.5)
	t.tween_property(party, "modulate:a", 0.0, 0.25)
	t.tween_callback(party.queue_free)


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
	_show_the_move(_teaching_target(lesson))


## The narrated lesson names a harvest gesture, so demonstrate that gesture --
## not merely whichever current crop happened to be planted first.
func _teaching_target(lesson: String) -> Node2D:
	for node in _targets:
		if _target_is_available_now(node) and node.visible \
				and str(node.crop.get("harvest_gesture", "")) == lesson:
			return node
	return _first_target()


func _first_target() -> Node2D:
	for node in _targets:
		if _target_is_available_now(node) and node.visible \
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


func _show_the_move(node: Node2D = null) -> void:
	# A hand already holding a crop has its question, and it is "which
	# basket" -- not "how to pick". Showing the picking gesture now would be
	# a second finger about the half already done, so the help points at the
	# baskets instead, exactly as the third level of help does.
	if _in_hand != null and is_instance_valid(_in_hand):
		_point_at_the_baskets()
		return
	if node == null:
		node = _first_target()
	if node == null:
		return
	var hand := Tutorial.new()
	_demo = hand
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


## Help, step three: do the hard part, and leave the last move to him.
##
## The rule the whole hint system is built on, and the one line of it that this
## template used to skip -- the body was `_show_the_move()` and nothing else,
## so a child stuck three times got the same finger animation he had already
## been shown at step two, twice, and then a third time. Three steps that are
## really two.
##
## A sorting level splits cleanly, which is what makes the rule workable here:
## getting the crop off the plant is the hard half, and deciding which basket
## it belongs in is the half worth having. So the game picks it and stops with
## it sitting in his hand.
##
## With one basket there is no split -- picking IS the level -- so it stays at
## showing the move again. That is the same answer the garden gives for a plot
## whose only remaining move is to be watered.
func _do_the_hard_part() -> void:
	# Already holding one: the hard part is behind him and what is left is the
	# choice. Choosing FOR him would be doing the whole thing.
	if _in_hand != null and is_instance_valid(_in_hand):
		_point_at_the_baskets()
		return
	if _baskets.size() > 1:
		var node := _first_target()
		if node == null:
			return
		node.taken = true
		_take_in_hand(node)
		return
	_show_the_move()
