extends Node
## All progress lives on this device in user://save_game.json.
## No account, no server, no analytics, no network calls anywhere in this game.

signal progress_changed()

const SAVE_PATH := "user://save_game.json"
## The previous good save. Every successful write rotates the current file
## here first, so there is always ONE known-good generation behind us.
const SAVE_BACKUP := "user://save_game.bak"
## Writes land here first, then rename into place. A rename is atomic on
## every platform this game ships to; writing straight over the real file
## was not, and one interrupted write (a child swiping the app away
## mid-save) truncated the file -- which the old loader then "recovered"
## from by overwriting months of stars with a fresh save. That was the
## whole mystery of the vanishing history.
const SAVE_TMP := "user://save_game.tmp"
const SAVE_VERSION := 1

## The autoload order puts SaveManager BEFORE I18n, so the I18n singleton
## does not exist yet while a fresh save is being built. Reading the
## constant off the script itself works whatever the order, and keeps one
## definition of "which language does this island speak".
const I18nScript = preload("res://scripts/core/i18n.gd")

var data: Dictionary = {}


func _ready() -> void:
	print("[autoload] SaveManager starting")
	load_game()
	print("[autoload] SaveManager ok")


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {
			"name": "",
			"character_id": str(GameData.characters.get("default", "light_hero")),
			"created_at": Time.get_unix_time_from_system(),
			# Hero experience: only ever rises, one shared number for the one
			# child. Levels come out of it via hero_level().
			"xp": 0,
			# What the child is wearing, by slot. The outfit rides the CHILD,
			# not the hero: swap heroes and the crown comes along.
			"outfit": {"hat": "", "face": "", "back": ""},
		},
		# Challenge ranks: level_id -> how many times its challenge has been
		# beaten. Each rank makes that challenge a little bigger -- the level
		# system that keeps growing after the hand-made levels run out.
		"challenges": {},
		"settings": {
			"locale": I18nScript.DEFAULT_LOCALE,
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"voice_volume": 1.0,
			"daily_limit_minutes": 30,
			# 0 gentle / 1 normal / 2 brave. Set in the Parent Center; every
			# template scales its own knobs off it (LevelManager.harder).
			"difficulty": 1,
			# Some children find particles and bouncing genuinely unpleasant.
			"reduce_motion": false,
		},
		# level_id -> {stars, best_accuracy, attempts, completed}
		"levels": {},
		"rewards": {
			"coins": 0,
			"badges": [],
			"stickers": [],
			# Retired. Kept only so an old save's balance can be refunded as
			# 星星币 once, by _refund_spent_stars(). Nothing writes it any more.
			"spent_stars": 0,
			"items": {},
			# Outfit pieces owned (ids). Bought once with coins, kept forever.
			"outfits": [],
			# Every monster the child has met, by id. A collection that grows
			# by PLAYING rather than by buying, which is the only kind this
			# game has -- there is no shop for these and no way to miss one.
			"album": [],
			# What the child MADE. Not a reward and not a score -- the only
			# thing in this file that belongs to them rather than to the
			# game, which is why it is stored whole and never inspected.
			"creations": {},
			# Abilities the hero keeps forever once a chest gives them.
			# Separate from outfits because these change what the child can
			# DO, not what they look like -- and because a skill that is not
			# written down is a skill that vanishes when the tablet sleeps.
			"skills": [],
		},
		# 星光礼物屋. His shop life, kept apart from the catalogue on purpose:
		# data/shop_items.json is read-only game data and this is his. Editing a
		# price must never be able to lose him a hat.
		"shop": _default_shop(),
		# Growth attributes. Displayed as growing plants/flags, never as combat stats.
		"growth": {
			"courage": 0,
			"wisdom": 0,
			"kindness": 0,
			"focus": 0,
			"safety": 0,
		},
		# date string -> seconds played, used by the Parent Center.
		"playtime": {},
	}


