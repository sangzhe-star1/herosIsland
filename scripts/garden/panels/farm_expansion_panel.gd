extends "res://scripts/garden/panels/farm_panel_base.gd"
## The one-bed purchase card shown between a child's press and clearing land.

const Expand := preload("res://scripts/garden/farm_expansion_manager.gd")


func build(view: Vector2) -> void:
	var index := int(screen.get("_confirm_expand"))
	if index < 0 or Expand.state_of(index) != "ready":
		return
	var card := Panel.new()
	card.name = "PlotExpansionCard"
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.99, 0.94), 24))
	card.position = Vector2(view.x * 0.5 - 210.0, TOP_BAR + 60.0)
	card.custom_minimum_size = Vector2(420.0, 170.0)
	card.size = Vector2(420.0, 170.0)
	play.add_child(card)
	block_world(card)

	var art := UiKit.picture("shovel", 52.0)
	if art != null:
		art.position = card.position + Vector2(28.0, 24.0)
		play.add_child(art)
	var coin := UiKit.picture("star_coin", 40.0)
	if coin != null:
		coin.position = card.position + Vector2(110.0, 30.0)
		play.add_child(coin)
	var cost := UiKit.title(str(Expand.cost_of(index)), 34)
	cost.position = card.position + Vector2(162.0, 34.0)
	cost.size = Vector2(90.0, 44.0)
	play.add_child(cost)

	var panel_buttons: Dictionary = screen.get("_panel_buttons")
	var yes := chip_button(I18n.t("garden.expand"),
		Color(0.72, 0.88, 0.60), Vector2(170.0, 58.0))
	yes.name = "ConfirmPlotExpansion"
	yes.position = card.position + Vector2(30.0, 94.0)
	yes.pressed.connect(func(): screen.call("_expand_confirmed", index))
	play.add_child(yes)
	panel_buttons["confirm_expand"] = yes
	var no := chip_button(I18n.t("garden.cancel"),
		Color(0.78, 0.86, 0.97), Vector2(170.0, 58.0))
	no.name = "CancelPlotExpansion"
	no.position = card.position + Vector2(220.0, 94.0)
	no.pressed.connect(func():
		screen.set("_confirm_expand", -1)
		screen.call("_queue_rebuild"))
	play.add_child(no)
	panel_buttons["cancel_expand"] = no
