extends Control
## The little lesson at the end of a world.
##
## The thing cartoons for this age do at the end of an episode: stop the
## story, look at the camera, and say one small useful thing. Bluey does it,
## Ultraman does it, and they do it because a five-minute story is when a
## six-year-old is most willing to be told something.
##
## Rules it follows, all of them the same rules as the levels:
##
##   * ONE idea per lesson. Not three tips, one thing
##   * three beats: what happens → what you do → why that is good
##   * pictures carry it; the sentence underneath is short enough that a
##     child who cannot read still gets the whole lesson from the drawing
##   * it plays itself. Nothing to press, no way to get it wrong, and a
##     "watch it again" button for the child who wants to
##   * it is SKIPPABLE, because a lesson you cannot leave is a lecture
##
## The five lessons are aimed at a child about to start school, because that
## is the child playing this: putting things back, crossing roads, looking
## before you decide, asking for something to be said again, and noticing
## when somebody needs help.

signal finished()

const Fit := preload("res://scripts/shared/screen_fit.gd")

const BEAT := 4.6                 # seconds per picture, read-aloud pace

## world id -> the one thing that world is about.
##
## Each beat is a drawing name plus a line. The drawing does the work; the
## line is what a parent would say over the top of it.
const LESSONS := {
	"sunny_park": {
		"title": "lesson.park.title",
		"beats": [
			{"draw": "mess", "say": "lesson.park.1"},
			{"draw": "tidy", "say": "lesson.park.2"},
			{"draw": "found", "say": "lesson.park.3"},
		],
	},
	"night_city": {
		"title": "lesson.city.title",
		"beats": [
			{"draw": "red_light", "say": "lesson.city.1"},
			{"draw": "hold_hand", "say": "lesson.city.2"},
			{"draw": "green_light", "say": "lesson.city.3"},
		],
	},
	"monster_valley": {
		"title": "lesson.valley.title",
		"beats": [
			{"draw": "startled", "say": "lesson.valley.1"},
			{"draw": "look", "say": "lesson.valley.2"},
			{"draw": "calm", "say": "lesson.valley.3"},
		],
	},
	"sky_base": {
		"title": "lesson.sky.title",
		"beats": [
			{"draw": "muddle", "say": "lesson.sky.1"},
			{"draw": "ask", "say": "lesson.sky.2"},
			{"draw": "got_it", "say": "lesson.sky.3"},
		],
	},
	"dark_castle": {
		"title": "lesson.castle.title",
		"beats": [
			{"draw": "someone_sad", "say": "lesson.castle.1"},
			{"draw": "offer", "say": "lesson.castle.2"},
			{"draw": "together", "say": "lesson.castle.3"},
		],
	},
}

var _world := "sunny_park"
var _stage: Control
var _caption: Label
var _dots: HBoxContainer
var _beat := 0
var _playing := false


## Which lesson. Called before the scene is added, or it reads the world the
## child was last in.
func set_world(world_id: String) -> void:
	_world = world_id if LESSONS.has(world_id) else "sunny_park"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	if not LESSONS.has(_world):
		_world = str(GameManager.current_world_id)
		if not LESSONS.has(_world):
			_world = "sunny_park"
	_build()
	_play()


