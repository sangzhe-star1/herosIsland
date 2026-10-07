extends Node2D
## The guard dog: a pointer with a tail.
##
## WHAT THE DOG IS FOR
##
## He runs to the most interesting thing on the farm and sits beside it --
## ripe beds first, then a caterpillar to grumble at, then the visitor board
## when something new is on it, then home to the kennel. A child who cannot
## read follows a dog perfectly; a red badge with a number in it he cannot
## follow at all. That is the dog's whole job.
##
## WHAT THE DOG IS NOT
##
## Not a pet sim. No hunger, no injury, no leaving, no state on disk -- a dog
## that can be neglected is a lever for guilt, and this game does not pull
## that one. And not an obstacle: he draws behind everything that matters and
## he sits a full sit_gap away from any bed's centre. He receives exactly ONE
## input, checked after everything that matters and before bare grass: a hand
## on his head gets a wag and a couple of hearts, and nothing else -- no
## counter, no gratitude meter, nothing a child can forget to do. A dog you
## have to tap around is a dog in the way; a dog who answers a hello is a
## friend.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Layout := preload("res://scripts/garden/farm_layout.gd")
const NpcFarm := preload("res://scripts/garden/npc_farm_manager.gd")
const DogManager := preload("res://scripts/garden/farm_dog_manager.gd")

var _pup: Node2D
## The red scarf, worn from the first friendship star onward. DERIVED, not
## stored: friendship only rises, so the scarf can never be lost, and a fact
## that is computed cannot disagree with the save it came from. It is the
## story chain's last beat -- the child comes home from the bear's farm and
## his dog is wearing the thank-you.
var _scarf: Node2D
var _target := Vector2.ZERO
var _speed := 240.0
var _sit_gap := 130.0
var _kennel := Vector2.ZERO
var _walking := false
## True for the half second his cheer lasts. Not a MOOD, not a bond meter:
## just the door that stops a second press restarting the same wag.
var _petting := false
var _performing_trick := false
var _digging := false
var _on_dig_completed: Callable


func _ready() -> void:
	var config: Dictionary = GameData.farm_dog
	_speed = maxf(80.0, float(config.get("speed", 240)))
	_sit_gap = maxf(96.0, float(config.get("sit_gap", 130)))
	var DogSprite := preload("res://scripts/garden/farm_dog_sprite.gd")
	_pup = DogSprite.new() if DogSprite.available() \
		else preload("res://scripts/world/puppy_art.gd").new()
	add_child(_pup)
	_pup.set_height(maxf(48.0, float(config.get("height", 96))))
	var kennel := Layout.facility("kennel")
	_kennel = Layout.facility_at(kennel) + Vector2(0, 40)
	position = _kennel
	_target = _kennel
	_dress()


## Where should the dog be, given what the farm looks like? Called after every
## refresh -- the same moments the beds redraw -- so he reacts to what the
## child just did without anything ticking to keep him up to date.
##
## The seat is beside the bed, never on it: sit_gap past the centre, on the
## kennel's side so he reads as having RUN there. bed_under() cannot see him
## anyway (he takes no input), but a dog SITTING on the carrot would say the
## carrot is his.
## Fetch: he is running to a thrown stick, or bringing it back.
var _fetching := false
var _bringing := false
var _stick: Node = null
var _return_to := Vector2.ZERO


func can_fetch() -> bool:
	return not _fetching and not _bringing and not _petting and not _digging and not _performing_trick


## A stick landed there. Off he goes; when he has it he comes back to where
## he was heading before and cheers. Nothing is written down.
func fetch(to: Vector2, stick: Node) -> void:
	if not can_fetch():
		if stick != null and is_instance_valid(stick):
			stick.queue_free()
		return
	_fetching = true
	_stick = stick
	_return_to = _target
	_target = to


