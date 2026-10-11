extends LevelManager
## 星光菜园 -- four patches of earth, and the five things a child does to them.
##
## WHY TAPPING A PLOT DOES NOT NEED A TOOL FIRST
##
## Every other farming game gives you a tool rack and asks you to pick the hoe
## before you can hoe. That is one extra decision per action, and the failure
## it creates -- watering with the trowel, nothing happening, no idea why -- is
## exactly the failure a six-year-old cannot debug.
##
## So a plot has one thing it wants at any moment, it says what that is with a
## picture, and tapping it does that. Untilled earth gets turned. Thirsty
## ground gets watered. Weeds get pulled. Ripe crops get picked. There is no
## wrong tap, because there is nothing to choose.
##
## Planting is the exception, and deliberately: dragging a seed from the rack
## into the ground is the one action where WHICH one matters, and the drag is
## what makes choosing it feel like putting something in the earth rather than
## picking from a menu.
##
##
## WHY THE WHOLE SCREEN IS REBUILT AFTER EVERY ACTION
##
## Four plots and a seed rack is not enough on screen to be worth diffing, and
## a rebuild cannot leave a stale badge behind saying a plot is thirsty after
## it has been watered. DragField's slots are registered once when it is built,
## so a rebuild is also the honest way to change which plots will accept a seed.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const PlotCare := preload("res://scripts/garden/farm_plot_care_controller.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")
const FarmWorld := preload("res://scripts/garden/farm_world_controller.gd")
const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
const ToolTargetView := preload("res://scripts/garden/farm_tool_target_view.gd")
const Stroke := preload("res://scripts/garden/continuous_action_controller.gd")
const PlotGesture := preload("res://scripts/garden/plot_gesture_controller.gd")
const PlotAction := preload("res://scripts/garden/farm_plot_action_controller.gd")
const SeedShop := preload("res://scripts/garden/seed_shop_manager.gd")
const Market := preload("res://scripts/garden/farm_market_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")
const ArrivalSettlement := preload("res://scripts/garden/farm_arrival_settlement_controller.gd")
const FacilityAction := preload("res://scripts/garden/farm_facility_action_controller.gd")
const BuildingAction := preload("res://scripts/garden/farm_building_action_controller.gd")
const FarmTick := preload("res://scripts/garden/farm_tick_controller.gd")
const WellWish := preload("res://scripts/garden/farm_well_wish_controller.gd")
const BearReturn := preload("res://scripts/garden/farm_bear_return_controller.gd")
const CollectionFeedback := preload("res://scripts/garden/farm_collection_feedback_controller.gd")
const DogManager := preload("res://scripts/garden/farm_dog_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const DailyClaim := preload("res://scripts/garden/farm_daily_claim_controller.gd")
const DailyProgress := preload("res://scripts/garden/farm_daily_progress_controller.gd")
const BarnUpgrade := preload("res://scripts/garden/farm_barn_upgrade_controller.gd")
const HarvestTransaction := preload("res://scripts/garden/farm_harvest_transaction_controller.gd")
const OrderDelivery := preload("res://scripts/garden/farm_order_delivery_controller.gd")
const OrderBoard := preload("res://scripts/garden/farm_order_board_controller.gd")
const NextTask := preload("res://scripts/garden/farm_next_task_controller.gd")
const PendingUndo := preload("res://scripts/garden/farm_pending_undo_controller.gd")
const Lesson := preload("res://scripts/garden/farm_lesson_controller.gd")
const PlantingContext := preload("res://scripts/garden/farm_planting_context_controller.gd")
const PlantingTransaction := preload("res://scripts/garden/farm_planting_transaction_controller.gd")
const FarmOrdersPanel := preload("res://scripts/garden/panels/farm_orders_panel.gd")
const FarmShopPanel := preload("res://scripts/garden/panels/farm_shop_panel.gd")
const FarmMarketPanel := preload("res://scripts/garden/panels/farm_market_panel.gd")
const FarmBarnPanel := preload("res://scripts/garden/panels/farm_barn_panel.gd")
const FarmVisitPanel := preload("res://scripts/garden/panels/farm_visit_panel.gd")
const FarmRecipesPanel := preload("res://scripts/garden/panels/farm_recipes_panel.gd")
const FarmKitchenPanel := preload("res://scripts/garden/panels/farm_kitchen_panel.gd")
const FarmChallengePanel := preload("res://scripts/garden/panels/farm_challenge_panel.gd")
const FarmHeaderPanel := preload("res://scripts/garden/panels/farm_header_panel.gd")
const FarmGiftPanel := preload("res://scripts/garden/panels/farm_gift_panel.gd")
const FarmSeedRackPanel := preload("res://scripts/garden/panels/farm_seed_rack_panel.gd")
const FarmToolRackPanel := preload("res://scripts/garden/panels/farm_tool_rack_panel.gd")
const FarmPanelBase := preload("res://scripts/garden/panels/farm_panel_base.gd")
const FarmExpansionPanel := preload("res://scripts/garden/panels/farm_expansion_panel.gd")
const FarmUndoPanel := preload("res://scripts/garden/panels/farm_undo_panel.gd")
const FarmNextTaskPanel := preload("res://scripts/garden/panels/farm_next_task_panel.gd")
const FarmViewControlsPanel := preload("res://scripts/garden/panels/farm_view_controls_panel.gd")
const FarmDecorationsView := preload("res://scripts/garden/farm_decorations_view.gd")
const FarmLessonView := preload("res://scripts/garden/farm_lesson_view.gd")
const FarmLessonSession := preload("res://scripts/garden/farm_lesson_session_controller.gd")
const FarmHintActions := preload("res://scripts/garden/farm_hint_action_controller.gd")
const FarmProgressNoticeView := preload("res://scripts/garden/farm_progress_notice_view.gd")
const FarmPanelState := preload("res://scripts/garden/farm_panel_state_controller.gd")

const SEED_TILE := FarmSeedRackPanel.TILE_SIZE
## The old 96px header plus 168px shelf left less than two thirds of a 16:9
## tablet for the island. These are compact *lanes*, not smaller touch targets:
## the buttons inside keep their child-friendly hit boxes.
const TOP_BAR := 68.0
const SHELF := FarmBarnPanel.SHELF_HEIGHT

## Paged surfaces: six rows on the shop sheet, fourteen seed slots on the
## dense possession row. The usual whole seed collection fits at once.
const PANEL_PAGE := 6

## How often the garden asks the clock again once the lesson is over. Growth is
## still worked out from timestamps and nothing accumulates frame by frame --
## the tick only re-runs the same arithmetic the entry settle runs, so a bed
## whose minute arrived while he was watering another one turns ripe IN FRONT
## of him instead of on his next visit, and a plant inched taller while he
## watches. Twenty seconds: slow enough that it reads as the farm being alive
## rather than as a machine polling, fast enough that a stage boundary lands
## within half a minute of its time.
const GARDEN_TICK := 20.0

## How long a plot stays untappable after being picked. Long enough to cover
## the crops flying into the barn, short enough that a child who taps twice on
## purpose is not left wondering why the second one did nothing.
const HARVEST_LOCK_SECONDS := 0.45

## Compatibility query used by the screen probe; probability lives with the
## planting context, not in this presentation script.
func _golden_chance() -> float:
	var dailies: Dictionary = _farm().get("dailies", {})
	return PlantingContext.golden_chance(dailies)

var _field: DragField
var _play: Control
## Short-lived collection feedback survives the UI rebuild that immediately
## redraws the empty bed and barn count. It is a screen layer, not a second
## animation system: labels and crop art still come from UiKit/Juice.
var _harvest_feedback: CanvasLayer
var _collection_feedback = CollectionFeedback.new()
var _shelf: Control
var _rebuild_queued := false
## The farm itself: ground, buildings and beds, all of which move together when
## the picture is dragged. Built ONCE and kept -- see _rebuild for why it is
## the one thing on this screen that does not get thrown away.
var _world: FarmWorld
## The invisible Node2Ds a dropped seed clicks into, one per bed that will take
## one. They live in screen space because DragField measures the release
## against node.position and the release is a point on the glass; they are
## moved to follow the beds whenever the camera does (see _follow_the_camera).
var _drop_targets: Array = []
## Only one paper panel can cover the farm. These read-only views preserve the
## screen seam used by panel presenters and touch probes while the controller
## owns the actual route and its aliases.
var _panel_state := FarmPanelState.new()
var _orders_open: bool:
	get:
		return _panel_state.is_open("orders")
var _challenges_open: bool:
	get:
		return _panel_state.is_open("challenges")
var _challenge_page := 0
var _shop_open: bool:
	get:
		return _panel_state.is_open("shop")
var _market_open: bool:
	get:
		return _panel_state.is_open("market")
var _barn_open: bool:
	get:
		return _panel_state.is_open("barn")
var _barn_show_overflow: bool:
	get:
		return _panel_state.barn_show_overflow
var _visit_open: bool:
	get:
		return _panel_state.is_open("visits")
var _recipes_open: bool:
	get:
		return _panel_state.is_open("recipes")
var _kitchen_open: bool:
	get:
		return _panel_state.is_open("kitchen")
var _gift_open: bool:
	get:
		return _panel_state.is_open("gift")
var _gift_basket: Dictionary = {}
var _confirm_cook := ""
## Shop, recipe and kitchen sheets show six rows at a time. The rack holds
## all fourteen familiar seeds and keeps the same pager for future additions.
## Each sheet returns to its first page when its door opens.
var _shop_page := 0
var _book_page := 0
var _kitchen_page := 0
var _rack_page := 0
## Which crop's confirm card is up in the shop ("" for none).
var _confirm_crop := ""
## Whether the barn's upgrade confirm card is up.
var _confirm_upgrade := false
## Which expansion slot's confirm card is up, -1 for none.
var _confirm_expand := -1
## What he has dragged into the market box this visit: crop_id -> count.
## Nothing leaves the barn until 卖掉 is pressed -- closing the panel forgets
## this and loses NOTHING.
var _market_sell: Dictionary = {}
## One stepper row per crop in the box, keyed by crop id: {"row": Node,
## "count": Label}. Rows live in the receipt's scroll area; a rebuild frees
## them with the panel, then `_market_panel` repopulates from the basket.
var _market_rows: Dictionary = {}
var _market_rows_scroll: ScrollContainer
var _market_scroll_offset := 0
var _market_rows_list: VBoxContainer
var _market_drop_hint: Label
var _market_total: Label
## The panel handles market events; the screen owns the basket across rebuilds.
var _market_ui: RefCounted
## The market's own drag field, so crops can be dragged into the box with the
## same hands-feel as everything else. Separate from the rack's _field: each
## grabs only its own pieces.
var _market_field: DragField
## The regret receipt lives through a rebuild and is consumed once by its
## controller. This property remains for the panel and existing probe seam.
var _undo_flow := PendingUndo.new()
var _pending_undo: Dictionary:
	get:
		return _undo_flow.current()
	set(value):
		_undo_flow.set_pending(value)
## Buttons the probes press by name instead of by hunting coordinates.
var _panel_buttons: Dictionary = {}
## Which tool is in his hand and which crop the seed brush plants. Survives
## every rebuild on purpose -- the toolbar is furniture, the CHOICE is not.
var _tools := Tools.new()
## The bookkeeping of one brush stroke. See continuous_action_controller.gd.
var _stroke := Stroke.new()
## tool id -> its Button, rebuilt with the rest of the furniture. The probe
## reads this instead of guessing at coordinates.
var _tool_buttons: Dictionary = {}
## The tool drawer is closed by default; the hand and the tools for the current
## task stay on the shelf, while the complete rack remains one tap away.
var _tool_rack_expanded := false
## The running count while a harvest stroke is going, and the label showing it.
var _combo := 0
## Where picked crops fly to: the barn shortcut is the honest home for food.
## The basket tool harvests; it does not store the harvest.
var _barn_button_at := Vector2.ZERO

## plot_id -> true while its harvest animation is running. In memory only, on
## purpose: see _tap_plot. Cleared HARVEST_LOCK_SECONDS after the pick.
var _harvesting: Dictionary = {}
## Whether anything has been picked or delivered this visit. The rest hint is
## offered once, after something good happens, and never on the way in.
var _harvested_something := false
var _rest_offered := false
## The graded helper. Watches for a child who has stopped doing anything and
## nudges, then shows, then does the hard part -- the same escalation the
## thirty main levels use, so the garden does not teach a second language.
var _hints: Hints
## The first planting is a visit-long session, not a temporary animation.
var _lesson_session := FarmLessonSession.new()
## Compatibility seams for the screen's callers and the touch probe.
var _lesson_running: bool:
	get: return _lesson_session.running
	set(value): _lesson_session.running = value
## Whether the garden's quiet clock is running. One loop per screen, started
## once on entry; the lesson's faster tick rides alongside it.
var _garden_tick_running := false
## The last step whose line has been spoken; redraws do not repeat it.
var _lesson_said: String:
	get: return _lesson_session.said
	set(value): _lesson_session.said = value
## The market's one pointing finger, waiting for the rebuild. The finger is a
## Control, and the rebuild that follows the harvest frees every Control --
## so the harvest QUEUES it and the rebuild plants it after sweeping, or the
## child gets a finger that lives one frame. (The first lesson solves the
## same problem with its tick; one flag is enough for one moment.)
var _market_finger_queued := false
## The tutorial carrot's per-plant override, never written to crops.json.
var _tutorial_growth: int:
	get: return _lesson_session.tutorial_growth
	set(value): _lesson_session.tutorial_growth = value
## What the beds looked like when they were last drawn. Written by _rebuild,
## read by the lesson's tick -- the difference between "a second went by" and
## "something the child can see has changed".
var _beds_looked_like := ""


## A room, not a level: nothing here completes and nothing here is scored.
func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	var arrival: Dictionary = ArrivalSettlement.settle()
	var dew: Dictionary = arrival.get("dew", {})
	var visit: Dictionary = arrival.get("visit", {})
	if not visit.is_empty():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
	elif bool(dew.get("applied", false)) and int(dew.get("sparkle_count", dew.get("watered_count", 0))) > 0:
		AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	build_world(self, 0.42)
	_rebuild()
	# App resume settles the save before this signal. The settlement may
	# change the warehouse as well as the beds; the lesson's half-second
	# settle is deliberately not part of this signal.
	if not GameManager.farm_resumed.is_connected(_on_farm_resumed):
		GameManager.farm_resumed.connect(_on_farm_resumed)

	# The graded helper, watching from now on. Same three steps as every level:
	# say it again, show the finger, then do the hardest part and leave the last
	# move to him.
	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_nudge, _show_the_move, _do_the_hard_part)

	# The garden's quiet clock, from now on. One loop, started once; it dies
	# with the screen (is_inside_tree guards every beat).
	if not _garden_tick_running:
		_garden_tick_running = true
		_garden_tick()

	if not bool(_farm().get("tutorial_completed", false)):
		_teach_the_first_planting()


