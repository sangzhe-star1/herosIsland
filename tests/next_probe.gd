extends Node
## Checks the "what comes next" chain without a person pressing anything.
func _ready() -> void:
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
	GameManager.current_level_id = "safety_traffic_01"
	print("after safety_traffic_01 -> ", GameManager.next_level_id())
	GameManager.current_level_id = "monster_arena_07"
	print("after monster_arena_07 -> '", GameManager.next_level_id(), "'")
	get_tree().quit(1 if bad > 0 else 0)
