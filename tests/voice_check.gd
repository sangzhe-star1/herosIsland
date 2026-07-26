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
	# The thirty-one that were in the script must all be there. The bonus
	# levels arrived after it was written and are allowed to be quiet.
	_ok(found >= 31, "only %d levels have a recorded line" % found)

	# 2. The shared lines -- the ones a child hears most.
	var gaps: Array = []
	for name in ["praise_1", "praise_2", "praise_3", "retry", "almost",
			"finish", "hint_1", "hint_2", "hint_3",
			"rest_1", "rest_2", "rest_3", "rest_4"]:
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

	for f in _out:
		print("FAIL  %s" % f)
	print("VOICE CHECK %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


func _has_line(name: String) -> bool:
	for suffix in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists("res://assets/audio/voice/level/%s%s" % [name, suffix]):
			return true
	return false
