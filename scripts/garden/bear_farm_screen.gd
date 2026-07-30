extends Node2D
## 小熊农场: a friend's garden, and one strawberry with a star over it.
##
## ONE SCREEN, NO CAMERA
##
## The bear's farm fits on the glass whole. That is on purpose: a visit is a
## moment, not a place to manage, and a place that pans is a place a child can
## get lost in twice over -- once at home, once here. Six beds, the bear, a
## well, and the way back, all visible at once.
##
## WHAT A VISIT IS
##
## Look around; if the shared strawberry has grown back, pick it (a tap -- the
## strawberry's own gesture); it flies to the visitor basket and is HIS, kept,
## whatever happens next. The bear then points at the thirsty bed, and
## watering it clears the promise and grows the friendship by one. A child who
## leaves without watering keeps the strawberry and finds the bear still
## hoping next time -- the next share waits on the kindness, but nothing is
## ever taken back and nobody is ever cross. See npc_farm_manager.gd for the
## arithmetic; this file only draws it and hands taps over.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Level := preload("res://scripts/garden/farm_level_manager.gd")
const PlotView := preload("res://scripts/garden/plot_view.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")

const TOP_BAR := 96.0

## Where the six beds sit on the glass, two rows of three on the left, leaving
## the right side to the bear and his well. Spaced by the same thumb rules as
## everything else: 236px between centres beats every reach in the game.
const BED_COLS := 3
const BED_FIRST := Vector2(240, 250)
const BED_STEP := Vector2(250, 240)

var _plots: Array = []
var _bed_views: Array = []
var _star: Node2D
var _basket_at := Vector2.ZERO
## Watered this visit, in memory only: the bear's farm has no save, and next
## visit the arithmetic will have dried the bed again, which is a garden being
## a garden.
var _watered_this_visit := false
var _t := 0.0
## Who owns the press: -1 nobody, a touch index, or -2 the mouse. The same
## claim the farm's world makes, for the same reason: with touch<->mouse
## emulation on, ONE physical tap arrives as BOTH event families, and a
## screen that answers each family separately does everything twice. The
## idempotence guards would eat the double quietly -- which is worse than
## loudly, because the probe proved it by removing one.
var _finger := -1
## How many presses this screen has actually dispatched. Read by the probe,
## which taps N times and requires exactly N -- the assertion that keeps the
## claim above from quietly rotting.
var presses := 0