func _farm() -> Dictionary:
	return SaveManager.data.get("farm", {})


func _plots() -> Array:
	return _farm().get("plots", [])


## One more of today's verbs done. The tally lives in the save and the date
## lives in its keys, so "yesterday's water" can never pay for "today's
## water". A tally that crosses its target says so exactly once, with the
## little found-chime -- found, not won: the finding is the reward's knock,
## the claim on the board is the child's own act.
func _daily_progress(verb: String, by: int = 1) -> void:
	var receipt := DailyProgress.record(_farm(), GameClock.now_date(), verb, by)
	_respond_to_daily_progress(receipt)


func _respond_to_daily_progress(receipt: Dictionary) -> void:
	FarmProgressNoticeView.new(self).daily_progress(receipt)


func _on_farm_resumed(changed: bool) -> void:
	if not changed or not is_inside_tree():
		return
	_queue_rebuild()


# --- the screen ---------------------------------------------------------

## Redraw the screen furniture. The FARM is not redrawn.
##
## The four-bed garden threw everything away after every action, and that was
## right: four rectangles and a seed rack are not worth diffing, and a rebuild
## is the only thing that cannot leave a thirsty badge on a bed that has just
## been watered.
##
## A farm cannot be treated that way. Throwing it away also throws away where
## the camera is pointed -- so watering a bed would snap the picture back to
## the opening view, and a child who had dragged over to look at the well would
## be moved somewhere else every time he did anything. So the world is built
## once and told what changed, and everything that does NOT move with the farm
## is still rebuilt wholesale, because that part is still not worth diffing.
func _rebuild() -> void:
	# Ingredients can arrive through overflow refills, not just harvesting.
	# Resolve recipe knowledge before the book and kitchen read their rows.
	var learned: Array = Recipes.check_barn()
	# Keep the receipt on the row being read when the garden clock refreshes.
	# Closing the market or emptying the box starts the next receipt at the top.
	if _market_open and not _market_sell.is_empty() \
			and is_instance_valid(_market_rows_scroll):
		_market_scroll_offset = _market_rows_scroll.scroll_vertical
	else:
		_market_scroll_offset = 0
	for child in get_children():
		if child is Control or child is DragField:
			child.queue_free()
	_field = null
	_drop_targets.clear()
	# Everything that was standing over the farm has just been freed; the list
	# of it is rebuilt below by whoever recreates each piece.
	if _world != null and is_instance_valid(_world):
		_world.blockers.clear()

	var view := get_viewport_rect().size
	if _world == null or not is_instance_valid(_world):
		_world = FarmWorld.new()
		add_child(_world)
		_world.connect_screen_callbacks(self)
		_world.build(view, TOP_BAR, SHELF, _plots())
	else:
		_world.refresh(_plots())
	# Ask the existing task resolver ONCE. The shelf card and the flag in the
	# farm are two views of the same answer, never competing quest systems.
	# A crop that is merely growing keeps its quiet shelf preview but gets no
	# world flag: only a thing the child can do right now is a destination.
	var task: Dictionary = _next_task()
	var show_task := not _lesson_running and not _something_is_open() \
		and not task.is_empty()
	var show_beacon := show_task and bool(task.get("actionable", false))
	_world.set_task_beacon(task if show_beacon else {},
		FarmNextTaskPanel.color_for_task(task))
	_draw_decorations()

	_play = UiKit.play_area(self, true)
	_play.theme = UiKit.theme()
	FarmHeaderPanel.new(self).build(view, TOP_BAR)
	_seed_drop_targets()
	_panel_buttons.clear()
	_market_field = null
	if _challenges_open:
		_challenge_panel(view)
	elif _orders_open:
		_order_board(view)
	elif _shop_open:
		_shop_panel(view)
	elif _market_open:
		_market_panel(view)
	elif _barn_open:
		_barn_panel(view)
	elif _visit_open:
		_visit_panel(view)
	elif _recipes_open:
		_recipes_panel(view)
	elif _kitchen_open:
		_kitchen_panel(view)
	elif _gift_open:
		_gift_panel(view)
	_expand_card(view)
	_undo_toast(view)
	# The barn is drawn AFTER the rack, because the rack lays down the shelf
	# panel and anything added before it ends up underneath.
	_seed_rack(view)
	_tool_bar(view)
	_sync_tool_target_halos(task if show_beacon else {})
	_barn(view)
	_deco_door(view)
	FarmViewControlsPanel.new(self).build(view, SHELF)
	# The shelf is drawn after the top bar. Put this last so its one clear
	# instruction is visible above the shelf background and never hidden by it.
	if show_task:
		FarmNextTaskPanel.new(self).build(view, task, SHELF)
	# The world needs to know whether a press on a bed is a tap or a stroke,
	# and it must never disagree with the toolbar about it.
	_world.brush_armed = _tools.is_brush()

	# What the beds look like as of this drawing. The lesson's tick compares
	# against it, so a change somebody else has already drawn -- a tap, a drop,
	# the hint director turning a bed over -- does not make it rebuild a second
	# time half a second later. That second rebuild is not invisible: it wipes
	# the pointing finger off the screen a moment after it appears, which was
	# caught in a screenshot and by nothing else.
	_beds_looked_like = FarmTick.visual_signature(_plots())

	# The market's finger, planted AFTER the sweep that would have taken it.
	if _market_finger_queued:
		_market_finger_queued = false
		_point_at_market()

	# Last, and only during the first visit of a childhood: the screen has just
	# been rebuilt because something changed, and what changed may be the thing
	# the lesson was waiting for. Asked here rather than at each of the four
	# call sites that change a plot, so a fifth one cannot forget.
	_lesson_advance()
	# Show the existing lesson card after the sweep that would have freed it.
	if not learned.is_empty():
		_recipe_learned_card(learned[0])


