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
const ALBUM := [
	{"id": "walker", "icon": "monster", "tint": "#95919c",
		"name": "monster.walker"},
	{"id": "spitter", "icon": "goo", "tint": "#8cd26b",
		"name": "monster.spitter"},
	{"id": "armoured", "icon": "rock", "tint": "#7f8496",
		"name": "monster.armoured"},
	{"id": "rock_giant", "icon": "monster", "tint": "#b0a6c9",
		"name": "monster.rock_giant"},
]


func _album_shelf() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var met := 0
	for entry in ALBUM:
		if SaveManager.has_met(str(entry["id"])):
			met += 1
	var heading := UiKit.title("%s   %d / %d" % [
		I18n.t("album.title"), met, ALBUM.size()], 32)
	heading.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	box.add_child(heading)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for entry in ALBUM:
		var known: bool = SaveManager.has_met(str(entry["id"]))
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 2)

		var face := Control.new()
		face.custom_minimum_size = Vector2(112, 112)
		face.pivot_offset = Vector2(56, 56)
		var pad := Node2D.new()
		face.add_child(pad)
		Shapes.fill(pad, Shapes.rounded_rect(Vector2(2, 2), Vector2(108, 108), 26.0),
			Color(0.05, 0.09, 0.20, 0.55), 0.0)
		var art: Control = UiKit.picture(str(entry["icon"]), 74)
		if art != null:
			art.position = Vector2(19, 19)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if known:
				art.modulate = Color.from_string(str(entry["tint"]), Color.WHITE)
			else:
				# A silhouette, not a blank: the shape is a promise.
				art.modulate = Color(0.16, 0.19, 0.30)
			face.add_child(art)
		if not known:
			var mark := Label.new()
			mark.text = "?"
			mark.add_theme_font_size_override("font_size", 46)
			mark.add_theme_color_override("font_color", Color(0.55, 0.62, 0.80))
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.position = Vector2(0, 30)
			mark.size = Vector2(112, 52)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.add_child(mark)
		tile.add_child(face)

		var name_label := Label.new()
		name_label.text = I18n.t(str(entry["name"])) if known else "???"
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color",
			Color(0.92, 0.96, 1.0) if known else Color(0.52, 0.58, 0.72))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(112, 0)
		tile.add_child(name_label)
		row.add_child(tile)
	box.add_child(row)
	return box


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.world_background(self, "piglet_town", "rewards", 0.62)

	var root := UiKit.screen_root(self)
	root.add_theme_constant_override("separation", 16)

	var header := HBoxContainer.new()
	header.add_child(UiKit.back_button(func(): SceneManager.goto_home()))
	var title := UiKit.title(I18n.t("rewards.title"), 52)
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
	shop_style.set_corner_radius_all(26)
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
	shop_label.add_theme_font_size_override("font_size", 30)
	shop_label.add_theme_color_override("font_color", Color.WHITE)
	shop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_row.add_child(shop_label)
	shop.add_child(shop_row)
	shop.pressed.connect(func():
		SceneManager.goto_scene("res://scenes/shop/ItemShop.tscn"))
	header.add_child(shop)
	root.add_child(header)

	root.add_child(_album_shelf())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 20)
	scroll.add_child(list)

	# --- treasure card ---------------------------------------------------
	var treasure_card := UiKit.card()
	treasure_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var treasure_row := HBoxContainer.new()
	treasure_row.add_theme_constant_override("separation", 14)
	var coin_icon: Control = UiKit.picture("coin", 52)
	if coin_icon != null:
		treasure_row.add_child(coin_icon)
	var coins: int = int(SaveManager.data["rewards"]["coins"])
	treasure_row.add_child(UiKit.title("%s: %d" % [I18n.t("rewards.coins"), coins], 40))
	var star_icon: Control = UiKit.picture("star", 52)
	if star_icon != null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(28, 0)
		treasure_row.add_child(spacer)
		treasure_row.add_child(star_icon)
		treasure_row.add_child(UiKit.title("%d" % SaveManager.total_stars(), 40))
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
	var badge_title := UiKit.title(I18n.t("rewards.badges"), 40)
	badge_head.add_child(badge_title)
	var head_medal: Control = UiKit.picture("medal", 40)
	if head_medal != null:
		badge_head.add_child(head_medal)
	var count := UiKit.title("%d / %d" % [owned.size(), all_badges.size()], 36,
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

	var sticker_title := UiKit.title(I18n.t("rewards.stickers"), 40)
	sticker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sticker_box.add_child(sticker_title)

	var sticker_row := HFlowContainer.new()
	sticker_row.add_theme_constant_override("h_separation", 14)
	sticker_row.add_theme_constant_override("v_separation", 14)
	sticker_box.add_child(sticker_row)

	for sticker in GameData.rewards.get("stickers", []):
		sticker_row.add_child(_build_sticker(sticker))
	list.add_child(sticker_card)

	# --- growth card ---------------------------------------------------------
	var growth_card := UiKit.card()
	growth_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var growth_box := VBoxContainer.new()
	growth_box.add_theme_constant_override("separation", 12)
	growth_card.add_child(growth_box)

	var growth_title := UiKit.title(I18n.t("rewards.growth"), 40)
	growth_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	growth_box.add_child(growth_title)

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
		name_label.add_theme_font_size_override("font_size", 32)
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
	flat.set_corner_radius_all(20)
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
	caption.add_theme_font_size_override("font_size", 21)
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


func _build_sticker(sticker: Dictionary) -> Control:
	var sticker_id := str(sticker.get("id", ""))
	var cost := int(sticker.get("cost", 10))
	var owned := SaveManager.has_sticker(sticker_id)

	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(150, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0) if owned else Color(0.55, 0.58, 0.66, 0.18)
	style.set_corner_radius_all(22)
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
		var coin: Control = UiKit.picture("coin", 30)
		if coin != null:
			price.add_child(coin)
		var amount := Label.new()
		amount.text = str(cost)
		amount.add_theme_font_size_override("font_size", 24)
		amount.add_theme_color_override("font_color", Palette.INK)
		price.add_child(amount)
		price.position = Vector2(48, 112)
		tile.add_child(price)
		tile.pressed.connect(func(): _try_buy(sticker_id, cost, tile, icon, price))
	return tile


func _try_buy(sticker_id: String, cost: int, tile: Button, icon: Control, price: Control) -> void:
	if SaveManager.has_sticker(sticker_id):
		return
	if not SaveManager.spend_coins(cost):
		# Not enough yet: the price tag wiggles, nothing is lost, and the next
		# level is the way to fix it. No error sound, no popup.
		Juice.nudge(price)
		return
	SaveManager.add_sticker(sticker_id)
	if icon != null:
		icon.modulate = Color.WHITE
	price.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	style.set_corner_radius_all(22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		tile.add_theme_stylebox_override(state, style)
	Juice.pop(tile, 0.25)
	Juice.burst(self, tile.get_global_rect().get_center(), 18)
	AudioManager.play_sfx("res://assets/audio/coin.ogg")
	# The header chip and coins card are stale now; rebuild the screen state
	# cheaply by refreshing the scene.
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn")