func _build() -> void:
	# A quiet backdrop: this is not a level, and it should not look like one.
	#
	# It used to get quiet twice over -- the stage's own `calm` lays a white
	# wash on top, and then this laid a blue-black veil on top of THAT. Two
	# veils pulling opposite ways landed all five worlds on the same grey-blue
	# and you could not tell the valley lesson from the castle lesson. So:
	# no white wash, and one veil that is the world's OWN sky taken down
	# almost to black. The park stays green under it, the castle stays purple,
	# the caption still reads white against every one of them.
	UiKit.world_background(self, _world, "lesson", 0.0)
	var veil := ColorRect.new()
	var style: WorldStyle = WorldStyle.for_world(_world)
	# Light enough that the park still looks sunny. The caption does not need
	# the veil to be readable -- UiKit.on_art() gives it its own outline, the
	# same one every label over scenery in this game uses. The veil is here to
	# change the mood, not to rescue the text.
	veil.color = Color(style.sky_top.darkened(0.70), 0.42)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var lesson: Dictionary = LESSONS[_world]
	var title := UiKit.title_on_art(I18n.t(str(lesson["title"])), 48)
	title.position = Vector2(240, 40)
	title.size = Vector2(800, 60)
	add_child(title)

	_stage = Control.new()
	# Centred in whatever room is left between the title and the caption, so a
	# tablet's extra height is shared out instead of all landing in one gap. The
	# second term is zero on a 1280x720 screen, where this stays at 110.
	_stage.position = Vector2(0, 110.0 + (Fit.bottom(self, 520.0) - 520.0) * 0.5)
	_stage.size = Vector2(1280, 380)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 40)
	_caption.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_caption)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Caption, dots and the two buttons all sit in the lower band of the page,
	# so they are measured from the BOTTOM of it. On a 4:3 tablet the page is
	# 1280x960 and design numbers leave all three stranded two thirds of the way
	# down with a third of the screen empty beneath them.
	_caption.position = Vector2(180, Fit.bottom(self, 520))
	_caption.size = Vector2(920, 110)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

	# Three dots: how much lesson is left, without a bar or a number.
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 18)
	_dots.position = Vector2(596, Fit.bottom(self, 646))
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dots)
	for i in range(3):
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.pivot_offset = Vector2(13, 13)
		var art := Node2D.new()
		dot.add_child(art)
		Shapes.fill(art, Shapes.circle_points(Vector2(13, 13), 11.0, 18),
			Color(0.92, 0.96, 1.0), 0.0)
		dot.modulate.a = 0.28
		_dots.add_child(dot)

	# Skip. Small, in the corner, always there: a lesson you cannot leave is
	# a lecture, and a child who has heard it four times has heard it.
	var skip := UiKit.big_button(I18n.t("lesson.skip"), Palette.SLATE)
	skip.custom_minimum_size = Vector2(180, 84)
	skip.position = Vector2(1064, 24)
	skip.pressed.connect(_leave)
	add_child(skip)


# --- playing it -----------------------------------------------------------------

func _play() -> void:
	if _playing:
		return
	_playing = true
	_beat = 0
	_show_beat()


func _show_beat() -> void:
	var lesson: Dictionary = LESSONS[_world]
	var beats: Array = lesson["beats"]
	if _beat >= beats.size():
		_finish()
		return
	var beat: Dictionary = beats[_beat]

	for child in _stage.get_children():
		child.queue_free()
	var art := Node2D.new()
	art.position = Vector2(640, 190)
	_stage.add_child(art)
	_draw_scene(art, str(beat["draw"]))
	var line: String = str(beat["say"])
	_caption.text = I18n.t(line)
	# Said aloud, if somebody has recorded it. A six-year-old three weeks into
	# 一年级 cannot read this caption yet, so a silent lesson teaches him only
	# what the drawing manages on its own. The string key IS the filename --
	# "lesson.park.1" looks for lesson_park_1 -- so recording the file is the
	# whole of the wiring. No file, no sound, no error.
	AudioManager.say(line.replace(".", "_"))

	for i in range(_dots.get_child_count()):
		var dot: Control = _dots.get_child(i)
		dot.modulate.a = 1.0 if i <= _beat else 0.28
		if i == _beat:
			Juice.pop(dot, 0.3)

	if Juice.motion_enabled():
		art.scale = Vector2(0.86, 0.86)
		art.modulate.a = 0.0
		var t := art.create_tween().set_parallel(true)
		t.tween_property(art, "scale", Vector2.ONE, 0.42)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(art, "modulate:a", 1.0, 0.3)
		_caption.modulate.a = 0.0
		var c := _caption.create_tween()
		c.tween_interval(0.25)
		c.tween_property(_caption, "modulate:a", 1.0, 0.35)
	AudioManager.play_sfx("res://assets/audio/pop.ogg")

	_beat += 1
	var wait := get_tree().create_timer(BEAT)
	wait.timeout.connect(func():
		if is_instance_valid(self) and _playing:
			_show_beat())


func _finish() -> void:
	_playing = false
	_caption.text = I18n.t("lesson.remember")
	AudioManager.say("lesson_remember")
	for child in _stage.get_children():
		child.queue_free()
	var art := Node2D.new()
	art.position = Vector2(640, 190)
	_stage.add_child(art)
	_draw_scene(art, "star")
	Juice.burst(self, Vector2(640, 300), 40)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.position = Vector2(340, Fit.bottom(self, 630))
	row.size = Vector2(600, 110)
	add_child(row)
	var again := UiKit.big_button(I18n.t("lesson.again"), Palette.BLUE)
	again.custom_minimum_size = Vector2(240, 96)
	again.pressed.connect(func():
		row.queue_free()
		_play())
	row.add_child(again)
	var done := UiKit.big_button(I18n.t("lesson.done"), Palette.GREEN)
	done.custom_minimum_size = Vector2(240, 96)
	done.pressed.connect(_leave)
	row.add_child(done)
	UiKit.breathe(done, 0.035, 0.9)


