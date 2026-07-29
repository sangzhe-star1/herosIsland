extends RefCounted
## The farm's five levels: one rising number, and the ladder it climbs.
##
##     const Level := preload("res://scripts/garden/farm_level_manager.gd")
##
## WHY XP CANNOT BE FARMED
##
## There is no add_xp(n) for screens to call with whatever they like. There is
## award(kind), and the three kinds are paid ONLY from inside the three gates
## that already exist: a harvest's plant-cycle ledger, an order's delivered
## list, the bear's help_owed flag. An event that cannot happen twice cannot
## pay twice, so the xp needs no ledger of its own -- it inherits three.
##
## WHY THE LEVEL IS COMPUTED, NOT STORED
##
## farm_level the FIELD is a copy, kept because the cross-tablet merge wants a
## number it can maxi(). The truth is level_of(farm_xp), recomputed on every
## ask: a stored level and a stored xp are two numbers that can disagree, and
## the day they do, one child has a level-5 farm with a level-2 ladder drawn
## under it. award() writes both from the same arithmetic in the same line.

const Farm := preload("res://scripts/garden/farm_save.gd")


static func xp() -> int:
	return maxi(0, int(SaveManager.data.get("farm", {}).get("farm_xp", 0)))


## Which level this much xp has climbed to: the highest rung whose threshold
## is paid for. The table arrives sorted from GameData, so this is a walk.
static func level_of(points: int) -> int:
	var reached := 1
	for row in GameData.farm_level_table():
		if points >= int(row.get("xp", 0)):
			reached = maxi(reached, int(row.get("level", 1)))
	return reached


static func level() -> int:
	return level_of(xp())


## The next threshold ahead of this much xp, or -1 from the top of the ladder.
static func next_at() -> int:
	var points := xp()
	for row in GameData.farm_level_table():
		if int(row.get("xp", 0)) > points:
			return int(row.get("xp", 0))
	return -1


## How far along the current rung he is, 0..1, and 1.0 at the top for ever --
## a full bar, not an empty one: the ladder ending is not a thing going wrong.
static func progress() -> float:
	var ahead := next_at()
	if ahead < 0:
		return 1.0
	var floor_xp := 0
	for row in GameData.farm_level_table():
		var at := int(row.get("xp", 0))
		if at <= xp():
			floor_xp = maxi(floor_xp, at)
	if ahead <= floor_xp:
		return 1.0
	return clampf(float(xp() - floor_xp) / float(ahead - floor_xp), 0.0, 1.0)


## Pay one event's worth of xp. Returns [level before, level after], so the
## caller can tell a level-up from an ordinary day without asking twice.
## Writes the farm but does NOT save: every caller is already inside a
## transaction that ends in its own save_game(), and a second save between
## the gate and the goods is a torn-save shape this project has met before.
static func award(kind: String) -> Array:
	var before := level()
	var points := GameData.farm_xp_for(kind)
	if points <= 0:
		return [before, before]
	var farm: Dictionary = SaveManager.data["farm"]
	farm["farm_xp"] = maxi(0, int(farm.get("farm_xp", 0))) + points
	var after := level_of(int(farm["farm_xp"]))
	farm["farm_level"] = after
	return [before, after]