## Rebuild after this frame, and not while he is holding something.
##
## Rebuilding inside a signal handler would free the node that is still
## delivering it. One frame later is soon enough and always safe.
##
## NEVER WHILE A SEED IS IN THE AIR
##
## A rebuild throws the whole screen away and registers DragField's slots from
## scratch, which takes the piece out of his hand: the carrot he was carrying
## disappears back onto the rack, mid-drag, with nothing on screen to explain
## it. He is six -- he will think he did it wrong.
##
## It was reachable before anything ticked. The hint director tills a bed for a
## child who has been stuck three times, and rebuilds to show it; if he had
## finally started dragging a seed at that exact moment, it dropped. Rare and
## invisible, which is the worst combination this project has. The lesson's
## half-second tick made it common enough for the touch probe to catch, and the
## fix belongs here rather than in the tick, because the rule is about drags and
## not about lessons. The reason for the rebuild is still true when he lets go.
func _queue_rebuild(release_frames: int = 1) -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	for _frame in range(maxi(release_frames, 1)):
		await get_tree().process_frame
	while is_inside_tree() and ((_field != null and is_instance_valid(_field) \
			and not _field.held().is_empty()) \
			or (is_instance_valid(_market_field) and not _market_field.held().is_empty()) \
			or (_world != null and is_instance_valid(_world) and _world.stroking())):
		# Seeds, market produce and brush strokes all keep their live gesture
		# until release; a clock update must not take an item out of his hand.
		await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild()


func _crop_picture(crop_id: String, box: float,
		node_name: String = "GardenCropPicture", golden: bool = false) -> Control:
	return FarmPanelBase.new(self).crop_picture(crop_id, box, node_name, golden)


## A tiny, derived answer to "what now?". It deliberately has no save field:
## the farm, the order board and the tool controller already know every fact
## it needs. Keeping this as a query means a new crop state cannot make the
## ribbon disagree with a tap, a brush or the dog.
func _next_task() -> Dictionary:
	if _lesson_running:
		return {}
	var plots := _plots()
	var pending := _first_pending_order()
	var deliverable := _first_fillable_order()
	var unlocked: Array = _farm().get("unlocked_crops", [])
	return NextTask.select(plots, pending, deliverable, unlocked, _tools,
		_harvesting)


## The first still-open order on the physical board. The ribbon only previews
## this one little reason to grow; _order_board remains the one full view.
func _first_pending_order() -> Dictionary:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	return OrderBoard.first_pending(_orders_for_board(delivered), delivered)


func _focus_next_task(task: Dictionary) -> void:
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	if str(task.get("kind", "")) == "deliver":
		# The visitor board lives in the movable farm, not in the shelf. Move it
		# into the farm window before drawing the already-existing order finger;
		# otherwise a child who follows the ribbon only sees a hand pointing off
		# the glass. Looking is deliberately separate from opening: handing the
		# order over remains the child's tap on the real board/card.
		if _world != null and is_instance_valid(_world):
			_world.look_at_facility("orders")
		_point_at("order")
		return
	var index := int(task.get("index", -1))
	var plots := _plots()
	if index < 0 or index >= plots.size() or _world == null \
			or not is_instance_valid(_world):
		return
	_world.look_at_world(Layout.plot_at(index))
	var plot: Dictionary = plots[index]
	_world.show_ring(index, plot)
	Juice.shockwave(_play, _bed_centre(index), 110.0,
		FarmNextTaskPanel.color_for_task(task).lightened(0.12))
	if str(task.get("kind", "")) == "plant" and _shelf != null \
			and is_instance_valid(_shelf):
		Juice.pop(_shelf, 0.05)


## Where a dragged seed may be let go.
##
## An invisible Node2D per bed that is turned and empty, sitting on the glass
## over that bed. DragField measures a release against `node.position`, and a
## release is a point on the glass, so these cannot live inside the farm -- the
## farm's coordinates are the world's, and the two disagree the moment anything
## is dragged or zoomed.
##
## Only TURNED AND EMPTY beds get one, and that single fact is the whole of "a
## bed holds one crop": a planted bed is not a target, so it never lights up
## and a seed released over it floats home. Refusing him after he has let go
## would be a worse answer than never offering.
func _seed_drop_targets() -> void:
	_field = DragField.new()
	_play.add_child(_field)
	_field.dropped.connect(_on_seed_dropped)
	# While a seed is in the air the farm holds still. One finger cannot drag a
	# carrot and the ground at once, and a pan mid-drag would slide the bed out
	# from under the thing he is aiming at. And if he picked it up from the
	# whole-farm overview, the farm leans IN first: every spacing promise the
	# drop relies on is written against the planting zooms, so no seed is ever
	# in the air further out than min_zoom.
	_field.picked_up.connect(func(_item):
		_world.ensure_planting_zoom()
		_world.locked = true)
	_field.dropped.connect(func(_i, _s, _c): _world.locked = false)

	var plots := _plots()
	for i in range(plots.size()):
		if str(plots[i].get("state", "")) != Farm.TILLED:
			continue
		var target := Node2D.new()
		_play.add_child(target)
		_field.add_slot(target, _bed_centre(i), "", 1)
		_drop_targets.append([i, target])


## The camera moved, so everything on the glass that points at the farm has to
## point somewhere else.
##
## Only the drop targets, and that is worth saying out loud: everything else on
## this screen is either inside the farm (and moved by the camera itself) or
## screen furniture (and does not care). If a third thing ever has to follow the
## farm, it goes here, next to the first two, and not into a second listener.
func _follow_the_camera() -> void:
	for pair in _drop_targets:
		var node: Node2D = pair[1]
		if is_instance_valid(node):
			node.position = _bed_centre(int(pair[0]))


## A press on one of the buildings.
##
## The camera has already slid over to it by the time this runs -- that happens
## in the farm, because "tapping a thing looks at it" is true whether or not
## anybody is listening. What is left is whatever that building DOES, and in
## this stage only one of them does anything yet.
func _tap_building(id: String) -> void:
	var deco_room := ""
	var deco_room_exists := false
	if id == "decor":
		deco_room = str(level_data.get("config", {}).get("deco_room", ""))
		deco_room_exists = deco_room != "" \
			and not GameData.get_level(deco_room).is_empty()
	var decision := BuildingAction.press(id, _farm(), Level.level(),
		Level.is_master_farmer(), deco_room, deco_room_exists)
	match str(decision.get("kind", BuildingAction.LOCKED)):
		BuildingAction.PANEL:
			if bool(decision.get("needs_save", false)):
				# Reading the board makes its news old and sends the dog home.
				SaveManager.save_game()
			if id == "orders" and _lesson_said == "order":
				# The lesson's last step pointed at the board. With its cards up,
				# let it say the line again beside one he can actually fill.
				_lesson_said = ""
			_open_panel(str(decision.get("panel", "")))
		BuildingAction.FACILITY:
			_tap_facility(str(decision.get("facility_id", id)))
		BuildingAction.WISH:
			_tap_wishing_well()
		BuildingAction.START_LEVEL:
			AudioManager.play_sfx("res://assets/audio/door.ogg")
			GameManager.start_level(str(decision.get("level_id", "")))
		BuildingAction.LOCKED:
			AudioManager.play_sfx("res://assets/audio/%s.ogg"
				% str(decision.get("cue", "pop")))


## A timed facility answers a press in the same four ways whatever it makes.
## The action controller supplies the manager and spec; this screen maps that
## result to sound, save, ring, want bubble, and the truthful produce flight.
func _tap_facility(facility_id: String) -> void:
	var facility := Layout.facility(facility_id)
	if facility.is_empty():
		return
	var fallback_level := 1
	if facility_id == "coop":
		fallback_level = 2
	elif facility_id == "mill":
		fallback_level = 3
	if Level.level() < int(facility.get("level", fallback_level)):
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		return
	var result := FacilityAction.press(_farm(), facility_id,
		GameClock.now_unix())
	if result.is_empty():
		return
	var spec: Dictionary = result.get("spec", {})
	var at: Vector2 = _world.facility_screen_position(facility_id) \
		if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	match str(result.get("action", "")):
		FacilityAction.COLLECTED:
			var receipt: Dictionary = result.get("receipt", {})
			_collect_facility_produce(facility_id,
				receipt,
				str(spec.get("voice_collect", "farm_coop_eggs")))
		FacilityAction.WAITING:
			AudioManager.play_sfx("res://assets/audio/correct.ogg")
			_collection_feedback.show_waiting_ring(_harvest_feedback_layer(), at,
				float(result.get("progress", 0.0)))
		FacilityAction.STARTED:
			SaveManager.save_game()
			AudioManager.play_sfx("res://assets/audio/%s.ogg"
				% str(spec.get("start_sfx", "rustle")))
			AudioManager.say(str(spec.get("voice_feed", "farm_coop_feed")))
			if facility_id == "coop" and _world != null \
					and is_instance_valid(_world):
				_world.poke_scenery_kind("chicken")
			_queue_rebuild()
		FacilityAction.MISSING:
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			var input_crop := str(result.get("input_crop", ""))
			_collection_feedback.show_wanted_icon(_harvest_feedback_layer(), at,
				str(GameData.get_crop(input_crop).get("icon", "seed")))


## All timed facilities collect through the barn's ordinary flight and spill
## receipt. The action controller decides WHAT happened; this page presents it.
func _collect_facility_produce(facility_id: String, receipt: Dictionary,
		voice: String) -> void:
	if receipt.is_empty():
		return
	var at: Vector2 = _world.facility_screen_position(facility_id) \
		if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/found.ogg")
	AudioManager.say(voice)
	var stored := int(receipt.get("stored", 0))
	var spilled := int(receipt.get("spilled", 0))
	if stored > 0:
		_collection_feedback.show_flight(_harvest_feedback_layer(), self,
			receipt, stored, _barn_button_at, "warehouse", "HarvestFlight",
			Callable(self, "_crop_picture"), at + Vector2(0, -20))
	if spilled > 0:
		_collection_feedback.show_flight(_harvest_feedback_layer(), self,
			receipt, spilled, _spill_flight_destination(), "harvest_basket",
			"HarvestSpillFlight", Callable(self, "_crop_picture"),
			at + Vector2(0, -20))
	_harvested_something = true
	_queue_rebuild()


