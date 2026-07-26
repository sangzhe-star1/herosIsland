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
	for suffix in [".wav", ".ogg", ".mp3"]:
		var path := "res://assets/audio/voice/level/%s_intro%s" % [level_id, suffix]
		if ResourceLoader.exists(path):
			play_voice(path)
			return true
	return false


## The shared lines -- praise, retry, the three hint steps. Same deal: present
## means spoken, absent means silent.
func say(name: String) -> bool:
	for suffix in [".wav", ".ogg", ".mp3"]:
		var path := "res://assets/audio/voice/level/%s%s" % [name, suffix]
		if ResourceLoader.exists(path):
			play_voice(path)
			return true
	return false


func _on_voice_finished() -> void:
	_music.volume_db = _music_base_db


func _load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	# Voice lines generated on the family Mac arrive as .wav (tools/
	# make_voice.command); every call site says .ogg, so fall through.
	if path.ends_with(".ogg"):
		var wav := path.trim_suffix(".ogg") + ".wav"
		if ResourceLoader.exists(wav):
			return load(wav) as AudioStream
	return null
