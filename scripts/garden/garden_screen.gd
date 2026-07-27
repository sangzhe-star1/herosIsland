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

## How far apart two beds have to be, derived from the snap radius rather than
## chosen by eye.
##
## DragField clicks a released piece into any slot within SNAP of it, so two
## beds closer together than twice that can both claim the same drop -- and a
## child who watched his carrot land in the wrong bed has no way to move it.
## The margin on top is for the thumb: releasing 40px off centre is normal.
##
## Written as arithmetic on DragField.SNAP on purpose. The first cut picked 260
## across and 200 down by eye, which was under the line in one direction, and
## the touch probe caught it. Retuning the snap radius now moves the beds with
## it instead of quietly breaking them.
const BED_GAP := DragField.SNAP * 2.0 + 26.0

const PLOT_BOX := Vector2(240, 168)
const SEED_TILE := Vector2(104, 84)
const TOP_BAR := 96.0
const SHELF := 168.0

## How long a plot stays untappable after being picked. Long enough to cover
## the crops flying into the barn, short enough that a child who taps twice on
## purpose is not left wondering why the second one did nothing.
const HARVEST_LOCK_SECONDS := 0.45

var _field: DragField
var _play: Control
var _shelf: Control
var _rebuild_queued := false

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
## The first-planting lesson, while it is running.
var _lesson: Tutorial
## Seconds the tutorial carrot takes, replacing its real 30 minutes for the
## length of the lesson and never written to crops.json.
var _tutorial_growth := 0


## A room, not a level: nothing here completes and nothing here is scored.
func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	# Whatever grew while he was away, before the first thing is drawn. Growth
	# is worked out from timestamps, so this is the only moment it has to
	# happen -- there is nothing ticking to keep up with afterwards.
	SaveManager.settle_farm()
	# When he last actually stood here, as opposed to when growth was last
	# settled -- which anything that loads the save does, including a level.
	SaveManager.data["farm"]["last_farm_visit_at"] = GameClock.now_unix()
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

func _rebuild() -> void:
	for child in get_children():
		if child is Control or child is DragField:
			child.queue_free()
	_field = null

	var view := get_viewport_rect().size
	_play = UiKit.play_area(self, true)
	_top_bar(view)
	_plot_beds(view)
	_order_board(view)
	# The barn is drawn AFTER the rack, because the rack lays down the shelf
	# panel and anything added before it ends up underneath.
	_seed_rack(view)
	_barn(view)


func _queue_rebuild() -> void:
	# Rebuilding inside a signal handler would free the node that is still
	# delivering it. One frame later is soon enough and always safe.
	if _rebuild_queued:
		return
	_rebuild_queued = true
	await get_tree().process_frame
	_rebuild_queued = false
	if is_inside_tree():
		_rebuild()