func retarget(plots: Array, log_unread: bool) -> void:
	var interesting := -1
	for want in [Farm.READY, ""]:
		for i in range(plots.size()):
			var plot: Dictionary = plots[i]
			if want == Farm.READY and Farm.is_ready(plot):
				interesting = i
				break
			if want == "" and str(plot.get("care_event", "")) == Growth.CARE_BUG:
				interesting = i
				break
		if interesting >= 0:
			break

	_dress()
	var seat := _kennel
	if interesting >= 0:
		var bed := Layout.plot_at(interesting)
		var away := (_kennel - bed).normalized()
		if away == Vector2.ZERO:
			away = Vector2(0, 1)
		seat = bed + away * _sit_gap
	elif log_unread:
		seat = Layout.facility_at(Layout.facility("visit_board")) \
			+ Vector2(0, 52)
	# Mid-fetch the stick comes first; the new seat is where he brings it.
	if _fetching or _bringing:
		_return_to = seat
	else:
		_target = seat


## Put the scarf on (or notice it is already on). Called from every
## retarget, which runs on every refresh -- so the walk home from the bear's
## farm is exactly long enough for the scarf to be there when he looks.
func _dress() -> void:
	var earned := NpcFarm.friendship() >= 1
	if not earned or (_scarf != null and is_instance_valid(_scarf)):
		return
	if _pup == null or not is_instance_valid(_pup):
		return
	var height := maxf(48.0, float(GameData.farm_dog.get("height", 96)))
	_scarf = Node2D.new()
	_scarf.position = Vector2(0, -height * 0.46)
	add_child(_scarf)
	Shapes.fill(_scarf, Shapes.rounded_rect(
		Vector2(-height * 0.20, 0), Vector2(height * 0.40, height * 0.12), 5.0),
		Color(0.83, 0.31, 0.27), 0.8)
	Shapes.fill(_scarf, Shapes.rounded_rect(
		Vector2(height * 0.04, height * 0.10), Vector2(height * 0.11, height * 0.20),
		4.0), Color(0.83, 0.31, 0.27), 0.8)


## Was this glass point ON the dog? He is small and he moves, so the reach is
## his own height, read through the camera like every other reach on this
## screen -- a radius in world units would shrink to nothing at the overview
## zoom and grow to a bed-sized blob up close.
func pet_at(at: Vector2, camera) -> bool:
	if _pup == null or not is_instance_valid(_pup) or _petting or _digging or _performing_trick:
		return false
	var height := maxf(48.0, float(GameData.farm_dog.get("height", 96)))
	var core: Vector2 = camera.world_to_screen(
		position + Vector2(0.0, -height * 0.5))
	return at.distance_to(core) <= height * 0.55 * camera.zoom


## A hand landed on him. He pops into a cheer for a beat -- hearts, a sound,
## and NOTHING else: no counter, no gratitude meter, nothing written down.
## Petting is a greeting, not a duty; mid-reaction presses land on a dog who
## is already happy, and when it ends he goes back to whatever he was doing.
func pet() -> void:
	if _petting or not is_inside_tree() or _digging or _performing_trick:
		return
	_petting = true
	var config: Dictionary = GameData.farm_dog
	var seconds := maxf(0.4, float(config.get("pet_seconds", 0.9)))
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	var farm: Dictionary = SaveManager.data.get("farm", {})
	var tricks: Array = DogManager.tricks_unlocked(farm)
	var active_trick := ""
	if not tricks.is_empty():
		active_trick = str(tricks[randi() % tricks.size()])
		if _pup != null and is_instance_valid(_pup) and _pup.has_method("set_trick"):
			_pup.call("set_trick", active_trick)
	if active_trick == "" and _pup != null and is_instance_valid(_pup):
		_pup.set_pose(HeroArt.Pose.CHEER)
	if Juice.motion_enabled():
		var height := maxf(48.0, float(config.get("height", 96)))
		for i in range(maxi(1, int(config.get("pet_hearts", 3)))):
			var heart := UiKit.picture("heart", 30.0)
			if heart == null:
				continue
			heart.name = "PetHeart"
			heart.position = Vector2((float(i) - 1.0) * 28.0, -height * 0.95)
			heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(heart)
			var t := heart.create_tween()
			t.tween_property(heart, "position",
				heart.position + Vector2(0.0, -46.0), seconds)				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(heart, "modulate:a", 0.0, seconds)
			t.tween_callback(heart.queue_free)
	await get_tree().create_timer(seconds).timeout
	_petting = false
	if not is_inside_tree() or _walking or _digging:
		return
	if _pup != null and is_instance_valid(_pup):
		if _pup.has_method("set_trick"):
			_pup.call("set_trick", "")
		_pup.set_pose(HeroArt.Pose.BEAM)


