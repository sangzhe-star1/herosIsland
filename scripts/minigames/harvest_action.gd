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
const FarmWorldArt := preload("res://scripts/garden/farm_world_art.gd")
const HarvestVisualArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const HarvestRoute := preload("res://scripts/harvest/harvest_route.gd")
const HARVEST_BACKDROP := preload("res://assets/backgrounds/harvest_meadow.png")

## Where the basket sits, against the design size. Bottom right, clear of the
## targets, in the corner a right thumb rests in.
## (BASKET_AT is the old single-basket anchor; _build_baskets() now measures
## the whole column against the soil, so this stays as a documented fallback.)
const BASKET_AT := Vector2(1140, 600)
## The biggest a basket picture gets. The column divides the soil height by the
## basket count, so three baskets still end up smaller than one -- smaller is
## not the failure, indistinguishable is (see _build_baskets).
const BASKET_SIZE := 150.0
## The shared tutorial is intentionally quieter on a crop-sized target than it
## is on the island's large buttons. Keeping this one named scale makes both
## the opening lesson and a later basket reminder read as one visual system.
const HARVEST_TUTORIAL_VISUAL_SCALE := 0.76
## The order is read from across a room and the touch probe holds this lower
## bound at both aspect ratios. The meadow must solve its hierarchy through
## placement and contrast, not by making the order itself illegible.
const ORDER_SAMPLE_SIZE := 80.0
const ORDER_COUNT_SIZE := 32
## A lifted crop should stay visually attached to the plant it came from.
## Small alpha-edge overlaps are cheaper than a large sideways jump.
const HELD_SHIFT_LIMIT := 48.0
const HELD_SHIFT_STEP := 16.0
const HELD_SHIFT_MOVE_WEIGHT := 0.50

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
var _order_customer: Control
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
## The sorting pointer is separate from `_demo`, but follows the same
## one-finger rule. Re-pointing after a missed tap replaces this one instead
## of leaving a small crowd of hands over the field.
var _basket_pointer: Tutorial = null

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

var _harvest_3d_vp: SubViewport
var _harvest_3d_world: Node3D
var _harvest_3d_cam: Camera3D


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

	_stage = _build_harvest_stage(config)
	_field = UiKit.play_area(self, true)
	_add_harvest_backdrop()
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


## The harvest camera looks down into a low meadow, while the ordinary park
## camera looks across a broad lawn. Reuse Stage and WorldStyle, but locally
## raise their horizon so crops grow out of land instead of open sky.
func _build_harvest_stage(config: Dictionary) -> Stage:
	var style := WorldStyle.for_world(str(level_data.get("world", "sunny_park")) )
	style.apply_config(config)
	style.calm = 0.30
	style.horizon = 0.38
	style.prop_band = 0.12
	style.props = []
	style.prop_density = 0.0
	style.grass_tuft_density = 1.18
	style.flower_density = 0.10
	# Coloured pollen dots read as loose stickers in a deliberately quiet
	# harvest meadow. Weather still owns its real rain/snow motes.
	if str(config.get("weather", "")) == "":
		style.mote_kind = "none"
	return Stage.build(self, style, str(level_data.get("id", "harvest")))


## A user-approved artwork layer is scoped to this fixed harvest screen only.
## Now rendered with a genuine 3D diorama (harvest_meadow.glb) with soft Nordic lighting
## and shadows, while keeping 2D interaction nodes in _field above it.
func _add_harvest_backdrop() -> void:
	var glb_path := "res://assets/scenes_3d/harvest_meadow.glb"
	if ResourceLoader.exists(glb_path):
		var vp_container := SubViewportContainer.new()
		vp_container.name = "HarvestMeadow3DBackdrop"
		vp_container.stretch = true
		vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp_container.z_index = -20

		var vp := SubViewport.new()
		vp.name = "SubViewport"
		vp.own_world_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.size = Vector2i(1280, 720)
		vp_container.add_child(vp)

		var world_root := Node3D.new()
		world_root.name = "World3D"
		vp.add_child(world_root)

		var glb_scene: PackedScene = load(glb_path)
		if glb_scene != null:
			var glb_inst: Node = glb_scene.instantiate()
			world_root.add_child(glb_inst)

		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.28, 0.55, 0.88)
		sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.96)
		sky_mat.ground_bottom_color = Color(0.26, 0.38, 0.22)
		sky_mat.ground_horizon_color = Color(0.68, 0.74, 0.65)
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.34
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.glow_enabled = false

		var env_node := WorldEnvironment.new()
		env_node.environment = env
		world_root.add_child(env_node)

		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35.0, -28.0, 0.0)
		sun.light_color = Color(1.0, 0.96, 0.90)
		sun.light_energy = 0.76
		sun.shadow_enabled = true
		sun.shadow_blur = 1.8
		sun.shadow_bias = 0.03
		world_root.add_child(sun)

		var cam := Camera3D.new()
		cam.position = Vector3(0.0, 5.2, 11.2)
		cam.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
		cam.fov = 38.0
		cam.current = true
		world_root.add_child(cam)

		_harvest_3d_vp = vp
		_harvest_3d_world = world_root
		_harvest_3d_cam = cam

		_field.add_child(vp_container)
		_field.move_child(vp_container, 0)
		return

func _screen_to_ground_3d(screen_pos: Vector2, ground_y: float = 0.12) -> Vector3:
	if _harvest_3d_cam == null:
		return Vector3.ZERO
	var ray_origin := _harvest_3d_cam.project_ray_origin(screen_pos)
	var ray_normal := _harvest_3d_cam.project_ray_normal(screen_pos)
	if absf(ray_normal.y) < 0.0001:
		return Vector3.ZERO
	var t := (ground_y - ray_origin.y) / ray_normal.y
	return ray_origin + ray_normal * t

	var backdrop := TextureRect.new()
	backdrop.name = "HarvestMeadowBackdrop"
	backdrop.texture = HARVEST_BACKDROP
	var tablet_backdrop := "res://assets/backgrounds/harvest_meadow_4x3.png"
	var viewport_size := get_viewport_rect().size
	if viewport_size.x / viewport_size.y < 1.55 \
			and ResourceLoader.exists(tablet_backdrop):
		backdrop.texture = load(tablet_backdrop) as Texture2D
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -20
	_field.add_child(backdrop)
	_field.move_child(backdrop, 0)


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
	# A fourth order sample can widen the folder on brave. Put the clock in
	# the free upper-right HUD corner so the folder never clips its digits.
	_clock.position = Vector2(get_viewport_rect().size.x - 172.0, 40.0)
	_clock.size = Vector2(140, 34)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_clock)


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
	var spots := _plan_positions(count, _planting_bounds(config),
		_spread(config) * 2.0 + 20.0)
	var art_scale := _crop_art_scale_for_spacing(spots)
	spots = _assign_visual_spots(plan, spots, art_scale, config)
	var next := 0

	# The earth is drawn from the same spots the crops are planted on, so
	# every mound below sits under exactly one crop.
	var mound_layers := _draw_bed(spots, _root_widths_for_plan(plan, art_scale))

	for entry in plan:
		var crop: Dictionary = _tuned(entry["crop"])
		var step: String = entry["step"]
		for i in range(int(entry["count"])):
			var spot_index := next
			var at: Vector2 = spots[spot_index] if spot_index < spots.size() \
				else _bed().position + _bed().size * 0.5
			next += 1
			var node: Node2D = Target.new()
			node.position = at
			_field.add_child(node)
			node.build(crop, step, _reach(crop), art_scale)
			if spot_index < mound_layers.size():
				node.set_meta("visual_mound", mound_layers[spot_index])
			_add_passive_plant(node, art_scale)
			node.picked.connect(_on_picked)
			node.refused.connect(_on_refused)
			_targets.append(node)
			_bind_3d_crop(node, crop, step)

	# One order, or several in a row. A level with several is a level with
	# checkpoints: each one that lands is written to disk before the next
	# appears, so a tablet that dies in the middle of the celebration level
	# costs the current order and never the two already delivered.
	_orders = config.get("orders", [])
	if _orders.is_empty():
		_orders = [{"requirements": config.get("order", [])}]
	_restore_checkpoint()
	_load_order()


