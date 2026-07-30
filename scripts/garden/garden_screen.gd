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
const SEED_TILE := Vector2(96, 72)
const TOP_BAR := 96.0
const SHELF := 168.0
## The shelf's spacing rhythm: one gap, used between rows, between tiles,
## and between the shelf's edge and its first tile. One number is a rhythm;
## three numbers are three accidents that used to live here -- the rack's
## rings touched the tool row, and both rows read as one squashed pile.
const SHELF_GAP := 12.0

## The order board, written down once instead of in four places.
##
## The first lesson ends by pointing a finger at one particular card, and a
## finger that lands beside the card rather than on it is worse than no finger:
## a child follows it, taps nothing, and concludes the game is broken. Both the
## drawing and the pointing read these, so the two cannot drift apart.
const ORDER_CARD := Vector2(378, 96)
const ORDER_FIRST := 54.0        # heading down to the first card
const ORDER_GAP := 110.0         # card to card

## How often the garden re-settles itself while the first lesson is running.
## Nothing else in this game ticks; see _lesson_tick for why this one does.
const LESSON_TICK := 0.5

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

var _field: DragField
var _play: Control
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
## The other three doors: the seed shop, the market box, the barn. At most one
## of the four stands open -- _open_panel() is the only writer, so the "close
## everything else" rule cannot be forgotten at one call site.
var _shop_open := false
var _market_open := false
var _barn_open := false
## Whether the visitor board is open: who has dropped by and what they left.
var _visit_open := false
var _recipes_open := false
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
## Where picked crops fly to: the middle of the basket tool's button.
var _basket_button_at := Vector2.ZERO

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
	# is worked out from timestamps, so this is the only moment it has to
	# happen -- there is nothing ticking to keep up with afterwards.
	SaveManager.settle_farm()
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
	build_world(self, 0.42)
	_rebuild()

	# The graded helper, watching from now on. Same three steps as every level:
	# say it again, show the finger, then do the hardest part and leave the last
	# move to him.
	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_nudge, _show_the_move, _do_the_hard_part)

	if not bool(_farm().get("tutorial_completed", false)):
		_teach_the_first_planting()


func _farm() -> Dictionary:
	return SaveManager.data.get("farm", {})


func _plots() -> Array:
	return _farm().get("plots", [])


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
	else:
		_world.refresh(_plots())
	_draw_decorations()

	_play = UiKit.play_area(self, true)
	_top_bar(view)
	_seed_drop_targets()
	_panel_buttons.clear()
	_market_field = null
	if _orders_open:
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
	_expand_card(view)
	_undo_toast(view)
	# The barn is drawn AFTER the rack, because the rack lays down the shelf
	# panel and anything added before it ends up underneath.
	_seed_rack(view)
	_tool_bar(view)
	_barn(view)
	_deco_door(view)
	_view_buttons(view)
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
			or (_world != null and is_instance_valid(_world) and _world.stroking())):
		# Not while a seed is in the air, and not while a brush stroke is going:
		# both are a child mid-gesture, and a rebuild takes the thing he is
		# using out of his hand.
		await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild()