## The rain cloud he dragged over a thirsty bed let go: the bed drinks by
## the same rule the watering can uses, and the day's water job counts.
func _on_cloud_rained(index: int) -> void:
	var plots := _plots()
	if index < 0 or index >= plots.size():
		return
	var plot: Dictionary = plots[index]
	if str(plot.get("care_event", "")) != Growth.CARE_THIRSTY:
		return
	plots[index] = _care_for(plot, index)
	_commit_plot(plots, index)


## The bear's animated visit is one transaction: the thirsty bed, water tally,
## spent visit, and unread board entry commit together at the water moment.
## The animation stays in the existing world until its separate finish signal.
func _on_bear_watering(index: int) -> void:
	var farm := _farm()
	var result := BearReturn.settle_water(farm, index, GameClock.now_unix())
	if not bool(result.get("settled", false)):
		return
	var plots := _plots()
	if _world != null and is_instance_valid(_world):
		_world.refresh(plots)
	_respond_to_plot_care(str(result.get("action", "")), index)
	SaveManager.save_game()
	if _hints != null:
		_hints.progress()


func _on_bear_visit_finished(_index: int) -> void:
	_queue_rebuild()


func _on_fish_caught(info: Dictionary) -> void:
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/found.ogg")
	var pond_pos := Vector2(1362.0, 612.0)
	var at: Vector2 = _world.camera.world_to_screen(pond_pos) if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	var stored := int(info.get("stored", 1))
	var spilled := int(info.get("spilled", 0))
	if stored > 0:
		_collection_feedback.show_flight(_harvest_feedback_layer(), self,
			info, stored, _barn_button_at, "warehouse", "HarvestFlight",
			Callable(self, "_crop_picture"), at + Vector2(0, -20))
	if spilled > 0:
		_collection_feedback.show_flight(_harvest_feedback_layer(), self,
			info, spilled, _spill_flight_destination(), "harvest_basket",
			"HarvestSpillFlight", Callable(self, "_crop_picture"),
			at + Vector2(0, -20))
	_harvested_something = true
	_queue_rebuild()
	if bool(info.get("unlocked_ducklings", false)):
		AudioManager.say("praise_3")


func _on_dog_found_seed(crop_id: String) -> void:
	# FarmWorldController persists the deterministic dig result before it emits
	# this receipt. This callback only presents that already-committed reward.
	_queue_rebuild()
	var spot_pos: Vector2 = DogManager.DIG_SPOT_POSITION
	var at: Vector2 = _world.camera.world_to_screen(spot_pos) if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	var receipt := {"crop_id": crop_id, "amount": 1, "stored": 1, "spilled": 0}
	_collection_feedback.show_flight(_harvest_feedback_layer(), self,
		receipt, 1, _barn_button_at, "seed", "HarvestFlight",
		Callable(self, "_crop_picture"), at + Vector2(0, -20))


func _on_scarecrow_tapped() -> void:
	if Level.is_master_farmer():
		AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
		AudioManager.say("praise_3")
		if Juice.motion_enabled() and _world != null and is_instance_valid(_world):
			var at: Vector2 = _world.camera.world_to_screen(FarmWorld.SCARECROW_POS)
			Juice.burst(_harvest_feedback_layer(), at, 16)
		_show_toast_message(I18n.t("farm.scarecrow_cheer"), "crown")
	else:
		AudioManager.play_sfx("res://assets/audio/rustle.ogg")


func _tap_wishing_well() -> void:
	var farm: Dictionary = _farm()
	var today: String = GameClock.now_date()
	var result := WellWish.claim(farm, today)
	if not bool(result.get("claimed", false)):
		AudioManager.play_sfx("res://assets/audio/water.ogg")
		_show_toast_message(I18n.t("farm.well_wish_done"), "star")
		return
	Coins.earn(int(result.get("coins", 0)), "farm:well_wish", false)
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	if Juice.motion_enabled() and _world != null and is_instance_valid(_world):
		var well_pos: Vector2 = _world.facility_screen_position("well")
		Juice.burst(_harvest_feedback_layer(), well_pos, 16)
	_show_toast_message(I18n.t("farm.well_wish_done"), "star")
	_queue_rebuild()


## Open one door and shut the rest. The panel-state controller owns route
## exclusivity; this screen resets route-specific data and handles feedback.
func _open_panel(which: String) -> void:
	_panel_state.open(which)
	_challenge_page = 0
	# A door always opens on its first page -- a shop remembered mid-flip
	# reads as a shop with rows missing.
	_shop_page = 0
	_book_page = 0
	_kitchen_page = 0
	_confirm_crop = ""
	_confirm_cook = ""
	_confirm_expand = -1
	_confirm_upgrade = false
	_market_ui = null
	if which != "market":
		_market_sell = {}
		_market_rows = {}
	if which != "gift" and which != "bear_door":
		_gift_basket = {}
	AudioManager.play_sfx("res://assets/audio/door.ogg")
	_queue_rebuild()


func _close_panels() -> void:
	_panel_state.close()
	_gift_basket = {}
	_confirm_cook = ""
	_confirm_crop = ""
	_confirm_expand = -1
	_confirm_upgrade = false
	_market_sell = {}
	_market_rows = {}
	_market_ui = null
	_queue_rebuild()


## Is there a sheet of paper over the farm right now?
##
## Reads the same panel flags `_open_panel` writes, plus the expand card --
## that one is drawn OUTSIDE the elif chain, so it can be the only thing on
## top of the farm and would otherwise not count as "something is open".
func _something_is_open() -> bool:
	return _panel_state.any_open() or _confirm_expand >= 0


## The back button, one step at a time.
##
## With a panel open there are two ways off the screen: this button -- 112x96,
## dark, top-left, where every other room in the game puts "leave" -- and the
## panel's own close button. A six-year-old presses the one he can see, and
## before this it meant "throw away the whole garden", which is the most
## destructive reading available. Now the first press shuts the paper and the
## second one leaves. Nothing is taken away: the panel's own close button
## still works, and two presses still get him out.
func _one_step_back() -> void:
	if _something_is_open():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_close_panels()
		return
	quit_level()


## Y coordinate shared by the seed pouch and its lesson pointer.
func _seed_lane_y(view: Vector2) -> float:
	return view.y - 38.0


func _seed_rack(view: Vector2) -> void:
	FarmSeedRackPanel.new(self).build(view, SHELF)


# --- what a tap does ----------------------------------------------------

## One tap, dispatched on the plot's state and nothing else.
##
## This used to ask four booleans in a fixed order, and the ORDER was the rule:
## whether a plot that was both ripe and thirsty got watered or picked was
## decided by which `elif` came first, and nothing said so. Now the state says
## what the plot is doing and the branches below say what a tap does to it,
## which is a thing that can be read rather than a thing that has to be traced.
func _tap_plot(index: int) -> void:
	var plots := _plots()
	if index < 0 or index >= plots.size():
		return
	var plot: Dictionary = plots[index]
	var plot_id := str(plot.get("plot_id", ""))
	var decision: Dictionary = _tools.apply_hand_tap(plot,
		plot_id in _harvesting, GameClock.now_unix())
	match str(decision.get("kind", PlotAction.WAIT)):
		PlotAction.LOCKED:
			return
		PlotAction.TILL:
			var tilled: Dictionary = decision.get("plot", plot)
			if tilled == plot:
				return
			plot = tilled
			AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		PlotAction.HARVEST:
			_harvest(plot, index)
		PlotAction.CARE:
			var cared: Dictionary = decision.get("plot", plot)
			if cared == plot:
				return
			plot = cared
			_respond_to_plot_care(str(decision.get("transition", "")), index)
		PlotAction.PLANT:
			# Turned, empty, and tapped: he is trying to plant by tapping. Point
			# at the rack rather than doing nothing, which is the same as being
			# broken. A 4% pulse of the whole shelf was the whole answer here,
			# and with motion off it was nothing: now the line, a sound, and
			# a ring on the first seed.
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			AudioManager.say("garden_tut_plant")
			if _play != null and is_instance_valid(_play):
				Juice.shockwave(_play, _seed_rack_centre(), 120.0,
					Color(1.0, 0.94, 0.62, 0.5))
			if _shelf != null:
				Juice.pop(_shelf, 0.04)
			return
		PlotAction.WAIT:
			# SEEDED or GROWING. Nothing to do yet -- so answer the question he
			# WAS asking, which is "how much longer": the ring comes up for a
			# few seconds and then gets out of the way again. A bed that does
			# nothing at all when pressed is a bed he decides is broken.
			AudioManager.play_sfx("res://assets/audio/correct.ogg")
			if _world != null and is_instance_valid(_world):
				_world.show_ring(index, plot)
			return

	plots[index] = plot
	_commit_plot(plots, index)


## The tail every plot action shares: the save learns the new state, the farm
## redraws the bed, the lesson may advance, and the rebuild waits for the
## finger to leave. One body, because "the save and the screen agree" is the
## kind of promise that drifts when written twice.
func _commit_plot(plots: Array, index: int) -> void:
	SaveManager.data["farm"]["plots"] = plots
	if _world != null and is_instance_valid(_world):
		_world.refresh(plots)
	SaveManager.save_game()
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


## Does a bare-hand drag that lands on this bed belong to the crop? Ripe, its
## move is one the catalogue knows, and nobody is mid-harvest on it. Asked the
## moment a finger lands -- the world keeps no copy, so the answer can never go
## stale the way a list of ripe indexes would.
func _bed_wants_gesture(index: int) -> bool:
	var plots := _plots()
	if index < 0 or index >= plots.size():
		return false
	var plot: Dictionary = plots[index]
	return PlotGesture.wants_gesture(plot,
		str(plot.get("plot_id", "")) in _harvesting)


## The bed leans while the finger pulls on it. Pure forwarding: what the lean
## means lives in the crop data and the judge below, not here.
func _on_gesture_moved(index: int, offset: Vector2) -> void:
	if _world != null and is_instance_valid(_world):
		_world.gesture_lean(index, offset)