func _bind_3d_crop(node: Node2D, crop: Dictionary, _step: String) -> void:
	if _harvest_3d_world == null or _harvest_3d_cam == null:
		return
	var crop_id := str(crop.get("id", "carrot"))
	var glb_path := "res://assets/harvest_3d/runtime_candidates/crops/%s.glb" % crop_id
	if not ResourceLoader.exists(glb_path):
		glb_path = "res://assets/harvest_3d/runtime_candidates/crops/carrot.glb"
	if not ResourceLoader.exists(glb_path):
		return
	var c_scene: PackedScene = load(glb_path)
	if c_scene == null:
		return
	var c_inst: Node3D = c_scene.instantiate() as Node3D
	if c_inst == null:
		return
	_harvest_3d_world.add_child(c_inst)
	var p3d := _screen_to_ground_3d(node.position, -0.18)
	c_inst.position = p3d

	var c_scale := 1.25
	if crop_id == "pumpkin" or crop_id == "watermelon":
		c_scale = 1.05
	elif crop_id == "strawberry":
		c_scale = 1.35
	elif crop_id == "carrot" or crop_id == "golden_carrot":
		c_scale = 1.20
	c_inst.scale = Vector3(c_scale, c_scale, c_scale)
	c_inst.rotation_degrees.y = randf_range(-25.0, 25.0)

	node.set_meta("crop_3d", c_inst)
	node.tree_exited.connect(func():
		if is_instance_valid(c_inst):
			c_inst.queue_free()
	)

	# Hide flat 2D sprite so real 3D mesh is seen
	var art_node := node.get_node_or_null("HarvestTargetVisual/HarvestCrop3DArt")
	if art_node == null:
		art_node = node.get_node_or_null("HarvestTargetVisual/HarvestPlantFruit3DArt")
	if art_node != null:
		art_node.modulate.a = 0.0


## Pictures shrink in dense rows; touch radii and gesture distances stay in
## the crop data. The nearest target rule still chooses the same target.
func _crop_art_scale_for_spacing(spots: Array) -> float:
	var closest := INF
	for i in range(spots.size()):
		var a: Vector2 = spots[i]
		for j in range(i + 1, spots.size()):
			var b: Vector2 = spots[j]
			closest = minf(closest, a.distance_to(b))
	return 0.8 if closest < 112.0 else 1.0


## Refine seeded slot ownership using the visible artwork for every order.
## The existing positions, radius, RNG and input rules stay authoritative.

const VISUAL_SLOT_MAX_SWAPS := 4
const VISUAL_SLOT_OVERLAP_ALLOWANCE := 0.05
const VISUAL_SLOT_EDGE_WEIGHT := 12.0
const VISUAL_SLOT_BASKET_WEIGHT := 6.0
const VISUAL_SLOT_ROOT_MARGIN := 12.0
const VISUAL_ROW_BALANCE_WEIGHT := 2.0
const VISUAL_ROW_BALANCE_BAND := 72.0


func _assign_visual_spots(plan: Array, spots: Array, art_scale: float,
		config: Dictionary) -> Array:
	var orders := _visual_order_requirements(config)
	var items := _visual_slot_items(plan, art_scale, orders)
	var count := items.size()
	if count != spots.size() or count < 2:
		return spots
	var row_count := _visual_row_count(spots)
	var visible_masks := _visual_slot_visibility(plan, orders)
	var obstacles := _visual_basket_obstacles(config)
	var screen := get_viewport_rect()
	var terms := _visual_pair_terms(items, orders.size(), visible_masks,
		_visual_row_balance_enabled(str(level_data.get("id", "")), row_count))
	var unary: Array = []
	var assignment: Array[int] = []
	for i in range(count):
		assignment.append(i)
		var costs: Array[float] = []
		for spot in spots:
			costs.append(_visual_fixed_cost(items[i], spot, screen, obstacles,
				orders.size()))
		unary.append(costs)

	# Cache the current pair costs. A candidate swap computes only its new
	# contributions, rather than rescoring the entire n-by-n assignment.
	var pair_costs: Array = []
	for i in range(count):
		var row: Array[float] = []
		row.resize(count)
		row.fill(0.0)
		pair_costs.append(row)
	for i in range(count):
		for j in range(i + 1, count):
			var cost := _visual_pair_cost(terms, count, i, j, spots[i], spots[j])
			pair_costs[i][j] = cost
			pair_costs[j][i] = cost

	# Fixed cap: O(4*n^3*p^2), p <= 3 parts per current target. A tie retains
	# the existing seeded assignment, and this function never reads the picker.
	for pass_index in range(VISUAL_SLOT_MAX_SWAPS):
		var best_delta := -0.00001
		var best_a := -1
		var best_b := -1
		for i in range(count):
			for j in range(i + 1, count):
				var a: int = assignment[i]
				var b: int = assignment[j]
				var delta: float = unary[i][b] - unary[i][a] \
					+ unary[j][a] - unary[j][b]
				delta += _visual_pair_cost(terms, count, i, j, spots[b], spots[a]) \
					- float(pair_costs[i][j])
				for k in range(count):
					if k == i or k == j:
						continue
					var at: Vector2 = spots[assignment[k]]
					delta += _visual_pair_cost(terms, count, i, k, spots[b], at) \
						- float(pair_costs[i][k])
					delta += _visual_pair_cost(terms, count, j, k, spots[a], at) \
						- float(pair_costs[j][k])
				if delta < best_delta - 0.00001:
					best_delta = delta
					best_a = i
					best_b = j
		if best_a < 0:
			break
		var old_slot: int = assignment[best_a]
		assignment[best_a] = assignment[best_b]
		assignment[best_b] = old_slot
		for changed in [best_a, best_b]:
			for k in range(count):
				if changed == k:
					continue
				var cost := _visual_pair_cost(terms, count, changed, k,
					spots[assignment[changed]], spots[assignment[k]])
				pair_costs[changed][k] = cost
				pair_costs[k][changed] = cost
	var out: Array = []
	for slot in assignment:
		out.append(spots[slot])
	return out


func _visual_order_requirements(config: Dictionary) -> Array:
	var definitions: Array = config.get("orders", [])
	if definitions.is_empty():
		definitions = [{"requirements": config.get("order", [])}]
	var orders: Array = []
	for definition in definitions:
		orders.append(_requirements_for_order(definition))
	return orders


