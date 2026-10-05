extends Node2D
## The farm dog as the studio rendered him, standing in for PuppyArt when the
## render exists. The controller keeps calling set_height / set_pose / scale.x
## exactly as it did; this answers them with a sprite anchored by its paws,
## a small trot while walking and a hop for a cheer. One dog, one light, like
## everything else on the farm now.

const Art := preload("res://scripts/harvest/harvest_visual_art.gd")

var _art: TextureRect
var _height := 96.0
var _pose := HeroArt.Pose.BEAM
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


func _process(delta: float) -> void:
	if _art == null or not is_instance_valid(_art):
		return
	var rest := -_art.size.y * Art.GROUND_ORIGIN_PIXEL_Y / Art.SOURCE_CANVAS_SIZE
	if not Juice.motion_enabled():
		_art.rotation = 0.0
		_art.position.y = rest
		return
	_t += delta
	match _pose:
		HeroArt.Pose.WALK:
			_art.rotation = sin(_t * 14.0) * 0.06
			_art.position.y = rest - absf(sin(_t * 14.0)) * _height * 0.05
		HeroArt.Pose.CHEER:
			_art.position.y = rest - absf(sin(_t * 9.0)) * _height * 0.12
		_:
			_art.position.y = rest - (sin(_t * 2.2) * 0.5 + 0.5) * 1.5