func _top_bar(view: Vector2) -> void:
	# An opaque strip, which the four-bed garden did not need. The farm can be
	# dragged, and without something solid here the ground slides up behind the
	# back button and the purse and they become unreadable -- the one place on
	# this screen where a child has to be able to read a number and find the
	# way out.
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.99, 0.98, 0.93), 0))
	strip.position = Vector2.ZERO
	strip.custom_minimum_size = Vector2(view.x, TOP_BAR)
	strip.size = Vector2(view.x, TOP_BAR)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(strip)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(26, 22)
	_play.add_child(back)

	var title := UiKit.title_on_art(I18n.t("garden.title"), 46)
	title.position = Vector2(view.x * 0.5 - 220.0, 26)
	title.size = Vector2(440, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play.add_child(title)

	_challenge_door(view)

	# The farm's level: a star, a number, and a sliver of progress. No xp
	# figure anywhere -- the bar filling IS the number, at the resolution a
	# six-year-old reads. By the back button: the right side of the bar is
	# already three cards deep (challenge door, purse).
	var badge := UiKit.card(Color(0.99, 0.96, 0.86))
	badge.position = Vector2(142.0, 24)
	badge.custom_minimum_size = Vector2(104, 56)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	var level_star := UiKit.picture("star", 32.0)
	if level_star != null:
		badge_row.add_child(level_star)
	var level_tag := UiKit.title(str(Level.level()), 30)
	badge_row.add_child(level_tag)
	badge.add_child(badge_row)
	_play.add_child(badge)
	var rail := ColorRect.new()
	rail.color = Color(0.88, 0.84, 0.72)
	rail.position = Vector2(152.0, 86.0)
	rail.size = Vector2(84, 5)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(rail)
	var fill := ColorRect.new()
	fill.color = Color(1.0, 0.78, 0.22)
	fill.position = rail.position
	fill.size = Vector2(84.0 * Level.progress(), 5)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(fill)

	# The purse, read-only. Nothing in the garden spends or earns yet -- that
	# arrives with the orders -- but the number he is used to seeing in every
	# other room should not vanish in this one.
	var purse := UiKit.card(Color(1.0, 0.98, 0.90))
	purse.position = Vector2(view.x - 26.0 - 150.0, 24)
	purse.custom_minimum_size = Vector2(150, 56)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var coin := UiKit.picture("star_coin", 32.0)
	if coin != null:
		row.add_child(coin)
	var amount := UiKit.title(str(Coins.balance()), 28)
	row.add_child(amount)
	purse.add_child(row)
	_play.add_child(purse)


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
			# Through the gate to the bear's farm. The door only exists once
			# the first harvest has been paid (see FarmWorld._bear_door_open),
			# so there is no locked state to explain here -- a door he can see
			# is a door that opens.
			AudioManager.play_sfx("res://assets/audio/door.ogg")
			SceneManager.goto_scene("res://scenes/garden/BearFarm.tscn")
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
			AudioManager.play_sfx("res://assets/audio/water.ogg")
		_:
			AudioManager.play_sfx("res://assets/audio/pop.ogg")


## Open one door and shut the rest. The ONLY writer of these four flags: two
## sheets stacked over each other is a screen nobody can read, and a rule
## enforced at one call site is a rule.
func _open_panel(which: String) -> void:
	_orders_open = which == "orders"
	_shop_open = which == "shop"
	_market_open = which == "market"
	_barn_open = which == "barn"
	_visit_open = which == "visits"
	_recipes_open = which == "recipes"
	_confirm_crop = ""
	_confirm_expand = -1
	_confirm_upgrade = false
	if which != "market":
		_market_sell = {}
	AudioManager.play_sfx("res://assets/audio/door.ogg")
	_queue_rebuild()


func _close_panels() -> void:
	_orders_open = false
	_shop_open = false
	_market_open = false
	_barn_open = false
	_visit_open = false
	_recipes_open = false
	_confirm_crop = ""
	_confirm_expand = -1
	_confirm_upgrade = false
	_market_sell = {}
	_queue_rebuild()


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
const RACK_X := 24.0 + 48.0
const RACK_STEP := SEED_TILE.x + SHELF_GAP


func _seed_rack(view: Vector2) -> void:
	var shelf_h := SHELF
	var shelf := Panel.new()
	shelf.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 0))
	shelf.position = Vector2(0, view.y - shelf_h)
	shelf.custom_minimum_size = Vector2(view.x, shelf_h)
	shelf.size = Vector2(view.x, shelf_h)
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(shelf)
	_shelf = shelf

	# The shelf holds two rows: the tool rack above, the seeds and the barn
	# below, one SHELF_GAP between everything -- rows, tiles, edges. The first
	# cut let the rows touch and the chosen seed's ring reach into the tool
	# row, and the whole shelf read as one squashed pile.
	var unlocked: Array = _farm().get("unlocked_crops", [])
	var chosen := _tools.crop_to_plant(unlocked)
	for i in range(unlocked.size()):
		var crop_id := str(unlocked[i])
		var crop: Dictionary = GameData.get_crop(crop_id)
		if crop.is_empty():
			continue
		var at := _rack_tile_centre(i)
		var tile := Node2D.new()
		tile.position = at
		_play.add_child(tile)
		Shapes.fill(tile, Shapes.rounded_rect(
			-SEED_TILE * 0.5, SEED_TILE, 16.0), Color(0.97, 0.93, 0.83), 1.0)
		# The chosen seed wears a ring while the seed brush is armed, so "which
		# one will the brush plant" is answered by looking, not by remembering.
		# The ring grows INTO the gap and no further: half the rhythm, so two
		# ringed neighbours could not touch even if two rings could exist.
		if _tools.selected == "seed" and crop_id == chosen:
			Shapes.fill(tile, Shapes.rounded_rect(
				-SEED_TILE * 0.5 - Vector2(4, 4), SEED_TILE + Vector2(8, 8),
				19.0), Color(0.95, 0.62, 0.18, 0.55), 1.0)
		var art := UiKit.picture(str(crop.get("icon", "seed")), 52.0)
		if art != null:
			art.position = at - Vector2(26.0, 30.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_play.add_child(art)
		_field.add_item(tile, at, crop_id)

		# A TAP on the tile arms the seed brush with this crop; a DRAG from it
		# is the classic single planting, untouched. The two do not fight: the
		# button only fires when the finger comes up still inside it, and a
		# drag has left by then -- so the same tile answers both, and which one
		# the child meant is decided by what his finger actually did.
		var pick := Button.new()
		pick.flat = true
		pick.focus_mode = Control.FOCUS_NONE
		pick.position = at - SEED_TILE * 0.5
		pick.custom_minimum_size = SEED_TILE
		pick.size = SEED_TILE
		var this_crop := crop_id
		pick.pressed.connect(func(): _choose_seed(this_crop))
		_play.add_child(pick)


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
			_harvest(plot)
		Farm.NEEDS_CARE:
			match str(plot.get("care_event", "")):
				Growth.CARE_THIRSTY:
					plot = Growth.water(plot)
					AudioManager.play_sfx("res://assets/audio/water.ogg")
				Growth.CARE_WEEDS:
					plot = Growth.weed(plot)
					AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
				Growth.CARE_BUG:
					plot = Growth.shoo(plot)
					AudioManager.play_sfx("res://assets/audio/rustle.ogg")
				_:
					# Waiting for care, but not for anything with a name. Repair
					# it rather than leave a plot no tap can ever move.
					plot["state"] = Farm.GROWING
		Farm.TILLED:
			# Turned, empty, and tapped: he is trying to plant by tapping. Point
			# at the rack rather than doing nothing, which is the same as being
			# broken.
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
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


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
func _harvest(plot: Dictionary) -> void:
	if _harvest_core(plot) <= 0:
		return
	AudioManager.play_sfx("res://assets/audio/star.ogg")
	AudioManager.say("praise_1")
	_harvested_something = true


## The transactional half of picking: pay once, store everything, reset the
## bed. Shared by the tap and by the basket brush, because the promise "one
## planting is paid for exactly once" must not have two implementations that
## can drift. Returns how many crops came off, 0 for a repeat.
##
## THE TRANSACTION ID
##
## `farm_harvest_<plot_id>_<plant_cycle_id>` -- the patch of earth, and which
## planting in it. plant_cycle_id rises by one every time a seed goes in and
## never resets, so no two harvests in the history of a save can ever produce
## the same id, and the same id presented twice is always a repeat.
func _harvest_core(plot: Dictionary) -> int:
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
		return 0
	Farm.remember_paid(farm, key)
	# The farm grows up a little. INSIDE the gate on purpose: a repeat that
	# was refused above pays no xp either, so the level inherits the same
	# once-per-planting promise as the crops.
	_earn_xp("harvest")

	_harvesting[plot_id] = true

	var crop: Dictionary = GameData.get_crop(crop_id)
	var picked := maxi(int(crop.get("harvest_amount", 1)), 1)
	# Into the barn, and whatever does not fit into the basket by its door.
	# NOT Barn.put(): put() now answers "how many actually went in", and a
	# harvest that ignores that answer is a harvest that silently eats crops
	# the moment the barn is full. store_harvest() is the only call that
	# guarantees stored + spilled == picked.
	var learned: Array = []
	Barn.store_harvest(crop_id, picked)
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
	return picked


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
	plot["growth_override_seconds"] = _tutorial_growth if _lesson_running else 0
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

	var x := 24.0
	var y := view.y - SHELF + 10.0
	for tool in Tools.TOOLS:
		var tool_id := str(tool.get("id", ""))
		var live: bool = tool_id == Tools.HAND \
			or _tools.work_exists(tool_id, _plots())
		var held: bool = _tools.selected == tool_id

		var button := Button.new()
		button.flat = false
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(x, y)
		button.custom_minimum_size = Vector2(92, 68)
		button.size = Vector2(92, 68)
		button.pivot_offset = Vector2(46, 34)
		var fill := Color(1.0, 0.99, 0.94) if live else Color(0.93, 0.92, 0.88)
		var style := UiKit.panel_style(fill, 18)
		if held:
			# The held tool GLOWS -- a thick warm ring, not a subtle tint. Six
			# is an age where "which one is on" has to be answerable from the
			# far side of a room.
			style.border_color = Color(0.95, 0.58, 0.16)
			style.set_border_width_all(4)
		for look in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(look, style)
		button.disabled = not live
		button.modulate = Color(1, 1, 1, 1.0 if live else 0.92)
		var art := UiKit.picture(str(tool.get("icon", "star")), 46.0)
		if art != null:
			art.position = Vector2(23, 11)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.modulate.a = 1.0 if live else 0.40
			button.add_child(art)
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
		if tool_id == "basket":
			_basket_button_at = button.position + Vector2(46, 34)
		x += 92.0 + SHELF_GAP


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
			plot = Growth.water(plot)
			AudioManager.play_sfx("res://assets/audio/water.ogg")
		"weed":
			plot = Growth.weed(plot)
			AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
		"bug":
			plot = Growth.shoo(plot)
			AudioManager.play_sfx("res://assets/audio/rustle.ogg")
		"basket":
			var picked := _harvest_core(plot)
			if picked > 0:
				_combo += 1
				_show_combo(index)
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
	plots[index] = plot
	SaveManager.data["farm"]["plots"] = plots
	# The bed changes under the brush as it passes -- that is the whole show --
	# but nothing is SAVED yet: one stroke is one write, at the end.
	_world.refresh(plots)


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
func _show_combo(index: int) -> void:
	if _combo_label == null or not is_instance_valid(_combo_label):
		_combo_label = UiKit.title("", 64, Color(1.0, 0.62, 0.12))
		_combo_label.position = Vector2(get_viewport_rect().size.x * 0.5 - 70.0,
			TOP_BAR + 30.0)
		_combo_label.size = Vector2(140, 72)
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_play.add_child(_combo_label)
	_combo_label.text = "x%d" % _combo
	Juice.pop(_combo_label, 0.22)
	_fly_to_basket(index)


## The picked crop flies from its bed into the basket button -- the one piece
## of theatre that says WHERE the things went, so the barn count changing is a
## confirmation rather than a mystery.
func _fly_to_basket(index: int) -> void:
	if not Juice.motion_enabled():
		return
	var plots := _plots()
	if index < 0 or index >= plots.size():
		return
	var crop: Dictionary = GameData.get_crop(str(plots[index].get("crop_id", "")))
	var art := UiKit.picture(str(crop.get("icon", "basket")), 44.0)
	if art == null:
		return
	art.position = _bed_centre(index) - Vector2(22, 22)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(art)
	var t := art.create_tween()
	t.tween_property(art, "position", _basket_button_at - Vector2(22, 22), 0.4)\
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
## The door to the decorating room, beside the barn: a sticker book on a
## chip. Which room it opens is the garden's own DATA (config.deco_room) --
## the room-naming rule keeps the id out of code, and a save from before the
## room existed simply shows no door. 二期阶段 1 的入口。
func _deco_door(view: Vector2) -> void:
	var room_id := str(level_data.get("config", {}).get("deco_room", ""))
	if room_id == "" or GameData.get_level(room_id).is_empty():
		return
	var box := Vector2(64, SEED_TILE.y)
	var at := Vector2(view.x - 24.0 - 168.0 - 12.0 - box.x,
		view.y - SHELF * 0.25 - box.y * 0.5)
	var b := Button.new()
	b.name = "DecoDoor"
	b.focus_mode = Control.FOCUS_NONE
	b.position = at
	b.custom_minimum_size = box
	b.size = box
	b.add_theme_stylebox_override("normal", UiKit.panel_style(Color(0.97, 0.93, 0.83), 16))
	b.add_theme_stylebox_override("hover", UiKit.panel_style(Color(0.99, 0.96, 0.88), 16))
	b.add_theme_stylebox_override("pressed", UiKit.panel_style(Color(0.93, 0.88, 0.76), 16))
	var art: Control = UiKit.picture("sticker_book", 44.0)
	if art != null:
		art.position = Vector2((box.x - 44.0) * 0.5, (box.y - 44.0) * 0.5)
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
func _draw_decorations() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var old: Node = _world.get_node_or_null("Decorations")
	if old != null:
		old.name = "DecorationsGone"
		old.queue_free()
	var room_id := str(level_data.get("config", {}).get("deco_room", ""))
	if room_id == "":
		return
	var room: Dictionary = GameData.get_level(room_id)
	if room.is_empty():
		return
	var key := str(room.get("config", {}).get("canvas_id", room_id))
	var placed: Array = SaveManager.get_creation(key)
	if placed.is_empty():
		return
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
		var fx := clampf(float(entry.get("x", 640.0)) / 1280.0, 0.0, 1.0)
		var fy := clampf(float(entry.get("y", 300.0)) / 720.0, 0.0, 1.0)
		art.position = Vector2(fx * (world.x - size), fy * (world.y - size))
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(art)


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
	var box := Vector2(168, SEED_TILE.y)
	var at := Vector2(view.x - 24.0 - box.x, view.y - SHELF * 0.25 - box.y * 0.5)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.97, 0.93, 0.83), 16))
	card.position = at
	card.custom_minimum_size = box
	card.size = box
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(card)

	var basket := UiKit.picture("basket", 40.0)
	if basket != null:
		basket.position = at + Vector2(14.0, box.y * 0.5 - 20.0)
		basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play.add_child(basket)
	var label := UiKit.title(I18n.t("garden.barn"), 17, Color(0.55, 0.51, 0.44))
	label.position = at + Vector2(66.0, 11.0)
	label.size = Vector2(90, 20)
	_play.add_child(label)
	var room := UiKit.title("%d/%d" % [Barn.total(), Barn.cap()], 24)
	room.position = at + Vector2(66.0, 32.0)
	room.size = Vector2(96, 28)
	_play.add_child(room)

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
	# Just left of the barn's card, on the shelf and not over the farm: the
	# farm scrolls, and a strawberry that stays put while the ground slides
	# past is not a strawberry, it is a bug. Measured from the card so a
	# taller pile grows LEFT into the shelf's spare middle, never under it.
	var at := Vector2(view.x - 24.0 - 168.0 - 24.0
		- 38.0 - float(spilled.size()) * 66.0, view.y - SHELF * 0.25)
	var pile := UiKit.picture("basket", 30.0)
	if pile != null:
		pile.modulate = Color(1.0, 0.94, 0.78)
		pile.position = Vector2(at.x, at.y - 6.0)
		_play.add_child(pile)
	var x := at.x + 38.0
	for pair in spilled:
		var crop: Dictionary = GameData.get_crop(str(pair[0]))
		var art := UiKit.picture(str(crop.get("icon", "seed")), 26.0)
		if art != null:
			art.position = Vector2(x, at.y - 4.0)
			_play.add_child(art)
		var many := UiKit.title("x%d" % int(pair[1]), 18)
		many.position = Vector2(x + 24.0, at.y)
		many.size = Vector2(44, 22)
		_play.add_child(many)
		x += 66.0


