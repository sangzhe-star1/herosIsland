extends Control
## One thing in the wardrobe, as a card a six-year-old can read without words.
##
## The old tile was 94x94 with a 62 px icon and a number under it, and the only
## difference between "you own this", "you are wearing this" and "you cannot
## have this yet" was the colour of a 4 px border. This is the same information
## as pictures: a tick, a gold frame, a real silhouette with the thing he has
## to do to unlock it drawn beside it.
##
## The picture is the ITEM, not the hero wearing it. A row of nine identical
## small heroes is the single most common way a dressing-up game becomes
## unreadable, and the brief calls it out by name.

const Shapes := preload("res://scripts/world/shapes.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")
const Art := preload("res://scripts/reward/monster_art.gd")

signal tapped(item_id: String)
signal held(item_id: String)
signal dragged(item_id: String, at: Vector2)

const BOX := Vector2(180, 168)
## The picture gets this much of the card. The brief asks for 60% minimum.
const ART_H := 100.0

var entry: Dictionary = {}
var _state: int = Shop.State.BUYABLE
var _press := 0.0
var _pressing := false
var _dragged := false
var _from := Vector2.ZERO


func build(item: Dictionary, character_id: String) -> void:
	entry = item
	custom_minimum_size = BOX
	size = BOX
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_state = Shop.state_of(entry, character_id)

	for child in get_children():
		child.queue_free()

	var pad := Node2D.new()
	add_child(pad)
	_paint(pad)
	_picture()
	_label()
	_footer(pad)

	gui_input.connect(_on_input)
	set_process(true)


func refresh(character_id: String) -> void:
	build(entry, character_id)


# --- the card itself ------------------------------------------------------

func _paint(pad: Node2D) -> void:
	var wearing: bool = _state == Shop.State.WEARING
	var dim: bool = _state == Shop.State.LOCKED or _state == Shop.State.INCOMPATIBLE
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(4, 8), BOX - Vector2(8, 8), 26.0),
		Color(0.20, 0.30, 0.45, 0.18), 0.0)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2), BOX - Vector2(8, 10), 26.0),
		Color(0.94, 0.96, 0.99, 0.96) if dim else Color(1, 1, 1, 0.98), 0.0)
	if wearing:
		# A whole gold frame, not a hairline: "this is the one you have on" has
		# to survive being glanced at from across a room.
		var ring := Shapes.rounded_rect(Vector2(2, 2), BOX - Vector2(8, 10), 26.0)
		# A thin band. The first version was 9 px in on every side, which put
		# the gold straight over the "正在使用" caption underneath it.
		var inner := Shapes.rounded_rect(Vector2(6, 6), BOX - Vector2(16, 18), 22.0)
		var band := PackedVector2Array()
		band.append_array(ring)
		band.append(ring[0])
		for i in range(inner.size() - 1, -1, -1):
			band.append(inner[i])
		band.append(inner[inner.size() - 1])
		Shapes.fill(pad, band, Color(1.0, 0.78, 0.26, 0.95), 0.0)


func _picture() -> void:
	var holder := Control.new()
	holder.position = Vector2(0, 8)
	holder.size = Vector2(BOX.x, ART_H)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	add_child(holder)

	# A face has no PNG: it is drawn, so the card draws the real figure at card
	# size. That matters more here than anywhere else in the wardrobe -- the
	# thing being chosen IS the picture, and a child picks the one whose
	# outline he likes long before he reads the name.
	if Shop.is_who(entry):
		_portrait(holder)
		return

	var art_path := str(entry.get("art", ""))
	if art_path != "":
		var tex: Texture2D = Art._load(art_path)
		if tex != null:
			var s := TextureRect.new()
			s.texture = tex
			s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			s.position = Vector2(12, 0)
			s.size = Vector2(BOX.x - 24, ART_H)
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _state == Shop.State.LOCKED:
				# A real silhouette of the real thing. Not a question mark:
				# the shape is the promise, and a "?" tells a child only that
				# something is being kept from him.
				s.material = _shadow_material()
			holder.add_child(s)
			return
	# Colours and anything without a picture fall back to a drawn swatch.
	_swatch(holder)


## The character, standing in the card. Bought or not, he is drawn in full
## colour -- a locked face is marked by its price tag, not by being hidden.
## Greying out a person reads as "he is broken", and the whole point of the
## drawer is to make him want to meet them.
func _portrait(holder: Control) -> void:
	var cid := Shop.who_id(entry)
	var skin: CharacterSkin = GameData.skin_for(cid)
	if skin == null:
		_swatch(holder)
		return
	var figure := SkinnedCharacter.new()
	# No companion in a 100 px card: a hero and a puppy in that space shows
	# neither of them.
	figure.show_pal = false
	figure.skin = skin
	figure.position = Vector2(BOX.x * 0.5, ART_H - 2.0)
	holder.add_child(figure)
	figure.set_height(ART_H - 8.0)


