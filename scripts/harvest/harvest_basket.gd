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

var id := ""
## Tags this basket takes. Empty means it takes anything -- the single-basket
## case, where there is nothing to decide.
var accepts: Array = []
var radius := 120.0

var _label: Control
## The "something is waiting for you" pulse, kept so it can be stopped. A
## looping tween nobody holds on to runs until the node dies.
var _pulse: Tween


## `reach` is how far a press may land from the middle and still mean THIS
## basket. It is handed in rather than worked out from `size`, because what
## makes a reach right is how far away the next basket is -- see
## harvest_action._build_baskets, where the whole column is measured at once.
func build(spec: Dictionary, size: float, reach: float = -1.0) -> void:
	id = str(spec.get("id", "basket"))
	accepts = spec.get("accepts_tags", [])
	radius = float(spec.get("radius", reach if reach > 0.0 else size * 0.9))

	var art: Control = UiKit.picture(str(spec.get("icon", "basket")), size)
	if art != null:
		art.position = Vector2(-size * 0.5, -size * 0.5)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

	# What it takes, drawn as the thing itself rather than written as a word.
	# A child who cannot read "fruit" can recognise a strawberry.
	var sample := str(spec.get("sample", ""))
	if sample != "":
		var badge: Control = UiKit.picture(sample, size * 0.42)
		if badge != null:
			# Tucked against the basket's left shoulder rather than floating
			# above it, where two stacked baskets put one sample on top of the
			# other basket and it read as a berry sitting in the wrong one.
			badge.position = Vector2(-size * 0.86, -size * 0.44)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(badge)
			_label = badge


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
	if not Juice.motion_enabled():
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.12, 0.9), 0.09)
	t.tween_property(self, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	if not on or not Juice.motion_enabled():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "scale", Vector2(1.07, 1.07), 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "scale", Vector2.ONE, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## No -- and said with a shake, not a buzzer.
func refuse() -> void:
	if not Juice.motion_enabled():
		return
	var t := create_tween()
	var home := position
	t.tween_property(self, "position", home + Vector2(8, 0), 0.06)
	t.tween_property(self, "position", home - Vector2(8, 0), 0.06)
	t.tween_property(self, "position", home, 0.06)
