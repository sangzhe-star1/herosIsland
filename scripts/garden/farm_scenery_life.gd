extends Node2D
## The farm's small motions: sails that turn, a duck that bobs, hens that
## peck, butterflies that wander, and a friend who answers a hello.
## Scenery only -- nothing here is a gameplay target,
## nothing reads the save, and everything holds still under reduced motion.
## FarmWorldArt registers each moving sprite with the kind of life it has.

const DayCycle := preload("res://scripts/garden/farm_day_cycle.gd")

var _alive: Array = []        # [{sprite, kind, base, phase, speed, path, t}]
var _t := 0.0
const GREETING_SECONDS := 0.9


func add(sprite: Control, kind: String, spec: Dictionary) -> void:
	var hit := Rect2(Vector2.ZERO, sprite.size)
	var textured := sprite as TextureRect
	if kind == "greet" and textured != null and textured.texture != null:
		var source: Image = textured.texture.get_image()
		if source != null:
			var bounds: Rect2i = source.get_used_rect()
			var factor: Vector2 = sprite.size / Vector2(source.get_size())
			hit = Rect2(Vector2(bounds.position) * factor, Vector2(bounds.size) * factor)
	_alive.append({"sprite": sprite, "kind": kind, "base": sprite.position,
		"base_rotation": sprite.rotation, "base_scale": sprite.scale,
		"hit": hit, "hop": 0.0, "greeting_left": 0.0, "greeting": null,
		"phase": float(spec.get("phase", 0.0)), "speed": float(spec.get("speed", 1.0)),
		"path": spec.get("path", []), "leg": 0, "t": 0.0})


## The sprite under a press, if it is one that answers (duck, hen). The hop
## is a short impulse the bob/peck motion rides on top of.
func poke_at(screen_at: Vector2) -> String:
	for life in _alive:
		var sprite: Control = life["sprite"]
		if not is_instance_valid(sprite) or str(life["kind"]) == "flutter":
			continue
		var local_at := sprite.get_global_transform_with_canvas().affine_inverse() * screen_at
		var hit: Rect2 = life["hit"]
		if hit.grow(8.0).has_point(local_at):
			_hop(life)
			return str(sprite.get_meta("prop_id", ""))
	return ""


func poke_kind(kind: String) -> void:
	for life in _alive:
		var sprite: Control = life["sprite"]
		if is_instance_valid(sprite) and str(sprite.get_meta("prop_id", "")) == kind:
			_hop(life)


func _hop(life: Dictionary) -> void:
	# A held/repeated hello has one response, not one new heart per input.
	if float(life.get("greeting_left", 0.0)) > 0.0 \
			or float(life.get("hop", 0.0)) > 0.0:
		return
	life["hop"] = 0.5
	var sprite: Control = life["sprite"]
	if str(life["kind"]) != "greet":
		return
	var heart := UiKit.picture("heart", 30.0)
	if heart == null:
		return
	heart.name = "FriendGreeting"
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hit: Rect2 = life["hit"]
	heart.position = Vector2(hit.get_center().x - 15.0, hit.position.y - 34.0)
	sprite.add_child(heart)
	life["greeting"] = heart
	life["greeting_base"] = heart.position
	life["greeting_left"] = GREETING_SECONDS


func _rest(life: Dictionary, sprite: Control) -> void:
	sprite.position = life["base"]
	sprite.rotation = float(life["base_rotation"])
	sprite.scale = life["base_scale"]


func _greeting_tick(life: Dictionary, delta: float, moving: bool) -> void:
	var heart: Control = life.get("greeting")
	if heart == null or not is_instance_valid(heart):
		return
	life["greeting_left"] = maxf(0.0, float(life["greeting_left"]) - delta)
	if float(life["greeting_left"]) <= 0.0:
		heart.queue_free()
		life["greeting"] = null
		return
	var progress := 1.0 - float(life["greeting_left"]) / GREETING_SECONDS
	var base: Vector2 = life["greeting_base"]
	heart.position = base - Vector2(0.0, 18.0 * progress) if moving else base
	heart.modulate.a = minf(1.0, (1.0 - progress) * 3.0) if moving else 1.0