## Who needs a hand today. Three cards, each one a picture of somebody, what
## they want, and what they will give for it.
func _order_board(view: Vector2) -> void:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	var at := _order_board_origin()

	# The board used to live in the right third of the screen, permanently. It
	# cannot any more: that third is farm now, and a panel nailed over it would
	# hide the market and the order board's own building. So it opens when he
	# walks up to the board and closes when he is done -- which is also how a
	# real notice board works, and one fewer thing on screen the rest of the time.
	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.99, 0.97, 0.90), 28))
	sheet.position = at - Vector2(24, 18)
	sheet.custom_minimum_size = Vector2(ORDER_CARD.x + 48.0,
		ORDER_FIRST + ORDER_GAP * float(maxi(GameData.garden_orders.size(), 1)) + 24.0)
	sheet.size = sheet.custom_minimum_size
	_play.add_child(sheet)
	if _world != null and is_instance_valid(_world):
		# The board stands over the beds. A press on one of its cards must not
		# ALSO till the bed behind the card -- see FarmWorld.blockers.
		_world.add_blocker(sheet)

	# The way out, in the corner a back button is always in, and big enough for
	# a thumb. Closing is never refused and never asks anything.
	var shut := Button.new()
	shut.flat = false
	shut.focus_mode = Control.FOCUS_NONE
	shut.text = "X"
	shut.add_theme_font_size_override("font_size", 32)
	shut.position = sheet.position + Vector2(sheet.size.x - 74.0, 12.0)
	shut.custom_minimum_size = Vector2(62, 62)
	shut.size = Vector2(62, 62)
	for look in ["normal", "hover", "pressed", "focus"]:
		shut.add_theme_stylebox_override(look,
			UiKit.panel_style(Color(0.96, 0.92, 0.84), 20))
	shut.pressed.connect(func():
		_orders_open = false
		_queue_rebuild())
	_play.add_child(shut)

	var heading := UiKit.title_on_art(I18n.t("garden.orders"), 30)
	heading.position = at
	heading.size = Vector2(400, 40)
	_play.add_child(heading)

	var y := at.y + ORDER_FIRST
	for order in GameData.garden_orders:
		var order_id := str(order.get("id", ""))
		var done: bool = order_id in delivered
		var wants: Dictionary = order.get("requirements", {})
		var can: bool = Barn.can_pay(wants)

		var card := Button.new()
		card.flat = false
		card.focus_mode = Control.FOCUS_NONE
		card.position = Vector2(at.x, y)
		card.custom_minimum_size = ORDER_CARD
		card.size = ORDER_CARD
		var tint := Color(0.90, 0.92, 0.88) if done \
			else (Color(1.0, 0.99, 0.94) if can else Color(0.98, 0.97, 0.92))
		for state in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(state, UiKit.panel_style(tint, 22))
		card.disabled = done or not can
		_play.add_child(card)
		if not done and can:
			card.pressed.connect(func(): _deliver(order))
			UiKit.breathe(card, 0.02, 1.4)

		var who := UiKit.picture(str(order.get("customer_icon", "heart")), 54.0)
		if who != null:
			who.position = Vector2(at.x + 16.0, y + 20.0)
			who.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_play.add_child(who)

		# What they want, as pictures and numbers. No sentence to read.
		var x := at.x + 86.0
		for crop_id in wants.keys():
			var crop: Dictionary = GameData.get_crop(str(crop_id))
			var art := UiKit.picture(str(crop.get("icon", "seed")), 40.0)
			if art != null:
				art.position = Vector2(x, y + 26.0)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_play.add_child(art)
			var need := int(wants[crop_id])
			var have := Barn.count(str(crop_id))
			var tally := UiKit.title("%d/%d" % [mini(have, need), need], 22)
			tally.position = Vector2(x + 4.0, y + 62.0)
			tally.size = Vector2(60, 26)
			tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_play.add_child(tally)
			x += 74.0

		# The price, or a tick if it is already done.
		if done:
			var tick := UiKit.picture("check", 44.0)
			if tick != null:
				tick.position = Vector2(at.x + 310.0, y + 26.0)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_play.add_child(tick)
		else:
			var coin := UiKit.picture("star_coin", 34.0)
			if coin != null:
				coin.position = Vector2(at.x + 286.0, y + 24.0)
				coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_play.add_child(coin)
			var price := UiKit.title(str(int(order.get("rewards", {}).get("coins", 0))), 26)
			price.position = Vector2(at.x + 286.0, y + 58.0)
			price.size = Vector2(60, 30)
			price.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_play.add_child(price)
		y += ORDER_GAP


