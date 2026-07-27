extends RefCounted
## 怪兽图鉴 -- the monsters he has met, and the ones still out there.
##
##     const Album := preload("res://scripts/reward/monster_album.gd")
##
## Not a `class_name`, same as every shared helper here: an unknown class name
## is a parse error on a machine whose editor has not rescanned, and that greys
## the whole game rather than one screen.
##
##
## WHY THIS FILE EXISTS
##
## There was already an album: a shelf of four silhouettes, filled by the
## adventure levels through _remember_monster(). That half worked -- beat a
## walker, get a card.
##
## What did not work is everything else. The DUELS recorded nothing at all, so
## the six biggest monsters in the game -- the one at the end of every world,
## the fight a child actually tells you about -- left no trace in the book. And
## the shelf drew them all with the same generic "monster" icon in four tints,
## so the creature he beat and the card he collected were two different
## drawings and only one of them was his.
##
## Underneath that was a bigger waste. The monster builder takes colours,
## horns, spikes, eye count, proportions and a tail. Every duel level passed it
## `{"scale": 1.15}` and nothing else, so all six bosses on the island were the
## same purple creature at six different sizes. The kaiju designer was already
## written; nobody had ever filled in the form.
##
## So: data/monsters.json is that form, filled in ten times. It is the ONE
## source for what a monster looks like, which is what stops the creature in
## the fight and the card in the book from ever drifting apart again.
##
## The designs are cartoon originals drawn by the game's own Shapes code, with
## silhouettes borrowed from the kaiju archetypes a six-year-old already knows:
## the one with the nose horn and the heavy tail, the striped eel with horns
## for eyes, the one with the enormous forearms. Reference for the SHAPE, not
## the artwork -- which is also why nothing here downloads a picture, and why
## every monster still looks like it belongs to this island.

const SAVE_KEY := "album"


static func all() -> Array:
	return GameData.monsters


static func get_monster(monster_id: String) -> Dictionary:
	for entry in GameData.monsters:
		if str(entry.get("id", "")) == monster_id:
			return entry
	return {}


static func met(monster_id: String) -> bool:
	return SaveManager.has_met(monster_id)


static func met_count() -> int:
	var n := 0
	for entry in GameData.monsters:
		if met(str(entry.get("id", ""))):
			n += 1
	return n


static func total() -> int:
	return GameData.monsters.size()


## He beat one. Returns true the FIRST time, so a level can make a small fuss
## about it exactly once and stay quiet on every replay.
##
## Beaten, not merely seen: a card he earns by winning is worth more than one
## he gets for walking past, and it means the album is a record of what he did
## rather than of where he has been.
static func beat_monster(monster_id: String) -> bool:
	if monster_id == "" or get_monster(monster_id).is_empty():
		return false
	return SaveManager.record_meeting(monster_id)


## The config the monster builder wants, straight from the album entry. One
## source for what a monster looks like, so the creature in the duel and the
## card in the album can never drift apart.
static func build_config(monster_id: String, scale: float = 1.0) -> Dictionary:
	var entry := get_monster(monster_id)
	if entry.is_empty():
		return {"id": monster_id}
	var config := entry.duplicate(true)
	config["height"] = float(config.get("height", 300.0)) * scale
	return config
