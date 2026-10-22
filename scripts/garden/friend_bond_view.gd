extends RefCounted
## The two moments friendship pays out, shown on the friend's own farm: a
## keepsake sticker for the decorating room, and becoming best friends (every
## later share gives one more). Feedback, never a dialog: the card fades on
## its own and blocks no touch.

const CARD_NAME := "FriendBondCard"


static func show(parent: Node, view: Vector2, npc_id: String, sticker: String,
		became_best: bool) -> void:
	if sticker == "" and not became_best:
		return
	var friend_name := I18n.t(str(GameData.get_npc_farm(npc_id).get("name_key", "")))
	var lines: Array = []
	if sticker != "":
		lines.append(I18n.t("garden.friend_keepsake") % [friend_name])
	if became_best:
		lines.append(I18n.t("garden.friend_best") % [friend_name])

	var card := Panel.new()
	card.name = CARD_NAME
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",
		UiKit.panel_style(Color(1.0, 0.98, 0.92, 0.96), 26))
	var size := Vector2(620.0, 96.0 + 34.0 * float(lines.size() - 1))
	card.size = size
	card.position = Vector2((view.x - size.x) * 0.5, view.y - size.y - 28.0)
	parent.add_child(card)

	var art: Control = UiKit.picture(sticker if sticker != "" else "heart", 72.0)
	if art != null:
		art.position = Vector2(20.0, (size.y - 72.0) * 0.5)
		card.add_child(art)
	var text := UiKit.title("\n".join(lines), 22, Color(0.40, 0.28, 0.10))
	text.position = Vector2(108.0, 12.0)
	text.size = Vector2(size.x - 128.0, size.y - 24.0)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(text)

	AudioManager.play_sfx("res://assets/audio/sparkle.ogg")
	if Juice.motion_enabled():
		Juice.burst(parent, card.position + Vector2(56.0, size.y * 0.5), 14)
	var linger := card.create_tween()
	linger.tween_interval(3.2)
	linger.tween_property(card, "modulate:a", 0.0, 0.4)
	linger.tween_callback(card.queue_free)