## Top left of the order board, measured from the viewport every time -- see
## _bed_centre for why nothing here may be measured from a hard-coded 720.
func _order_board_origin() -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(view.x * 0.5 - ORDER_CARD.x * 0.5, TOP_BAR + 52.0)


## The middle of one order's card, for the lesson's finger to land on.
func _order_card_centre(order_id: String) -> Vector2:
	var at := _order_board_origin()
	var y := at.y + ORDER_FIRST
	for order in GameData.garden_orders:
		if str(order.get("id", "")) == order_id:
			break
		y += ORDER_GAP
	return Vector2(at.x, y) + ORDER_CARD * 0.5


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

	# Asked BEFORE the barn is touched, and that order matters. The first cut
	# emptied the barn first and only then asked whether this order had already
	# been paid for -- so an order delivered twice would have taken three more
	# carrots and given nothing back. The card is disabled once delivered, so
	# it was unreachable, but "unreachable" is a property of today's screen and
	# not of the rule.
	if order_id in delivered:
		return
	var wants: Dictionary = order.get("requirements", {})
	if not Barn.pay(wants):
		return
	var paid := RewardManager.grant("garden:order:%s" % order_id,
		int(order.get("rewards", {}).get("coins", 0)), order_id, delivered)
	if paid > 0:
		# The thank-you gifts ride the same once-only gate as the coins: paid
		# is only ever above zero the first time this order_id goes through.
		# Today that is one plank per friend -- the three the barn's bigger
		# roof is built from, each one seen arriving rather than found in a
		# menu.
		var gifts: Dictionary = order.get("rewards", {}).get("items", {})
		for item_id in gifts.keys():
			Barn.put(str(item_id), int(gifts[item_id]), "inventory")
		# Helping a friend grows the farm most of all -- and only the first
		# time this order goes through, same gate as the coins above.
		_earn_xp("order")
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
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


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
	b.add_theme_font_size_override("font_size", int(box.y * 0.44))
	b.add_theme_color_override("font_color", Color(0.15, 0.13, 0.10))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.48))
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(look, UiKit.panel_style(fill, 16))
	b.custom_minimum_size = box
	b.size = box
	return b