func do_trick(trick_id: String, duration: float = 1.4) -> void:
	if _performing_trick or not is_inside_tree():
		return
	_performing_trick = true
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	if _pup != null and is_instance_valid(_pup):
		if _pup.has_method("set_trick"):
			_pup.call("set_trick", trick_id)
		else:
			_pup.set_pose(HeroArt.Pose.CHEER)
	if Juice.motion_enabled():
		var height := maxf(48.0, float(GameData.farm_dog.get("height", 96)))
		var star := UiKit.picture("sparkle", 32.0)
		if star != null:
			star.position = Vector2(0.0, -height * 0.95)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(star)
			var t := star.create_tween()
			t.tween_property(star, "position", star.position + Vector2(0.0, -36.0), duration)
			t.parallel().tween_property(star, "modulate:a", 0.0, duration)
			t.tween_callback(star.queue_free)
	await get_tree().create_timer(duration).timeout
	_performing_trick = false
	if not is_inside_tree() or _walking or _digging:
		return
	if _pup != null and is_instance_valid(_pup):
		if _pup.has_method("set_trick"):
			_pup.call("set_trick", "")
		_pup.set_pose(HeroArt.Pose.BEAM)


func dig_to(spot_pos: Vector2, on_completed: Callable) -> void:
	if _fetching or _bringing or _digging or _performing_trick:
		return
	_digging = true
	_return_to = _target
	_target = spot_pos
	_on_dig_completed = on_completed


func _process(delta: float) -> void:
	if _pup == null or not is_instance_valid(_pup):
		return
	var gap := position.distance_to(_target)
	if gap > 6.0:
		if not _walking:
			_walking = true
			_pup.set_pose(HeroArt.Pose.WALK)
		var step := _speed * delta
		position = position.move_toward(_target, step)
		_pup.scale.x = -1.0 if _target.x < position.x else 1.0
	elif _fetching:
		# Got it. The stick is in his mouth now, which is to say gone. Judged
		# by where he IS, not by whether he walked there: a dog already
		# standing on the spot picks it up too.
		_walking = false
		_fetching = false
		if _stick != null and is_instance_valid(_stick):
			_stick.queue_free()
		_stick = null
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		_bringing = true
		_target = _return_to
	elif _bringing:
		_walking = false
		_bringing = false
		var farm: Dictionary = SaveManager.data.get("farm", {})
		var fetch_res := DogManager.record_fetch(farm)
		SaveManager.save_game()
		var latest_trick: String = str(fetch_res.get("latest_trick", ""))
		if latest_trick != "":
			do_trick(latest_trick)
		else:
			pet()
	elif _digging:
		_walking = false
		_digging = false
		if _pup != null and is_instance_valid(_pup) and _pup.has_method("set_trick"):
			_pup.call("set_trick", "dig")
		AudioManager.play_sfx("res://assets/audio/rustle.ogg")
		await get_tree().create_timer(1.1).timeout
		if _on_dig_completed.is_valid():
			_on_dig_completed.call()
		if _pup != null and is_instance_valid(_pup):
			if _pup.has_method("set_trick"):
				_pup.call("set_trick", "")
			_pup.set_pose(HeroArt.Pose.CHEER)
		AudioManager.play_sfx("res://assets/audio/found.ogg")
		pet()
		_target = _return_to
	elif _walking:
		_walking = false
		_pup.set_pose(HeroArt.Pose.BEAM)
