extends Button
## A compact, picture-first answer to "what do I do now?".
##
## This is deliberately a display component. It receives one already-derived
## task and never reads a garden, order, barn, save file or camera itself.
## That keeps a page's existing rules as the only source of truth while making
## the child-facing hierarchy reusable by another activity later.


## A daily crest, the next action and an order preview are three independent
## reading lines. They need this much vertical room at the project's caption
## size; below it, the optional preview yields instead of letting letters
## overlap. Callers that want all three use this same component at 78px.
const THREE_LINE_HEIGHT := 78.0
const DAILY_ACTION_Y := 24.0


func configure(spec: Dictionary, box: Vector2) -> void:
	name = str(spec.get("name", "HeroTaskRibbon"))
	flat = false
	focus_mode = Control.FOCUS_NONE
	# The visual only needs the one action. Keep its short category available to
	# hover, assistive tooling and future keyboard navigation without asking a
	# pre-reader to decode an extra line on the card.
	tooltip_text = str(spec.get("hint", ""))
	custom_minimum_size = box
	size = box
	var tint: Color = spec.get("tint", Palette.YELLOW)
	for look in ["normal", "hover", "pressed", "focus"]:
		var fill := tint
		if look == "hover":
			fill = Palette.lift(tint)
		elif look == "pressed":
			fill = tint.darkened(0.08)
		var style := UiKit.panel_style(fill, 20)
		style.border_color = tint.darkened(0.20)
		style.set_border_width_all(3)
		add_theme_stylebox_override(look, style)

	var badge_size := clampf(box.y - 20.0, 38.0, 46.0)
	var badge := Panel.new()
	badge.name = "HeroTaskIconBadge"
	badge.position = Vector2(9.0, (box.y - badge_size) * 0.5)
	badge.size = Vector2.ONE * badge_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := UiKit.panel_style(Color(1.0, 1.0, 1.0, 0.72), 15)
	badge_style.set_content_margin_all(0)
	badge.add_theme_stylebox_override("panel", badge_style)
	add_child(badge)

	var art_size := badge_size - 10.0
	var art: Control = UiKit.picture(str(spec.get("icon", "star")), art_size)
	if art != null:
		art.name = "HeroTaskIcon"
		art.position = Vector2.ONE * (badge_size - art_size) * 0.5
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(art)

	var content_left := badge.position.x + badge_size + 10.0
	var action_right := box.x - 38.0
	var content_width := maxf(40.0, action_right - content_left)
	var preview: Dictionary = spec.get("preview", {})
	var marker_text := str(spec.get("marker", ""))
	# The farm's three daily verbs are optional presentation data, prepared by
	# its existing daily manager.  This component never opens the save itself:
	# another activity can use the same small progress crest without inheriting
	# the garden's rules.
	var daily: Dictionary = spec.get("daily", {})
	var has_daily := not daily.is_empty()
	# A marker is the caller's explicit header, so it wins over an optional
	# daily crest. More importantly, never pretend a three-line card fits in a
	# shorter slot: the action remains readable and the optional preview can
	# return when a host gives the ribbon its full height.
	var show_daily := has_daily and marker_text == ""
	var show_preview := not preview.is_empty() and (not show_daily \
		or box.y >= THREE_LINE_HEIGHT)
	var action_y := 8.0 if show_preview else (box.y - 27.0) * 0.5
	if marker_text != "":
		var marker := UiKit.title(marker_text, UiKit.TYPE_CAPTION,
			Color(0.32, 0.30, 0.24))
		marker.name = "HeroTaskMarker"
		marker.position = Vector2(content_left, 4.0)
		marker.size = Vector2(content_width, 16.0)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
		action_y = 18.0
	elif show_daily:
		_add_daily_badge(daily, content_left, box)
		action_y = DAILY_ACTION_Y

	var action := UiKit.title(str(spec.get("title", "")), UiKit.TYPE_CAPTION)
	action.name = "HeroTaskAction"
	action.position = Vector2(content_left, action_y)
	action.size = Vector2(content_width, 27.0)
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action.clip_text = true
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(action)

	var arrow := UiKit.title(">", UiKit.TYPE_BODY, Color(0.34, 0.30, 0.22))
	arrow.name = "HeroTaskArrow"
	arrow.position = Vector2(box.x - 29.0, (box.y - 28.0) * 0.5)
	arrow.size = Vector2(20.0, 28.0)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow)

	if show_preview:
		_add_preview(preview, content_left, box)
	if bool(spec.get("primary", false)):
		UiKit.breathe(self, 0.016, 1.4)


