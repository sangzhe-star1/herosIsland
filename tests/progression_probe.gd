extends Node
## Probe for the progression layer: hero XP, improvement-only coins, sticker
## spending, and challenge rank scaling -- including the rule this probe
## exists to protect: a scaled challenge target must be the target the level
## actually completes at, not just the number on the label.
##
## Runs headless, snapshots the save first and restores it after, so it can
## run on a machine with a real child's save without touching it.

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== progression probe ===")
	var snapshot: Dictionary = SaveManager.data.duplicate(true)

	_check_xp_and_coins()
	_check_stickers()
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

	var clean := LevelResult.new("hero_city_01")
	clean.correct = 8
	RewardManager.grant_for_level(clean)
	_ok(RewardManager.last_xp_earned == 45, "clean run should pay 45 XP, paid %d" % RewardManager.last_xp_earned)
	var first_coins := RewardManager.last_coins_earned
	_ok(first_coins >= 0, "coins should never be negative")

	# The same result again: coins pay improvement only (zero the second
	# time), XP pays effort (again in full).
	var again := LevelResult.new("hero_city_01")
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
	_ok(not SaveManager.spend_coins(11), "spending more than owned must fail")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 10, "failed spend must not deduct")
	_ok(SaveManager.spend_coins(8), "affordable spend must succeed")
	_ok(int(SaveManager.data["rewards"]["coins"]) == 2, "spend must deduct exactly")
	SaveManager.add_sticker("check")
	_ok(SaveManager.has_sticker("check"), "sticker must be owned after purchase")
	SaveManager.add_sticker("check")
	_ok(SaveManager.data["rewards"]["stickers"].count("check") == 1, "sticker must not duplicate")
	print("  sticker economy holds")


func _check_challenge_scaling() -> void:
	# Pretend the Hero City challenge has been beaten three times.
	SaveManager.data["challenges"] = {"hero_city_challenge": 3}
	# Read the base out of the data rather than asserting a number: level
	# targets move whenever the island is retuned (they just went up a step
	# across all twelve templates), and a probe that hard-codes one is a
	# probe that cries wolf every time somebody balances the game.
	var base_target := int(GameData.get_level("hero_city_challenge").get("target", {}).get("correct", 0))
	_ok(base_target > 0, "the challenge level must declare a target")

	GameManager.current_level_id = "hero_city_challenge"
	var packed: PackedScene = load("res://scenes/minigames/collect_energy/CollectEnergy.tscn")
	var level: Node = packed.instantiate()
	add_child(level)
	for i in range(8):
		await get_tree().process_frame

	var scaled := int(level.level_data.get("target", {}).get("correct", 0))
	_ok(scaled == base_target + 3, "rank 3 should raise target to %d, got %d" % [base_target + 3, scaled])

	# The rule that used to be broken: completion must be measured against
	# the SCALED target, not the base one in GameData.
	level.result.correct = base_target
	_ok(not level.result.met_target(),
		"base target must NOT complete a rank-3 challenge")
	level.result.correct = scaled
	_ok(level.result.met_target(), "scaled target must complete the challenge")

	# And GameData's own copy must be untouched by the scaling.
	var still_base := int(GameData.get_level("hero_city_challenge").get("target", {}).get("correct", 0))
	_ok(still_base == base_target, "challenge scaling leaked into GameData (now %d)" % still_base)

	remove_child(level)
	level.queue_free()
	await get_tree().process_frame
	print("  challenge scaling holds")
