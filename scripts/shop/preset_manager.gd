extends RefCounted
## Saved looks, themed outfits, the magic mixer and today's suggestion.
##
##     const Presets := preload("res://scripts/shop/preset_manager.gd")
##
## The rule that runs through every function here: **nothing may put on
## something he does not own.** A magic mix that quietly dresses him in a hat
## from the shop is a shop demo, not a toy -- and the moment he taps something
## else it vanishes and he does not know why. `owned_in()` is the only place
## that decides what is available, and everything else goes through it.
##
## The other rule: no timers. Today's suggestion is a suggestion, not an
## offer; there is no countdown, nothing expires, and coming back tomorrow
## loses him nothing.

const Shop := preload("res://scripts/shop/shop_manager.gd")

const SLOTS := ["head", "body", "back", "hands", "feet"]
const SAVE_KEY := "shop"
const SAVED := 3


# --- the twelve themed outfits -------------------------------------------

static func sets() -> Array:
	return GameData.outfit_presets.get("sets", [])


static func set_by_id(set_id: String) -> Dictionary:
	for entry in sets():
		if str(entry.get("id", "")) == set_id:
			return entry
	return {}


## What a themed outfit would put on, as slot -> item id. Pieces he does not
## own are left out rather than faked, so a half-owned set dresses the half he
## has -- and the card can say how many are still missing.
static func pieces_of(set_id: String, owned_only: bool = true) -> Dictionary:
	var out := {}
	for piece in set_by_id(set_id).get("pieces", []):
		var entry: Dictionary = Shop.item(str(piece))
		if entry.is_empty():
			continue
		if owned_only and not Shop.owns(str(piece)):
			continue
		out[str(entry.get("slot", ""))] = str(piece)
	return out


static func set_progress(set_id: String) -> Array:
	var pieces: Array = set_by_id(set_id).get("pieces", [])
	var have := 0
	for piece in pieces:
		if Shop.owns(str(piece)):
			have += 1
	return [have, pieces.size()]


# --- the magic mixer ------------------------------------------------------

## Everything he owns that this hero can wear, in one slot.
static func owned_in(slot: String, character_id: String) -> Array:
	var out: Array = []
	for entry in Shop.items():
		if str(entry.get("slot", "")) != slot:
			continue
		if not Shop.owns(str(entry.get("id", ""))):
			continue
		if not Shop.fits(entry, character_id):
			continue
		out.append(str(entry.get("id", "")))
	return out


## Shake the wardrobe. Returns a whole outfit built only from things he owns.
##
## A slot he owns nothing for comes back empty rather than unchanged: a mixer
## that leaves yesterday's hat on half the time does not read as random, it
## reads as broken.
static func magic_mix(character_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var roll := rng
	if roll == null:
		roll = RandomNumberGenerator.new()
		roll.randomize()
	var out := {}
	for slot in SLOTS:
		var choices := owned_in(slot, character_id)
		if choices.is_empty():
			out[slot] = ""
			continue
		# A one-in-six chance of leaving a slot bare, so the mixer can produce
		# "just a hat", which is a look a child will actually choose.
		if choices.size() > 1 and roll.randi_range(0, 5) == 0:
			out[slot] = ""
		else:
			out[slot] = str(choices[roll.randi_range(0, choices.size() - 1)])
	return out


# --- today's suggestion ---------------------------------------------------

## One themed outfit to suggest, picked from the ones he can actually get:
## fully owned first, then the closest to complete. Never a countdown, never
## "only today" -- it is a nudge towards something he is near, and if he
## ignores it forever he loses nothing.
static func today(day: int) -> String:
	var all := sets()
	if all.is_empty():
		return ""
	var best := ""
	var best_score := -1.0
	for i in range(all.size()):
		var set_id := str(all[i].get("id", ""))
		var progress := set_progress(set_id)
		var total: float = maxf(float(progress[1]), 1.0)
		var share: float = float(progress[0]) / total
		# Rotate through the list day by day so it is not the same one forever,
		# then prefer the one he is closest to finishing.
		var turn: float = 0.35 if (i + day) % all.size() < 3 else 0.0
		var score: float = share + turn
		if score > best_score:
			best_score = score
			best = set_id
	return best


# --- the three saved looks ------------------------------------------------

static func _shop() -> Dictionary:
	if not SaveManager.data.has(SAVE_KEY):
		SaveManager.data[SAVE_KEY] = SaveManager.default_shop()
	return SaveManager.data[SAVE_KEY]


static func saved() -> Array:
	var slots: Array = _shop().get("presets", [])
	while slots.size() < SAVED:
		slots.append("")
	return slots


## Store what he is wearing into one of the three drawers.
static func save_look(index: int, outfit: Dictionary) -> void:
	if index < 0 or index >= SAVED:
		return
	var slots := saved()
	slots[index] = JSON.stringify(outfit)
	var shop := _shop()
	shop["presets"] = slots
	SaveManager.data[SAVE_KEY] = shop
	SaveManager.save_game()


## Read one back. Anything in it he has since undone -- refunded, or a hero who
## cannot wear it -- is dropped, so a saved look can never resurrect something
## he does not own.
static func load_look(index: int, character_id: String) -> Dictionary:
	var slots := saved()
	if index < 0 or index >= slots.size() or str(slots[index]) == "":
		return {}
	var parsed: Variant = JSON.parse_string(str(slots[index]))
	if not (parsed is Dictionary):
		return {}
	var out := {}
	for slot in (parsed as Dictionary):
		var item_id := str((parsed as Dictionary)[slot])
		if item_id == "":
			out[slot] = ""
			continue
		var entry: Dictionary = Shop.item(item_id)
		if entry.is_empty() or not Shop.owns(item_id) \
				or not Shop.fits(entry, character_id):
			out[slot] = ""
		else:
			out[slot] = item_id
	return out


static func has_look(index: int) -> bool:
	var slots := saved()
	return index >= 0 and index < slots.size() and str(slots[index]) != ""
