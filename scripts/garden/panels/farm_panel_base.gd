extends RefCounted
## Base class for garden sheets and panels.
##
## Provides the shared sheet canvas, title, blocking against farm touch input,
## uniform X close button, and side-paging controls across all farm panels.

const Palette := preload("res://scripts/ui/palette.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const TOP_BAR := 68.0

var screen: Node
var play: Control
var world: Node


func _init(p_screen: Node) -> void:
	screen = p_screen
	play = screen.get("_play") as Control
	world = screen.get("_world") as Node


func block_world(node: Control) -> void:
	if world != null and is_instance_valid(world):
		world.call("add_blocker", node)


func sheet_close(at: Vector2, on_pressed: Callable) -> Button:
	var shut := Button.new()
	shut.flat = false
	shut.focus_mode = Control.FOCUS_NONE
	shut.text = "X"
	shut.add_theme_font_size_override("font_size", 26)
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		shut.add_theme_color_override(slot, Palette.ON_COLOR)
	shut.position = at
	shut.custom_minimum_size = Vector2(60, 60)
	shut.size = Vector2(60, 60)
	for look in ["normal", "hover", "pressed", "focus"]:
		shut.add_theme_stylebox_override(look, UiKit.chip_style(Palette.SLATE, 16))
	shut.pressed.connect(on_pressed)
	play.add_child(shut)
	block_world(shut)
	return shut


func panel_sheet(view: Vector2, title_key: String, wide: float, tall: float, on_close: Callable) -> Vector2:
	var origin := Vector2(view.x * 0.5 - wide * 0.5, TOP_BAR + 16.0)
	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.99, 0.97, 0.90), 28))
	if title_key in ["garden.warehouse_title", "garden.waiting_harvest_title"]:
		sheet.name = "BarnCollectionPanel"
		if screen.has_method("_inventory_surface"):
			sheet.add_theme_stylebox_override("panel", screen.call("_inventory_surface"))
	sheet.position = origin
	sheet.custom_minimum_size = Vector2(wide, tall)
	sheet.size = Vector2(wide, tall)
	play.add_child(sheet)
	block_world(sheet)

	var title: Control
	if title_key in ["garden.warehouse_title", "garden.waiting_harvest_title"]:
		title = UiKit.title(I18n.t(title_key), 22, Color(0.29, 0.24, 0.16))
		title.name = "BarnCollectionTitle"
		title.position = origin + Vector2(28.0, 8.0)
		title.size = Vector2(wide - 130.0, 28.0)
	else:
		title = UiKit.title(I18n.t(title_key), 24, Color(0.26, 0.22, 0.17))
		title.position = origin + Vector2(28.0, 12.0)
		title.size = Vector2(wide - 130.0, 32.0)
	play.add_child(title)

	sheet_close(origin + Vector2(wide + 14.0, 0.0), on_close)
	return origin


func pager(origin: Vector2, wide: float, tall: float, page: int, pages: int, flip: Callable) -> void:
	if pages <= 1:
		return
	if page > 0:
		var back := chip_button("<", Color(0.99, 0.96, 0.88), Vector2(60, 76))
		back.position = Vector2(origin.x - 74.0, origin.y + tall * 0.5 - 38.0)
		back.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			flip.call(-1))
		play.add_child(back)
		block_world(back)
		var panel_buttons: Dictionary = screen.get("_panel_buttons")
		if panel_buttons != null:
			panel_buttons["page_back"] = back
	if page < pages - 1:
		var next := chip_button(">", Color(0.99, 0.96, 0.88), Vector2(60, 76))
		next.position = Vector2(origin.x + wide + 14.0, origin.y + tall * 0.5 - 38.0)
		next.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			flip.call(+1))
		play.add_child(next)
		block_world(next)
		var panel_buttons: Dictionary = screen.get("_panel_buttons")
		if panel_buttons != null:
			panel_buttons["page_next"] = next


func chip_button(symbol: String, tint: Color, box: Vector2) -> Button:
	var btn := Button.new()
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = symbol
	btn.add_theme_font_size_override("font_size", int(box.y * 0.44))
	btn.add_theme_color_override("font_color", Color(0.15, 0.13, 0.10))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.48))
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(look, UiKit.chip_style(tint, 16))
	btn.custom_minimum_size = box
	btn.size = box
	return btn