func _visual_slot_items(plan: Array, art_scale: float, orders: Array) -> Array:
	var items: Array = []
	for entry in plan:
		var crop: Dictionary = entry["crop"]
		var step := Maturity.normalise(str(entry["step"]))
		var id := str(crop.get("id", ""))
		var visible: Array[bool] = []
		for wanted in orders:
			visible.append(_crop_is_available_for_order(crop, step, wanted, {}))
		var plant := HarvestVisualArt.plant_layout(id, art_scale)
		var parts: Array = []
		var root_at := Vector2(0.0, 42.0)
		var root_width := 48.0
		var root_visible: Array[bool] = visible.duplicate()
		var look := Maturity.look(step, crop)
		var maturity_scale := float(look.get("scale", 1.0))
		if not plant.is_empty():
			# A picked target is freed, while its field-sibling plant remains.
			# Conservatively retain the body's first-visible phase onward; this
			# also covers partial-order surplus without another state controller.
			var persistent: Array[bool] = []
			var has_appeared := false
			for phase_visible in visible:
				has_appeared = has_appeared or phase_visible
				persistent.append(has_appeared)
			parts.append({"rect": HarvestVisualArt.texture_used_bounds(plant["body"],
				plant["body_size"], plant["slot_pixel"]),
				"visible": persistent, "importance": 1.0})
			parts.append({"rect": HarvestVisualArt.texture_used_bounds(plant["fruit"],
				float(plant["fruit_size"]) * maturity_scale,
				plant["fruit_center_pixel"]), "visible": visible, "importance": 1.0})
			root_at = plant["ground_at"]
			root_width = clampf(HarvestVisualArt.texture_ground_width(plant["body"],
				plant["body_size"]) + 4.0, 48.0, 86.0)
			root_visible = persistent
		else:
			var size := 90.0 * maturity_scale * clampf(art_scale, 0.6, 1.0)
			var texture := HarvestVisualArt.crop_texture(id)
			var rect := HarvestVisualArt.texture_used_bounds(texture, size,
				Vector2(256.0, HarvestVisualArt.GROUND_ORIGIN_PIXEL_Y), root_at)
			if texture == null:
				rect = Rect2(Vector2.ONE * (-size * 0.5), Vector2.ONE * size)
			parts.append({"rect": rect, "visible": visible, "importance": 1.0})
			if str(crop.get("recogniser", "")) == Gesture.SWEEP \
					and str(crop.get("sweep_cover", "soil")) == "soil":
				var cover := HarvestVisualArt.soil_cover_layout(size)
				if not cover.is_empty():
					parts.append({"rect": cover["rect"], "visible": visible,
						"importance": 1.0})
			root_width = clampf(HarvestVisualArt.crop_ground_width(id, size) + 4.0,
				48.0, 86.0)
		# Include the actual hollow at +3px and the 0.92*width ground shadow
		# at +6px (outer y radius 0.15*0.92*width), not only the lit oval.
		var root_bottom := maxf(11.0, 6.0 + root_width * 0.138)
		parts.append({"rect": Rect2(root_at + Vector2(-root_width * 0.5 - 4.0, -10.0),
			Vector2(root_width + 8.0, root_bottom + 10.0)),
			"visible": root_visible, "importance": 0.4,
			"root": true})
		for instance_index in range(int(entry["count"])):
			items.append(parts)
	return items


func _visual_basket_obstacles(config: Dictionary) -> Array:
	var definitions: Array = config.get("baskets", [])
	var count := maxi(definitions.size(), 1)
	var soil := _bed().grow(CROP_HALF + 14.0)
	var size := minf(BASKET_SIZE, soil.size.y / float(count) * 0.72)
	var texture := HarvestVisualArt.prop_texture("basket_empty")
	var basket := HarvestVisualArt.texture_used_bounds(texture, size,
		Vector2(256.0, HarvestVisualArt.GROUND_ORIGIN_PIXEL_Y),
		Vector2(0.0, size * 0.52))
	if texture == null:
		basket = Rect2(Vector2(-size * 0.65, -size * 0.8),
			Vector2(size * 1.3, size * 1.4))
	var obstacles: Array = []
	for at in _basket_positions(count, soil):
		obstacles.append(Rect2(basket.position + at, basket.size))
	return obstacles


func _visual_slot_visibility(plan: Array, orders: Array) -> Array:
	var masks: Array = []
	for entry in plan:
		var crop: Dictionary = entry["crop"]
		var step := Maturity.normalise(str(entry["step"]))
		var mask: Array[bool] = []
		for wanted in orders:
			mask.append(_crop_is_available_for_order(crop, step, wanted, {}))
		for _instance_index in range(int(entry["count"])):
			masks.append(mask.duplicate())
	return masks


func _visual_row_count(spots: Array) -> int:
	var ordered: Array = spots.duplicate()
	ordered.sort_custom(func(a, b): return (a as Vector2).y < (b as Vector2).y)
	var rows := 0
	var previous_y := -INF
	for value in ordered:
		var point: Vector2 = value
		if rows == 0 or point.y - previous_y > VISUAL_ROW_BALANCE_BAND:
			rows += 1
		previous_y = point.y
	return rows


func _visual_row_balance_enabled(id: String, row_count: int) -> bool:
	# This correction has only been A/B validated on the celebration level's
	# multi-phase ownership map. Keep the scope explicit until another four-row
	# level has its own aspect-ratio and touch review.
	return id == "harvest_08" and row_count >= 4


func _visual_pair_terms(items: Array, phase_count: int, visible_masks: Array,
		balance_rows: bool) -> Array:
	var count := items.size()
	var terms: Array = []
	terms.resize(count * count)
	for i in range(count):
		for j in range(i + 1, count):
			var pair: Array = []
			for a in items[i]:
				for b in items[j]:
					var common := 0
					for phase in range(phase_count):
						if a["visible"][phase] and b["visible"][phase]:
							common += 1
					if common > 0:
						pair.append({"a": a["rect"], "b": b["rect"],
							"weight": float(common) / float(maxi(phase_count, 1)) \
							* minf(float(a["importance"]), float(b["importance"]))})
			if balance_rows:
				var co_visible_phases := 0
				for phase in range(phase_count):
					if visible_masks[i][phase] and visible_masks[j][phase]:
						co_visible_phases += 1
				if co_visible_phases > 0:
					pair.append({"row_balance": true,
						"weight": float(co_visible_phases)})
			terms[i * count + j] = pair
	return terms


func _visual_pair_cost(terms: Array, count: int, i: int, j: int,
		a_at: Vector2, b_at: Vector2) -> float:
	if i > j:
		return _visual_pair_cost(terms, count, j, i, b_at, a_at)
	var cost := 0.0
	var pair: Array = terms[i * count + j]
	for term in pair:
		if bool(term.get("row_balance", false)):
			if absf(a_at.y - b_at.y) <= VISUAL_ROW_BALANCE_BAND:
				cost += float(term["weight"]) * VISUAL_ROW_BALANCE_WEIGHT
			continue
		var a: Rect2 = term["a"]
		var b: Rect2 = term["b"]
		cost += _visual_overlap_loss(Rect2(a.position + a_at, a.size),
			Rect2(b.position + b_at, b.size)) * float(term["weight"])
	return cost


func _visual_fixed_cost(parts: Array, at: Vector2, screen: Rect2,
		obstacles: Array, phase_count: int) -> float:
	var cost := 0.0
	for part in parts:
		var active := 0
		for visible in part["visible"]:
			if visible:
				active += 1
		if active == 0:
			continue
		var local_rect: Rect2 = part["rect"]
		var rect := Rect2(local_rect.position + at, local_rect.size)
		var allowed := screen.grow(-VISUAL_SLOT_ROOT_MARGIN) \
			if bool(part.get("root", false)) else screen
		var outside := 1.0 - rect.intersection(allowed).get_area() \
			/ maxf(rect.get_area(), 1.0)
		var weight := float(active) / float(maxi(phase_count, 1))
		cost += maxf(outside, 0.0) * VISUAL_SLOT_EDGE_WEIGHT * weight
		for obstacle in obstacles:
			cost += _visual_overlap_loss(rect, obstacle) \
				* VISUAL_SLOT_BASKET_WEIGHT * weight
	return cost


func _visual_overlap_loss(a: Rect2, b: Rect2) -> float:
	if not a.intersects(b):
		return 0.0
	var smaller := minf(a.get_area(), b.get_area())
	if smaller <= 0.0:
		return 0.0
	return maxf(a.intersection(b).get_area() / smaller \
		- VISUAL_SLOT_OVERLAP_ALLOWANCE, 0.0)

func _root_widths_for_plan(plan: Array, art_scale: float) -> Array:
	var widths: Array = []
	for entry in plan:
		var crop: Dictionary = entry["crop"]
		var look := Maturity.look(str(entry["step"]), crop)
		var size := 90.0 * float(look.get("scale", 1.0)) * art_scale
		var id := str(crop.get("id", ""))
		var plant := HarvestVisualArt.plant_layout(id, art_scale)
		var footprint := HarvestVisualArt.crop_ground_width(id, size)
		if not plant.is_empty():
			footprint = HarvestVisualArt.texture_ground_width(plant["body"], plant["body_size"])
		var width := clampf(footprint + 4.0, 48.0, 86.0)
		for i in range(int(entry["count"])):
			widths.append(width)
	return widths


