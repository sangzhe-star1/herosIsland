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
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Rest := preload("res://scripts/shared/rest_director.gd")
const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")
const FarmWorld := preload("res://scripts/garden/farm_world_controller.gd")
const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
const Stroke := preload("res://scripts/garden/continuous_action_controller.gd")
const SeedShop := preload("res://scripts/garden/seed_shop_manager.gd")
const Market := preload("res://scripts/garden/farm_market_manager.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")
const DayCycle := preload("res://scripts/garden/farm_day_cycle.gd")
const Coop := preload("res://scripts/garden/farm_coop_manager.gd")
const Pen := preload("res://scripts/garden/farm_pen_manager.gd")
const Maker := preload("res://scripts/garden/farm_maker_manager.gd")
const DogManager := preload("res://scripts/garden/farm_dog_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Gesture := preload("res://scripts/harvest/gesture.gd")
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const HarvestCrops := preload("res://scripts/harvest/harvest_crops.gd")
const HeroTaskRibbon := preload("res://scripts/ui/hero_task_ribbon.gd")
const FarmOrdersPanel := preload("res://scripts/garden/panels/farm_orders_panel.gd")
const FarmShopPanel := preload("res://scripts/garden/panels/farm_shop_panel.gd")
const FarmMarketPanel := preload("res://scripts/garden/panels/farm_market_panel.gd")
const FarmBarnPanel := preload("res://scripts/garden/panels/farm_barn_panel.gd")
const FarmVisitPanel := preload("res://scripts/garden/panels/farm_visit_panel.gd")
const FarmRecipesPanel := preload("res://scripts/garden/panels/farm_recipes_panel.gd")
const FarmKitchenPanel := preload("res://scripts/garden/panels/farm_kitchen_panel.gd")
const FarmChallengePanel := preload("res://scripts/garden/panels/farm_challenge_panel.gd")
const FarmGiftPanel := preload("res://scripts/garden/panels/farm_gift_panel.gd")

## WHERE THE BEDS ARE IS NO LONGER THIS FILE'S BUSINESS
##
## The four-bed garden laid its beds out here, from a gap derived from
## DragField.SNAP. The farm lays them out in world coordinates, in
## data/farm_world_layout.json, and the rules about that layout live in
## scripts/garden/farm_layout.gd where the probe and tools_check.py can run the
## same arithmetic against the same numbers.
##
## The rule itself did not go away, it got harder: SNAP is measured on the
## GLASS and the farm can be zoomed out, so the same world distance buys fewer
## screen pixels at 0.8 than at 1.0. See Layout.world_gap_needed().
const SEED_TILE := Vector2(64, 60)
## The old 96px header plus 168px shelf left less than two thirds of a 16:9
## tablet for the island. These are compact *lanes*, not smaller touch targets:
## the buttons inside keep their child-friendly hit boxes.
const TOP_BAR := 68.0
const SHELF := 140.0
## One header rhythm, used by the five facts a child sees before touching the
## farm. Keeping the measurements together prevents the title plaque, level
## and challenge door from each growing toward one another on 4:3.
const HUD_INSET := 20.0
const HUD_GAP := 12.0
const HUD_BACK_BOX := Vector2(64.0, 60.0)
const HUD_LEVEL_BOX := Vector2(102.0, 54.0)
const HUD_CHALLENGE_BOX := Vector2(88.0, 48.0)
const HUD_CHOOSER_BOX := Vector2(48.0, 48.0)
const HUD_PURSE_BOX := Vector2(126.0, 54.0)
const HUD_CARD_Y := 4.0
## The barn card and its overflow basket share this one shelf measurement.
## A flight should land on the same place the rebuilt shelf will draw.
const BARN_CARD := Vector2(152.0, SEED_TILE.y)

## The order board, written down once instead of in four places.
##
## The first lesson ends by pointing a finger at one particular card, and a
## finger that lands beside the card rather than on it is worse than no finger:
## a child follows it, taps nothing, and concludes the game is broken. Both the
## drawing and the pointing read these, so the two cannot drift apart.
const ORDER_CARD := Vector2(378, 94)
const ORDER_FIRST := 48.0        # heading down to the first card
const ORDER_GAP := 102.0          # card to card
## How the board picks its three: see _orders_for_board.
const ORDER_BOARD_CARDS := 3

## Paged surfaces: six rows on the shop sheet, fourteen seed slots on the
## dense possession row. The usual whole seed collection fits at once.
const PANEL_PAGE := 6
const RACK_PAGE := 14

## How often the garden re-settles itself while the first lesson is running --
## twice a second, because the lesson's carrot is done in six seconds, and a
## child who puts a seed in and then watches four patches of earth do nothing
## for ever has been told a lie by the game at the first thing it ever asked
## him to do. After the lesson the garden keeps a slower beat: GARDEN_TICK.
const LESSON_TICK := 0.5

## How often the garden asks the clock again once the lesson is over. Growth is
## still worked out from timestamps and nothing accumulates frame by frame --
## the tick only re-runs the same arithmetic the entry settle runs, so a bed
## whose minute arrived while he was watering another one turns ripe IN FRONT
## of him instead of on his next visit, and a plant inched taller while he
## watches. Twenty seconds: slow enough that it reads as the farm being alive
## rather than as a machine polling, fast enough that a stage boundary lands
## within half a minute of its time.
const GARDEN_TICK := 20.0

## A beat between "this is our garden" and "turn the soil over", so the two
## lines do not land on top of each other. Long enough to hear the first one,
## short enough that a child does not start tapping to see if it is broken.
const WELCOME_BEAT := 2.0

## How long a plot stays untappable after being picked. Long enough to cover
## the crops flying into the barn, short enough that a child who taps twice on
## purpose is not left wondering why the second one did nothing.
const HARVEST_LOCK_SECONDS := 0.45

## The barn's one upgrade: sixty coins and the three planks the three friends
## left as thanks. Numbers a child can hold: he has SEEN each plank arrive.
const UPGRADE_COINS := 60
const UPGRADE_PLANKS := 3

## How long the regret window stays open after money moves. Long enough to
## change a six-year-old's mind, short enough that the toast is gone before it
## becomes furniture.
const UNDO_WINDOW_MS := 5000

## The chance a planting comes up golden: the whole plant glows for its whole
## life, and picking it gets a celebration of its own. One bed in twenty-five:
## often enough that a child who gardens every day meets one every few visits,
## rare enough that meeting one is a story he tells. Gold changes the
## CELEBRATION and never the yield -- see _harvest_core.
const GOLDEN_PLANT_CHANCE := 0.04

## The move each care event asks for, in the same Gesture grammar the harvest
## uses: a weed pulls up like a carrot, a bug is shooed side to side, water
## pours from above. A tap still does every one of these jobs -- the moves
## are the expressive path, never a gate.
const CARE_MOVES := {
	"weeds": {"recogniser": "drag",
		"params": {"direction_x": 0.0, "direction_y": -1.0,
			"distance": 90.0, "angle": 40.0}},
	"bug": {"recogniser": "sweep",
		"params": {"turns": 2, "leg": 50.0}},
	"thirsty": {"recogniser": "drag",
		"params": {"direction_x": 0.0, "direction_y": 1.0,
			"distance": 90.0, "angle": 40.0}},
}

## The chance as it stands for THIS farm today: doubled when every one of the
## day's little jobs is done. 王者农场's blessing-to-mutation loop in its
## kindest form -- the bonus is earned by CARING, never by paying, and a
## child who never opens the list is never told he lost anything, because
## four percent is already the gift it was yesterday.
func _golden_chance() -> float:
	var dailies: Dictionary = _farm().get("dailies", {})
	return GOLDEN_PLANT_CHANCE * 2.0 if Dailies.all_done(dailies) \
		else GOLDEN_PLANT_CHANCE

var _field: DragField
var _play: Control
## Short-lived collection feedback survives the UI rebuild that immediately
## redraws the empty bed and barn count. It is a screen layer, not a second
## animation system: labels and crop art still come from UiKit/Juice.
var _harvest_feedback: CanvasLayer
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
## Whether the order board is open on top of the farm.
var _orders_open := false
var _challenges_open := false
var _challenge_page := 0
## The other three doors: the seed shop, the market box, the barn. At most one
## of the four stands open -- _open_panel() is the only writer, so the "close
## everything else" rule cannot be forgotten at one call site.
var _shop_open := false
var _market_open := false
var _barn_open := false
var _barn_show_overflow := false
## Whether the visitor board is open: who has dropped by and what they left.
var _visit_open := false
var _recipes_open := false
var _kitchen_open := false
var _gift_open := false
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
## The market's own drag field, so crops can be dragged into the box with the
## same hands-feel as everything else. Separate from the rack's _field: each
## grabs only its own pieces.
var _market_field: DragField
## The regret window: {kind, id, until}. Drawn by _rebuild while ticks_ms is
## short of `until`, so it survives the rebuild that follows its own purchase.
var _pending_undo: Dictionary = {}
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
## The running count while a harvest stroke is going, and the label showing it.
var _combo := 0
var _combo_label: Label
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
## True from the child's first step into the garden until he hands the first
## basket over. Not a node: the lesson is six moments spread across a whole
## visit, not an animation with a lifetime -- see _teach_the_first_planting.
var _lesson_running := false
## Whether the garden's quiet clock is running. One loop per screen, started
## once on entry; the lesson's faster tick rides alongside it.
var _garden_tick_running := false
## The step whose line has already been spoken. A rebuild happens after every
## action and the lesson is re-read on each one, so without this the same
## sentence would land three times while he watched a carrot grow.
var _lesson_said := ""
## The market's one pointing finger, waiting for the rebuild. The finger is a
## Control, and the rebuild that follows the harvest frees every Control --
## so the harvest QUEUES it and the rebuild plants it after sweeping, or the
## child gets a finger that lives one frame. (The first lesson solves the
## same problem with its tick; one flag is enough for one moment.)
var _market_finger_queued := false
## Seconds the tutorial carrot takes, replacing its real 30 minutes for the
## length of the lesson and never written to crops.json.
var _tutorial_growth := 0
## What the beds looked like when they were last drawn. Written by _rebuild,
## read by the lesson's tick -- the difference between "a second went by" and
## "something the child can see has changed".
var _beds_looked_like := ""


## A room, not a level: nothing here completes and nothing here is scored.
func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	# Whatever grew while he was away, before the first thing is drawn. Growth
	# is worked out from timestamps; this is where it catches up on arrival,
	# and the garden's quiet clock (GARDEN_TICK) keeps it caught up from here
	# on -- nothing accumulates frame by frame, the clock is only re-asked.
	SaveManager.settle_farm()
	var dew: Dictionary = DayCycle.check_morning_dew(SaveManager.data.get("farm", {}))
	# Today's little jobs, rolled against today's date. A list from yesterday
	# rolls over silently here -- nothing is lost, nothing nags; see
	# farm_daily_manager.gd for why the date lives inside the claim keys.
	SaveManager.data["farm"]["dailies"] = Dailies.roll(_farm(),
		GameClock.now_date())
	# Did the bear drop by while nobody was here? Worked out the same way
	# growth is -- from the clock, on arrival -- so a visit can never happen in
	# front of the child while he stands watching the gate. If it did happen,
	# the log has a new line and the dog will point at the board.
	var visit := NpcFarm.maybe_visit(GameClock.now_unix())
	# When he last actually stood here, as opposed to when growth was last
	# settled -- which anything that loads the save does, including a level.
	SaveManager.data["farm"]["last_farm_visit_at"] = GameClock.now_unix()
	# Written to disk now, entry or not: maybe_visit's own bookkeeping (the
	# first-friendship stamp) must survive a child who looks in and leaves.
	SaveManager.save_game()
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
	var before: Dictionary = _farm().get("dailies", {})
	SaveManager.data["farm"]["dailies"] = Dailies.add(_farm(),
		GameClock.now_date(), verb, by)
	var after: Dictionary = SaveManager.data["farm"].get("dailies", {})
	for task in GameData.garden_dailies:
		if str(task.get("id", "")) != verb:
			continue
		if Dailies.done(after, task) \
				and not Dailies.done(before, task):
			AudioManager.play_sfx("res://assets/audio/found.ogg")
		break
	# The third little star is a small happy discovery, not a countdown alarm:
	# the same pure all_done() gate drives the visible ribbon and the doubled
	# rare-crop chance.  Claims are intentionally irrelevant -- caring is what
	# lit the luck, and a child may collect the coins whenever he finds the board.
	if Dailies.all_done(after) and not Dailies.all_done(before):
		AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
		AudioManager.say("praise_3")


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
		_world.build(view, TOP_BAR, SHELF, _plots())
		_world.plot_pressed.connect(_tap_plot)
		_world.facility_pressed.connect(_tap_building)
		_world.expansion_pressed.connect(_tap_stones)
		_world.camera_moved.connect(_follow_the_camera)
		_world.stroke_swept.connect(_on_stroke_swept)
		_world.stroke_ended.connect(_on_stroke_ended)
		_world.grass_pressed.connect(_poke_decoration)
		_world.cloud_rained.connect(_on_cloud_rained)
		_world.fish_caught.connect(_on_fish_caught)
		_world.dog_found_seed.connect(_on_dog_found_seed)
		_world.scarecrow_tapped.connect(_on_scarecrow_tapped)
		_world.gesture_bed_check = _bed_wants_gesture
		_world.gesture_moved.connect(_on_gesture_moved)
		_world.gesture_finished.connect(_on_gesture_finished)
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
	_world.set_task_beacon(task if show_beacon else {}, _next_task_color(task))
	_draw_decorations()

	_play = UiKit.play_area(self, true)
	_play.theme = UiKit.theme()
	_top_bar(view)
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
	_view_buttons(view)
	# The shelf is drawn after the top bar. Put this last so its one clear
	# instruction is visible above the shelf background and never hidden by it.
	if show_task:
		_next_task_ribbon(view, task)
	# The world needs to know whether a press on a bed is a tap or a stroke,
	# and it must never disagree with the toolbar about it.
	_world.brush_armed = _tools.is_brush()

	# What the beds look like as of this drawing. The lesson's tick compares
	# against it, so a change somebody else has already drawn -- a tap, a drop,
	# the hint director turning a bed over -- does not make it rebuild a second
	# time half a second later. That second rebuild is not invisible: it wipes
	# the pointing finger off the screen a moment after it appears, which was
	# caught in a screenshot and by nothing else.
	_beds_looked_like = _how_the_beds_look()

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
func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
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


## The right two HUD slots are shared by the top strip and the challenge door.
## Their geometry is a single answer, so a longer coin total cannot make the
## challenge chip drift under it on a 4:3 tablet.
func _header_purse_at(view: Vector2) -> Vector2:
	return Vector2(view.x - HUD_INSET - HUD_PURSE_BOX.x, HUD_CARD_Y)


func _header_challenge_at(view: Vector2) -> Vector2:
	return _header_purse_at(view) - Vector2(
		HUD_GAP * 2.0 + HUD_CHALLENGE_BOX.x + HUD_CHOOSER_BOX.x, -6.0)


## The garden needs surfaces to separate reading lanes, not a second row of
## cards.  Keep that low-relief material in one helper so the header and dock
## can share it without inventing another UI family for each little panel.
func _quiet_surface_style(fill: Color, radius: int, edge: Color,
		edge_width: int = 0, content_margin: int = 20) -> StyleBoxFlat:
	var style := UiKit.panel_style(fill, radius)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.set_content_margin_all(content_margin)
	if edge_width > 0:
		style.border_color = edge
		style.set_border_width_all(edge_width)
	return style


## The collection tray and its items share one warm material. This is local
## to the farm; other screens keep UiKit's existing theme and interactions.
func _inventory_surface(inset: bool = false, selected: bool = false) -> StyleBoxFlat:
	var fill := Color(0.97, 0.92, 0.80) if inset else Color(1.0, 0.97, 0.88)
	var edge := Color(0.72, 0.55, 0.29, 0.42)
	if selected:
		fill = Color(1.0, 0.89, 0.61)
		edge = Color(0.48, 0.34, 0.14)
	var style := _quiet_surface_style(fill, 16 if inset else 24, edge, 2 if selected else 1, 0)
	style.border_width_bottom = 3 if inset else 2
	style.shadow_color = Color(0.35, 0.22, 0.08, 0.12)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style


## Inventory pictures use the same Blender renders as the garden, fitted to
## their visible alpha bounds so a flour sack and a carrot read at equal size.
func _crop_picture(crop_id: String, box: float,
		node_name: String = "GardenCropPicture", golden: bool = false) -> Control:
	var art: Control
	if crop_id in ["egg", "flour", "milk", "honey", "fish"]:
		art = HarvestArt.prop_badge(crop_id, box, node_name)
	else:
		if golden:
			art = HarvestArt.crop_badge("golden_" + crop_id, box, node_name)
		if art == null:
			art = HarvestArt.crop_badge(crop_id, box, node_name)
	if art == null:
		art = UiKit.picture(str(GameData.get_crop(crop_id).get("icon", "seed")), box)
	if art != null:
		art.name = node_name
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _tool_picture(tool: Dictionary, box: float) -> Control:
	var tool_id := str(tool.get("id", ""))
	var prop := {"shovel": "tool_trowel", "water": "tool_watering_can",
		"basket": "basket_empty"}
	var art: Control
	if prop.has(tool_id):
		art = HarvestArt.prop_badge(str(prop[tool_id]), box, "GardenToolIcon")
	if art == null:
		art = UiKit.picture(str(tool.get("icon", "star")), box)
	if art != null:
		art.name = "GardenToolIcon"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


## A tool is a choice inside the shared dock, rather than seven little cards.
## The selected one still gets a firm warm outline and a tiny lift; hover gets
## only a hairline so it cannot compete with the single gold task ribbon.
func _tool_tile_style(fill: Color, edge: Color, selected: bool,
		hovered: bool = false) -> StyleBoxFlat:
	var edge_width := 2 if selected else (1 if hovered else 0)
	var style := _quiet_surface_style(fill, 16, edge, edge_width)
	style.border_width_bottom = 3
	if selected:
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
	return style


func _top_bar(view: Vector2) -> void:
	# A fixed, pale strip prevents the moving farm from reaching the text. It is
	# deliberately flat: facts should read as one calm sentence above the farm,
	# not five raised cards competing with the island below.
	var strip := Panel.new()
	strip.name = "GardenTopBar"
	var strip_style := _quiet_surface_style(Color(0.99, 0.98, 0.93), 0,
		Color(0.53, 0.70, 0.42, 0.42))
	strip_style.border_width_bottom = 2
	strip.add_theme_stylebox_override("panel", strip_style)
	strip.position = Vector2.ZERO
	strip.custom_minimum_size = Vector2(view.x, TOP_BAR)
	strip.size = Vector2(view.x, TOP_BAR)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(strip)

	var back := UiKit.back_button(func(): _one_step_back(), HUD_BACK_BOX)
	back.name = "GardenBack"
	back.position = Vector2(HUD_INSET, HUD_CARD_Y)
	_play.add_child(back)

	# The farm is already recognisable from its map. Keep this compact lane
	# for controls and progress instead of repeating its large screen title.

	# The farm's level: a star, a number, and a sliver of progress. The bar
	# filling is the number at the resolution a young player reads; it belongs
	# in the same stable slot as the back door, not as a loose rail underneath.
	var badge := Panel.new()
	badge.name = "FarmLevelBadge"
	badge.add_theme_stylebox_override("panel", _quiet_surface_style(
		Color(0.99, 0.96, 0.86, 0.72), 18, Color(0.82, 0.68, 0.35, 0.38), 1))
	badge.position = Vector2(HUD_INSET + HUD_BACK_BOX.x + HUD_GAP, 7.0)
	badge.custom_minimum_size = HUD_LEVEL_BOX
	badge.size = HUD_LEVEL_BOX
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var level_star := UiKit.picture("star", 28.0)
	if level_star != null:
		level_star.name = "FarmLevelIcon"
		level_star.position = Vector2(12.0, 8.0)
		badge.add_child(level_star)
	var level_tag := UiKit.title(str(Level.level()), 24)
	level_tag.name = "FarmLevelValue"
	level_tag.position = Vector2(47.0, 3.0)
	level_tag.size = Vector2(42.0, 32.0)
	level_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(level_tag)
	var rail := Panel.new()
	rail.name = "FarmLevelRail"
	rail.add_theme_stylebox_override("panel", UiKit.track_style())
	rail.position = Vector2(11.0, 42.0)
	rail.size = Vector2(80.0, 7.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(rail)
	var fill := Panel.new()
	fill.name = "FarmLevelFill"
	fill.add_theme_stylebox_override("panel", UiKit.fill_style(Color(1.0, 0.78, 0.22)))
	fill.position = rail.position + Vector2(2.0, 2.0)
	fill.size = Vector2(76.0 * Level.progress(), 3.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(fill)
	_play.add_child(badge)

	_challenge_door(view)

	# The purse stays read-only on this screen. A compact card keeps the number
	# familiar without letting its empty white area compete with the challenge.
	var purse := Panel.new()
	purse.name = "FarmCoinPurse"
	purse.add_theme_stylebox_override("panel", _quiet_surface_style(
		Color(1.0, 0.98, 0.90, 0.72), 18, Color(0.83, 0.70, 0.39, 0.38), 1))
	purse.position = _header_purse_at(view)
	purse.custom_minimum_size = HUD_PURSE_BOX
	purse.size = HUD_PURSE_BOX
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := UiKit.picture("star_coin", 28.0)
	if coin != null:
		coin.name = "FarmCoinIcon"
		coin.position = Vector2(11.0, 13.0)
		purse.add_child(coin)
	var amount := UiKit.title(str(Coins.balance()), 24)
	amount.name = "FarmCoinValue"
	amount.position = Vector2(45.0, 8.0)
	amount.size = Vector2(72.0, 36.0)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.clip_text = true
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(amount)
	_play.add_child(purse)

## A tiny, derived answer to "what now?". It deliberately has no save field:
## the farm, the order board and the tool controller already know every fact
## it needs. Keeping this as a query means a new crop state cannot make the
## ribbon disagree with a tap, a brush or the dog.
func _next_task() -> Dictionary:
	if _lesson_running:
		return {}
	var plots := _plots()
	var pending := _first_pending_order()
	var deliverable := _an_order_he_can_fill()
	var index := Tools.next_action_index(plots)
	if index >= 0:
		var plot: Dictionary = plots[index]
		var state := str(plot.get("state", Farm.EMPTY))
		# Do not interrupt a ripe reward or a crop that needs help, but once the
		# basket can finish an order, delivering is a clearer next beat than
		# opening yet another empty patch of soil.
		if deliverable != "" and state in [Farm.TILLED, Farm.EMPTY]:
			return _delivery_task(deliverable)
		var crop_id := str(plot.get("crop_id", ""))
		var task: Dictionary = {
			"index": index,
			"crop_id": crop_id,
			"order": pending,
			"actionable": true,
		}
		match state:
			Farm.READY:
				task.merge({
					"kind": "harvest", "tool_id": "basket", "icon": "basket",
					"title_key": "garden.next.harvest",
				}, true)
			Farm.NEEDS_CARE:
				var tool_id := _tools.tool_for(plot)
				var title_key := "garden.next.water"
				if tool_id == "weed":
					title_key = "garden.next.weed"
				elif tool_id == "bug":
					title_key = "garden.next.bug"
				task.merge({
					"kind": "care", "tool_id": tool_id,
					"icon": str(_tools.tool_data(tool_id).get("icon", "watering_can")),
					"title_key": title_key,
				}, true)
			Farm.TILLED:
				var wanted := _first_missing_order_crop(pending)
				var unlocked: Array = _farm().get("unlocked_crops", [])
				if wanted == "" or not wanted in unlocked:
					wanted = _tools.crop_to_plant(unlocked)
				task.merge({
					"kind": "plant", "tool_id": "seed", "icon": "seed",
					"crop_id": wanted, "title_key": "garden.next.seed",
				}, true)
			_:
				task.merge({
					"kind": "till", "tool_id": "shovel", "icon": "shovel",
					"title_key": "garden.next.till",
				}, true)
		return task

	# A full basket is an immediate happy payoff, but it does not outrank a
	# ripe plant or a thirsty sprout that is already on the screen.
	if deliverable != "":
		return _delivery_task(deliverable)

	for i in range(plots.size()):
		var growing: Dictionary = plots[i]
		if Farm.is_planted(growing):
			return {
				"kind": "growing", "index": i,
				"crop_id": str(growing.get("crop_id", "")),
				"icon": str(GameData.get_crop(str(growing.get("crop_id", "")))
					.get("icon", "sprout")),
				"title_key": "garden.next.growing", "order": pending,
				"actionable": false,
			}
	return {}


func _delivery_task(order_id: String) -> Dictionary:
	var order := _order_for_id(order_id)
	return {
		"kind": "deliver", "icon": str(order.get("customer_icon", "teddy")),
		"title_key": "garden.next.deliver", "order": order,
		"actionable": true,
	}


## The first still-open order on the physical board. The ribbon only previews
## this one little reason to grow; _order_board remains the one full view.
func _first_pending_order() -> Dictionary:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	for order in _orders_for_board(delivered):
		if not str(order.get("id", "")) in delivered:
			return order
	return {}


func _order_for_id(order_id: String) -> Dictionary:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	for order in _orders_for_board(delivered):
		if str(order.get("id", "")) == order_id:
			return order
	return {}


## One crop is enough for the compact preview. Sorting makes its choice stable
## even if a future JSON editor happens to reorder the requirements object.
func _first_missing_order_crop(order: Dictionary) -> String:
	if order.is_empty():
		return ""
	var wants: Dictionary = order.get("requirements", {})
	var ids: Array = wants.keys()
	ids.sort()
	for crop_id in ids:
		if Barn.count(str(crop_id)) < int(wants[crop_id]):
			return str(crop_id)
	return str(ids[0]) if not ids.is_empty() else ""


func _next_task_text(task: Dictionary) -> String:
	var key := str(task.get("title_key", ""))
	if key == "":
		return ""
	var crop_id := str(task.get("crop_id", ""))
	if crop_id == "":
		return I18n.t(key)
	var crop: Dictionary = GameData.get_crop(crop_id)
	return I18n.t(key) % I18n.t(str(crop.get("name_key", "garden.tool.seed")))


func _next_task_color(task: Dictionary) -> Color:
	match str(task.get("kind", "")):
		"harvest": return Color(1.0, 0.90, 0.58)
		"care": return Color(0.78, 0.91, 1.0)
		"plant": return Color(0.84, 0.94, 0.72)
		"till": return Color(0.96, 0.86, 0.68)
		"deliver": return Color(0.90, 0.84, 1.0)
		_: return Color(0.91, 0.94, 0.84)


## The little daily crest is display data only. FarmDailyManager owns both
## the tally and the all-done meaning; this page only gives the shared task
## ribbon a small, word-light way to show it.
func _daily_task_badge() -> Dictionary:
	var daily: Dictionary = Dailies.summary(_farm().get("dailies", {}))
	if bool(daily.get("all_done", false)):
		daily["label"] = I18n.t("garden.daily.lucky")
	else:
		daily["label"] = "%d/%d" % [int(daily.get("done", 0)),
			int(daily.get("total", 0))]
	return daily


## One card, one verb, one target. Action and both progress summaries share
## a compact two-column slot beside the tools, leaving the farm free to pan.
func _next_task_ribbon(view: Vector2, task: Dictionary) -> void:
	if task.is_empty():
		return
	# Seven 72px tools finish at 568. The next-step card preserves action,
	# daily care and order tally in two columns within the same 60px row.
	_add_next_task_button(task, Vector2(580.0, view.y - SHELF + 6.0), Vector2(414.0, 60.0))


## Both shelf shapes use exactly the same derived task, icon, colour and
## focus action. Layout may respond to a tablet, but "what should I do?" must
## never become a second garden rule.
func _add_next_task_button(task: Dictionary, at: Vector2, box: Vector2) -> void:
	var order: Dictionary = task.get("order", {})
	var ribbon := HeroTaskRibbon.new()
	ribbon.configure({
		"name": "NextTask",
		"dense": true,
		"hint": I18n.t("garden.next"),
		"title": _next_task_text(task),
		"icon": str(task.get("icon", "star")),
		"tint": _next_task_color(task),
		"preview": _task_order_preview(order),
		"daily": _daily_task_badge(),
		"primary": bool(task.get("actionable", false)),
	}, box)
	ribbon.position = at
	ribbon.set_meta("kind", str(task.get("kind", "")))
	ribbon.set_meta("plot_index", int(task.get("index", -1)))
	ribbon.set_meta("tool_id", str(task.get("tool_id", "")))
	ribbon.set_meta("order_id", str(order.get("id", "")))

	var task_copy := task.duplicate(true)
	ribbon.pressed.connect(func(): _focus_next_task(task_copy))
	_play.add_child(ribbon)

## The order preview is a single icon-chain, not a miniature second order
## board. The grown-up details remain one tap away at the existing building.
func _task_order_preview(order: Dictionary) -> Dictionary:
	if order.is_empty():
		return {}
	var crop_id := _first_missing_order_crop(order)
	if crop_id == "":
		return {}
	var wants: Dictionary = order.get("requirements", {})
	var need := int(wants.get(crop_id, 0))
	var crop: Dictionary = GameData.get_crop(crop_id)
	return {
		"customer_icon": str(order.get("customer_icon", "teddy")),
		"crop_icon": str(crop.get("icon", "seed")),
		"progress": "%d/%d" % [mini(Barn.count(crop_id), need), need],
	}


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
		_next_task_color(task).lightened(0.12))
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
	match id:
		"orders":
			_open_panel("orders")
			# The lesson's last step was pointing at the board; now that the
			# cards are up, let it say the line again with the finger on the
			# one he can actually fill.
			if _lesson_said == "order":
				_lesson_said = ""
		"seed_shop":
			_open_panel("shop")
		"market":
			_open_panel("market")
		"warehouse":
			_open_panel("barn")
		"bear_door":
			_open_panel("gift")
		"visit_board":
			# Reading the board is what makes its news old: the unread flag
			# clears here, which also sends the dog home -- the rebuild that
			# opens the panel re-aims him.
			var farm: Dictionary = _farm()
			if bool(farm.get("visit_log_unread", false)):
				farm["visit_log_unread"] = false
				SaveManager.save_game()
			_open_panel("visits")
		"well":
			if Level.is_master_farmer():
				_tap_wishing_well()
			else:
				AudioManager.play_sfx("res://assets/audio/water.ogg")
		"coop":
			_tap_coop()
		"mill":
			_tap_mill()
		"cow_shed":
			_tap_pen("cow_shed")
		"beehive":
			_tap_pen("beehive")
		"workshop":
			# 5 级前它画成圈好的地，点了轻响就够——没有锁，只有还没长到。
			if Level.level() >= int(Layout.facility("workshop").get("level", 5)):
				_open_panel("kitchen")
			else:
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
		"decor":
			# 世界里的装饰区和货架上的贴纸书门是同一扇门，读同一条数据。
			var deco_room := str(level_data.get("config", {}).get("deco_room", ""))
			if Level.level() >= int(Layout.facility("decor").get("level", 4)) \
					and deco_room != "" and not GameData.get_level(deco_room).is_empty():
				AudioManager.play_sfx("res://assets/audio/door.ogg")
				GameManager.start_level(deco_room)
			else:
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_:
			AudioManager.play_sfx("res://assets/audio/pop.ogg")


## The hens. Three answers to one press, read off the save: hungry hens eat a
## corn from the barn (or show the corn they want), laying hens show how long
## is left, and waiting eggs go to the barn by the harvest's own door, flying
## the way every harvest flies. No lock, no scolding, no timer he has to beat.
func _tap_coop() -> void:
	var farm := _farm()
	if Level.level() < int(Layout.facility("coop").get("level", 2)):
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		return
	var now := GameClock.now_unix()
	var at: Vector2 = _world.facility_screen_position("coop") \
		if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	match Coop.state(farm, now):
		Coop.READY:
			var receipt := Coop.collect(farm)
			SaveManager.save_game()
			AudioManager.play_sfx("res://assets/audio/found.ogg")
			AudioManager.say("farm_coop_eggs")
			var stored := int(receipt.get("stored", 0))
			var spilled := int(receipt.get("spilled", 0))
			if stored > 0:
				_spawn_harvest_flight(-1, receipt, stored, _barn_button_at,
					"warehouse", "HarvestFlight", at + Vector2(0, -20))
			if spilled > 0:
				_spawn_harvest_flight(-1, receipt, spilled, _spill_flight_destination(),
					"harvest_basket", "HarvestSpillFlight", at + Vector2(0, -20))
			_harvested_something = true
			_queue_rebuild()
		Coop.LAYING:
			# How long is left, the way a bed answers: a ring, for a moment.
			AudioManager.play_sfx("res://assets/audio/correct.ogg")
			_show_coop_ring(at, Coop.progress(farm, now))
		_:
			if Coop.feed(farm, now):
				SaveManager.save_game()
				AudioManager.play_sfx("res://assets/audio/rustle.ogg")
				AudioManager.say("farm_coop_feed")
				if _world != null and is_instance_valid(_world):
					_world.poke_scenery_kind("chicken")
				_queue_rebuild()
			else:
				# No corn: show the corn. The picture IS the sentence.
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				_float_want(at, str(GameData.get_crop(Coop.FEED_CROP).get("icon", "seed")))


## The windmill: two wheat in, a minute and a half of turning sails, one
## sack of flour out. Same three answers as the coop, same doors.
func _tap_mill() -> void:
	var farm := _farm()
	if Level.level() < int(Layout.facility("mill").get("level", 3)):
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		return
	var now := GameClock.now_unix()
	var at: Vector2 = _world.facility_screen_position("mill") \
		if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	match Maker.state(farm, Maker.MILL, now):
		Maker.READY:
			var receipt := Maker.collect(farm, Maker.MILL)
			SaveManager.save_game()
			AudioManager.play_sfx("res://assets/audio/found.ogg")
			AudioManager.say("farm_mill_flour")
			var stored := int(receipt.get("stored", 0))
			var spilled := int(receipt.get("spilled", 0))
			if stored > 0:
				_spawn_harvest_flight(-1, receipt, stored, _barn_button_at,
					"warehouse", "HarvestFlight", at + Vector2(0, -20))
			if spilled > 0:
				_spawn_harvest_flight(-1, receipt, spilled, _spill_flight_destination(),
					"harvest_basket", "HarvestSpillFlight", at + Vector2(0, -20))
			_harvested_something = true
			_queue_rebuild()
		Maker.WORKING:
			AudioManager.play_sfx("res://assets/audio/correct.ogg")
			_show_coop_ring(at, Maker.progress(farm, Maker.MILL, now))
		_:
			if Maker.start(farm, Maker.MILL, now):
				SaveManager.save_game()
				AudioManager.play_sfx("res://assets/audio/machine.ogg")
				AudioManager.say("farm_mill_start")
				_queue_rebuild()
			else:
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				_float_want(at, str(GameData.get_crop(str(Maker.MILL["input"])).get("icon", "seed")))


## Data-driven pen taps: cow shed (wheat -> milk), beehive (strawberry -> honey),
## and any future facilities following the pen protocol.
func _tap_pen(facility_id: String) -> void:
	var spec := Pen.spec_for(facility_id)
	if spec.is_empty():
		return
	var farm := _farm()
	var needed_level := int(Layout.facility(facility_id).get("level", 1))
	if Level.level() < needed_level:
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		return
	var now := GameClock.now_unix()
	var at: Vector2 = _world.facility_screen_position(facility_id) \
		if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	match Pen.state(farm, spec, now):
		Pen.READY:
			var receipt := Pen.collect(farm, spec)
			SaveManager.save_game()
			AudioManager.play_sfx("res://assets/audio/found.ogg")
			AudioManager.say(str(spec.get("voice_collect", "farm_coop_eggs")))
			var stored := int(receipt.get("stored", 0))
			var spilled := int(receipt.get("spilled", 0))
			if stored > 0:
				_spawn_harvest_flight(-1, receipt, stored, _barn_button_at,
					"warehouse", "HarvestFlight", at + Vector2(0, -20))
			if spilled > 0:
				_spawn_harvest_flight(-1, receipt, spilled, _spill_flight_destination(),
					"harvest_basket", "HarvestSpillFlight", at + Vector2(0, -20))
			_harvested_something = true
			_queue_rebuild()
		Pen.PRODUCING:
			AudioManager.play_sfx("res://assets/audio/correct.ogg")
			_show_coop_ring(at, Pen.progress(farm, spec, now))
		_:
			if Pen.feed(farm, spec, now):
				SaveManager.save_game()
				AudioManager.play_sfx("res://assets/audio/rustle.ogg")
				AudioManager.say(str(spec.get("voice_feed", "farm_coop_feed")))
				_queue_rebuild()
			else:
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				_float_want(at, str(GameData.get_crop(str(spec.get("feed_crop", ""))).get("icon", "seed")))


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
	SaveManager.save_game()
	_queue_rebuild()


func _on_fish_caught(info: Dictionary) -> void:
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/found.ogg")
	var pond_pos := Vector2(1362.0, 612.0)
	var at: Vector2 = _world.camera.world_to_screen(pond_pos) if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	var stored := int(info.get("stored", 1))
	var spilled := int(info.get("spilled", 0))
	if stored > 0:
		_spawn_harvest_flight(-1, info, stored, _barn_button_at,
			"warehouse", "HarvestFlight", at + Vector2(0, -20))
	if spilled > 0:
		_spawn_harvest_flight(-1, info, spilled, _spill_flight_destination(),
			"harvest_basket", "HarvestSpillFlight", at + Vector2(0, -20))
	_harvested_something = true
	_queue_rebuild()
	if bool(info.get("unlocked_ducklings", false)):
		AudioManager.say("praise_3")


func _on_dog_found_seed(crop_id: String) -> void:
	SaveManager.save_game()
	_queue_rebuild()
	var spot_pos: Vector2 = DogManager.DIG_SPOT_POSITION
	var at: Vector2 = _world.camera.world_to_screen(spot_pos) if _world != null and is_instance_valid(_world) else Vector2(640, 360)
	var receipt := {"crop_id": crop_id, "amount": 1, "stored": 1, "spilled": 0}
	_spawn_harvest_flight(-1, receipt, 1, _barn_button_at,
		"seed", "HarvestFlight", at + Vector2(0, -20))


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
	if str(farm.get("last_well_wish_date", "")) == today:
		AudioManager.play_sfx("res://assets/audio/water.ogg")
		_show_toast_message(I18n.t("farm.well_wish_done"), "star")
		return
	farm["last_well_wish_date"] = today
	Coins.earn(2, "farm:well_wish")
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	if Juice.motion_enabled() and _world != null and is_instance_valid(_world):
		var well_pos: Vector2 = _world.facility_screen_position("well")
		Juice.burst(_harvest_feedback_layer(), well_pos, 16)
	_show_toast_message(I18n.t("farm.well_wish_done"), "star")
	_queue_rebuild()


func _show_coop_ring(at: Vector2, fraction: float) -> void:
	var ring := UiKit.wait_ring(fraction, 64.0)
	if ring == null:
		return
	ring.name = "CoopRing"
	ring.position = at + Vector2(0, -70)
	_harvest_feedback_layer().add_child(ring)
	var t := ring.create_tween()
	t.tween_interval(2.2)
	t.tween_property(ring, "modulate:a", 0.0, 0.4)
	t.tween_callback(ring.queue_free)


## A small picture of what is wanted, rising from the thing that wants it
## and fading: the wordless "I need corn".
func _float_want(at: Vector2, icon: String) -> void:
	var want := UiKit.picture(icon, 44.0)
	if want == null:
		return
	want.name = "CoopWant"
	want.position = at + Vector2(-22, -90)
	want.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_harvest_feedback_layer().add_child(want)
	if not Juice.motion_enabled():
		var still := want.create_tween()
		still.tween_interval(1.4)
		still.tween_callback(want.queue_free)
		return
	var t := want.create_tween()
	t.tween_property(want, "position:y", want.position.y - 40.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(want, "modulate:a", 0.0, 0.9).set_delay(0.5)
	t.tween_callback(want.queue_free)


## Open one door and shut the rest. The ONLY writer of these four flags: two
## sheets stacked over each other is a screen nobody can read, and a rule
## enforced at one call site is a rule.
func _open_panel(which: String) -> void:
	_challenges_open = which == "challenges"
	_challenge_page = 0
	_orders_open = which == "orders"
	_shop_open = which == "shop"
	_market_open = which == "market"
	_barn_open = which in ["barn", "basket"]
	_barn_show_overflow = which == "basket"
	_visit_open = which == "visits"
	_recipes_open = which == "recipes"
	_kitchen_open = which == "kitchen"
	_gift_open = which in ["gift", "bear_door"]
	# A door always opens on its first page -- a shop remembered mid-flip
	# reads as a shop with rows missing.
	_shop_page = 0
	_book_page = 0
	_kitchen_page = 0
	_confirm_crop = ""
	_confirm_cook = ""
	_confirm_expand = -1
	_confirm_upgrade = false
	if which != "market":
		_market_sell = {}
		_market_rows = {}
	if which != "gift" and which != "bear_door":
		_gift_basket = {}
	AudioManager.play_sfx("res://assets/audio/door.ogg")
	_queue_rebuild()


func _close_panels() -> void:
	_challenges_open = false
	_orders_open = false
	_shop_open = false
	_market_open = false
	_barn_open = false
	_visit_open = false
	_recipes_open = false
	_kitchen_open = false
	_gift_open = false
	_gift_basket = {}
	_confirm_cook = ""
	_confirm_crop = ""
	_confirm_expand = -1
	_confirm_upgrade = false
	_market_sell = {}
	_market_rows = {}
	_queue_rebuild()


## Is there a sheet of paper over the farm right now?
##
## Reads the same panel flags `_open_panel` writes, plus the expand card --
## that one is drawn OUTSIDE the elif chain, so it can be the only thing on
## top of the farm and would otherwise not count as "something is open".
func _something_is_open() -> bool:
	return _challenges_open or _orders_open or _shop_open or _market_open or _barn_open \
		or _visit_open or _recipes_open or _kitchen_open or _gift_open \
		or _confirm_expand >= 0


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


## One capsule for how close in the farm is drawn: plus above, minus below,
## a hairline between.
##
## Pinching works too, but these are the way it is MEANT to be done: two
## fingers on a tablet is a gesture a six-year-old performs by accident more
## often than on purpose, and a control he cannot find is a control he does
## not have. Greyed rather than hidden at the ends of the range, so the pair
## does not move about.
##
## Bottom-right, just above the shelf, on purpose twice over: it is the
## corner a tablet-holding thumb already rests near, and it is the one edge
## of the farm with nothing under it -- the first cut floated two separate
## squares at the top-right, where they sat on the purse's shoulder and over
## the expansion stones, and every screenshot read as three things fighting
## for one corner.
func _view_buttons(view: Vector2) -> void:
	var tile := 64.0
	var pad := 20.0
	var origin := Vector2(view.x - tile - pad,
		view.y - SHELF - tile * 2.0 - 1.0 - pad)

	var shell := Panel.new()
	shell.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 22))
	shell.position = origin
	shell.custom_minimum_size = Vector2(tile, tile * 2.0 + 1.0)
	shell.size = Vector2(tile, tile * 2.0 + 1.0)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(shell)
	# The capsule sits over the farm, and Node._input runs before the GUI:
	# without this, every press on + would also be a tap on the ground
	# beneath it, and two presses would be the go-home double tap.
	_world.add_blocker(shell)

	var hairline := ColorRect.new()
	hairline.color = Color(0.30, 0.27, 0.22, 0.14)
	hairline.position = origin + Vector2(12, tile)
	hairline.size = Vector2(tile - 24.0, 1)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(hairline)

	for step: int in [1, -1]:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = "+" if step > 0 else "−"
		button.add_theme_font_size_override("font_size", 38)
		var live := _world != null and _world.can_zoom(step)
		button.add_theme_color_override("font_color",
			Color(0.24, 0.21, 0.16) if live else Color(0.72, 0.70, 0.65))
		button.add_theme_color_override("font_disabled_color",
			Color(0.72, 0.70, 0.65))
		button.position = origin if step > 0 else origin + Vector2(0, tile + 1.0)
		button.custom_minimum_size = Vector2(tile, tile)
		button.size = Vector2(tile, tile)
		button.disabled = not live
		var direction: int = step
		button.pressed.connect(func():
			_world.zoom_by(direction)
			_queue_rebuild())
		_play.add_child(button)
		_world.add_blocker(button)
		_panel_buttons["zoom_in" if step > 0 else "zoom_out"] = button


## Where the first seed tile sits, and how far apart the tiles are.
##
## Read by the layout below AND by the finger that points at the rack, which is
## the whole reason they are up here. The pointer used to aim at the middle of
## the shelf -- view.x * 0.5 -- which is the empty gap between the last seed and
## the barn: the lesson said "pick a seed and drag it into the earth" while a
## spotlight sat on nothing at all.
const RACK_X := 16.0 + SEED_TILE.x * 0.5
const RACK_STEP := SEED_TILE.x + 4.0


## The whole lower possession row moves together: seeds, its page arrows,
## and barn. Keeping a named answer gives a held seed enough bottom margin
## to rise to full size without falling outside the glass.
func _seed_lane_y(view: Vector2) -> float:
	return view.y - 38.0


## The seed pouch hugs the actual collection: fourteen crops fit one row,
## and a younger farm with four keeps a shorter pouch.
func _seed_deck_width(slots: int) -> float:
	var last := RACK_X + RACK_STEP * float(maxi(slots, 1) - 1)
	return last + SEED_TILE.x * 0.5 - 12.0 + 2.0


## The paging chevron is part of the seed collection.  It reuses UiKit's
## compact button behaviour rather than the roomy sheet chip, then adopts the
## dock's quiet paint so a one-letter arrow does not become another card.
func _seed_page_button(direction: String) -> Button:
	var button := UiKit.compact_button(direction, Color(0.98, 0.94, 0.83),
		Vector2(60, 60), 26)
	# Paging is a detail of the seed collection, not a second raised button in
	# the dock.  Preserve UiKit's existing size, sound and press behaviour while
	# letting the warm seed lane carry the grouping.
	button.add_theme_stylebox_override("normal", _quiet_surface_style(
		Color(0.98, 0.94, 0.83), 16, Color(0.68, 0.49, 0.23, 0.28), 1, 8))
	button.add_theme_stylebox_override("hover", _quiet_surface_style(
		Color(1.0, 0.97, 0.89), 16, Color(0.68, 0.49, 0.23, 0.48), 1, 8))
	button.add_theme_stylebox_override("pressed", _quiet_surface_style(
		Color(0.94, 0.86, 0.69), 16, Color(0.60, 0.42, 0.19, 0.48), 1, 8))
	for slot in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		button.add_theme_color_override(slot, Palette.INK)
	button.size = Vector2(60, 60)
	return button


func _seed_rack(view: Vector2) -> void:
	var shelf_h := SHELF
	var shelf := Panel.new()
	# A honey-coloured tray packs the two existing rows into 140px. Tools
	# and seeds keep separate 60px targets and their actual capture bounds.
	var shelf_style := _quiet_surface_style(Color(0.97, 0.93, 0.83), 0,
		Color(0.68, 0.49, 0.23, 0.50))
	shelf_style.border_width_top = 2
	shelf.add_theme_stylebox_override("panel", shelf_style)
	shelf.position = Vector2(0, view.y - shelf_h)
	shelf.custom_minimum_size = Vector2(view.x, shelf_h)
	shelf.size = Vector2(view.x, shelf_h)
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(shelf)
	_shelf = shelf

	# These low-contrast lanes are passive backers under the existing controls,
	# not a new toolbar or input path.  Their colour is enough to orient a child
	# without carving the dock into a second dashboard.
	var tool_deck := Panel.new()
	tool_deck.name = "GardenToolDeck"
	tool_deck.add_theme_stylebox_override("panel", _quiet_surface_style(
		Color(0.87, 0.77, 0.57, 0.30), 20, Color(0.65, 0.46, 0.21, 0.25), 1))
	tool_deck.position = Vector2(12.0, view.y - SHELF + 2.0)
	tool_deck.custom_minimum_size = Vector2(minf(560.0, view.x - 24.0), 64.0)
	tool_deck.size = tool_deck.custom_minimum_size
	tool_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(tool_deck)

	# The tool row and the seed row each have sixty-pixel targets, with six
	# pixels between rows. Seed-only capture bounds protect the upper tools.
	var unlocked: Array = _farm().get("unlocked_crops", [])
	var chosen := _tools.crop_to_plant(unlocked)
	# All fourteen familiar crops fit one row. A future larger catalogue
	# still uses the same pager and real drag targets.
	var rack_pages := int(ceil(unlocked.size() / float(RACK_PAGE)))
	_rack_page = clampi(_rack_page, 0, maxi(rack_pages - 1, 0))
	var on_page: Array = unlocked.slice(_rack_page * RACK_PAGE,
		(_rack_page + 1) * RACK_PAGE)
	var seed_deck := Panel.new()
	seed_deck.name = "GardenSeedDeck"
	seed_deck.add_theme_stylebox_override("panel", _quiet_surface_style(
		Color(0.87, 0.77, 0.57, 0.30), 20, Color(0.65, 0.46, 0.21, 0.25), 1))
	seed_deck.position = Vector2(12.0, _seed_lane_y(view) - 32.0)
	seed_deck.custom_minimum_size = Vector2(
		minf(_seed_deck_width(on_page.size()), view.x - 24.0), 64.0)
	seed_deck.size = seed_deck.custom_minimum_size
	seed_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(seed_deck)
	for i in range(on_page.size()):
		var crop_id := str(on_page[i])
		var crop: Dictionary = GameData.get_crop(crop_id)
		if crop.is_empty():
			continue
		var at := _rack_tile_centre(i)
		var tile := Node2D.new()
		tile.name = "GardenSeedArt_%s" % crop_id
		tile.position = at
		tile.set_meta("grab_rect", Rect2(-SEED_TILE * 0.5, SEED_TILE))
		_play.add_child(tile)
		var slot := Panel.new()
		slot.name = "SeedSlot_%s" % crop_id
		slot.position = -SEED_TILE * 0.5
		slot.size = SEED_TILE
		slot.add_theme_stylebox_override("panel", _inventory_surface(true, crop_id == chosen))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(slot)
		var art := _crop_picture(crop_id, 46.0, "SeedPicture_%s" % crop_id)
		if art != null:
			art.position = Vector2(-23.0, -23.0)
			tile.add_child(art)
		if crop_id == chosen:
			var selected := Panel.new()
			selected.name = "SeedSelectedMark"
			selected.position = Vector2(SEED_TILE.x * 0.5 - 23.0, -SEED_TILE.y * 0.5 + 4.0)
			selected.size = Vector2(19.0, 19.0)
			selected.add_theme_stylebox_override("panel", _quiet_surface_style(
				Color(0.36, 0.42, 0.19), 8, Color(0.36, 0.42, 0.19), 0, 0))
			selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(selected)
			var tick := UiKit.picture("check", 15.0)
			if tick != null:
				tick.position = Vector2(2.0, 2.0)
				tick.modulate = Color(1.0, 0.98, 0.83)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				selected.add_child(tick)
		_field.add_item(tile, at, crop_id)

		# A TAP on the tile arms the seed brush with this crop; a DRAG from it
		# is the classic single planting, untouched. The two do not fight: the
		# button only fires when the finger comes up still inside it, and a
		# drag has left by then -- so the same tile answers both, and which one
		# the child meant is decided by what his finger actually did.
		var pick := Button.new()
		pick.name = "GardenSeed_%s" % crop_id
		pick.flat = true
		pick.focus_mode = Control.FOCUS_NONE
		pick.position = at - SEED_TILE * 0.5
		pick.custom_minimum_size = SEED_TILE
		pick.size = SEED_TILE
		var this_crop := crop_id
		pick.pressed.connect(func(): _choose_seed(this_crop))
		_play.add_child(pick)

	# The rack's page arrows stand directly after the last visible tile whenever
	# there is only one direction to go.  The old next arrow reserved a second,
	# invisible direction slot on page one, so it floated in a strip of cream
	# and read like a stray button instead of part of the seed collection.  A
	# middle page still gets two separate, finger-sized directions.
	if rack_pages > 1:
		var arrow_y: float = _seed_lane_y(view) - 30.0
		var pager_x: float = RACK_X + RACK_STEP * float(on_page.size()) - SEED_TILE.x * 0.5
		var has_back := _rack_page > 0
		var has_next := _rack_page < rack_pages - 1
		# A passive warm backer gives the pale arrow a clear home in
		# the seed family.  On the future middle page it grows to hold both
		# directions; it never takes input away from the existing buttons.
		var pager_deck := Panel.new()
		pager_deck.name = "GardenSeedPagerDeck"
		pager_deck.add_theme_stylebox_override("panel", _quiet_surface_style(
			Color(0.87, 0.77, 0.57, 0.30), 18, Color(0.65, 0.46, 0.21, 0.25), 1))
		pager_deck.position = Vector2(pager_x - 2.0, _seed_lane_y(view) - 32.0)
		pager_deck.custom_minimum_size = Vector2(132.0 if has_back and has_next else 64.0,
			64.0)
		pager_deck.size = pager_deck.custom_minimum_size
		pager_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play.add_child(pager_deck)
		if _rack_page > 0:
			var back := _seed_page_button("<")
			back.position = Vector2(pager_x, arrow_y)
			back.pressed.connect(func():
				AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
				_rack_page -= 1
				_queue_rebuild())
			_play.add_child(back)
			_panel_buttons["rack_back"] = back
		if _rack_page < rack_pages - 1:
			var next := _seed_page_button(">")
			next.position = Vector2(
				pager_x + (68.0 if has_back and has_next else 0.0), arrow_y)
			next.pressed.connect(func():
				AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
				_rack_page += 1
				_queue_rebuild())
			_play.add_child(next)
			_panel_buttons["rack_next"] = next


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

	# A plot in the middle of its harvest is not tappable. This is the whole of
	# that rule, and it lives in memory rather than in the save on purpose: a
	# tablet closed mid-animation must not come back holding a patch of earth
	# that is permanently mid-animation and can never be touched again.
	if plot_id in _harvesting:
		return

	match str(plot.get("state", Farm.EMPTY)):
		Farm.EMPTY:
			plot["state"] = Farm.TILLED
			AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		Farm.READY:
			_harvest(plot, index)
		Farm.NEEDS_CARE:
			plot = _care_for(plot, index)
		Farm.TILLED:
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
		_:
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
	if str(plot.get("plot_id", "")) in _harvesting:
		return false
	# Ripe beds ask for the crop's own move, judged by the same recognisers
	# 丰收行动 judges by. Care beds stay tap-only: arming gesture intent on
	# them bisected as the change that silently broke later harvest taps
	# (2026-09-04 session) -- re-attempt only with that mystery solved.
	if str(plot.get("state", "")) == Farm.READY:
		return not HarvestCrops.gesture_for(str(plot.get("crop_id", ""))).is_empty()
	if str(plot.get("state", "")) == Farm.NEEDS_CARE:
		return CARE_MOVES.has(str(plot.get("care_event", "")))
	return false


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
	# The bed may have changed while the finger was down; judge the bed that
	# IS, not the one the finger landed on.
	var state := str(plot.get("state", ""))
	if str(plot.get("plot_id", "")) in _harvesting:
		return
	if state == Farm.NEEDS_CARE:
		# The care move: pour, pull or shoo, judged by the same recogniser
		# the harvest moves are. Success does the care the tap would have;
		# anything else was a pan that happened to start on a bed.
		var care: Dictionary = CARE_MOVES.get(str(plot.get("care_event", "")), {})
		if care.is_empty():
			return
		if Gesture.satisfied(str(care["recogniser"]), care["params"],
				track, centre):
			plot = _care_for(plot, index)
			plots[index] = plot
			_commit_plot(plots, index)
			return
		if _world != null and is_instance_valid(_world):
			_world.pan_by(net)
		return
	if state != Farm.READY:
		return
	var move := HarvestCrops.gesture_for(str(plot.get("crop_id", "")))
	if move.is_empty():
		return
	if Gesture.satisfied(str(move["recogniser"]), move["gesture_params"],
			track, centre):
		Juice.burst(_play, _bed_centre(index), 12)
		_harvest(plot, index)
		_commit_plot(plots, index)
		return
	if _world != null and is_instance_valid(_world):
		_world.pan_by(net)


## The care a NEEDS_CARE bed asks for, done: water, weed or shoo, each with
## its sound, the water one with its drip response and its day-tally. Shared
## by the tap and by the care gestures, because "the same care from a
## different hand" must be the same care. Returns the plot in its new state.
func _care_for(plot: Dictionary, index: int) -> Dictionary:
	var cared_at := GameClock.now_unix()
	match str(plot.get("care_event", "")):
		Growth.CARE_THIRSTY:
			plot = Growth.reanchor(Growth.water(plot), cared_at)
			AudioManager.play_sfx("res://assets/audio/water.ogg")
			_daily_progress("water")
			if _world != null and is_instance_valid(_world):
				_world.drink_bed(index)
		Growth.CARE_WEEDS:
			plot = Growth.reanchor(Growth.weed(plot), cared_at)
			AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
		Growth.CARE_BUG:
			plot = Growth.reanchor(Growth.shoo(plot), cared_at)
			AudioManager.play_sfx("res://assets/audio/rustle.ogg")
		_:
			# Waiting for care, but not for anything with a name. Repair
			# it rather than leave a plot no tap can ever move.
			plot["state"] = Farm.GROWING
			plot = Growth.reanchor(plot, cared_at)
	return plot


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
	Juice.burst(_play, _bed_centre(index), 30)
	if not Juice.motion_enabled() or _play == null:
		return
	for i in range(6):
		var star := UiKit.picture("star_coin", 26.0)
		if star == null:
			continue
		star.position = _bed_centre(index) \
			+ Vector2(float(i - 3) * 16.0, -10.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_harvest_feedback_layer().add_child(star)
		var t := star.create_tween()
		t.tween_interval(0.06 * float(i))
		t.tween_property(star, "position",
			star.position + Vector2(0.0, -90.0 - float(i) * 8.0), 0.6)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(star, "modulate:a", 0.0, 0.6)
		t.tween_callback(star.queue_free)


## The transactional half of picking: pay once, store everything, reset the
## bed. Shared by the tap and by the basket brush, because the promise "one
## planting is paid for exactly once" must not have two implementations that
## can drift. Returns an immutable crop/amount receipt, or {} for a repeat.
##
## THE TRANSACTION ID
##
## `farm_harvest_<plot_id>_<plant_cycle_id>` -- the patch of earth, and which
## planting in it. plant_cycle_id rises by one every time a seed goes in and
## never resets, so no two harvests in the history of a save can ever produce
## the same id, and the same id presented twice is always a repeat.
## A ripe bed the ledger says was already paid for, turned back into earth.
## Nothing is stored and nothing is paid: the ledger is the truth about
## money, and this is the truth about the earth. Walks plant_cycle_id past
## every id the ledger knows so the NEXT planting in this bed is a planting
## that pays.
func _free_a_bed_paid_twice(plot: Dictionary, paid: Array) -> void:
	var plot_id := str(plot.get("plot_id", ""))
	var cycle := int(plot.get("plant_cycle_id", 0))
	var next := cycle + 1
	while ("farm_harvest_%s_%d" % [plot_id, next]) in paid:
		next += 1
	push_warning("garden: bed %s cycle %d was already paid for; freed without pay"
		% [plot_id, cycle])
	var fresh: Dictionary = Farm.fresh_plot(0)
	fresh["plot_id"] = plot_id
	fresh["state"] = Farm.TILLED
	fresh["plant_cycle_id"] = next - 1
	for k in fresh.keys():
		plot[k] = fresh[k]
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")


func _harvest_core(plot: Dictionary) -> Dictionary:
	var farm := _farm()
	var plot_id := str(plot.get("plot_id", ""))
	var crop_id := str(plot.get("crop_id", ""))
	var cycle := int(plot.get("plant_cycle_id", 0))
	var key := "farm_harvest_%s_%d" % [plot_id, cycle]

	var paid: Array = farm.get("paid_harvests", [])
	if not paid is Array:
		paid = []
	# Ask first, take second. If this is a repeat nothing at all happens --
	# including no crops into the barn, which is the half that would otherwise
	# have kept paying out silently.
	if not RewardManager.record("garden:harvest:%s" % crop_id, key, paid):
		# A repeat. The tap-while-animating and restart-after-save repeats
		# arrive on a bed that is already reset; nothing to do. But a READY
		# bed whose id is in the ledger is a bed that can never be picked:
		# the tap returned here, silently, forever. Two tablets merging
		# their ledgers can make one (paid_harvests is unioned while the
		# beds are kept from one side). Free the bed -- no crops, no coins,
		# and an id the ledger has not seen for its next planting.
		if str(plot.get("state", "")) == Farm.READY:
			_free_a_bed_paid_twice(plot, paid)
		return {}
	Farm.remember_paid(farm, key)
	# The farm grows up a little. INSIDE the gate on purpose: a repeat that
	# was refused above pays no xp either, so the level inherits the same
	# once-per-planting promise as the crops.
	_earn_xp("harvest")

	_harvesting[plot_id] = true

	var crop: Dictionary = GameData.get_crop(crop_id)
	var picked := maxi(int(crop.get("harvest_amount", 1)), 1)
	# Was THIS planting golden? Read before the reset below wipes the field:
	# the receipt is the only place the celebration can learn it from, and
	# gold changes how the harvest FELT, never what it paid.
	var was_golden := bool(plot.get("golden", false))
	# Into the barn, and whatever does not fit into the basket by its door.
	# NOT Barn.put(): put() now answers "how many actually went in", and a
	# harvest that ignores that answer is a harvest that silently eats crops
	# the moment the barn is full. store_harvest() is the only call that
	# guarantees stored + spilled == picked.
	var learned: Array = []
	var landed := Barn.store_harvest(crop_id, picked)
	_daily_progress("harvest", picked)
	learned = Recipes.check_barn()
	if not learned.is_empty():
		_recipe_learned_card(learned[0])

	# The plot goes back to TURNED EARTH rather than to grass.
	#
	# A deviation from the brief, which says EMPTY, and a deliberate one: going
	# back to grass means three swipes of tilling between every harvest and the
	# next seed, forever, for a six-year-old who has already learned what
	# tilling is. The lesson is worth teaching once, not once per carrot.
	#
	# plant_cycle_id survives the reset. It is the only field that does, and it
	# has to: reset it and the next planting in this bed would reuse a
	# transaction id that has already been paid for, and the harvest after that
	# would pay nothing at all.
	var fresh: Dictionary = Farm.fresh_plot(0)
	fresh["plot_id"] = plot_id
	fresh["state"] = Farm.TILLED
	fresh["plant_cycle_id"] = cycle
	for k in fresh.keys():
		plot[k] = fresh[k]

	# The one other thing this garden ever teaches: the first time the barn
	# gets close to full, say the market's name once and point at its box.
	# A flag, not a schedule -- taught is taught, exactly like the lesson.
	if not bool(farm.get("market_taught", false)) \
			and Barn.total() >= Barn.cap() - 6:
		farm["market_taught"] = true
		AudioManager.say("farm_market_hint")
		_market_finger_queued = true

	_release_after_the_animation(plot_id)
	return {
		"crop_id": crop_id,
		"amount": picked,
		"stored": int(landed.get("stored", 0)),
		"spilled": int(landed.get("spilled", 0)),
		"golden": was_golden,
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
	_plant_in(index, str(item.get("key", "")))
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
func _plant_in(index: int, crop_id: String) -> void:
	var plots := _plots()
	if index < 0 or index >= plots.size() or crop_id == "":
		return
	var plot: Dictionary = plots[index]
	if str(plot.get("state", "")) != Farm.TILLED:
		return
	plot["crop_id"] = crop_id
	plot["state"] = Farm.SEEDED
	# A new planting, and therefore a new transaction id for whatever comes out
	# of it. Rising by one here is the whole reason a harvest cannot be paid
	# for twice; see _harvest_core().
	plot["plant_cycle_id"] = int(plot.get("plant_cycle_id", 0)) + 1
	plot["planted_at"] = GameClock.now_unix()
	plot["last_updated_at"] = GameClock.now_unix()
	plot["growth_stage"] = 0
	plot["growth_progress"] = 0.0
	plot["water_level"] = 1.0
	plot["care_event"] = ""
	plot["care_completed"] = false
	# The lesson's carrot, and nothing else ever, runs on its own clock: six
	# seconds from seed to ripe so the child sees the end of what he started
	# while he is still crouched over it. Cleared by the harvest, because a
	# picked bed is reset from Farm.fresh_plot().
	# "The lesson's carrot, and nothing else ever" -- the code said "anything
	# planted while the lesson is on". Corn in bed three grew in six seconds,
	# every visit, until the first order was handed over.
	var lesson_seed: bool = _lesson_running and index == _lesson_plot() \
		and crop_id == str(GameData.garden_tutorial.get("crop_id", "carrot"))
	plot["growth_override_seconds"] = _tutorial_growth if lesson_seed else 0
	# One roll per PLANTING, not per crop: the whole plant is golden for its
	# whole life, which is why the glow is worth walking over to see. Rare on
	# purpose -- a bed in twenty-five -- because the whole value of gold is
	# that it is an event, and a reward the harvest hands out either way
	# (the yield is exactly the crop's own; gold changes the celebration,
	# never the numbers).
	plot["golden"] = not _lesson_running \
		and randf() < _golden_chance()
	plots[index] = plot
	SaveManager.data["farm"]["plots"] = plots


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

## The seven tools, along the top row of the shelf.
##
## The FIRST one is the hand, and the hand is the old game: tap a bed, it does
## the one thing it wants. Always selected on the way in, never grey, never
## taken away. The six after it are batch brushes for a farm that has more
## beds than a morning has taps -- and a brush with no work anywhere is drawn
## grey and dead, because a tool that can be picked up and then does nothing
## teaches him that tools sometimes do nothing.
func _tool_bar(view: Vector2) -> void:
	_tool_buttons.clear()
	# The choice has to be honest before it is drawn: if the tool in his hand
	# ran out of work while the screen was away, it is the hand again now.
	_auto_return()

	var x := 16.0
	var y := view.y - SHELF + 6.0
	for tool in Tools.TOOLS:
		var tool_id := str(tool.get("id", ""))
		var live: bool = tool_id == Tools.HAND \
			or _tools.work_exists(tool_id, _plots())
		var held: bool = _tools.selected == tool_id

		var button := Button.new()
		button.name = "GardenTool_%s" % tool_id
		button.flat = false
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(x, y)
		button.custom_minimum_size = Vector2(72, 60)
		button.size = Vector2(72, 60)
		button.pivot_offset = Vector2(36, 30)
		# Tools and seeds share the same warm inset material. The chosen tool
		# keeps a darker edge; its established size and label remain unchanged.
		var fill := Color(0.98, 0.94, 0.83) if live else Color(0.91, 0.88, 0.81)
		var edge := Color(0.48, 0.34, 0.14) if held else Color(0.69, 0.52, 0.28, 0.42)
		var normal := _tool_tile_style(fill, edge, held)
		var hover := _tool_tile_style(fill.lightened(0.025), edge, held, not held)
		var pressed := _tool_tile_style(fill.darkened(0.025), edge, held, not held)
		var disabled := _tool_tile_style(Color(0.91, 0.88, 0.81),
			Color(0.69, 0.62, 0.48, 0.28), false)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", normal)
		button.add_theme_stylebox_override("disabled", disabled)
		button.tooltip_text = I18n.t(_tools.label_key(tool_id))
		button.disabled = not live
		button.modulate = Color(1, 1, 1, 1.0 if live else 0.82)
		var art := _tool_picture(tool, 30.0)
		if art != null:
			art.name = "GardenToolIcon"
			art.position = Vector2(21, 2)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.modulate.a = 1.0 if live else 0.40
			button.add_child(art)
		var label := UiKit.title(I18n.t(_tools.label_key(tool_id)), 14,
			Color(0.30, 0.28, 0.24) if live else Color(0.58, 0.57, 0.54))
		label.name = "GardenToolLabel"
		# The 30px picture ends at 32, followed by a 2px gutter and Noto's
		# 24px line box. The touch target remains 60px tall.
		label.position = Vector2(2.0, 34.0)
		label.size = Vector2(68.0, 24.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		# Pressing SHRINKS it under the finger -- the cheap half of feeling
		# mechanical -- and release springs it back.
		button.button_down.connect(func():
			if Juice.motion_enabled():
				var t := button.create_tween()
				t.tween_property(button, "scale", Vector2(0.90, 0.90), 0.06))
		button.button_up.connect(func():
			if Juice.motion_enabled():
				var t := button.create_tween()
				t.tween_property(button, "scale", Vector2.ONE, 0.10)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		button.pressed.connect(func(): _select_tool(tool_id))
		_play.add_child(button)
		_tool_buttons[tool_id] = button
		x += 80.0


func _select_tool(tool_id: String) -> void:
	if _tools.selected == tool_id:
		return
	_tools.selected = tool_id
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
	if _world == null or not is_instance_valid(_world):
		return
	var targets: Array = []
	if _tools.selected != Tools.HAND and not _something_is_open():
		for i in range(_plots().size()):
			if _tools.needs(_tools.selected, _plots()[i]):
				targets.append(i)
	var primary := int(task.get("index", -1))
	_world.set_tool_targets(targets, _tool_target_color(_tools.selected), primary)


## Reuse the same warm/cool task palette for the in-world target rings. Tool
## semantics remain in FarmToolController; this only gives each existing kind
## the visual family children have already learned from the task ribbon.
func _tool_target_color(tool_id: String) -> Color:
	match tool_id:
		"basket": return _next_task_color({"kind": "harvest"})
		"water", "weed", "bug": return _next_task_color({"kind": "care"})
		"seed": return _next_task_color({"kind": "plant"})
		"shovel": return _next_task_color({"kind": "till"})
		_: return Color(1.0, 1.0, 1.0)


## Tapping a seed tile arms the seed brush with that crop, in one move. No
## separate "now choose a crop" step: the tile IS the choice, and the ring
## drawn around it is the receipt.
func _choose_seed(crop_id: String) -> void:
	_tools.seed_crop = crop_id
	if _tools.selected != "seed":
		_tools.selected = "seed"
		AudioManager.say("farm_tool_seed")
	_world.brush_armed = true
	AudioManager.play_sfx("res://assets/audio/drag_pick.ogg")
	_queue_rebuild()


## The tool ran out of work: back to the hand, on its own, silently. Silently
## because coming back is not an instruction -- there is nothing he must do
## about it -- and a line here would talk over the praise for the job he just
## finished.
func _auto_return() -> void:
	if _tools.selected == Tools.HAND:
		return
	if not _tools.work_exists(_tools.selected, _plots()):
		_tools.selected = Tools.HAND
		if _world != null and is_instance_valid(_world):
			_world.brush_armed = false


## One bed swept by the brush. The two gates (once per stroke, and only beds
## that need it) live in the stroke bookkeeping; this is what happens to a bed
## that passes them.
func _on_stroke_swept(index: int) -> void:
	if not _stroke.may_apply(_tools, _plots(), index):
		return
	var plots := _plots()
	var plot: Dictionary = plots[index]
	match _tools.selected:
		"shovel":
			plot["state"] = Farm.TILLED
			AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		"seed":
			_plant_in(index, _tools.crop_to_plant(_farm().get("unlocked_crops", [])))
			plot = plots[index]
			AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
		"water":
			plot = Growth.reanchor(Growth.water(plot), GameClock.now_unix())
			AudioManager.play_sfx("res://assets/audio/water.ogg")
			_daily_progress("water")
			if _world != null and is_instance_valid(_world):
				_world.drink_bed(index)
		"weed":
			plot = Growth.reanchor(Growth.weed(plot), GameClock.now_unix())
			AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
		"bug":
			plot = Growth.reanchor(Growth.shoo(plot), GameClock.now_unix())
			AudioManager.play_sfx("res://assets/audio/rustle.ogg")
		"basket":
			var receipt: Dictionary = _harvest_core(plot)
			if not receipt.is_empty():
				_combo += int(receipt.get("amount", 0))
				_show_combo(index, receipt)
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				if bool(receipt.get("golden", false)):
					_celebrate_golden(index)
	plots[index] = plot
	SaveManager.data["farm"]["plots"] = plots
	# The bed changes under the brush as it passes -- that is the whole show --
	# but nothing is SAVED yet: one stroke is one write, at the end.
	_world.refresh(plots)
	_sync_tool_target_halos()


## The finger lifted. Now the stroke is a fact: write it down once, praise it
## once, and put the hand back if the tool has nothing left to do.
func _on_stroke_ended() -> void:
	var did := _stroke.applied
	_stroke.begin()
	if did == 0:
		# Swept, but over nothing that needed this tool. Not an error and not
		# silence either: the tool itself shrugs, so the answer is "nothing to
		# do HERE" rather than "nothing happened", which reads as broken.
		var button: Variant = _tool_buttons.get(_tools.selected)
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


## The running count of a harvest stroke, big and in the middle where the
## crops are flying from. "x3" is a number he can read.
func _harvest_feedback_layer() -> CanvasLayer:
	if _harvest_feedback == null or not is_instance_valid(_harvest_feedback):
		_harvest_feedback = CanvasLayer.new()
		_harvest_feedback.name = "HarvestFeedbackLayer"
		_harvest_feedback.layer = 2
		add_child(_harvest_feedback)
	return _harvest_feedback


func _show_combo(index: int, receipt: Dictionary) -> void:
	if _combo_label == null or not is_instance_valid(_combo_label):
		_combo_label = UiKit.title("", 64, Color(1.0, 0.62, 0.12))
		_combo_label.name = "HarvestYield"
		_combo_label.position = Vector2(get_viewport_rect().size.x * 0.5 - 70.0,
			TOP_BAR + 30.0)
		_combo_label.size = Vector2(140, 72)
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_harvest_feedback_layer().add_child(_combo_label)
	_combo_label.text = "x%d" % _combo
	Juice.pop(_combo_label, 0.22)
	_fly_to_barn(index, receipt)


## The picked crop flies from its bed to the place that really received it.
## A partial harvest deliberately has two small receipts: otherwise a child
## sees all three carrots fly to the barn even though one is waiting in the
## overflow basket, and the screen tells the opposite story to the inventory.
func _fly_to_barn(index: int, receipt: Dictionary) -> void:
	if not Juice.motion_enabled():
		return
	var crop_id := str(receipt.get("crop_id", ""))
	if crop_id == "" or index < 0 or index >= _plots().size():
		return
	# Older callers supplied only `amount`; keep that harmless shape meaning
	# "all stored" while the harvesting path now carries the full receipt.
	var stored := maxi(int(receipt.get("stored", receipt.get("amount", 0))), 0)
	var spilled := maxi(int(receipt.get("spilled", 0)), 0)
	if stored > 0:
		_spawn_harvest_flight(index, receipt, stored, _barn_button_at,
			"warehouse", "HarvestFlight")
	if spilled > 0:
		_spawn_harvest_flight(index, receipt, spilled, _spill_flight_destination(),
			"harvest_basket", "HarvestSpillFlight")


## One visual receipt. Both destinations use this exact component so crop art,
## golden tint, timing and cleanup cannot drift apart while only the honest
## destination and quantity vary.
func _spawn_harvest_flight(index: int, receipt: Dictionary, amount: int,
		destination_at: Vector2, destination: String, node_prefix: String,
		from_at: Vector2 = Vector2.INF) -> void:
	var crop_id := str(receipt.get("crop_id", ""))
	var golden := bool(receipt.get("golden", false))
	var art := _crop_picture(crop_id, 44.0, "HarvestCropPicture", golden)
	if art == null:
		return
	art.name = "%s_%s" % [node_prefix, crop_id]
	art.set_meta("crop_id", crop_id)
	art.set_meta("amount", amount)
	art.set_meta("total_amount", int(receipt.get("amount", amount)))
	art.set_meta("stored", int(receipt.get("stored", amount)))
	art.set_meta("spilled", int(receipt.get("spilled", 0)))
	art.set_meta("destination", destination)
	art.set_meta("destination_at", destination_at)
	art.set_meta("golden", bool(receipt.get("golden", false)))
	# The flight lives 0.4 s. A receipt of it stays on the screen so a slow
	# frame (a probe under software GL, a tablet mid-save) can still ask
	# "what flew, and how much" after the sprite itself has gone.
	var stamp := {"node": art.name, "crop_id": crop_id, "amount": amount,
		"destination": destination, "destination_at": destination_at}
	set_meta("last_harvest_flight", stamp)
	# One stroke across two beds makes two flights 0.4 s apart; the first is
	# gone before the second is asked about. Keep the last few, in order.
	var flights: Array = get_meta("harvest_flights", [])
	flights.append(stamp)
	while flights.size() > 8:
		flights.pop_front()
	set_meta("harvest_flights", flights)
	if bool(receipt.get("golden", false)):
		# The one that came up gold flies gold: the same flight, telling the
		# same story, in the colour the bed promised.
		art.modulate = Color(1.0, 0.85, 0.35)
	var root_offset := Vector2.ZERO
	var start := from_at if from_at.is_finite() else _bed_centre(index)
	art.position = start - Vector2(22, 22) + root_offset
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_harvest_feedback_layer().add_child(art)
	# When one crop batch splits, the little x2 / x1 tags answer the question
	# a single flying icon cannot: how much reached each real destination.
	if amount != int(receipt.get("amount", amount)):
		var count := UiKit.on_art(UiKit.title("×%d" % amount, 20, Color.WHITE), 4)
		count.name = "FlightAmount"
		count.position = Vector2(24.0, -13.0)
		count.size = Vector2(46.0, 24.0)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(count)
	var t := art.create_tween()
	t.tween_property(art, "position", destination_at - Vector2(22, 22) + root_offset, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(art, "scale", Vector2(0.5, 0.5), 0.4)
	t.tween_callback(art.queue_free)


func _end_combo() -> void:
	_combo = 0
	if _combo_label != null and is_instance_valid(_combo_label):
		var label := _combo_label
		_combo_label = null
		if Juice.motion_enabled():
			var t := label.create_tween()
			t.tween_property(label, "modulate:a", 0.0, 0.5)
			t.tween_callback(label.queue_free)
		else:
			label.queue_free()


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
	var room_id := str(level_data.get("config", {}).get("deco_room", ""))
	if room_id == "" or GameData.get_level(room_id).is_empty():
		return
	var box := Vector2(60, 60)
	# Keep the lower possession lane clear for the overflow basket. This door
	# used to cover its entire image while receipts kept flying underneath it.
	var at := Vector2(view.x - 16.0 - box.x, view.y - SHELF + 6.0)
	var b := Button.new()
	b.name = "DecoDoor"
	b.focus_mode = Control.FOCUS_NONE
	b.position = at
	b.custom_minimum_size = box
	b.size = box
	b.add_theme_stylebox_override("normal", _quiet_surface_style(
		Color(0.97, 0.93, 0.83), 16, Color(0.73, 0.60, 0.38, 0.26), 1))
	b.add_theme_stylebox_override("hover", _quiet_surface_style(
		Color(0.99, 0.96, 0.88), 16, Color(0.73, 0.60, 0.38, 0.48), 1))
	b.add_theme_stylebox_override("pressed", _quiet_surface_style(
		Color(0.93, 0.88, 0.76), 16, Color(0.67, 0.51, 0.31, 0.48), 1))
	var art: Control = UiKit.picture("sticker_book", 38.0)
	if art != null:
		art.position = Vector2((box.x - 38.0) * 0.5, (box.y - 38.0) * 0.5)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(art)
	b.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		GameManager.start_level(room_id))
	_play.add_child(b)


## What he arranged in the decorating room, standing in the farm itself.
##
## Drawn from the SAME creation the 装饰间 saves (its canvas_id, read from
## data), mapped from the room's design space onto the whole farm world, and
## deliberately mute: no input, no buttons, z below the beds. A decoration
## that can swallow a tap meant for a plot is furniture blocking the door --
## the home screen's clear_lane taught that lesson already.
## What the furniture looked like when it was last drawn. See _draw_decorations.
var _deco_drawn := ""


func _drop_decorations(old: Node) -> void:
	_deco_drawn = ""
	if old != null:
		old.name = "DecorationsGone"
		old.queue_free()


func _draw_decorations() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var old: Node = _world.get_node_or_null("Decorations")
	var room_id := str(level_data.get("config", {}).get("deco_room", ""))
	var room: Dictionary = GameData.get_level(room_id) if room_id != "" else {}
	if room.is_empty():
		_drop_decorations(old)
		return
	var key := str(room.get("config", {}).get("canvas_id", room_id))
	var placed: Array = SaveManager.get_creation(key)
	if placed.is_empty():
		_drop_decorations(old)
		return
	# Same arrangement, same furniture. The decorations used to be thrown
	# away and redrawn on every rebuild: a wiggle in flight was cut off by
	# the rebuild that followed the poke, and the idle bob restarted from
	# zero every time anything happened.
	var stamp := JSON.stringify(placed) + str(get_viewport_rect().size)
	if stamp == _deco_drawn and old != null:
		return
	_drop_decorations(old)
	_deco_drawn = stamp
	var layer := Node2D.new()
	layer.name = "Decorations"
	_world.add_child(layer)
	# Between the ground and everything that stands on it. FarmWorld layers
	# by CHILD ORDER, not z_index -- a z of -1 rendered the furniture under
	# the grass itself, which the first screenshot said plainly by showing
	# nothing at all. Ground is child 0; slot 1 is "on the grass, behind the
	# beds and the buildings", which is where furniture belongs.
	_world.move_child(layer, 1)
	var world: Vector2 = Layout.world_size()
	for entry in placed:
		var size := clampf(float(entry.get("size", 84.0)), 40.0, 160.0)
		var art: Control = UiKit.picture(str(entry.get("icon", "star")), size)
		if art == null:
			continue
		# The room's canvas is its design screen; the farm is a 2200x1150
		# world. Fractions carry the arrangement across: left stays left,
		# high stays high, and nothing depends on either screen's pixels.
		# The room lays its canvas out on the REAL viewport -- 1280x960 on
		# a 4:3 tablet -- so the fraction is taken against that, not against
		# the design size: divided by 720, everything he placed in the lower
		# third of an iPad screen piled up on the bottom fence.
		var canvas: Vector2 = get_viewport_rect().size
		var fx := clampf(float(entry.get("x", 640.0)) / maxf(canvas.x, 1.0), 0.0, 1.0)
		var fy := clampf(float(entry.get("y", 300.0)) / maxf(canvas.y, 1.0), 0.0, 1.0)
		art.position = Vector2(fx * (world.x - size), fy * (world.y - size))
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 三期阶段 3：家具活了一点。围着自己的中心一点点呼吸式起伏，
		# 周期各自错开——一排同拍点头的家具是布景，不是院子。
		# （先进树再上发条：create_tween 只认树上的节点。）
		art.pivot_offset = art.size * 0.5
		layer.add_child(art)
		Juice.idle_bob(art, 2.0, 2.6 + 0.37 * float(layer.get_child_count()))


## 三期阶段 3：家具会答话，但永远排在最后。
##
## 这里接的是世界的 grass_pressed——地块、建筑、石头都没认领的那种
## 点击。所以"家具从不吞掉给地里的手指"这条红线原样成立：装饰的
## mouse_filter 还是 IGNORE，它从不接输入，只是剩下的点击落在它身上
## 时，它答应一声。挤压回弹加一下歪头，首页 poke 的语言；只动
## scale/rotation，不进存档，不算玩法。
func _poke_decoration(at: Vector2) -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var layer: Node = _world.get_node_or_null("Decorations")
	if layer == null:
		return
	var spot: Vector2 = _world.camera.screen_to_world(at)
	for child in layer.get_children():
		if not (child is Control):
			continue
		var art := child as Control
		if not Rect2(art.position, art.size).has_point(spot):
			continue
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		Juice.pop(art, 0.16)
		# Written down before the wiggle, for two readers: the probe, which
		# used to read `rotation` 0.12 s later and lost the race on a slow
		# frame; and the reduce-motion case, which used to be no answer.
		art.set_meta("poked_at", GameClock.ticks_ms())
		if not Juice.motion_enabled():
			Juice.pop(art, 0.1)
		if Juice.motion_enabled():
			var t := art.create_tween()
			t.tween_property(art, "rotation", 0.13, 0.11)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(art, "rotation", -0.09, 0.15)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(art, "rotation", 0.0, 0.13)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return


func _barn(view: Vector2) -> void:
	# Inside the shelf, to the right of the seeds. The first cut put it just
	# above the shelf and it landed on top of the bottom row of beds -- there
	# is no room between them at 16:9, and "your seeds | your barn" belongs
	# together anyway: both are things he HAS.
	# The rack can grow to six tiles now, so the shelf keeps only the short
	# version: the basket and how full it is. The pile itself -- which crops,
	# how many of each -- lives one tap away behind the barn's own door, which
	# is where a pile that size belongs. "40" stays here because it is the
	# number he needs to have seen BEFORE the day he fills it.
	# A real card, pinned to the shelf's right edge with the same margin the
	# rack starts with -- the first cut floated a bare label at 65% of the
	# width, which read as text that had fallen off something.
	var box := BARN_CARD
	var at := Vector2(view.x - 16.0 - box.x, _seed_lane_y(view) - box.y * 0.5)
	var card := Panel.new()
	card.name = "GardenBarnCard"
	card.add_theme_stylebox_override("panel",
		_inventory_surface(true))
	card.position = at
	card.custom_minimum_size = box
	card.size = box
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(card)

	var basket := HarvestArt.prop_badge("basket_empty", 36.0, "BarnBasketPicture")
	if basket != null:
		basket.position = at + Vector2(12.0, box.y * 0.5 - 18.0)
		basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play.add_child(basket)
	var label := UiKit.title(I18n.t("garden.barn"), 17, Color(0.55, 0.51, 0.44))
	label.position = at + Vector2(58.0, 6.0)
	label.size = Vector2(82, 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(label)
	var room := UiKit.title("%d/%d" % [Barn.total(), Barn.cap()], 22)
	room.position = at + Vector2(58.0, 24.0)
	room.size = Vector2(82, 25)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(room)
	# The same tiny capacity rail as the farm-level chip turns the number into
	# a shape a five-year-old can compare at a glance.
	var rail := Panel.new()
	rail.name = "BarnCapacityRail"
	rail.add_theme_stylebox_override("panel", UiKit.track_style())
	rail.position = at + Vector2(58.0, 51.0)
	rail.size = Vector2(82.0, 5.0)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(rail)
	var fill := Panel.new()
	fill.name = "BarnCapacityFill"
	fill.add_theme_stylebox_override("panel", UiKit.fill_style(Color(0.95, 0.66, 0.20)))
	fill.position = rail.position + Vector2(2.0, 2.0)
	fill.size = Vector2(78.0 * clampf(float(Barn.total()) / float(maxi(Barn.cap(), 1)),
		0.0, 1.0), 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(fill)

	# This card already looks like a button, so make it the child's shortest
	# path to the existing barn panel instead of asking him to rediscover the
	# world building that represents the same storage.
	var press := Button.new()
	press.name = "BarnShortcut"
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = at
	press.custom_minimum_size = box
	press.size = box
	press.pressed.connect(func(): _open_panel("barn"))
	_play.add_child(press)
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(press)
	_barn_button_at = at + Vector2(box.x * 0.5, box.y * 0.5)

	_spilled_basket(view)


## The basket by the barn door: what he picked when the barn was already full.
##
## Drawn ONLY when there is something in it, and drawn as a pile of crops rather
## than as a warning. Nothing here is lost and nothing here is urgent -- the
## basket empties itself back into the barn the moment an order or a sale makes
## room (InventoryManager.tip_basket_in), so there is no errand to give him and
## no red badge to give him it with.
func _spilled_basket(view: Vector2) -> void:
	var spilled := Barn.contents(Barn.BASKET)
	if spilled.is_empty():
		return
	# The upper row reserves a fixed slot beside the task ribbon. Two crops
	# summarize the pile; its touch target opens every waiting crop below.
	# All spill flights land on the same rim as the number of kinds changes.
	var at := spilled_basket_anchor(view)
	var rim := Panel.new()
	rim.name = "OverflowBasketSlot"
	rim.position = at + Vector2(-6.0, -10.0)
	rim.size = Vector2(42.0, 38.0)
	rim.add_theme_stylebox_override("panel", _inventory_surface(true))
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(rim)
	var pile := HarvestArt.prop_badge("basket_empty", 30.0, "HarvestOverflowBasket")
	if pile != null:
		pile.name = "HarvestOverflowBasket"
		pile.set_meta("crop_kinds", spilled.size())
		pile.set_meta("destination_at", at + Vector2(15.0, 9.0))
		pile.modulate = Color(1.0, 0.94, 0.78)
		pile.position = Vector2(at.x, at.y - 6.0)
		_play.add_child(pile)
	var x := at.x - 8.0 - float(mini(spilled.size(), 2)) * 66.0
	for pair in spilled.slice(0, 2):
		var art := _crop_picture(str(pair[0]), 26.0, "OverflowPicture_%s" % str(pair[0]))
		if art != null:
			art.position = Vector2(x, at.y - 4.0)
			_play.add_child(art)
		var many := UiKit.title("x%d" % int(pair[1]), 18)
		many.position = Vector2(x + 24.0, at.y)
		many.size = Vector2(44, 22)
		many.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play.add_child(many)
		x += 66.0

	if spilled.size() > 2:
		var more_badge := Panel.new()
		more_badge.position = at + Vector2(-6.0, -20.0)
		more_badge.size = Vector2(40.0, 22.0)
		more_badge.add_theme_stylebox_override("panel", _quiet_surface_style(
			Color(1.0, 0.91, 0.68), 9, Color(0.60, 0.45, 0.22), 1, 0))
		more_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play.add_child(more_badge)
		var more := UiKit.title("+%d" % (spilled.size() - 2), 14, Color(0.42, 0.32, 0.18))
		more.name = "OverflowMoreKinds"
		more.size = Vector2(40.0, 22.0)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		more_badge.add_child(more)

	# The bounded summary has a way to inspect every waiting crop. It opens
	# the same collection sheet on the existing BASKET store, never a new bag.
	var press := Button.new()
	press.name = "OverflowShortcut"
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = Vector2(view.x - 268.0, view.y - SHELF + 6.0)
	press.custom_minimum_size = Vector2(188.0, 60.0)
	press.size = press.custom_minimum_size
	press.pressed.connect(func(): _open_panel("basket"))
	_play.add_child(press)


## Pure shelf geometry, shared by the rebuilt overflow pile and every flight
## already on its way there. Crop rows extend left; this landing rim never does.
static func spilled_basket_anchor(view: Vector2) -> Vector2:
	return Vector2(view.x - 118.0, view.y - SHELF + 27.0)


func _spill_flight_destination() -> Vector2:
	return spilled_basket_anchor(get_viewport_rect().size) + Vector2(15.0, 9.0)


## Who needs a hand today. Three cards, each one a picture of somebody, what
## they want, and what they will give for it.
func _order_board(view: Vector2) -> void:
	FarmOrdersPanel.new(self).build(view)


## One-time requests have a purpose and get their turn before routine baskets.
## Routine baskets rotate by the existing delivery ledger; ties keep file order.
## No date, random seed, or new save field is needed, including for old saves.
static func select_orders_for_board(catalogue: Array, delivered: Array,
		counts: Dictionary, farm_level: int) -> Array:
	var story: Array = []
	var recurring: Array = []
	var receipts: Array = []
	for index in range(catalogue.size()):
		var order: Dictionary = catalogue[index]
		var gate := str(order.get("unlock_condition", ""))
		if gate.begins_with("level:") and farm_level < int(gate.substr(6)):
			continue
		var order_id := str(order.get("id", ""))
		if bool(order.get("recurring", false)):
			recurring.append({"order": order, "index": index,
				"count": maxi(0, int(counts.get(order_id, 0)))})
		elif order_id in delivered:
			receipts.append(order)
		else:
			story.append(order)
	recurring.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) == int(b["count"]):
			return int(a["index"]) < int(b["index"])
		return int(a["count"]) < int(b["count"]))
	var board: Array = story.slice(0, ORDER_BOARD_CARDS)
	for row in recurring:
		if board.size() == ORDER_BOARD_CARDS:
			break
		board.append(row["order"])
	while board.size() < ORDER_BOARD_CARDS and not receipts.is_empty():
		board.append(receipts.pop_back())
	return board


func _orders_for_board(delivered: Array) -> Array:
	var counts: Dictionary = SaveManager.data.get("farm_orders", {}).get("counts", {})
	return select_orders_for_board(GameData.garden_orders, delivered, counts, Level.level())

## Top left of the order board, measured from the viewport every time -- see
## _bed_centre for why nothing here may be measured from a hard-coded 720.
func _order_board_origin() -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(view.x * 0.5 - ORDER_CARD.x * 0.5, TOP_BAR + 46.0)


## The middle of one order's card, for the lesson's finger to land on. Walks
## the BOARD, not the file -- the finger must land where the card is drawn.
func _order_card_centre(order_id: String) -> Vector2:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	var at := _order_board_origin()
	var y := at.y + ORDER_FIRST
	for order in _orders_for_board(delivered):
		if str(order.get("id", "")) == order_id:
			break
		y += ORDER_GAP
	return Vector2(at.x, y) + ORDER_CARD * 0.5


## Collect a finished day-job. The date is inside the once-key, so a claim
## pays once today and once again tomorrow, and never twice in either.
func _claim_daily(task: Dictionary) -> void:
	var farm := _farm()
	var dailies: Dictionary = Dailies.roll(farm, GameClock.now_date())
	if Dailies.claimed(dailies, task) or not Dailies.done(dailies, task):
		return
	var claimed_list: Array = dailies.get("claimed", [])
	var paid := RewardManager.grant("garden:daily",
		int(task.get("coins", 0)), Dailies.claim_key(dailies, task),
		claimed_list)
	if paid > 0:
		dailies["claimed"] = claimed_list
		SaveManager.data["farm"]["dailies"] = dailies
		SaveManager.save_game()
		AudioManager.play_sfx("res://assets/audio/coin.ogg")
		AudioManager.say("praise_2")
		_queue_rebuild()


func _close_orders() -> void:
	_orders_open = false
	_queue_rebuild()


## Hand the basket over.
##
## The order of these four lines is the whole of "an order pays once". The
## barn is emptied and the delivery recorded and the save written BEFORE any
## animation, because an await here with the recording after it is exactly how
## a second press pays twice -- and a six-year-old presses things twice.
func _deliver(order: Dictionary) -> void:
	var order_id := str(order.get("id", ""))
	var orders: Dictionary = SaveManager.data.get("farm_orders", {})
	var delivered: Array = orders.get("delivered", [])
	var recurring := bool(order.get("recurring", false))

	# Asked BEFORE the barn is touched, and that order matters. The first cut
	# emptied the barn first and only then asked whether this order had already
	# been paid for -- so an order delivered twice would have taken three more
	# carrots and given nothing back. The card is disabled once delivered, so
	# it was unreachable, but "unreachable" is a property of today's screen and
	# not of the rule. A recurring order has no "delivered" to check -- its
	# once-only proof is the delivery COUNT below, not the ledger.
	if not recurring and order_id in delivered:
		return
	var wants: Dictionary = order.get("requirements", {})
	if not Barn.pay(wants):
		return
	var paid := 0
	if recurring:
		# Delivery N's once-key names N: no earlier delivery ever used it, so
		# a second press on the same card pays the same delivery once -- the
		# same promise the friends' own orders keep, kept a different way.
		var counts: Dictionary = orders.get("counts", {})
		var n := int(counts.get(order_id, 0)) + 1
		counts[order_id] = n
		orders["counts"] = counts
		var once_key := "%s:%d" % [
			str(order.get("completion_transaction_key", order_id)), n]
		var ledger: Array = orders.get("recurring_paid", [])
		paid = RewardManager.grant("garden:order:%s" % order_id,
			int(order.get("rewards", {}).get("coins", 0)), once_key, ledger)
		orders["recurring_paid"] = ledger
	else:
		paid = RewardManager.grant("garden:order:%s" % order_id,
			int(order.get("rewards", {}).get("coins", 0)), order_id, delivered)
	if paid > 0:
		# The thank-you gifts ride the same once-only gate as the coins: paid
		# is only ever above zero the first time this order_id goes through.
		# Today that is one plank per friend -- the three the barn's bigger
		# roof is built from, each one seen arriving rather than found in a
		# menu. Recurring orders carry no gifts; their gift is that they exist.
		var gifts: Dictionary = order.get("rewards", {}).get("items", {})
		for item_id in gifts.keys():
			Barn.put(str(item_id), int(gifts[item_id]), "inventory")
		# Helping a friend grows the farm most of all -- and only the first
		# time this order goes through, same gate as the coins above. For a
		# recurring order every delivery is a first delivery, and that is the
		# design: tending beds is how the farm grows up, forever.
		_earn_xp("order")
		_daily_progress("deliver")
	orders["delivered"] = delivered
	SaveManager.data["farm_orders"] = orders
	SaveManager.save_game()

	# Handing the first basket over is the end of the lesson, and the only end
	# it has. Written down here rather than on a timer, because "he has been
	# taught" should mean he did the whole thing once -- turned the earth, put
	# a seed in, watered it, picked it, and gave it to somebody who wanted it.
	_the_lesson_is_over()

	if paid > 0:
		AudioManager.play_sfx("res://assets/audio/coin.ogg")
		AudioManager.say("praise_2")
		_harvested_something = true
		_offer_a_break()
		_order_thanks(order)
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


func _order_customer_art(order: Dictionary, box: float) -> Control:
	if str(order.get("customer_icon", "")) == "res://assets/harvest_3d/props/rabbit.png":
		return HarvestArt.prop_badge("rabbit", box, "RabbitOrderPortrait")
	return UiKit.picture(str(order.get("customer_icon", "heart")), box)


## A friend's response is feedback, never a dialog to dismiss. The existing
## collection layer keeps it alive through the paid order's redraw.
func _order_thanks(order: Dictionary) -> void:
	var key := str(order.get("thanks_key", ""))
	if key.is_empty():
		return
	var layer := _harvest_feedback_layer()
	var old := layer.get_node_or_null("OrderThanks")
	if old != null:
		old.name = "ExpiredOrderThanks"
		old.queue_free()
	var card := Panel.new()
	card.name = "OrderThanks"
	card.set_meta("order_id", str(order.get("id", "")))
	card.add_theme_stylebox_override("panel", UiKit.panel_style(
		Color(1.0, 0.98, 0.89, 0.98), 20))
	card.position = Vector2((get_viewport_rect().size.x - 450.0) * 0.5, TOP_BAR + 14.0)
	card.size = Vector2(450.0, 64.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var face := _order_customer_art(order, 44.0)
	if face != null:
		face.position = Vector2(12.0, 10.0)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
	var words := UiKit.title(I18n.t(key), 18, Color(0.34, 0.31, 0.23))
	words.name = "OrderThanksText"
	words.position = Vector2(68.0, 10.0)
	words.size = Vector2(370.0, 44.0)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(words)
	Juice.pop(card, 0.05)
	var lifetime := card.create_tween()
	lifetime.tween_interval(3.0)
	lifetime.tween_property(card, "modulate:a", 0.0, 0.25)
	lifetime.tween_callback(card.queue_free)


# --- the shop, the market box, and the barn's own door --------------------

## A button that is exactly the size it is asked to be. UiKit.big_button
## carries its own minimum size and shadow for full-screen choices; inside a
## panel's rows it balloons over its neighbours -- the first cut of the shop
## had two 买下 stacked into one green blob hanging off the sheet.
func _chip_button(text: String, fill: Color, box: Vector2) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	var bold := UiKit.bold_font()
	if bold != null:
		b.add_theme_font_override("font", bold)
	var font_sz: int = int(roundf(box.y * 0.40))
	if text.length() >= 4:
		font_sz = mini(font_sz, 16)
	elif text.length() >= 3:
		font_sz = mini(font_sz, 17)
	else:
		font_sz = mini(font_sz, 19)
	b.add_theme_font_size_override("font_size", font_sz)
	var is_dark := fill.get_luminance() < 0.62
	var text_col := Palette.ON_COLOR if is_dark else Color(0.20, 0.17, 0.13)
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.48))
	b.add_theme_stylebox_override("normal", UiKit.chip_style(fill, 16))
	b.add_theme_stylebox_override("hover", UiKit.chip_style(Palette.lift(fill), 16))
	b.add_theme_stylebox_override("pressed", UiKit.chip_style(fill.darkened(0.08), 16))
	b.add_theme_stylebox_override("focus", UiKit.chip_style(fill, 16))
	b.add_theme_stylebox_override("disabled", UiKit.chip_style(Color(0.88, 0.86, 0.82), 16))
	b.custom_minimum_size = box
	b.size = box
	return b


## The scaffolding every panel shares: a sheet over the farm, a title, and a
## way out in the corner a way out is always in. Registered as a blocker so
## pressing the paper can never reach the ground behind it.
## The way out of a sheet of paper, written once: sixty pixels of dark slate
## (the thumb floor the touch probe measures), one light letter, a corner
## radius that matches the paper's own. Both the market family and the order
## board hang this in their top-right corner; the only thing that varies is
## where the corner is and what closing means.
func _sheet_close(at: Vector2, on_pressed: Callable) -> Button:
	var shut := Button.new()
	shut.flat = false
	shut.focus_mode = Control.FOCUS_NONE
	shut.text = "X"
	shut.add_theme_font_size_override("font_size", 26)
	for slot in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		shut.add_theme_color_override(slot, Palette.ON_COLOR)
	shut.position = at
	shut.custom_minimum_size = Vector2(60, 60)
	shut.size = Vector2(60, 60)
	for look in ["normal", "hover", "pressed", "focus"]:
		shut.add_theme_stylebox_override(look,
			UiKit.chip_style(Palette.SLATE, 16))
	shut.pressed.connect(on_pressed)
	_play.add_child(shut)
	# It stands over the farm now, not over the paper: a press on it must
	# not also reach the bed underneath.
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(shut)
	return shut


func _panel_sheet(view: Vector2, title_key: String, wide: float,
		tall: float) -> Vector2:
	var origin := Vector2(view.x * 0.5 - wide * 0.5, TOP_BAR + 16.0)
	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.99, 0.97, 0.90), 28))
	if title_key in ["garden.warehouse_title", "garden.waiting_harvest_title"]:
		sheet.name = "BarnCollectionPanel"
		sheet.add_theme_stylebox_override("panel", _inventory_surface())
	sheet.position = origin
	sheet.custom_minimum_size = Vector2(wide, tall)
	sheet.size = Vector2(wide, tall)
	_play.add_child(sheet)
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(sheet)

	var title := UiKit.title(I18n.t(title_key), 22, Color(0.29, 0.24, 0.16)) \
		if title_key in ["garden.warehouse_title", "garden.waiting_harvest_title"] else UiKit.title(I18n.t(title_key), 24, Color(0.26, 0.22, 0.17))
	title.position = origin + Vector2(28, 12)
	title.size = Vector2(wide - 130.0, 32)
	if title_key in ["garden.warehouse_title", "garden.waiting_harvest_title"]:
		title.name = "BarnCollectionTitle"
		title.position = origin + Vector2(28.0, 8.0)
		title.size.y = 28.0
	_play.add_child(title)

	# The way out of the paper: same dark slate as the back button, at the
	# thumb floor the touch probe measures (60px, 3:1), and quiet about it --
	# a 26-point letter in a tight little pill instead of a slab that shouts
	# over the heading it sits beside. See _sheet_close.
	_sheet_close(origin + Vector2(wide + 14.0, 0.0), _close_panels)
	return origin


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


## Side arrows for a sheet with more rows than glass: the world map's page
## language shrunk to a panel. Arrows stand OUTSIDE the paper, vertically
## centred, and only the one that goes somewhere is drawn -- an arrow that
## shakes its head is a lock wearing a different hat. `flip` receives -1/+1;
## the caller owns the page variable and the clamp.
func _pager(origin: Vector2, wide: float, tall: float, page: int,
		pages: int, flip: Callable) -> void:
	if pages <= 1:
		return
	if page > 0:
		var back := _chip_button("<", Color(0.99, 0.96, 0.88), Vector2(60, 76))
		back.position = Vector2(origin.x - 74.0, origin.y + tall * 0.5 - 38.0)
		back.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			flip.call(-1))
		_play.add_child(back)
		if _world != null and is_instance_valid(_world):
			_world.add_blocker(back)
		_panel_buttons["page_back"] = back
	if page < pages - 1:
		var next := _chip_button(">", Color(0.99, 0.96, 0.88), Vector2(60, 76))
		next.position = Vector2(origin.x + wide + 14.0,
			origin.y + tall * 0.5 - 38.0)
		next.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			flip.call(+1))
		_play.add_child(next)
		if _world != null and is_instance_valid(_world):
			_world.add_blocker(next)
		_panel_buttons["page_next"] = next


