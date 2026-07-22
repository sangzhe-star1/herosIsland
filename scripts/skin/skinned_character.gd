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


## An original light hero, drawn from primitives.
##
## Uses the giant-hero vocabulary a child recognises instantly -- smooth
## helmet-like head, large glowing eyes, a fin crest, silver body with red
## accents, and a round chest light -- without reproducing any particular
## character. Those elements are genre conventions, not protected expression,
## so this design is the project's own and can ship.
##
## It is still a placeholder in the sense that commissioned art will be better.
## It is not a placeholder in the sense of being a rectangle: the point is that
## the game reads correctly today, and art becomes an upgrade rather than a
## prerequisite.
func _build_placeholder() -> void:
	_placeholder = Node2D.new()
	add_child(_placeholder)

	var w: float = skin.body_size.x
	var h: float = skin.body_size.y
	var silver: Color = skin.body_color
	var shade: Color = silver.darkened(0.16)
	var accent: Color = skin.accent_color

	# --- legs, drawn first so the torso overlaps them ---
	for side in [-1.0, 1.0]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(side * w * 0.07, h * 0.10),
			Vector2(side * w * 0.26, h * 0.10),
			Vector2(side * w * 0.24, h * 0.44),
			Vector2(side * w * 0.10, h * 0.44),
		])
		leg.color = silver
		_placeholder.add_child(leg)

		var boot := Polygon2D.new()
		boot.polygon = PackedVector2Array([
			Vector2(side * w * 0.09, h * 0.40),
			Vector2(side * w * 0.25, h * 0.40),
			Vector2(side * w * 0.27, h * 0.50),
			Vector2(side * w * 0.07, h * 0.50),
		])
		boot.color = accent
		_placeholder.add_child(boot)

	# --- arms ---
	for side in [-1.0, 1.0]:
		var arm := Polygon2D.new()
		arm.polygon = PackedVector2Array([
			Vector2(side * w * 0.26, -h * 0.30),
			Vector2(side * w * 0.42, -h * 0.24),
			Vector2(side * w * 0.38, h * 0.10),
			Vector2(side * w * 0.24, h * 0.06),
		])
		arm.color = silver
		_placeholder.add_child(arm)

	# --- torso ---
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-w * 0.28, -h * 0.36),
		Vector2(w * 0.28, -h * 0.36),
		Vector2(w * 0.30, -h * 0.06),
		Vector2(w * 0.20, h * 0.14),
		Vector2(-w * 0.20, h * 0.14),
		Vector2(-w * 0.30, -h * 0.06),
	])
	body.color = silver
	_placeholder.add_child(body)

	# Red shoulder-to-chest stripes: the accent that makes the silhouette read
	# as a hero rather than a robot.
	for side in [-1.0, 1.0]:
		var stripe := Polygon2D.new()
		stripe.polygon = PackedVector2Array([
			Vector2(side * w * 0.28, -h * 0.36),
			Vector2(side * w * 0.16, -h * 0.36),
			Vector2(side * w * 0.05, h * 0.12),
			Vector2(side * w * 0.15, h * 0.12),
		])
		stripe.color = accent
		_placeholder.add_child(stripe)

	# --- head ---
	var head_centre := Vector2(0, -h * 0.54)
	var head_r: float = w * 0.25

	var head := Polygon2D.new()
	var head_pts := PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		head_pts.append(head_centre + Vector2(cos(a) * head_r, sin(a) * head_r * 1.22))
	head.polygon = head_pts
	head.color = silver
	_placeholder.add_child(head)

	# Large angled eyes. More than anything else, these are what a small child
	# uses to identify the character.
	for side in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([
			head_centre + Vector2(side * head_r * 0.20, -head_r * 0.34),
			head_centre + Vector2(side * head_r * 0.82, -head_r * 0.10),
			head_centre + Vector2(side * head_r * 0.70, head_r * 0.42),
			head_centre + Vector2(side * head_r * 0.22, head_r * 0.20),
		])
		eye.color = Color(1.0, 0.94, 0.62)
		_placeholder.add_child(eye)

	# Fin crest along the top of the head.
	var crest := Polygon2D.new()
	crest.polygon = PackedVector2Array([
		head_centre + Vector2(0, -head_r * 2.05),
		head_centre + Vector2(head_r * 0.26, -head_r * 0.95),
		head_centre + Vector2(-head_r * 0.26, -head_r * 0.95),
	])
	crest.color = accent
	_placeholder.add_child(crest)

	# --- belt ---
	var belt := Polygon2D.new()
	belt.polygon = PackedVector2Array([
		Vector2(-w * 0.22, h * 0.06),
		Vector2(w * 0.22, h * 0.06),
		Vector2(w * 0.20, h * 0.14),
		Vector2(-w * 0.20, h * 0.14),
	])
	belt.color = shade
	_placeholder.add_child(belt)

	# --- chest light ---
	# Gameplay depends on this: levels recolour it to tell the child which
	# orbs to collect, so it is drawn neutral and tinted at runtime.
	var halo := Polygon2D.new()
	var halo_pts := PackedVector2Array()
	var halo_r: float = w * 0.20
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		halo_pts.append(Vector2(cos(a) * halo_r, sin(a) * halo_r * 1.25) + Vector2(0, -h * 0.16))
	halo.polygon = halo_pts
	halo.color = Color(1, 1, 1, 0.30)
	_placeholder.add_child(halo)

	_core = Polygon2D.new()
	var core_pts := PackedVector2Array()
	var cr: float = w * 0.14
	for i in range(14):
		var a: float = TAU * float(i) / 14.0
		core_pts.append(Vector2(cos(a) * cr, sin(a) * cr * 1.25) + Vector2(0, -h * 0.16))
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
	if not Juice.motion_enabled():
		return
	var base := scale
	var t := create_tween().set_loops(3)
	t.tween_property(self, "scale", base * Vector2(1.12, 0.92), 0.16)
	t.tween_property(self, "scale", base * Vector2(0.96, 1.08), 0.16)
	t.tween_property(self, "scale", base, 0.16)


## The chest light brightening, for moments worth marking. Slow enough to read
## as a glow rather than a blink.
func power_up() -> void:
	if _core == null or not Juice.motion_enabled():
		return
	var lit: Color = core_color.lightened(0.45)
	var t := create_tween()
	t.tween_property(_core, "color", lit, 0.28).set_trans(Tween.TRANS_SINE)
	t.tween_property(_core, "color", core_color, 0.42).set_trans(Tween.TRANS_SINE)


func _fallback_skin() -> CharacterSkin:
	var s := CharacterSkin.new()
	s.id = "placeholder"
	return s
