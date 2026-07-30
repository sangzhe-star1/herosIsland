extends Control
## What the child has earned. Coins, badges, and the five growth attributes
## shown as bars that only ever grow.
##
## Laid out like a BabyBus catalogue page: a soft light background with white
## rounded cards, one card per idea -- treasure, badges, growing up. The
## child's stuff looks collected and cared for, not listed.

## Every monster on the island, as a shelf of faces. Met ones are lit and
## named; the rest are dark silhouettes with a question mark.
##
## The silhouette is the whole point of a collection at six: a child can SEE
## that there are four and they have two, without being able to count or read.
## It is also the only thing in this game that says "there is more" -- and it
## says it without a shop, a timer or a locked box.
const Album := preload("res://scripts/reward/monster_album.gd")
const Coins := preload("res://scripts/shop/currency_manager.gd")
const Buying := preload("res://scripts/shop/purchase_manager.gd")

var _buying: Buying
var _coins_title: Label
var _sticker_row: HFlowContainer



## 怪兽图鉴 -- a card for every monster on the island.
##
## Each card draws the REAL creature, at the size a card can hold, from the
## same data the duel builds it from. A generic "monster" icon in four tints
## was what stood here before, which meant the thing he beat and the thing he
## collected were two different drawings and only one of them was his.
##
## Unmet monsters keep their true silhouette, dark, with no question mark: the
## shape is the promise. A question mark tells a child nothing except that
## something is being withheld.
func _album_shelf() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var heading := UiKit.title("%s   %d / %d" % [
		I18n.t("album.title"), Album.met_count(), Album.total()], UiKit.TYPE_TITLE)
	heading.add_theme_color_override("font_color", Color(0.16, 0.26, 0.42))
	box.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	for entry in Album.all():
		grid.add_child(_album_card(entry))
	var centre := HBoxContainer.new()
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(grid)
	box.add_child(centre)
	return box


## The card is ONE white panel, and the writing lives INSIDE it.
##
## It used to be a picture panel with two loose labels hanging underneath, and
## on the bottom row those labels came to rest on the hills and bushes of the
## background -- pale blue text on a green hillside, which a six-year-old
## cannot read at all. A caption that is not on the card is not on anything.
const CARD := Vector2(126, 192)
## Everything above this line is picture; everything below it is writing.
const CARD_ART := 130.0
## The page that opens when he taps a card he has earned.
const PAGE := Vector2(880, 460)


func _album_card(entry: Dictionary) -> Control:
	var known: bool = Album.met(str(entry.get("id", "")))
	var face := Control.new()
	face.custom_minimum_size = CARD
	face.clip_contents = true

	var pad := Node2D.new()
	face.add_child(pad)
	# A soft drop shadow, then the panel: the same white card the rest of this
	# screen is made of, so the album belongs to the page instead of sitting on
	# top of it.
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(3, 6), CARD - Vector2(6, 6), 22.0),
		Color(0.20, 0.28, 0.42, 0.20), 0.0)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2), CARD - Vector2(6, 8), 22.0),
		Color(1.0, 1.0, 1.0, 0.96) if known else Color(0.90, 0.93, 0.97, 0.94),
		0.0)

	# The creature itself, built by the same script the duel uses and scaled
	# down to fit the card. Standing on the card's floor, not floating.
	face.add_child(_beast(entry, known, CARD.x * 0.5, CARD_ART - 6.0,
		CARD_ART - 22.0))

	var name_label := Label.new()
	name_label.text = I18n.t(str(entry.get("name_key", ""))) if known else "???"
	name_label.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	name_label.add_theme_color_override("font_color",
		Color(0.16, 0.22, 0.34) if known else Color(0.55, 0.60, 0.70))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, CARD_ART)
	name_label.size = Vector2(CARD.x, 28)
	face.add_child(name_label)

	# Where he met it -- which is the part that turns a list into a memory.
	var where := Label.new()
	where.text = I18n.t(str(entry.get("where_key", ""))) if known \
		else I18n.t("album.not_yet")
	where.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	where.add_theme_color_override("font_color",
		Color(0.38, 0.50, 0.68) if known else Color(0.62, 0.67, 0.76))
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	where.position = Vector2(2, CARD_ART + 30.0)
	where.size = Vector2(CARD.x - 4, 26)
	face.add_child(where)

	# Tapping a card he has earned opens the page about it. The catalogue knows
	# each monster's move, its weakness and a sentence about how it behaves,
	# and none of that fits on a 126 px card -- but it is the part that turns a
	# shelf of stickers into a book worth opening twice.
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = Vector2.ZERO
	hit.size = CARD
	face.add_child(hit)
	if known:
		hit.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/card_flip.ogg")
			_open_page(entry))
	else:
		# A card he has not earned still ANSWERS: it shakes its head and
		# stays shut. It used to carry no button at all, and a tap fell
		# through to the sparkle catcher -- which at six reads as "this
		# shelf is a photograph". "Not yet" is information; silence is not.
		hit.pressed.connect(func():
			Juice.nudge(face)
			AudioManager.play_sfx("res://assets/audio/pop.ogg"))
	return face