## The seed shop: six rows a page, and on every row the three numbers the red
## line demands be visible BEFORE any confirm button exists -- what it costs,
## how long it grows, how many come off. Nothing here is a one-press purchase.
## A seed of a level the farm has not grown to is a dim silhouette with the
## star badge saying which level -- 圈好的地 on a shelf, never a lock.
func _shop_panel(view: Vector2) -> void:
	FarmShopPanel.new(self).build(view)


## The confirm card: the crop, the price, and two honest buttons. Drawn on top
## of the shop's rows, inside the same sheet, so the blocker already covers it.
func _confirm_card(view: Vector2, origin: Vector2, wide: float) -> void:
	var crop: Dictionary = GameData.get_crop(_confirm_crop)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 24))
	card.position = Vector2(origin.x + wide * 0.5 - 220.0, origin.y + 110.0)
	card.custom_minimum_size = Vector2(440, 210)
	card.size = Vector2(440, 210)
	_play.add_child(card)

	var art := UiKit.picture(str(crop.get("icon", "seed")), 64.0)
	if art != null:
		art.position = card.position + Vector2(56, 36)
		_play.add_child(art)
	var coin := UiKit.picture("star_coin", 40.0)
	if coin != null:
		coin.position = card.position + Vector2(170, 48)
		_play.add_child(coin)
	var price_tag := UiKit.title(str(SeedShop.price_of(_confirm_crop)), 38)
	price_tag.position = card.position + Vector2(220, 46)
	price_tag.size = Vector2(120, 46)
	_play.add_child(price_tag)

	var yes := _chip_button(I18n.t("garden.buy"),
		Color(0.72, 0.88, 0.60), Vector2(160, 60))
	yes.position = card.position + Vector2(44, 124)
	yes.pressed.connect(_buy_confirmed)
	_play.add_child(yes)
	_panel_buttons["confirm_buy"] = yes

	var no := _chip_button(I18n.t("garden.cancel"),
		Color(0.78, 0.86, 0.97), Vector2(160, 60))
	no.position = card.position + Vector2(236, 124)
	no.pressed.connect(func():
		_confirm_crop = ""
		_queue_rebuild())
	_play.add_child(no)
	_panel_buttons["cancel_buy"] = no