## The pull is over; judge it once, with the recogniser 丰收行动 judges by.
##
## Two verdicts and no third. The move: pick it, the same _harvest a tap takes,
## plus a burst because the crop came out with some theatre. Anything else: the
## drag was the other thing a drag from a bed can be -- a pan -- and one
## catch-up jump says so without a sound, a shake or a red X. A wrong pull is
## never an error; it is a pan that happened to start on a carrot.
func _on_gesture_finished(index: int, track: PackedVector2Array,
		centre: Vector2, net: Vector2) -> void:
	var plots := _plots()
	if index < 0 or index >= plots.size():
		return
	var plot: Dictionary = plots[index]
	# Judge the bed as it exists at release, since its state may have changed
	# while the finger was down. This pure result leaves side effects here.
	var verdict := PlotGesture.judge(plot,
		str(plot.get("plot_id", "")) in _harvesting, track, centre)
	match verdict:
		PlotGesture.CARE:
			plot = _care_for(plot, index)
			plots[index] = plot
			_commit_plot(plots, index)
		PlotGesture.HARVEST:
			Juice.burst(_play, _bed_centre(index), 12)
			_harvest(plot, index)
			_commit_plot(plots, index)
		PlotGesture.PAN:
			if _world != null and is_instance_valid(_world):
				_world.pan_by(net)


## The care a NEEDS_CARE bed asks for, done: water, weed or shoo, each with
## its sound, the water one with its drip response and its day-tally. Shared
## by the tap and by the care gestures, because "the same care from a
## different hand" must be the same care. Returns the plot in its new state.
func _care_for(plot: Dictionary, index: int) -> Dictionary:
	var tool_id := _tools.tool_for(plot)
	var result: Dictionary = _tools.apply_to_plot(tool_id, plot,
		GameClock.now_unix())
	if result.is_empty():
		return plot
	_respond_to_plot_care(str(result.get("action", "")), index)
	return result.get("plot", plot)


## The same response follows a care transition whether it came from one tap or
## one brush stroke. PlotCare owns the saved state; this screen owns the
## child's audible and visible confirmation.
func _respond_to_plot_care(action: String, index: int) -> void:
	match action:
		PlotCare.WATER:
			AudioManager.play_sfx("res://assets/audio/water.ogg")
			_daily_progress("water")
			if _world != null and is_instance_valid(_world):
				_world.drink_bed(index)
		PlotCare.WEED:
			AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
		PlotCare.SHOO:
			AudioManager.play_sfx("res://assets/audio/rustle.ogg")


## Pick it, and pay for it exactly once.
##
## THE TRANSACTION ID
##
## `farm_harvest_<plot_id>_<plant_cycle_id>` -- the patch of earth, and which
## planting in it. plant_cycle_id rises by one every time a seed goes in and
## never resets, so no two harvests in the history of a save can ever produce
## the same id, and the same id presented twice is always a repeat.
##
## There are three ways a repeat can arrive and this covers all three: a second
## tap while the animation runs (also blocked by _harvesting), a tap that
## arrives between the reward and the save landing, and a restart from a save
## written after the payment. RewardManager owns the check, because the rule
## "a thing is paid for once" belongs in one place for the whole island rather
## than being re-implemented per screen.
func _harvest(plot: Dictionary, index: int = -1) -> void:
	var receipt: Dictionary = _harvest_core(plot)
	if receipt.is_empty():
		return
	AudioManager.play_sfx("res://assets/audio/star.ogg")
	AudioManager.say("praise_1")
	_harvested_something = true
	if index >= 0:
		_combo += int(receipt.get("amount", 0))
		_show_combo(index, receipt)
	_end_combo()
	if bool(receipt.get("golden", false)):
		_celebrate_golden(index)


## Gold's own celebration. NOT a bonus: the yield was exactly the crop's own,
## the purse is untouched, and what gold buys is this -- a bigger burst, a
## shower of stars where the plant stood, and its own sound. Rare should
## sound and look rare, or it is just a number.
func _celebrate_golden(index: int) -> void:
	if index < 0 or index >= _plots().size():
		return
	AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	_collection_feedback.show_golden_harvest(_play,
		_harvest_feedback_layer(), _bed_centre(index))


## Tell the player that a merged, already-paid crop was released without yield.
## The transaction controller has already updated the bed; this screen owns
## the warning and the quiet correction sound.
func _report_a_paid_duplicate(plot_id: String, cycle: int) -> void:
	push_warning("garden: bed %s cycle %d was already paid for; freed without pay"
		% [plot_id, cycle])
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")


func _harvest_core(plot: Dictionary) -> Dictionary:
	var farm := _farm()
	var transaction: Dictionary = HarvestTransaction.settle(plot, farm,
		GameClock.now_date())
	if not bool(transaction.get("claimed", false)):
		# A repeat. The tap-while-animating and restart-after-save repeats
		# arrive on a bed that is already reset; nothing to do. But a READY
		# bed whose id is in the ledger is a bed that can never be picked:
		# the tap returned here, silently, forever. Two tablets merging
		# their ledgers can make one (paid_harvests is unioned while the
		# beds are kept from one side). Free the bed -- no crops, no coins,
		# and an id the ledger has not seen for its next planting.
		if bool(transaction.get("duplicate_freed", false)):
			_report_a_paid_duplicate(str(transaction.get("plot_id", "")),
				int(transaction.get("cycle", 0)))
		return {}
	var plot_id := str(transaction.get("plot_id", ""))
	var crop_id := str(transaction.get("crop_id", ""))
	var picked := int(transaction.get("amount", 0))
	# The transaction has already settled storage, the bed, and every durable
	# harvest follow-up in memory. This page now only answers those events.
	var level_event: Array = transaction.get("levels", [])
	_respond_to_level_award(level_event)

	_harvesting[plot_id] = true
	var daily_event: Dictionary = transaction.get("daily", {})
	_respond_to_daily_progress(daily_event)
	var learned: Array = transaction.get("learned_recipes", [])
	if not learned.is_empty():
		_recipe_learned_card(learned[0])

	# The one other thing this garden ever teaches: the first time the barn
	# gets close to full, say the market's name once and point at its box.
	# A flag, not a schedule -- taught is taught, exactly like the lesson.
	if bool(transaction.get("market_taught", false)):
		AudioManager.say("farm_market_hint")
		_market_finger_queued = true

	_release_after_the_animation(plot_id)
	return {
		"crop_id": crop_id,
		"amount": picked,
		"stored": int(transaction.get("stored", 0)),
		"spilled": int(transaction.get("spilled", 0)),
		"golden": bool(transaction.get("golden", false)),
	}


## Let go of the plot once the picking animation has had its moment.
func _release_after_the_animation(plot_id: String) -> void:
	await get_tree().create_timer(HARVEST_LOCK_SECONDS).timeout
	_harvesting.erase(plot_id)


func _on_seed_dropped(item: Dictionary, slot: Variant, correct: bool) -> void:
	if not correct or slot == null:
		return
	# WHICH BED: matched by the slot's NODE, never by any position. The slot
	# remembers where the bed was when the targets were built, and the farm has
	# usually moved since -- the camera pans, the targets follow the beds, but
	# a remembered point does not. Matching by distance against it picks the
	# right bed after a small pan and a NEIGHBOURING bed after a big one, which
	# is a carrot appearing where he did not put it, rarely, and only after
	# scrolling: the exact kind of bug nobody can reproduce on a desk. The
	# node's identity cannot go stale.
	var index := -1
	for pair in _drop_targets:
		if pair[1] == slot.get("node"):
			index = int(pair[0])
	if index < 0:
		return
	var plots := _plots()
	# There is no "is this bed already planted" check on the DROP path, and
	# there does not need to be: a bed only offers DragField a slot while it is
	# turned AND empty, so a planted bed is not a target at all. The child
	# never sees a ring light up over his carrot, which is a better answer than
	# refusing him after he has already let go.
	if not _plant_in(index, str(item.get("key", ""))):
		return
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	_queue_rebuild()


## Put one seed in one bed. The classic drag and the seed brush both end here,
## because "planting starts a new cycle" is the rule a harvest's pay-once
## transaction id hangs from, and a rule like that gets ONE implementation.
##
## Does not save: the drop saves after its one planting, the brush saves once
## per stroke. Guards on TILLED itself -- the drop path cannot reach it any
## other way, but the brush asks needs() first and a second door should not
## trust the first one's lock.
func _plant_in(index: int, crop_id: String) -> bool:
	var plots := _plots()
	if index < 0 or index >= plots.size() or crop_id == "":
		return false
	var plot: Dictionary = plots[index]
	if str(plot.get("state", "")) != Farm.TILLED:
		return false
	# The six-second carrot belongs only to its lesson bed. The random roll is
	# supplied once per real planting and never consumed during the lesson.
	var lesson_target := _lesson_plot_after_planting(index) \
		if _lesson_running else -1
	var golden_roll := randf() if not _lesson_running else -1.0
	var transaction: Dictionary = PlantingTransaction.settle(_farm(), index,
		crop_id, GameClock.now_unix(), _lesson_running, lesson_target,
		str(GameData.garden_tutorial.get("crop_id", "carrot")),
		_tutorial_growth, golden_roll)
	return bool(transaction.get("planted", false))


## Where bed `index` is ON THE GLASS right now.
##
## Two coordinate spaces meet here and everything that gets this wrong looks
## like something else. The bed's position is a fact about the FARM; where it
## appears is a fact about the farm AND where the camera is pointed, and the
## camera moves. So this is asked of the farm every time rather than computed
## once, and the arithmetic lives in one pure function
## (FarmCamera.world_to_screen) that a probe can hand numbers to.
##
## It never returns a stale answer, which is why it is safe for the pointing
## finger, the drop targets and both probes to keep calling it.
func _bed_centre(index: int) -> Vector2:
	if _world == null or not is_instance_valid(_world):
		return Vector2.ZERO
	return _world.bed_screen_position(index)


# --- the tool rack and the brush ------------------------------------------

## The compact shelf keeps the current job close; the full rack stays one tap
## away for everything else. FarmToolRackPanel only presents the choices --
## availability and selection still come from FarmToolController.
func _tool_bar(view: Vector2) -> void:
	FarmToolRackPanel.new(self).build(view, SHELF)


