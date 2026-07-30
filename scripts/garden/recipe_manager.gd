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
