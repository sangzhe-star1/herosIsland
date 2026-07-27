extends Node
## Probe for the progression layer: hero XP, improvement-only coins, sticker
## spending, and challenge rank scaling -- including the rule this probe
## exists to protect: a scaled challenge target must be the target the level
## actually completes at, not just the number on the label.
##
## Runs headless, snapshots the save first and restores it after, so it can
## run on a machine with a real child's save without touching it.


const Coins := preload("res://scripts/shop/currency_manager.gd")

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== progression probe ===")
	var snapshot: Dictionary = SaveManager.data.duplicate(true)

	_check_xp_and_coins()
	_check_stickers()
	_check_a_sitting_starts_when_he_sits_down()
	await _check_challenge_scaling()

	SaveManager.data = snapshot
	SaveManager.save_game()

	for f in _failures:
		print("FAIL  %s" % f)
	print("PROGRESSION PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _check_xp_and_coins() -> void:
	var xp_before := int(SaveManager.data["profile"].get("xp", 0))
	var coins_before := int(SaveManager.data["rewards"]["coins"])
	var stars_before: Dictionary = SaveManager.data["levels"].duplicate(true)

	var clean := LevelResult.new("sunny_park_01")
	clean.correct = 8
	RewardManager.grant_for_level(clean)
	_ok(RewardManager.last_xp_earned == 45, "clean run should pay 45 XP, paid %d" % RewardManager.last_xp_earned)
	var first_coins := RewardManager.last_coins_earned
	_ok(first_coins >= 0, "coins should never be negative")

	# The same result again: coins pay improvement only (zero the second
	# time), XP pays effort (again in full).
	var again := LevelResult.new("sunny_park_01")
	again.correct = 8
	RewardManager.grant_for_level(again)
	_ok(RewardManager.last_coins_earned == 0,
		"replaying at the same stars must pay 0 coins, paid %d" % RewardManager.last_coins_earned)
	_ok(RewardManager.last_xp_earned == 45, "replay should still pay full XP")
	_ok(int(SaveManager.data["profile"]["xp"]) == xp_before + 90, "XP should accumulate by 90")

	# hero_level maths: 120 XP per level, floor + 1.
	SaveManager.data["profile"]["xp"] = 0
	_ok(SaveManager.hero_level() == 1, "0 XP should be hero level 1")
	SaveManager.data["profile"]["xp"] = 359
	_ok(SaveManager.hero_level() == 3, "359 XP should be hero level 3")
	var gained := SaveManager.add_xp(1)
	_ok(gained == 1 and SaveManager.hero_level() == 4, "360th XP point should gain exactly one level")

	SaveManager.data["levels"] = stars_before
	SaveManager.data["rewards"]["coins"] = coins_before
	print("  xp and coins hold")


func _check_stickers() -> void:
	SaveManager.data["rewards"]["coins"] = 10
	_ok(not Coins.spend(11), "spending more than owned must fail")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 10, "failed spend must not deduct")
	_ok(Coins.spend(8), "affordable spend must succeed")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 2, "spend must deduct exactly")
	SaveManager.add_sticker("check")
	_ok(SaveManager.has_sticker("check"), "sticker must be owned after purchase")
	SaveManager.add_sticker("check")
	_ok(SaveManager.data["rewards"]["stickers"].count("check") == 1, "sticker must not duplicate")
	print("  sticker economy holds")


func _check_challenge_scaling() -> void:
	# Challenge levels were a feature of the twelve retired templates: a level
	# that grew its own target each time it was beaten. The rebuilt island
	# grows differently -- every adventure level is beatable at three stars
	# and the RANGE comes from the beats, not from a rising counter -- so
	# there is no challenge level left to scale.
	#
	# The rule this used to protect still matters and is still tested, in
	# `LevelManager.bump_target` and `LevelResult.target_override`: scaling
	# must land on the run's own copy and never leak into GameData.
	var level_id := "sunny_park_01"
	var data := GameData.get_level(level_id)
	_ok(not data.is_empty(), "the first level of the island must exist")

	GameManager.current_level_id = level_id
	var packed: PackedScene = load("res://scenes/adventure/Adventure.tscn")
	var level: Node = packed.instantiate()
	add_child(level)
	for i in range(8):
		await get_tree().process_frame

	level.bump_target("correct", 4)
	_ok(int(level.level_data["target"]["correct"]) == 4,
		"bump_target must raise the run's own target")
	_ok(GameData.get_level(level_id).get("target", {}).is_empty(),
		"scaling leaked into GameData")
	level.result.correct = 3
	_ok(not level.result.met_target(), "3 of 4 must not count as met")
	level.result.correct = 4
	_ok(level.result.met_target(), "4 of 4 must count as met")

	remove_child(level)
	level.queue_free()
	await get_tree().process_frame
	print("  challenge scaling holds")


## A sitting starts when he sits down.
##
## RestDirector.new_session() existed for months without a caller, so
## levels_this_session only ever went up: the every-third-level break was
## counted from an arbitrary moment weeks in the past rather than from when he
## picked the tablet up. boot.gd calls it now, and this notices if that line is
## ever taken out again -- a helper with no caller is not a feature.
func _check_a_sitting_starts_when_he_sits_down() -> void:
	SaveManager.set_setting("levels_this_session", 9)
	RestDirector.new_session()
	_ok(RestDirector.so_far() == 0, "a new sitting starts the level count at zero")

	var rhythm: Array = []
	for i in range(6):
		rhythm.append(RestDirector.should_offer())
	_ok(rhythm == [false, false, true, false, false, true],
		"and the break comes every third level of THIS sitting, not of all time")

	# On a line that is CODE. The first version of this check just searched the
	# whole file, and the explanation of why the call exists sits in a comment
	# directly above it -- so deleting the call left the check passing on its
	# own footnote.
	var calls_it := false
	for line in FileAccess.get_file_as_string("res://scripts/ui/boot.gd").split("\n"):
		if not line.strip_edges().begins_with("#") \
				and line.contains("RestDirector.new_session()"):
			calls_it = true
	_ok(calls_it, "and boot actually calls it, in code and not in a comment")
	print("  the rest rhythm is measured from this sitting")
