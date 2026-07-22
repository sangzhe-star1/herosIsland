@tool
class_name SkinnedCharacter
extends Node2D
## Draws whichever CharacterSkin it is given. If the skin has no textures it
## draws a simple placeholder figure instead: body, cape accent, and a glowing
## chest core that can change colour.
##
## Levels talk to this node ("walk to x", "set core colour"), never to art.

@export var skin: CharacterSkin: set = set_skin

var _sprite: Sprite2D
var _placeholder: Node2D
var _core: Polygon2D

var core_color: Color = Color.WHITE: set = set_core_color


func _ready() -> void:
	_build()


func set_skin(value: CharacterSkin) -> void:
	skin = value
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_sprite = null
	_placeholder = null
	_core = null

	if skin == null:
		skin = _fallback_skin()

	if skin.idle_texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = skin.idle_texture
		add_child(_sprite)
	else:
		_build_placeholder()

	set_core_color(skin.core_color)


## A recognisable hero silhouette from primitives: no art dependency, but still
## reads as a character to a child rather than as a rectangle.
func _build_placeholder() -> void:
	_placeholder = Node2D.new()
	add_child(_placeholder)

	var w: float = skin.body_size.x
	var h: float = skin.body_size.y

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-w * 0.3, -h * 0.5),
		Vector2(w * 0.3, -h * 0.5),
		Vector2(w * 0.36, h * 0.2),
		Vector2(w * 0.22, h * 0.5),
		Vector2(-w * 0.22, h * 0.5),
		Vector2(-w * 0.36, h * 0.2),
	])
	body.color = skin.body_color
	_placeholder.add_child(body)

	var head := Polygon2D.new()
	var head_r: float = w * 0.26
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * head_r, sin(a) * head_r * 1.15) + Vector2(0, -h * 0.62))
	head.polygon = pts
	head.color = skin.body_color
	_placeholder.add_child(head)

	var crest := Polygon2D.new()
	crest.polygon = PackedVector2Array([
		Vector2(0, -h * 0.62 - head_r * 1.35),
		Vector2(head_r * 0.34, -h * 0.62 - head_r * 0.2),
		Vector2(-head_r * 0.34, -h * 0.62 - head_r * 0.2),
	])
	crest.color = skin.accent_color
	_placeholder.add_child(crest)

	var belt := Polygon2D.new()
	belt.polygon = PackedVector2Array([
		Vector2(-w * 0.34, h * 0.06),
		Vector2(w * 0.34, h * 0.06),
		Vector2(w * 0.32, h * 0.18),
		Vector2(-w * 0.32, h * 0.18),
	])
	belt.color = skin.accent_color
	_placeholder.add_child(belt)

	# The chest core. Levels use it as a colour signal the child must read.
	_core = Polygon2D.new()
	var core_pts := PackedVector2Array()
	var cr: float = w * 0.16
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		core_pts.append(Vector2(cos(a) * cr, sin(a) * cr * 1.3) + Vector2(0, -h * 0.2))
	_core.polygon = core_pts
	_core.color = skin.core_color
	_placeholder.add_child(_core)


func set_core_color(value: Color) -> void:
	core_color = value
	if _core != null:
		_core.color = value


## Soft pulse used for celebration. No flashing: rapid flicker is both
## unpleasant and a seizure risk, so this stays slow and low-contrast.
func celebrate() -> void:
	var t := create_tween().set_loops(3)
	t.tween_property(self, "scale", Vector2(1.12, 0.92), 0.16)
	t.tween_property(self, "scale", Vector2(0.96, 1.08), 0.16)
	t.tween_property(self, "scale", Vector2.ONE, 0.16)


func _fallback_skin() -> CharacterSkin:
	var s := CharacterSkin.new()
	s.id = "placeholder"
	return s
