extends Node
## Does the voice actually come out?
##
## Written the day the recordings arrived, because "the files are in the right
## folder" and "a child hears them" are two different claims and this project
## has been caught by that gap before. It checks three things a filename
## listing cannot: that every level finds a line, that the shared lines are
## all present, and that asking for one actually loads a stream into the
## player rather than silently doing nothing.

var _out: Array[String] = []


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== voice check ===")

	# 0. Every line the CODE asks for has words written for it.
	#
	# The other checks below start from the level list and from a fixed list of
	# shared lines, so a line spoken from inside a screen -- the garden's first
	# planting lesson, the harvest's "not yet" -- was invisible to all of them.
	# Five of them shipped that way: the lesson a child meets on their very
	# first visit to the garden played in complete silence, and nothing here
	# said so, because nothing here was reading the code.
	_every_spoken_line_has_words()

	# 1. Every level that should speak, can.
	var missing: Array = []
	var found := 0
	for level in GameData.levels:
		var lid := str(level.get("id", ""))
		if _has_line("%s_intro" % lid):
			found += 1
		else:
			missing.append(lid)
	print("  levels with a line: %d of %d" % [found, GameData.levels.size()])
	if not missing.is_empty():
		print("  still silent: %s" % ", ".join(missing))
	# Every level now, not "the thirty-one that were in the script". A level
	# that goes quiet from here is a regression, not a to-do -- with ONE
	# distinction, added when 星光菜园 arrived:
	#
	#   a level nobody has even written words for   -> failure
	#   a level whose words are in VOICE_SCRIPT.md  -> waiting to be recorded
	#
	# Those are different problems. The first is a level that was forgotten.
	# The second is a job for whoever holds the microphone, and failing the
	# suite over it would mean new content could never be finished until an
	# adult had time to record -- so instead it is printed, loudly, every run.
	var written: Array = []
	var forgotten: Array = []
	for lid in missing:
		if _in_the_script("%s_intro" % lid):
			written.append(lid)
		else:
			forgotten.append(lid)
	if not written.is_empty():
		print("  WAITING TO BE RECORDED (words are written, see "
			+ "docs/VOICE_SCRIPT.md): %s" % ", ".join(written))
	_ok(forgotten.is_empty(),
		"%d level(s) have no line and no words written for one: %s"
			% [forgotten.size(), ", ".join(forgotten)])

	# 2. The shared lines -- the ones a child hears most.
	var gaps: Array = []
	var shared: Array = ["praise_1", "praise_2", "praise_3", "retry", "almost",
		"finish", "hint_1", "hint_2", "hint_3",
		"rest_1", "rest_2", "rest_3", "rest_4"]
	# The mini lessons. Their string key IS their filename -- "lesson.park.1"
	# looks for lesson_park_1 -- so this list is derived from the lessons
	# themselves rather than typed out, and a sixth lesson would be checked
	# the day it is added.
	var lessons: Node = load("res://scenes/ui/MiniLesson.tscn").instantiate()
	for world_id in lessons.get("LESSONS"):
		for beat in lessons.get("LESSONS")[world_id]["beats"]:
			shared.append(str(beat["say"]).replace(".", "_"))
	lessons.free()
	shared.append("lesson_remember")
	for name in shared:
		if not _has_line(name):
			gaps.append(name)
	_ok(gaps.is_empty(), "shared lines missing: %s" % ", ".join(gaps))
	print("  shared lines: %s" % ("all present" if gaps.is_empty() else ", ".join(gaps)))

	# 3. Asking for one really loads it. `say()` returning true is the claim;
	# a stream sitting in the player is the proof.
	var spoke: bool = AudioManager.say("praise_1")
	_ok(spoke, "AudioManager.say() found nothing to play")
	await get_tree().process_frame
	var player: AudioStreamPlayer = AudioManager.get_node_or_null("Voice")
	if player == null:
		for child in AudioManager.get_children():
			if child is AudioStreamPlayer and str(child.name).to_lower().contains("voice"):
				player = child
	if player != null:
		_ok(player.stream != null, "the voice player was handed nothing")
		print("  a spoken line loaded: %s" % (player.stream != null))
	else:
		print("  (no named voice player found -- skipped the stream check)")

	# 4. And the level path, which is what actually runs in the game.
	_ok(AudioManager.play_level_voice("sunny_park_01"),
		"sunny_park_01 has a file but play_level_voice() refused it")
	await get_tree().process_frame
	if player != null:
		_ok(player.stream != null,
			"play_level_voice() said yes and the player got nothing")

	# 5. Every single line, loaded for real. The expensive version of check 1,
	# and the one that would have caught the silence: 44 files present, 44
	# files unloadable, and every cheaper check green.
	var dead: Array = []
	for level in GameData.levels:
		var lid := str(level.get("id", ""))
		if _has_line("%s_intro" % lid):
			continue
		# Only a complaint if the file is actually there. A level with no
		# recording at all is a known, fine state -- check 1 already counts it.
		for suffix in [".ogg", ".wav"]:
			if FileAccess.file_exists("res://assets/audio/voice/level/%s_intro%s"
					% [lid, suffix]):
				dead.append(lid)
				break
	_ok(dead.is_empty(), "files present but unplayable: %s" % ", ".join(dead))
	print("  every present line loads: %s"
		% ("yes" if dead.is_empty() else "NO -- " + ", ".join(dead)))

	for f in _out:
		print("FAIL  %s" % f)
	print("VOICE CHECK %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## Really load it. Not "does the engine know about it" -- really load it.
##
## This used to ask ResourceLoader.exists(), and that is exactly how the game
## went silent on the family Mac without a single check noticing. An audio file
## carries a `.import` alongside it naming an artifact under `.godot/imported/`,
## and that folder is machine-local: it is not in git and never travels. So on
## a machine the files were copied to, every line reported
##
##     ResourceLoader.exists(path) -> true      ("I know that resource")
##     load(path)                  -> null      ("...I cannot produce it")
##
## and this check believed the first line. A check that can pass while a child
## hears nothing is worse than no check, because it is the reason nobody looks.
func _has_line(name: String) -> bool:
	return _stream_for(name) != null


## Has anybody written the words yet? docs/VOICE_SCRIPT.md is the one place a
## line exists before it is a file, and tools_check.py reads it the same way.
func _in_the_script(name: String) -> bool:
	if not FileAccess.file_exists("res://docs/VOICE_SCRIPT.md"):
		return false
	return FileAccess.get_file_as_string("res://docs/VOICE_SCRIPT.md").contains(name)


func _stream_for(name: String) -> AudioStream:
	for suffix in [".ogg", ".wav", ".mp3"]:
		var path := "res://assets/audio/voice/level/%s%s" % [name, suffix]
		if ResourceLoader.exists(path):
			var res := load(path) as AudioStream
			if res != null:
				return res
			# Known but unproducible: the state that caused the silence. Say so
			# loudly -- it is a real condition on a real machine, not a
			# hypothetical, and the runtime now works around it.
			print("  ! %s exists but will not load (import missing)" % path)
		if FileAccess.file_exists(path):
			if suffix == ".ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			if suffix == ".wav":
				return AudioStreamWAV.load_from_file(path)
	return null

## Scan the scripts for AudioManager.say("...") and check each one has words.
##
## The words, not the recording. A line with words and no audio is a line
## waiting to be recorded, which is a normal state for this project and prints
## as a note. A line with NEITHER is a line nobody will ever record, because
## nobody knows it is missing -- and it comes out as silence at the one moment
## it was written for.
func _every_spoken_line_has_words() -> void:
	var asked: Array[String] = []
	_collect_says("res://scripts", asked)

	var wordless: Array[String] = []
	var unrecorded: Array[String] = []
	for name in asked:
		if not _in_the_script(name):
			wordless.append(name)
		elif not _has_line(name):
			unrecorded.append(name)

	print("  lines spoken from code: %d" % asked.size())
	if not unrecorded.is_empty():
		print("  WAITING TO BE RECORDED (words are written): %s"
			% ", ".join(unrecorded))
	_ok(wordless.is_empty(),
		"%d line(s) are spoken by the code with no words written anywhere: %s"
		% [wordless.size(), ", ".join(wordless)])


func _collect_says(dir_path: String, into: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect_says(path, into)
		elif entry.ends_with(".gd"):
			var src := FileAccess.get_file_as_string(path)
			# say("...") with a literal. A key built at runtime -- praise_%d and
			# the like -- cannot be read from here and is covered by the fixed
			# shared-line list further down.
			var re := RegEx.create_from_string('say\\("([a-z0-9_]+)"\\)')
			for m in re.search_all(src):
				var name := m.get_string(1)
				if not name in into:
					into.append(name)
		entry = dir.get_next()
	dir.list_dir_end()