func load_game() -> void:
	# Main file first; if it is missing or torn, fall back to the previous
	# good generation. Only when BOTH are gone does the island start over --
	# a torn main file used to start over immediately, taking the child's
	# whole history with it.
	var parsed: Variant = _read_save(SAVE_PATH)
	if parsed == null and FileAccess.file_exists(SAVE_BACKUP):
		parsed = _read_save(SAVE_BACKUP)
		if parsed != null:
			push_warning("SaveManager: main save was torn; recovered from backup")
	if parsed is Dictionary:
		data = _migrate(parsed)
		_settle_after_load()
		return
	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BACKUP):
		push_warning("SaveManager: no readable save found, starting fresh")
	data = _default_data()
	save_game()


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else null


## Fill in any keys added by a later build so old saves never crash the game.
## The shape of a child's shop life. Public so the shop managers can repair a
## save that predates them without reaching into private state.
func default_shop() -> Dictionary:
	return _default_shop()


## Every slot a hero can wear something in, in the order they are drawn.
const OUTFIT_SLOTS := ["back", "body", "feet", "hands", "head", "colour", "pal"]


func empty_outfit() -> Dictionary:
	var out := {}
	for slot in OUTFIT_SLOTS:
		out[slot] = ""
	return out


func _default_shop() -> Dictionary:
	return {
		# What he owns. One list -- clothes belong to the CHILD, not to a hero.
		"owned": [],
		# What each hero has ON. Per character on purpose: dressing 迪迦 used to
		# dress 赛罗 too, because there was one global outfit, and that made six
		# heroes read as one hero in six colours. Five heroes he can dress five
		# different ways is most of what makes this a dressing-up game.
		"worn": {},
		# Three looks he can save and put back on with one tap.
		"presets": ["", "", ""],
		# Up to five things he is saving for. See wishlist_manager.gd.
		"wishlist": [],
		# Decorations placed in the hero base, and which shelves have opened.
		"base_decor": [],
		"unlocked_categories": ["wardrobe", "action"],
		# Which "new!" marks he has already seen, so the star stops glowing.
		"seen_new": [],
		"bundles_done": [],
		"free_gift_taken": false,
		"tutorial_done": false,
	}


# --- the wardrobe --------------------------------------------------------

## What this hero is wearing. Always every slot, so a screen can read one
## without checking whether it is there.
func worn_by(character_id: String) -> Dictionary:
	var shop: Dictionary = data.get("shop", {})
	var all: Dictionary = shop.get("worn", {})
	var mine: Dictionary = all.get(character_id, {})
	var out := empty_outfit()
	for slot in out:
		out[slot] = str(mine.get(slot, ""))
	return out


func wear_item(character_id: String, slot: String, item_id: String) -> void:
	if not data.has("shop"):
		data["shop"] = _default_shop()
	var all: Dictionary = data["shop"].get("worn", {})
	var mine: Dictionary = all.get(character_id, {})
	mine[slot] = item_id
	all[character_id] = mine
	data["shop"]["worn"] = all
	save_game()
	progress_changed.emit()


func wear_whole(character_id: String, outfit: Dictionary) -> void:
	if not data.has("shop"):
		data["shop"] = _default_shop()
	var all: Dictionary = data["shop"].get("worn", {})
	all[character_id] = outfit.duplicate(true)
	data["shop"]["worn"] = all
	save_game()
	progress_changed.emit()


func _migrate(loaded: Dictionary) -> Dictionary:
	var base := _default_data()
	for key in base.keys():
		if not loaded.has(key):
			loaded[key] = base[key]
		elif base[key] is Dictionary and loaded[key] is Dictionary:
			for sub in base[key].keys():
				if not loaded[key].has(sub):
					loaded[key][sub] = base[key][sub]
	loaded["version"] = SAVE_VERSION
	return loaded


## Everything that has to happen once, after a save is loaded and merged.
##
## "Once" is the load-bearing word, and it costs a write: a settlement that
## only happens in memory is re-applied on the next launch, and the launch
## after that. The first cut of the refund below did exactly that -- the
## balance looked right every time and the file never changed, so it would have
## paid out again every morning forever.
func _settle_after_load() -> void:
	var changed := _refund_spent_stars()
	changed = _rename_old_monsters() or changed
	changed = _move_wardrobe_in() or changed
	changed = _split_wardrobes() or changed
	if changed:
		save_game()


