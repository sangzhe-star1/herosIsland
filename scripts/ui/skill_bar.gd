class_name SkillBar
extends Control
## The whole control layout for an adventure level, in one place.
##
##   bottom left   ◀ ▶      move
##   bottom right  jump, attack, and two skill buttons with cooldown rings
##   floating      the interact key, which only exists when there is
##                 something to interact with
##
## Why it is its own file: every adventure level has the same hands. Laying
## the pad out per level is how a child ends up with the jump button in a
## different place on level four, which at six is the same as a new game.
##
## Sizes come from the house rules (>=220x120 area) and from a real six-year-
## old's thumbs: jump is the biggest because it is pressed most, the skills
## are smallest because they are pressed least and a mis-press costs a
## cooldown rather than a life.

signal move_pressed(dir: float, down: bool)
signal jump_pressed()
signal jump_released()
signal attack_pressed()
signal skill_pressed(slot: int)
signal interact_pressed()

## Sizes. Jump stays biggest because it is pressed most; the skills came down
## from 112 to 88 and their icons from 60 to 46, because four buttons of the
## same weight in one corner read as a wall of buttons rather than as a hand.
const PAD_JUMP := 138.0
const PAD_ATTACK := 112.0
const PAD_SKILL := 88.0
const ICON_SKILL := 46.0

var _skill_buttons: Array = []      # [{button, ring, icon, ready_at, cooldown}]
var _interact: Button
var _interact_icon: Control
var _jump_button: Button
var _attack_button: Button
var _demo_hand: Control
var _stick: Stick
var _last_dir := 0.0

## By path, not by class name: a new class_name is invisible until the editor
## rescans, and that made every level in the game fail to parse once already.
const Stick := preload("res://scripts/ui/thumb_stick.gd")
## Every button below is drawn against 1280x720 and placed with Fit.corner:
## thumb chrome keeps its GAP to the corner, so on a 1280x960 tablet the pad
## sits under the thumb instead of 240 px up the screen.
const Fit := preload("res://scripts/shared/screen_fit.gd")
var _clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_move()
	_build_action()
	_build_interact()
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	for entry in _skill_buttons:
		_draw_cooldown(entry)


# --- the pad ---------------------------------------------------------------

## The left hand is a stick now, not two buttons. See `thumb_stick.gd` for
## why; the short version is that a thumb leans, it does not aim.
func _build_move() -> void:
	_stick = Stick.new()
	add_child(_stick)
	_stick.moved.connect(func(dir: float):
		# The rest of the game still speaks in "left held / right held", so
		# the stick is translated here rather than everywhere.
		if is_equal_approx(dir, _last_dir):
			return
		if _last_dir < 0.0 and dir >= 0.0:
			move_pressed.emit(-1.0, false)
		if _last_dir > 0.0 and dir <= 0.0:
			move_pressed.emit(1.0, false)
		if dir < 0.0 and _last_dir >= 0.0:
			move_pressed.emit(-1.0, true)
		if dir > 0.0 and _last_dir <= 0.0:
			move_pressed.emit(1.0, true)
		_last_dir = dir)


func _build_action() -> void:
	# Jump, bottom right corner and biggest: the verb of the genre.
	var jump := _round_button(Fit.corner(self, Vector2(1098, 540)), PAD_JUMP,
		Color(1.0, 0.86, 0.40))
	_jump_button = jump
	_jump_glyph(jump, PAD_JUMP)
	jump.button_down.connect(func():
		_ripple(jump)
		jump_pressed.emit())
	jump.button_up.connect(func(): jump_released.emit())

	# Attack, just left of jump, the second-most-pressed thing.
	var attack := _round_button(Fit.corner(self, Vector2(948, 566)), PAD_ATTACK,
		Color(0.96, 0.52, 0.42))
	_attack_button = attack
	var fist: Control = UiKit.picture("power", PAD_ATTACK * 0.52)
	if fist != null:
		fist.position = Vector2(PAD_ATTACK * 0.24, PAD_ATTACK * 0.24)
		fist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		attack.add_child(fist)
	attack.button_down.connect(func():
		_ripple(attack)
		attack_pressed.emit())