func _process(delta: float) -> void:
	var moving := Juice.motion_enabled()
	if moving:
		_t += delta
	for life in _alive:
		var sprite: Control = life["sprite"]
		if not is_instance_valid(sprite):
			continue
		_greeting_tick(life, delta, moving)
		_rest(life, sprite)
		if not moving:
			life["hop"] = 0.0
			continue
		var base: Vector2 = life["base"]
		var base_scale: Vector2 = life["base_scale"]
		var phase: float = life["phase"]
		var hop := 0.0
		if float(life.get("hop", 0.0)) > 0.0:
			life["hop"] = float(life["hop"]) - delta
			hop = sin(clampf(float(life["hop"]) / 0.5, 0.0, 1.0) * PI) * 14.0
			sprite.scale = base_scale * (1.0 + hop / 100.0)
		match str(life["kind"]):
			"spin":
				sprite.rotation += _t * float(life["speed"])
			"bob":
				sprite.position.y = base.y + sin(_t * 1.6 + phase) * 2.5 - hop
				sprite.rotation = sin(_t * 1.1 + phase) * 0.05
			"peck":
				# A hen pecks in little bursts: a nod every so often, head down.
				var cycle := fmod(_t * 0.7 + phase, 3.0)
				sprite.rotation = -absf(sin(cycle * TAU * 2.0)) * 0.22 if cycle < 1.0 else 0.0
				sprite.position.y = base.y - hop
			"flutter":
				_flutter(life, sprite, delta)
			"greet":
				# The pivot is the feet: a quiet breath does not float the bunny.
				sprite.scale.y *= 1.0 + sin(_t * 1.8 + phase) * 0.012
				sprite.rotation += sin(_t * 2.4) * hop * 0.006
				sprite.position.y = base.y - hop * 0.45
			"lantern":
				var flicker := 0.97 + 0.03 * sin(_t * 4.6 + phase) + 0.015 * cos(_t * 7.2 + phase)
				sprite.scale = base_scale * (flicker + hop / 100.0)
				var nf := DayCycle.current_night_factor()
				sprite.modulate = Color(1.0 + 0.15 * nf, 1.0 + 0.12 * nf, 0.95 + 0.05 * nf, 1.0)
			"firefly":
				_firefly(life, sprite, delta)


func _firefly(life: Dictionary, sprite: Control, delta: float) -> void:
	var nf := DayCycle.current_night_factor()
	var visibility := clampf(nf * 1.25, 0.05, 1.0)
	var phase: float = life["phase"]
	var blink := 0.2 + 0.8 * pow(maxf(0.0, sin(_t * 2.5 + phase)), 2.0)
	sprite.modulate.a = visibility * blink

	var path: Array = life.get("path", [])
	if path.size() >= 2:
		_flutter(life, sprite, delta)
	else:
		var base: Vector2 = life["base"]
		var speed: float = life.get("speed", 1.0)
		var offset := Vector2(
			cos(_t * 1.2 * speed + phase) * 28.0 + sin(_t * 0.6 * speed) * 14.0,
			sin(_t * 1.7 * speed + phase) * 18.0 + cos(_t * 0.8 * speed) * 10.0
		)
		var holder := sprite.get_parent() as Node2D
		var origin := holder.position if holder != null else Vector2.ZERO
		sprite.position = base + offset - origin - sprite.pivot_offset


func _flutter(life: Dictionary, sprite: Control, delta: float) -> void:
	var path: Array = life["path"]
	if path.size() < 2:
		return
	var leg: int = int(life["leg"])
	var from := Vector2(float(path[leg][0]), float(path[leg][1]))
	var to_i := (leg + 1) % path.size()
	var to := Vector2(float(path[to_i][0]), float(path[to_i][1]))
	var length := maxf(from.distance_to(to), 1.0)
	life["t"] = float(life["t"]) + delta * float(life["speed"]) / length
	if float(life["t"]) >= 1.0:
		life["t"] = 0.0
		life["leg"] = to_i
		from = to
		to = Vector2(float(path[(to_i + 1) % path.size()][0]),
			float(path[(to_i + 1) % path.size()][1]))
	var at := from.lerp(to, float(life["t"]))
	at.y += sin(_t * 9.0 + float(life["phase"])) * 6.0
	# The sprite is anchored by its pivot; keep that anchor on the path. The
	# path is in the layer's space and the sprite hangs in a holder.
	var holder := sprite.get_parent() as Node2D
	var origin := holder.position if holder != null else Vector2.ZERO
	sprite.position = at - origin - sprite.pivot_offset
	sprite.scale.y = 0.55 + 0.45 * absf(cos(_t * 11.0))
	sprite.flip_h = to.x < from.x
