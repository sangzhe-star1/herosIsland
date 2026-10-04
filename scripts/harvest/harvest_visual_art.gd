extends RefCounted
## Offline 3D renders used as passive 2D harvest artwork.
##
## The gameplay scene remains a 2D interaction surface. These helpers only
## resolve textures and place the shared orthographic ground pivot; targets,
## baskets, and the field still own every hit rule and state transition.

const CROP_ROOT := "res://assets/harvest_3d/crops/"
const PROP_ROOT := "res://assets/harvest_3d/props/"
const PLANT_ROOT := "res://assets/harvest_3d/plants/"
const SPRITE_CANVAS_MULTIPLIER := 2.0
## Projection of Blender world origin (0, 0, 0) in the shared 512px render.
## Kept as an explicit part of the export contract so every prop sits on the
## same screen-space ground line after scaling.
const GROUND_ORIGIN_PIXEL_Y := 467.0
const SOURCE_CANVAS_SIZE := 512.0

const CROP_IDS := [
	"carrot", "golden_carrot", "potato", "tomato", "strawberry", "corn",
	"orange", "apple", "peas", "pumpkin", "watermelon", "broccoli",
	"lettuce", "grape", "wheat", "stone", "bug",
]

const PROP_IDS := ["basket_empty", "soil_grass_patch", "soil_cover",
	# The farm's scenery, from the same studio as the crops (pipeline/recipes).
	"tree", "hedge", "stones", "tuft", "sprig_yellow", "sprig_pink", "sprig_lilac",
	# The farm's buildings, its fence, its dog and the neighbour.
	"building_hut", "building_seed_shop", "building_warehouse", "building_kennel",
	"building_well", "building_gate", "building_market", "building_orders",
	"building_visit_board", "building_decor", "building_orchard", "building_workshop",
	"building_bear_door", "fence", "fence_y", "dog", "bear",
	# The rest of the farm's life (data/farm_world_dressing.json).
	"tree_pine", "tree_fruit", "bush_flower", "flowerbed", "mushrooms", "log",
	"hay_bale", "wheelbarrow", "scarecrow", "windmill", "windmill_blades", "pond",
	"duck", "chicken", "signpost", "bench", "butterfly", "butterfly_blue",
	"building_coop", "egg"]
static var _crop_badge_region_cache: Dictionary = {}
static var _crop_ground_width_cache: Dictionary = {}
static var _plant_spec_cache: Dictionary = {}
static var _texture_used_region_cache: Dictionary = {}


## Measure contact near the shared ground pivot once per source crop. Leaves
## above the root must not turn a narrow stem into a wide soil platform.
static func crop_ground_width(crop_id: String, world_size: float) -> float:
	return texture_ground_width(crop_texture(crop_id), world_size)


static func texture_used_bounds(texture: Texture2D, world_size: float,
		source_anchor: Vector2, screen_anchor: Vector2 = Vector2.ZERO) -> Rect2:
	if texture == null:
		return Rect2()
	var key := texture.resource_path
	if not _texture_used_region_cache.has(key):
		var source := texture.get_image()
		_texture_used_region_cache[key] = Rect2(source.get_used_rect()) \
			if source != null else Rect2()
	var region: Rect2 = _texture_used_region_cache[key]
	var factor := world_size * SPRITE_CANVAS_MULTIPLIER / SOURCE_CANVAS_SIZE
	return Rect2(screen_anchor + (region.position - source_anchor) * factor,
		region.size * factor)


static func texture_ground_width(texture: Texture2D, world_size: float) -> float:
	var key := texture.resource_path if texture != null else ""
	if not _crop_ground_width_cache.has(key):
		var source := texture.get_image() if texture != null else null
		var left := int(SOURCE_CANVAS_SIZE)
		var right := -1
		if source != null:
			var first_y := maxi(0, int(GROUND_ORIGIN_PIXEL_Y) - 47)
			var last_y := mini(source.get_height() - 1, int(GROUND_ORIGIN_PIXEL_Y) + 23)
			for y in range(first_y, last_y + 1):
				for x in range(source.get_width()):
					if source.get_pixel(x, y).a >= 0.05:
						left = mini(left, x)
						right = maxi(right, x)
		_crop_ground_width_cache[key] = float(maxi(0, right - left + 1))
	return float(_crop_ground_width_cache[key]) * world_size \
		* SPRITE_CANVAS_MULTIPLIER / SOURCE_CANVAS_SIZE


