extends Node2D
## A basket, and what it will take.
##
## The sorting half of 丰收行动. One basket means the game puts things away for
## him; two mean he decides, and deciding is the whole point of a sorting level.
##
##
## WHY A WRONG BASKET IS NOT A MISTAKE
##
## Dropping a strawberry in the vegetable basket floats it back and says so.
## Nothing is lost -- not the fruit, not a star, not time -- and the fruit is
## still on the plant to try again. The only thing a wrong drop feeds is the
## hint director, which is a counter for HELP.
##
## That is not softness for its own sake. A six-year-old sorting fruit from
## vegetables is being asked a question they are still learning the answer to,
## and a game that punishes the wrong answer teaches them to stop guessing.

const Maturity := preload("res://scripts/harvest/maturity.gd")
const FarmWorldArt := preload("res://scripts/garden/farm_world_art.gd")
const VisualArt := preload("res://scripts/harvest/harvest_visual_art.gd")

var id := ""
## Tags this basket takes. Empty means it takes anything -- the single-basket
## case, where there is nothing to decide.
var accepts: Array = []
var radius := 120.0
var _size := 0.0

var _label: Control
## The answer is a visible place before it is a moving place. This ring stays
## on with reduce-motion enabled; the gentle breathing below is only an extra
## invitation for children who use motion.
var _waiting_cue: Node2D
## The "something is waiting for you" pulse, kept so it can be stopped. A
## looping tween nobody holds on to runs until the node dies.
var _pulse: Tween
## In reduced-motion mode this is the visible landing receipt. It is a child
## of the basket, not an extra HUD or a second scoring signal.
var _accepted_cue: Node2D


## `reach` is how far a press may land from the middle and still mean THIS
## basket. It is handed in rather than worked out from `size`, because what
## makes a reach right is how far away the next basket is -- see
## harvest_action._build_baskets, where the whole column is measured at once.
func build(spec: Dictionary, size: float, reach: float = -1.0) -> void:
	id = str(spec.get("id", "basket"))
	accepts = spec.get("accepts_tags", [])
	radius = float(spec.get("radius", reach if reach > 0.0 else size * 0.9))
	_size = size
	_build_waiting_cue(size)

	# The 3D render shares the crop camera/ground pivot. Metadata selects
	# the existing short ground shadow. Keep the previous shell as a fallback so
	# this component remains usable before optional artwork is imported.
	var basket_texture := VisualArt.prop_texture("basket_empty")
	if basket_texture != null:
		if not VisualArt.prop_has_baked_contact_shadow("basket_empty"):
			Shapes.ground_shadow(self, Vector2(0.0, size * 0.52), size * 1.05, 0.18)
		var basket_art := VisualArt.grounded_sprite(basket_texture, size,
			Vector2(0.0, size * 0.52), "HarvestBasket3DArt")
		add_child(basket_art)
	else:
		Shapes.ground_shadow(self, Vector2(0, size * 0.52), size * 1.05, 0.20)
		FarmWorldArt.draw_basket_shell(self, size)

	# What it takes, drawn as the thing itself rather than written as a word.
	# A child who cannot read "fruit" can recognise a strawberry.
	var sample := str(spec.get("sample", ""))
	if sample != "":
		# The sample is a stitched-on basket tag, not a cream disc floating next
		# to it.  A loose disc is too easily read as another pickable crop; this
		# small warm tag stays physically attached to the place it describes.
		var tag := Node2D.new()
		tag.name = "BasketSampleTag"
		tag.position = Vector2(0.0, size * 0.14)
		tag.z_index = 1
		add_child(tag)
		var tag_box := Vector2(size * 0.58, size * 0.30)
		Shapes.lit(tag, Shapes.rounded_rect(-tag_box * 0.5, tag_box,
			tag_box.y * 0.46), Color(1.0, 0.84, 0.43), 0.52)
		var badge_size := minf(size * 0.42, tag_box.y * 1.18)
		var sample_id := sample.get_file().get_basename() if sample.begins_with("res://") \
			else sample
		var badge: Control = VisualArt.crop_badge(sample_id, badge_size,
			"BasketSample3DBadge")
		if badge == null:
			badge = UiKit.picture(sample, badge_size)
		if badge != null:
			badge.position = Vector2.ONE * (-badge_size * 0.5)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag.add_child(badge)
			_label = badge
		if "golden" in accepts:
			var star := UiKit.picture("star", maxf(badge_size * 0.62, 18.0))
			if star != null:
				star.name = "GoldenBasketMarker"
				star.position = Vector2(-badge_size * 0.57, -badge_size * 0.60)
				star.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tag.add_child(star)


