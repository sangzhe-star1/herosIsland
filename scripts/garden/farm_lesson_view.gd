extends "res://scripts/garden/panels/farm_panel_base.gd"
## Draw the garden's temporary teaching cues without owning lesson progress.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Tutorial := preload("res://scripts/shared/tutorial_director.gd")
const Rest := preload("res://scripts/shared/rest_director.gd")


func point_to(look_at: Vector2, act_at: Vector2, hold: float) -> void:
	if play == null or not is_instance_valid(play):
		return
	var hand := Tutorial.new()
	play.add_child(hand)
	hand.add_step(look_at, act_at, hold)
	hand.play()


func show_move(state: String, bed: Vector2, seed: Vector2) -> void:
	var start := bed
	var finish := bed
	if state == Farm.READY:
		# Ripe: show the PULL, not a tap -- press on the bed, glide up.
		finish += Vector2(0.0, -90.0)
	elif state == Farm.TILLED:
		start = seed
	point_to(start, finish, 1.3)


func highlight(at: Vector2, tint: Color = Color(1.0, 0.94, 0.62, 0.5),
		radius: float = 140.0) -> void:
	if play != null and is_instance_valid(play):
		Juice.shockwave(play, at, radius, tint)


func offer_break(view: Vector2, on_leave: Callable) -> void:
	if play == null or not is_instance_valid(play):
		return
	var card := UiKit.card(Color(1.0, 0.99, 0.93))
	card.custom_minimum_size = Vector2(560, 190)
	card.position = Vector2(view.x * 0.5 - 280.0, view.y * 0.5 - 95.0)
	play.add_child(card)
	block_world(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var line := UiKit.title(I18n.t(Rest.line()), 30)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	# Staying comes first: the break is offered, never pushed.
	var stay := UiKit.big_button(I18n.t("garden.keep_planting"), Palette.GREEN)
	stay.pressed.connect(func(): card.queue_free())
	row.add_child(stay)
	var leave := UiKit.big_button(I18n.t("garden.go_exploring"), Palette.BLUE)
	leave.pressed.connect(on_leave)
	row.add_child(leave)
