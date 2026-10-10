extends "res://scripts/garden/panels/farm_panel_base.gd"
## The farm shelf's one next action, with its daily crest and order preview.
## FarmNextTaskController chooses the task; this panel only presents that answer.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const NextTask := preload("res://scripts/garden/farm_next_task_controller.gd")
const HeroTaskRibbon := preload("res://scripts/ui/hero_task_ribbon.gd")

const RIBBON_AT := Vector2(580.0, 0.0)
const RIBBON_SIZE := Vector2(414.0, 60.0)


static func color_for_task(task: Dictionary) -> Color:
	match str(task.get("kind", "")):
		"harvest": return Color(1.0, 0.90, 0.58)
		"care": return Color(0.78, 0.91, 1.0)
		"plant": return Color(0.84, 0.94, 0.72)
		"till": return Color(0.96, 0.86, 0.68)
		"deliver": return Color(0.90, 0.84, 1.0)
		_: return Color(0.91, 0.94, 0.84)


static func title_for_task(task: Dictionary) -> String:
	var key := str(task.get("title_key", ""))
	if key == "":
		return ""
	var crop_id := str(task.get("crop_id", ""))
	if crop_id == "":
		return I18n.t(key)
	var crop: Dictionary = GameData.get_crop(crop_id)
	return I18n.t(key) % I18n.t(str(crop.get("name_key", "garden.tool.seed")))


func build(view: Vector2, task: Dictionary, shelf_height: float) -> void:
	if task.is_empty():
		return
	# Seven 72px tools finish at 568. The next-step card preserves action,
	# daily care and order tally in the same 60px lane on both screen shapes.
	var box := RIBBON_SIZE
	var at := Vector2(RIBBON_AT.x, view.y - shelf_height + 6.0)
	var order: Dictionary = task.get("order", {})
	var ribbon := HeroTaskRibbon.new()
	ribbon.configure({
		"name": "NextTask",
		"dense": true,
		"hint": I18n.t("garden.next"),
		"title": title_for_task(task),
		"icon": str(task.get("icon", "star")),
		"tint": color_for_task(task),
		"preview": _order_preview(order),
		"daily": _daily_badge(),
		"primary": bool(task.get("actionable", false)),
	}, box)
	ribbon.position = at
	ribbon.set_meta("kind", str(task.get("kind", "")))
	ribbon.set_meta("plot_index", int(task.get("index", -1)))
	ribbon.set_meta("tool_id", str(task.get("tool_id", "")))
	ribbon.set_meta("order_id", str(order.get("id", "")))

	var task_copy := task.duplicate(true)
	ribbon.pressed.connect(func(): screen.call("_focus_next_task", task_copy))
	play.add_child(ribbon)


func _daily_badge() -> Dictionary:
	var farm: Dictionary = screen.call("_farm")
	var daily: Dictionary = Dailies.summary(farm.get("dailies", {}))
	if bool(daily.get("all_done", false)):
		daily["label"] = I18n.t("garden.daily.lucky")
	else:
		daily["label"] = "%d/%d" % [int(daily.get("done", 0)),
			int(daily.get("total", 0))]
	return daily


## A single icon chain previews the first missing ingredient. Full details stay
## on the physical order board, so this card remains one action rather than a
## second list.
func _order_preview(order: Dictionary) -> Dictionary:
	if order.is_empty():
		return {}
	var crop_id := NextTask.first_missing_order_crop(order)
	if crop_id == "":
		return {}
	var wants: Dictionary = order.get("requirements", {})
	var need := int(wants.get(crop_id, 0))
	var crop: Dictionary = GameData.get_crop(crop_id)
	return {
		"customer_icon": str(order.get("customer_icon", "teddy")),
		"crop_icon": str(crop.get("icon", "seed")),
		"progress": "%d/%d" % [mini(Barn.count(crop_id), need), need],
	}
