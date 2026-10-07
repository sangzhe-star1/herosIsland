extends Node
## Loads all static configuration from res://data/*.json.
## Nothing in the game hardcodes level content -- add levels by editing JSON.

var worlds: Array = []
var levels: Array = []
var rewards: Dictionary = {}
## The gift shop's catalogue. Read-only game data: what he OWNS lives in the
## save, never here, so changing a price can never lose him a hat.
var shop_items: Array = []
var shop_categories: Array = []
var shop_bundles: Array = []
## 怪兽图鉴. What each monster looks like AND what goes on its album card --
## one source, so the creature in the duel and the card can never disagree.
var monsters: Array = []
## Mount points for painted clothes, and the twelve themed outfits.
var character_slots: Dictionary = {}
var outfit_presets: Dictionary = {}
var characters: Dictionary = {}
## 星光菜园. What each crop is called, how long each of its five stages takes,
## and how much comes out of the ground. Read-only: what is PLANTED lives in
## the save, so retuning a growth time can never uproot anything.
var crops: Array = []
## Who wants what, and what it is worth. Read-only: what has been DELIVERED
## lives in the save, so retuning a reward can never un-pay an order.
var garden_orders: Array = []
var garden_recipes: Array = []
var garden_dailies: Array = []
## The first-planting lesson: which crop, which bed, how fast it grows for the
## lesson only, and what the helper points at in what order.
var garden_tutorial: Dictionary = {}
## 丰收行动 的作物目录。和 crops.json 分开：菜园种的是四种会长大的东西，
## these are the fifteen a harvest level can put on the ground, and they
## carry a gesture rather than a growth curve.
var harvest_crops: Array = []
## Where everything in 星光农场 stands, in world coordinates. Read-only, and
## deliberately NOT in the save: a bed's position is a fact about the farm's
## design, not about the child's game, so moving the well in a future version
## must not require a migration. What is GROWING in a bed lives in the save and
## is matched to this by index -- see scripts/garden/farm_layout.gd.
var farm_layout: Dictionary = {}
## The seed shop's shelf: which crops are sold and for how much. Read-only;
## what he OWNS is farm.unlocked_crops in the save, so retuning a price can
## never take a crop away.
var farm_seed_shop: Dictionary = {}
## What the market box pays per crop. Read-only for the same reason: a price
## change must never reach into anyone's barn.
var farm_market_prices: Dictionary = {}
## The neighbours: who they are and what their farms look like. Their STATE is
## computed from the clock, never stored -- see npc_farm_manager.gd.
var npc_farms: Dictionary = {}
## Which lines a visitor's log entry is told with. The words themselves live
## in strings.json; this file only says which icon goes with which line.
var farm_visit_texts: Dictionary = {}
var farm_visitor_milestones: Dictionary = {}
var farm_visitor_schedule: Dictionary = {}
## The dog's numbers: speed, height, how far from a bed it sits.
var farm_dog: Dictionary = {}
## Where the farm's extra scenery stands (windmill, pond, hens...); read by
## FarmWorldArt, which skips anything that would cover a bed or a building.
var farm_dressing: Dictionary = {}
## What the farm makes without a bed (eggs). get_crop() answers for these.
var farm_produce: Dictionary = {}
var _produce_by_id: Dictionary = {}
## The farm's five levels: where each threshold sits and what each of the
## three xp sources pays. Read-only; the child's own farm_xp is in the save.
var farm_levels: Dictionary = {}
## The two beds that can be cleared, what each costs, and the animation
## numbers for the clearing. Read-only for the usual reason: retuning a cost
## must never take a bought bed away.
var farm_expansions: Dictionary = {}

var _levels_by_id: Dictionary = {}
var _worlds_by_id: Dictionary = {}
var _crops_by_id: Dictionary = {}


