extends Node2D
## The farm's small motions: sails that turn, a duck that bobs, hens that
## peck, butterflies that wander. Scenery only -- nothing here is a target,
## nothing reads the save, and everything holds still under reduced motion.
## FarmWorldArt registers each moving sprite with the kind of life it has.

var _alive: Array = []        # [{sprite, kind, base, phase, speed, path, t}]
var _t := 0.0


func add(sprite: Control, kind: String, spec: Dictionary) -> void:
	_alive.append({"sprite": sprite, "kind": kind, "base": sprite.position,
		"phase": float(spec.get("phase", 0.0)), "speed": float(spec.get("speed", 1.0)),
		"path": spec.get("path", []), "leg": 0, "t": 0.0})


## The sprite under a press, if it is one that answers (duck, hen). The hop
## is a short impulse the bob/peck motion rides on top of.
func poke_at(screen_at: Vector2) -> String:
	for life in _alive:
		var sprite: Control = life["sprite"]
		if not is_instance_valid(sprite) or str(life["kind"]) == "flutter":
			continue
		if sprite.get_global_rect().grow(8.0).has_point(screen_at):
			_hop(life)
			return str(sprite.get_meta("prop_id", ""))
	return ""


func poke_kind(kind: String) -> void:
	for life in _alive:
		var sprite: Control = life["sprite"]
		if is_instance_valid(sprite) and str(sprite.get_meta("prop_id", "")) == kind:
			_hop(life)


func _hop(life: Dictionary) -> void:
	life["hop"] = 0.5
	var sprite: Control = life["sprite"]
	if Juice.motion_enabled():
		Juice.pop(sprite, 0.16)


func _process(delta: float) -> void:
	if not Juice.motion_enabled():
		return
	_t += delta
	for life in _alive:
		var sprite: Control = life["sprite"]
		if not is_instance_valid(sprite):
			continue
		var base: Vector2 = life["base"]
		var phase: float = life["phase"]
		var hop := 0.0
		if float(life.get("hop", 0.0)) > 0.0:
			life["hop"] = float(life["hop"]) - delta
			hop = sin(clampf(float(life["hop"]) / 0.5, 0.0, 1.0) * PI) * 14.0
		match str(life["kind"]):
			"spin":
				sprite.rotation += delta * float(life["speed"])
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
	# The sprite is anchored by its pivot; keep that anchor on the path.
	sprite.position = at - (sprite.pivot_offset)
	sprite.scale.y = 0.55 + 0.45 * absf(cos(_t * 11.0))
	sprite.flip_h = to.x < from.x