## The old wardrobe moves into the new one, and nothing he owns is lost.
##
## There were two wardrobes. The Hero House kept ownership in
## `rewards.outfits` and what-is-worn in `profile.outfit`, with slots called
## hat/face/suit/back/colour. The gift shop kept both in `data.shop`, with
## slots called head/body/back/hands/feet -- and `back` meant a different thing
## in each. They shared only the coin balance.
##
## This is the merge. It runs once, converts the old ids to their new
## equivalents, and leaves the old keys alone rather than deleting them: if
## this is ever wrong, the original is still on disk to read.
##
## A card that vanishes is the failure this project has already had once, with
## the monster album. It is worse here -- these are things he SPENT stars on.
const OUTFIT_RENAMES := {
	# hats
	"crown": "crown_brave", "party_hat": "crown_party",
	"cap": "cap_cloud", "cowboy_hat": "cap_captain",
	# the old face slot has no home; the nearest thing is a head piece
	"sunglasses": "goggles_sky", "bandana": "headband_bunny",
	# suits
	"dress": "dress_party", "vest": "vest_park", "star_robe": "robe_wizard",
	# backs
	"cape_red": "cape_castle", "wings": "wings_sky",
	# colours
	"sky": "colour_sky", "mint": "colour_mint", "rose": "colour_rose",
	"sun": "colour_sun", "violet": "colour_violet", "shadow": "colour_cloud",
}
const OLD_TO_NEW_SLOT := {
	"hat": "head", "face": "head", "suit": "body",
	"back": "back", "colour": "colour",
}


func _move_wardrobe_in() -> bool:
	var rewards: Dictionary = data.get("rewards", {})
	var old_owned: Array = rewards.get("outfits", [])
	var old_worn: Dictionary = data.get("profile", {}).get("outfit", {})
	if old_owned.is_empty() and old_worn.is_empty():
		return false
	if not data.has("shop"):
		data["shop"] = _default_shop()
	if bool(data["shop"].get("wardrobe_moved", false)):
		return false

	var catalogue := {}
	for entry in GameData.shop_items:
		catalogue[str(entry.get("id", ""))] = true
	if catalogue.is_empty():
		return false            # the catalogue failed to load; touch nothing

	var owned: Array = data["shop"].get("owned", [])
	for old_id in old_owned:
		var new_id := str(OUTFIT_RENAMES.get(str(old_id), str(old_id)))
		if catalogue.has(new_id) and not owned.has(new_id):
			owned.append(new_id)
	data["shop"]["owned"] = owned

	# Whatever he had on goes on the hero he was PLAYING, and on nobody else.
	#
	# The first cut put it on all of them, reasoning that there had only ever
	# been one outfit so it could not have been meant for one hero. That was
	# wrong the moment there were fourteen faces: it dressed the whole cast
	# identically, and a row of fourteen heads in the same crown is a row a
	# child reads as one character repeated.
	var outfit := empty_outfit()
	for old_slot in old_worn:
		var new_slot := str(OLD_TO_NEW_SLOT.get(str(old_slot), ""))
		var new_id := str(OUTFIT_RENAMES.get(str(old_worn[old_slot]), ""))
		if new_slot != "" and catalogue.has(new_id) and owned.has(new_id):
			outfit[new_slot] = new_id
	var worn: Dictionary = data["shop"].get("worn", {})
	var chosen := str(data.get("profile", {}).get("character_id", ""))
	if chosen != "" and not worn.has(chosen):
		worn[chosen] = outfit.duplicate(true)
	data["shop"]["worn"] = worn
	data["shop"]["wardrobe_moved"] = true
	# The old dictionary has been read; leaving it in place is what made every
	# hero wear the same drawn crown. It stays on disk as `outfit_old` so the
	# original is still there to look at if this was ever wrong.
	data["profile"]["outfit_old"] = old_worn.duplicate(true)
	data["profile"]["outfit"] = {}
	return true


