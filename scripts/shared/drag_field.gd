class_name DragField
extends Control
## Picking things up and putting them somewhere.
##
## Two of the nine templates are built entirely out of this -- sorting things
## into bins and slotting parts into a machine -- and a third uses it for its
## puzzle pieces. Writing the drag three times would mean three different
## feels, and the one thing a six-year-old notices instantly is when the same
## gesture behaves differently on the next screen.
##
## Everything here exists because of how a small hand actually drags:
##
##   * the GRAB RADIUS is bigger than the thing, because a thumb covers what
##     it is reaching for and lands beside it
##   * the piece rises and grows while held, so it is visible past the thumb
##   * every target within reach lights up -- the child is told where things
##     can go before they have to guess
##   * SNAP: let go anywhere near the right place and it clicks in
##   * a wrong drop floats home, it does not fall or vanish
##
## No failure state lives in here. Wrong drops are a shrug and a retry, and
## whether they cost anything is the level's business, not the field's.

signal picked_up(item: Dictionary)
signal dropped(item: Dictionary, slot: Dictionary, correct: bool)
signal solved()

## How far from a piece a thumb may land and still grab it.
const GRAB := 84.0
## How near a slot a piece must be released to click into it.
const SNAP := 118.0
const LIFT := 1.18                # how much a held piece grows
const HOME := 0.28                # seconds for a wrong drop to float back

var _items: Array = []            # [{node, at, home, key, placed, slot}]
var _slots: Array = []            # [{node, at, key, filled, glow}]
var _held: Dictionary = {}
var _grab_offset := Vector2.ZERO
var _touch := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- what the level puts in the field ---------------------------------------

## Add something draggable. `key` is what it IS; a slot with a matching key
## accepts it. The node is drawn by the level -- the field only moves it.
func add_item(node: Node2D, at: Vector2, key: String) -> Dictionary:
	node.position = at
	var item := {"node": node, "at": at, "home": at, "key": key,
		"placed": false, "slot": {}}
	_items.append(item)
	return item


## Add somewhere things can go. `accepts` is the key it wants, or "" for any.
## `capacity` above one lets a bin take several things.
func add_slot(node: Node2D, at: Vector2, accepts: String,
		capacity: int = 99) -> Dictionary:
	node.position = at
	var slot := {"node": node, "at": at, "accepts": accepts, "held": 0,
		"capacity": capacity, "glow": null}
	_slots.append(slot)
	return slot


func items() -> Array:
	return _items


func slots() -> Array:
	return _slots


func held() -> Dictionary:
	return _held


## A caller returning a placed item owns its new position immediately.
## Stop our earlier lift/snap animations before they can overwrite that move.
func cancel_item_motion(item: Dictionary) -> void:
	_cancel_item_tween(item, "position_tween")
	_cancel_item_tween(item, "scale_tween")


func _cancel_item_tween(item: Dictionary, key: String) -> void:
	var moving := item.get(key) as Tween
	if moving != null and moving.is_valid():
		moving.kill()
	item.erase(key)


## Everything placed where it belongs?
func complete() -> bool:
	for item in _items:
		if not bool(item["placed"]):
			return false
	return true


# --- the gesture ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	_handle(event)


func _input(event: InputEvent) -> void:
	_handle(event)