## A fixed yellow ring and warm halo say "this basket" without requiring a
## child to notice a scale change. They are children of the basket, not a new
## HUD or second destination rule; HarvestAction alone decides when this cue
## is on through its shared `_basket_accepts` resolver.
func _build_waiting_cue(size: float) -> void:
	_waiting_cue = Node2D.new()
	_waiting_cue.name = "WaitingCue"
	_waiting_cue.z_index = -1
	_waiting_cue.visible = false
	add_child(_waiting_cue)

	var glow := Shapes.glow(_waiting_cue, Vector2.ZERO, size * 0.72,
		Palette.YELLOW, 5, 0.60)
	glow.name = "WaitingGlow"

	var ring := Line2D.new()
	ring.name = "TargetRing"
	ring.points = Shapes.oval_points(Vector2(0.0, size * 0.06),
		Vector2(size * 0.56, size * 0.46), 28)
	ring.closed = true
	ring.width = maxf(size * 0.075, 8.0)
	ring.default_color = Palette.YELLOW
	ring.antialiased = true
	_waiting_cue.add_child(ring)


## Would this crop belong here?
##
## A basket with no tags takes everything. Otherwise the crop has to carry at
## least one of the tags -- ANY of them, not all: "fruit" and "red" on the same
## basket means "fruit or red", which is how a child would read two pictures
## sitting side by side.
func takes(crop: Dictionary) -> bool:
	if accepts.is_empty():
		return true
	var tags: Array = crop.get("tags", [])
	for tag in accepts:
		if tag in tags:
			return true
	return false


func in_reach(at: Vector2) -> bool:
	return global_position.distance_to(at) <= radius


## Yes, that one belongs here.
func accept() -> void:
	if _accepted_cue != null and is_instance_valid(_accepted_cue):
		_accepted_cue.queue_free()
	_accepted_cue = null
	if not Juice.motion_enabled():
		_show_accepted_cue()
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.12, 0.9), 0.09)
	t.tween_property(self, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if has_meta("basket_3d"):
		var b3d: Node3D = get_meta("basket_3d", null) as Node3D
		if b3d != null and is_instance_valid(b3d):
			var base_s: Vector3 = b3d.get_meta("base_scale", b3d.scale)
			var bt := b3d.create_tween()
			bt.tween_property(b3d, "scale", Vector3(base_s.x * 1.18, base_s.y * 0.82, base_s.z * 1.18), 0.09)
			bt.tween_property(b3d, "scale", base_s, 0.16)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Still does not mean silent. A fixed check on the actual basket answers
## "where did it go?" when the crop itself is intentionally not animated
## across the field. It expires without moving or bouncing.
func _show_accepted_cue() -> void:
	var cue := Node2D.new()
	cue.name = "AcceptedCue"
	cue.z_index = 2
	add_child(cue)
	var check: Control = UiKit.picture("check", _size * 0.48)
	if check != null:
		check.position = Vector2(-_size * 0.24, -_size * 0.72)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cue.add_child(check)
	_accepted_cue = cue
	# A second landing replaces this receipt. Its own tween dies with it,
	# rather than leaving a tree timer holding a freed Node in a closure.
	var lifetime := cue.create_tween()
	lifetime.tween_interval(0.72)
	lifetime.tween_callback(_finish_accepted_cue.bind(cue.get_instance_id()))


func _finish_accepted_cue(instance_id: int) -> void:
	if not is_instance_valid(_accepted_cue) \
			or _accepted_cue.get_instance_id() != instance_id:
		return
	_accepted_cue.queue_free()
	_accepted_cue = null


## "Something is waiting to go in one of us."
##
## Turned on the moment a crop is picked in a sorting level and off again as
## soon as it is put away, so the baskets are only asking for attention at the
## one moment they are what to do next. A thing that pulses all the time is
## wallpaper, and a six-year-old stops seeing it within a minute.
func waiting(on: bool) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
		_pulse = null
	scale = Vector2.ONE
	if _waiting_cue != null and is_instance_valid(_waiting_cue):
		_waiting_cue.visible = on
	# The static cue is the actual answer. Breathing is deliberately optional:
	# reduce-motion must make the screen calmer, not make its next step vanish.
	if not on or not Juice.motion_enabled():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2(1.07, 1.07), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "scale", Vector2.ONE, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## No -- and said with a shake, not a buzzer.
func refuse() -> void:
	# See harvest_target.refuse: the nudge restores its origin first.
	Juice.nudge(self, 8.0)
