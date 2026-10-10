extends RefCounted
## Choose the order cards the child can see, then derive the next usable one.
## The screen supplies live data and draws the returned cards.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const BOARD_SIZE := 3


## One-time requests get their turn before routine baskets. Routine baskets
## rotate by completed delivery count; ties preserve catalogue order. Finished
## story receipts fill only the remaining spaces, newest receipt last.
static func select_orders_for_board(catalogue: Array, delivered: Array,
		counts: Dictionary, farm_level: int) -> Array:
	var story: Array = []
	var recurring: Array = []
	var receipts: Array = []
	for index in range(catalogue.size()):
		var order: Dictionary = catalogue[index]
		var gate := str(order.get("unlock_condition", ""))
		if gate.begins_with("level:") and farm_level < int(gate.substr(6)):
			continue
		var order_id := str(order.get("id", ""))
		if bool(order.get("recurring", false)):
			recurring.append({"order": order, "index": index,
				"count": maxi(0, int(counts.get(order_id, 0)))})
		elif order_id in delivered:
			receipts.append(order)
		else:
			story.append(order)
	recurring.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) == int(b["count"]):
			return int(a["index"]) < int(b["index"])
		return int(a["count"]) < int(b["count"]))
	var board: Array = story.slice(0, BOARD_SIZE)
	for row in recurring:
		if board.size() == BOARD_SIZE:
			break
		board.append(row["order"])
	while board.size() < BOARD_SIZE and not receipts.is_empty():
		board.append(receipts.pop_back())
	return board


static func first_pending(board: Array, delivered: Array) -> Dictionary:
	for order in board:
		var order_id := str(order.get("id", ""))
		if not order_id in delivered:
			return order
	return {}


static func first_fillable(board: Array, delivered: Array) -> Dictionary:
	for order in board:
		if str(order.get("id", "")) in delivered:
			continue
		if Barn.can_pay(order.get("requirements", {})):
			return order
	return {}