## Saves that already came through the move are still carrying the old global
## wardrobe and a copy of it on every hero. Undo exactly that, once.
##
## Only outfits IDENTICAL to the chosen hero's are cleared: if he has since
## dressed 赛罗 differently, that was a decision and it stays. Nothing he owns
## is touched -- clothes belong to the child, so undressing a hero costs him
## nothing but a tap to put it back.
func _split_wardrobes() -> bool:
	if not data.has("shop"):
		return false
	var shop: Dictionary = data["shop"]
	if bool(shop.get("wardrobe_split", false)):
		return false
	shop["wardrobe_split"] = true
	var changed := false
	if not (data.get("profile", {}).get("outfit", {}) as Dictionary).is_empty():
		data["profile"]["outfit_old"] = data["profile"]["outfit"].duplicate(true)
		data["profile"]["outfit"] = {}
		changed = true
	var worn: Dictionary = shop.get("worn", {})
	var chosen := str(data.get("profile", {}).get("character_id", ""))
	var mine: Dictionary = worn.get(chosen, {})
	if mine.is_empty():
		return true
	for character_id in worn.keys():
		if str(character_id) == chosen:
			continue
		var theirs: Dictionary = worn[character_id]
		var same := theirs.size() == mine.size()
		if same:
			for slot in mine:
				if str(theirs.get(slot, "")) != str(mine[slot]):
					same = false
					break
		if same:
			worn.erase(character_id)
			changed = true
	shop["worn"] = worn
	return changed or true


## 怪兽图鉴 was rebuilt with painted art and fifteen new monsters, and the ten
## old ids went with the old drawings.
##
## A save file still holds the old ids, and an id that matches nothing is a
## card that silently disappears. A six-year-old does not know his game was
## rebuilt. He knows the monster he beat is gone out of his book -- which is
## the one thing a collection must never do.
##
## So the old ones are renamed to whoever took their place: same world, same
## job in that world. Anything with no successor is dropped rather than left to
## sit in the save as a card that can never be drawn.
const MONSTER_RENAMES := {
	"walker": "stone_cub",           # the first small foe in the park
	"spitter": "twin_horn",          # the second one
	"armoured": "drill_armor",       # the one you have to get above
	"rock_giant": "blaze_claw",      # the arena boss in the castle
	"horn_beast": "red_wing",        # first duel, sunny park
	"spark_eel": "steel_spine",      # duel, neon city
	"big_arms": "sand_fist",         # duel, monster valley
	"valley_king": "crystal_armor",  # second duel, monster valley
	"sky_watcher": "thunder_wyvern", # duel, sky base
	"castle_shadow": "shadow_wing",  # the last fight in the game
}


func _rename_old_monsters() -> bool:
	var album: Array = data["rewards"].get("album", [])
	if album.is_empty():
		return false
	var known := {}
	for entry in GameData.monsters:
		known[str(entry.get("id", ""))] = true
	if known.is_empty():
		return false     # the catalogue failed to load; touch nothing
	var fresh: Array = []
	var changed := false
	for old in album:
		var id := str(old)
		if known.has(id):
			if not fresh.has(id):
				fresh.append(id)
			continue
		changed = true
		var new_id := str(MONSTER_RENAMES.get(id, ""))
		if new_id != "" and known.has(new_id) and not fresh.has(new_id):
			fresh.append(new_id)
	if changed:
		data["rewards"]["album"] = fresh
	return changed


func save_game() -> void:
	# Write-to-temp, rotate, rename: at every instant of this sequence there
	# is a complete save on disk somewhere. Interrupt it wherever you like --
	# the worst case is losing the one change being written.
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write save file")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BACKUP):
			DirAccess.remove_absolute(SAVE_BACKUP)
		DirAccess.rename_absolute(SAVE_PATH, SAVE_BACKUP)
	DirAccess.rename_absolute(SAVE_TMP, SAVE_PATH)


# --- settings ---

func get_setting(key: String, fallback: Variant = null) -> Variant:
	return data.get("settings", {}).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_game()


# --- profile ---

func get_profile() -> Dictionary:
	return data.get("profile", {})


func set_profile_name(child_name: String) -> void:
	data["profile"]["name"] = child_name
	save_game()