func _leave() -> void:
	_playing = false
	finished.emit()
	SceneManager.goto_world_map()


# --- the pictures ------------------------------------------------------------------
#
# Drawn here rather than pulled from the icon library, because a lesson needs
# a SITUATION -- a child beside a mess, a hand being held -- and the library
# holds objects. Same `Shapes` calls as everything else, so it is the same
# world the child has been playing in.

func _draw_scene(at: Node2D, which: String) -> void:
	match which:
		"mess":
			_child_figure(at, Vector2(-190, 40), false)
			for spot in [Vector2(60, 90), Vector2(180, 50), Vector2(280, 96),
					Vector2(140, 120), Vector2(320, 40)]:
				_toy(at, spot)
		"tidy":
			_child_figure(at, Vector2(-190, 40), true)
			_crate(at, Vector2(190, 70))
			for i in range(3):
				_toy(at, Vector2(150.0 + float(i) * 40.0, 10.0 - float(i) * 34.0))
		"found":
			_child_figure(at, Vector2(-120, 40), true)
			_crate(at, Vector2(150, 70))
			Shapes.glow(at, Vector2(150, -10), 190.0, Color(1.0, 0.90, 0.50), 5, 0.45)
			_toy(at, Vector2(150, -10))
		"red_light":
			_traffic(at, Vector2(210, -20), 0)
			_child_figure(at, Vector2(-190, 40), false)
			_stop_hand(at, Vector2(-40, -20))
		"hold_hand":
			_grown_up(at, Vector2(-30, 30))
			_child_figure(at, Vector2(-190, 40), true)
			_link(at, Vector2(-140, 10), Vector2(-70, 4))
		"green_light":
			_traffic(at, Vector2(210, -20), 1)
			_grown_up(at, Vector2(30, 30))
			_child_figure(at, Vector2(-110, 40), true)
			_link(at, Vector2(-62, 10), Vector2(-8, 4))
		"startled":
			_child_figure(at, Vector2(-160, 40), false)
			_bush(at, Vector2(180, 60))
			_question(at, Vector2(-120, -110))
		"look":
			_child_figure(at, Vector2(-160, 40), true)
			_bush(at, Vector2(180, 60))
			_eye_beam(at, Vector2(-110, -30), Vector2(120, 10))
		"calm":
			_child_figure(at, Vector2(-120, 40), true)
			_critter(at, Vector2(150, 60))
			Shapes.glow(at, Vector2(150, 20), 150.0, Color(0.66, 0.94, 0.72), 4, 0.4)
		"muddle":
			_grown_up(at, Vector2(180, 30))
			_child_figure(at, Vector2(-170, 40), false)
			_question(at, Vector2(-130, -110))
		"ask":
			_grown_up(at, Vector2(180, 30))
			_child_figure(at, Vector2(-170, 40), true)
			_speech(at, Vector2(-90, -110))
		"got_it":
			_grown_up(at, Vector2(180, 30))
			_child_figure(at, Vector2(-170, 40), true)
			Shapes.glow(at, Vector2(-130, -110), 150.0, Color(1.0, 0.92, 0.52), 4, 0.5)
			Shapes.fill(at, Shapes.star_points(Vector2(-130, -110), 34.0, 0.45, 5),
				Color(1.0, 0.88, 0.42), 0.0)
		"someone_sad":
			_child_figure(at, Vector2(-190, 40), true)
			_critter(at, Vector2(170, 70), false)
		"offer":
			_child_figure(at, Vector2(-120, 40), true)
			_critter(at, Vector2(150, 70), false)
			_speech(at, Vector2(-60, -110))
		"together":
			_child_figure(at, Vector2(-120, 40), true)
			_critter(at, Vector2(120, 60), true)
			Shapes.glow(at, Vector2(0, -20), 230.0, Color(1.0, 0.82, 0.62), 5, 0.42)
			_heart(at, Vector2(0, -130))
		_:
			Shapes.glow(at, Vector2.ZERO, 260.0, Color(1.0, 0.92, 0.52), 6, 0.5)
			Shapes.fill(at, Shapes.star_points(Vector2.ZERO, 96.0, 0.45, 5),
				Color(1.0, 0.88, 0.42), 0.0)