func _select_tool(tool_id: String) -> void:
	var selection: Dictionary = _tools.select_tool(tool_id,
		_world != null and is_instance_valid(_world) and _world.stroking())
	if selection.is_empty():
		return
	var drawer_was_open := _tool_rack_expanded
	_tool_rack_expanded = false
	if not bool(selection.get("changed", false)):
		if drawer_was_open:
			_queue_rebuild()
		return
	_world.brush_armed = _tools.is_brush()
	var voice := str(_tools.tool_data(tool_id).get("voice", ""))
	if voice != "":
		AudioManager.say(voice)
	AudioManager.play_sfx("res://assets/audio/drag_pick.ogg")
	_queue_rebuild()


## The selected brush gets a small, physical answer in the farm itself: every
## bed it can work on receives a halo. The eligibility still comes from
## FarmToolController.needs(), the same function that greys tools and gates a
## brush stroke, so presentation can never promise a bed the gesture will skip.
func _sync_tool_target_halos(task: Dictionary = {}) -> void:
	ToolTargetView.sync(_world, _tools, _plots(), _something_is_open(), task)


## Tapping a seed tile arms the seed brush with that crop, in one move. No
## separate "now choose a crop" step: the tile IS the choice, and the ring
## drawn around it is the receipt.
func _choose_seed(crop_id: String) -> void:
	var selection: Dictionary = _tools.select_seed(crop_id,
		_world != null and is_instance_valid(_world) and _world.stroking())
	if selection.is_empty():
		return
	if bool(selection.get("tool_changed", false)):
		AudioManager.say("farm_tool_seed")
	_world.brush_armed = true
	AudioManager.play_sfx("res://assets/audio/drag_pick.ogg")
	_queue_rebuild()


## The tool ran out of work: back to the hand, on its own, silently. Silently
## because coming back is not an instruction -- there is nothing he must do
## about it -- and a line here would talk over the praise for the job he just
## finished.
func _auto_return() -> void:
	if _tools.return_to_hand_if_idle(_plots()):
		if _world != null and is_instance_valid(_world):
			_world.brush_armed = false


## One bed swept by the brush. The two gates (once per stroke, and only beds
## that need it) live in the stroke bookkeeping; this is what happens to a bed
## that passes them.
func _on_stroke_swept(index: int) -> void:
	var plots := _plots()
	var transition := func(tool_id: String, plot: Dictionary) -> Dictionary:
		return _resolve_brush_transition(tool_id, index, plot, plots)
	var outcome: Dictionary = _stroke.apply_once(_tools, plots, index, transition)
	if outcome.is_empty():
		return
	var action := str(outcome.get("action", ""))
	match action:
		"till", "plant":
			AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		PlotCare.WATER, PlotCare.WEED, PlotCare.SHOO:
			_respond_to_plot_care(action, index)
		"harvest":
			var receipt: Dictionary = outcome.get("receipt", {})
			if not receipt.is_empty():
				_combo += int(receipt.get("amount", 0))
				_show_combo(index, receipt)
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				if bool(receipt.get("golden", false)):
					_celebrate_golden(index)
	SaveManager.data["farm"]["plots"] = plots
	# The bed changes under the brush as it passes -- that is the whole show --
	# but nothing is SAVED yet: one stroke is one write, at the end.
	_world.refresh(plots)
	_sync_tool_target_halos()


## Resolve the action for one bed. Shared eligibility and changed-state
## bookkeeping live in ContinuousActionController; the screen supplies its
## lesson context and the harvest transaction that cannot be a plot-only edit.
func _resolve_brush_transition(tool_id: String, index: int, plot: Dictionary,
		plots: Array) -> Dictionary:
	match tool_id:
		"shovel":
			var till_result: Dictionary = _tools.apply_to_plot(tool_id, plot)
			if till_result.is_empty():
				return {}
			return {"plot": till_result.get("plot", plot),
				"action": str(till_result.get("action", "till"))}
		"seed":
			if not _plant_in(index,
					_tools.crop_to_plant(_farm().get("unlocked_crops", []))):
				return {}
			return {"plot": plots[index], "action": "plant"}
		"water", "weed", "bug":
			var care_result: Dictionary = _tools.apply_to_plot(tool_id,
				plot, GameClock.now_unix())
			if care_result.is_empty():
				return {}
			return {"plot": care_result.get("plot", plot),
				"action": str(care_result.get("action", ""))}
		"basket":
			var receipt: Dictionary = _harvest_core(plot)
			# Duplicate recovery can change the bed without paying a second time,
			# so return the possibly-reset plot even when there is no receipt.
			return {"plot": plot, "action": "harvest", "receipt": receipt}
	return {}


## The finger lifted. Now the stroke is a fact: write it down once, praise it
## once, and put the hand back if the tool has nothing left to do.
func _on_stroke_ended() -> void:
	var completion: Dictionary = _stroke.finish()
	if not bool(completion.get("did_work", false)):
		# Swept, but over nothing that needed this tool. Not an error and not
		# silence either: the tool itself shrugs, so the answer is "nothing to
		# do HERE" rather than "nothing happened", which reads as broken.
		var button: Variant = _tool_buttons.get(str(completion.get("tool_id", "")))
		if button is Button and is_instance_valid(button):
			Juice.nudge(button, 8.0)
		_end_combo()
		return
	SaveManager.save_game()
	if _combo > 0:
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		AudioManager.say("praise_1")
		_harvested_something = true
	_end_combo()
	_auto_return()
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


## Collection feedback must survive the bed and barn redraw that just paid
## for it, so it lives on one screen-space layer owned by the farm.
func _harvest_feedback_layer() -> CanvasLayer:
	if _harvest_feedback == null or not is_instance_valid(_harvest_feedback):
		_harvest_feedback = CanvasLayer.new()
		_harvest_feedback.name = "HarvestFeedbackLayer"
		_harvest_feedback.layer = 2
		add_child(_harvest_feedback)
	return _harvest_feedback


func _show_combo(index: int, receipt: Dictionary) -> void:
	var plots := _plots()
	var source_valid := index >= 0 and index < plots.size()
	var source_at := _bed_centre(index) if source_valid else Vector2.ZERO
	_collection_feedback.show_combo(self, _harvest_feedback_layer(), _combo,
		receipt, source_at, source_valid, _barn_button_at,
		_spill_flight_destination(), get_viewport_rect().size, TOP_BAR,
		Callable(self, "_crop_picture"))


func _end_combo() -> void:
	_combo = 0
	_collection_feedback.end_combo()


# --- the barn and the order board ---------------------------------------

## What is in the barn, along the bottom of the play area.
##
## Small and always visible rather than behind a button: the whole point of
## growing something is watching the pile get bigger, and a pile behind a door
## is a pile he has to remember to go and look at.
## The door to the decorating room, at the right end of the tool row: a sticker book on a
## chip. Which room it opens is the garden's own DATA (config.deco_room) --
## the room-naming rule keeps the id out of code, and a save from before the
## room existed simply shows no door. 二期阶段 1 的入口。
func _deco_door(view: Vector2) -> void:
	FarmDecorationsView.new(self).build_door(view, SHELF)


## What he arranged in the decorating room, standing in the farm itself.
##
## Drawn from the SAME creation the 装饰间 saves (its canvas_id, read from
## data), mapped from the room's design space onto the whole farm world, and
## deliberately mute: no input, no buttons, z below the beds. A decoration
## that can swallow a tap meant for a plot is furniture blocking the door --
## the home screen's clear_lane taught that lesson already.
## What the furniture looked like when it was last drawn. See _draw_decorations.
var _deco_drawn := ""


func _draw_decorations() -> void:
	_deco_drawn = FarmDecorationsView.new(self).refresh_saved(
		get_viewport_rect().size, _deco_drawn)


## 三期阶段 3：家具会答话，但永远排在最后。
##
## 这里接的是世界的 grass_pressed——地块、建筑、石头都没认领的那种
## 点击。所以"家具从不吞掉给地里的手指"这条红线原样成立：装饰的
## mouse_filter 还是 IGNORE，它从不接输入，只是剩下的点击落在它身上
## 时，它答应一声。挤压回弹加一下歪头，首页 poke 的语言；只动
## scale/rotation，不进存档，不算玩法。
func _poke_decoration(at: Vector2) -> void:
	FarmDecorationsView.new(self).poke(at)


func _barn(view: Vector2) -> void:
	FarmBarnPanel.new(self).build_shelf(view)


func _spill_flight_destination() -> Vector2:
	return FarmBarnPanel.spill_flight_destination(get_viewport_rect().size)


## Who needs a hand today. Three cards, each one a picture of somebody, what
## they want, and what they will give for it.
func _order_board(view: Vector2) -> void:
	FarmOrdersPanel.new(self).build(view)


func _orders_for_board(delivered: Array) -> Array:
	var counts: Dictionary = SaveManager.data.get("farm_orders", {}).get("counts", {})
	return OrderBoard.select_orders_for_board(GameData.garden_orders, delivered,
		counts, Level.level())

## Top left of the order board, measured from the viewport every time -- see
## _bed_centre for why nothing here may be measured from a hard-coded 720.
func _order_board_origin() -> Vector2:
	return FarmOrdersPanel.board_origin(get_viewport_rect().size)


## The middle of one order's card, for the lesson's finger to land on. Walks
## the BOARD, not the file -- the finger must land where the card is drawn.
func _order_card_centre(order_id: String) -> Vector2:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	var board: Array = _orders_for_board(delivered)
	return FarmOrdersPanel.card_centre(order_id, board, get_viewport_rect().size)


## Collect a finished day-job. The date is inside the once-key, so a claim
## pays once today and once again tomorrow, and never twice in either.
func _claim_daily(task: Dictionary) -> void:
	var farm := _farm()
	var receipt := DailyClaim.claim(farm, task, GameClock.now_date())
	var paid := int(receipt.get("paid", 0))
	if paid > 0:
		SaveManager.save_game()
		AudioManager.play_sfx("res://assets/audio/coin.ogg")
		AudioManager.say("praise_2")
		_queue_rebuild()


func _close_orders() -> void:
	_panel_state.close("orders")
	_queue_rebuild()


