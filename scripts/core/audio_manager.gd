extends Node
## Three independent channels. Voice ducks music so spoken instructions are
## always intelligible -- at this age the voice line IS the instruction, since
## the child may not read yet.

var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _voice: AudioStreamPlayer

var _music_base_db := 0.0

## The island theme: quiet, slow, pentatonic. Starts with the app and simply
## keeps going -- one continuous piece of place, the way the gentle kids'
## apps do it. Parents turn it off with the music slider.
const THEME := "res://assets/audio/music/island_theme.ogg"


func _ready() -> void:
	print("[autoload] AudioManager starting")
	_music = AudioStreamPlayer.new()
	_sfx = AudioStreamPlayer.new()
	_voice = AudioStreamPlayer.new()
	# Named so a test can find it and check a spoken line really reached the
	# player. "The file is in the folder" and "a child hears it" are two
	# different claims, and this project has been caught by that gap before.
	_voice.name = "Voice"
	for p in [_music, _sfx, _voice]:
		add_child(p)
	_voice.finished.connect(_on_voice_finished)
	# Manual loop: restart on finish, so looping never depends on per-file
	# import flags.
	_music.finished.connect(func(): _music.play())
	apply_volumes()
	play_music(THEME)
	print("[autoload] AudioManager ok")


func apply_volumes() -> void:
	_music_base_db = linear_to_db(clampf(SaveManager.get_setting("music_volume", 0.8), 0.0, 1.0))
	_music.volume_db = _music_base_db
	_sfx.volume_db = linear_to_db(clampf(SaveManager.get_setting("sfx_volume", 1.0), 0.0, 1.0))
	_voice.volume_db = linear_to_db(clampf(SaveManager.get_setting("voice_volume", 1.0), 0.0, 1.0))


func play_music(path: String) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func play_sfx(path: String) -> void:
	var stream := _load_stream(path)
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


## Spoken instruction or praise. Silently no-ops until audio files are recorded,
## so the game is fully playable before any voiceover exists.
func play_voice(path: String) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	_speak(stream)


## Say it, and duck the music under it so the words win.
func _speak(stream: AudioStream) -> void:
	_voice.stream = stream
	_music.volume_db = _music_base_db - 12.0
	_voice.play()


## Say a level's own line, if somebody has recorded one.
##
## The whole point is that nothing else has to change. A parent reads the
## script in `docs/VOICE_SCRIPT.md` into a phone, drops the files into
## `assets/audio/voice/level/`, and every level starts speaking -- no JSON
## edit, no code, no rebuild of anything but the project. A level with no
## recording is silent and completely fine, which is the state the game
## ships in.
##
## Both `.wav` and `.ogg` are looked for, because a phone will hand you
## whichever it feels like and a parent should not have to convert anything.
func play_level_voice(level_id: String) -> bool:
	if level_id == "":
		return false
	return say("%s_intro" % level_id)


## The shared lines -- praise, retry, the three hint steps. Same deal: present
## means spoken, absent means silent.
##
## Returns whether a line was actually SPOKEN, not whether a file exists. Those
## were the same answer right up until they were not: see _load_stream().
func say(name: String) -> bool:
	if name == "":
		return false
	for suffix in [".ogg", ".wav", ".mp3"]:
		var path := "res://assets/audio/voice/level/%s%s" % [name, suffix]
		var stream := _load_stream(path)
		if stream != null:
			_speak(stream)
			return true
	return false


func _on_voice_finished() -> void:
	_music.volume_db = _music_base_db


## Load an audio file, by whatever route actually works.
##
## The first route is the ordinary one: Godot imports the file and load()
## returns the imported artifact. That is what runs in an exported build.
##
## The second route exists because of a silence that took a while to find. An
## audio file in the project is accompanied by a `.import` file which says
## where its imported artifact lives, under `.godot/imported/`. That folder is
## machine-local -- it is not in git and it is not copied between machines. So
## a project whose files arrived from somewhere else has 44 `.import` files
## pointing at 44 artifacts that do not exist, and until an editor rescans, the
## engine reports:
##
##   ResourceLoader.exists(path) -> true      ("I know that resource")
##   load(path)                  -> null      ("...I cannot produce it")
##
## Every voice line in the game went through that gap. `say()` checked exists(),
## got true, reported success, and played nothing. No error, no warning, no
## missing file -- just a game that had stopped talking.
##
## So: never trust exists() for something you are about to play, and when the
## import is missing, read the file straight off disk. AudioStream*.load_from_
## file() needs no import step at all, which also makes the folder genuinely
## drop-in the way its documentation always claimed: put a .wav in it and the
## game says it, with no editor round trip.
func _load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	var found := _one_file(path)
	if found != null:
		return found
	# Whichever extension the caller named, try the other one. Call sites say
	# ".ogg" by convention, and a line recorded on a phone arrives as ".wav" --
	# a parent should not have to convert anything, and the older templates
	# still ask for well_done.ogg where only well_done.wav has ever existed.
	var swapped := ""
	if path.ends_with(".ogg"):
		swapped = path.trim_suffix(".ogg") + ".wav"
	elif path.ends_with(".wav"):
		swapped = path.trim_suffix(".wav") + ".ogg"
	return _one_file(swapped) if swapped != "" else null


func _one_file(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var imported := load(path) as AudioStream
		if imported != null:
			return imported
		push_warning("AudioManager: %s is known but will not load -- its import "
			% path + "is missing. Reading it from disk instead.")
	if not FileAccess.file_exists(path):
		return null
	if path.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_file(path)
	if path.ends_with(".wav"):
		return AudioStreamWAV.load_from_file(path)
	return null