func _buy_confirmed() -> void:
	var crop_id := _confirm_crop
	_confirm_crop = ""
	if SeedShop.buy(crop_id) != "":
		# Refused -- owned already, or the coins moved under him. Nothing was
		# taken, so nothing needs saying beyond the rows redrawing honestly.
		_queue_rebuild()
		return
	_pending_undo = {"kind": "seed", "id": crop_id,
		"until": GameClock.ticks_ms() + UNDO_WINDOW_MS}
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	AudioManager.say("farm_shop_bought")
	_queue_rebuild()


## The market box: what the barn holds on the left, the box on the right, and
## the total climbing as crops are dragged in. NOTHING moves out of the barn
## until 卖掉 is pressed -- shutting the panel forgets the box and loses
## nothing, which is what makes dragging things in safe to play with.
func _market_panel(view: Vector2) -> void:
	FarmMarketPanel.new(self).build(view)


## A pile landed in the box: remember it, give it its stepper row, and move
## the total. No rebuild -- DragField has already sat the chip in the box, and
## rebuilding mid-gesture is forbidden anyway.
func _on_market_drop(item: Dictionary, slot: Variant, correct: bool) -> void:
	if not _market_open or not correct or slot == null:
		return
	var crop_id := str(item.get("key", ""))
	_market_sell[crop_id] = Barn.count(crop_id)
	if not _market_rows.has(crop_id):
		_ensure_market_row(crop_id)
	_market_refresh_row(crop_id)
	_market_sync_rows_visibility()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")


