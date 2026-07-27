extends RefCounted
## The one place a monster's picture is loaded.
##
##     const MonsterArt := preload("res://scripts/reward/monster_art.gd")
##
## Three screens draw the same creature -- the duel, the small foes in an
## adventure level, and the card in 怪兽图鉴 -- and the whole point of the
## album is that they are the same drawing. Three separate load() calls is how
## that stops being true, so there is one.
##
##
## WHY IT DOES NOT JUST CALL load()
##
## A .png in a Godot project is not the file the game reads. The editor imports
## it into .godot/imported/ and writes a .png.import file pointing at that
## artifact -- and the artifact is machine-local. Check in the .import file
## without the artifact and `ResourceLoader.exists()` says yes while `load()`
## returns null, on a machine whose editor has never opened the project.
##
## This has already cost this project one full debugging round, with the voice
## lines: every file present, every path correct, and total silence. The fix
## there was to read the file off disk when the import was missing, and it is
## the fix here. A monster that does not draw is a worse failure than a voice
## line that does not play -- it is an empty rectangle in the middle of a
## fight.

const DIR := "res://assets/characters/monsters/"

static var _cache: Dictionary = {}


static func path_for(monster_id: String) -> String:
	return "%s%s.png" % [DIR, monster_id]


## The picture, or null for a monster that is drawn by code instead.
static func texture(monster_id: String) -> Texture2D:
	if monster_id == "":
		return null
	if _cache.has(monster_id):
		return _cache[monster_id]
	var tex: Texture2D = _load(path_for(monster_id))
	_cache[monster_id] = tex
	return tex


static func has_art(monster_id: String) -> bool:
	return texture(monster_id) != null


static func _load(path: String) -> Texture2D:
	# The ordinary way first: in the editor and in an exported build this is
	# the whole story, and it gives us the imported (compressed, mipmapped)
	# texture rather than a raw one.
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			return res as Texture2D
	# ...and the way that works when the import artifact is not on this
	# machine. Image.load_from_file reads the actual .png.
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		push_error("MonsterArt: %s is on disk but will not decode" % path)
		return null
	return ImageTexture.create_from_image(image)