func _swatch(holder: Control) -> void:
	var body := Color.from_string(str(entry.get("body_color", "#8fb8e8")),
		Color(0.56, 0.72, 0.91))
	var accent := Color.from_string(str(entry.get("accent_color", "#4a7cc0")),
		body.darkened(0.25))
	var pad := Node2D.new()
	holder.add_child(pad)
	var mid := Vector2(BOX.x * 0.5, ART_H * 0.5)
	if str(entry.get("id", "")) == "colour_rainbow":
		var bands := [Color(0.93,0.36,0.36), Color(0.97,0.72,0.30),
			Color(0.98,0.90,0.38), Color(0.48,0.82,0.52),
			Color(0.42,0.66,0.94), Color(0.68,0.50,0.90)]
		for i in range(bands.size()):
			Shapes.fill(pad, Shapes.rounded_rect(
				Vector2(mid.x - 46.0, mid.y - 46.0 + float(i) * 15.0),
				Vector2(92.0, 14.0), 7.0), bands[i], 0.0)
	else:
		Shapes.lit(pad, Shapes.circle_points(mid, 46.0, 32), body, 1.0)
		Shapes.fill(pad, Shapes.circle_points(mid + Vector2(0, 16.0), 26.0, 24),
			accent, 0.0)
		Shapes.fill(pad, Shapes.oval_points(mid + Vector2(-14.0, -18.0),
			Vector2(16.0, 10.0), 14), Color(1, 1, 1, 0.5), 0.0)


static var _shadow: ShaderMaterial


static func _shadow_material() -> ShaderMaterial:
	if _shadow != null:
		return _shadow
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" \
		+ "uniform vec4 tint : source_color = vec4(0.63, 0.68, 0.78, 1.0);\n" \
		+ "void fragment() {\n" \
		+ "\tCOLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);\n" \
		+ "}\n"
	_shadow = ShaderMaterial.new()
	_shadow.shader = shader
	return _shadow


func _label() -> void:
	var name_label := Label.new()
	name_label.text = I18n.t(str(entry.get("name_key", "")))
	name_label.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	name_label.add_theme_color_override("font_color",
		Color(0.58, 0.63, 0.72) if _state == Shop.State.LOCKED
		else Color(0.15, 0.22, 0.34))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(4, ART_H + 4.0)
	name_label.size = Vector2(BOX.x - 8, 26)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)


## The bottom strip says, in pictures, what happens if he taps it.
func _footer(pad: Node2D) -> void:
	var y := ART_H + 26.0
	match _state:
		Shop.State.WEARING:
			# The tick to the LEFT of the caption, not on top of it. The first
			# pass put both in the middle of the card and the tick sat on the
			# first character.
			# The tick is the message and the words are the footnote: a child
			# who cannot read has to be able to tell "wearing" from "have it"
			# from "costs stars" at a glance, from across the table.
			_tick(pad, Vector2(26.0, y + 13.0), Color(1.0, 0.72, 0.20), 15.0)
			# A face is not worn, so it says 就是他 rather than 正在使用.
			_line(I18n.t("house.being" if Shop.is_who(entry) else "house.wearing"),
				y + 2.0, Color(0.72, 0.50, 0.06), 17, 30.0)
		Shop.State.OWNED:
			_tick(pad, Vector2(34.0, y + 13.0), Color(0.34, 0.74, 0.42), 15.0)
			_line(I18n.t("house.be_him" if Shop.is_who(entry) else "house.wear"),
				y + 2.0, Color(0.20, 0.52, 0.28), 17, 30.0)
		Shop.State.INCOMPATIBLE:
			_line(I18n.t("house.locked_hint"), y, Color(0.52, 0.58, 0.70), 19)
		Shop.State.LOCKED:
			_unlock_hint(pad, y)
		_:
			_price(pad, y)
	if Shop.is_new(str(entry.get("id", ""))):
		# One small star, corner, gone after he looks. Never a pulsing dot.
		Shapes.lit(pad, Shapes.star_points(Vector2(BOX.x - 30.0, 26.0), 15.0, 0.44, 5),
			Color(1.0, 0.86, 0.34), 0.9)


