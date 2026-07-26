extends RefCounted
## 星星币 -- the one thing in this game a child can spend.
##
## Deliberately NOT a `class_name`. Godot's global class cache is only rebuilt
## by the editor, so a new class name is a parse error on any machine that has
## not rescanned -- and a parse error takes the whole game grey, not one screen.
## Every shared helper here is reached the same way:
##
##     const Coins := preload("res://scripts/shop/currency_manager.gd")
##
##
## WHY THIS FILE EXISTS
##
## Before it, the island had three money-shaped numbers:
##
##   total_stars()   the achievement count. Unlocks worlds. Only ever rises.
##   star_balance()  total_stars() minus rewards.spent_stars -- a PURSE, spent
##                   in the item shop on potions.
##   rewards.coins   a second currency, spent on outfits and stickers.
##
## The middle one is the problem. Its author saw it coming -- there is a
## comment in save_manager.gd explaining that spending must never re-lock a
## world, which is why it is a subtraction and not a decrement. The arithmetic
## is careful and the child still watches "89 stars" become "83 stars" after
## buying a potion, and has no way to know that the number the map cares about
## did not move. Two numbers that look identical and mean different things is
## not something a six-year-old can be expected to hold.
##
## So there are two now, and only two:
##
##   关卡星章  total_stars()      a score. Never spent, never spendable.
##   星星币    rewards.coins      money. The only thing purchases touch.
##
## Everything that spends goes through spend() here. Nothing else in the
## codebase may decrement a currency, which is what makes "buying can never
## cost him a star" a fact about the code rather than a promise in a comment.

const KEY := "coins"


static func balance() -> int:
	return int(SaveManager.data["rewards"].get(KEY, 0))


static func can_afford(amount: int) -> bool:
	return amount >= 0 and balance() >= amount


## Money in. `reason` is not stored -- it is there so every call site has to
## say out loud what the child did to deserve it, which is the only defence
## against a reward quietly appearing from nowhere.
static func earn(amount: int, _reason: String = "") -> int:
	if amount <= 0:
		return 0
	SaveManager.data["rewards"][KEY] = balance() + amount
	SaveManager.save_game()
	SaveManager.progress_changed.emit()
	return amount


## Money out. Returns false and changes NOTHING when it will not fit, so a
## caller that forgets to check cannot overdraw.
static func spend(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	SaveManager.data["rewards"][KEY] = balance() - amount
	SaveManager.save_game()
	SaveManager.progress_changed.emit()
	return true


## Undo a purchase, in full. The brief asks for a "放回去" button after a
## mis-tap, and a partial refund would be a worse lesson than no refund.
static func refund(amount: int) -> void:
	earn(amount, "undo")


## How short he is, for the "还差一点点星星" line. Never negative.
static func short_by(price: int) -> int:
	return maxi(price - balance(), 0)
