extends Node
## Single place that changes scenes, with a fade so nothing ever flashes or
## jump-cuts. Young children startle easily; transitions are deliberately slow
## and quiet.

const FADE_TIME := 0.35

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	print("[autoload] SceneManager starting")
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	print("[autoload] SceneManager ok")


func goto_scene(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: no scene at %s" % path)
		return
	_busy = true

	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await t.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await t2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func switch_to(path: String) -> void:
	goto_scene(path)


func goto_home() -> void:
	goto_scene("res://scenes/home/HomeDiorama.tscn")


func goto_world_map() -> void:
	goto_scene("res://scenes/map/WorldMap.tscn")
