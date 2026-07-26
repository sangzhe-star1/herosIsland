extends Node
## Films a mini lesson to a folder of PNGs, one per frame.
##
##   FILM_WORLD=sunny_park FILM_DIR=/tmp/film FILM_SECONDS=17 \
##     xvfb-run -a godot --path . --rendering-driver opengl3 \
##     res://tests/LessonFilm.tscn
##
## Why film it rather than screen-record: the frames come out at exactly 30
## a second whatever the machine is doing, so the result plays at the right
## speed on a phone that never ran the game. `tools/make_film.sh` turns the
## folder into an MP4 and lays the island's music underneath.
##
## It drives the real scene -- same script, same drawings, same timings a
## child sees -- so the video cannot drift away from the game.

const FPS := 30


func _ready() -> void:
	var out_dir := OS.get_environment("FILM_DIR")
	if out_dir == "":
		out_dir = "/tmp/lesson-film"
	var world := OS.get_environment("FILM_WORLD")
	if world == "":
		world = "sunny_park"
	var seconds := float(OS.get_environment("FILM_SECONDS"))
	if seconds <= 0.0:
		seconds = 17.0
	DirAccess.make_dir_recursive_absolute(out_dir)

	var window := get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)

	GameManager.current_world_id = world
	var lesson: Control = load("res://scenes/ui/MiniLesson.tscn").instantiate()
	lesson.set("_world", world)
	add_child(lesson)
	await get_tree().process_frame

	# The film has to advance the SCENE by 1/30 s per captured frame, and a
	# software renderer manages nowhere near thirty frames a second. Left
	# alone, the scene runs on wall-clock while the capture runs on render
	# rate, and the lesson finishes a third of the way into the video -- which
	# is exactly what the first cut did.
	#
	# So the capture drives time: measure how long each frame really took, and
	# scale the engine's clock so that real interval equals 1/30 s of scene
	# time. It self-corrects, so a frame that took twice as long simply gets
	# half the time scale.
	Engine.max_fps = 0
	var hide_chrome := OS.get_environment("FILM_CLEAN") != ""
	if hide_chrome:
		_hide_buttons(lesson)

	var frames: int = int(seconds * float(FPS))
	var want: float = 1.0 / float(FPS)
	var last: int = Time.get_ticks_usec()
	for i in range(frames):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var real: float = maxf(float(now - last) / 1_000_000.0, 0.0005)
		last = now
		Engine.time_scale = clampf(want / real, 0.02, 4.0)
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/frame_%05d.png" % [out_dir, i])
		if i % 90 == 0:
			print("  filmed %d / %d  (time scale %.2f)" % [i, frames, Engine.time_scale])
	Engine.time_scale = 1.0
	print("filmed %d frames to %s" % [frames, out_dir])
	get_tree().quit(0)


## A film of the lesson should not have the game's buttons in it. They are
## right for a child holding a tablet and wrong for a video being watched.
func _hide_buttons(root: Node) -> void:
	for child in root.get_children():
		if child is Button:
			(child as Button).visible = false
		elif child is Control:
			_hide_buttons(child)
