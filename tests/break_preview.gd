extends Node
## One-off: renders the break card, which otherwise only appears after a
## child has already played past the daily limit.
func _ready() -> void:
	var home: Control = load("res://scenes/home/Home.tscn").instantiate()
	add_child(home)
	await get_tree().create_timer(0.8).timeout
	home.call("_show_break_message")
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	print("break_preview -> ", error_string(
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))))
	get_tree().quit(0)
