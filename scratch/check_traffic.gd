extends SceneTree

func _init() -> void:
	var scn := load("res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn") as PackedScene
	var inst := scn.instantiate()
	root.add_child(inst)
	_print_node(inst, 0)
	quit(0)

func _print_node(n: Node, depth: int) -> void:
	var indent := ""
	for i in range(depth): indent += "  "
	print(indent + n.name + " (" + n.get_class() + ")")
	for c in n.get_children():
		_print_node(c, depth + 1)
