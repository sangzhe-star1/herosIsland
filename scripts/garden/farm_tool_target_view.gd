extends RefCounted
## Projects the selected tool's real eligibility onto the farm beds.
##
## Tool availability remains owned by FarmToolController; this small view
## adapter keeps the rings and task priority in sync without copying those
## rules into GardenScreen.

const Tools := preload("res://scripts/garden/farm_tool_controller.gd")
const NextTaskPanel := preload("res://scripts/garden/panels/farm_next_task_panel.gd")


static func sync(world: Node, tools: Tools, plots: Array,
		overlay_open: bool, task: Dictionary = {}) -> void:
	if world == null or not is_instance_valid(world):
		return
	var targets: Array = []
	if tools.selected != Tools.HAND and not overlay_open:
		for i in range(plots.size()):
			if tools.needs(tools.selected, plots[i]):
				targets.append(i)
	var primary := int(task.get("index", -1))
	world.set_tool_targets(targets, _tool_color(tools.selected), primary)


static func _tool_color(tool_id: String) -> Color:
	match tool_id:
		"basket": return NextTaskPanel.color_for_task({"kind": "harvest"})
		"water", "weed", "bug":
			return NextTaskPanel.color_for_task({"kind": "care"})
		"seed": return NextTaskPanel.color_for_task({"kind": "plant"})
		"shovel": return NextTaskPanel.color_for_task({"kind": "till"})
		_: return Color(1.0, 1.0, 1.0)
