extends Node
## Does picking an upgrade actually change the gun? Written because the
## playtester's father said the drafted skills "aren't reflected".
var _out: Array[String] = []

func _count_bolts(lvl: Node) -> int:
	var n := 0
	for child in lvl._play_area.get_children():
		if child is Line2D:
			n += 1
	return n

func _fire(lvl: Node, at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = at
	lvl._on_field_input(ev)

func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	await get_tree().process_frame
	GameManager.current_level_id = "star_trials_05"
	var lvl: Node = load("res://scenes/minigames/light_defense/LightDefense.tscn").instantiate()
	add_child(lvl)
	for i in range(6):
		await get_tree().process_frame

	print("  base cooldown  = %.3f" % lvl._cooldown())
	print("  base radius    = %.1f" % lvl._blast_radius())
	print("  base damage    = %d" % lvl._damage())
	lvl._clock = 99.0
	lvl._fire_ready = 0.0
	_fire(lvl, Vector2(800, 500))
	print("  base bolts     = %d" % _count_bolts(lvl))

	for child in lvl._play_area.get_children():
		if child is Line2D:
			child.queue_free()
	await get_tree().process_frame

	lvl._take("spread")
	lvl._take("rapid")
	lvl._take("power")
	lvl._take("wide")
	lvl._clock = 199.0
	lvl._fire_ready = 0.0
	_fire(lvl, Vector2(800, 500))
	var bolts: int = _count_bolts(lvl)
	print("  after draft: cooldown=%.3f radius=%.1f damage=%d bolts=%d" % [
		lvl._cooldown(), lvl._blast_radius(), lvl._damage(), bolts])

	if lvl._cooldown() >= 0.5:
		_out.append("rapid must shorten the cooldown")
	if lvl._blast_radius() <= 96.0:
		_out.append("wide must grow the blast")
	if lvl._damage() < 2:
		_out.append("power must raise the damage")
	if bolts < 2:
		_out.append("spread must add a bolt, got %d" % bolts)
	# And the gun has to LOOK different, which is the half that was missing.
	if lvl._bolt_color().is_equal_approx(Color(1.0, 0.86, 0.40)):
		_out.append("a powered bolt must not be the plain colour")
	lvl._take("slow")
	if not lvl._bolt_color().is_equal_approx(Color(0.60, 0.88, 1.0)):
		_out.append("frost must turn the bolt icy")

	for f in _out:
		print("FAIL  %s" % f)
	print("UPGRADE PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)