## Which hero the child plays as. Only ids present in data/characters.json are
## accepted, so a corrupt save cannot point the game at a skin that is not there.
func set_character(character_id: String) -> void:
	if not GameData.characters.get("characters", {}).has(character_id):
		return
	data["profile"]["character_id"] = character_id
	save_game()
	progress_changed.emit()


# --- level progress ---

func get_level_progress(level_id: String) -> Dictionary:
	return data["levels"].get(level_id, {
		"stars": 0, "best_accuracy": 0.0, "attempts": 0, "completed": false,
		"found_hidden": false,
	})


## Stars only ever go up. A worse run never erases what the child already earned.
##
## `found_hidden` is remembered for the same reason and works the same way: it
## latches true and stays there, so the 星星币 bonus for finding the hidden gem
## is paid exactly once however many times he replays the level.
func record_level_result(level_id: String, stars: int, accuracy: float,
		found_hidden: bool = false) -> void:
	var prev := get_level_progress(level_id)
	data["levels"][level_id] = {
		"stars": maxi(prev.get("stars", 0), stars),
		"best_accuracy": maxf(prev.get("best_accuracy", 0.0), accuracy),
		"attempts": int(prev.get("attempts", 0)) + 1,
		"completed": true,
		"found_hidden": bool(prev.get("found_hidden", false)) or found_hidden,
	}
	save_game()
	progress_changed.emit()


func total_stars() -> int:
	var sum := 0
	for level_id in data["levels"].keys():
		sum += int(data["levels"][level_id].get("stars", 0))
	return sum


## The one switch that opens the whole island, for testing.
##
## Deliberately a VIEW of the save and never a write to it. Nothing about his
## stars, his completions or his album changes when this goes on or off -- it
## is reversible precisely because it never edited anything. Turn it off and
## the locks are exactly where he left them, to the star.
##
## It lives here rather than in the map because four different places ask
## whether a level is open -- the map, the "next level" button, the island's
## completion ring, the probes -- and a test switch that only some of them
## honour is worse than no switch at all.
const TEST_UNLOCK := "test_unlock_all"


func test_unlock_all() -> bool:
	return bool(get_setting(TEST_UNLOCK, false))


func is_level_unlocked(level_id: String) -> bool:
	var level := GameData.get_level(level_id)
	if level.is_empty():
		return false
	if test_unlock_all():
		return true
	var requires: String = level.get("requires", "")
	if requires == "":
		return true
	return get_level_progress(requires).get("completed", false)


# --- rewards ---

func add_coins(amount: int) -> void:
	data["rewards"]["coins"] = int(data["rewards"]["coins"]) + amount
	save_game()


# --- hero level and challenges ---

const XP_PER_LEVEL := 120


func hero_level() -> int:
	return 1 + int(data["profile"].get("xp", 0)) / XP_PER_LEVEL


## Adds experience and returns how many hero levels that gained (usually 0,
## sometimes 1 -- the result screen throws the party).
func add_xp(amount: int) -> int:
	var before := hero_level()
	data["profile"]["xp"] = int(data["profile"].get("xp", 0)) + maxi(amount, 0)
	save_game()
	return hero_level() - before


func get_challenge_rank(level_id: String) -> int:
	return int(data.get("challenges", {}).get(level_id, 0))


func bump_challenge_rank(level_id: String) -> void:
	data["challenges"][level_id] = get_challenge_rank(level_id) + 1
	save_game()
	progress_changed.emit()


# --- the star shop ------------------------------------------------------
#
# Stars are two things at once: the lifetime achievement count that unlocks
# worlds (total_stars(), which only ever rises) and, since the star shop, a
# spendable allowance. Spending NEVER touches the lifetime count -- it only
# raises rewards.spent_stars -- so buying a potion can never re-lock a world
# or shrink the tally a child is proud of.

