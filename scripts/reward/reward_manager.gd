extends Node
## Turns a LevelResult into coins, badges and growth points.
##
## Rules kept in one place so no level can invent its own economy. There is no
## spendable-for-money currency, no loot box, and no randomised reward.

signal badge_earned(badge_id: String)

var last_new_badge: String = ""
var last_coins_earned: int = 0
var last_xp_earned: int = 0
var last_levels_gained: int = 0


func grant_for_level(result: LevelResult) -> void:
	last_new_badge = ""
	last_coins_earned = 0
	last_xp_earned = 0
	last_levels_gained = 0
	if result.quit_early:
		return

	var level := GameData.get_level(result.level_id)
	var reward: Dictionary = level.get("reward", {})
	var stars := result.stars()

	var previous := SaveManager.get_level_progress(result.level_id)
	var previous_stars := int(previous.get("stars", 0))

	SaveManager.record_level_result(result.level_id, stars, result.accuracy())

	# Coins scale with stars, and only the improvement is paid out, so replaying
	# a mastered level is fun but not a coin farm.
	var base_coins := int(reward.get("coins", 10))
	var new_coins := int(round(base_coins * (float(stars) / 3.0)))
	var already_paid := int(round(base_coins * (float(previous_stars) / 3.0)))
	var delta_coins := maxi(0, new_coins - already_paid)
	last_coins_earned = delta_coins
	if delta_coins > 0:
		SaveManager.add_coins(delta_coins)

	var badge: String = reward.get("badge", "")
	if badge != "" and stars >= 2:
		if SaveManager.add_badge(badge):
			last_new_badge = badge
			badge_earned.emit(badge)

	_grant_growth(level, stars)

	# Hero experience: every finished level feeds the hero level, replays
	# included -- effort always counts, unlike coins which pay improvement
	# only. Challenges pay a rank bonus, so the endless levels stay the best
	# way to grow once the hand-made ones are mastered.
	var xp := 15 + 10 * stars
	if bool(level.get("challenge", false)):
		xp += 20 + 5 * mini(SaveManager.get_challenge_rank(result.level_id), 8)
	last_xp_earned = xp
	last_levels_gained = SaveManager.add_xp(xp)


## Growth attributes rise from the world the level belongs to. They are shown to
## the child as things that get bigger, never as a score to compare.
func _grant_growth(level: Dictionary, stars: int) -> void:
	var attribute: String = level.get("growth_attribute", "")
	if attribute == "":
		var world := GameData.get_world(level.get("world", ""))
		attribute = world.get("growth_attribute", "")
	if attribute != "":
		SaveManager.add_growth(attribute, stars)


func badge_name(badge_id: String) -> String:
	var badges: Dictionary = GameData.rewards.get("badges", {})
	var badge: Dictionary = badges.get(badge_id, {})
	var key: String = badge.get("name_key", "")
	return I18n.t(key) if key != "" else badge_id
