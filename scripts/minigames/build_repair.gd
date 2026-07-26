extends LevelManager
## "Build the thing, then watch it work." The most satisfying template here.
##
## A child drags parts into outlined slots and the machine grows under their
## hands. The brief is specific about two things and both are the whole point:
##
##   * every step gets its own animation, light and sound -- not a progress
##     bar, an EVENT
##   * when it is finished the thing has to actually RUN. A bridge you can
##     walk across, a tower whose light comes on, a robot that stands up and
##     waves. "Success!" on a card is what a spreadsheet says.
##
## The parts are drawn from the level's data, the slots are outlines of
## exactly the part that belongs there, and the drag comes from `DragField`,
## so it feels the same as the sorting levels a child played an hour ago.

const Field := preload("res://scripts/shared/drag_field.gd")
const Hints := preload("res://scripts/shared/hint_director.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Picker := preload("res://scripts/shared/variant_picker.gd")

var _field: Field
var _hud: Control
var _hints: Hints
var _picker: Picker
var _machine: Node2D               # everything that is being built
var _kind := "bridge"
var _parts: Array = []             # [{item, spec}]
var _slot_nodes: Array = []
var _placed := 0
var _wanted := 4
var _slips := 0
var _helped := false
var _golden_used := false
var _tally: Label
var _finished_level := false

## The shapes each machine is made of: where the slots sit, and what a part
## that belongs there looks like. Hand-placed, because "generate a bridge"
## produces bridges nobody wants to cross.
const BLUEPRINTS := {
	"bridge": {
		"anchor": Vector2(640, 470),
		"slots": [Vector2(-210, 0), Vector2(-70, 0), Vector2(70, 0), Vector2(210, 0)],
		"part": "plank", "runs": "cross",
	},
	"tower": {
		"anchor": Vector2(640, 560),
		"slots": [Vector2(0, 0), Vector2(0, -110), Vector2(0, -220), Vector2(0, -320)],
		"part": "block", "runs": "light",
	},
	"robot": {
		"anchor": Vector2(640, 470),
		"slots": [Vector2(0, -110), Vector2(0, 0), Vector2(-120, -30),
			Vector2(120, -30), Vector2(0, 120)],
		"part": "limb", "runs": "wave",
	},
	"ship": {
		"anchor": Vector2(640, 420),
		"slots": [Vector2(-160, 0), Vector2(0, 0), Vector2(160, 0), Vector2(0, -110)],
		"part": "hull", "runs": "fly",
	},
}


func auto_complete_on_target() -> bool:
	return false


func setup_level() -> void:
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_picker = Picker.for_level(str(level_data.get("id", "")))
	_kind = str(config.get("machine", "bridge"))
	if not BLUEPRINTS.has(_kind):
		_kind = "bridge"

	build_world(self, 0.35)
	_field = Field.new()
	add_child(_field)
	_field.dropped.connect(_on_dropped)

	_machine = Node2D.new()
	_field.add_child(_machine)
	_build_machine(config)
	_build_hud()

	_hints = Hints.new()
	add_child(_hints)
	_hints.watch(_glow_next_slot, _show_the_drag, _do_it_for_them)
	_hints.escalated.connect(func(_level: int): _helped = true)
	_play_tutorial()


# --- the machine ----------------------------------------------------------------

func _build_machine(config: Dictionary) -> void:
	var plan: Dictionary = BLUEPRINTS[_kind]
	var anchor: Vector2 = plan["anchor"]
	var places: Array = plan["slots"]
	_wanted = places.size()

	# Who we are building it FOR. A machine with nobody waiting is homework.
	var who := str(config.get("waiting_for", "paw"))
	var friend := Node2D.new()
	friend.position = anchor + Vector2(430, -40)
	_field.add_child(friend)
	var art: Control = UiKit.picture(who, 92)
	if art != null:
		art.position = Vector2(-46, -46)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		friend.add_child(art)
	Juice.idle_bob(friend, 10.0, 1.3)
	_machine.set_meta("friend", friend)

	# The slots: dashed outlines of exactly the part that goes in them.
	for i in range(places.size()):
		var at: Vector2 = anchor + (places[i] as Vector2)
		var ghost := Node2D.new()
		_field.add_child(ghost)
		_draw_part(ghost, str(plan["part"]), true)
		var slot := _field.add_slot(ghost, at, "part", 1)
		slot["index"] = i
		_slot_nodes.append(ghost)

	# The parts, scattered along the bottom, plus decoys that fit nowhere.
	var spread := 1080.0
	var count: int = _wanted + 2
	var order: Array = []
	for i in range(_wanted):
		order.append("part")
	order.append("junk")
	order.append("junk")
	_picker.shuffle(order)
	for i in range(count):
		var x: float = 640.0 + (float(i) - float(count - 1) * 0.5) * (spread / float(count))
		var node := Node2D.new()
		_field.add_child(node)
		var golden: bool = str(order[i]) == "part" and i == _picker.whole(0, count - 1)
		_draw_part(node, str(plan["part"]) if str(order[i]) == "part" else "junk",
			false, golden)
		var item := _field.add_item(node, Vector2(x, 660.0),
			"part" if str(order[i]) == "part" else "junk")
		item["golden"] = golden
		_parts.append(item)


## One drawing routine for ghosts, real parts and junk, so a slot and the
## thing that fills it are unmistakably the same shape.
func _draw_part(node: Node2D, kind: String, ghost: bool, golden: bool = false) -> void:
	var tint := Color(0.62, 0.44, 0.28)
	match kind:
		"block":
			tint = Color(0.56, 0.60, 0.72)
		"limb":
			tint = Color(0.52, 0.68, 0.88)
		"hull":
			tint = Color(0.72, 0.76, 0.86)
		"junk":
			tint = Color(0.48, 0.46, 0.44)
	if golden:
		tint = Color(1.0, 0.82, 0.34)
	var body := PackedVector2Array()
	match kind:
		"plank", "junk":
			body = Shapes.rounded_rect(Vector2(-64, -20), Vector2(128, 40), 9.0)
		"block":
			body = Shapes.rounded_rect(Vector2(-58, -52), Vector2(116, 104), 14.0)
		"limb":
			body = Shapes.rounded_rect(Vector2(-46, -46), Vector2(92, 92), 22.0)
		_:
			body = Shapes.rounded_rect(Vector2(-70, -34), Vector2(140, 68), 26.0)
	if ghost:
		# A dashed outline, not a faded copy: a faded copy reads as "already
		# done" and a child skips it.
		var line := Line2D.new()
		line.points = body
		line.closed = true
		line.width = 5.0
		line.default_color = Color(1.0, 0.95, 0.70, 0.75)
		line.antialiased = true
		node.add_child(line)
		Shapes.fill(node, body, Color(0.06, 0.12, 0.24, 0.22), 0.0)
		return
	if golden:
		Shapes.glow(node, Vector2.ZERO, 130.0, Color(1.0, 0.86, 0.40), 5, 0.42)
	Shapes.lit(node, body, tint, 1.0)
	if kind == "junk":
		# Junk is visibly broken -- cracked and crooked, so "this one is
		# wrong" is a thing you can see rather than a thing you find out.
		Shapes.fill(node, Shapes.taper(Vector2(-40, -16), Vector2(30, 18), 5.0, 2.0),
			Color(0.28, 0.26, 0.25), 0.0)
		node.rotation_degrees = 8.0
	else:
		Shapes.fill(node, Shapes.rounded_rect(Vector2(-40, -8), Vector2(80, 6), 3.0),
			tint.lightened(0.22), 0.0)


func _on_dropped(item: Dictionary, slot: Dictionary, correct: bool) -> void:
	if _finished_level:
		return
	if not correct:
		_slips += 1
		score_mistake()
		_hints.missed()
		return
	_placed += 1
	score_correct()
	_hints.progress()
	if bool(item.get("golden", false)):
		_golden_used = true
	_celebrate_step(slot)
	_refresh_tally()
	if _placed >= _wanted:
		_run_the_machine()


## Every step is an event: the ghost fills in, a light comes on, the note goes
## up. The brief asks for this by name and it is the difference between
## building something and filling in a form.
func _celebrate_step(slot: Dictionary) -> void:
	var node: Node2D = slot["node"]
	if not is_instance_valid(node):
		return
	Juice.burst(_field, node.position, 16)
	Shapes.glow(node, Vector2.ZERO, 150.0, Color(1.0, 0.92, 0.55), 4, 0.34)
	Juice.pop(node, 0.3)
	AudioManager.play_sfx("res://assets/audio/build_step.ogg")
	# The note climbs with each part, so the machine sings itself together.
	var step: int = clampi(_placed, 1, 8)
	get_tree().create_timer(0.12).timeout.connect(func():
		AudioManager.play_sfx("res://assets/audio/notes/note_%d.ogg" % step))


# --- and then it works ------------------------------------------------------------

## The payoff. Whatever was built now does its job, on screen, before the
## result card ever appears.
func _run_the_machine() -> void:
	if _finished_level:
		return
	_finished_level = true
	_hints.pause_watching(true)
	AudioManager.play_sfx("res://assets/audio/machine.ogg")
	var plan: Dictionary = BLUEPRINTS[_kind]
	match str(plan["runs"]):
		"light":
			_run_light()
		"wave":
			_run_wave()
		"fly":
			_run_fly()
		_:
			_run_cross()
	await get_tree().create_timer(2.4).timeout
	_finish()


func _run_light() -> void:
	# The tower lights from the bottom up, one slot at a time.
	for i in range(_slot_nodes.size()):
		var node: Node2D = _slot_nodes[i]
		get_tree().create_timer(0.18 * float(i)).timeout.connect(func():
			if not is_instance_valid(node):
				return
			Shapes.glow(node, Vector2.ZERO, 190.0, Color(1.0, 0.94, 0.55), 5, 0.55)
			Juice.pop(node, 0.24))
	get_tree().create_timer(0.9).timeout.connect(func():
		AudioManager.play_sfx("res://assets/audio/power_on.ogg")
		Juice.shockwave(_field, (BLUEPRINTS[_kind]["anchor"] as Vector2)
			+ Vector2(0, -320.0), 420.0, Color(1.0, 0.94, 0.55)))


func _run_cross() -> void:
	# The friend walks across the bridge the child just built.
	var friend: Node2D = _machine.get_meta("friend")
	if not is_instance_valid(friend):
		return
	var anchor: Vector2 = BLUEPRINTS[_kind]["anchor"]
	AudioManager.play_sfx("res://assets/audio/water.ogg")
	if not Juice.motion_enabled():
		friend.position = anchor + Vector2(-330, -60)
		return
	var t := friend.create_tween()
	t.tween_property(friend, "position", anchor + Vector2(-330, -60), 1.9)\
		.set_trans(Tween.TRANS_SINE)
	# A little hop per plank, so it reads as walking rather than sliding.
	for i in range(4):
		var hop := friend.create_tween()
		hop.tween_interval(0.3 + 0.4 * float(i))
		hop.tween_callback(func():
			if is_instance_valid(friend):
				Juice.pop(friend, 0.18)
				AudioManager.play_sfx("res://assets/audio/footstep.ogg"))


func _run_wave() -> void:
	var arms: Array = []
	for i in range(_slot_nodes.size()):
		if i == 2 or i == 3:
			arms.append(_slot_nodes[i])
	AudioManager.play_sfx("res://assets/audio/power_on.ogg")
	for arm in arms:
		if not is_instance_valid(arm) or not Juice.motion_enabled():
			continue
		var t := (arm as Node2D).create_tween().set_loops(3)
		t.tween_property(arm, "rotation_degrees", -26.0, 0.28)
		t.tween_property(arm, "rotation_degrees", 12.0, 0.28)


func _run_fly() -> void:
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
	if not Juice.motion_enabled():
		return
	for node in _slot_nodes:
		if not is_instance_valid(node):
			continue
		var t := (node as Node2D).create_tween()
		t.tween_interval(0.4)
		t.tween_property(node, "position:y", (node as Node2D).position.y - 240.0, 1.6)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# --- the screen ---------------------------------------------------------------------

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

	_tally = Label.new()
	_tally.add_theme_font_size_override("font_size", 40)
	_tally.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_tally)
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally.position = Vector2(440, 28)
	_tally.size = Vector2(400, 52)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tally)
	_refresh_tally()


