extends LevelManager
## "Somebody needs you." The helping game.
##
## A character is in trouble and the child picks the right thing to do about
## it: the bandage for the cut paw, the umbrella for the rain, the green light
## for the road. Choose, watch it work, watch them be pleased.
##
## Two things make this template rather than a quiz:
##
##   * the one being helped is ALIVE the whole time -- worried before, relieved
##     after, and they say thank you with their face and not with a label
##   * a wrong choice is tried and gently doesn't work: the umbrella opens and
##     the character is still cold, so the child sees WHY, and picks again
##
## There is no timer, nothing to dodge and nothing to lose. This is the level
## a child plays when they want to be kind, and there should be one in every
## world for exactly that reason.

const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")
## The scene is drawn against 1280x720; a tablet hands it 1280x960. Everything
## placed below goes through Fit.at so the patient and the row of tools stay
## the same fraction of the way down the screen instead of leaving the bottom
## quarter empty.
const Fit := preload("res://scripts/shared/screen_fit.gd")

## Every situation: who needs help, what it looks like, and which tool fixes
## it. Hand-written, because "generate a problem" produces problems that make
## no sense to a six-year-old.
const CASES := [
	{"who": "paw", "trouble": "hurt", "tool": "plaster",
	 "wrong": ["scissors", "carrot", "umbrella"], "say": "rescue.hurt"},
	{"who": "fish", "trouble": "thirsty", "tool": "potion",
	 "wrong": ["blanket", "hat", "blocks"], "say": "rescue.thirsty"},
	{"who": "teddy", "trouble": "cold", "tool": "blanket",
	 "wrong": ["fish", "ball", "magnifier"], "say": "rescue.cold"},
	{"who": "paw", "trouble": "hungry", "tool": "carrot",
	 "wrong": ["socks", "crayon", "compass"], "say": "rescue.hungry"},
	{"who": "teddy", "trouble": "rain", "tool": "umbrella",
	 "wrong": ["comic", "berries", "medal"], "say": "rescue.rain"},
	{"who": "fish", "trouble": "lost", "tool": "compass",
	 "wrong": ["pillow", "matches", "coin"], "say": "rescue.lost"},
	{"who": "paw", "trouble": "dark", "tool": "spark",
	 "wrong": ["scarf", "socket", "sort"], "say": "rescue.dark"},
]

var _hud: Control
var _field: Control
var _hints: Hints
var _picker: Picker
var _cases: Array = []
var _at := 0
var _wanted := 4
var _tools: Array = []            # the row of things to choose from
var _patient: Node2D
var _face: Node2D
var _slips := 0
var _helped := false
var _thanked := 0                 # how many said thank you first try
var _busy := false
var _caption: Label
var _finished_level := false


func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_wanted = clampi(Hints.extra_things(harder_i(int(config.get("count", 4)), 1)), 3, 6)
	_cases = _picker.some(CASES, _wanted)
	while _cases.size() < _wanted:
		_cases.append(_picker.one(CASES))

	build_world(self, 0.40)
	_field = UiKit.play_area(self, true)
	_field.gui_input.connect(_on_tap)

	_build_hud()
	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_glow_tool, _show_the_tap, _use_it_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_next_case()
	_play_tutorial()


# --- one person at a time ---------------------------------------------------------