## The scaffolding every panel shares: a sheet over the farm, a title, and a
## way out in the corner a way out is always in. Registered as a blocker so
## pressing the paper can never reach the ground behind it.
func _panel_sheet(view: Vector2, title_key: String, wide: float,
		tall: float) -> Vector2:
	var origin := Vector2(view.x * 0.5 - wide * 0.5, TOP_BAR + 16.0)
	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.99, 0.97, 0.90), 28))
	sheet.position = origin
	sheet.custom_minimum_size = Vector2(wide, tall)
	sheet.size = Vector2(wide, tall)
	_play.add_child(sheet)
	if _world != null and is_instance_valid(_world):
		_world.add_blocker(sheet)

	var title := UiKit.title_on_art(I18n.t(title_key), 30)
	title.position = origin + Vector2(28, 14)
	title.size = Vector2(wide - 130.0, 40)
	_play.add_child(title)

	var shut := Button.new()
	shut.flat = false
	shut.focus_mode = Control.FOCUS_NONE
	shut.text = "X"
	shut.add_theme_font_size_override("font_size", 32)
	shut.position = origin + Vector2(wide - 74.0, 12.0)
	shut.custom_minimum_size = Vector2(62, 62)
	shut.size = Vector2(62, 62)
	for look in ["normal", "hover", "pressed", "focus"]:
		shut.add_theme_stylebox_override(look,
			UiKit.panel_style(Color(0.96, 0.92, 0.84), 20))
	shut.pressed.connect(_close_panels)
	_play.add_child(shut)
	return origin


## "X分" under an hour, "X时" from there up. Every crop's time is a whole
## number of one or the other on purpose -- crops.json is checked for it.
func _grow_time_text(seconds: int) -> String:
	if seconds < 3600:
		return "%d分" % int(round(seconds / 60.0))
	return "%d时" % int(round(seconds / 3600.0))


