extends Node
## Turns a LevelResult into coins, badges and growth points.
##
## Rules kept in one place so no level can invent its own economy. There is no
## spendable-for-money currency, no loot box, and no randomised reward.

const Coins := preload("res://scripts/shop/currency_manager.gd")

signal badge_earned(badge_id: String)

var last_new_badge: String = ""
var last_coins_earned: int = 0
var last_xp_earned: int = 0
var last_levels_gained: int = 0


## Pay out for something that is not a level.
##
## 星光菜园's orders are the first of these: he grows three carrots, a bear asks
## for three carrots, and handing them over is worth 星星币. That is a reward,
## and rewards belong in one file -- the alternative is the garden calling
## Coins.earn() directly, which is exactly how a second economy starts.
##
## `once_key` is the whole of the "an order pays once" rule. The caller passes
## the list it keeps of what it has already been paid for, this refuses to pay
## twice for the same key, and it is the CALLER's list because only the caller
## knows where to persist it. Anything paid here is recorded before this
## returns, so an await on the animation afterwards cannot let a second press
## through.
##
## Returns the coins actually paid: 0 means "already paid for" or "nothing to
## pay", and both are things the caller should be able to see.
func grant(source: String, coins: int, once_key: String,
		already_paid: Array) -> int:
	if coins <= 0:
		return 0
	if once_key != "" and once_key in already_paid:
		return 0
	if once_key != "":
		already_paid.append(once_key)
	Coins.earn(coins, source)
	last_coins_earned = coins
	return coins


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

	# Read the bonuses BEFORE recording, or every one of them compares this run
	# against itself and pays nothing, forever.
	var bonus := _first_time_bonuses(result, level, previous, stars)
	SaveManager.record_level_result(result.level_id, stars, result.accuracy(),
		result.found_hidden)

	# 星星币 scale with stars, and only the improvement is paid out, so replaying
	# a mastered level is fun but not a coin farm.
	var base_coins := int(reward.get("coins", 10))
	var new_coins := int(round(base_coins * (float(stars) / 3.0)))
	var already_paid := int(round(base_coins * (float(previous_stars) / 3.0)))
	var delta_coins := maxi(0, new_coins - already_paid)
	delta_coins += bonus
	last_coins_earned = delta_coins
	if delta_coins > 0:
		Coins.earn(delta_coins, "level:%s" % result.level_id)

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


## The five ways to earn 星星币 that are not "you finished the level".
##
## The brief lists six sources. Only the first -- finishing -- was implemented;
## the other five paid nothing at all, so a child who hunted down every hidden
## gem on the island was no richer for it than one who walked past them. These
## are the other five.
##
## Every one is FIRST TIME ONLY, and every one is decided by comparing this run
## against what the save already knew. No new bookkeeping, no counters that can
## drift: if the save does not yet record it and this run did it, it pays once
## and can never pay again.
##
## They are also, deliberately, all small. The point is not to make hunting
## lucrative -- it is to make it *count*, so that the child who looks around is
## visibly better off than the child who does not.
const BONUS_FIRST_THREE := 10     # first time a level gives up all three stars
const BONUS_HIDDEN := 5           # the hidden gem, found for the first time
const BONUS_RESCUE := 5           # a rescue case seen through to the end
const BONUS_CHEST := 3            # the level's chest, opened for the first time
const BONUS_CHALLENGE := 15       # a challenge rank beaten


func _first_time_bonuses(result: LevelResult, level: Dictionary,
		previous: Dictionary, stars: int) -> int:
	var bonus := 0
	var first_finish: bool = not bool(previous.get("completed", false))

	if stars >= 3 and int(previous.get("stars", 0)) < 3:
		bonus += BONUS_FIRST_THREE
	# `found_hidden` is only meaningful for templates that score by objective;
	# everything else leaves it false and is never paid for it.
	if result.objective_scoring and result.found_hidden \
			and not bool(previous.get("found_hidden", false)):
		bonus += BONUS_HIDDEN
	if first_finish and str(level.get("game_type", "")) == "roleplay_rescue":
		bonus += BONUS_RESCUE
	if first_finish and result.reached_goal:
		bonus += BONUS_CHEST
	# Challenge rank is bumped by GameManager AFTER this runs, so the rank read
	# here is the one he had going in -- beating it again pays again, which is
	# the whole point of a challenge that keeps growing.
	if bool(level.get("challenge", false)) and not result.quit_early:
		bonus += BONUS_CHALLENGE
	return bonus


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
