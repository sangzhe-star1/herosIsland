extends Node
## Every drawn icon on one screen. The set has to be judged together -- an icon
## that reads well alone can still be the odd one out in a row.
func _ready() -> void:
	var out := OS.get_environment("SHOT_PATH")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.98, 0.97, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var cols := 12
	var cell := 100.0
	for i in range(IconLibrary.NAMES.size()):
		var icon: Control = IconLibrary.build(str(IconLibrary.NAMES[i]), 76.0)
		if icon == null:
			continue
		icon.position = Vector2(20.0 + float(i % cols) * cell, 20.0 + float(i / cols) * cell)
		root.add_child(icon)
		var l := Label.new()
		l.text = str(IconLibrary.NAMES[i])
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
		l.position = icon.position + Vector2(0, 78)
		l.size = Vector2(cell - 8, 20)
		root.add_child(l)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	print("icon_preview -> ", error_string(get_viewport().get_texture().get_image().save_png(out)))
	get_tree().quit(0)