## RETIRED. Stars are a score again, and only a score.
##
## These two used to make total_stars() double as a purse: the shop spent
## against `total_stars() - spent_stars`. It never re-locked a world, which was
## the danger its author guarded against -- but a child still saw his star
## count drop after buying a potion, with no way to tell that the number the
## map cares about had not moved.
##
## Everything spendable is 星星币 now (scripts/shop/currency_manager.gd).
## `spent_stars` is refunded coin-for-coin by _refund_spent_stars() on the
## first load after this change, so nobody is a single star worse off.
##
## Left here as a hard error rather than deleted, because a call site that
## quietly went back to spending stars is exactly the regression this whole
## change exists to prevent.
func spend_stars(_amount: int) -> bool:
	push_error("SaveManager.spend_stars() is retired -- 关卡星章 cannot be "
		+ "spent. Use scripts/shop/currency_manager.gd.")
	return false


## One-time: turn a returning child's already-spent stars into 星星币.
##
## He spent them; he should still have the value. Paying it back as coins
## means the change can only ever make him richer, which is the only kind of
## migration worth shipping to somebody's six-year-old.
## Returns whether anything changed, so the caller knows to write it down.
func _refund_spent_stars() -> bool:
	var spent: int = int(data["rewards"].get("spent_stars", 0))
	if spent <= 0:
		return false
	data["rewards"]["coins"] = int(data["rewards"].get("coins", 0)) + spent
	data["rewards"]["spent_stars"] = 0
	print("[save] refunded %d spent stars as 星星币" % spent)
	return true