## The creature, built by the same script the duel uses, from the same album
## entry. `at_y` is the floor it stands on; `room` is how tall it may be.
func _beast(entry: Dictionary, known: bool, at_x: float, at_y: float,
		room: float) -> Node2D:
	var beast: Node2D = preload("res://scripts/battle/monster.gd").new()
	beast.position = Vector2(at_x, at_y)
	var config: Dictionary = entry.duplicate(true)
	if not known:
		# Flat grey, shape only. For a painted monster this is a shader (see
		# monster.gd); the colours here are the fallback for any creature still
		# drawn by code.
		config["body_color"] = "#aab2c1"
		config["belly_color"] = "#c4cad4"
		config["accent_color"] = "#8d96a7"
		config["silhouette"] = true
	beast.build(config)
	var tall: float = maxf(float(entry.get("height", 300.0)), 1.0)
	var fit: float = room / tall
	beast.scale = Vector2(fit, fit)
	return beast


## One monster's page: the picture big, and the four things the catalogue
## knows about it. Opened by tapping its card.
func _open_page(entry: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.10, 0.20, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var page := Control.new()
	page.custom_minimum_size = PAGE
	layer.add_child(page)
	# Placed by hand, not by a preset. PRESET_CENTER sets the anchors AND the
	# offsets, so a position written afterwards is measured from the centre
	# rather than from the corner and the page slides off the bottom right --
	# which is exactly what the first screenshot showed.
	page.size = PAGE
	page.position = ((page.get_viewport_rect().size - PAGE) * 0.5).floor()

	var pad := Node2D.new()
	page.add_child(pad)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2(4, 10), PAGE, 30.0),
		Color(0.18, 0.24, 0.38, 0.28), 0.0)
	Shapes.fill(pad, Shapes.rounded_rect(Vector2.ZERO, PAGE, 30.0),
		Color(1.0, 1.0, 1.0, 0.98), 0.0)

	page.add_child(_beast(entry, true, 172.0, PAGE.y - 54.0, PAGE.y - 130.0))

	var name_label := UiKit.title(I18n.t(str(entry.get("name_key", ""))), UiKit.TYPE_TITLE)
	name_label.add_theme_color_override("font_color", Color(0.14, 0.20, 0.32))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.position = Vector2(330, 34)
	name_label.size = Vector2(PAGE.x - 360, 54)
	page.add_child(name_label)

	var rows: Array = [
		[I18n.t("album.element"), "%s · %s"
			% [I18n.t(str(entry.get("element_key", ""))),
				I18n.t(str(entry.get("where_key", "")))]],
		[I18n.t("album.skill"), I18n.t(str(entry.get("skill_key", "")))],
		[I18n.t("album.weakness"), I18n.t(str(entry.get("weakness_key", "")))],
	]
	var y := 96.0
	for row in rows:
		var tag := Label.new()
		tag.text = str(row[0])
		tag.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
		tag.add_theme_color_override("font_color", Color(0.52, 0.60, 0.74))
		tag.position = Vector2(330, y)
		tag.size = Vector2(96, 30)
		page.add_child(tag)
		var val := Label.new()
		val.text = str(row[1])
		val.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
		val.add_theme_color_override("font_color", Color(0.16, 0.24, 0.38))
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.position = Vector2(432, y - 2)
		val.size = Vector2(PAGE.x - 468, 62)
		page.add_child(val)
		y += 62.0

	var about := Label.new()
	about.text = I18n.t(str(entry.get("about_key", "")))
	about.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	about.add_theme_color_override("font_color", Color(0.30, 0.38, 0.52))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.position = Vector2(330, y + 6)
	# Stops above the close button rather than running under it -- the first
	# render had the last line of the description sitting behind 返回.
	about.size = Vector2(PAGE.x - 366, PAGE.y - y - 102.0)
	page.add_child(about)

	var close := UiKit.big_button(I18n.t("common.back"), Palette.BLUE)
	close.custom_minimum_size = Vector2(148, 72)
	close.position = Vector2(PAGE.x - 172, PAGE.y - 92)
	close.pressed.connect(func(): layer.queue_free())
	page.add_child(close)
	# Tapping the dark part closes it too -- a six-year-old taps outside the
	# box long before they find a button.
	dim.gui_input.connect(func(event: InputEvent):
		if UiKit.is_press(event):
			layer.queue_free())
	Juice.pop(page, 0.18)


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.world_background(self, "piglet_town", "rewards", 0.62)

	# Stickers used to be bought by ONE tap on the tile -- the exact shape the
	# red line forbids, shipped here because the wardrobe got the careful flow
	# and the sticker book was built earlier and never revisited. Same
	# contract, same file, now: confirm sheet, three numbers, five seconds of
	# 放回去.
	_buying = Buying.new()
	add_child(_buying)
	_buying.changed.connect(_refresh_money)
	_buying.go_play.connect(func(): SceneManager.goto_world_map())

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 16)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title(I18n.t("rewards.title"), UiKit.TYPE_DISPLAY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	# The treasure chest is now a DOOR: it opens the star shop. It sits where
	# the decorative chest used to sit, so the child who tapped the picture
	# out of hope (they all do) now gets a shop instead of nothing.
	var shop := Button.new()
	shop.custom_minimum_size = Vector2(220, 84)
	shop.focus_mode = Control.FOCUS_NONE
	var shop_style := StyleBoxFlat.new()
	shop_style.bg_color = Palette.ORANGE
	shop_style.set_corner_radius_all(UiKit.RADIUS)
	shop_style.border_width_bottom = 8
	shop_style.border_color = Palette.edge(Palette.ORANGE)
	var shop_pressed: StyleBoxFlat = shop_style.duplicate()
	shop_pressed.border_width_bottom = 3
	shop.add_theme_stylebox_override("normal", shop_style)
	shop.add_theme_stylebox_override("hover", shop_style)
	shop.add_theme_stylebox_override("pressed", shop_pressed)
	var shop_row := HBoxContainer.new()
	shop_row.position = Vector2(18, 10)
	shop_row.add_theme_constant_override("separation", 10)
	shop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chest: Control = UiKit.picture("chest", 60)
	if chest != null:
		shop_row.add_child(chest)
	var shop_label := Label.new()
	shop_label.text = I18n.t("shop.title")
	shop_label.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
	shop_label.add_theme_color_override("font_color", Color.WHITE)
	shop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_row.add_child(shop_label)
	shop.add_child(shop_row)
	shop.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		SceneManager.goto_scene("res://scenes/shop/ItemShop.tscn"))
	header.add_child(shop)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 20)
	scroll.add_child(list)

	# Inside the scroll, not above it. Ten monster cards is 460 px of fixed
	# height, and sitting outside the scroll it simply pushed the treasure and
	# the badges off the bottom of the screen -- the same trap the result
	# screen fell into: a column that grows with content, in a space that does
	# not.
	#
	# And FIRST only once there is something in it. A brand-new save used to
	# open this screen onto fifteen grey silhouettes saying 还没遇到 -- a wall
	# of "you have nothing" as the very first thing on a page called 我的奖励.
	# The silhouettes are a promise worth keeping, so the shelf stays; it just
	# waits below the things he HAS until the first monster is met.
	var shelf := _album_shelf()
	if Album.met_count() > 0:
		list.add_child(shelf)

	# --- treasure card ---------------------------------------------------
	var treasure_card := UiKit.card()
	treasure_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var treasure_row := HBoxContainer.new()
	treasure_row.add_theme_constant_override("separation", 14)
	var coin_icon: Control = UiKit.picture("star_coin", 52)
	if coin_icon != null:
		treasure_row.add_child(coin_icon)
	_coins_title = UiKit.title(
		"%s: %d" % [I18n.t("rewards.coins"), Coins.balance()], UiKit.TYPE_TITLE)
	treasure_row.add_child(_coins_title)
	var star_icon: Control = UiKit.picture("star", 52)
	if star_icon != null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(28, 0)
		treasure_row.add_child(spacer)
		treasure_row.add_child(star_icon)
		treasure_row.add_child(UiKit.title("%d" % SaveManager.total_stars(), UiKit.TYPE_TITLE))
	treasure_card.add_child(treasure_row)
	list.add_child(treasure_card)

	# --- badges card -------------------------------------------------------
	var badge_card := UiKit.card()
	badge_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge_box := VBoxContainer.new()
	badge_box.add_theme_constant_override("separation", 12)
	badge_card.add_child(badge_box)

	var owned: Array = SaveManager.data["rewards"]["badges"]
	var all_badges: Dictionary = GameData.rewards.get("badges", {})

	# Heading with a count. A six-year-old cannot read "Badges" but can
	# absolutely read "7 / 22", and the gap between the two numbers is the
	# whole reason to come back to this screen.
	var badge_head := HBoxContainer.new()
	badge_head.add_theme_constant_override("separation", 10)
	var badge_title := UiKit.title(I18n.t("rewards.badges"), UiKit.TYPE_TITLE)
	badge_head.add_child(badge_title)
	var head_medal: Control = UiKit.picture("medal", 40)
	if head_medal != null:
		badge_head.add_child(head_medal)
	var count := UiKit.title("%d / %d" % [owned.size(), all_badges.size()], UiKit.TYPE_TITLE,
		Palette.INK_SOFT)
	badge_head.add_child(count)
	badge_box.add_child(badge_head)

	var badge_row := HFlowContainer.new()
	badge_row.add_theme_constant_override("h_separation", 12)
	badge_row.add_theme_constant_override("v_separation", 14)
	badge_box.add_child(badge_row)

	for badge_id in all_badges.keys():
		badge_row.add_child(_build_badge(str(badge_id), all_badges[badge_id],
			str(badge_id) in owned))
	list.add_child(badge_card)

	# --- sticker book card ---------------------------------------------------
	# Coins finally have somewhere to GO. Each sticker is one of the game's
	# own badge pictures with a coin price; owned stickers glow at full
	# colour, unowned ones sit dim behind their price. Tap to buy -- if the
	# coins are there, it pops and it is yours forever. No reading needed:
	# picture, price, tap.
	var sticker_card := UiKit.card()
	sticker_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sticker_box := VBoxContainer.new()
	sticker_box.add_theme_constant_override("separation", 12)
	sticker_card.add_child(sticker_box)

	var sticker_title := UiKit.title(I18n.t("rewards.stickers"), UiKit.TYPE_TITLE)
	sticker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sticker_box.add_child(sticker_title)

	_sticker_row = HFlowContainer.new()
	_sticker_row.add_theme_constant_override("h_separation", 14)
	_sticker_row.add_theme_constant_override("v_separation", 14)
	sticker_box.add_child(_sticker_row)
	_fill_stickers()
	list.add_child(sticker_card)

	# --- growth card ---------------------------------------------------------
	var growth_card := UiKit.card()
	growth_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var growth_box := VBoxContainer.new()
	growth_box.add_theme_constant_override("separation", 12)
	growth_card.add_child(growth_box)

	var growth_title := UiKit.title(I18n.t("rewards.growth"), UiKit.TYPE_TITLE)
	growth_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	growth_box.add_child(growth_title)

	if Album.met_count() == 0:
		list.add_child(shelf)

	for attribute in GameData.rewards.get("growth_attributes", []):
		var id: String = attribute.get("id", "")
		var value: int = int(SaveManager.data["growth"].get(id, 0))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		# Courage, wisdom, kindness, focus, safety -- five words a six-year-old
		# cannot read, so each one wears its picture. Same rule as everywhere
		# else in the game; this screen was the last place still breaking it.
		var attr_icon: Control = UiKit.picture(str(attribute.get("icon", "star")), 46)
		if attr_icon != null:
			line.add_child(attr_icon)
		var name_label := Label.new()
		name_label.text = I18n.t(attribute.get("name_key", ""))
		name_label.custom_minimum_size = Vector2(230, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
		line.add_child(name_label)

		var bar := ProgressBar.new()
		bar.max_value = 30.0
		bar.value = mini(value, 30)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(500, 34)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", UiKit.track_style())
		bar.add_theme_stylebox_override("fill", UiKit.fill_style(Palette.STAR_ON))
		line.add_child(bar)
		growth_box.add_child(line)
	list.add_child(growth_card)


## One badge, as a medal.
##
## What this replaces: a grey slab reading "?" until earned and a line of
## Chinese afterwards. A child who cannot read learned nothing from either
## state -- not what they had won, and not what was left to win. That breaks
## the rule the rest of the game is built on: nothing important is carried by
## words alone.
##
## A locked badge now shows its OWN picture in silhouette behind a padlock, so
## the wall is a display of things to go and get rather than a row of question
## marks. It is the same reasoning as drawing the empty stars: seeing what is
## still out there is the entire point of showing it at all.
func _build_badge(badge_id: String, entry: Dictionary, earned: bool) -> Control:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(168, 208)
	tile.tooltip_text = RewardManager.badge_name(badge_id)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(1, 1, 1, 0.0)
	flat.set_corner_radius_all(UiKit.RADIUS_CARD)
	for state in ["normal", "hover", "pressed", "disabled"]:
		tile.add_theme_stylebox_override(state, flat)

	var medal := Control.new()
	medal.custom_minimum_size = Vector2(168, 132)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(medal)
	_draw_medal(medal, Vector2(84, 66), 56.0, earned)

	var icon: Control = UiKit.picture(str(entry.get("icon", "star")), 62)
	if icon != null:
		icon.position = Vector2(53, 33)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not earned:
			# The picture survives as a silhouette: recognisable in outline,
			# clearly not yet yours.
			icon.modulate = Color(0.40, 0.44, 0.54, 0.72)
		tile.add_child(icon)

	if not earned:
		var lock: Control = UiKit.picture("lock", 46)
		if lock != null:
			lock.position = Vector2(104, 74)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(lock)

	# The name only appears once it is won, and then it is a caption under a
	# picture the child already understands -- which is how early-reading
	# material teaches a word.
	var caption := Label.new()
	caption.text = RewardManager.badge_name(badge_id) if earned else ""
	caption.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	caption.add_theme_color_override("font_color", Palette.INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.position = Vector2(4, 132)
	caption.size = Vector2(160, 56)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(caption)

	if earned:
		# An earned badge is worth touching. It pops and chimes -- a small
		# reason to come back and visit the things you own.
		tile.resized.connect(func(): tile.pivot_offset = tile.size / 2.0)
		tile.pressed.connect(func():
			Juice.pop(tile, 0.22)
			Juice.burst(self, tile.get_global_rect().get_center(), 14)
			AudioManager.play_sfx("res://assets/audio/star.ogg")
		)
	else:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile


## A medal: ribbon, disc, scalloped rim. Drawn through Shapes like everything
## else, so a badge on this shelf is made of the same material as a tree.
func _draw_medal(parent: Control, at: Vector2, radius: float, earned: bool) -> void:
	var gold := Color(1.0, 0.80, 0.24) if earned else Color(0.72, 0.75, 0.82)
	var rim := Color(0.94, 0.68, 0.18) if earned else Color(0.62, 0.66, 0.74)
	var ribbon_a := Color(0.86, 0.32, 0.32) if earned else Color(0.66, 0.68, 0.74)
	var ribbon_b := Color(0.34, 0.54, 0.84) if earned else Color(0.60, 0.63, 0.70)

	for side in [-1.0, 1.0]:
		Shapes.fill(parent, PackedVector2Array([
			at + Vector2(side * radius * 0.16, -radius * 0.10),
			at + Vector2(side * radius * 0.72, -radius * 0.10),
			at + Vector2(side * radius * 0.98, radius * 1.20),
			at + Vector2(side * radius * 0.60, radius * 1.02),
			at + Vector2(side * radius * 0.30, radius * 1.20),
		]), ribbon_a if side < 0.0 else ribbon_b, 1.0)

	# Scalloped rim: twelve little bumps around the disc. It is the difference
	# between "a medal" and "a yellow circle".
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		Shapes.fill(parent, Shapes.circle_points(
			at + Vector2(cos(a), sin(a)) * radius * 0.92, radius * 0.20, 12), rim, 0.0)
	Shapes.lit(parent, Shapes.circle_points(at, radius * 0.94, 28), rim, 1.0)
	Shapes.lit(parent, Shapes.circle_points(at, radius * 0.76, 26), gold, 1.0)
	if earned:
		Shapes.glow(parent, at, radius * 2.0, Color(1.0, 0.86, 0.42), 5, 0.30)


## The shelf, rebuilt from the save. Called once at open and again after every
## buy or 放回去 -- the tiles are cheap, and rebuilding is how a tile bought
## and then returned goes honestly back to dim-with-a-price instead of some
## hand-mutated in-between.
func _fill_stickers() -> void:
	for child in _sticker_row.get_children():
		child.queue_free()
	for sticker in GameData.rewards.get("stickers", []):
		_sticker_row.add_child(_build_sticker(sticker))


func _refresh_money() -> void:
	if is_instance_valid(_coins_title):
		_coins_title.text = "%s: %d" % [I18n.t("rewards.coins"), Coins.balance()]
	if is_instance_valid(_sticker_row):
		_fill_stickers()


func _build_sticker(sticker: Dictionary) -> Control:
	var sticker_id := str(sticker.get("id", ""))
	var cost := int(sticker.get("cost", 10))
	var owned := SaveManager.has_sticker(sticker_id)

	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(150, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0) if owned else Color(0.55, 0.58, 0.66, 0.18)
	style.set_corner_radius_all(UiKit.RADIUS_CARD)
	for state in ["normal", "hover", "pressed", "disabled"]:
		tile.add_theme_stylebox_override(state, style)

	var icon: Control = UiKit.picture(sticker_id, 96)
	if icon != null:
		icon.position = Vector2(27, 8)
		icon.modulate = Color(1, 1, 1, 1.0) if owned else Color(0.6, 0.62, 0.7, 0.8)
		tile.add_child(icon)

	if not owned:
		var price := HBoxContainer.new()
		price.add_theme_constant_override("separation", 4)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var coin: Control = UiKit.picture("star_coin", 30)
		if coin != null:
			price.add_child(coin)
		var amount := Label.new()
		amount.text = str(cost)
		amount.add_theme_font_size_override("font_size", UiKit.TYPE_BODY)
		amount.add_theme_color_override("font_color", Palette.INK)
		price.add_child(amount)
		price.position = Vector2(48, 112)
		tile.add_child(price)
		# Opens the sheet; never buys. The sticker itself is handed over and
		# taken back through the two callables, and the money never moves in
		# this file at all.
		tile.pressed.connect(func():
			_buying.offer({
				"icon": sticker_id,
				"price": cost,
				"give": func(): SaveManager.add_sticker(sticker_id),
				"take_back": func(): SaveManager.remove_sticker(sticker_id),
			}))
	return tile
