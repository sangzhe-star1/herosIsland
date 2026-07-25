@tool
class_name SkinnedCharacter
extends Node2D
## The hero as levels see it.
##
## Levels talk to this node -- "walk to x", "cheer", "set the core colour" --
## and never to art. Underneath it is either a drawn HeroArt (the default) or a
## Sprite2D for a skin that carries pictures, and no level can tell which.
##
## This wrapper exists so that the choice between drawn and photographic art is
## a property of a `.tres` file rather than a branch in fourteen level scripts,
## which is how the previous version ended up with the same "if the PNG exists,
## use it" test copy-pasted into every template.

@export var skin: CharacterSkin: set = set_skin

var _art: HeroArt
## The alternate drawn figure (the heeler). Exactly one of _art/_pup/_sprite
## is alive at a time; _pup speaks enough of HeroArt's language (set_height,
## set_pose, core_position...) that the verbs below stay renderer-blind.
var _pup: Node2D
var _sprite: Sprite2D
var _core: Polygon2D
## Height in pixels, when a caller has asked for one. Held here because a
## screen usually sets it immediately after add_child(), which is BEFORE
## _ready() builds the figure -- so the request has to survive the build.
var _height := 0.0

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
	_art = null
	_pup = null
	_sprite = null
	_core = null

	if skin == null:
		skin = _fallback_skin()

	if skin.is_drawn() and skin.renderer == "puppy":
		_pup = preload("res://scripts/world/puppy_art.gd").new()
		add_child(_pup)
		_pup.set_height(_height if _height > 0.0 else skin.body_size.y * 1.9)
	elif skin.is_drawn():
		_art = HeroArt.new(skin)
		# Dressed from the save before entering the tree (HeroArt builds in
		# _ready). The outfit follows the child across heroes and levels;
		# textured skins (photo cut-outs, drop-in PNGs) stay as they came --
		# and so does the puppy: paint sticks to neither photographs nor fur.
		_art.outfit = SaveManager.get_outfit()
		add_child(_art)
		# Fitted to the same footprint the old placeholder occupied, so every
		# position a level already chose keeps working.
		_art.set_height(_height if _height > 0.0 else skin.body_size.y * 1.9)
	else:
		_build_textured()

	set_core_color(skin.core_color)


func _build_textured() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = skin.idle_texture
	var tex_h: float = maxf(float(skin.idle_texture.get_height()), 1.0)
	var s: float = (skin.body_size.y * 1.35) / tex_h
	_sprite.scale = Vector2(s, s)
	_sprite.position = Vector2(0, skin.body_size.y * 0.5 - (tex_h * s) * 0.5)
	add_child(_sprite)

	if skin.core_radius <= 0.0:
		return
	var halo := Polygon2D.new()
	halo.polygon = Shapes.oval_points(skin.core_offset,
		Vector2(skin.core_radius * 1.7, skin.core_radius * 2.0))
	halo.color = Color(1, 1, 1, 0.28)
	_sprite.add_child(halo)
	_core = Polygon2D.new()
	_core.polygon = Shapes.oval_points(skin.core_offset,
		Vector2(skin.core_radius, skin.core_radius * 1.2))
	_core.color = skin.core_color
	_sprite.add_child(_core)


## Re-dress after the wardrobe changes, without rebuilding the whole node.
func refresh_outfit() -> void:
	if _art == null or not is_instance_valid(_art):
		return
	_art.outfit = SaveManager.get_outfit()
	_art.rebuild()
	_art.set_pose(HeroArt.Pose.IDLE, false)


func set_core_color(value: Color) -> void:
	core_color = value
	if _art != null and is_instance_valid(_art):
		_art.set_core_color(value)
	if _pup != null and is_instance_valid(_pup):
		_pup.set_core_color(value)
	if _core != null and is_instance_valid(_core):
		_core.color = value