## One receipt row: the crop, its boxed count, and two thumb-sized ways to
## change it. The scroll area owns overflow; the total and commit button stay
## fixed so every crop can be sold without covering the action.
func _ensure_market_row(crop_id: String) -> void:
	if _market_rows.has(crop_id) or _market_rows_list == null \
			or not is_instance_valid(_market_rows_list):
		return
	var row := PanelContainer.new()
	row.name = "MarketBoxRow_%s" % crop_id
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.custom_minimum_size = Vector2(274.0, 50.0)
	row.add_theme_stylebox_override("panel", _quiet_surface_style(
		Color(1.0, 0.99, 0.93), 13, Color(0.67, 0.58, 0.39, 0.24), 1, 4))
	_market_rows_list.add_child(row)
	var line := HBoxContainer.new()
	line.name = "MarketReceiptLine"
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_theme_constant_override("separation", 4)
	row.add_child(line)
	var art := UiKit.picture(
		str(GameData.get_crop(crop_id).get("icon", "seed")), 32.0)
	if art != null:
		art.custom_minimum_size = Vector2(36.0, 40.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(art)
	var count := UiKit.title("x%d" % int(_market_sell.get(crop_id, 0)), 19)
	count.name = "BoxCount_%s" % crop_id
	count.custom_minimum_size = Vector2(54.0, 34.0)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(count)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	var minus := _chip_button("−", Color(0.99, 0.86, 0.74), Vector2(44.0, 44.0))
	minus.name = "BoxMinus_%s" % crop_id
	minus.pressed.connect(func(): _market_step(crop_id, -1))
	line.add_child(minus)
	var plus := _chip_button("+", Color(0.88, 0.95, 0.84), Vector2(44.0, 44.0))
	plus.name = "BoxPlus_%s" % crop_id
	plus.pressed.connect(func(): _market_step(crop_id, +1))
	line.add_child(plus)
	_market_rows[crop_id] = {"row": row, "count": count}


func _market_sync_rows_visibility() -> void:
	var has_boxed := not _market_sell.is_empty()
	if _market_rows_scroll != null and is_instance_valid(_market_rows_scroll):
		_market_rows_scroll.visible = has_boxed
	if _market_drop_hint != null and is_instance_valid(_market_drop_hint):
		_market_drop_hint.visible = not has_boxed


## The box row redraws its number and the shelf chip answers with what is
## still on the shelf -- the pair of numbers is the whole "sell some, keep
## the rest" decision, and both move on every press.
func _market_refresh_row(crop_id: String) -> void:
	var entry: Variant = _market_rows.get(crop_id, null)
	if entry is Dictionary and (entry as Dictionary).get("count") is Label:
		var label: Label = (entry as Dictionary)["count"]
		if is_instance_valid(label):
			label.text = "x%d" % int(_market_sell.get(crop_id, 0))
	_market_refresh_shelf(crop_id)
	if _market_total != null and is_instance_valid(_market_total):
		_market_total.text = str(Market.quote(_market_sell))
		Juice.pop(_market_total, 0.12)


## The shelf chip's half of the two numbers. Called on every step INCLUDING
## the one that empties the box for a crop -- that is the step that hands the
## whole pile back, and a shelf that still says "x0" after it is a lie.
func _market_refresh_shelf(crop_id: String) -> void:
	var chip_count := _play.find_child("PileCount_%s" % crop_id, true, false)
	if chip_count is Label and is_instance_valid(chip_count):
		(chip_count as Label).text = "x%d" % (
			Barn.count(crop_id) - int(_market_sell.get(crop_id, 0)))


## Put this crop card back on the barn shelf when its receipt count reaches
## zero. The receipt is the basket's live contents; an empty row with a card
## still parked in the crate would tell a different story.
func _market_return_to_shelf(crop_id: String) -> void:
	if _market_field == null or not is_instance_valid(_market_field):
		return
	for item in _market_field.items():
		if str(item.get("key", "")) != crop_id \
				or not bool(item.get("placed", false)):
			continue
		var slot: Variant = item.get("slot", {})
		if slot is Dictionary and not slot.is_empty():
			slot["held"] = maxi(0, int(slot.get("held", 0)) - 1)
		item["placed"] = false
		item["slot"] = {}
		var node_value: Variant = item.get("node")
		if not is_instance_valid(node_value) or not (node_value is Node2D):
			return
		var card := node_value as Node2D
		var home: Vector2 = item.get("home", item.get("at", Vector2.ZERO))
		_market_field.cancel_item_motion(item)
		card.position = home
		card.scale = Vector2.ONE
		card.z_index = 0
		return


## One crop, one step. The floor is an empty box for that crop -- the row
## leaves with it, and the shelf chip comes back whole. The ceiling is the
## barn itself: boxed crops never left the barn, so "all of them" is always
## one press away.
func _market_step(crop_id: String, delta: int) -> void:
	var boxed := clampi(int(_market_sell.get(crop_id, 0)) + delta,
		0, Barn.count(crop_id))
	if boxed == 0:
		_market_sell.erase(crop_id)
	else:
		_market_sell[crop_id] = boxed
	if boxed == 0:
		if _market_rows.has(crop_id):
			var entry: Variant = _market_rows[crop_id]
			if entry is Dictionary and (entry as Dictionary).get("row") is Node:
				var row: Node = (entry as Dictionary)["row"]
				if is_instance_valid(row):
					row.queue_free()
			_market_rows.erase(crop_id)
		_market_return_to_shelf(crop_id)
	_market_refresh_row(crop_id)
	_market_sync_rows_visibility()
	AudioManager.play_sfx("res://assets/audio/%s"
		% ("drag_snap.ogg" if delta > 0 else "drag_back.ogg"))


func _sell_pressed() -> void:
	var paid := Market.sell(_market_sell)
	if paid <= 0:
		# A refused sale keeps its receipt and card placement unchanged.
		var button: Variant = _panel_buttons.get("sell")
		if button is Button and is_instance_valid(button):
			Juice.nudge(button, 8.0)
		return
	_market_sell = {}
	_market_rows = {}
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	AudioManager.say("farm_market_sold")
	# Coins fly to the purse: the one piece of theatre that says where the
	# number went.
	if Juice.motion_enabled() and _play != null:
		var view := get_viewport_rect().size
		for i in range(5):
			var fly := UiKit.picture("star_coin", 30.0)
			if fly == null:
				continue
			fly.position = Vector2(view.x * 0.5, view.y * 0.45) \
				+ Vector2(float(i - 2) * 22.0, 0)
			_play.add_child(fly)
			var t := fly.create_tween()
			t.tween_interval(0.05 * float(i))
			t.tween_property(fly, "position",
				Vector2(view.x - 160.0, 40.0), 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(fly.queue_free)
	_queue_rebuild()


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
	# Three ways to be refused, and all three used to return without a
	# redraw: the confirm card stayed up over a button that did nothing.
	if Barn.cap() >= Farm.WAREHOUSE_UPGRADED \
			or not Barn.has("plank", UPGRADE_PLANKS, "inventory") \
			or not Coins.spend(UPGRADE_COINS):
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_queue_rebuild()
		return
	Barn.take("plank", UPGRADE_PLANKS, "inventory")
	farm["warehouse_cap"] = Farm.WAREHOUSE_UPGRADED
	# Room just appeared out of thin air; anything waiting outside comes in.
	Barn.tip_basket_in()
	SaveManager.save_game()
	_pending_undo = {"kind": "cap", "id": "",
		"until": GameClock.ticks_ms() + UNDO_WINDOW_MS}
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
	if _confirm_expand < 0 or Expand.state_of(_confirm_expand) != "ready":
		return
	var card := Panel.new()
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 24))
	card.position = Vector2(view.x * 0.5 - 210.0, TOP_BAR + 60.0)
	card.custom_minimum_size = Vector2(420, 170)
	card.size = Vector2(420, 170)
	_play.add_child(card)
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(card)

	var art := UiKit.picture("shovel", 52.0)
	if art != null:
		art.position = card.position + Vector2(28, 24)
		_play.add_child(art)
	var coin := UiKit.picture("star_coin", 40.0)
	if coin != null:
		coin.position = card.position + Vector2(110, 30)
		_play.add_child(coin)
	var cost := UiKit.title(str(Expand.cost_of(_confirm_expand)), 34)
	cost.position = card.position + Vector2(162, 34)
	cost.size = Vector2(90, 44)
	_play.add_child(cost)

	var yes := _chip_button(I18n.t("garden.expand"),
		Color(0.72, 0.88, 0.60), Vector2(170, 58))
	yes.position = card.position + Vector2(30, 94)
	yes.pressed.connect(func(): _expand_confirmed(_confirm_expand))
	_play.add_child(yes)
	_panel_buttons["confirm_expand"] = yes
	var no := _chip_button(I18n.t("garden.cancel"),
		Color(0.78, 0.86, 0.97), Vector2(170, 58))
	no.position = card.position + Vector2(220, 94)
	no.pressed.connect(func():
		_confirm_expand = -1
		_queue_rebuild())
	_play.add_child(no)
	_panel_buttons["cancel_expand"] = no


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
	_pending_undo = {"kind": "plot", "id": str(index),
		"until": GameClock.ticks_ms() + UNDO_WINDOW_MS}
	_queue_rebuild()


