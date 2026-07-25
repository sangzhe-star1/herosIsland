class_name CharacterSkin
extends Resource
## The seam between "who the character is" and "what the level does".
##
## Level code NEVER references a character by name, only through this resource.
## Swapping the hero -- an original design, a variant, your son's own drawing --
## is a data edit, not a code edit.
##
## What changed at the architecture pass: a skin used to be *a pair of PNGs*
## with a few fallback colours in case the art was missing. It is now *a design*
## -- proportions, crest shape, chest pattern, four colours -- that HeroArt
## draws. The pictures became optional rather than primary, which is what lets
## the hero be posed, lit by the scene, recoloured mid-level, and released.

@export var id: String = ""
@export var display_name_key: String = ""

# --- the design, which is what actually gets drawn ----------------------

## Shoulder width in local units. Everything else on the body is a fraction of
## it, so one number resizes the whole build: 76 is the standard hero, smaller
## reads younger, larger reads heavier.
@export var build_width: float = 76.0

## The shape on top of the head. In silhouette this is what a child recognises
## from across the room, so it is the design's signature.
@export_enum("fin", "twin", "horns") var crest_kind: String = "fin"

## How the accent sweeps across the chest.
@export_enum("blade", "chevron", "bands") var chest_pattern: String = "blade"

@export var body_color: Color = Color(0.87, 0.89, 0.92)   # the suit
@export var accent_color: Color = Color(0.91, 0.27, 0.27) # sweeps, crest, boots
@export var trim_color: Color = Color(1.00, 0.84, 0.35)   # the thin bright line
@export var eye_color: Color = Color(1.00, 0.94, 0.62)
@export var core_color: Color = Color(0.35, 0.88, 1.00)   # the chest light

# --- optional photographic art -----------------------------------------

## A skin MAY carry pictures instead of being drawn. Kept for two reasons: a
## scan of a child's own drawing belongs here, and the licensed render cut-outs
## still work for a private family build. Neither can be posed or lit, so the
## drawn design is the default and this is opt-in.
@export var prefer_texture: bool = false
@export var idle_texture: Texture2D
@export var cheer_texture: Texture2D
@export var walk_frames: SpriteFrames
@export var portrait: Texture2D

## Where the tintable chest light sits on idle_texture, in texture pixels from
## the texture's centre. Only meaningful for a textured skin -- a drawn one
## knows where its own core is.
@export var core_offset: Vector2 = Vector2.ZERO
@export var core_radius: float = 0.0

## Voice line folder, e.g. "res://assets/audio/voice/light_hero/".
@export var voice_dir: String = ""

## Legacy: the drawn placeholder's footprint. Levels that still ask for it get
## a figure of the right size; new code asks HeroArt for a height instead.
@export var body_size: Vector2 = Vector2(64, 96)


func voice(clip: String) -> String:
	if voice_dir == "":
		return ""
	return voice_dir.path_join(clip + ".ogg")


## True when this skin should be drawn rather than blitted. A skin with no
## texture is always drawn; a skin with one is drawn unless it asks not to be.
func is_drawn() -> bool:
	return idle_texture == null or not prefer_texture