## Hand the basket over.
##
## FarmOrderDelivery settles the basket and once key synchronously; XP, daily
## progress, and the save are written before any presentation or await. A
## second press cannot get between payment and its persisted record.
func _deliver(order: Dictionary) -> void:
	var orders: Dictionary = SaveManager.data.get("farm_orders", {})
	var receipt := OrderDelivery.settle(order, orders)
	if not bool(receipt.get("settled", false)):
		return
	var paid := int(receipt.get("paid", 0))
	if paid > 0:
		# Helping a friend grows the farm most of all -- and only the first
		# time this order goes through, same gate as the coins above. For a
		# recurring order every delivery is a first delivery, and that is the
		# design: tending beds is how the farm grows up, forever.
		_earn_xp("order")
		_daily_progress("deliver")
	SaveManager.data["farm_orders"] = orders
	# Completion belongs to this delivery transaction. Set the lesson flag
	# before the single save so an interrupted entry cannot leave the order paid
	# while the first-planting lesson is still marked unfinished.
	_the_lesson_is_over()
	SaveManager.save_game()

	# Handing the first basket over is the end of the lesson, and the only end
	# it has. Written down here rather than on a timer, because "he has been
	# taught" should mean he did the whole thing once -- turned the earth, put
	# a seed in, watered it, picked it, and gave it to somebody who wanted it.
	if paid > 0:
		AudioManager.play_sfx("res://assets/audio/coin.ogg")
		AudioManager.say("praise_2")
		_harvested_something = true
		_offer_a_break()
		FarmProgressNoticeView.new(self).order_thanks(order,
			_harvest_feedback_layer(), get_viewport_rect().size)
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


func _order_customer_art(order: Dictionary, box: float) -> Control:
	if str(order.get("customer_icon", "")) == "res://assets/harvest_3d/props/rabbit.png":
		return HarvestArt.prop_badge("rabbit", box, "RabbitOrderPortrait")
	return UiKit.picture(str(order.get("customer_icon", "heart")), box)


# --- the shop, the market box, and the barn's own door --------------------


## "X分" under an hour, "X时" from there up. Every crop's time is a whole
## number of one or the other on purpose -- crops.json is checked for it.
func _longest_wait() -> int:
	var longest := 0
	for row in GameData.farm_seed_shop.get("seeds", []):
		longest = maxi(longest, int(GameData.crop_total_seconds(
			str(row.get("crop_id", "")))))
	return longest


func _grow_time_text(seconds: int) -> String:
	if seconds < 3600:
		return "%d分" % int(round(seconds / 60.0))
	return "%d时" % int(round(seconds / 3600.0))


## The seed shop: six rows a page, and on every row the three numbers the red
## line demands be visible BEFORE any confirm button exists -- what it costs,
## how long it grows, how many come off. Nothing here is a one-press purchase.
## A seed of a level the farm has not grown to is a dim silhouette with the
## star badge saying which level -- 圈好的地 on a shelf, never a lock.
func _shop_panel(view: Vector2) -> void:
	FarmShopPanel.new(self).build(view)


func _buy_confirmed() -> void:
	var crop_id := _confirm_crop
	_confirm_crop = ""
	if SeedShop.buy(crop_id) != "":
		# Refused -- owned already, or the coins moved under him. Nothing was
		# taken, so nothing needs saying beyond the rows redrawing honestly.
		_queue_rebuild()
		return
	_undo_flow.offer("seed", crop_id, GameClock.ticks_ms())
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	AudioManager.say("farm_shop_bought")
	_queue_rebuild()


## The market sheet owns its live drop, quantity, and sale callbacks. The
## screen retains only the visit basket, which must survive furniture rebuilds.
func _market_panel(view: Vector2) -> void:
	var panel := FarmMarketPanel.new(self)
	_market_ui = panel
	panel.build(view)


## Probe seam for the real market panel's drop response.
func _on_market_drop(item: Dictionary, slot: Variant, correct: bool) -> void:
	if _market_ui != null:
		_market_ui.call("on_market_drop", item, slot, correct)


## Probe seam for the real market panel's quantity stepper.
func _market_step(crop_id: String, delta: int) -> void:
	if _market_ui != null:
		_market_ui.call("step_crop", crop_id, delta)


## The barn's own door: how full it is, what is in it, and -- once, ever --
## the upgrade that the three friends' planks were for.
func _barn_panel(view: Vector2) -> void:
	FarmBarnPanel.new(self).build(view)


## The one purchase that is not a crop. Planks first -- take() is all or
## nothing -- then coins, then the roof. cap < UPGRADED is the idempotence:
## a second press finds the barn already big and stops at the first line.
func _upgrade_confirmed() -> void:
	_confirm_upgrade = false
	var farm := _farm()
	var receipt := BarnUpgrade.settle(farm, GameClock.ticks_ms())
	if not bool(receipt.get("upgraded", false)):
		# A refused purchase still closes the confirm card and redraws honestly.
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_queue_rebuild()
		return
	_undo_flow.set_pending(receipt.get("undo", {}))
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	AudioManager.say("farm_barn_bigger")
	_queue_rebuild()


## The visitor board: who came while nobody was looking, and what they left.
##
## Icons carry the story -- a face, a watering can with a number, a star --
## and the words underneath are the footnote for the grown-up reading over a
## shoulder. Newest at the top, three visits deep: the log remembers ten, but
## a board taller than the screen is a list, and this is a noticeboard.
##
## Nothing here is a button. There is nothing to claim, confirm, or miss:
## everything a visitor left was already given when they left it -- the board
## only says so. A reward that must be COLLECTED from a panel is a red-line
## mechanic (miss-out anxiety) wearing a friendly face.
func _visit_panel(view: Vector2) -> void:
	FarmVisitPanel.new(self).build(view)


## A press on land still under stones. Three answers, all gentle: a confirm
## card when it is ready to clear, a purse wobble when coins are short, and
## a look at the star badge when the farm has growing to do first -- the
## badge over the stones already says which level, so pointing at it IS the
## explanation, and nothing here is ever a lock.
func _tap_stones(index: int) -> void:
	match Expand.state_of(index):
		"ready":
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			_confirm_expand = index
			_queue_rebuild()
		"poor":
			# The same sentence the hero house says when stars are short --
			# one recording, one phrasing, everywhere money is almost enough.
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			AudioManager.say("house_almost")
		_:
			# "level" (or a slot that is not next): the stones shrug.
			AudioManager.play_sfx("res://assets/audio/pop.ogg")


## The clearing, asked about first: the cost, the yes, the no. Same shape as
## every purchase on this farm -- three numbers were already visible on the
## badge, and no press lands money without this card in between.
func _expand_card(view: Vector2) -> void:
	if _confirm_expand < 0:
		return
	FarmExpansionPanel.new(self).build(view)


func _expand_confirmed(index: int) -> void:
	_confirm_expand = -1
	if Expand.buy(index) != "":
		_queue_rebuild()
		return
	# The stones slide off the exact patch he pressed, before the rebuild
	# replaces the furniture; the world grows the seventh bed on its next
	# refresh, camera untouched.
	if _world != null and is_instance_valid(_world):
		_world.celebrate_new_bed(index)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	AudioManager.say("farm_new_plot")
	_undo_flow.offer("plot", str(index), GameClock.ticks_ms())
	_queue_rebuild()


## One event's worth of farm xp, and the celebration if it crossed a rung.
## Callers are all INSIDE their own once-only gates, which is the whole of
## why the xp cannot be farmed; see farm_level_manager.gd.
func _earn_xp(kind: String) -> void:
	_respond_to_level_award(Level.award(kind))


func _respond_to_level_award(levels: Array) -> void:
	if levels.size() < 2:
		return
	if int(levels[1]) <= int(levels[0]):
		return
	FarmProgressNoticeView.new(self).level_up(
		_harvest_feedback_layer(), get_viewport_rect().size,
		int(levels[0]) < 8 and int(levels[1]) >= 8)
	# The chip redraws with the screen; the town (orchard corner, star
	# badges over the stones) redraws itself on the world's next refresh.
	_queue_rebuild()


## The pointing finger, at the market box, once. Node2D, so the rebuild that
## follows the harvest does not sweep it away with the furniture.
func _point_at_market() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var at: Vector2 = _world.facility_screen_position("market")
	if not _world.camera.inside(at):
		_world.look_at_facility("market")
		at = _world.facility_screen_position("market")
	FarmLessonView.new(self).point_to(at, at, 1.4, self)


## The regret window, drawn while it is open. One small card, one button, and
## letting it lapse costs nothing -- it just stops being offered.
## The bear's lesson, the moment it is earned: a card slides in with his
## face, the dish's ingredients, and the name -- then leaves by itself.
## Nothing to dismiss, nothing modal: the harvest that earned it is still
## mid-celebration and this must not interrupt that.
func _recipe_learned_card(recipe: Dictionary) -> void:
	FarmProgressNoticeView.new(self).recipe_learned(recipe,
		_harvest_feedback_layer(), get_viewport_rect().size)


func _show_master_farmer_celebration() -> void:
	FarmProgressNoticeView.new(self).master_farmer(
		_harvest_feedback_layer(), get_viewport_rect().size)


func _show_toast_message(text: String, icon_name: String = "") -> void:
	FarmProgressNoticeView.new(self).toast(_harvest_feedback_layer(),
		get_viewport_rect().size, TOP_BAR, text, icon_name)


## 小熊的菜谱本：一页六道菜，多了翻页。会做的亮着、配料和名字都在；还不
## 会的只留暗色配料——"去凑齐这些"本身就是答案，和图鉴的剪影一个道理。
func _recipes_panel(view: Vector2) -> void:
	FarmRecipesPanel.new(self).build(view)


## 加工小屋：会做的菜在这里下锅，做好的菜从这里送出去。
##
## Only unlocked recipes appear -- the kitchen cooks knowledge, and the page
## for wanting more is the recipe book in the barn. Each row answers three
## questions with pictures: what goes in (ingredient icons, bright when the
## barn has them), what comes out (the dish and how many are made), and where
## it goes (送给小熊). Cooking asks first, like every spend in this game;
## short ingredients get a headshake, never a greyed-out row.
func _kitchen_panel(view: Vector2) -> void:
	FarmKitchenPanel.new(self).build(view)


func _gift_panel(view: Vector2) -> void:
	FarmGiftPanel.new(self).build(view)


func _undo_toast(view: Vector2) -> void:
	_undo_flow.expire(GameClock.ticks_ms())
	FarmUndoPanel.new(self).build(view)