## One event's worth of farm xp, and the celebration if it crossed a rung.
## Callers are all INSIDE their own once-only gates, which is the whole of
## why the xp cannot be farmed; see farm_level_manager.gd.
func _earn_xp(kind: String) -> void:
	var levels: Array = Level.award(kind)
	if int(levels[1]) <= int(levels[0]):
		return
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	AudioManager.say("farm_level_up")
	if Juice.motion_enabled() and _play != null and is_instance_valid(_play):
		Juice.burst(_play, Vector2(190.0, TOP_BAR * 0.55), 16)
	if int(levels[0]) < 8 and int(levels[1]) >= 8:
		_show_master_farmer_celebration()
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
	var hand := Tutorial.new()
	add_child(hand)
	hand.add_step(at, at, 1.4)
	hand.play()


## The regret window, drawn while it is open. One small card, one button, and
## letting it lapse costs nothing -- it just stops being offered.
## The bear's lesson, the moment it is earned: a card slides in with his
## face, the dish's ingredients, and the name -- then leaves by itself.
## Nothing to dismiss, nothing modal: the harvest that earned it is still
## mid-celebration and this must not interrupt that.
func _recipe_learned_card(recipe: Dictionary) -> void:
	var view: Vector2 = get_viewport_rect().size
	var wide := 520.0
	var card := Panel.new()
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.95, 0.98), 22))
	card.position = Vector2((view.x - wide) * 0.5, 96.0)
	card.custom_minimum_size = Vector2(wide, 116.0)
	card.size = Vector2(wide, 116.0)
	card.z_index = 30
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Collection feedback survives the bed/barn redraw that earned it.
	_harvest_feedback_layer().add_child(card)
	var face := UiKit.picture("teddy", 72.0)
	if face != null:
		face.position = Vector2(20.0, 22.0)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
	var said := UiKit.title(I18n.t("garden.recipe_learned"), UiKit.TYPE_CAPTION,
		Color(0.52, 0.48, 0.40))
	said.position = Vector2(108.0, 18.0)
	said.size = Vector2(wide - 130.0, 26.0)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(said)
	var dish := UiKit.title(I18n.t(str(recipe.get("name_key", ""))), UiKit.TYPE_BODY)
	dish.position = Vector2(108.0, 46.0)
	dish.size = Vector2(wide - 130.0, 34.0)
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(dish)
	var x := 108.0
	for need in recipe.get("needs", []):
		var art := UiKit.picture(
			str(GameData.get_crop(str(need.get("crop_id", ""))).get("icon", "seed")), 26.0)
		if art != null:
			art.position = Vector2(x, 82.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art)
		x += 34.0
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	Juice.pop(card, 0.14)
	var t := card.create_tween()
	t.tween_interval(2.6)
	t.tween_property(card, "modulate:a", 0.0, 0.4)
	t.tween_callback(card.queue_free)


