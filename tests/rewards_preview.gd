extends Node
## Renders the Reward Centre with some progress already made, because on a
## fresh save every badge is locked and the earned state is never seen.
## Nothing is written to disk: only the in-memory save is touched.
func _ready() -> void:
	SaveManager.data["rewards"]["coins"] = 250
	SaveManager.data["rewards"]["badges"] = [
		"road_guardian", "sharp_eyes", "energy_collector", "color_expert",
		"tracker", "night_walker", "monster_friend",
	]
	SaveManager.data["rewards"]["stickers"] = ["star", "heart", "paw"]
	for pair in [["courage", 18], ["wisdom", 11], ["kindness", 24],
			["focus", 7], ["safety", 15]]:
		SaveManager.data["growth"][str(pair[0])] = int(pair[1])
	# A tall window so the whole scrolling page is captured at once; the
	# screen itself is still laid out for 1280x720.
	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 2150)
		window.content_scale_size = Vector2i(1280, 2150)
	add_child(load("res://scenes/reward/RewardCenter.tscn").instantiate())
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	print("rewards_preview -> ", error_string(
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH"))))
	get_tree().quit(0)