## Battle items are consumable and counted: bought in the star shop, spent
## in a fight, one at a time.
func item_count(item_id: String) -> int:
	return int(data["rewards"].get("items", {}).get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> void:
	var items: Dictionary = data["rewards"].get("items", {})
	items[item_id] = int(items.get(item_id, 0)) + amount
	data["rewards"]["items"] = items
	save_game()
	progress_changed.emit()


## Items go out only through here, and only if one is really there.
func use_item(item_id: String) -> bool:
	if item_count(item_id) <= 0:
		return false
	data["rewards"]["items"][item_id] = item_count(item_id) - 1
	save_game()
	progress_changed.emit()
	return true


# --- the wardrobe ---------------------------------------------------------

func get_outfit() -> Dictionary:
	return data["profile"].get("outfit", {"hat": "", "face": "", "back": ""})


## --- the monster album ---------------------------------------------------

func has_met(monster_id: String) -> bool:
	return monster_id in data["rewards"].get("album", [])


## Meeting a monster writes it down. Returns true the first time, so a level
## can make a small fuss about it exactly once.
func record_meeting(monster_id: String) -> bool:
	if monster_id == "":
		return false
	if not data["rewards"].has("album"):
		data["rewards"]["album"] = []
	if has_met(monster_id):
		return false
	data["rewards"]["album"].append(monster_id)
	save_game()
	progress_changed.emit()
	return true


func album() -> Array:
	return data["rewards"].get("album", [])


## How much of the island is finished, 0 to 1: stars earned over stars there
## are. The map shows this, because "how far am I" is the one question a
## six-year-old asks about a game that has more than one screen.
func island_completion() -> float:
	var possible := 0
	for level in GameData.levels:
		if str(level.get("id", "")) == "hero_studio":
			continue        # the free-play room has nothing to complete
		possible += 3
	if possible == 0:
		return 0.0
	return clampf(float(total_stars()) / float(possible), 0.0, 1.0)


## --- things the child made -----------------------------------------------

func get_creation(name: String) -> Array:
	return (data["rewards"].get("creations", {}) as Dictionary).get(name, [])


func set_creation(name: String, layout: Array) -> void:
	if not data["rewards"].has("creations"):
		data["rewards"]["creations"] = {}
	data["rewards"]["creations"][name] = layout
	save_game()
	progress_changed.emit()


## --- skills the hero keeps ---------------------------------------------

func has_skill(skill_id: String) -> bool:
	return skill_id in data["rewards"].get("skills", [])


## Grant a skill. Returns true only the FIRST time, so the level can throw a
## party for it exactly once and stay quiet on every replay.
func unlock_skill(skill_id: String) -> bool:
	if skill_id == "":
		return false
	if not data["rewards"].has("skills"):
		data["rewards"]["skills"] = []
	if has_skill(skill_id):
		return false
	data["rewards"]["skills"].append(skill_id)
	save_game()
	progress_changed.emit()
	return true


func has_outfit(outfit_id: String) -> bool:
	return outfit_id in data["rewards"].get("outfits", [])


func add_outfit(outfit_id: String) -> void:
	if outfit_id == "" or has_outfit(outfit_id):
		return
	data["rewards"]["outfits"].append(outfit_id)
	save_game()
	progress_changed.emit()


## Wear a piece (or pass "" to take the slot's piece off). One piece per
## slot: putting on the crown hangs the party hat back on its hook.
func wear_outfit(slot: String, outfit_id: String) -> void:
	var outfit: Dictionary = get_outfit()
	outfit[slot] = outfit_id
	data["profile"]["outfit"] = outfit
	save_game()
	progress_changed.emit()


## Coins go out only through here, and only if they are really there.
func spend_coins(amount: int) -> bool:
	if amount <= 0 or int(data["rewards"]["coins"]) < amount:
		return false
	data["rewards"]["coins"] = int(data["rewards"]["coins"]) - amount
	save_game()
	progress_changed.emit()
	return true


func has_sticker(sticker_id: String) -> bool:
	return sticker_id in data["rewards"]["stickers"]


func add_sticker(sticker_id: String) -> void:
	if sticker_id == "" or has_sticker(sticker_id):
		return
	data["rewards"]["stickers"].append(sticker_id)
	save_game()
	progress_changed.emit()


func add_badge(badge_id: String) -> bool:
	if badge_id == "" or badge_id in data["rewards"]["badges"]:
		return false
	data["rewards"]["badges"].append(badge_id)
	save_game()
	return true


func add_growth(attribute: String, amount: int) -> void:
	if not data["growth"].has(attribute):
		return
	data["growth"][attribute] = int(data["growth"][attribute]) + amount
	save_game()


# --- progress backup: how two devices share one child's history ----------
#
# There is no cloud and no account, on purpose. Instead the Parent Center
# can EXPORT the save as a small file (AirDrop or WeChat it across) and
# IMPORT one found on this device. Import MERGES by best-of -- stars, coins,
# items, badges all take the higher value -- so importing an old file can
# never downgrade anyone, and importing twice never double-counts.

const BACKUP_PREFIX := "heroes_island_progress"


## Writes the backup file and returns its absolute path ("" only if even the
## app's own folder refuses, which means the disk is full or broken).
##
## Order matters, and the first version had it backwards. It wrote straight
## to Downloads and gave up if that failed -- and on macOS it always failed:
## Apple guards Downloads, Documents and Desktop behind TCC, so an app
## without the matching usage-description entitlement is denied silently,
## with no prompt and no explanation. Hence "could not write the backup
## file" on a Mac with plenty of disk.
##
## So: write to user:// first, which no OS permission can take away (macOS
## Application Support, the iPad's own Documents where the Files app can
## see it). THEN try to also drop a copy somewhere friendlier, and report
## that path if it lands. The backup always exists either way.
func export_progress() -> String:
	var stamp: Dictionary = Time.get_datetime_dict_from_system()
	var file_name := "%s_%04d-%02d-%02d_%02d%02d.json" % [BACKUP_PREFIX,
		stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute]
	var payload := JSON.stringify({
		"heroes_island_backup": true,
		"exported_at": Time.get_datetime_string_from_system(),
		"data": data,
	}, "\t")

	var f := FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write backup to user:// (error %d)"
			% FileAccess.get_open_error())
		return ""
	f.store_string(payload)
	f.close()
	var written := ProjectSettings.globalize_path("user://" + file_name)

	# The nicety, not the deliverable: a copy where a parent looks first.
	# Failure here is expected on locked-down systems and costs nothing.
	for kind in [OS.SYSTEM_DIR_DOWNLOADS, OS.SYSTEM_DIR_DOCUMENTS]:
		var dir: String = OS.get_system_dir(kind)
		if dir == "" or not DirAccess.dir_exists_absolute(dir):
			continue
		var candidate: String = dir.path_join(file_name)
		var out := FileAccess.open(candidate, FileAccess.WRITE)
		if out == null:
			continue
		out.store_string(payload)
		out.close()
		return candidate
	return written