## Where the chest light is, in global coordinates -- the muzzle of the light
## beam in battle levels.
func core_position() -> Vector2:
	if _art != null and is_instance_valid(_art):
		return _art.core_position()
	if _pup != null and is_instance_valid(_pup):
		return _pup.core_position()
	if _core != null and is_instance_valid(_core):
		return _core.global_position
	return to_global(Vector2(0, -skin.body_size.y * 0.16) if skin != null else Vector2.ZERO)


## Fit the figure to a height in pixels. Levels use this rather than picking a
## scale, so a hero is the same size in the forest as in the city.
func set_height(pixels: float) -> void:
	_height = pixels
	if _art != null and is_instance_valid(_art):
		_art.set_height(pixels)
	if _pup != null and is_instance_valid(_pup):
		_pup.set_height(pixels)
		return
	if _sprite != null and is_instance_valid(_sprite) and skin.idle_texture != null:
		var s: float = pixels / maxf(float(skin.idle_texture.get_height()), 1.0)
		_sprite.scale = Vector2(s, s)
		_sprite.position = Vector2(0, -pixels * 0.5)


func set_pose(pose: int, animate: bool = true) -> void:
	if _art != null and is_instance_valid(_art):
		_art.set_pose(pose as HeroArt.Pose, animate)
	if _pup != null and is_instance_valid(_pup):
		_pup.set_pose(pose, animate)


func walk(enabled: bool) -> void:
	set_pose(HeroArt.Pose.WALK if enabled else HeroArt.Pose.IDLE)


## Soft pulse used for celebration. No flashing: rapid flicker is both
## unpleasant and a seizure risk, so this stays slow and low-contrast.
func celebrate() -> void:
	# Never during a jump or roll: reading a mid-flight scale as the base is
	# how a hero ends up permanently squashed.
	if _moving:
		return
	set_pose(HeroArt.Pose.CHEER)
	_show_cheer_texture()
	if not Juice.motion_enabled():
		return
	_capture_rest()
	var base := _rest_scale
	var t := create_tween().set_loops(3)
	t.tween_property(self, "scale", base * Vector2(1.10, 0.93), 0.16)
	t.tween_property(self, "scale", base * Vector2(0.97, 1.07), 0.16)
	t.tween_property(self, "scale", base, 0.16)
	# Timed off a tween this figure OWNS. A SceneTreeTimer outlives the node
	# it was meant to reset, and fires into a freed character when a level is
	# left mid-animation -- which is every level, every time.
	var back := create_tween()
	back.tween_interval(1.6)
	back.tween_callback(func(): set_pose(HeroArt.Pose.IDLE))


func brace() -> void:
	set_pose(HeroArt.Pose.BEAM)


# --- motion verbs --------------------------------------------------------
#
# The hero moves like a hero now: crouch, leap, tumble, arrive from the sky.
# All of it lives here so every level gets the same physics -- the same
# anticipation beat, the same squash on landing, the same dust -- and all of
# it degrades to stillness under reduce-motion, because a child who finds
# motion overwhelming should get a quiet hero, not a broken one.
#
# Squash and stretch scale THIS node, whose origin is at the feet, so the
# figure compresses into the ground rather than around its own middle.

var _moving := false
## The scale the hero returns to after every squash. Captured while at rest;
## without it each landing "returned" to the stretched launch scale and the
## figure grew five percent per hop, forever.
var _rest_scale := Vector2.ONE


func is_moving() -> bool:
	return _moving


func _capture_rest() -> void:
	if not _moving:
		_rest_scale = scale