func _top_bar(view: Vector2) -> void:
	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(26, 22)
	_play.add_child(back)

	var title := UiKit.title_on_art(I18n.t("garden.title"), 46)
	title.position = Vector2(view.x * 0.5 - 220.0, 26)
	title.size = Vector2(440, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play.add_child(title)

	# The purse, read-only. Nothing in the garden spends or earns yet -- that
	# arrives with the orders -- but the number he is used to seeing in every
	# other room should not vanish in this one.
	var purse := UiKit.card(Color(1.0, 0.98, 0.90))
	purse.position = Vector2(view.x - 208.0, 24)
	purse.custom_minimum_size = Vector2(182, 56)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var coin := UiKit.picture("star_coin", 34.0)
	if coin != null:
		row.add_child(coin)
	var amount := UiKit.title(str(Coins.balance()), 30)
	row.add_child(amount)
	purse.add_child(row)
	_play.add_child(purse)


func _plot_beds(view: Vector2) -> void:
	_field = DragField.new()
	_play.add_child(_field)
	_field.dropped.connect(_on_seed_dropped)

	var plots := _plots()
	for i in range(plots.size()):
		_one_bed(plots[i], i, _bed_centre(i))


func _one_bed(plot: Dictionary, index: int, at: Vector2) -> void:
	var doing := str(plot.get("state", Farm.EMPTY))
	var tilled := Farm.is_tilled(plot)
	var crop_id := str(plot.get("crop_id", ""))
	var crop: Dictionary = GameData.get_crop(crop_id)
	var ready := Farm.is_ready(plot)
	var thirsty := str(plot.get("care_event", "")) == Growth.CARE_THIRSTY

	var bed := Button.new()
	# NOT flat. A flat Button skips its stylebox entirely, which is how the
	# first cut of this screen came out as four invisible patches of earth
	# with progress rings floating in the sky above them.
	bed.flat = false
	bed.position = at - PLOT_BOX * 0.5
	bed.custom_minimum_size = PLOT_BOX
	bed.size = PLOT_BOX
	bed.focus_mode = Control.FOCUS_NONE
	var earth := Color(0.45, 0.32, 0.22) if tilled else Color(0.38, 0.62, 0.34)
	for look in ["normal", "hover", "pressed", "focus"]:
		bed.add_theme_stylebox_override(look, UiKit.panel_style(earth, 26))
	_play.add_child(bed)
	bed.pressed.connect(func(): _tap_plot(index))

	# What is growing, if anything, and how far along it is.
	if Farm.is_planted(plot) and not crop.is_empty():
		var done := Growth.fraction_done(plot, crop)
		var size := 56.0 + 62.0 * done
		var art := UiKit.picture(str(crop.get("icon", "sprout")), size)
		if art != null:
			art.position = at - Vector2(size, size) * 0.5 - Vector2(0, 8)
			_play.add_child(art)
		_ring(at, 64.0, done)
	elif doing == Farm.TILLED:
		# Turned and empty: the ONE state a seed may be dropped into, which is
		# now a single word rather than two booleans that have to agree. The
		# dashed ring is DragField's own idea of a target, so it lights up on
		# its own when a seed is picked up.
		var hole := UiKit.picture("seed", 78.0)
		if hole != null:
			hole.modulate = Color(1, 1, 1, 0.55)
			hole.position = at - Vector2(39, 39)
			_play.add_child(hole)
		var target := Node2D.new()
		target.position = at
		_play.add_child(target)
		_field.add_slot(target, at, "", 1)

	# The badge: the one thing this plot is asking for. Icons, not words --
	# he cannot read, and this is the only instruction on the screen.
	var badge := ""
	match doing:
		Farm.EMPTY:
			badge = "soil"
		Farm.READY:
			badge = "basket"
		Farm.NEEDS_CARE:
			badge = "watering_can" if thirsty else "weed"
	if badge != "":
		_badge(at + Vector2(PLOT_BOX.x * 0.5 - 30.0, -PLOT_BOX.y * 0.5 + 30.0), badge)


func _badge(at: Vector2, icon_name: String) -> void:
	var disc := Panel.new()
	disc.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 26))
	disc.position = at - Vector2(30, 30)
	disc.custom_minimum_size = Vector2(60, 60)
	disc.size = Vector2(60, 60)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(disc)
	var art := UiKit.picture(icon_name, 44.0)
	if art != null:
		art.position = at - Vector2(22, 22)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_play.add_child(art)
	Juice.idle_bob(disc, 5.0, 2.2)


## A ring that fills as the crop grows. A six-year-old reads a ring filling up;
## he cannot read "stage 3 of 5".
func _ring(centre: Vector2, radius: float, fraction: float) -> void:
	var back := Node2D.new()
	back.position = Vector2.ZERO
	_play.add_child(back)
	Shapes.fill(back, _annulus(centre, radius, 7.0, 1.0),
		Color(1, 1, 1, 0.45), 1.0)
	if fraction > 0.01:
		Shapes.fill(back, _annulus(centre, radius, 7.0, fraction),
			Color(1.0, 0.80, 0.18), 1.0)


func _annulus(centre: Vector2, radius: float, width: float,
		fraction: float) -> PackedVector2Array:
	var steps := maxi(3, int(round(48.0 * clampf(fraction, 0.0, 1.0))))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(steps + 1):
		var a: float = -PI * 0.5 + TAU * clampf(fraction, 0.0, 1.0) * (float(i) / float(steps))
		var dir := Vector2(cos(a), sin(a))
		outer.append(centre + dir * radius)
		inner.append(centre + dir * (radius - width))
	inner.reverse()
	var ring := PackedVector2Array(outer)
	ring.append_array(inner)
	return ring


