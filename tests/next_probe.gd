extends Node
## Checks the "what comes next" chain without a person pressing anything.
##
## The chain is the only thing carrying a six-year-old from one level to the
## next: the result screen's big green button is next_level_id(). A link that
## points at itself is an infinite loop he cannot escape, and a link to a level
## that no longer exists is a button that does nothing.
##
## This probe was written months ago and then never wired into run_smoke.sh, so
## none of that was being checked. Wiring it in needed two fixes first:
##
##   * it prints no PASSED marker, which is what the suite greps for
##   * it fills the save with 34 completed levels and never puts it back, which
##     would hand every probe after it a finished game

func _ready() -> void:
	# Snapshot the whole save. This probe lies to the game about what has been
	# finished, and the save file outlives this process.
	var before: Dictionary = SaveManager.data.duplicate(true)

	var checks := 0
	var bad := 0
	for level in GameData.levels:
		var id := str(level.get("id", ""))
		# Pretend everything up to and including this level is done.
		for other in GameData.levels:
			var oid := str(other.get("id", ""))
			SaveManager.data["levels"][oid] = {"stars": 3, "completed": true}
			if oid == id:
				break
		GameManager.current_level_id = id
		var next := GameManager.next_level_id()
		checks += 1
		if next == id:
			print("  BAD  %s -> itself" % id)
			bad += 1
		elif next != "" and GameData.get_level(next).is_empty():
			print("  BAD  %s -> unknown %s" % [id, next])
			bad += 1
	print("next_level_id: %d levels checked, %d bad" % [checks, bad])

	# The end of the island has to end. Everything is marked done by now, so the
	# last entry in the list has nothing playable after it.
	var last_id := str(GameData.levels[GameData.levels.size() - 1].get("id", ""))
	GameManager.current_level_id = last_id
	var after_last := GameManager.next_level_id()
	if after_last != "":
		print("  BAD  the last level %s still offers %s" % [last_id, after_last])
		bad += 1
	else:
		print("after the last level (%s) -> nothing, as it should" % last_id)

	# An unknown level id must not invent a destination.
	GameManager.current_level_id = "a_level_that_was_deleted"
	var after_ghost := GameManager.next_level_id()
	if after_ghost != "":
		print("  BAD  an unknown level offered %s" % after_ghost)
		bad += 1
	else:
		print("after a level that does not exist -> nothing, as it should")

	# Put the save back the way it was found. Without this the shop, album and
	# save probes downstream would open on a game that had already been won.
	SaveManager.data = before
	SaveManager.save_game()
	GameManager.current_level_id = ""

	if bad == 0:
		print("NEXT PROBE PASSED")
	get_tree().quit(1 if bad > 0 else 0)