## Three tiny stars turn the ordinary "today" tally into a visual promise:
## water, harvest and help a friend all light one; all lit becomes a warm
## spark and the existing garden's doubled rare-crop chance.  These are a
## secondary status, not new buttons or a second task list, so the one large
## action above remains the only thing asking for a thumb.
func _add_daily_badge(daily: Dictionary, left: float, box: Vector2) -> void:
	var row := Control.new()
	row.name = "HeroTaskDaily"
	row.position = Vector2(left, 2.0)
	row.size = Vector2(maxf(74.0, box.x - left - 36.0), 18.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var done := clampi(int(daily.get("done", 0)), 0,
		maxi(int(daily.get("total", 0)), 0))
	var total := maxi(int(daily.get("total", 0)), 0)
	var all_done := bool(daily.get("all_done", false))
	row.set_meta("done", done)
	row.set_meta("total", total)
	row.set_meta("all_done", all_done)
	add_child(row)

	var crest: Control = UiKit.picture("spark" if all_done else "medal", 17.0)
	if crest != null:
		crest.name = "HeroTaskDailyIcon"
		crest.position = Vector2(0.0, -1.0)
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if all_done:
			crest.modulate = Color(1.0, 0.80, 0.26)
		row.add_child(crest)

	var star_size := 14.0
	# Before the surprise, the three small stars show what remains. Once all
	# are lit, let the warm "luck ×2" answer own the entire slim row rather
	# than squeezing a reward phrase beside decorative stars.
	var shown := mini(total, 5) if not all_done else 0
	var stars_left := maxf(50.0, row.size.x - float(shown) * (star_size + 1.0))
	var label := UiKit.title(str(daily.get("label", "%d/%d" % [done, total])),
		UiKit.TYPE_CAPTION,
		Color(0.38, 0.34, 0.25))
	label.name = "HeroTaskDailyProgress"
	label.position = Vector2(20.0, -2.0)
	label.size = Vector2(maxf(26.0, stars_left - 23.0), 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	for i in range(shown):
		var star: Control = UiKit.picture("star" if i < done else "star_empty", star_size)
		if star == null:
			continue
		star.name = "HeroTaskDailyStar_%d" % i
		star.position = Vector2(stars_left + float(i) * (star_size + 1.0), 1.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= done:
			star.modulate = Color(0.56, 0.54, 0.48, 0.72)
		row.add_child(star)


func _add_preview(preview: Dictionary, left: float, box: Vector2) -> void:
	var row := Control.new()
	row.name = "HeroTaskPreview"
	row.position = Vector2(left, box.y - 24.0)
	row.size = Vector2(maxf(44.0, box.x - left - 36.0), 21.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var x := 0.0
	var customer: Control = UiKit.picture(str(preview.get("customer_icon", "")), 20.0)
	if customer != null:
		customer.name = "HeroTaskCustomer"
		customer.position = Vector2(x, 0.0)
		customer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(customer)
		x += 26.0
	var crop: Control = UiKit.picture(str(preview.get("crop_icon", "")), 20.0)
	if crop != null:
		crop.name = "HeroTaskPreviewIcon"
		crop.position = Vector2(x, 0.0)
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(crop)
		x += 26.0
	var progress := UiKit.title(str(preview.get("progress", "")), UiKit.TYPE_CAPTION,
		Color(0.36, 0.32, 0.25))
	progress.name = "HeroTaskProgress"
	progress.position = Vector2(x, -1.0)
	progress.size = Vector2(maxf(26.0, row.size.x - x), 22.0)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.clip_text = true
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(progress)