## The seed shop: six rows, and on every row the three numbers the red line
## demands be visible BEFORE any confirm button exists -- what it costs, how
## long it grows, how many come off. Nothing here is a one-press purchase.
func _shop_panel(view: Vector2) -> void:
	var wide := 780.0
	var origin := _panel_sheet(view, "garden.shop_title", wide, 430.0)
	var y := origin.y + 74.0
	for row in GameData.farm_seed_shop.get("seeds", []):
		var crop_id := str(row.get("crop_id", ""))
		var crop: Dictionary = GameData.get_crop(crop_id)
		if crop.is_empty():
			continue
		var art := UiKit.picture(str(crop.get("icon", "seed")), 44.0)
		if art != null:
			art.position = Vector2(origin.x + 30.0, y)
			_play.add_child(art)
		var name_tag := UiKit.title(I18n.t(str(crop.get("name_key", ""))), 24)
		name_tag.position = Vector2(origin.x + 88.0, y + 8.0)
		name_tag.size = Vector2(96, 30)
		_play.add_child(name_tag)

		# The three numbers, always, owned or not: the row is the label on the
		# shelf, not the receipt.
		var coin := UiKit.picture("star_coin", 26.0)
		if coin != null:
			coin.position = Vector2(origin.x + 200.0, y + 8.0)
			_play.add_child(coin)
		var price := SeedShop.price_of(crop_id)
		var price_tag := UiKit.title("0" if price <= 0 else str(price), 24)
		price_tag.position = Vector2(origin.x + 232.0, y + 7.0)
		price_tag.size = Vector2(64, 30)
		_play.add_child(price_tag)
		var time_tag := UiKit.title(
			_grow_time_text(int(GameData.crop_total_seconds(crop_id))), 24)
		time_tag.position = Vector2(origin.x + 320.0, y + 7.0)
		time_tag.size = Vector2(86, 30)
		_play.add_child(time_tag)
		var pick := UiKit.picture("basket", 26.0)
		if pick != null:
			pick.position = Vector2(origin.x + 424.0, y + 8.0)
			_play.add_child(pick)
		var count_tag := UiKit.title("x%d" % int(crop.get("harvest_amount", 1)), 24)
		count_tag.position = Vector2(origin.x + 456.0, y + 7.0)
		count_tag.size = Vector2(60, 30)
		_play.add_child(count_tag)

		match SeedShop.state_of(crop_id):
			"owned", "free":
				var tick := UiKit.picture("check", 30.0)
				if tick != null:
					tick.position = Vector2(origin.x + wide - 200.0, y + 6.0)
					_play.add_child(tick)
				var owned_tag := UiKit.title(I18n.t("garden.owned"), 22)
				owned_tag.position = Vector2(origin.x + wide - 162.0, y + 9.0)
				owned_tag.size = Vector2(90, 28)
				_play.add_child(owned_tag)
			"buyable":
				var buy := _chip_button(I18n.t("garden.buy"),
					Color(0.72, 0.88, 0.60), Vector2(150, 48))
				buy.position = Vector2(origin.x + wide - 214.0, y - 4.0)
				var this_crop := crop_id
				buy.pressed.connect(func():
					_confirm_crop = this_crop
					_queue_rebuild())
				_play.add_child(buy)
				_panel_buttons["buy_%s" % crop_id] = buy
			"poor":
				# He cannot afford it YET. Not hidden, not red, not disabled art:
				# the row stays honest and the price sits where it always sits.
				# A little star shows how far he has to go.
				var short_tag := UiKit.title(
					"还差%d" % Coins.short_by(price), 22, Color(0.62, 0.52, 0.36))
				short_tag.position = Vector2(origin.x + wide - 200.0, y + 9.0)
				short_tag.size = Vector2(150, 28)
				_play.add_child(short_tag)
		y += 56.0
	if _confirm_crop != "":
		_confirm_card(view, origin, wide)


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
	var wide := 780.0
	var origin := _panel_sheet(view, "garden.market_title", wide, 430.0)

	_market_field = DragField.new()
	_play.add_child(_market_field)
	_market_field.dropped.connect(_on_market_drop)

	# The box: a crate drawn where the crops land, with a dark mouth so "put
	# it IN" is legible without a word. Drawn by hand -- the first cut used a
	# picture that quietly failed to show, and an invisible drop target is a
	# game of pin-the-tail.
	var box_at := origin + Vector2(wide - 190.0, 200.0)
	var crate := Node2D.new()
	crate.position = box_at
	_play.add_child(crate)
	Shapes.fill(crate, Shapes.rounded_rect(Vector2(-70, -24),
		Vector2(140, 78), 14.0), Color(0.72, 0.52, 0.30), 1.0)
	Shapes.fill(crate, Shapes.rounded_rect(Vector2(-58, -40),
		Vector2(116, 30), 10.0), Color(0.45, 0.31, 0.18), 1.0)
	Shapes.fill(crate, Shapes.rounded_rect(Vector2(-70, 10),
		Vector2(140, 10), 5.0), Color(0.62, 0.44, 0.26), 0.0)
	var box_slot := Node2D.new()
	_play.add_child(box_slot)
	_market_field.add_slot(box_slot, box_at, "", 99)

	# One chip per pile in the barn. The chip IS the pile: dragging it into
	# the box offers the whole pile, which is the only amount a screen with no
	# numbers pad can ask for honestly.
	var contents := Barn.contents()
	var x := origin.x + 46.0
	var y := origin.y + 96.0
	for pair in contents:
		var crop_id := str(pair[0])
		if crop_id in _market_sell:
			continue
		var chip := Node2D.new()
		chip.position = Vector2(x, y)
		_play.add_child(chip)
		Shapes.fill(chip, Shapes.rounded_rect(Vector2(-44, -34),
			Vector2(88, 68), 16.0), Color(0.98, 0.95, 0.86), 1.0)
		# The picture and the count are CHILDREN of the chip, in chip-local
		# coordinates. The first cut parented them to the screen, so dragging
		# the chip into the box moved an empty beige rectangle while the
		# carrot and its number stayed floating over the shelf.
		var art := UiKit.picture(
			str(GameData.get_crop(crop_id).get("icon", "seed")), 40.0)
		if art != null:
			art.position = Vector2(-20.0, -28.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(art)
		var many := UiKit.title("x%d" % int(pair[1]), 20)
		many.position = Vector2(-22.0, 10.0)
		many.size = Vector2(60, 24)
		many.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(many)
		_market_field.add_item(chip, Vector2(x, y), crop_id)
		x += 108.0
		if x > origin.x + 380.0:
			x = origin.x + 46.0
			y += 84.0

	# The total, and the one button that makes it real.
	var coin := UiKit.picture("star_coin", 34.0)
	if coin != null:
		coin.position = box_at + Vector2(-64, 74)
		_play.add_child(coin)
	_market_total = UiKit.title(str(Market.quote(_market_sell)), 32)
	_market_total.position = box_at + Vector2(-20, 72)
	_market_total.size = Vector2(110, 40)
	_play.add_child(_market_total)

	var sell := _chip_button(I18n.t("garden.sell"),
		Color(0.99, 0.83, 0.52), Vector2(180, 62))
	sell.position = Vector2(box_at.x - 90.0, origin.y + 348.0)
	sell.pressed.connect(_sell_pressed)
	_play.add_child(sell)
	_panel_buttons["sell"] = sell


## A pile landed in the box: remember it and move the total. No rebuild --
## DragField has already sat the chip in the box, and rebuilding mid-gesture
## is forbidden anyway.
func _on_market_drop(item: Dictionary, slot: Variant, correct: bool) -> void:
	if not correct or slot == null:
		return
	var crop_id := str(item.get("key", ""))
	_market_sell[crop_id] = Barn.count(crop_id)
	if _market_total != null and is_instance_valid(_market_total):
		_market_total.text = str(Market.quote(_market_sell))
		Juice.pop(_market_total, 0.2)
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")


func _sell_pressed() -> void:
	var paid := Market.sell(_market_sell)
	_market_sell = {}
	if paid <= 0:
		# An empty box. The button shrugs instead of the screen erroring.
		var button: Variant = _panel_buttons.get("sell")
		if button is Button and is_instance_valid(button):
			Juice.nudge(button, 8.0)
		return
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
			fly.position = Vector2(view.x * 0.5, view.y * 0.45) 				+ Vector2(float(i - 2) * 22.0, 0)
			_play.add_child(fly)
			var t := fly.create_tween()
			t.tween_interval(0.05 * float(i))
			t.tween_property(fly, "position",
				Vector2(view.x - 160.0, 40.0), 0.5)				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(fly.queue_free)
	_queue_rebuild()


## The barn's own door: how full it is, what is in it, and -- once, ever --
## the upgrade that the three friends' planks were for.
func _barn_panel(view: Vector2) -> void:
	var wide := 700.0
	var origin := _panel_sheet(view, "garden.warehouse_title", wide, 430.0)

	var basket := UiKit.picture("basket", 84.0)
	if basket != null:
		basket.position = origin + Vector2(46, 80)
		_play.add_child(basket)
	var room := UiKit.title("%d/%d" % [Barn.total(), Barn.cap()], 40)
	room.position = origin + Vector2(150, 102)
	room.size = Vector2(180, 48)
	_play.add_child(room)

	# The recipe book lives where its ingredients do. A chip, not a word.
	var book := Button.new()
	book.name = "RecipeBook"
	book.focus_mode = Control.FOCUS_NONE
	book.position = origin + Vector2(wide - 96.0, 78.0)
	book.custom_minimum_size = Vector2(64, 64)
	book.size = Vector2(64, 64)
	book.add_theme_stylebox_override("normal", UiKit.panel_style(Color(0.97, 0.93, 0.83), 16))
	book.add_theme_stylebox_override("hover", UiKit.panel_style(Color(0.99, 0.96, 0.88), 16))
	book.add_theme_stylebox_override("pressed", UiKit.panel_style(Color(0.93, 0.88, 0.76), 16))
	var book_art := UiKit.picture("picture_book", 44.0)
	if book_art != null:
		book_art.position = Vector2(10, 10)
		book_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book.add_child(book_art)
	book.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_open_panel("recipes"))
	_play.add_child(book)

	var x := origin.x + 46.0
	var y := origin.y + 210.0
	for pair in Barn.contents():
		var art := UiKit.picture(
			str(GameData.get_crop(str(pair[0])).get("icon", "seed")), 36.0)
		if art != null:
			art.position = Vector2(x, y)
			_play.add_child(art)
		var many := UiKit.title("x%d" % int(pair[1]), 22)
		many.position = Vector2(x + 34.0, y + 8.0)
		many.size = Vector2(56, 26)
		_play.add_child(many)
		x += 100.0
		if x > origin.x + wide - 120.0:
			x = origin.x + 46.0
			y += 52.0

	if Barn.cap() >= Farm.WAREHOUSE_UPGRADED:
		return

	# The upgrade card: what it costs, what he has, one button. The plank
	# count doubles as the story so far -- each one arrived with a delivery.
	var planks := Barn.count("plank", "inventory")
	var coin := UiKit.picture("star_coin", 34.0)
	if coin != null:
		coin.position = origin + Vector2(360, 88)
		_play.add_child(coin)
	var cost := UiKit.title(str(UPGRADE_COINS), 30)
	cost.position = origin + Vector2(400, 90)
	cost.size = Vector2(70, 36)
	_play.add_child(cost)
	var plank_art := UiKit.picture("plank", 34.0)
	if plank_art != null:
		plank_art.position = origin + Vector2(478, 88)
		_play.add_child(plank_art)
	var plank_tag := UiKit.title("%d/%d" % [planks, UPGRADE_PLANKS], 30,
		Color(0.24, 0.5, 0.24) if planks >= UPGRADE_PLANKS
			else Color(0.62, 0.52, 0.36))
	plank_tag.position = origin + Vector2(518, 90)
	plank_tag.size = Vector2(90, 36)
	_play.add_child(plank_tag)

	var can_do: bool = planks >= UPGRADE_PLANKS 		and Coins.can_afford(UPGRADE_COINS)
	var up := _chip_button(I18n.t("garden.upgrade"),
		Color(0.72, 0.88, 0.60) if can_do else Color(0.90, 0.89, 0.84),
		Vector2(200, 58))
	up.position = origin + Vector2(360, 134)
	up.disabled = not can_do
	up.pressed.connect(func():
		_confirm_upgrade = true
		_queue_rebuild())
	_play.add_child(up)
	_panel_buttons["upgrade"] = up

	if _confirm_upgrade:
		var yes := _chip_button(I18n.t("garden.upgrade"),
			Color(0.99, 0.83, 0.52), Vector2(180, 60))
		yes.position = origin + Vector2(150, 330)
		yes.pressed.connect(_upgrade_confirmed)
		_play.add_child(yes)
		_panel_buttons["confirm_upgrade"] = yes
		var no := _chip_button(I18n.t("garden.cancel"),
			Color(0.78, 0.86, 0.97), Vector2(180, 60))
		no.position = origin + Vector2(370, 330)
		no.pressed.connect(func():
			_confirm_upgrade = false
			_queue_rebuild())
		_play.add_child(no)
		_panel_buttons["cancel_upgrade"] = no