func _ready() -> void:
	print("[autoload] GameData starting")
	worlds = _load_json("res://data/worlds.json", [])
	levels = _load_json("res://data/levels.json", [])
	rewards = _load_json("res://data/rewards.json", {})
	characters = _load_json("res://data/characters.json", {})
	shop_items = _load_json("res://data/shop_items.json", [])
	shop_categories = _load_json("res://data/shop_categories.json", [])
	shop_bundles = _load_json("res://data/shop_bundles.json", [])
	monsters = _load_json("res://data/monsters.json", [])
	# The wardrobe: where each garment hangs on the figure, and the twelve
	# themed outfits. Loaded here with everything else so a missing file is
	# one loud error at boot rather than an empty shelf three screens in.
	character_slots = _load_json("res://data/character_slots.json", {})
	outfit_presets = _load_json("res://data/outfit_presets.json", {})
	crops = _load_json("res://data/crops.json", [])
	garden_orders = _load_json("res://data/garden_orders.json", [])
	garden_recipes = _load_json("res://data/garden_recipes.json", [])
	garden_dailies = _load_json("res://data/garden_dailies.json", [])
	garden_tutorial = _load_json("res://data/garden_tutorial.json", {})
	harvest_crops = _load_json("res://data/harvest_crops.json", [])
	farm_layout = _load_json("res://data/farm_world_layout.json", {})
	farm_seed_shop = _load_json("res://data/farm_seed_shop.json", {})
	farm_market_prices = _load_json("res://data/farm_market_prices.json", {})
	npc_farms = _load_json("res://data/npc_farms.json", {})
	farm_visit_texts = _load_json("res://data/farm_visit_texts.json", {})
	farm_visitor_milestones = _load_json("res://data/farm_visitors.json", {})
	farm_visitor_schedule = _load_json("res://data/farm_visitor_schedule.json", {})
	farm_dog = _load_json("res://data/farm_dog.json", {})
	farm_dressing = _load_json("res://data/farm_world_dressing.json", {})
	farm_produce = _load_json("res://data/farm_produce.json", {})
	for item in farm_produce.get("produce", []):
		if item is Dictionary and str(item.get("id", "")) != "":
			_produce_by_id[str(item["id"])] = item
	farm_levels = _load_json("res://data/farm_levels.json", {})
	farm_expansions = _load_json("res://data/farm_expansions.json", {})

	for c in crops:
		_crops_by_id[c.get("id", "")] = c
	for w in worlds:
		_worlds_by_id[w.get("id", "")] = w
	for l in levels:
		_levels_by_id[l.get("id", "")] = l
	_register_dropin_characters()
	# Every count, not just two.
	#
	# 怪兽图鉴 went out with one file left behind on the other machine, so the
	# game booted happily with zero monsters and the album drew an empty shelf
	# -- and the only symptom anybody could see was "it isn't there". A line
	# that says `0 monsters` at startup turns a silent half-install into
	# something you can read in two seconds.
	print("[autoload] GameData ok: %d worlds, %d levels, %d monsters, "
		% [worlds.size(), levels.size(), monsters.size()]
		+ "%d shop items, %d characters, %d outfit sets"
		% [shop_items.size(), characters.size(),
			int(outfit_presets.get("sets", []).size())])
	for pair in [["levels", levels.size()], ["worlds", worlds.size()],
			["monsters", monsters.size()], ["shop items", shop_items.size()],
			["crops", crops.size()], ["garden orders", garden_orders.size()],
			["garden recipes", garden_recipes.size()],
			["garden dailies", garden_dailies.size()],
			["garden tutorial steps", garden_tutorial.get("steps", []).size()],
			["harvest crops", harvest_crops.size()],
			# Counted by its facilities, because an empty dictionary and a
			# dictionary with a "world" key and nothing standing in it are the
			# same disaster: a farm that opens on bare ground.
			["farm layout facilities", farm_layout.get("facilities", []).size()],
			["seed shop shelf", farm_seed_shop.get("seeds", []).size()],
			["market prices", farm_market_prices.get("prices", {}).size()],
			["npc farms", npc_farms.get("farms", []).size()],
			["visit text lines",
				farm_visit_texts.get("bear", {}).get("lines", []).size()],
			["farm dog numbers", farm_dog.size()],
			["farm dressing props", farm_dressing.get("props", []).size()],
			["farm produce", farm_produce.get("produce", []).size()],
			["farm levels", farm_levels.get("levels", []).size()],
			["farm expansions", farm_expansions.get("slots", []).size()]]:
		if int(pair[1]) == 0:
			push_error("GameData: %s is EMPTY -- a data file is missing or "
				% str(pair[0]) + "the code that loads it is out of date")


func _load_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing data file %s" % path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: could not parse %s" % path)
		return fallback
	return parsed


