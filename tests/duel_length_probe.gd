extends Node
## How long does a duel actually last?
##
##   xvfb-run -a godot --path . res://tests/DuelLengthProbe.tscn
##
## The brief asks for levels of two to four minutes. Picking the number of hits
## a monster takes by eye gets that wrong in both directions -- a boss that
## folds in fifteen seconds is not a boss, and one that takes four hundred taps
## is a chore. So this fights each duel the way a determined six-year-old does
## -- press the beam the instant it is ready, and never miss -- and reports the
## wall-clock. That is the FLOOR: real play is slower, because he also has to
## shield and swat.

const DUELS := ["sunny_park_06", "night_city_06", "monster_valley_03",
	"monster_valley_06", "sky_base_06", "dark_castle_06"]

## The fastest a duel may end when played perfectly, and the slowest it may
## drag. Below the floor it is not a fight; above the ceiling he has stopped
## looking at it.
const FLOOR := 30.0
const CEILING := 120.0


func _ready() -> void:
	var w := get_window()
	if w != null:
		w.size = Vector2i(1280, 720)
	# Run the clock fast. create_timer() and the duel's own cooldowns are both
	# on scaled time, so the GAME seconds counted below stay honest while the
	# wall-clock cost of six duels drops from ten minutes to under one.
	Engine.time_scale = 20.0
	await get_tree().process_frame
	print("=== duel length probe ===")
	var out: Array[String] = []

	for level_id in DUELS:
		out.append_array(await _fight(level_id))

	Engine.time_scale = 1.0
	for f in out:
		print("  FAIL: ", f)
	print("DUEL LENGTH PROBE %s" % ("PASSED" if out.is_empty() else "FAILED"))
	get_tree().quit(0 if out.is_empty() else 1)


func _fight(level_id: String) -> Array[String]:
	var out: Array[String] = []
	GameManager.current_level_id = level_id
	var game: Node = load("res://scenes/minigames/monster_duel/MonsterDuel.tscn")\
		.instantiate()
	add_child(game)
	for i in range(6):
		await get_tree().process_frame

	var need: int = game.call("target_value", "correct", 0)
	if need <= 0:
		out.append("%s has no target -- it will end on the first hit" % level_id)
		game.queue_free()
		await get_tree().process_frame
		return out

	# Fight. Beam whenever it is off cooldown.
	#
	# The light bar is held full throughout, on purpose. This probe measures
	# the BEAM clock -- how long the monster takes to give up when every shot
	# lands -- and a probe that does not shield or swat runs out of light in
	# twenty seconds and stops the duel with the heart-potion card, measuring
	# nothing. Real play is slower than this number, never faster.
	var seconds := 0.0
	var hits := 0
	var step := 0.1
	while not bool(game.get("_finished")) and seconds < 240.0:
		game.set("_light_left", 5)
		if get_tree().paused:
			get_tree().paused = false
		if bool(game.call("fire_beam_skill")):
			hits += 1
		await get_tree().create_timer(step).timeout
		seconds += step
		if not is_instance_valid(game):
			break

	var landed: int = 0
	if is_instance_valid(game) and game.get("result") != null:
		landed = int((game.result as LevelResult).correct)
	print("  %-19s need %2d  ->  %5.1f s, %d beams, %d landed%s"
		% [level_id, need, seconds, hits, landed,
			"" if seconds < 240.0 else "  (NEVER ENDED)"])

	if seconds >= 240.0:
		out.append("%s never ended" % level_id)
	elif seconds < FLOOR:
		out.append("%s is over in %.1f s even before dodging -- not a fight"
			% [level_id, seconds])
	elif seconds > CEILING:
		out.append("%s takes %.1f s of perfect play; he will stop looking"
			% [level_id, seconds])

	if is_instance_valid(game):
		game.queue_free()
	await get_tree().process_frame
	return out
