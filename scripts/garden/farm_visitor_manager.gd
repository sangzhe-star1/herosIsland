extends RefCounted
## Farm Visitor Manager: deterministic daily visitor schedule and dish gifting.
##
## Rules:
## 1. Visitors come on a fixed schedule (by weekday) shown on the visit board,
##    never by chance.
## 2. Each day, the visiting friend asks for one dish from the kitchen.
## 3. Gifting the dish earns star coins and friendship stars.
## 4. No random drops, no decay, no guilt.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Recipes := preload("res://scripts/garden/recipe_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Farm := preload("res://scripts/garden/farm_save.gd")


static func schedule() -> Array:
	return GameData.farm_visitor_schedule.get("schedule", [])


static func today_visitor() -> Dictionary:
	var dt: Dictionary = GameClock.now_datetime()
	var weekday := int(dt.get("weekday", 0))
	for entry in schedule():
		if int(entry.get("day_of_week", -1)) == weekday:
			return entry
	if not schedule().is_empty():
		return schedule()[0]
	return {}


static func today_date_key() -> String:
	return GameClock.now_date()


static func has_fed_today(farm: Dictionary) -> bool:
	var fed_visitors: Dictionary = farm.get("fed_visitors", {})
	return bool(fed_visitors.get(today_date_key(), false))


static func can_feed_visitor(farm: Dictionary) -> bool:
	if has_fed_today(farm):
		return false
	var visitor := today_visitor()
	if visitor.is_empty():
		return false
	var dish_id := str(visitor.get("dish_id", ""))
	return Barn.count(Recipes.dish_id(dish_id), "inventory") >= 1


static func feed_visitor(farm: Dictionary) -> Dictionary:
	if not can_feed_visitor(farm):
		return {}
	var visitor := today_visitor()
	var who := str(visitor.get("who", "rabbit"))
	var dish_id := str(visitor.get("dish_id", ""))
	var reward_coins := int(visitor.get("reward_coins", 15))

	if not Recipes.give_to_friend(who, dish_id):
		return {}

	# Record fed for today
	var fed_visitors: Dictionary = farm.get("fed_visitors", {})
	fed_visitors[today_date_key()] = true
	farm["fed_visitors"] = fed_visitors

	# Award coins
	Coins.earn(reward_coins)

	# Check visitor milestones
	var milestones: Array = GameData.farm_visitor_milestones.get(who, [])
	var friends: Dictionary = farm.get("npc_friendship", {})
	var visit_count := int(friends.get(who, 0))
	var ledger: Dictionary = SaveManager.data.get("farm_visitors", {})
	var given_milestones: Array = ledger.get(who, [])
	for stone in milestones:
		var sid := str(stone.get("id", ""))
		if sid != "" and not sid in given_milestones and visit_count >= int(stone.get("at_visits", 999)):
			given_milestones.append(sid)
			var gift: Dictionary = stone.get("gift", {})
			if int(gift.get("coins", 0)) > 0:
				Coins.earn(int(gift["coins"]))
			if int(gift.get("plank", 0)) > 0:
				Barn.put("plank", int(gift["plank"]), "inventory")
	ledger[who] = given_milestones
	SaveManager.data["farm_visitors"] = ledger

	SaveManager.save_game()
	return {
		"who": who,
		"dish_id": dish_id,
		"coins": reward_coins,
		"success": true
	}