func _add_passive_plant(target: Node2D, art_scale: float) -> void:
	var plant := HarvestVisualArt.plant_layout(str(target.crop.get("id", "")), art_scale)
	if plant.is_empty():
		return
	var body := Node2D.new()
	body.name = "HarvestPlantBody"
	body.position = target.position
	body.z_index = -1
	_field.add_child(body)
	var art := HarvestVisualArt.anchored_sprite(plant["body"], plant["body_size"],
		plant["slot_pixel"], Vector2.ZERO, "HarvestPlantBody3DArt")
	body.add_child(art)
	target.set_meta("visual_plant", body)
	# A fruit must visibly clear the plant even when its detached render is
	# much smaller than the body's canvas. Use their actual alpha extents and
	# the same final held scale; do not alter planting or touch coordinates.
	var body_bounds := HarvestVisualArt.texture_used_bounds(plant["body"],
		plant["body_size"], plant["slot_pixel"])
	var look := Maturity.look(target.step, target.crop)
	var fruit_bounds := HarvestVisualArt.texture_used_bounds(plant["fruit"],
		float(plant["fruit_size"]) * float(look.get("scale", 1.0)),
		plant["fruit_center_pixel"])
	target.set_meta("visual_lift_clearance", maxf(46.0,
		fruit_bounds.end.y * Target.HELD_SCALE - body_bounds.position.y + 16.0))
	var mound: Node2D = target.get_meta("visual_mound") as Node2D \
		if target.has_meta("visual_mound") else null
	if mound != null:
		mound.position += Vector2(plant["ground_at"]) - Vector2(0.0, 42.0)


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


func _requirements_for_order(order: Dictionary) -> Dictionary:
	var wanted: Dictionary = {}
	for entry in order.get("requirements", []):
		wanted[str(entry.get("crop_id", ""))] = int(entry.get("count", 1))
	if difficulty() == BRAVE:
		for entry in order.get("brave_extra", []):
			wanted[str(entry.get("crop_id", ""))] = int(entry.get("count", 1))
	return wanted


func _crop_is_available_for_order(crop: Dictionary, step: String,
		wanted: Dictionary, picked: Dictionary) -> bool:
	if "clutter" in crop.get("tags", []):
		return true
	if not Maturity.pickable(step, _allowed):
		return true
	var crop_id := str(crop.get("id", ""))
	return wanted.has(crop_id) and int(picked.get(crop_id, 0)) \
		< int(wanted[crop_id])


func _load_order() -> void:
	_wanted.clear()
	_picked.clear()
	if _order_index >= _orders.size():
		return
	_wanted.merge(_requirements_for_order(_orders[_order_index]))
	_refresh_order_targets()
	_rebuild_order_strip()
	_refresh_order_customer()


## A relay changes the portrait inside the same HUD slot. Ordinary orders
## inherit the level's customer, including when resuming a saved delivery.
func _current_customer_reference() -> String:
	var config: Dictionary = level_data.get("config", {})
	var fallback := str(config.get("customer_icon", ""))
	if _order_index < 0 or _order_index >= _orders.size():
		return fallback
	return str((_orders[_order_index] as Dictionary).get("customer_icon", fallback))


func _refresh_order_customer() -> void:
	# The first order is loaded before the HUD is built. A later order may
	# introduce its own customer even when the level has no default portrait.
	if not is_instance_valid(_tally):
		return
	var reference := _current_customer_reference()
	if is_instance_valid(_order_customer) \
			and str(_order_customer.get_meta("customer_reference", "")) == reference:
		return
	var portrait: Control
	if reference.begins_with("res://assets/harvest_3d/props/") and reference.ends_with(".png"):
		portrait = HarvestVisualArt.prop_badge(reference.get_file().get_basename(), 72.0,
			"CustomerPortrait")
	else:
		portrait = UiKit.picture(reference, 72.0)
	# No customer means no node or empty layout slot, as in the original
	# single-order lessons. A relay with real portraits keeps the same slot.
	if portrait == null:
		if is_instance_valid(_order_customer):
			_order_customer.get_parent().remove_child(_order_customer)
			_order_customer.queue_free()
		_order_customer = null
		return
	if not is_instance_valid(_order_customer):
		_order_customer = Control.new()
		_order_customer.name = "OrderCustomer"
		_order_customer.custom_minimum_size = Vector2(72.0, 72.0)
		_order_customer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := _tally.get_parent()
		row.add_child(_order_customer)
		row.move_child(_order_customer, _tally.get_index())
	var previous := _order_customer.get_node_or_null("CustomerPortrait")
	if previous != null:
		_order_customer.remove_child(previous)
		previous.queue_free()
	_order_customer.set_meta("customer_reference", reference)
	portrait.name = "CustomerPortrait"
	_order_customer.add_child(portrait)


