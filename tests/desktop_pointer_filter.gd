extends Node
## Drops the real desktop mouse while a rendered probe drives synthetic input.
##
## A probe window on macOS still receives the user's own mouse motion
## (device DEVICE_ID_MOUSE) even with mouse_passthrough set. If that motion
## lands while a synthetic tap is held, the pressed Button sees the pointer
## leave and the tap is lost. GardenTouchProbe failed 3/3 with the cursor
## moving and passed 49/49 with the desk idle (21-22 October): that is the
## "one lost touch in three" farm-probe flake, which only ever happened while
## somebody was using the Mac.
##
## Synthetic touches arrive as device 0 and pass. Synthetic MOUSE events can
## carry the same device id as the desktop mouse, so a probe tags every mouse
## event it parses with synthetic(); untagged physical-mouse events are eaten.
## Tagging rather than an on/off gate, because a gate held open for a
## deliberate mouse check lets the desktop cursor through in the same frames.
##
## _input reaches the LAST child of the root first, so this node keeps itself
## the root's last child.

const TAG := "qa_synthetic"


static func synthetic(event: InputEvent) -> InputEvent:
	event.set_meta(TAG, true)
	return event


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.child_entered_tree.connect(_stay_last)


func _stay_last(_node: Node) -> void:
	var root := get_tree().root
	if get_parent() == root:
		root.move_child.call_deferred(self, -1)


func _input(event: InputEvent) -> void:
	if event.device != InputEvent.DEVICE_ID_MOUSE:
		return
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	if event.has_meta(TAG):
		return
	get_viewport().set_input_as_handled()
