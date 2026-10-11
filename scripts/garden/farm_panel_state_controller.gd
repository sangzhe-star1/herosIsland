extends RefCounted
## The one farm sheet currently covering the world, plus its barn view.
##
## The screen used nine booleans for mutually exclusive panels. One route
## string makes exclusivity structural, while route-local pages, confirmations,
## and uncommitted baskets live for exactly one panel visit. View nodes remain
## with the screen and are rebuilt there.

const ROUTES := {
	"challenges": "challenges",
	"orders": "orders",
	"shop": "shop",
	"market": "market",
	"barn": "barn",
	"basket": "barn",
	"visits": "visits",
	"recipes": "recipes",
	"kitchen": "kitchen",
	"gift": "gift",
	"bear_door": "gift",
}

var active := ""
var barn_show_overflow := false

## A panel visit is a short-lived interaction session. Keep page and
## confirmation state beside the active route so opening another door cannot
## leave an old purchase or page selection visible in the next sheet.
var challenge_page := 0
var shop_page := 0
var book_page := 0
var kitchen_page := 0
var confirm_crop := ""
var confirm_cook := ""
var confirm_upgrade := false
var confirm_expand := -1
var gift_basket: Dictionary = {}
var market_sell: Dictionary = {}


## Replace the current sheet with the named route. Unknown names close the
## sheet, matching the screen's previous all-flags-false behavior.
func open(route: String) -> String:
	active = str(ROUTES.get(route, ""))
	barn_show_overflow = route == "basket" and active == "barn"
	_reset_pages_and_confirmations()
	if route != "market":
		market_sell = {}
	if route != "gift" and route != "bear_door":
		gift_basket = {}
	return active


## Close the active sheet, or close it only if `route` is the current route.
## Aliases such as `basket` and `bear_door` resolve to their owning sheet.
func close(route: String = "") -> bool:
	if route == "":
		active = ""
		barn_show_overflow = false
		_clear_visit_state()
		return true
	var canonical := str(ROUTES.get(route, ""))
	if canonical == "" or canonical != active:
		return false
	active = ""
	barn_show_overflow = false
	_clear_visit_state()
	return true


func is_open(route: String) -> bool:
	var canonical := str(ROUTES.get(route, ""))
	return canonical != "" and active == canonical


func any_open() -> bool:
	return active != ""


func _reset_pages_and_confirmations() -> void:
	challenge_page = 0
	shop_page = 0
	book_page = 0
	kitchen_page = 0
	confirm_crop = ""
	confirm_cook = ""
	confirm_upgrade = false
	confirm_expand = -1


func _clear_visit_state() -> void:
	confirm_crop = ""
	confirm_cook = ""
	confirm_upgrade = false
	confirm_expand = -1
	gift_basket = {}
	market_sell = {}