## Is this target allowed to answer a finger right now?
##
## The answer is shared by hit testing, the tutorial, and the field's visual
## state. Keeping it here prevents a future order from becoming a hidden second
## inventory: a crop must not disappear before the order that asks for it is on
## screen.
func _target_is_available_now(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or target.taken:
		return false
	return _crop_is_available_for_order(target.crop, target.step, _wanted, _picked)


## Multi-order fields are planted once for a stable layout, but only the crops
## in the current order are on the glass. This removes the "pick it now, need it
## later" trap and lets the top HUD honestly describe what can be touched.
func _refresh_order_targets() -> void:
	for target in _targets:
		if not is_instance_valid(target) or target.taken:
			continue
		var available := _target_is_available_now(target)
		target.visible = available
		var mound: Variant = target.get_meta("visual_mound", null)
		if mound is CanvasItem:
			(mound as CanvasItem).visible = available
		var plant: Variant = target.get_meta("visual_plant") \
			if target.has_meta("visual_plant") else null
		if plant is CanvasItem:
			(plant as CanvasItem).visible = available


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


## The bed rectangle anchors basket stations and the right-hand planting limit.
## Crop centres use a wider, screen-relative meadow band so the order card and
## baskets keep their space while the field uses the open grass between them.
const CROP_HALF := 62.0

## Basket stations remain anchored to the lower field reference. Crop centres
## use a separate screen-relative meadow band without moving the baskets.
const BED_TOP := 0.43
## Includes the order folder's card and shadow in the authored 1280-wide HUD.
const HARVEST_HUD_SAFE_BOTTOM := 204.0
const HARVEST_HUD_TOUCH_MARGIN := 24.0


func _bed() -> Rect2:
	var view := get_viewport_rect().size
	var top: float = view.y * BED_TOP
	# Clear of the basket in the right-hand corner.
	return Rect2(110.0 + CROP_HALF, top + CROP_HALF,
		view.x - 360.0 - CROP_HALF * 2.0,
		view.y - top - 60.0 - CROP_HALF * 2.0)


## Three destinations extend further into the meadow than a basket column.
## Plan the grid in its final rectangle so every 92px gap survives; moving or
## squeezing an already jittered grid could violate that spacing floor.
func _planting_bounds(config: Dictionary) -> Rect2:
	var bed := _bed()
	var view := get_viewport_rect().size
	var y_bounds := _safe_meadow_y_bounds(view.y, _spread(config))
	var box := Rect2(Vector2(bed.position.x, y_bounds.x),
		Vector2(bed.size.x, maxf(y_bounds.y - y_bounds.x, 0.0)))
	for entry in config.get("targets", []):
		if not HarvestVisualArt.plant_layout(str(entry.get("crop_id", "")), 1.0).is_empty():
			# Reserve the passive plant root shadow before planning any points.
			box.size.y = maxf(box.size.y - 8.0, 0.0)
			break
	var specs: Array = config.get("baskets", [])
	if specs.size() < 3:
		return box
	var soil := _bed().grow(CROP_HALF + 14.0)
	var span := soil.size.y / float(specs.size())
	var basket_size := minf(BASKET_SIZE, span * 0.72)
	var right := box.end.x
	for basket_at in _basket_positions(specs.size(), soil):
		right = minf(right, basket_at.x - basket_size * 0.64 - 14.0 - CROP_HALF - 2.0)
	# Keep the 180px transparent crop canvas inside the window and preserve a
	# broad clear lane beside the basket column.
	var left := 102.0
	return Rect2(Vector2(left, box.position.y), Vector2(right - left, box.size.y))


static func _safe_meadow_y_bounds(view_height: float, max_touch_radius: float) -> Vector2:
	var top := maxf(view_height * 0.34,
		HARVEST_HUD_SAFE_BOTTOM + max_touch_radius + HARVEST_HUD_TOUCH_MARGIN)
	# Let the lower row use more of the field. The former 76% cutoff left a
	# conspicuous empty strip below the crops, while the plant-root artwork still
	# has room before the viewport edge at 81%.
	return Vector2(top, maxf(top, view_height * 0.81))


func _draw_bed(mounds: Array, root_widths: Array = []) -> Array:
	# Crop positions and hit testing share the final planting rectangle. The scene is
	# part of the same park as the garden, not a brown panel placed over it: each
	# crop gets a small root patch, while Stage keeps one continuous meadow.
	var soil := Node2D.new()
	soil.z_index = -5
	_field.add_child(soil)
	# These are a little darker than the grass, not opaque brown labels. The
	# shadow and low-contrast warm earth say "rooted" while leaving the meadow
	# visually continuous behind the crop art.
	var earth_shadow := Color(0.34, 0.28, 0.17, 0.32 * 0.85)
	var earth_lit := Color(0.62, 0.48, 0.29, 0.39 * 0.85)
	var earth_hollow := Color(0.25, 0.20, 0.13, 0.13 * 0.85)
	# The procedural Stage fallback benefits from a faint row cue. The selected
	# meadow backdrop already carries its own ground depth; adding another band
	# on top made it read as a translucent sticker, so keep only the root marks.
	var backdrop := _field.get_node_or_null("HarvestMeadowBackdrop") as TextureRect
	if backdrop == null or backdrop.texture == null:
		_draw_meadow_rows(soil, mounds)
	# The source crop art's roots sit near +42 rather than at its centre, so the
	# soft soil is visibly below the crop instead of looking like a badge stuck
	# on its middle.
	const FOOT_Y := 42.0
	var patches: Array = []
	for i in range(mounds.size()):
		var at: Vector2 = mounds[i]
		var width: float = float(root_widths[i]) if i < root_widths.size() else 72.0
		var mound := Node2D.new()
		mound.name = "HarvestMound"
		mound.position = at
		soil.add_child(mound)
		patches.append(mound)
		# A separate 3D grass pad reads as a little platform against the
		# watercolor meadow. Keep the contact detail in this page's flat paint
		# language until a same-source 3D ground plane replaces the backdrop.
		Shapes.ground_shadow(mound, Vector2(2.0, FOOT_Y + 6.0), width * 0.92, 0.065)
		Shapes.fill(mound, Shapes.oval_points(Vector2(2.0, FOOT_Y + 3.0),
			Vector2(width * 0.5, 8.0), 24), earth_hollow, 0.0)
		Shapes.fill(mound, Shapes.oval_points(Vector2(1.0, FOOT_Y),
			Vector2(width * 0.48, 8.0), 24), earth_shadow, 0.0)
		Shapes.lit(mound, Shapes.oval_points(Vector2(-2.0, FOOT_Y - 4.0),
			Vector2(width * 0.48, 6.0), 24), earth_lit, 0.0)
	return patches


## Two or three loose rows organise a busy order. They are grass pressed by
## gardening, not closed soil panels: their colour stays close to Stage's
## meadow and their edges leave the screen instead of becoming another card.
func _draw_meadow_rows(parent: Node2D, mounds: Array) -> void:
	var ordered: Array = mounds.duplicate()
	ordered.sort_custom(func(a, b): return a.y < b.y)
	var rows: Array = []
	var wanted_rows := clampi(int(ceil(float(ordered.size()) / 5.0)), 1, 3)
	var gaps: Array = []
	for i in range(maxi(ordered.size() - 1, 0)):
		gaps.append({"after": i, "size": ordered[i + 1].y - ordered[i].y})
	gaps.sort_custom(func(a, b): return float(a["size"]) > float(b["size"]))
	var starts: Dictionary = {0: true}
	for i in range(mini(wanted_rows - 1, gaps.size())):
		starts[int(gaps[i]["after"]) + 1] = true
	for i in range(ordered.size()):
		if starts.has(i):
			rows.append([])
		(rows[rows.size() - 1] as Array).append(ordered[i])

	for row in rows:
		if row.size() < 2:
			continue
		var y := 0.0
		var left := INF
		var right := -INF
		for member in row:
			var at: Vector2 = member
			y += at.y
			left = minf(left, at.x)
			right = maxf(right, at.x)
		y = y / float(row.size()) + 42.0
		# Follow only the crop roots, not the whole viewport: a full-width
		# ribbon reads as lawn striping and competes with the plants.
		var run := maxf(right - left, 1.0)
		# End underneath the outer root patches instead of exposing capped tips.
		var inset := minf(14.0, run * 0.12)
		var x0 := left + inset
		var x1 := right - inset
		var bend := clampf(run * 0.025, 8.0, 18.0)
		var sweep := PackedVector2Array([
			Vector2(x0, y + 2.0),
			Vector2(lerpf(x0, x1, 0.34), y - bend),
			Vector2(lerpf(x0, x1, 0.68), y + bend * 0.55),
			Vector2(x1, y - 1.0),
		])
		Shapes.fill(parent, Shapes.ribbon(sweep, 56.0),
			Color(0.38, 0.58, 0.34, 0.10), 0.0)
		Shapes.fill(parent, Shapes.ribbon(sweep, 22.0),
			Color(0.72, 0.83, 0.50, 0.06), 0.0)


## Where everything on this level goes: a jittered grid, worked out in one go.
##
## WHY A GRID AND NOT SIXTY RANDOM DARTS
##
## The former random placement could pack two centres 57px apart on crowded
## orders, closer than a six-year-old can aim. Use a balanced grid and reduce
## the requested spacing only as far as the 92px touch-centre floor.
##
## A grid packs what the meadow can actually hold. Its row count is chosen for
## the screen shape and target count, then balanced rows are centred so a short
## row never leaves a lonely crop at one edge.
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
	var view := get_viewport_rect().size
	var preferred_rows := _preferred_grid_rows(count, view.x / maxf(view.y, 1.0))
	var fitted := _fit_grid_shape(count, box, wanted, preferred_rows)
	var apart := float(fitted["apart"])
	var rows := int(fitted["rows"])
	var slots := _balanced_grid_points(count, box, apart, rows)

	# Shuffled, so that "the third one along is always the golden carrot" is
	# not a thing a child can learn instead of looking.
	_picker.shuffle(slots)

	# Half the slack, each way, so two neighbours can lose at most the whole
	# spacing above the floor and still clear it. Use the widest row to keep
	# every shuffled point inside the same safe jitter envelope.
	var jitter: float = maxf(0.0, (apart - THUMB_APART) * 0.5)
	var row_counts := _balanced_row_counts(count, rows)
	var widest := 0
	for row_count in row_counts:
		widest = maxi(widest, row_count)
	var jitter_x := minf(jitter,
		maxf(0.0, box.size.x - float(maxi(widest - 1, 0)) * apart) * 0.5)
	var jitter_y := minf(jitter,
		maxf(0.0, box.size.y - float(rows - 1) * apart) * 0.5)
	var out: Array = []
	for i in range(mini(count, slots.size())):
		var at: Vector2 = slots[i]
		if jitter_x > 0.0 or jitter_y > 0.0:
			at += Vector2(_picker.number(-jitter_x, jitter_x),
				_picker.number(-jitter_y, jitter_y))
		# Kept inside the planting rectangle. The jitter is what stops the
		# field looking like a spreadsheet, and on a short bed it is also what
		# would tip the top row outside the safe meadow band. Clamping only
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


## Screens with more width get fewer rows; a tall 4:3 screen can use another
## row before the field becomes too wide to scan. Small orders remain legible.
static func _preferred_grid_rows(count: int, aspect: float) -> int:
	if count <= 1:
		return 1
	if aspect >= 1.55:
		if count <= 4:
			return 1
		if count <= 12:
			return 2
		if count <= 18:
			return 3
		return 4
	if count <= 3:
		return 1
	if count <= 6:
		return 2
	if count <= 12:
		return 3
	return 4


## Rows share extras symmetrically when possible: 11 becomes 4/3/4 and 18 in
## four rows becomes 5/4/4/5. The result is deterministic and easy to probe.
static func _balanced_row_counts(count: int, rows: int) -> Array[int]:
	var safe_rows := maxi(rows, 1)
	var result: Array[int] = []
	result.resize(safe_rows)
	result.fill(int(floor(float(count) / float(safe_rows))))
	var extras := count % safe_rows
	var order: Array[int] = []
	if safe_rows % 2 == 1 and extras % 2 == 1:
		order.append(int(floor(float(safe_rows) * 0.5)))
	var left := 0
	var right := safe_rows - 1
	while left <= right:
		if left == right:
			if not order.has(left):
				order.append(left)
		else:
			if not order.has(left):
				order.append(left)
			if not order.has(right):
				order.append(right)
		left += 1
		right -= 1
	for i in range(extras):
		result[order[i]] += 1
	return result


## Pick the requested row count while preserving the 92px touch-centre floor.
## If the box is unusually narrow or short, add rows before declaring it full.
static func _fit_grid_shape(count: int, box: Rect2, wanted: float,
		preferred_rows: int) -> Dictionary:
	var max_rows := maxi(1, int(floor(box.size.y / THUMB_APART)) + 1)
	var rows := clampi(preferred_rows, 1, max_rows)
	while true:
		var apart := maxf(wanted, THUMB_APART)
		while apart > THUMB_APART and not _grid_shape_holds(count, box, apart, rows):
			apart -= 4.0
		apart = maxf(apart, THUMB_APART)
		if _grid_shape_holds(count, box, apart, rows) or rows >= max_rows:
			return {"rows": rows, "apart": apart}
		rows += 1
	return {"rows": rows, "apart": THUMB_APART}


## Does this balanced row shape fit at the requested centre spacing?
static func _grid_shape_holds(count: int, box: Rect2, apart: float,
		rows: int) -> bool:
	if count <= 0 or rows <= 0 or apart <= 0.0:
		return count <= 0
	var row_counts := _balanced_row_counts(count, rows)
	var widest := 0
	for row_count in row_counts:
		widest = maxi(widest, row_count)
	var span_x := float(maxi(widest - 1, 0)) * apart
	var span_y := float(maxi(rows - 1, 0)) * apart
	return span_x <= box.size.x and span_y <= box.size.y


## One centred point row by row. Unequal rows naturally stagger by half a slot,
## giving diagonally adjacent crops more than the 92px centre minimum.
static func _balanced_grid_points(count: int, box: Rect2, apart: float,
		rows: int) -> Array:
	var row_counts := _balanced_row_counts(count, rows)
	var out: Array = []
	var span_y := float(maxi(rows - 1, 0)) * apart
	var first_y := box.position.y + (box.size.y - span_y) * 0.5
	for row_index in range(row_counts.size()):
		var row_count := int(row_counts[row_index])
		var span_x := float(maxi(row_count - 1, 0)) * apart
		var first_x := box.position.x + (box.size.x - span_x) * 0.5
		for column in range(row_count):
			out.append(Vector2(first_x + float(column) * apart,
				first_y + float(row_index) * apart))
	return out


func _build_hud(config: Dictionary) -> void:
	_order_customer = null
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UiKit.theme()
	layer.add_child(_hud)

	var back := UiKit.back_button(func(): quit_level(), Vector2(84, 68))
	back.position = Vector2(24, 24)
	_hud.add_child(back)

	# The order card is a folder with a page tab, not another floating status
	# panel. Add the tab first so the card naturally overlaps its lower edge;
	# both are passive HUD paint and the field keeps the same input path.
	var folder_tab := Panel.new()
	folder_tab.name = "OrderFolderTab"
	folder_tab.position = Vector2(190.0, 0.0)
	folder_tab.custom_minimum_size = Vector2(120.0, 28.0)
	folder_tab.size = folder_tab.custom_minimum_size
	folder_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.84, 0.69, 0.43)
	tab_style.set_corner_radius_all(10)
	tab_style.border_color = Color(0.56, 0.41, 0.24, 0.68)
	tab_style.set_border_width_all(1)
	tab_style.shadow_color = Color(0.12, 0.10, 0.06, 0.16)
	tab_style.shadow_size = 7
	tab_style.shadow_offset = Vector2(0.0, 3.0)
	folder_tab.add_theme_stylebox_override("panel", tab_style)
	_hud.add_child(folder_tab)

	# What the order wants, as pictures and pips. No sentence to read. The route
	# lives in the same vertical group, so a taller tally on a narrow tablet can
	# never overlap the current-order marker. The whole group rides on one
	# parchment card, so the tally never has to argue with the sun behind it.
	var order_card := UiKit.card(Color(0.99, 0.97, 0.90))
	order_card.position = Vector2(156, 14)
	var folder_style := UiKit.panel_style(Color(0.99, 0.97, 0.90), 24)
	folder_style.border_color = Color(0.63, 0.49, 0.29, 0.42)
	folder_style.set_border_width_all(1)
	order_card.add_theme_stylebox_override("panel", folder_style)
	# A look, not a button: the tally was untouchable before and stays that
	# way, so every press still falls through to the field.
	order_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(order_card)
	var order_hud := HBoxContainer.new()
	order_hud.add_theme_constant_override("separation", 18)
	order_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_card.add_child(order_hud)

	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 16)
	order_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_hud.add_child(order_row)

	_tally = HBoxContainer.new()
	_tally.add_theme_constant_override("separation", 24)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_row.add_child(_tally)
	_refresh_order_customer()

	_order_strip = HBoxContainer.new()
	_order_strip.add_theme_constant_override("separation", 14)
	_order_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var route_wrap := CenterContainer.new()
	route_wrap.custom_minimum_size = Vector2(142, 112)
	route_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_wrap.add_child(_order_strip)
	order_hud.add_child(route_wrap)
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
	var positions := _basket_positions(spec.size(), soil)
	FarmWorldArt.draw_harvest_basket_station(_field, positions, size)
	for i in range(spec.size()):
		var node: Node2D = Basket.new()
		node.position = positions[i]
		_field.add_child(node)
		node.build(spec[i], size, reach)
		_baskets.append(node)
		if _harvest_3d_world != null:
			var b_glb := "res://assets/harvest_3d/runtime/basket.glb"
			if ResourceLoader.exists(b_glb):
				var b_scene: PackedScene = load(b_glb)
				if b_scene != null:
					var b_inst: Node3D = b_scene.instantiate() as Node3D
					if b_inst != null:
						_harvest_3d_world.add_child(b_inst)
						b_inst.position = _screen_to_ground_3d(positions[i], 0.06)
						var b_scale: float = 1.25 * (size / 130.0)
						b_inst.scale = Vector3(b_scale, b_scale, b_scale)
						b_inst.set_meta("base_scale", b_inst.scale)
						node.set_meta("basket_3d", b_inst)
						node.tree_exited.connect(func():
							if is_instance_valid(b_inst):
								b_inst.queue_free()
						)
						var b_art := node.get_node_or_null("HarvestBasket3DArt")
						if b_art != null:
							b_art.modulate.a = 0.0