func _ready() -> void:
	_build()
	AudioManager.say("bear_welcome")
	if NpcFarm.can_pick(GameClock.now_unix()):
		# One beat later so the welcome is not talked over.
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_inside_tree() and NpcFarm.can_pick(GameClock.now_unix()):
				AudioManager.say("bear_share"))


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_bed_views.clear()
	_star = null
	var view := get_viewport_rect().size

	# The ground: the bear's meadow, a shade warmer than home so "somewhere
	# else" is legible before anything else is read.
	Shapes.gradient_quad(self, Vector2.ZERO, view,
		Color(0.66, 0.82, 0.94), Color(0.80, 0.88, 0.72))
	Shapes.fill(self, Shapes.rounded_rect(Vector2(30, TOP_BAR + 20),
		view - Vector2(60, TOP_BAR + 50), 40.0), Color(0.76, 0.86, 0.60), 1.0)

	_plots = NpcFarm.bear_beds(GameClock.now_unix())
	for i in range(_plots.size()):
		var bed := PlotView.new()
		add_child(bed)
		bed.setup(i)
		bed.position = _bed_centre(i)
		bed.refresh(_plots[i])
		_bed_views.append(bed)

	# The share star, slowly turning over the one strawberry that is his to
	# take. The star IS the rule: no star, nothing to take, nothing to refuse.
	for i in range(_plots.size()):
		if bool(_plots[i].get("share", false)) \
				and Farm.is_ready(_plots[i]):
			_star = Node2D.new()
			_star.position = _bed_centre(i) + Vector2(0, -96)
			add_child(_star)
			Shapes.fill(_star, Shapes.star_points(Vector2.ZERO, 26.0),
				Color(1.0, 0.86, 0.30), 1.0)
			Shapes.glow(_star, Vector2.ZERO, 44.0,
				Color(1.0, 0.88, 0.42), 4, 0.5)

	# The bear, by his well, waving.
	var bear := UiKit.picture("teddy", 170.0)
	if bear != null:
		bear.position = Vector2(view.x - 320.0, 200.0)
		add_child(bear)
		Juice.idle_bob(bear, 6.0, 2.4)
	var well := Node2D.new()
	well.position = Vector2(view.x - 160.0, 420.0)
	add_child(well)
	Shapes.lit(well, Shapes.circle_points(Vector2.ZERO, 56.0),
		Color(0.62, 0.66, 0.72), 0.5)
	Shapes.fill(well, Shapes.circle_points(Vector2.ZERO, 34.0),
		Color(0.35, 0.52, 0.72), 0.0)
	var can := UiKit.picture("watering_can", 54.0)
	if can != null:
		can.position = well.position + Vector2(-90, -60)
		add_child(can)

	# The visitor basket: where the shared strawberry lands. HIS basket, drawn
	# apart from everything of the bear's.
	_basket_at = Vector2(view.x - 150.0, view.y - 130.0)
	var basket := UiKit.picture("basket", 84.0)
	if basket != null:
		basket.position = _basket_at - Vector2(42, 42)
		add_child(basket)

	_top_bar(view)

	# Owed from last time: the bear points at the thirsty bed straight away.
	if bool(NpcFarm.bear_state().get("help_owed", false)):
		_point_at_thirsty()