## Drop-in characters: a family's own pictures as playable heroes.
##
## Drop two transparent PNGs into assets/characters/<id>/ -- hero_idle.png
## (required, roughly 256x384, feet at the bottom edge) and hero_cheer.png
## (optional) -- and the character appears in the Hero House on the next run.
## No .tres, no JSON edit, no code. This is the seam for a saved picture of a
## favourite character (which stays in this house, like the photo skins) or a
## scan of the child's own drawing.
##
## The ids are listed here rather than scanned from disk so the static checker
## can see the name keys, and so a stray folder cannot add a character nobody
## asked for.
const DROPIN_CHARACTERS := {"bluey": "character.bluey"}

var _dropin_skins: Dictionary = {}


func _register_dropin_characters() -> void:
	for id in DROPIN_CHARACTERS:
		var idle := "res://assets/characters/%s/hero_idle.png" % id
		if not ResourceLoader.exists(idle):
			continue
		var skin := CharacterSkin.new()
		skin.id = id
		skin.display_name_key = str(DROPIN_CHARACTERS[id])
		skin.prefer_texture = true
		skin.idle_texture = load(idle)
		var cheer := "res://assets/characters/%s/hero_cheer.png" % id
		if ResourceLoader.exists(cheer):
			skin.cheer_texture = load(cheer)
		skin.body_size = Vector2(64, 96)
		_dropin_skins[id] = skin
		var entries: Dictionary = characters.get("characters", {})
		entries[id] = {"name_key": str(DROPIN_CHARACTERS[id]), "skin": "", "unlocked": true}
		characters["characters"] = entries
		print("[autoload] GameData: drop-in character '%s' found" % id)