## A vertical stack made the baskets look like a toolbar clipped onto the
## meadow. Two or three real destinations fit in a shallow collection nook,
## still outside the crop bed and further apart than their independently
## measured reaches. One basket stays exactly where the original simple level
## taught it.
func _basket_positions(count: int, soil: Rect2) -> Array:
	var view := get_viewport_rect().size
	var middle := soil.position.y + soil.size.y * 0.5
	if count <= 1:
		return [Vector2(view.x - 150.0, middle)]
	if count == 2:
		var span := soil.size.y * 0.5
		return [
			Vector2(view.x - 150.0, middle - span * 0.5),
			Vector2(view.x - 150.0, middle + span * 0.5),
		]
	if count == 3:
		return [
			Vector2(view.x - 270.0, soil.position.y + soil.size.y * 0.60),
			Vector2(view.x - 100.0, soil.position.y + soil.size.y * 0.60),
			Vector2(view.x - 185.0, soil.position.y + soil.size.y * 0.88),
		]
	# Current level data stops at three baskets. Keep an honest, reachable
	# fallback if a future author adds more before designing a new station.
	var positions: Array = []
	for i in range(count):
		positions.append(Vector2(view.x - 150.0,
			soil.position.y + soil.size.y * (float(i) + 0.5) / float(count)))
	return positions