func _show_master_farmer_celebration() -> void:
	var layer := _harvest_feedback_layer()
	var old := layer.get_node_or_null("MasterCelebration")
	if old != null:
		old.name = "ExpiredMasterCelebration"
		old.queue_free()
	var card := Panel.new()
	card.name = "MasterCelebration"
	card.add_theme_stylebox_override("panel", UiKit.panel_style(
		Color(1.0, 0.97, 0.82, 0.98), 20))
	var wide := 480.0
	var tall := 90.0
	var view: Vector2 = get_viewport_rect().size
	card.position = Vector2((view.x - wide) * 0.5, 96.0)
	card.custom_minimum_size = Vector2(wide, tall)
	card.size = Vector2(wide, tall)
	card.z_index = 32
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var crown := UiKit.picture("crown", 48.0)
	if crown != null:
		crown.position = Vector2(16.0, 21.0)
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(crown)
	var title := UiKit.title(I18n.t("farm.level_8_title"), 22, Color(0.68, 0.42, 0.10))
	title.position = Vector2(78.0, 12.0)
	title.size = Vector2(wide - 92.0, 24.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(title)
	var desc := UiKit.title(I18n.t("farm.level_8_desc"), 16, Color(0.42, 0.36, 0.25))
	desc.position = Vector2(78.0, 38.0)
	desc.size = Vector2(wide - 92.0, 20.0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(desc)
	var reward_lbl := UiKit.title(I18n.t("farm.level_8_reward"), 14, Color(0.56, 0.46, 0.22))
	reward_lbl.position = Vector2(78.0, 60.0)
	reward_lbl.size = Vector2(wide - 92.0, 18.0)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(reward_lbl)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	Juice.pop(card, 0.14)
	if Juice.motion_enabled():
		Juice.burst(layer, Vector2(view.x * 0.5, 140.0), 16)
	var t := card.create_tween()
	t.tween_interval(3.6)
	t.tween_property(card, "modulate:a", 0.0, 0.45)
	t.tween_callback(card.queue_free)


func _show_toast_message(text: String, icon_name: String = "") -> void:
	var layer := _harvest_feedback_layer()
	var old := layer.get_node_or_null("ToastBanner")
	if old != null:
		old.name = "ExpiredToastBanner"
		old.queue_free()
	var card := Panel.new()
	card.name = "ToastBanner"
	card.add_theme_stylebox_override("panel", UiKit.panel_style(
		Color(1.0, 0.98, 0.89, 0.98), 20))
	var wide := 500.0
	card.position = Vector2((get_viewport_rect().size.x - wide) * 0.5, TOP_BAR + 14.0)
	card.size = Vector2(wide, 64.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var x_offset := 16.0
	if icon_name != "":
		var art := UiKit.picture(icon_name, 40.0)
		if art != null:
			art.position = Vector2(14.0, 12.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(art)
			x_offset = 64.0
	var words := UiKit.title(text, 17, Color(0.34, 0.31, 0.23))
	words.position = Vector2(x_offset, 10.0)
	words.size = Vector2(wide - x_offset - 16.0, 44.0)
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(words)
	Juice.pop(card, 0.05)
	var lifetime := card.create_tween()
	lifetime.tween_interval(2.8)
	lifetime.tween_property(card, "modulate:a", 0.0, 0.35)
	lifetime.tween_callback(card.queue_free)


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
	if _pending_undo.is_empty():
		return
	if GameClock.ticks_ms() > int(_pending_undo.get("until", 0)):
		_pending_undo = {}
		return
	var card := Panel.new()
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.98, 0.90), 22))
	card.position = Vector2(view.x * 0.5 - 150.0, view.y - SHELF - 84.0)
	card.custom_minimum_size = Vector2(300, 64)
	card.size = Vector2(300, 64)
	_play.add_child(card)
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(card)
	var undo := _chip_button(I18n.t("garden.undo"),
		Color(0.78, 0.86, 0.97), Vector2(160, 48))
	undo.position = card.position + Vector2(70, 8)
	undo.pressed.connect(_undo_pressed)
	_play.add_child(undo)
	_panel_buttons["undo"] = undo


func _undo_pressed() -> void:
	if GameClock.ticks_ms() > int(_pending_undo.get("until", 0)):
		# Pressed after the window shut, on a toast the clock had not yet
		# swept away. Too late is too late; say so quietly.
		_pending_undo = {}
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_queue_rebuild()
		return
	var kind := str(_pending_undo.get("kind", ""))
	var id := str(_pending_undo.get("id", ""))
	_pending_undo = {}
	match kind:
		"seed":
			SeedShop.undo(id)
		"cap":
			# The roof back off: coins and planks returned whole. Crops that
			# came in over 40 while it was big STAY -- the ceiling refuses new
			# things, it never ejects old ones -- so nothing is lost here either.
			var farm := _farm()
			if int(farm.get("warehouse_cap", 0)) >= Farm.WAREHOUSE_UPGRADED:
				farm["warehouse_cap"] = Farm.WAREHOUSE_START
				Coins.refund(UPGRADE_COINS)
				Barn.put("plank", UPGRADE_PLANKS, "inventory")
				SaveManager.save_game()
		"plot":
			# The stones back on -- but only while the new bed is still
			# untouched grass. Earth he has already turned is his earth;
			# Expand.undo() checks and quietly does nothing rather than
			# reach into the farm and take a bed with something in it.
			Expand.undo(int(id))
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
	var plan: Dictionary = GameData.garden_tutorial
	var crop_id := str(plan.get("crop_id", "carrot"))
	_tutorial_growth = int(GameData.get_crop(crop_id).get(
		"tutorial_growth_override", 0))
	_lesson_running = true

	# The greeting is the one line that is not about a job, so it is the one
	# line the garden cannot ask for. Everything after it is.
	_lesson_said = "welcome"
	_say_the_step("welcome")
	_lesson_tick()
	await get_tree().create_timer(WELCOME_BEAT).timeout
	if _lesson_running and is_inside_tree():
		_lesson_advance()


## Say the step the garden is asking for, if it is not the one already said.
##
## Called from _rebuild(), which runs after every action and after every tick
## that changed something -- so this is asked far more often than it answers.
func _lesson_advance() -> void:
	if not _lesson_running:
		return
	var step := _lesson_step()
	if step == "" or step == _lesson_said:
		return
	_lesson_said = step
	_say_the_step(step)


## Which of the six steps the garden is currently asking for, or "" for none.
func _lesson_step() -> String:
	# The last step first, and deliberately out of order: something in the barn
	# that somebody is waiting for beats anything the earth is doing. Handing it
	# over is the end of the lesson, and he is already holding the carrots.
	if _an_order_he_can_fill() != "":
		return "order"

	var index := _lesson_plot()
	var plots := _plots()
	if index < 0 or index >= plots.size():
		return ""
	var plot: Dictionary = plots[index]
	match str(plot.get("state", "")):
		Farm.EMPTY:
			return "till"
		Farm.TILLED:
			return "plant"
		Farm.READY:
			return "harvest"
		Farm.NEEDS_CARE:
			# Only thirst has words. The lesson's carrot never grows weeds --
			# its care_event_types is ["thirsty"] and nothing else -- but a plot
			# waiting for something nobody has recorded a line for should stay
			# quiet rather than say the nearest thing.
			if str(plot.get("care_event", "")) == Growth.CARE_THIRSTY:
				return "water"
	# SEEDED or GROWING: nothing to say. It is just time passing, and a lesson
	# that filled the silence would be asking him to do something he cannot.
	return ""


## Which bed the lesson is about.
##
## Normally the one garden_tutorial.json names, and the finger has been pointing
## at it since the first line. But a child who dropped his seed two beds to the
## left did the thing he was asked to do, and a lesson that carried on pointing
## at bare earth while his carrot grew somewhere else would be teaching him that
## the game is not watching him. So the plant wins over the plan.
func _lesson_plot() -> int:
	var plots := _plots()
	var named := int(GameData.garden_tutorial.get("plot_index", 0))
	if named >= 0 and named < plots.size() and Farm.is_planted(plots[named]):
		return named
	for i in range(plots.size()):
		if Farm.is_planted(plots[i]):
			return i
	return named if named >= 0 and named < plots.size() else -1


## The first order the barn can pay for and nobody has delivered yet, or "".
## Reads the BOARD, not the file: a level-gated order is not there to point
## at, and a finger aimed at a card that is not drawn teaches "the game lies".
func _an_order_he_can_fill() -> String:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	for order in _orders_for_board(delivered):
		var order_id := str(order.get("id", ""))
		if order_id in delivered:
			continue
		if Barn.can_pay(order.get("requirements", {})):
			return order_id
	return ""


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
	var hand := Tutorial.new()
	_play.add_child(hand)
	match what:
		"seed":
			# The one action in the garden that is a drag, shown as one: the
			# finger travels from the rack into the earth.
			hand.add_step(_seed_rack_centre(), bed, 1.4)
		"order":
			# Shut board: point at the BOARD, which is a building on the farm,
			# and let him open it. A finger on a card that is not on the screen
			# is a finger on nothing, and a child who follows it and taps
			# nothing concludes the game is broken -- the same accident the
			# seed rack's spotlight had before it was aimed properly.
			var card: Vector2 = _order_card_centre(_an_order_he_can_fill()) \
				if _orders_open else _world.facility_screen_position("orders")
			hand.add_step(card, card, 1.3)
		_:
			hand.add_step(bed, bed, 1.2)
	hand.play()


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
func _lesson_tick() -> void:
	while _lesson_running and is_inside_tree():
		await get_tree().create_timer(LESSON_TICK).timeout
		if not _lesson_running or not is_inside_tree():
			return
		SaveManager.settle_farm()
		if _how_the_beds_look() != _beds_looked_like:
			_queue_rebuild()


## Everything about the beds that the screen draws, as one string. Comparing
## this is how the tick knows the difference between "a second went by" and
## "something happened", and last_seen_at moving is not something happening.
func _how_the_beds_look() -> String:
	var out := ""
	for plot in _plots():
		out += "%s/%d/%.3f/%s;" % [
			str(plot.get("state", "")),
			int(plot.get("growth_stage", 0)),
			float(plot.get("growth_progress", 0.0)),
			str(plot.get("care_event", "")),
		]
	return out


## Everything about the beds that decides what the SCREEN should be -- ribbon,
## dog, hints -- as one string. Sub-stage growth is deliberately left out: a
## plant that inched a millimetre taller does not need the furniture rebuilt
## over his head, and a rebuild takes a pointing finger down with it. The bed
## art itself does follow the inch, because PlotView.refresh redraws only beds
## whose own fingerprint moved.
func _what_the_beds_mean() -> String:
	var out := ""
	for plot in _plots():
		out += "%s/%d/%s;" % [
			str(plot.get("state", "")),
			int(plot.get("growth_stage", 0)),
			str(plot.get("care_event", "")),
		]
	return out


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
	# The basket's overflow goes in when there is room, on the same beat. Asked
	# here rather than read out of settle_farm's work, because settle runs it
	# too and the second call finds an empty basket -- this way the screen
	# learns whether anything MOVED, which is what the shelf count shows.
	var tipped := Barn.tip_basket_in()
	var ripe_before := {}
	for plot in _plots():
		if Farm.is_ready(plot):
			ripe_before[str(plot.get("plot_id", ""))] = true
	var meant_before := _what_the_beds_mean()
	SaveManager.settle_farm()
	if _world != null and is_instance_valid(_world):
		_world.refresh(_plots())
	_beds_looked_like = _how_the_beds_look()
	if _what_the_beds_mean() == meant_before and tipped == 0:
		return
	if _world != null and is_instance_valid(_world):
		var celebrated := false
		for i in range(_plots().size()):
			var plot: Dictionary = _plots()[i]
			if Farm.is_ready(plot) \
					and not ripe_before.has(str(plot.get("plot_id", ""))):
				if not celebrated:
					celebrated = true
					AudioManager.play_sfx("res://assets/audio/pop.ogg")
				Juice.shockwave(_play, _bed_centre(i), 140.0,
					Color(1.0, 0.94, 0.62, 0.5))
	_queue_rebuild()


## Written down the moment the lesson ends, and never asked again.
func _the_lesson_is_over() -> void:
	if not _lesson_running:
		return
	_lesson_running = false
	var farm := _farm()
	farm["tutorial_completed"] = true
	SaveManager.save_game()


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
	return Vector2(RACK_X + RACK_STEP * float(index), _seed_lane_y(view))


## The one plot that most wants attention, or -1 if the garden is content.
## The ribbon and the dog read this exact priority from FarmToolController too:
## ripe food first, then care, then planting the soil he already turned.
func _the_plot_that_wants_something() -> int:
	return Tools.next_action_index(_plots())


## Help, step one: say it again, and make the thing glow.
func _nudge() -> void:
	var task := _next_task()
	if str(task.get("kind", "")) == "deliver":
		# The basket is already full: the child needs to notice the visitor
		# board, not be sent looking for another patch of dirt.
		AudioManager.say("garden_tut_order")
		if _world != null and is_instance_valid(_world):
			Juice.shockwave(_play, _world.facility_screen_position("orders"),
				140.0, Color(1.0, 0.94, 0.62, 0.5))
		return
	var index := _the_plot_that_wants_something()
	if index < 0:
		return
	var plots := _plots()
	match str(plots[index].get("state", "")):
		Farm.READY: AudioManager.say("garden_tut_harvest")
		Farm.NEEDS_CARE:
			# "Give it some water" for a caterpillar sent him to the
			# watering can. The line follows the badge.
			match str(plots[index].get("care_event", "")):
				Growth.CARE_WEEDS: AudioManager.say("harvest_pull_up")
				Growth.CARE_BUG: AudioManager.say("harvest_shoo_bug")
				_: AudioManager.say("garden_tut_water")
		Farm.EMPTY: AudioManager.say("garden_tut_till")
		_: AudioManager.say("garden_tut_plant")
	Juice.shockwave(_play, _bed_centre(index), 140.0,
		Color(1.0, 0.94, 0.62, 0.5))


## Help, step two: show the finger doing it.
func _show_the_move() -> void:
	if str(_next_task().get("kind", "")) == "deliver":
		# Reuse the normal order-board finger. It points at the physical board
		# while it is shut, then at the matching card after it opens.
		_point_at("order")
		return
	var index := _the_plot_that_wants_something()
	if index < 0:
		return
	var hand := Tutorial.new()
	_play.add_child(hand)
	var bed := _bed_centre(index)
	var state := str(_plots()[index].get("state", ""))
	if state == Farm.READY:
		# Ripe: show the PULL, not a tap -- press on the bed, glide up. It is
		# the same move 丰收行动 teaches for the same crop, so one lesson
		# serves both screens, and a child who taps instead still picks.
		hand.add_step(bed, bed + Vector2(0.0, -90.0), 1.3)
	elif state == Farm.NEEDS_CARE:
		hand.add_step(bed, bed, 1.3)
	elif state == Farm.TILLED:
		hand.add_step(_seed_rack_centre(), bed, 1.3)
	else:
		hand.add_step(bed, bed, 1.3)
	hand.play()


## Help, step three: do the hard part, and leave the last move to him.
##
## The rule the whole hint system is built on -- never finish it FOR him. For
## a plot that needs turning, that means turning it, because the move after it
## (dropping a seed in) is the one worth having. For a plot that is waiting on
## water or weeds there is only one move, so this stops at showing it again:
## doing it would be doing the whole thing.
func _do_the_hard_part() -> void:
	if str(_next_task().get("kind", "")) == "deliver":
		# The last hint may prepare an empty patch, but it must never hand an
		# order in for the child. Showing the board again keeps the final thank-
		# you as his action.
		_show_the_move()
		return
	var index := _the_plot_that_wants_something()
	if index < 0:
		return
	var plots := _plots()
	if str(plots[index].get("state", "")) != Farm.EMPTY:
		_show_the_move()
		return
	plots[index]["state"] = Farm.TILLED
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	_queue_rebuild()


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

	var view := get_viewport_rect().size
	var card := UiKit.card(Color(1.0, 0.99, 0.93))
	card.custom_minimum_size = Vector2(560, 190)
	card.position = Vector2(view.x * 0.5 - 280.0, view.y * 0.5 - 95.0)
	_play.add_child(card)
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var line := UiKit.title(I18n.t(Rest.line()), 30)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	# Staying is the first and largest button on purpose. The break is offered,
	# not pushed -- a child who is happily gardening should not have to hunt for
	# the way to carry on.
	var stay := UiKit.big_button(I18n.t("garden.keep_planting"), Palette.GREEN)
	stay.pressed.connect(func(): card.queue_free())
	row.add_child(stay)
	var leave := UiKit.big_button(I18n.t("garden.go_exploring"), Palette.BLUE)
	leave.pressed.connect(func(): quit_level())
	row.add_child(leave)

## The way into 丰收行动.
##
## The crop/play icon starts the next unfinished challenge; the adjacent grid
## opens the same level picker. A completed set offers the last level again.
func _challenge_door(view: Vector2) -> void:
	var levels: Array = GameData.get_levels_for_mode("harvest")
	if levels.is_empty():
		return
	var next: Dictionary = levels[levels.size() - 1]
	var done := 0
	for level in levels:
		var id := str(level.get("id", ""))
		if int(SaveManager.get_level_progress(id).get("stars", 0)) > 0:
			done += 1
		else:
			next = level
			break

	# One warm side-quest chip, distinct from the tool dock and the gold
	# next-step ribbon.  It shares the header's low-relief material so it reads
	# as useful context, not a second primary action.
	var door_box := HUD_CHALLENGE_BOX
	var door := Panel.new()
	door.name = "HarvestChallenge"
	door.add_theme_stylebox_override("panel", _quiet_surface_style(
		Color(0.98, 0.94, 0.78, 0.72), 18, Color(0.75, 0.58, 0.28, 0.38), 1))
	door.custom_minimum_size = door_box
	door.size = door_box
	door.position = _header_challenge_at(view)
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(door)

	var play := Control.new()
	play.name = "ChallengePlayIcon"
	play.position = Vector2(58.0, 8.0)
	play.size = Vector2(12.0, 12.0)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Shapes.fill(play, PackedVector2Array([
		Vector2.ZERO, Vector2(0.0, 12.0), Vector2(11.0, 6.0)]),
		Color(0.42, 0.48, 0.24), 0.0)
	door.add_child(play)
	var count := UiKit.title("%d/%d" % [done, levels.size()], 13,
		Color(0.34, 0.27, 0.17))
	count.name = "ChallengeCount"
	count.position = Vector2(44.0, 25.0)
	count.size = Vector2(40.0, 18.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door.add_child(count)

	var press := Button.new()
	press.name = "HarvestChallengeShortcut"
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = door.position
	press.size = door_box
	press.custom_minimum_size = door_box
	press.tooltip_text = I18n.t("garden.harvest_challenge")
	var go := str(next.get("id", ""))
	press.pressed.connect(func(): GameManager.start_level(go))
	_play.add_child(press)
	var choose := _chip_button("", Color(0.97, 0.91, 0.68), HUD_CHOOSER_BOX)
	choose.name = "HarvestChallengeChooser"
	choose.tooltip_text = I18n.t("garden.choose_challenge")
	choose.position = door.position + Vector2(door_box.x + 12.0, 0.0)
	var grid := Control.new()
	grid.name = "ChallengeChooserIcon"
	grid.position = Vector2(13.0, 13.0)
	grid.size = Vector2(22.0, 22.0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in range(4):
		var cell := Panel.new()
		cell.position = Vector2((index % 2) * 13.0, (index / 2) * 13.0)
		cell.size = Vector2(9.0, 9.0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_stylebox_override("panel", _quiet_surface_style(
			Color(0.48, 0.38, 0.22), 2, Color.TRANSPARENT, 0, 0))
		grid.add_child(cell)
	choose.add_child(grid)
	choose.pressed.connect(func(): _open_panel("challenges"))
	_play.add_child(choose)

	# The next crop sits beside the challenge tally, inside the header on both
	# shapes. It no longer needs a separate card over the player's map.
	var preview_box := Vector2(32.0, 32.0)
	var preview := Control.new()
	preview.name = "ChallengeNext"
	preview.position = Vector2(6.0, 8.0)
	preview.custom_minimum_size = preview_box
	preview.size = preview_box
	# A look, not a button: the door above is the way in, and this card must
	# never eat a tap meant for the bed underneath it.
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shows := "star"
	# Resolve the picture before constructing it. Replacing a newly drawn star
	# would leave that unparented node (and its shapes) alive after every refresh.
	var art_ref := "star"
	if done < levels.size():
		var tgts: Array = (next.get("config", {}) as Dictionary).get("targets", [])
		if not tgts.is_empty():
			var crop: Dictionary = HarvestCrops.get_crop(
				str(tgts[0].get("crop_id", "")))
			if not crop.is_empty():
				art_ref = str(crop.get("asset", ""))
				shows = str(crop.get("id", ""))
	var art: Control = _crop_picture(shows, 32.0) if shows != "star" else UiKit.picture(art_ref, 32.0)
	preview.set_meta("shows", shows)
	if art != null:
		preview.add_child(art)
	door.add_child(preview)
	var task := _next_task()
	if not _lesson_running and not bool(task.get("actionable", false)):
		UiKit.breathe(door, 0.018, 1.3)


## The same harvest levels, replayable from the same farm door. Four roomy
## rows and the existing sheet pager fit both screen shapes without a scroll
## gesture fighting the farm camera. Stars come straight from level progress.
func _challenge_panel(view: Vector2) -> void:
	FarmChallengePanel.new(self).build(view)