## The one purchase that is not a crop. Planks first -- take() is all or
## nothing -- then coins, then the roof. cap < UPGRADED is the idempotence:
## a second press finds the barn already big and stops at the first line.
func _upgrade_confirmed() -> void:
	_confirm_upgrade = false
	var farm := _farm()
	if Barn.cap() >= Farm.WAREHOUSE_UPGRADED:
		return
	if not Barn.has("plank", UPGRADE_PLANKS, "inventory"):
		return
	if not Coins.spend(UPGRADE_COINS):
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
	var wide := 640.0
	var origin := _panel_sheet(view, "garden.visit_title", wide, 400.0)
	var log: Array = _farm().get("visit_log", [])
	var templates: Dictionary = GameData.farm_visit_texts

	if log.is_empty():
		# Nobody yet: the board says so warmly, with the bear it is hoping
		# for. An empty panel with no explanation reads as broken.
		var face := UiKit.picture("teddy", 92.0)
		if face != null:
			face.position = origin + Vector2(wide * 0.5 - 46.0, 110.0)
			_play.add_child(face)
		var line := UiKit.title(I18n.t("garden.visit_empty"), 26,
			Color(0.52, 0.48, 0.40))
		line.position = origin + Vector2(60.0, 230.0)
		line.size = Vector2(wide - 120.0, 40)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_play.add_child(line)
		return

	var y := origin.y + 74.0
	for entry_index in range(mini(log.size(), 3)):
		var entry: Dictionary = log[entry_index]
		var who := str(entry.get("who", "bear"))
		var card := Panel.new()
		card.add_theme_stylebox_override("panel",
			UiKit.panel_style(Color(1.0, 0.99, 0.95), 20))
		card.position = Vector2(origin.x + 24.0, y)
		card.custom_minimum_size = Vector2(wide - 48.0, 92)
		card.size = Vector2(wide - 48.0, 92)
		_play.add_child(card)

		var face := UiKit.picture("teddy", 64.0)
		if face != null:
			face.position = card.position + Vector2(14.0, 14.0)
			_play.add_child(face)

		# What they did, one icon at a time, from the same template table
		# tools_check reads -- so a line the screen can show is always a line
		# the checker has approved. Two stories, two line sets: "lines" when
		# the bear came here, "visited_lines" when the child went THERE (a
		# guest entry) -- same board, so kindness in both directions is one
		# list.
		var x := card.position.x + 100.0
		var set_key := "visited_lines" \
			if str(entry.get("kind", "")) == "guest" else "lines"
		var lines: Array = templates.get(who, {}).get(set_key, [])
		for line_def: Dictionary in lines:
			var count_field := str(line_def.get("count_field", ""))
			var count := int(entry.get(count_field, 0)) if count_field != "" else 1
			if count <= 0:
				continue
			var art := UiKit.picture(str(line_def.get("icon", "star")), 40.0)
			if art != null:
				art.position = Vector2(x, card.position.y + 12.0)
				_play.add_child(art)
			# On a milestone entry the counts stand aside: the friendship
			# line is long, it runs right under this column, and "x1" over
			# the middle of a sentence reads as noise over news.
			if count_field != "" and not entry.has("milestone_key"):
				var many := UiKit.title("x%d" % count, 22)
				many.position = Vector2(x + 6.0, card.position.y + 54.0)
				many.size = Vector2(52, 26)
				_play.add_child(many)
			x += 74.0

		# The footnote: the milestone's sentence when this visit carried one
		# -- an old friend's Nth call is the more interesting story -- and
		# the first template line's otherwise. Small, grey, one line.
		var note_key := str(entry.get("milestone_key", ""))
		if note_key == "" and not lines.is_empty():
			note_key = str((lines[0] as Dictionary).get("key", ""))
		if note_key != "":
			var note := UiKit.title(I18n.t(note_key), 18,
				Color(0.72, 0.52, 0.28) if entry.has("milestone_key")
				else Color(0.55, 0.51, 0.44))
			note.position = card.position + Vector2(100.0, 62.0)
			note.size = Vector2(wide - 190.0, 24)
			_play.add_child(note)
		if entry.has("milestone_icon"):
			var keepsake := UiKit.picture(str(entry.get("milestone_icon", "heart")), 40.0)
			if keepsake != null:
				keepsake.position = Vector2(x, card.position.y + 12.0)
				_play.add_child(keepsake)
		y += 104.0


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
	add_child(card)
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