## A leap on the spot: crouch, spring, hang, land with dust. The crouch is
## what sells it -- a jump with no anticipation reads as levitation.
func jump(height: float = 80.0, duration: float = 0.55) -> void:
	if _moving or not is_inside_tree():
		return
	if not Juice.motion_enabled():
		return
	_capture_rest()
	_moving = true
	var base_y: float = position.y
	if _art != null and is_instance_valid(_art):
		_art.crouch()
	if _pup != null and is_instance_valid(_pup):
		_pup.crouch()
	var seq := create_tween()
	seq.tween_property(self, "scale:y", _rest_scale.y * 0.90, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	seq.tween_callback(func():
		set_pose(HeroArt.Pose.JUMP)
	)
	seq.tween_property(self, "scale:y", _rest_scale.y * 1.05, 0.10)
	seq.parallel().tween_property(self, "position:y", base_y - height, duration * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	seq.tween_property(self, "position:y", base_y, duration * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	seq.tween_callback(func():
		_land(base_y, height)
	)


func _land(base_y: float, height: float) -> void:
	position.y = base_y
	Juice.dust(get_parent(), position, 5 + int(height / 30.0))
	if height >= 130.0:
		Juice.shockwave(get_parent(), position, 90.0, Color(1.0, 0.95, 0.75, 0.8))
	set_pose(HeroArt.Pose.IDLE)
	var settle := create_tween()
	settle.tween_property(self, "scale:y", _rest_scale.y * 0.88, 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle.tween_property(self, "scale:y", _rest_scale.y, 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_callback(func():
		scale = _rest_scale
		_moving = false
	)


## A small happy hop.
func hop() -> void:
	jump(42.0, 0.42)


## The tumble: tuck into a ball, one full turn, travel sideways, land in a
## puff of dust with speed lines trailing. `distance` may be negative.
func roll(distance: float = 170.0, duration: float = 0.55) -> void:
	if _moving or not is_inside_tree():
		return
	if not Juice.motion_enabled():
		# Reduce-motion still gets there, quietly.
		position.x += distance
		return
	_moving = true
	var base_y: float = position.y
	var direction := Vector2(signf(distance), 0.0)
	set_pose(HeroArt.Pose.TUCK)
	if _art != null and is_instance_valid(_art):
		_art.spin(signf(distance), duration)
	if _pup != null and is_instance_valid(_pup):
		_pup.spin(signf(distance), duration)
	Juice.speed_lines(get_parent(), position + Vector2(0, -60), direction)
	var seq := create_tween()
	seq.set_parallel(true)
	seq.tween_property(self, "position:x", position.x + distance, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# A shallow arc: up over the middle of the roll, down at the end.
	seq.tween_property(self, "position:y", base_y - 26.0, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	seq.chain().tween_property(self, "position:y", base_y, duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	seq.chain().tween_callback(func():
		Juice.dust(get_parent(), position, 6)
		set_pose(HeroArt.Pose.IDLE)
		_moving = false
	)


## The hero of light arriving: drops from the sky and lands with a shockwave.
## Call after placing the node where it should stand.
func entrance(from_height: float = 360.0, delay: float = 0.0) -> void:
	if not is_inside_tree() or not Juice.motion_enabled():
		return
	_moving = true
	var target_y: float = position.y
	position.y = target_y - from_height
	set_pose(HeroArt.Pose.JUMP, false)
	var seq := create_tween()
	if delay > 0.0:
		seq.tween_interval(delay)
	seq.tween_property(self, "position:y", target_y, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	seq.tween_callback(func():
		_land(target_y, from_height)
		power_up()
	)


## The win: a leap, then the cheer at the top of the bounce-back.
func victory() -> void:
	jump(72.0, 0.5)
	if not Juice.motion_enabled():
		celebrate()
		return
	var timer := create_tween()
	timer.tween_interval(0.95)
	timer.tween_callback(celebrate)


func stumble() -> void:
	set_pose(HeroArt.Pose.HURT)
	var back := create_tween()
	back.tween_interval(0.7)
	back.tween_callback(func(): set_pose(HeroArt.Pose.IDLE))


func _show_cheer_texture(hold_seconds: float = 1.5) -> void:
	if _sprite == null or skin == null or skin.cheer_texture == null:
		return
	_sprite.texture = skin.cheer_texture
	var timer := get_tree().create_timer(hold_seconds)
	timer.timeout.connect(func():
		if is_instance_valid(_sprite) and skin != null and skin.idle_texture != null:
			_sprite.texture = skin.idle_texture
	)


## The chest light brightening, for moments worth marking.
func power_up() -> void:
	if _art != null and is_instance_valid(_art):
		_art.pulse_core()
	if _pup != null and is_instance_valid(_pup):
		_pup.pulse_core()
		return
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
