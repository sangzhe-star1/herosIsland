extends Node
## Try on, decide, buy, and change your mind.
##
## Everything that can cost a child a star goes through this file, so there is
## one place to look when the answer to "did that just spend money?" has to be
## no. The rules it exists to enforce:
##
##   TRYING ON IS FREE, ALWAYS. Not "free unless you tap twice", not "free
##   until you leave the page". A six-year-old explores by touching everything,
##   and a wardrobe that charges for looking teaches him to stop touching.
##   The preview never writes to the save; see SkinnedCharacter.preview_outfit.
##
##   NOTHING IS BOUGHT BY ONE TAP. Try-on comes first, always, and the buy
##   button is a second, deliberate press on a card that shows him the three
##   numbers that matter: what he has, what it costs, what is left.
##
##   A MIS-TAP IS RECOVERABLE. 放回去 sits there for five seconds after every
##   purchase and refunds in full. Shop.undo() was written for this.
##
##   RUNNING SHORT IS NOT AN ERROR. No red, no cross, no "failed". Three big
##   buttons and a sentence that points at the game.

const Shapes := preload("res://scripts/world/shapes.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Wishes := preload("res://scripts/shop/wishlist_manager.gd")
const Art := preload("res://scripts/reward/monster_art.gd")

signal bought(item_id: String)
signal changed()
signal go_play()

const UNDO_SECONDS := 5.0

var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)


func _panel(box: Vector2) -> Control:
	for child in _layer.get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.11, 0.21, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var card := Control.new()
	_layer.add_child(card)
	card.size = box
	card.position = ((card.get_viewport_rect().size - box) * 0.5).floor()
	var pad := Node2D.new()
	card.add_child(pad)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(5, 12), box, 32.0),
		Color(0.18, 0.25, 0.40, 0.26), 0.0)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, box, 32.0),
		Color(1, 1, 1, 0.99), 0.0)
	Juice.pop(card, 0.2)
	return card


func close() -> void:
	for child in _layer.get_children():
		child.queue_free()


func is_open() -> bool:
	return _layer != null and _layer.get_child_count() > 0


# --- the confirm card -----------------------------------------------------

## Three numbers and two buttons. No sentences: "现在有 / 要花 / 还剩" over
## three star counts is a thing a child who cannot read yet can still follow,
## because the middle number is the one that leaves.
func confirm(item_id: String) -> void:
	var entry := Shop.item(item_id)
	if entry.is_empty():
		return
	var price := int(entry.get("price", 0))
	var have := Coins.balance()
	if have < price:
		short_of(item_id)
		return

	var box := Vector2(720, 420)
	var card := _panel(box)
	var pad := Node2D.new()
	card.add_child(pad)

	_thumb(card, Vector2(box.x * 0.5, 40.0), 132.0, entry)
	var name_label := UiKit.title(I18n.t(str(entry.get("name_key", ""))), 40)
	name_label.add_theme_color_override("font_color", Color(0.14, 0.21, 0.34))
	name_label.position = Vector2(0, 178)
	name_label.size = Vector2(box.x, 50)
	card.add_child(name_label)

	var cols := [
		[I18n.t("house.have"), have, Color(0.30, 0.40, 0.56)],
		[I18n.t("house.cost"), price, Color(0.90, 0.55, 0.16)],
		[I18n.t("house.left"), have - price, Color(0.24, 0.60, 0.36)],
	]
	for i in range(cols.size()):
		var x: float = box.x * (0.22 + 0.28 * float(i))
		Shapes.lit(pad, Shapes.star_points(Vector2(x - 34.0, 258.0), 15.0, 0.44, 5),
			Color(1.0, 0.83, 0.30), 0.9)
		var n := Label.new()
		n.text = str(cols[i][1])
		n.add_theme_font_size_override("font_size", 34)
		n.add_theme_color_override("font_color", cols[i][2])
		n.position = Vector2(x - 14.0, 238.0)
		n.size = Vector2(90, 44)
		card.add_child(n)
		var t := Label.new()
		t.text = str(cols[i][0])
		t.add_theme_font_size_override("font_size", 19)
		t.add_theme_color_override("font_color", Color(0.56, 0.62, 0.74))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.position = Vector2(x - 70.0, 286.0)
		t.size = Vector2(140, 26)
		card.add_child(t)

	var yes := _star_button(str(price), Palette.GREEN, Vector2(250, 84))
	yes.position = Vector2(box.x * 0.5 - 268.0, 322.0)
	yes.pressed.connect(func(): _do_buy(item_id))
	card.add_child(yes)

	var no := UiKit.big_button(I18n.t("common.back"), Palette.BLUE)
	no.custom_minimum_size = Vector2(210, 84)
	no.position = Vector2(box.x * 0.5 + 30.0, 322.0)
	no.pressed.connect(close)
	card.add_child(no)