func _top_bar(view: Vector2) -> void:
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(0.99, 0.98, 0.93), 0))
	strip.position = Vector2.ZERO
	strip.custom_minimum_size = Vector2(view.x, TOP_BAR)
	strip.size = Vector2(view.x, TOP_BAR)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	var back := UiKit.back_button(_go_home)
	back.position = Vector2(26, 22)
	add_child(back)

	var title := UiKit.title_on_art(I18n.t("garden.bear_farm_title"), 46)
	title.position = Vector2(view.x * 0.5 - 220.0, 26)
	title.size = Vector2(440, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# The friendship so far: a star and a number. Only ever rises.
	var star := UiKit.picture("star", 40.0)
	if star != null:
		star.position = Vector2(view.x - 190.0, 28)
		add_child(star)
	var count := UiKit.title(str(NpcFarm.friendship()), 34)
	count.position = Vector2(view.x - 140.0, 30)
	count.size = Vector2(90, 44)
	add_child(count)


func _go_home() -> void:
	# Home is the garden, entered the front way so its own setup runs -- growth
	# settles, the dog re-aims, the shared strawberry he is carrying shows up
	# in the barn. current_level_id is still the garden's: it was set walking
	# IN and nothing here ever changes it.
	SceneManager.goto_scene("res://scenes/garden/Garden.tscn")


func _bed_centre(index: int) -> Vector2:
	return BED_FIRST + Vector2(
		float(index % BED_COLS) * BED_STEP.x,
		float(index / BED_COLS) * BED_STEP.y)


func _bed_under(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in range(_plots.size()):
		var centre := _bed_centre(i)
		var half: Vector2 = (_bed_views[i] as Node2D).call("reach")
		if absf(at.x - centre.x) > half.x or absf(at.y - centre.y) > half.y:
			continue
		var d := centre.distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1:
			_finger = touch.index
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			_press(touch.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _finger == -1:
			_finger = -2
		elif not click.pressed and _finger == -2:
			_finger = -1
			_press(click.position)


func _press(at: Vector2) -> void:
	presses += 1
	var index := _bed_under(at)
	if index < 0:
		return
	var plot: Dictionary = _plots[index]
	if bool(plot.get("share", false)):
		_pick_the_shared_one(index)
	elif bool(plot.get("help_target", false)):
		_water_for_the_bear(index)
	else:
		# The bear's own beds are the bear's. A wobble says "not this one"
		# without a refusal, a sound, or a lesson.
		Juice.nudge(_bed_views[index], 8.0)


## The pick. A tap is the strawberry's own harvest gesture, and the ONE
## allowed target is the bed wearing the star -- everything else already
## turned the tap away above.
func _pick_the_shared_one(index: int) -> void:
	var now := GameClock.now_unix()
	if not NpcFarm.can_pick(now):
		# The star is down: nothing here to take. The bed shrugs.
		Juice.nudge(_bed_views[index], 8.0)
		return
	# Written down FIRST, saved at once: a tablet closed mid-flight must come
	# back knowing the strawberry was his and the watering is owed.
	NpcFarm.record_pick(now)
	var farm_def: Dictionary = GameData.get_npc_farm("bear")
	Barn.store_harvest(str(farm_def.get("share_crop", "strawberry")), 1)
	# The shared berry can be the last ingredient of something. Unlock the
	# ledger quietly -- the celebration card belongs to the garden screen,
	# and this screen is the bear's own moment.
	preload("res://scripts/garden/recipe_manager.gd").check_barn()
	SaveManager.save_game()

	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	# The strawberry flies to HIS basket; the star goes out; the bed starts
	# growing the next one.
	if _star != null and is_instance_valid(_star):
		_star.queue_free()
		_star = null
	var art := UiKit.picture("strawberry", 56.0)
	if art != null:
		art.position = _bed_centre(index) - Vector2(28, 28)
		add_child(art)
		if Juice.motion_enabled():
			var t := art.create_tween()
			t.tween_property(art, "position", _basket_at - Vector2(28, 28), 0.5)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(art.queue_free)
		else:
			art.queue_free()
	_plots = NpcFarm.bear_beds(now)
	(_bed_views[index] as Node2D).call("refresh", _plots[index], true)

	AudioManager.say("bear_thirsty")
	_point_at_thirsty()


func _water_for_the_bear(index: int) -> void:
	if _watered_this_visit:
		return
	_watered_this_visit = true
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	# The bed drinks, on screen, this visit.
	var plot: Dictionary = _plots[index]
	plot["care_event"] = ""
	plot["water_level"] = 1.0
	plot["state"] = Farm.GROWING
	_plots[index] = plot
	(_bed_views[index] as Node2D).call("refresh", plot, true)

	if NpcFarm.record_help():
		# The whole exchange, written on the board at home: went visiting,
		# brought back the shared one, earned the star. Same board the bear's
		# own visits go on, so "who has been kind lately" is one place --
		# and the entry is a GUEST entry, telling the story from this side.
		var farm: Dictionary = SaveManager.data["farm"]
		Farm.remember_visit(farm, {"who": "bear", "kind": "guest",
			"shared": 1, "star": 1, "at": GameClock.now_unix()})
		# Helping a friend grows the farm too -- inside the help_owed gate,
		# so it pays exactly as many times as the kindness happened.
		Level.award("help")
		SaveManager.save_game()
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		AudioManager.say("bear_thanks")
		if Juice.motion_enabled():
			Juice.burst(self, _bed_centre(index), 16)


func _point_at_thirsty() -> void:
	for i in range(_plots.size()):
		if bool(_plots[i].get("help_target", false)):
			var hand := Tutorial.new()
			add_child(hand)
			hand.add_step(_bed_centre(i), _bed_centre(i), 1.3)
			hand.play()
			return


func _process(delta: float) -> void:
	_t += delta
	if _star != null and is_instance_valid(_star) and Juice.motion_enabled():
		_star.rotation = sin(_t * 1.4) * 0.4
		_star.position.y += sin(_t * 2.2) * 0.08
