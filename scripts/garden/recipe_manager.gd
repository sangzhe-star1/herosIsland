extends RefCounted
## 食谱：仓库里凑齐一组作物，小熊就教一道菜。
##
##     const Recipes := preload("res://scripts/garden/recipe_manager.gd")
##
## COLLECTING, NOT COOKING. A recipe here is a card that says "you grew all
## of this at once", the garden's own album page -- the processing hut and
## any actual cooking belong to 三期. So there is exactly one verb (unlock)
## and one ledger (farm.unlocked_recipes), and unlocking takes nothing OUT
## of the barn: a reward that confiscates the harvest it praises would teach
## a child to stop filling the barn.
##
## The trigger is the BARN, not the bear's visit. The plan said "the bear
## teaches it when he visits", but a lesson that waits for a random visit
## arrives days after the harvest that earned it, and the child cannot
## connect the two. The bear still fronts the celebration card -- he teaches
## the moment the last ingredient lands, which is when the child is looking.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")


static func all() -> Array:
	return GameData.garden_recipes


static func unlocked_ids() -> Array:
	return SaveManager.data.get("farm", {}).get("unlocked_recipes", [])


static func is_unlocked(recipe_id: String) -> bool:
	return recipe_id in unlocked_ids()


## Does the warehouse hold everything this recipe wants, right now?
static func barn_has_all(recipe: Dictionary) -> bool:
	for need in recipe.get("needs", []):
		if not Barn.has(str(need.get("crop_id", "")), int(need.get("count", 1))):
			return false
	return true


## Look at the barn and unlock whatever it has newly earned. Returns the
## recipes that JUST unlocked (full dictionaries, for the celebration card);
## an empty array means nothing new. Idempotent by construction: a recipe
## already in the ledger is never returned twice, so callers may check as
## often as they like -- after every harvest, after the basket tips in --
## without a child ever being congratulated twice for the same dish.
static func check_barn() -> Array:
	var fresh: Array = []
	var farm: Dictionary = SaveManager.data.get("farm", {})
	var owned: Array = farm.get("unlocked_recipes", [])
	for recipe in all():
		var rid := str(recipe.get("id", ""))
		if rid == "" or rid in owned:
			continue
		if barn_has_all(recipe):
			owned.append(rid)
			fresh.append(recipe)
	if not fresh.is_empty():
		farm["unlocked_recipes"] = owned
		SaveManager.save_game()
	return fresh


# --- 三期：会做的菜可以下锅，做好的菜送给朋友 -----------------------------
#
# A dish is inventory item "dish_<recipe_id>" -- no new save structure, the
# same {id: count} shelf the seeds live on, no cap. Cooking SPENDS the barn's
# ingredients (through Barn.take, the one door things leave by) and giving
# spends the dish; both are asked-first in the kitchen panel, refused-with-a-
# headshake when short, and neither touches money.


static func dish_id(recipe_id: String) -> String:
	return "dish_%s" % recipe_id


static func dish_count(recipe_id: String) -> int:
	return Barn.count(dish_id(recipe_id), "inventory")


## May this recipe go on the stove right now? Knowledge AND ingredients.
static func can_cook(recipe: Dictionary) -> bool:
	return is_unlocked(str(recipe.get("id", ""))) and barn_has_all(recipe)


## One dish: the ingredients leave the warehouse, one dish arrives.
##
## All-or-nothing. The needs are checked as a whole before anything is taken,
## so a half-cooked failure -- two strawberries gone, no soup -- cannot exist.
## Returns false (and changes nothing) when knowledge or ingredients are
## short, however it was called.
static func cook(recipe_id: String) -> bool:
	var recipe: Dictionary = {}
	for row in all():
		if str(row.get("id", "")) == recipe_id:
			recipe = row
	if recipe.is_empty() or not can_cook(recipe):
		return false
	for need in recipe.get("needs", []):
		Barn.take(str(need.get("crop_id", "")), int(need.get("count", 1)))
	Barn.put(dish_id(recipe_id), 1, "inventory")
	SaveManager.save_game()
	return true


## Give one cooked dish to a friend: the dish leaves, the friendship grows by
## one star, and the visit board gets an amber thank-you entry.
static func give_to_friend(who: String, recipe_id: String) -> bool:
	if not Barn.take(dish_id(recipe_id), 1, "inventory"):
		return false
	var farm: Dictionary = SaveManager.data["farm"]
	var friends: Dictionary = farm.get("npc_friendship", {})
	friends[who] = int(friends.get(who, 0)) + 1
	farm["npc_friendship"] = friends
	var name_key := ""
	for row in all():
		if str(row.get("id", "")) == recipe_id:
			name_key = str(row.get("name_key", ""))
	Farm.remember_visit(farm, {
		"who": who, "kind": "thanks", "at": GameClock.now_unix(),
		"dish_name_key": name_key,
		"milestone_key": "garden.dish_thanks",
		"milestone_icon": "dish",
	})
	SaveManager.save_game()
	return true


static func give_to_bear(recipe_id: String) -> bool:
	return give_to_friend("bear", recipe_id)