func _next_case() -> void:
	if _at >= _cases.size():
		_finish()
		return
	_busy = false
	for node in _tools:
		if is_instance_valid(node):
			node.queue_free()
	_tools.clear()
	if is_instance_valid(_patient):
		_patient.queue_free()

	var story: Dictionary = _cases[_at]
	_patient = Node2D.new()
	_patient.position = Fit.at(_field, Vector2(640, 300))
	_field.add_child(_patient)
	# The one who needs help, with a worried face floating over them. The face
	# is a separate node because it is the thing that changes.
	var art: Control = UiKit.picture(str(story["who"]), 168)
	if art != null:
		art.position = Vector2(-84, -84)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_patient.add_child(art)
	Juice.idle_bob(_patient, 8.0, 1.4)
	_face = Node2D.new()
	_face.position = Vector2(96, -96)
	_patient.add_child(_face)
	_paint_face(false)
	# And what is wrong, as a picture beside them.
	var trouble: Control = UiKit.picture(_trouble_icon(str(story["trouble"])), 74)
	if trouble != null:
		trouble.position = Vector2(-150, -120)
		trouble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_patient.add_child(trouble)

	# The tools: the right one and two or three that plainly are not.
	var choices: Array = [str(story["tool"])]
	var wrong: Array = (story["wrong"] as Array).duplicate()
	_picker.shuffle(wrong)
	var extra: int = 2 if difficulty() == GENTLE else 3
	for i in range(mini(extra, wrong.size())):
		choices.append(str(wrong[i]))
	_picker.shuffle(choices)
	var span: float = 200.0 * float(choices.size())
	for i in range(choices.size()):
		var x: float = 640.0 + (float(i) - float(choices.size() - 1) * 0.5) \
			* (span / float(choices.size()))
		var node := Node2D.new()
		node.position = Fit.at(_field, Vector2(x, 570.0))
		node.set_meta("tool", str(choices[i]))
		node.set_meta("home", node.position)      # where a refused tool goes back to
		_field.add_child(node)
		Shapes.fill(node, Shapes.rounded_rect(Vector2(-74, -74), Vector2(148, 148), 32.0),
			Color(0.96, 0.97, 1.0, 0.92), 0.0)
		var pic: Control = UiKit.picture(str(choices[i]), 96)
		if pic != null:
			pic.position = Vector2(-48, -48)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(pic)
		# Everything you can touch says so by breathing.
		if Juice.motion_enabled():
			node.scale = Vector2(0.9, 0.9)
			var t := node.create_tween()
			t.tween_interval(0.06 * float(i))
			t.tween_property(node, "scale", Vector2.ONE, 0.3)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tools.append(node)

	_say(str(story["say"]))


## The picture of what is WRONG, beside the patient. It must never be the
## picture of the answer: the first cut showed a plaster next to the hurt paw
## and an umbrella over the rained-on teddy, so the child matched pictures
## instead of thinking about what a hurt paw needs. Each of these is a problem,
## drawn with an icon the library already has.
func _trouble_icon(trouble: String) -> String:
	match trouble:
		"hurt":
			return "warning"          # "ouch!" -- the fix is the plaster
		"thirsty":
			return "watering_can"     # dry, wants water -- the fix is the potion
		"cold":
			return "scarf"            # shivering -- the fix is the blanket
		"hungry":
			return "berries"          # empty tummy -- the fix is the carrot
		"rain":
			return "cloud"            # weather -- the fix is the umbrella
		"lost":
			return "magnifier"        # looking for the way -- the fix is the compass
		_:
			return "moon"             # dark -- the fix is the spark


## The face over their head: worried, then delighted. Two circles and a curve,
## which is all a face needs to be to be read across a room.
func _paint_face(happy: bool) -> void:
	for child in _face.get_children():
		child.queue_free()
	Shapes.fill(_face, Shapes.circle_points(Vector2.ZERO, 44.0, 24),
		Color(0.99, 0.98, 0.94, 0.96), 0.0)
	for eye in [-15.0, 15.0]:
		Shapes.fill(_face, Shapes.circle_points(Vector2(eye, -8.0), 6.0, 12),
			Color(0.12, 0.15, 0.24), 0.0)
	var mouth := PackedVector2Array()
	for i in range(11):
		var t: float = float(i) / 10.0
		var x: float = lerpf(-18.0, 18.0, t)
		var y: float = 14.0 + (8.0 if happy else -8.0) * sin(PI * t)
		mouth.append(Vector2(x, y))
	var line := Line2D.new()
	line.points = mouth
	line.width = 5.0
	line.default_color = Color(0.12, 0.15, 0.24)
	line.antialiased = true
	_face.add_child(line)
	if happy:
		Shapes.glow(_face, Vector2.ZERO, 120.0, Color(1.0, 0.90, 0.50), 4, 0.4)


# --- choosing --------------------------------------------------------------------

func _on_tap(event: InputEvent) -> void:
	if _finished_level or _busy or not UiKit.is_press(event):
		return
	var at: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	for node in _tools:
		if not is_instance_valid(node) or node.position.distance_to(at) > 92.0:
			continue
		_use(node)
		return


