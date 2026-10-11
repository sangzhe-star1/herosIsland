extends "res://scripts/garden/panels/farm_panel_base.gd"
## The farm's corner zoom capsule. It owns its layout and input blockers while
## GardenScreen retains the world-camera rebuild callback.
##
## Plus sits above minus with a hairline between. Pinching works too, but
## two-finger gestures are easy to perform accidentally on a tablet; these
## large controls stay visible and grey at the ends of the zoom range. Their
## bottom-right position sits above the shelf under the tablet-holding thumb,
## away from the purse and expansion stones.

const BOX := 64.0
const INSET := 20.0
const SEPARATOR_GAP := 1.0


func build(view: Vector2, shelf_height: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var origin := Vector2(view.x - BOX - INSET,
		view.y - shelf_height - BOX * 2.0 - SEPARATOR_GAP - INSET)
	var shell := Panel.new()
	shell.name = "FarmZoomCapsule"
	shell.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 22))
	shell.position = origin
	shell.custom_minimum_size = Vector2(BOX, BOX * 2.0 + SEPARATOR_GAP)
	shell.size = shell.custom_minimum_size
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(shell)
	# World input runs before GUI input, so the visible capsule must also be a
	# world blocker or a zoom press may tap the bed underneath it.
	block_world(shell)

	var hairline := ColorRect.new()
	hairline.color = Color(0.30, 0.27, 0.22, 0.14)
	hairline.position = origin + Vector2(12.0, BOX)
	hairline.size = Vector2(BOX - 24.0, SEPARATOR_GAP)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_child(hairline)

	for step: int in [1, -1]:
		var button := Button.new()
		button.name = "FarmZoomIn" if step > 0 else "FarmZoomOut"
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.text = "+" if step > 0 else "−"
		button.add_theme_font_size_override("font_size", 38)
		var live := bool(world.call("can_zoom", step))
		button.add_theme_color_override("font_color",
			Color(0.24, 0.21, 0.16) if live else Color(0.72, 0.70, 0.65))
		button.add_theme_color_override("font_disabled_color",
			Color(0.72, 0.70, 0.65))
		button.position = origin if step > 0 \
			else origin + Vector2(0.0, BOX + SEPARATOR_GAP)
		button.custom_minimum_size = Vector2(BOX, BOX)
		button.size = button.custom_minimum_size
		button.disabled = not live
		var direction := step
		button.pressed.connect(func():
			world.call("zoom_by", direction)
			screen.call("_queue_rebuild"))
		play.add_child(button)
		block_world(button)