## Optional passive plant body and detachable fruit share export coordinates.
## The page places the body beside the existing Target; no input or state
## lives in these specifications.
static func plant_layout(crop_id: String, art_scale: float) -> Dictionary:
	if not _plant_spec_cache.has(crop_id):
		var path := PLANT_ROOT + crop_id + ".json"
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) \
			if FileAccess.file_exists(path) else null
		_plant_spec_cache[crop_id] = parsed if parsed is Dictionary else {}
	var spec: Dictionary = _plant_spec_cache[crop_id]
	if spec.is_empty():
		return {}
	var body := _load_texture(str(spec.get("body", "")))
	var fruit := _load_texture(str(spec.get("fruit", "")))
	if body == null or fruit == null:
		return {}
	var anchor: Array = spec.get("fruit_slot_pixel", [256.0, 467.0])
	var centre: Array = spec.get("fruit_center_pixel", [256.0, 467.0])
	var slot := Vector2(float(anchor[0]), float(anchor[1]))
	var size := float(spec.get("body_world_size", 128.0)) * clampf(art_scale, 0.6, 1.0)
	var ground := (Vector2(256.0, GROUND_ORIGIN_PIXEL_Y) - slot) \
		* size * SPRITE_CANVAS_MULTIPLIER / SOURCE_CANVAS_SIZE
	return {"body": body, "fruit": fruit, "body_size": size,
		"slot_pixel": slot, "ground_at": ground,
		"fruit_center_pixel": Vector2(float(centre[0]), float(centre[1])),
		"fruit_size": size * float(spec.get("fruit_ortho", 1.08)) \
			/ float(spec.get("body_ortho", 2.95)) * float(spec.get("slot_scale", 1.13)) \
			/ float(spec.get("fruit_source_scale", 1.0))}


static func anchored_sprite(texture: Texture2D, world_size: float,
		source_anchor: Vector2, screen_anchor: Vector2,
		node_name: String) -> TextureRect:
	var sprite := grounded_sprite(texture, world_size, Vector2.ZERO, node_name)
	if sprite != null:
		sprite.position = screen_anchor - source_anchor \
			* world_size * SPRITE_CANVAS_MULTIPLIER / SOURCE_CANVAS_SIZE
	return sprite


static func crop_texture(crop_id: String) -> Texture2D:
	if crop_id not in CROP_IDS:
		return null
	return _load_texture(CROP_ROOT + crop_id + ".png")


static func prop_texture(prop_id: String) -> Texture2D:
	if prop_id not in PROP_IDS:
		return null
	return _load_texture(PROP_ROOT + prop_id + ".png")


## Fit the loose earth to the crop's visible size. The source ground pivot
## stays fixed; the transparent canvas must not determine the mound width.
static func soil_cover_layout(crop_size: float) -> Dictionary:
	var texture := prop_texture("soil_cover")
	if texture == null:
		return {}
	var unit := texture_used_bounds(texture, SOURCE_CANVAS_SIZE * 0.5,
		Vector2(256.0, GROUND_ORIGIN_PIXEL_Y))
	if unit.size.x <= 0.0:
		return {}
	var width := crop_size * 1.30
	var size := width / unit.size.x * SOURCE_CANVAS_SIZE * 0.5
	var ground := Vector2(0.0, 42.0)
	return {"texture": texture, "size": size, "ground_at": ground,
		"rect": texture_used_bounds(texture, size,
			Vector2(256.0, GROUND_ORIGIN_PIXEL_Y), ground)}


static func prop_has_baked_contact_shadow(prop_id: String) -> bool:
	var path := PROP_ROOT + prop_id + ".json"
	if not FileAccess.file_exists(path):
		return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return bool(parsed.get("contact_shadow_baked", true)) if parsed is Dictionary else true


## A compact square crop picture for the order card or a basket's sample tag.
## Unlike `grounded_sprite()`, this does not scale the transparent ground-pivot
## canvas to a world object; the icon keeps the same source artwork while
## fitting the existing UI badge box.
static func crop_badge(crop_id: String, box_size: float,
		node_name: String = "HarvestCropBadge") -> Control:
	var texture := crop_texture(crop_id)
	if texture == null:
		return null
	var region := _crop_badge_region(crop_id, texture)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return null
	var badge := Control.new()
	badge.name = node_name
	badge.custom_minimum_size = Vector2.ONE * box_size
	badge.size = Vector2.ONE * box_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = true
	sprite.scale = Vector2.ONE * (box_size / maxf(region.size.x, region.size.y))
	sprite.position = Vector2.ONE * (box_size * 0.5)
	badge.add_child(sprite)
	return badge



static func _crop_badge_region(crop_id: String, source: Texture2D) -> Rect2:
	var region: Rect2
	if _crop_badge_region_cache.has(crop_id):
		region = _crop_badge_region_cache[crop_id]
	else:
		var image := source.get_image()
		if image == null:
			return Rect2()
		var used := image.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			return Rect2()
		region = Rect2(used.position, used.size)
		_crop_badge_region_cache[crop_id] = region
	return region


## Build a passive, square TextureRect whose Blender ground origin lands at
## `ground_at`. `world_size` is the gameplay object's familiar display size;
## the source render uses a 2x transparent canvas so the modeled silhouette
## fills that same amount of screen space without cropping shadows or leaves.
static func grounded_sprite(texture: Texture2D, world_size: float,
		ground_at: Vector2, node_name: String = "Harvest3DSprite") -> TextureRect:
	if texture == null:
		return null
	var side := world_size * SPRITE_CANVAS_MULTIPLIER
	var sprite := TextureRect.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2.ONE * side
	sprite.size = Vector2.ONE * side
	sprite.position = ground_at - Vector2(side * 0.5,
		side * GROUND_ORIGIN_PIXEL_Y / SOURCE_CANVAS_SIZE)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