func _rebuild_tally() -> void:
	for child in _tally.get_children():
		child.queue_free()
	_tally_pips.clear()
	for crop_id in _wanted.keys():
		var crop: Dictionary = Crops.get_crop(str(crop_id))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var art: Control = HarvestVisualArt.crop_badge(str(crop.get("id", crop_id)),
			ORDER_SAMPLE_SIZE, "OrderCrop3DBadge")
		if art == null:
			art = UiKit.picture(str(crop.get("asset", "")), ORDER_SAMPLE_SIZE)
		if art != null:
			box.add_child(art)
		var count := UiKit.title("%d/%d" % [int(_picked.get(crop_id, 0)),
			int(_wanted[crop_id])], ORDER_COUNT_SIZE)
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
		if target.has_meta("crop_3d") and _baskets[0].has_meta("basket_3d"):
			var c3d: Node3D = target.get_meta("crop_3d")
			var b3d: Node3D = _baskets[0].get_meta("basket_3d")
			if is_instance_valid(c3d) and is_instance_valid(b3d):
				c3d.set_meta("basket_pos_3d", b3d.position)
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
	_clear_basket_pointer()
	# It rises where it grew. See HarvestTarget.lift for why it does not travel
	# somewhere tidier: a picked strawberry parked on the soil is indis-
	# tinguishable from a strawberry still growing on the soil.
	if target.has_meta("visual_plant"):
		target.set_meta("visual_held_shift", _clear_held_plant_shift(target))
	if target.has_meta("crop_3d") and not _baskets.is_empty():
		var c3d: Node3D = target.get_meta("crop_3d", null) as Node3D
		if c3d != null and is_instance_valid(c3d):
			var dest_basket: Node2D = _destination_for(target)
			if dest_basket == null:
				dest_basket = _baskets[0]
			var b_pos_3d := _screen_to_ground_3d(dest_basket.position, 0.45)
			c3d.set_meta("basket_pos_3d", b_pos_3d)
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


## Keep a detached fruit near its growing point while clearing neighbouring
## artwork. This uses the existing field and changes only the held transform.
func _clear_held_plant_shift(target: Node2D) -> Vector2:
	var art: TextureRect = target.get("_art") as TextureRect
	if art == null:
		return Vector2.ZERO
	var obstacles: Array[Rect2] = []
	for child in _field.get_children():
		var body_art := child.get_node_or_null("HarvestPlantBody3DArt") as TextureRect
		if body_art != null and body_art.is_visible_in_tree():
			obstacles.append(_world_art_bounds(body_art).grow(4.0))
	for other: Node2D in _targets:
		var other_art: TextureRect = other.get("_art") as TextureRect
		if other_art != null and other_art.is_visible_in_tree():
			obstacles.append(_world_art_bounds(other_art).grow(4.0))
	for basket: Node2D in _baskets:
		var basket_art := basket.get_node_or_null("HarvestBasket3DArt") as TextureRect
		if basket_art != null:
			obstacles.append(_world_art_bounds(basket_art).grow(8.0))
	# Score the actual visible crop silhouette, not the oversized square implied
	# by held_art_radius(). The latter made a 1px alpha-bound intersection look
	# like a collision across most of a 100x100 disk and could push fruit 128px
	# away from its rooted plant. Predict the existing lift and held scale here.
	var fruit_bounds := _scale_rect_about_point(_world_art_bounds(art),
		target.global_position, Target.HELD_SCALE).grow(3.0)
	fruit_bounds.position.y -= target.held_lift_height()
	var screen := get_viewport_rect().grow(-24.0)
	var best := Vector2.ZERO
	var best_score := INF
	var candidates: Array[float] = [0.0]
	var steps := int(ceil(HELD_SHIFT_LIMIT / HELD_SHIFT_STEP))
	for step_index in range(1, steps + 1):
		var offset := minf(float(step_index) * HELD_SHIFT_STEP, HELD_SHIFT_LIMIT)
		candidates.append(-offset)
		candidates.append(offset)
	for x in candidates:
		var shift := Vector2(x, 0.0)
		var bounds := Rect2(fruit_bounds.position + shift, fruit_bounds.size)
		var move_cost_per_pixel := maxf(minf(bounds.size.x, bounds.size.y), 1.0) \
			* HELD_SHIFT_MOVE_WEIGHT
		var score := absf(x) * move_cost_per_pixel
		if not screen.encloses(bounds):
			score += 100000.0
		for obstacle in obstacles:
			if bounds.intersects(obstacle):
				score += bounds.intersection(obstacle).get_area()
		if score < best_score:
			best_score = score
			best = shift
	return best


func _scale_rect_about_point(bounds: Rect2, origin: Vector2, factor: float) -> Rect2:
	var corners: Array[Vector2] = [
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]
	var first := origin + (corners[0] - origin) * factor
	var result := Rect2(first, Vector2.ZERO)
	for index in range(1, corners.size()):
		var point := origin + (corners[index] - origin) * factor
		result = result.expand(point)
	return result


