class_name VariantPicker
extends RefCounted
## Making a level different the second time, without ever making it broken.
##
## The brief asks for replay variation -- different hiding places, different
## objects to find, a different order of lights -- and then draws the line in
## exactly the right spot: **"random content must come from pre-verified
## combinations; it must never generate an unfinishable level."**
##
## So this does not generate anything. It PICKS, from lists a person wrote
## down, using a seed that changes per play-through but is stable within one.
## The worst thing it can produce is a combination somebody already looked at.
##
## The seed is the level id plus how many times the level has been finished,
## so:
##   * a child's first run is the same for every child (we can test it)
##   * a replay is different (that is the point)
##   * a replay INTERRUPTED and resumed is the same (nothing shuffles under
##     their hands halfway through)

var _rng := RandomNumberGenerator.new()
var _level_id := ""
var _round := 0


func _init(level_id: String, times_finished: int = 0) -> void:
	_level_id = level_id
	_round = times_finished
	_rng = Shapes.rng_for("%s#%d" % [level_id, times_finished])


## Which run through this level is this? Templates use it to add a little
## more on later visits -- one more hidden thing, a slightly longer tune.
func round_number() -> int:
	return _round


## One item from a list.
func one(options: Array):
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]


## `count` different items from a list, in a random order. Never repeats, and
## never returns fewer than asked unless the list is genuinely too short.
func some(options: Array, count: int) -> Array:
	var pool: Array = options.duplicate()
	shuffle(pool)
	return pool.slice(0, mini(count, pool.size()))


## In place, with THIS picker's seed. `Array.shuffle()` uses Godot's global
## generator, which would re-deal on every load and break the promise above.
func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap


func number(low: float, high: float) -> float:
	return _rng.randf_range(low, high)


func whole(low: int, high: int) -> int:
	return _rng.randi_range(low, high)


func chance(probability: float) -> bool:
	return _rng.randf() < probability


## Positions for `count` things, taken from a list of hand-placed spots and
## spread out so two of them never land on top of each other.
##
## The hand-placed part is what keeps it safe: every spot in the list is
## somewhere a person decided a child can reach.
func spots(all_spots: Array, count: int, apart: float = 140.0) -> Array:
	var pool: Array = all_spots.duplicate()
	shuffle(pool)
	var out: Array = []
	for spot in pool:
		if out.size() >= count:
			break
		var ok := true
		for taken in out:
			if (taken as Vector2).distance_to(spot as Vector2) < apart:
				ok = false
				break
		if ok:
			out.append(spot)
	# If crowding left us short, fill from what is left rather than returning
	# a level with three of the five things it promised.
	for spot in pool:
		if out.size() >= count:
			break
		if not out.has(spot):
			out.append(spot)
	return out


## The picker a level should use, built from its own save data.
##
## NO RETURN TYPE, deliberately. Naming this file's own `class_name` here is
## the obvious thing to write and it is a trap: a global class name lives in
## `.godot/global_script_class_cache.cfg`, which only the EDITOR rebuilds, so
## on a machine that has not rescanned since this file was written the name
## does not exist -- INCLUDING inside the file that declares it. The script
## then fails to COMPILE, every template that calls this dies with it, and the
## child gets a grey window with nothing on it.
##
## That is exactly what happened: "公园里的光球页面空白". The templates hold
## this script as a `preload` const and annotate their own variable with that,
## which resolves by path and never touches the cache.
static func for_level(level_id: String):
	# `attempts` counts every finished run, which is exactly "how many times
	# has this child seen this level" -- the number the variation should turn on.
	var done: int = int(SaveManager.get_level_progress(level_id).get("attempts", 0))
	# `new()` on the file's own script resource, not on its global name -- same
	# reason as the missing return type above. `load(...)` here rather than a
	# `const preload` because a script preloading itself is a cycle.
	return (load("res://scripts/shared/variant_picker.gd") as GDScript).new(
		level_id, done)
