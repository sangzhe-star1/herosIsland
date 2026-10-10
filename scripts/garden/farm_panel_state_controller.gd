extends RefCounted
## The one farm sheet currently covering the world, plus its barn view.
##
## The screen used nine booleans for mutually exclusive panels. One route
## string makes exclusivity structural, while the barn's ordinary/waiting
## switch remains a small state belonging to that route.

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


## Replace the current sheet with the named route. Unknown names close the
## sheet, matching the screen's previous all-flags-false behavior.
func open(route: String) -> String:
	active = str(ROUTES.get(route, ""))
	barn_show_overflow = route == "basket" and active == "barn"
	return active


## Close the active sheet, or close it only if `route` is the current route.
## Aliases such as `basket` and `bear_door` resolve to their owning sheet.
func close(route: String = "") -> bool:
	if route == "":
		active = ""
		barn_show_overflow = false
		return true
	var canonical := str(ROUTES.get(route, ""))
	if canonical == "" or canonical != active:
		return false
	active = ""
	barn_show_overflow = false
	return true


func is_open(route: String) -> bool:
	var canonical := str(ROUTES.get(route, ""))
	return canonical != "" and active == canonical


func any_open() -> bool:
	return active != ""