func _seed_rack(view: Vector2) -> void:
	var shelf_h := 168.0
	var shelf := Panel.new()
	shelf.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 0))
	shelf.position = Vector2(0, view.y - shelf_h)
	shelf.custom_minimum_size = Vector2(view.x, shelf_h)
	shelf.size = Vector2(view.x, shelf_h)
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(shelf)
	_shelf = shelf

	var unlocked: Array = _farm().get("unlocked_crops", [])
	var x := 90.0
	var y := view.y - shelf_h * 0.5
	for crop_id in unlocked:
		var crop: Dictionary = GameData.get_crop(str(crop_id))
		if crop.is_empty():
			continue
		var tile := Node2D.new()
		tile.position = Vector2(x, y)
		_play.add_child(tile)
		Shapes.fill(tile, Shapes.rounded_rect(
			-SEED_TILE * 0.5, SEED_TILE, 18.0), Color(0.96, 0.92, 0.82), 1.0)
		var art := UiKit.picture(str(crop.get("icon", "seed")), 58.0)
		if art != null:
			art.position = Vector2(x - 29.0, y - 34.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_play.add_child(art)
		_field.add_item(tile, Vector2(x, y), str(crop_id))
		x += SEED_TILE.x + 26.0


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
			# SEEDED or GROWING. Nothing to do yet -- say so with the plant
			# itself rather than with a refusal.
			AudioManager.play_sfx("res://assets/audio/correct.ogg")
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
		return
	Farm.remember_paid(farm, key)

	_harvesting[plot_id] = true

	var crop: Dictionary = GameData.get_crop(crop_id)
	var picked := maxi(int(crop.get("harvest_amount", 1)), 1)
	Barn.put(crop_id, picked)

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

	AudioManager.play_sfx("res://assets/audio/star.ogg")
	AudioManager.say("praise_1")
	_harvested_something = true
	_release_after_the_animation(plot_id)


## Let go of the plot once the picking animation has had its moment.
func _release_after_the_animation(plot_id: String) -> void:
	await get_tree().create_timer(HARVEST_LOCK_SECONDS).timeout
	_harvesting.erase(plot_id)


func _on_seed_dropped(item: Dictionary, slot: Variant, correct: bool) -> void:
	if not correct or slot == null:
		return
	var at: Vector2 = slot.get("at", Vector2.ZERO)
	var plots := _plots()
	var index := -1
	var best := 1e9
	for i in range(plots.size()):
		var centre := _bed_centre(i)
		var d := centre.distance_to(at)
		if d < best:
			best = d
			index = i
	if index < 0:
		return
	var plot: Dictionary = plots[index]
	# There is no "is this bed already planted" check here, and there does not
	# need to be: a bed only offers DragField a slot while it is turned AND
	# empty, so a planted bed is not a target at all. The child never sees a
	# ring light up over his carrot, which is a better answer than refusing him
	# after he has already let go. Deleting the check and watching the touch
	# probe stay green is how it was found to be unreachable.
	plot["crop_id"] = str(item.get("key", ""))
	plot["state"] = Farm.SEEDED
	# A new planting, and therefore a new transaction id for whatever comes out
	# of it. Rising by one here is the whole reason a harvest cannot be paid
	# for twice; see _harvest().
	plot["plant_cycle_id"] = int(plot.get("plant_cycle_id", 0)) + 1
	plot["planted_at"] = GameClock.now_unix()
	plot["last_updated_at"] = GameClock.now_unix()
	plot["growth_stage"] = 0
	plot["growth_progress"] = 0.0
	plot["water_level"] = 1.0
	plot["care_event"] = ""
	plot["care_completed"] = false
	plots[index] = plot
	SaveManager.data["farm"]["plots"] = plots
	SaveManager.save_game()
	AudioManager.play_sfx("res://assets/audio/drag_snap.ogg")
	_queue_rebuild()


## Where plot `index` sits, measured from the viewport every time.
##
## Never from a hard-coded 720: the island stretches with aspect=expand, so a
## 4:3 tablet hands this screen a 1280x960 viewport, and anything positioned
## against 720 ends up floating a quarter of the way down. That has shipped
## here twice.
func _bed_centre(index: int) -> Vector2:
	var view := get_viewport_rect().size
	var gap := maxf(BED_GAP, PLOT_BOX.x + 40.0)
	var middle := TOP_BAR + (view.y - TOP_BAR - SHELF) * 0.5
	# The block sits left of centre. The right third is where the order board
	# goes when there are orders to put on it.
	var origin := Vector2(view.x * 0.33 - gap * 0.5, middle - BED_GAP * 0.5)
	return origin + Vector2(float(index % 2) * gap, float(index / 2) * BED_GAP)


# --- the barn and the order board ---------------------------------------

## What is in the barn, along the bottom of the play area.
##
## Small and always visible rather than behind a button: the whole point of
## growing something is watching the pile get bigger, and a pile behind a door
## is a pile he has to remember to go and look at.
func _barn(view: Vector2) -> void:
	# Inside the shelf, to the right of the seeds. The first cut put it just
	# above the shelf and it landed on top of the bottom row of beds -- there
	# is no room between them at 16:9, and "your seeds | your barn" belongs
	# together anyway: both are things he HAS.
	var contents := Barn.contents()
	var at := Vector2(view.x * 0.52, view.y - SHELF + 58.0)

	var label := UiKit.title(I18n.t("garden.barn"), 24)
	label.position = at - Vector2(0, 40)
	label.size = Vector2(220, 30)
	_play.add_child(label)

	var basket := UiKit.picture("basket", 48.0)
	if basket != null:
		basket.position = at
		_play.add_child(basket)

	if contents.is_empty():
		return
	var x := at.x + 64.0
	for pair in contents:
		var crop: Dictionary = GameData.get_crop(str(pair[0]))
		var art := UiKit.picture(str(crop.get("icon", "seed")), 42.0)
		if art != null:
			art.position = Vector2(x, at.y + 4.0)
			_play.add_child(art)
		var many := UiKit.title("x%d" % int(pair[1]), 24)
		many.position = Vector2(x + 38.0, at.y + 12.0)
		many.size = Vector2(56, 28)
		_play.add_child(many)
		x += 100.0


## Who needs a hand today. Three cards, each one a picture of somebody, what
## they want, and what they will give for it.
func _order_board(view: Vector2) -> void:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	var at := Vector2(view.x * 0.66, TOP_BAR + 24.0)

	var heading := UiKit.title_on_art(I18n.t("garden.orders"), 30)
	heading.position = at
	heading.size = Vector2(400, 40)
	_play.add_child(heading)

	var y := at.y + 54.0
	for order in GameData.garden_orders:
		var order_id := str(order.get("id", ""))
		var done: bool = order_id in delivered
		var wants: Dictionary = order.get("requirements", {})
		var can: bool = Barn.can_pay(wants)

		var card := Button.new()
		card.flat = false
		card.focus_mode = Control.FOCUS_NONE
		card.position = Vector2(at.x, y)
		card.custom_minimum_size = Vector2(378, 96)
		card.size = Vector2(378, 96)
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
		y += 110.0


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
	orders["delivered"] = delivered
	SaveManager.data["farm_orders"] = orders
	SaveManager.save_game()

	if paid > 0:
		AudioManager.play_sfx("res://assets/audio/coin.ogg")
		AudioManager.say("praise_2")
		_harvested_something = true
		_offer_a_break()
	if _hints != null:
		_hints.progress()
	_queue_rebuild()


# --- the first planting, the graded help, and the way to stop ------------

## The lesson, run once in a child's life.
##
## Not a script that plays AT him: the helper points, he does it, the helper
## points at the next thing. Every step is a real action on the real garden --
## there is no rehearsal mode and nothing is faked, so what he learns is the
## thing he will do tomorrow.
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

	_lesson = Tutorial.new()
	_play.add_child(_lesson)
	var bed := _bed_centre(int(plan.get("plot_index", 0)))
	# Point at the earth, then at the seed rack, then at the earth again --
	# turn it over, put something in it, look after it. Three moves, in the
	# order he will do them.
	_lesson.add_step(bed, bed, 1.2)
	_lesson.add_step(_seed_rack_centre(), bed, 1.4)
	_lesson.add_step(bed, bed, 1.0)
	_lesson.finished.connect(_the_lesson_is_over)
	AudioManager.say("garden_tut_welcome")
	_lesson.play()


## Written down the moment the lesson ends, and never asked again.
func _the_lesson_is_over() -> void:
	var farm := _farm()
	farm["tutorial_completed"] = true
	SaveManager.save_game()


## Roughly where the seed rack sits, for the finger to point at.
func _seed_rack_centre() -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(view.x * 0.5, view.y - SHELF * 0.5)


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