## Add a skill button. Slot 0 sits above attack, slot 1 above that -- an arc
## the thumb sweeps rather than a row it has to reach across.
func add_skill(icon_name: String, colour: Color, cooldown: float) -> void:
	var slot: int = _skill_buttons.size()
	# An arc the thumb sweeps, not a row it reaches across. Tighter now that
	# the buttons are smaller.
	# The third spot was 1200: with an 88 px button that ends at 1288, eight
	# pixels past the right edge of a 1280 screen. 1184 keeps it inside.
	var spots := [Vector2(966, 430), Vector2(1096, 380), Vector2(1184, 292)]
	var design: Vector2 = spots[slot] if slot < spots.size() \
		else Vector2(966.0 - 118.0 * float(slot), 430.0)
	var at: Vector2 = Fit.corner(self, design)
	var button := _round_button(at, PAD_SKILL, colour)
	var icon: Control = UiKit.picture(icon_name, ICON_SKILL)
	if icon != null:
		icon.position = Vector2(PAD_SKILL - ICON_SKILL, PAD_SKILL - ICON_SKILL) / 2.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		# The icon breathes while the skill is ready: a still button on a
		# screen full of moving things reads as switched off.
		if Juice.motion_enabled():
			icon.pivot_offset = Vector2(ICON_SKILL, ICON_SKILL) / 2.0
			var b := icon.create_tween().set_loops()
			b.tween_property(icon, "scale", Vector2(1.10, 1.10), 0.9)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			b.tween_property(icon, "scale", Vector2.ONE, 0.9)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# The cooldown ring: a wedge that sweeps away as the skill comes back.
	# A greyed-out button says "no"; a ring says "not yet, and this much
	# longer" -- which is the difference between a rule and a wait.
	var ring := Node2D.new()
	ring.position = Vector2(PAD_SKILL, PAD_SKILL) / 2.0
	button.add_child(ring)

	var entry := {"button": button, "ring": ring, "ready_at": 0.0,
		"cooldown": maxf(cooldown, 0.1), "colour": colour, "icon": icon,
		"was_ready": true}
	_skill_buttons.append(entry)
	button.button_down.connect(func():
		_ripple(button)
		skill_pressed.emit(slot))


## Has this skill come back yet?
func skill_ready(slot: int) -> bool:
	if slot < 0 or slot >= _skill_buttons.size():
		return false
	return _clock >= float(_skill_buttons[slot]["ready_at"])


## Start a skill's cooldown. Returns false when it was not ready, so the
## caller can answer the tap with a wobble instead of silence.
func use_skill(slot: int) -> bool:
	if not skill_ready(slot):
		if slot >= 0 and slot < _skill_buttons.size():
			Juice.nudge(_skill_buttons[slot]["button"])
		return false
	var entry: Dictionary = _skill_buttons[slot]
	entry["ready_at"] = _clock + float(entry["cooldown"])
	Juice.pop(entry["button"], 0.12)
	return true


func _draw_cooldown(entry: Dictionary) -> void:
	var ring: Node2D = entry["ring"]
	if not is_instance_valid(ring):
		return
	for child in ring.get_children():
		child.queue_free()
	var left: float = float(entry["ready_at"]) - _clock
	if left <= 0.0:
		# The moment it comes back, say so. A child watching a wedge shrink
		# has to keep watching to know when it is gone; a flash means they
		# can look at the monster instead, which is where they should be
		# looking.
		if not bool(entry["was_ready"]):
			entry["was_ready"] = true
			_ready_flash(entry)
		return
	entry["was_ready"] = false
	var fraction: float = clampf(left / float(entry["cooldown"]), 0.0, 1.0)
	var points := PackedVector2Array([Vector2.ZERO])
	var steps: int = maxi(int(fraction * 26.0), 2)
	for i in range(steps + 1):
		var a: float = -PI * 0.5 + TAU * fraction * float(i) / float(steps)
		points.append(Vector2(cos(a), sin(a)) * PAD_SKILL * 0.46)
	Shapes.fill(ring, points, Color(0.04, 0.07, 0.16, 0.62), 0.0)


# --- the interact key -------------------------------------------------------

func _build_interact() -> void:
	_interact = _round_button(Vector2(-999, -999), 116.0, Color(0.55, 0.95, 0.75))
	_interact.visible = false
	_interact_icon = UiKit.picture("tap", 62)
	if _interact_icon != null:
		_interact_icon.position = Vector2(27, 27)
		_interact_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_interact.add_child(_interact_icon)
	_interact.button_down.connect(func():
		_ripple(_interact)
		interact_pressed.emit())


## Show the interact key at a screen position, wearing the icon of whatever
## it will do. Called every frame by the level with the nearest thing, or
## with an empty icon to hide it.
func show_interact(at: Vector2, icon_name: String) -> void:
	if _interact == null or not is_instance_valid(_interact):
		return
	if icon_name == "":
		if _interact.visible:
			_interact.visible = false
		return
	if not _interact.visible:
		_interact.visible = true
		Juice.pop(_interact, 0.30)
	_interact.position = at - Vector2(58, 58)
	if _interact_icon != null and is_instance_valid(_interact_icon):
		var fresh: Control = UiKit.picture(icon_name, 62)
		if fresh != null:
			_interact_icon.queue_free()
			fresh.position = Vector2(27, 27)
			fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_interact.add_child(fresh)
			_interact_icon = fresh