func _world_art_bounds(art: TextureRect) -> Rect2:
	if art.texture == null:
		return Rect2()
	var image := art.texture.get_image()
	if image == null or image.is_empty():
		return art.get_global_transform() * Rect2(Vector2.ZERO, art.size)
	var used := Rect2(image.get_used_rect())
	if used.size.x <= 0.0 or used.size.y <= 0.0:
		return Rect2()
	# Crop and plant sprites can be anchored to a Blender source pixel rather
	# than centred in their canvas. Measure the real alpha bounds in the
	# TextureRect's local coordinates; applying a centered source anchor here
	# moves the route obstacle away from the image that is actually on screen.
	var factor := art.size / Vector2(image.get_size())
	var local := Rect2(used.position * factor, used.size * factor)
	var transform := art.get_global_transform()
	var corners: Array[Vector2] = [
		transform * local.position,
		transform * Vector2(local.end.x, local.position.y),
		transform * local.end,
		transform * Vector2(local.position.x, local.end.y),
	]
	var left := corners[0].x
	var top := corners[0].y
	var right := corners[0].x
	var bottom := corners[0].y
	for corner in corners:
		left = minf(left, corner.x)
		top = minf(top, corner.y)
		right = maxf(right, corner.x)
		bottom = maxf(bottom, corner.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


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
	_clear_basket_pointer()
	for other in _baskets:
		other.waiting(false)
	basket.accept()
	if target.has_meta("crop_3d") and basket.has_meta("basket_3d"):
		var c3d: Node3D = target.get_meta("crop_3d")
		var b3d: Node3D = basket.get_meta("basket_3d")
		if is_instance_valid(c3d) and is_instance_valid(b3d):
			c3d.set_meta("basket_pos_3d", b3d.position)
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
	_clear_basket_pointer()
	var hand := Tutorial.new()
	# The crops are deliberately compact here, so reuse the lesson director at
	# its compact scale instead of allowing the global hero glove to hide the
	# destination basket.
	hand.set_visual_scale(HARVEST_TUTORIAL_VISUAL_SCALE)
	hand.set_look_radius(_in_hand.held_art_radius() + 12.0)
	hand.set_route_visible_in_motion(true)
	var hint_anchor := _held_crop_hint_anchor(_in_hand)
	var route_start: Vector2 = hint_anchor["world"]
	hand.follow_look_target(_in_hand, hint_anchor["local"])
	_basket_pointer = hand
	_field.add_child(hand)
	hand.add_path(route_start,
		_basket_hint_route(_in_hand, destination), 1.1)
	hand.finished.connect(_on_basket_pointer_finished.bind(hand.get_instance_id()))
	hand.play()


## Route and LOOK share the visible held-fruit anchor. In motion mode the
## target is still at the start of its lift when this runs, so plan from its
## settled pose; reduced motion has already placed it there synchronously.
func _held_crop_hint_anchor(target: Node2D) -> Dictionary:
	var art := target.get("_art") as TextureRect
	if art == null or art.texture == null:
		return {"world": target.global_position, "local": Vector2.ZERO}
	var local_anchor := target.to_local(_world_art_bounds(art).get_center())
	var held_origin := target.global_position
	if Juice.motion_enabled():
		held_origin += target.held_lift_displacement()
	var parent := target.get_parent() as CanvasItem
	var parent_transform := parent.get_global_transform() \
		if parent != null else Transform2D.IDENTITY
	var held_visual_offset := parent_transform.basis_xform(
		local_anchor * Target.HELD_SCALE)
	return {"world": held_origin + held_visual_offset, "local": local_anchor}


## Keep the temporary basket route clear of live crop silhouettes. The real
## gesture, basket resolver and accepted target remain owned by HarvestAction.
func _basket_hint_route(target: Node2D, destination: Node2D) -> PackedVector2Array:
	var obstacles: Array = []
	# Picking removes the fruit from `_targets`, but its plant is deliberately
	# left rooted in the field. Keep that sibling in the route geometry so the
	# basket pointer does not draw through the crop he just picked.
	var held_plant: Node2D
	if target.has_meta("visual_plant"):
		held_plant = target.get_meta("visual_plant") as Node2D
	if held_plant != null:
		var held_body_art := held_plant.get_node_or_null(
			"HarvestPlantBody3DArt") as TextureRect
		if held_body_art != null and held_body_art.is_visible_in_tree():
			obstacles.append(_world_art_bounds(held_body_art))
	for other: Node2D in _targets:
		if other == target or not other.is_visible_in_tree():
			continue
		var fruit_art := other.get("_art") as TextureRect
		if fruit_art != null and fruit_art.is_visible_in_tree():
			obstacles.append(_world_art_bounds(fruit_art))
		var plant: Variant = other.get_meta("visual_plant") \
			if other.has_meta("visual_plant") else null
		if plant is Node2D:
			var body_art := (plant as Node2D).get_node_or_null(
				"HarvestPlantBody3DArt") as TextureRect
			if body_art != null and body_art.is_visible_in_tree():
				obstacles.append(_world_art_bounds(body_art))
	for basket: Node2D in _baskets:
		if basket == destination:
			continue
		var basket_art := basket.get_node_or_null("HarvestBasket3DArt") as TextureRect
		if basket_art != null and basket_art.is_visible_in_tree():
			obstacles.append(_world_art_bounds(basket_art))
	var start: Vector2 = _held_crop_hint_anchor(target)["world"]
	# The teaching hand points into the basket mouth, not at its stitched-on
	# sample tag. `_basket_for()` and the real hit radius continue to use the
	# basket origin; this is only the route's visual endpoint.
	var finish := destination.global_position
	finish.y -= maxf(float(destination.get("_size")) * 0.38, 30.0)
	var route_bounds := _field.get_global_transform() * Rect2(Vector2.ZERO, _field.size)
	var route := HarvestRoute.avoid_rectangles(start, finish, obstacles, 14.0,
		route_bounds.grow(-24.0))
	return route


func _on_basket_pointer_finished(pointer_id: int) -> void:
	if is_instance_valid(_basket_pointer) \
			and _basket_pointer.get_instance_id() == pointer_id:
		_basket_pointer = null


func _clear_basket_pointer() -> void:
	if _basket_pointer == null:
		return
	var pointer := _basket_pointer
	_basket_pointer = null
	if is_instance_valid(pointer):
		pointer.skip()


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
	var mound: Variant = target.get_meta("visual_mound", null)
	var plant: Variant = target.get_meta("visual_plant") \
		if target.has_meta("visual_plant") else null
	if mound is CanvasItem and not (plant is CanvasItem):
		(mound as CanvasItem).visible = false
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	Juice.burst(_field, target.global_position, 16)
	Juice.dust(_field, target.global_position, 8, 1.2)


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
	_show_customer_happy()

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


## The customer is the third beat of an order: the same face that wanted the
## crops gets a small heart when they arrive. Attach it to the existing avatar
## so it follows the HUD at every aspect ratio and cannot cover the field.
## Reduced-motion mode keeps the heart still while preserving the feedback.
func _show_customer_happy() -> void:
	if _order_customer == null or not is_instance_valid(_order_customer):
		return
	var heart: Control = UiKit.picture("heart", 40.0)
	if heart == null:
		return
	heart.name = "CustomerHappyHeart"
	heart.size = Vector2(40.0, 40.0)
	heart.position = Vector2(42.0, -10.0)
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.z_index = 4
	heart.pivot_offset = heart.size * 0.5
	_order_customer.add_child(heart)
	if not Juice.motion_enabled():
		var lifetime := heart.create_tween()
		lifetime.tween_interval(0.8)
		lifetime.tween_callback(heart.queue_free)
		return
	heart.modulate.a = 0.0
	heart.scale = Vector2(0.55, 0.55)
	var reaction := heart.create_tween()
	reaction.tween_property(heart, "position", Vector2(44.0, -34.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.parallel().tween_property(heart, "modulate:a", 1.0, 0.12)
	reaction.parallel().tween_property(heart, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.tween_interval(0.34)
	reaction.tween_property(heart, "modulate:a", 0.0, 0.20)
	reaction.tween_callback(heart.queue_free)


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
	# This is the same shared gesture teacher used across the game, just scaled
	# to the 90px crop vocabulary on the harvest meadow.
	hand.set_visual_scale(HARVEST_TUTORIAL_VISUAL_SCALE)
	_demo = hand
	_field.add_child(hand)
	hand.add_path(node.global_position, _gesture_path(node), 1.2)
	hand.play()


## The teacher and the recogniser consult the same crop parameters. Keeping
## this one small bridge in the action scene lets the touch probe verify the
## exact path that `_show_the_move()` sends to TutorialDirector.
func _gesture_path(node: Node2D) -> PackedVector2Array:
	var params: Dictionary = node.crop.get("gesture_params", {})
	return Gesture.demo_path(str(node.crop.get("recogniser", "")), params,
		node.global_position, float(node.get("radius")))


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
