extends Control
## The stage: one big hero, and everything a child can do to him by touching.
##
## The old Hero House put the character inside a 176-340 px card, fifth item
## down a vertical list, at about a quarter of the screen -- so the thing being
## dressed was smaller than the menu for dressing it. Here the hero is the
## page: he stands on a lit platform in the middle, at 75% of the stage height,
## and the clothes are what surround him.
##
## What a finger can do:
##   tap the hero          a random happy action
##   tap what he is wearing jumps to that drawer of the wardrobe
##   drag left or right    turns him
##   press and hold        a full show-off routine
##
## The turn is a real turn, not four camera angles. `HeroArt.spin()` has been
## in the codebase since the adventure levels and nothing had ever called it.
## True front/side/back views would mean drawing the hero and all 84 garments
## three more times -- 250-odd pictures -- to gain "you can see the back of the
## cape". The spin gives the feeling of turning him for the cost of a tween.

const Shapes := preload("res://scripts/world/shapes.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")
const Art := preload("res://scripts/reward/monster_art.gd")

signal slot_tapped(slot: String)
signal poked()

## Where each worn piece sits on screen, as a fraction of the hero's height
## above his feet -- used to turn a tap into "he touched the hat".
const HIT_ZONES := [
	["head", 0.78, 1.05],
	["body", 0.42, 0.78],
	["hands", 0.30, 0.55],
	["feet", 0.00, 0.18],
]
const ACTIONS := ["act_wave", "act_spin", "act_hero", "act_jump",
	"act_victory", "act_star"]

var hero: SkinnedCharacter
var _floor_y := 0.0
var _hero_h := 0.0
var _drag_from := 0.0
var _dragging := false
var _turned := 0.0
var _held := 0.0
var _pressing := false
var _rng := RandomNumberGenerator.new()
var _next_action := 0
var _hint: Label


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)
	set_process(true)


## Build the platform and stand the hero on it. Called once the Control has a
## real size, because everything here is measured from that.
func build(character_id: String) -> void:
	for child in get_children():
		child.queue_free()
	hero = null

	var box := size
	# This Control is now exactly the standing area -- the row of hero faces
	# sits BELOW it, not inside it. The first screenshot had the faces strip
	# painted over the platform, so the hero appeared to hover in mid-air with
	# no ground at all. Everything here is a fraction of the standing area, and
	# the platform is drawn shallow enough to finish inside it.
	_floor_y = box.y * 0.85
	# 0.80 of the standing area for the FIGURE. A hat stands above the head, so
	# the silhouette a child actually sees is nearer 0.88 -- comfortably past
	# the number the brief is asking for. Measuring the figure instead would
	# push the hat up into the title.
	_hero_h = box.y * 0.80

	var art := Node2D.new()
	art.name = "Stage"
	add_child(art)

	# A soft round platform, a rug and a ring of light. Deliberately plain: the
	# brief asks for nothing that competes with the child's own creation.
	Shapes.fill(art, Shapes.oval_points(Vector2(box.x * 0.5, _floor_y + 22.0),
		Vector2(box.x * 0.36, box.y * 0.055), 40), Color(0.62, 0.78, 0.96, 0.30), 0.0)
	Shapes.fill(art, Shapes.oval_points(Vector2(box.x * 0.5, _floor_y + 15.0),
		Vector2(box.x * 0.30, box.y * 0.042), 40), Color(0.90, 0.95, 1.0, 0.92), 0.0)
	Shapes.fill(art, Shapes.oval_points(Vector2(box.x * 0.5, _floor_y + 10.0),
		Vector2(box.x * 0.24, box.y * 0.030), 36), Color(1.0, 1.0, 1.0, 0.75), 0.0)
	Shapes.glow(art, Vector2(box.x * 0.5, _floor_y - _hero_h * 0.45),
		box.x * 0.42, Color(1.0, 0.94, 0.72), 5, 0.16)

	hero = SkinnedCharacter.new()
	var skin: CharacterSkin = GameData.skin_for(character_id)
	if skin != null:
		hero.skin = skin
	hero.position = Vector2(box.x * 0.5, _floor_y)
	add_child(hero)
	hero.set_height(_hero_h)

	# No "tap me" caption. The subtitle already says it, and a second line of
	# text under the hero is one more thing between him and the toy.