func _star_button(text: String, colour: Color, box: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = box
	b.size = box
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(26)
	style.border_width_bottom = 8
	style.border_color = Palette.edge(colour)
	var down: StyleBoxFlat = style.duplicate()
	down.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", style)
	b.add_theme_stylebox_override("pressed", down)
	var row := Node2D.new()
	row.position = Vector2(box.x * 0.5 - 34.0, box.y * 0.5)
	row.z_index = 1
	b.add_child(row)
	Shapes.lit(row, Shapes.star_points(Vector2.ZERO, 19.0, 0.44, 5),
		Color(1.0, 0.90, 0.42), 0.95)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(box.x * 0.5 - 6.0, box.y * 0.5 - 24.0)
	label.size = Vector2(96, 48)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	return b


func _thumb(parent: Control, at: Vector2, box: float, entry: Dictionary) -> void:
	var art_path := str(entry.get("art", ""))
	if art_path == "":
		return
	var tex: Texture2D = Art._load(art_path)
	if tex == null:
		return
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = at - Vector2(box * 0.5, 0)
	pic.size = Vector2(box, box)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)


# --- buying ---------------------------------------------------------------

func _do_buy(item_id: String) -> void:
	var result := Shop.buy(item_id)
	if result != "":
		# buy() already refuses for the right reasons; the only one a child can
		# reach from here is running short between opening the card and tapping.
		short_of(item_id)
		return
	Shop.equip(item_id)
	Shop.mark_seen(item_id)
	bought.emit(item_id)
	changed.emit()
	_celebrate(item_id)


## Star flies, box opens, thing jumps out, hero wears it, confetti. Then a
## quiet 放回去 that lasts five seconds.
func _celebrate(item_id: String) -> void:
	var entry := Shop.item(item_id)
	var box := Vector2(620, 430)
	var card := _panel(box)
	var pad := Node2D.new()
	card.add_child(pad)

	var frames: Array = []
	for i in range(1, 7):
		frames.append(Art._load("res://assets/outfits/giftbox/giftbox_0%d_%s.png"
			% [i, ["closed", "shake", "opening", "lightbeam", "starburst",
				"afterglow"][i - 1]]))
	var gift := TextureRect.new()
	gift.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gift.position = Vector2(box.x * 0.5 - 130.0, 30.0)
	gift.size = Vector2(260, 260)
	gift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if frames[0] != null:
		gift.texture = frames[0]
	card.add_child(gift)

	var line := UiKit.title(I18n.t("house.bought"), 36)
	line.add_theme_color_override("font_color", Color(0.16, 0.24, 0.38))
	line.position = Vector2(0, 296)
	line.size = Vector2(box.x, 48)
	line.modulate.a = 0.0
	card.add_child(line)

	AudioManager.play_sfx("res://assets/audio/chest_open.ogg")
	AudioManager.say("house_bought")

	if Juice.motion_enabled():
		for i in range(1, frames.size()):
			await get_tree().create_timer(0.13).timeout
			if not is_instance_valid(gift):
				return
			if frames[i] != null:
				gift.texture = frames[i]
		Juice.burst(card, Vector2(box.x * 0.5, 150.0), 34)
	if is_instance_valid(line):
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 1.0, 0.22)

	if not is_instance_valid(card):
		return
	var keep := UiKit.big_button(I18n.t("house.keep_going"), Palette.GREEN)
	keep.custom_minimum_size = Vector2(280, 82)
	keep.position = Vector2(box.x * 0.5 - 296.0, 336.0)
	keep.pressed.connect(close)
	card.add_child(keep)

	# 放回去: full refund, no questions, and it goes away by itself so it never
	# becomes a thing he can undo an hour later by accident.
	var undo := UiKit.big_button(I18n.t("house.buy_back"), Palette.BLUE)
	undo.custom_minimum_size = Vector2(280, 82)
	undo.position = Vector2(box.x * 0.5 + 16.0, 336.0)
	undo.pressed.connect(func():
		if Shop.undo(item_id):
			changed.emit()
		close())
	card.add_child(undo)
	await get_tree().create_timer(UNDO_SECONDS).timeout
	if is_instance_valid(undo):
		undo.visible = false
		if is_instance_valid(keep):
			keep.position.x = box.x * 0.5 - 140.0


