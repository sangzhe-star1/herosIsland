extends Node2D
## World actor for the bear's reciprocal visit.
##
## After the child helps on the bear's farm, the bear comes out of the bear door,
## walks to a bed that needs water, waters it, gives a happy emote, and walks back.

const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Juice := preload("res://scripts/ui/juice.gd")
const Shapes := preload("res://scripts/world/shapes.gd")

var _sprite: Node2D
var _emote: Node2D
var _home_pos := Vector2.ZERO
var _walking := false


func setup(home_pos: Vector2) -> void:
	_home_pos = home_pos
	position = home_pos
	_build_art()


func _build_art() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.queue_free()

	var tex := HarvestArt.prop_texture("bear")
	if tex != null:
		var sprite_rect := HarvestArt.grounded_sprite(tex, 76.0, Vector2.ZERO, "BearSprite")
		if sprite_rect != null:
			_sprite = Node2D.new()
			_sprite.name = "BearArt"
			_sprite.add_child(sprite_rect)
	if _sprite == null:
		var pic := UiKit.picture("teddy", 60.0)
		if pic != null:
			_sprite = Node2D.new()
			_sprite.name = "BearArt"
			pic.position = Vector2(-30, -60)
			_sprite.add_child(pic)
	if _sprite != null:
		add_child(_sprite)


func walk_to_bed_and_water(target_pos: Vector2, on_watered: Callable, on_finished: Callable) -> void:
	if not Juice.motion_enabled():
		if on_watered.is_valid():
			on_watered.call()
		if on_finished.is_valid():
			on_finished.call()
		queue_free()
		return

	var walk_dest := target_pos + Vector2(60.0, 15.0)
	var t := create_tween()

	# 1. Walk from bear door to target bed
	t.tween_property(self, "position", walk_dest, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Water the bed
	t.tween_callback(func():
		AudioManager.play_sfx("res://assets/audio/water.ogg")
		_spawn_water_effect(target_pos)
		if on_watered.is_valid():
			on_watered.call()
	)
	t.tween_interval(0.4)

	# 3. Show happy emote
	t.tween_callback(func():
		AudioManager.play_sfx("res://assets/audio/star.ogg")
		_show_emote()
	)
	t.tween_interval(0.8)

	# 4. Walk back to bear door
	t.tween_property(self, "position", _home_pos, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 5. Finish and cleanup
	t.tween_callback(func():
		if on_finished.is_valid():
			on_finished.call()
		queue_free()
	)


func _spawn_water_effect(at_bed: Vector2) -> void:
	for i in range(8):
		var drop := Node2D.new()
		drop.z_index = 25
		drop.position = position + Vector2(-20.0 + 8.0 * float(i), -20.0)
		get_parent().add_child(drop)
		Shapes.fill(drop, Shapes.oval_points(Vector2.ZERO, Vector2(3.0, 6.0)),
			Color(0.45, 0.70, 0.92, 0.9), 0.0)
		var dt := drop.create_tween()
		dt.tween_property(drop, "position", at_bed + Vector2(-30.0 + 10.0 * float(i), 0.0), 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dt.tween_callback(drop.queue_free)


func _show_emote() -> void:
	if _emote != null and is_instance_valid(_emote):
		_emote.queue_free()
	_emote = Node2D.new()
	_emote.position = Vector2(0.0, -84.0)
	add_child(_emote)
	var heart := UiKit.picture("heart", 32.0)
	if heart != null:
		heart.position = Vector2(-16.0, -16.0)
		_emote.add_child(heart)
	var et := _emote.create_tween()
	et.tween_property(_emote, "position:y", -100.0, 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	et.tween_property(_emote, "modulate:a", 0.0, 0.3)
	et.tween_callback(_emote.queue_free)
