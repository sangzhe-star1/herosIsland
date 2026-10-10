extends RefCounted
## Collection feedback shared by crop, facility, pond, and dog receipts.
##
## GardenScreen supplies the common feedback layer, the truthful destination
## positions, and its crop-picture builder. This controller owns only the
## flying receipt and the short harvest combo label; transactions and saves
## remain with their gameplay controllers.

var _combo_label: Label


func show_combo(host: Node, layer: CanvasLayer, count: int,
		receipt: Dictionary, source_at: Vector2, source_valid: bool,
		warehouse_at: Vector2, basket_at: Vector2, viewport_size: Vector2,
		top_bar: float, picture_builder: Callable) -> void:
	if _combo_label == null or not is_instance_valid(_combo_label):
		_combo_label = UiKit.title("", 64, Color(1.0, 0.62, 0.12))
		_combo_label.name = "HarvestYield"
		_combo_label.position = Vector2(viewport_size.x * 0.5 - 70.0,
			top_bar + 30.0)
		_combo_label.size = Vector2(140, 72)
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_combo_label)
	_combo_label.text = "x%d" % count
	Juice.pop(_combo_label, 0.22)

	if not source_valid or not Juice.motion_enabled():
		return
	var crop_id := str(receipt.get("crop_id", ""))
	if crop_id.is_empty():
		return
	# Older callers supplied only `amount`; keep that harmless shape meaning
	# "all stored" while the harvesting path carries the full receipt.
	var stored := maxi(int(receipt.get("stored", receipt.get("amount", 0))), 0)
	var spilled := maxi(int(receipt.get("spilled", 0)), 0)
	if stored > 0:
		show_flight(layer, host, receipt, stored, warehouse_at,
			"warehouse", "HarvestFlight", picture_builder, source_at)
	if spilled > 0:
		show_flight(layer, host, receipt, spilled, basket_at,
			"harvest_basket", "HarvestSpillFlight", picture_builder, source_at)


## One crop or produce icon travelling to the place that received it.
## Facility outputs use this same path, with their world position supplied as
## `from_at`; harvests use the bed position passed by show_combo().
func show_flight(layer: CanvasLayer, host: Node, receipt: Dictionary,
		amount: int, destination_at: Vector2, destination: String,
		node_prefix: String, picture_builder: Callable,
		from_at: Vector2 = Vector2.INF) -> void:
	var crop_id := str(receipt.get("crop_id", ""))
	var golden := bool(receipt.get("golden", false))
	var art: Control = picture_builder.call(crop_id, 44.0,
		"HarvestCropPicture", golden)
	if art == null:
		return
	art.name = "%s_%s" % [node_prefix, crop_id]
	art.set_meta("crop_id", crop_id)
	art.set_meta("amount", amount)
	art.set_meta("total_amount", int(receipt.get("amount", amount)))
	art.set_meta("stored", int(receipt.get("stored", amount)))
	art.set_meta("spilled", int(receipt.get("spilled", 0)))
	art.set_meta("destination", destination)
	art.set_meta("destination_at", destination_at)
	art.set_meta("golden", golden)
	# A receipt remains queryable after the 0.4-second sprite has left, so a
	# slow frame or the probe can still verify what flew and where it landed.
	var stamp := {"node": art.name, "crop_id": crop_id, "amount": amount,
		"destination": destination, "destination_at": destination_at}
	host.set_meta("last_harvest_flight", stamp)
	var flights: Array = host.get_meta("harvest_flights", [])
	flights.append(stamp)
	while flights.size() > 8:
		flights.pop_front()
	host.set_meta("harvest_flights", flights)
	if golden:
		art.modulate = Color(1.0, 0.85, 0.35)
	var start := from_at if from_at.is_finite() else Vector2.ZERO
	art.position = start - Vector2(22, 22)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(art)
	# If one crop batch splits, small counts show how much reached each real
	# destination instead of implying the entire yield went to the barn.
	if amount != int(receipt.get("amount", amount)):
		var count := UiKit.on_art(UiKit.title("×%d" % amount, 20, Color.WHITE), 4)
		count.name = "FlightAmount"
		count.position = Vector2(24.0, -13.0)
		count.size = Vector2(46.0, 24.0)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(count)
	var tween := art.create_tween()
	tween.tween_property(art, "position", destination_at - Vector2(22, 22), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(art, "scale", Vector2(0.5, 0.5), 0.4)
	tween.tween_callback(art.queue_free)


func end_combo() -> void:
	if _combo_label == null or not is_instance_valid(_combo_label):
		return
	var label := _combo_label
	_combo_label = null
	if Juice.motion_enabled():
		var tween := label.create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)
	else:
		label.queue_free()
