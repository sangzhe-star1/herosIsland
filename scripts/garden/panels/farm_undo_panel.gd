extends "res://scripts/garden/panels/farm_panel_base.gd"
## The short regret window offered after a reversible farm purchase.

const Undo := preload("res://scripts/garden/farm_undo_controller.gd")
const SHELF := 140.0


func build(view: Vector2) -> void:
	var pending: Dictionary = screen.get("_pending_undo")
	if pending.is_empty():
		return
	if not Undo.is_open(pending, GameClock.ticks_ms()):
		screen.set("_pending_undo", {})
		return
	var card := Panel.new()
	card.name = "FarmUndoCard"
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.98, 0.90), 22))
	card.position = Vector2(view.x * 0.5 - 150.0, view.y - SHELF - 84.0)
	card.custom_minimum_size = Vector2(300.0, 64.0)
	card.size = Vector2(300.0, 64.0)
	play.add_child(card)
	block_world(card)

	var undo := chip_button(I18n.t("garden.undo"),
		Color(0.78, 0.86, 0.97), Vector2(160.0, 48.0))
	undo.name = "FarmUndoButton"
	undo.position = card.position + Vector2(70.0, 8.0)
	undo.pressed.connect(func(): screen.call("_undo_pressed"))
	play.add_child(undo)
	var panel_buttons: Dictionary = screen.get("_panel_buttons")
	panel_buttons["undo"] = undo
