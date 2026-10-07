class_name HeroController
extends Node2D
## The hero, actually controlled.
##
## Everything the child does to the character lives here: walking, jumping,
## climbing, attacking, being hurt, getting back up. The level tells it what
## the ground is and reads where it ended up; it tells the level when
## something happened. Nothing in here knows what a level IS.
##
## The whole design brief is FORGIVENESS. A six-year-old aims badly, presses
## late, and lets go early, so:
##   * coyote time -- a jump pressed just after walking off a ledge works
##   * jump buffer -- a jump pressed just before landing works
##   * ledge magnet -- a jump that lands a few pixels short is pulled up
##   * auto-aim   -- an attack turns toward the nearest enemy by itself
##   * a fat hurtbox on enemies and a slim one on the hero
##   * invulnerability and a visible flash after every hit
## None of these are visible. All of them are the difference between "this
## game is fun" and "this game is broken".

signal landed(at: Vector2, hard: bool)
signal attacked(at: Vector2, facing: float)
signal hurt_taken(remaining: int)
signal died()                       # out of hearts -- the level respawns us

const GRAVITY := 1560.0
const MOVE_SPEED := 275.0
const JUMP_VELOCITY := -655.0
const DOUBLE_JUMP_VELOCITY := -560.0
const CLIMB_SPEED := 215.0
const COYOTE := 0.15
const JUMP_BUFFER := 0.18
## A jump that lands within this many pixels UNDER a ledge lip gets pulled
## up onto it. Without it, a child who is "nearly there" is just wrong.
const LEDGE_MAGNET := 30.0
## How far an attack will turn to find a target on its own.
const AUTO_AIM := 340.0
const ATTACK_COOLDOWN := 0.34
const ATTACK_REACH := 130.0
const HURT_INVULN := 1.2

var hearts := 3
var max_hearts := 3
var facing := 1.0
var velocity := Vector2.ZERO
var grounded := false
var double_jump_unlocked := false

var _hero: SkinnedCharacter
var _shadow: Node2D
var _platforms: Array = []          # [{rect: Rect2, node, base_y, spring, cap}]
var _ropes: Array = []              # [{x, top, bottom}]
var _enemies_provider: Callable     # () -> Array of Node2D, for auto-aim
var _ground_y := 620.0

var _dir_left := false
var _dir_right := false
var _hold_jump := false
var _buffer := 0.0
var _coyote := 0.0
var _jumps_left := 1
var _stand_on := -1
var _attack_ready := 0.0
var _invuln_until := 0.0
var _clock := 0.0
var _idle_clock := 0.0
var _frozen := false
var _climbing := false


func setup(skin: CharacterSkin, ground_y: float, height: float = 168.0) -> void:
	_ground_y = ground_y
	_shadow = Shapes.ground_shadow(self, Vector2(0, 0), 96.0, 0.38)
	_hero = SkinnedCharacter.new()
	_hero.skin = skin
	add_child(_hero)
	_hero.set_height(height)
	_jumps_left = 1


## The level owns the terrain and hands it over; the controller never builds
## geometry, so the same controller works in a park, a city and a castle.
func use_terrain(platforms: Array, ropes: Array) -> void:
	_platforms = platforms
	_ropes = ropes


## How the controller finds something to auto-aim at, without ever knowing
## what an enemy is.
func use_enemies(provider: Callable) -> void:
	_enemies_provider = provider


func figure() -> SkinnedCharacter:
	return _hero


## Where a beam or a pickup should aim for: the chest, not the feet.
func chest() -> Vector2:
	if _hero != null and is_instance_valid(_hero):
		return _hero.core_position()
	return position + Vector2(0, -90.0)


# --- what the buttons do ----------------------------------------------------

func press_left(down: bool) -> void:
	_dir_left = down


func press_right(down: bool) -> void:
	_dir_right = down


func press_jump() -> void:
	_buffer = JUMP_BUFFER
	_hold_jump = true


func release_jump() -> void:
	_hold_jump = false


## Freeze for cutscenes, puzzle cards and the moment after being hurt. The
## hero keeps standing and breathing -- frozen, not deleted.
func freeze(on: bool) -> void:
	_frozen = on
	if on:
		_dir_left = false
		_dir_right = false
		velocity.x = 0.0


