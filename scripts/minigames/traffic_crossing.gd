extends LevelManager
## "Cross the Road Safely" -- the first vertical slice, and the template that
## four different levels are built from via data/levels.json.
##
## The lesson, in this order:
##   1. red means stop, green means go        (difficulty 1)
##   2. still look for cars on a green light  (difficulty 2+, "runner" cars)
##   3. do all of that when it is harder      (difficulty 3, faster, rain)
##
## Getting it wrong is never punished. The hero steps back, a calm voice says
## why, and the child tries again. Only the star count reflects mistakes, and
## finishing always earns at least one star.

const ROAD_TOP := 150.0
const ROAD_BOTTOM := 520.0
const CROSSWALK_LEFT := 545.0
const CROSSWALK_RIGHT := 735.0
const NEAR_SIDE_Y := 615.0
const FAR_SIDE_Y := 95.0
const WALK_SECONDS := 1.7
## How far ahead we look for traffic when the child taps. Roughly the time the
## hero needs to be inside the road.
const LOOKAHEAD_SECONDS := 2.2

enum Light { RED, GREEN }

var _light: int = Light.RED
var _light_timer := 0.0
var _spawn_timer := 0.0
var _walking := false
var _at_far_side := false

var _cars: Array = []
var _lane_ys: Array[float] = []

# Difficulty knobs, all read from the level's "config" block.
var _car_speed := 150.0
var _gap_min := 2.2
var _gap_max := 3.4
var _green_seconds := 5.0
var _red_seconds := 5.0
var _lanes := 1
var _late_cars := false
var _rain := false

var _hero: SkinnedCharacter
var _light_body: Polygon2D
var _road_layer: Node2D
var _instruction: Label
var _progress: Label
var _cross_button: Button


## One moving car. Kept as a plain object so cars cost nothing to spawn.
class Car extends RefCounted:
	var node: Node2D
	var speed: float
	var direction: int   # 1 = left to right, -1 = right to left
	var runner: bool     # ignores the stop line; teaches "look anyway"
	var stopped: bool = false


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_car_speed = float(config.get("car_speed", 150.0))
	_gap_min = float(config.get("car_gap_min", 2.2))
	_gap_max = float(config.get("car_gap_max", 3.4))
	_green_seconds = float(config.get("green_seconds", 5.0))
	_red_seconds = float(config.get("red_seconds", 5.0))
	_lanes = int(config.get("lanes", 1))
	_rain = bool(config.get("rain", false))
	# Cars that run a late green only appear once the basic rule is learned.
	_late_cars = bool(config.get("late_cars", int(level_data.get("difficulty", 1)) >= 2))

	_build_scene()
	_build_ui()
	_set_light(Light.RED)
	_spawn_timer = 1.0


# --- construction -------------------------------------------------------

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.75, 0.55) if not _rain else Color(0.42, 0.52, 0.50)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var road := ColorRect.new()
	road.color = Color(0.30, 0.30, 0.33) if not _rain else Color(0.22, 0.23, 0.27)
	road.position = Vector2(0, ROAD_TOP)
	road.size = Vector2(1280, ROAD_BOTTOM - ROAD_TOP)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(road)

	# Zebra stripes mark the only safe place to cross.
	for i in range(6):
		var stripe := ColorRect.new()
		stripe.color = Color(0.95, 0.95, 0.92, 0.9)
		stripe.position = Vector2(CROSSWALK_LEFT + i * 32.0, ROAD_TOP)
		stripe.size = Vector2(20, ROAD_BOTTOM - ROAD_TOP)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)

	_lane_ys.clear()
	var span := ROAD_BOTTOM - ROAD_TOP
	for i in range(_lanes):
		_lane_ys.append(ROAD_TOP + span * (float(i) + 0.5) / float(_lanes))

	_road_layer = Node2D.new()
	add_child(_road_layer)

	_build_traffic_light()

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(640, NEAR_SIDE_Y)
	_hero.scale = Vector2(1.15, 1.15)
	add_child(_hero)


