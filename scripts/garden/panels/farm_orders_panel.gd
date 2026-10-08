extends "res://scripts/garden/panels/farm_panel_base.gd"
## Notice board sheet: pending customer orders and daily tasks.

const Barn := preload("res://scripts/garden/inventory_manager.gd")
const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")
const Juice := preload("res://scripts/ui/juice.gd")

const ORDER_CARD := Vector2(378, 94)
const ORDER_FIRST := 48.0
const ORDER_GAP := 102.0
const ORDER_BOARD_CARDS := 3


func build(view: Vector2) -> void:
	var delivered: Array = SaveManager.data.get("farm_orders", {}).get("delivered", [])
	var board: Array = screen.call("_orders_for_board", delivered)
	var at: Vector2 = screen.call("_order_board_origin")

	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.99, 0.97, 0.90), 28))
	sheet.position = at - Vector2(28, 20)
	sheet.custom_minimum_size = Vector2(ORDER_CARD.x + 56.0,
		ORDER_FIRST + ORDER_GAP * float(maxi(board.size(), 1)) + 82.0)
	sheet.size = sheet.custom_minimum_size
	play.add_child(sheet)
	block_world(sheet)

	sheet_close(sheet.position + Vector2(sheet.size.x + 14.0, 0.0),
		Callable(screen, "_close_orders"))

	var heading := UiKit.title(I18n.t("garden.orders"), 24, Color(0.26, 0.22, 0.17))
	heading.position = at
	heading.size = Vector2(400, 32)
	play.add_child(heading)

	var y := at.y + ORDER_FIRST
	for order in board:
		var order_id := str(order.get("id", ""))
		var done: bool = order_id in delivered
		var wants: Dictionary = order.get("requirements", {})
		var can: bool = Barn.can_pay(wants)

		var card := Button.new()
		card.name = "OrderCard_%s" % order_id
		card.flat = false
		card.focus_mode = Control.FOCUS_NONE
		card.position = Vector2(at.x, y)
		card.custom_minimum_size = ORDER_CARD
		card.size = ORDER_CARD
		var tint := Color(0.90, 0.92, 0.88) if done \
			else (Color(1.0, 0.99, 0.94) if can else Color(0.98, 0.97, 0.92))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			card.add_theme_stylebox_override(state, UiKit.panel_style(tint, 22))
		play.add_child(card)

		if not done and can:
			card.pressed.connect(func(): screen.call("_deliver", order))
			UiKit.breathe(card, 0.02, 1.4)
		else:
			var this_card: Button = card
			card.pressed.connect(func():
				AudioManager.play_sfx("res://assets/audio/pop.ogg")
				if done:
					Juice.pop(this_card, 0.04)
				else:
					Juice.nudge(this_card, 8.0))

		var has_purpose := not str(order.get("purpose_key", "")).is_empty()
		var detail_nodes: Array[Control] = []
		var detail_lift := -8.0 if has_purpose else 0.0
		var who: Control = screen.call("_order_customer_art", order, 44.0)
		if who != null:
			who.position = Vector2(at.x + 16.0, y + 14.0 + detail_lift)
			who.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(who)
			detail_nodes.append(who)

		var x := at.x + 86.0
		for crop_id in wants.keys():
			var art: Control = screen.call("_crop_picture", str(crop_id), 34.0)
			if art != null:
				art.position = Vector2(x, y + 16.0 + detail_lift)
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				play.add_child(art)
				detail_nodes.append(art)
			var need := int(wants[crop_id])
			var have := Barn.count(str(crop_id))
			var tally := UiKit.title("%d/%d" % [mini(have, need), need], 18)
			tally.name = "OrderTally_%s_%s" % [order_id, crop_id]
			tally.position = Vector2(x + 4.0, y + 48.0 + detail_lift)
			tally.size = Vector2(60, 24)
			tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(tally)
			detail_nodes.append(tally)
			x += 74.0

		if done:
			var tick := UiKit.picture("check", 44.0)
			if tick != null:
				tick.position = Vector2(at.x + 310.0, y + 26.0)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				play.add_child(tick)
				detail_nodes.append(tick)
		else:
			var coin := UiKit.picture("star_coin", 28.0)
			if coin != null:
				coin.position = Vector2(at.x + 286.0, y + 14.0 + detail_lift)
				coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
				play.add_child(coin)
				detail_nodes.append(coin)
			var price := UiKit.title(str(int(order.get("rewards", {}).get("coins", 0))), 22)
			price.name = "OrderPrice_%s" % order_id
			price.position = Vector2(at.x + 286.0, y + 44.0 + detail_lift)
			price.size = Vector2(60, 26)
			price.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(price)
			detail_nodes.append(price)

		if has_purpose:
			card.tooltip_text = I18n.t(str(order["purpose_key"]))
			var purpose := UiKit.title(I18n.t(str(order["purpose_key"])), 14,
				Color(0.44, 0.40, 0.31))
			purpose.name = "OrderPurpose_%s" % order_id
			purpose.tooltip_text = I18n.t(str(order["purpose_key"]))
			purpose.size = Vector2(ORDER_CARD.x - 32.0, 22.0)
			purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			purpose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			purpose.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(purpose)
			var purpose_height := maxf(22.0, purpose.get_minimum_size().y)
			purpose.size.y = purpose_height
			purpose.position = Vector2(at.x + 16.0, y + ORDER_CARD.y - 2.0 - purpose_height)
			var details_bottom := y
			for detail in detail_nodes:
				details_bottom = maxf(details_bottom, detail.position.y + maxf(detail.size.y, detail.get_minimum_size().y))
			var lift := minf(0.0, purpose.position.y - 2.0 - details_bottom)
			for detail in detail_nodes:
				detail.position.y += lift
		y += ORDER_GAP

	var jobs_y := at.y + ORDER_FIRST + ORDER_GAP * float(board.size()) + 4.0
	var daily_state: Dictionary = (screen.call("_farm") as Dictionary).get("dailies", {})
	var job_x := at.x + 12.0
	for task in GameData.garden_dailies:
		var task_id := str(task.get("id", ""))
		var tally := int(daily_state.get("progress", {}).get(task_id, 0))
		var want := Dailies.target(task_id)
		var is_done := Dailies.done(daily_state, task)
		var is_claimed := Dailies.claimed(daily_state, task)
		var job := Button.new()
		job.flat = false
		job.focus_mode = Control.FOCUS_NONE
		job.position = Vector2(job_x, jobs_y)
		job.custom_minimum_size = Vector2(116, 48)
		job.size = Vector2(116, 48)
		var fill := Color(0.98, 0.97, 0.92)
		if is_claimed:
			fill = Color(0.93, 0.93, 0.90)
		elif is_done:
			fill = Color(0.88, 0.95, 0.84)
		for look in ["normal", "hover", "pressed", "focus"]:
			job.add_theme_stylebox_override(look, UiKit.panel_style(fill, 14))
		var ready := is_done and not is_claimed
		job.disabled = not ready
		job.name = "DailyJob_%s" % task_id
		play.add_child(job)
		if ready:
			job.pressed.connect(func(): screen.call("_claim_daily", task))
			UiKit.breathe(job, 0.02, 1.4)
		var job_art := UiKit.picture(str(task.get("icon", "check")), 26.0)
		if job_art != null:
			job_art.position = Vector2(job_x + 8.0, jobs_y + 11.0)
			job_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(job_art)
		var tally_label := UiKit.title("%d/%d" % [mini(tally, want), want], 18)
		tally_label.position = Vector2(job_x + 38.0, jobs_y + 13.0)
		tally_label.size = Vector2(44, 22)
		tally_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play.add_child(tally_label)
		if is_claimed:
			var tick := UiKit.picture("check", 20.0)
			if tick != null:
				tick.position = Vector2(job_x + 84.0, jobs_y + 14.0)
				tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
				play.add_child(tick)
		else:
			var job_coin := UiKit.picture("star_coin", 14.0)
			if job_coin != null:
				job_coin.position = Vector2(job_x + 80.0, jobs_y + 17.0)
				job_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
				play.add_child(job_coin)
			var job_price := UiKit.title(str(int(task.get("coins", 0))), 16)
			job_price.position = Vector2(job_x + 94.0, jobs_y + 15.0)
			job_price.size = Vector2(22, 20)
			job_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play.add_child(job_price)
		job_x += 122.0