func _undo_pressed() -> void:
	var result: Dictionary = _undo_flow.consume(GameClock.ticks_ms())
	if bool(result.get("expired", false)):
		# Pressed after the window shut, on a toast the clock had not yet
		# swept away. Too late is too late; say so quietly.
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_queue_rebuild()
		return
	if not bool(result.get("accepted", false)):
		_queue_rebuild()
		return
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
	_queue_rebuild()


# --- the first planting, the graded help, and the way to stop ------------

## The lesson, run once in a child's life.
##
## Not a script that plays AT him: the helper says one thing, he does it, and
## the helper says the next thing. Every step is a real action on the real
## garden -- there is no rehearsal mode and nothing is faked, so what he learns
## is the thing he will do tomorrow.
##
## WHY THE STEP IS WORKED OUT AND NOT COUNTED
##
## There is no step counter and nothing to keep in sync. The lesson looks at
## the garden and says what the garden is asking for: bare earth means "turn it
## over", turned earth means "put a seed in", a thirsty plant means "give it a
## drink". That is the same rule the beds themselves run on -- one tap does the
## one thing this plot wants -- so the lesson cannot drift out of step with the
## screen it is teaching, and a child who wanders off mid-lesson and comes back
## on Thursday is met where he actually is rather than where a counter left him.
##
## It ran as a four-second finger animation before, all three points shown at
## once on the way in, and the four lines after "welcome" had nowhere to play
## at all: garden_tutorial.json described six steps and the code read one field
## out of it. "Give it some water" was recorded, written down, and unreachable.
##
## The carrot grows in `tutorial_growth_override` seconds instead of its real
## thirty minutes, for this planting only. crops.json is NOT edited: a lesson
## that changed the crop would leave every later carrot fast too, and the
## override lives on the plot where it belongs.
func _teach_the_first_planting() -> void:
	await _lesson_session.teach(self)


## Say the step the garden is asking for, if it is not the one already said.
##
## Called from _rebuild(), which runs after every action and after every tick
## that changed something -- so this is asked far more often than it answers.
func _lesson_advance() -> void:
	_lesson_session.advance(self)


## Which of the six steps the garden is currently asking for, or "" for none.
func _lesson_step() -> String:
	return Lesson.step(_plots(),
		int(GameData.garden_tutorial.get("plot_index", 0)),
		_an_order_he_can_fill())


## Which bed the lesson is about.
##
## Normally the one garden_tutorial.json names, and the finger has been pointing
## at it since the first line. But a child who dropped his seed two beds to the
## left did the thing he was asked to do, and a lesson that carried on pointing
## at bare earth while his carrot grew somewhere else would be teaching him that
## the game is not watching him. So the plant wins over the plan.
func _lesson_plot() -> int:
	return Lesson.target_plot(_plots(),
		int(GameData.garden_tutorial.get("plot_index", 0)))


## Preview the lesson target after planting `index`, without mutating the save.
## This lets the lesson choose its one fast-growing carrot before the shared
## planting transition writes the selected bed.
func _lesson_plot_after_planting(index: int) -> int:
	return Lesson.target_after_planting(_plots(),
		int(GameData.garden_tutorial.get("plot_index", 0)), index)


## The first order the barn can pay for and nobody has delivered yet.
## Reads the BOARD, not the file: a level-gated order is not there to point
## at, and a finger aimed at a card that is not drawn teaches "the game lies".
func _first_fillable_order() -> Dictionary:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	return OrderBoard.first_fillable(_orders_for_board(delivered), delivered)


func _an_order_he_can_fill() -> String:
	return str(_first_fillable_order().get("id", ""))


## Say one step's line, and point at the thing the line is about.
##
## The words live in garden_tutorial.json and not here, so that the line an
## adult records and the moment it plays are described in the same file. A step
## the data does not name is skipped in silence -- better than a finger
## pointing at nothing while nobody speaks.
func _say_the_step(step_id: String) -> void:
	var step := _step_data(step_id)
	if step.is_empty():
		return
	AudioManager.say(str(step.get("voice", "")))
	_point_at(str(step.get("point_at", "plot")))


func _step_data(step_id: String) -> Dictionary:
	for step in GameData.garden_tutorial.get("steps", []):
		if step is Dictionary and str(step.get("id", "")) == step_id:
			return step
	return {}


## The finger, for one step.
##
## Transient on purpose: it goes into the play area, so the next rebuild takes
## it away with everything else and nothing outside this function has to
## remember it is there. That is also what fixes an old bug -- the lesson used
## to be one long-lived node holding the "it is finished" signal, so a child who
## tapped a bed while it was still playing had it freed underneath him and the
## garden never wrote down that he had been taught. It taught him again the next
## day, and the day after that.
func _point_at(what: String) -> void:
	if _play == null or not is_instance_valid(_play):
		return
	var bed := _bed_centre(maxi(_lesson_plot(), 0))
	var look_at := bed
	var act_at := bed
	match what:
		"seed":
			# The one action in the garden that is a drag, shown as one: the
			# finger travels from the rack into the earth.
			look_at = _seed_rack_centre()
		"order":
			# Shut board: point at the BOARD, which is a building on the farm,
			# and let him open it. A finger on a card that is not on the screen
			# is a finger on nothing, and a child who follows it and taps
			# nothing concludes the game is broken -- the same accident the
			# seed rack's spotlight had before it was aimed properly.
			var card: Vector2 = _order_card_centre(_an_order_he_can_fill()) \
				if _orders_open else _world.facility_screen_position("orders")
			look_at = card
			act_at = card
	FarmLessonView.new(self).point_to(look_at, act_at,
		1.4 if what == "seed" else (1.3 if what == "order" else 1.2))


## Grow the garden while he is watching -- for the length of the lesson only.
##
## Nothing in this game ticks. Growth is arithmetic on two timestamps, worked
## out once on the way in, and that is exactly what makes a carrot keep growing
## while the tablet is shut in a bag (see offline_growth.gd). It is the right
## design for a crop that takes half an hour and the wrong one for precisely
## one plant: the lesson's carrot is done in six seconds, and a child who puts
## a seed in and then watches four patches of earth do nothing for ever has
## been told a lie by the game at the first thing it ever asked him to do.
##
## So the settling that normally happens on the way in happens twice a second
## while the lesson runs, and stops the moment it ends. The screen is only
## rebuilt when a plot actually looks different, which is why a ripe carrot
## waiting to be picked costs nothing.
## The garden's quiet clock. One beat every GARDEN_TICK seconds until the
## screen goes away. The lesson runs its own, much faster, tick -- the two
## never run in the same second on purpose, so the lesson's pointing finger
## cannot be wiped by this one's rebuild.
func _garden_tick() -> void:
	while _garden_tick_running and is_inside_tree():
		await get_tree().create_timer(GARDEN_TICK).timeout
		if not _garden_tick_running or not is_inside_tree():
			return
		if _lesson_running:
			continue
		_garden_tick_once()


## One beat: settle against the clock, redraw whatever bed now looks different,
## and rebuild the furniture only if something MEANING happened -- a bed turned
## ripe, started asking for care, or produce waiting by the door found the barn
## to have room for it at last. The celebration is for him: a bed that ripened
## while he stood there says so, once, and then leaves the choice to him.
func _garden_tick_once() -> void:
	var result := FarmTick.settle(_plots())
	var plots: Array = result.get("plots", _plots())
	if _world != null and is_instance_valid(_world):
		_world.refresh(plots)
	_beds_looked_like = str(result.get("visual", ""))
	if not bool(result.get("needs_rebuild", false)):
		return
	if _world != null and is_instance_valid(_world):
		var celebrated := false
		for index_value in result.get("ripened_indices", []):
			var index := int(index_value)
			if not celebrated:
				celebrated = true
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
			Juice.shockwave(_play, _bed_centre(index), 140.0,
				Color(1.0, 0.94, 0.62, 0.5))
	_queue_rebuild()


## Written down the moment the lesson ends, and never asked again.
func _the_lesson_is_over() -> void:
	_lesson_session.finish(self)


## The first seed on the rack -- the one the finger points at.
##
## Not the middle of the shelf, which is what this used to answer: the seeds are
## laid out from the left and the barn sits on the right, so the midpoint is the
## empty gap between them. The spotlight landed on bare shelf, and a child told
## to pick up a seed was being shown a place where there is no seed.
func _seed_rack_centre() -> Vector2:
	return _rack_tile_centre(0)


## Where tile `index` of the rack sits. The rack's own drawing uses this, and
## so does the touch probe -- which used to carry its own copy of the layout
## and had to be kept in step by hand every time the rack moved.
func _rack_tile_centre(index: int) -> Vector2:
	var view := get_viewport_rect().size
	return FarmSeedRackPanel.tile_centre(index, _seed_lane_y(view))


## The one plot that most wants attention, or -1 if the garden is content.
## The ribbon and the dog read this exact priority from FarmToolController too:
## ripe food first, then care, then planting the soil he already turned.
func _the_plot_that_wants_something() -> int:
	return FarmHintActions.next_plot(self)


## Help, step one: say it again, and make the thing glow.
func _nudge() -> void:
	FarmHintActions.nudge(self)


## Help, step two: show the finger doing it.
func _show_the_move() -> void:
	FarmHintActions.show_move(self)


## Help, step three: do the hard part, and leave the last move to him.
##
## The rule the whole hint system is built on -- never finish it FOR him. For
## a plot that needs turning, that means turning it, because the move after it
## (dropping a seed in) is the one worth having. For a plot that is waiting on
## water or weeds there is only one move, so this stops at showing it again:
## doing it would be doing the whole thing.
func _do_the_hard_part() -> void:
	FarmHintActions.do_hard_part(self)


## "The garden is looked after. Shall we go and do something else?"
##
## Offered once per visit, after something good has happened, and never on the
## way in. It is a suggestion with two buttons and no countdown, no reward for
## staying and no penalty for leaving -- see rest_director.gd for why the game
## does this rather than leaving it to the parent.
func _offer_a_break() -> void:
	if _rest_offered or not _harvested_something:
		return
	_rest_offered = true
	FarmLessonView.new(self).offer_break(get_viewport_rect().size,
		func(): quit_level())

## The same harvest levels, replayable from the same farm door. Four roomy
## rows and the existing sheet pager fit both screen shapes without a scroll
## gesture fighting the farm camera. Stars come straight from level progress.
func _challenge_panel(view: Vector2) -> void:
	FarmChallengePanel.new(self).build(view)