func _build_traffic_light() -> void:
	var pole := ColorRect.new()
	pole.color = Color(0.25, 0.25, 0.28)
	pole.position = Vector2(792, 470)
	pole.size = Vector2(12, 180)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pole)

	var housing := ColorRect.new()
	housing.color = Color(0.18, 0.18, 0.20)
	housing.position = Vector2(760, 380)
	housing.size = Vector2(76, 110)
	housing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(housing)

	# One large lamp rather than a stack: at this age the colour is the signal,
	# and a single bright circle is far easier to read at a glance.
	_light_body = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * 30.0 + Vector2(798, 435))
	_light_body.polygon = pts
	add_child(_light_body)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	layer.add_child(root)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	root.add_child(back)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 34)
	_progress.add_theme_color_override("font_color", Color.WHITE)
	# Right-aligned inside a fixed box that ends 24px short of the right edge,
	# so the text grows leftward and can never run off-screen. At x=980 with no
	# box it overflowed by 18px in every traffic level (the smoke test's one
	# standing warning).
	_progress.position = Vector2(756, 36)
	_progress.size = Vector2(500, 48)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_progress)
	_update_progress()

	_instruction = Label.new()
	_instruction.text = I18n.t("traffic.instruction")
	_instruction.add_theme_font_size_override("font_size", 38)
	_instruction.add_theme_color_override("font_color", Color.WHITE)
	_instruction.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_instruction.add_theme_constant_override("outline_size", 8)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# No anchor preset here: PRESET_CENTER_TOP anchors to the screen centre and
	# then treats `position` as an offset from it, which pushed this label to
	# x=980 and ran 300px off the right edge. Plain absolute positioning, like
	# every other label in the game.
	_instruction.position = Vector2(340, 40)
	_instruction.custom_minimum_size = Vector2(600, 0)
	_instruction.size = Vector2(600, 60)
	root.add_child(_instruction)

	# Bottom-right, not bottom-centre: centred it sat exactly on top of the
	# hero waiting at the kerb, hiding everything but his head -- and on a
	# landscape tablet the right corner is where the child's thumb already
	# rests anyway.
	_cross_button = UiKit.big_button(I18n.t("traffic.tap_to_cross"), Color(0.20, 0.62, 0.35))
	_cross_button.custom_minimum_size = Vector2(380, 130)
	_cross_button.position = Vector2(864, 566)
	_cross_button.pressed.connect(_on_cross_pressed)
	root.add_child(_cross_button)


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_tick_light(delta)
	_tick_spawn(delta)
	_tick_cars(delta)


func _tick_light(delta: float) -> void:
	_light_timer -= delta
	if _light_timer > 0.0:
		return
	_set_light(Light.GREEN if _light == Light.RED else Light.RED)


func _set_light(value: int) -> void:
	_light = value
	if value == Light.GREEN:
		_light_timer = _green_seconds
		_light_body.color = Color(0.25, 0.85, 0.35)
		_instruction.text = I18n.t("traffic.go")
	else:
		_light_timer = _red_seconds
		_light_body.color = Color(0.90, 0.25, 0.25)
		_instruction.text = I18n.t("traffic.wait")


