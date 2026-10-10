extends "res://scripts/garden/panels/farm_panel_base.gd"
## The saved decorating-room arrangement as a passive, touch-safe part of the farm.

const Layout := preload("res://scripts/garden/farm_layout.gd")


func build_door(view: Vector2, shelf_height: float) -> void:
	var level_data: Dictionary = screen.get("level_data")
	var room_id := str(level_data.get("config", {}).get("deco_room", ""))
	if room_id == "" or GameData.get_level(room_id).is_empty():
		return
	var box := Vector2(60.0, 60.0)
	# Keep the lower possession lane clear for the overflow basket and flights.
	var at := Vector2(view.x - 16.0 - box.x, view.y - shelf_height + 6.0)
	var button := Button.new()
	button.name = "DecoDoor"
	button.focus_mode = Control.FOCUS_NONE
	button.position = at
	button.custom_minimum_size = box
	button.size = box
	button.add_theme_stylebox_override("normal", _door_style(
		Color(0.97, 0.93, 0.83), Color(0.73, 0.60, 0.38, 0.26)))
	button.add_theme_stylebox_override("hover", _door_style(
		Color(0.99, 0.96, 0.88), Color(0.73, 0.60, 0.38, 0.48)))
	button.add_theme_stylebox_override("pressed", _door_style(
		Color(0.93, 0.88, 0.76), Color(0.67, 0.51, 0.31, 0.48)))
	var art: Control = UiKit.picture("sticker_book", 38.0)
	if art != null:
		art.position = Vector2((box.x - 38.0) * 0.5, (box.y - 38.0) * 0.5)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(art)
	button.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		GameManager.start_level(room_id))
	play.add_child(button)


func draw_saved(placed: Array, canvas: Vector2) -> void:
	if world == null or not is_instance_valid(world):
		return
	var layer := Node2D.new()
	layer.name = "Decorations"
	world.add_child(layer)
	# FarmWorld layers by child order, not z_index: ground is child zero and
	# saved furniture belongs on the grass behind beds and buildings.
	world.call("move_child", layer, 1)
	var farm_size: Vector2 = Layout.world_size()
	for entry in placed:
		var size := clampf(float(entry.get("size", 84.0)), 40.0, 160.0)
		var art: Control = UiKit.picture(str(entry.get("icon", "star")), size)
		if art == null:
			continue
		var fx := clampf(float(entry.get("x", 640.0)) / maxf(canvas.x, 1.0),
			0.0, 1.0)
		var fy := clampf(float(entry.get("y", 300.0)) / maxf(canvas.y, 1.0),
			0.0, 1.0)
		art.position = Vector2(fx * (farm_size.x - size),
			fy * (farm_size.y - size))
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.pivot_offset = art.size * 0.5
		layer.add_child(art)
		Juice.idle_bob(art, 2.0, 2.6 + 0.37 * float(layer.get_child_count()))


func poke(at: Vector2) -> void:
	if world == null or not is_instance_valid(world):
		return
	var layer := world.get_node_or_null("Decorations")
	if layer == null:
		return
	var camera: Variant = world.get("camera")
	if camera == null:
		return
	var spot: Vector2 = camera.call("screen_to_world", at)
	for child in layer.get_children():
		if not (child is Control):
			continue
		var art := child as Control
		if not Rect2(art.position, art.size).has_point(spot):
			continue
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		Juice.pop(art, 0.16)
		# Record the answer before animation for slow frames and reduced motion.
		art.set_meta("poked_at", GameClock.ticks_ms())
		if not Juice.motion_enabled():
			Juice.pop(art, 0.1)
		if Juice.motion_enabled():
			var tween := art.create_tween()
			tween.tween_property(art, "rotation", 0.13, 0.11)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(art, "rotation", -0.09, 0.15)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(art, "rotation", 0.0, 0.13)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return


func _door_style(fill: Color, edge: Color) -> StyleBoxFlat:
	return screen.call("_quiet_surface_style", fill, 16, edge, 1)
