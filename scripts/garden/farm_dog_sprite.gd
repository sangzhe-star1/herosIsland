extends Node2D
## The farm dog as the studio rendered him, standing in for PuppyArt when the
## render exists. The controller keeps calling set_height / set_pose / scale.x
## exactly as it did; this answers them with a sprite anchored by its paws,
## a small trot while walking and a hop for a cheer. One dog, one light, like
## everything else on the farm now.
##
## Also supports unlocked tricks (sit, roll, carry, dig).

const Art := preload("res://scripts/harvest/harvest_visual_art.gd")

var _art: TextureRect
var _height := 96.0
var _pose := HeroArt.Pose.BEAM
var _trick := ""
var _basket: TextureRect = null
var _t := 0.0


func _ready() -> void:
	var texture := Art.prop_texture("dog")
	if texture == null:
		return
	# The render is 1.4 m of a 2.6 m span: the dog stands about this tall.
	_art = Art.grounded_sprite(texture, _height * 0.95, Vector2.ZERO, "DogArt")
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.pivot_offset = -_art.position
	add_child(_art)


static func available() -> bool:
	return Art.prop_texture("dog") != null


func set_height(pixels: float) -> void:
	_height = pixels
	if _art != null and is_instance_valid(_art):
		_art.queue_free()
		_ready()


func set_pose(pose: int) -> void:
	_pose = pose
	if _art != null and is_instance_valid(_art) and pose != HeroArt.Pose.WALK:
		_art.rotation = 0.0
		_art.position.y = -_art.size.y * Art.GROUND_ORIGIN_PIXEL_Y / Art.SOURCE_CANVAS_SIZE


func set_trick(trick: String) -> void:
	_trick = trick
	if _basket != null and is_instance_valid(_basket):
		_basket.queue_free()
		_basket = null
	if trick == "carry" or trick == "carry_basket":
		var b_tex := Art.prop_texture("basket_empty")
		if b_tex != null:
			_basket = Art.grounded_sprite(b_tex, _height * 0.40, Vector2.ZERO, "DogBasket")
			_basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_basket.position = Vector2(16.0, -_height * 0.45)
			add_child(_basket)
	if _art != null and is_instance_valid(_art):
		if trick == "":
			_art.scale = Vector2.ONE
			_art.rotation = 0.0


func _process(delta: float) -> void:
	if _art == null or not is_instance_valid(_art):
		return
	var rest := -_art.size.y * Art.GROUND_ORIGIN_PIXEL_Y / Art.SOURCE_CANVAS_SIZE
	if not Juice.motion_enabled():
		_art.rotation = 0.0
		_art.position.y = rest
		_art.scale = Vector2.ONE
		return
	_t += delta

	if _trick != "":
		match _trick:
			"sit":
				_art.scale = Vector2(1.06, 0.82)
				_art.position.y = rest + _height * 0.08
				_art.rotation = sin(_t * 3.0) * 0.02
				return
			"roll":
				_art.scale = Vector2(0.95, 0.95)
				_art.rotation = sin(_t * 12.0) * 0.45
				_art.position.y = rest + absf(sin(_t * 12.0)) * 6.0
				return
			"carry", "carry_basket":
				_art.scale = Vector2.ONE
				_art.rotation = sin(_t * 6.0) * 0.04
				_art.position.y = rest - absf(sin(_t * 6.0)) * 4.0
				return
			"dig":
				_art.scale = Vector2(0.96, 0.92)
				_art.rotation = -0.16 + sin(_t * 18.0) * 0.08
				_art.position.y = rest - absf(sin(_t * 18.0)) * _height * 0.08
				return

	match _pose:
		HeroArt.Pose.WALK:
			_art.rotation = sin(_t * 14.0) * 0.06
			_art.position.y = rest - absf(sin(_t * 14.0)) * _height * 0.05
		HeroArt.Pose.CHEER:
			_art.position.y = rest - absf(sin(_t * 9.0)) * _height * 0.12
		_:
			_art.position.y = rest - (sin(_t * 2.2) * 0.5 + 0.5) * 1.5