func _tick_spawn(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(_gap_min, _gap_max)
	_spawn_car()


func _spawn_car() -> void:
	if _lane_ys.is_empty():
		return
	var lane := randi() % _lane_ys.size()
	var direction := 1 if lane % 2 == 0 else -1

	var car := Car.new()
	car.speed = _car_speed * randf_range(0.9, 1.15)
	car.direction = direction
	# A runner only ever appears while the light is still red, so it is always
	# visible before the child decides. The child is never ambushed.
	car.runner = _late_cars and _light == Light.RED and randf() < 0.35

	var node := Node2D.new()
	var body := ColorRect.new()
	body.size = Vector2(120, 60)
	body.position = Vector2(-60, -30)
	body.color = Color.from_hsv(randf(), 0.55, 0.9)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(body)

	var window := ColorRect.new()
	window.size = Vector2(44, 30)
	window.position = Vector2(-10 * direction, -22)
	window.color = Color(0.75, 0.88, 0.95)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(window)

	node.position = Vector2(-140.0 if direction > 0 else 1420.0, _lane_ys[lane])
	_road_layer.add_child(node)

	car.node = node
	_cars.append(car)


func _tick_cars(delta: float) -> void:
	var survivors: Array = []
	for car in _cars:
		var stop_x: float = CROSSWALK_LEFT - 90.0 if car.direction > 0 else CROSSWALK_RIGHT + 90.0
		var before_line: bool = (car.node.position.x < stop_x) if car.direction > 0 \
			else (car.node.position.x > stop_x)

		# On a green pedestrian light, ordinary cars wait at the line. Cars that
		# are already inside the crossing drive on through, which is exactly the
		# situation the child needs to learn to wait out.
		car.stopped = _light == Light.GREEN and not car.runner and before_line

		if not car.stopped:
			car.node.position.x += car.speed * car.direction * delta

		if car.node.position.x < -300.0 or car.node.position.x > 1580.0:
			car.node.queue_free()
		else:
			survivors.append(car)
	_cars = survivors


# --- the decision -------------------------------------------------------

func _on_cross_pressed() -> void:
	if _walking:
		return

	if _light == Light.RED:
		_reject("traffic.too_soon", "wrong_light")
		return

	if _traffic_in_the_way():
		_reject("traffic.car_coming", "car_coming")
		return

	_walk_across()


## True if any moving car is inside the crossing, or will reach it before the
## hero is clear. Stopped cars are safe and deliberately do not block, otherwise
## a queue at the line would make the level unwinnable.
func _traffic_in_the_way() -> bool:
	for car in _cars:
		if car.stopped:
			continue
		var x: float = car.node.position.x
		var future_x: float = x + car.speed * car.direction * LOOKAHEAD_SECONDS
		var lo: float = minf(x, future_x)
		var hi: float = maxf(x, future_x)
		if hi >= CROSSWALK_LEFT - 80.0 and lo <= CROSSWALK_RIGHT + 80.0:
			return true
	return false


func _reject(message_key: String, voice_clip: String) -> void:
	_instruction.text = I18n.t(message_key)
	AudioManager.play_voice("res://assets/audio/voice/level/%s.ogg" % voice_clip)
	_shake_hero()
	score_mistake()


## A small step backwards, not a scary noise or a lost life.
func _shake_hero() -> void:
	if not Juice.motion_enabled():
		return
	# Steps back rather than sideways: the hero retreating from the kerb is
	# the correction being shown, not just motion.
	var origin := _hero.position
	var t := create_tween()
	t.tween_property(_hero, "position", origin + Vector2(0, 26), 0.12)
	t.tween_property(_hero, "position", origin, 0.18)


func _walk_across() -> void:
	_walking = true
	_cross_button.disabled = true
	var destination := FAR_SIDE_Y if not _at_far_side else NEAR_SIDE_Y

	var t := create_tween()
	t.tween_property(_hero, "position:y", destination, WALK_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	_at_far_side = not _at_far_side
	_walking = false
	_cross_button.disabled = false
	_instruction.text = I18n.t("traffic.well_done")
	AudioManager.play_voice("res://assets/audio/voice/level/well_done.ogg")
	Juice.burst(self, _hero.position)
	_hero.celebrate()
	score_correct()
	_update_progress()


func on_correct() -> void:
	_update_progress()


func _update_progress() -> void:
	if _progress == null:
		return
	_progress.text = I18n.t("traffic.progress") % [
		result.correct, target_value("correct_crossings", 3)
	]