## Which way the hands are ASKING to go, -1, 0 or 1 -- regardless of whether
## anything is actually moving. A level needs this to tell "walking into a
## crate" apart from "standing next to a crate": once contact with the box
## clamps the hero in place, velocity reads zero for both.
func wish_dir() -> float:
	var left: bool = _dir_left or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var right: bool = _dir_right or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	return (1.0 if right else 0.0) - (1.0 if left else 0.0)


func can_attack() -> bool:
	return _clock >= _attack_ready and not _frozen


var _combo_step := 0
var _last_attack_time := 0.0


## Swing. Turns toward the nearest enemy first, so a child who is facing the
## wrong way still hits the thing they were obviously aiming at.
## Now features a dynamic 3-hit combo (Punch -> Kick -> Tornado Finish) and aerial kick!
func attack() -> bool:
	if not can_attack():
		return false
	_attack_ready = _clock + ATTACK_COOLDOWN
	var target := _nearest_enemy()
	if target != Vector2.ZERO:
		facing = signf(target.x - position.x)
		if facing == 0.0:
			facing = 1.0
	_face()

	# Reset combo if too much time elapsed
	if _clock - _last_attack_time > 0.65:
		_combo_step = 0
	_last_attack_time = _clock

	if _hero != null and is_instance_valid(_hero):
		if not grounded:
			# Mid-air flying jump kick!
			_hero.kick(0.30)
			Juice.speed_lines(get_parent(), position + Vector2(0, -60), Vector2(facing, 0), Color(1.0, 0.9, 0.5, 0.8), 3)
		else:
			match _combo_step:
				0:
					# Hit 1: Straight Punch lunge
					_hero.punch(0.26)
					position.x += facing * 12.0
				1:
					# Hit 2: High Side Kick
					_hero.kick(0.28)
					position.x += facing * 18.0
				2, _:
					# Hit 3: Tornado Spin Finisher
					_hero.spin(1.0, 0.38)
					Juice.speed_lines(get_parent(), position + Vector2(0, -70), Vector2(facing, 0), Color(1.0, 0.8, 0.3, 0.9), 5)
					Juice.shockwave(get_parent(), position + Vector2(0, -50), 95.0, Color(1.0, 0.85, 0.4))
					Juice.screen_shake(get_parent(), 8.0, 0.16)
			_combo_step = (_combo_step + 1) % 3

	attacked.emit(position + Vector2(facing * ATTACK_REACH * 0.5, -80.0), facing)
	return true


## Where a swing reaches, as a circle the level can test things against.
func attack_area() -> Dictionary:
	return {"at": position + Vector2(facing * ATTACK_REACH * 0.55, -80.0),
		"radius": ATTACK_REACH}


func invulnerable() -> bool:
	return _clock < _invuln_until


## Being hit: one heart, a stumble, a bright flash, and a second of mercy.
## Never a knockback that throws the child off a ledge -- the hit is the
## punishment, falling because of the hit is a second one.
func take_hit(from: Vector2) -> void:
	if invulnerable() or _frozen:
		return
	hearts = maxi(hearts - 1, 0)
	_invuln_until = _clock + HURT_INVULN
	velocity.y = minf(velocity.y, -240.0)
	velocity.x = signf(position.x - from.x) * 90.0
	if _hero != null and is_instance_valid(_hero):
		_hero.stumble()
	_flash()
	Juice.screen_shake(get_parent(), 10.0, 0.20)
	Juice.hit_stop(get_tree(), 0.05)
	hurt_taken.emit(hearts)
	if hearts <= 0:
		died.emit()


func heal_full() -> void:
	hearts = max_hearts
	_invuln_until = _clock + 0.6


