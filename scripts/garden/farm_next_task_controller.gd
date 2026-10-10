extends RefCounted
## Derive the garden's next action from the live plots and visible orders.
## The screen draws and focuses the result; this controller owns its priority.

const Farm := preload("res://scripts/garden/farm_save.gd")
const Barn := preload("res://scripts/garden/inventory_manager.gd")
const PlotAction := preload("res://scripts/garden/farm_plot_action_controller.gd")


static func select(plots: Array, pending_order: Dictionary,
		deliverable_order: Dictionary, unlocked_crops: Array,
		tools: RefCounted, harvesting_ids: Dictionary = {}) -> Dictionary:
	var index: int = PlotAction.next_action_index(plots, harvesting_ids)
	if index >= 0:
		var plot: Dictionary = plots[index]
		var action := PlotAction.for_plot(plot)
		# A crop already ripe or asking for care stays ahead of delivery. Once
		# the next bed is empty or tilled, a complete order is the clearer beat.
		if not deliverable_order.is_empty() \
				and action in [PlotAction.PLANT, PlotAction.TILL]:
			return _delivery_task(deliverable_order)
		var crop_id := str(plot.get("crop_id", ""))
		var task := {
			"index": index,
			"crop_id": crop_id,
			"order": pending_order,
			"actionable": true,
		}
		match action:
			PlotAction.HARVEST:
				task.merge({
					"kind": "harvest", "tool_id": "basket", "icon": "basket",
					"title_key": "garden.next.harvest",
				}, true)
			PlotAction.CARE:
				var tool_id := str(tools.call("tool_for", plot))
				var title_key := "garden.next.water"
				if tool_id == "weed":
					title_key = "garden.next.weed"
				elif tool_id == "bug":
					title_key = "garden.next.bug"
				var tool_info: Dictionary = tools.call("tool_data", tool_id)
				task.merge({
					"kind": "care", "tool_id": tool_id,
					"icon": str(tool_info.get("icon", "watering_can")),
					"title_key": title_key,
				}, true)
			PlotAction.PLANT:
				var wanted := first_missing_order_crop(pending_order)
				if wanted == "" or not wanted in unlocked_crops:
					wanted = str(tools.call("crop_to_plant", unlocked_crops))
				task.merge({
					"kind": "plant", "tool_id": "seed", "icon": "seed",
					"crop_id": wanted, "title_key": "garden.next.seed",
				}, true)
			PlotAction.TILL:
				task.merge({
					"kind": "till", "tool_id": "shovel", "icon": "shovel",
					"title_key": "garden.next.till",
				}, true)
		return task

	if not deliverable_order.is_empty():
		return _delivery_task(deliverable_order)

	for i in range(plots.size()):
		var growing: Dictionary = plots[i]
		var plot_id := str(growing.get("plot_id", ""))
		if Farm.is_planted(growing) and not harvesting_ids.has(plot_id):
			var growing_crop := str(growing.get("crop_id", ""))
			return {
				"kind": "growing", "index": i,
				"crop_id": growing_crop,
				"icon": str(GameData.get_crop(growing_crop).get("icon", "sprout")),
				"title_key": "garden.next.growing", "order": pending_order,
				"actionable": false,
			}
	return {}


## Stable across dictionary order: the first missing crop is the one the order
## asks for alphabetically; once complete, keep the first crop as its preview.
static func first_missing_order_crop(order: Dictionary) -> String:
	if order.is_empty():
		return ""
	var wants: Dictionary = order.get("requirements", {})
	var ids: Array = wants.keys()
	ids.sort()
	for crop_id in ids:
		if Barn.count(str(crop_id)) < int(wants[crop_id]):
			return str(crop_id)
	return str(ids[0]) if not ids.is_empty() else ""


static func _delivery_task(order: Dictionary) -> Dictionary:
	return {
		"kind": "deliver", "icon": str(order.get("customer_icon", "teddy")),
		"title_key": "garden.next.deliver", "order": order,
		"actionable": true,
	}