## The one place a character id becomes a CharacterSkin: drop-ins first, then
## .tres resources. Levels and screens all come here.
func skin_for(character_id: String) -> CharacterSkin:
	if character_id in _dropin_skins:
		return _dropin_skins[character_id]
	var entry: Dictionary = characters.get("characters", {}).get(character_id, {})
	var path: String = str(entry.get("skin", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path) as CharacterSkin
	return null


## The skin of the character the child currently plays as, or null when its
## resource is missing (SkinnedCharacter then falls back to the drawn hero).
func current_skin() -> CharacterSkin:
	var character_id: String = SaveManager.get_profile().get(
		"character_id", str(characters.get("default", "light_hero"))
	)
	return skin_for(character_id)


func get_level(level_id: String) -> Dictionary:
	return _levels_by_id.get(level_id, {})


func get_world(world_id: String) -> Dictionary:
	return _worlds_by_id.get(world_id, {})


## A room is a place, not a level.
##
## The child walks in whenever he likes, there is nothing in it to finish, and
## it must be invisible to everything that asks "is this world done" or "how
## much of the island is left" -- otherwise a world he has beaten stays at 5/6
## forever and the shop items behind it never open.
##
## This used to be four separate `if id == "hero_studio"` string comparisons in
## four files. That was survivable with one room. 星光菜园 is the second, and
## four two-element checks is how a rule quietly stops applying to one of them.
func is_room(level_id: String) -> bool:
	return bool(get_level(level_id).get("room", false))


func get_order(order_id: String) -> Dictionary:
	for order in garden_orders:
		if str(order.get("id", "")) == order_id:
			return order
	return {}


## What the market pays for one of these. Zero for a crop it has never heard
## of -- a retired crop sells for nothing rather than crashing the till.
func market_price(crop_id: String) -> int:
	return maxi(0, int(farm_market_prices.get("prices", {}).get(crop_id, 0)))


## The shop's row for this crop, or {} if it is not on the shelf.
func seed_listing(crop_id: String) -> Dictionary:
	for row in farm_seed_shop.get("seeds", []):
		if str(row.get("crop_id", "")) == crop_id:
			return row
	return {}


## One neighbour's farm, by id, or {}.
func get_npc_farm(npc_id: String) -> Dictionary:
	for farm in npc_farms.get("farms", []):
		if str(farm.get("id", "")) == npc_id:
			return farm
	return {}


## The level table, sorted by threshold so "which level is this much xp"
## is a walk from the top. Sorted here once per ask rather than trusted:
## a hand-edited json with two rows swapped must not invert the ladder.
func farm_level_table() -> Array:
	var rows: Array = farm_levels.get("levels", [])
	var out := rows.duplicate()
	out.sort_custom(func(a, b): return int(a.get("xp", 0)) < int(b.get("xp", 0)))
	return out


## What one event of this kind pays toward the farm's level. Zero for a kind
## nobody has heard of, so a typo earns nothing rather than something.
func farm_xp_for(kind: String) -> int:
	return maxi(0, int(farm_levels.get("xp", {}).get(kind, 0)))


## The expansion slot for bed `index`, or {} if that bed is not for sale.
func farm_expansion_slot(index: int) -> Dictionary:
	for slot in farm_expansions.get("slots", []):
		if int(slot.get("index", -1)) == index:
			return slot
	return {}


func get_crop(crop_id: String) -> Dictionary:
	# Produce (an egg) has a name and a picture but no bed: every display
	# that asks a crop for its icon gets one; nothing that plants finds it,
	# because no seed listing and no unlocked_crops entry ever names it.
	return _crops_by_id.get(crop_id, _produce_by_id.get(crop_id, {}))


## How long this crop takes from seed to ripe, in seconds. Zero for a crop that
## does not exist, so a plot holding a crop_id that has been retired since sits
## still rather than finishing instantly.
func crop_total_seconds(crop_id: String) -> int:
	var total := 0
	for seconds in get_crop(crop_id).get("stage_seconds", []):
		total += int(seconds)
	return total


## Levels belonging to a world, in listed order.
## The levels on a world's PATH, in order -- what the map draws.
##
## Levels carrying a `mode` are deliberately left out. 丰收行动 is eight levels
## reached from a button in the garden, not eight more stones on the island's
## path: putting them on the map would bury 阳光公园's nine hand-made levels
## under a run of one template, which is the thing the island is built not to
## do. They are still real levels in every other way -- same manager, same
## stars, same rewards, same probes.
func get_levels_for_world(world_id: String) -> Array:
	var out: Array = []
	for l in levels:
		if l.get("world", "") == world_id and str(l.get("mode", "")) == "":
			out.append(l)
	return out


## Every level belonging to one mode, in order. The garden's 丰收挑战 button
## reads this.
func get_levels_for_mode(mode_id: String) -> Array:
	var out: Array = []
	for l in levels:
		if str(l.get("mode", "")) == mode_id:
			out.append(l)
	return out


## The scene that implements a level's game_type. One template serves many levels.
func get_minigame_scene(game_type: String) -> String:
	var map := {
		"traffic_crossing": "res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn",
		"collect_energy": "res://scenes/minigames/collect_energy/CollectEnergy.tscn",
		"item_sorting": "res://scenes/minigames/item_sorting/ItemSorting.tscn",
		"animal_rescue": "res://scenes/minigames/animal_rescue/AnimalRescue.tscn",
		"monster_battle": "res://scenes/minigames/monster_battle/MonsterBattle.tscn",
		"memory_match": "res://scenes/minigames/memory_match/MemoryMatch.tscn",
		"light_echo": "res://scenes/minigames/light_echo/LightEcho.tscn",
		"monster_duel": "res://scenes/minigames/monster_duel/MonsterDuel.tscn",
		"platformer": "res://scenes/minigames/platformer/Platformer.tscn",
		"monster_expedition": "res://scenes/minigames/monster_expedition/MonsterExpedition.tscn",
		"keepy_uppy": "res://scenes/minigames/keepy_uppy/KeepyUppy.tscn",
		"light_defense": "res://scenes/minigames/light_defense/LightDefense.tscn",
		# The adventure template: one side-scrolling level made of beats, and
		# the thing the twelve above are being folded into.
		"platform_adventure": "res://scenes/adventure/Adventure.tscn",
		# The nine templates of the multi-play island. One core idea each, so
		# no two levels in a row ask a child for the same thing.
		"observation_search": "res://scenes/minigames/observation_search/ObservationSearch.tscn",
		# 丰收行动: a level, not a room in the farm -- see harvest_action.gd for why.
		"harvest_action": "res://scenes/minigames/harvest_action/HarvestAction.tscn",
		"matching_sorting": "res://scenes/minigames/matching_sorting/MatchingSorting.tscn",
		"build_repair": "res://scenes/minigames/build_repair/BuildRepair.tscn",
		"puzzle_mechanism": "res://scenes/minigames/puzzle_mechanism/PuzzleMechanism.tscn",
		"memory_rhythm": "res://scenes/minigames/memory_rhythm/MemoryRhythm.tscn",
		"roleplay_rescue": "res://scenes/minigames/roleplay_rescue/RoleplayRescue.tscn",
		"creative_play": "res://scenes/minigames/creative_play/CreativePlay.tscn",
		"garden": "res://scenes/garden/Garden.tscn",
	}
	return map.get(game_type, "")