func place_at(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	grounded = true
	_stand_on = -1
	_jumps_left = _max_jumps()
	if _hero != null and is_instance_valid(_hero):
		_hero.set_pose(HeroArt.Pose.IDLE)


# --- the run ----------------------------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	if _hero == null or not is_instance_valid(_hero):
		return
	_flicker()
	if _frozen:
		_hero.walk(false)
		return

	# Keyboard shares the pad, so a desktop build plays identically.
	var left: bool = _dir_left or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var right: bool = _dir_right or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var holding: bool = _hold_jump or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_UP)
	var dir: float = (1.0 if right else 0.0) - (1.0 if left else 0.0)
	if dir != 0.0:
		facing = dir
		_face()

	# AFK idle emotes: standing still gives the chibi character life
	if absf(dir) > 0.05 or not grounded or _climbing or _frozen:
		_idle_clock = 0.0
	else:
		_idle_clock += delta
		if _idle_clock >= 4.5:
			_idle_clock = 0.0
			var emotes: Array[String] = ["peace", "stretch", "look_around", "flex", "wave"]
			_hero.emote(emotes[randi() % emotes.size()])

	# Ropes: stand in one and HOLD jump to climb. One button, two meanings,
	# picked by where the feet are.
	var rope := _rope_at(position)
	_climbing = false
	if not rope.is_empty() and holding:
		_climb(rope, dir, delta)
		return

	velocity.x = dir * MOVE_SPEED
	velocity.y += GRAVITY * delta
	_buffer = maxf(_buffer - delta, 0.0)
	_coyote = maxf(_coyote - delta, 0.0)
	if grounded:
		_jumps_left = _max_jumps()

	if _buffer > 0.0 and (grounded or _coyote > 0.0):
		_launch(JUMP_VELOCITY)
		_jumps_left = _max_jumps() - 1
	elif _buffer > 0.0 and _jumps_left > 0:
		_launch(DOUBLE_JUMP_VELOCITY)
		_jumps_left -= 1
		Juice.shockwave(get_parent(), position, 74.0, Color(0.86, 0.96, 1.0))
		Juice.dust(get_parent(), position, 4, 0.6)
		if _hero != null and is_instance_valid(_hero):
			_hero.spin(1.0, 0.32)

	var was_y: float = position.y
	position.x += velocity.x * delta
	position.y += velocity.y * delta

	_ride_platform()
	_land_on_something(was_y)
	_hero.walk(grounded and absf(dir) > 0.1)
	if _shadow != null and is_instance_valid(_shadow):
		if grounded:
			_shadow.scale = Vector2.ONE
			_shadow.modulate.a = 1.0
		else:
			_shadow.scale = Vector2(0.72, 0.72)
			_shadow.modulate.a = 0.50


func _launch(power: float) -> void:
	_buffer = 0.0
	_coyote = 0.0
	grounded = false
	_stand_on = -1
	velocity.y = power
	_hero.set_pose(HeroArt.Pose.JUMP)


func _climb(rope: Dictionary, dir: float, delta: float) -> void:
	_climbing = true
	grounded = false
	_stand_on = -1
	velocity = Vector2.ZERO
	_jumps_left = _max_jumps()
	position.x = lerpf(position.x, float(rope["x"]), 0.35)
	position.y = maxf(position.y - CLIMB_SPEED * delta, float(rope["top"]))
	_hero.set_pose(HeroArt.Pose.BEAM)
	_hero.walk(false)


## Standing on something that moves takes the rider with it, sideways as
## well as up. Without the sideways half, a moving platform slides out from
## under the feet and "riding" never happens.
func _ride_platform() -> void:
	if not grounded or _stand_on < 0 or _stand_on >= _platforms.size():
		return
	var entry: Dictionary = _platforms[_stand_on]
	if not _within_x(entry):
		grounded = false
		_stand_on = -1
		_coyote = COYOTE
		return
	position.y = _top_of(entry)
	var node: Variant = entry.get("node")
	if node != null and is_instance_valid(node):
		var nx: float = (node as Node2D).position.x
		position.x += nx - float(entry.get("last_x", nx))
		entry["last_x"] = nx