## The rim lights up and a ring flies off it. Half a second, once.
func _ready_flash(entry: Dictionary) -> void:
	var button: Button = entry["button"]
	if not is_instance_valid(button) or not Juice.motion_enabled():
		return
	var burst := Node2D.new()
	burst.position = Vector2(PAD_SKILL, PAD_SKILL) / 2.0
	button.add_child(burst)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, PAD_SKILL * 0.5, 28)
	ring.closed = true
	ring.width = 6.0
	ring.default_color = entry["colour"]
	ring.antialiased = true
	burst.add_child(ring)
	var t := burst.create_tween().set_parallel(true)
	t.tween_property(burst, "scale", Vector2(1.7, 1.7), 0.42)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(burst, "modulate:a", 0.0, 0.42)
	t.chain().tween_callback(burst.queue_free)
	Juice.pop(button, 0.16)
	AudioManager.play_sfx("res://assets/audio/pop.ogg")


## A ripple out from the middle of a pressed button. Immediate visual answer
## to a press, which the brief asks for on every interactive thing.
func _ripple(button: Button) -> void:
	if not is_instance_valid(button) or not Juice.motion_enabled():
		return
	var size: float = button.custom_minimum_size.x
	var wave := Node2D.new()
	wave.position = Vector2(size, size) / 2.0
	button.add_child(wave)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, size * 0.28, 24)
	ring.closed = true
	ring.width = 5.0
	ring.default_color = Color(1, 1, 1, 0.75)
	ring.antialiased = true
	wave.add_child(ring)
	var t := wave.create_tween().set_parallel(true)
	t.tween_property(wave, "scale", Vector2(2.1, 2.1), 0.34)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(wave, "modulate:a", 0.0, 0.34)
	t.chain().tween_callback(wave.queue_free)


# --- showing a stuck child which button ---------------------------------------

## A translucent finger that taps a button, over and over, until told to stop.
##
## The spec asks for this by name for a child who has lost twice. Pointing at
## the THING in the world is only half an answer -- "get past that gate" is
## useless to someone who has not worked out that the round yellow circle is
## how you jump. This points at the hand, not the world.
##
## `which` is "jump", "attack", "left", "right" or a skill slot as "skill0".
func demo(which: String) -> void:
	stop_demo()
	var target: Button = _demo_target(which)
	if target == null:
		return
	var hand := Control.new()
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.position = target.position + target.custom_minimum_size * 0.55
	hand.name = "ButtonDemo"
	add_child(hand)
	var art := UiKit.guide_hand(92.0)
	if art != null:
		hand.add_child(art)
	_demo_hand = hand

	# The button itself pulses in time with the tap, so the two read as one
	# action rather than as a finger floating near a coincidence.
	if not Juice.motion_enabled():
		return
	var t := hand.create_tween().set_loops()
	t.tween_property(hand, "position:y", hand.position.y - 34.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(hand, "position:y", hand.position.y, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		if is_instance_valid(target):
			Juice.pop(target, 0.16))
	t.tween_interval(0.7)


func stop_demo() -> void:
	if _demo_hand != null and is_instance_valid(_demo_hand):
		_demo_hand.queue_free()
	_demo_hand = null


func _demo_target(which: String) -> Button:
	match which:
		"jump":
			return _jump_button
		"attack":
			return _attack_button
		"left", "right", "move":
			return null      # the stick is demonstrated by the tutorial, not here
	if which.begins_with("skill"):
		var slot: int = int(which.substr(5))
		if slot >= 0 and slot < _skill_buttons.size():
			return _skill_buttons[slot]["button"]
	return null


# --- shared button shape ----------------------------------------------------

func _round_button(at: Vector2, size: float, ring: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.position = at
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(size, size) / 2.0
	# Opaque: a translucent round face shows the corner-fan seam, and lets
	# the world show through the one thing that must never be ambiguous.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.15, 0.30)
	style.set_corner_radius_all(int(size / 2.0))
	style.border_width_bottom = 7
	style.border_width_top = 5
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_color = ring
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = Color(0.14, 0.22, 0.40)
	pressed.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", style)
	add_child(b)
	return b


func _arrow(button: Button, size: float, dir: float) -> void:
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var c := Vector2(size, size) / 2.0
	var r: float = size * 0.23
	Shapes.fill(icon, PackedVector2Array([
		c + Vector2(-dir * r * 0.7, -r), c + Vector2(-dir * r * 0.7, r),
		c + Vector2(dir * r * 1.1, 0),
	]), Color(0.92, 0.96, 1.0), 0.0)


func _jump_glyph(button: Button, size: float) -> void:
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var c := Vector2(size, size) / 2.0
	var r: float = size * 0.22
	Shapes.fill(icon, PackedVector2Array([
		c + Vector2(-r * 1.1, 0.0), c + Vector2(0, -r * 1.2), c + Vector2(r * 1.1, 0.0),
	]), Color(1.0, 0.94, 0.6), 0.0)
	Shapes.fill(icon, Shapes.rounded_rect(c + Vector2(-r * 0.34, r * 0.05),
		Vector2(r * 0.68, r * 0.95), r * 0.2), Color(1.0, 0.94, 0.6), 0.0)
