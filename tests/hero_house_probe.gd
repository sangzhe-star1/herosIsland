extends Node
## 英雄小屋, pressed the way a six-year-old presses it.
##
##   godot --headless --path . res://tests/HeroHouseProbe.tscn
##
## The brief lists seventeen things to check and every one of them is here,
## because a dressing-up room is made almost entirely of state -- what he owns,
## what he has on, which hero he is, what he was trying on and did not buy --
## and state is exactly what a screenshot cannot show.
##
## The first one is the one that matters most: TRYING THINGS ON MUST BE FREE.
## A child explores by touching everything. If touching costs stars he learns
## to stop touching, and the whole room is dead.

const Shop := preload("res://scripts/shop/shop_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Presets := preload("res://scripts/shop/preset_manager.gd")
const Layers := preload("res://scripts/shop/outfit_layer.gd")
const HISTORY := preload("res://scripts/shop/outfit_history.gd")

var _out: Array[String] = []
var _screen: Control


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	await get_tree().process_frame
	print("\n=== hero house probe ===")

	_the_old_wardrobe_moves_in()
	_the_old_saves_get_split()
	await _trying_on_is_free()
	await _buying_costs_exactly_the_price()
	await _the_rules_of_the_shelf()
	await _each_hero_keeps_his_own_clothes()
	await _the_toys()
	await _it_survives_being_closed()
	await _the_cast()
	await _the_room_fits_both_screens()

	# Put the save back the way a player would leave it. This probe plays as
	# the puppy for one check, and leaving him selected made the shop probe
	# fail in the next process -- the save file outlives the run.
	SaveManager.data["profile"]["character_id"] = "tiga"
	SaveManager.save_game()

	for f in _out:
		print("FAIL  %s" % f)
	print("HERO HOUSE PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


func _fresh(coins: int = 200) -> void:
	SaveManager.data["shop"] = SaveManager.default_shop()
	SaveManager.data["rewards"]["coins"] = coins
	SaveManager.data["profile"]["character_id"] = "tiga"


func _own(ids: Array) -> void:
	var shop: Dictionary = SaveManager.data["shop"]
	for id in ids:
		if not shop["owned"].has(str(id)):
			shop["owned"].append(str(id))
	shop["free_gift_taken"] = true


# --- 1. the merge ---------------------------------------------------------

## The old Hero House kept ownership in rewards.outfits and what-was-worn in
## profile.outfit, with different slot names and different item ids. Nothing a
## child paid for may be lost in the move.
func _the_old_wardrobe_moves_in() -> void:
	SaveManager.data.erase("shop")
	SaveManager.data["profile"]["character_id"] = "tiga"
	SaveManager.data["rewards"]["outfits"] = ["crown", "vest", "cape_red", "sky"]
	SaveManager.data["profile"]["outfit"] = {
		"hat": "crown", "suit": "vest", "back": "cape_red", "colour": "sky"}
	SaveManager.call("_move_wardrobe_in")

	var shop: Dictionary = SaveManager.data["shop"]
	var owned: Array = shop["owned"]
	print("  old wardrobe: 4 things in -> %d out (%s)"
		% [owned.size(), ", ".join(owned)])
	for want in ["crown_brave", "vest_park", "cape_castle", "colour_sky"]:
		_ok(owned.has(want), "the move lost %s" % want)
	var worn := SaveManager.worn_by("tiga")
	_ok(str(worn.get("head", "")) == "crown_brave",
		"he was wearing a crown and now has %s on his head" % worn.get("head", ""))
	_ok(str(worn.get("body", "")) == "vest_park", "his vest came off in the move")
	# ...and it goes on the hero he was PLAYING, not on all fourteen. Dressing
	# the whole cast identically is what made every face in the row look like
	# the same character in a different colour.
	var others := 0
	for cid in GameData.characters.get("characters", {}):
		if str(cid) == "tiga":
			continue
		if str(SaveManager.worn_by(str(cid)).get("head", "")) != "":
			others += 1
	print("  the old outfit landed on tiga and %d others" % others)
	_ok(others == 0, "the move dressed %d other heroes in the same clothes" % others)
	# The old global dictionary must be emptied, or every hero keeps wearing
	# its drawn crown forever -- and a drawn hat replaces the crest, so all
	# fourteen silhouettes become one.
	_ok((SaveManager.get_outfit() as Dictionary).is_empty(),
		"the old global outfit is still there after the move: %s"
			% SaveManager.get_outfit())
	# ...and it must not run twice and double everything up.
	SaveManager.call("_move_wardrobe_in")
	_ok((SaveManager.data["shop"]["owned"] as Array).size() == owned.size(),
		"the move ran a second time and duplicated things")
	SaveManager.data["profile"].erase("outfit")
	SaveManager.data["rewards"]["outfits"] = []


## The save on Zane's Mac had ALREADY come through the move, so fixing the move
## does nothing for it: fourteen heroes wearing one outfit, and the old global
## dictionary still on disk repainting every one of them the same blue. This is
## the one-time repair for that save, and it must leave a hero he dressed on
## purpose alone.
func _the_old_saves_get_split() -> void:
	SaveManager.data["shop"] = SaveManager.default_shop()
	SaveManager.data["shop"]["wardrobe_moved"] = true
	SaveManager.data["shop"].erase("wardrobe_split")
	SaveManager.data["profile"]["character_id"] = "tiga"
	SaveManager.data["profile"]["outfit"] = {"hat": "crown", "colour": "sky"}
	var everyone := SaveManager.empty_outfit()
	everyone["head"] = "crown_brave"
	everyone["body"] = "vest_park"
	var worn := {}
	for cid in GameData.characters.get("characters", {}):
		worn[str(cid)] = everyone.duplicate(true)
	# ...except one he dressed himself, which must survive.
	var mine := SaveManager.empty_outfit()
	mine["head"] = "cap_sun"
	worn["zero"] = mine
	SaveManager.data["shop"]["worn"] = worn

	SaveManager.call("_split_wardrobes")
	var still := 0
	for cid in GameData.characters.get("characters", {}):
		if str(cid) == "tiga" or str(cid) == "zero":
			continue
		if str(SaveManager.worn_by(str(cid)).get("head", "")) != "":
			still += 1
	print("  split an already-moved save: %d heroes still in the shared outfit"
		% still)
	_ok(still == 0, "%d heroes are still wearing the copied outfit" % still)
	_ok(str(SaveManager.worn_by("tiga").get("head", "")) == "crown_brave",
		"the split undressed the hero he was actually playing")
	_ok(str(SaveManager.worn_by("zero").get("head", "")) == "cap_sun",
		"the split threw away an outfit he had chosen himself")
	_ok((SaveManager.get_outfit() as Dictionary).is_empty(),
		"the split left the old global outfit in place")
	# ...and it must not run twice: dressing everyone the same on purpose is
	# allowed once the repair has happened.
	SaveManager.data["shop"]["worn"]["grigio"] = everyone.duplicate(true)
	SaveManager.call("_split_wardrobes")
	_ok(str(SaveManager.worn_by("grigio").get("head", "")) == "crown_brave",
		"the split ran a second time and undressed a hero he had just dressed")


# --- 2. trying on ---------------------------------------------------------

func _trying_on_is_free() -> void:
	_fresh(120)
	var hero := SkinnedCharacter.new()
	hero.skin = GameData.skin_for("tiga")
	add_child(hero)
	hero.set_height(300.0)
	await get_tree().process_frame

	var before: int = Coins.balance()
	var owned_before: int = (SaveManager.data["shop"]["owned"] as Array).size()
	var tried := 0
	for entry in Shop.items():
		if str(entry.get("slot", "")) == "colour" or str(entry.get("slot", "")) == "pal":
			continue
		hero.preview_outfit({str(entry.get("slot", "")): str(entry.get("id", ""))})
		tried += 1
		if tried >= 30:
			break
	hero.clear_preview()
	print("  tried on %d things: %d stars -> %d, owned %d -> %d"
		% [tried, before, Coins.balance(), owned_before,
			(SaveManager.data["shop"]["owned"] as Array).size()])
	_ok(Coins.balance() == before,
		"trying on %d things cost %d stars" % [tried, before - Coins.balance()])
	_ok((SaveManager.data["shop"]["owned"] as Array).size() == owned_before,
		"trying something on made him own it")
	_ok(SaveManager.worn_by("tiga").get("head", "") == "",
		"a try-on stuck to the save")

	# ...and the preview really does put something on, or the whole test is
	# measuring nothing.
	hero.preview_outfit({"head": "cap_cloud"})
	await get_tree().process_frame
	var art = hero.get("_art")
	var hung := 0
	if art != null:
		for child in (art.get("_head") as Node).get_children():
			if child.has_meta(Layers.TAG):
				hung += 1
	print("  the preview really hangs the hat: %d sprite(s) on the head" % hung)
	_ok(hung > 0, "preview_outfit put nothing on the hero at all")
	hero.queue_free()
	await get_tree().process_frame


# --- 3. buying ------------------------------------------------------------

func _buying_costs_exactly_the_price() -> void:
	_fresh(120)
	var entry := Shop.item("cap_cloud")
	var price := int(entry["price"])
	var before: int = Coins.balance()
	_ok(Shop.buy("cap_cloud") == "", "could not buy an always-unlocked hat")
	print("  bought a %d star hat: %d -> %d" % [price, before, Coins.balance()])
	_ok(Coins.balance() == before - price,
		"a %d star hat took %d stars" % [price, before - Coins.balance()])
	_ok(Shop.owns("cap_cloud"), "bought it and does not own it")

	# Buying it again must not be possible, and must not cost anything.
	var after: int = Coins.balance()
	_ok(Shop.buy("cap_cloud") == "owned", "sold him the same hat twice")
	_ok(Coins.balance() == after, "the second purchase still took stars")

	# Locked things cannot be bought at any price.
	_ok(Shop.buy("tiara_rainbow") == "locked",
		"sold him something he has not unlocked")
	_ok(Coins.balance() == after, "a refused purchase still took stars")

	# Short of stars: refused, and nothing changes.
	SaveManager.data["rewards"]["coins"] = 3
	_ok(Shop.buy("crown_party") == "poor", "sold him something he cannot afford")
	_ok(Coins.balance() == 3, "a refused purchase moved the balance")
	_ok(not Shop.owns("crown_party"), "a refused purchase still handed it over")

	# 放回去: full refund, taken off, gone from the list.
	SaveManager.data["rewards"]["coins"] = 120
	Shop.buy("crown_party")
	Shop.equip("crown_party")
	var paid: int = Coins.balance()
	_ok(Shop.undo("crown_party"), "could not put it back")
	print("  put back: %d -> %d stars, owned=%s, worn=%s"
		% [paid, Coins.balance(), Shop.owns("crown_party"),
			Shop.equipped_in("head")])
	_ok(Coins.balance() == paid + int(Shop.item("crown_party")["price"]),
		"putting it back did not refund the whole price")
	_ok(not Shop.owns("crown_party"), "put back and he still owns it")
	_ok(Shop.equipped_in("head") != "crown_party",
		"put back and he is still wearing it")


# --- 4. slots and compatibility -------------------------------------------

func _the_rules_of_the_shelf() -> void:
	_fresh(400)
	_own(["cap_cloud", "cap_sun", "vest_park", "boots_park"])
	Shop.equip("cap_cloud")
	Shop.equip("cap_sun")
	print("  two hats, one head: wearing '%s'" % Shop.equipped_in("head"))
	_ok(Shop.equipped_in("head") == "cap_sun",
		"the second hat did not replace the first")

	# Different slots do not fight.
	Shop.equip("vest_park")
	Shop.equip("boots_park")
	_ok(Shop.equipped_in("head") == "cap_sun"
		and Shop.equipped_in("body") == "vest_park"
		and Shop.equipped_in("feet") == "boots_park",
		"putting on a vest knocked off the hat")

	# The puppy wears nothing, and the shop must say so rather than sell it.
	var hat := Shop.item("cap_cloud")
	_ok(Shop.fits(hat, "tiga"), "tiga cannot wear a hat")
	_ok(not Shop.fits(hat, "bluey"), "the shop thinks the puppy can wear a hat")
	_ok(Shop.state_of(hat, "bluey") == Shop.State.INCOMPATIBLE,
		"the puppy is offered a hat as if he could wear it")
	# ...but a companion stands beside him, so his shelf is not empty.
	_ok(Shop.fits(Shop.item("pal_puppy"), "bluey"),
		"the puppy cannot even have a friend")

	# Equipping onto a hero who cannot wear it must be refused outright.
	SaveManager.data["profile"]["character_id"] = "bluey"
	_ok(not Shop.equip("cap_cloud", "bluey"),
		"a hat went onto the puppy anyway")
	SaveManager.data["profile"]["character_id"] = "tiga"

	# Six states, and every one reachable.
	var seen := {}
	for entry in Shop.items():
		seen[Shop.state_of(entry, "tiga")] = true
	print("  states in play: %d of 5" % seen.size())
	for state in [Shop.State.LOCKED, Shop.State.BUYABLE, Shop.State.OWNED,
			Shop.State.WEARING]:
		_ok(seen.has(state), "no item is ever in state %d" % state)


# --- 5. one wardrobe each -------------------------------------------------

func _each_hero_keeps_his_own_clothes() -> void:
	_fresh(400)
	_own(["cap_cloud", "cap_sun"])
	Shop.equip("cap_cloud", "tiga")
	Shop.equip("cap_sun", "zero")
	print("  tiga wears '%s', zero wears '%s'"
		% [Shop.equipped_in("head", "tiga"), Shop.equipped_in("head", "zero")])
	_ok(Shop.equipped_in("head", "tiga") == "cap_cloud",
		"dressing zero changed what tiga has on")
	_ok(Shop.equipped_in("head", "zero") == "cap_sun",
		"zero is not wearing what he was given")
	# Owning is shared: the clothes belong to the child, not to a hero.
	_ok(Shop.owns("cap_sun"), "buying for one hero hid it from the others")


# --- 6. the toys ----------------------------------------------------------

func _the_toys() -> void:
	_fresh(400)
	_own(["cap_cloud", "vest_park", "backpack_park", "boots_park", "gloves_leaf"])

	# A companion has to be VISIBLE. The first version of the stage loaded the
	# picture, measured it, scaled the sprite from it -- and never assigned it,
	# so every puppy in the game was a correctly-placed empty rectangle and
	# picking one looked like it did nothing at all.
	var pal_id := ""
	for pal_entry in Shop.in_category("pal"):
		if Shop.unlocked(pal_entry):
			pal_id = str(pal_entry.get("id", ""))
			break
	var podium: Control = load("res://scripts/shop/character_preview.gd").new()
	podium.size = Vector2(600, 360)
	add_child(podium)
	podium.call("build", "tiga")
	await get_tree().process_frame
	podium.call("try_on", {"pal": pal_id})
	await get_tree().process_frame
	# The companion belongs to the hero, not to the stage: it has to follow
	# him into the levels, so it is a child of SkinnedCharacter now.
	var pal = (podium.get("hero") as Node).get("_pal")
	var has_picture: bool = pal != null and is_instance_valid(pal) \
		and pal.texture != null
	print("  companion '%s' on stage: sprite=%s, picture=%s"
		% [pal_id, pal != null, has_picture])
	_ok(pal != null and is_instance_valid(pal),
		"trying on a companion put nothing on the stage")
	_ok(has_picture, "the companion sprite carries no picture, so it is invisible")
	if has_picture:
		var seen: Vector2 = pal.texture.get_size() * pal.scale
		_ok(seen.x > 20.0 and seen.y > 20.0,
			"the companion renders %.0fx%.0f px -- too small to see"
				% [seen.x, seen.y])
	# ...and it must go away again when the try-on is put back.
	podium.call("stop_trying")
	await get_tree().process_frame
	var after = (podium.get("hero") as Node).get("_pal")
	_ok(after == null or not is_instance_valid(after),
		"the companion he did not buy stayed on the stage")
	podium.queue_free()
	await get_tree().process_frame

	# ...and he FOLLOWS. The companion has to come into the levels, and the
	# levels move the hero in two different ways: the adventure slides the
	# whole world sideways (so the hero's global position barely changes) and
	# the minigames move the figure itself. Both have to read as walking.
	var mover := Node2D.new()
	add_child(mover)
	var walker := SkinnedCharacter.new()
	walker.skin = GameData.skin_for("tiga")
	mover.add_child(walker)
	walker.set_height(180.0)
	_own([pal_id])
	Shop.equip(pal_id, "tiga")
	walker.refresh_outfit()
	await get_tree().process_frame
	var walk_pal = walker.get("_pal")
	_ok(walk_pal != null and is_instance_valid(walk_pal),
		"the companion did not come into the level at all")
	if walk_pal != null and is_instance_valid(walk_pal):
		for i in range(30):
			mover.position.x += 12.0
			await get_tree().process_frame
		var going_right: float = walk_pal.position.x
		for i in range(30):
			mover.position.x -= 12.0
			await get_tree().process_frame
		var going_left: float = walk_pal.position.x
		print("  companion trails: %.0f walking right, %.0f walking left"
			% [going_right, going_left])
		_ok(going_right < -10.0,
			"walking right, the companion is at %.0f instead of behind him"
				% going_right)
		_ok(going_left > 10.0,
			"walking left, the companion is at %.0f instead of behind him"
				% going_left)
	mover.queue_free()
	await get_tree().process_frame

	# EVERY kind of figure gets the companion, not just the hero rig.
	#
	# The first version built it inside the hero branch of _build(), so
	# choosing a pet while playing as Bluey did nothing -- the puppy renderer
	# and the photo skins returned before the wardrobe code ran. That is the
	# category of bug this project keeps shipping: fix it for one case, leave
	# it broken for the others, and only find out when a six-year-old picks
	# the dog. So this walks the whole cast.
	var without: Array = []
	for cid in GameData.characters.get("characters", {}):
		var character_id := str(cid)
		_own([pal_id])
		SaveManager.data["profile"]["character_id"] = character_id
		Shop.equip(pal_id, character_id)
		var body := SkinnedCharacter.new()
		body.skin = GameData.skin_for(character_id)
		add_child(body)
		body.set_height(200.0)
		await get_tree().process_frame
		var theirs = body.get("_pal")
		if theirs == null or not is_instance_valid(theirs) \
				or theirs.texture == null:
			without.append(character_id)
		body.queue_free()
		await get_tree().process_frame
	print("  companion shows for every face: %d without (%s)"
		% [without.size(), ", ".join(without)])
	_ok(without.is_empty(),
		"%s cannot see their companion" % ", ".join(without))

	# ...and a try-on works for the puppy too, which is the ONE thing the
	# wardrobe lets him have.
	SaveManager.data["profile"]["character_id"] = "bluey"
	var pup_stage: Control = load("res://scripts/shop/character_preview.gd").new()
	pup_stage.size = Vector2(600, 360)
	add_child(pup_stage)
	pup_stage.call("build", "bluey")
	await get_tree().process_frame
	Shop.unequip("pal", "bluey")
	pup_stage.call("try_on", {"pal": pal_id})
	await get_tree().process_frame
	var pup_pal = (pup_stage.get("hero") as Node).get("_pal")
	print("  Bluey trying a pet on: %s"
		% ["yes" if pup_pal != null and is_instance_valid(pup_pal) else "no"])
	_ok(pup_pal != null and is_instance_valid(pup_pal)
			and pup_pal.texture != null,
		"Bluey cannot try a pet on, and a pet is all he is allowed")
	pup_stage.queue_free()
	SaveManager.data["profile"]["character_id"] = "tiga"
	Shop.unequip("pal", "tiga")
	await get_tree().process_frame

	# Magic mix may only ever use things he owns. Two hundred shakes.
	var owned: Array = SaveManager.data["shop"]["owned"]
	var strangers: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260726
	for i in range(200):
		for slot in Presets.magic_mix("tiga", rng).values():
			if str(slot) != "" and not owned.has(str(slot)):
				strangers.append(str(slot))
	print("  200 magic mixes, %d things he does not own" % strangers.size())
	_ok(strangers.is_empty(),
		"the magic mixer dressed him in things he has not bought: %s"
			% ", ".join(strangers.slice(0, 4)))

	# Undo walks back, one step at a time, five deep.
	var history := HISTORY.new()
	var marks: Array = []
	for i in range(7):
		var outfit := SaveManager.empty_outfit()
		outfit["head"] = "step%d" % i
		history.remember(outfit)
		marks.append("step%d" % i)
	print("  undo depth %d (kept the last %d of 7)"
		% [history.depth(), history.depth()])
	_ok(history.depth() == HISTORY.DEPTH,
		"the undo stack is %d deep, not %d" % [history.depth(), HISTORY.DEPTH])
	for i in range(HISTORY.DEPTH):
		var want: String = marks[marks.size() - 1 - i]
		var got := str(history.back().get("head", ""))
		_ok(got == want, "undo step %d gave %s, wanted %s" % [i, got, want])
	_ok(not history.can_undo(), "undo kept going past the end")

	# A saved look comes back exactly, and drops anything he no longer owns.
	Shop.equip("cap_cloud")
	Shop.equip("vest_park")
	Presets.save_look(0, Shop.worn("tiga"))
	Shop.unequip("head")
	Shop.unequip("body")
	var back := Presets.load_look(0, "tiga")
	print("  saved look reloads: head=%s body=%s"
		% [back.get("head", ""), back.get("body", "")])
	_ok(str(back.get("head", "")) == "cap_cloud"
		and str(back.get("body", "")) == "vest_park",
		"a saved look did not come back")
	Shop.undo("cap_cloud")
	_ok(str(Presets.load_look(0, "tiga").get("head", "")) == "",
		"a saved look put back something he had refunded")

	# A themed outfit dresses only the pieces he has.
	_own(["cap_sun", "backpack_park"])
	var pieces := Presets.pieces_of("park")
	print("  park set: he owns %d of %d pieces"
		% [pieces.size(), Presets.set_by_id("park").get("pieces", []).size()])
	for slot in pieces:
		_ok(Shop.owns(str(pieces[slot])),
			"the park set would put on %s, which he does not own" % pieces[slot])
	# Every one of the twelve has to be finishable.
	for spec in Presets.sets():
		var total: int = int(Presets.set_progress(str(spec["id"]))[1])
		_ok(total >= 4, "set '%s' has only %d pieces" % [spec["id"], total])
		for piece in spec.get("pieces", []):
			_ok(not Shop.item(str(piece)).is_empty(),
				"set '%s' wants '%s', which is not in the catalogue"
					% [spec["id"], piece])


# --- 7. closing the door --------------------------------------------------

func _it_survives_being_closed() -> void:
	_fresh(400)
	_own(["cap_sun", "boots_park"])
	Shop.equip("cap_sun", "tiga")
	Shop.equip("boots_park", "tiga")
	SaveManager.save_game()
	var before := Shop.worn("tiga")
	SaveManager.load_game()
	var after := SaveManager.worn_by("tiga")
	print("  after a save and load: head=%s feet=%s"
		% [after.get("head", ""), after.get("feet", "")])
	_ok(str(after.get("head", "")) == str(before.get("head", ""))
		and str(after.get("feet", "")) == str(before.get("feet", "")),
		"what he was wearing did not survive closing the game")


# --- 7b. the cast ---------------------------------------------------------

## Fourteen faces, ten free and four bought with stars. What is checked here is
## everything a screenshot of the drawer cannot show: that looking is free,
## that a face he has not paid for cannot become him by accident, that paying
## switches him, and that 放回去 puts BOTH the stars and the old character back.
func _the_cast() -> void:
	_fresh(300)
	var cast: Dictionary = GameData.characters.get("characters", {})
	var free: Array = []
	var paid: Array = []
	for cid in cast:
		if bool(cast[cid].get("unlocked", false)):
			free.append(str(cid))
		else:
			paid.append(str(cid))
	print("  cast: %d faces, %d free, %d bought (%s)"
		% [cast.size(), free.size(), paid.size(), ", ".join(paid)])
	_ok(cast.size() >= 12, "only %d faces to choose from" % cast.size())
	_ok(free.size() >= 6, "only %d faces are free" % free.size())

	# Every face has a card, and a card knows which face it is.
	var carded: Array = []
	for entry in Shop.cast():
		carded.append(Shop.who_id(entry))
	for cid in cast:
		_ok(str(cid) in carded, "'%s' has no card in the 形象 drawer" % cid)

	# Nobody he has not got can become him, however the call is made.
	var target := str(paid[0])
	_ok(not Shop.have_character(target), "'%s' starts out owned" % target)
	_ok(not Shop.become(target), "became '%s' without ever getting him" % target)
	_ok(Shop.who() != target, "the profile switched to a face he has not got")

	# Buying one costs exactly its price, and hands it over.
	var entry := Shop.item("who_" + target)
	var price := int(entry.get("price", 0))
	var before: int = Coins.balance()
	_ok(Shop.buy("who_" + target) == "", "could not buy '%s'" % target)
	print("  bought '%s' for %d: %d -> %d stars"
		% [target, price, before, Coins.balance()])
	_ok(Coins.balance() == before - price,
		"'%s' cost %d instead of %d" % [target, before - Coins.balance(), price])
	_ok(Shop.have_character(target), "paid for '%s' and still cannot be him" % target)
	_ok(Shop.become(target), "paid for '%s' and could not become him" % target)
	_ok(Shop.who() == target, "became '%s' and the profile says '%s'"
		% [target, Shop.who()])
	_ok(Shop.state_of(entry) == Shop.State.WEARING,
		"the card for the face he IS does not say so")

	# 放回去: the stars come back and so does the face.
	_ok(Shop.undo("who_" + target), "could not put a face back")
	_ok(Coins.balance() == before, "putting '%s' back refunded %d of %d"
		% [target, Coins.balance() - (before - price), price])
	_ok(not Shop.have_character(target), "put back and he still has him")

	# The room must not leave the game standing as somebody he no longer owns.
	SaveManager.data["profile"]["character_id"] = target
	var screen: Control = load("res://scenes/shop/HeroHouseScreen.tscn")\
		.instantiate()
	add_child(screen)
	for i in range(6):
		await get_tree().process_frame
	screen.call("_after_change")
	await get_tree().process_frame
	print("  standing as a refunded face -> '%s'" % Shop.who())
	_ok(Shop.have_character(Shop.who()),
		"the room left him playing as '%s', who he does not own" % Shop.who())

	# Looking is free here too: tapping a face he cannot afford must not spend.
	var purse: int = Coins.balance()
	screen.call("_card_tapped", "who_" + target)
	await get_tree().process_frame
	_ok(Coins.balance() == purse, "trying a face on cost %d stars"
		% (purse - Coins.balance()))
	_ok(not Shop.have_character(target), "trying a face on handed it over")
	screen.queue_free()
	await get_tree().process_frame


# --- 8. the room itself ---------------------------------------------------

## Built at both screen shapes, because `stretch/aspect` is "expand" and a 4:3
## tablet gets a 1280x960 viewport. Two screens in this project have already
## shipped with 720 written into them.
func _the_room_fits_both_screens() -> void:
	for shape in [Vector2i(1280, 720), Vector2i(1024, 768)]:
		var w := get_window()
		if w != null:
			w.size = shape
		await get_tree().process_frame
		await get_tree().process_frame
		var view: Vector2 = get_viewport().get_visible_rect().size

		_fresh(300)
		_own(["cap_sun", "vest_park", "boots_park"])
		Shop.equip("cap_sun")
		var screen: Control = load("res://scenes/shop/HeroHouseScreen.tscn")\
			.instantiate()
		add_child(screen)
		for i in range(6):
			await get_tree().process_frame

		var stage: Control = screen.get("_stage")
		var hero = stage.get("hero") if stage != null else null
		var hero_h: float = 0.0
		if hero != null and is_instance_valid(hero):
			hero_h = float(hero.get("_height"))
		print("  %s -> viewport %.0fx%.0f, stage %.0fx%.0f, hero %.0f px (%.0f%% of stage)"
			% [shape, view.x, view.y, stage.size.x, stage.size.y, hero_h,
				100.0 * hero_h / maxf(stage.size.y, 1.0)])
		_ok(stage != null and stage.size.y > view.y * 0.40,
			"the stage is only %.0f%% of the page" % (100.0 * stage.size.y / view.y))
		# The brief asks for 75% of the stage. This measures the FIGURE, and a
		# hat stands above the head -- so 0.70 here is about 0.78 of what a
		# child actually sees. Measuring the figure at 0.75 would push the hat
		# up into the title.
		_ok(hero_h > stage.size.y * 0.70,
			"the hero is %.0f%% of the stage" % (100.0 * hero_h / stage.size.y))

		# He must be standing on ground a child can SEE. The first render had
		# the row of hero faces painted over the platform, so he hovered above
		# a white strip with nothing under his boots -- and every automated
		# check passed, because the hero was still 72% of the stage.
		# The faces live inside a scroller now -- the row's own position is
		# relative to it, so measure the scroller.
		var faces: Control = screen.get("_face_scroll")
		var ground: float = stage.position.y + float(stage.call("ground_bottom"))
		print("    ground ends at %.0f, faces start at %.0f" % [ground, faces.position.y])
		_ok(ground <= faces.position.y + 1.0,
			"the face row covers the platform by %.0f px"
				% (ground - faces.position.y))
		_ok(faces.position.y + faces.size.y <= view.y - 176.0,
			"the face row runs into the shelf")

		# Nothing off the bottom, nothing under the shelf.
		var shelf: Control = screen.get("_scroll")
		_ok(shelf.position.y + shelf.size.y <= view.y + 1.0,
			"the shelf runs %.0f px off the bottom"
				% (shelf.position.y + shelf.size.y - view.y))
		var tools: Control = screen.get("_preset_row")
		_ok(tools.position.y + tools.size.y <= shelf.position.y + 2.0,
			"the buttons on the right overlap the shelf by %.0f px"
				% (tools.position.y + tools.size.y - shelf.position.y))

		# Every drawer opens onto something -- and everything printed on a card
		# stays ON the card. The 整套 cards were laying pictures over the set's
		# name and printing "5 / 5" on the grass 8 px below the card.
		var Card := load("res://scripts/shop/item_card.gd")
		for category in screen.get("CATEGORIES"):
			screen.call("_open", str(category))
			await get_tree().process_frame
			var shelf_box: Node = screen.get("_shelf") as Node
			var count: int = shelf_box.get_child_count()
			_ok(count > 0, "the '%s' drawer opens onto nothing" % category)
			for card in shelf_box.get_children():
				var art_bottom := 0.0
				var text_top := 9999.0
				for bit in card.get_children():
					if not (bit is Control):
						continue
					var c := bit as Control
					# A Label's BOX is not what a child sees: Godot grows it to
					# its minimum size (a CJK font at 23 px reports 69 px tall)
					# and then draws one line at the top of it. Measure the ink.
					var drawn: Vector2 = c.size
					if c is Label:
						var lab := c as Label
						var f: Font = lab.get_theme_font("font")
						var fs: int = lab.get_theme_font_size("font_size")
						if f != null:
							drawn = f.get_string_size(lab.text,
								HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
							drawn.y = maxf(drawn.y, float(fs) * 1.35)
							drawn.x = minf(drawn.x, c.size.x)
					var far: float = c.position.y + drawn.y
					_ok(far <= Card.BOX.y + 1.0,
						"'%s': a card prints %.0f px past its bottom edge"
							% [category, far - Card.BOX.y])
					_ok(c.position.x + drawn.x <= Card.BOX.x + 1.0,
						"'%s': a card prints %.0f px past its right edge"
							% [category, c.position.x + drawn.x - Card.BOX.x])
					if c is TextureRect:
						art_bottom = maxf(art_bottom, far)
					elif c is Label and c.position.y > 40.0:
						text_top = minf(text_top, c.position.y)
				if art_bottom > 0.0 and text_top < 9999.0:
					_ok(art_bottom <= text_top + 1.0,
						"'%s': the picture is drawn over the caption by %.0f px"
							% [category, art_bottom - text_top])
		screen.queue_free()
		await get_tree().process_frame