## The lowest pixel of the painted platform. The probe uses this to prove the
## hero is standing on visible ground rather than on top of the face row.
func ground_bottom() -> float:
	return _floor_y + 22.0 + size.y * 0.055


func hero_height() -> float:
	return _hero_h


## The companion is no longer the stage's business. It hangs off
## SkinnedCharacter, so it walks with the hero in every level as well as
## standing beside him here -- and there is one implementation instead of two
## that drift apart.
func try_on(overrides: Dictionary) -> void:
	if hero != null and is_instance_valid(hero):
		hero.preview_outfit(overrides)


func stop_trying() -> void:
	if hero != null and is_instance_valid(hero):
		hero.clear_preview()


func refresh() -> void:
	if hero != null and is_instance_valid(hero):
		hero.refresh_outfit()


## The little show a new piece gets: half a turn, then a happy action.
func show_off(delay: float = 0.0) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var art = hero.get("_art")
	if art != null and is_instance_valid(art):
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		if not is_instance_valid(hero):
			return
		art.spin(0.5, 0.34)
	await get_tree().create_timer(0.36).timeout
	if is_instance_valid(hero):
		hero.celebrate()


func play_random_action() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	# Cycled rather than rolled: six random draws in a row will repeat one
	# three times and a child reads that as "it is broken".
	_next_action = (_next_action + 1) % ACTIONS.size()
	hero.play_action(ACTIONS[_next_action])
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	poked.emit()


# --- touch ----------------------------------------------------------------

func _on_input(event: InputEvent) -> void:
	if UiKit.is_press(event):
		_drag_from = _local(event).x
		_dragging = false
		_pressing = true
		_held = 0.0
		accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not _pressing:
			return
		var dx: float = _local(event).x - _drag_from
		if absf(dx) > 18.0:
			_dragging = true
			_turn(dx)
	elif UiKit.is_release(event):
		if not _pressing:
			return
		_pressing = false
		if _dragging:
			_settle()
		elif _held < 0.6:
			_tap(_local(event))
		_dragging = false
		accept_event()


func _process(delta: float) -> void:
	if not _pressing or _dragging:
		return
	_held += delta
	if _held >= 0.6:
		# A long press is the full routine, and it fires once: the flag flips
		# to "dragging" so releasing does not also count as a tap.
		_pressing = false
		_dragging = true
		_full_show()


func _local(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position - global_position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position - global_position
	return Vector2.ZERO


## Follow the finger. Not a real rotation -- the figure squeezes horizontally
## and flips past the halfway point, which is what a paper doll does when you
## turn it and is entirely convincing at this size.
func _turn(dx: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_turned = clampf(dx / 220.0, -1.0, 1.0)
	var squeeze: float = cos(_turned * PI * 0.5)
	hero.scale = Vector2(maxf(absf(squeeze), 0.12) * signf(squeeze if squeeze != 0.0 else 1.0), 1.0)


func _settle() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	_turned = 0.0
	if not Juice.motion_enabled():
		hero.scale = Vector2.ONE
		return
	var t := hero.create_tween()
	t.tween_property(hero, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")


## A tap on a piece he is wearing opens that drawer; a tap anywhere else on
## him is just a poke, and he does something.
func _tap(at: Vector2) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var up: float = (_floor_y - at.y) / maxf(_hero_h, 1.0)
	var across: float = absf(at.x - size.x * 0.5) / maxf(size.x * 0.5, 1.0)
	if across < 0.42:
		for zone in HIT_ZONES:
			if up >= float(zone[1]) and up < float(zone[2]):
				var slot := str(zone[0])
				if Shop.equipped_in(slot) != "":
					_flash()
					slot_tapped.emit(slot)
					return
				break
	play_random_action()


func _flash() -> void:
	if hero == null or not is_instance_valid(hero) or not Juice.motion_enabled():
		return
	var t := hero.create_tween()
	t.tween_property(hero, "modulate", Color(1.25, 1.25, 1.15), 0.10)
	t.tween_property(hero, "modulate", Color.WHITE, 0.18)


func _full_show() -> void:
	if hero == null or not is_instance_valid(hero):
		return
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	hero.play_action("act_hero")
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(hero):
		return
	var art = hero.get("_art")
	if art != null and is_instance_valid(art):
		art.spin(1.0, 0.6)
	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(hero):
		hero.victory()
