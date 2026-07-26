extends Node
## The parent's "unlock everything" switch, checked from both sides.
##
##   godot --headless --path . res://tests/UnlockProbe.tscn
##
## The whole promise of this switch is that it is a VIEW and not a WRITE: his
## son's stars, finished levels and album have to come out the other side
## untouched, or the switch is a progress-eraser with a friendly name. So the
## probe takes a fingerprint of the save, flips the switch both ways, and
## checks the fingerprint never moved.

func _ready() -> void:
	await get_tree().process_frame
	print("=== unlock probe ===")
	var out: Array[String] = []

	# A save that looks like a child three levels in.
	SaveManager.set_setting(SaveManager.TEST_UNLOCK, false)
	for lid in ["sunny_park_01", "sunny_park_02"]:
		var p: Dictionary = SaveManager.get_level_progress(lid)
		p["completed"] = true
		p["stars"] = 3
		SaveManager.data["levels"][lid] = p
	var before := _fingerprint()

	# 1. Off: the locks are real. Something late in the island must be shut,
	# or the switch is measuring nothing.
	var shut := 0
	for level in GameData.levels:
		if not SaveManager.is_level_unlocked(str(level.get("id", ""))):
			shut += 1
	print("  switch off: %d of %d levels locked" % [shut, GameData.levels.size()])
	if shut == 0:
		out.append("with the switch off nothing is locked -- "
			+ "the probe cannot tell whether the switch does anything")

	# 2. On: every level opens.
	SaveManager.set_setting(SaveManager.TEST_UNLOCK, true)
	var still_shut: Array = []
	for level in GameData.levels:
		var lid := str(level.get("id", ""))
		if not SaveManager.is_level_unlocked(lid):
			still_shut.append(lid)
	print("  switch on : %d still locked" % still_shut.size())
	if not still_shut.is_empty():
		out.append("switch on but still locked: %s" % ", ".join(still_shut))

	# 3. And it wrote nothing. This is the point of the whole design.
	var during := _fingerprint()
	if during != before:
		out.append("turning it ON changed his progress: %s -> %s"
			% [before, during])

	# 4. Off again: exactly the locks he had, to the star.
	SaveManager.set_setting(SaveManager.TEST_UNLOCK, false)
	var after_shut := 0
	for level in GameData.levels:
		if not SaveManager.is_level_unlocked(str(level.get("id", ""))):
			after_shut += 1
	print("  switch off: %d locked again" % after_shut)
	if after_shut != shut:
		out.append("after switching off, %d locked instead of the original %d"
			% [after_shut, shut])
	var after := _fingerprint()
	if after != before:
		out.append("his progress did not survive the round trip: %s -> %s"
			% [before, after])
	print("  progress fingerprint: %s -> %s" % [before, after])

	for f in out:
		print("  FAIL: ", f)
	print("UNLOCK PROBE %s" % ("PASSED" if out.is_empty() else "FAILED"))
	get_tree().quit(0 if out.is_empty() else 1)


## Everything the switch is forbidden to touch, in one string.
func _fingerprint() -> String:
	var done := 0
	var stars := 0
	for lid in SaveManager.data["levels"].keys():
		var p: Dictionary = SaveManager.data["levels"][lid]
		if bool(p.get("completed", false)):
			done += 1
		stars += int(p.get("stars", 0))
	return "completed=%d stars=%d total=%d coins=%d" % [done, stars,
		SaveManager.total_stars(), int(SaveManager.data["rewards"]["coins"])]