func _land_on_something(was_y: float) -> void:
	if velocity.y <= 0.0:
		return
	for i in range(_platforms.size()):
		var entry: Dictionary = _platforms[i]
		var top: float = _top_of(entry)
		# The magnet: a landing that fell just SHORT of the lip still counts.
		var crossed: bool = was_y <= top + 1.0 and position.y >= top
		var nearly: bool = not crossed and absf(position.y - top) <= LEDGE_MAGNET \
			and was_y < top and velocity.y > 0.0
		if not (crossed or nearly) or not _within_x(entry):
			continue
		if bool(entry.get("spring", false)):
			_bounce(entry, top)
			return
		var hard: bool = velocity.y > 900.0
		position.y = top
		velocity.y = 0.0
		if not grounded:
			landed.emit(position, hard)
			if hard and _hero != null and is_instance_valid(_hero):
				_hero.set_pose(HeroArt.Pose.SLAM)
				Juice.dust(get_parent(), position, 6, 0.8)
				Juice.shockwave(get_parent(), position, 80.0, Color(1.0, 0.9, 0.5))
				Juice.screen_shake(get_parent(), 6.0, 0.14)
				var rt := create_tween()
				rt.tween_interval(0.18)
				rt.tween_callback(func():
					if grounded and is_instance_valid(_hero) and not _frozen:
						_hero.set_pose(HeroArt.Pose.IDLE)
				)
			elif _hero != null and is_instance_valid(_hero):
				_hero.set_pose(HeroArt.Pose.IDLE)
		grounded = true
		_stand_on = i
		var node: Variant = entry.get("node")
		if node != null and is_instance_valid(node):
			entry["last_x"] = (node as Node2D).position.x
		return


func _bounce(entry: Dictionary, top: float) -> void:
	position.y = top
	velocity.y = -1000.0
	grounded = false
	_stand_on = -1
	_jumps_left = _max_jumps()
	_hero.set_pose(HeroArt.Pose.JUMP)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	Juice.dust(get_parent(), position, 5, 0.8)
	var cap: Variant = entry.get("cap")
	if cap is Node2D and is_instance_valid(cap) and Juice.motion_enabled():
		var t := (cap as Node2D).create_tween()
		t.tween_property(cap, "scale", Vector2(1.25, 0.55), 0.10)
		t.tween_property(cap, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)


func _top_of(entry: Dictionary) -> float:
	var rect: Rect2 = entry["rect"]
	var node: Variant = entry.get("node")
	if node != null and is_instance_valid(node):
		return float(entry.get("base_y", rect.position.y)) + (node as Node2D).position.y
	return rect.position.y


func _within_x(entry: Dictionary) -> bool:
	var rect: Rect2 = entry["rect"]
	var off := 0.0
	var node: Variant = entry.get("node")
	if node != null and is_instance_valid(node):
		off = (node as Node2D).position.x
	return position.x >= rect.position.x + off - 18.0 \
		and position.x <= rect.position.x + off + rect.size.x + 18.0


func _rope_at(at: Vector2) -> Dictionary:
	for rope in _ropes:
		if absf(at.x - float(rope["x"])) > 46.0:
			continue
		if at.y < float(rope["top"]) - 12.0 or at.y > float(rope["bottom"]) + 44.0:
			continue
		return rope
	return {}


func _max_jumps() -> int:
	return 2 if double_jump_unlocked else 1


func _nearest_enemy() -> Vector2:
	if _enemies_provider.is_null():
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_d := AUTO_AIM
	for node in _enemies_provider.call():
		if not is_instance_valid(node):
			continue
		var d: float = (node as Node2D).position.distance_to(position)
		if d < best_d:
			best_d = d
			best = (node as Node2D).position
	return best


func _face() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.scale.x = absf(_hero.scale.x) * (1.0 if facing >= 0.0 else -1.0)


func _flash() -> void:
	if not Juice.motion_enabled() or _hero == null:
		return
	var t := _hero.create_tween()
	t.tween_property(_hero, "modulate", Color(1.6, 0.7, 0.7), 0.08)
	t.tween_property(_hero, "modulate", Color.WHITE, 0.16)


## While invulnerable the hero blinks, so a child can SEE that the next hit
## will not land. A silent mercy window teaches nothing.
func _flicker() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	if not invulnerable():
		_hero.modulate.a = 1.0
		return
	_hero.modulate.a = 0.45 if fmod(_clock, 0.22) < 0.11 else 1.0
