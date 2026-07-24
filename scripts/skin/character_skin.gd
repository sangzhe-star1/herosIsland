class_name CharacterSkin
extends Resource
## The seam between "who the character is" and "what the level does".
##
## Level code NEVER references a character by name, only through this resource.
## Swapping the hero -- placeholder shape today, your son's drawing tomorrow,
## an original design in a released build -- is a data edit, not a code edit.

@export var id: String = ""
@export var display_name_key: String = ""

## Optional art. Any that is missing falls back to a coloured placeholder shape,
## so the game is fully playable before a single sprite exists.
@export var idle_texture: Texture2D
@export var cheer_texture: Texture2D
@export var walk_frames: SpriteFrames
@export var portrait: Texture2D

## Where the tintable chest light sits on idle_texture, in texture pixels
## relative to the texture's centre. The game recolours this light at runtime --
## in Repair the Energy Tower it IS the instruction -- so a textured skin must
## say where its light is. Radius 0 means "this skin has no tintable light",
## and colour-driven moments simply do nothing.
@export var core_offset: Vector2 = Vector2.ZERO
@export var core_radius: float = 0.0

## Placeholder appearance, used when idle_texture is null.
@export var body_color: Color = Color(0.85, 0.87, 0.9)
@export var accent_color: Color = Color(0.9, 0.25, 0.25)
@export var core_color: Color = Color(0.4, 0.85, 1.0)

## Voice line folder, e.g. "res://assets/audio/voice/light_hero/".
@export var voice_dir: String = ""

@export var body_size: Vector2 = Vector2(64, 96)


func voice(clip: String) -> String:
	if voice_dir == "":
		return ""
	return voice_dir.path_join(clip + ".ogg")