func _child_figure(at: Node2D, where: Vector2, happy: bool) -> void:
	var body := Node2D.new()
	body.position = where
	at.add_child(body)
	Shapes.ground_shadow(body, Vector2(0, 96.0), 130.0, 0.20)
	Shapes.lit(body, Shapes.rounded_rect(Vector2(-40, -20), Vector2(80, 116), 26.0),
		Color(0.42, 0.66, 0.94), 1.0)
	Shapes.lit(body, Shapes.circle_points(Vector2(0, -62.0), 46.0, 24),
		Color(0.99, 0.86, 0.72), 1.0)
	for eye in [-16.0, 16.0]:
		Shapes.fill(body, Shapes.circle_points(Vector2(eye, -70.0), 6.0, 12),
			Color(0.14, 0.17, 0.26), 0.0)
	var mouth := PackedVector2Array()
	for i in range(11):
		var t: float = float(i) / 10.0
		mouth.append(Vector2(lerpf(-18.0, 18.0, t),
			-44.0 + (9.0 if happy else -6.0) * sin(PI * t)))
	var line := Line2D.new()
	line.points = mouth
	line.width = 5.0
	line.default_color = Color(0.14, 0.17, 0.26)
	line.antialiased = true
	body.add_child(line)


func _grown_up(at: Node2D, where: Vector2) -> void:
	var body := Node2D.new()
	body.position = where
	at.add_child(body)
	Shapes.ground_shadow(body, Vector2(0, 108.0), 150.0, 0.20)
	Shapes.lit(body, Shapes.rounded_rect(Vector2(-48, -46), Vector2(96, 154), 30.0),
		Color(0.86, 0.52, 0.56), 1.0)
	Shapes.lit(body, Shapes.circle_points(Vector2(0, -92.0), 52.0, 24),
		Color(0.98, 0.84, 0.70), 1.0)
	for eye in [-18.0, 18.0]:
		Shapes.fill(body, Shapes.circle_points(Vector2(eye, -100.0), 6.0, 12),
			Color(0.14, 0.17, 0.26), 0.0)
	var mouth := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(11):
		var t: float = float(i) / 10.0
		pts.append(Vector2(lerpf(-20.0, 20.0, t), -72.0 + 9.0 * sin(PI * t)))
	mouth.points = pts
	mouth.width = 5.0
	mouth.default_color = Color(0.14, 0.17, 0.26)
	mouth.antialiased = true
	body.add_child(mouth)


func _link(at: Node2D, from: Vector2, to: Vector2) -> void:
	Shapes.fill(at, Shapes.taper(from, to, 12.0, 12.0), Color(0.99, 0.86, 0.72), 0.0)
	Shapes.glow(at, (from + to) * 0.5, 90.0, Color(1.0, 0.88, 0.60), 3, 0.4)


func _toy(at: Node2D, where: Vector2) -> void:
	Shapes.lit(at, Shapes.circle_points(where, 26.0, 18), Color(0.96, 0.62, 0.36), 0.9)
	Shapes.fill(at, Shapes.rounded_rect(where - Vector2(20, 4), Vector2(40, 8), 4.0),
		Color(1, 1, 1, 0.6), 0.0)


func _crate(at: Node2D, where: Vector2) -> void:
	var node := Node2D.new()
	node.position = where
	at.add_child(node)
	Shapes.ground_shadow(node, Vector2.ZERO, 190.0, 0.20)
	Shapes.lit(node, PackedVector2Array([
		Vector2(-86, -96), Vector2(86, -96), Vector2(70, 0), Vector2(-70, 0),
	]), Color(0.45, 0.72, 0.92), 1.0)
	Shapes.fill(node, PackedVector2Array([
		Vector2(-86, -96), Vector2(86, -96), Vector2(72, -74), Vector2(-72, -74),
	]), Color(0.30, 0.54, 0.76), 0.0)


func _traffic(at: Node2D, where: Vector2, lit_lamp: int) -> void:
	var node := Node2D.new()
	node.position = where
	at.add_child(node)
	Shapes.fill(node, Shapes.taper(Vector2(0, 150.0), Vector2(0, 20.0), 12.0, 9.0),
		Color(0.42, 0.46, 0.56), 0.0)
	Shapes.lit(node, Shapes.rounded_rect(Vector2(-42, -120), Vector2(84, 150), 18.0),
		Color(0.28, 0.32, 0.42), 1.0)
	var lamps := [Color(0.94, 0.32, 0.30), Color(0.40, 0.84, 0.48)]
	for i in range(2):
		var y: float = -84.0 + float(i) * 66.0
		var on: bool = i == lit_lamp
		if on:
			Shapes.glow(node, Vector2(0, y), 130.0, lamps[i], 4, 0.5)
		Shapes.fill(node, Shapes.circle_points(Vector2(0, y), 24.0, 18),
			lamps[i] if on else lamps[i].darkened(0.62), 0.0)


