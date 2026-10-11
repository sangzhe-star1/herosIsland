extends Node
## Contract check for the value-free field paths shown by save audits.

const Audit := preload("res://tests/save_migration_audit.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var audit: Node = Audit.new()
	var before := {
		"keep": {"count": 3},
		"removed": "old",
		"npc": {"rabbit": {"owed": true}},
		"plots": [{"state": "ready"}, {"state": "tilled"}],
	}
	var after := {
		"keep": {"count": 3.0, "new": true},
		"npc": {"rabbit": {"owed": false}, "robot": {}},
		"plots": [
			{"state": "ready"},
			{"state": "ready"},
			{"state": "empty"},
		],
	}
	var changes: Array = audit.call("_json_change_paths", before, after, "farm")
	var expected := [
		"farm.keep.new (added)",
		"farm.npc.rabbit.owed",
		"farm.npc.robot (added)",
		"farm.plots[1].state",
		"farm.plots[2] (added)",
		"farm.removed (removed)",
	]
	_ok(changes == expected,
		"nested additions, removals, changes, and array entries get stable paths")
	_ok(not "farm.keep.count" in changes,
		"integer and equivalent float values do not produce a false change")
	var values_not_exposed := true
	for path in changes:
		if path.contains("old") or path.contains("true") \
				or path.contains("false"):
			values_not_exposed = false
	_ok(values_not_exposed, "the field-path report never includes saved values")
	if _failures.is_empty():
		print("SAVE MIGRATION AUDIT PATH PROBE PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("SAVE MIGRATION AUDIT PATH PROBE FAILED")
		get_tree().quit(1)


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