# --- not enough stars -----------------------------------------------------

## Never an error. Three doors out, and one of them is "go and play", which is
## the honest answer: stars come from levels.
func short_of(item_id: String) -> void:
	var entry := Shop.item(item_id)
	var price := int(entry.get("price", 0))
	var have := Coins.balance()
	var box := Vector2(840, 400)
	var card := _panel(box)
	var pad := Node2D.new()
	card.add_child(pad)

	var lines := ["house.almost_1", "house.almost_2", "house.almost_3"]
	var pick: int = 0 if have * 3 < price else (1 if have * 4 >= price * 3 else 2)
	var head := UiKit.title(I18n.t(lines[pick]), 38)
	head.add_theme_color_override("font_color", Color(0.20, 0.30, 0.46))
	head.position = Vector2(0, 34)
	head.size = Vector2(box.x, 52)
	card.add_child(head)

	# The gap, drawn. A bar that is nearly full says "nearly" without numbers.
	var share: float = clampf(float(have) / maxf(float(price), 1.0), 0.0, 1.0)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(box.x * 0.5 - 270.0, 116.0),
		Vector2(540.0, 34.0), 17.0), Color(0.87, 0.91, 0.96), 0.0)
	# fill(), not lit(). Shapes.lit adds a highlight shifted by a tenth of the
	# shape's EXTENT -- fine on a star or a face, but on a 540 px bar that is a
	# 54 px shove and the highlight floats off above it as a second stray pill.
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(box.x * 0.5 - 270.0, 116.0),
		Vector2(maxf(540.0 * share, 34.0), 34.0), 17.0),
		Color(1.0, 0.80, 0.30), 0.9)
	for i in range(2):
		Shapes.lit(pad, Shapes.star_points(
			Vector2(box.x * 0.5 - 292.0 + float(i) * 584.0, 133.0), 16.0, 0.44, 5),
			Color(1.0, 0.83, 0.30) if i == 0 else Color(0.72, 0.78, 0.88), 0.9)
	var counts := Label.new()
	counts.text = "%d / %d" % [have, price]
	counts.add_theme_font_size_override("font_size", 26)
	counts.add_theme_color_override("font_color", Color(0.34, 0.44, 0.60))
	counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counts.position = Vector2(0, 162)
	counts.size = Vector2(box.x, 34)
	card.add_child(counts)

	var buttons := [
		[I18n.t("house.go_play"), Palette.GREEN, func():
			close(); go_play.emit()],
		[I18n.t("house.wish"), Palette.PURPLE, func():
			Wishes.add(item_id); close(); changed.emit()],
		[I18n.t("house.browse"), Palette.BLUE, close],
	]
	for i in range(buttons.size()):
		var b := UiKit.big_button(str(buttons[i][0]), buttons[i][1])
		b.custom_minimum_size = Vector2(236, 92)
		b.position = Vector2(box.x * 0.5 - 372.0 + float(i) * 256.0, 240.0)
		b.pressed.connect(buttons[i][2])
		card.add_child(b)
	AudioManager.play_sfx("res://assets/audio/drag_back.ogg")
