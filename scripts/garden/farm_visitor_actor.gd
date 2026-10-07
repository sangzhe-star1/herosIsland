extends Node2D
## World actor for today's visiting friend on the farm.
##
## Walks in from the gate and stands beside the notice board showing a
## speech bubble with the dish they wish to taste. Tapping them opens the board.

const VisitorManager := preload("res://scripts/garden/farm_visitor_manager.gd")
const HarvestArt := preload("res://scripts/harvest/harvest_visual_art.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")

var _sprite: Node2D
var _bubble: Node2D
var _bubble_tween: Tween
var _who := "rabbit"
var _dish_id := ""
var _fed := false
var _target := Vector2(460, 1020)


func setup(farm: Dictionary) -> void:
	var visitor := VisitorManager.today_visitor()
	if visitor.is_empty():
		visible = false
		return
	_who = str(visitor.get("who", "rabbit"))
	_dish_id = str(visitor.get("dish_id", ""))
	_fed = VisitorManager.has_fed_today(farm)

	var board := Layout.facility("visit_board")
	_target = Layout.facility_at(board) + Vector2(-60, 20)

	position = _target
	_build_art()
	_build_bubble()


func _build_art() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.queue_free()

	var prop_key := "dog" if _who == "puppy" else _who
	var tex := HarvestArt.prop_texture(prop_key)
	if tex != null:
		var sprite_rect := HarvestArt.grounded_sprite(tex, 75.0, Vector2.ZERO, "VisitorSprite")
		if sprite_rect != null:
			_sprite = Node2D.new()
			_sprite.name = "VisitorArt"
			_sprite.add_child(sprite_rect)
	if _sprite == null:
		var pic := UiKit.picture("teddy", 60.0)
		if pic != null:
			_sprite = Node2D.new()
			_sprite.name = "VisitorArt"
			pic.position = Vector2(-30, -60)
			_sprite.add_child(pic)
	if _sprite != null:
		add_child(_sprite)


func _build_bubble() -> void:
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
		_bubble_tween = null
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()

	_bubble = Node2D.new()
	_bubble.name = "WantBubble"
	_bubble.position = Vector2(0, -78)
	add_child(_bubble)

	# Bubble background
	var bg := Panel.new()
	bg.size = Vector2(46, 38)
	bg.position = Vector2(-23, -19)
	bg.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1.0, 0.99, 0.95), 12))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(bg)

	if _fed:
		var heart := UiKit.picture("heart", 24.0)
		if heart != null:
			heart.position = Vector2(-12, -12)
			heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bubble.add_child(heart)
	else:
		var icon := UiKit.picture("dish", 26.0)
		if icon != null:
			icon.position = Vector2(-13, -13)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bubble.add_child(icon)

	# Gentle breathing animation
	if is_inside_tree() and Juice.motion_enabled():
		_bubble_tween = _bubble.create_tween().set_loops()
		_bubble_tween.tween_property(_bubble, "position:y", -82.0, 0.9).set_trans(Tween.TRANS_SINE)
		_bubble_tween.tween_property(_bubble, "position:y", -76.0, 0.9).set_trans(Tween.TRANS_SINE)


func is_hit(point: Vector2) -> bool:
	return point.distance_to(position + Vector2(0, -35)) < 55.0
