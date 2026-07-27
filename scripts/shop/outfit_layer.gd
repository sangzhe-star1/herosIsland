extends RefCounted
## Hangs painted clothes on the hero's bones.
##
##     const Layers := preload("res://scripts/shop/outfit_layer.gd")
##     Layers.dress(hero_art, {"head": "cap_cloud", "feet": "boots_park"})
##
## The whole design rests on one property of `hero_art.gd`: its node tree is
##
##     self -> _spin -> _root -> { _leg_back, _arm_back, _torso,
##                                 _leg_front, _head, _arm_front, caps }
##
## and those nodes are ALREADY what the poses move. So a Sprite2D parented to
## `_head` follows every nod, hop, spin and cheer for free -- no animation code
## on the clothes at all, ever. That was the single biggest unknown in this
## feature and it was checked with a throwaway spike before a line of the real
## thing was written: a hero in a full rescue outfit, four poses, everything
## staying where it belonged.
##
## The spike also found the two things that are wrong by default:
##
##   1. BOOTS AND GLOVES COME IN PAIRS, in one picture. Parenting the whole
##      picture to each leg gives the hero four boots. Each limb gets half,
##      cut down the middle with an AtlasTexture -- no re-drawing.
##
##   2. THE ART IS DRAWN AT ICON SCALE, not at "worn on this body" scale. A hat
##      that fills a 1024 px frame is enormous next to a 232-unit hero. That is
##      not a re-draw either: it is three numbers per item, which live in
##      data/character_slots.json.

const Art := preload("res://scripts/reward/monster_art.gd")

## Marks the sprites this file added, so re-dressing removes only its own work
## and never a piece of the hero.
const TAG := "outfit_layer"

static func _slots() -> Dictionary:
	return GameData.character_slots


## Where a piece hangs and how big it is drawn. Slot default, then whatever the
## item overrides.
static func placement(item_id: String, slot: String) -> Dictionary:
	var table := _slots()
	var base: Dictionary = table.get("slots", {}).get(slot, {})
	if base.is_empty():
		return {}
	var out := base.duplicate(true)
	var over: Dictionary = table.get("items", {}).get(item_id, {})
	for key in over:
		out[key] = over[key]
	return out


## Half of a pair picture. Boots and gloves are drawn two-in-one; each limb
## takes one of them, or the hero grows four feet.
static func half(tex: Texture2D, right: bool) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var w := float(tex.get_width()) * 0.5
	atlas.region = Rect2(w if right else 0.0, 0.0, w, float(tex.get_height()))
	return atlas


static func undress(art: Node) -> void:
	if art == null or not is_instance_valid(art):
		return
	for bone_name in ["_head", "_torso", "_root", "_leg_front", "_leg_back",
			"_arm_front", "_arm_back"]:
		var bone = art.get(bone_name)
		if bone == null or not is_instance_valid(bone):
			continue
		for child in (bone as Node).get_children():
			if child.has_meta(TAG):
				(bone as Node).remove_child(child)
				child.queue_free()


## Put an outfit on. `outfit` is slot -> item id; "" means bare.
##
## Returns how many pieces actually went on, which is what a test can assert
## on -- "the hero looks dressed" is not something a headless run can see.
static func dress(art: Node, outfit: Dictionary) -> int:
	if art == null or not is_instance_valid(art):
		return 0
	undress(art)
	var Shop := load("res://scripts/shop/shop_manager.gd")
	var worn := 0
	# Colour first: it repaints the figure underneath, so it has to happen
	# before anything is hung on top of it.
	_repaint(art, str(outfit.get("colour", "")), Shop)
	# Back first so a cape sits behind the legs; the rest front to back.
	for slot in ["back", "body", "feet", "hands", "head"]:
		var item_id := str(outfit.get(slot, ""))
		if item_id == "":
			continue
		var entry: Dictionary = Shop.item(item_id)
		var art_path := str(entry.get("art", ""))
		if art_path == "":
			continue
		var tex: Texture2D = Art._load(art_path)
		if tex == null:
			push_error("outfit_layer: %s has no loadable picture at %s"
				% [item_id, art_path])
			continue
		var place := placement(item_id, slot)
		if place.is_empty():
			continue
		worn += _hang(art, tex, place, slot)
	return worn


## Recolour the hero himself. Deliberately only the body, the accent and the
## trim: 迪迦's chest chevron, 赛罗's blade and every eye colour are what a
## six-year-old uses to tell one hero from another, and the brief forbids
## touching them. A palette that turns everyone into the same blue shape is a
## palette that costs the game its cast.
static func _repaint(art: Node, colour_id: String, Shop: Variant) -> void:
	if colour_id == "":
		return
	var entry: Dictionary = Shop.item(colour_id)
	if entry.is_empty():
		return
	var design = art.get("design")
	if design == null:
		return
	var body := Color.from_string(str(entry.get("body_color", "")), Color.WHITE)
	var accent := Color.from_string(str(entry.get("accent_color", "")),
		body.darkened(0.25))
	# A tint on the whole figure, not a repaint of the resource: the resource
	# is shared between every screen that draws this hero, and writing to it
	# here would recolour him in the levels too.
	var rig = art.get("_rig") if art.get("_rig") != null else art.get("_root")
	if rig != null and is_instance_valid(rig):
		(rig as CanvasItem).modulate = body.lerp(Color.WHITE, 0.45)
	if art.has_method("set_core_color"):
		art.call("set_core_color", accent.lightened(0.25))


static func _hang(art: Node, tex: Texture2D, place: Dictionary, slot: String) -> int:
	var at_raw: Array = place.get("at", [0, 0])
	var at := Vector2(float(at_raw[0]), float(at_raw[1]))
	var width := float(place.get("width", 80.0))
	var behind := bool(place.get("behind", false))
	var paired := bool(place.get("pair", false))

	var bones: Array = []
	if paired:
		# Front limb gets the right-hand half, back limb the left-hand one, so
		# the two are mirror images the way a real pair is.
		bones = [["_leg_front" if slot == "feet" else "_arm_front", true, 1.0],
				 ["_leg_back" if slot == "feet" else "_arm_back", false, -1.0]]
	else:
		bones = [[str(place.get("bone", "_root")), false, 1.0]]

	var hung := 0
	for spec in bones:
		var bone = art.get(str(spec[0]))
		if bone == null or not is_instance_valid(bone):
			continue
		var use := half(tex, bool(spec[1])) if paired else tex
		var sprite := Sprite2D.new()
		sprite.texture = use
		sprite.set_meta(TAG, true)
		var scale: float = width / maxf(float(use.get_width()), 1.0)
		sprite.scale = Vector2(scale, scale)
		sprite.position = Vector2(at.x * float(spec[2]), at.y)
		(bone as Node).add_child(sprite)
		if behind:
			(bone as Node).move_child(sprite, 0)
		hung += 1
	return hung