func _use(node: Node2D) -> void:
	var story: Dictionary = _cases[_at]
	var chosen := str(node.get_meta("tool"))
	_busy = true
	# The tool always FLIES OVER and gets tried. Even the wrong one: seeing
	# the umbrella not help a hungry rabbit is how a child learns what hungry
	# means, and it is far kinder than a buzzer.
	var fly := node.create_tween()
	fly.tween_property(node, "position", _patient.position + Vector2(0, 40.0), 0.34)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fly.tween_callback(func(): _resolve(node, chosen == str(story["tool"])))


func _resolve(node: Node2D, right: bool) -> void:
	if right:
		if _hints.level() == 0:
			_thanked += 1
		score_correct()
		_hints.progress()
		_paint_face(true)
		Juice.pop(_patient, 0.4)
		Juice.burst(_field, _patient.position, 30)
		Juice.shockwave(_field, _patient.position, 200.0, Color(1.0, 0.90, 0.55))
		AudioManager.play_sfx("res://assets/audio/found.ogg")
		_say("rescue.thanks")
		if is_instance_valid(node):
			node.queue_free()
		_at += 1
		get_tree().create_timer(1.5).timeout.connect(func():
			if not _finished_level:
				_next_case())
		return
	# Wrong: it does not work, and the tool goes back to the row. Nobody is
	# told off and nothing is taken away.
	_slips += 1
	score_mistake()
	_hints.missed()
	Juice.nudge(_patient)
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
	_say("rescue.not_that")
	if is_instance_valid(node):
		var back := node.create_tween()
		back.tween_property(node, "position",
			node.get_meta("home", node.position), 0.34)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		back.tween_callback(func(): _busy = false)
	else:
		_busy = false


# --- the screen ------------------------------------------------------------------

func _build_hud() -> void:
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

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_caption)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(240, 34)
	_caption.size = Vector2(800, 50)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_caption)


func _say(key: String) -> void:
	if _caption != null and is_instance_valid(_caption):
		_caption.text = I18n.t(key)


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(_patient.position, _patient.position, 1.0)
	if not _tools.is_empty():
		demo.add_step((_tools[0] as Node2D).position,
			(_tools[0] as Node2D).position, 1.0)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	demo.finished.connect(func(): _field.mouse_filter = Control.MOUSE_FILTER_STOP)
	demo.play()


# --- the three levels of help ---------------------------------------------------

func _right_tool() -> Node2D:
	if _at >= _cases.size():
		return null
	var want := str((_cases[_at] as Dictionary)["tool"])
	for node in _tools:
		if is_instance_valid(node) and str(node.get_meta("tool")) == want:
			return node
	return null


func _glow_tool() -> void:
	var node := _right_tool()
	if node == null:
		return
	Juice.pop(node, 0.3)
	Shapes.glow(node, Vector2.ZERO, 180.0, Color(1.0, 0.94, 0.55), 4, 0.45)


func _show_the_tap() -> void:
	var node := _right_tool()
	if node == null:
		return
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step(node.position, node.position, 1.0)
	demo.play()


## Three: the wrong tools quietly step aside, leaving only the right one for
## the child to pick. They still make the choice.
func _use_it_for_them() -> void:
	var keep := _right_tool()
	for node in _tools:
		if node == keep or not is_instance_valid(node):
			continue
		if Juice.motion_enabled():
			var t := (node as Node2D).create_tween()
			t.tween_property(node, "modulate:a", 0.18, 0.4)
		else:
			(node as Node2D).modulate.a = 0.18
	_glow_tool()


func _finish() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	result.reached_goal = true
	# Star two: everybody helped correctly the first time you tried.
	result.found_hidden = _thanked >= _cases.size()
	result.clean_run = _slips == 0 and not _helped
	# Feeds the streak that decides whether the next level offers
	# a child one more thing to find. Only ever buys them more game.
	Hints.record_run(_helped)
	_say("rescue.all_safe")
	Juice.burst(_field, Fit.at(_field, Vector2(640, 340)), 44)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(1.4).timeout
	complete_level()