func _handle(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch == -1:
			if _grab(touch.position):
				_touch = touch.index
		elif not touch.pressed and touch.index == _touch:
			_release(touch.position)
			_touch = -1
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch:
		_move((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed and _touch == -1:
			if _grab(click.position):
				_touch = -2
		elif not click.pressed and _touch == -2:
			_release(click.position)
			_touch = -1
	elif event is InputEventMouseMotion and _touch == -2:
		_move((event as InputEventMouseMotion).position)


func _grab(at: Vector2) -> bool:
	var best := {}
	var best_d := GRAB
	for item in _items:
		if bool(item["placed"]):
			continue
		var node: Node2D = item["node"]
		if not is_instance_valid(node):
			continue
		var d: float = node.position.distance_to(at)
		if d < best_d:
			best_d = d
			best = item
	if best.is_empty():
		return false
	_held = best
	var node2: Node2D = best["node"]
	_grab_offset = node2.position - at
	node2.z_index = 50
	cancel_item_motion(best)
	if Juice.motion_enabled():
		var t := node2.create_tween()
		best["scale_tween"] = t
		t.tween_property(node2, "scale", Vector2(LIFT, LIFT), 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		node2.scale = Vector2(LIFT, LIFT)
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	_light_targets(true)
	picked_up.emit(best)
	return true


func _move(at: Vector2) -> void:
	if _held.is_empty():
		return
	var node: Node2D = _held["node"]
	if not is_instance_valid(node):
		return
	# Held a little ABOVE the finger, so the thumb is not standing on the
	# thing the child is trying to look at.
	node.position = at + _grab_offset + Vector2(0, -34.0)
	_pulse_nearest(node.position)


func _release(at: Vector2) -> void:
	if _held.is_empty():
		return
	var item: Dictionary = _held
	_held = {}
	_light_targets(false)
	var node: Node2D = item["node"]
	if not is_instance_valid(node):
		return
	node.z_index = 0
	_cancel_item_tween(item, "scale_tween")
	if Juice.motion_enabled():
		var t := node.create_tween()
		item["scale_tween"] = t
		t.tween_property(node, "scale", Vector2.ONE, 0.12)
	else:
		node.scale = Vector2.ONE

	var slot := _slot_near(node.position)
	if slot.is_empty():
		_float_home(item)
		dropped.emit(item, {}, false)
		return
	var correct: bool = str(slot["accepts"]) == "" \
		or str(slot["accepts"]) == str(item["key"])
	if not correct:
		_float_home(item)
		_refuse(slot)
		dropped.emit(item, slot, false)
		return
	_click_in(item, slot)
	dropped.emit(item, slot, true)
	if complete():
		solved.emit()


func _slot_near(at: Vector2) -> Dictionary:
	var best := {}
	var best_d := SNAP
	for slot in _slots:
		if int(slot["held"]) >= int(slot["capacity"]):
			continue
		var node: Node2D = slot["node"]
		if not is_instance_valid(node):
			continue
		var d: float = node.position.distance_to(at)
		if d < best_d:
			best_d = d
			best = slot
	return best


## Clicking in: the piece flies the last few pixels by itself, which is what
## makes a near miss feel like a hit rather than like a correction.
func _click_in(item: Dictionary, slot: Dictionary) -> void:
	item["placed"] = true
	item["slot"] = slot
	slot["held"] = int(slot["held"]) + 1
	var node: Node2D = item["node"]
	var target: Vector2 = (slot["node"] as Node2D).position \
		+ Vector2(0, float(slot.get("offset_y", 0.0)))
	_cancel_item_tween(item, "position_tween")
	if Juice.motion_enabled():
		var t := node.create_tween()
		item["position_tween"] = t
		t.tween_property(node, "position", target, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		node.position = target
	Juice.pop(slot["node"], 0.22)
	Juice.burst(self, target, 12)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")


## A wrong drop floats home. Not drops, not vanishes, not flashes red: the
## piece simply goes back to where it was waiting, and the child tries again
## with everything exactly as it was.
func _float_home(item: Dictionary) -> void:
	var node: Node2D = item["node"]
	_cancel_item_tween(item, "position_tween")
	if Juice.motion_enabled():
		var t := node.create_tween()
		item["position_tween"] = t
		t.tween_property(node, "position", item["home"], HOME)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		node.position = item["home"]


func _refuse(slot: Dictionary) -> void:
	Juice.nudge(slot["node"], 10.0)
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")


# --- telling the child where things can go -------------------------------------

## While something is held, every place it could go glows. A child should
## never have to work out what the targets are by dropping things on them.
func _light_targets(on: bool) -> void:
	for slot in _slots:
		var node: Node2D = slot["node"]
		if not is_instance_valid(node):
			continue
		var glow: Variant = slot.get("glow")
		if on and int(slot["held"]) < int(slot["capacity"]):
			if glow == null or not is_instance_valid(glow):
				var ring := Node2D.new()
				node.add_child(ring)
				Shapes.glow(ring, Vector2.ZERO, 150.0, Color(1.0, 0.92, 0.55), 4, 0.34)
				slot["glow"] = ring
				if Juice.motion_enabled():
					var t := ring.create_tween().set_loops()
					t.tween_property(ring, "scale", Vector2(1.10, 1.10), 0.55)\
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					t.tween_property(ring, "scale", Vector2.ONE, 0.55)\
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif glow != null and is_instance_valid(glow):
			(glow as Node2D).queue_free()
			slot["glow"] = null


## The nearest target glows harder than the rest, so "let go now" is legible
## a moment before the child lets go.
func _pulse_nearest(at: Vector2) -> void:
	var near := _slot_near(at)
	for slot in _slots:
		var glow: Variant = slot.get("glow")
		if glow == null or not is_instance_valid(glow):
			continue
		(glow as Node2D).modulate.a = 1.0 if slot == near else 0.45


## Put a piece where it belongs without the child doing it -- the last resort
## of the hint system, after three failures. The child still sees it happen.
func place_for_them(item: Dictionary) -> void:
	if bool(item["placed"]):
		return
	for slot in _slots:
		if int(slot["held"]) >= int(slot["capacity"]):
			continue
		if str(slot["accepts"]) == "" or str(slot["accepts"]) == str(item["key"]):
			_click_in(item, slot)
			if complete():
				solved.emit()
			return