## Every backup file this device can see, newest first.
func list_backups() -> Array:
	var found: Array = []
	var dirs := [
		OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS),
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
		OS.get_user_data_dir(),
	]
	for dir in dirs:
		if dir == "" or not DirAccess.dir_exists_absolute(dir):
			continue
		for file_name in DirAccess.get_files_at(dir):
			if str(file_name).begins_with(BACKUP_PREFIX) and str(file_name).ends_with(".json"):
				var path: String = dir.path_join(str(file_name))
				found.append({
					"path": path,
					"modified": FileAccess.get_modified_time(path),
				})
	found.sort_custom(func(a, b): return int(a["modified"]) > int(b["modified"]))
	return found


## Merge a backup into this device's save. Returns
## {ok, error?, stars_before, stars_after, path}.
func import_progress(path: String) -> Dictionary:
	var before := total_stars()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not bool(parsed.get("heroes_island_backup", false)) \
			or not (parsed.get("data") is Dictionary):
		return {"ok": false, "error": "bad_file", "stars_before": before,
			"stars_after": before, "path": path}
	_merge_progress(_migrate(parsed["data"]))
	save_game()
	progress_changed.emit()
	return {"ok": true, "stars_before": before, "stars_after": total_stars(),
		"path": path}


## Best-of, field by field. Settings and playtime stay LOCAL -- each device
## keeps its own volume and daily limit; it is the child's achievements
## that travel.
func _merge_progress(theirs: Dictionary) -> void:
	for level_id in theirs.get("levels", {}).keys():
		var t: Dictionary = theirs["levels"][level_id]
		var m: Dictionary = get_level_progress(level_id)
		data["levels"][level_id] = {
			"stars": maxi(int(m.get("stars", 0)), int(t.get("stars", 0))),
			"best_accuracy": maxf(float(m.get("best_accuracy", 0.0)),
				float(t.get("best_accuracy", 0.0))),
			"attempts": maxi(int(m.get("attempts", 0)), int(t.get("attempts", 0))),
			"completed": bool(m.get("completed", false)) or bool(t.get("completed", false)),
		}
	for level_id in theirs.get("challenges", {}).keys():
		data["challenges"][level_id] = maxi(get_challenge_rank(str(level_id)),
			int(theirs["challenges"][level_id]))
	var tr: Dictionary = theirs.get("rewards", {})
	data["rewards"]["coins"] = maxi(int(data["rewards"].get("coins", 0)), int(tr.get("coins", 0)))
	data["rewards"]["spent_stars"] = maxi(int(data["rewards"].get("spent_stars", 0)),
		int(tr.get("spent_stars", 0)))
	for badge in tr.get("badges", []):
		if not badge in data["rewards"]["badges"]:
			data["rewards"]["badges"].append(badge)
	for sticker in tr.get("stickers", []):
		if not sticker in data["rewards"]["stickers"]:
			data["rewards"]["stickers"].append(sticker)
	for outfit in tr.get("outfits", []):
		if not outfit in data["rewards"]["outfits"]:
			data["rewards"]["outfits"].append(outfit)
	for item_id in tr.get("items", {}).keys():
		data["rewards"]["items"][item_id] = maxi(item_count(str(item_id)),
			int(tr["items"][item_id]))
	var tp: Dictionary = theirs.get("profile", {})
	data["profile"]["xp"] = maxi(int(data["profile"].get("xp", 0)), int(tp.get("xp", 0)))
	for attribute in theirs.get("growth", {}).keys():
		if data["growth"].has(attribute):
			data["growth"][attribute] = maxi(int(data["growth"][attribute]),
				int(theirs["growth"][attribute]))


# --- playtime, for the Parent Center ---

func add_playtime(seconds: float) -> void:
	var today := Time.get_date_string_from_system()
	data["playtime"][today] = float(data["playtime"].get(today, 0.0)) + seconds
	save_game()


func playtime_today() -> float:
	return float(data["playtime"].get(Time.get_date_string_from_system(), 0.0))