func _stop_hand(at: Node2D, where: Vector2) -> void:
	Shapes.glow(at, where, 130.0, Color(0.96, 0.44, 0.38), 4, 0.4)
	Shapes.lit(at, Shapes.rounded_rect(where - Vector2(34, 40), Vector2(68, 80), 22.0),
		Color(0.99, 0.86, 0.72), 1.0)


func _bush(at: Node2D, where: Vector2) -> void:
	for spot in [Vector2(-46, 0), Vector2(0, -26), Vector2(46, 0)]:
		Shapes.lit(at, Shapes.circle_points(where + spot, 52.0, 20),
			Color(0.40, 0.68, 0.44), 0.9)


func _critter(at: Node2D, where: Vector2, happy: bool = true) -> void:
	var node := Node2D.new()
	node.position = where
	at.add_child(node)
	Shapes.ground_shadow(node, Vector2(0, 40.0), 110.0, 0.18)
	Shapes.lit(node, Shapes.oval_points(Vector2.ZERO, Vector2(48.0, 42.0), 22),
		Color(0.98, 0.84, 0.52), 1.0)
	for ear in [-26.0, 26.0]:
		Shapes.lit(node, Shapes.oval_points(Vector2(ear, -38.0), Vector2(14.0, 26.0), 14),
			Color(0.98, 0.84, 0.52), 0.9)
	for eye in [-16.0, 16.0]:
		Shapes.fill(node, Shapes.circle_points(Vector2(eye, -6.0), 7.0, 12),
			Color(0.16, 0.19, 0.28), 0.0)
	var mouth := Line2D.new()
	var pts := PackedVector2Array()
	for i in range(9):
		var t: float = float(i) / 8.0
		pts.append(Vector2(lerpf(-14.0, 14.0, t),
			14.0 + (7.0 if happy else -6.0) * sin(PI * t)))
	mouth.points = pts
	mouth.width = 4.0
	mouth.default_color = Color(0.16, 0.19, 0.28)
	mouth.antialiased = true
	node.add_child(mouth)


func _question(at: Node2D, where: Vector2) -> void:
	Shapes.glow(at, where, 120.0, Color(0.62, 0.82, 1.0), 4, 0.4)
	Shapes.fill(at, Shapes.circle_points(where, 44.0, 20), Color(0.98, 0.99, 1.0), 0.0)
	var mark := Label.new()
	mark.text = "?"
	mark.add_theme_font_size_override("font_size", 56)
	mark.add_theme_color_override("font_color", Color(0.24, 0.40, 0.68))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.position = where + Vector2(-44, -42)
	mark.size = Vector2(88, 80)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	at.add_child(mark)


func _speech(at: Node2D, where: Vector2) -> void:
	Shapes.fill(at, Shapes.rounded_rect(where - Vector2(70, 42),
		Vector2(140, 84), 26.0), Color(0.98, 0.99, 1.0), 0.0)
	Shapes.fill(at, PackedVector2Array([
		where + Vector2(-18, 38), where + Vector2(6, 38), where + Vector2(-4, 66),
	]), Color(0.98, 0.99, 1.0), 0.0)
	for i in range(3):
		Shapes.fill(at, Shapes.circle_points(
			where + Vector2(-32.0 + float(i) * 32.0, 0.0), 9.0, 12),
			Color(0.42, 0.56, 0.80), 0.0)


func _eye_beam(at: Node2D, from: Vector2, to: Vector2) -> void:
	Shapes.fill(at, Shapes.taper(from, to, 16.0, 46.0),
		Color(1.0, 0.94, 0.60, 0.34), 0.0)
	Shapes.glow(at, to, 150.0, Color(1.0, 0.94, 0.60), 4, 0.34)


func _heart(at: Node2D, where: Vector2) -> void:
	Shapes.glow(at, where, 130.0, Color(0.98, 0.50, 0.56), 4, 0.45)
	var pts := PackedVector2Array()
	for i in range(25):
		var t: float = TAU * float(i) / 24.0
		pts.append(where + Vector2(
			16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		) * 2.4)
	Shapes.lit(at, pts, Color(0.96, 0.44, 0.52), 0.9)