## Money wears the COIN, everywhere. The plain star is the score a level
## pays and can never be spent; drawing prices with that same star was
## quietly telling a child the opposite of the game's first promise.
func _price(pad: Node2D, y: float) -> void:
	var price := int(entry.get("price", 0))
	var mid := Vector2(BOX.x * 0.5 - 32.0, y + 15.0)
	Shapes.lit(pad, Shapes.circle_points(mid, 13.0, 20), Color(1.0, 0.83, 0.30), 0.95)
	Shapes.fill(pad, Shapes.star_points(mid, 7.5, 0.44, 5), Color(0.95, 0.55, 0.15), 0.0)
	var label := Label.new()
	label.text = str(price)
	label.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	label.add_theme_color_override("font_color", Color(0.24, 0.34, 0.50))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector2(BOX.x * 0.5 - 12.0, y)
	label.size = Vector2(70, 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## What he has to DO, drawn. A locked card that only says "locked" teaches a
## child that some things are simply not for him; one that shows three stars
## or a world badge teaches him where to go.
func _unlock_hint(pad: Node2D, y: float) -> void:
	var cond: Dictionary = entry.get("unlock_condition", {})
	var kind := str(cond.get("type", ""))
	var count := int(cond.get("count", 0))
	var mid := Vector2(BOX.x * 0.5, y + 15.0)
	match kind:
		"three_stars", "world_stars":
			for i in range(3):
				Shapes.lit(pad, Shapes.star_points(
					mid + Vector2(float(i - 1) * 30.0, 0.0), 13.0, 0.44, 5),
					Color(1.0, 0.83, 0.30), 0.85)
			_number(count, mid + Vector2(46.0, 0.0))
		"world_done":
			Shapes.lit(pad, Shapes.rounded_rect(mid - Vector2(20.0, 14.0),
				Vector2(40.0, 28.0), 8.0), Color(0.56, 0.74, 0.96), 0.9)
			Shapes.fill(pad, Shapes.circle_points(mid, 7.0, 14),
				Color(1.0, 0.94, 0.62), 0.0)
		"badges":
			Shapes.lit(pad, Shapes.circle_points(mid, 16.0, 20),
				Color(0.98, 0.78, 0.34), 0.9)
			Shapes.fill(pad, Shapes.star_points(mid, 9.0, 0.44, 5),
				Color(1.0, 1.0, 1.0, 0.9), 0.0)
			_number(count, mid + Vector2(34.0, 0.0))
		"boss_beaten":
			Shapes.lit(pad, Shapes.circle_points(mid, 17.0, 20),
				Color(0.72, 0.55, 0.92), 0.9)
			for horn in [-1.0, 1.0]:
				Shapes.fill(pad, PackedVector2Array([
					mid + Vector2(horn * 6.0, -12.0),
					mid + Vector2(horn * 16.0, -26.0),
					mid + Vector2(horn * 15.0, -9.0)]),
					Color(0.94, 0.90, 0.82), 0.0)
		_:
			# levels_done, and anything new: a little flag and a number.
			Shapes.fill(pad, Shapes.taper(mid + Vector2(-16.0, 14.0),
				mid + Vector2(-16.0, -16.0), 4.0, 3.0), Color(0.62, 0.66, 0.76), 0.0)
			Shapes.lit(pad, PackedVector2Array([
				mid + Vector2(-14.0, -16.0), mid + Vector2(14.0, -9.0),
				mid + Vector2(-14.0, -2.0)]), Color(0.56, 0.78, 0.98), 0.9)
			_number(count, mid + Vector2(30.0, 0.0))


func _number(value: int, at: Vector2) -> void:
	if value <= 0:
		return
	var label := Label.new()
	label.text = str(value)
	label.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	label.add_theme_color_override("font_color", Color(0.42, 0.50, 0.64))
	label.position = at - Vector2(6, 16)
	label.size = Vector2(56, 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _tick(pad: Node2D, at: Vector2, colour: Color, radius: float = 15.0) -> void:
	Shapes.lit(pad, Shapes.circle_points(at, radius, 20), colour, 0.9)
	var k: float = radius / 15.0
	Shapes.fill(pad, Shapes.ribbon(PackedVector2Array([
		at + Vector2(-7.0 * k, 0.0), at + Vector2(-2.0 * k, 6.0 * k),
		at + Vector2(8.0 * k, -7.0 * k)]),
		4.0 * k, 4), Color(1, 1, 1, 0.95), 0.0)


func _line(text: String, y: float, colour: Color, size_px: int = 21,
		shift: float = 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(20.0 + shift, y)
	label.size = Vector2(BOX.x - 40.0 - shift, 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


# --- touch ----------------------------------------------------------------

func _on_input(event: InputEvent) -> void:
	if UiKit.is_press(event):
		_pressing = true
		_press = 0.0
		_dragged = false
		_from = _where(event)
		if Juice.motion_enabled():
			var t := create_tween()
			t.tween_property(self, "scale", Vector2(0.94, 0.94), 0.07)
		accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		# Dragging the card upward, towards the hero, is the other way to try
		# something on -- and it is the one a child invents on their own.
		if _pressing and not _dragged and _where(event).y - _from.y < -46.0:
			_dragged = true
			_pressing = false
			if Juice.motion_enabled():
				var t := create_tween()
				t.tween_property(self, "scale", Vector2.ONE, 0.12)
			dragged.emit(str(entry.get("id", "")), _where(event))
	elif UiKit.is_release(event):
		if Juice.motion_enabled():
			var t := create_tween()
			t.tween_property(self, "scale", Vector2.ONE, 0.12)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _pressing and _press < 0.55 and not _dragged:
			tapped.emit(str(entry.get("id", "")))
		_pressing = false
		_dragged = false
		accept_event()


func _where(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).global_position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).global_position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.ZERO


func _process(delta: float) -> void:
	if not _pressing:
		return
	_press += delta
	if _press >= 0.55:
		_pressing = false
		held.emit(str(entry.get("id", "")))
