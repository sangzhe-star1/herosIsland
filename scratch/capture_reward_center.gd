extends Node

const OUT_DIR := "/Users/xhzhou/.gemini/antigravity/brain/2a762f9a-01f0-43fc-b355-5a304be9bd77"

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var scene: PackedScene = load("res://scenes/reward/RewardCenter.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in range(25):
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/shot_reward_center_v18.png" % OUT_DIR
	img.save_png(path)
	print("Saved reward center screenshot!")
	get_tree().quit(0)