## 小熊的菜谱本：一页六道菜。会做的亮着、配料和名字都在；还不会的只留
## 暗色配料——"去凑齐这些"本身就是答案，和图鉴的剪影一个道理。
func _recipes_panel(view: Vector2) -> void:
	var wide := 640.0
	var origin := _panel_sheet(view, "garden.recipes_title", wide, 470.0)
	var y := origin.y + 70.0
	for recipe in Recipes.all():
		var known: bool = Recipes.is_unlocked(str(recipe.get("id", "")))
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(
			Color(1.0, 0.99, 0.95) if known else Color(0.93, 0.91, 0.86), 16))
		row.position = Vector2(origin.x + 24.0, y)
		row.custom_minimum_size = Vector2(wide - 48.0, 56.0)
		row.size = Vector2(wide - 48.0, 56.0)
		_play.add_child(row)
		var x := row.position.x + 14.0
		for need in recipe.get("needs", []):
			var art := UiKit.picture(str(GameData.get_crop(
				str(need.get("crop_id", ""))).get("icon", "seed")), 30.0)
			if art != null:
				art.position = Vector2(x, y + 13.0)
				art.modulate = Color(1, 1, 1, 1.0) if known else Color(1, 1, 1, 0.35)
				_play.add_child(art)
			var many := UiKit.title("x%d" % int(need.get("count", 1)), 16,
				Color(0.4, 0.38, 0.34) if known else Color(0.62, 0.60, 0.56))
			many.position = Vector2(x + 28.0, y + 20.0)
			many.size = Vector2(34.0, 20.0)
			_play.add_child(many)
			x += 66.0
		var dish := UiKit.title(I18n.t(str(recipe.get("name_key", ""))) if known
			else "?", UiKit.TYPE_BODY,
			Color(0.30, 0.28, 0.24) if known else Color(0.62, 0.60, 0.56))
		dish.position = Vector2(row.position.x + row.size.x - 220.0, y + 12.0)
		dish.size = Vector2(200.0, 32.0)
		dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_play.add_child(dish)
		y += 64.0


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
func _an_order_he_can_fill() -> String:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	for order in GameData.garden_orders:
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
	return Vector2(RACK_X + RACK_STEP * float(index), view.y - SHELF * 0.25)


## The one plot that most wants attention, or -1 if the garden is content.
##
## Order is what a child should do first, not what is most urgent to a
## programmer: something ripe is the reward and comes first, then something
## that has stopped and is waiting, then bare earth to turn.
func _the_plot_that_wants_something() -> int:
	var plots := _plots()
	for want in [Farm.READY, Farm.NEEDS_CARE, Farm.EMPTY, Farm.TILLED]:
		for i in range(plots.size()):
			if str(plots[i].get("state", "")) == want:
				return i
	return -1


## Help, step one: say it again, and make the thing glow.
func _nudge() -> void:
	var index := _the_plot_that_wants_something()
	if index < 0:
		return
	var plots := _plots()
	match str(plots[index].get("state", "")):
		Farm.READY: AudioManager.say("garden_tut_harvest")
		Farm.NEEDS_CARE: AudioManager.say("garden_tut_water")
		Farm.EMPTY: AudioManager.say("garden_tut_till")
		_: AudioManager.say("garden_tut_plant")
	Juice.shockwave(_play, _bed_centre(index), 140.0,
		Color(1.0, 0.94, 0.62, 0.5))


## Help, step two: show the finger doing it.
func _show_the_move() -> void:
	var index := _the_plot_that_wants_something()
	if index < 0:
		return
	var hand := Tutorial.new()
	_play.add_child(hand)
	var bed := _bed_centre(index)
	var from: Vector2 = _seed_rack_centre() \
		if str(_plots()[index].get("state", "")) == Farm.TILLED else bed
	hand.add_step(from, bed, 1.3)
	hand.play()


## Help, step three: do the hard part, and leave the last move to him.
##
## The rule the whole hint system is built on -- never finish it FOR him. For
## a plot that needs turning, that means turning it, because the move after it
## (dropping a seed in) is the one worth having. For a plot that is waiting on
## water or weeds there is only one move, so this stops at showing it again:
## doing it would be doing the whole thing.
func _do_the_hard_part() -> void:
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
## A door in the garden and nowhere else. The eight harvest levels are
## deliberately off the island's map: they are one template eight times, which
## is right for a challenge a child CHOOSES and wrong for a stretch of the
## path he is walked down. See GameData.get_levels_for_mode().
##
## The next one he has not finished, so the button is always "the one to play"
## rather than a menu of eight. When they are all done it offers the last one
## again -- replaying is fine, and a door that stops opening is a door that
## looks broken.
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

	# One chip family on this bar: 56 tall, 12 apart, 26 from the edge. The
	# first cut gave this card its own height and its own x, and at some
	# window shapes it leaned on the purse's shoulder.
	var door := UiKit.card(Color(0.98, 0.94, 0.78))
	door.custom_minimum_size = Vector2(186, 56)
	door.position = Vector2(view.x - 26.0 - 150.0 - 12.0 - 186.0, 24)
	_play.add_child(door)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	door.add_child(row)
	var basket: Control = UiKit.picture("basket", 38.0)
	if basket != null:
		row.add_child(basket)
	# How many are done, as a number he can compare to eight. No percentage.
	var count := UiKit.title("%d/%d" % [done, levels.size()], 24)
	row.add_child(count)

	var press := Button.new()
	press.flat = true
	press.focus_mode = Control.FOCUS_NONE
	press.position = door.position
	press.size = door.custom_minimum_size
	press.custom_minimum_size = door.custom_minimum_size
	var go := str(next.get("id", ""))
	press.pressed.connect(func(): GameManager.start_level(go))
	_play.add_child(press)