func _refresh_tally() -> void:
	if _tally != null and is_instance_valid(_tally):
		_tally.text = "%d / %d" % [_placed, _wanted]


func _play_tutorial() -> void:
	var demo := Tutorial.new()
	_hud.add_child(demo)
	if not _parts.is_empty() and not _slot_nodes.is_empty():
		demo.add_step((_parts[0]["node"] as Node2D).position,
			(_slot_nodes[0] as Node2D).position, 1.2)
	demo.play()


# --- the three levels of help ---------------------------------------------------

func _next_slot() -> Node2D:
	for slot in _field.slots():
		if int(slot["held"]) == 0 and is_instance_valid(slot["node"]):
			return slot["node"]
	return null


func _next_part() -> Dictionary:
	for item in _field.items():
		if not bool(item["placed"]) and str(item["key"]) == "part":
			return item
	return {}


func _glow_next_slot() -> void:
	var node := _next_slot()
	if node == null:
		return
	Juice.pop(node, 0.3)
	Shapes.glow(node, Vector2.ZERO, 170.0, Color(1.0, 0.94, 0.55), 4, 0.45)


func _show_the_drag() -> void:
	var node := _next_slot()
	var part := _next_part()
	if node == null or part.is_empty():
		return
	var demo := Tutorial.new()
	_hud.add_child(demo)
	demo.add_step((part["node"] as Node2D).position, node.position, 1.1)
	demo.play()


## The last resort, done the brief's way: the game does the hard part and
## leaves the final piece, so the child is the one who finishes the machine.
func _do_it_for_them() -> void:
	var left: Array = []
	for item in _field.items():
		if not bool(item["placed"]) and str(item["key"]) == "part":
			left.append(item)
	if left.size() <= 1:
		return                    # already down to the last one: theirs to place
	for i in range(left.size() - 1):
		_field.place_for_them(left[i])
		_placed += 1
	_refresh_tally()
	_glow_next_slot()


func _finish() -> void:
	result.reached_goal = true
	result.found_hidden = _golden_used
	result.clean_run = _slips == 0 and not _helped
	Juice.burst(_field, Vector2(640, 380), 44)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	await get_tree().create_timer(1.0).timeout
	complete_level()
